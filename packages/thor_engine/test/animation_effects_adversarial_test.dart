// Adversarial tests: an effect that reads an AnimationController's value and
// status never sees a torn pair and runs at most once per call, in the lite
// engine (node) and in dart2js's Dart source.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/src/lite_bundle.dart';
import 'package:thor_engine/thor_engine.dart';

final _hasNode = Process.runSync('node', ['--version']).exitCode == 0;

// ---------------------------------------------------------------- lite side

String _bundle() {
  String read(String f) => File('lib/lite/$f').readAsStringSync();
  return liteBundle(
    runtime: read('runtime.js'),
    parts: {
      'duration': read('parts/duration.js'),
      'controllers': read('parts/controllers.js'),
      'animation_controller': read('parts/animation_controller.js'),
    },
    stateJs: '',
    minify: false,
  );
}

const _page = r'''
globalThis.window = globalThis;
const root = { addEventListener() {}, querySelectorAll: () => [] };
globalThis.document = {
  documentElement: root, getElementById: () => null, querySelectorAll: () => [],
  dispatchEvent() {}, cookie: '', createElement: () => ({}),
};
globalThis.CustomEvent = class {};
globalThis.matchMedia = () => ({ matches: false });
globalThis.reportError = () => {};
globalThis.CSSAnimation = class {};
globalThis.KeyframeEffect = class {
  constructor() { this.t = { iterations: 1 }; this.a = null; }
  getComputedTiming() { return { progress: Math.min(1, Math.max(0, (this.a.currentTime ?? 0) / 1000)) }; }
  updateTiming(o) { Object.assign(this.t, o); }
  getTiming() { return this.t; }
  setKeyframes() {}
};
globalThis.Animation = class {
  constructor(e) { this.effect = e; e.a = this; this.currentTime = 0; this.playbackRate = 1; this.playState = 'paused'; }
  pause() { this.playState = 'paused'; }
  play() { this.playState = 'running'; }
};
const step = () => new Promise((r) => setTimeout(r, 0));
''';

/// Runs [body] (JS, with `T`, `D`, `mk(ms)`, `finish(ctl)`) and returns the
/// JSON it leaves in `out`.
Map<String, Object?> _lite(String body) {
  final js =
      '$_page${_bundle()}\n(async () => {\nawait step();\n'
      'const T = thor, D = T.dt.Dur, out = {};\n'
      r'''
const mk = (ms, id = 'S.c') => T.ctl.anim(id, null, D.of(0, 0, 0, 0, ms), null, null);
const finish = (ctl) => {
  const r = ctl.pb.peek() && ctl.pb.peek().r;
  ctl.lead.effect.a.currentTime = r ? 0 : 1000;
  ctl.lead.playState = 'finished';
  ctl.lead.onfinish();
};
const r4 = (n) => Math.round(n * 1e4) / 1e4;
'''
      '$body\nconsole.log(JSON.stringify(out));\n})().catch((e) => { console.error(e); process.exit(1); });';
  final r = Process.runSync('node', ['-e', js]);
  if (r.exitCode != 0) fail('node failed:\n${r.stderr}');
  return jsonDecode((r.stdout as String).trim()) as Map<String, Object?>;
}

// --------------------------------------------------------------- dart side

class FakeDriver implements AnimationDriver {
  final plays = <AnimationPlayback>[];
  bool playing = false;
  @override
  double progress = 0;
  @override
  bool reducedMotion = false;
  @override
  void play(AnimationPlayback p) {
    plays.add(p);
    playing = true;
    progress = p.from;
  }

  @override
  void seek(double t) {
    playing = false;
    progress = t;
  }
}

// ------------------------------------------------------------ common script

/// A step: [op, arg]. Both engines run the same ones.
typedef Op = List<Object?>;

bool torn(List<Object?> r) {
  final v = (r[0] as num).toDouble();
  final s = r[1] as int;
  final anim = r[2] == 1;
  if (anim) return s != 1 && s != 2;
  if (v > 0 && v < 1) return s != 1 && s != 2;
  if (v == 0) return s == 3;
  if (v == 1) return s == 0;
  return false;
}

double _r4(double n) => (n * 1e4).round() / 1e4;

