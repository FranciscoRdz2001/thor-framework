@TestOn('vm')
library;

// The lite runtime's core under node with a tiny fake DOM (no jsdom): what
// an effect that throws, a computed in error, a cycle, hostile ids, a
// broken `#thor-state` and events that bubble do to the engine. Each test
// runs on the runtime as written and minified.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/src/lite_bundle.dart';

final _hasNode = Process.runSync('node', ['--version']).exitCode == 0;

// A page reduced to what the runtime touches: `root` keeps the delegated
// listeners (`fire` dispatches by hand, no bubbling: the runtime's
// delegation does it), elements know their parent, `closest` only matches
// `[attr]` selectors, and `#thor-state` is whatever `stateText` holds.
const _page = r'''
globalThis.window = globalThis;
const listeners = {};
let stateText = null;
let scanEls = []; // what the first activation finds in the page
const root = {
  addEventListener(t, f) { listeners[t] = f; },
  querySelectorAll: () => scanEls,
};
globalThis.document = {
  documentElement: root, cookie: '', querySelectorAll: () => [],
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
  }
  get parentElement() { return this.parent; }
  getAttribute(n) { return n in this.a ? this.a[n] : null; }
  hasAttribute(n) { return n in this.a; }
  closest(sel) {
    const names = sel.split(',').map((s) => s.slice(1, -1));
    for (let e = this; e; e = e.parent) if (names.some((n) => e.hasAttribute(n))) return e;
    return null;
  }
}
const fire = (target, type, extra = {}) => {
  const e = { type, target, cancelBubble: false, defaultPrevented: false, preventDefault() { this.defaultPrevented = true; }, stopPropagation() { this.cancelBubble = true; }, ...extra };
  listeners[type](e);
  return e;
};
const step = () => new Promise((r) => setTimeout(r, 0));
const proto = () => Object.getOwnPropertyNames(Object.prototype).sort().join();
''';

