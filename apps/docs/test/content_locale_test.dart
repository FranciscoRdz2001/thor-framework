import 'dart:io';

import 'package:docs/app.dart';
import 'package:docs/core/content/library.dart';
import 'package:docs/core/content/widget_docs.dart';
import 'package:docs/core/i18n/docs_locale.dart';
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';

/// Writes [files] (relative to a fresh temp dir that plays `docs/`).
Directory _docs(Map<String, String> files) {
  final dir = Directory.systemTemp.createTempSync('docs_locale');
  for (final MapEntry(:key, :value) in files.entries) {
    File('${dir.path}/$key')
      ..createSync(recursive: true)
      ..writeAsStringSync(value);
  }
  return dir;
}

void main() {
  setUpAll(initializeThorTests);

  group('error pages by language', () {
    late final Directory dir;
    setUpAll(
      () => dir = _docs({
        'errores/THOR-X001.md':
            '# THOR-X001 · Titulo\n\n**Dónde:** `thor build`.\n\n'
            '## Qué pasó\n\nEsto pasó con `x`. Y esto más.\n\n'
            '## Cómo se arregla\n\nHazlo.\n',
        'errores/README.md': '# Códigos\n\nLos códigos.\n',
        'errores/en/THOR-X001.md':
            '# THOR-X001 · Title\n\n**Where:** `thor build`.\n\n'
            '## What happened\n\nThis happened with `x`. And more.\n',
      }),
    );
    tearDownAll(() => dir.deleteSync(recursive: true));

    test('the default language reads docs/errores/<code>.md', () {
      final content = loadErrorContent('THOR-X001', 'es', dir: dir.path)!;
      expect(content.fallback, isFalse);
      expect(content.locale, 'es');
      expect(content.page.title, 'THOR-X001 · Titulo');
    });

    test('a translation lives in docs/errores/<locale>/', () {
      final content = loadErrorContent('THOR-X001', 'en', dir: dir.path)!;
      expect(content.fallback, isFalse);
      expect(content.locale, 'en');
      expect(content.page.title, 'THOR-X001 · Title');
    });

    test('a language without the page shows the default one, and says so', () {
      final content = loadErrorContent('THOR-X001', 'fr', dir: dir.path)!;
      expect(content.fallback, isTrue);
      expect(content.locale, sourceLocale);
      expect(content.page.title, 'THOR-X001 · Titulo');
      expect(loadErrorContent('README', 'en', dir: dir.path)!.fallback, isTrue);
      expect(loadErrorContent('THOR-X999', 'es', dir: dir.path), isNull);
    });

    test('the description is the first sentence of what happened', () {
      final es = loadErrorContent('THOR-X001', 'es', dir: dir.path)!;
      expect(es.page.description, 'Esto pasó con x.');
      final en = loadErrorContent('THOR-X001', 'en', dir: dir.path)!;
      expect(en.page.description, 'This happened with x.');
    });

    test(
      'a link to another code lands on the page, in any language folder',
      () {
        final page = renderMarkdown(
          'x\n\n[b](THOR-B002.md) [i](README.md)',
          source: 'docs/errores/en/THOR-X001.md',
          fileDir: 'errores/en',
        );
        expect(page.html, contains('href="/errores/THOR-B002"'));
        expect(page.html, contains('href="/errores"'));
      },
    );
  });

  group('the API reference by language', () {
    late final Directory dir;
    setUpAll(
      () => dir = _docs({
        'api/thor_ui.md':
            '# `thor_ui`\n\nIntro.\n\n## `layout` · Diseño\n\n### `Row` · class\n',
        'api/en/thor_ui.md':
            '# `thor_ui`\n\nIntro.\n\n## `layout` · Layout\n\n### `Row` · class\n',
        'api/widgets.json':
            '[{"name":"Row","topic":"layout","doc":null,'
            '"flutter":"widgets","constructors":[]}]',
      }),
    );
    tearDownAll(() => dir.deleteSync(recursive: true));

    test('a translation has its own page and topic titles', () {
      final es = loadApiContent(
        'thor_ui',
        'es',
        folder: 'layout',
        dir: dir.path,
      )!;
      final en = loadApiContent(
        'thor_ui',
        'en',
        folder: 'layout',
        dir: dir.path,
      )!;
      expect(es.fallback, isFalse);
      expect(en.fallback, isFalse);
      expect(es.page.title, 'Diseño');
      expect(en.page.title, 'Layout');
      expect(const ApiPage('thor_ui', 'layout').labelIn('en'), 'Layout');
      expect(const ApiPage('thor_ui', 'layout').labelIn('es'), 'Diseño');
    });

    test(
      'a language without a reference shows the default one, and says so',
      () {
        final content = loadApiContent('thor_ui', 'fr', dir: dir.path)!;
        expect(content.fallback, isTrue);
        expect(content.locale, sourceLocale);
        expect(
          loadApiContent('thor_ui', 'es', dir: dir.path)!.fallback,
          isFalse,
        );
        // The title of a topic without a translation is the default's.
        expect(const ApiPage('thor_ui', 'layout').labelIn('fr'), 'Diseño');
        expect(loadApiContent('otro', 'es', dir: dir.path), isNull);
      },
    );

    test('the heading the site adds comes from the messages', () {
      final layout = loadApiContent(
        'thor_ui',
        'es',
        folder: 'layout',
        dir: dir.path,
      )!;
      expect(layout.page.toc.first.label, messagesFor('es').apiSymbolsHeading);
      expect(layout.page.html, contains(messagesFor('es').widgetPageLink));
    });
  });

  group('interface strings of the generated pages', () {
    test('a widget page writes its headings from the messages', () {
      final t = messagesFor('es');
      final widget = widgetDocs().firstWhere(
        (w) => w.constructors.any((c) => c.params.isNotEmpty),
      );
      final markdown = widgetMarkdown(widget, t);
      expect(markdown, contains('## ${t.widgetSignatureHeading}'));
      expect(markdown, contains('## ${t.widgetParamsHeading}'));
      expect(markdown, contains('## ${t.widgetInFlutterHeading}'));
      expect(
        markdown,
        contains('| ${t.widgetColParam} | ${t.widgetColType} |'),
      );
    });

    test('the badges of the guide come from the messages', () {
      final page = renderMarkdown('# T\n\n✅ ❌ 🟡\n', source: 'docs/x.md');
      final t = messagesFor('es');
      expect(page.html, contains('>${t.badgeYes}</strong>'));
      expect(page.html, contains('>${t.badgeNo}</strong>'));
      expect(page.html, contains('>${t.badgePartial}</strong>'));
    });
  });

  group('the site', () {
    test(
      'every error page ends with the index link and has no section after',
      () {
        final pages = Directory('${docsDir()}/errores')
            .listSync()
            .whereType<File>()
            .where((f) => RegExp(r'THOR-[A-Z]\d{3}\.md$').hasMatch(f.path));
        expect(pages, isNotEmpty);
        for (final page in pages) {
          final lines = page
              .readAsLinesSync()
              .where((l) => l.trim().isNotEmpty)
              .toList();
          expect(
            lines.last,
            '[Todos los códigos](README.md)',
            reason: page.path,
          );
        }
      },
    );

    test('an error page describes what happened, not where', () async {
      final client = docsHandler().client(origin: 'http://docs.test');
      for (final code in ['THOR-B012', 'THOR-B021', 'THOR-S001']) {
        final html = (await client.get('/es/errores/$code')).text;
        final description = RegExp(
          r'<meta name="description" content="([^"]*)"',
        ).firstMatch(html)?[1];
        expect(description, isNotNull, reason: code);
        expect(description, isNot(contains('Dónde')), reason: code);
        expect(description, isNot(contains('thor build')), reason: code);
      }
      final b012 = (await client.get('/es/errores/THOR-B012')).text;
      // The `events` section comes before the index link, not after it.
      expect(
        b012.indexOf('Si el error nombra'),
        lessThan(b012.indexOf('Todos los códigos')),
      );
    });

    test(
      'the errors of a state do not ask the developer to pick an engine',
      () {
        for (final code in ['B021', 'B030', 'B033', 'B035']) {
          final title = File(
            '${docsDir()}/errores/THOR-$code.md',
          ).readAsLinesSync().first;
          expect(title, isNot(contains('engine')), reason: code);
          expect(title, isNot(contains('motor')), reason: code);
        }
        final readme = File(
          '${docsDir()}/errores/README.md',
        ).readAsStringSync();
        expect(readme, isNot(contains('vercel.app')));
      },
    );

    test('/api is the reference of thor_ui', () async {
      final client = docsHandler().client(origin: 'http://docs.test');
      final response = await client.get('/es/api');
      expect(response.status, anyOf(301, 308));
      expect(response.headers['location'], '/es/api/thor_ui');
    });
  });
}
