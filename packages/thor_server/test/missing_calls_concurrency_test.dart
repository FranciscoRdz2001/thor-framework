// Calls that arrive together on an isolate that has not drawn the page yet
// (the page loaded on another isolate): each one is a real query of the
// page, so none may be answered 404 just because the first is still drawing.
import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

final _ids = [for (var i = 0; i < 14; i++) 'Data.q$i'];

class _Renderer implements PageRenderer<String>, ServerQueries, ServerCallIds {
  @override
  ServerMessages get serverMessages => const ServerMessages();

  _Renderer({Set<String>? shows}) : _shows = shows ?? {..._ids};

  final Set<String> _shows;
  int renders = 0;
  final _used = Expando<Set<String>>();

  @override
  bool declaresCall(String id) => _ids.contains(id);

  @override
  List<int> render(String page, RenderContext context) {
    renders++;
    _used[context] = {..._shows};
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
      'value of $id $arg';
}

PageRequest _call(String id, {Object? arg = 0, String cookie = 'sid=a'}) =>
    PageRequest(
      method: HttpMethod.post,
      uri: Uri.parse('http://site.test/'),
      headers: {
        HttpHeader.host: 'site.test',
        HttpHeader.origin: 'http://site.test',
        HttpHeader.contentType: 'application/json',
        const HttpHeader('x-thor-query'): id,
        HttpHeader.cookie: cookie,
      },
      body: Stream.value(utf8.encode(jsonEncode({'arg': arg}))),
    );

/// How long a load takes: the calls of a test are all issued in one turn,
/// and this keeps the first drawing in flight while they are (wide, so a
/// loaded machine does not let it end before the last one starts).
const _overlap = Duration(milliseconds: 250);

RouteHandler<String> _handler(_Renderer renderer) => RouteHandler<String>(
  renderer: renderer,
  routes: [
    PageRoute<String, void>(
      load: (_) => Future<void>.delayed(_overlap),
      build: (_) => 'home',
    ),
  ],
);

void main() {
  test('14 different queries of the page at once all answer', () async {
    final renderer = _Renderer();
    final h = _handler(renderer);
    final answers = await Future.wait([
      for (final id in _ids) h.handle(_call(id)),
    ]);
    expect(answers.map((r) => r.status), everyElement(200));
    expect(renderer.renders, 1, reason: 'one drawing serves them all');
  });

  test('the same query twice at once (other args) both answer', () async {
    final renderer = _Renderer();
    final h = _handler(renderer);
    final answers = await Future.wait([
      h.handle(_call('Data.q0', arg: 1)),
      h.handle(_call('Data.q0', arg: 2)),
    ]);
    expect(answers.map((r) => r.status), [200, 200]);
    expect(renderer.renders, 1);
  });

  test(
    '50 calls of one visitor at once for a real id: one drawing, all answer',
    () async {
      final renderer = _Renderer();
      final h = RouteHandler<String>(
        renderer: renderer,
        routes: [
          PageRoute<String, void>(
            path: 'other',
            load: (_) => Future<void>.delayed(_overlap),
            build: (_) => 'other',
          ),
        ],
      );
      PageRequest onOther() => PageRequest(
        method: HttpMethod.post,
        uri: Uri.parse('http://site.test/other'),
        headers: {
          HttpHeader.host: 'site.test',
          HttpHeader.origin: 'http://site.test',
          HttpHeader.contentType: 'application/json',
          const HttpHeader('x-thor-query'): 'Data.q0',
          HttpHeader.cookie: 'sid=a',
        },
        body: Stream.value(utf8.encode('{}')),
      );
      // This renderer shows every id, so it is found: all 200, one drawing.
      final answers = await Future.wait([
        for (var i = 0; i < 50; i++) h.handle(onOther()),
      ]);
      expect(answers.map((r) => r.status), everyElement(200));
      expect(renderer.renders, 1);
    },
  );

  test(
    '50 calls at once for an id the page does not show: one drawing',
    () async {
      final renderer = _Renderer(shows: {'Data.q1'});
      final h = _handler(renderer);
      final answers = await Future.wait([
        for (var i = 0; i < 50; i++) h.handle(_call('Data.q0')),
      ]);
      expect(answers.map((r) => r.status), everyElement(404));
      expect(renderer.renders, 1);
    },
  );

  test('a drawing that throws does not leave the visitor stuck', () async {
    var fail = true;
    final renderer = _Renderer();
    final h = RouteHandler<String>(
      renderer: renderer,
      routes: [
        PageRoute<String, void>(
          load: (_) async {
            await Future<void>.delayed(_overlap);
            if (fail) throw StateError('boom');
          },
          build: (_) => 'home',
        ),
      ],
      onError: (_, _, _) {},
    );
    final first = await Future.wait([
      h.handle(_call('Data.q0')),
      h.handle(_call('Data.q0')),
    ]);
    expect(first.map((r) => r.status), everyElement(isNot(200)));
    fail = false;
    // The mark of the failed drawing may hold it back for the window; a
    // visitor with another cookie is not held.
    final other = await h.handle(_call('Data.q0', cookie: 'sid=b'));
    expect(other.status, 200);
  });
}
