// A POST without an action key (`POST /login`) runs the page's only action;
// with several it still needs `?/name`.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

PageRequest _post(String path, [String body = '']) => PageRequest(
  method: HttpMethod.post,
  uri: Uri.parse('http://site.test$path'),
  headers: const {
    HttpHeader.host: 'site.test',
    HttpHeader.origin: 'http://site.test',
    HttpHeader.contentType: 'application/x-www-form-urlencoded',
  },
  body: Stream.value(utf8.encode(body)),
);

void main() {
  final calls = <String>[];
  FormAction run(String name) => (r) {
    calls.add(name);
    return const ActionResult.fail(422, 'no');
  };

  final handler = RouteHandler<String>(
    renderer: _Renderer(),
    onError: (request, error, stack) {},
    routes: [
      PageRoute<String, void>(
        path: '/one',
        build: (s) => 'one',
        actions: {'signIn': run('signIn')},
      ),
      PageRoute<String, void>(
        path: '/two',
        build: (s) => 'two',
        actions: {'a': run('a'), 'b': run('b')},
      ),
      PageRoute<String, void>(
        path: '/dflt',
        build: (s) => 'dflt',
        actions: {'a': run('a'), 'default': run('default')},
      ),
      PageRoute<String, void>(path: '/none', build: (s) => 'none'),
    ],
  );

  setUp(calls.clear);

  test('a post without a key runs the only action', () async {
    final r = await handler.handle(_post('/one'));
    expect(calls, ['signIn']);
    expect(r.status, 422);
  });

  test('the named action still works (old URLs, ?/name strings)', () async {
    await handler.handle(_post('/one?/signIn'));
    expect(calls, ['signIn']);
    expect((await handler.handle(_post('/one?/nope'))).status, 404);
  });

  test('with several actions a keyless post is a 404 and runs none', () async {
    expect((await handler.handle(_post('/two'))).status, 404);
    expect(calls, isEmpty);
    await handler.handle(_post('/two?/b'));
    expect(calls, ['b']);
  });

  test('an action called default wins over being the only other one', () async {
    await handler.handle(_post('/dflt'));
    expect(calls, ['default']);
  });

  test('a page without actions is still a 405', () async {
    expect((await handler.handle(_post('/none'))).status, 405);
  });

  test('the origin check runs before the only action', () async {
    final r = await handler.handle(
      PageRequest(
        method: HttpMethod.post,
        uri: Uri.parse('http://site.test/one'),
        headers: const {
          HttpHeader.host: 'site.test',
          HttpHeader.origin: 'http://evil.test',
          HttpHeader.contentType: 'application/x-www-form-urlencoded',
        },
        body: Stream.value(utf8.encode('')),
      ),
    );
    expect(r.status, 403);
    expect(calls, isEmpty);
  });
}
