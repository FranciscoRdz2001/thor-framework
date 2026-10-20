// The lite part `animation_controller` under node, with a fake Web
// Animations API: an effect that reads the controller's signals must see
// them change together (value, status and playback in one batch), once per
// call, never a new value beside the old status.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/src/lite_bundle.dart';

final _hasNode = Process.runSync('node', ['--version']).exitCode == 0;

String _bundle({required bool minify}) {
  String read(String f) => File('lib/lite/$f').readAsStringSync();
  return liteBundle(
    runtime: read('runtime.js'),
    parts: {
      'duration': read('parts/duration.js'),
      'controllers': read('parts/controllers.js'),
      'animation_controller': read('parts/animation_controller.js'),
    },
    stateJs: '',
    minify: minify,
  );
}

// A page without markup and a Web Animations stand-in: an animation's
// progress follows its currentTime (SPAN = 1000 ms), `finish` ends the lead.
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
  cancel() { this.playState = 'idle'; }
  play() { this.playState = 'running'; }
};
const step = () => new Promise((r) => setTimeout(r, 0));
''';

Map<String, Object?> _run(String script, {required bool minify}) {
  final js =
      '$_page${_bundle(minify: minify)}\n(async () => {\n'
      'await step();\nconst T = thor, D = T.dt.Dur, out = {};\n'
      // One controller with an effect on it: `log` gets one entry per run.
      r'''
const ctl = T.ctl.anim('S.c', null, D.of(0, 0, 0, 0, 300), null, null);
const other = T.signal(-1);
const log = [];
// A status "listener": writes another signal when the status moves.
T.effect(() => { other.value = ctl.s.value * 10; });
T.effect(() => log.push({ v: ctl.v.value, s: ctl.s.value, pb: ctl.pb.value }));
// Another observer, of the listener's signal too: it may run again as the
// listener's write cascades, but its last view must agree.
const seen = [];
T.effect(() => seen.push({ s: ctl.s.value, o: other.value }));
const agree = () => seen.length > 0 && seen[seen.length - 1].o === seen[seen.length - 1].s * 10;
// Runs of the observer caused by `f`, and whether every one is coherent:
// playing => the status agrees with the direction; at a bound, the status is that bound's.
const op = (f) => {
  const n = log.length;
  f();
  const runs = log.slice(n);
  return {
    runs: runs.length,
    bad: runs.filter((r) =>
      (r.pb && r.s !== (r.pb.a ? 1 : r.pb.r ? 2 : 1)) ||
      (r.pb == null && r.v === 0 && r.s !== 0) ||
      (r.pb == null && r.v === 1 && r.s !== 3)).length,
    agree: agree(),
  };
};
const finish = () => { ctl.lead.effect.a.currentTime = ctl.pb.peek().r ? 0 : 1000; ctl.lead.playState = 'finished'; ctl.lead.onfinish(); };
'''
      '$script\nconsole.log(JSON.stringify(out));\n})();';
  final r = Process.runSync('node', ['-e', js]);
  if (r.exitCode != 0) fail('node failed:\n${r.stderr}');
  return jsonDecode((r.stdout as String).trim()) as Map<String, Object?>;
}

void main() {
  for (final minify in [false, true]) {
    group(
      minify ? 'minified' : 'as written',
      skip: _hasNode ? false : 'needs node',
      () {
        test('each call is one coherent tick of the effect', () {
          final out = _run(r'''
