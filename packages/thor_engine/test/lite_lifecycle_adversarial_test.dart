@TestOn('vm')
library;

// Adversarial: the lifecycle of a lite state where the page is not
// polite. Same fake DOM as lite_lifecycle_test.dart, plus children, moves
// (out and in in one batch) and a count of the page-wide queries the runtime
// makes (a sweep must not cost a scan per state). Each test runs on the
// runtime as written and minified.
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
const ATTRS = ['data-tt', 'data-tv', 'data-tl', 'data-tf', 'data-tvf', 'data-t-on', 'data-tca', 'data-tcv', 'data-tfa', 'data-tks', 'data-tg', 'data-tdc', 'data-tsc', 'data-ttc', 'data-tfn'];
const calls = { q: 0 }; // full-page queries the runtime made
const live = () => all.filter((e) => e.isConnected);
const presence = (sel) => [...sel.matchAll(/\[([\w-]+)\]/g)].map((m) => m[1]);
const root = {
  innerHTML: '',
  addEventListener(t, f) { listeners[t] = f; },
  querySelectorAll: (sel) => { calls.q++; const n = presence(sel); return live().filter((e) => n.some((a) => e.hasAttribute(a))); },
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
  querySelector: (sel) => { calls.q++; const m = matcher(sel); return live().find(m) || null; },
  getElementById: (id) => (id === 'thor-state' && stateText != null ? { textContent: stateText } : null),
  dispatchEvent() {}, createElement: () => ({}),
};
globalThis.CustomEvent = class {};
class El {
  constructor(attrs = {}, parent = null, tagName = 'DIV') {
    this.a = Object.assign(Object.create(null), attrs);
    this.parent = parent;
    this.tagName = tagName;
    this.kids = [];
    parent?.kids.push(this);
    this.textContent = '';
    this.nodeType = 1;
    all.push(this);
    const o = MutationObserver.last;
    if (o && !parent) queueMicrotask(() => o.cb([{ removedNodes: [], addedNodes: [this] }]));
  }
  get isConnected() { return this.off !== true && (!this.parent || this.parent.isConnected); }
  matches(sel) { return presence(sel).some((a) => this.hasAttribute(a)); }
  querySelectorAll(sel) {
    const n = presence(sel), out = [];
    const walk = (e) => { for (const k of e.kids) { if (n.some((a) => k.hasAttribute(a))) out.push(k); walk(k); } };
    walk(this);
    return out;
  }
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
    this.off = true;
    const o = MutationObserver.last;
    if (o) queueMicrotask(() => o.cb([{ removedNodes: [this], addedNodes: [] }]));
  }
}
// What a move does (insertBefore / moveBefore): out and in again, seen as one
// batch of records while the element stays in the page.
const move = (el) => {
  const o = MutationObserver.last;
  queueMicrotask(() => o.cb([{ removedNodes: [el], addedNodes: [] }, { removedNodes: [], addedNodes: [el] }]));
};
// A whole list going at once: the browser reports every removal of a task in
// one batch.
const removeMany = (els) => {
  for (const e of els) e.off = true;
  const o = MutationObserver.last;
  queueMicrotask(() => o.cb(els.map((e) => ({ removedNodes: [e], addedNodes: [] }))));
};
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

const _row = r'''
const log = [];
const tick = thor.signal(0);
thor.def('Row', ($) => {
  const n = $.state('n', 0);
  return {
    label: () => `${$.key}:${n.value}:${tick.value}`,
    inc: () => { n.value++; },
    $l: {
      h: () => { log.push(`h${$.key}`); },
      d: () => { log.push(`d${$.key}`); },
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
        test('a list of 300 live states removed at once costs a few scans of '
            'the page, not one per state', () async {
          final out = await _run(_row, r'''
const rows = [];
for (let i = 0; i < 300; i++) rows.push(rowEls(`k${i}`));
await step(); await step();
const before = calls.q;
removeMany(rows.flatMap((r) => [r.label, r.btn]));
await step(); await step();
out.scans = calls.q - before;
out.disposed = log.filter((x) => x[0] === 'd').length;
''', minify: minify);
          expect(out['disposed'], 300);
          expect(out['scans'], lessThanOrEqualTo(3));
        });

        test('3000 live states removed at once are swept in a few passes '
            '(no quadratic work)', () async {
          final out = await _run(_row, r'''
const rows = [];
for (let i = 0; i < 3000; i++) rows.push(rowEls(`k${i}`));
await step(); await step();
const before = calls.q;
const t = Date.now();
removeMany(rows.flatMap((r) => [r.label, r.btn]));
await step(); await step();
out.scans = calls.q - before;
out.ms = Date.now() - t;
out.disposed = log.filter((x) => x[0] === 'd').length;
''', minify: minify);
          expect(out['disposed'], 3000);
          expect(out['scans'], lessThanOrEqualTo(3));
          expect(out['ms'], lessThan(2000));
        });

        test('elements without any state attribute leaving (toasts, '
            'tooltips) cost no scan of the page', () async {
          final out = await _run(_row, r'''
