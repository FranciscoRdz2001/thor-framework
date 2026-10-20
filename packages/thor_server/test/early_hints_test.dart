import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

/// Links one shared stylesheet (like `WidgetRenderer(shareStyles: true)`)
/// and writes the robots meta, so a late error page can be checked.
class _Renderer implements PageRenderer<String>, EarlyHints {
  _Renderer({this.links = const [LinkHint.style('/_thor/base.abc.css')]});

  final List<LinkHint> links;

  @override
  List<int> render(String page, RenderContext context) => utf8.encode(
    '<!DOCTYPE html><html><head>'
    '${context.meta.robotsContent == null ? '' : '<meta name="robots" content="${context.meta.robotsContent}">'}'
    '<link rel="stylesheet" href="/_thor/base.abc.css"></head>'
    '<body>$page</body></html>',
  );

  @override
  String errorPage(ErrorState state) => 'plain error ${state.status}';

  @override
  List<LinkHint> linksFor(
    PageRequest request,
    List<LayoutRoute<Object?, Object?>> layouts,
  ) => links;
}

PageRequest _get(String path) => PageRequest(
  method: HttpMethod.get,
  uri: Uri.parse('http://site.test$path'),
  headers: const {HttpHeader.host: 'site.test'},
);

Future<String> _body(ThorResponse r) async {
  final stream = r.stream;
  if (stream == null) return r.text;
  return utf8.decode([for (final chunk in await stream.toList()) ...chunk]);
}

