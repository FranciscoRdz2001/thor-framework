/// The documentation: which files of `docs/` are pages, in which section,
/// and how a markdown file becomes a page (HTML, headings, links).
library;

import 'dart:convert';
import 'dart:io';

import 'package:markdown/markdown.dart' as md;

import '../../modules/api/api_routes.dart';
import '../../modules/errors/errors_routes.dart';
import '../i18n/docs_locale.dart';
import 'blocks.dart';
import 'code.dart';
import 'directives.dart';
import 'redirects.dart';
import 'repository.dart';
import 'widget_docs.dart';

export 'repository.dart';

/// How a page's title reads in a language: a message of the ARB.
typedef MessageOf = String Function(AppLocalizations t);

/// A guide page: its [slug] (`que-es-thor`), the [section] it is in and its
/// [title] in the navigation. Its content is `docs/guia/<locale>/<slug>.md`,
/// named by the page's slug in that language.
class Guide {
  /// A guide of [section].
  const Guide(
    this.section,
    this.slug,
    this.title, {
    this.slugs = const {},
    this.sectionSlugs = const {},
  });

  /// The section's URL segment (`empezar`): the route's own.
  final String section;

  /// Its URL segment: the route's own (`que-es-thor`).
  final String slug;

  /// Its name in the navigation, in the page's language.
  final MessageOf title;

  /// Its URL segment in the languages that spell it otherwise
  /// (`{'en': 'what-is-thor'}`).
  final Map<String, String> slugs;

  /// The section's URL segment in the languages that spell it otherwise.
  final Map<String, String> sectionSlugs;

  /// Its URL, without the language (`/empezar/que-es-thor`): the route's
  /// own path, the one the code links to. [localizePath] spells it in a
  /// language (`/en/get-started/what-is-thor`).
  String get path => '/$section/$slug';

  /// Its URL segment in [locale].
  String slugIn(String locale) => slugs[locale] ?? slug;

  /// Its section's URL segment in [locale].
  String sectionIn(String locale) => sectionSlugs[locale] ?? section;

  /// Its URL in [locale], without the language (`/get-started/what-is-thor`).
  String pathIn(String locale) => '/${sectionIn(locale)}/${slugIn(locale)}';

  /// Its file in `docs/` for [locale]: the examples are in a folder of their
  /// own (`guia/es/ejemplos/`, `guia/en/examples/`).
  String file(String locale) =>
      section == examplesSection && slug != examplesSection
      ? 'guia/$locale/${sectionIn(locale)}/${slugIn(locale)}.md'
      : 'guia/$locale/${slugIn(locale)}.md';
}

/// A titled section of the navigation: its guides, in reading order.
class GuideSection {
  /// A section whose pages are [pages] (slug, its spelling in the other
  /// languages, title); [slugs] is its own segment in the other languages.
  GuideSection(
    this.slug,
    this.title,
    this.summary,
    List<(String, Map<String, String>, MessageOf)> pages, {
    this.slugs = const {},
  }) : guides = [
         for (final (page, spelled, name) in pages)
           Guide(slug, page, name, slugs: spelled, sectionSlugs: slugs),
       ];

  /// Its URL segment (`empezar`): the route's own.
  final String slug;

  /// Its name, in the page's language.
  final MessageOf title;

  /// What it is for, in the page's language (the home page's map).
  final MessageOf summary;

  /// Its URL segment in the languages that spell it otherwise.
  final Map<String, String> slugs;

  /// Its guides, in reading order.
  final List<Guide> guides;
}

/// The section of the widget catalog: a tab of the top bar of its own.
const componentsSection = 'componentes';

/// The section of the examples: a tab of the top bar of its own, its pages in
/// `docs/guia/<locale>/ejemplos/`.
const examplesSection = 'ejemplos';

