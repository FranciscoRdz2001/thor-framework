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

Future<ThorTestResponse> _get(
  String path, {
  String? session = 'ana',
  Map<HttpHeader, String> headers = const {},
}) => _visitor(session).get(path, headers: headers);

/// The browser's call to command [id] on [path] (or, with [header], to a
/// query: what a call sends under the other header).
Future<ThorTestResponse> _command(
  String path,
  String id, {
  String? session = 'ana',
  Object? body = const <String, Object?>{},
  String? origin = 'http://localhost',
  String type = 'application/json',
  String header = 'x-thor-command',
}) {
  final headers = <HttpHeader, String?>{
    HttpHeader.origin: origin,
    HttpHeader.contentType: type,
  };
  final client = _visitor(session);
  return header == 'x-thor-query'
      ? client.callQuery(id, path: path, body: body, headers: headers)
      : client.callCommand(id, path: path, body: body, headers: headers);
}

Map<String, Object?> _json(ThorTestResponse r) =>
    jsonDecode(r.text) as Map<String, Object?>;

/// The units of [sku] in [login]'s cart (0 when none).
int _units(String login, String sku) =>
    database.select('SELECT qty FROM cart WHERE login = ? AND sku = ?', [
          login,
          sku,
        ]).firstOrNull?['qty']
        as int? ??
    0;

void _put(String login, String sku, int qty) => database.execute(
  'INSERT INTO cart (login, sku, qty) VALUES (?, ?, ?)',
  [login, sku, qty],
);

