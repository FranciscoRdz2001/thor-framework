// Files in public/: media types, byte ranges (206, 416; Safari plays no
// video without them) and big files streamed instead of read whole.
@TestOn('vm')
library;

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
  late Directory dir;
  final video = List<int>.generate(3000, (i) => i % 251);
  final big = List<int>.filled((1 << 20) + 10, 7);

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('thor_range_');
    File('${dir.path}/clip.mp4').writeAsBytesSync(video);
    File('${dir.path}/big.bin').writeAsBytesSync(big);
    for (final ext in ['webm', 'mp3', 'ogg', 'pdf', 'otf', 'csv']) {
      File('${dir.path}/a.$ext').writeAsStringSync('x');
    }
    final server = ThorServer(
      publicDir: dir.path,
      handler: RouteHandler<String>(
        renderer: _Renderer(),
        onError: (request, error, stack) {},
        routes: [PageRoute<String, void>(build: (s) => 'home')],
      ),
    );
    http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen(server.handleHttp);
  });
  tearDown(() async {
    await http.close(force: true);
    dir.deleteSync(recursive: true);
  });

  Future<(int, HttpHeaders, List<int>)> get(
    String path, {
    Map<String, String> headers = const {},
    String method = 'GET',
  }) async {
    final client = HttpClient()..autoUncompress = false;
    try {
      final req = await client.open(method, http.address.host, http.port, path);
      headers.forEach(req.headers.set);
      final res = await req.close();
      final body = <int>[];
      await res.forEach(body.addAll);
      return (res.statusCode, res.headers, body);
    } finally {
      client.close(force: true);
    }
  }

  test('media and document types', () async {
    for (final (ext, type) in [
      ('mp4', 'video/mp4'),
      ('webm', 'video/webm'),
      ('mp3', 'audio/mpeg'),
      ('ogg', 'audio/ogg'),
      ('pdf', 'application/pdf'),
      ('otf', 'font/otf'),
      ('csv', 'text/csv'),
    ]) {
      final r = await get(ext == 'mp4' ? '/clip.mp4' : '/a.$ext');
      expect(r.$1, 200, reason: ext);
      expect(r.$2.contentType.toString(), startsWith(type), reason: ext);
    }
  });

  test('a file says it takes ranges', () async {
    final r = await get('/clip.mp4');
    expect(r.$2.value('accept-ranges'), 'bytes');
    expect(r.$3, video);
  });

  test('a single range answers 206 with Content-Range', () async {
    final r = await get('/clip.mp4', headers: {'range': 'bytes=10-19'});
    expect(r.$1, 206);
    expect(r.$2.value('content-range'), 'bytes 10-19/3000');
    expect(r.$2.contentLength, 10);
    expect(r.$3, video.sublist(10, 20));
  });

  test('open-ended and suffix ranges', () async {
    final open = await get('/clip.mp4', headers: {'range': 'bytes=2990-'});
    expect(open.$1, 206);
    expect(open.$3, video.sublist(2990));
    final suffix = await get('/clip.mp4', headers: {'range': 'bytes=-5'});
    expect(suffix.$2.value('content-range'), 'bytes 2995-2999/3000');
    expect(suffix.$3, video.sublist(2995));
    final past = await get('/clip.mp4', headers: {'range': 'bytes=0-99999'});
    expect(past.$2.value('content-range'), 'bytes 0-2999/3000');
  });

  test('past the end is a 416; garbage or several ranges, a 200', () async {
    final r = await get('/clip.mp4', headers: {'range': 'bytes=5000-6000'});
    expect(r.$1, 416);
    expect(r.$2.value('content-range'), 'bytes */3000');
    for (final h in ['bytes=0-1,5-6', 'items=0-1', 'bytes=9-2', 'nonsense']) {
      final x = await get('/clip.mp4', headers: {'range': h});
      expect(x.$1, 200, reason: h);
      expect(x.$3, video, reason: h);
    }
  });

  test('If-Range with another validator sends the whole file', () async {
    final first = await get('/clip.mp4');
    final etag = first.$2.value('etag')!;
    final same = await get(
      '/clip.mp4',
      headers: {'range': 'bytes=0-4', 'if-range': etag},
    );
    expect(same.$1, 206);
    final other = await get(
      '/clip.mp4',
      headers: {'range': 'bytes=0-4', 'if-range': '"nope"'},
    );
    expect(other.$1, 200);
    expect(other.$3, video);
  });

  test('a HEAD of a range has headers and no body', () async {
    final r = await get(
      '/clip.mp4',
      method: 'HEAD',
      headers: {'range': 'bytes=0-9'},
    );
    expect(r.$1, 206);
    expect(r.$3, isEmpty);
  });

  test('a file over 1 MB is streamed whole with its length', () async {
    final r = await get('/big.bin');
    expect(r.$1, 200);
    expect(r.$2.contentLength, big.length);
    expect(r.$3.length, big.length);
  });

  test('StaticFiles streams a big file instead of buffering it', () async {
    final files = StaticFiles(dir.path, index: true);
    final r = (await files.lookup('/big.bin', null, null))!;
    expect(r.stream, isNotNull);
    expect(r.body, isEmpty);
    final small = (await files.lookup('/clip.mp4', null, null))!;
    expect(small.stream, isNull);
    expect(small.body, video);
  });
}
