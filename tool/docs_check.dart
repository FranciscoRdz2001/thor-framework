/// Compiles the ```dart blocks of the guide (docs/guia/es/*.md) against the
/// workspace packages and reports `file:line: message` for each one that does
/// not. `tool/thor docs-check [page.md...] [--list]`.
///
/// A block is a library when it parses as one, the statements of a function
/// when it does not, an expression as a last resort; a block with no `import`
/// gets the imports the guide takes for granted ([_prelude]). Blocks that
/// start with a path comment (`// lib/catalog.dart`) are that file of the
/// page's project, so the page's other blocks can import it. A genuinely
/// partial snippet is marked ```dart no-check and counted, never silently
/// skipped (the convention is in `docs_blocks.dart`).
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart' show Diagnostic;
import 'package:analyzer/source/line_info.dart';

import 'docs_blocks.dart';

/// What a block of the guide may use without importing it.
const _prelude = '''
import 'package:thor_ui/thor_ui.dart';
import 'package:thor_ui/router.dart';
import 'dart:async';
import 'dart:convert';
import 'package:thor_ui/intl.dart';
import 'package:thor_server/thor_server.dart';
import 'package:thor_test/thor_test.dart';
import 'package:test/test.dart';
''';

/// Pages whose snippets use a facade that would clash with the others
/// (the web layer's names are HTML's).
const _pageImports = {
  'publicar': "import 'package:thor_ui/server.dart';\n",
  'idiomas': "import 'package:thor_ui/server.dart';\n",
  'formularios': "import 'dart:io';\n",
};

/// Findings of the analyzer that say nothing about a snippet being right.
bool _noise(String code) =>
    code.startsWith('unused_') ||
    const {
      'duplicate_definition',
      'non_abstract_class_inherits_abstract_member',
      'override_on_non_overriding_member',
      'dead_code',
      'undefined_hidden_name',
      'duplicate_import',
      'unnecessary_import',
    }.contains(code);