void main() {
  setUp(() => database.execute('DELETE FROM cart'));

  group('first render', () {
    test('draws the queries, never runs a command', () async {
      _put('ana', 'taza', 2);
      final r = await _get('/cart');
      expect(r.status, 200);
      expect(r.text, contains('Taza × 2'));
      expect(r.text, contains(r'Total: $240'));
      // The page binds the commands' `run`, and nothing ran: same cart.
      expect(r.text, contains(r'CartState.add$run'));
      expect(r.text, contains(r'CartState.clear$run'));
      expect(_units('ana', 'taza'), 2);
      expect(r.text, isNot(contains('payments gateway')));
      expect(r.text, isNot(contains(r'CartState.checkout$error"')));
    });

    test('a GET naming a command draws the page and runs nothing', () async {
      final r = await _get(
        '/cart',
        headers: {const HttpHeader('x-thor-command'): 'CartState.clear'},
      );
      _put('ana', 'pluma', 1);
      final again = await _get(
        '/cart',
        headers: {const HttpHeader('x-thor-command'): 'CartState.clear'},
      );
      expect(r.status, 200);
      expect(again.status, 200);
      expect(again.text, contains('<html'));
      expect(_units('ana', 'pluma'), 1);
    });
  });

  group('what a command refreshes', () {
    Map<String, Object?> queriesOf(ThorTestResponse r) =>
        (_json(r)['queries'] ?? const <String, Object?>{})
            as Map<String, Object?>;

    test('only the queries the browser has on the page', () async {
      _put('ana', 'taza', 1);
      final r = await _command(
        '/cart',
        'CartState.add',
        body: {
          'arg': 'taza',
          'queries': {'CartState.total': null},
        },
      );
      expect(r.status, 200);
      expect(queriesOf(r).keys, ['CartState.total']);
    });

    test(
      'a page with no queries gets none, and the command still ran',
      () async {
        final r = await _command(
          '/cart',
          'CartState.add',
          body: {'arg': 'taza', 'queries': <String, Object?>{}},
        );
        expect(r.status, 200);
        expect(_json(r)['result'], 1);
        expect(_json(r), isNot(contains('queries')));
        expect(_units('ana', 'taza'), 1);
      },
    );

    test('ids the route does not use are ignored, never a 400', () async {
      final r = await _command(
        '/cart',
        'CartState.add',
        body: {
          'arg': 'taza',
          'queries': {
            'ProfileState.orders': 'not a number',
            'AdminState.users': 1,
            'CartState.nope': 1,
            '__proto__': 1,
            'CartState.total': null,
          },
        },
      );
      expect(r.status, 200);
      expect(queriesOf(r).keys, ['CartState.total']);
    });

    test('`invalidates` narrows to the queries it names', () async {
      _put('ana', 'taza', 1);
      final r = await _command(
        '/cart',
        'CartState.recount',
        body: {
          'queries': {'CartState.lines': 2, 'CartState.total': null},
        },
      );
      expect(r.status, 200);
      expect(_json(r)['result'], 120);
      expect(queriesOf(r).keys, ['CartState.total']);
    });

    test(
      '`invalidates` naming a query that is not on the page: none',
      () async {
        _put('ana', 'taza', 1);
        final r = await _command(
          '/cart',
          'CartState.recount',
          body: {
            'queries': {'CartState.lines': 2},
          },
        );
        expect(r.status, 200);
        expect(_json(r)['result'], 120);
        expect(_json(r), isNot(contains('queries')));
        expect(_json(r), isNot(contains('errors')));
      },
    );

    test('a bad argument of a query nobody refreshes is not checked', () async {
      final r = await _command(
        '/cart',
        'CartState.recount',
        body: {
          'queries': {'CartState.lines': 'all', 'CartState.total': null},
        },
      );
      expect(r.status, 200);
      expect(queriesOf(r).keys, ['CartState.total']);
    });
  });

  group('the endpoint', () {
    test('runs, and the page queries come back in the same answer', () async {
      final r = await _command('/cart', 'CartState.add', body: {'arg': 'taza'});
      expect(r.status, 200);
      expect(r.headers['cache-control'], 'no-store');
      final j = _json(r);
      expect(j['result'], 1);
      expect(_units('ana', 'taza'), 1);
      final queries = j['queries']! as Map<String, Object?>;
      expect(
        queries.keys,
        unorderedEquals(['CartState.lines', 'CartState.total']),
      );
      expect(queries['CartState.total'], 120);
      expect(queries['CartState.lines'], [
        {'sku': 'taza', 'name': 'Taza', 'qty': 1, 'price': 120},
      ]);
      expect(j, isNot(contains('errors')));
      // A write: the browser drops what it fetched ahead.
      expect(r.headers['clear-site-data'], contains('prefetchCache'));
    });

    test('refreshes queries with the arguments the browser has', () async {
      for (final sku in ['libreta', 'pluma', 'taza']) {
        _put('ana', sku, 1);
      }
      final shown = await _command(
        '/cart',
        'CartState.add',
        body: {'arg': 'taza'},
      );
      // No argument sent: the query's initial one (2 lines).
      expect(
        (_json(shown)['queries']! as Map)['CartState.lines'],
        hasLength(2),
      );
      final limited = await _command(
        '/cart',
        'CartState.add',
        body: {
          'arg': 'taza',
          'queries': {'CartState.lines': 1},
        },
      );
      expect(
        (_json(limited)['queries']! as Map)['CartState.lines'],
        hasLength(1),
      );
      expect(_units('ana', 'taza'), 3);
    });

    test('a command without an argument, returning nothing', () async {
      _put('ana', 'taza', 4);
      final r = await _command('/cart', 'CartState.clear');
      expect(r.status, 200);
      final j = _json(r);
      expect(j['result'], isNull);
      expect(j['queries'], {
        'CartState.lines': <Object?>[],
        'CartState.total': 0,
      });
      expect(_units('ana', 'taza'), 0);
    });

    test('reads the caller (PageRequest.current): per session', () async {
      await _command(
        '/cart',
        'CartState.add',
        session: 'beto',
        body: {'arg': 'pluma'},
      );
      expect(_units('beto', 'pluma'), 1);
      expect(_units('ana', 'pluma'), 0);
    });

    test('without a session: 401 with the redirect, nothing runs', () async {
      for (final session in [null, 'eve']) {
        final r = await _command(
          '/cart',
          'CartState.add',
          session: session,
          body: {'arg': 'taza'},
        );
        expect(r.status, 401);
        expect(_json(r), {'error': 'Sign in again', 'redirect': '/login'});
      }
      expect(database.select('SELECT COUNT(*) AS n FROM cart').single['n'], 0);
    });

    test('only on a route whose page uses the state', () async {
      for (final path in ['/', '/profile', '/login']) {
        final r = await _command(path, 'CartState.add', body: {'arg': 'taza'});
        expect(r.status, 404, reason: path);
      }
      expect(_units('ana', 'taza'), 0);
    });

    test('ids: a query is not a command, a command is not a query', () async {
      expect((await _command('/cart', 'CartState.total')).status, 404);
      expect((await _command('/cart', 'CartState.nope')).status, 404);
      expect((await _command('/cart', 'CartState.adding')).status, 404);
      final asQuery = await _command(
        '/cart',
        'CartState.clear',
        header: 'x-thor-query',
      );
      expect(asQuery.status, 404);
      _put('ana', 'taza', 1);
      expect(
        (await _command(
          '/cart',
          'CartState.clear',
          header: 'x-thor-query',
        )).status,
        404,
      );
      expect(_units('ana', 'taza'), 1);
    });

    test('cross-site calls are rejected, nothing runs', () async {
      for (final r in [
        await _command(
          '/cart',
          'CartState.add',
          origin: 'https://evil.test',
          body: {'arg': 'taza'},
        ),
        await _command(
          '/cart',
          'CartState.add',
          origin: null,
          body: {'arg': 'taza'},
        ),
        await _command(
          '/cart',
          'CartState.add',
          type: 'text/plain',
          body: '{"arg":"taza"}',
        ),
      ]) {
        expect(r.status, 403);
        expect(_json(r), {'error': 'Cross-site command is forbidden'});
      }
      expect(_units('ana', 'taza'), 0);
    });

    test('a bad argument is a 400 and nothing runs', () async {
      for (final arg in [1, null, <String>[], true]) {
        final r = await _command('/cart', 'CartState.add', body: {'arg': arg});
        expect(r.status, 400, reason: '$arg');
      }
      // A bad argument of a query to refresh: checked before the command.
      final badQuery = await _command(
        '/cart',
        'CartState.add',
        body: {
          'arg': 'taza',
          'queries': {'CartState.lines': 'all'},
        },
      );
      expect(badQuery.status, 400);
      final notMap = await _command(
        '/cart',
        'CartState.add',
        body: {'arg': 'taza', 'queries': 3},
      );
      expect(notMap.status, 400);
      expect((await _command('/cart', 'CartState.add', body: '{')).status, 400);
      expect(_units('ana', 'taza'), 0);
    });

    test('an HttpError keeps its status and message, no refresh', () async {
      final out = await _command(
        '/cart',
        'CartState.add',
        body: {'arg': 'termo'},
      );
      expect(out.status, 409);
      expect(_json(out), {'error': 'Ya no hay existencias.'});
      final unknown = await _command(
        '/cart',
        'CartState.add',
        body: {'arg': 'nada'},
      );
      expect(unknown.status, 404);
      expect(_json(unknown), {'error': 'Ese producto no existe.'});
    });

    test('any other error is a generic 500, details never leave', () async {
      final r = await _command('/cart', 'CartState.checkout');
      expect(r.status, 500);
      expect(_json(r), {'error': 'Something went wrong'});
    });
  });
}
