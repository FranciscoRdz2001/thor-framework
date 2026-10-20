// `app.query(state.field)` and `app.command(state.field)`: what the browser
// does on `refresh` and `run`, without writing a header, an id or a body.
import 'package:server_query/app.dart';
import 'package:server_query/core/db/database.dart';
import 'package:server_query/modules/cart/state/cart_state.dart';
import 'package:server_query/modules/profile/state/profile_state.dart';
import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';
import 'package:thor_test/thor_test.dart';

ThorTestClient _visitor([String? session = 'ana']) {
  final app = appHandler().client();
  if (session != null) app.setCookie('sq-session', session);
  return app;
}

void _put(String sku, int qty) => database.execute(
  'INSERT INTO cart (login, sku, qty) VALUES (?, ?, ?)',
  ['ana', sku, qty],
);

void main() {
  setUp(() => database.execute('DELETE FROM cart'));

  group('query', () {
    test('asks the page the client is on, with the visitor session', () async {
      _put('taza', 2);
      final app = _visitor();
      await app.get('/cart');
      final total = await app.query(cart.total);
      expect(total, hasStatus(200));
      expect(total.data, 240);
    });

    test('queryWith takes its argument, a bad one is a 400', () async {
      final app = _visitor();
      await app.get('/profile');
      final page = await app.query(profile.orders, 1);
      expect(page.data, isA<List<Object?>>());
      expect((page.data! as List).first, containsPair('item', 'Mochila'));
      expect(await app.query(profile.orders, -1), hasStatus(400));
      // What the type would not let through: straight to the id.
      expect(
        await app.callQuery('ProfileState.orders', arg: 'x'),
        hasStatus(400),
      );
    });

    test('a query the page does not use is a 404, as in the browser', () async {
      final app = _visitor(null);
      await app.get('/');
      expect(await app.query(profile.info), hasStatus(404));
    });

    test('a guest gets the 401 with the redirect, never the data', () async {
      final app = _visitor(null)..goTo('/profile');
      final r = await app.query(profile.info);
      expect(r, hasStatus(401));
      expect(r.error, 'Sign in again');
      expect(r.data, isNull);
    });

    test('a failing query is a 500 that keeps its details', () async {
      final app = _visitor();
      await app.get('/profile');
      final r = await app.query(profile.ledger);
      expect(r, hasStatus(500));
      expect(r.text, isNot(contains('locked')));
    });

    test('with no page in sight it says what to do', () {
      expect(
        () => _visitor().query(cart.total),
        throwsA(
          isA<StateError>().having((e) => e.message, 'm', contains('get()')),
        ),
      );
    });

    test('a query that is not a field of a state is an ArgumentError', () {
      final orphan = query(() => 1);
      expect(() => _visitor().query(orphan), throwsArgumentError);
    });

    test('concurrent calls of one visitor keep their own answers', () async {
      final app = _visitor();
      await app.get('/profile');
      final pages = await Future.wait([
        for (var i = 0; i < 12; i++) app.query(profile.orders, i % 2),
      ]);
      for (final p in pages) {
        expect(p, hasStatus(200));
      }
      expect(pages[0].data, pages[2].data);
      expect(pages[0].data, isNot(pages[1].data));
    });
  });

  group('command', () {
    test('runs on the server and brings the queries it refreshed', () async {
      final app = _visitor();
      await app.get('/cart');
      final r = await app.command(cart.add, 'taza');
      expect(r, hasStatus(200));
      expect(r.result, 1);
      expect(
        r.queries.keys,
        containsAll(['CartState.total', 'CartState.lines']),
      );
      expect(r.queries['CartState.total'], 120);
      // The change is there for the next read.
      expect((await app.query(cart.total)).data, 120);
    });

    test('invalidates: only the queries it names come back', () async {
      _put('taza', 1);
      final app = _visitor();
      await app.get('/cart');
      final r = await app.command(cart.recount);
      expect(r.queries.keys, ['CartState.total']);
    });

    test(
      'callCommand(queries:) names what the browser has on its page',
      () async {
        final app = _visitor();
        await app.get('/cart');
        final r = await app.callCommand(
          app.idOf(cart.clear),
          hasArg: false,
          queries: {'CartState.total': null},
        );
        expect(r.queries.keys, ['CartState.total']);
      },
    );

    test('a failing command is an error and changes no query', () async {
      final app = _visitor();
      await app.get('/cart');
      final r = await app.command(cart.checkout);
      expect(r, hasStatus(500));
      expect(r.queries, isEmpty);
    });

    test('a guest cannot run it, and a made-up sku is refused', () async {
      final guest = _visitor(null)..goTo('/cart');
      final r = await guest.command(cart.add, 'taza');
      expect(r, hasStatus(401));
      expect(_units('taza'), 0);
      final app = _visitor();
      await app.get('/cart');
      expect(await app.command(cart.add, 'nope'), hasStatus(anyOf(400, 404)));
    });

    test('a foreign origin is a 403 before anything runs', () async {
      _put('taza', 3);
      final app = _visitor();
      await app.get('/cart');
      final r = await app.callCommand(
        'CartState.clear',
        hasArg: false,
        headers: {HttpHeader.origin: 'https://evil.test'},
      );
      expect(r, hasStatus(403));
      expect(_units('taza'), 3);
    });
  });
}

int _units(String sku) =>
    database.select('SELECT qty FROM cart WHERE login = ? AND sku = ?', [
          'ana',
          sku,
        ]).firstOrNull?['qty']
        as int? ??
    0;