Future<void> main(List<String> args) async {
  final root = Directory.current.path;
  final pages = [
    for (final a in args)
      if (!a.startsWith('-')) a,
  ];
  final list = args.contains('--list');
  final files = pages.isNotEmpty
      ? pages
      : [
          // The Spanish pages and its examples (a translation
          // repeats the same code: `apps/docs/test/english_test.dart`).
          for (final dir in ['docs/guia/es', 'docs/guia/es/ejemplos'])
            ...(Directory(dir)
                .listSync()
                .whereType<File>()
                .map((f) => f.path)
                .where((f) => f.endsWith('.md'))
                .toList()
              ..sort()),
        ];

  // Outside the repo: `dart analyze` (tool/thor check runs it in parallel)
  // would otherwise find these files while they are written and deleted.
  final sandbox = Directory.systemTemp.createTempSync('thor_docs_check_');
  _writeWorkspaceConfig(sandbox.path, _rootPackages());
  // Own options: the repo's strict lints are for the repo's code.
  File(
    '${sandbox.path}/analysis_options.yaml',
  ).writeAsStringSync('analyzer:\n  language:\n    strict-casts: false\n');
  File('${sandbox.path}/ambient.dart').writeAsStringSync(
    _ambient(File('tool/docs_ambient.txt').readAsStringSync()),
  );
  final shadow = File('${sandbox.path}/shadow.dart')
    ..writeAsStringSync(
      _shadowProbe(File('tool/docs_ambient.txt').readAsStringSync()),
    );
  final rootPackages = _rootPackages();
  final appPackages = <String>[]; // pages that are a project of their own
  final appDirs = <String, String>{}; // their dirs → package name
  // origin of each generated file: block + how it was wrapped.
  final origin = <String, (DocBlock, Wrapped)>{};
  var total = 0;
  var wrongExamples = 0;
  final skipped = <DocBlock>[];
  for (final file in files) {
    final page = file.split('/').last.replaceFirst(RegExp(r'\.md$'), '');
    final prelude = _prelude + (_pageImports[page] ?? '');
    final blocks = <DocBlock>[];
    for (final b in extractBlocks(File(file).readAsStringSync(), file: file)) {
      if (b.lang != 'dart') continue;
      for (final (:block, :wrong)
          in b.skip ? [(block: b, wrong: false)] : sections(b)) {
        total++;
        if (wrong) {
          wrongExamples++;
        } else {
          blocks.add(block);
        }
      }
    }
    // The page's own files (`// lib/env.dart`): what the blocks after them
    // (and the other files) can use. They hide the stubs of the same name.
    // A file the page shows again (its next version) is the last one for the
    // blocks that import it; the earlier versions are checked on their own.
    final lastOfPath = {
      for (final b in blocks)
        if (b.path != null) b.path!: b,
    };
    bool canonical(DocBlock b) =>
        b.path == null || identical(lastOfPath[b.path], b);
    final files = [
      for (final b in blocks)
        if (b.path != null &&
            !b.skip &&
            canonical(b) &&
            wrapBlock(b).kind == WrapKind.library)
          b,
    ];
    final appPackage = _appPackage(blocks, rootPackages);
    final pageDir = '${sandbox.path}/$page';
    if (appPackage != null) {
      _writeAppPackage(pageDir, appPackage, rootPackages);
      appPackages.add(pageDir);
      appDirs[pageDir] = appPackage;
    }
    for (final b in blocks) {
      if (b.skip) {
        skipped.add(b);
        continue;
      }
      final visible = [
        for (final f in files)
          if (f.path != b.path && (b.path != null || f.line < b.line)) f,
      ];
      final declared = {for (final f in visible) ..._declared(f.code)};
      final hide = declared.isEmpty ? '' : ' hide ${declared.join(', ')}';
      final world =
          "import 'file://$root/tool/docs_world.dart'$hide;\nimport 'file://${sandbox.path}/ambient.dart'$hide;\n";
      final w = wrapBlock(
        b,
        prelude: prelude,
        always:
            world +
            [
              for (final f in visible)
                "import 'file://${sandbox.path}/$page/${f.path}';\n",
            ].join(),
      );
      final rel = b.path != null && canonical(b)
          ? b.path!
          : '_blocks/L${b.line}.dart';
      final out = File('${sandbox.path}/$page/$rel')
        ..createSync(recursive: true);
      out.writeAsStringSync(w.source);
      origin[out.path] = (b, w);
    }
  }
  for (final file in origin.keys) {
    _stubMissingImports(File(file), appDirs);
  }
  if (list) {
    for (final b in skipped) {
      stdout.writeln('skipped ${b.file}:${b.line}');
    }
    stdout.writeln(
      '${origin.length} to check, ${skipped.length} no-check, $wrongExamples WRONG, of $total',
    );
    sandbox.deleteSync(recursive: true);
    return;
  }

  var failures = 0;
  final collection = AnalysisContextCollection(
    includedPaths: [sandbox.path, ...appPackages],
  );
  failures += await _checkShadows(collection, shadow);
  for (final entry in origin.entries) {
    final (block, wrapped) = entry.value;
    final lines = <String>[];
    if (wrapped.kind == WrapKind.unparseable) {
      for (final e in wrapped.errors) {
        final n = int.parse(e.substring(0, e.indexOf(':')));
        lines.add(
          '${block.file}:${block.line + n - 1}: syntax: ${e.substring(e.indexOf(':') + 2)}',
        );
      }
    } else {
      final result = await collection
          .contextFor(entry.key)
          .currentSession
          .getErrors(entry.key);
      if (args.contains('--debug')) {
        stdout.writeln('${entry.key}: ${result.runtimeType}');
      }
      if (result is ErrorsResult) {
        if (args.contains('--debug')) {
          for (final d in result.diagnostics) {
            stdout.writeln(
              '  ${d.diagnosticCode.lowerCaseName} ${d.severity} ${d.message}',
            );
          }
        }
        for (final d in _reported(result.diagnostics, result.lineInfo)) {
          final line = wrapped.blockLine(
            result.lineInfo.getLocation(d.offset).lineNumber,
          );
          lines.add(
            '${block.file}:${block.line + (line < 1 ? 0 : line - 1)}: ${d.diagnosticCode.lowerCaseName}: ${d.message}',
          );
        }
      }
    }
    if (lines.isNotEmpty) {
      failures++;
      lines.forEach(stdout.writeln);
      if (args.contains('--show')) {
        final src = block.code.split('\n');
        for (var i = 0; i < src.length; i++) {
          stdout.writeln('    ${block.line + i}| ${src[i]}');
        }
      }
    }
  }
  sandbox.deleteSync(recursive: true);
  stdout.writeln(
    '\n${origin.length - failures} of ${origin.length} blocks compile '
    '($total in all: ${skipped.length} partial snippets marked no-check, $wrongExamples WRONG examples not checked)',
  );
  if (failures > 0) {
    stderr.writeln(
      '$failures blocks fail: fix the page, or mark a genuinely partial snippet ```dart no-check',
    );
    exitCode = 1;
  }
}

