// `m.value[k]` of a map state in the translator: it becomes the
// runtime's per-key read, so a Watch that reads one entry re-runs when that
// entry changes, not on every write to the map. The output runs on the real
// runtime under node; the 7GUIs sheet is the case (test/fixtures/apps/cells).
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
  test('a Watch over one entry of a map runs only when it changes', () async {
    final js = await _translate('''
$_header
var runsA = 0, runsB = 0, runsSum = 0, runsAll = 0;

class SheetState extends ThorState {
  final cells = state(<String, String>{'A': '1', 'B': '2'});

  String a() {
    runsA++;
    return cells.value['A'] ?? '';
  }

  String b() {
    runsB++;
    return cells.value['B'] ?? '';
  }

  // Through a tear-off, as a formula reads the cells it refers to.
  String sum() {
    runsSum++;
    return '\${_total(raw)}';
  }

  int _total(String Function(String) read) =>
      int.parse(read('A')) + int.parse(read('B'));

  String raw(String k) => cells.value[k] ?? '0';

  // The whole map: re-runs on every write.
  int count() {
    runsAll++;
    return cells.value.length;
  }

  void put(String k, String v) => cells.value = {...cells.value, k: v};
  String runs() => '\$runsA,\$runsB,\$runsSum,\$runsAll';
}
''');
    expect(js, contains(".key('A')"));
    expect(js, matches(RegExp(r'// thor-lite parts: .*\bmap_keys\b')));
    final out = _run(js, r'''
const S = thor.use('SheetState');
const seen = {};
for (const m of ['a', 'b', 'sum', 'count']) thor.effect(() => (seen[m] = S[m]()));
out.start = S.runs();
S.put('A~5'); // an action's two arguments, as the page hands them
out.afterA = S.runs();
out.sum = seen.sum;
S.put('C~9');
out.afterC = S.runs();
out.count = seen.count;
''');
    // a, b, sum, all
    expect(out['start'], '1,1,1,1');
    expect(out['afterA'], '2,1,2,2');
    expect(out['sum'], '7');
    expect(out['afterC'], '2,1,2,3');
    expect(out['count'], 3);
  });
}