/// Every section and page of the guide, as the navigation shows them. This
/// is the only place that says which page is where; the names are messages
/// of `lib/l10n/` and the content is `docs/guia/<locale>/<slug>.md`.
final guideSections = [
  GuideSection(
    'empezar',
    (t) => t.sectionGetStarted,
    (t) => t.sectionGetStartedSummary,
    [
      ('que-es-thor', {'en': 'what-is-thor'}, (t) => t.pageWhatIsThor),
      ('instalacion', {'en': 'installation'}, (t) => t.pageInstallation),
      ('primera-app', {'en': 'first-app'}, (t) => t.pageFirstApp),
      ('desde-flutter', {'en': 'from-flutter'}, (t) => t.pageFromFlutter),
    ],
    slugs: {'en': 'get-started'},
  ),
  GuideSection(
    'fundamentos',
    (t) => t.sectionFundamentals,
    (t) => t.sectionFundamentalsSummary,
    [
      ('widgets', {}, (t) => t.pageWidgets),
      ('layout', {}, (t) => t.pageLayout),
      ('interactividad', {'en': 'interactivity'}, (t) => t.pageInteractivity),
      ('navegacion', {'en': 'navigation'}, (t) => t.pageNavigation),
      ('leer-datos', {'en': 'reading-data'}, (t) => t.pageReadingData),
    ],
    slugs: {'en': 'fundamentals'},
  ),
  GuideSection(
    'arquitectura',
    (t) => t.sectionArchitecture,
    (t) => t.sectionArchitectureSummary,
    [
      (
        'arquitectura',
        {'en': 'app-architecture'},
        (t) => t.pageAppArchitecture,
      ),
      (
        'estructura',
        {'en': 'project-structure'},
        (t) => t.pageProjectStructure,
      ),
      ('capa-ui', {'en': 'ui-layer'}, (t) => t.pageUiLayer),
      ('capa-datos', {'en': 'data-layer'}, (t) => t.pageDataLayer),
      ('patrones', {'en': 'patterns'}, (t) => t.pagePatterns),
      ('como-funciona', {'en': 'how-it-works'}, (t) => t.pageHowItWorks),
    ],
    slugs: {'en': 'architecture'},
  ),
  GuideSection(
    'interfaz',
    (t) => t.sectionInterface,
    (t) => t.sectionInterfaceSummary,
    [
      (
        'tema-y-estilos',
        {'en': 'theme-and-styles'},
        (t) => t.pageThemeAndStyles,
      ),
      (
        'estilos-avanzados',
        {'en': 'advanced-styles'},
        (t) => t.pageAdvancedStyles,
      ),
      ('animaciones', {'en': 'animations'}, (t) => t.pageAnimations),
      ('gestos', {'en': 'gestures'}, (t) => t.pageGestures),
      (
        'dialogos-y-menus',
        {'en': 'dialogs-and-menus'},
        (t) => t.pageDialogsAndMenus,
      ),
      ('accesibilidad', {'en': 'accessibility'}, (t) => t.pageAccessibility),
      ('idiomas', {'en': 'localization'}, (t) => t.pageLocalization),
      (
        'flutter-embebido',
        {'en': 'embedded-flutter'},
        (t) => t.pageEmbeddedFlutter,
      ),
    ],
    slugs: {'en': 'interface'},
  ),
  GuideSection(
    'datos-y-estado',
    (t) => t.sectionDataAndState,
    (t) => t.sectionDataAndStateSummary,
    [
      ('estado', {'en': 'state'}, (t) => t.pageState),
      (
        'red-y-servidor',
        {'en': 'server-and-actions'},
        (t) => t.pageServerAndActions,
      ),
      ('formularios', {'en': 'forms'}, (t) => t.pageForms),
      ('datos-vivos', {'en': 'live-data'}, (t) => t.pageLiveData),
      ('listas-largas', {'en': 'long-lists'}, (t) => t.pageLongLists),
      ('paquetes', {'en': 'pub-packages'}, (t) => t.pagePubPackages),
      (
        'sesion-y-seguridad',
        {'en': 'session-and-security'},
        (t) => t.pageSessionAndSecurity,
      ),
    ],
    slugs: {'en': 'data-and-state'},
  ),
  GuideSection(
    'publicar',
    (t) => t.sectionTestAndDeploy,
    (t) => t.sectionTestAndDeploySummary,
    [
      ('pruebas', {'en': 'testing'}, (t) => t.pageTesting),
      ('cli', {}, (t) => t.pageCli),
      ('publicar', {'en': 'build-and-deploy'}, (t) => t.pageBuildAndDeploy),
      ('seo', {}, (t) => t.pageSeo),
    ],
    slugs: {'en': 'test-and-deploy'},
  ),
  // The two tabs of the top bar with a sidebar of their own.
  GuideSection(
    componentsSection,
    (t) => t.sectionComponents,
    (t) => t.sectionComponentsSummary,
    [
      ('componentes', {'en': 'components'}, (t) => t.pageComponents),
      (
        'componentes-botones',
        {'en': 'components-buttons'},
        (t) => t.pageComponentsButtons,
      ),
      (
        'componentes-entradas',
        {'en': 'components-inputs'},
        (t) => t.pageComponentsInputs,
      ),
      (
        'componentes-seleccion',
        {'en': 'components-selection'},
        (t) => t.pageComponentsSelection,
      ),
      (
        'componentes-contenido',
        {'en': 'components-content'},
        (t) => t.pageComponentsContent,
      ),
      (
        'componentes-navegacion',
        {'en': 'components-navigation'},
        (t) => t.pageComponentsNavigation,
      ),
      (
        'componentes-avisos',
        {'en': 'components-feedback'},
        (t) => t.pageComponentsFeedback,
      ),
    ],
    slugs: {'en': 'components'},
  ),
  GuideSection(
    examplesSection,
    (t) => t.sectionExamples,
    (t) => t.sectionExamplesSummary,
    [
      ('ejemplos', {'en': 'examples'}, (t) => t.pageExamples),
      ('contador', {'en': 'counter'}, (t) => t.pageExampleCounter),
      ('temperatura', {'en': 'temperature'}, (t) => t.pageExampleTemperature),
      ('vuelos', {'en': 'flight-booker'}, (t) => t.pageExampleFlightBooker),
      ('temporizador', {'en': 'timer'}, (t) => t.pageExampleTimer),
      ('crud', {}, (t) => t.pageExampleCrud),
      ('circulos', {'en': 'circle-drawer'}, (t) => t.pageExampleCircleDrawer),
      ('celdas', {'en': 'cells'}, (t) => t.pageExampleCells),
      (
        'pagina-de-contenido',
        {'en': 'content-page'},
        (t) => t.pageExampleContentPage,
      ),
      (
        'deslizar-confirmar',
        {'en': 'slide-to-confirm'},
        (t) => t.pageExampleSlideToConfirm,
      ),
      ('copiar', {'en': 'copy-button'}, (t) => t.pageExampleCopyButton),
      ('pestanas', {'en': 'tab-indicator'}, (t) => t.pageExampleTabIndicator),
      ('avisos', {'en': 'toast-stack'}, (t) => t.pageExampleToastStack),
    ],
    slugs: {'en': 'examples'},
  ),
];

