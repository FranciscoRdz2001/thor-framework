import 'dart:convert';

import 'package:server_query/app.dart';
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';
import 'package:thor_ui/router.dart';

final _handler = appHandler();

/// A visitor signed in as [session] (a guest when null).
ThorTestClient _visitor(String? session) {
  final client = _handler.client();
  if (session != null) client.setCookie('sq-session', session);
  return client;
}

Future<ThorTestResponse> _get(String path, {String? session}) =>
    _visitor(session).get(path);

/// The browser's call to query [id] on [path].
Future<ThorTestResponse> _query(
  String path,
  String id, {
  String? session = 'ana',
  Object? body = const <String, Object?>{},
  String? origin = 'http://localhost',
  String type = 'application/json',
}) => _visitor(session).callQuery(
  id,
  path: path,
  body: body,
  headers: {HttpHeader.origin: origin, HttpHeader.contentType: type},
);

Object? _json(ThorTestResponse r) => r.json;

void main() {
  group('first render', () {
    test('the HTML already has the data, and #thor-state carries it', () async {
      final r = await _get('/profile', session: 'ana');
      expect(r.status, 200);
      expect(r.text, contains('Ana López'));
      expect(r.text, contains('Taza · \$120'));
      expect(r.text, contains('"ProfileState.info\$data":{"name":"Ana López"'));
      expect(r.text, contains('"ProfileState.orders\$data":[{"id":1'));
      // Browser state starts as the code says: not in the JSON.
      expect(r.text, isNot(contains('ProfileState.editing')));
    });

    test('#thor-state names the queries this page drew', () async {
      final r = await _get('/profile', session: 'ana');
      final state = RegExp(
        r'id="thor-state"[^>]*>\s*(\{.*?\})\s*</script>',
      ).firstMatch(r.text)!.group(1)!;
      final ids = (jsonDecode(state) as Map<String, Object?>)['!q']! as List;
      expect(
        ids,
        unorderedEquals([
          'ProfileState.info',
          'ProfileState.orders',
          'ProfileState.ledger',
        ]),
      );
      // A page without queries carries no list.
      final login = await _get('/login');
      expect(login.text, isNot(contains('"!q"')));
    });

    test('a failing query draws its safe message; the page is a 200', () async {
      final r = await _get('/profile', session: 'ana');
      expect(r.status, 200);
      expect(
        r.text,
        contains('"ProfileState.ledger\$error":"Something went wrong"'),
      );
      expect(r.text, isNot(contains('ledger table is locked')));
    });

    test('runs under the session: another user sees their own data', () async {
      final r = await _get('/profile', session: 'beto');
      expect(r.text, contains('Beto Ruiz'));
      expect(r.text, isNot(contains('Taza')));
    });

    test('a page without queries draws once and is unchanged', () async {
      final r = await _get('/login');
      expect(r.status, 200);
      expect(r.text, isNot(contains('\$data')));
    });
  });

  group('the endpoint', () {
    test('answers JSON through the page route and its middleware', () async {
      final r = await _query(
        '/profile',
        'ProfileState.orders',
        body: {'arg': 1},
      );
      expect(r.status, 200);
      expect(r.headers['cache-control'], 'no-store');
      final data = (_json(r)! as Map)['data'] as List;
      expect(data.map((o) => (o as Map)['item']), [
        'Mochila',
        'Lámpara',
        'Termo',
      ]);
      // A read: no cache clear for speculations.
      expect(
        r.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('clear-site-data')),
      );
    });

    test('reads the request (PageRequest.current) of the caller', () async {
      final r = await _query('/profile', 'ProfileState.info', session: 'beto');
      expect(((_json(r)! as Map)['data'] as Map)['name'], 'Beto Ruiz');
    });

    test('without a session: 401 with the middleware redirect', () async {
      final r = await _query('/profile', 'ProfileState.info', session: null);
      expect(r.status, 401);
      expect(_json(r), {'error': 'Sign in again', 'redirect': '/login'});
      final forged = await _query(
        '/profile',
        'ProfileState.info',
        session: 'eve',
      );
      expect(forged.status, 401);
    });

    test('only on a route whose page uses the state', () async {
      // `/` is public and draws StatsState only: the profile query can't be
      // reached through it, with or without a session.
      final r = await _query('/', 'ProfileState.info');
      expect(r.status, 404);
      expect(r.text, isNot(contains('Ana')));
      final ok = await _query('/', 'StatsState.orders', session: null);
      expect(ok.status, 200);
      expect(_json(ok), {'data': 7});
    });

    test('an unknown query is a 404', () async {
      expect((await _query('/profile', 'ProfileState.nope')).status, 404);
      expect((await _query('/profile', 'ProfileState.editing')).status, 404);
      expect((await _query('/profile', 'x')).status, 404);
    });

    test('cross-site calls are rejected before the middleware', () async {
      for (final r in [
        await _query(
          '/profile',
          'ProfileState.info',
          origin: 'https://evil.test',
        ),
        await _query('/profile', 'ProfileState.info', origin: null),
        await _query(
          '/profile',
          'ProfileState.info',
          type: 'text/plain',
          body: '{}',
        ),
      ]) {
        expect(r.status, 403);
        expect(_json(r), {'error': 'Cross-site query is forbidden'});
      }
    });

    test('a bad argument is a 400 and the function never runs', () async {
      for (final arg in ['x', 1.5, null, <int>[]]) {
        final r = await _query(
          '/profile',
          'ProfileState.orders',
          body: {'arg': arg},
        );
        expect(r.status, 400, reason: '$arg');
      }
      final notJson = await _query(
        '/profile',
        'ProfileState.orders',
        body: '{',
      );
      expect(notJson.status, 400);
      final notMap = await _query(
        '/profile',
        'ProfileState.orders',
        body: '[1]',
      );
      expect(notMap.status, 400);
    });

    test('an HttpError keeps its status and message', () async {
      final r = await _query(
        '/profile',
        'ProfileState.orders',
        body: {'arg': -1},
      );
      expect(r.status, 400);
      expect(_json(r), {'error': 'Esa página no existe.'});
    });

    test('any other error is a generic 500, details never leave', () async {
      final r = await _query('/profile', 'ProfileState.ledger');
      expect(r.status, 500);
      expect(_json(r), {'error': 'Something went wrong'});
      expect(
        (_json(r)! as Map).containsKey('detail'),
        isFalse,
        reason: 'a release server never sends the exception',
      );
    });

    test('under thor dev the first line of the detail says why the page shows '
        'only the generic message (THOR-P034)', () async {
      final was = ThorDev.enabled;
      ThorDev.enabled = true;
      addTearDown(() => ThorDev.enabled = was);
      final r = await _query('/profile', 'ProfileState.ledger');
      expect(r.status, 500);
      final body = _json(r)! as Map;
      expect(body['error'], 'Something went wrong');
      final first = (body['detail']! as String).split('\n').first;
      expect(first, contains('THOR-P034'));
      expect(first, contains('HttpError'));
      expect(first, contains('StateError'));
      expect(first, contains('locked'));
    });
  });

  test('outside a query, PageRequest.current is THOR-P019', () {
    expect(
      () => PageRequest.current,
      throwsA(
        isA<StateError>().having((e) => '$e', 'message', contains('THOR-P019')),
      ),
    );
  });
}
