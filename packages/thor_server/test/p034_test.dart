// THOR-P034: a query that throws something that is not an HttpError answers a
// generic 500; only under `thor dev` the detail says why. Whatever is thrown
// (a String, an Error, an Exception) and never an HttpError.
import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

/// Draws pages and knows the app's calls: `Admin.stats` shows only on the
/// home page of an admin, `Other.thing` only on `/other`.
class _Renderer implements PageRenderer<String>, ServerQueries, ServerCallIds {
  @override
  ServerMessages get serverMessages => const ServerMessages();

  int renders = 0;
  final _used = Expando<Set<String>>();

  static const declared = {'Boom.it'};
  Object? toThrow;

  @override
  bool declaresCall(String id) => declared.contains(id);

  @override
  List<int> render(String page, RenderContext context) {
    renders++;
    _used[context] = {if (page == 'home') 'Boom.it'};
    return utf8.encode(page);
  }

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';

  @override
  Set<String> queriesFound(RenderContext context) => _used[context] ?? {};

  @override
  List<(Object, StackTrace)> queryErrorsFound(RenderContext context) => [];

  @override
  Future<Object?> runQuery(PageRequest request, String id, Object? arg) async =>
      throw toThrow!;
}

PageRequest _call(String path, String id, {String cookie = ''}) => PageRequest(
  method: HttpMethod.post,
  uri: Uri.parse('http://site.test$path'),
  headers: {
    HttpHeader.host: 'site.test',
    HttpHeader.origin: 'http://site.test',
    HttpHeader.contentType: 'application/json',
    const HttpHeader('x-thor-query'): id,
    if (cookie.isNotEmpty) HttpHeader.cookie: cookie,
  },
  body: Stream.value(utf8.encode('{}')),
);

void main() {
  late _Renderer renderer;
  late RouteHandler<String> handler;

  setUp(() {
    renderer = _Renderer();
    handler = RouteHandler<String>(
      renderer: renderer,
      routes: [PageRoute<String, void>(build: (_) => 'home')],
    );
  });

  final was = ThorDev.enabled;
  tearDown(() => ThorDev.enabled = was);

  final throwables = <String, Object>{
    'a String': 'secret string detail',
    'an Error': ArgumentError('secret error detail'),
    'an Exception': const FormatException('secret exception detail'),
  };

  for (final MapEntry(:key, :value) in throwables.entries) {
    test('$key: release sends a generic 500, nothing of it', () async {
      ThorDev.enabled = false;
      renderer.toThrow = value;
      final r = await handler.handle(_call('/', 'Boom.it'));
      expect(r.status, 500);
      expect(r.text, isNot(contains('secret')));
      expect(r.text, isNot(contains('detail')));
      expect(r.text, isNot(contains('THOR-P034')));
    });

    test('$key: thor dev says THOR-P034 in the detail', () async {
      ThorDev.enabled = true;
      renderer.toThrow = value;
      final r = await handler.handle(_call('/', 'Boom.it'));
      expect(r.status, 500);
      final body = jsonDecode(r.text) as Map;
      expect(body['detail'], contains('THOR-P034'));
      expect(body['error'], isNot(contains('secret')));
    });
  }

  test('an HttpError and an UpstreamError never say THOR-P034', () async {
    ThorDev.enabled = true;
    for (final e in <Object>[
      const HttpError(418, 'teapot'),
      UpstreamError(
        502,
        method: HttpMethod.get,
        uri: Uri.parse('http://b.test/x?token=1'),
        reason: 'secret upstream reason',
      ),
    ]) {
      renderer.toThrow = e;
      final r = await handler.handle(_call('/', 'Boom.it'));
      expect(r.text, isNot(contains('THOR-P034')), reason: '$e');
      expect(r.text, isNot(contains('secret')), reason: '$e');
    }
  });
}