/// The API reference pages (`docs/api/<package>.md`, from `tool/thor docs`):
/// what an app can import, all of it through `thor_ui`.
const apiPackages = ['thor_ui'];

/// An API reference page: a [package]'s index, or one of its topics
/// ([folder]: `layout`, `estilos`, `router`…), one page each (a page with
/// every widget would be ~1,400 elements).
class ApiPage {
  /// A page.
  const ApiPage(this.package, [this.folder]);

  /// The package.
  final String package;

  /// The folder of `lib/src/`, or null for the package's page.
  final String? folder;

  /// Its URL.
  String get path => folder == null
      ? apiPackageRoute.link({'package': package})
      : apiTopicRoute.link({'package': package, 'folder': folder!});

  /// Its name in the navigation: the topic's title, in the default language.
  String get label => labelIn(defaultLocale);

  /// Its name in the navigation in [locale]: the topic's title in that
  /// language's reference, or the generated one's when it has none.
  String labelIn(String locale) {
    if (folder == null) return package;
    // The titles are read with the pages; a sidebar may ask before.
    for (final l in {sourceLocale, locale}) {
      if (!_titles.containsKey(l)) _apiSections(package, docsDir(), l);
    }
    final title = _titles[locale]?[folder] ?? _titles[sourceLocale]?[folder];
    return (title ?? folder!).replaceAll('`', '');
  }
}

/// A topic's heading in the generated reference: `## \`slug\` · Title`.
final _folder = RegExp(r'^## `([a-z_]+)` · (.+)$');

/// The topics' titles by language, then folder.
final _titles = <String, Map<String, String>>{};
final _widgetEntry = RegExp(r'^### `(\w+)` · class$');

/// Where the reference of [package] in [locale] is: `docs/api/<package>.md`
/// is [sourceLocale]'s and `docs/api/<locale>/` another language's (`tool/thor
/// docs` writes both).
File _apiFile(String package, String dir, String locale) =>
    locale == sourceLocale
    ? File('$dir/api/$package.md')
    : File('$dir/api/$locale/$package.md');

/// The markdown of [package] in [locale] by page: null → the package's (its
/// intro and the files outside a folder), else a folder's sections.
Map<String?, String> _apiSections(String package, String dir, String locale) =>
    _sections['$dir/$locale/$package'] ??= _splitApi(package, dir, locale);

final _sections = <String, Map<String?, String>>{};

