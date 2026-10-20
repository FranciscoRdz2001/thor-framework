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

Future<List<String>> _errors(String source) async {
  try {
    await _translate(source);
  } on LiteTranslationException catch (e) {
    return [for (final x in e.errors) '$x'];
  }
  fail('expected lite errors');
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
  test('the toast idiom: unawaited(Future.delayed(d, callback))', () async {
    final js = await _translate('''
$_header
class ToastState extends ThorState {
  final snackBarVisible = state(false);
  void submit() {
    snackBarVisible.value = true;
    unawaited(Future.delayed(const Duration(seconds: 3), () => snackBarVisible.value = false));
  }
}
''');
    expect(js, contains('setTimeout'));
    expect(js, isNot(contains('unawaited')));
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, '''
S.submit();
out.on = S.\$s.snackBarVisible.value;
await advance(2999);
out.at2999 = S.\$s.snackBarVisible.value;
await advance(1);
out.at3000 = S.\$s.snackBarVisible.value;
''');
    expect(out['on'], true);
    expect(out['at2999'], true);
    expect(out['at3000'], false);
    expect(out['delays'], [3000]);
  });

  test(
    'every Duration unit, const or computed, in a field or a const',
    () async {
      final js = await _translate('''
$_header
const _kDay = Duration(days: 1, hours: 2, microseconds: 1500);
class UnitsState extends ThorState {
  final hold = state(2);
  final done = state(0);
  final Duration _field = const Duration(minutes: 1, seconds: 30);
  Duration computed() => Duration(seconds: hold.value * 2, milliseconds: 7);
  void go() {
    unawaited(Future<void>.delayed(_kDay, () => done.value += 1));
    unawaited(Future<void>.delayed(_field, () => done.value += 10));
    unawaited(Future<void>.delayed(computed(), () => done.value += 100));
    unawaited(Future<void>.delayed(Duration(hours: hold.value), () => done.value += 1000));
    unawaited(Future<void>.delayed(const Duration(microseconds: 999), () => done.value += 10000));
  }
}
''');
      if (!_node) return markTestSkipped('node is not installed');
      final out = _run(js, '''
S.go();
await advance(0);
out.d0 = S.\$s.done.value;
await advance(4007);
out.computed = S.\$s.done.value;
await advance(90000 - 4007);
out.field = S.\$s.done.value;
await advance(7200000 - 90000);
out.hours = S.\$s.done.value;
await advance(86400000 + 7200000 + 1 - 7200000);
out.day = S.\$s.done.value;
''');
      // 999 us truncates to 0 ms: due at once, like Dart's inMilliseconds.
      expect(out['d0'], 10000);
      expect(out['computed'], 10100);
      expect(out['field'], 10110);
      expect(out['hours'], 11110);
      expect(out['day'], 11111);
      expect(out['delays'], [86400000 + 7200000 + 1, 90000, 4007, 7200000, 0]);
    },
  );

  test('awaited delays: nested, in a loop, zero and negative', () async {
    final js = await _translate('''
$_header
class SeqState extends ThorState {
  final log = state('');
  Future<void> nested() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    log.value += 'a';
    await Future<void>.delayed(const Duration(milliseconds: 20));
    log.value += 'b';
    final v = await Future.delayed(Duration.zero, () => 'c');
    log.value += v;
  }
  Future<void> loop() async {
    for (var i = 1; i <= 3; i++) {
      await Future<void>.delayed(Duration(milliseconds: i * 10));
      log.value += '\$i';
    }
  }
  Future<void> negative() async {
    await Future<void>.delayed(const Duration(seconds: -5));
    log.value += 'n';
    await Future<void>.delayed(Duration.zero);
    log.value += 'z';
  }
  void fanOut() {
    for (var i = 3; i >= 1; i--) {
      unawaited(Future<void>.delayed(Duration(milliseconds: i * 10), () => log.value += '\$i'));
    }
  }
}
''');
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, '''
const L = () => S.\$s.log.value;
S.nested();
await advance(9); out.n0 = L();
await advance(1); out.n1 = L();
await advance(19); out.n2 = L();
await advance(1); out.n3 = L();
S.\$s.log.value = '';
S.loop();
await advance(10); out.l1 = L();
await advance(20); out.l2 = L();
await advance(29); out.l3a = L();
await advance(1); out.l3 = L();
S.\$s.log.value = '';
S.negative();
await advance(0); out.neg = L();
S.\$s.log.value = '';
S.fanOut();
await advance(30); out.fan = L();
''');
    expect(out['n0'], '');
    expect(out['n1'], 'a');
    expect(out['n2'], 'a');
    expect(out['n3'], 'abc');
    expect(out['l1'], '1');
    expect(out['l2'], '12');
    expect(out['l3a'], '12');
    expect(out['l3'], '123');
    expect(out['neg'], 'nz');
    expect(out['fan'], '123'); // time order, not call order
    expect((out['delays'] as List).take(2), [10, 20]);
    expect(out['delays'] as List, contains(0)); // -5 s clamped to 0
    expect(out['delays'] as List, isNot(contains(-5000)));
  });

  test('a callback fires on the state as it is then, not as it was', () async {
    final js = await _translate('''
$_header
class LateState extends ThorState {
  final shown = state(false);
  final n = state(0);
  void show() {
    shown.value = true;
    final mine = n.value;
    unawaited(Future.delayed(const Duration(seconds: 1), () {
      // Reads the field at fire time.
      n.value = n.value * 10 + mine;
      shown.value = false;
    }));
  }
  void bump() => n.value++;
  void hide() => shown.value = false;
  void later() => unawaited(Future.delayed(const Duration(seconds: 1), hide));
}
''');
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, '''
S.show();
S.bump(); S.bump();
await advance(1000);
out.n = S.\$s.n.value;
out.shown = S.\$s.shown.value;
S.\$s.shown.value = true;
S.later(); // a tear-off as the callback
out.before = S.\$s.shown.value;
await advance(1000);
out.after = S.\$s.shown.value;
''');
    expect(out['n'], 20); // (2 * 10) + 0
    expect(out['shown'], false);
    expect(out['before'], true);
    expect(out['after'], false);
  });

  test('unawaited of a future that is not a delay', () async {
    final js = await _translate('''
$_header
class PingState extends ThorState {
  final pings = state(0);
  Future<void> _ping() async {
    pings.value++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    pings.value += 10;
  }
  void go() {
    unawaited(_ping());
    unawaited(Future.value(1));
    unawaited(Future<void>.delayed(Duration.zero));
  }
  Future<void> goAwait() async {
    unawaited(_ping());
    pings.value += 100;
  }
}
''');
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, '''
S.go();
out.sync = S.\$s.pings.value; // _ping ran to its first await
await advance(5);
out.after = S.\$s.pings.value;
S.\$s.pings.value = 0;
await S.goAwait();
out.both = S.\$s.pings.value;
await advance(5);
out.end = S.\$s.pings.value;
''');
    expect(out['sync'], 1);
    expect(out['after'], 11);
    expect(out['both'], 101);
    expect(out['end'], 111);
  });

  test('Timer: one-shot, zero, cancel before and after, periodic', () async {
    final js = await _translate('''
$_header
class TimerState extends ThorState {
  final hits = state(0);
  Timer? _once;
  Timer? _tick;
  void _hit() => hits.value++;
  void arm() {
    _once?.cancel();
    _once = Timer(const Duration(milliseconds: 50), _hit);
  }
  void zero() => Timer(Duration.zero, _hit);
  void negative() => Timer(const Duration(seconds: -1), _hit);
  void disarm() => _once?.cancel();
  void every() {
    _tick = Timer.periodic(const Duration(milliseconds: 10), (t) {
      hits.value += 100;
      if (t.tick >= 3) t.cancel();
    });
  }
  void stop() {
    _tick?.cancel();
    _tick?.cancel(); // twice: harmless
  }
  bool armed() => _once?.isActive ?? false;
}
''');
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, '''
const H = () => S.\$s.hits.value;
S.arm(); S.arm(); // the second cancels the first
out.armed = S.armed();
await advance(49); out.h49 = H();
await advance(1); out.h50 = H(); out.armedAfter = S.armed();
S.arm(); S.disarm();
await advance(100); out.cancelled = H();
S.zero(); S.negative();
await advance(0); out.zeros = H();
S.\$s.hits.value = 0;
S.every();
await advance(100); out.periodic = H(); // cancelled by its callback at tick 3
S.\$s.hits.value = 0;
S.every();
await advance(25); S.stop();
await advance(100); out.stopped = H();
''');
    expect(out['armed'], true);
    expect(out['h49'], 0);
    expect(out['h50'], 1);
    expect(out['armedAfter'], false);
    expect(out['cancelled'], 1);
    expect(out['zeros'], 3);
    expect(out['periodic'], 300);
    expect(out['stopped'], 200);
  });

  test('the generated JS runs on real timers', () async {
    final js = await _translate('''
$_header
class RealState extends ThorState {
  final s = state('');
  Future<void> go() async {
    unawaited(Future.delayed(const Duration(milliseconds: 5), () => s.value += 'b'));
    s.value += 'a';
    await Future<void>.delayed(const Duration(milliseconds: 30));
    s.value += 'c';
  }
}
''');
    if (!_node) return markTestSkipped('node is not installed');
    final dur = [
      for (final p in ['datetime', 'duration'])
        File('../thor_engine/lib/lite/parts/$p.js').readAsStringSync(),
    ].join('\n');
    final program =
        '''
const defs = {};
globalThis.thor = { def: (n, f) => { defs[n] = f; }, batch: (f) => f() };
$dur
$js
const sig = { v: '', get value() { return this.v; }, set value(x) { this.v = x; } };
const S = defs[Object.keys(defs)[0]]({ key: null, state: () => sig, use: () => ({}) });
S.go().then(() => console.log(sig.v));
''';
    final r = Process.runSync('node', ['-e', program]);
    if (r.exitCode != 0) fail('node failed:\n${r.stderr}\n$js');
    expect((r.stdout as String).trim(), 'abc');
  });

  group('what stays out says how to get out', () {
    test('.timeout on Future.delayed names Timer', () async {
      final e = await _errors('''
$_header
class ThenState extends ThorState {
  final v = state(0);
  void go() {
    Future<void>.delayed(const Duration(seconds: 1)).timeout(const Duration(seconds: 2));
  }
}
''');
      final text = e.join('\n');
      expect(text, contains('`.timeout()`'));
      expect(text, contains('Timer'));
    });

    test('Timer.run and Future.delayed(...).timeout name Timer(...)', () async {
      final e = await _errors('''
$_header
class RunState extends ThorState {
  final v = state(0);
  void go() => Timer.run(() => v.value = 1);
}
''');
      expect(e.join('\n'), contains('Timer.run'));
      expect(e.join('\n'), contains('Timer(Duration.zero'));
    });

    test('unawaited of a non-lite future still fails on the future', () async {
      final e = await _errors('''
$_header
class WaitState extends ThorState {
  void go() => unawaited(Future.value(1).timeout(const Duration(seconds: 1)));
}
''');
      expect(e.join('\n'), contains('.timeout()'));
    });
  });
}
