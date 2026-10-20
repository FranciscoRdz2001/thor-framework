// Adversarial: the listeners of a StateSignal in the lite engine,
// translated from Dart and run on the real runtime under node, where the page
// is not polite: a listener that adds one, throws, writes the signal it
// listens to, or is added twice.
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

Future<List<String>> _errors(String source) async {
  try {
    await _translate(source);
  } on LiteTranslationException catch (e) {
    return [for (final x in e.errors) '$x'];
  }
  fail('expected lite errors');
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
  test(
    'a listener added during a notification waits for the next one',
    () async {
      final js = await _translate('''
$_header
class LState extends ThorState {
  final n = state(0);
  final log = state('');
  void _late() => log.value += 'L';
  void _a() {
    log.value += 'a';
    n.addListener(_late);
  }
  void start() => n.addListener(_a);
  void stop() => n.removeListener(_a);
  void inc() => n.value++;
  String text() => log.value;
}
''');
      final out = _run(js, r'''
const S = thor.use('LState');
S.start();
S.inc();
out.first = S.text();
S.stop();
S.inc();
out.second = S.text();
''');
      expect(out['first'], 'a');
      expect(out['second'], 'aL');
    },
  );

  test(
    'the same listener added twice is called twice; one remove takes one',
    () async {
      final js = await _translate('''
$_header
class LState extends ThorState {
  final n = state(0);
  final log = state('');
  void _a() => log.value += 'a';
  void twice() {
    n.addListener(_a);
    n.addListener(_a);
  }
  void once() => n.removeListener(_a);
  void inc() => n.value++;
  String text() => log.value;
}
''');
      final out = _run(js, r'''
const S = thor.use('LState');
S.twice();
S.inc();
out.both = S.text();
S.once();
S.inc();
out.one = S.text();
''');
      expect(out['both'], 'aa');
      expect(out['one'], 'aaa');
    },
  );

  test('a listener that throws is reported and the others still run', () async {
    final js = await _translate('''
$_header
class LState extends ThorState {
  final n = state(0);
  final log = state('');
  void _a() => log.value += 'a';
  void _boom() => throw StateError('boom');
  void _c() => log.value += 'c';
  void start() {
    n.addListener(_a);
    n.addListener(_boom);
    n.addListener(_c);
  }
  void inc() => n.value++;
  String text() => log.value;
}
''');
    final out = _run(js, r'''
const S = thor.use('LState');
S.start();
// the batch runs every effect and rethrows the first error to the writer
// (an event handler: the browser reports it)
const attempt = (f) => { try { f(); return null; } catch (e) { return e.message ?? String(e); } };
out.threw1 = attempt(() => S.inc()) !== null;
out.first = S.text();
out.threw2 = attempt(() => S.inc()) !== null;
out.second = S.text();
''');
    expect(out['first'], 'ac');
    expect(out['second'], 'acac');
    expect(out['threw1'], isTrue);
    expect(out['threw2'], isTrue);
  });

  test(
    'a listener that writes the signal it listens to, converging, settles',
    () async {
      final js = await _translate('''
$_header
class LState extends ThorState {
  final n = state(0);
  final calls = state(0);
  void _clamp() {
    calls.value++;
    if (n.value > 3) n.value = 3;
  }
  void start() => n.addListener(_clamp);
  void set(int v) => n.value = v;
  String text() => '\${n.value}/\${calls.value}';
}
''');
      final out = _run(js, r'''
const S = thor.use('LState');
S.start();
S.set(10);
out.text = S.text();
''');
      // Flutter: the write of 10 notifies (clamp writes 3, which notifies
      // again): 2 calls
      expect(out['text'], '3/2');
    },
  );

  test('a listener that always writes the signal it listens to does not '
      'hang the page: the loop is cut with an error', () async {
    final js = await _translate('''
$_header
class LState extends ThorState {
  final n = state(0);
  void _grow() => n.value++;
  void start() => n.addListener(_grow);
  void kick() => n.value = 1;
  String text() => '\${n.value}';
}
''');
    final out = _run(js, r'''
const S = thor.use('LState');
S.start();
try { S.kick(); out.cut = null; } catch (e) { out.cut = e.message; }
out.text = S.text();
''');
    expect(out['cut'], contains('cycle'));
    expect(int.parse(out['text'] as String), lessThan(100000));
  });

  test('a ValueNotifier inside a helper class a state uses gets the same fix '
      'as a field (make it a state field)', () async {
    final errors = await _errors('''
$_header
class Store {
  final ValueNotifier<int> n = ValueNotifier(0);
}
class PState extends ThorState {
  final store = Store();
  final c = state(0);
  String label() => '\${store.n.value}';
  void inc() => store.n.value++;
}
''');
    expect(errors, isNotEmpty);
    // the constructor and the read say it (an assignment to `.value` only
    // names the member, not the type)
    expect(
      errors.where((e) => e.contains('make it a `state(...)` field')),
      hasLength(greaterThanOrEqualTo(2)),
    );
  });
}