Map<String?, String> _splitApi(String package, String dir, String locale) {
  final file = _apiFile(package, dir, locale);
  if (!file.existsSync()) return const {};
  final t = messagesFor(locale);
  final lines = const LineSplitter().convert(file.readAsStringSync());
  final title = lines.first;
  final pages = <String?, List<String>>{null: []};
  String? current;
  final titles = <String, String>{};
  for (final line in lines.skip(1)) {
    if (line.startsWith('## ')) {
      final topic = _folder.firstMatch(line);
      current = topic?[1];
      if (topic != null) {
        titles[topic[1]!] = topic[2]!;
        continue; // the topic's title is its page's title
      }
    }
    (pages[current] ??= []).add(line);
    // A widget has a page of its own: the entry says so under its heading.
    final entry = _widgetEntry.firstMatch(line);
    if (entry != null && current != null) {
      final widget = widgetDoc(current, entry[1]!, dir: dir);
      if (widget != null) {
        pages[current]!.addAll(['', '[${t.widgetPageLink}](${widget.path})']);
      }
    }
  }
  (_titles[locale] ??= {}).addAll(titles);
  return {
    for (final MapEntry(:key, :value) in pages.entries)
      key: [
        if (key == null) title else '# ${titles[key]}',
        // The entries are `###`: a heading level between them and the title
        // (headings go down one level at a time).
        if (key != null) ...['', '## ${t.apiSymbolsHeading}'],
        ...value,
      ].join('\n'),
  };
}

/// Every API reference page, packages first, each followed by its folders.
List<ApiPage> apiPages({String? dir}) => [
  for (final p in apiPackages)
    for (final folder in _apiSections(p, dir ?? docsDir(), sourceLocale).keys)
      ApiPage(p, folder),
];

/// The reference page of [package] ([folder]: one of its `lib/src/`
/// folders), rendered once per process; null if there is none.
DocPage? loadApi(String package, [String? folder, String? dir]) =>
    loadApiContent(package, defaultLocale, folder: folder, dir: dir)?.page;

/// The reference page of [package] in [locale] (`docs/api/<locale>/`); when
/// that language has no reference, the generated one's ([sourceLocale],
/// `fallback`, so the page says so). Null when there is none at all.
GuideContent? loadApiContent(
  String package,
  String locale, {
  String? folder,
  String? dir,
}) {
  if (!apiPackages.contains(package)) return null;
  final root = dir ?? docsDir();
  var served = locale;
  if (!_apiFile(package, root, served).existsSync()) served = sourceLocale;
  final key = '$root/$served/api/$package.md#${folder ?? ''}';
  final markdown = _apiSections(package, root, served)[folder];
  if (markdown == null) return null;
  final page = _cache[key] ??= renderMarkdown(
    markdown,
    source: 'docs/api/$package.md',
    fileDir: 'api',
    locale: served,
  );
  return (page: page, locale: served, fallback: served != locale);
}

/// Every guide in reading order.
final List<Guide> allGuides = [for (final s in guideSections) ...s.guides];

/// The guide at [slug] (the route's own, or its spelling in any language:
/// the name of its file there), or null.
Guide? guideBySlug(String slug) {
  for (final g in allGuides) {
    if (g.slug == slug || g.slugs.containsValue(slug)) return g;
  }
  return null;
}

/// The guide at `/<section>/<slug>`, or null.
Guide? guideAt(String section, String slug) {
  final guide = guideBySlug(slug);
  return guide != null && guide.section == section ? guide : null;
}

/// The first segment of the pages outside the guide, in the languages that
/// spell it otherwise (the route's own is the key: `/errores`).
const rootSlugs = {
  'en': {'errores': 'errors', 'cambios': 'changes', 'buscar': 'search'},
};

/// The topics of the API reference (`/api/thor_ui/<folder>`), in the
/// languages that spell them otherwise.
const apiFolderSlugs = {
  'en': {
    'texto': 'text',
    'controles': 'controls',
    'estilos': 'styles',
    'animacion': 'animation',
    'estado': 'state',
  },
};

/// [path], a route's own (`/empezar/instalacion#paso`), as [locale] spells
/// it (`/get-started/installation#paso`), without the language: a guide's
/// section and slug, the first segment of the other pages and the API's
/// topics. What follows `?` or `#` is kept.
String routePathIn(String locale, String path) => _respell(path, (segments) {
  if (segments.length == 2) {
    final guide = guideAt(segments[0], segments[1]);
    if (guide != null) {
      return [guide.sectionIn(locale), guide.slugIn(locale)];
    }
  }
  return _respellOthers(segments, rootSlugs[locale], apiFolderSlugs[locale]);
});

