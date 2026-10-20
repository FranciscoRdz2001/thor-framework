// The site in every language: each one has every page, message and error
// code, its own spelling of the URLs, and links between the two.
import 'dart:convert';
import 'dart:io';

import 'package:docs/app.dart';
import 'package:docs/core/content/library.dart';
import 'package:docs/core/i18n/docs_locale.dart';
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';

/// The placeholders of an ARB message (`{name}`, the variable of a plural).
Set<String> _placeholders(String message) => {
  for (final m in RegExp(r'\{(\w+)[,}]').allMatches(message)) m[1]!,
};

void main() {
  setUpAll(initializeThorTests);

  test('English is the default language, Spanish the generated files\'', () {
    expect(defaultLocale, 'en');
    expect(sourceLocale, 'es');
    expect(docsLocales.toSet(), {'en', 'es'});
  });

  group('every language has', () {
    test('every message of the template ARB, with its placeholders', () {
      Map<String, Object?> arb(String locale) =>
          jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
              as Map<String, Object?>;
      final template = arb(sourceLocale);
      final messages = {
        for (final MapEntry(:key, :value) in template.entries)
          if (!key.startsWith('@')) key: value as String,
      };
      for (final locale in docsLocales) {
        final own = arb(locale);
        expect(own['@@locale'], locale);
        final keys = {
          for (final k in own.keys)
            if (!k.startsWith('@')) k,
        };
        expect(
          messages.keys.toSet().difference(keys),
          isEmpty,
          reason: '$locale misses messages',
        );
        expect(
          keys.difference(messages.keys.toSet()),
          isEmpty,
          reason: '$locale has messages the template has not',
        );
        for (final MapEntry(:key, :value) in messages.entries) {
          expect(
            _placeholders(own[key]! as String),
            _placeholders(value),
            reason: '$locale: $key',
          );
        }
      }
    });

    test('every page of the guide', () {
      for (final locale in docsLocales) {
        for (final guide in allGuides) {
          expect(
            File('${docsDir()}/${guide.file(locale)}').existsSync(),
            isTrue,
            reason: '${guide.file(locale)} (${guide.path})',
          );
          final content = loadGuide(guide, locale)!;
          expect(content.fallback, isFalse, reason: guide.file(locale));
        }
      }
    });

    test('the same headings as the guide in Spanish, in the same order', () {
      // The links between pages are translated by position: a page with a
      // heading more or less would send a link to the wrong section.
      for (final locale in docsLocales) {
        for (final guide in allGuides) {
          final own = loadGuide(guide, locale)!.page.toc;
          final source = loadGuide(guide, sourceLocale)!.page.toc;
          expect(
            [for (final h in own) h.depth],
            [for (final h in source) h.depth],
            reason: guide.file(locale),
          );
        }
      }
    });

    test('the same code as the guide in Spanish (tool/thor docs-check)', () {
      // `docs-check` compiles the Spanish pages' code: a translation shows
      // the very same blocks, in the same order.
      List<String> code(String file) => [
        for (final m in RegExp(
          r'^(```[^\n]*\n[\s\S]*?^```)',
          multiLine: true,
        ).allMatches(File('${docsDir()}/$file').readAsStringSync()))
          m[1]!,
      ];
      for (final locale in docsLocales) {
        for (final guide in allGuides) {
          expect(
            code(guide.file(locale)),
            code(guide.file(sourceLocale)),
            reason: guide.file(locale),
          );
        }
      }
    });

    test('every error code and the reference', () {
      for (final locale in docsLocales) {
        if (locale == sourceLocale) continue;
        for (final name in ['README', ...errorCodes()]) {
          final content = loadErrorContent(name, locale)!;
          expect(content.fallback, isFalse, reason: '$locale/$name');
        }
        for (final package in apiPackages) {
          final content = loadApiContent(package, locale)!;
          expect(content.fallback, isFalse, reason: '$locale/$package');
          for (final page in apiPages()) {
            expect(page.labelIn(locale), isNotEmpty);
          }
        }
      }
    });
  });

  group('URLs', () {
    test('each language spells every page once, and back', () {
      for (final locale in docsLocales) {
        final seen = <String>{};
        for (final path in sitePaths()) {
          final spelled = routePathIn(locale, path);
          expect(seen.add(spelled), isTrue, reason: '$locale: $spelled twice');
          expect(routePathOf(locale, spelled), path, reason: '$locale $path');
        }
      }
      expect(
        routePathIn('en', '/empezar/instalacion#paso'),
        '/get-started/installation#paso',
      );
      expect(routePathIn('en', '/errores/THOR-B012'), '/errors/THOR-B012');
      expect(
        routePathIn('en', '/api/thor_ui/controles/FilledButton'),
        '/api/thor_ui/controls/FilledButton',
      );
      expect(routePathIn('es', '/empezar/instalacion'), '/empezar/instalacion');
      expect(localizePath('en', '/buscar'), '/en/search');
      expect(localizePath('es', '/buscar'), '/es/buscar');
    });

    test('a slug names one guide in every language', () {
      final owner = <String, Guide>{};
      for (final guide in allGuides) {
        for (final slug in {guide.slug, ...guide.slugs.values}) {
          final other = owner[slug];
          expect(
            other == null || identical(other, guide),
            isTrue,
            reason: '$slug is ${other?.path} and ${guide.path}',
          );
          owner[slug] = guide;
        }
      }
    });

    test('a page links its other language, and says which it is', () async {
      final client = docsHandler().client(origin: 'http://docs.test');
      final en = (await client.get('/en/get-started/installation')).text;
      expect(en, contains('<html lang="en"'));
      expect(en, contains('hreflang="es" href="/es/empezar/instalacion"'));
      expect(en, contains('href="/es/empezar/instalacion"'));
      final es = (await client.get('/es/empezar/instalacion')).text;
      expect(es, contains('<html lang="es"'));
      expect(es, contains('hreflang="en" href="/en/get-started/installation"'));
      expect((await client.get('/en/errors/THOR-B012')).status, 200);
      expect((await client.get('/en/search')).status, 200);
      expect((await client.get('/en/changes')).status, 200);
    });

    test('the root and the old addresses go to the default language', () async {
      final client = docsHandler().client(origin: 'http://docs.test');
      expect(await client.get('/'), redirectsTo('/en'));
      expect(
        await client.get('/', headers: {HttpHeader.acceptLanguage: 'es-MX'}),
        redirectsTo('/es'),
      );
      expect(
        await client.get('/errores/THOR-B012'),
        redirectsTo('/en/errors/THOR-B012'),
      );
      expect(
        await client.get('/es/recetas/contador'),
        redirectsTo('/es/ejemplos/contador'),
      );
      expect(
        await client.get('/en/recetas/contador'),
        redirectsTo('/en/examples/counter'),
      );
    });
  });
}
