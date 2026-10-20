// Fake backends: a page that calls a global ThorHttpClient is answered by
// fixtures (no network), loudly when nothing matches.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart' show ThorHttpRequest;
import 'package:thor_test/thor_test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

// A global client, as an app's `final api = ShopApi(...)` holds it.
final api = ThorHttpClient(timeout: const Duration(seconds: 2));

const _base = 'http://127.0.0.1:1'; // nothing listens: a real call fails

RouteHandler<Widget> _handler() => RouteHandler<Widget>(
  renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
  onError: (request, error, stack) {},
  routes: [
    PageRoute<Widget, Object?>(
      path: 'item',
      load: (r) => api.getJson('$_base/items/1'),
      build: (s) => Text('item ${(s.data! as Map)['name']}'),
    ),
    PageRoute<Widget, Object?>(
      path: 'swallow',
      load: (r) async {
        try {
          return await api.getJson('$_base/nope');
        } on Object {
          return 'fallback';
        }
      },
      build: (s) => Text('${s.data}'),
    ),
    PageRoute<Widget, List<Future<Object?>>>(
      path: 'lazy',
      load: (r) => [api.getJson('$_base/items/2')],
      build: (s) => Column(
        children: [
          const Text('shell'),
          FutureBuilder<Object>(
            future: s.data.single.then((v) => v!),
            builder: (c, snap) => Text(
              snap.hasData ? 'lazy ${(snap.data! as Map)['name']}' : '…',
            ),
          ),
        ],
      ),
    ),
  ],
);

void main() {
  setUpAll(initializeThorTests);

  test('withHttpFixtures answers a global client', () async {
    await withHttpFixtures(
      {
        'GET $_base/items/1': {'name': 'Shoe'},
      },
      () async {
        final res = await _handler().client().get('/item');
        expect(res, hasStatus(200));
        expect(res.text, contains('item Shoe'));
      },
    );
  });

  test('httpOverrides on the client, requests recorded', () async {
    final mock = MockTransport.fixtures({
      '$_base/items/*': ThorHttpFixture.json({'name': 'Hat'}),
    });
    final res = await _handler().client(httpOverrides: mock).get('/item');
    expect(res.text, contains('item Hat'));
    expect(mock.requests.single.toString(), 'GET $_base/items/1');
  });

  test('a deferred future is answered too', () async {
    final mock = MockTransport.fixtures({
      'GET $_base/items/2': {'name': 'Cap'},
    });
    final res = await _handler().client(httpOverrides: mock).get('/lazy');
    expect(res.text, contains('lazy Cap'));
  });

  test('an unmatched call fails loudly with method and URL', () async {
    await expectLater(
      withHttpFixtures({'GET $_base/other': 1}, () async {
        await _handler().client().get('/item');
      }),
      throwsA(
        isA<UnmockedHttpRequest>().having(
          (e) => e.toString(),
          'message',
          contains('GET $_base/items/1'),
        ),
      ),
    );
  });

  test('a page that swallows the error still fails the test', () async {
    final client = _handler().client(httpOverrides: MockTransport.fixtures({}));
    await expectLater(
      client.get('/swallow'),
      throwsA(isA<UnmockedHttpRequest>()),
    );
  });

  test('functions, status and json bodies', () async {
    final seen = <Object?>[];
    await withHttpFixtures(
      {
        'POST $_base/cart': (ThorHttpRequest r) {
          seen.add(r.json());
          return ThorHttpFixture.json({'ok': true}, status: 201);
        },
      },
      () async {
        final res = await api.post('$_base/cart', json: {'sku': 'a'});
        expect(res.statusCode, 201);
        expect(res.json(), {'ok': true});
      },
    );
    expect(seen, [
      {'sku': 'a'},
    ]);
  });

  test('without a zone the real client runs (no override leaks)', () async {
    await expectLater(api.get('$_base/x'), throwsA(isA<UpstreamError>()));
  });

  test('record then replay', () async {
    final dir = Directory.systemTemp.createTempSync('thor_http');
    addTearDown(() => dir.deleteSync(recursive: true));
    final server = await HttpServer.bind('127.0.0.1', 0);
    addTearDown(server.close);
    server.listen((r) {
      r.response
        ..headers.contentType = ContentType.json
        ..write('{"name":"Live"}')
        ..close();
    });
    final url = 'http://127.0.0.1:${server.port}/items/1';
    await withHttpMock(
      MockTransport.recorded(dir.path, record: true),
      () async {
        expect((await api.getJson(url))! as Map, {'name': 'Live'});
      },
    );
    expect(dir.listSync(), hasLength(1));
    await server.close(force: true);
    await withHttpMock(
      MockTransport.recorded(dir.path, record: false),
      () async {
        expect((await api.getJson(url))! as Map, {'name': 'Live'});
      },
    );
    // A request that was never recorded names itself.
    await expectLater(
      withHttpMock(MockTransport.recorded(dir.path, record: false), () async {
        await api.getJson('http://127.0.0.1:1/other');
      }),
      throwsA(isA<UnmockedHttpRequest>()),
    );
  });
}