/// The route's own path of [path] as [locale] spells it
/// (`/get-started/installation` in `en` → `/empezar/instalacion`): what the
/// router matches. A path [locale] doesn't spell is kept.
String routePathOf(String locale, String path) => _respell(path, (segments) {
  if (segments.length == 2) {
    final guide = (_spelled[locale] ??= {
      for (final g in allGuides) g.pathIn(locale): g,
    })['/${segments[0]}/${segments[1]}'];
    if (guide != null) return [guide.section, guide.slug];
  }
  return _respellOthers(
    segments,
    _inverse(rootSlugs[locale]),
    _inverse(apiFolderSlugs[locale]),
  );
});

final _spelled = <String, Map<String, Guide>>{};

Map<String, String>? _inverse(Map<String, String>? map) =>
    map == null ? null : {for (final e in map.entries) e.value: e.key};

/// [path] with its segments (before `?` or `#`) through [change].
String _respell(String path, List<String> Function(List<String>) change) {
  if (!path.startsWith('/') || path == '/') return path;
  final cut = path.indexOf(RegExp('[?#]'));
  final body = cut < 0 ? path : path.substring(0, cut);
  final rest = cut < 0 ? '' : path.substring(cut);
  final segments = body.substring(1).split('/');
  return '/${change(segments).join('/')}$rest';
}

/// [segments] of a page outside the guide with its first segment ([roots])
/// and its API topic ([folders]) respelled.
List<String> _respellOthers(
  List<String> segments,
  Map<String, String>? roots,
  Map<String, String>? folders,
) => [
  for (var i = 0; i < segments.length; i++)
    switch (i) {
      0 => roots?[segments[0]] ?? segments[0],
      2 when segments[0] == 'api' => folders?[segments[2]] ?? segments[2],
      _ => segments[i],
    },
];

/// The section [guide] is in.
GuideSection sectionOfGuide(Guide guide) =>
    guideSections.firstWhere((s) => s.slug == guide.section);

/// A guide's content in a language.
typedef GuideContent = ({DocPage page, String locale, bool fallback});

/// The content of [guide] in [locale]; when that language has no file for
/// it, the default language's (`fallback`, so the page says so). Null when
/// not even the default has it.
GuideContent? loadGuide(Guide guide, String locale, {String? dir}) {
  final own = loadDoc(guide.file(locale), dir: dir);
  if (own != null) return (page: own, locale: locale, fallback: false);
  if (locale == defaultLocale) return null;
  final base = loadDoc(guide.file(defaultLocale), dir: dir);
  return base == null
      ? null
      : (page: base, locale: defaultLocale, fallback: true);
}

/// The error page [name] (`THOR-B012`, or `README` for the index) in
/// [locale]: `docs/errores/<locale>/<name>.md` is a translation, and
/// `docs/errores/<name>.md` is [sourceLocale]'s (`fallback`, so the page
/// says so). Its description is the first sentence of what happened,
/// not the line that says where. Null when there is no such page.
GuideContent? loadErrorContent(String name, String locale, {String? dir}) {
  final own = locale == sourceLocale
      ? null
      : loadDoc('errores/$locale/$name.md', dir: dir);
  final served = own ?? loadDoc('errores/$name.md', dir: dir);
  if (served == null) return null;
  final page = name == 'README' ? served : _errorWithSummary(served);
  return (
    page: page,
    locale: own == null ? sourceLocale : locale,
    fallback: own == null && locale != sourceLocale,
  );
}

final _summaries = Expando<DocPage>('error summaries');

/// [page] with its description set to the first sentence of its first
/// section (`## What happened`): an error page opens with the line that
/// says where it comes from, which says nothing in a search result.
DocPage _errorWithSummary(DocPage page) => _summaries[page] ??= () {
  final summary = _firstSectionSentence(page.html);
  return DocPage(
    title: page.title,
    blocks: page.blocks,
    toc: page.toc,
    description: summary ?? page.description,
    source: page.source,
    examples: page.examples,
  );
}();

/// The first sentence of the first paragraph after the first `<h2>`, as
/// plain text, or null.
String? _firstSectionSentence(String html) {
  final h2 = html.indexOf('</h2>');
  if (h2 < 0) return null;
  final paragraph = RegExp(r'<p>([\s\S]*?)</p>').firstMatch(html.substring(h2));
  if (paragraph == null) return null;
  final text = _unescape(
    paragraph[1]!.replaceAll(RegExp('<[^>]+>'), ''),
  ).replaceAll(RegExp(r'\s+'), ' ').trim();
  final end = RegExp(r'[.!?](?=\s|$)').firstMatch(text);
  final sentence = end == null ? text : text.substring(0, end.end);
  return sentence.isEmpty ? null : sentence;
}

