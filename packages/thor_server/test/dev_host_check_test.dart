// Under `thor dev` the app itself refuses a foreign Host (DNS rebinding
// reaching its port directly, not only the proxy's), and binds loopback.
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
  final client = HttpClient();
  final wasEnabled = ThorDev.enabled;
  final hadHosts = ThorDev.hosts;

  setUp(() async {
    final server = ThorServer(
      handler: RouteHandler<String>(
        renderer: _Renderer(),
        onError: (request, error, stack) {},
        routes: [PageRoute<String, void>(path: '', build: (s) => 'home')],
      ),
    );
    http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen(server.handleHttp);
  });

  tearDown(() async {
    ThorDev.enabled = wasEnabled;
    ThorDev.hosts = hadHosts;
    await http.close(force: true);
  });

  Future<(int, String)> get(String? host) async {
    final request = await client.get('127.0.0.1', http.port, '/');
    if (host != null) request.headers.host = host;
    final response = await request.close();
    return (response.statusCode, await utf8.decodeStream(response));
  }

  test('under dev: 403 for a foreign Host, the page for localhost', () async {
    ThorDev.enabled = true;
    final (status, body) = await get('evil.example');
    expect(status, 403);
    expect(body, contains('evil.example'));
    expect(body, contains('--allowed-host'));
    expect(await get('localhost'), (200, 'home'));
    expect(await get('LOCALHOST'), (200, 'home'));
    expect((await get('127.0.0.1')).$1, 200);
    expect((await get('[::1]')).$1, 200);
  });

  test('under dev: --allowed-host names pass', () async {
    ThorDev.enabled = true;
    ThorDev.hosts = const DevHosts(['dev.example']);
    expect((await get('dev.example')).$1, 200);
    expect((await get('evil.example')).$1, 403);
  });

  test('a release does not check the Host (a deploy decision)', () async {
    ThorDev.enabled = false;
    expect((await get('evil.example')).$1, 200);
  });

  test('under dev the server binds loopback whatever address was asked', () {
    ThorDev.enabled = true;
    expect(ThorDev.bindAddress(null), InternetAddress.loopbackIPv4);
    expect(
      ThorDev.bindAddress(InternetAddress.anyIPv6),
      InternetAddress.loopbackIPv4,
    );
    expect(ThorDev.bindAddress('0.0.0.0'), InternetAddress.loopbackIPv4);
    ThorDev.enabled = false;
    expect(
      ThorDev.bindAddress(InternetAddress.anyIPv6),
      InternetAddress.anyIPv6,
    );
    expect(ThorDev.bindAddress(null), InternetAddress.anyIPv6);
  });

  test(
    'under dev: an absolute-form target for a foreign host is refused',
    () async {
      ThorDev.enabled = true;
      Future<String> raw(String target, String host) async {
        final socket = await Socket.connect('127.0.0.1', http.port);
        socket.write(
          'GET $target HTTP/1.1\r\nHost: $host\r\nConnection: close\r\n\r\n',
        );
        final answer = await utf8.decodeStream(socket);
        socket.destroy();
        return answer.split('\r\n').first;
      }

      expect(await raw('http://evil.example/', 'localhost'), contains('403'));
      expect(
        await raw('http://localhost@evil.example/', 'localhost'),
        contains('403'),
      );
      expect(await raw('http://localhost:1/', 'localhost'), contains('200'));
      expect(await raw('/', 'localhost'), contains('200'));
    },
  );

  test(
    'under dev: a hostile Host over a raw socket, two Hosts, no crash',
    () async {
      ThorDev.enabled = true;
      Future<String> raw(String headers) async {
        final socket = await Socket.connect('127.0.0.1', http.port);
        socket.write('GET / HTTP/1.1\r\n$headers\r\nConnection: close\r\n\r\n');
        final answer = await latin1.decodeStream(socket);
        socket.destroy();
        return answer.split('\r\n').first;
      }

      expect(await raw('Host: attacker.example:5000'), contains('403'));
      expect(await raw('Host: localhost:80@evil.example'), contains('403'));
      expect(await raw('Host: 127.0.0.1.nip.io'), contains('403'));
      await raw('Host: evil.example\r\nHost: localhost');
      expect(await raw('Host: localhost'), contains('200'));
    },
  );
}
