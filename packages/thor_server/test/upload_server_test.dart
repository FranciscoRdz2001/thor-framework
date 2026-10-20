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
  final saved = <String, List<int>>{};
  final client = HttpClient();

  setUp(() async {
    saved.clear();
    final server = ThorServer(
      maxBodyBytes: 4096,
      handler: RouteHandler<String>(
        renderer: _Renderer(),
        onError: (request, error, stack) {},
        routes: [
          PageRoute<String, void>(
            path: 'upload',
            build: (s) => 'form ${s.form ?? ''}',
            actions: {
              'default': (r) async {
                final form = await r.form();
                final file = form.file('doc');
                if (file == null) {
                  return const ActionResult.fail(422, {'error': 'no file'});
                }
                saved[file.filename] = file.bytes;
                return Redirect(RouteUrl('/upload?saved=${form['title']}'));
              },
            },
          ),
        ],
      ),
    );
    http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen(server.handleHttp);
  });

  tearDown(() => http.close(force: true));

  Future<HttpClientResponse> post(
    List<int> body, {
    String boundary = 'b0undary',
    String? origin,
  }) async {
    final request = await client.post('127.0.0.1', http.port, '/upload');
    request
      ..followRedirects = false
      ..headers.set('content-type', 'multipart/form-data; boundary=$boundary')
      ..headers.set('origin', origin ?? 'http://127.0.0.1:${http.port}')
      ..add(body);
    return request.close();
  }

  List<int> multipart(List<int> file, {String name = 'doc'}) => [
    ...utf8.encode(
      '--b0undary\r\n'
      'Content-Disposition: form-data; name="title"\r\n\r\nInforme\r\n'
      '--b0undary\r\n'
      'Content-Disposition: form-data; name="$name"; filename="r.pdf"\r\n'
      'Content-Type: application/pdf\r\n\r\n',
    ),
    ...file,
    ...utf8.encode('\r\n--b0undary--\r\n'),
  ];

  test(
    'an action reads the file and the fields; the visitor is redirected',
    () async {
      final pdf = [0x25, 0x50, 0x44, 0x46, 0, 1, 2, 255];
      final response = await post(multipart(pdf));
      await response.drain<void>();
      expect(response.statusCode, HttpStatus.seeOther);
      expect(response.headers.value('location'), '/upload?saved=Informe');
      expect(saved['r.pdf'], pdf);
    },
  );

  test(
    'no file: the action fails with its own status, the page re-renders',
    () async {
      final response = await post(multipart(const [], name: 'other'));
      expect(response.statusCode, 422);
      expect(await utf8.decodeStream(response), contains('no file'));
    },
  );

  test("a body over the server's limit is a 413, nothing saved", () async {
    final response = await post(multipart(List.filled(5000, 1)));
    await response.drain<void>();
    expect(response.statusCode, 413);
    expect(saved, isEmpty);
  });

  // A body far over the limit is still arriving when the handler gives
  // up: the client must get the 413, not a dropped connection.
  test('a body far over the limit is a 413, not an empty reply', () async {
    final response = await post(multipart(List.filled(4 << 20, 1)));
    await response.drain<void>();
    expect(response.statusCode, 413);
    expect(saved, isEmpty);
  });

  test('a malformed body is a 400, not a 500', () async {
    final response = await post(utf8.encode('--b0undary\r\nnope'));
    await response.drain<void>();
    expect(response.statusCode, 400);
  });

  test(
    'an upload from another site is refused (same-origin actions)',
    () async {
      final response = await post(
        multipart(const [1]),
        origin: 'https://evil.test',
      );
      await response.drain<void>();
      expect(response.statusCode, 403);
      expect(saved, isEmpty);
    },
  );
}
