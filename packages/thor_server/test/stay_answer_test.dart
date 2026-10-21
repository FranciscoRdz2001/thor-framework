// A POST of a `Form(stay: true)` (`x-thor-stay`): the page stays, so a
// redirect back to it is a `200` that carries its flash in headers (no
// cookie, nothing waits for a next page), a failed action keeps its status
// and says its message, and a redirect elsewhere says where to go.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

class _Said implements ActionMessage {
  @override
  String get actionMessage => 'Two things failed.';
}

PageRequest _post(String path, {bool stay = true}) => PageRequest(
  method: HttpMethod.post,
  uri: Uri.parse('http://site.test$path'),
  headers: {
    HttpHeader.host: 'site.test',
    HttpHeader.origin: 'http://site.test',
    HttpHeader.contentType: 'application/x-www-form-urlencoded',
    if (stay) const HttpHeader('x-thor-stay'): '1',
  },
  body: Stream.value(const []),
);

void main() {
  final handler = RouteHandler<String>(
    renderer: _Renderer(),
    onError: (request, error, stack) {},
    routes: [
      PageRoute<String, void>(
        path: '/p',
        build: (s) => 'page',
        actions: {
          'back': (r) => Redirect.back(
            r,
          ).flash('Guardado ✓ 100%', kind: FlashKind.success),
          'plain': (r) => null,
          'away': (r) => const Redirect(RouteUrl('/done')).flash('Moved'),
          'bad': (r) => const ActionResult.fail(422, 'Name is required'),
          'map': (r) => const ActionResult.fail(409, {'error': 'Taken'}),
          'said': (r) => ActionResult.fail(422, _Said()),
          'mute': (r) => const ActionResult.fail(500),
          'fine': (r) => const ActionResult.success('Done'),
        },
      ),
    ],
  );

  test(
    'a redirect back is a 200 with the flash in headers, no cookie',
    () async {
      final r = await handler.handle(_post('/p?/back'));
      expect(r.status, 200);
      expect(r.headers['x-thor-stay'], '1');
      expect(r.headers['x-thor-flash-kind'], 'success');
      expect(
        Uri.decodeComponent(r.headers['x-thor-flash']!),
        'Guardado ✓ 100%',
      );
      expect(r.headers.containsKey('x-thor-location'), isFalse);
      expect(r.cookies.any((c) => c.startsWith('$flashCookie=')), isFalse);
      expect(r.body, isEmpty);
    },
  );

  test('a null answer is the page again, with nothing to say', () async {
    final r = await handler.handle(_post('/p?/plain'));
    expect(r.status, 200);
    expect(r.headers['x-thor-stay'], '1');
    expect(r.headers.containsKey('x-thor-flash'), isFalse);
  });

  test(
    'a redirect elsewhere says where, and the flash rides the cookie',
    () async {
      final r = await handler.handle(_post('/p?/away'));
      expect(r.status, 200);
      expect(r.headers['x-thor-location'], '/done');
      expect(r.headers.containsKey('x-thor-flash'), isFalse);
      expect(r.cookies.any((c) => c.startsWith('$flashCookie=')), isTrue);
    },
  );

  test('a failed action keeps its status and answers its message', () async {
    var r = await handler.handle(_post('/p?/bad'));
    expect(r.status, 422);
    expect(r.headers['x-thor-flash-kind'], 'error');
    expect(Uri.decodeComponent(r.headers['x-thor-flash']!), 'Name is required');
    expect(r.body, isEmpty);
    r = await handler.handle(_post('/p?/map'));
    expect(r.status, 409);
    expect(Uri.decodeComponent(r.headers['x-thor-flash']!), 'Taken');
    r = await handler.handle(_post('/p?/said'));
    expect(
      Uri.decodeComponent(r.headers['x-thor-flash']!),
      'Two things failed.',
    );
  });

  test('a failure with no message says the generic one', () async {
    final r = await handler.handle(_post('/p?/mute'));
    expect(r.status, 500);
    expect(r.headers['x-thor-flash-kind'], 'error');
    expect(r.headers['x-thor-flash'], isNotEmpty);
  });

  test('a success result says its message as a success', () async {
    final r = await handler.handle(_post('/p?/fine'));
    expect(r.status, 200);
    expect(r.headers['x-thor-flash-kind'], 'success');
    expect(Uri.decodeComponent(r.headers['x-thor-flash']!), 'Done');
  });

  test('without the header everything is as before', () async {
    var r = await handler.handle(_post('/p?/back', stay: false));
    expect(r.status, 303);
    expect(r.headers['location'], '/p');
    expect(r.cookies.any((c) => c.startsWith('$flashCookie=')), isTrue);
    expect(r.headers.containsKey('x-thor-stay'), isFalse);
    r = await handler.handle(_post('/p?/bad', stay: false));
    expect(r.status, 422);
    expect(utf8.decode(r.body), 'page');
  });
}