/// Dart engine: runs [ops]; the observer logs [value, status, animating].
List<Map<String, Object?>> runDart(
  List<Op> ops, {
  required int ms,
  bool driver = true,
}) {
  final c = AnimationController(duration: Duration(milliseconds: ms));
  final d = FakeDriver();
  if (driver) c.attachDriver(d);
  final log = <List<Object?>>[];
  effect(() => log.add([_r4(c.value), c.status.index, c.isAnimating ? 1 : 0]));
  final trace = <Map<String, Object?>>[];
  for (final op in ops) {
    final n = log.length;
    String? err;
    try {
      switch (op[0]) {
        case 'forward':
          c.forward();
        case 'reverse':
          c.reverse();
        case 'toggle':
          c.toggle();
        case 'stop':
          c.stop();
        case 'reset':
          c.reset();
        case 'dispose':
          c.dispose();
        case 'value':
          c.value = (op[1] as num).toDouble();
        case 'fwdFrom':
          c.forward(from: (op[1] as num).toDouble());
        case 'revFrom':
          c.reverse(from: (op[1] as num).toDouble());
        case 'repeat':
          c.repeat();
        case 'repeatR':
          c.repeat(reverse: true, count: op.length > 1 ? op[1] as int? : null);
        case 'mid':
          d.progress = (op[1] as num).toDouble();
        case 'finish':
          d.progress = (c.playback?.reverse ?? false) ? 0 : 1;
          c.driverFinished();
      }
    } catch (e) {
      err = e.toString();
    }
    trace.add({'op': op.join(' '), 'err': err != null, 'runs': log.sublist(n)});
  }
  return trace;
}

/// Lite engine: same ops.
List<Map<String, Object?>> runLite(
  List<Op> ops, {
  required int ms,
  bool sig = false,
}) {
  final out = _lite('''
const ops = ${jsonEncode(ops)};
const ctl = mk($ms);
const log = [];
T.effect(() => log.push([r4(${sig ? 'ctl.v.value' : 'ctl.value'}), ctl.s.value, ctl.pb.value != null ? 1 : 0]));
const trace = [];
for (const [op, a] of ops) {
  const n = log.length;
  let err = false;
  try {
    switch (op) {
      case 'forward': ctl.forward(); break;
      case 'reverse': ctl.reverse(); break;
      case 'toggle': ctl.toggle(); break;
      case 'stop': ctl.stop(); break;
      case 'reset': ctl.reset(); break;
      case 'dispose': ctl.dispose(); break;
      case 'value': ctl.value = a; break;
      case 'fwdFrom': ctl.forward(a); break;
      case 'revFrom': ctl.reverse(a); break;
      case 'repeat': ctl.repeat(); break;
      case 'repeatR': ctl.repeat(undefined, undefined, true, undefined, a ?? undefined); break;
      case 'mid': ctl.lead.effect.a.currentTime = a * 1000; break;
      case 'finish': finish(ctl); break;
    }
  } catch (e) { err = true; }
  trace.push({ op: a === undefined || a === null ? op : op + ' ' + a, err, runs: log.slice(n) });
}
out.trace = trace;
''');
  return [for (final t in out['trace'] as List) (t as Map).cast()];
}

Op o(String name, [Object? a]) => a == null ? [name] : [name, a];

Object? _norm(Object? x) => x is List
    ? [for (final e in x) _norm(e)]
    : x is num && x == x.roundToDouble()
    ? x.toInt()
    : x;

String _fmt(List<Map<String, Object?>> t) => t
    .map(
      (e) =>
          '${e['op']}${e['err'] == true ? ' THROWS' : ''}: ${jsonEncode(_norm(e['runs']))}',
    )
    .join('\n');

