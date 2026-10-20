// Headers a client may repeat (RFC 9110 lists): `Accept-Encoding` and
// `If-None-Match` joined, never a 500; `gzip;q=0` refuses gzip.
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

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('thor_repeated_');
    File('${dir.path}/app.css').writeAsStringSync('a{b:c}' * 400);
    final server = ThorServer(
      publicDir: dir.path,
      handler: RouteHandler<String>(
        renderer: _Renderer(),
        onError: (request, error, stack) {},
        routes: [PageRoute<String, void>(build: (s) => 'home' * 600)],
      ),
    );
    http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen(server.handleHttp);
  });
  tearDown(() async {
    await http.close(force: true);
    dir.deleteSync(recursive: true);
  });

  Future<(int, String, String)> raw(String path, List<String> headers) async {
    final socket = await Socket.connect(http.address, http.port);
    socket.write(
      'GET $path HTTP/1.1\r\nHost: site.test\r\nConnection: close\r\n'
      '${headers.map((h) => '$h\r\n').join()}\r\n',
    );
    final bytes = <int>[];
    await socket.listen(bytes.addAll).asFuture<void>();
    socket.destroy();
    final text = latin1.decode(bytes);
    final split = text.indexOf('\r\n\r\n');
    return (
      int.parse(text.substring(9, 12)),
      text.substring(0, split).toLowerCase(),
      text.substring(split + 4),
    );
  }

  test('repeated Accept-Encoding lines are joined, not a 500', () async {
    for (final path in ['/', '/app.css']) {
      final r = await raw(path, [
        'Accept-Encoding: deflate',
        'Accept-Encoding: gzip',
      ]);
      expect(r.$1, 200, reason: path);
      expect(r.$2, contains('content-encoding: gzip'), reason: path);
    }
  });

  test('repeated If-None-Match lines are joined, not a 500', () async {
    final first = await raw('/app.css', []);
    final etag = RegExp(r'etag: (\S+)').firstMatch(first.$2)!.group(1)!;
    final r = await raw('/app.css', [
      'If-None-Match: "other"',
      'If-None-Match: $etag',
    ]);
    expect(r.$1, 304);
    final page = await raw('/', ['If-None-Match: "a"', 'If-None-Match: "b"']);
    expect(page.$1, 200);
  });

  test('gzip;q=0 refuses gzip', () async {
    for (final path in ['/', '/app.css']) {
      final r = await raw(path, ['Accept-Encoding: gzip;q=0, identity']);
      expect(r.$1, 200, reason: path);
      expect(r.$2, isNot(contains('content-encoding')), reason: path);
    }
  });
}
