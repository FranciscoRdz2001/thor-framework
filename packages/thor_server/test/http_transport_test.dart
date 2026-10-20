@TestOn('vm')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

ThorHttpResponse _ok(ThorHttpRequest r, String body) => ThorHttpResponse(
  uri: r.uri,
  method: r.method,
  statusCode: 200,
  bytes: Uint8List.fromList(utf8.encode(body)),
);

void main() {
  final client = ThorHttpClient(headers: {const HttpHeader('X-Key'): 'k'});

  test('a transport in the zone answers instead of the network', () async {
    ThorHttpRequest? seen;
    final res = await runWithThorHttpTransport((r) {
      seen = r;
      return _ok(r, '{"a":1}');
    }, () => client.post('http://127.0.0.1:1/x?q=1', json: {'b': 2}));
    expect(res.json(), {'a': 1});
    expect(seen!.method, HttpMethod.post);
    expect(seen!.headers['x-key'], 'k');
    expect(seen!.headers['content-type'], 'application/json');
    expect(seen!.json(), {'b': 2});
  });

  test('the innermost zone wins and nothing leaks out', () async {
    final out = await runWithThorHttpTransport(
      (r) => _ok(r, 'outer'),
      () => runWithThorHttpTransport(
        (r) => _ok(r, 'inner'),
        () async => (await client.get('http://127.0.0.1:1/')).text,
      ),
    );
    expect(out, 'inner');
    await expectLater(
      client.get('http://127.0.0.1:1/'),
      throwsA(isA<UpstreamError>()),
    );
  });
}
