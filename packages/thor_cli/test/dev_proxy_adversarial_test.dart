import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_cli/src/dev_proxy.dart';

void main() {
  late HttpServer app;
  late DevProxy proxy;
  // The stub holds its second event until the test has read the first.
  var release = Completer<void>();
  final client = HttpClient()..autoUncompress = false;

  setUp(() async {
    release = Completer<void>();
    app = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    app.listen((r) async {
      final res = r.response;
      switch (r.uri.path) {
        case '/dotted':
          // `İ` lowercases to two code units: indexes of the lowered copy
          // are not those of the page.
          res
            ..headers.contentType = ContentType.html
            ..write('<body><p>İİİ İstanbul</p></body>');
        case '/gzip':
          res
            ..headers.contentType = ContentType.html
            ..headers.set(HttpHeaders.contentEncodingHeader, 'gzip')
            ..add(gzip.encode(utf8.encode('<body><p>hi</p></body>')));
        case '/utf8':
          final bytes = utf8.encode('<body><p>€€€ ñ 日本</p></body>');
          res
            ..headers.contentType = ContentType.html
            ..bufferOutput = false;
          for (var i = 0; i < bytes.length; i++) {
            res.add([bytes[i]]);
            await res.flush();
          }
        case '/sse':
          res
            ..headers.contentType = ContentType('text', 'event-stream')
            ..bufferOutput = false
            ..write('data: 1\n\n');
          await res.flush();
          await release.future;
          res.write('data: 2\n\n</body>');
        case '/clen':
          const body = '<body>x</body>';
          res
            ..headers.contentType = ContentType.html
            ..contentLength = body.length
            ..write(body);
        case '/script':
          res
            ..headers.contentType = ContentType.html
            ..write(
              '<body><script>var s = "</body>";</script><p>real</p></body>',
            );
        case '/304':
          res.statusCode = HttpStatus.notModified;
        case '/huge':
          res
            ..headers.contentType = ContentType.html
            ..write('<body>${'x' * 5000000}</body>');
        case '/latin1':
          res
            ..headers.contentType = ContentType(
              'text',
              'html',
              charset: 'iso-8859-1',
            )
            ..add(latin1.encode('<body>ñ</body>'));
        default:
          res
            ..headers.contentType = ContentType.html
            ..write('<body></body>');
      }
      await res.close();
    });
    proxy = DevProxy(upstream: app.port, wait: const Duration(seconds: 1));
    await proxy.start(0);
    proxy.ready();
  });

  tearDown(() async {
    if (!release.isCompleted) release.complete();
    await proxy.close();
    await app.close(force: true);
  });

  Future<HttpClientResponse> send(String path, {String method = 'GET'}) async {
    final req = await client.open(method, 'localhost', proxy.port, path);
    req.headers.set(HttpHeaders.acceptHeader, 'text/html');
    return req.close();
  }

  Future<String> text(HttpClientResponse r) => utf8.decodeStream(r);

  test('a page with chars that change length lowered keeps its text', () async {
    final html = await text(await send('/dotted'));
    expect(html, contains('<p>İİİ İstanbul</p>'));
    expect(html, contains('thor-live-reload'));
    expect(html, endsWith('</body>'));
    expect(
      html.indexOf('thor-live-reload'),
      lessThan(html.lastIndexOf('</body>')),
    );
  });

  test('multi-byte characters split across chunks arrive intact', () async {
    final html = await text(await send('/utf8'));
    expect(html, contains('<p>€€€ ñ 日本</p>'));
  });

  test('an encoded HTML body from the app is not corrupted', () async {
    final r = await send('/gzip');
    final bytes = await r.fold<List<int>>([], (a, b) => a..addAll(b));
    final encoding = r.headers.value(HttpHeaders.contentEncodingHeader);
    final body = encoding == 'gzip'
        ? utf8.decode(gzip.decode(bytes))
        : utf8.decode(bytes);
    expect(body, contains('<p>hi</p>'));
  });

  test('event streams are not buffered nor changed', () async {
    final r = await send('/sse');
    // Order, not a clock: the first event arrives while the app still holds
    // the second (a buffering proxy would never get here).
    final first = await r.first;
    expect(utf8.decode(first), 'data: 1\n\n');
    expect(release.isCompleted, isFalse);
  });

  test(
    'a </body> inside a script string: scripts go before the real end',
    () async {
      final html = await text(await send('/script'));
      expect(html, contains('var s = "</body>";</script><p>real</p>'));
      expect(
        html.indexOf('thor-live-reload'),
        greaterThan(html.indexOf('real')),
      );
    },
  );

  test('Content-Length of the app is dropped for HTML', () async {
    final r = await send('/clen');
    final html = await text(r);
    expect(html, contains('thor-live-reload'));
  });

  test('a 304 and a HEAD pass', () async {
    final r = await send('/304');
    expect(r.statusCode, 304);
    await r.drain<void>();
    final h = await send('/clen', method: 'HEAD');
    expect(h.statusCode, 200);
    await h.drain<void>();
  });

  test('a huge single chunk', () async {
    final html = await text(await send('/huge'));
    expect(html.length, greaterThan(5000000));
    expect(html, contains('thor-live-reload'));
  });

  test('a latin1 page is sent as utf-8', () async {
    final html = await text(await send('/latin1'));
    expect(html, contains('<body>ñ'));
  });
}
