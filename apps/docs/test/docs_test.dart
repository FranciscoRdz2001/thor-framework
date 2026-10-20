import 'dart:io';

import 'package:docs/app.dart';
import 'package:docs/core/content/blocks.dart';
import 'package:docs/core/content/library.dart';
import 'package:docs/core/content/redirects.dart';
import 'package:docs/core/content/widget_docs.dart';
import 'package:docs/core/i18n/docs_locale.dart';
import 'package:docs/modules/guide/examples/examples.dart';
import 'package:docs/shell/docs_locale_routing.dart';
import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart' show exportSite;
import 'package:thor_test/thor_test.dart';

Future<ThorTestResponse> _get(String path) =>
    docsHandler().client(origin: 'http://docs.test').get(path);

/// [path] (a route's own) in the default language, as it is served.
String _es(String path) => localizePath('es', path);

/// Where the old address [target] (a route's own path, or a URL) lands, in
/// [locale].
String _target(String target, [String locale = 'es']) =>
    target.startsWith('http')
    ? target
    : localizeAnchor(locale, localizePath(locale, target));

void main() {
  setUpAll(initializeThorTests);

  group('headings', () {
    test('ids follow GitHub: accents kept, punctuation dropped', () {
      expect(
        headingId('Estilos: qué usar, en orden'),
        'estilos-qué-usar-en-orden',
      );
      expect(headingId('Variantes (`.when()`)'), 'variantes-when');
      expect(
        headingId('Formularios: ¿qué valida el servidor?'),
        'formularios-qué-valida-el-servidor',
      );
      expect(headingId('Caché y deploy'), 'caché-y-deploy');
    });

    test('title, table of contents, repeated ids, description', () {
      final page = renderMarkdown(
        '# 06 · Engine\n\nFirst paragraph.\n\n## One\n\n### Sub\n\n## One\n',
        source: 'docs/x.md',
      );
      expect(page.title, 'Engine');
      expect(page.description, 'First paragraph.');
      expect(
        [for (final e in page.toc) '${e.depth}:${e.href}'],
        ['0:#one', '1:#sub', '0:#one-1'],
      );
      final html = [
        for (final b in page.blocks)
          if (b is ProseBlock) b.html,
      ].join();
      expect(html, contains('<h2 id="one">'));
      expect(html, contains('<h2 id="one-1">'));
      expect(html, isNot(contains('<h1')));
    });
  });

  group('links', () {
    test('another guide, with its anchor: the route, without the language', () {
      expect(rewriteLink('estado.md', 'guia/es'), '/datos-y-estado/estado');
      expect(
        rewriteLink('navegacion.md#ahora', 'guia/es'),
        '/fundamentos/navegacion#ahora',
      );
      expect(rewriteLink('guia/es/estado.md', ''), '/datos-y-estado/estado');
      // Any language lands on the same page.
      expect(rewriteLink('estado.md', 'guia/en'), '/datos-y-estado/estado');
    });

    test('a guide that was renamed, merged or removed lands on the page '
        'that replaced it', () {
      expect(
        rewriteLink('rutas-y-datos.md', 'guia/es'),
        '/fundamentos/navegacion',
      );
      expect(
        rewriteLink('../guia/es/rutas-y-datos.md', 'errores'),
        '/fundamentos/navegacion',
      );
      expect(rewriteLink('guia/capa-web.md', ''), '/fundamentos/widgets');
      expect(
        rewriteLink('entorno.md', 'guia/es'),
        '/datos-y-estado/sesion-y-seguridad#entorno-y-secretos',
      );
      expect(
        rewriteLink('iconos.md', 'guia/es'),
        '/componentes/componentes-contenido#icon',
      );
    });

    test('paths get the reader\'s language when a page is shown', () {
      expect(localizePath('es', '/api/thor_ui'), '/es/api/thor_ui');
      expect(localizePath('en', '/'), '/en');
      expect(localizePath('en', '/es/api'), '/es/api');
      expect(localizePath('es', 'https://dart.dev'), 'https://dart.dev');
      expect(localizePath('es', '/llms.txt'), '/llms.txt');
      expect(
        localizeLinks(
          'en',
          '<p><a class="x" href="/api/a">a</a> <a href="#b">b</a>',
        ),
        '<p><a class="x" href="/en/api/a">a</a> <a href="#b">b</a>',
      );
    });

    test('a page of docs/ that is not on the site goes to GitHub', () {
      expect(
        rewriteLink('../notes.md', 'guia'),
        '$repositoryUrl/blob/master/docs/notes.md',
      );
      expect(
        rewriteLink('notes.md#p1', ''),
        '$repositoryUrl/blob/master/docs/notes.md#p1',
      );
    });

    test('the API reference, from the root and from api/; a topic is its '
        'own page, any other anchor stays', () {
      expect(rewriteLink('api/thor_ui.md', ''), '/api/thor_ui');
      expect(rewriteLink('thor_ui.md#layout', 'api'), '/api/thor_ui/layout');
      expect(rewriteLink('thor_ui.md#nada', 'api'), '/api/thor_ui#nada');
      // Only what an app imports has a reference page.
      expect(
        rewriteLink('thor_style.md', 'api'),
        '$repositoryUrl/blob/master/docs/api/thor_style.md',
      );
    });

    test('files outside the site go to the repository', () {
      expect(
        rewriteLink('../../packages/thor_style/README.md', 'api'),
        '$repositoryUrl/blob/master/packages/thor_style/README.md',
      );
      expect(
        rewriteLink('drafts/page.md', ''),
        '$repositoryUrl/blob/master/docs/drafts/page.md',
      );
      expect(
        rewriteLink('drafts/', ''),
        '$repositoryUrl/tree/master/docs/drafts/',
      );
    });

    test('in-page, absolute and external links are kept', () {
      for (final href in [
        '#fases',
        '/api/thor_ui',
        'https://dart.dev',
        'mailto:a@b.c',
      ]) {
        expect(rewriteLink(href, ''), href);
      }
    });
  });

  group('site', () {
    test('every guide file exists and has a title', () {
      for (final guide in allGuides) {
        final page = loadDoc(guide.file(defaultLocale));
        expect(page, isNotNull, reason: guide.slug);
        expect(page!.title, isNotEmpty, reason: guide.slug);
      }
      for (final package in apiPackages) {
        expect(loadApi(package), isNotNull, reason: package);
      }
    });

    test('the guide says nothing about how thor works inside', () {
      // The engine's protocol and the framework's internals are not the
      // public guide's subject (`guide_public_test.dart`). Every file
      // of `docs/guia/es/` is read (examples too), with word boundaries so
      // `sqlite3` or `literal` are not `lite`. A superset of the words in
      // the error pages' test (`tool/test/error_pages_test.dart`).
      final internals = RegExp(
        r'\bdata-t(?!able)[a-z-]*|thor_engine|oracle|thorElement|ChildRules|WrapData|ParentDataWrapper'
        r'|src/core/|\blite\b|dart2js|\bmotor\b|\btool/|\bapps/'
        // `thor/packages/thor_cli` is where the install command points.
        r'|(?<!thor/)(?<!<thor>/)\bpackages/|\.dart_tool|docs/\d',
      );
      final files = Directory('${docsDir()}/guia/$defaultLocale')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList();
      expect(files.length, greaterThanOrEqualTo(allGuides.length));
      for (final file in files) {
        final text = file.readAsStringSync();
        expect(internals.firstMatch(text)?.group(0), isNull, reason: file.path);
      }
    });

    test('the internals guard does not trip on look-alike words', () {
      final internals = RegExp(r'\blite\b|\bmotor\b');
      for (final ok in ['sqlite3', 'literal', 'motorcycle', 'delite']) {
        expect(internals.hasMatch(ok), isFalse, reason: ok);
      }
      expect(internals.hasMatch('el motor lite'), isTrue);
      final dataT = RegExp(r'\bdata-t(?!able)[a-z-]*');
      expect(dataT.hasMatch('cat-data-table'), isFalse);
      expect(dataT.hasMatch('data-table'), isFalse);
      expect(dataT.hasMatch('data-tt'), isTrue);
    });

    test('every symbol the reference shows is public (an app can import '
        'it)', () {
      final public = {
        for (final line in File(
          '${docsDir()}/api/public_api.txt',
        ).readAsLinesSync())
          if (line.isNotEmpty) line.split('\t')[1],
      };
      final shown = RegExp(r'^### `([^`]+)`', multiLine: true)
          .allMatches(File('${docsDir()}/api/thor_ui.md').readAsStringSync())
          .map((m) => m[1]!)
          .toList();
      expect(shown, isNotEmpty);
      expect(shown.where((s) => !public.contains(s)), isEmpty);
      expect(
        File('${docsDir()}/api/thor_ui.md').readAsStringSync(),
        isNot(contains('lib/src/')),
      );
    });

    test('the API reference is split by topic, each page titled by it', () {
      final dir = Directory.systemTemp.createTempSync('docs_api');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory('${dir.path}/api').createSync();
      File('${dir.path}/api/thor_ui.md').writeAsStringSync(
        '# `thor_ui`\n\nIntro.\n\n| Import | Página |\n|---|---|\n\n'
        '## `layout` · Layout\n\n### `Row` · class\n\n'
        '### `Column` · class\n\n'
        '## `router` · `package:thor_ui/router.dart`\n\n'
        '### `WidgetRenderer` · class\n',
      );
      final pages = apiPages(dir: dir.path);
      expect(pages.map((p) => p.path), [
        '/api/thor_ui',
        '/api/thor_ui/layout',
        '/api/thor_ui/router',
      ]);
      expect(pages.map((p) => p.label), [
        'thor_ui',
        'Layout',
        'package:thor_ui/router.dart',
      ]);
      final root = loadApi('thor_ui', null, dir.path)!;
      expect(root.description, 'Intro.');
      final layout = loadApi('thor_ui', 'layout', dir.path)!;
      expect(layout.title, 'Layout');
      expect(layout.toc.map((e) => e.label), [
        messagesFor('es').apiSymbolsHeading,
        'Row · class',
        'Column · class',
      ]);
      expect(loadApi('thor_ui', 'nada', dir.path), isNull);
      expect(loadApi('otro', null, dir.path), isNull);
    });

    test('every page renders, with its own title and a description', () async {
      final titles = <String>{};
      // Only a guide with an interactive demo loads the engine.
      final withDemos = {
        for (final g in allGuides)
          if (loadGuide(
                g,
                'es',
              )?.page.examples.any((id) => !examples[id]!.native) ??
              false)
            _es(g.path),
      };
      expect(withDemos, contains('/es/empezar/instalacion'));
      // The search page's own script (`search.js`: it fetches the index
      // when there is a query) is the one page of the site with JS that
      // is not the engine.
      withDemos.add('/es/buscar');
      // The home's bench is a live example.
      withDemos.add('/es');
      // A widget's page with a live example may bring its script (the
      // engine, or the widget's own: an autocomplete's); one without ships
      // none.
      final mayScript = {
        for (final w in widgetDocs())
          if (exampleIdsFor(w.name, examples.keys).isNotEmpty) _es(w.path),
      };
      for (final path in [for (final p in sitePaths()) _es(p)]) {
        final r = await _get(path);
        expect(r.status, 200, reason: path);
        // The guide's "copy as Markdown" is a link without its script, and
        // the search pill's ⌘K hint is a link too (its key is a script), and
        // so is the copy button of a code block (`studio-code.js`: without
        // it the button is hidden and the code stays selectable).
        var html = r.text
            .replaceAll(
              RegExp(
                r'<script data-search-href="[^"]*" src="/search-shortcut.js" defer></script>',
              ),
              '',
            )
            .replaceAll('<script src="/copy-md.js" defer></script>', '')
            .replaceAll(
              '<script src="/scripts/studio-code.js" defer></script>',
              '',
            )
            // The theme toggle remembers the choice with one tiny inline
            // script (it runs before the first paint: no flash).
            .replaceAll(
              RegExp(r'<script>[^<]*thor:theme[\s\S]*?</script>'),
              '',
            );
        final title = RegExp('<title>([^<]*)</title>').firstMatch(html)?[1];
        expect(title, isNotNull, reason: path);
        expect(titles.add(title!), isTrue, reason: 'duplicate title: $title');
        expect(html, contains('<meta name="description"'), reason: path);
        expect(html, contains('<html lang="es"'), reason: path);
        // No JS (a debug build adds only thor's inspector). The speculation
        // rules (prefetch on hover) and the JSON-LD are data the browser or
        // a crawler reads, not code.
        // A validated form's messages without the engine come in a small
        // inline script (the engine's forms part), not the engine.
        if (!withDemos.contains(path) &&
            html.contains('data-msg-') &&
            !html.contains('<script src=')) {
          html = html.replaceFirst(RegExp(r'<script>[\s\S]*?</script>'), '');
        }
        // The «sending» state of a form that posts (`form_submit.js`) is one
        // inline script too, engine or not; the guide's demo forms have it.
        html = html.replaceAll(
          RegExp(
            r'<script>(?:(?!</script>)[\s\S])*?data-t-nopending[\s\S]*?</script>',
          ),
          '',
        );
        // The sidebar's scroll restoration (`restorationId`) is a tiny
        // inline enhancement too: without it the sidebar starts at the top.
        final scripts = RegExp(
          '<script(?! id="thor-debug-inspector")(?! type="speculationrules")'
          '(?! type="application/ld\\+json")(?! data-thor-restore)(?! data-thor-prefetch)',
        );
        expect(
          html,
          contains('<script type="application/ld+json">'),
          reason: '$path describes the site',
        );
        if (!mayScript.contains(path)) {
          expect(
            scripts.hasMatch(html),
            withDemos.contains(path),
            reason: withDemos.contains(path)
                ? '$path loads the engine for its demos'
                : '$path ships no JS',
          );
        }
        expect(
          html,
          contains('<script type="speculationrules">'),
          reason: '$path prefetches the next page',
        );
        // The current page is marked in the navigation (the home and the
        // search page are in none of its lists).
        if (path != '/es' && path != '/es/buscar') {
          expect(html, contains('aria-current="page"'), reason: path);
        }
        // The language of the page, and the same page in every language.
        expect(
          html,
          contains(RegExp('<link hreflang="es" href="[^"]+" rel="alternate"')),
          reason: path,
        );
        expect(html, contains('hreflang="x-default"'), reason: path);
      }
      expect(titles, hasLength(sitePaths().length));
    });

    test('every page has its Open Graph card, absolute', () async {
      String? og(String html, String property) =>
          RegExp('property="$property" content="([^"]*)"').firstMatch(html)?[1];
      for (final path in [for (final p in sitePaths()) _es(p)]) {
        final html = (await _get(path)).text;
        final title = RegExp('<title>([^<]*)</title>').firstMatch(html)![1];
        expect(og(html, 'og:title'), title, reason: path);
        expect(og(html, 'og:description'), isNotEmpty, reason: path);
        expect(og(html, 'og:url'), 'http://docs.test$path', reason: path);
        expect(og(html, 'og:image'), 'http://docs.test/og.png', reason: path);
        expect(og(html, 'og:site_name'), 'Thor docs', reason: path);
        expect(
          html,
          contains('name="twitter:card" content="summary_large_image"'),
          reason: path,
        );
      }
    });

    test('the search page is a GET form to itself with its results', () async {
      final html = (await _get('/es/buscar')).text;
      expect(html, contains('role="search"'));
      expect(html, contains('action="/es/buscar"'));
      expect(html, contains('id="docs-results"'));
      expect(html, contains('<script src="/search.js" defer>'));
      // Every page's top bar has the field that lands there, and indexes
      // only its text (not the navigation).
      final page = (await _get('/es/datos-y-estado/estado')).text;
      expect(page, contains('href="/es/buscar"'));
      expect(RegExp('data-pagefind-body').allMatches(page), hasLength(1));
      expect(page, contains('data-pagefind-meta="section:'));
      // The search page itself is not in the index (its text is the form).
      expect(
        (await _get('/es/buscar')).text,
        isNot(contains('data-pagefind-body')),
      );
      // Its messages are the page's, for the script.
      expect(html, contains('data-msg-none="Nada para «{query}»'));
    });

    test(
      'the search page finds its script and index under a path prefix',
      () async {
        final out = await Directory.systemTemp.createTemp('docs_prefix');
        addTearDown(() => out.delete(recursive: true));
        final report = await exportSite(
          docsHandler(baseUrl: 'https://x.dev/thor'),
          paths: ['/buscar'],
          outDir: out.path,
          baseUrl: 'https://x.dev/thor',
        );
        expect(report.failed, isEmpty);
        final html = File('${out.path}/es/buscar.html').readAsStringSync();
        expect(html, contains('<script src="/thor/search.js" defer>'));
        expect(html, contains('data-base="/thor/"'));
        // Without a prefix the root.
        final root = (await _get('/es/buscar')).text;
        expect(root, contains('<script src="/search.js" defer>'));
        expect(root, contains('data-base="/"'));
      },
    );

    test('a guide links its Markdown, which copies with JavaScript', () async {
      final html = (await _get('/es/datos-y-estado/estado')).text;
      expect(html, contains('href="/es/datos-y-estado/estado.md"'));
      expect(html, contains('data-copied="Copiado"'));
      expect(html, contains('data-copy-md'));
      expect(html, contains('<script src="/copy-md.js" defer>'));
      // The API reference has no Markdown of its own.
      expect(
        (await _get('/es/api/thor_ui')).text,
        isNot(contains('data-copy-md')),
      );
    });

    test(
      'a widget has its page: signature, parameters, example, Flutter',
      () async {
        final html = (await _get(
          '/es/api/thor_ui/controles/FilledButton',
        )).text;
        expect(
          html,
          contains('<title>FilledButton · Widget · Thor docs</title>'),
        );
        expect(html, contains('FilledButton.icon'));
        expect(html, contains('onPressed'));
        // The guide's live example of it.
        expect(html, contains('data-studio-code'));
        expect(
          html,
          contains(
            'https://api.flutter.dev/flutter/material/FilledButton-class.html',
          ),
        );
        // The folder's page points at it.
        final folder = (await _get('/es/api/thor_ui/controles')).text;
        expect(
          folder,
          contains('href="/es/api/thor_ui/controles/FilledButton"'),
        );
        expect((await _get('/es/api/thor_ui/controles/Nada')).status, 404);
        expect((await _get('/es/api/thor_ui/layout/FilledButton')).status, 404);
      },
    );

    test('a widget page has a parameter table per constructor', () async {
      final html = (await _get('/es/api/thor_ui/controles/FilledButton')).text;
      expect(html, contains('Parámetros de <code>FilledButton.icon</code>'));
      expect(
        html,
        contains('Parámetros de <code>FilledButton.tonalIcon</code>'),
      );
      // `label` only exists in the icon constructors: its row is in their table.
      final icon = html.split(
        'Parámetros de <code>FilledButton.icon</code>',
      )[1];
      expect(icon.split('<h3')[0], contains('<code>label</code>'));
      final list = (await _get('/es/api/thor_ui/layout/ListView')).text;
      expect(list, contains('Parámetros de <code>ListView.builder</code>'));
      // One constructor: no extra headings.
      expect(
        (await _get('/es/api/thor_ui/layout/Row')).text,
        isNot(contains('Parámetros de')),
      );
    });

    test('a deprecated parameter is marked on its widget page', () async {
      final html = (await _get('/es/api/thor_ui/controles/Radio')).text;
      final row = RegExp(
        r'<tr>(?:(?!</tr>).)*groupValue(?:(?!</tr>).)*</tr>',
      ).firstMatch(html)?[0];
      expect(row, isNotNull);
      expect(row, contains('Deprecado'));
      // The current one is not.
      final id = RegExp(
        r'<tr>(?:(?!</tr>).)*<code>value</code>(?:(?!</tr>).)*</tr>',
      ).firstMatch(html)?[0];
      expect(id, isNot(contains('Deprecado')));
    });

    test(
      'the changes come from the changelogs, with the migration notes',
      () async {
        final index = (await _get('/es/cambios')).text;
        expect(index, contains('<title>Cambios · Thor docs</title>'));
        expect(index, contains('Migrar'));
        expect(index, contains('href="/es/cambios/thor_ui"'));
        // What is deprecated is quoted from the package that says it.
        expect(index, contains('@Deprecated'));
        final ui = (await _get('/es/cambios/thor_ui')).text;
        expect(ui, contains('Sin publicar'));
        expect(ui, contains('<title>Cambios de thor_ui · Thor docs</title>'));
        expect((await _get('/es/cambios/nada')).status, 404);
        // The first release breaks nothing: no warning (what a
        // `**Breaking:**` line gathers is covered by changes_test.dart).
        expect(ui, contains('0.1.0'));
        expect(ui, isNot(contains('Cambios que rompen')));
        // The navigation points at it.
        expect(
          (await _get('/es/empezar/que-es-thor')).text,
          contains('href="/es/cambios"'),
        );
      },
    );

    test('a callout is a labelled note with its tone', () async {
      final html = (await _get('/es/publicar/publicar')).text;
      final callout = RegExp(
        r'<[a-z]+ [^>]*role="note"[^>]*>',
      ).firstMatch(html)?[0];
      expect(callout, isNotNull);
      expect(callout, contains('aria-label="Importante"'));
      expect(html, isNot(contains('thor-callout')));
      final flutter = (await _get('/es/datos-y-estado/formularios')).text;
      expect(flutter, contains('aria-label="Diferencia con Flutter"'));
    });

    test('an unknown guide or package is a 404 in the frame', () async {
      for (final path in [
        '/es/empezar/missing',
        '/es/api/nothing',
        '/es/other',
        '/es/guia/missing',
      ]) {
        final r = await _get(path);
        expect(r.status, 404, reason: path);
        expect(r.text, contains('No encontramos esa página'), reason: path);
        // A 404 is the translation of nothing: no hreflang alternates.
        expect(r.text, isNot(contains('<link hreflang')), reason: path);
      }
    });

    test('/api goes to the first package, in one hop', () async {
      final client = docsHandler().client(origin: 'http://docs.test');
      expect(await client.get('/es/api'), redirectsTo('/es/api/thor_ui'));
      expect(await client.get('/api'), redirectsTo('/en/api/thor_ui'));
    });

    test(
      'every page has a canonical; x-default is the language picker',
      () async {
        final html = (await _get('/es/empezar/instalacion')).text;
        expect(
          html,
          contains(
            '<link href="http://docs.test/es/empezar/instalacion" rel="canonical"/>',
          ),
        );
        expect(html, contains('hreflang="es"'));
        expect(
          html,
          contains('<link hreflang="x-default" href="/" rel="alternate"/>'),
        );
      },
    );

    test('a page without its own file is no hreflang alternate', () {
      expect(DocsLocaleRouting.hasPage('es', '/empezar/instalacion'), isTrue);
      expect(DocsLocaleRouting.hasPage('en', '/empezar/instalacion'), isTrue);
      expect(DocsLocaleRouting.hasPage('en', '/api/thor_ui'), isTrue);
      expect(DocsLocaleRouting.hasPage('en', '/errores/THOR-B012'), isTrue);
      // No file in another language: a fallback copy, not an alternate.
      expect(DocsLocaleRouting.hasPage('fr', '/empezar/instalacion'), isFalse);
      expect(DocsLocaleRouting.hasPage('fr', '/api/thor_ui'), isFalse);
      expect(DocsLocaleRouting.hasPage('fr', '/errores/THOR-B012'), isFalse);
      expect(DocsLocaleRouting.hasPage('fr', '/'), isTrue);
    });

    test('the top bar marks the area the page is in', () async {
      bool marks(String html, String href) => RegExp(
        '<a(?=[^>]*aria-current="page")(?=[^>]*href="$href")[^>]*>',
      ).hasMatch(html);

      expect(marks((await _get('/es/errores')).text, '/es/errores'), isTrue);
      expect(
        marks((await _get('/es/api/thor_ui')).text, '/es/api/thor_ui'),
        isTrue,
      );
      // A guide page is "Guide", not the reference.
      final guide = (await _get('/es/empezar/instalacion')).text;
      expect(marks(guide, '/es/errores'), isFalse);
    });

    test('the root sends the reader to their language', () async {
      final client = docsHandler().client(origin: 'http://docs.test');
      expect(await client.get('/'), redirectsTo('/en'));
      expect(
        await client.get(
          '/',
          headers: {HttpHeader.acceptLanguage: 'fr, es;q=0.8'},
        ),
        redirectsTo('/es'),
      );
      // Every page is under its language: without one it asks for it.
      expect(await client.get('/api/thor_ui'), redirectsTo('/en/api/thor_ui'));
      expect(
        await client.get(
          '/errores/THOR-B012',
          headers: {HttpHeader.acceptLanguage: 'es'},
        ),
        redirectsTo('/es/errores/THOR-B012'),
      );
    });

    test('every old address redirects to a page that exists', () async {
      final client = docsHandler().client(origin: 'http://docs.test');
      final pages = {for (final p in sitePaths()) _es(p)};
      for (final MapEntry(:key, :value) in legacyGuideTargets.entries) {
        // One hop: the old address answers in the reader's language, with
        // no stop at `/es/guia/<slug>` on the way.
        final first = await client.get('/guia/$key');
        expect(first, redirectsTo(_target(value, defaultLocale)), reason: key);
        final r = await client.get('/es/guia/$key');
        expect(r, redirectsTo(_target(value)), reason: key);
        if (!value.startsWith('http')) {
          // An address may land on an anchor of the page.
          expect(pages, contains(_target(value).split('#').first), reason: key);
          // The anchor is a heading of the page in each language.
          for (final locale in docsLocales) {
            final target = _target(value, locale);
            if (!target.contains('#')) continue;
            final [path, anchor] = target.split('#');
            final page = await client.get(path);
            expect(page.text, contains('id="$anchor"'), reason: target);
          }
        }
      }
    });

    test('a page that changed section redirects to where it is now', () async {
      final client = docsHandler().client(origin: 'http://docs.test');
      final pages = {for (final p in sitePaths()) _es(p)};
      for (final MapEntry(:key, :value) in legacySectionTargets.entries) {
        final r = await client.get(_es(key));
        expect(r, redirectsTo(_target(value)), reason: key);
        expect(pages, contains(_target(value).split('#').first), reason: key);
      }
      // A slug no section ever had is still a 404.
      expect(await client.get('/es/aprender/missing'), hasStatus(404));
      expect(await client.get('/es/arquitectura/missing'), hasStatus(404));
    });

    test('a page without a translation shows the default language, and '
        'says so', () {
      final guide = guideBySlug('que-es-thor')!;
      final own = loadGuide(guide, defaultLocale)!;
      expect(own.fallback, isFalse);
      final other = loadGuide(guide, 'xx')!;
      expect(other.fallback, isTrue);
      expect(other.locale, defaultLocale);
      expect(other.page, same(own.page));
    });

    test('every page of the guide is in the navigation, every source is '
        'not', () {
      for (final locale in docsLocales) {
        final slugs = {for (final g in allGuides) g.slugIn(locale)};
        // The examples live in their own folder.
        final examples = guideBySlug(examplesSection)!.slugIn(locale);
        final files = [
          for (final dir in ['guia/$locale', 'guia/$locale/$examples'])
            ...Directory('${docsDir()}/$dir')
                .listSync()
                .whereType<File>()
                .map((f) => f.uri.pathSegments.last)
                .where((name) => name.endsWith('.md')),
        ];
        expect(
          {for (final f in files) f.replaceAll('.md', '')},
          slugs,
          reason: locale,
        );
      }
    });

    test(
      'every interface string is a message: the nav comes from the ARB',
      () async {
        final html = (await _get('/es/empezar/que-es-thor')).text;
        expect(html, contains('Qué es Thor'));
        expect(html, contains('Datos y estado'));
        expect(html, contains('En esta página'));
        expect(html, contains('<html lang="es"'));
        // The language menu, to the same page in the other language.
        expect(html, contains('aria-label="Idioma"'));
        expect(html, contains('href="/en/get-started/what-is-thor"'));
        final en = (await _get('/en/get-started/what-is-thor')).text;
        expect(en, contains('What is Thor'));
        expect(en, contains('Data and state'));
        expect(en, contains('<html lang="en"'));
        expect(en, contains('href="/es/empezar/que-es-thor"'));
      },
    );

    test('the docs folder is the repository\'s', () {
      expect(Directory(docsDir()).existsSync(), isTrue);
    });
  });
}
