// Which responses are gzipped: text yes, already-compressed bytes (images,
// fonts, archives) and bodies that already carry a Content-Encoding no;
// Vary and the ETag variants of the two representations.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
  final zeros = List<int>.filled(8000, 0);
  final random = Random(3);
  final noise = [for (var i = 0; i < 6000; i++) random.nextInt(256)];

  setUp(() async {
    final server = ThorServer(
      handler: RouteHandler<String>(
        renderer: _Renderer(),
        onError: (request, error, stack) {},
        routes: [
          for (final (name, type) in [
            ('a.png', 'image/png'),
            ('a.jpg', 'image/jpeg'),
            ('a.webp', 'image/webp'),
            ('a.woff2', 'font/woff2'),
            ('a.zip', 'application/zip'),
            ('a.mp4', 'video/mp4'),
            ('a.gz', 'application/gzip'),
            ('a.pdf', 'application/pdf'),
            ('a.json', 'application/json; charset=utf-8'),
            ('a.svg', 'image/svg+xml'),
            ('a.xml', 'application/xml'),
            ('a.txt', 'text/plain; charset=utf-8'),
            ('a.js', 'application/javascript'),
            ('a.ld', 'application/ld+json'),
            ('a.wasm', 'application/wasm'),
            ('a.bin', 'application/octet-stream'),
          ])
            ResourceRoute<String>(
              path: name,
              respond: (r) => ThorResponse.bytes(zeros, contentType: type),
            ),
          ResourceRoute<String>(
            path: 'pre.json',
            respond: (r) => ThorResponse.bytes(
              gzip.encode(noise),
              contentType: 'application/json',
              headers: {HttpHeader.contentEncoding: 'gzip'},
            ),
          ),
        ],
      ),
    );
    http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen(server.handleHttp);
  });

  tearDown(() => http.close(force: true));

  Future<HttpClientResponse> get(String path, {String? etag}) async {
    final client = HttpClient()..autoUncompress = false;
    final request = await client.get('127.0.0.1', http.port, path);
    request.headers.set('accept-encoding', 'gzip');
    if (etag != null) request.headers.set('if-none-match', etag);
    return request.close();
  }

  for (final name in [
    'png',
    'jpg',
    'webp',
    'woff2',
    'zip',
    'mp4',
    'gz',
    'pdf',
  ]) {
    test('a.$name is never gzipped', () async {
      final r = await get('/a.$name');
      expect(r.headers.value('content-encoding'), isNull);
      expect(r.headers.contentLength, zeros.length);
      await r.drain<void>();
    });
  }

  for (final name in ['json', 'svg', 'xml', 'txt', 'js', 'ld', 'wasm']) {
    test('a.$name is gzipped', () async {
      final r = await get('/a.$name');
      expect(r.headers.value('content-encoding'), 'gzip');
      expect(r.headers.value('vary'), contains('Accept-Encoding'));
      await r.drain<void>();
    });
  }

  test('a body that already has a Content-Encoding is left as it is', () async {
    final r = await get('/pre.json');
    expect(r.headers.value('content-encoding'), 'gzip');
    final bytes = await r.fold<List<int>>([], (a, b) => [...a, ...b]);
    expect(gzip.decode(bytes), noise, reason: 'compressed once, not twice');
  });

  test('the two representations have different validators, one hash', () async {
    final gz = await get('/a.json');
    final tag = gz.headers.value('etag')!;
    await gz.drain<void>();
    expect(tag, startsWith('W/'));
    final client = HttpClient()..autoUncompress = false;
    final request = await client.get('127.0.0.1', http.port, '/a.json');
    request.headers.set('accept-encoding', 'identity');
    final plain = await request.close();
    final plainTag = plain.headers.value('etag')!;
    await plain.drain<void>();
    expect(plain.headers.value('content-encoding'), isNull);
    expect(plain.headers.value('vary'), contains('Accept-Encoding'));
    expect(plainTag, isNot(startsWith('W/')));
    expect(tag, 'W/$plainTag');
    // Either validator gets a 304 for either representation.
    for (final t in [tag, plainTag]) {
      final r = await get('/a.json', etag: t);
      expect(r.statusCode, 304, reason: t);
      expect(r.headers.value('vary'), contains('Accept-Encoding'));
      await r.drain<void>();
    }
  });
}
