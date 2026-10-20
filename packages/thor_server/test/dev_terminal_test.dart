import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) =>
      utf8.encode('<html><body>$page</body></html>');

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

PageRequest _get(String path) => PageRequest(
  method: HttpMethod.get,
  uri: Uri.parse('http://site.test$path'),
  headers: const {HttpHeader.host: 'site.test'},
);

void main() {
  late List<String> lines;
  late DateTime now;
  late List<Object> reported;

  RouteHandler<String> make({bool customOnError = true}) =>
      RouteHandler<String>(
        renderer: _Renderer(),
        onError: customOnError
            ? (r, e, s) => reported.add(e)
            : RouteHandler.onErrorDefault,
        routes: [
          PageRoute<String, String>(
            path: 'boom',
            load: (r) => throw StateError('db down\nsecond line'),
            build: (s) => s.data,
          ),
          PageRoute<String, void>(path: 'ok', build: (s) => 'fine'),
        ],
      );

  setUp(() {
    lines = [];
    reported = [];
    now = DateTime(2026);
    ThorDev.enabled = true;
    ThorDev.errorSink = lines.add;
    ThorDev.clock = () => now;
    ThorDev.forgetLoggedErrors();
  });

  tearDown(() {
    ThorDev.enabled = false;
    ThorDev.errorSink = (l) {};
    ThorDev.clock = DateTime.now;
    ThorDev.forgetLoggedErrors();
  });

  test(
    'a load that throws prints one line even with a custom onError',
    () async {
      final r = await make().handle(_get('/boom'));
      expect(r.status, 500);
      expect(lines, hasLength(1));
      expect(lines.single, startsWith('[thor] 500 GET /boom: StateError: '));
      expect(lines.single, contains('Bad state: db down'));
      // First line of the message only, and the app's frame, not a stack.
      expect(lines.single, isNot(contains('second line')));
      expect(lines.single, contains('(at '));
      expect(lines.single, contains('dev_terminal_test.dart:'));
      expect(lines.single, isNot(contains('\n')));
      // The app's own onError still runs.
      expect(reported, hasLength(1));
    },
  );

  test(
    'the same error within the window is written once, then counted',
    () async {
      final h = make();
      await h.handle(_get('/boom'));
      await h.handle(_get('/boom'));
      await h.handle(_get('/boom'));
      expect(lines, hasLength(1));
      now = now.add(ThorDev.errorDedupe + const Duration(seconds: 1));
      await h.handle(_get('/boom'));
      expect(lines, hasLength(2));
      expect(lines.last, endsWith('[+2 repeats]'));
      expect(reported, hasLength(4));
    },
  );

  test('a different path is not a repeat', () {
    for (final p in ['/a', '/b']) {
      ThorDev.logRequestError(method: 'GET', path: p, error: StateError('x'));
    }
    expect(lines, hasLength(2));
  });

  test('a request that works prints nothing', () async {
    await make().handle(_get('/ok'));
    expect(lines, isEmpty);
  });

  test(
    'outside thor dev nothing is printed (a release keeps onError)',
    () async {
      ThorDev.enabled = false;
      await make().handle(_get('/boom'));
      expect(lines, isEmpty);
      expect(reported, hasLength(1));
    },
  );

  test('an exception whose text names its type is not repeated', () {
    ThorDev.logRequestError(
      method: 'POST',
      path: '/a',
      error: const FormatException('bad'),
    );
    expect(lines.single, contains('POST /a: FormatException: bad'));
    expect(lines.single, isNot(contains('FormatException: FormatException')));
  });

  group('appFrame', () {
    test('skips dart: and thor packages for the app frame', () {
      final stack = StackTrace.fromString(
        '#0 _f (dart:core/errors.dart:1:1)\n'
        '#1 R.handle (package:thor_server/src/handler.dart:10:3)\n'
        '#2 load (package:shop/pages/home.dart:42:7)\n',
      );
      expect(ThorDev.appFrame(stack), 'package:shop/pages/home.dart:42:7');
    });

    test('no app frame: the first frame there is; no stack: null', () {
      final stack = StackTrace.fromString(
        '#0 R.handle (package:thor_server/src/handler.dart:10:3)\n',
      );
      expect(
        ThorDev.appFrame(stack),
        'package:thor_server/src/handler.dart:10:3',
      );
      expect(ThorDev.appFrame(null), isNull);
      expect(ThorDev.appFrame(StackTrace.fromString('garbage')), isNull);
    });
  });
}