/// The findings that say something about the snippet. A free variable
/// (`cart`, `orders`) is the page's context, not the API, and it has no type:
/// what follows from that (a condition or a constant on it) is not reported.
/// A type or a function that is missing is not free: name it in docs_world.dart.
List<Diagnostic> _reported(List<Diagnostic> all, LineInfo lines) {
  bool free(Diagnostic d) =>
      d.diagnosticCode.lowerCaseName == 'undefined_identifier' &&
      RegExp(r"^Undefined name '[a-z_]").hasMatch(d.message);
  final freeLines = {
    for (final d in all)
      if (free(d)) lines.getLocation(d.offset).lineNumber,
  };
  bool untyped(Diagnostic d) {
    if (freeLines.isEmpty) return false;
    final name = d.diagnosticCode.lowerCaseName;
    // A constant that holds a free variable.
    if (name == 'invalid_constant' ||
        name == 'const_with_non_constant_argument') {
      return freeLines.contains(lines.getLocation(d.offset).lineNumber);
    }
    return const {
      'non_bool_condition',
      'unchecked_use_of_nullable_value',
      'return_of_invalid_type',
      'argument_type_not_assignable',
      'invalid_assignment',
    }.contains(name);
  }

  // The page's own app (`package:my_app/ui.dart`) is not a package.
  bool placeholder(Diagnostic d) =>
      d.diagnosticCode.lowerCaseName == 'uri_does_not_exist' &&
      RegExp(r'package:my_(app|site)/').hasMatch(d.message);
  return [
    for (final d in all)
      if (!_noise(d.diagnosticCode.lowerCaseName) &&
          !placeholder(d) &&
          !free(d) &&
          !untyped(d) &&
          (d.severity.name == 'error' || d.severity.name == 'warning'))
        d,
  ];
}

/// A library that imports the packages the guide takes for granted (the
/// prelude) showing only the names of tool/docs_ambient.txt and
/// tool/docs_world.dart: `show` of a name the library does not export is
/// `undefined_shown_name`, so a stub that shadows a name of the real API (and
/// would let a block use it with the stub's loose types) is the one that does
/// *not* report it. The stubs must stand for the page's own code only.
String _shadowProbe(String ambient) {
  final names = <String>{
    for (final line in ambient.split('\n'))
      if (RegExp(r'^(type|value|widget|fn|page|layout|error):').hasMatch(line))
        ...line.substring(line.indexOf(':') + 1).trim().split(RegExp(r'\s+')),
    for (final m in RegExp(
      r'^(?:abstract\s+|final\s+|base\s+|sealed\s+)*(?:class|enum|mixin|typedef)\s+(\w+)',
      multiLine: true,
    ).allMatches(File('tool/docs_world.dart').readAsStringSync()))
      m.group(1)!,
  }..remove('');
  final out = StringBuffer();
  for (final lib in const [
    'package:thor_ui/thor_ui.dart',
    'package:thor_ui/router.dart',
    'package:thor_ui/intl.dart',
    'package:thor_server/thor_server.dart',
    'package:thor_test/thor_test.dart',
    'package:test/test.dart',
    'dart:async',
    'dart:convert',
  ]) {
    out.writeln("import '$lib' show ${names.join(', ')};");
  }
  return out.toString();
}