out.forward = op(() => ctl.forward());
finish(); // (not counted) completes
out.completed = [ctl.s.peek(), ctl.v.peek()];
out.reverse = op(() => ctl.reverse());
out.midStop = (() => { ctl.lead.effect.a.currentTime = 400; return op(() => ctl.stop()); })();
out.afterStop = [ctl.s.peek(), ctl.v.peek(), ctl.pb.peek()];
out.reverseFromMid = op(() => ctl.reverse());
out.setValue = op(() => { ctl.value = 0.5; });
out.forwardFrom = op(() => ctl.forward(0.25));
out.repeat = op(() => ctl.repeat(undefined, undefined, true));
out.reset = op(() => ctl.reset());
out.toggle = op(() => ctl.toggle());
out.reverseToBound = op(() => ctl.reverse(1));
out.finishReverse = op(() => finish());
out.dispose = (() => { ctl.lead.effect.a.currentTime = 700; return op(() => ctl.dispose()); })();
''', minify: minify);
          for (final k in [
            'forward',
            'reverse',
            'midStop',
            'reverseFromMid',
            'setValue',
            'forwardFrom',
            'repeat',
            'reset',
            'toggle',
            'dispose',
            'reverseToBound',
            'finishReverse',
          ]) {
            final o = out[k] as Map;
            expect(o['bad'], 0, reason: '$k: an effect saw a torn state');
            expect(o['agree'], isTrue, reason: '$k: the listener lagged');
            expect(o['runs'], lessThanOrEqualTo(1), reason: '$k: one run');
          }
          expect((out['forward'] as Map)['runs'], 1);
          expect((out['reverse'] as Map)['runs'], 1);
          expect((out['setValue'] as Map)['runs'], 1);
          expect((out['reset'] as Map)['runs'], 1);
          expect((out['finishReverse'] as Map)['runs'], 1);
          expect(out['completed'], [3, 1]);
          // stop() keeps the status (like Flutter), drops the playback.
          expect((out['afterStop'] as List).sublist(0, 2), [2, 0.4]);
          expect((out['afterStop'] as List)[2], isNull);
        });

        test('repeat(min, max) loops over a stretch: the easing maps the pass '
            'to it, it starts from the value clamped into it', () {
          final out = _run(r'''
const snap = () => ({ pb: ctl.pb.peek(), s: ctl.s.peek(), t: { ...ctl.lead.effect.t }, rate: ctl.lead.playbackRate, at: ctl.lead.currentTime });
ctl.value = 0.55;
ctl.repeat(0.3, 0.8, true);
out.window = snap();
ctl.value = 0;
ctl.repeat(0.3, 0.8);
out.below = snap();
ctl.repeat();
out.whole = snap();
''', minify: minify);
          Map<String, Object?> m(String k) => out[k]! as Map<String, Object?>;
          expect(m('window')['t'], {
            'iterations': null,
            'direction': 'alternate',
            'easing': 'linear(0.3, 0.8)',
          });
          expect((m('window')['pb'] as Map)['m'], [0.3, 0.8]);
          expect(
            m('window')['at'],
            closeTo(500, 1e-6),
            reason: '(0.55-0.3)/0.5',
          );
          expect(m('below')['at'], 0, reason: 'below the window: its start');
          expect(m('whole')['t'], containsPair('easing', 'linear'));
          expect((m('whole')['pb'] as Map)['m'], isNull);
        });

        test('animateTo, animateBack and fling play part of a pass and '
            'release their promises', () {
          final out = _run(r'''
let done = 0;
const dur = (ms) => D.of(0, 0, 0, 0, ms);
const snap = () => ({ pb: ctl.pb.peek(), s: ctl.s.peek(), t: { ...ctl.lead.effect.t }, rate: ctl.lead.playbackRate, at: ctl.lead.currentTime });
const end = (ms) => { ctl.lead.effect.a.currentTime = ms; ctl.lead.playState = 'finished'; ctl.lead.onfinish(); };

// Forward, half way, in 100 ms: the whole pass would take 200 ms.
ctl.animateTo(0.5, dur(100)).then(() => done++);
out.to = snap();
await step();
out.toEarly = done;
end(500);
await step();
out.toEnd = { v: ctl.v.peek(), s: ctl.s.peek(), pb: ctl.pb.peek(), done };

// Backwards from the top to 0.25: reversed direction, three quarters of a pass.
ctl.value = 1;
ctl.animateBack(0.25).then(() => done++);
out.back = snap();
end(250);
await step();
out.backEnd = { v: ctl.v.peek(), s: ctl.s.peek(), done };