for (let i = 0; i < 50; i++) rowEls(`k${i}`);
await step(); await step();
const before = calls.q;
for (let i = 0; i < 20; i++) { new El().remove(); await step(); }
out.scans = calls.q - before;
out.disposed = log.filter((x) => x[0] === 'd').length;
''', minify: minify);
          expect(out['scans'], 0);
          expect(out['disposed'], 0);
        });

        test('a state bound by a class or attribute binding (data-tca) '
            'outlives the text that left', () async {
          final out = await _run(
            r'''
const log = [];
thor.def('Theme', ($) => ({
  label: () => 'x', cls: () => 'dark',
  $l: { d: () => log.push('dTheme') },
}));
''',
            r'''
const panel = new El({ 'data-tt': 'Theme.label' });
const body = new El({ 'data-tca': 'class:Theme.cls' });
thor.use('Theme');
panel.remove();
await step(); await step();
out.afterText = log.join();
body.remove();
await step(); await step();
out.afterBody = log.join();
''',
            minify: minify,
          );
          expect(out['afterText'], '');
          expect(out['afterBody'], 'dTheme');
        });

        test('states that use each other in a cycle are disposed (a leaving '
            'page and pagehide)', () async {
          const defs = r'''
const log = [];
thor.def('A', ($) => { $.use('B'); return { label: () => 'a', $l: { d: () => log.push('dA') } }; }, { uses: ['B'] });
thor.def('B', ($) => { $.use('A'); return { label: () => 'b', $l: { d: () => log.push('dB') } }; }, { uses: ['A'] });
''';
          final out = await _run(defs, r'''
const a = new El({ 'data-tt': 'A.label' }), b = new El({ 'data-tt': 'B.label' });
thor.use('A');
a.remove(); b.remove();
await step(); await step();
out.removed = log.slice().sort().join();
''', minify: minify);
          expect(out['removed'], 'dA,dB');
          final end = await _run(defs, r'''
new El({ 'data-tt': 'A.label' }); new El({ 'data-tt': 'B.label' });
thor.use('A');
pagehide(false);
out.unloaded = log.slice().sort().join();
''', minify: minify);
          expect(end['unloaded'], 'dA,dB');
        });

        test('pagehide disposes a state with dispose even if a state without '
            'dispose uses it', () async {
          final out = await _run(
            r'''
const log = [];
thor.def('Inner', ($) => ({ label: () => 'i', $l: { d: () => log.push('dInner') } }));
thor.def('Lazy', ($) => { $.use('Inner'); return { label: () => 'l' }; }, { uses: ['Inner'] });
''',
            r'''
new El({ 'data-tt': 'Inner.label' }); new El({ 'data-tt': 'Lazy.label' });
thor.use('Lazy');
pagehide(false);
out.log = log.join();
''',
            minify: minify,
          );
          expect(out['log'], 'dInner');
        });

        test('a state a staying state uses waits, and goes when its user '
            'does, even if its own elements left long before', () async {
          final out = await _run(
            r'''
const log = [];
thor.def('Inner', ($) => ({ label: () => 'i', $l: { d: () => log.push('dInner') } }));
thor.def('Outer', ($) => { $.use('Inner'); return { label: () => 'o', $l: { d: () => log.push('dOuter') } }; }, { uses: ['Inner'] });
''',
            r'''
const i = new El({ 'data-tt': 'Inner.label' }), o = new El({ 'data-tt': 'Outer.label' });
thor.use('Outer');
i.remove();
await step(); await step();
out.waiting = log.join();
// an unrelated removal must not dispose it while Outer lives
new El({ 'data-tt': 'Other.label' }).remove();
await step(); await step();
out.stillWaiting = log.join();
o.remove();
await step(); await step();
out.both = log.join();
''',
            minify: minify,
          );
          expect(out['waiting'], '');
          expect(out['stillWaiting'], '');
          expect(out['both'], 'dOuter,dInner');
        });

        test('a move (out and in within one batch) is not a disposal, even '
            'with the state on both elements', () async {
          final out = await _run(_row, r'''
const a = rowEls('a');
await step(); await step();
move(a.label); move(a.btn);
await step(); await step();
out.moved = log.join();
// a real removal afterwards still disposes
a.label.remove(); a.btn.remove();
await step(); await step();
out.gone = log.join();
''', minify: minify);
          expect(out['moved'], 'ha');
          expect(out['gone'], 'ha,da');
        });

        test('an ancestor removed with the state elements inside it disposes '
            'the state once', () async {
          final out = await _run(_row, r'''
const box = new El({});
new El({ 'data-tt': 'Row#x.label' }, box);
new El({ 'data-t-on': 'click:Row#x.inc' }, box);
await step(); await step();
out.hydrated = log.join();
box.remove();
await step(); await step();
out.log = log.join();
''', minify: minify);
          expect(out['hydrated'], 'hx');
          expect(out['log'], 'hx,dx');
        });

        test('an async onHydrated finishing after dispose writes a signal '
            'without throwing, painting or resurrecting', () async {
          final out = await _run(
            r'''