/// A rendered markdown page.
class DocPage {
  /// A page.
  const DocPage({
    required this.title,
    required this.blocks,
    required this.toc,
    this.description,
    required this.source,
    this.examples = const [],
    this.benches = const [],
    this.layers = const [],
  });

  /// The `# title` (without its `NN ·` number).
  final String title;

  /// The body, without the title: prose, code, callouts, steps, examples…
  final List<DocBlock> blocks;

  /// The page's prose as HTML, without its code blocks and directives:
  /// what a summary or a search reads.
  String get html => [
    for (final b in blocks)
      if (b is ProseBlock) b.html,
  ].join('\n');

  /// Its `##` and `###` headings.
  final List<DocHeading> toc;

  /// The first paragraph as plain text (the page's meta description).
  final String? description;

  /// The source file, relative to the repository (`docs/guia/es/estado.md`),
  /// or null for a page generated from several files.
  final String? source;

  /// The live examples it shows (`:::example`, `:::bench`), in order.
  final List<String> examples;

  /// The ones of them written `:::bench`: each must declare controls.
  final List<String> benches;

  /// The layer sets it shows (`:::layers`), in order.
  final List<String> layers;
}

/// Where `docs/` is: `DOCS_DIR`, or the repository's from this app.
String docsDir() =>
    Platform.environment['DOCS_DIR'] ??
    (Directory('../../docs').existsSync() ? '../../docs' : 'docs');

final _cache = <String, DocPage>{};

/// The page of [file] (relative to [docsDir]), rendered once per process.
DocPage? loadDoc(String file, {String? dir}) {
  final root = dir ?? docsDir();
  final key = '$root/$file';
  final cached = _cache[key];
  if (cached != null) return cached;
  final f = File(key);
  if (!f.existsSync()) return null;
  final page = renderMarkdown(
    f.readAsStringSync(),
    source: 'docs/$file',
    fileDir: file.contains('/') ? file.substring(0, file.lastIndexOf('/')) : '',
    locale: _contentLocale(file),
  );
  return _cache[key] = page;
}

/// Renders [markdown]: the `#` title comes out as [DocPage.title], `##`
/// and `###` get GitHub-style ids (the docs link to `#qué-usar-en-orden`),
/// Dart code blocks are highlighted, and links between docs point to the
/// site's pages ([fileDir]: the folder of the file inside `docs/`). [locale]
/// is the language the markdown is written in: the titles and labels the
/// renderer adds (callouts, "Terminal") are in it.
DocPage renderMarkdown(
  String markdown, {
  required String? source,
  String fileDir = '',
  String locale = sourceLocale,
}) {
  final lines = const LineSplitter().convert(markdown);
  var title = '';
  var from = 0;
  while (from < lines.length && lines[from].trim().isEmpty) {
    from++;
  }
  if (from < lines.length && lines[from].startsWith('# ')) {
    // The heading's text, as the markdown shows it (no `code` marks).
    title = _unescape(
      md
          .markdownToHtml(lines[from].substring(2).trim(), inlineOnly: true)
          .replaceAll(RegExp('<[^>]+>'), ''),
    ).replaceFirst(RegExp(r'^\d+\s*·\s*'), '');
    from++;
  }
  final renderer = _Renderer(fileDir, messagesFor(locale));
  final blocks = renderer.blocks(lines.sublist(from).join('\n'));
  return DocPage(
    title: title,
    blocks: blocks,
    toc: renderer.toc,
    description: renderer.description,
    source: source,
    examples: renderer.examples,
    benches: renderer.benches,
    layers: renderer.layers,
  );
}

/// Renders markdown with the guide's directives (`directives.dart`), one
/// page at a time: headings get unique ids and join [toc] in order, also
/// inside a directive. The result is blocks, not HTML: prose stays HTML,
/// everything else (code, callouts, steps…) is data a widget draws.
class _Renderer implements DirectiveContext {
  _Renderer(this.fileDir, this.l10n);

  final String fileDir;

  @override
  final AppLocalizations l10n;

  final toc = <DocHeading>[];
  final examples = <String>[];
  final benches = <String>[];
  final layers = <String>[];
  final _used = <String, int>{};
  String? description;

  @override
  List<DocBlock> blocks(String markdown) {
    final out = <DocBlock>[];
    for (final part in splitDirectives(markdown)) {
      if (part is Directive) {
        out.addAll(parseDirective(part, this) ?? blocks(part.body));
      } else {
        out.addAll(_markdown(part as String));
      }
    }
    return out;
  }

  @override
  String link(String href) => rewriteLink(href, fileDir);

  @override
  void useExample(String id, {bool bench = false}) {
    examples.add(id);
    if (bench) benches.add(id);
  }

