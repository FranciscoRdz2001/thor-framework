@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

void main() {
  late HttpServer http;
  var target = '/x';
  var status = 303;

  setUp(() async {
    final server = ThorServer(
      handler: RouteHandler<String>(
        renderer: _Renderer(),
        onError: (request, error, stack) {},
        routes: [
          PageRoute<String, void>(
            path: 'go',
            build: (s) => 'go',
            redirect: (r) => throw Redirect(RouteUrl(target), status: status),
            actions: {'default': (r) => null},
          ),
          PageRoute<String, void>(
            path: 'about',
            build: (s) => 'about',
            actions: {'default': (r) => null},
          ),
        ],
      ),
    );
    http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen(server.handleHttp);
  });

  tearDown(() => http.close(force: true));

  Future<String> rawReq(String request) async {
    final socket = await Socket.connect('127.0.0.1', http.port);
    final reply = <int>[];
    final done = Completer<void>();
    socket.listen(
      reply.addAll,
      onDone: done.complete,
      onError: (_) => done.complete(),
    );
    socket.add(latin1.encode(request));
    await done.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    socket.destroy();
    return latin1.decode(reply);
  }

  Future<String> get(String path, {String method = 'GET'}) => rawReq(
    '$method $path HTTP/1.1\r\nHost: 127.0.0.1:${http.port}\r\n'
    'Connection: close\r\n\r\n',
  );

  String? location(String reply) => RegExp(
    r'^location: (.*)\r$',
    multiLine: true,
    caseSensitive: false,
  ).firstMatch(reply)?.group(1);

  int code(String reply) =>
      int.tryParse(
        RegExp(r'^HTTP/1\.\d (\d+)').firstMatch(reply)?.group(1) ?? '',
      ) ??
      0;

  // What a browser would resolve against http://site.test/.
  bool sameSite(String loc) {
    final base = Uri.parse('https://site.test/');
    final stripped = loc
        .replaceAll(RegExp(r'[\t\r\n]'), '')
        .replaceFirst(RegExp(r'^[\x00-\x20]+'), '');
    if (RegExp(r'^[/\\]{2}').hasMatch(stripped)) return false;
    final m = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.-]*):').firstMatch(stripped);
    if (m != null) return false;
    return base.resolve(stripped.replaceAll('\\', '/')).host == 'site.test';
  }

  group('framework-built redirects from the request path', () {
    final paths = [
      '//evil.example/',
      '///evil.example/',
      '/\\evil.example/',
      '/%2F/evil.example/',
      '/%5Cevil.example/',
      '/./..//evil.example/',
      '/%0d%0aSet-Cookie:%20x=1/',
      '/%09/evil.example/',
      '/%00/',
      '/about//',
      '/about///',
      '/a%2F%2Fevil/',
      '/%E2%88%95evil.example/',
    ];
    for (final p in paths) {
      test('trailing slash $p', () async {
        final r = await get(p);
        if (code(r) == 400 || code(r) == 0) return;
        final loc = location(r);
        if (loc == null) return;
        expect(r, isNot(contains('\r\nSet-Cookie')));
        expect(sameSite(loc), isTrue, reason: 'Location: $loc');
      });
    }
  });

  group('a thrown Redirect', () {
    final hostile = [
      'https://evil.example',
      '//evil.example',
      '/\\evil.example',
      '\\/evil.example',
      '/%2F%2Fevil.example',
      '/%5Cevil.example',
      'http:evil.example',
      'JaVaScRiPt:alert(1)',
      'data:text/html,x',
      '/ok\u0000//evil.example',
      '\u0000//evil.example',
      '/∕evil.example',
      '/./..//evil.example',
      '/café',
      '/ok\r\nSet-Cookie: a=b',
      '/ok x',
      '/ok\u0085x',
    ];
    for (final t in hostile) {
      test('target ${jsonEncode(t)} gives a well-formed response', () async {
        target = t;
        status = 303;
        final r = await get('/go');
        expect(code(r), 303, reason: r);
        expect(r.split('\r\n\r\n').first, isNot(contains('\r\nSet-Cookie')));
        // exactly one status line, no header smuggled
        expect(RegExp(r'^HTTP/1\.1', multiLine: true).allMatches(r).length, 1);
      });
    }

    final exact = {
      'JaVaScRiPt:alert(1)': '/',
      'java\tscript:alert(1)': '/',
      ' \x01data:text/html,x': '/',
      '/caf\u00e9': '/caf%C3%A9',
      '/\u2215evil.example': '/%E2%88%95evil.example',
      '/a\u{1F600}': '/a%F0%9F%98%80',
      '/ok\u0000//evil.example': '/ok//evil.example',
      'https://sso.example/in?next=/x': 'https://sso.example/in?next=/x',
    };
    for (final MapEntry(key: t, value: want) in exact.entries) {
      test('${jsonEncode(t)} is sent as $want', () async {
        target = t;
        status = 303;
        expect(location(await get('/go')), want);
      });
    }

    for (final s in [0, 100, 200, 299, 300, 304, 399, 400, 500, 1000, -1]) {
      test('invalid status $s becomes a 303', () async {
        target = '/x';
        status = s;
        final r = await get('/go');
        expect(code(r), 303, reason: r);
        expect(location(r), '/x');
      });
    }
  });
}