// Below the value with animateTo: still the forward status.
ctl.value = 1;
ctl.animateTo(0.75).then(() => done++);
out.below = snap();

// The bound itself keeps the plain negative-rate playback; a new call
// releases the one before.
ctl.lead.effect.a.currentTime = 1000; // (the fake clock: the value is 1)
ctl.animateBack(0).then(() => done++);
await step();
out.bound = snap();
out.releasedByAnother = done;
end(0);
await step();
out.boundEnd = { v: ctl.v.peek(), s: ctl.s.peek(), done };

// fling: the bound in the direction of the velocity, the spring's time.
ctl.fling().then(() => done++);
out.fling = snap();
ctl.lead.effect.a.currentTime = 1000;
ctl.fling(-3).then(() => done++);
out.flingBack = snap();

// A zero duration jumps, status completed; a stop releases.
ctl.value = 0;
const jumped = ctl.animateTo(0.4, dur(0));
out.jumped = { v: ctl.v.peek(), s: ctl.s.peek(), pb: ctl.pb.peek() };
await jumped;
ctl.animateTo(1);
let stopped = 0;
ctl.animateTo(0.5).then(() => stopped++);
ctl.stop();
await step();
out.stopped = stopped;
out.errors = [];
for (const f of [() => ctl.animateTo(NaN), () => { ctl.duration = null; ctl.animateTo(1); }]) {
  try { f(); out.errors.push('none'); } catch (e) { out.errors.push(String(e.message)); }
}
''', minify: minify);
          Map<String, Object?> m(String k) => out[k]! as Map<String, Object?>;
          expect(m('to')['pb'], {
            'f': 0,
            'w': {'us': 200000},
            'r': false,
            'i': 0.5,
            'a': false,
            'e': 0.5,
          });
          expect(m('to')['s'], 1);
          expect(m('to')['t'], {
            'iterations': 0.5,
            'direction': 'normal',
            'easing': 'linear',
          });
          expect(m('to')['rate'], 5);
          expect(out['toEarly'], 0, reason: 'not done while it plays');
          expect(m('toEnd'), {'v': 0.5, 's': 3, 'pb': null, 'done': 1});
          expect(m('back')['t'], {
            'iterations': 0.75,
            'direction': 'reverse',
            'easing': 'linear',
          });
          expect(m('back')['rate'], closeTo(1000 / 300, 1e-9));
          expect(
            m('back')['at'],
            0,
            reason: 'a reversed pass starts at 1 - from',
          );
          expect(m('back')['s'], 2);
          expect(m('backEnd'), {'v': 0.25, 's': 0, 'done': 2});
          expect(m('below')['s'], 1, reason: 'animateTo keeps `forward`');
          expect((m('below')['pb'] as Map)['r'], isTrue);
          expect(m('bound')['rate'], closeTo(-1000 / 300, 1e-9));
          expect((m('bound')['pb'] as Map)['e'], isNull);
          expect(out['releasedByAnother'], 3);
          expect(m('boundEnd')['s'], 0);
          expect(m('boundEnd')['done'], 4);
          // The spring of a fling takes about 0.29 s over the range.
          expect(m('fling')['rate'], inInclusiveRange(1000 / 340, 1000 / 250));
          expect(m('fling')['s'], 1);
          expect(m('flingBack')['s'], 2);
          expect(
            m('flingBack')['rate'],
            inInclusiveRange(-1000 / 250, -1000 / 340),
          );
          expect(
            (m('fling')['t'] as Map)['easing'],
            allOf(startsWith('linear(0 0%, '), endsWith(', 1 100%)')),
          );
          expect(m('jumped'), {'v': 0.4, 's': 3, 'pb': null});
          expect(out['stopped'], 1, reason: 'stop() releases it');
          expect((out['errors'] as List).map((e) => '$e'), [
            contains('target'),
            contains('no default duration'),
          ]);
        });
      },
    );
  }
}
