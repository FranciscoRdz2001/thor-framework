import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_cli/thor_cli.dart';
import 'package:yaml/yaml.dart';

/// `thor create` leaves a project ready: CI, the lint plugin wired, current
/// APIs, no hard-coded language; `thor analyze` and `thor format` run from
/// the workspace root.
void main() {
  group('a project outside the monorepo', () {
    final local = appFiles('shop', source: const LocalSource('/opt/thor'));
    final git = appFiles(
      'shop',
      source: const GitSource('https://x/thor.git', ref: 'v0.1'),
    );

    test('has a CI workflow: format, analyze, thor test', () {
      for (final files in [local, git]) {
        final ci = files['.github/workflows/ci.yml']!;
        expect(ci, contains('dart pub get'));
        expect(
          ci,
          contains('dart format --output=none --set-exit-if-changed .'),
        );
        expect(ci, contains('dart analyze --fatal-infos'));
        expect(ci, contains('thor test'));
      }
    });

    test('CI installs thor from the project\'s git source', () {
      final ci = git['.github/workflows/ci.yml']!;
      expect(ci, contains('--source git https://x/thor.git'));
      expect(ci, contains('--git-ref v0.1 --git-path packages/thor_cli'));
      expect(ci, isNot(contains('checkout on your machine')));
    });

    test('CI of a local checkout says it needs git dependencies', () {
      final ci = local['.github/workflows/ci.yml']!;
      expect(ci, contains('checkout on your machine'));
      expect(ci, contains('thor-framework.git'));
    });

    test('the lint plugin is wired and the recommended lints included', () {
      final options = local['analysis_options.yaml']!;
      expect(options, contains('include: package:lints/recommended.yaml'));
      expect(
        options,
        contains(
          'plugins:\n  thor_lints:\n    path: /opt/thor/packages/thor_lints',
        ),
      );
      expect(local['pubspec.yaml'], contains('lints: ^6.0.0'));
    });
  });

  test('the generated project is dart format clean (CI checks it)', () {
    final tmp = Directory.systemTemp.createTempSync('thor_fmt');
    addTearDown(() => tmp.deleteSync(recursive: true));
    writeApp(p.join(tmp.path, 'shop'), 'shop', source: const LocalSource('/x'));
    final r = Process.runSync('dart', [
      'format',
      '--output=none',
      '--set-exit-if-changed',
      p.join(tmp.path, 'shop'),
    ]);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    final ci = loadYaml(
      File(
        p.join(tmp.path, 'shop', '.github/workflows/ci.yml'),
      ).readAsStringSync(),
    );
    expect(((ci as YamlMap)['jobs'] as YamlMap).containsKey('check'), isTrue);
  });

  test('an app of the monorepo gets no CI of its own', () {
    final files = appFiles('shop');
    expect(files.keys.where((k) => k.startsWith('.github/')), isEmpty);
    expect(files['pubspec.yaml'], isNot(contains('lints:')));
  });

  group('templates use current APIs and no hard-coded language', () {
    final files = appFiles('shop');
    final dart = {
      for (final e in files.entries)
        if (e.key.endsWith('.dart')) e.key: e.value,
    };

    test('the language is a typed locale, not a literal', () {
      final app = files['lib/app.dart']!;
      expect(app, contains("const appLocale = Locale('en');"));
      expect(app, contains('supportedLocales: const [appLocale]'));
      expect(app, contains('locale: appLocale'));
      expect(app, isNot(contains("lang: 'es'")));
    });

    test('AppShell takes its title and footer as typed fields', () {
      final shell = files['lib/shell/app_shell.dart']!;
      expect(shell, contains('const AppShell({this.title = '));
      expect(shell, contains('final String title;'));
      expect(shell, contains('PageMeta(title: title)'));
      expect(shell, isNot(contains('Hecho con')));
    });

    test('no Spanish text and no deprecated size names', () {
      final spanish = RegExp(
        r'Hola|Hecho|Volver|Sumar|Reiniciar|Algo salió|No encontramos|'
        r'Edita|Mi primera',
      );
      for (final MapEntry(:key, :value) in dart.entries) {
        expect(value, isNot(contains(spanish)), reason: key);
        expect(value, isNot(contains('.flutter(')), reason: key);
        expect(value, isNot(contains(RegExp(r'WindowSizeClass\.(sm|md)\b'))));
      }
      for (final text in [layoutFile(), errorFile(), notFoundFile()]) {
        expect(text, isNot(contains(spanish)));
      }
    });

    test('a title with a quote or a dollar stays one string literal', () {
      final files = appFiles('shop', title: r"L'atelier $5 \ x");
      const escaped = r"L\'atelier \$5 \\ x";
      expect(files['lib/shell/app_shell.dart'], contains("title = '$escaped'"));
      expect(
        files.values.where((c) => c.contains("L'atelier")),
        isEmpty,
        reason: 'the raw title never reaches a literal',
      );
      expect(files.values.where((c) => c.contains("'$escaped'")), isNotEmpty);
      expect(layoutFile(title: "It's"), contains(r"title: 'It\'s'"));
    });

    test('the title option reaches the shell and the home page', () {
      final custom = appFiles('shop', title: 'My shop');
      expect(custom['lib/shell/app_shell.dart'], contains("title = 'My shop'"));
      expect(
        custom['lib/modules/home/pages/home_page.dart'],
        contains("PageTitle('My shop')"),
      );
    });
  });

  group('thor analyze and thor format', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('thor_tools'));
    tearDown(() => tmp.deleteSync(recursive: true));

    void pubspec(String dir, String body) {
      Directory(dir).createSync(recursive: true);
      File(p.join(dir, 'pubspec.yaml')).writeAsStringSync(body);
    }

    test('a project of its own runs from its own folder', () {
      final dir = p.join(tmp.path, 'shop');
      pubspec(dir, 'name: shop\ndependencies:\n  thor_ui:\n    path: /x\n');
      final location = toolLocation(Project(dir));
      expect(location.root, p.normalize(dir));
      expect(location.target, '.');
    });

    test('a member of a workspace runs from the workspace root', () {
      pubspec(tmp.path, 'name: ws\nworkspace:\n  - apps/shop\n');
      final dir = p.join(tmp.path, 'apps', 'shop');
      pubspec(
        dir,
        'name: shop\nresolution: workspace\n'
        'dependencies:\n  thor_ui:\n    path: /x\n',
      );
      final location = toolLocation(Project(dir));
      expect(location.root, p.normalize(tmp.path));
      expect(location.target, p.join('apps', 'shop'));
    });

    test('the dart arguments', () {
      expect(analyzeArgs('apps/shop'), [
        'analyze',
        '--fatal-infos',
        'apps/shop',
      ]);
      expect(analyzeArgs('.', fatalInfos: false), ['analyze', '.']);
      expect(formatArgs('.'), ['format', '.']);
      expect(formatArgs('.', check: true), [
        'format',
        '--output=none',
        '--set-exit-if-changed',
        '.',
      ]);
    });

    test('both commands are registered', () {
      final commands = thorRunner().commands.keys;
      expect(commands, containsAll(['analyze', 'format']));
    });
  });
}
