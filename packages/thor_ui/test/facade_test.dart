@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// The repository root, from this package.
const _root = '../..';

Iterable<File> _dartFiles(String dir) sync* {
  final d = Directory('$_root/$dir');
  if (!d.existsSync()) return;
  for (final f in d.listSync(recursive: true)) {
    if (f is File &&
        f.path.endsWith('.dart') &&
        !f.path.contains('/.dart_tool/') &&
        !f.path.contains('/build/')) {
      yield f;
    }
  }
}

/// The packages thor_ui's own code may import: the render core is thor's.
const _allowed = {'meta', 'thor_engine', 'thor_server', 'thor_style'};

/// One other package, behind one opt-in library that no widget imports:
/// `intl` (CLDR number and date data) only in `package:thor_ui/intl.dart`.
/// Test tooling that needs `matcher` and `html` (the HTTP test client) lives
/// in `thor_test`, a dev dependency of the apps, so a production app (or a
/// hybrid Flutter one, whose `flutter_test` pins `matcher`) never gets them.
const _optIn = {'intl': 'packages/thor_ui/lib/intl.dart'};

/// `package:<name>` of every import and export in [dir].
Map<String, Set<String>> _packagesUsed(String dir) {
  final used = <String, Set<String>>{};
  for (final f in _dartFiles(dir)) {
    for (final m in RegExp(
      r"^(?:import|export) 'package:([\w]+)/",
      multiLine: true,
    ).allMatches(f.readAsStringSync())) {
      (used[m[1]!] ??= {}).add(f.path.substring(_root.length + 1));
    }
  }
  return used;
}

void main() {
  test('thor_ui renders with thor alone: its code imports only thor '
      'packages and meta', () {
    final used = _packagesUsed('packages/thor_ui/lib');
    expect({
      for (final MapEntry(:key, :value) in used.entries)
        if (!_allowed.contains(key) &&
            !(value.length == 1 && value.single == _optIn[key]))
          key: value,
    }, isEmpty);
  });

  test('its pubspec declares exactly those dependencies', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final deps = RegExp(
      r'^dependencies:\n((?:  .*\n|\n)*)',
      multiLine: true,
    ).firstMatch(pubspec)![1]!;
    final names = {
      for (final m in RegExp(r'^  (\w+):', multiLine: true).allMatches(deps))
        m[1]!,
    };
    expect(names, {..._allowed, ..._optIn.keys});
  });

  test(
    'it depends on neither matcher nor html (test tooling is thor_test)',
    () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final name in ['matcher', 'html', 'test_api', 'test']) {
        final asDependency = RegExp(
          '^dependencies:\\n(?:  .*\\n|\\n)*?  $name:',
          multiLine: true,
        );
        expect(asDependency.hasMatch(pubspec), isFalse, reason: name);
      }
      expect(
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (f) =>
                  f.path.endsWith('.dart') &&
                  RegExp(
                    r'package:(matcher|html|test_api|test|stack_trace)/',
                  ).hasMatch(f.readAsStringSync()),
            ),
        isEmpty,
      );
    },
  );

  test('the facades re-export only thor', () {
    for (final facade in ['thor_ui', 'server', 'html', 'testing', 'router']) {
      final exports = RegExp(r"export 'package:(\w+)/")
          .allMatches(File('lib/$facade.dart').readAsStringSync())
          .map((m) => m[1]!);
      expect(
        exports.where((p) => !p.startsWith('thor_') && p != 'meta'),
        isEmpty,
        reason: facade,
      );
    }
  });

  test('apps, fixtures, tools and the other packages reach widgets '
      'through thor_ui only', () {
    final offenders = <String>[
      for (final dir in [
        'apps',
        'test/fixtures',
        'tool',
        'packages/thor_studio',
        'packages/thor_server',
        'packages/thor_style',
        'packages/thor_engine',
        'packages/thor_builder',
        'packages/thor_cli',
      ])
        for (final f in _dartFiles(dir))
          if (RegExp(
            "import 'package:thor_ui/src/",
          ).hasMatch(f.readAsStringSync()))
            f.path.substring(_root.length + 1),
    ];
    expect(offenders, isEmpty);
  });
}
