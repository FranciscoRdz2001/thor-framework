import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

/// Pages are strings; the document shows the request's locale.
class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) =>
      utf8.encode('<html lang="${context.request.locale}">$page</html>');

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

PageRequest _get(String path, {Map<HttpHeader, String> headers = const {}}) =>
    PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://site.test$path'),
      headers: {HttpHeader.host: 'site.test', ...headers},
    );

List<RouteNode<String>> _routes() => [
  PageRoute<String, void>(build: (s) => 'home ${s.request.locale}'),
  PageRoute<String, void>(
    path: 'about',
    cache: const Duration(minutes: 1),
    build: (s) =>
        'about ${s.request.locale} ${s.request.routePath} '
        '${s.request.localizedPath('/about', locale: _l('en'))}',
  ),
  PageRoute<String, void>(
    path: 'links',
    build: (s) => '<a href="/es/about">es</a><a href="/fr/about">fr</a>',
  ),
];

Locale _l(String tag) => Locale.tryParse(tag)!;

List<Locale> _ls(List<String> tags) => [for (final t in tags) _l(t)];

List<String> _tags(List<Locale> locales) => [
  for (final l in locales) l.toLanguageTag(),
];

String? _tag(Locale? locale) => locale?.toLanguageTag();

void main() {
  group('parseAcceptLanguage', () {
    test('orders by q, ties in header order', () {
      expect(_tags(parseAcceptLanguage('fr;q=0.5, es-MX, en;q=0.9, de')), [
        'es-MX',
        'de',
        'en',
        'fr',
      ]);
    });

    test('skips malformed entries instead of failing', () {
      expect(
        _tags(
          parseAcceptLanguage(
            'en;q=abc, ;;, 12, e, es;q=2, *, fr;q, de;q=0.8, '
            '<script>, pt_br;q=0.7, it;q=1.0001',
          ),
        ),
        ['de', 'pt-BR'],
      );
    });

    test('q=0 means "not this one"', () {
      expect(parseAcceptLanguage('es;q=0, en;q=0.000'), isEmpty);
    });

    test('an oversized header or entries past the 32nd are ignored', () {
      expect(parseAcceptLanguage('en,' * 3000), isEmpty);
      final many = [for (var i = 0; i < 40; i++) 'x$i'.padRight(3, 'a')];
      many[35] = 'es';
      expect(_tags(parseAcceptLanguage(many.join(','))), isNot(contains('es')));
    });

    test('an empty header prefers nothing', () {
      expect(parseAcceptLanguage(''), isEmpty);
      expect(parseAcceptLanguage(' , ,'), isEmpty);
    });
  });

  group('matchLocale', () {
    test('same tag, then the bare language, then any region of it', () {
      expect(_tag(matchLocale(_ls(['es-MX']), _ls(['en', 'es']))), 'es');
      expect(_tag(matchLocale(_ls(['pt']), _ls(['en', 'pt-BR']))), 'pt-BR');
      expect(_tag(matchLocale(_ls(['EN-us']), _ls(['en', 'en-US']))), 'en-US');
    });

    test('the first preferred language that matches wins', () {
      // es-AR has no exact match but its language does: before en.
      expect(_tag(matchLocale(_ls(['es-AR', 'en']), _ls(['en', 'es']))), 'es');
    });

    test('nothing supported → null', () {
      expect(matchLocale(_ls(['fr', 'de']), _ls(['en', 'es'])), isNull);
      expect(matchLocale(const [], _ls(['en'])), isNull);
    });
  });

  group('LocaleRouting', () {
    test('rejects an empty, invalid or inconsistent configuration', () {
      expect(
        () => LocaleRouting(supportedLocales: const []),
        throwsArgumentError,
      );
      expect(
        () => LocaleRouting(
          supportedLocales: _ls(['en']),
          defaultLocale: _l('es'),
        ),
        throwsArgumentError,
      );
      expect(
        () => LocaleRouting(
          supportedLocales: [const Locale('en'), const Locale('e/s')],
        ),
        throwsArgumentError,
      );
      expect(
        () => LocaleRouting(supportedLocales: _ls(['es', 'ES'])),
        throwsArgumentError,
      );
    });

    test(
      'precedence: URL, then cookie, then Accept-Language, then default',
      () {
        final r = LocaleRouting(supportedLocales: _ls(['en', 'es', 'ar']));
        expect(
          r.resolve('/ar/x', cookie: 'es', acceptLanguage: 'en').locale,
          _l('ar'),
        );
        expect(
          r.resolve('/x', cookie: 'es', acceptLanguage: 'ar').locale,
          _l('es'),
        );
        expect(r.resolve('/x', acceptLanguage: 'ar, es').locale, _l('ar'));
        expect(r.resolve('/x').locale, _l('en'));
      },
    );

    test('an unsupported or hostile cookie is ignored', () {
      final r = LocaleRouting(supportedLocales: _ls(['en', 'es']));
      expect(r.negotiate(cookie: 'fr', acceptLanguage: 'es'), _l('es'));
      expect(
        r.negotiate(cookie: 'es"><script>', acceptLanguage: 'x'),
        _l('en'),
      );
      expect(r.negotiate(cookie: ''), _l('en'));
      expect(r.negotiate(cookie: 'ES'), _l('es'));
    });

    test('only an exact supported first segment is a prefix', () {
      final r = LocaleRouting(supportedLocales: _ls(['en', 'es', 'pt-BR']));
      expect(r.resolve('/es'), (locale: _l('es'), path: '/', prefixed: true));
      expect(r.resolve('/pt-BR/a/b').path, '/a/b');
      expect(r.resolve('/ES/about').prefixed, isFalse);
      expect(r.resolve('/esp/about').prefixed, isFalse);
      expect(r.resolve('/').prefixed, isFalse);
    });

    test('negotiation never reads the URL', () {
      final r = LocaleRouting(
        supportedLocales: _ls(['en', 'es']),
        strategy: LocaleStrategy.negotiate,
      );
      expect(r.resolve('/es/about'), (
        locale: _l('en'),
        path: '/es/about',
        prefixed: false,
      ));
      expect(r.pathFor(_l('es'), '/about'), '/about');
      expect(r.alternates('/about'), isEmpty);
    });

    test('alternates: every locale and x-default, absolute with baseUrl', () {
      final r = LocaleRouting(
        supportedLocales: _ls(['en', 'es']),
        baseUrl: 'https://ex.com/',
      );
      expect(r.alternates('/'), {
        'en': 'https://ex.com/en',
        'es': 'https://ex.com/es',
        'x-default': 'https://ex.com/en',
      });
      expect(() => r.pathFor(_l('fr'), '/'), throwsArgumentError);
    });
  });

  test('isRtlLanguageTag: languages and scripts', () {
    for (final tag in ['ar', 'he', 'iw', 'fa-IR', 'ur', 'az-Arab', 'ckb']) {
      expect(isRtlLanguageTag(tag), isTrue, reason: tag);
    }
    for (final tag in ['en', 'es-MX', 'ku', 'ar-Latn', 'zh-Hant-TW']) {
      expect(isRtlLanguageTag(tag), isFalse, reason: tag);
    }
  });

  group('RouteHandler with a URL prefix', () {
    late RouteHandler<String> handler;
    setUp(() {
      handler = RouteHandler<String>(
        renderer: _Renderer(),
        onError: (r, e, s) {},
        locales: LocaleRouting(supportedLocales: _ls(['en', 'es'])),
        routes: _routes(),
      );
    });

    test('a page without its locale redirects to the visitor\'s', () async {
      final r = await handler.handle(
        _get(
          '/about?x=1',
          headers: {HttpHeader.acceptLanguage: 'es-MX,en;q=0.5'},
        ),
      );
      expect(r.status, 302);
      expect(r.headers['location'], '/es/about?x=1');
      expect(r.headers['vary'], 'Accept-Language, Cookie');

      final root = await handler.handle(_get('/'));
      expect(root.headers['location'], '/en');
    });

    test('the cookie beats the header in the redirect', () async {
      final r = await handler.handle(
        _get(
          '/about',
          headers: {
            HttpHeader.acceptLanguage: 'es',
            HttpHeader.cookie: 'locale=en',
          },
        ),
      );
      expect(r.headers['location'], '/en/about');
    });

    test('the URL beats cookie and header', () async {
      final r = await handler.handle(
        _get(
          '/es/about',
          headers: {
            HttpHeader.acceptLanguage: 'en',
            HttpHeader.cookie: 'locale=en',
          },
        ),
      );
      expect(r.status, 200);
      expect(r.text, contains('about es /about /en/about'));
      expect(r.headers.containsKey('vary'), isFalse);
    });

    test('an unsupported locale requested falls back to the default', () async {
      final r = await handler.handle(
        _get('/about', headers: {HttpHeader.acceptLanguage: 'fr-FR, de;q=0.9'}),
      );
      expect(r.headers['location'], '/en/about');
    });

    test(
      'an unknown path is a 404 in the visitor\'s locale, no redirect',
      () async {
        final r = await handler.handle(
          _get('/fr/about', headers: {HttpHeader.acceptLanguage: 'es'}),
        );
        expect(r.status, 404);
        expect(r.text, contains('lang="es"'));
      },
    );

    test(
      'a POST without a prefix is not redirected (its body would be lost)',
      () async {
        final r = await handler.handle(
          PageRequest(
            method: HttpMethod.post,
            uri: Uri.parse('http://site.test/about'),
            headers: {
              HttpHeader.host: 'site.test',
              HttpHeader.origin: 'http://site.test',
            },
          ),
        );
        expect(r.status, isNot(302));
      },
    );

    test('/es/ loses its slash, then serves the home in es', () async {
      final r = await handler.handle(_get('/es/'));
      expect(r.status, 308);
      expect(r.headers['location'], '/es');
      final home = await handler.handle(_get('/es'));
      expect(home.text, contains('home es'));
    });

    test('the page cache keeps each locale apart', () async {
      final es = await handler.handle(_get('/es/about'));
      final en = await handler.handle(_get('/en/about'));
      expect(es.text, contains('about es'));
      expect(en.text, contains('about en'));
      expect(handler.cachedPaths, hasLength(2));
      // A hit returns the page of its own locale.
      expect((await handler.handle(_get('/es/about'))).text, es.text);
    });
  });

  group('RouteHandler without a prefix for the default', () {
    late RouteHandler<String> handler;
    setUp(() {
      handler = RouteHandler<String>(
        renderer: _Renderer(),
        onError: (r, e, s) {},
        locales: LocaleRouting(
          supportedLocales: _ls(['en', 'es']),
          strategy: LocaleStrategy.prefixExceptDefault,
          baseUrl: 'https://ex.com',
        ),
        routes: _routes(),
      );
    });

    test(
      'a path without a prefix is the default page, never a redirect',
      () async {
        final r = await handler.handle(
          _get(
            '/about',
            headers: {
              HttpHeader.acceptLanguage: 'es',
              HttpHeader.cookie: 'locale=es',
            },
          ),
        );
        expect(r.status, 200);
        expect(r.text, contains('about en /about'));
        // No negotiation happened: nothing to vary on.
        expect(r.headers['vary'] ?? '', isNot(contains('Accept-Language')));
      },
    );

    test('the other locales keep their prefix', () async {
      final r = await handler.handle(_get('/es/about'));
      expect(r.status, 200);
      expect(r.text, contains('about es /about /about'));
    });

    test(
      'a language switch on a double-slash path stays on the site',
      () async {
        // `//evil.example/about` must not become `Location: //evil.example/…`
        // (a protocol-relative URL: an open redirect).
        for (final path in ['//evil.example/about', '/%5Cevil.example/about']) {
          for (final tag in ['en', 'es', 'xx']) {
            final r = await handler.handle(_get('$path?set-locale=$tag'));
            final location = r.headers['location'] ?? '';
            expect(location, startsWith('/'), reason: '$path $tag');
            expect(location, isNot(matches(r'^/[/\\]')), reason: '$path $tag');
          }
        }
      },
    );

    test('only the root asks the visitor', () async {
      final es = await handler.handle(
        _get('/', headers: {HttpHeader.acceptLanguage: 'es-MX,en;q=0.5'}),
      );
      expect(es.status, 302);
      expect(es.headers['location'], '/es');
      expect(es.headers['vary'], 'Accept-Language, Cookie');

      final cookie = await handler.handle(
        _get(
          '/',
          headers: {
            HttpHeader.acceptLanguage: 'es',
            HttpHeader.cookie: 'locale=en',
          },
        ),
      );
      expect(cookie.status, 200, reason: 'the cookie chose the default');
      expect(cookie.headers['vary'], 'Accept-Language, Cookie');

      final none = await handler.handle(_get('/'));
      expect(none.status, 200);
      expect(none.text, contains('home en'));
    });

    test(
      'a hostile Accept-Language or cookie falls back to the default',
      () async {
        final r = await handler.handle(
          _get(
            '/',
            headers: {
              HttpHeader.acceptLanguage: ';;q=abc, *, x' * 400,
              HttpHeader.cookie: 'locale=../../etc',
            },
          ),
        );
        expect(r.status, 200);
        expect(r.text, contains('home en'));
      },
    );

    test('the default spelled with its prefix goes to its one URL', () async {
      final about = await handler.handle(_get('/en/about?x=1'));
      expect(about.status, 308);
      expect(about.headers['location'], '/about?x=1');
      final home = await handler.handle(_get('/en'));
      expect(home.status, 308);
      expect(home.headers['location'], '/');
    });

    test('an unsupported prefix is a path of its own (404)', () async {
      final r = await handler.handle(_get('/fr/about'));
      expect(r.status, 404);
    });

    test('pathFor and alternates: the default without a prefix', () {
      final l = handler.locales!;
      expect(l.pathFor(_l('en'), '/about'), '/about');
      expect(l.pathFor(_l('en'), '/'), '/');
      expect(l.pathFor(_l('es'), '/'), '/es');
      expect(l.alternates('/about'), {
        'en': 'https://ex.com/about',
        'es': 'https://ex.com/es/about',
        'x-default': 'https://ex.com/about',
      });
    });

    test(
      'a switcher link with a malformed query is a 400, not a 500',
      () async {
        for (final path in [
          '/about?set-locale=en&q=%FF',
          '/?q=%FF&set-locale=es',
        ]) {
          final r = await handler.handle(_get(path));
          expect(r.status, 400, reason: path);
        }
      },
    );

    test('a switcher link remembers the choice and lands on its URL', () async {
      final toDefault = await handler.handle(
        _get('/es/about?set-locale=en&x=1'),
      );
      expect(toDefault.status, 303);
      expect(toDefault.headers['location'], '/about?x=1');
      expect(toDefault.cookies.single, startsWith('locale=en;'));
      expect(toDefault.headers['cache-control'], 'no-store');

      final toEs = await handler.handle(_get('/?set-locale=es'));
      expect(toEs.headers['location'], '/es');
      expect(toEs.cookies.single, startsWith('locale=es;'));
    });

    test(
      'a switcher link to a locale the app lacks only loses the parameter',
      () async {
        for (final bad in ['fr', '../x', 'en;domain=evil', '']) {
          final r = await handler.handle(
            _get('/about?set-locale=${Uri.encodeComponent(bad)}'),
          );
          expect(r.status, 303, reason: bad);
          expect(r.headers['location'], '/about', reason: bad);
          expect(r.cookies, isEmpty, reason: bad);
        }
      },
    );

    test('exports the default at the root and no chooser', () async {
      final out = await Directory.systemTemp.createTemp('thor_i18n_ped');
      addTearDown(() => out.delete(recursive: true));
      final report = await exportSite(
        handler,
        paths: ['/', '/about'],
        outDir: out.path,
        baseUrl: 'https://ex.com',
      );
      expect(report.failed, isEmpty);
      expect(report.written.keys, ['/', '/es', '/about', '/es/about']);
      expect(
        await File('${out.path}/index.html').readAsString(),
        contains('home en'),
      );
      final sitemap = await File('${out.path}/sitemap.xml').readAsString();
      expect(sitemap, contains('<loc>https://ex.com/</loc>'));
      expect(sitemap, contains('<loc>https://ex.com/es/about</loc>'));
    });
  });

  group('RouteHandler negotiating', () {
    late RouteHandler<String> handler;
    setUp(() {
      handler = RouteHandler<String>(
        renderer: _Renderer(),
        onError: (r, e, s) {},
        locales: LocaleRouting(
          supportedLocales: _ls(['en', 'es']),
          strategy: LocaleStrategy.negotiate,
        ),
        routes: _routes(),
      );
    });

    test('one URL, a cached page per locale, and Vary', () async {
      final es = await handler.handle(
        _get('/about', headers: {HttpHeader.acceptLanguage: 'es'}),
      );
      final en = await handler.handle(
        _get('/about', headers: {HttpHeader.acceptLanguage: 'en'}),
      );
      expect(es.status, 200);
      expect(es.text, contains('about es'));
      // Not the Spanish page that is already cached for the same URL.
      expect(en.text, contains('about en'));
      expect(en.headers['vary'], 'Accept-Language, Cookie');
      expect(handler.cachedPaths, hasLength(2));
      final hit = await handler.handle(
        _get('/about', headers: {HttpHeader.cookie: 'locale=es'}),
      );
      expect(hit.text, es.text);
    });

    test('an ETag of one locale does not validate another', () async {
      final es = await handler.handle(
        _get('/about', headers: {HttpHeader.acceptLanguage: 'es'}),
      );
      final en = await handler.handle(
        _get(
          '/about',
          headers: {
            HttpHeader.acceptLanguage: 'en',
            HttpHeader.ifNoneMatch: es.headers['etag']!,
          },
        ),
      );
      expect(en.status, 200);
      expect(en.text, contains('about en'));
    });

    test('malformed Accept-Language falls back to the default', () async {
      final r = await handler.handle(
        _get('/about', headers: {HttpHeader.acceptLanguage: ';q=,,es;q=x;'}),
      );
      expect(r.status, 200);
      expect(r.text, contains('about en'));
    });
  });

  group('exportSite', () {
    late Directory out;
    setUp(() async => out = await Directory.systemTemp.createTemp('thor_i18n'));
    tearDown(() => out.delete(recursive: true));

    test('writes every locale of each path and a chooser at /', () async {
      final handler = RouteHandler<String>(
        renderer: _Renderer(),
        onError: (r, e, s) {},
        locales: LocaleRouting(supportedLocales: _ls(['en', 'es'])),
        routes: _routes(),
      );
      final report = await exportSite(
        handler,
        paths: ['/', '/about', '/es/about'],
        outDir: out.path,
        baseUrl: 'https://ex.com',
      );
      expect(report.failed, isEmpty);
      expect(report.written.keys, [
        '/',
        '/en',
        '/es',
        '/en/about',
        '/es/about',
      ]);
      expect(
        await File('${out.path}/es/about.html').readAsString(),
        contains('about es'),
      );
      final chooser = await File('${out.path}/index.html').readAsString();
      expect(chooser, contains('http-equiv="refresh" content="0; url=/en"'));
      expect(chooser, contains('hreflang="es" href="/es"'));
      final sitemap = await File('${out.path}/sitemap.xml').readAsString();
      expect(sitemap, isNot(contains('<loc>https://ex.com/</loc>')));
      expect(sitemap, contains('<loc>https://ex.com/es/about</loc>'));
    });

    test('a link to a locale the site lacks is broken', () async {
      final handler = RouteHandler<String>(
        renderer: _Renderer(),
        onError: (r, e, s) {},
        locales: LocaleRouting(supportedLocales: _ls(['en', 'es'])),
        routes: _routes(),
      );
      final report = await exportSite(
        handler,
        paths: ['/about', '/links'],
        outDir: out.path,
      );
      expect(report.brokenLinks['/en/links'], ['/fr/about']);
      expect(report.brokenLinks['/es/links'], ['/fr/about']);
    });

    test('a negotiating site cannot be exported', () async {
      final handler = RouteHandler<String>(
        renderer: _Renderer(),
        locales: LocaleRouting(
          supportedLocales: _ls(['en', 'es']),
          strategy: LocaleStrategy.negotiate,
        ),
        routes: _routes(),
      );
      expect(
        () => exportSite(handler, paths: ['/'], outDir: out.path),
        throwsStateError,
      );
    });
  });
}
