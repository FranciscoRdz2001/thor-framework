// `derived(() => …)` in the translator: a field becomes the runtime's cached
// `computed`, registered on its state, and the output runs on the real
// runtime under node: three readers share one computation per change of what
// it reads, and none while nothing changes.
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_engine/src/lite_bundle.dart';
import 'package:thor_lints/lite.dart';

Future<String> _translate(String source) async {
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
  return translateLiteStates(units);
}

const _header = '''
import 'dart:async';

import 'package:thor_ui/thor_ui.dart';

''';

const _page = r'''
globalThis.window = globalThis;
const winL = {};
globalThis.addEventListener = (t, f) => { (winL[t] ||= []).push(f); };
const pagehide = () => (winL.pagehide || []).forEach((f) => f({ persisted: false }));
globalThis.MutationObserver = class { observe() {} };
globalThis.reportError = (x) => (globalThis.errs ||= []).push(x.message);
const root = { innerHTML: '', addEventListener() {}, querySelectorAll: () => [] };
globalThis.document = {
  documentElement: root, cookie: '', querySelectorAll: () => [], querySelector: () => null,
  getElementById: () => null, dispatchEvent() {}, createElement: () => ({}),
};
globalThis.CustomEvent = class {};
''';

Map<String, Object?> _run(String js, String script) {
  final runtime = File('../thor_engine/lib/lite/runtime.js').readAsStringSync();
  // The runtime parts the state names (`// thor-lite parts: …`).
  final names =
      RegExp(
        r'^// thor-lite parts: (.*)$',
        multiLine: true,
      ).firstMatch(js)?.group(1)!.split(' ') ??
      const <String>[];
  final bundle = liteBundle(
    runtime: runtime,
    parts: {
      for (final p in names)
        p: File('../thor_engine/lib/lite/parts/$p.js').readAsStringSync(),
    },
    stateJs: js,
    minify: false,
  );
  final program =
      '$_page$bundle\n(async () => {\nawait new Promise((r) => setTimeout(r, 0));\n'
      'const out = {};\n$script\nconsole.log(JSON.stringify(out));\nprocess.exit(0);\n})();';
  final r = Process.runSync('node', ['-e', program]);
  if (r.exitCode != 0) fail('node failed:\n${r.stderr}\n$js');
  return jsonDecode((r.stdout as String).trim()) as Map<String, Object?>;
}

void main() {
  test('a derived read by three Watches computes once per change', () async {
    final js = await _translate('''
$_header
var computes = 0;

class QuakesState extends ThorState {
  final rows = state(<int>[3, 1, 2]);
  final min = state(0);
  late final visible = derived(() {
    computes++;
    return (rows.value.where((r) => r >= min.value).toList())..sort();
  });

  String table() => visible.value.join(',');
  int count() => visible.value.length;
  String dots() => '\${visible.value.length}:\${visible.value.isEmpty ? 0 : visible.value.first}';

  void setMin(int v) => min.value = v;
  void add(int v) => rows.value = [...rows.value, v];
  int runs() => computes;
}
''');
    expect(js, contains(r'$.computed('));
    expect(js, isNot(contains('const visible = () =>')));
    final out = _run(js, r'''
const S = thor.use('QuakesState');
const seen = [];
// three Watches: each one an effect over its own method
for (const m of ['table', 'count', 'dots']) thor.effect(() => seen.push(S[m]()));
out.first = S.runs();
S.setMin(2);
out.afterMin = S.runs();
S.add(5);
out.afterAdd = S.runs();
// nothing changes: nothing computes, however often it is read
for (let i = 0; i < 10; i++) { S.table(); S.count(); S.dots(); }
out.idle = S.runs();
// a write that leaves the value the same does not compute either
S.setMin(2);
out.same = S.runs();
out.table = S.table();
''');
    expect(out['first'], 1);
    expect(out['afterMin'], 2);
    expect(out['afterAdd'], 3);
    expect(out['idle'], 3);
    expect(out['same'], 3);
    expect(out['table'], '2,3,5');
  });
}
