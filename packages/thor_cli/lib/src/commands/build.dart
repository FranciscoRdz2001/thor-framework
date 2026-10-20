import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:thor_server/thor_server.dart'
    show Locale, LocaleRouting, fileForPath, localeChooserPage;
import 'package:yaml/yaml.dart';

import '../assets.dart';
import '../deploy.dart' show writeServerLauncher;
import '../dev/dev_runs.dart' show warnIfDevRunning;
import '../flutter_embed.dart';
import '../images.dart';
import '../resources.dart';
import '../run.dart';
import '../workspace.dart';
import 'base.dart';

/// thor's release flag (compact HTML, no debug attributes or checks); the
/// renderer reads it in one place.
const releaseFlag = '-Dthor.release=true';

/// `thor build`: the release of the project.
///
/// A server app → `build/server` (native executable) and `build/public`
/// (its public files and the optimized engine). A static app → the
/// pre-rendered site in `build/site`.
class BuildCommand extends Command<int> with ProjectCommand {
  /// The command.
  BuildCommand() {
    argParser.addFlag(
      'flutter',
      defaultsTo: true,
      help:
          'Build the Flutter project the app embeds (pubspec thor.flutter) '
          'into web/; --no-flutter publishes the one already there.',
    );
    addShareStylesFlag(argParser);
  }

  @override
  String get name => 'build';

  @override
  String get description =>
      'Release build: build/server + build/public, or build/site.';

  @override
  String get invocation => 'thor build [project]';

  @override
  Future<int> run() async {
    final project = resolveProject();
    warnIfDevRunning(Directory(project.path('.dart_tool/thor')), say: Say.warn);
    await pubGetIfStale(project.pubRoot, project.dir);
    PublicAssets(project).sync();
    final embed = FlutterEmbed.of(project);
    if (embed != null) {
      if (argResults!['flutter'] as bool) {
        Say.step('Flutter (${p.relative(embed.project)})');
        await embed.build();
      } else if (!Directory(embed.publicDir).existsSync()) {
        Say.warn(
          'web/${embed.public}/ is missing: the FlutterViews will keep '
          'their placeholders.',
        );
      }
    }
    final engine = project.engine;
    if (project.isServer) {
      await buildServer(project, engine: engine);
      Say.ok(
        '${p.relative(project.path('build/server'))}  (thor preview runs it; '
        'build/run.sh adds the GC flag for ISOLATES above 4)',
      );
    } else {
      await buildStatic(
        project,
        shareStyles: argResults!['share-styles'] as bool?,
        engine: engine,
      );
      Say.ok(
        '${p.relative(project.path('build/site'))}  (thor preview serves it)',
      );
    }
    return 0;
  }
}

/// Codegen, public files and the optimized engine into `build/public`,
/// and the server executable.
Future<void> buildServer(
  Project project, {
  EngineKind engine = EngineKind.lite,
}) async {
  Say.step('Code generation');
  await generate(project.dir, strict: true);
  // Before anything is copied or compiled (buildEngine checks again).
  if (engine == EngineKind.dart) rejectDartEngineLimits(project.dir);

  Say.step('Public files');
  final public = Directory(project.path('build/public'));
  if (public.existsSync()) public.deleteSync(recursive: true);
  public.createSync(recursive: true);
  copyPublicFiles(project, public.path);
  await buildImages(project, public.path);
  if (project.hasEngine) {
    await buildEngine(project, engine, out: 'build/public');
  }
  Say.step('Server executable');
  await exec(
    'dart',
    ['compile', 'exe', releaseFlag, project.entry, '-o', 'build/server'],
    dir: project.dir,
    quiet: true,
  );
  // What the server reads at run time (`thor: resources:`, `thor: sdk:`):
  // a native executable has neither package: URIs nor an SDK beside it.
  final resources = ServerResources(project);
  if (resources.declared().isNotEmpty || resources.wantsSdk) {
    final files = resources.copyInto(project.path('build/resources'));
    Say.ok('${files.length} resource files in build/resources');
  } else if (Directory(project.path('build/resources')) case final old
      when old.existsSync()) {
    // Declared by an earlier build only: the server must not find them.
    old.deleteSync(recursive: true);
  }
  writeServerLauncher(project);
}

/// The image step: the WebP variants of `web/images/` into
/// [siteDir] and the manifest the renderer reads, at `build/images.json`
/// (written even when empty, so a stale one never lingers). Its path.
Future<String> buildImages(Project project, String siteDir) async {
  final pipeline = ImagePipeline(project);
  final names = pipeline.sources();
  if (names.isNotEmpty) Say.step('Images (${names.length})');
  final manifest = await pipeline.build(siteDir);
  final path = buildManifestPath(project);
  writeImageManifest(manifest, path);
  return path;
}

