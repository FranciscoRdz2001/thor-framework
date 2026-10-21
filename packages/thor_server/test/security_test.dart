@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:test/test.dart';
import 'package:thor_server/src/csp.dart' show NonceInjector, cspNonceToken;
import 'package:thor_server/src/host_check.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

class _TokenRenderer implements PageRenderer<String> {
  _TokenRenderer(this.onToken);

  final void Function(String? token) onToken;

  @override
  List<int> render(String page, RenderContext context) {
    onToken(context.cspNonceToken);
    return utf8.encode(page);
  }

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

PageRequest _get(String path) => PageRequest(
  method: HttpMethod.get,
  uri: Uri.parse('http://site.test$path'),
  headers: {HttpHeader.host: 'site.test'},
);

String _html(ThorResponse r) => utf8.decode(r.body);

String? _header(ThorResponse r, String name) => r.headers.entries
    .where((e) => e.key.toLowerCase() == name)
    .map((e) => e.value)
    .firstOrNull;

const _page =
    '<html><head><style>a{}</style><script>var x="<script>";</script>'
    '<script src="/e.js"></script></head><body><p>hi</p></body></html>';

void main() {
  group('CSP header', () {
    test('default policy: strict, with the nonce in script and style', () {
      final v = const ContentSecurityPolicy().headerValue('N0NCE');
      expect(v, contains("default-src 'self'"));
      expect(v, contains("script-src 'self' 'nonce-N0NCE'"));
      expect(v, contains("style-src 'self' 'nonce-N0NCE'"));
      expect(v, contains("style-src-attr 'unsafe-inline'"));
      expect(v, contains("object-src 'none'"));
      expect(v, contains("frame-ancestors 'none'"));
      expect(v, isNot(contains('script-src-attr')));
    });

    test('a null script-src keeps falling back to default-src + nonce', () {
      final v = const ContentSecurityPolicy(
        scriptSrc: null,
        defaultSrc: [CspSource.self, CspSource.data],
      ).headerValue('abc');
      expect(v, contains("script-src 'self' data: 'nonce-abc'"));
    });

    test('report-only changes the header name, not the nonce', () {
      final policy = ContentSecurityPolicy(
        reportOnly: true,
        reportUri: Uri(path: '/csp;evil-directive x'),
      );
      expect(policy.headerName, 'content-security-policy-report-only');
      final v = policy.headerValue('n');
      expect(v, contains("'nonce-n'"));
      // A report-uri cannot smuggle a directive.
      expect(v, endsWith('report-uri /cspevil-directive%20x'));
    });

    test('typed sources refuse what would end the directive', () {
      expect(() => CspSource.host('a.com; script-src *'), throwsArgumentError);
      expect(
        () => CspSource.host("a.com 'unsafe-inline'"),
        throwsArgumentError,
      );
      expect(() => CspSource.scheme('ht tp'), throwsArgumentError);
      expect(
        () => CspSource.hash(CspHashAlgorithm.sha256, "x'; y"),
        throwsArgumentError,
      );
      expect(
        CspSource.host('https://cdn.example.com').value,
        'https://cdn.example.com',
      );
      expect(CspSource.scheme('HTTPS').value, 'https:');
    });
  });

  group('hashes instead of a nonce', () {
    String digest(String text) =>
        base64.encode(sha256.convert(utf8.encode(text)).bytes);
    const policy = ContentSecurityPolicy(nonce: false, hashes: true);
    const page =
        '<html><head><style>a{}</style><script>var x="<script>";</script>'
        '<script src="/e.js"></script>'
        '<script type="application/ld+json">{"a":1}</script>'
        '<script type="speculationrules">{"prefetch":[]}</script>'
        '</head><body><p>hi</p></body></html>';

    ThorResponse html(String body, {String etag = '"h1"'}) => ThorResponse(
      200,
      headers: {
        HttpHeader.contentType: 'text/html; charset=utf-8',
        HttpHeader.etag: etag,
        HttpHeader.cacheControl: 'public, max-age=60',
      },
      body: utf8.encode(body),
    );

    test('the header lists the hash of each inline script and style', () async {
      final request = _get('/');
      final response = await contentSecurityPolicy(policy)(
        request,
        () async => html(page),
      );
      final v = _header(response, 'content-security-policy')!;
      expect(request.cspNonce, isNull);
      expect(
        v,
        contains(
          "script-src 'self' "
          "'sha256-${digest('var x="<script>";')}' "
          "'sha256-${digest('{"prefetch":[]}')}'",
        ),
      );
      expect(v, contains("style-src 'self' 'sha256-${digest('a{}')}'"));
      expect(v, isNot(contains('nonce')));
      expect(v, isNot(contains(digest('{"a":1}'))));
    });

    test('the page stays public and keeps its ETag and body', () async {
      final response = await contentSecurityPolicy(policy)(
        _get('/'),
        () async => html(page, etag: '"h2"'),
      );
      expect(_header(response, 'cache-control'), 'public, max-age=60');
      expect(_header(response, 'etag'), '"h2"');
      expect(_html(response), page);
    });

    test('a streamed page is read whole', () async {
      final response = await contentSecurityPolicy(policy)(
        _get('/'),
        () async => ThorResponse(
          200,
          headers: {HttpHeader.contentType: 'text/html; charset=utf-8'},
          stream: Stream.fromIterable([
            utf8.encode('<style>b{}</st'),
            utf8.encode('yle><p>x</p>'),
          ]),
        ),
      );
      expect(
        _header(response, 'content-security-policy'),
        contains("'sha256-${digest('b{}')}'"),
      );
      expect(_html(response), '<style>b{}</style><p>x</p>');
    });

    test('hashes need nonce: false', () {
      expect(() => ContentSecurityPolicy(hashes: true), throwsA(anything));
    });
  });

  group('nonce in the HTML', () {
    // What Thor's renderer writes: the placeholder as the nonce of its own
    // elements. `_page` below also holds markup it did not emit.
    final t = cspNonceToken;
    final own =
        '<html><head><style nonce="$t">a{}</style>'
        '<script nonce="$t">var x="<script>";</script>'
        '<script nonce="$t" src="/e.js"></script></head>'
        '<body><p>hi</p></body></html>';

    ThorResponse html(String body) => ThorResponse(
      200,
      headers: {
        HttpHeader.contentType: 'text/html; charset=utf-8',
        HttpHeader.etag: '"x"',
      },
      body: utf8.encode(body),
    );

    test('every element Thor emitted carries the request nonce', () async {
      final mw = contentSecurityPolicy();
      final request = _get('/');
      final response = await mw(request, () async => html(own));
      final nonce = request.cspNonce!;
      final body = _html(response);
      expect(
        _header(response, 'content-security-policy'),
        contains("'nonce-$nonce'"),
      );
      expect(body, contains('<style nonce="$nonce">'));
      expect(body, contains('<script nonce="$nonce" src="/e.js">'));
      expect(body, isNot(contains(t)));
      expect(RegExp('nonce=').allMatches(body), hasLength(3));
    });

    test('markup Thor did not emit gets no nonce (forged or not)', () async {
      final mw = contentSecurityPolicy();
      final request = _get('/');
      final injected =
          '<p><script>alert(1)</script><script src=//evil></script>'
          '<style>*{}</style><script nonce="guess">1</script></p>$own';
      final body = _html(await mw(request, () async => html(injected)));
      final nonce = request.cspNonce!;
      expect(body, contains('<p><script>alert(1)</script>'));
      expect(body, contains('<script src=//evil></script>'));
      expect(body, contains('<style>*{}</style>'));
      expect(body, contains('<script nonce="guess">1</script>'));
      expect(
        RegExp(RegExp.escape('nonce="$nonce"')).allMatches(body),
        hasLength(3),
      );
    });

    test('a page asks for the placeholder only under the policy', () async {
      String? seen;
      final handler = RouteHandler<String>(
        renderer: _TokenRenderer((t) => seen = t),
        routes: [
          PageRoute<String, void>(path: 'plain', build: (s) => 'p'),
          LayoutRoute<String, void>(
            build: (s, child) => child,
            error: (e) => 'error',
            middleware: contentSecurityPolicy(),
            children: [PageRoute<String, void>(path: 'csp', build: (s) => 'p')],
          ),
        ],
      );
      await handler.handle(_get('/plain'));
      expect(seen, isNull);
      await handler.handle(_get('/csp'));
      expect(seen, cspNonceToken);
      expect(cspNonceToken.length, greaterThan(30));
    });

    test('each request has its own nonce', () async {
      final mw = contentSecurityPolicy();
      final seen = <String>{};
      for (var i = 0; i < 20; i++) {
        final request = _get('/');
        await mw(request, () async => ThorResponse(200));
        seen.add(request.cspNonce!);
      }
      expect(seen, hasLength(20));
      expect(seen.every((n) => n.length >= 22), isTrue);
    });

    test('a page from the cache gets a new nonce every time', () async {
      final handler = RouteHandler<String>(
        renderer: _Renderer(),
        routes: [
          LayoutRoute<String, void>(
            build: (s, child) => child,
            error: (e) => 'error',
            middleware: contentSecurityPolicy(),
            children: [
              PageRoute<String, void>(
                build: (s) => own,
                cache: const Duration(minutes: 1),
              ),
            ],
          ),
        ],
      );
      final a = await handler.handle(_get('/'));
      final b = await handler.handle(_get('/'));
      String nonceOf(ThorResponse r) =>
          RegExp(r'<script nonce="([^"]+)"').firstMatch(_html(r))![1]!;
      expect(nonceOf(a), isNot(nonceOf(b)));
      expect(_html(b), isNot(contains(cspNonceToken)));
      expect(
        _header(b, 'content-security-policy'),
        contains("'nonce-${nonceOf(b)}'"),
      );
      expect(
        _header(b, 'content-security-policy'),
        isNot(contains(nonceOf(a))),
      );
    });

    test('revalidation never pairs a stored body with a new nonce', () async {
      final handler = RouteHandler<String>(
        renderer: _Renderer(),
        routes: [
          LayoutRoute<String, void>(
            build: (s, child) => child,
            error: (e) => 'error',
            middleware: contentSecurityPolicy(),
            children: [PageRoute<String, void>(build: (s) => own)],
          ),
        ],
      );
      final first = await handler.handle(_get('/'));
      final etag = _header(first, 'etag');
      // No validator: the client has nothing to revalidate with.
      expect(etag, isNull);
      // A client that sends one anyway (a stale tag) gets the full page.
      final again = await handler.handle(
        PageRequest(
          method: HttpMethod.get,
          uri: Uri.parse('http://site.test/'),
          headers: {HttpHeader.host: 'site.test', HttpHeader.ifNoneMatch: '*'},
        ),
      );
      expect(again.status, 200);
      expect(_header(again, 'etag'), isNull);
      final nonce = RegExp(
        r"'nonce-([^']+)'",
      ).firstMatch(_header(again, 'content-security-policy')!)![1];
      expect(_html(again), contains('nonce="$nonce"'));
    });

    test('public caching becomes private', () async {
      final mw = contentSecurityPolicy();
      final response = await mw(
        _get('/'),
        () async => ThorResponse(
          200,
          headers: {
            HttpHeader.contentType: 'text/html',
            HttpHeader.cacheControl: 'public, max-age=60, s-maxage=600',
          },
          body: utf8.encode(own),
        ),
      );
      expect(_header(response, 'cache-control'), 'private, max-age=60');
    });

    test('a response with its own policy is left alone', () async {
      final mw = contentSecurityPolicy();
      final response = await mw(
        _get('/'),
        () async => ThorResponse(
          200,
          headers: {
            const HttpHeader('Content-Security-Policy'): "default-src 'none'",
            HttpHeader.contentType: 'text/html',
          },
          body: utf8.encode(_page),
        ),
      );
      expect(_html(response), _page);
    });

    test('not HTML: header yes, body untouched', () async {
      final mw = contentSecurityPolicy();
      final js = '<script nonce="$t">1</script>';
      final response = await mw(
        _get('/'),
        () async => ThorResponse(
          200,
          headers: {HttpHeader.contentType: 'application/json'},
          body: utf8.encode(js),
        ),
      );
      expect(_html(response), js);
      expect(_header(response, 'content-security-policy'), isNotNull);
    });

    test('a streamed page is stamped, whatever the chunk boundaries', () async {
      final mw = contentSecurityPolicy();
      final request = _get('/');
      final bytes = utf8.encode('$own<p>é</p>');
      final response = await mw(
        request,
        () async => ThorResponse(
          200,
          headers: {HttpHeader.contentType: 'text/html'},
          // 3-byte chunks split the token, and the multi-byte é.
          stream: Stream.fromIterable([
            for (var i = 0; i < bytes.length; i += 3)
              bytes.sublist(i, i + 3 > bytes.length ? bytes.length : i + 3),
          ]),
        ),
      );
      final text = utf8.decode([await for (final c in response.stream!) ...c]);
      final nonce = request.cspNonce!;
      expect(text, contains('<style nonce="$nonce">a{}</style>'));
      expect(text, contains('<script nonce="$nonce" src="/e.js"></script>'));
      expect(text, isNot(contains(cspNonceToken)));
      expect(text, endsWith('<p>é</p>'));
    });

    test('injector: only the exact token, in any chunking', () {
      String run(String html, {int chunk = 1 << 20, String token = 'TOK-123'}) {
        final i = NonceInjector('N', token: token);
        final out = StringBuffer();
        for (var k = 0; k < html.length; k += chunk) {
          out.write(
            i.feed(
              html.substring(
                k,
                k + chunk > html.length ? html.length : k + chunk,
              ),
            ),
          );
        }
        out.write(i.feed('', end: true));
        return out.toString();
      }

      const cases = {
        '<script nonce="TOK-123">1</script>': '<script nonce="N">1</script>',
        '<script>1</script><script nonce="TOK-12">':
            '<script>1</script><script nonce="TOK-12">',
        'TOK-TOK-123 TOK-123TOK-123': 'TOK-N NN',
        '<script nonce="evil">1</script>': '<script nonce="evil">1</script>',
      };
      for (final MapEntry(:key, :value) in cases.entries) {
        for (final chunk in [1, 2, 5, 1 << 20]) {
          expect(run(key, chunk: chunk), value, reason: '$key / $chunk');
        }
      }
      // A token whose end begins another one (the random secret can end
      // in `t`, `th`…): a whole token at a chunk's end is still replaced.
      for (final chunk in [1, 2, 5, 9, 1 << 20]) {
        expect(
          run('<a n="TOK-1T">TOK-1TOK-1T', chunk: chunk, token: 'TOK-1T'),
          '<a n="N">NOK-1T',
          reason: '$chunk',
        );
      }
    });
  });

  group('host check', () {
    test('matching', () {
      const allowed = ['example.com', '*.example.com'];
      expect(hostAllowed('example.com', allowed), isTrue);
      expect(hostAllowed('EXAMPLE.com:8443', allowed), isTrue);
      expect(hostAllowed('example.com.', allowed), isTrue);
      expect(hostAllowed('app.example.com', allowed), isTrue);
      expect(hostAllowed('evil.com', allowed), isFalse);
      expect(hostAllowed('example.com.evil.com', allowed), isFalse);
      expect(hostAllowed('evilexample.com', allowed), isFalse);
      expect(hostAllowed('example.com@evil.com', allowed), isFalse);
      expect(hostAllowed('example.com, evil.com', allowed), isFalse);
      expect(hostAllowed('example.com/evil', allowed), isFalse);
      expect(hostAllowed('', allowed), isFalse);
      expect(hostAllowed(null, allowed), isFalse);
      expect(hostAllowed('example.com', const ['*.example.com']), isFalse);
      expect(hostAllowed('[::1]:8080', const ['[::1]']), isTrue);
    });
  });

  group('static files', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('thor_sec_');
      File('${dir.path}/app.js').writeAsStringSync('1');
      File('${dir.path}/app.js.map').writeAsStringSync('{}');
      File('${dir.path}/a..b.js').writeAsStringSync('1');
      File('${dir.path}/.env').writeAsStringSync('SECRET=1');
      Directory('${dir.path}/.git').createSync();
      File('${dir.path}/.git/config').writeAsStringSync('x');
      Directory('${dir.path}/.well-known').createSync();
      File('${dir.path}/.well-known/security.txt').writeAsStringSync('c');
      Directory('${dir.path}/img').createSync();
      File('${dir.path}/img/.hidden').writeAsStringSync('x');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    for (final index in [true, false]) {
      test('dotfiles are 404 except /.well-known/ (index: $index)', () async {
        final files = StaticFiles(dir.path, index: index, sourceMaps: false);
        for (final p in [
          '/.env',
          '/.git/config',
          '/img/.hidden',
          '/%2eenv',
          '/.well-known/../.env',
          '/img/../.env',
        ]) {
          expect(await files.lookup(p, null, null), isNull, reason: p);
        }
        expect(
          (await files.lookup('/.well-known/security.txt', null, null))!.status,
          200,
        );
      });

      test('.map is 404 in release, served in dev (index: $index)', () async {
        final release = StaticFiles(dir.path, index: index);
        final wasDev = ThorDev.enabled;
        addTearDown(() => ThorDev.enabled = wasDev);
        ThorDev.enabled = false;
        expect(await release.lookup('/app.js.map', null, null), isNull);
        expect(await release.lookup('/app.js.MAP', null, null), isNull);
        expect((await release.lookup('/app.js', null, null))!.status, 200);
        ThorDev.enabled = true;
        expect((await release.lookup('/app.js.map', null, null))!.status, 200);
        final forced = StaticFiles(dir.path, index: index, sourceMaps: true);
        ThorDev.enabled = false;
        expect((await forced.lookup('/app.js.map', null, null))!.status, 200);
      });
    }

    test('`..` rejects only real segments', () async {
      final files = StaticFiles(dir.path, index: false, sourceMaps: false);
      expect((await files.lookup('/a..b.js', null, null))!.status, 200);
      for (final p in [
        '/../x',
        '/img/..%2f..%2fx',
        '/%2e%2e/x',
        '/img/%2E%2E/app.js',
      ]) {
        expect(await files.lookup(p, null, null), isNull, reason: p);
      }
      expect(await files.lookup('/app.js%00.png', null, null), isNull);
    });
  });

