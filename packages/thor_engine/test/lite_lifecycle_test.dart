@TestOn('vm')
library;

// The lifecycle of a lite state (`onHydrated`, `dispose`) under node with
// A fake DOM that knows what the runtime asks of a page that changes:
// connected elements, `querySelector` by attribute, a MutationObserver that
// reports removals, `pagehide`. Each test runs on the runtime as written and
// minified. `$l: {h, d}` is what thor_builder emits for a state that
// overrides `onHydrated()` / `dispose()`; `idle: true` marks the first.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/src/lite_bundle.dart';

final _hasNode = Process.runSync('node', ['--version']).exitCode == 0;

const _page = r'''
globalThis.window = globalThis;
const listeners = {};
const winListeners = {};
let stateText = null;
const all = []; // every element ever made; the connected ones are the page
const ATTRS = ['data-tt', 'data-tv', 'data-tl', 'data-tf', 'data-tvf', 'data-t-on'];
const live = () => all.filter((e) => e.isConnected);
const root = {
  innerHTML: '',
  addEventListener(t, f) { listeners[t] = f; },
  querySelectorAll: (sel) => live().filter((e) => ATTRS.some((a) => sel.includes(`[${a}]`) && e.hasAttribute(a))),
};
// `[attr^="v"]` / `[attr*="v"]`, comma separated, with \" and \\ escapes.
const matcher = (sel) => {
  const re = /\[([\w-]+)([\^*])="((?:[^"\\]|\\.)*)"\]/g;
  const parts = [];
  for (let m; (m = re.exec(sel)); ) parts.push([m[1], m[2], m[3].replace(/\\(.)/g, '$1')]);
  return (e) => parts.some(([a, op, v]) => {
    const x = e.getAttribute(a);
    return x != null && (op === '^' ? x.startsWith(v) : x.includes(v));
  });
};
let observers = 0;
class MutationObserver {
  constructor(cb) { this.cb = cb; MutationObserver.last = this; }
  observe() { observers++; }
}
globalThis.MutationObserver = MutationObserver;
globalThis.addEventListener = (t, f) => { (winListeners[t] ||= []).push(f); };
const pagehide = (persisted) => (winListeners.pagehide || []).forEach((f) => f({ type: 'pagehide', persisted }));
globalThis.document = {
  documentElement: root, cookie: '', querySelectorAll: (s) => root.querySelectorAll(s),
  querySelector: (sel) => { const m = matcher(sel); return live().find(m) || null; },
  getElementById: (id) => (id === 'thor-state' && stateText != null ? { textContent: stateText } : null),
  dispatchEvent() {}, createElement: () => ({}),
};
globalThis.CustomEvent = class {};
class El {
  constructor(attrs = {}, parent = null, tagName = 'DIV') {
    this.a = Object.assign(Object.create(null), attrs);
    this.parent = parent;
    this.tagName = tagName;
    this.isConnected = true;
    this.textContent = '';
    this.nodeType = 1;
    all.push(this);
    const o = MutationObserver.last;
    if (o) queueMicrotask(() => o.cb([{ removedNodes: [], addedNodes: [this] }]));
  }
  matches(sel) { return ATTRS.some((a) => sel.includes(`[${a}]`) && this.hasAttribute(a)); }
  querySelectorAll() { return []; }
  get parentElement() { return this.parent; }
  getAttribute(n) { return n in this.a ? this.a[n] : null; }
  hasAttribute(n) { return n in this.a; }
  closest(sel) {
    const names = sel.split(',').map((s) => s.slice(1, -1));
    for (let e = this; e; e = e.parent) if (names.some((n) => e.hasAttribute(n))) return e;
    return null;
  }
  // What the browser does: the element leaves; the observer hears it at the
  // end of the task (a microtask), in one batch.
  remove() {
    this.isConnected = false;
    const o = MutationObserver.last;
    if (o) queueMicrotask(() => o.cb([{ removedNodes: [this], addedNodes: [] }]));
  }
}
const fire = (target, type, extra = {}) => {
  const e = { type, target, cancelBubble: false, preventDefault() {}, stopPropagation() { this.cancelBubble = true; }, ...extra };
  listeners[type](e);
  return e;
};
const step = () => new Promise((r) => setTimeout(r, 0));
const errors = [];
globalThis.reportError = (x) => errors.push(x.message);
// A row of keyed states: its text and its button, as the server wrote them.
const rowEls = (key, cls = 'Row') => ({
  label: new El({ 'data-tt': `${cls}#${key}.label` }),
  btn: new El({ 'data-t-on': `click:${cls}#${key}.inc` }),
});
// The subscribers of a signal: what a state leaked if it is not 0.
const subs = (s) => { let n = 0; for (let l = s.sh; l; l = l.q) n++; return n; };
''';

