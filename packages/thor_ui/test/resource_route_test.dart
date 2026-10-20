import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

class _Home extends ThorPage<void> {
  const _Home();

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      const Text('home');
}

var _cancelled = false;

Future<ThorResponse> _guard(PageRequest request, Next next) {
  if (request.headers['x-auth'] == null) {
    throw const Redirect.found(RouteUrl('/login'));
  }
  return next();
}

void main() {
  final dataRoute = ThorRoute<void>.resource(
    '/api/items/:id:int',
    (request) => ThorResponse.json({
      'id': request.paramInt('id'),
    }, maxAge: const Duration(seconds: 60)),
  );
  final agentRoute = ThorRoute<void>.resource('/api/agent/:tool', (
    request,
  ) async {
    final body = await request.text();
    return ThorResponse.json({
      'tool': request.param('tool'),
      'method': request.method.name,
      'in': body.isEmpty ? null : jsonDecode(body),
    });
  }, methods: {HttpMethod.post, HttpMethod.delete});
  final router = ThorRouter([
    ThorRoute('/', const _Home()),
    dataRoute,
    agentRoute,
    ThorRoute<void>.stream('/events', (request) async* {
      try {
        yield const ServerEvent('hello');
        await Completer<void>().future; // never ends
      } finally {
        _cancelled = true;
      }
    }, heartbeat: const Duration(seconds: 5)),
    Group(
      middleware: [_guard],
      children: [
        ThorRoute<void>.resource(
          '/private.json',
          (request) => ThorResponse.json({'secret': 1}, private: true),
        ),
      ],
    ),
  ]);
  final handler = RouteHandler<Widget>(
    renderer: WidgetRenderer(),
    onError: (request, error, stack) {},
    routes: router.routes,
  );

  Future<ThorResponse> send(
    String path, {
    HttpMethod method = HttpMethod.get,
    Map<HttpHeader, String> headers = const {},
    String? body,
  }) => handler.handle(
    PageRequest(
      method: method,
      uri: Uri.parse('http://site.test$path'),
      headers: {HttpHeader.host: 'site.test', ...headers},
      body: body == null ? null : Stream.value(utf8.encode(body)),
    ),
  );

  test('a resource answers its response, with its parameters', () async {
    final r = await send('/api/items/42');
    expect(r.status, 200);
    expect(r.headers['content-type'], startsWith('application/json'));
    expect(r.headers['cache-control'], 'public, max-age=60');
    expect(jsonDecode(r.text), {'id': 42});
  });

  test('a typed parameter that does not fit is a 404 before it runs', () async {
    expect((await send('/api/items/abc')).status, 404);
  });

  test('If-None-Match gets a 304', () async {
    final first = await send('/api/items/1');
    final again = await send(
      '/api/items/1',
      headers: {HttpHeader.ifNoneMatch: first.headers['etag']!},
    );
    expect(again.status, 304);
  });

  test('GET and HEAD only', () async {
    expect((await send('/api/items/1', method: HttpMethod.post)).status, 405);
  });

  test('methods: a resource answers a POST with its JSON body', () async {
    final r = await send(
      '/api/agent/render',
      method: HttpMethod.post,
      body: '{"a":1}',
      headers: {HttpHeader.contentType: 'application/json'},
    );
    expect(r.status, 200);
    expect(jsonDecode(r.text), {
      'tool': 'render',
      'method': 'post',
      'in': {'a': 1},
    });
    // GET stays allowed; a method outside the set is a 405 with Allow.
    expect((await send('/api/agent/render')).status, 200);
    final put = await send('/api/agent/render', method: HttpMethod.put);
    expect(put.status, 405);
    expect(put.headers['allow'], 'GET, HEAD, POST, DELETE');
    expect(
      (await send('/api/agent/x', method: HttpMethod.delete, body: '1')).status,
      200,
    );
  });

  test('a cross-site POST to a resource is refused', () async {
    final r = await send(
      '/api/agent/render',
      method: HttpMethod.post,
      body: '{}',
      headers: {const HttpHeader('origin'): 'http://evil.test'},
    );
    expect(r.status, 403);
  });

  test('a resource with no methods keeps GET and HEAD only', () {
    expect(dataRoute.methods, isEmpty);
  });

  test('link() builds its URL and a resource is not a page to list', () {
    expect(dataRoute.link({'id': 7}), '/api/items/7');
    expect(router.staticPaths, ['/']);
    expect(router.pages.map((p) => p.path), ['/']);
  });

  test('the guards of its groups run around it', () async {
    final denied = await send('/private.json');
    expect(denied.status, 302);
    final ok = await send(
      '/private.json',
      headers: {const HttpHeader('x-auth'): '1'},
    );
    expect(ok.status, 200);
    expect(ok.headers['cache-control'], startsWith('private'));
  });

  test(
    'stream(): an event stream response whose source is the function',
    () async {
      final r = await send('/events');
      expect(r.status, 200);
      expect(r.headers['content-type'], startsWith('text/event-stream'));
      final it = StreamIterator(r.stream!);
      expect(await it.moveNext(), isTrue); // the first comment
      expect(await it.moveNext(), isTrue);
      expect(utf8.decode(it.current), 'data: hello\n\n');
      await it.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(_cancelled, isTrue, reason: 'cancelling reaches the function');
    },
  );
}
