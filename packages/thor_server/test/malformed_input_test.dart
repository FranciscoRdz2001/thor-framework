// Malformed input from the client (invalid UTF-8 or a broken percent
// escape in the query or a form body) is the client's error: a 400, never
// a 500 reported as a server failure.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

void main() {
  late List<Object> errors;
  late RouteHandler<String> handler;

  setUp(() {
    errors = [];
    handler = RouteHandler<String>(
      renderer: _Renderer(),
      onError: (request, error, stack) => errors.add(error),
      routes: [
        PageRoute<String, String>(
          path: 'echo',
          load: (r) => r.queryParameters['q'] ?? '',
          build: (s) => 'q=${s.data}',
          actions: {
            'send': (r) async =>
                ActionResult.fail(422, (await r.form())['text'] ?? ''),
          },
        ),
      ],
    );
  });

  Future<ThorResponse> post(List<int> body) => handler.handle(
    PageRequest(
      method: HttpMethod.post,
      uri: Uri.parse('http://site.test/echo?/send'),
      headers: const {
        HttpHeader.host: 'site.test',
        HttpHeader.origin: 'http://site.test',
        HttpHeader.contentType: 'application/x-www-form-urlencoded',
      },
      body: Stream.value(body),
    ),
  );

  Future<ThorResponse> get(String query) => handler.handle(
    PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://site.test/echo?$query'),
      headers: const {HttpHeader.host: 'site.test'},
    ),
  );

  test('a query with invalid UTF-8 is a 400', () async {
    expect((await get('q=%FF%FE')).status, 400);
    // A broken escape: `Uri.parse` keeps it as text.
    expect((await get('q=%zz')).text, 'q=%zz');
    expect(errors, isEmpty);
  });

  test('queryParametersAll keeps repeated keys; queryParameters the last', () {
    final r = PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://site.test/echo?f=a&f=b%20c&q=1'),
      headers: const {HttpHeader.host: 'site.test'},
    );
    expect(r.queryParametersAll, {
      'f': ['a', 'b c'],
      'q': ['1'],
    });
    expect(r.queryParameters['f'], 'b c');
    final bad = PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://site.test/echo?q=%FF%FE'),
      headers: const {HttpHeader.host: 'site.test'},
    );
    expect(
      () => bad.queryParametersAll,
      throwsA(isA<HttpError>().having((e) => e.status, 'status', 400)),
    );
  });

  test('a form body with invalid UTF-8 or a broken escape is a 400', () async {
    for (final body in [
      utf8.encode('text=%FF%FE'),
      utf8.encode('text=%zz'),
      [...utf8.encode('text='), 0xFF, 0xFE],
    ]) {
      expect((await post(body)).status, 400, reason: '$body');
    }
    expect(errors, isEmpty);
  });

  test('well-formed input still works', () async {
    final r = await handler.handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://site.test/echo?q=%F0%9F%98%80+%D7%A9'),
        headers: const {HttpHeader.host: 'site.test'},
      ),
    );
    expect(r.text, 'q=😀 ש');
    expect((await post(utf8.encode('text=caf%C3%A9'))).status, 422);
  });

  test('a path with invalid UTF-8 is a 404, not a 500', () async {
    final r = await handler.handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://site.test/%FF'),
        headers: const {HttpHeader.host: 'site.test'},
      ),
    );
    expect(r.status, 404);
    expect(errors, isEmpty);
  });

  test('a cookie with invalid UTF-8 is kept as written', () async {
    final r = await handler.handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://site.test/echo?q=1'),
        headers: const {
          HttpHeader.host: 'site.test',
          HttpHeader.cookie: 'x=%FF; y=%zz',
        },
      ),
    );
    expect(r.status, 200);
    expect(parseCookies('x=%FF; y=%E2%82%AC'), {'x': '%FF', 'y': '€'});
  });

  test('an action URL with invalid UTF-8 in its query is a 400', () async {
    final r = await handler.handle(
      PageRequest(
        method: HttpMethod.post,
        uri: Uri.parse('http://site.test/echo?/send&%FF=1'),
        headers: const {
          HttpHeader.host: 'site.test',
          HttpHeader.origin: 'http://site.test',
          HttpHeader.contentType: 'application/x-www-form-urlencoded',
        },
        body: Stream.value(utf8.encode('text=a')),
      ),
    );
    expect(r.status, 400);
    expect(errors, isEmpty);
  });
}
