// DevProxy and framing: by default dart:io's X-Frame-Options: SAMEORIGIN
// stays (an editor on another origin sees a blank iframe); `frameAncestors`
// (or THOR_FRAME_ANCESTORS) lets exactly those origins frame the app.
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_cli/src/dev_proxy.dart';
import 'package:thor_cli/src/run.dart';

void main() {
  late HttpServer app;
  DevProxy? proxy;
  final client = HttpClient();

  setUp(() async {
    app = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    app.listen((r) async {
      r.response.headers.contentType = ContentType.html;
      if (r.uri.path == '/strict') {
        r.response.headers
          ..set('x-frame-options', 'DENY')
          ..set(
            'content-security-policy',
            "default-src 'self'; frame-ancestors 'none'; img-src *",
          );
      }
      r.response.write('<html><body>hi</body></html>');
      await r.response.close();
    });
  });

  tearDown(() async {
    await proxy?.close();
    await app.close(force: true);
  });

  Future<HttpHeaders> headersOf(String path) async {
    final req = await client.open('GET', 'localhost', proxy!.port, path);
    final res = await req.close();
    await res.drain<void>();
    return res.headers;
  }

  Future<void> startProxy({List<String>? frameAncestors}) async {
    proxy = DevProxy(upstream: app.port, frameAncestors: frameAncestors);
    await proxy!.start(0);
    proxy!.ready();
  }

  test('by default pages stay unframable from another origin', () async {
    await startProxy();
    final h = await headersOf('/');
    expect(h.value('x-frame-options'), contains('SAMEORIGIN'));
    expect(h.value('content-security-policy'), isNull);
  });

  test('frameAncestors lets only those origins frame every response', () async {
    await startProxy(frameAncestors: ['http://localhost:4700']);
    const policy = "frame-ancestors 'self' http://localhost:4700";
    for (final path in ['/', '/__thor/status']) {
      final h = await headersOf(path);
      expect(h.value('x-frame-options'), isNull, reason: path);
      expect(h['content-security-policy'], [policy], reason: path);
    }
  });

  test("the app's own DENY and frame-ancestors are replaced", () async {
    await startProxy(frameAncestors: ['https://editor.example']);
    final h = await headersOf('/strict');
    expect(h.value('x-frame-options'), isNull);
    final directives = [
      for (final line in h['content-security-policy']!)
        ...line.split(RegExp('[;,]')).map((d) => d.trim()),
    ];
    expect(directives, contains("default-src 'self'"));
    expect(directives, contains('img-src *'));
    expect(directives.where((d) => d.startsWith('frame-ancestors')).toSet(), {
      "frame-ancestors 'self' https://editor.example",
    });
  });

  test('a wildcard or a path is refused when the proxy is built', () {
    for (final bad in ['*', 'https://*.example.com', 'https://a.example/x']) {
      expect(
        () => DevProxy(upstream: 1, frameAncestors: [bad]),
        throwsA(isA<ThorException>()),
        reason: bad,
      );
    }
  });

  test('THOR_FRAME_ANCESTORS is a comma-separated list of origins', () {
    expect(parseFrameAncestors(null), isEmpty);
    expect(parseFrameAncestors(' '), isEmpty);
    expect(parseFrameAncestors('http://localhost:4700, https://a.example'), [
      'http://localhost:4700',
      'https://a.example',
    ]);
  });
}