/// A static app, pre-rendered by thor: its entry (`lib/main.server.dart`,
/// a `Document`) renders once in release to `build/site/index.html`, the
/// engine compiles optimized next to it, `web/` files are copied, then the
/// optimizer (short class names) and the fingerprints (cache busting).
/// No server, no port: the page is rendered in the process.
Future<void> buildStatic(
  Project project, {
  bool? shareStyles,
  EngineKind engine = EngineKind.lite,
}) async {
  final entry = File(project.path('lib/main.server.dart'));
  if (!entry.existsSync()) {
    throw ThorException(
      'A static app renders lib/main.server.dart (a Document); there is none.',
    );
  }
  final site = Directory(project.path('build/site'));
  if (site.existsSync()) site.deleteSync(recursive: true);

  Say.step('Code generation');
  await generate(project.dir, strict: true);

  final images = await buildImages(project, site.path);
  final index = File(p.join(site.path, 'index.html'));
  final locales = staticLocales(project);
  if (locales.length < 2) {
    Say.step('Pre-render');
    await exec(
      'dart',
      ['run', releaseFlag, project.entry],
      dir: project.dir,
      quiet: true,
      environment: {
        ...Platform.environment,
        'THOR_RENDER_TO': index.path,
        'THOR_IMAGES': images,
      },
    );
    if (!index.existsSync()) {
      throw ThorException('The pre-render wrote no index.html.');
    }
  } else {
    // One page per locale of lib/l10n (`/es` → es.html) and, at `/`, a
    // page that sends the visitor to theirs.
    final routing = LocaleRouting(
      supportedLocales: [for (final tag in locales) Locale.tryParse(tag)!],
    );
    for (final locale in locales) {
      Say.step('Pre-render ($locale)');
      final page = File(
        p.join(
          site.path,
          fileForPath(routing.pathFor(Locale.tryParse(locale)!, '/')),
        ),
      );
      await exec(
        'dart',
        ['run', releaseFlag, project.entry],
        dir: project.dir,
        quiet: true,
        environment: {
          ...Platform.environment,
          'THOR_RENDER_TO': page.path,
          'THOR_LOCALE': locale,
          'THOR_IMAGES': images,
        },
      );
      if (!page.existsSync()) {
        throw ThorException('The pre-render of $locale wrote nothing.');
      }
    }
    index.writeAsStringSync(localeChooserPage(routing));
  }

  copyPublicFiles(project, site.path);
  if (project.hasEngine) {
    await buildEngine(project, engine, out: 'build/site', pages: true);
  }

  final share = shareStyles ?? project.shareStyles;
  Say.step(
    share
        ? 'Shared stylesheet, short class names, fingerprints'
        : 'Short class names, fingerprints',
  );
  await optimizeSite(project, shareStyles: share);
  await fingerprintSite(project);
  Say.info(siteSize(site.path));
}

/// Content-hashed names for the files the pages of `build/site` ask for, and
/// the `_headers` that cache them forever (cache busting). Running it again
/// changes nothing.
Future<void> fingerprintSite(Project project) => exec(
  'dart',
  ['run', 'thor_engine:fingerprint', 'build/site'],
  dir: project.dir,
  quiet: true,
);

/// The locales of a static app's `lib/l10n/*.arb` as BCP 47 tags, the
/// template's first (`template_arb_file` of the `thor_l10n` builder in
/// `build.yaml`, `app_en.arb` by default); empty without ARB files. A
/// locale is the file's `@@locale`, else its name after the template's
/// prefix (`app_pt_BR.arb` → `pt-BR`).
List<String> staticLocales(Project project) {
  final dir = Directory(project.path('lib/l10n'));
  if (!dir.existsSync()) return const [];
  var template = 'app_en.arb';
  final buildYaml = File(project.path('build.yaml'));
  if (buildYaml.existsSync()) {
    final Object? config;
    try {
      config = loadYaml(buildYaml.readAsStringSync());
    } on YamlException catch (e) {
      throw ThorException('build.yaml: ${e.message}');
    }
    Object? at(Object? node, String key) => node is Map ? node[key] : null;
    final options = at(
      at(at(at(config, 'targets'), r'$default'), 'builders'),
      'thor_builder:thor_l10n',
    );
    final chosen = at(at(options, 'options'), 'template_arb_file');
    if (chosen is String) template = chosen;
  }
  final prefix = template.contains('_')
      ? template.substring(0, template.indexOf('_') + 1)
      : '';
  String? templateLocale;
  final locales = <String>{};
  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.arb'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final name = p.basename(file.path);
    Object? json;
    try {
      json = jsonDecode(file.readAsStringSync());
    } on FormatException catch (e) {
      throw ThorException('lib/l10n/$name is not valid JSON: ${e.message}');
    }
    final declared = json is Map ? json['@@locale'] : null;
    final base = p.basenameWithoutExtension(name);
    final locale = declared is String
        ? declared
        : prefix.isNotEmpty && base.startsWith(prefix)
        ? base.substring(prefix.length)
        : null;
    if (locale == null ||
        !RegExp(r'^[A-Za-z]{2,8}([_-][A-Za-z0-9]{1,8})*$').hasMatch(locale)) {
      throw ThorException(
        'lib/l10n/$name: no locale (name it $prefix<locale>.arb or add '
        '"@@locale")',
      );
    }
    final tag = locale.replaceAll('_', '-');
    if (name == template) templateLocale = tag;
    locales.add(tag);
  }
  if (locales.isEmpty) return const [];
  return [
    ?templateLocale,
    // Then by name, like the generated `supportedLocales`.
    ...(locales.where((l) => l != templateLocale).toList()..sort()),
  ];
}

