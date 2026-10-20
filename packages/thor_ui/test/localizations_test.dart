@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/server.dart' show Document;
import 'package:thor_ui/src/core/render.dart' as core;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

/// What a generated `AppLocalizations` looks like, by hand.
class _Messages {
  _Messages(this.localeName);
  final String localeName;
  String get hello => localeName == 'es' ? 'hola' : 'hello';
  String greet(String name) => localeName == 'es' ? 'hola $name' : 'hi $name';

  static _Messages of(BuildContext context) =>
      Localizations.of<_Messages>(context, _Messages)!;
}

class _Delegate extends LocalizationsDelegate<_Messages> {
  const _Delegate();
  @override
  bool isSupported(Locale locale) =>
      const {'en', 'es', 'ar'}.contains(locale.languageCode);
  @override
  Future<_Messages> load(Locale locale) =>
      SynchronousFuture(_Messages(locale.languageCode));
  @override
  bool shouldReload(_Delegate old) => false;
}

class _AsyncDelegate extends LocalizationsDelegate<_Messages> {
  const _AsyncDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<_Messages> load(Locale locale) async => _Messages('en');
  @override
  bool shouldReload(_AsyncDelegate old) => false;
}

class _Hello extends StatelessWidget implements ThorElementWidget {
  const _Hello();
  @override
  Widget build(BuildContext context) => Text(
    '${_Messages.of(context).hello} '
    '${Localizations.localeOf(context).toLanguageTag()}',
  );
}

const _supported = [Locale('en'), Locale('es'), Locale('ar')];

Future<String> _render(Widget app, {Locale? lang}) async =>
    utf8.decode((await core.renderPage(Document(lang: lang, body: app))).body);

