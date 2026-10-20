// A query id that a route's render did not show is remembered as missing so
// a call can't make the server draw the page again and again. The mark
// belongs to the visitor who asked and expires: a real query that only
// another visitor's page shows (an admin's) is not blocked for them.
import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/src/handler.dart' show learnWindow;
import 'package:thor_server/thor_server.dart';

/// Draws pages and knows the app's calls: `Admin.stats` shows only on the
/// home page of an admin, `Other.thing` only on `/other`.
class _Renderer implements PageRenderer<String>, ServerQueries, ServerCallIds {
  @override
  ServerMessages get serverMessages => const ServerMessages();

  int renders = 0;
  final _used = Expando<Set<String>>();

  static const declared = {'Admin.stats', 'Public.list', 'Other.thing'};

  @override
  bool declaresCall(String id) => declared.contains(id);

  @override
  List<int> render(String page, RenderContext context) {
    renders++;
    final r = context.request;
    _used[context] = {
      if (page == 'home') 'Public.list',
      if (page == 'home' && r.locals['admin'] == true) 'Admin.stats',
      if (page == 'other') 'Other.thing',
    };
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
      'value of $id';
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
      onRequest: (r) => r.locals['admin'] = r.cookies['role'] == 'admin',
      routes: [
        PageRoute<String, void>(build: (_) => 'home'),
        PageRoute<String, void>(path: 'other', build: (_) => 'other'),
      ],
    );
  });

  test('an admin gets the query a visitor asked for first', () async {
    final visitor = await handler.handle(_call('/', 'Admin.stats'));
    expect(visitor.status, 404);
    final admin = await handler.handle(
      _call('/', 'Admin.stats', cookie: 'role=admin'),
    );
    expect(admin.status, 200);
    expect(admin.text, contains('value of Admin.stats'));
  });

  test('the same visitor asking again does not draw the page again', () async {
    await handler.handle(_call('/', 'Admin.stats', cookie: 'sid=a'));
    final after = renderer.renders;
    for (var i = 0; i < 30; i++) {
      final r = await handler.handle(
        _call('/', 'Admin.stats', cookie: 'sid=a'),
      );
      expect(r.status, 404);
    }
    expect(renderer.renders, after);
  });

  test('70 made-up ids draw nothing', () async {
    for (var i = 0; i < 70; i++) {
      final r = await handler.handle(
        _call('/', 'Nope.made$i', cookie: 'sid=$i'),
      );
      expect(r.status, 404);
    }
    expect(renderer.renders, 0);
  });

  test(
    'a real id of another route draws once per visitor per window',
    () async {
      learnWindow = const Duration(milliseconds: 150);
      addTearDown(() => learnWindow = const Duration(seconds: 10));
      for (var i = 0; i < 20; i++) {
        expect((await handler.handle(_call('/', 'Other.thing'))).status, 404);
      }
      expect(renderer.renders, 1);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      for (var i = 0; i < 20; i++) {
        expect((await handler.handle(_call('/', 'Other.thing'))).status, 404);
      }
      expect(renderer.renders, 2, reason: 'the mark expired: once more');
    },
  );

  test(
    'visitors rotating cookies draw at most a few pages per window',
    () async {
      for (var i = 0; i < 200; i++) {
        await handler.handle(_call('/', 'Other.thing', cookie: 'sid=$i'));
      }
      expect(renderer.renders, lessThanOrEqualTo(8));
    },
  );

  test('a page drawn for the admin teaches the route for good', () async {
    await handler.handle(_call('/', 'Admin.stats', cookie: 'role=admin'));
    final after = renderer.renders;
    // Learned in this isolate: no more drawing for anyone.
    for (var i = 0; i < 10; i++) {
      await handler.handle(_call('/', 'Admin.stats', cookie: 'role=admin'));
    }
    expect(renderer.renders, after);
  });
}
