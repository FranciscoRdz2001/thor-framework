import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'run.dart';
import 'workspace.dart';

/// The line that marks thor's multi-view bootstrap (see
/// [flutterBootstrapTemplate]); a `web/flutter_bootstrap.js` without it is
/// the user's own and is never overwritten.
const flutterBootstrapMarker =
    "// thor: multi-view bootstrap for thor_ui's FlutterView";

/// `web/flutter_bootstrap.js` of a Flutter project embedded with
/// `FlutterView`: one engine in multi-view mode whose app is handed to the
/// page's loader (`window.thorFlutter`). URLs resolve from the script, so
/// the build works under any folder. `flutter build web` fills the two
/// `{{…}}` placeholders.
const flutterBootstrapTemplate =
    '''
{{flutter_js}}
{{flutter_build_config}}
$flutterBootstrapMarker (written by `thor build`
// when missing; keep this marker line). URLs resolve from this script, not
// from the page, so the build can live under any path (/flutter/).
(() => {
  const script = document.currentScript;
  const base = new URL('.', script.src).href;
  const config = { entrypointBaseUrl: base, assetBase: base };
  if (_flutter.buildConfig.useLocalCanvasKit) {
    config.canvasKitBaseUrl = base + 'canvaskit/';
  }
  _flutter.loader.load({
    config,
    nonce: script.nonce || undefined,
    onEntrypointLoaded: async (initializer) => {
      const engine = await initializer.initializeEngine({
        ...config,
        multiViewEnabled: true,
      });
      const app = await engine.runApp();
      // The page's FlutterView loader adds the views; opened on its own
      // (`flutter run`), the app draws one view in <body>.
      if (typeof window.thorFlutter === 'function') window.thorFlutter(app);
      else app.addView({ hostElement: document.body });
    },
  });
})();
''';

/// Files of `flutter build web` a thor page doesn't use: the standalone
/// page, the (deprecated) service worker, build ids and debug symbols.
bool isFlutterPublicFile(String relative) {
  final name = p.basename(relative);
  return name != 'index.html' &&
      name != 'flutter_service_worker.js' &&
      name != '.last_build_id' &&
      name != 'version.json' &&
      !name.endsWith('.symbols');
}

/// A Flutter project a thor app embeds with `FlutterView`, declared in the
/// app's pubspec:
///
/// ```yaml
/// thor:
///   flutter:
///     project: flutter_widgets   # the Flutter project (relative to the app)
///     public: flutter            # published at /flutter/ (default)
///     cdn: false                 # CanvasKit from gstatic.com (default: self-hosted)
/// ```
///
/// `thor build` builds it (`flutter build web --release`) into
/// `web/<public>/`, which the release then publishes like any public file.
class FlutterEmbed {
  /// The embedded project of [app] at [project], published under
  /// `web/[public]/`.
  FlutterEmbed(
    this.app,
    this.project, {
    this.public = 'flutter',
    this.cdn = false,
  });

  /// The thor app.
  final Project app;

  /// The Flutter project's folder (absolute).
  final String project;

  /// The folder of `web/` it is published to (the URL `FlutterView.src`).
  final String public;

  /// Whether CanvasKit loads from Google's CDN instead of the site.
  final bool cdn;

  /// The embed [app] declares, or null. A malformed declaration throws.
  static FlutterEmbed? of(Project app) {
    final yaml = loadYaml(File(app.path('pubspec.yaml')).readAsStringSync());
    final thor = yaml is YamlMap ? yaml['thor'] : null;
    final flutter = thor is YamlMap ? thor['flutter'] : null;
    if (flutter == null) return null;
    if (flutter is! YamlMap || flutter['project'] is! String) {
      throw ThorException(
        'thor.flutter in pubspec.yaml needs `project:` (the Flutter '
        'project folder, relative to the app).',
      );
    }
    final public = flutter['public'] ?? 'flutter';
    if (public is! String ||
        public.isEmpty ||
        p.isAbsolute(public) ||
        p.normalize(public).startsWith('..')) {
      throw ThorException(
        'thor.flutter.public must be a folder inside web/ (got "$public").',
      );
    }
    return FlutterEmbed(
      app,
      p.normalize(p.join(app.dir, flutter['project'] as String)),
      public: p.normalize(public),
      cdn: flutter['cdn'] == true,
    );
  }

  /// Where the build is published inside the app.
  String get publicDir => app.path(p.join('web', public));

  /// Writes thor's bootstrap into the project's `web/` when it has none.
  /// A bootstrap of its own (without [flutterBootstrapMarker]) is an error:
  /// the page's loader could never get the app.
  void ensureBootstrap() {
    if (!File(p.join(project, 'pubspec.yaml')).existsSync()) {
      throw ThorException(
        'thor.flutter.project: no Flutter project at ${p.relative(project)}.',
      );
    }
    final file = File(p.join(project, 'web', 'flutter_bootstrap.js'));
    if (!file.existsSync()) {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(flutterBootstrapTemplate);
      Say.info('wrote ${p.relative(file.path)} (multi-view bootstrap)');
      return;
    }
    if (!file.readAsStringSync().contains(flutterBootstrapMarker)) {
      throw ThorException(
        '${p.relative(file.path)} is not thor\'s multi-view bootstrap: '
        'delete it (thor build writes it) or start from '
        'flutterBootstrapTemplate.',
      );
    }
  }

  /// `flutter build web --release` of the project, published into
  /// [publicDir] (replacing what was there).
  Future<void> build() async {
    ensureBootstrap();
    final flutter = flutterExecutable();
    if (flutter == null) {
      throw ThorException(
        'This app embeds a Flutter project (thor.flutter) and the Flutter '
        'SDK was not found: put `flutter` on PATH or set FLUTTER_ROOT, or '
        'run `thor build --no-flutter` to publish the web/$public/ already '
        'there.',
      );
    }
    final out = app.path(p.join('.dart_tool', 'thor', 'flutter_web'));
    await exec(
      flutter,
      [
        'build',
        'web',
        '--release',
        if (!cdn) '--no-web-resources-cdn',
        '--output',
        out,
      ],
      dir: project,
      quiet: true,
    );
    publish(out);
  }

  /// Copies the files of the build at [out] the page uses into
  /// [publicDir], replacing it.
  void publish(String out) {
    final target = Directory(publicDir);
    if (target.existsSync()) target.deleteSync(recursive: true);
    for (final entity in Directory(out).listSync(recursive: true)) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: out);
      if (!isFlutterPublicFile(relative)) continue;
      final dest = File(p.join(target.path, relative));
      dest.parent.createSync(recursive: true);
      entity.copySync(dest.path);
    }
  }

  /// The `flutter` command: `FLUTTER_ROOT/bin/flutter`, or the one on
  /// PATH; null when there is none.
  static String? flutterExecutable({Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;
    final exe = Platform.isWindows ? 'flutter.bat' : 'flutter';
    final root = env['FLUTTER_ROOT'];
    if (root != null && root.isNotEmpty) {
      final candidate = p.join(root, 'bin', exe);
      if (File(candidate).existsSync()) return candidate;
    }
    for (final dir in (env['PATH'] ?? '').split(
      Platform.isWindows ? ';' : ':',
    )) {
      if (dir.isEmpty) continue;
      final candidate = p.join(dir, exe);
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }
}