/// What the first page costs: its HTML and JS, gzipped.
String siteSize(String site) {
  final files = [
    for (final f in Directory(site).listSync())
      if (f is File) f,
  ];
  int gz(String extension) {
    final bytes = <int>[
      for (final f in files)
        if (f.path.endsWith(extension)) ...f.readAsBytesSync(),
    ];
    return bytes.isEmpty ? 0 : gzip.encode(bytes).length;
  }

  String kb(int n) => (n / 1024).toStringAsFixed(1);
  // A site with an engine per page (or group of pages) says how many and
  // how big: their sum would be what no visitor downloads.
  final engines = [
    for (final f in files)
      if (RegExp(r'engine\.dart\.[0-9a-f]{8}\.js$').hasMatch(f.path))
        gzip.encode(f.readAsBytesSync()).length,
  ]..sort();
  if (engines.length > 1) {
    return '${kb(gz('.html'))} KB html, ${engines.length} engines of '
        '${kb(engines.first)}-${kb(engines.last)} KB js (gzip)';
  }
  return '${kb(gz('.html'))} KB html, ${kb(gz('.js'))} KB js (gzip)';
}

/// `thor export`: a server app as a static site (its `bin/export.dart`).
class ExportCommand extends Command<int> with ProjectCommand {
  /// The command.
  ExportCommand() {
    argParser.addOption(
      'base-url',
      help: "The site's URL (writes sitemap.xml and robots.txt).",
    );
    addShareStylesFlag(argParser);
  }

  @override
  String get name => 'export';

  @override
  String get description =>
      'Export a server app as a static site in build/site (links checked).';

  @override
  String get invocation => 'thor export [project]';

  @override
  Future<int> run() async {
    final project = resolveProject();
    if (!File(project.path('bin/export.dart')).existsSync()) {
      throw ThorException(
        'No bin/export.dart: it lists the pages to write and calls '
        'exportSite (thor_server).',
      );
    }
    warnIfDevRunning(Directory(project.path('.dart_tool/thor')), say: Say.warn);
    await pubGetIfStale(project.pubRoot, project.dir);
    PublicAssets(project).sync();
    Say.step('Code generation');
    await generate(project.dir, strict: true);
    // exportSite writes build/site from scratch: the variants wait in
    // build/.images and join the site after.
    final staged = Directory(project.path('build/.images'));
    if (staged.existsSync()) staged.deleteSync(recursive: true);
    final images = await buildImages(project, staged.path);
    Say.step('Export');
    final baseUrl = argResults!['base-url'] as String?;
    if (exportBaseUrlWarning(baseUrl) case final warning?) Say.warn(warning);
    await exec(
      'dart',
      [
        'run',
        releaseFlag,
        File(project.path('.dart_tool/thor/export.dart')).existsSync()
            ? '.dart_tool/thor/export.dart'
            : 'bin/export.dart',
        'build/site',
        ?baseUrl,
      ],
      dir: project.dir,
      environment: {...Platform.environment, 'THOR_IMAGES': images},
    );
    if (staged.existsSync()) {
      for (final f in staged.listSync(recursive: true).whereType<File>()) {
        final target = File(
          p.join(
            project.path('build/site'),
            p.relative(f.path, from: staged.path),
          ),
        );
        target.parent.createSync(recursive: true);
        f.copySync(target.path);
      }
      staged.deleteSync(recursive: true);
    }
    // Pages with browser state need the engine next to them, as in a
    // static build: the site is served as files, with no server to compile
    // it (only the pages with state load it).
    if (project.hasEngine) {
      await buildEngine(
        project,
        project.engine,
        out: 'build/site',
        pages: true,
      );
    }
    final share = argResults!['share-styles'] as bool? ?? project.shareStyles;
    Say.step(
      share
          ? 'Shared stylesheet, short class names, fingerprints'
          : 'Short class names, fingerprints',
    );
    await optimizeSite(project, shareStyles: share);
    await fingerprintSite(project);
    Say.ok(
      '${p.relative(project.path('build/site'))}  (thor preview serves it)',
    );
    return 0;
  }
}