Future<Map<String, Object?>> _run(
  String stateJs,
  String script, {
  required bool minify,
}) async {
  final runtime = File('lib/lite/runtime.js').readAsStringSync();
  final bundle = liteBundle(
    runtime: runtime,
    parts: {
      'lifecycle': File('lib/lite/parts/lifecycle.js').readAsStringSync(),
    },
    stateJs: stateJs,
    minify: minify,
  );
  final js =
      '$_page$bundle\n(async () => {\nawait step();\nconst out = {};\n'
      '$script\nconsole.log(JSON.stringify(out));\nprocess.exit(0);\n})();';
  // A runtime that loops must fail the test, not hang the run.
  final p = await Process.start('node', ['-e', js]);
  final stdout = utf8.decodeStream(p.stdout);
  final stderr = utf8.decodeStream(p.stderr);
  final code = await p.exitCode.timeout(
    const Duration(seconds: 30),
    onTimeout: () {
      p.kill(ProcessSignal.sigkill);
      return -1;
    },
  );
  if (code != 0) fail('node failed ($code):\n${await stderr}');
  return jsonDecode((await stdout).trim()) as Map<String, Object?>;
}

// A keyed state that logs its life, reads the shared `tick` signal in its
// label (one subscriber per live state) and keeps an interval it stops in
// `dispose`.
const _row = r'''
const log = [];
const tick = thor.signal(0);
let intervals = 0;
thor.def('Row', ($) => {
  const n = $.state('n', 0);
  let iv;
  return {
    label: () => `${$.key}:${n.value}:${tick.value}`,
    inc: () => { n.value++; },
    $l: {
      h: () => { log.push(`h${$.key}`); intervals++; iv = setInterval(() => {}, 1000); },
      d: () => { log.push(`d${$.key}`); intervals--; clearInterval(iv); },
    },
  };
}, { idle: true });
''';