void main() {
  late Completer<String> data;
  late List<Object> errors;

  RouteHandler<String> handler({
    List<LinkHint> links = const [LinkHint.style('/_thor/base.abc.css')],
    bool? earlyHints = true,
    Duration? cache,
    Loader<String>? load,
    Middleware? middleware,
    // Tests whose data is a Completer that only they complete answer early
    // whatever the load; the ones whose data is there at once must not, so
    // they give a long wait (a stall of a loaded machine is not slow data).
    Duration after = const Duration(milliseconds: 10),
  }) => RouteHandler<String>(
    renderer: _Renderer(links: links),
    onError: (request, error, stack) => errors.add(error),
    earlyHintsAfter: after,
    routes: [
      LayoutRoute<String, void>(
        build: (s, child) => '<main>$child</main>',
        error: (e) => 'error ${e.status}',
        earlyHints: earlyHints,
        middleware: middleware,
        children: [
          PageRoute<String, String>(
            path: 'slow',
            load: load ?? (request) => data.future,
            build: (s) => 'data ${s.data}',
            cache: cache,
          ),
          PageRoute<String, String>(
            path: 'form',
            load: (request) => data.future,
            build: (s) => 'form ${s.data}',
            actions: {
              'default': (request) async => const ActionResult.success(),
            },
          ),
        ],
      ),
    ],
  );

  setUp(() {
    data = Completer();
    errors = [];
  });

  test('data in time: one whole response, its status, ETag and Link', () async {
    data.complete('fast');
    final r = await handler(
      after: const Duration(seconds: 30),
    ).handle(_get('/slow'));
    expect(r.stream, isNull);
    expect(r.status, 200);
    expect(r.headers['etag'], isNotNull);
    expect(r.headers['link'], '</_thor/base.abc.css>; rel=preload; as=style');
    expect(r.text, contains('data fast'));
  });

  test('slow data: status and Link first, then the same document', () async {
    final early = await handler().handle(_get('/slow'));
    expect(early.status, 200);
    expect(early.stream, isNotNull);
    expect(early.headers['link'], contains('/_thor/base.abc.css'));
    // Unknown until the page is rendered.
    expect(early.headers['etag'], isNull);
    final body = _body(early);
    data.complete('late');
    final whole = await body;

    // Byte for byte what the page answers when its data comes in time.
    data = Completer()..complete('late');
    final inTime = await handler(
      after: const Duration(seconds: 30),
    ).handle(_get('/slow'));
    expect(whole, inTime.text);
    expect(errors, isEmpty);
  });

  test('the first chunk is the doctype, never a second one', () async {
    final early = await handler().handle(_get('/slow'));
    final chunks = <String>[];
    final done = early.stream!.listen((c) => chunks.add(utf8.decode(c)));
    await Future<void>.delayed(Duration.zero);
    expect(chunks, ['<!DOCTYPE html>']);
    data.complete('x');
    await done.asFuture<void>();
    await done.cancel();
    expect(chunks.join().indexOf('<!DOCTYPE'), 0);
    expect('<!DOCTYPE'.allMatches(chunks.join()), hasLength(1));
  });

  test('a load that fails after the answer: its error page, noindex', () async {
    final early = await handler().handle(_get('/slow'));
    data.completeError(const NotFound());
    final body = await _body(early);
    expect(early.status, 200);
    expect(body, contains('<main>error 404</main>'));
    expect(body, contains('<meta name="robots" content="noindex">'));
  });

  test('a load that redirects after the answer: a page that redirects', () async {
    final early = await handler().handle(_get('/slow'));
    data.completeError(const Redirect.found(RouteUrl('/login?next="/slow"')));
    final body = await _body(early);
    expect(
      body,
      contains(
        '<meta http-equiv="refresh" content="0;url=/login?next=&quot;/slow&quot;">',
      ),
    );
    expect(body, contains('noindex'));
  });

  test('a cookie after the answer is reported, never sent', () async {
    final early = await handler(
      load: (request) async {
        final value = await data.future;
        request.response.setCookie('late', '1');
        return value;
      },
      middleware: (request, next) {
        request.response.setCookie('early', '1');
        return next();
      },
    ).handle(_get('/slow'));
    data.complete('x');
    await _body(early);
    expect(early.cookies.single, startsWith('early=1'));
    expect(errors.single.toString(), contains('THOR-P010'));
  });

  test('a middleware still adds headers to an early answer', () async {
    final early = await handler(
      middleware: (request, next) async =>
          (await next()).withHeaders({const HttpHeader('x-mw'): 'yes'}),
    ).handle(_get('/slow'));
    expect(early.headers['x-mw'], 'yes');
    expect(early.stream, isNotNull);
    data.complete('x');
    expect(await _body(early), contains('data x'));
  });

  test('never early: without earlyHints, without links, a cached page, '
      'a form action', () async {
    Future<ThorResponse> slow(RouteHandler<String> h, PageRequest request) {
      final r = h.handle(request);
      Timer(const Duration(milliseconds: 40), () {
        if (!data.isCompleted) data.complete('x');
      });
      return r;
    }

    expect(
      (await slow(handler(earlyHints: null), _get('/slow'))).stream,
      isNull,
    );
    data = Completer();
    expect(
      (await slow(handler(links: const []), _get('/slow'))).stream,
      isNull,
    );
    data = Completer();
    expect(
      (await slow(
        handler(cache: const Duration(seconds: 10)),
        _get('/slow'),
      )).stream,
      isNull,
    );
    data = Completer();
    final post = PageRequest(
      method: HttpMethod.post,
      uri: Uri.parse('http://site.test/form'),
      headers: const {
        HttpHeader.host: 'site.test',
        HttpHeader.origin: 'http://site.test',
        HttpHeader.contentType: 'application/x-www-form-urlencoded',
      },
      body: Stream.value(utf8.encode('a=1')),
    );
    expect((await slow(handler(), post)).stream, isNull);
  });

  test('Link entries: fonts in CORS mode, nothing that forges a header', () {
    expect(
      const LinkHint.font('/f/geist.woff2').header,
      '</f/geist.woff2>; rel=preload; as=font; type=font/woff2; crossorigin',
    );
    for (final bad in ['/a>b', '/a,b', '/a;b', '/a\r\nx: y', '/a b']) {
      expect(() => LinkHint.style(bad).header, throwsArgumentError);
    }
    expect(
      () => const LinkHint('/a', as: 'style\r\nx').header,
      throwsArgumentError,
    );
  });

  test(
    'over HTTP: the headers arrive before the page, gzip reads whole',
    () async {
      final server = ThorServer(handler: handler(), compress: true);
      final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      http.listen(server.handleHttp);
      final client = HttpClient();
      try {
        final request = await client.get('127.0.0.1', http.port, '/slow');
        request.headers.set('accept-encoding', 'gzip');
        // Headers only: the data is still loading.
        final response = await request.close().timeout(
          const Duration(seconds: 5),
        );
        expect(data.isCompleted, isFalse);
        expect(response.statusCode, 200);
        expect(response.headers.value('link'), contains('/_thor/base.abc.css'));
        expect(response.headers.value('content-encoding'), 'gzip');
        data.complete('over http');
        final text = await utf8.decodeStream(response);
        expect(text, contains('<main>data over http</main>'));
        expect(text, startsWith('<!DOCTYPE html><html>'));
      } finally {
        client.close(force: true);
        await http.close(force: true);
      }
    },
  );

  test(
    'a hundred font hints cannot blow the Link header past the budget',
    () async {
      data.complete('fast');
      final links = [
        const LinkHint.style('/_thor/base.abc.css'),
        for (var i = 0; i < 100; i++)
          LinkHint.font('/fonts/a-family-with-a-rather-long-name-$i.woff2'),
      ];
      final r = await handler(
        links: links,
        after: const Duration(seconds: 30),
      ).handle(_get('/slow'));
      final link = r.headers['link']!;
      // Proxies read response headers into one small buffer (nginx: 4-8 KB for
      // all of them): a Link of tens of KB turns the page into a 502.
      expect(link.length, lessThanOrEqualTo(2000));
      expect(link, startsWith('</_thor/base.abc.css>; rel=preload; as=style'));
      expect(link, contains('a-family-with-a-rather-long-name-0.woff2'));
      expect(link, isNot(contains('name-99.woff2')));
      // Whole entries only: no hint cut in the middle.
      expect(
        link.split(', ').every((h) => h.startsWith('<') && h.contains('rel=')),
        isTrue,
      );
    },
  );

  test('the early answer keeps to the budget too', () async {
    final links = [
      for (var i = 0; i < 100; i++)
        LinkHint.font('/fonts/a-family-with-a-rather-long-name-$i.woff2'),
    ];
    final early = await handler(links: links).handle(_get('/slow'));
    expect(early.stream, isNotNull);
    expect(early.headers['link']!.length, lessThanOrEqualTo(2000));
    data.complete('x');
    await _body(early);
  });
}