/// The stubs that are also names of the real API (see [_shadowProbe]); each
/// one is reported and counts as a failure.
Future<int> _checkShadows(
  AnalysisContextCollection collection,
  File probe,
) async {
  final result = await collection
      .contextFor(probe.path)
      .currentSession
      .getErrors(probe.path);
  if (result is! ErrorsResult) return 0;
  // name → in how many of the probe's imports it is *missing*.
  final missing = <String, int>{};
  for (final d in result.diagnostics) {
    if (d.diagnosticCode.lowerCaseName != 'undefined_shown_name') continue;
    final m = RegExp(r"'(\w+)'").firstMatch(d.message);
    if (m != null) missing.update(m.group(1)!, (n) => n + 1, ifAbsent: () => 1);
  }
  final text = probe.readAsStringSync();
  final imports = RegExp(r'^import', multiLine: true).allMatches(text).length;
  final names = {
    for (final m in RegExp(r'show ([^;]+);').allMatches(text))
      ...m.group(1)!.split(', '),
  };
  var failures = 0;
  for (final n in names) {
    if ((missing[n] ?? 0) < imports) {
      failures++;
      stdout.writeln(
        'tool/docs_ambient.txt / tool/docs_world.dart: `$n` is a name of the real API: '
        'a stub must not shadow it (use the real one)',
      );
    }
  }
  return failures;
}

/// The stubs of tool/docs_ambient.txt as a library.
String _ambient(String text) {
  final out = StringBuffer()
    ..writeln("import 'file://${Directory.current.path}/tool/docs_world.dart';")
    ..writeln("import 'package:thor_ui/thor_ui.dart';")
    ..writeln("import 'package:thor_ui/router.dart';");
  for (final line in text.split('\n')) {
    final m = RegExp(
      r'^(type|value|widget|fn|page|layout|error):\s*(.+)$',
    ).firstMatch(line);
    if (m == null) continue;
    for (final name in m.group(2)!.split(RegExp(r'\s+'))) {
      switch (m.group(1)) {
        case 'type':
          out.writeln('typedef $name = dynamic;');
        case 'value':
          out.writeln(
            'class $name extends Made { const $name([super.a, super.b, super.c, super.d, super.e]); }',
          );
        case 'widget':
          out.writeln(
            'class $name extends AmbientWidget { const $name([super.a, super.b, super.c, super.d]); }',
          );
        case 'page':
          out.writeln(
            'class $name extends ThorPage<dynamic> { const $name(); @override Future<dynamic> load(PageRequest request) async => null; @override Widget build(BuildContext context, PageState<dynamic> state) => const SizedBox(); }',
          );
        case 'layout':
          out.writeln(
            'class $name extends ThorLayout<dynamic> { const $name(); @override Widget build(BuildContext context, PageState<dynamic> state, Widget child) => child; }',
          );
        case 'error':
          out.writeln(
            'class $name extends ErrorPage { const $name(); @override Widget build(BuildContext context, ErrorState state) => const SizedBox(); }',
          );
        case 'fn':
          out.writeln(
            'dynamic $name([dynamic a, dynamic b, dynamic c, dynamic d, dynamic e]) => null;',
          );
      }
    }
  }
  return out.toString();
}

/// The names a source declares at the top level (what a stub of the same
/// name must not shadow).
Set<String> _declared(String code) => {
  for (final m in RegExp(
    r'^(?:(?:abstract|final|sealed|base|interface|mixin|const)\s+)*(?:class|enum|typedef|mixin|extension type)\s+(\w+)',
    multiLine: true,
  ).allMatches(code))
    m.group(1)!,
  for (final m in RegExp(
    r'^(?:final|const|var|late)\s+(?:[\w<>?,. ]+?\s+)?(\w+)\s*=',
    multiLine: true,
  ).allMatches(code))
    m.group(1)!,
  for (final m in RegExp(
    r'^(?:[A-Za-z_][\w<>?,.]*\s+)(\w+)\(',
    multiLine: true,
  ).allMatches(code))
    if (!const {
      'if',
      'for',
      'while',
      'switch',
      'return',
      'await',
    }.contains(m.group(1)))
      m.group(1)!,
};

