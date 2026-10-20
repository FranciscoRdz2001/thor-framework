// The texts of the errors of server calls and their kinds: the
// app translates them once (`ThorApp(serverMessages:)`), the server writes
// its answers with them and puts the browser's in the page.
import 'dart:convert';

import 'package:server_query/core/repositories/lab_repository.dart';
import 'package:server_query/router.dart';
import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

const _es = ServerMessages(
  network: 'Sin conexión',
  timeout: 'El servidor tardó demasiado',
  aborted: 'Se canceló la petición',
  generic: 'Algo salió mal',
  signIn: 'Inicia sesión otra vez',
  badRequest: 'Petición inválida',
  notFound: 'No existe',
  httpError: 'Error {status} del servidor',
);

RouteHandler<Widget> _handlerWith(
  ServerMessages messages, {
  Duration? callTimeout,
}) {
  final app = callTimeout == null
      ? ThorApp.router(routerConfig: router, serverMessages: messages)
      : ThorApp.router(
          routerConfig: router,
          serverMessages: messages,
          callTimeout: callTimeout,
        );
  return RouteHandler(
    routes: app.routes,
    renderer: WidgetRenderer.router(app, locale: const Locale('es')),
  );
}

final _handler = _handlerWith(_es);

Future<ThorResponse> _get(
  String path, {
  String? session,
  RouteHandler<Widget>? handler,
}) => (handler ?? _handler).handle(
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
  String? session,
  Object? body = const <String, Object?>{},
  RouteHandler<Widget>? handler,
}) => (handler ?? _handler).handle(
  PageRequest(
    method: HttpMethod.post,
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

Future<ThorResponse> _command(
  String path,
  String id, {
  String? session,
  Object? body = const <String, Object?>{},
  RouteHandler<Widget>? handler,
}) => _call(
  path,
  'x-thor-command',
  id,
  session: session,
  body: body,
  handler: handler,
);

Map<String, Object?> _json(ThorResponse r) =>
    jsonDecode(r.text) as Map<String, Object?>;

/// The page's `#thor-state` as a map.
Map<String, Object?> _state(ThorResponse r) {
  final m = RegExp(
    r'id="thor-state"[^>]*>\s*(\{.*?\})\s*</script>',
  ).firstMatch(r.text);
  return m == null ? const {} : jsonDecode(m.group(1)!) as Map<String, Object?>;
}

void main() {
  setUp(labRepository.reset);

  group('the answers the server writes', () {
    test('a missing session says sign in, in the app\'s words', () async {
      final q = await _call('/cart', 'x-thor-query', 'CartState.total');
      final c = await _command('/cart', 'CartState.clear');
      for (final r in [q, c]) {
        expect(r.status, 401);
        expect(_json(r), {
          'error': 'Inicia sesión otra vez',
          'redirect': '/login',
        });
      }
    });

    test('a body it can\'t read, an id it doesn\'t know', () async {
      for (final body in ['{', '[1]']) {
        final r = await _command('/lab', 'LabState.reset', body: body);
        expect(r.status, 400, reason: body);
        expect(_json(r), {'error': 'Petición inválida'});
      }
      final badQueries = await _command(
        '/lab',
        'LabState.reset',
        body: {'queries': 3},
      );
      expect(_json(badQueries), {'error': 'Petición inválida'});
      final unknown = await _command('/lab', 'LabState.nope');
      expect(unknown.status, 404);
      expect(_json(unknown), {'error': 'No existe'});
      final badArg = await _call(
        '/lab',
        'x-thor-query',
        'LabState.slow',
        body: {'arg': 'x'},
      );
      expect(badArg.status, 400);
      expect(_json(badArg), {'error': 'Petición inválida'});
    });

    test('an unexpected failure is generic; details never leave', () async {
      final r = await _call('/lab', 'x-thor-query', 'LabState.broken');
      expect(r.status, 500);
      expect(_json(r), {'error': 'Algo salió mal'});
    });

    test('an HttpError keeps its message, or gets the status one', () async {
      final own = await _call('/lab', 'x-thor-query', 'LabState.denied');
      expect(own.status, 403);
      expect(_json(own), {'error': 'Solo para administradores.'});
      final bare = await _call('/lab', 'x-thor-query', 'LabState.plain');
      expect(bare.status, 429);
      expect(_json(bare), {'error': 'Error 429 del servidor'});
      final cmd = await _command('/lab', 'LabState.throttle');
      expect(cmd.status, 429);
      expect(_json(cmd), {'error': 'Error 429 del servidor'});
    });

    test('the defaults are English', () async {
      final r = await _call(
        '/lab',
        'x-thor-query',
        'LabState.broken',
        handler: _handlerWith(const ServerMessages()),
      );
      expect(_json(r), {'error': 'Something went wrong'});
      final bare = await _call(
        '/lab',
        'x-thor-query',
        'LabState.plain',
        handler: _handlerWith(const ServerMessages()),
      );
      expect(_json(bare), {'error': 'Error 429'});
    });

    test(
      'a query that failed inside a command answer: message and kind',
      () async {
        final r = await _command('/lab', 'LabState.reset');
        expect(r.status, 200);
        final j = _json(r);
        expect(j['errors'], {
          'LabState.denied': 'Solo para administradores.',
          'LabState.broken': 'Algo salió mal',
          'LabState.plain': 'Error 429 del servidor',
        });
        expect(j['kinds'], {
          'LabState.denied': 'forbidden',
          'LabState.broken': 'server',
          'LabState.plain': 'client',
        });
        expect((j['queries']! as Map).keys, ['LabState.rows', 'LabState.slow']);
      },
    );

    test('a command that invalidates a good query sends no errors', () async {
      final r = await _command(
        '/lab',
        'LabState.remove',
        body: {
          'arg': 'a',
          'queries': {
            'LabState.rows': null,
            'LabState.slow': 0,
            'LabState.denied': null,
          },
        },
      );
      final j = _json(r);
      expect(j['result'], 'a');
      expect((j['queries']! as Map)['LabState.rows'], ['b', 'c', 'd']);
      expect(j, isNot(contains('errors')));
      expect(j, isNot(contains('kinds')));
    });
  });

  group('the page carries the browser\'s texts', () {
    test('#thor-state has them where the page has server calls', () async {
      final r = await _get('/lab');
      expect(_state(r)['!m'], {
        'network': 'Sin conexión',
        'timeout': 'El servidor tardó demasiado',
        'aborted': 'Se canceló la petición',
        'generic': 'Algo salió mal',
      });
      final home = await _get('/');
      expect(_state(home)['!m'], isA<Map<String, Object?>>());
      final login = await _get('/login');
      expect(_state(login), isNot(contains('!m')));
      expect(login.text, isNot(contains('Sin conexión')));
    });

    test('a failed first paint has its message and its kind', () async {
      final state = _state(await _get('/lab'));
      expect(state['LabState.denied\$error'], 'Solo para administradores.');
      expect(state['LabState.denied\$errorKind'], 'forbidden');
      expect(state['LabState.broken\$error'], 'Algo salió mal');
      expect(state['LabState.broken\$errorKind'], 'server');
      expect(state['LabState.plain\$error'], 'Error 429 del servidor');
      expect(state['LabState.plain\$errorKind'], 'client');
      // Nothing failed: no kind in the page.
      expect(state, isNot(contains('LabState.rows\$errorKind')));
    });

    test('a text can\'t close the script', () async {
      final r = await _get(
        '/lab',
        handler: _handlerWith(
          const ServerMessages(network: '</script><script>alert(1)</script>'),
        ),
      );
      expect(r.text, isNot(contains('</script><script>alert(1)')));
      expect(_state(r)['!m'], containsPair('network', contains('alert(1)')));
    });

    test('the default timeout of a call (30 s) sends nothing', () async {
      final r = await _get('/lab');
      expect(_state(r), isNot(contains('!t')));
    });

    test(
      '`ThorApp(callTimeout:)` reaches the page in ms; zero is none',
      () async {
        final slow = await _get(
          '/lab',
          handler: _handlerWith(_es, callTimeout: const Duration(seconds: 90)),
        );
        expect(_state(slow)['!t'], 90000);
        final none = await _get(
          '/lab',
          handler: _handlerWith(_es, callTimeout: Duration.zero),
        );
        expect(_state(none)['!t'], 0);
        // Only where the page has calls.
        final login = await _get(
          '/login',
          handler: _handlerWith(_es, callTimeout: Duration.zero),
        );
        expect(_state(login), isNot(contains('!t')));
      },
    );

    test('a callTimeout under a millisecond is not "none"', () async {
      final r = await _get(
        '/lab',
        handler: _handlerWith(
          _es,
          callTimeout: const Duration(microseconds: 500),
        ),
      );
      expect(_state(r)['!t'], 1);
    });

    test('the extremes of callTimeout stay inside setTimeout', () async {
      final big = await _get(
        '/lab',
        handler: _handlerWith(_es, callTimeout: const Duration(days: 400)),
      );
      expect(_state(big)['!t'], 2147483647);
      final negative = await _get(
        '/lab',
        handler: _handlerWith(_es, callTimeout: const Duration(seconds: -5)),
      );
      // A negative wait is no wait: none, like zero.
      expect(_state(negative)['!t'], 0);
    });

    test('the defaults are English too', () async {
      final r = await _get(
        '/lab',
        handler: _handlerWith(const ServerMessages()),
      );
      expect(_state(r)['!m'], {
        'network': 'Network error',
        'timeout': 'The server took too long to answer',
        'aborted': 'The request was cancelled',
        'generic': 'Something went wrong',
      });
    });
  });

  group('ServerMessages', () {
    test('a status message fills {status}', () {
      expect(const ServerMessages().forStatus(418), 'Error 418');
      expect(_es.forStatus(503), 'Error 503 del servidor');
      expect(const ServerMessages(httpError: 'HTTP').forStatus(500), 'HTTP');
    });
  });
}
