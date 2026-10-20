// Edges of query()/command() that query_test and command_test do not cover:
// made-up ids, concurrent requests from two sessions, odd arguments and a
// command with a misspelled refresh query.
import 'dart:convert';

import 'package:server_query/app.dart';
import 'package:server_query/core/db/database.dart';
import 'package:test/test.dart';
import 'package:thor_ui/router.dart';

final _handler = appHandler();

Future<ThorResponse> _get(String path, {String? session = 'ana'}) =>
    _handler.handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://localhost$path'),
        headers: {
          HttpHeader.host: 'localhost',
          if (session != null) HttpHeader.cookie: 'sq-session=$session',
        },
      ),
    );

Future<ThorResponse> _call(
  String path,
  String header,
  String id, {
  String? session = 'ana',
  Object? body = const <String, Object?>{},
  HttpMethod method = HttpMethod.post,
}) => _handler.handle(
  PageRequest(
    method: method,
    uri: Uri.parse('http://localhost$path'),
    headers: {
      HttpHeader.host: 'localhost',
      HttpHeader(header): id,
      HttpHeader.contentType: 'application/json',
      HttpHeader.origin: 'http://localhost',
      if (session != null) HttpHeader.cookie: 'sq-session=$session',
    },
    body: Stream.value(utf8.encode(body is String ? body : jsonEncode(body))),
  ),
);

Future<ThorResponse> _query(String path, String id, {Object? body}) =>
    _call(path, 'x-thor-query', id, body: body ?? const <String, Object?>{});

Future<ThorResponse> _command(
  String path,
  String id, {
  Object? body,
  String? session = 'ana',
}) => _call(
  path,
  'x-thor-command',
  id,
  session: session,
  body: body ?? const <String, Object?>{},
);

int _visits(String login) =>
    database.select('SELECT visits FROM users WHERE login = ?', [
          login,
        ]).single['visits']
        as int;

int _units(String login, String sku) =>
    database.select('SELECT qty FROM cart WHERE login = ? AND sku = ?', [
          login,
          sku,
        ]).firstOrNull?['qty']
        as int? ??
    0;

Map<String, Object?> _json(ThorResponse r) =>
    jsonDecode(r.text) as Map<String, Object?>;

void main() {
  setUp(() => database.execute('DELETE FROM cart'));

  group('ids', () {
    test('made-up ids do not draw the page again each time', () async {
      // Learn the route once (a real call draws it if needed).
      await _query('/profile', 'ProfileState.orders', body: {'arg': 0});
      final before = _visits('ana');
      for (var i = 0; i < 50; i++) {
        expect((await _query('/profile', 'ProfileState.nope$i')).status, 404);
      }
      // The same id again, many times: never drawn again for it.
      for (var i = 0; i < 20; i++) {
        expect((await _query('/profile', 'ProfileState.nope0')).status, 404);
      }
      // Each draw runs `info`, which counts a visit: an id that is no query
      // or command of the app (not in the build's list) never draws the
      // page.
      expect(_visits('ana') - before, 0);
    });

    test('a real id of another route draws the page once at most', () async {
      await _query('/profile', 'ProfileState.orders', body: {'arg': 0});
      final before = _visits('ana');
      // `StatsState.orders` exists, but `/profile` doesn't use it.
      for (var i = 0; i < 20; i++) {
        expect((await _query('/profile', 'StatsState.orders')).status, 404);
      }
      expect(_visits('ana') - before, lessThanOrEqualTo(1));
    });

    test('a key on a state without keys is a 404', () async {
      expect((await _command('/cart', 'CartState#x.add')).status, 404);
      expect((await _query('/profile', 'ProfileState#x.info')).status, 404);
    });

    test('a HEAD naming a query answers no data', () async {
      final r = await _call(
        '/profile',
        'x-thor-query',
        'ProfileState.info',
        method: HttpMethod.head,
      );
      expect(r.text, isNot(contains('"data"')));
    });
  });

  group('arguments', () {
    test('a queryWith without arg is a 400', () async {
      expect((await _query('/profile', 'ProfileState.orders')).status, 400);
    });

    test('a string for an int is a 400', () async {
      final r = await _query(
        '/profile',
        'ProfileState.orders',
        body: {'arg': '1'},
      );
      expect(r.status, 400);
    });

    test(
      'an arg for a query without one is ignored or a 400, never a 500',
      () async {
        final r = await _query(
          '/profile',
          'ProfileState.info',
          body: {'arg': 3},
        );
        expect(r.status, anyOf(200, 400));
      },
    );

    test('an arg for a command without one never runs it wrongly', () async {
      database.execute(
        "INSERT INTO cart (login, sku, qty) VALUES ('ana', 'taza', 2)",
      );
      final r = await _command('/cart', 'CartState.clear', body: {'arg': 'x'});
      expect(r.status, anyOf(200, 400));
    });

    test('a bad refresh argument stops the command before it runs', () async {
      final r = await _command(
        '/cart',
        'CartState.add',
        body: {
          'arg': 'taza',
          'queries': {'CartState.lines': 'many'},
        },
      );
      expect(r.status, 400);
      expect(_units('ana', 'taza'), 0);
    });

    test('a JSON body that is not an object is a 400', () async {
      for (final body in ['[]', '"x"', '1', 'null', '']) {
        final r = await _query('/profile', 'ProfileState.info', body: body);
        expect(r.status, 400, reason: 'body $body');
      }
    });
  });

  group('concurrency', () {
    test('two sessions drawing at once each see their own data', () async {
      final rs = await Future.wait([
        for (var i = 0; i < 10; i++)
          _get('/profile', session: i.isEven ? 'ana' : 'beto'),
      ]);
      for (final (i, r) in rs.indexed) {
        expect(r.status, 200);
        final mine = i.isEven ? 'Ana López' : 'Beto Ruiz';
        final other = i.isEven ? 'Beto Ruiz' : 'Ana López';
        expect(r.text, contains(mine), reason: 'request $i');
        expect(r.text, isNot(contains(other)), reason: 'request $i');
      }
    });

    test('queries of two sessions at once answer each caller', () async {
      final rs = await Future.wait([
        for (var i = 0; i < 10; i++)
          _call(
            '/profile',
            'x-thor-query',
            'ProfileState.info',
            session: i.isEven ? 'ana' : 'beto',
          ),
      ]);
      for (final (i, r) in rs.indexed) {
        final name = (_json(r)['data']! as Map)['name'];
        expect(name, i.isEven ? 'Ana López' : 'Beto Ruiz', reason: '$i');
      }
    });

    test('commands of two sessions at once refresh each cart', () async {
      final rs = await Future.wait([
        for (var i = 0; i < 6; i++)
          _command(
            '/cart',
            'CartState.add',
            session: i.isEven ? 'ana' : 'beto',
            body: {'arg': i.isEven ? 'taza' : 'libreta'},
          ),
      ]);
      expect(_units('ana', 'taza'), 3);
      expect(_units('beto', 'libreta'), 3);
      expect(_units('ana', 'libreta'), 0);
      for (final (i, r) in rs.indexed) {
        final lines = (_json(r)['queries']! as Map)['CartState.lines']! as List;
        final skus = lines.map((l) => (l! as Map)['sku']).toSet();
        expect(skus, {i.isEven ? 'taza' : 'libreta'}, reason: 'answer $i');
      }
    });
  });
}