const log = [];
thor.def('T', ($) => {
  const n = $.state('n', 0);
  return {
    label: () => `${n.value}`,
    $l: {
      h: async () => { await new Promise((r) => setTimeout(r, 40)); n.value = 9; log.push('late'); },
      d: () => log.push('d'),
    },
  };
}, { idle: true });
''',
            r'''
const el = new El({ 'data-tt': 'T.label' });
await step(); await step();
el.remove();
await step(); await step();
await new Promise((r) => setTimeout(r, 80));
out.log = log.join();
out.text = el.textContent;
out.errors = errors.slice();
''',
            minify: minify,
          );
          expect(out['log'], 'd,late');
          expect(out['text'], '0');
          expect(out['errors'], isEmpty);
        });

        test('a row that removes itself in its own click handler: the '
            'handler finishes, then the state is disposed once', () async {
          final out = await _run(
            r'''
const log = [];
globalThis.me = null;
thor.def('R', ($) => {
  const n = $.state('n', 0);
  return {
    label: () => `${n.value}`,
    del: () => { log.push('start'); me.remove(); n.value++; log.push('end'); },
    $l: { d: () => log.push('d') },
  };
});
''',
            r'''
const label = new El({ 'data-tt': 'R.label' });
me = new El({ 'data-t-on': 'click:R.del' });
fire(me, 'click');
await step(); await step();
out.log = log.join();
out.errors = errors.slice();
''',
            minify: minify,
          );
          expect(out['log'], 'start,end');
          // label is still in the page: the state lives (only the button left)
          expect(out['errors'], isEmpty);
          final gone = await _run(
            r'''
const log = [];
globalThis.me = null;
thor.def('R', ($) => {
  const n = $.state('n', 0);
  return {
    label: () => `${n.value}`,
    del: () => { log.push('start'); me.remove(); n.value++; log.push('end'); },
    $l: { d: () => log.push('d') },
  };
});
''',
            r'''
me = new El({ 'data-t-on': 'click:R.del' });
fire(me, 'click');
await step(); await step();
out.log = log.join();
out.errors = errors.slice();
''',
            minify: minify,
          );
          expect(gone['log'], 'start,end,d');
          expect(gone['errors'], isEmpty);
        });

        test(
          'an onHydrated that removes its own element: h then d, balanced',
          () async {
            final out = await _run(
              r'''
const log = [];
globalThis.el = null;
thor.def('S', ($) => ({
  label: () => 's',
  $l: { h: () => { log.push('h'); el.remove(); }, d: () => log.push('d') },
}), { idle: true });
''',
              r'''
el = new El({ 'data-tt': 'S.label' });
await step(); await step(); await step();
out.log = log.join();
out.errors = errors.slice();
''',
              minify: minify,
            );
            // (the idle wake may make one more, balanced instance: an unkeyed
            // class with no element wakes by name)
            expect(out['log'], startsWith('h,d'));
            final log = out['log'] as String;
            expect('h'.allMatches(log).length, 'd'.allMatches(log).length);
            expect(out['errors'], isEmpty);
          },
        );

        test('an unkeyed state with onHydrated whose element leaves and '
            'comes back later wakes again', () async {
          final out = await _run(
            r'''
const log = [];
thor.def('Clock', ($) => {
  const t = $.state('t', 'now');
  return { time: () => t.value, $l: { h: () => log.push('h'), d: () => log.push('d') } };
}, { idle: true });
''',
            r'''
const c = new El({ 'data-tt': 'Clock.time' });
await step(); await step();
c.remove();
await step(); await step();
out.left = log.join();
const back = new El({ 'data-tt': 'Clock.time' });
await step(); await step();
out.back = log.join();
out.text = back.textContent;
''',
            minify: minify,
          );
          expect(out['left'], 'h,d');
          expect(out['back'], 'h,d,h');
          expect(out['text'], 'now');
        });

        test('pagehide (not persisted) and the page shown again: the next '
            'event builds a fresh instance and nothing throws', () async {
          final out = await _run(_row, r'''
const a = rowEls('a');
await step(); await step();
pagehide(false);
out.unloaded = log.join();
fire(a.btn, 'click'); fire(a.btn, 'click');
await step();
out.again = log.join();
out.label = a.label.textContent;
pagehide(false);
out.final = log.join();
out.errors = errors.slice();
''', minify: minify);
          expect(out['unloaded'], 'ha,da');
          expect(out['again'], 'ha,da,ha');
          expect(out['label'], 'a:2:0');
          expect(out['final'], 'ha,da,ha,da');
          expect(out['errors'], isEmpty);
        });

        test('50 states with onHydrated all wake at idle, once each, in the '
            'order they were defined', () async {
          final defs = StringBuffer('const log = [];\n');
          for (var i = 0; i < 50; i++) {
            defs.writeln(
              "thor.def('S$i', () => ({ x: () => 1, \$l: { h: () => log.push($i) } }), { idle: true });",
            );
          }
          final out = await _run(defs.toString(), r'''
await step(); await step(); await step();
out.log = log.join();
''', minify: minify);
          expect(out['log'], [for (var i = 0; i < 50; i++) i].join(','));
        });
      },
    );
  }
}