  test('SecurityHeaders takes enums, securityHeaders() keeps its strings', () {
    final typed = const SecurityHeaders(
      frameOptions: FrameOptions.sameOrigin,
      referrerPolicy: ReferrerPolicy.noReferrer,
      openerPolicy: OpenerPolicy.sameOriginAllowPopups,
    ).headers;
    expect(typed['x-frame-options'], 'SAMEORIGIN');
    expect(typed['referrer-policy'], 'no-referrer');
    expect(typed['cross-origin-opener-policy'], 'same-origin-allow-popups');
    final defaults = const SecurityHeaders().headers;
    expect(defaults['x-frame-options'], 'DENY');
    expect(defaults['referrer-policy'], 'strict-origin-when-cross-origin');
    expect(defaults['cross-origin-opener-policy'], 'same-origin');
    expect(
      const SecurityHeaders(frameOptions: null).headers,
      isNot(contains('x-frame-options')),
    );
  });

  group('frameAncestors', () {
    test('default stays DENY with no CSP', () {
      final h = const SecurityHeaders().headers;
      expect(h['x-frame-options'], 'DENY');
      expect(h, isNot(contains('content-security-policy')));
    });

    test('origins replace X-Frame-Options with frame-ancestors', () {
      final h = const SecurityHeaders(
        frameAncestors: ['https://editor.example', 'http://localhost:4700/'],
      ).headers;
      expect(h, isNot(contains('x-frame-options')));
      expect(
        h['content-security-policy'],
        "frame-ancestors 'self' https://editor.example http://localhost:4700",
      );
    });

    test('the securityHeaders() middleware takes them too', () async {
      final response = await securityHeaders(
        frameAncestors: ['https://editor.example'],
      )(_get('/'), () async => ThorResponse(200, body: const []));
      expect(response.headers['x-frame-options'], isNull);
      expect(
        response.headers['content-security-policy'],
        "frame-ancestors 'self' https://editor.example",
      );
    });

    test('anything that is not a plain http(s) origin is refused', () {
      for (final bad in [
        '*',
        'https://*.example.com',
        'https://a.example/path',
        'https://a.example?x=1',
        'https://u:p@a.example',
        'ftp://a.example',
        'a.example',
        'https://a.example; script-src *',
        "https://a.example 'none'",
        'https://a.example, https://b.example',
        '',
        "'self'",
      ]) {
        expect(
          () => frameAncestorsPolicy([bad]),
          throwsArgumentError,
          reason: bad,
        );
      }
    });

    test('a server refuses a bad origin when it is built', () {
      expect(
        () => ThorServer(
          handler: RouteHandler<String>(renderer: _Renderer(), routes: []),
          securityHeaders: const SecurityHeaders(frameAncestors: ['*']),
        ),
        throwsArgumentError,
      );
    });
  });