/// The packages the workspace resolves (name → package_config entry).
Map<String, Map<String, Object?>> _rootPackages() {
  final config =
      jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
          as Map<String, Object?>;
  return {
    for (final p in config['packages']! as List<Object?>)
      (p! as Map<String, Object?>)['name']! as String:
          p as Map<String, Object?>,
  };
}

/// The package a page is the project of: the one its blocks import
/// (`package:store/core/catalog.dart`) that the workspace does not have and
/// that is not a placeholder (`my_app`). Null when the page is no project.
String? _appPackage(List<DocBlock> blocks, Map<String, Object?> known) {
  if (!blocks.any((b) => b.path != null)) return null;
  final names = {
    for (final b in blocks)
      for (final m in RegExp(r'package:(\w+)/').allMatches(b.code)) m.group(1)!,
  }..removeWhere((n) => known.containsKey(n) || n.startsWith('my_'));
  return names.length == 1 ? names.single : null;
}

/// The workspace's packages resolved from [dir] (a sandbox outside the repo
/// finds no `.dart_tool` above it): absolute `rootUri`s.
void _writeWorkspaceConfig(
  String dir,
  Map<String, Map<String, Object?>> known,
) {
  final rootConfig = Directory('.dart_tool').absolute.uri;
  File('$dir/.dart_tool/package_config.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(
      jsonEncode({
        'configVersion': 2,
        'packages': [
          for (final p in known.values)
            {
              ...p,
              'rootUri': rootConfig.resolve(p['rootUri']! as String).toString(),
            },
        ],
      }),
    );
}

/// [dir] as a package named [name]: the workspace's package config (its
/// paths made absolute) and the page's own `lib/`.
void _writeAppPackage(
  String dir,
  String name,
  Map<String, Map<String, Object?>> known,
) {
  Directory(dir).createSync(recursive: true);
  File(
    '$dir/pubspec.yaml',
  ).writeAsStringSync('name: $name\nenvironment:\n  sdk: ^3.10.0\n');
  File(
    '$dir/analysis_options.yaml',
  ).writeAsStringSync('analyzer:\n  language:\n    strict-casts: false\n');
  final rootConfig = Directory('.dart_tool').absolute.uri;
  final packages = [
    for (final p in known.values)
      {...p, 'rootUri': rootConfig.resolve(p['rootUri']! as String).toString()},
    {
      'name': name,
      'rootUri': Directory(dir).absolute.uri.toString(),
      'packageUri': 'lib/',
      'languageVersion': '3.8',
    },
  ];
  File('$dir/.dart_tool/package_config.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(jsonEncode({'configVersion': 2, 'packages': packages}));
}

/// A page's file imports others the page does not show (`import
/// 'shell/app_shell.dart'`, `package:store/core/widgets/page_title.dart`): an
/// empty library stands for each, and the names it would give are in
/// docs_ambient.txt.
void _stubMissingImports(File source, Map<String, String> pages) {
  final text = source.readAsStringSync();
  final page = pages.keys.where(source.path.startsWith).firstOrNull;
  for (final m in RegExp(
    r"^import\s+'([^']+)';",
    multiLine: true,
  ).allMatches(text)) {
    final uri = m.group(1)!;
    File? target;
    if (uri.startsWith('package:')) {
      if (page != null && uri.startsWith('package:${pages[page]}/')) {
        target = File(
          '$page/lib/${uri.substring('package:${pages[page]}/'.length)}',
        );
      }
    } else if (!uri.startsWith('dart:') && !uri.startsWith('file:')) {
      target = File('${source.parent.path}/$uri');
    }
    if (target != null && !target.existsSync()) {
      target.createSync(recursive: true);
      target.writeAsStringSync(
        '// stub: a file of the project the page does not show\n',
      );
    }
  }
}