  @override
  void useLayers(String id) => layers.add(id);

  // A step is one of the page's sections: it sits at the top of the TOC.
  @override
  String heading(String text) => _heading(text, depth: 0);

  /// A unique id for [text], listed in [toc] at [depth].
  String _heading(String text, {required int depth}) {
    final base = headingId(text);
    final n = _used[base] = (_used[base] ?? -1) + 1;
    final id = n == 0 ? base : '$base-$n';
    toc.add(DocHeading(text, '#$id', depth: depth));
    return id;
  }

  /// The blocks of plain markdown: each top-level code fence is a block of
  /// its own, the rest is prose between them.
  List<DocBlock> _markdown(String markdown) {
    if (markdown.trim().isEmpty) return const [];
    final document = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: true,
    );
    final nodes = document.parseLines(const LineSplitter().convert(markdown));
    nodes.forEach(_visit);
    final out = <DocBlock>[];
    final prose = <md.Node>[];
    void flush() {
      if (prose.isEmpty) return;
      final html = _badgesIn(
        _dropBlockNewlines(md.HtmlRenderer().render(prose)),
        l10n,
      );
      if (html.trim().isNotEmpty) out.add(ProseBlock(html));
      prose.clear();
    }

    for (final node in nodes) {
      if (node is md.Element && node.tag == 'pre') {
        flush();
        final code = node.children?.firstOrNull;
        final cls = code is md.Element ? code.attributes['class'] : null;
        out.add(
          codeBlockOf(
            _unescape(node.textContent),
            cls?.replaceFirst('language-', ''),
            _unescape(node.attributes['data-metadata'] ?? ''),
          ),
        );
      } else {
        prose.add(node);
      }
    }
    flush();
    return out;
  }

  void _visit(md.Node node) {
    if (node is! md.Element) return;
    switch (node.tag) {
      case 'h2' || 'h3':
        final text = _unescape(node.textContent);
        node.attributes['id'] = _heading(text, depth: node.tag == 'h2' ? 0 : 1);
      case 'p' when description == null && toc.isEmpty:
        description = _unescape(node.textContent).replaceAll('\n', ' ');
      case 'a':
        final href = node.attributes['href'];
        if (href != null) node.attributes['href'] = link(href);
      case 'li':
        // A task list's box is named by its text (axe `label`).
        final first = node.children?.firstOrNull;
        if (first is md.Element && first.tag == 'input') {
          final kids = List<md.Node>.of(node.children!);
          node.children!
            ..clear()
            ..add(md.Element('label', kids));
        }
      case 'table':
        // Wide tables scroll sideways: reachable with the keyboard (axe
        // scrollable-region-focusable).
        node.attributes['tabindex'] = '0';
      case 'pre':
        // A block of its own, made by `_markdown`.
        return;
    }
    node.children?.forEach(_visit);
  }
}

/// The guide's status emoji, as words (they read as text, not pictures).
String _badgesIn(String html, AppLocalizations t) {
  final badges = {
    '✅': '<strong>${t.badgeYes}</strong>',
    '❌': '<strong>${t.badgeNo}</strong>',
    '🟡': '<strong>${t.badgePartial}</strong>',
  };
  var out = html;
  for (final MapEntry(:key, :value) in badges.entries) {
    out = out.replaceAll(key, value);
  }
  return out;
}

const _blockTags =
    'p|ul|ol|li|h[1-6]|blockquote|table|thead|tbody|tr|th|td|pre|hr|div|'
    'figure';
final _afterBlock = RegExp('(<\\/?(?:$_blockTags)\\b[^>]*>)\\n+');
final _beforeBlock = RegExp('\\n+(<\\/?(?:$_blockTags)\\b)');
final _preBlock = RegExp(r'<pre\b[\s\S]*?</pre>');

/// The renderer puts a newline around every block tag: each one is a
/// whitespace text node in the DOM (hundreds per guide). Between blocks it
/// means nothing; inside a paragraph (a soft break) it is a space and is
/// kept, and so is everything inside `<pre>`.
String _dropBlockNewlines(String html) {
  final out = StringBuffer();
  var last = 0;
  String strip(String s) => s
      .replaceAllMapped(_afterBlock, (m) => m[1]!)
      .replaceAllMapped(_beforeBlock, (m) => m[1]!);
  for (final m in _preBlock.allMatches(html)) {
    out
      ..write(strip(html.substring(last, m.start)))
      ..write(m[0]);
    last = m.end;
  }
  out.write(strip(html.substring(last)));
  return out.toString();
}

