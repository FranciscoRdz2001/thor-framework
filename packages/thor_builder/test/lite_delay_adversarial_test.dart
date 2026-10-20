// The delay idioms of a Flutter developer in a ThorState (Future.delayed,
// unawaited, Timer, Duration of any unit) on the lite subset: translated to
// setTimeout/Promise and run in node on a fake clock, so the order and the
// time of every callback is checked, not just the text.
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
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

final _node = () {
  try {
    return Process.runSync('node', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();

const _header = '''
import 'dart:async';

import 'package:thor_ui/thor_ui.dart';

''';

/// Runs [js] in node on a fake clock: `advance(ms)` runs every timer due
/// within `ms` in time order (then insertion order), letting promises settle
/// after each; `delays` records the delay asked of each setTimeout.
Map<String, Object?> _run(String js, String script) {
  final parts = RegExp(
    r'^// thor-lite parts: (.*)$',
    multiLine: true,
  ).firstMatch(js)?.group(1)!.split(' ');
  final code = [
    for (final p in ['json', 'datetime', 'duration'])
      if (parts?.contains(p) ?? false)
        File('../thor_engine/lib/lite/parts/$p.js').readAsStringSync(),
  ].join('\n');
  final program =
      '''
const defs = {};
globalThis.thor = { def: (n, f) => { defs[n] = f; }, batch: (f) => f(), untracked: (f) => f() };
$code
$js
const signal = (v) => ({ x: v, get value() { return this.x; }, set value(y) { this.x = y; }, peek() { return this.x; } });
const make = (n) => defs[n]({ key: null, state: (n, v) => signal(v), use: (q) => make(q) });
// The fake clock.
let now = 0, seq = 0;
const timers = [];
const delays = [];
globalThis.setTimeout = (f, ms) => { delays.push(ms); const t = { at: now + ms, id: ++seq, f, p: false, ms }; timers.push(t); return t.id; };
globalThis.setInterval = (f, ms) => { delays.push(ms); const t = { at: now + ms, id: ++seq, f, p: true, ms }; timers.push(t); return t.id; };
globalThis.clearTimeout = globalThis.clearInterval = (h) => { const i = timers.findIndex((t) => t.id === h); if (i >= 0) timers.splice(i, 1); };
const settle = () => new Promise((r) => setImmediate(r));
const advance = async (ms) => {
  const end = now + ms;
  await settle();
  for (;;) {
    const due = timers.filter((t) => t.at <= end).sort((a, b) => a.at - b.at || a.id - b.id)[0];
    if (!due) break;
    now = due.at;
    if (due.p) due.at += Math.max(1, due.ms); else timers.splice(timers.indexOf(due), 1);
    due.f(due.p ? undefined : undefined);
    await settle();
  }
  now = end;
};
const S = make(Object.keys(defs)[0]);
const out = {};
globalThis.__done = (async () => {
$script
out.delays = delays;
})();
Promise.resolve(globalThis.__done).then(() => console.log(JSON.stringify(out)));
''';
  final r = Process.runSync('node', ['-e', program]);
  if (r.exitCode != 0) fail('node failed:\n${r.stderr}\n$js');
  return jsonDecode(r.stdout as String) as Map<String, Object?>;
}

void main() {
  test(
    'unawaited with a conditional, cascade and await-free comma-free args',
    () async {
      final js = await _translate('''
$_header
class AState extends ThorState {
  final n = state(0);
  final flag = state(true);
  Future<void> a() async { n.value += 1; }
  Future<void> b() async { n.value += 10; }
  void go() {
    unawaited(flag.value ? a() : b());
    unawaited(flag.value ? Future<void>.delayed(const Duration(seconds: 1), () => n.value += 100) : b());
  }
  Future<void> viaAwait() async {
    unawaited(Future<void>.delayed(const Duration(seconds: 1), () => n.value += 1000));
  }
}
''');
      expect(js, isNot(contains('unawaited')));
      if (!_node) return markTestSkipped('node is not installed');
      final out = _run(js, '''
S.go();
await advance(0);
out.a = S.\$s.n.value;
await advance(1000);
out.b = S.\$s.n.value;
''');
      expect(out['a'], 1);
      expect(out['b'], 101);
    },
  );

  test('unawaited as the value of an arrow body and of a closure', () async {
    final js = await _translate('''
$_header
class BState extends ThorState {
  final n = state(0);
  void go() => unawaited(Future<void>.delayed(const Duration(seconds: 1), () => n.value += 1));
  final List<void Function()> hooks = [];
  void reg() {
    hooks.add(() => unawaited(Future<void>.delayed(Duration.zero, () => n.value += 5)));
    hooks.first();
  }
}
''');
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, '''
const r = S.go();
out.ret = r === undefined ? null : 'defined';
S.reg();
await advance(1000);
out.n = S.\$s.n.value;
''');
    expect(out['ret'], null);
    expect(out['n'], 6);
  });

  test(
    'unawaited shadowed by a local function or imported with a prefix',
    () async {
      final prefixed = await _translate('''
import 'dart:async' as async;
import 'package:thor_ui/thor_ui.dart';

class CState extends ThorState {
  final n = state(0);
  void go() {
    async.unawaited(Future<void>.delayed(const Duration(seconds: 1), () => n.value += 1));
  }
}
''');
      expect(prefixed, isNot(contains('unawaited')));
      if (_node) {
        final out = _run(prefixed, '''
S.go();
await advance(1000);
out.n = S.\$s.n.value;
''');
        expect(out['n'], 1);
      }
      final shadow = await _translate('''
$_header
class DState extends ThorState {
  final n = state(0);
  void go() {
    void unawaited(Object? x) { n.value += 7; }
    unawaited(1);
  }
}
''');
      if (_node) {
        final out = _run(shadow, '''
S.go();
out.n = S.\$s.n.value;
''');
        expect(out['n'], 7);
      }
    },
  );

  test('unawaited as a tear-off is rejected, not miscompiled', () async {
    try {
      await _translate('''
$_header
class EState extends ThorState {
  void go() {
    final f = unawaited;
    f(Future<void>.value());
  }
}
''');
    } on LiteTranslationException catch (e) {
      expect('${e.errors}', contains('unawaited'));
      return;
    }
    fail('expected an error for the tear-off');
  });

  test('a throwing delayed callback rejects only its own promise', () async {
    final js = await _translate('''
$_header
class FState extends ThorState {
  final n = state(0);
  Future<void> bad() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 5), () => throw StateError('x'));
      n.value = 1;
    } catch (_) {
      n.value = 2;
    } finally {
      n.value += 10;
    }
  }
  void other() { n.value += 100; }
}
''');
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, '''
S.bad();
await advance(5);
out.n = S.\$s.n.value;
S.other();
out.m = S.\$s.n.value;
''');
    expect(out['n'], 12);
    expect(out['m'], 112);
  });

  test('delayed callback value used after await, and try/finally', () async {
    final js = await _translate('''
$_header
class GState extends ThorState {
  final s = state('');
  Future<void> go() async {
    try {
      final v = await Future<int>.delayed(const Duration(milliseconds: 3), () => 41);
      s.value = 'v=\${v + 1}';
    } finally {
      s.value += '!';
    }
  }
}
''');
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, '''
S.go();
await advance(2);
out.early = S.\$s.s.value;
await advance(1);
out.s = S.\$s.s.value;
''');
    expect(out['early'], '');
    expect(out['s'], 'v=42!');
  });

  test('Duration arithmetic in delays', () async {
    final js = await _translate('''
$_header
const Duration base = Duration(milliseconds: 100);
class HState extends ThorState {
  final n = state(0);
  void go() {
    const other = Duration(milliseconds: 50);
    unawaited(Future<void>.delayed(base * 2, () => n.value += 1));
    unawaited(Future<void>.delayed(base + other, () => n.value += 10));
    unawaited(Future<void>.delayed(Duration(seconds: 1) - base, () => n.value += 100));
    unawaited(Future<void>.delayed(Duration(milliseconds: Duration(seconds: 2).inMilliseconds ~/ 4), () => n.value += 1000));
  }
  void dflt() {
    unawaited(Future<void>.delayed(const Duration(), () => n.value += 5));
    unawaited(Future<void>.delayed(Duration.zero, () => n.value += 5));
  }
}
''');
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, '''
S.go();
await advance(150);
out.a = S.\$s.n.value;
await advance(50);
out.b = S.\$s.n.value;
await advance(300);
out.c = S.\$s.n.value;
await advance(450);
out.d = S.\$s.n.value;
S.dflt();
await advance(0);
out.e = S.\$s.n.value;
''');
    expect(out['a'], 10);
    expect(out['b'], 11);
    expect(out['c'], 1011);
    expect(out['d'], 1111);
    expect(out['e'], 1121);
  });

  test('a Timer kept in a field, cancelled from another method', () async {
    final js = await _translate('''
$_header
class IState extends ThorState {
  final n = state(0);
  Timer? _t;
  void start() {
    _t?.cancel();
    _t = Timer.periodic(const Duration(milliseconds: 10), (t) {
      n.value += 1;
      if (n.value >= 3) t.cancel();
    });
  }
  void stop() { _t?.cancel(); _t = null; }
  bool get running => _t != null && _t!.isActive;
}
''');
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, '''
S.start();
S.start();
await advance(25);
out.a = S.\$s.n.value;
S.stop();
await advance(100);
out.b = S.\$s.n.value;
S.start();
await advance(100);
out.c = S.\$s.n.value;
''');
    expect(out['a'], 2);
    expect(out['b'], 2);
    expect(out['c'], 3);
  });

  test('a Timer stored in a signal and a periodic timer of 0 ms', () async {
    final js = await _translate('''
$_header
class JState extends ThorState {
  final n = state(0);
  final timer = state<Timer?>(null);
  void start() {
    timer.value = Timer.periodic(Duration.zero, (t) {
      n.value += 1;
      if (n.value == 4) { timer.value?.cancel(); }
    });
  }
}
''');
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, '''
S.start();
await advance(50);
out.n = S.\$s.n.value;
''');
    expect(out['n'], 4);
  });

  test(
    'an async getter of a plain class keeps this and returns a promise',
    () async {
      final js = await _translate('''
$_header
class Box {
  Box(this.v);
  final int v;
  Future<int> get later async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return v + 1;
  }
}
class LState extends ThorState {
  final n = state(0);
  Future<void> go() async { n.value = await Box(4).later; }
}
''');
      if (!_node) return markTestSkipped('node is not installed');
      final out = _run(js, '''
const p = S.go();
await advance(5);
await p;
out.n = S.\$s.n.value;
''');
      expect(out['n'], 5);
    },
  );

  test('a delay inside a getter used by Watch-style reads', () async {
    final js = await _translate('''
$_header
class KState extends ThorState {
  final n = state(0);
  Future<int> get later async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return n.value + 1;
  }
  Future<void> go() async { n.value = await later; }
}
''');
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, '''
const p = S.go();
await advance(5);
await p;
out.n = S.\$s.n.value;
''');
    expect(out['n'], 1);
  });
}