void main() {
  for (final minify in [false, true]) {
    group(
      minify ? 'minified' : 'as written',
      skip: _hasNode ? false : 'needs node',
      () {
        test('onHydrated runs once, before the first action, on a lazy '
            'state (no idle)', () async {
          final out = await _run(
            r'''
const log = [];
thor.def('S', ($) => {
  const n = $.state('n', 0);
  return {
    count: () => `${n.value}`,
    inc: () => { log.push('inc'); n.value++; },
    $l: { h: () => log.push('h') },
  };
});
''',
            r'''
const label = new El({ 'data-tt': 'S.count' });
const btn = new El({ 'data-t-on': 'click:S.inc' });
await step();
out.beforeEvent = log.join();
fire(btn, 'click'); fire(btn, 'click');
out.log = log.join();
out.label = label.textContent;
''',
            minify: minify,
          );
          expect(out['beforeEvent'], '');
          expect(out['log'], 'h,inc,inc');
          expect(out['label'], '2');
        });

        test('a state with idle: true wakes at idle with no event', () async {
          final out = await _run(_row, r'''
const { label } = rowEls('a');
rowEls('b');
await step(); await step();
out.log = log.join();
out.label = label.textContent;
out.intervals = intervals;
''', minify: minify);
          // the keyed instances the page shows wake; no phantom `Row` (no key)
          expect(out['log'], 'ha,hb');
          expect(out['label'], 'a:0:0');
          expect(out['intervals'], 2);
        });

        test(
          'a named-only idle state wakes only where the page names it',
          () async {
            const defs = r'''
const log = [];
thor.def('Lazy', ($) => ({
  label: () => 'x',
  $l: { h: () => log.push('lazy') },
}), { idle: true, named: true });
thor.def('Ticker', ($) => ({
  $l: { h: () => log.push('ticker') },
}), { idle: true });
''';
            // Another page: nothing names `Lazy`; the plain idle state still
            // wakes with no element.
            final other = await _run(defs, r'''
new El({ 'data-tt': 'Other.x' });
await step(); await step();
out.log = log.join();
''', minify: minify);
            expect(other['log'], 'ticker');
            // Its own page: an element names it.
            final own = await _run(defs, r'''
new El({ 'data-tt': 'Lazy.label' });
await step(); await step();
out.log = log.sort().join();
''', minify: minify);
            expect(own['log'], 'lazy,ticker');
            // Named by an event binding only.
            final ev = await _run(defs, r'''
new El({ 'data-t-on': 'click:Lazy.label' });
await step(); await step();
out.log = log.sort().join();
''', minify: minify);
            expect(ev['log'], 'lazy,ticker');
            // Named only through a state the page names that uses it.
            final used = await _run(
              '''
$defs
thor.def('User', (\$) => ({ label: () => 'u' }), { uses: ['Lazy'] });
''',
              r'''
new El({ 'data-tt': 'User.label' });
await step(); await step();
out.log = log.sort().join();
''',
              minify: minify,
            );
            expect(used['log'], 'lazy,ticker');
          },
        );

        test('a keyed class with idle: true and no page elements wakes its '
            'default instance', () async {
          final out = await _run(_row, r'''
await step(); await step();
out.log = log.join();
''', minify: minify);
          expect(out['log'], 'hnull');
        });

        test('an idle state wakes even when another class name ends with '
            'its name and has a key in the page', () async {
          final out = await _run(
            r'''
const log = [];
thor.def('Clock', ($) => ({ $l: { h: () => log.push('clock') } }), { idle: true });
thor.def('WorldClock', ($) => ({ x: () => 'x' }));
''',
            r'''
root.innerHTML = '<i data-tt="WorldClock#a.x"></i>';
await step(); await step();
out.log = log.join();
''',
            minify: minify,
          );
          expect(out['log'], 'clock');
        });

        test('onHydrated that throws is reported; the state and the others '
            'keep working', () async {
          final out = await _run(
            r'''
thor.def('Bad', ($) => {
  const n = $.state('n', 0);
  return {
    count: () => `${n.value}`,
    inc: () => { n.value++; },
    $l: { h: () => { throw Error('init boom'); } },
  };
}, { idle: true });
thor.def('Good', ($) => {
  const n = $.state('n', 0);
  return { count: () => `${n.value}`, inc: () => { n.value++; } };
});
''',
            r'''
const bad = new El({ 'data-tt': 'Bad.count' });
const good = new El({ 'data-tt': 'Good.count' });
await step(); await step();
out.errors = errors.slice();
fire(new El({ 'data-t-on': 'click:Bad.inc' }), 'click');
fire(new El({ 'data-t-on': 'click:Good.inc' }), 'click');
out.bad = bad.textContent;
out.good = good.textContent;
out.errorsAfter = errors.length; // not run again
''',
            minify: minify,
          );
          expect(out['errors'], ['init boom']);
          expect(out['bad'], '1');
          expect(out['good'], '1');
          expect(out['errorsAfter'], 1);
        });

        test('an async onHydrated that rejects is reported', () async {
          final out = await _run(
            r'''
thor.def('S', ($) => ({
  inc: () => {},
  $l: { h: async () => { await null; throw Error('late boom'); } },
}));
''',
            r'''
fire(new El({ 'data-t-on': 'click:S.inc' }), 'click');
await step();
out.errors = errors.slice();
''',
            minify: minify,
          );
          expect(out['errors'], ['late boom']);
        });

        test(
          'onHydrated that sets fields updates the UI once, no loop',
          () async {
            final out = await _run(
              r'''
let runs = 0, renders = 0;
thor.def('S', ($) => {
  const n = $.state('n', 0);
  const m = $.state('m', 0);
  return {
    count: () => { renders++; return `${n.value}/${m.value}`; },
    $l: { h: () => { runs++; n.value = 5; m.value = 6; } },
  };
}, { idle: true });
''',
              r'''
const label = new El({ 'data-tt': 'S.count' });
await step(); await step();
out.label = label.textContent;
out.runs = runs;
out.renders = renders; // first paint + one batched update
''',
              minify: minify,
            );
            expect(out['label'], '5/6');
            expect(out['runs'], 1);
            expect(out['renders'], 2);
          },
        );

        test('dispose runs once when the last element of the state leaves; '
            'the same key back is a new instance', () async {
          final out = await _run(_row, r'''
const a = rowEls('a');
await step(); await step();
a.label.remove(); // the button is still there: the state lives
await step();
out.stillThere = log.join();
a.btn.remove();
await step(); await step();
out.removed = log.join();
out.intervalsAfterRemove = intervals;
// the same key back (a row re-added): a new instance, hydrated again
const again = rowEls('a');
fire(again.btn, 'click');
await step();
out.readded = log.join();
out.label = again.label.textContent;
again.label.remove(); again.btn.remove();
await step(); await step();
out.final = log.join();
out.intervals = intervals;
out.subs = subs(tick);
''', minify: minify);
          expect(out['stillThere'], 'ha');
          expect(out['removed'], 'ha,da');
          expect(out['intervalsAfterRemove'], 0);
          // fresh from the server's value (the click counts: 1), tick bound
          expect(out['readded'], 'ha,da,ha');
          expect(out['label'], 'a:1:0');
          expect(out['final'], 'ha,da,ha,da');
          expect(out['intervals'], 0);
          expect(out['subs'], 0);
        });

        test('a list cleared disposes every row state exactly once', () async {
          final out = await _run(_row, r'''
const rows = [];
for (let i = 0; i < 5; i++) rows.push(rowEls(`k${i}`));
await step(); await step();
for (const r of rows) { r.label.remove(); r.btn.remove(); }
await step(); await step();
out.log = log.join();
out.intervals = intervals;
out.subs = subs(tick);
// a second sweep (any other removal) does not dispose again
new El().remove();
await step();
out.again = log.length;
''', minify: minify);
          expect(out['log'], 'hk0,hk1,hk2,hk3,hk4,dk0,dk1,dk2,dk3,dk4');
          expect(out['intervals'], 0);
          expect(out['subs'], 0);
          expect(out['again'], 10);
        });

        test('a variant replaced by its copy in the same task is not a '
            'disposal; removed for good, it is', () async {
          final out = await _run(_row, r'''
const a = rowEls('a');
await step(); await step();
// replaceWith: the copy is in before the observer reports the old one out
const copy = rowEls('a');
a.label.remove(); a.btn.remove();
await step(); await step();
out.swapped = log.join();
// and back
const back = rowEls('a');
copy.label.remove(); copy.btn.remove();
await step(); await step();
out.swappedBack = log.join();
back.label.remove(); back.btn.remove();
await step(); await step();
out.gone = log.join();
''', minify: minify);
          expect(out['swapped'], 'ha');
          expect(out['swappedBack'], 'ha');
          expect(out['gone'], 'ha,da');
        });

        test('pagehide: a page kept for the bfcache disposes nothing; a '
            'page unloaded disposes every live state once', () async {
          final out = await _run(_row, r'''
rowEls('a'); rowEls('b');
await step(); await step();
pagehide(true); // bfcache: the browser freezes the page as it is
out.persisted = log.join();
pagehide(false);
out.unloaded = log.join();
pagehide(false);
out.twice = log.join();
out.intervals = intervals;
out.subs = subs(tick);
''', minify: minify);
          expect(out['persisted'], 'ha,hb');
          expect(out['unloaded'], 'ha,hb,da,db');
          expect(out['twice'], 'ha,hb,da,db');
          expect(out['intervals'], 0);
          expect(out['subs'], 0);
        });

        test('dispose that throws is reported; the effects still stop and '
            'the other states are disposed', () async {
          final out = await _run(
            r'''
const log = [];
const tick = thor.signal(0);
for (const name of ['A', 'B']) {
  thor.def(name, ($) => ({
    label: () => `${tick.value}`,
    $l: { d: () => { log.push('d' + name); if (name === 'A') throw Error('dispose boom'); } },
  }));
}
''',
            r'''
const a = new El({ 'data-tt': 'A.label' }), b = new El({ 'data-tt': 'B.label' });
thor.use('A'); thor.use('B');
out.subsBefore = subs(tick);
a.remove(); b.remove();
await step();
out.log = log.join();
out.errors = errors.slice();
out.subs = subs(tick);
''',
            minify: minify,
          );
          expect(out['subsBefore'], 2);
          expect(out['log'], 'dA,dB');
          expect(out['errors'], ['dispose boom']);
          expect(out['subs'], 0);
        });

        test('nested states: a state another one uses lives until its users '
            'are gone; users are disposed first', () async {
          final out = await _run(
            r'''
const log = [];
thor.def('Inner', ($) => ({
  label: () => 'i',
  $l: { d: () => log.push('dInner') },
}));
thor.def('Outer', ($) => {
  const inner = $.use('Inner');
  return { label: () => `o${inner.label()}`, $l: { d: () => log.push('dOuter') } };
}, { uses: ['Inner'] });
''',
            r'''
const i = new El({ 'data-tt': 'Inner.label' }), o = new El({ 'data-tt': 'Outer.label' });
thor.use('Outer');
i.remove();
await step();
out.innerOnly = log.join();
o.remove();
await step();
out.both = log.join();
''',
            minify: minify,
          );
          expect(out['innerOnly'], '');
          expect(out['both'], 'dOuter,dInner');
        });

        test('1000 rows, each with its own state, added and removed: nothing '
            'leaks', () async {
          final out = await _run(_row, r'''
for (let round = 0; round < 3; round++) {
  const rows = [];
  for (let i = 0; i < 1000; i++) rows.push(rowEls(`r${i}`));
  await step(); await step();
  if (round === 0) out.subsFull = subs(tick);
  for (const r of rows) { r.label.remove(); r.btn.remove(); }
  await step(); await step();
}
out.hydrated = log.filter((x) => x[0] === 'h').length;
out.disposed = log.filter((x) => x[0] === 'd').length;
out.intervals = intervals;
out.subs = subs(tick);
''', minify: minify);
          expect(out['subsFull'], 1000);
          expect(out['hydrated'], 3000);
          expect(out['disposed'], 3000);
          expect(out['intervals'], 0);
          expect(out['subs'], 0);
        });

        test('a state without dispose costs nothing: no observer, and its '
            'elements leaving change nothing', () async {
          final out = await _run(
            r'''
thor.def('S', ($) => {
  const n = $.state('n', 0);
  return { count: () => `${n.value}`, inc: () => { n.value++; } };
});
''',
            r'''
const label = new El({ 'data-tt': 'S.count' });
const btn = new El({ 'data-t-on': 'click:S.inc' });
fire(btn, 'click');
label.remove();
await step();
fire(btn, 'click');
out.observers = observers;
out.count = thor.use('S').count();
''',
            minify: minify,
          );
          expect(out['observers'], 0);
          expect(out['count'], '2');
        });
      },
    );
  }
}