/// GitHub's heading anchor: lowercase, punctuation dropped (letters with
/// accents kept), spaces to `-`.
String headingId(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}\s_-]', unicode: true), '')
    .trim()
    .replaceAll(RegExp(r'\s'), '-');

/// `guia/es/estado.md`, `guia/es/ejemplos/contador.md`, `guia/estado.md`: a
/// file of the guide, by its slug.
final _guideFile = RegExp(
  r'^guia/(?:[a-z]{2}(?:-[A-Za-z]+)?/)?(?:ejemplos/|examples/)?([\w-]+)\.md$',
);

/// The language of a file of `docs/`: the folder of a guide's or an error
/// page's translation, else [sourceLocale] (the generated API reference and
/// the error pages next to the README are written in it).
String _contentLocale(String file) =>
    RegExp(
      r'^(?:guia|errores|api)/([a-z]{2}(?:-[A-Za-z]+)?)/',
    ).firstMatch(file)?[1] ??
    sourceLocale;

/// A link in `docs/[fileDir]/…`: another guide → its page (anchor kept);
/// the API reference → its page; another file of the repository → GitHub;
/// anything absolute is kept.
String rewriteLink(String href, String fileDir) {
  if (href.startsWith('#') ||
      href.contains('://') ||
      href.startsWith('mailto:') ||
      href.startsWith('/')) {
    return href;
  }
  final hash = href.indexOf('#');
  final target = hash < 0 ? href : href.substring(0, hash);
  final anchor = hash < 0 ? '' : href.substring(hash);
  final normalized = _normalize(fileDir.isEmpty ? target : '$fileDir/$target');
  if (normalized == null) return '${repoFile(target)}$anchor';
  final path = normalized;
  final page = _guideFile.firstMatch(path);
  if (page != null) {
    // A page of the guide (in any language, or one that moved or left: see
    // `redirects.dart`), at the route's own path: the page's view puts the
    // reader's language in front of it.
    final target = guideBySlug(page[1]!)?.path ?? legacyGuidePath(page[1]!);
    if (target != null) return '$target$anchor';
  }
  final api = RegExp(r'^api/([a-z_]+)\.md$').firstMatch(path);
  if (api != null && apiPackages.contains(api[1])) {
    // A topic of the reference is its own page.
    final topic = anchor.length > 1 ? anchor.substring(1) : null;
    if (topic != null &&
        _apiSections(api[1]!, docsDir(), sourceLocale).containsKey(topic)) {
      return apiTopicRoute.link({'package': api[1]!, 'folder': topic});
    }
    return '${apiPackageRoute.link({'package': api[1]!})}$anchor';
  }
  if (RegExp(r'^errores/(?:[a-z]{2}/)?README\.md$').hasMatch(path)) {
    return '${errorsRoute.link()}$anchor';
  }
  final code = RegExp(
    r'^errores/(?:[a-z]{2}/)?(THOR-[A-Z]\d{3})\.md$',
  ).firstMatch(path);
  if (code != null) return '${errorCodeRoute.link({'code': code[1]!})}$anchor';
  if (path == 'README.md' || path == 'api/README.md') return '/$anchor';
  // A file outside the site: its source on GitHub (under docs/ or above).
  final repoPath = path.startsWith('../') ? path.substring(3) : 'docs/$path';
  final view = repoPath.endsWith('/') ? RepoView.tree : RepoView.blob;
  return '${repoFile(repoPath, view: view)}$anchor';
}

/// Resolves `.` and `..` in a path relative to `docs/` (`../x` stays one
/// level above; more than that: null).
String? _normalize(String path) {
  final out = <String>[];
  var above = 0;
  final parts = path.split('/');
  for (var i = 0; i < parts.length; i++) {
    final part = parts[i];
    if (part == '.' || (part.isEmpty && i < parts.length - 1)) continue;
    if (part == '..') {
      if (out.isNotEmpty) {
        out.removeLast();
      } else {
        above++;
      }
      continue;
    }
    out.add(part);
  }
  if (above > 1) return null;
  final joined = out.join('/');
  return above == 1 ? '../$joined' : joined;
}

String _unescape(String html) => html
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');

/// The error codes with a page (`docs/errores/THOR-*.md`), sorted.
List<String> errorCodes() {
  final dir = Directory('${docsDir()}/errores');
  if (!dir.existsSync()) return const [];
  return [
    for (final f in dir.listSync().whereType<File>())
      if (RegExp(r'THOR-[A-Z]\d{3}\.md$').hasMatch(f.path))
        f.uri.pathSegments.last.replaceAll('.md', ''),
  ]..sort();
}