Map<String, Object?> _run(
  String stateJs,
  String script, {
  required bool minify,
  List<String> parts = const [],
}) {
  final runtime = File('lib/lite/runtime.js').readAsStringSync();
  final bundle = liteBundle(
    runtime: runtime,
    parts: {
      for (final p in parts) p: File('lib/lite/parts/$p.js').readAsStringSync(),
    },
    stateJs: stateJs,
    minify: minify,
  );
  final js =
      '$_page$bundle\n(async () => {\nawait step();\nconst out = {};\n'
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
        test(
          'a plain click on a link with a handler runs it, no navigation',
          () {
            final out = _run(
              r'''
thor.def('S', ($) => {
  const n = $.state('n', 0);
  return { count: () => n.value, inc: () => { n.value++; } };
});
''',
              r'''
const S = thor.use('S');
const link = () => new El({ 'data-t-on': 'click:S.inc', href: '/more?page=2' }, null, 'A');
out.plain = fire(link(), 'click', { button: 0 }).defaultPrevented;
out.ran = S.count();
out.ctrl = fire(link(), 'click', { button: 0, ctrlKey: true }).defaultPrevented;
out.middle = fire(link(), 'click', { button: 1 }).defaultPrevented;
const blank = new El({ 'data-t-on': 'click:S.inc', href: '/x', target: '_blank' }, null, 'A');
out.blank = fire(blank, 'click', { button: 0 }).defaultPrevented;
out.ranAll = S.count();
''',
              minify: minify,
            );
            expect(out['plain'], isTrue);
            expect(out['ran'], 1);
            expect(out['ctrl'], isFalse);
            expect(out['middle'], isFalse);
            expect(out['blank'], isFalse);
            // A modified click still runs the handler, as before.
            expect(out['ranAll'], 4);
          },
        );

        test('clearing a field on Enter refreshes its maxLength counter', () {
          final out = _run(
            r'''
thor.def('S', ($) => ({ send: () => {} }));
''',
            r'''
const counter = new El({}, null, 'SPAN');
counter.textContent = '5/200';
const own = new El({}, null, 'SPAN');
own.textContent = 'custom';
const getById = document.getElementById;
document.getElementById = (id) => (id === 'f-cnt' ? counter : id === 'g-cnt' ? own : getById(id));
const oninput = 'document.getElementById(this.id+"-cnt").textContent=0';
const field = new El({ id: 'f', maxlength: '200', oninput, 'data-t-clear': '', 'data-t-on': 'enter:S.send' }, null, 'INPUT');
field.id = 'f';
field.maxLength = 200;
field.value = 'hello';
fire(field, 'keydown', { key: 'Enter' });
out.value = field.value;
out.counter = counter.textContent;
// A counterText of the app (no live handler) is left alone.
const other = new El({ id: 'g', maxlength: '200', 'data-t-clear': '', 'data-t-on': 'enter:S.send' }, null, 'INPUT');
other.id = 'g';
other.maxLength = 200;
other.value = 'hi';
fire(other, 'keydown', { key: 'Enter' });
out.own = own.textContent;
''',
            minify: minify,
          );
          expect(out['value'], '');
          expect(out['counter'], '0/200');
          expect(out['own'], 'custom');
        });

        test('an effect that throws does not freeze the engine', () {
          final out = _run(
            r'''
thor.def('S', ($) => {
  const n = $.state('n', 0);
  return { count: () => n.value, inc: () => { n.value++; } };
});
''',
            r'''
const S = thor.use('S'), ran = [];
let bad = true;
thor.effect(() => { ran.push('a' + S.count()); if (bad && S.count() === 1) throw Error('boom'); });
thor.effect(() => { ran.push('b' + S.count()); });
const btn = new El({ 'data-t-on': 'click:S.inc' });
try { fire(btn, 'click'); } catch (e) { out.err = e.message; }
out.first = ran.join();
bad = false;
fire(btn, 'click');
out.second = ran.join();
// a batch still coalesces after the failure
const n = thor.signal(0), seen = [];
thor.effect(() => seen.push(n.value));
thor.batch(() => { n.value = 1; n.value = 2; });
out.batch = seen.join();
''',
            minify: minify,
          );
          // The error is not swallowed (it reaches the event handler's caller),
          // and the effect after the failing one ran in the same batch.
          expect(out['err'], 'boom');
          expect(out['first'], 'a0,b0,a1,b1');
          // The next click updates both.
          expect(out['second'], 'a0,b0,a1,b1,a2,b2');
          expect(out['batch'], '0,2');
        });

        test('a computed in error throws on every read and recomputes', () {
          final out = _run('', r'''
const src = thor.signal(0);
let calls = 0;
const c = thor.computed(() => { calls++; if (src.value === 1) throw Error('bad'); return src.value * 10; });
const read = () => { try { return c.value; } catch (e) { return 'E:' + e.message; } };
out.ok = read();
src.value = 1;
out.first = read();
out.second = read(); // used to return the stale value silently
out.peek = (() => { try { c.peek(); return 'no'; } catch (e) { return e.message; } })();
out.calls = calls; // the failure is cached: read three times, computed twice
src.value = 2;
out.fixed = read();
// an effect that read it in error runs again when the source recovers
const seen = [];
src.value = 1;
thor.effect(() => { try { seen.push(c.value); } catch (e) { seen.push('E'); } });
src.value = 3;
out.effect = seen.join();
''', minify: minify);
          expect(out['ok'], 0);
          expect(out['first'], 'E:bad');
          expect(out['second'], 'E:bad');
          expect(out['peek'], 'bad');
          expect(out['calls'], 2);
          expect(out['fixed'], 20);
          expect(out['effect'], 'E,30');
        });

        // `m.value[k]` of a map state is `m.key(k)`.
        test('a key read re-runs only when that key changes', () {
          final out = _run(
            '',
            r'''
const m = thor.signal(new Map([['A', '1'], ['B', '2']]));
const runs = { a: 0, b: 0, c: 0, sum: 0, all: 0 };
const seen = {};
thor.effect(() => { runs.a++; seen.a = m.key('A') ?? null; });
thor.effect(() => { runs.b++; seen.b = m.key('B') ?? null; });
thor.effect(() => { runs.c++; seen.c = m.key('C') ?? null; }); // absent
thor.effect(() => { runs.sum++; seen.sum = +(m.key('A') ?? 0) + +(m.key('B') ?? 0); });
thor.effect(() => { runs.all++; seen.all = m.value.size; }); // the whole map
const set = (k, v) => { const n = new Map(m.peek()); v == null ? n.delete(k) : n.set(k, v); m.value = n; };
const snap = () => Object.values(runs).join();
out.start = snap();
set('A', '5');
out.a = snap();
out.sumA = seen.sum;
set('C', '7');
out.c = snap();
out.seenC = seen.c;
set('B', null);
out.b = snap();
out.seenB = seen.b;
m.value = new Map(m.peek()); // a new map, the same entries
out.same = snap();
m.value = 3; // no longer a map: every key reader runs
out.notMap = snap();
''',
            minify: minify,
            parts: ['map_keys'],
          );
          // a, b, c, sum, all
          expect(out['start'], '1,1,1,1,1');
          expect(out['a'], '2,1,1,2,2');
          expect(out['sumA'], 7);
          expect(out['c'], '2,1,2,2,3');
          expect(out['seenC'], '7');
          expect(out['b'], '2,2,2,3,4');
          expect(out['seenB'], null);
          expect(out['same'], '2,2,2,3,5');
          expect(out['notMap'], '3,3,3,4,6');
        });

        test(
          'cycles raise thor: cycle instead of hanging or returning undefined',
          () {
            final out = _run('', r'''
const msg = (f) => { try { f(); return 'no error'; } catch (e) { return e.message; } };
// effect that writes what it reads (self-limited so a missing cap fails, not hangs)
const s = thor.signal(0);
let runs = 0;
out.effect = msg(() => thor.effect(() => {
  if (++runs > 5000) throw Error('runaway');
  s.value = s.value + 1;
}));
out.runs = runs < 5000; // stopped by the cap, not by the guard
// two effects feeding each other
const a = thor.signal(0), b = thor.signal(0);
let n = 0;
thor.effect(() => { if (++n > 5000) throw Error('runaway'); b.value = a.value + 1; });
out.pair = msg(() => thor.effect(() => { if (++n > 5000) throw Error('runaway'); a.value = b.value + 1; }));
// the engine still works afterwards
const t = thor.signal(0), seen = [];
thor.effect(() => seen.push(t.value));
t.value = 1;
out.after = seen.join();
// a computed that reads itself, and two that read each other
const self = thor.computed(() => self.value + 1);
out.self = msg(() => self.value);
out.self2 = msg(() => self.value); // and again: the error is kept
const x = thor.computed(() => y.value), y = thor.computed(() => x.value);
out.mutual = msg(() => x.value);
// a wide but legitimate flush (5000 effects on one signal) is not a cycle
const w = thor.signal(0);
let hits = 0;
for (let i = 0; i < 5000; i++) thor.effect(() => { w.value; hits++; });
w.value = 1;
out.wide = hits;
''', minify: minify);
            expect(out['effect'], startsWith('thor: cycle'));
            expect(out['runs'], isTrue);
            expect(out['pair'], startsWith('thor: cycle'));
            expect(out['after'], '0,1');
            expect(out['self'], startsWith('thor: cycle'));
            expect(out['self2'], startsWith('thor: cycle'));
            expect(out['mutual'], startsWith('thor: cycle'));
            expect(out['wide'], 10000);
          },
        );

        // THOR-S037 at boot: the group starts at the state the server drew
        // when the client's value is one the element ships as a patch.
        test('a state met at a value the server did not draw starts at the '
            'one it drew', () {
          final out = _run(
            r'''
thor.def('Counter', ($) => {
  const n = $.state('n', 0); // the browser's default, until the real value arrives
  return { phase: () => n.value, set: (v) => { n.value = v; }, click: () => {} };
});
''',
            r'''
const misses = [];
thor.miss = (el, n) => misses.push(n);
// The server drew state 3; 0, 1 and 2 are patches of the live element.
class Live extends El {
  get attributes() { return Object.keys(this.a).map((name) => ({ name, value: this.a[name] })); }
  get nextElementSibling() { return null; }
  querySelectorAll() { return []; }
  querySelector() { return null; }
  matches() { return false; }
  cloneNode() { return this; }
  setAttribute(n, v) { this.a[n] = v; }
  removeAttribute(n) { delete this.a[n]; }
}
const el = new Live({ 'data-tv': 'Counter.phase', 'data-tp-0': '|class|=a', 'data-tp-1': '|class|=b', 'data-tp-2': '|class|=c' });
scanEls = [el];
fire(new El({ 'data-t-on': 'click:Counter.click' }), 'click'); // activates Counter
thor.use('Counter').set(3);
await step();
out.misses = misses;
''',
            minify: minify,
          );
          expect(out['misses'], isEmpty);
        });

        test('hostile ids and arguments neither pollute nor throw', () {
          final out = _run(
            r'''
let got = -1;
thor.def('Counter', ($) => {
  const n = $.state('n', 0);
  return { count: () => `${n.value}`, inc: () => { n.value++; }, take: (a) => { got = a.length; } };
});
''',
            r'''
const base = proto();
const label = new El({ 'data-tt': 'Counter.count' });
scanEls = [
  label,
  new El({ 'data-tt': 'Counter.__proto__' }), new El({ 'data-tt': 'Counter.constructor' }),
  new El({ 'data-tv': 'Counter.__proto__' }), new El({ 'data-tv': 'Counter.toString' }),
  new El({ 'data-tl': 'Counter.__proto__', 'data-tlk': 'Counter.__proto__' }),
];
const errors = [];
const click = (spec, extra = {}) => {
  try { fire(new El({ 'data-t-on': `click:${spec}`, ...extra }), 'click'); } catch (e) { errors.push(`${spec.slice(0, 30)}: ${e.message}`); }
};
click('Counter.inc'); // activates Counter (scans the hostile ids above)
for (const id of ['__proto__.x', 'constructor.x', 'toString.x', 'Counter.__proto__', 'Counter.constructor',
  'Counter.toString', 'Counter.hasOwnProperty', 'Counter.', '.inc', 'Counter#.inc.', 'a b.inc', '__proto__',
  `Counter.${'a'.repeat(1e6)}`, `${'a'.repeat(1e6)}.inc`]) click(id);
click('Counter#__proto__.inc');
click('Counter.take', { 'data-tx': 'x'.repeat(1e6) });
out.errors = errors;
out.polluted = proto() !== base || ({}).on !== undefined || ({}).x !== undefined || ({}).p !== undefined;
out.got = got;
out.use = [thor.use('__proto__'), thor.use('constructor'), thor.use('toString')].map(String);
out.polluted2 = proto() !== base || ({}).on !== undefined;
// normal states keep working
click('Counter.inc');
out.label = label.textContent;
''',
            minify: minify,
          );
          expect(out['errors'], isEmpty);
          expect(out['polluted'], isFalse);
          expect(out['got'], 1000000);
          expect(out['use'], ['undefined', 'undefined', 'undefined']);
          expect(out['polluted2'], isFalse);
          // the two Counter.inc (Counter#__proto__ is another instance)
          expect(out['label'], '2');
        });

        test('a malformed #thor-state leaves the page interactive', () {
          const state = r'''
thor.def('S', ($) => {
  const n = $.state('n', 7);
  return { count: () => `${n.value}`, inc: () => { n.value++; } };
});
''';
          // Broken JSON, and JSON that is not an object.
          for (final text in ['{"S.n": 3', '', 'null', '5', '"s"']) {
            final out = _run(state, '''
stateText = ${jsonEncode(text)};
const label = new El({ 'data-tt': 'S.count' });
scanEls = [label];
const btn = new El({ 'data-t-on': 'click:S.inc' });
try { fire(btn, 'click'); out.err = null; } catch (e) { out.err = e.message; }
out.label = label.textContent;
fire(btn, 'click');
out.label2 = label.textContent;
''', minify: minify);
            expect(out['err'], isNull, reason: text);
            expect(
              out['label'],
              '8',
              reason: text,
            ); // the code's 7, then the click
            expect(out['label2'], '9', reason: text);
          }
          // A good one still restores its fields.
          final ok = _run(state, '''
stateText = '{"S.n": 3}';
const label = new El({ 'data-tt': 'S.count' });
scanEls = [label];
fire(new El({ 'data-t-on': 'click:S.inc' }), 'click');
out.label = label.textContent;
''', minify: minify);
          expect(ok['label'], '4');
        });

        // A `String?` method (a field's bound error message) that returns
        // null is no text, as the server draws it: never the word "null".
        test('a bound text that returns null is empty', () {
          final out = _run(
            r'''
thor.def('S', ($) => {
  const bad = $.state('bad', false);
  return { error: () => (bad.value ? 'Use dd.mm.yyyy' : null), flip: () => { bad.value = !bad.value; } };
});
''',
            '''
const label = new El({ 'data-tt': 'S.error' });
scanEls = [label];
const btn = new El({ 'data-t-on': 'click:S.flip' });
fire(btn, 'click');
out.wrong = label.textContent;
fire(btn, 'click');
out.fixed = label.textContent;
''',
            minify: minify,
          );
          expect(out['wrong'], 'Use dd.mm.yyyy');
          expect(out['fixed'], '');
        });

        test('a click on a checkbox that handles change is not run twice', () {
          final out = _run(
            r'''
const log = [];
thor.def('S', ($) => ({
  row: (v) => { log.push('row:' + v); },
  box: (v) => { log.push('box:' + v); },
}));
''',
            r'''
const row = new El({ 'data-t-on': 'click:S.row', 'data-tx': 'true' });
const box = new El({ 'data-t-on': 'change:S.box' }, row, 'INPUT');
box.type = 'checkbox'; box.checked = true;
const plain = new El({}, row, 'INPUT'); plain.type = 'checkbox';
const flush = (label) => { out[label] = log.splice(0).join(); };
fire(box, 'click'); flush('click'); // the change event runs the box's handler
fire(box, 'change'); flush('change');
fire(plain, 'click'); flush('plain'); // no change handler: the row's click stays
fire(row, 'click'); flush('row');
''',
            minify: minify,
          );
          expect(out['click'], '');
          expect(out['change'], 'box:true');
          expect(out['plain'], 'row:true');
          expect(out['row'], 'row:true');
        });

        test(
          'Enter and Space click a focusable row or cell, not a plain one',
          () {
            final out = _run(
              r'''
const log = [];
thor.def('S', ($) => ({ row: (v) => { log.push('row:' + v); } }));
''',
              r'''
const mk = (attrs) => {
  const el = new El({ 'data-t-on': 'click:S.row', 'data-tx': 'true', ...attrs });
  el.click = () => fire(el, 'click');
  return el;
};
const flush = (label) => { out[label] = log.splice(0).join(); };
fire(mk({ role: 'row', tabindex: '0' }), 'keydown', { key: 'Enter' }); flush('enter');
fire(mk({ role: 'row', tabindex: '0' }), 'keydown', { key: ' ' }); flush('space');
fire(mk({ role: 'row' }), 'keydown', { key: ' ' }); flush('plain');
fire(mk({ role: 'cell' }), 'keydown', { key: ' ' }); flush('cell');
fire(mk({ role: 'cell', tabindex: '0' }), 'keydown', { key: 'Enter' }); flush('focusCell');
''',
              minify: minify,
            );
            expect(out['enter'], 'row:true');
            expect(out['space'], 'row:true');
            expect(out['plain'], '');
            expect(out['cell'], '');
            expect(out['focusCell'], 'row:true');
          },
        );

        test('an event bubbles to the next ancestor that handles its type', () {
          final out = _run(
            r'''
const log = [];
thor.def('S', ($) => ({
  typed: (v) => { log.push('typed:' + v); },
  clicked: (v) => { log.push('clicked:' + v); },
  outer: () => { log.push('outer'); },
  moved: () => { log.push('moved'); },
}));
''',
            r'''
const outer = new El({ 'data-t-on': 'click:S.outer;transitionend:S.moved' });
const parent = new El({ 'data-t-on': 'click:S.clicked;transitionend:S.moved', 'data-tx': 'P' }, outer);
const child = new El({ 'data-t-on': 'input:S.typed' }, parent, 'INPUT');
child.value = 'v';
const both = new El({ 'data-t-on': 'click:S.typed;input:S.typed' }, parent);
const flush = (label) => { out[label] = log.splice(0).join(); };
fire(child, 'click'); flush('click'); // child has no click: the parent gets it, once
fire(child, 'input'); flush('input'); // the child handles input: innermost wins
fire(both, 'click'); flush('inner'); // both handle click: the innermost only
fire(child, 'click', { cancelBubble: true }); flush('stopped'); // stopPropagation is respected
fire(child, 'transitionend'); flush('own'); // transitions never bubble
fire(new El({ 'data-t-on': 'input:S.typed' }, null, 'INPUT'), 'click'); flush('none'); // nobody: nothing
fire(new El({ 'data-t-on': 'input:S.typed' }, new El({ 'data-t-on': ':::;click' })), 'click'); flush('junk');
''',
            minify: minify,
          );
          expect(out['click'], 'clicked:P');
          expect(out['input'], 'typed:v');
          expect(out['inner'], 'typed:null');
          expect(out['stopped'], '');
          expect(out['own'], '');
          expect(out['none'], '');
          expect(out['junk'], '');
        });

        test(
          'onEnd runs once per change, not once per transitioned property',
          () {
            final out = _run(
              r'''
let n = 0;
thor.def('S', ($) => ({ moved: () => { n++; } }));
globalThis.count = () => n;
''',
              r'''
const el = new El({ 'data-t-on': 'transitionend:S.moved' });
// Four longhands end in the same task (padding on every side).
for (let i = 0; i < 4; i++) fire(el, 'transitionend');
out.together = count();
await step();
// Staggered: the first ends while another still runs; only the last counts.
let running = true;
el.getAnimations = () => [{ transitionProperty: 'height', playState: running ? 'running' : 'finished' }];
fire(el, 'transitionend');
out.waiting = count();
running = false;
fire(el, 'transitionend');
out.last = count();
''',
              minify: minify,
            );
            expect(out['together'], 1);
            expect(out['waiting'], 1);
            expect(out['last'], 2);
          },
        );

        test('a segmented button hands every checked value, U+001F apart', () {
          final out = _run(
            r'''
thor.def('S', ($) => ({ got: [], set: (v) => { thor.use('S').got.push(v); } }));
''',
            r'''
const mk = (v, checked, set) => {
  const e = new El({ 'data-t-on': 'change:S.set', 'data-t-set': set }, null, 'INPUT');
  e.type = 'checkbox'; e.value = v; e.checked = checked;
  return e;
};
const a = mk('list', true, 'g1'), b = mk('grid', true, 'g1'), c = mk('table', false, 'g1');
const other = mk('x', true, 'g2');
document.querySelectorAll = (sel) => [a, b, c, other].filter((e) => e.checked);
fire(b, 'change');
c.checked = true;
fire(c, 'change');
out.got = thor.use('S').got;
''',
            minify: minify,
          );
          expect(out['got'], ['list\u001fgrid', 'list\u001fgrid\u001ftable']);
        });

        // Ignored ids are silent in release, warned in `thor dev`
        test('an ignored id warns only when thor.dev is set', () {
          final out = _run(
            r'''
thor.def('E', ($) => ({ inc: () => {} }));
''',
            r'''
const warns = [];
console.warn = (m) => warns.push(m);
const click = (id) => fire(new El({ 'data-t-on': `click:${id}` }), 'click');
click('a b.x'); click('E.nope');
out.release = warns.length;
thor.dev = 1;
click('a b.x'); click('E.nope'); click('E#a~b.inc');
out.dev = warns.length;
''',
            minify: minify,
          );
          expect(out['release'], 0);
          expect(out['dev'], 2); // the keyed id with a tilde is fine
        });
      },
    );
  }
}