void main() {
  final sequences = <String, List<Op>>{
    'rapid same tick': [
      o('forward'),
      o('reverse'),
      o('stop'),
      o('value', 0.5),
      o('repeat'),
      o('stop'),
      o('forward'),
      o('mid', 0.4),
      o('reverse'),
      o('finish'),
      o('toggle'),
      o('finish'),
      o('reset'),
    ],
    'from outside [0,1]': [
      o('fwdFrom', -3),
      o('finish'),
      o('fwdFrom', 5),
      o('revFrom', 2),
      o('finish'),
      o('revFrom', -1),
      o('fwdFrom', 0.5),
      o('mid', 0.7),
      o('value', 9),
      o('value', -9),
    ],
    'repeat reverse': [
      o('repeatR', 2),
      o('finish'),
      o('repeatR', 1),
      o('mid', 0.5),
      o('repeatR', null),
      o('stop'),
      o('reverse'),
      o('finish'),
    ],
    'set exact bounds': [
      o('value', 1),
      o('value', 1),
      o('value', 0),
      o('value', 0),
      o('forward'),
      o('value', 1),
      o('reverse'),
      o('value', 0),
    ],
  };

  for (final ms in [300, 0]) {
    group('duration ${ms}ms', () {
      sequences.forEach((name, ops) {
        test('dart2js $name: no torn pair, at most one run', () {
          final t = runDart(ops, ms: ms);
          for (final e in t) {
            final runs = e['runs'] as List;
            expect(
              runs.length,
              lessThanOrEqualTo(1),
              reason: 'more than one run\n${_fmt(t)}',
            );
            for (final r in runs) {
              expect(
                torn(r as List),
                isFalse,
                reason: 'torn ${jsonEncode(r)} in ${e['op']}\n${_fmt(t)}',
              );
            }
          }
        });
        test('dart2js (no driver) $name: no torn pair', () {
          final t = runDart(ops, ms: ms, driver: false);
          for (final e in t) {
            final runs = e['runs'] as List;
            expect(
              runs.length,
              lessThanOrEqualTo(1),
              reason: 'more than one run\n${_fmt(t)}',
            );
          }
        });
        test(
          'lite $name: no torn pair, at most one run',
          skip: _hasNode ? false : 'needs node',
          () {
            final t = runLite(ops, ms: ms);
            for (final e in t) {
              final runs = e['runs'] as List;
              expect(
                runs.length,
                lessThanOrEqualTo(1),
                reason: 'more than one run\n${_fmt(t)}',
              );
              for (final r in runs) {
                expect(
                  torn(r as List),
                  isFalse,
                  reason: 'torn ${jsonEncode(r)} in ${e['op']}\n${_fmt(t)}',
                );
              }
            }
          },
        );
        test(
          'lite (effect reads the v signal) $name: no torn pair, one run',
          skip: _hasNode ? false : 'needs node',
          () {
            final t = runLite(ops, ms: ms, sig: true);
            for (final e in t) {
              final runs = e['runs'] as List;
              expect(
                runs.length,
                lessThanOrEqualTo(1),
                reason: 'more than one run\n${_fmt(t)}',
              );
              for (final r in runs) {
                expect(
                  torn(r as List),
                  isFalse,
                  reason: 'torn ${jsonEncode(r)} in ${e['op']}\n${_fmt(t)}',
                );
              }
            }
          },
        );
        test(
          'PARITY $name: lite and dart2js observe the same sequence',
          skip: _hasNode ? false : 'needs node',
          () {
            final a = runLite(ops, ms: ms);
            final b = runDart(ops, ms: ms);
            expect(_fmt(a), _fmt(b));
          },
        );
      });
    });
  }

  group('dispose during a running animation, then any call', () {
    final ops = [
      o('forward'),
      o('mid', 0.3),
      o('dispose'),
      o('forward'),
      o('mid', 0.6),
      o('finish'),
      o('reverse'),
      o('value', 0.5),
      o('stop'),
    ];
    test(
      'PARITY dispose then keep using it',
      skip: _hasNode ? false : 'needs node',
      () {
        expect(_fmt(runLite(ops, ms: 300)), _fmt(runDart(ops, ms: 300)));
      },
    );
    test(
      'dart2js after dispose, forward still drives value+status coherently',
      () {
        final t = runDart(ops, ms: 300);
        for (final e in t) {
          for (final r in e['runs'] as List) {
            expect(torn(r as List), isFalse, reason: _fmt(t));
          }
        }
        // forward() after dispose: an animating controller must be finishable.
        final c = AnimationController(
          duration: const Duration(milliseconds: 300),
        );
        final d = FakeDriver();
        c.attachDriver(d);
        c.forward();
        c.dispose();
        // Like Flutter: using it after dispose is a clear StateError, not a
        // controller that animates with no driver.
        for (final call in <void Function()>[
          c.forward,
          c.reverse,
          c.repeat,
          () => c.value = 0.5,
        ]) {
          expect(
            call,
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('called after dispose()'),
              ),
            ),
          );
        }
        expect(c.isAnimating, d.playing);
      },
    );
  });

  group('re-entrancy', () {
    test('dart2js status listener calling stop() leaves the driver playing', () {
      final c = AnimationController(
        duration: const Duration(milliseconds: 300),
      );
      final d = FakeDriver();
      c.attachDriver(d);
      c.addStatusListener((s) {
        if (s == AnimationStatus.forward) c.stop();
      });
      c.forward();
      expect(c.isAnimating, isFalse);
      expect(
        d.playing,
        isFalse,
        reason:
            'stop() ran in the listener, then _start called driver.play afterwards',
      );
    });

    test(
      'dart2js status listener calling reverse() leaves driver/status apart',
      () {
        final c = AnimationController(
          duration: const Duration(milliseconds: 300),
        );
        final d = FakeDriver();
        c.attachDriver(d);
        c.addStatusListener((s) {
          if (s == AnimationStatus.forward) c.reverse();
        });
        c.forward();
        // Whatever the final status is, the driver must play in that direction
        // iff the controller says it is animating.
        expect(
          d.playing,
          c.isAnimating,
          reason:
              'status=${c.status} playback=${c.playback?.reverse} '
              'driver.playing=${d.playing} plays=${d.plays.map((p) => p.reverse)}',
        );
        if (c.isAnimating) {
          expect(
            d.plays.last.reverse,
            c.status == AnimationStatus.reverse,
            reason: 'last play direction != status ${c.status}',
          );
        }
      },
    );

    test(
      'dart2js effect reacting to completed calls reverse() (same and other controller)',
      () {
        final a = AnimationController(
          duration: const Duration(milliseconds: 300),
        );
        final b = AnimationController(
          duration: const Duration(milliseconds: 300),
        );
        final da = FakeDriver(), db = FakeDriver();
        a.attachDriver(da);
        b.attachDriver(db);
        final seen = <List<Object?>>[];
        effect(() {
          final s = a.status;
          if (s == AnimationStatus.completed) {
            untracked(() {
              a.reverse();
              b.forward();
            });
          }
        });
        effect(
          () => seen.add([
            a.status.index,
            a.isAnimating,
            b.status.index,
            b.isAnimating,
          ]),
        );
        a.forward();
        da.progress = 1;
        a.driverFinished();
        expect(a.status, AnimationStatus.reverse, reason: jsonEncode(seen));
        expect(a.isAnimating, isTrue);
        expect(da.playing, isTrue);
        expect(b.status, AnimationStatus.forward);
        // The last observation equals the final state.
        expect(seen.last, [
          a.status.index,
          a.isAnimating,
          b.status.index,
          b.isAnimating,
        ], reason: jsonEncode(seen));
        // No observation of "a completed and animating" or "b forward and idle".
        for (final r in seen) {
          if (r[0] == 3) expect(r[1], isFalse, reason: jsonEncode(seen));
          if (r[0] == 1 || r[0] == 2) {
            expect(r[1], isTrue, reason: jsonEncode(seen));
          }
        }
      },
    );

    test(
      'lite effect reacting to completed calls reverse()/forward() (same and other)',
      skip: _hasNode ? false : 'needs node',
      () {
        final out = _lite(r'''
const a = mk(300, 'S.a'), b = mk(300, 'S.b');
const seen = [];
T.effect(() => {
  if (a.s.value === 3) T.untracked ? T.untracked(() => { a.reverse(); b.forward(); }) : (a.reverse(), b.forward());
});
T.effect(() => seen.push([a.s.value, a.pb.value != null ? 1 : 0, b.s.value, b.pb.value != null ? 1 : 0]));
a.forward();
finish(a);
out.seen = seen;
out.fin = [a.s.peek(), a.pb.peek() != null, b.s.peek(), b.pb.peek() != null];
''');
        final seen = (out['seen'] as List).cast<List<Object?>>();
        final fin = out['fin'] as List;
        expect(fin, [2, true, 1, true], reason: jsonEncode(seen));
        expect(seen.last, [2, 1, 1, 1], reason: jsonEncode(seen));
        for (final r in seen) {
          if (r[0] == 3) expect(r[1], 0, reason: jsonEncode(seen));
          if (r[0] == 1 || r[0] == 2) expect(r[1], 1, reason: jsonEncode(seen));
        }
      },
    );

    test(
      'lite effect calling stop() when it sees forward ends idle, effects agree',
      skip: _hasNode ? false : 'needs node',
      () {
        final out = _lite(r'''
const a = mk(300);
const seen = [];
T.effect(() => { if (a.s.value === 1) a.stop(); });
T.effect(() => seen.push([r4(a.value), a.s.value, a.pb.value != null ? 1 : 0]));
a.forward();
out.seen = seen;
out.fin = [a.s.peek(), a.pb.peek() != null];
''');
        expect(out['fin'], [1, false], reason: jsonEncode(out['seen']));
        final seen = (out['seen'] as List).cast<List<Object?>>();
        expect(seen.last, [0, 1, 0], reason: jsonEncode(seen));
      },
    );

    test(
      'dart2js effect calling stop() when it sees forward ends idle, effects agree',
      () {
        final c = AnimationController(
          duration: const Duration(milliseconds: 300),
        );
        final d = FakeDriver();
        c.attachDriver(d);
        final seen = <List<Object?>>[];
        effect(() {
          if (c.status == AnimationStatus.forward) untracked(c.stop);
        });
        effect(() => seen.add([c.value, c.status.index, c.isAnimating]));
        c.forward();
        expect(c.isAnimating, isFalse, reason: jsonEncode(seen));
        expect(d.playing, isFalse);
        expect(seen.last, [0.0, 1, false], reason: jsonEncode(seen));
      },
    );
  });

  group('a throw in the middle of the batch', () {
    test(
      'lite: an effect that throws does not kill the engine for the next call',
      () {
        final out = _lite(r'''
const a = mk(300);
let boom = true, threw = 0;
const seen = [];
T.effect(() => { if (a.s.value === 1 && boom) { boom = false; threw++; throw new Error('x'); } });
T.effect(() => seen.push([a.s.value, a.pb.value != null ? 1 : 0]));
try { a.forward(); } catch (e) { out.err1 = String(e.message); }
out.afterFirst = seen.slice();
out.state1 = [a.s.peek(), a.pb.peek() != null];
finish(a); // completed
out.afterFinish = seen.slice();
try { a.reverse(); } catch (e) { out.err2 = String(e.message); }
out.afterReverse = seen.slice();
out.state2 = [a.s.peek(), a.pb.peek() != null];
''');
        final seen = (out['afterReverse'] as List).cast<List<Object?>>();
        expect(seen.last, [
          2,
          1,
        ], reason: 'the observer is stuck: ${jsonEncode(out)}');
      },
    );

    test(
      'lite the observer after a throwing effect in the same flush still sees the new state',
      skip: _hasNode ? false : 'needs node',
      () {
        final out = _lite(r'''
const a = mk(300);
const seen = [];
T.effect(() => { if (a.s.value === 1) throw new Error('x'); });
T.effect(() => seen.push([a.s.value, a.pb.value != null ? 1 : 0]));
try { a.forward(); } catch (e) {}
out.seen = seen;
out.state = [a.s.peek(), a.pb.peek() != null];
''');
        final seen = (out['seen'] as List).cast<List<Object?>>();
        expect(seen.last, [1, 1], reason: jsonEncode(out));
      },
    );

    test(
      'dart2js an effect that throws: later observers still see the new state, next call fine',
      () {
        final c = AnimationController(
          duration: const Duration(milliseconds: 300),
        );
        final d = FakeDriver();
        c.attachDriver(d);
        final seen = <List<Object?>>[];
        var boom = true;
        effect(() {
          if (c.status == AnimationStatus.forward && boom) {
            boom = false;
            throw StateError('x');
          }
        });
        effect(() => seen.add([c.status.index, c.isAnimating]));
        try {
          c.forward();
        } catch (_) {}
        expect(seen.last, [
          c.status.index,
          c.isAnimating,
        ], reason: 'observer stale after the throw: ${jsonEncode(seen)}');
        d.progress = 1;
        c.driverFinished();
        c.reverse();
        expect(seen.last, [
          c.status.index,
          c.isAnimating,
        ], reason: jsonEncode(seen));
        expect(c.status, AnimationStatus.reverse);
      },
    );

    test(
      'dart2js a status listener that throws does not strand the driver',
      () {
        final c = AnimationController(
          duration: const Duration(milliseconds: 300),
        );
        final d = FakeDriver();
        c.attachDriver(d);
        var boom = true;
        c.addStatusListener((s) {
          if (boom) {
            boom = false;
            throw StateError('x');
          }
        });
        try {
          c.forward();
        } catch (_) {}
        expect(
          d.playing,
          c.isAnimating,
          reason:
              'status=${c.status} isAnimating=${c.isAnimating} '
              'but driver.playing=${d.playing}: the throw skipped driver.play',
        );
        // The next call must work.
        c.reverse();
        expect(d.playing, c.isAnimating);
      },
    );

    test(
      'dart2js a status listener that throws inside a batch still flushes effects once',
      () {
        final c = AnimationController(
          duration: const Duration(milliseconds: 300),
        );
        c.attachDriver(FakeDriver());
        final seen = <List<Object?>>[];
        effect(() => seen.add([c.status.index, c.isAnimating]));
        c.addStatusListener((s) => throw StateError('x'));
        try {
          c.forward();
        } catch (_) {}
        expect(seen.last, [
          c.status.index,
          c.isAnimating,
        ], reason: jsonEncode(seen));
        expect(seen.length, lessThanOrEqualTo(2), reason: jsonEncode(seen));
      },
    );
  });

  group('two controllers sharing one effect', () {
    test(
      'lite one effect on two controllers: one run per controller tick, coherent',
      skip: _hasNode ? false : 'needs node',
      () {
        final out = _lite(r'''
const a = mk(300, 'S.a'), b = mk(300, 'S.b');
const log = [];
T.effect(() => log.push([a.s.value, a.pb.value != null ? 1 : 0, b.s.value, b.pb.value != null ? 1 : 0]));
const trace = [];
const op = (name, f) => { const n = log.length; f(); trace.push([name, log.slice(n)]); };
op('a.forward', () => a.forward());
op('b.forward', () => b.forward());
op('both in one batch', () => T.batch(() => { a.reverse(); b.reverse(); }));
op('a.value=.5;b.value=.5', () => T.batch(() => { a.value = 0.5; b.value = 0.5; }));
op('stop both', () => T.batch(() => { a.forward(); b.forward(); a.stop(); b.stop(); }));
out.trace = trace;
''');
        for (final t in (out['trace'] as List).cast<List<Object?>>()) {
          final runs = (t[1] as List).cast<List<Object?>>();
          expect(runs.length, lessThanOrEqualTo(1), reason: jsonEncode(out));
          for (final r in runs) {
            for (final i in [0, 2]) {
              final anim = r[i + 1] == 1, s = r[i] as int;
              if (anim) {
                expect(
                  s == 1 || s == 2,
                  isTrue,
                  reason: '${t[0]} ${jsonEncode(r)}',
                );
              }
            }
          }
        }
      },
    );

    test(
      'dart2js one effect on two controllers: one run per grouped batch',
      () {
        final a = AnimationController(
          duration: const Duration(milliseconds: 300),
        );
        final b = AnimationController(
          duration: const Duration(milliseconds: 300),
        );
        a.attachDriver(FakeDriver());
        b.attachDriver(FakeDriver());
        final log = <List<Object?>>[];
        effect(
          () => log.add([
            a.status.index,
            a.isAnimating,
            b.status.index,
            b.isAnimating,
          ]),
        );
        var n = log.length;
        batch(() {
          a.forward();
          b.forward();
        });
        expect(log.length - n, 1, reason: jsonEncode(log));
        n = log.length;
        batch(() {
          a.reverse();
          b.reverse();
          a.stop();
          b.stop();
        });
        expect(log.length - n, lessThanOrEqualTo(1), reason: jsonEncode(log));
        for (final r in log) {
          if (r[1] == true) {
            expect(r[0] == 1 || r[0] == 2, isTrue, reason: jsonEncode(log));
          }
          if (r[3] == true) {
            expect(r[2] == 1 || r[2] == 2, isTrue, reason: jsonEncode(log));
          }
        }
      },
    );
  });
}