void main() {
  setUpAll(initializeThorTests);

  group('Locale', () {
    test('tryParse: tags, case and separators', () {
      expect(Locale.tryParse('pt_br'), const Locale('pt', 'BR'));
      expect(
        Locale.tryParse('zh-hant-tw'),
        const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
          countryCode: 'TW',
        ),
      );
      expect(Locale.tryParse('es-419')!.countryCode, '419');
      expect(Locale.tryParse('es-419')!.toLanguageTag(), 'es-419');
      for (final bad in ['', 'e', '12', 'en--US', 'en-US-', '<b>', 'es;q=1']) {
        expect(Locale.tryParse(bad), isNull, reason: bad);
      }
    });

    test('tag, toString and equality like Flutter', () {
      const l = Locale('pt', 'BR');
      expect(l.toLanguageTag(), 'pt-BR');
      expect(l.toString(), 'pt_BR');
      expect(l, Locale.tryParse('pt-BR'));
      expect(l, isNot(const Locale('pt')));
    });

    test('text direction', () {
      expect(const Locale('ar').textDirection, TextDirection.rtl);
      expect(const Locale('he', 'IL').textDirection, TextDirection.rtl);
      expect(const Locale('es').textDirection, TextDirection.ltr);
    });
  });

  group('basicLocaleListResolution (Flutter)', () {
    test('no preferred locale → the first supported', () {
      expect(basicLocaleListResolution(null, _supported), const Locale('en'));
      expect(basicLocaleListResolution([], _supported), const Locale('en'));
    });

    test('full match, then language', () {
      expect(
        basicLocaleListResolution([const Locale('es', 'MX')], _supported),
        const Locale('es'),
      );
      expect(
        basicLocaleListResolution([
          const Locale('fr'),
          const Locale('ar', 'EG'),
        ], _supported),
        const Locale('ar'),
      );
    });

    test('a later full match of the same language beats the first', () {
      expect(
        basicLocaleListResolution(
          [const Locale('es'), const Locale('es', 'MX')],
          [
            const Locale('en'),
            const Locale('es', 'AR'),
            const Locale('es', 'MX'),
          ],
        ),
        const Locale('es', 'MX'),
      );
    });

    test(
      'an unsupported language falls back to the region, then the first',
      () {
        expect(
          basicLocaleListResolution(
            [const Locale('fr', 'CA')],
            [const Locale('en', 'US'), const Locale('en', 'CA')],
          ),
          const Locale('en', 'CA'),
        );
        expect(
          basicLocaleListResolution([const Locale('fr')], _supported),
          const Locale('en'),
        );
      },
    );
  });

  group('ThorApp', () {
    test(
      'a localized app sets <html lang dir> and serves its messages',
      () async {
        final html = await _render(
          const ThorApp(
            locale: Locale('es'),
            supportedLocales: _supported,
            localizationsDelegates: [_Delegate()],
            child: _Hello(),
          ),
          lang: const Locale('en'),
        );
        expect(html, contains('<html lang="es" dir="ltr"'));
        expect(html, contains('hola es'));
      },
    );

    test('RTL: an Arabic page is dir="rtl"', () async {
      final html = await _render(
        const ThorApp(
          locale: Locale('ar', 'EG'),
          supportedLocales: _supported,
          localizationsDelegates: [_Delegate()],
          child: _Hello(),
        ),
      );
      // ar-EG isn't supported: its language is.
      expect(html, contains('<html lang="ar" dir="rtl"'));
    });

    test('an app without localization keeps the document lang', () async {
      final html = await _render(
        const ThorApp(child: _Locale()),
        lang: const Locale('es'),
      );
      expect(html, contains('<html lang="es">'));
      // Flutter's default: en_US.
      expect(html, contains('locale en-US'));
    });

    test('the list callback is asked first; null falls through', () async {
      final asked = <String>[];
      final html = await _render(
        ThorApp(
          locale: const Locale('en'),
          supportedLocales: _supported,
          localizationsDelegates: const [_Delegate()],
          localeListResolutionCallback: (locales, supported) {
            asked.add('list ${locales?.first}');
            return null;
          },
          localeResolutionCallback: (locale, supported) {
            asked.add('one $locale');
            return const Locale('ar');
          },
          child: const _Hello(),
        ),
      );
      expect(asked, ['list en', 'one en']);
      expect(html, contains('hello ar'));
    });

    test('an asynchronous delegate fails the page, clearly', () async {
      await expectLater(
        _render(
          const ThorApp(
            locale: Locale('en'),
            supportedLocales: _supported,
            localizationsDelegates: [_AsyncDelegate()],
            child: _Hello(),
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('SynchronousFuture'),
          ),
        ),
      );
    });

    test(
      'an unsupported locale has no resources (null, not a throw)',
      () async {
        final html = await _render(
          ThorApp(
            locale: const Locale('fr'),
            supportedLocales: const [Locale('fr')],
            localizationsDelegates: const [_Delegate()],
            child: Builder(
              builder: (context) =>
                  Text('${Localizations.of<_Messages>(context, _Messages)}'),
            ),
          ),
        );
        expect(html, contains('>null<'));
      },
    );

    test('a placeholder cannot inject markup', () async {
      final html = await _render(
        ThorApp(
          locale: const Locale('es'),
          supportedLocales: _supported,
          localizationsDelegates: const [_Delegate()],
          child: Builder(
            builder: (context) => Tooltip(
              message: _Messages.of(context).greet('"><img onerror=x>'),
              child: Text(
                _Messages.of(context).greet('<script>alert(1)</script>'),
              ),
            ),
          ),
        ),
      );
      expect(html, isNot(contains('<script>alert')));
      expect(html, isNot(contains('"><img')));
      expect(html, contains('hola &lt;script&gt;'));
    });
  });

  group('routed pages', () {
    RouteHandler<Widget> handler(LocaleStrategy strategy) => RouteHandler(
      locales: LocaleRouting(
        supportedLocales: [
          const Locale('en'),
          const Locale('es'),
          const Locale('ar'),
        ],
        strategy: strategy,
        baseUrl: 'https://site.test',
      ),
      renderer: WidgetRenderer(
        app: (page) => ThorApp(
          supportedLocales: _supported,
          localizationsDelegates: const [_Delegate()],
          child: page,
        ),
      ),
      onError: (r, e, s) {},
      routes: [
        PageRoute<Widget, void>(path: 'about', build: (s) => const _Hello()),
      ],
    );

    PageRequest get(
      String path, [
      Map<HttpHeader, String> headers = const {},
    ]) => PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://site.test$path'),
      headers: {HttpHeader.host: 'site.test', ...headers},
    );

    RouteHandler<Widget> withNotFound(PageMeta Function(ErrorState)? meta) =>
        RouteHandler(
          locales: LocaleRouting(
            supportedLocales: [
              const Locale('en'),
              const Locale('es'),
              const Locale('ar'),
            ],
            strategy: LocaleStrategy.prefix,
            baseUrl: 'https://site.test',
          ),
          renderer: WidgetRenderer(
            app: (page) => ThorApp(
              supportedLocales: _supported,
              localizationsDelegates: const [_Delegate()],
              child: page,
            ),
          ),
          onError: (r, e, s) {},
          routes: [
            routeLayout<void>(
              notFound: (context, state) => const Text('Lost'),
              notFoundMeta: meta,
              children: [
                PageRoute<Widget, void>(
                  path: 'about',
                  build: (s) => const _Hello(),
                ),
              ],
            ),
          ],
        );

    test('a not found page has its own title and no hreflang', () async {
      final r = await withNotFound(
        (state) => const PageMeta(title: 'Página no encontrada'),
      ).handle(get('/es/missing'));
      expect(r.status, 404);
      expect(r.text, contains('<title>Página no encontrada</title>'));
      expect(r.text, isNot(contains('hreflang')));
      // Without a hook: the status as the title, still no alternates.
      final plain = await withNotFound(null).handle(get('/es/missing'));
      expect(plain.text, contains('<title>404</title>'));
      expect(plain.text, isNot(contains('hreflang')));
      // Asking for them gets them.
      final forced = await withNotFound(
        (state) => const PageMeta(alternates: true),
      ).handle(get('/es/missing'));
      expect(forced.text, contains('hreflang'));
      // A page that answers 200 keeps its alternates.
      final ok = await withNotFound(null).handle(get('/es/about'));
      expect(ok.text, contains('hreflang="en"'));
    });

    test('the URL locale drives lang, dir, messages and alternates', () async {
      final r = await handler(LocaleStrategy.prefix).handle(get('/ar/about'));
      expect(r.status, 200);
      expect(r.text, contains('<html lang="ar" dir="rtl"'));
      expect(r.text, contains('hello ar'));
      for (final (lang, href) in [
        ('en', 'https://site.test/en/about'),
        ('es', 'https://site.test/es/about'),
        ('x-default', 'https://site.test/en/about'),
      ]) {
        expect(
          r.text,
          contains('<link hreflang="$lang" href="$href" rel="alternate"/>'),
        );
      }
    });

    test(
      'negotiated: the header picks the page language, no alternates',
      () async {
        final r = await handler(
          LocaleStrategy.negotiate,
        ).handle(get('/about', {HttpHeader.acceptLanguage: 'es-MX,en;q=0.1'}));
        expect(r.text, contains('<html lang="es" dir="ltr"'));
        expect(r.text, contains('hola es'));
        expect(r.text, isNot(contains('hreflang')));
      },
    );
  });
}

class _Locale extends StatelessWidget implements ThorElementWidget {
  const _Locale();
  @override
  Widget build(BuildContext context) =>
      Text('locale ${Localizations.localeOf(context).toLanguageTag()}');
}
