// Hostile bodies for a command's `queries` : ids
// that are not on the route, a crowd of them, prototype names, values of the
// wrong shape, giant arguments. Whatever the browser sends, the server
// answers 200 or 400, never 500, and refreshes only what the route uses and
// the browser named.
import 'dart:convert';

import 'package:server_query/app.dart';
import 'package:server_query/core/db/database.dart';
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';

final _handler = appHandler();

/// A visitor signed in as [session] (a guest when null).
ThorTestClient _visitor(String? session) {
  final client = _handler.client();
  if (session != null) client.setCookie('sq-session', session);
  return client;
}

Future<ThorTestResponse> _command(
  String path,
  String id,
  Object? body, {
  String? session = 'ana',
}) => _visitor(session).callCommand(id, path: path, body: body);

Future<ThorTestResponse> _get(String path, {String? session}) =>
    _visitor(session).get(path);

Map<String, Object?> _json(ThorTestResponse r) =>
    jsonDecode(r.text) as Map<String, Object?>;

Iterable<String> _queriesOf(ThorTestResponse r) =>
    ((_json(r)['queries'] ?? const <String, Object?>{}) as Map).keys.cast();

int _units(String sku) =>
    database.select('SELECT qty FROM cart WHERE login = ? AND sku = ?', [
          'ana',
          sku,
        ]).firstOrNull?['qty']
        as int? ??
    0;

void main() {
  setUp(() => database.execute('DELETE FROM cart'));

  group('a hostile `queries`', () {
    test('10k ids, only the ones of the route come back, and fast', () async {
      final queries = <String, Object?>{
        for (var i = 0; i < 10000; i++) 'Made$i.up': i,
        'CartState.total': null,
        'ProfileState.orders': 0,
        'AdminState.users': 0,
      };
      final t = Stopwatch()..start();
      final r = await _command('/cart', 'CartState.clear', {
        'queries': queries,
      });
      expect(r.status, 200);
      expect(_queriesOf(r), unorderedEquals(['CartState.total']));
      expect(t.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('prototype names are plain, unknown keys', () async {
      final r = await _command(
        '/cart',
        'CartState.clear',
        '{"queries":{"__proto__":{"a":1},"constructor":1,"toString":null,'
            '"hasOwnProperty":[],"CartState.total":null}}',
      );
      expect(r.status, 200);
      expect(_queriesOf(r), ['CartState.total']);
    });

    test(
      'a query with no argument given a value of any shape: never a 500',
      () async {
        for (final v in [
          1,
          'x',
          true,
          <Object?>[],
          <String, Object?>{
            'a': <Object?>[1],
          },
          'y' * 100000,
        ]) {
          final r = await _command('/cart', 'CartState.add', {
            'arg': 'taza',
            'queries': {'CartState.total': v},
          });
          expect(r.status, anyOf(200, 400), reason: '${v.runtimeType}');
        }
      },
    );

    test(
      'every shape of `queries` that is not an object is a 400 or none',
      () async {
        for (final q in [
          <Object?>[],
          <Object?>['CartState.total'],
          'CartState.total',
          0,
          true,
        ]) {
          final r = await _command('/cart', 'CartState.add', {
            'arg': 'taza',
            'queries': q,
          });
          expect(r.status, 400, reason: '$q');
        }
        // Nothing ran for any of them.
        expect(_units('taza'), 0);
        final none = await _command('/cart', 'CartState.add', {
          'arg': 'taza',
          'queries': null,
        });
        expect(none.status, 200);
        expect(
          _queriesOf(none),
          unorderedEquals(['CartState.lines', 'CartState.total']),
        );
      },
    );

    test(
      'a giant argument of a query to refresh is a 400, nothing ran',
      () async {
        final r = await _command('/cart', 'CartState.add', {
          'arg': 'taza',
          'queries': {'CartState.lines': 'x' * 500000},
        });
        expect(r.status, 400);
        expect(_units('taza'), 0);
      },
    );

    test('a huge int for a limit refreshes without breaking', () async {
      for (final n in [-1, 0, 9007199254740991, 1e300]) {
        final r = await _command('/cart', 'CartState.add', {
          'arg': 'taza',
          'queries': {'CartState.lines': n},
        });
        expect(r.status, anyOf(200, 400), reason: '$n');
      }
    });

    test('the same id under another route is never refreshed', () async {
      // /profile's page uses ProfileState; the cart command names it.
      final r = await _command('/cart', 'CartState.add', {
        'arg': 'taza',
        'queries': {
          'ProfileState.orders': 0,
          'CartState.total': null,
          'CartState#other.total': null,
        },
      });
      expect(r.status, 200);
      expect(_queriesOf(r), ['CartState.total']);
    });

    test(
      'a command of another route can not be named, queries or not',
      () async {
        final r = await _command('/', 'CartState.add', {
          'arg': 'taza',
          'queries': {'CartState.total': null},
        });
        expect(r.status, 404);
        expect(_units('taza'), 0);
      },
    );
  });

  group('the page names what it drew (`!q`)', () {
    Map<String, Object?> stateOf(ThorTestResponse r) {
      final m = RegExp(
        r'id="thor-state"[^>]*>\s*(\{.*?\})\s*</script>',
      ).firstMatch(r.text);
      return m == null
          ? const {}
          : jsonDecode(m.group(1)!) as Map<String, Object?>;
    }

    test('lists the queries of the page and no other', () async {
      final r = await _get('/cart', session: 'ana');
      expect(stateOf(r)['!q'], ['CartState.lines', 'CartState.total']);
      // Ids are names, never values: nothing of the visitor's data in them.
      expect(stateOf(r)['!q'].toString(), isNot(contains('taza')));
    });

    test(
      'a page without queries or commands ships neither `!q` nor `!m`',
      () async {
        final r = await _get('/login');
        expect(r.status, 200);
        expect(r.text, isNot(contains('"!q"')));
        expect(r.text, isNot(contains('"!m"')));
      },
    );
  });
}
