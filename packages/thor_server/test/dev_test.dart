import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

/// Pages are strings in a small document.
class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) =>
      utf8.encode('<!DOCTYPE html><html><body>$page</body></html>');

  @override
  String errorPage(ErrorState state) => 'plain error ${state.status}';
}

PageRequest _get(String path) => PageRequest(
  method: HttpMethod.get,
  uri: Uri.parse('http://site.test$path'),
  headers: const {HttpHeader.host: 'site.test'},
);

PageRequest _post(String path) => PageRequest(
  method: HttpMethod.post,
  uri: Uri.parse('http://site.test$path'),
  headers: const {
    HttpHeader.host: 'site.test',
    HttpHeader.origin: 'http://site.test',
    HttpHeader.contentType: 'application/x-www-form-urlencoded',
  },
  body: Stream.value(utf8.encode('a=1')),
);

/// The error blocks of [html], decoded.
List<Map<String, Object?>> _blocks(String html) => [
  for (final m in RegExp(
    '<script type="application/json" id="${ThorDev.errorId}">'
    r'([\s\S]*?)</script>',
  ).allMatches(html))
    jsonDecode(m[1]!) as Map<String, Object?>,
];

void main() {
  late RouteHandler<String> handler;
  late List<Object> reported;

  setUp(() {
    reported = [];
    handler = RouteHandler<String>(
      renderer: _Renderer(),
      onError: (request, error, stack) => reported.add(error),
      routes: [
        LayoutRoute<String, void>(
          build: (s, child) => '<main>$child</main>',
          error: (e) => 'error ${e.status}',
          children: [
            PageRoute<String, String>(
              path: 'load',
              load: (r) => throw StateError('db </script> down'),
              build: (s) => s.data,
            ),
            PageRoute<String, void>(
              path: 'build',
              build: (s) => throw ArgumentError('bad widget'),
            ),
            PageRoute<String, void>(
              path: 'action',
              build: (s) => 'form',
              actions: {'default': (r) => throw const FormatException('x')},
            ),
            PageRoute<String, void>(
              path: 'missing',
              load: (r) => throw const NotFound(),
              build: (s) => 'never',
            ),
            PageRoute<String, void>(path: 'ok', build: (s) => 'fine'),
            LayoutRoute<String, void>(
              path: 'admin',
              middleware: (r, next) => throw StateError('no session store'),
              build: (s, child) => child,
              children: [
                PageRoute<String, void>(path: 'panel', build: (s) => 'panel'),
              ],
            ),
          ],
        ),
      ],
    );
  });

  setUp(() => ThorDev.errorSink = (_) {});

  tearDown(() {
    ThorDev.enabled = false;
    ThorDev.forgetLoggedErrors();
  });

  group('outside thor dev (a release)', () {
    test('an exception never reaches the page', () async {
      ThorDev.enabled = false;
      final r = await handler.handle(_get('/load'));
      expect(r.status, 500);
      expect(r.text, isNot(contains(ThorDev.errorId)));
      expect(r.text, isNot(contains('db')));
      expect(reported, hasLength(1));
    });
  });

  group('under thor dev', () {
    setUp(() => ThorDev.enabled = true);

    test(
      'a load that throws: its block, with the phase and the stack',
      () async {
        final r = await handler.handle(_get('/load'));
        expect(r.status, 500);
        expect(r.text, contains('error 500'));
        final block = _blocks(r.text).single;
        expect(block['phase'], 'load');
        expect(block['where'], 'GET /load');
        expect(block['type'], 'StateError');
        expect(block['message'], 'Bad state: db </script> down');
        expect(block['stack'], contains('dev_test.dart'));
        // The message's `</script>` did not end the block early.
        expect(
          r.text.indexOf('</script>'),
          greaterThan(r.text.indexOf('down')),
        );
        expect(
          r.text.indexOf(ThorDev.errorId),
          lessThan(r.text.indexOf('</body>')),
        );
      },
    );

    test('a build and an action: their phases', () async {
      final build = _blocks((await handler.handle(_get('/build'))).text);
      expect(build.single['phase'], 'build');
      expect(build.single['type'], 'ArgumentError');
      final action = _blocks((await handler.handle(_post('/action'))).text);
      expect(action.single['phase'], 'action');
    });

    test('a middleware that throws: its block', () async {
      final r = await handler.handle(_get('/admin/panel'));
      expect(r.status, 500);
      expect(_blocks(r.text).single['phase'], 'middleware');
    });

    test('an HTTP error is not a fault: no block', () async {
      final r = await handler.handle(_get('/missing'));
      expect(r.status, 404);
      expect(_blocks(r.text), isEmpty);
      expect(reported, isEmpty);
    });

    test('a page that works has no block', () async {
      final r = await handler.handle(_get('/ok'));
      expect(r.status, 200);
      expect(r.text, isNot(contains(ThorDev.errorId)));
    });

    test('the blocks of one request never show in another', () async {
      await handler.handle(_get('/load'));
      final ok = await handler.handle(_get('/ok'));
      expect(ok.text, isNot(contains(ThorDev.errorId)));
    });
  });

  test('devPid reads the pid thor dev puts in THOR_DEV_PID', () {
    expect(ThorDev.pidEnvName, 'THOR_DEV_PID');
    expect(ThorDev.pidFrom({'THOR_DEV_PID': '1234'}), 1234);
    expect(ThorDev.pidFrom(const {}), isNull);
    expect(ThorDev.pidFrom({'THOR_DEV_PID': 'x'}), isNull);
    expect(ThorDev.pidFrom({'THOR_DEV_PID': '0'}), isNull);
    final was = ThorDev.enabled;
    addTearDown(() => ThorDev.enabled = was);
    ThorDev.enabled = false;
    expect(ThorDev.devPid, isNull, reason: 'outside thor dev');
  });

  group('reassemble hooks', () {
    test('each function once, in order, every time', () {
      final calls = <String>[];
      void a() => calls.add('a');
      void b() => calls.add('b');
      ThorDev.onReassemble(a);
      ThorDev.onReassemble(b);
      ThorDev.onReassemble(a);
      ThorDev.reassembled();
      ThorDev.reassembled();
      expect(calls, ['a', 'b', 'a', 'b']);
    });

    test('a hot reload runs the isolate set-ups again (the states)', () {
      final enabled = ThorDev.enabled;
      ThorDev.enabled = true;
      addTearDown(() => ThorDev.enabled = enabled);
      _setUps = 0;
      ThorServer.setUpIsolates(_countSetUp);
      expect(_setUps, 1);
      ThorDev.reassembled();
      expect(_setUps, 2);
      expect(ThorDev.reassembledResult, contains('"setUps":true'));
    });
  });

  test('withBlocks: before the last </body>, or at the end', () {
    expect(
      ThorDev.withBlocks('<body><p>"</body>"</p></body>', ['X']),
      '<body><p>"</body>"</p>X</body>',
    );
    expect(ThorDev.withBlocks('<p>', ['X']), '<p>X');
    expect(ThorDev.withBlocks('<p>', const []), '<p>');
  });
}

var _setUps = 0;

void _countSetUp() => _setUps++;