/// The release engine into [out] (a folder of the project) as
/// `engine.dart.js`, the URL the page loads either engine from: dart2js
/// on the app's engine entry, or the lite bundle — its states
/// translated from Dart (a construct outside the lite subset stops the
/// build with its file and line) and the runtime parts the app uses. With
/// [pages] (a site) each page gets its own `engine.dart.<hash>.js`: the
/// states its markup names and the parts that code and markup need.
Future<void> buildEngine(
  Project project,
  EngineKind engine, {
  required String out,
  bool pages = false,
}) async {
  final target = p.join(out, 'engine.dart.js');
  switch (engine) {
    case EngineKind.dart:
      rejectDartEngineLimits(project.dir);
      Say.step('Engine (optimized)');
      await exec(
        'dart',
        [
          'compile',
          'js',
          '-O4',
          releaseFlag,
          Project.engineEntry,
          '-o',
          target,
        ],
        dir: project.dir,
        quiet: true,
      );
      for (final extra in ['engine.dart.js.deps', 'engine.dart.js.map']) {
        final f = File(project.path('$target.${extra.split('.').last}'));
        if (f.existsSync()) f.deleteSync();
      }
    case EngineKind.lite:
      Say.step('Engine (lite)');
      const state = 'build/lite/state.js';
      await BuilderSteps.dartRun.liteState(project.dir, state, readable: false);
      await exec(
        'dart',
        [
          'run',
          'thor_engine:lite_bundle',
          // A site: one bundle per page, with its states and parts.
          if (pages) '--per-page',
          state,
          '.',
          target,
          if (pages) out,
        ],
        dir: project.dir,
        quiet: true,
      );
  }
}

/// `--share-styles` / `--no-share-styles`: overrides `thor.share_styles` of
/// the app's pubspec for one build.
void addShareStylesFlag(ArgParser parser) => parser.addFlag(
  'share-styles',
  defaultsTo: null,
  help:
      'Move the styles most pages share into one cached stylesheet '
      '(_thor/styles.<hash>.css). Default: thor.share_styles in pubspec.yaml '
      '(off).',
);

/// The export optimizer on every page of `build/site`: short class names
/// and, with [shareStyles], the site's shared stylesheet first
/// (`_thor/styles.<hash>.css`). Without it the pages keep all their
/// styles inline, as before the shared sheet existed.
Future<void> optimizeSite(Project project, {required bool shareStyles}) async {
  if (shareStyles) {
    await exec(
      'dart',
      ['run', 'thor_engine:share_styles', 'build/site'],
      dir: project.dir,
      quiet: true,
    );
    return;
  }
  final site = Directory(project.path('build/site'));
  final pages = [
    for (final f in site.listSync(recursive: true))
      if (f is File && f.path.endsWith('.html')) f.path,
  ];
  if (pages.isEmpty) return;
  await exec(
    'dart',
    ['run', 'thor_engine:optimize', ...pages],
    dir: project.dir,
    quiet: true,
  );
}

/// What to tell the person exporting without `--base-url`, or null when
/// there is one: the pages are written as if served from `http://localhost`,
/// so their canonical links, `og:url` and `hreflang` alternates point there,
/// and no `sitemap.xml` or `robots.txt` is written.
String? exportBaseUrlWarning(String? baseUrl) =>
    baseUrl != null && baseUrl.trim().isNotEmpty
    ? null
    : 'No --base-url: canonical links, og:url and hreflang point to '
          'http://localhost and no sitemap.xml or robots.txt is written. '
          'Export with --base-url https://your.site for a site you publish.';

/// Copies `web/` into [into] for a release: sources (`.dart`), the dev
/// engine (`engine.dart.js*`) and `.gitkeep` stay out; the release engine
/// is built next. The one place both release modes share these rules.
void copyPublicFiles(Project project, String into) {
  final web = Directory(project.path('web'));
  if (!web.existsSync()) return;
  for (final entity in web.listSync(recursive: true)) {
    if (entity is! File) continue;
    final relative = p.relative(entity.path, from: web.path);
    if (relative.endsWith('.dart') ||
        relative.startsWith('engine.dart.js') ||
        p.basename(relative) == '.gitkeep') {
      continue;
    }
    final target = File(p.join(into, relative));
    target.parent.createSync(recursive: true);
    entity.copySync(target.path);
  }
}
