import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

/// What a call can reach (docs/guia/en/server-and-actions.md, «HTTP
/// client»). The client is for backends the app chose: it has no allowlist,
/// so an app that builds a URL from what a visitor sent must check it. What
/// it does not do is leave the network: only `http` and
/// `https`, and a refused or silent backend is an `UpstreamError`, never a
/// hang.
void main() {
  late ThorHttpClient client;
  setUp(() => client = ThorHttpClient(timeout: const Duration(seconds: 2)));

  for (final url in [
    'file:///etc/passwd',
    'ftp://example.com/x',
    'gopher://example.com/',
    'data:text/plain,hello',
    'javascript:1',
    'ws://example.com/',
  ]) {
    test('$url is not fetched', () async {
      await expectLater(
        client.get(url),
        throwsA(
          anyOf(isA<UpstreamError>(), isA<ArgumentError>(), isA<StateError>()),
        ),
      );
    });
  }

  test('a URL with no host is an error, not a request to the local host', () {
    expect(client.get('http:///path'), throwsA(isA<Object>()));
    expect(client.get('/just/a/path'), throwsA(isA<Object>()));
  });

  test(
    'a backend that redirects is followed (dart:io: up to five hops)',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) {
        if (request.uri.path == '/start') {
          request.response
            ..statusCode = 302
            ..headers.set('location', '/end')
            ..close();
        } else {
          request.response
            ..write('end')
            ..close();
        }
      });
      final r = await client.get('http://127.0.0.1:${server.port}/start');
      // This is the reason a URL a visitor chose must be checked by the app:
      // the client follows what the backend says, wherever it points.
      expect(r.text, 'end');
    },
  );
}
