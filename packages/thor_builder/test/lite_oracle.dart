// Shared by the lite translator tests: translate a program, run it in
// node, and compare it with the same Dart compiled by dart2js (the oracle).
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_lints/lite.dart';

/// Resolves `lib/s.dart` and translates it.
Future<String> translate(String source, {bool shortNames = false}) async {
  final units = await resolveSources(
    {'app|lib/s.dart': source},
    (resolver) async {
      final lib = await resolver.libraryFor(AssetId.parse('app|lib/s.dart'));
      final result =
          await lib.session.getResolvedLibraryByElement(lib)
              as ResolvedLibraryResult;
      return [for (final u in result.units) LiteUnit('lib/s.dart', u.unit)];
    },
    rootPackage: 'app',
    readAllSourcesFromFilesystem: true,
  );
  return translateLiteStates(units, shortNames: shortNames);
}

/// The errors the translator reports for [source] (fails when none).
Future<List<LiteError>> liteErrors(String source) async {
  try {
    await translate(source);
  } on LiteTranslationException catch (e) {
    return e.errors;
  }
  fail('expected lite errors');
}

final hasNode = () {
  try {
    return Process.runSync('node', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();

const header = '''
import 'dart:async';

import 'package:thor_ui/thor_ui.dart';

''';

/// Runs [js] in node with a stub `thor.def`; [script] (async JS, `S` = the
/// first state's members) fills `out`, printed as JSON.
Map<String, Object?> runJs(String js, String script) {
  final parts = RegExp(
    r'^// thor-lite parts: (.*)$',
    multiLine: true,
  ).firstMatch(js)?.group(1)!.split(' ');
  final order = ['json', 'datetime', 'duration', 'time_of_day', 'date_utils'];
  final code = [
    for (final p in order)
      if (parts?.contains(p) ?? false)
        File('../thor_engine/lib/lite/parts/$p.js').readAsStringSync(),
  ].join('\n');
  final program =
      '''
const defs = {};
globalThis.thor = { def: (n, f) => { defs[n] = f; }, batch: (f) => f(), untracked: (f) => f() };
$code
$js
const signal = (v) => ({ x: v, n: 0, get value() { return this.x; }, set value(y) { this.x = y; this.n++; }, peek() { return this.x; } });
const make = (n) => defs[n]({ key: null, state: (_, v) => signal(v), use: (q) => make(q) });
const S = make(Object.keys(defs)[0]);
const out = {};
(async () => {
$script
})().then(() => console.log(JSON.stringify(out)), (e) => { console.error(e); process.exit(1); });
''';
  final r = Process.runSync('node', ['-e', program]);
  if (r.exitCode != 0) fail('node failed:\n${r.stderr}\n$js');
  return jsonDecode(r.stdout as String) as Map<String, Object?>;
}

/// Translates [lib] (functions `t0`…`t<n-1>` returning `FutureOr<String>`,
/// called by a state) and checks that lite prints what Dart on the web
/// prints (dart2js, run in node), also with the build's short names.
Future<void> sameAsWeb(String lib, int n, {String imports = ''}) async {
  final source =
      '''
$imports
$header
$lib
class PState extends ThorState {
${[for (var i = 0; i < n; i++) '  FutureOr<String> e$i() => t$i();'].join('\n')}
}
''';
  final js = await translate(source);
  final short = await translate(source, shortNames: true);
  if (!hasNode) return markTestSkipped('node is not installed');
  final script =
      'out.all = [${[for (var i = 0; i < n; i++) 'await S.e$i()'].join(', ')}];';
  final out = runJs(js, script);
  expect(runJs(short, script), out);
  final dir = Directory.systemTemp.createTempSync('lite_oracle');
  try {
    File('${dir.path}/probe.dart').writeAsStringSync('''
import 'dart:async';
import 'dart:convert';
$imports
$lib
Future<void> main() async => print(jsonEncode([${[for (var i = 0; i < n; i++) 'await t$i()'].join(', ')}]));
''');
    final compiled = Process.runSync(Platform.resolvedExecutable, [
      'compile',
      'js',
      '--packages=${File('../../.dart_tool/package_config.json').absolute.path}',
      '-O1',
      '--no-source-maps',
      '-o',
      '${dir.path}/probe.js',
      '${dir.path}/probe.dart',
    ]);
    if (compiled.exitCode != 0) fail('dart2js failed:\n${compiled.stdout}');
    final web = Process.runSync('node', [
      '-e',
      "globalThis.self = globalThis; require('${dir.path}/probe.js');",
    ]);
    if (web.exitCode != 0) fail('the dart2js probe failed:\n${web.stderr}');
    final expected = jsonDecode(web.stdout as String) as List<Object?>;
    final got = out['all']! as List<Object?>;
    for (var i = 0; i < n; i++) {
      expect(got[i], expected[i], reason: 't$i');
    }
  } finally {
    dir.deleteSync(recursive: true);
  }
}