  group('server', () {
    late Directory dir;
    late HttpServer http;
    late HttpClient client;
    late bool wasDev;

    Future<void> start({
      List<String>? allowedHosts,
      Uri? publicOrigin,
      SecurityHeaders? headers,
    }) async {
      final server = ThorServer(
        publicDir: dir.path,
        allowedHosts: allowedHosts,
        publicOrigin: publicOrigin,
        securityHeaders: headers,
        handler: RouteHandler<String>(
          renderer: _Renderer(),
          routes: [
            PageRoute<String, String>(
              load: (r) async => r.uri.toString(),
              build: (s) => 'uri=${s.data}',
              actions: {'default': (r) => null},
            ),
          ],
        ),
      );
      http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      http.listen(server.handleHttp);
    }

    Future<(int, HttpHeaders, String)> get(
      String path, {
      String? host,
      Map<String, String> headers = const {},
    }) async {
      final req = await client.getUrl(
        Uri.parse('http://127.0.0.1:${http.port}$path'),
      );
      if (host != null) req.headers.host = host;
      headers.forEach(req.headers.set);
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      return (res.statusCode, res.headers, body);
    }

    setUp(() {
      wasDev = ThorDev.enabled;
      ThorDev.enabled = false;
      dir = Directory.systemTemp.createTempSync('thor_srv_');
      File('${dir.path}/app.js').writeAsStringSync('1');
      File('${dir.path}/app.js.map').writeAsStringSync('{}');
      File('${dir.path}/.env').writeAsStringSync('SECRET');
      client = HttpClient();
    });
    tearDown(() async {
      ThorDev.enabled = wasDev;
      client.close(force: true);
      await http.close(force: true);
      dir.deleteSync(recursive: true);
    });

    test('a forged Host is a 400, the real one is served', () async {
      await start(allowedHosts: ['example.com']);
      final bad = await get('/', host: 'evil.com');
      expect(bad.$1, 400);
      expect(bad.$3, isNot(contains('evil.com')));
      expect((await get('/app.js', host: 'evil.com')).$1, 400);
      expect((await get('/', host: 'evil.com:80')).$1, 400);
      final ok = await get('/', host: 'example.com');
      expect(ok.$1, 200);
    });

    test('X-Forwarded-Host cannot replace the Host that passed', () async {
      await start(allowedHosts: ['example.com']);
      final res = await get(
        '/',
        host: 'example.com',
        headers: {'x-forwarded-host': 'evil.com'},
      );
      // Served (the Host is allowed), but the app never sees evil.com.
      expect(res.$1, 200);
      expect(res.$3, isNot(contains('evil.com')));
      expect(res.$3, contains('example.com'));
      // And a forged Host with a friendly X-Forwarded-Host is still a 400.
      final bad = await get(
        '/',
        host: 'evil.com',
        headers: {'x-forwarded-host': 'example.com'},
      );
      expect(bad.$1, 400);
    });

    test('the health check answers any host', () async {
      await start(allowedHosts: ['example.com']);
      expect((await get('/_thor/health', host: '10.0.0.7')).$1, 200);
    });

    test('without allowedHosts any host passes', () async {
      await start();
      expect((await get('/', host: 'evil.com')).$1, 200);
    });

    test('thor dev ignores allowedHosts', () async {
      ThorDev.enabled = true;
      await start(allowedHosts: ['example.com']);
      // Dev has its own host check; this one does not add a refusal.
      final res = await get('/', host: 'localhost:${http.port}');
      expect(res.$1, isNot(400));
    });

    test(
      'publicOrigin is the origin the app sees, whatever Host says',
      () async {
        await start(publicOrigin: Uri.parse('https://example.com'));
        final res = await get('/?a=1', host: 'evil.com');
        expect(res.$3, 'uri=https://example.com/?a=1');
      },
    );

    Future<int> post(
      String origin, {
      bool json = false,
      String host = 'internal:8080',
    }) async {
      final req = await client.postUrl(
        Uri.parse('http://127.0.0.1:${http.port}/'),
      );
      req.followRedirects = false;
      req.headers.set('origin', origin);
      req.headers.contentType = json
          ? ContentType('application', 'json')
          : ContentType('application', 'x-www-form-urlencoded');
      if (json) req.headers.set('x-thor-query', 'Nope.q');
      req.headers.host = host;
      req.write(json ? '{}' : 'a=1');
      final res = await req.close();
      await res.drain<void>();
      return res.statusCode;
    }

    test(
      'publicOrigin: a form from it passes behind a rewritten Host',
      () async {
        await start(publicOrigin: Uri.parse('https://example.com'));
        expect(await post('https://example.com'), lessThan(400));
        expect(await post('https://evil.com'), 403);
      },
    );

    test(
      'publicOrigin: a same-origin query passes, another is refused',
      () async {
        await start(publicOrigin: Uri.parse('https://example.com'));
        expect(await post('https://example.com', json: true), 404);
        expect(await post('https://evil.com', json: true), 403);
      },
    );

    test('allowedHosts alone keeps the validated Host for the check', () async {
      await start(allowedHosts: ['example.com']);
      final own = 'http://example.com:${http.port}';
      expect(await post(own, host: 'example.com'), lessThan(400));
      expect(await post('http://evil.com', host: 'example.com'), 403);
    });

    test('publicOrigin must be an origin', () {
      for (final bad in [
        Uri.parse('example.com'),
        Uri.parse('ftp://example.com'),
        Uri.parse('https://example.com/app'),
        Uri.parse('https://u@example.com'),
        Uri.parse('https://example.com?x'),
      ]) {
        expect(
          () => ThorServer(
            publicOrigin: bad,
            handler: RouteHandler<String>(renderer: _Renderer(), routes: []),
          ),
          throwsArgumentError,
          reason: '$bad',
        );
      }
    });

    test('an empty allowedHosts is refused, in release builds too', () {
      expect(
        () => ThorServer(
          allowedHosts: const [],
          handler: RouteHandler<String>(renderer: _Renderer(), routes: []),
        ),
        throwsArgumentError,
      );
    });

    test(
      'security headers on pages, static files, health and refusals',
      () async {
        await start(
          allowedHosts: ['example.com'],
          headers: const SecurityHeaders(hsts: Duration(days: 365)),
        );
        for (final (path, host, status) in [
          ('/', 'example.com', 200),
          ('/app.js', 'example.com', 200),
          ('/missing', 'example.com', 404),
          ('/_thor/health', 'example.com', 200),
          ('/', 'evil.com', 400),
        ]) {
          final res = await get(path, host: host);
          expect(res.$1, status, reason: '$path $host');
          final h = res.$2;
          expect(h.value('x-content-type-options'), 'nosniff', reason: path);
          expect(h.value('x-frame-options'), 'DENY', reason: path);
          expect(
            h.value('strict-transport-security'),
            contains('max-age='),
            reason: path,
          );
        }
      },
    );

    test('frameAncestors: every response frames by that origin only', () async {
      await start(
        allowedHosts: ['example.com'],
        headers: const SecurityHeaders(
          frameAncestors: ['https://editor.example'],
        ),
      );
      for (final (path, host, status) in [
        ('/', 'example.com', 200),
        ('/app.js', 'example.com', 200),
        ('/missing', 'example.com', 404),
        ('/', 'evil.com', 400),
      ]) {
        final res = await get(path, host: host);
        expect(res.$1, status, reason: path);
        expect(res.$2.value('x-frame-options'), isNull, reason: path);
        expect(
          res.$2.value('content-security-policy'),
          "frame-ancestors 'self' https://editor.example",
          reason: path,
        );
      }
    });

    test('release: .map and dotfiles are 404 over HTTP', () async {
      await start();
      expect((await get('/app.js')).$1, 200);
      expect((await get('/app.js.map')).$1, 404);
      expect((await get('/.env')).$1, 404);
    });
  });
}
