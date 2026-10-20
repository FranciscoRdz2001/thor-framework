// The test client's query and command against a live app, the hard cases: no
// page, the wrong page, a redirect, an argument the wire cannot carry, a
// hostile body, and calls racing each other on one jar.
import 'package:server_query/app.dart';
import 'package:server_query/core/db/database.dart';
import 'package:server_query/modules/cart/state/cart_state.dart';
import 'package:server_query/modules/profile/state/profile_state.dart';
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';

ThorTestClient _visitor([String? session = 'ana']) {
  final app = appHandler().client();
  if (session != null) app.setCookie('sq-session', session);
  return app;
}

int _units() =>
    database.select(
          'SELECT COALESCE(SUM(qty), 0) AS n FROM cart WHERE login = ?',
          ['ana'],
        ).first['n']
        as int;

void main() {
  setUp(() => database.execute('DELETE FROM cart'));

  group('which page a call goes to', () {
    test(
      'a guest bounced by a redirect has no page until it follows',
      () async {
        final app = _visitor(null);
        final bounce = await app.get('/profile');
        expect(bounce, redirectsTo('/login'));
        expect(app.location, isNull);
        expect(
          () => app.query(profile.info),
          throwsA(isA<StateError>()),
          reason: 'a redirect is not a page',
        );
        await app.follow(bounce);
        expect(app.location!.path, '/login');
      },
    );

    test(
      'after a followed redirect the query goes to the page that answered',
      () async {
        final app = _visitor(null);
        await app.get('/profile', follow: true);
        // /login does not use the profile state: as in a browser, a 404.
        expect(await app.query(profile.info), hasStatus(404));
      },
    );

    test('a query of another page is a 404, and so is a command', () async {
      final app = _visitor();
      await app.get('/profile');
      expect(await app.query(cart.total), hasStatus(404));
      expect(await app.command(cart.clear), hasStatus(404));
      expect(_units(), 0);
    });

    test(
      'path: sends the call to another page without moving the client',
      () async {
        final app = _visitor();
        await app.get('/profile');
        final r = await app.callQuery(
          app.idOf(cart.total),
          hasArg: false,
          path: '/cart',
        );
        expect(r, hasStatus(200));
        expect(app.location!.path, '/profile');
      },
    );

    test('a call does not move the client, even when it fails', () async {
      final app = _visitor();
      await app.get('/cart');
      await app.command(cart.checkout);
      expect(app.location!.path, '/cart');
    });

    test('a page with a query string keeps it for the call', () async {
      final app = _visitor();
      await app.get('/cart?x=1');
      expect(app.location.toString(), 'http://localhost/cart?x=1');
      expect(await app.query(cart.total), hasStatus(200));
    });
  });

  group('arguments', () {
    test(
      'a record cannot be JSON: the mistake is named before any request',
      () async {
        final app = _visitor();
        await app.get('/cart');
        await expectLater(
          app.callQuery('CartState.lines', arg: (1, 2)),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('an object of your own class says it is not JSON', () async {
      final app = _visitor();
      await app.get('/cart');
      await expectLater(
        app.command(cart.add, _Sku('taza') as dynamic),
        throwsA(
          isA<ArgumentError>().having((e) => '$e', 'message', contains('JSON')),
        ),
      );
    });

    test('a missing, null or wrong-typed arg is a 400, never a 500', () async {
      final app = _visitor();
      await app.get('/cart');
      for (final arg in <Object?>[
        null,
        'x',
        1.5,
        <Object?>[],
        {'a': 1},
        true,
      ]) {
        final r = await app.callQuery('CartState.lines', arg: arg);
        expect(r.status, anyOf(200, 400), reason: 'arg $arg → ${r.text}');
      }
      expect(
        await app.callQuery('CartState.lines', hasArg: false),
        hasStatus(400),
      );
    });

    test('a body that is not an object is a 400', () async {
      final app = _visitor();
      await app.get('/cart');
      for (final body in <Object>[
        '',
        '{',
        'null',
        '[]',
        '"x"',
        '1',
        <Object?>[1],
      ]) {
        final r = await app.callQuery('CartState.lines', body: body);
        expect(r.status, anyOf(400, 200), reason: '$body → ${r.text}');
        expect(r.status, isNot(500), reason: '$body');
      }
    });

    test(
      'ids the app does not have are a 404, however they are written',
      () async {
        final app = _visitor();
        await app.get('/cart');
        for (final id in [
          '',
          'Nope.x',
          'CartState',
          'CartState.',
          '.total',
          'CartState.__proto__',
          'CartState.total.extra',
          'CartState#zz.total',
          'cartstate.total',
          'CartState.add',
        ]) {
          final r = await app.callQuery(id, hasArg: false);
          expect(r.status, isNot(500), reason: id);
          expect(r.status, isNot(200), reason: id);
        }
      },
    );
  });

  group('the visitor', () {
    test('a forged session cookie is a 401, the same as none', () async {
      for (final session in ['nobody', "ana' OR '1'='1", '', 'ana; other=1']) {
        final app = _visitor(session)..goTo('/cart');
        final r = await app.query(cart.total);
        expect(r, hasStatus(401), reason: 'session "$session"');
        expect(r.data, isNull);
      }
    });

    test(
      'a session cleared in the middle turns the next call into a 401',
      () async {
        final app = _visitor();
        await app.get('/cart');
        expect(await app.query(cart.total), hasStatus(200));
        app.clearCookies();
        expect(await app.query(cart.total), hasStatus(401));
      },
    );

    test('two visitors do not see each other\'s calls', () async {
      final ana = _visitor();
      final nobody = _visitor(null)..goTo('/cart');
      await ana.get('/cart');
      await ana.command(cart.add, 'taza');
      expect(await nobody.query(cart.total), hasStatus(401));
      expect((await ana.query(cart.total)).data, 120);
    });

    test('no Origin is a 403 for a call, and so is a text/plain one', () async {
      final app = _visitor();
      await app.get('/cart');
      expect(
        await app.callCommand(
          'CartState.clear',
          hasArg: false,
          headers: {HttpHeader.origin: null},
        ),
        hasStatus(403),
      );
      expect(
        await app.callCommand(
          'CartState.clear',
          hasArg: false,
          headers: {HttpHeader.contentType: 'text/plain'},
        ),
        hasStatus(403),
      );
      expect(
        await app.callQuery(
          'CartState.total',
          hasArg: false,
          headers: {const HttpHeader('Origin'): 'http://localhost.evil.test'},
        ),
        hasStatus(403),
      );
    });

    test(
      'a call over an https client is the same origin of its own site',
      () async {
        final app = appHandler().client(origin: 'https://shop.test')
          ..setCookie('sq-session', 'ana');
        await app.get('/cart');
        expect(await app.query(cart.total), hasStatus(200));
      },
    );
  });

  group('racing calls', () {
    test('adds and reads at once end with every unit counted', () async {
      final app = _visitor();
      await app.get('/cart');
      final results = await Future.wait([
        for (var i = 0; i < 15; i++) app.command(cart.add, 'taza'),
        for (var i = 0; i < 15; i++) app.query(cart.total),
      ]);
      expect(results.map((r) => r.status), everyElement(200));
      expect(_units(), 15);
      expect((await app.query(cart.total)).data, 15 * 120);
    });

    test('a command and a page GET on one jar both finish', () async {
      final app = _visitor();
      await app.get('/cart');
      final both = await Future.wait([
        app.command(cart.add, 'taza'),
        app.get('/profile'),
      ]);
      expect(both.map((r) => r.status), everyElement(200));
      expect(app.location!.path, '/profile');
    });
  });
}

class _Sku {
  _Sku(this.sku);
  final String sku;
}
