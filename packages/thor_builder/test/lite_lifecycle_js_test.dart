// In the translator: `onHydrated()` / `dispose()` of a ThorState become
// `$l: {h, d}` (never a member the page can call) and `idle: true`; a
// StateSignal's addListener/removeListener become real, owned effects. The
// output runs on the real runtime under node.
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
  test('onHydrated and dispose are the state\'s life, not members', () async {
    final js = await _translate('''
$_header
class TickState extends ThorState {
  final ticks = state(0);
  Timer? _every;

  @override
  void onHydrated() {
    _every = Timer.periodic(const Duration(seconds: 1), (t) => ticks.value = t.tick);
  }

  @override
  void dispose() => _every?.cancel();

  String label() => '\${ticks.value}';
}

class PlainState extends ThorState {
  final n = state(0);
  String label() => '\${n.value}';
}
''');
    expect(js, contains(r'$l: { h: onHydrated, d: dispose }'));
    // idle: it wakes without waiting for an event
    expect(js, contains('idle: true'));
    // never a member the page can name in `data-t-on`
    expect(js, isNot(contains('    onHydrated,')));
    expect(js, isNot(contains('    dispose,')));
    // the state without them carries nothing
    final plain = js.substring(js.indexOf("thor.def('PlainState'"));
    expect(plain, isNot(contains(r'$l')));
    expect(plain, isNot(contains('idle')));
  });

  test('only dispose: no idle wake; only onHydrated: no disposal', () async {
    final js = await _translate('''
$_header
class AState extends ThorState {
  final n = state(0);
  @override
  void dispose() {}
}
class BState extends ThorState {
  final n = state(0);
  @override
  Future<void> onHydrated() async {}
}
''');
    final a = js.substring(
      js.indexOf("thor.def('AState'"),
      js.indexOf("thor.def('BState'"),
    );
    final b = js.substring(js.indexOf("thor.def('BState'"));
    expect(a, contains(r'$l: { d: dispose }'));
    expect(a, isNot(contains('idle')));
    expect(b, contains(r'$l: { h: onHydrated }'));
    expect(b, contains('idle: true'));
  });

  test('a lifecycle method with parameters is an error with a fix', () async {
    final errors = await _errors('''
$_header
class BadState extends ThorState {
  final n = state(0);
  void onHydrated([int x = 0]) {}
}
''');
    expect(errors, [contains('onHydrated')]);
  });

  test('a timer started in onHydrated is stopped by dispose (pagehide); the '
      'listeners of its signals stop too', () async {
    final js = await _translate('''
$_header
class TickState extends ThorState {
  final ticks = state(0);
  final seen = state(0);
  Timer? _every;

  void _heard() => seen.value++;

  @override
  void onHydrated() {
    ticks.addListener(_heard);
    _every = Timer.periodic(const Duration(milliseconds: 5), (t) => ticks.value = t.tick);
  }

  @override
  void dispose() {
    ticks.removeListener(_heard);
    _every?.cancel();
  }

  String label() => '\${ticks.value}/\${seen.value}';
  bool running() => _every?.isActive ?? false;
  void again() => ticks.addListener(_heard);
}
''');
    final out = _run(js, r'''
// a page that shows it: its text is what keeps it alive
const S = thor.use('TickState');
await new Promise((r) => setTimeout(r, 60));
out.running = S.running();
out.label = S.label();
pagehide();
out.after = S.running();
const frozen = S.label();
await new Promise((r) => setTimeout(r, 40));
out.frozen = S.label() === frozen;
// a late callback that listens to a state that is gone is a mistake
try { S.again(); out.late = null; } catch (e) { out.late = e.message; }
''');
    expect(out['late'], contains('disposed state'));
    expect(out['running'], isTrue);
    expect((out['label'] as String).split('/').first, isNot('0'));
    // every tick was heard once
    final parts = (out['label'] as String).split('/');
    expect(parts[1], parts[0]);
    expect(out['after'], isFalse);
    expect(out['frozen'], isTrue);
  });

  test('addListener: removed while notifying, twice, after dispose', () async {
    final js = await _translate('''
$_header
class LState extends ThorState {
  final n = state(0);
  final log = state('');

  void _a() => log.value += 'a';
  void _b() => log.value += 'b';

  void addBoth() {
    n.addListener(_a);
    n.addListener(_b);
  }

  // b is removed by a's turn: it must not hear this change
  void dropB() => n.removeListener(_b);
  void dropA() => n.removeListener(_a);
  void inc() => n.value++;
  String text() => log.value;
}
''');
    final out = _run(js, r'''
const S = thor.use('LState');
S.addBoth();
S.inc();
out.both = S.text();
S.dropB();
S.inc();
out.afterDropB = S.text();
S.dropA(); S.dropA(); S.dropB(); // removing what is not there is fine
S.inc();
out.none = S.text();
// a disposed state's signals refuse listeners
S.$s.n.off = 1;
try { S.addBoth(); out.err = null; } catch (e) { out.err = e.message; }
''');
    expect(out['both'], 'ab');
    expect(out['afterDropB'], 'aba');
    expect(out['none'], 'aba');
    expect(out['err'], contains('disposed state'));
  });

  test('a listener that removes another during a notification', () async {
    final js = await _translate('''
$_header
class LState extends ThorState {
  final n = state(0);
  final log = state('');
  void _a() {
    log.value += 'a';
    n.removeListener(_b);
  }
  void _b() => log.value += 'b';
  void start() {
    n.addListener(_a);
    n.addListener(_b);
  }
  void inc() => n.value++;
  String text() => log.value;
}
''');
    final out = _run(js, r'''
const S = thor.use('LState');
S.start();
S.inc();
out.first = S.text();
S.inc();
out.second = S.text();
''');
    // Flutter's ChangeNotifier: a removed listener that has not run yet is
    // skipped
    expect(out['first'], 'a');
    expect(out['second'], 'aa');
  });

  test('a plain ValueNotifier field is an error with its fix', () async {
    for (final type in ['ValueNotifier<int>(0)', 'ChangeNotifier()']) {
      final errors = await _errors('''
$_header
class BadState extends ThorState {
  final n = $type;
  String label() => 'x';
}
''');
      expect(errors, hasLength(1), reason: type);
      expect(errors.single, contains('does not react in the browser'));
      expect(errors.single, contains('final n = $type;'));
      expect(errors.single, contains('make it a `state(...)` field'));
    }
  });

  test(
    'super.dispose() and super.onHydrated() are accepted (Flutter habit)',
    () async {
      final js = await _translate('''
$_header
class SState extends ThorState {
  final n = state(0);
  @override
  void onHydrated() {
    super.onHydrated();
    n.value = 1;
  }

  @override
  void dispose() {
    n.value = 0;
    super.dispose();
  }
}
''');
      expect(js, isNot(contains('super')));
      expect(js, contains(r'$l: { h: onHydrated, d: dispose }'));
    },
  );
}
