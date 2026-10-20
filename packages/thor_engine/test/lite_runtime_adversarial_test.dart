@TestOn('vm')
library;

// Adversarial tests for the lite runtime: the same node + fake DOM harness as
// lite_runtime_test.dart, aimed at breaking it (errors in effects and
// computeds, cycles, state members and ids, a broken #thor-state, event
// delegation).
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
  const e = { type, target, cancelBubble: false, preventDefault() {}, stopPropagation() { this.cancelBubble = true; }, ...extra };
  listeners[type](e);
  return e;
};
const step = () => new Promise((r) => setTimeout(r, 0));
const proto = () => Object.getOwnPropertyNames(Object.prototype).sort().join();
''';

const _helpers = r'''
const msg = (f) => { try { f(); return 'no error'; } catch (e) { return e === null ? 'null' : e === undefined ? 'undefined' : (e.message ?? String(e)); } };
''';

Map<String, Object?> _run(
  String stateJs,
  String script, {
  required bool minify,
}) {
  final runtime = File('lib/lite/runtime.js').readAsStringSync();
  final bundle = liteBundle(
    runtime: runtime,
    parts: const {},
    stateJs: stateJs,
    minify: minify,
  );
  final js =
      '$_page$bundle\n(async () => {\nawait step();\nconst out = {};\n'
      '$script\nconsole.log(JSON.stringify(out));\n})();';
  final dir = Directory.systemTemp.createTempSync('thor_adv');
  final file = File('${dir.path}/t.js')..writeAsStringSync(js);
  final r = Process.runSync('node', [file.path]);
  dir.deleteSync(recursive: true);
  if (r.exitCode != 0) fail('node failed:\n${r.stderr}');
  return jsonDecode((r.stdout as String).trim()) as Map<String, Object?>;
}

void main() {
  for (final minify in [false, true]) {
    group(minify ? 'minified' : 'as written', skip: _hasNode ? false : 'needs node', () {
      void attack(
        String name,
        String stateJs,
        String script,
        void Function(Map<String, Object?> out) check,
      ) {
        test(
          name,
          () => check(_run(stateJs, _helpers + script, minify: minify)),
        );
      }

      const counter = r"""
thor.def('S', ($) => {
  const n = $.state('n', 0);
  return { count: () => `${n.value}`, inc: () => { n.value++; } };
});
""";

      // ---------- errors in effects
      attack(
        'two effects throw in one batch, all run, the first error surfaces',
        '',
        r'''
const s = thor.signal(0), ran = [];
thor.effect(() => { s.value; ran.push('a'); if (s.value === 1) throw Error('first'); });
thor.effect(() => { s.value; ran.push('b'); if (s.value === 1) throw Error('second'); });
thor.effect(() => { s.value; ran.push('c'); });
ran.length = 0;
out.err = msg(() => { s.value = 1; });
out.ran = ran.join();
ran.length = 0;
s.value = 2;
out.after = ran.join();
''',
        (out) {
          expect(out['err'], 'first');
          expect(out['ran'], 'a,b,c');
          expect(out['after'], 'a,b,c');
        },
      );

      attack(
        'throw of null / undefined / 0 in an effect still surfaces and does not freeze',
        '',
        r'''
const s = thor.signal(0), seen = [];
thor.effect(() => { if (s.value === 1) throw null; });
thor.effect(() => { if (s.value === 2) throw undefined; });
thor.effect(() => { if (s.value === 3) throw 0; });
thor.effect(() => seen.push(s.value));
const t = (v) => { try { s.value = v; return 'no error'; } catch (e) { return `threw ${String(e)}`; } };
out.a = t(1); out.b = t(2); out.c = t(3); out.d = t(4);
out.seen = seen.join();
''',
        (out) {
          expect(out['a'], 'threw null');
          expect(out['b'], 'threw undefined');
          expect(out['c'], 'threw 0');
          expect(out['d'], 'no error');
          expect(out['seen'], '0,1,2,3,4');
        },
      );

      attack(
        'an effect throwing inside nested batches surfaces once at the outermost and keeps depth',
        '',
        r'''
const s = thor.signal(0), seen = [];
thor.effect(() => { if (s.value === 1) throw Error('boom'); });
thor.effect(() => seen.push(s.value));
out.err = msg(() => thor.batch(() => { thor.batch(() => { s.value = 1; }); seen.push('inner-done'); s.value = 2; s.value = 1; }));
out.seen = seen.join();
// depth is back to zero: a plain write flushes at once
s.value = 5;
out.after = seen.join();
''',
        (out) {
          expect(out['err'], 'boom');
          expect(out['seen'], '0,inner-done,1');
          expect(out['after'], '0,inner-done,1,5');
        },
      );

      attack(
        'a handler that throws AND an effect that throws: which error surfaces',
        counter,
        r'''
thor.def('H', ($) => ({ go: () => { const s = thor.use('S'); s.inc(); throw Error('handler'); } }));
thor.effect(() => { if (thor.use('S').count() === '1') throw Error('effect'); });
out.err = msg(() => fire(new El({ 'data-t-on': 'click:H.go' }), 'click'));
''',
        (out) {
          // Preact rethrows the flush error from endBatch (the handler's is lost
          // there too); what matters is that one of them reaches the console.
          expect(out['err'], anyOf('handler', 'effect'));
        },
      );

      attack(
        'effect throwing at creation is retried by its sources and does not freeze others',
        '',
        r'''
const s = thor.signal(0), seen = [];
thor.effect(() => seen.push(s.value));
out.err = msg(() => thor.effect(() => { s.value; throw Error('creation'); }));
out.err2 = msg(() => { s.value = 1; }); // the broken effect reruns, throws again, the healthy one still ran
out.seen = seen.join();
''',
        (out) {
          expect(out['err'], 'creation');
          expect(out['err2'], 'creation');
          expect(out['seen'], '0,1');
        },
      );

      attack(
        'effect A throws after writing t, effect B (on t) and a downstream C still run in the same flush',
        '',
        r'''
const s = thor.signal(0), t = thor.signal(0), u = thor.signal(0), log = [];
thor.effect(() => { if (s.value > 0) { t.value = s.value; throw Error('A'); } });
thor.effect(() => { log.push('B' + t.value); u.value = t.value * 10; });
thor.effect(() => { log.push('C' + u.value); });
log.length = 0;
out.err = msg(() => { s.value = 1; });
out.log = log.join();
''',
        (out) {
          expect(out['err'], 'A');
          expect(out['log'], 'B1,C10');
        },
      );

      attack(
        'a text binding that throws at activation does not kill the rest of the state',
        r'''
thor.def('T', ($) => {
  const n = $.state('n', 0);
  return { bad: () => { if (n.value === 0) throw Error('bad text'); return 'x'; }, good: () => `${n.value}`, inc: () => { n.value++; }, rise: () => { n.value = 1; } };
});
''',
        r'''
const bad = new El({ 'data-tt': 'T.bad' }), good = new El({ 'data-tt': 'T.good' });
scanEls = [bad, good];
const btn = new El({ 'data-t-on': 'click:T.inc' });
out.err1 = msg(() => fire(btn, 'click'));
out.good1 = good.textContent;
out.err2 = msg(() => fire(btn, 'click'));
out.good2 = good.textContent;
''',
        (out) {
          // The click must not be lost, and the labels after the failing one
          // must still be wired (counter would be 1 then 2).
          expect(out['good1'], '1');
          expect(out['good2'], '2');
        },
      );

      // ---------- errored computeds
      attack(
        'a computed depending on an errored computed errors, then recovers',
        '',
        r'''
const s = thor.signal(0);
const a = thor.computed(() => { if (s.value === 1) throw Error('a'); return s.value; });
const b = thor.computed(() => a.value + 100);
const read = () => msg(() => b.value);
out.r0 = read();
s.value = 1;
out.r1 = read(); out.r2 = read();
s.value = 2;
out.r3 = read();
''',
        (out) {
          expect(out['r0'], 'no error');
          expect(out['r1'], 'a');
          expect(out['r2'], 'a');
          expect(out['r3'], 'no error');
        },
      );

      attack(
        'a computed thrown null/undefined is an error on every read, not a value',
        '',
        r'''
const s = thor.signal(0);
const c = thor.computed(() => { if (s.value === 1) throw null; return 'ok'; });
const d = thor.computed(() => { if (s.value === 1) throw undefined; return 'ok'; });
const r = (x) => { try { return x.value; } catch (e) { return `threw ${e}`; } };
out.a = r(c) + r(d);
s.value = 1;
out.b = r(c) + '|' + r(c) + '|' + r(d) + '|' + r(d);
s.value = 0;
out.c = r(c) + r(d);
''',
        (out) {
          expect(out['a'], 'okok');
          expect(
            out['b'],
            'threw null|threw null|threw undefined|threw undefined',
          );
          expect(out['c'], 'okok');
        },
      );

      attack(
        'an errored computed is cached across unrelated writes (no re-run per read)',
        '',
        r'''
const s = thor.signal(0), other = thor.signal(0);
let calls = 0;
const c = thor.computed(() => { calls++; if (s.value === 1) throw Error('bad'); return 1; });
c.value; s.value = 1;
msg(() => c.value); other.value = 1; msg(() => c.value); other.value = 2; msg(() => c.value);
out.calls = calls;
out.err = msg(() => c.value);
''',
        (out) {
          expect(out['calls'], 2);
          expect(out['err'], 'bad');
        },
      );

      attack(
        'an effect that reads an errored computed (uncaught) recovers when the source is fixed',
        '',
        r'''
const s = thor.signal(1), seen = [];
const c = thor.computed(() => { if (s.value === 1) throw Error('bad'); return s.value; });
out.create = msg(() => thor.effect(() => seen.push(c.value)));
out.fix = msg(() => { s.value = 2; });
out.seen = seen.join();
''',
        (out) {
          expect(out['create'], 'bad');
          expect(out['fix'], 'no error');
          expect(out['seen'], '2');
        },
      );

      attack(
        'a dynamic cycle between computeds errors, then recovers when the edge goes away',
        '',
        r'''
const flag = thor.signal(false);
const A = thor.computed(() => (flag.value ? B.value : 1));
const B = thor.computed(() => A.value + 1);
out.r0 = msg(() => B.value) + '/' + B.value;
flag.value = true;
out.r1 = msg(() => A.value);
out.r2 = msg(() => B.value);
flag.value = false;
out.r3 = msg(() => A.value) + '/' + msg(() => B.value);
out.v = [A.peek(), B.peek()].join();
''',
        (out) {
          expect(out['r0'], 'no error/2');
          expect(out['r1'], startsWith('thor: cycle'));
          expect(out['r2'], startsWith('thor: cycle'));
          expect(out['r3'], 'no error/no error');
          expect(out['v'], '1,2');
        },
      );

      attack(
        'a computed that throws before reading any signal keeps failing but does not corrupt the graph',
        '',
        r'''
const c = thor.computed(() => { throw Error('const'); });
out.a = msg(() => c.value); out.b = msg(() => c.value);
const s = thor.signal(0), seen = [];
thor.effect(() => { seen.push(s.value); });
s.value = 1;
out.seen = seen.join();
''',
        (out) {
          expect(out['a'], 'const');
          expect(out['b'], 'const');
          expect(out['seen'], '0,1');
        },
      );

      // ---------- cycles
      attack(
        'a cycle through a computed leaves the graph alive after the cap',
        '',
        r'''
const s = thor.signal(0), seen = [];
let stop = false;
const c = thor.computed(() => s.value * 2);
out.err = msg(() => thor.effect(() => { const v = c.value; seen.push(v); if (!stop) s.value = v + 1; }));
stop = true;
seen.length = 0;
out.write = msg(() => { s.value = 100; });
out.seen = seen.join();
''',
        (out) {
          expect(out['err'], startsWith('thor: cycle'));
          expect(out['seen'], '200');
        },
      );

      attack(
        'a cycle broken by the cap leaves an unrelated computed-fed effect alive',
        '',
        r'''
const s = thor.signal(0), other = thor.signal(0), seen = [];
const oc = thor.computed(() => other.value * 2);
thor.effect(() => seen.push(oc.value));
const a = thor.signal(0), b = thor.signal(0);
thor.effect(() => { b.value = a.value + 1; });
out.err = msg(() => thor.effect(() => { a.value = b.value + 1; }));
seen.length = 0;
other.value = 3;
out.seen = seen.join();
''',
        (out) {
          expect(out['err'], startsWith('thor: cycle'));
          expect(out['seen'], '6');
        },
      );

      attack(
        'an effect that converges after 90 rounds is not a cycle',
        '',
        r'''
const s = thor.signal(0);
out.err = msg(() => thor.effect(() => { if (s.value < 90) s.value = s.value + 1; }));
out.v = s.peek();
''',
        (out) {
          expect(out['err'], 'no error');
          expect(out['v'], 90);
        },
      );

      attack(
        'a legitimate chain of 150 dependent effects is not a cycle (cap is 1000 rounds)',
        '',
        r'''
const sig = Array.from({ length: 151 }, () => thor.signal(0));
for (let i = 0; i < 150; i++) thor.effect(() => { sig[i + 1].value = sig[i].value + 1; });
out.err = msg(() => { sig[0].value = 1; });
out.last = sig[150].peek();
''',
        (out) {
          expect(out['err'], 'no error');
          expect(out['last'], 151);
        },
      );

      attack(
        'a wide flush where 10k effects each write another signal is not a cycle',
        '',
        r'''
const N = 10000, src = thor.signal(0), mid = Array.from({ length: N }, () => thor.signal(0));
let hits = 0;
for (let i = 0; i < N; i++) thor.effect(() => { mid[i].value = src.value; });
for (let i = 0; i < N; i++) thor.effect(() => { mid[i].value; hits++; });
hits = 0;
out.err = msg(() => { src.value = 1; });
out.hits = hits;
''',
        (out) {
          expect(out['err'], 'no error');
          expect(out['hits'], 10000);
        },
      );

      attack(
        'a cycle whose effect also throws its own error: the engine stays alive and bounded',
        '',
        r'''
const a = thor.signal(0), b = thor.signal(0);
let runs = 0;
thor.effect(() => { b.value = a.value + 1; });
out.err = msg(() => thor.effect(() => { runs++; a.value = b.value + 1; if (runs > 3) throw Error('own'); }));
out.bounded = runs < 1000;
const t = thor.signal(0), seen = [];
thor.effect(() => seen.push(t.value));
t.value = 1;
out.after = seen.join();
''',
        (out) {
          expect(out['bounded'], isTrue);
          expect(out['err'], anyOf('own', startsWith('thor: cycle')));
          expect(out['after'], '0,1');
        },
      );

      attack(
        'after a cycle in a click handler the next click works',
        r'''
thor.def('C', ($) => {
  const a = $.state('a', 0), b = $.state('b', 0), mode = $.state('mode', 1);
  return { label: () => `${a.value}/${b.value}`, poke: () => { a.value++; }, calm: () => { mode.value = 0; a.value = 0; b.value = 0; },
    wire: () => { thor.effect(() => { if (mode.value) b.value = a.value + 1; }); thor.effect(() => { if (mode.value) a.value = b.value + 1; }); } };
});
''',
        r'''
const label = new El({ 'data-tt': 'C.label' });
scanEls = [label];
out.e1 = msg(() => fire(new El({ 'data-t-on': 'click:C.wire' }), 'click'));
out.e2 = msg(() => fire(new El({ 'data-t-on': 'click:C.calm' }), 'click'));
out.e3 = msg(() => fire(new El({ 'data-t-on': 'click:C.poke' }), 'click'));
out.label = label.textContent;
''',
        (out) {
          expect(out['e1'], startsWith('thor: cycle'));
          expect(out['e2'], 'no error');
          expect(out['e3'], 'no error');
          expect(out['label'], '1/0');
        },
      );

      attack(
        'a computed that reads itself only on a later run raises cycle and recovers',
        '',
        r'''
const flag = thor.signal(false);
const c = thor.computed(() => (flag.value ? c.value + 1 : 5));
out.a = c.value;
flag.value = true;
out.b = msg(() => c.value);
flag.value = false;
out.c = msg(() => c.value) + '/' + c.value;
''',
        (out) {
          expect(out['a'], 5);
          expect(out['b'], startsWith('thor: cycle'));
          expect(out['c'], 'no error/5');
        },
      );

      // ---------- state members and ids
      attack(
        'a getter in the returned members is a live read (used to be)',
        '',
        r'''
thor.def('G', ($) => { const n = $.state('n', 1); return { get live() { return n.value; }, inc: () => { n.value++; } }; });
const m = thor.use('G');
out.a = m.live;
m.inc();
out.b = m.live;
''',
        (out) {
          expect(out['a'], 1);
          expect(out['b'], 2);
        },
      );

      attack(
        'a member added to the returned object after creation is still found',
        '',
        r'''
let self;
thor.def('Late', ($) => { self = { a: () => 'a' }; return self; });
thor.use('Late');
self.late = () => 'late';
out.late = thor.use('Late').late?.() ?? 'missing';
''',
        (out) {
          expect(out['late'], 'late');
        },
      );

      attack(
        'members named constructor, toString, hasOwnProperty, __proto__ are legit own functions',
        r'''
const log = [];
thor.def('K', ($) => ({
  constructor: () => log.push('ctor'), toString: () => log.push('toString'), hasOwnProperty: () => log.push('hop'),
  ['__proto__']: () => log.push('proto'), valueOf: () => log.push('valueOf'),
}));
''',
        r'''
const before = proto();
for (const m of ['constructor', 'toString', 'hasOwnProperty', '__proto__', 'valueOf'])
  out['e_' + m] = msg(() => fire(new El({ 'data-t-on': `click:K.${m}` }), 'click'));
out.log = log.join();
out.clean = proto() === before;
''',
        (out) {
          expect(out['log'], 'ctor,toString,hop,proto,valueOf');
          expect(out['clean'], isTrue);
        },
      );

      attack(
        'hostile members that are NOT own on the state do nothing (inherited names)',
        counter,
        r'''
const before = proto();
const errs = [];
for (const m of ['constructor', 'toString', 'hasOwnProperty', '__proto__', 'valueOf', '__defineGetter__', 'isPrototypeOf'])
  errs.push(msg(() => fire(new El({ 'data-t-on': `click:S.${m}` }), 'click')));
out.errs = errs.join();
out.clean = proto() === before;
''',
        (out) {
          expect(out['errs'], List.filled(7, 'no error').join(','));
          expect(out['clean'], isTrue);
        },
      );

      attack(
        'the null-prototype member object still survives String() / spread / JSON',
        counter,
        r'''
const m = thor.use('S');
out.str = msg(() => String(m));
out.tpl = msg(() => `${m}`);
out.json = msg(() => JSON.stringify(m));
out.spread = Object.keys({ ...m }).join();
''',
        (out) {
          // A null-prototype object cannot be stringified: reported, since a
          // caller of thor.use (a part, an app script) could `${...}` it.
          expect(out['str'], 'no error');
          expect(out['json'], 'no error');
        },
      );

      attack(
        'an event target with a keyed state whose key has dots, unicode or a long text still works',
        r'''
thor.def('E', ($) => { const n = $.state('n', 0); return { count: () => `${$.key}:${n.value}`, inc: () => { n.value++; } }; });
''',
        r'''
const keys = ['a.b', 'ñandú', '🙂', 'x'.repeat(400), 'a b', 'a/b?c=d&e', '#', 'a#b', ''];
const labels = [];
for (const k of keys) {
  const l = new El({ 'data-tt': `E#${k}.count` });
  labels.push(l);
}
scanEls = labels;
const errs = [];
for (const k of keys) errs.push(msg(() => fire(new El({ 'data-t-on': `click:E#${k}.inc` }), 'click')));
out.errs = errs.filter((e) => e !== 'no error').join();
out.texts = labels.map((l) => l.textContent.slice(-2)).join('|');
''',
        (out) {
          expect(out['errs'], '');
          expect(out['texts'], ':1|:1|:1|:1|:1|:1|:1|:1|:1');
        },
      );

      attack(
        'a keyed state whose key has a tilde is still reachable by its click',
        r'''
thor.def('E', ($) => { const n = $.state('n', 0); return { inc: () => { n.value++; log.push($.key); } }; });
const log = [];
''',
        r'''
fire(new El({ 'data-t-on': 'click:E#2024~01.inc' }), 'click');
fire(new El({ 'data-t-on': 'click:E#plain.inc' }), 'click');
out.log = log.join();
''',
        (out) {
          expect(out['log'], '2024~01,plain');
        },
      );

      attack(
        'a text bound to a keyed state whose key has a tilde or a percent (escaped in the id) reads its own instance',
        r'''
thor.def('Row', ($) => ({ label: () => `[${$.key}]` }));
''',
        r'''
const a = new El({ 'data-tt': 'Row#a%7Eb.label' });
const b = new El({ 'data-tt': 'Row#100%25.label' });
const c = new El({ 'data-tt': 'Row#x%257E.label' });
const d = new El({ 'data-tt': 'Row#plain.label' });
const e = new El({ 'data-tt': 'Row#a%3Bb%253B.label' });
scanEls = [a, b, c, d, e];
for (const k of ['a%7Eb', '100%25', 'x%257E', 'plain', 'a%3Bb%253B']) thor.use(`Row#${k}`);
await step();
out.texts = [a, b, c, d, e].map((e) => e.textContent).join();
''',
        (out) {
          expect(out['texts'], '[a~b],[100%],[x%7E],[plain],[a;b%3B]');
        },
      );

      attack(
        'a keyed state whose key is longer than 512 chars is still reachable',
        r'''
thor.def('E', ($) => ({ inc: () => { log.push($.key.length); } }));
const log = [];
''',
        r'''
fire(new El({ 'data-t-on': `click:E#${'k'.repeat(600)}.inc` }), 'click');
out.log = log.join();
''',
        (out) {
          expect(out['log'], '600');
        },
      );

      attack(
        '1 MB id pieces and arguments neither throw nor stall (timed)',
        counter,
        r'''
const t0 = Date.now();
const big = 'a'.repeat(1 << 20);
const errs = [];
for (const spec of [`${big}.inc`, `S.${big}`, `S#${big}.inc`, `${big}#x.inc`, `S.inc~${big}`, big])
  errs.push(msg(() => fire(new El({ 'data-t-on': `click:${spec}` }), 'click')));
scanEls = [new El({ 'data-tt': `S.${big}` }), new El({ 'data-tv': `${big}.x` }), new El({ 'data-tl': `${big}.x` })];
errs.push(msg(() => fire(new El({ 'data-t-on': 'click:S.inc' }), 'click')));
out.errs = errs.filter((e) => e !== 'no error').join();
out.fast = Date.now() - t0 < 3000;
''',
        (out) {
          expect(out['errs'], '');
          expect(out['fast'], isTrue);
        },
      );

      attack(
        'regex backtracking on a hostile id is linear (ReDoS)',
        counter,
        r'''
const t0 = Date.now();
const bad = 'S#' + '.'.repeat(200) + '!';
for (let i = 0; i < 50; i++) fire(new El({ 'data-t-on': `click:${bad}` }), 'click');
const bad2 = 'a'.repeat(500) + '#' + 'a.'.repeat(5);
for (let i = 0; i < 50; i++) fire(new El({ 'data-t-on': `click:${bad2}` }), 'click');
out.fast = Date.now() - t0 < 1000;
''',
        (out) {
          expect(out['fast'], isTrue);
        },
      );

      attack(
        'data-tx / value that is __proto__ or a JSON bomb reaches the state as a plain string',
        r'''
thor.def('A', ($) => ({ take: (a) => { got.push(typeof a); } }));
const got = [];
''',
        r'''
const before = proto();
for (const v of ['__proto__', '{"__proto__":{"polluted":1}}', 'constructor', '']) {
  fire(new El({ 'data-t-on': 'click:A.take', 'data-tx': v }), 'click');
}
out.got = got.join();
out.clean = proto() === before && ({}).polluted === undefined;
''',
        (out) {
          expect(out['got'], 'string,string,string,string');
          expect(out['clean'], isTrue);
        },
      );

      // ---------- a broken #thor-state
      for (final entry in {
        'an array': '[1,2,3]',
        'an object with __proto__': '{"__proto__":{"polluted":1}}',
        'nested __proto__': '{"S.n":{"__proto__":{"polluted":1}}}',
        'truncated': '{"S.n":',
        'NaN literal': '{"S.n": NaN}',
        'only whitespace': '   ',
        'a string with a script tag': '"</script><script>alert(1)</script>"',
        'true': 'true',
        'a huge valid string': '{"S.n": "${'x' * 5000000}"}',
      }.entries) {
        attack(
          '#thor-state that is ${entry.key} leaves the page interactive and clean',
          r'''
thor.def('S', ($) => { const n = $.state('n', 7); return { count: () => `${n.value}`, inc: () => { n.value++; } }; });
''',
          '''
const before = proto();
stateText = ${jsonEncode(entry.value)};
const label = new El({ 'data-tt': 'S.count' });
scanEls = [label];
const btn = new El({ 'data-t-on': 'click:S.inc' });
out.err = msg(() => fire(btn, 'click'));
out.label = label.textContent;
fire(btn, 'click');
out.label2 = label.textContent;
out.clean = proto() === before && ({}).polluted === undefined;
''',
          (out) {
            expect(out['err'], 'no error');
            expect(out['clean'], isTrue);
            expect(out['label2'], isNotEmpty);
          },
        );
      }

      attack(
        'valid state with wrong field types does not stop other fields',
        r'''
thor.def('S', ($) => { const n = $.state('n', 7), m = $.state('m', 1); return { count: () => `${n.value}/${m.value}`, inc: () => { n.value++; m.value++; } }; });
''',
        r'''
stateText = '{"S.n": 3, "S.m": 4}';
const label = new El({ 'data-tt': 'S.count' });
scanEls = [label];
fire(new El({ 'data-t-on': 'click:S.inc' }), 'click');
out.label = label.textContent;
''',
        (out) {
          expect(out['label'], '4/5');
        },
      );

      attack(
        'a state named __proto__/constructor in #thor-state does not shadow saved fields',
        r'''
thor.def('S', ($) => { const n = $.state('n', 7); return { count: () => `${n.value}`, inc: () => { n.value++; } }; });
''',
        r'''
stateText = '{"constructor":1,"toString":2,"hasOwnProperty":3,"S.n":"5"}';
const label = new El({ 'data-tt': 'S.count' });
scanEls = [label];
out.err = msg(() => fire(new El({ 'data-t-on': 'click:S.inc' }), 'click'));
out.label = label.textContent;
''',
        (out) {
          expect(out['err'], 'no error');
          expect(out['label'], '6');
        },
      );

      // A factory that throws while its state is created must not leave a
      // half-made instance behind (`live[p] = {p}` with no members): every
      // later event of that state would be ignored in silence.
      attack(
        'a factory that throws once: the error is reported and the next event retries and runs',
        '',
        r"""
const errs = [];
globalThis.reportError = (x) => errs.push(x.message);
let calls = 0;
thor.def('Flaky', ($) => {
  calls++;
  if (calls === 1) throw Error('boom');
  const n = $.state('n', 0);
  return { count: () => `${n.value}`, inc: () => { n.value++; } };
});
const label = new El({ 'data-tt': 'Flaky.count' });
scanEls = [label];
const btn = new El({ 'data-t-on': 'click:Flaky.inc' });
out.err1 = msg(() => fire(btn, 'click'));
out.errs1 = errs.join();
out.label1 = label.textContent;
out.err2 = msg(() => fire(btn, 'click'));
out.label2 = label.textContent;
out.calls = calls;
out.errs = errs.length;
""",
        (out) {
          expect(out['err1'], 'no error');
          expect(out['errs1'], 'boom');
          expect(out['label1'], '');
          expect(out['err2'], 'no error');
          expect(out['label2'], '1');
          expect(out['calls'], 2);
          expect(out['errs'], 1);
        },
      );

      attack(
        'a factory that always throws: every event reports, no stale instance, other states unaffected',
        counter,
        r"""
const errs = [];
globalThis.reportError = (x) => errs.push(x.message);
let calls = 0;
thor.def('Bad', () => { calls++; throw Error('always'); });
const good = new El({ 'data-tt': 'S.count' });
scanEls = [good];
const badBtn = new El({ 'data-t-on': 'click:Bad.inc' });
const okBtn = new El({ 'data-t-on': 'click:S.inc' });
out.e1 = msg(() => fire(badBtn, 'click'));
out.e2 = msg(() => fire(badBtn, 'click'));
out.e3 = msg(() => fire(badBtn, 'click'));
out.errs = errs.join();
out.calls = calls;
out.use = msg(() => thor.use('Bad'));
fire(okBtn, 'click');
out.good = good.textContent;
""",
        (out) {
          expect([out['e1'], out['e2'], out['e3']], everyElement('no error'));
          expect(out['errs'], 'always,always,always');
          expect(out['calls'], 3);
          expect(out['good'], '1');
        },
      );

      // ---------- event delegation
      const tree = r'''
thor.def('S', ($) => {
  const mk = (n) => (v) => log.push(n + ':' + (v ?? 'null'));
  return { outer: mk('outer'), mid: mk('mid'), inner: mk('inner'), key: mk('key'), sub: mk('sub'), rm: () => { log.push('rm'); victim.isConnected = false; } };
});
const log = [];
let victim;
''';

      attack(
        'three levels, each handling click: only the innermost fires',
        tree,
        r'''
const a = new El({ 'data-t-on': 'click:S.outer' });
const b = new El({ 'data-t-on': 'click:S.mid' }, a);
const c = new El({ 'data-t-on': 'click:S.inner' }, b);
const leaf = new El({}, c);
fire(leaf, 'click');
out.log = log.join();
''',
        (out) => expect(out['log'], 'inner:null'),
      );

      attack(
        'a middle level that lacks the type is skipped, a level above catches',
        tree,
        r'''
const a = new El({ 'data-t-on': 'click:S.outer' });
const b = new El({ 'data-t-on': 'input:S.mid' }, a);
const c = new El({ 'data-t-on': 'change:S.inner' }, b);
fire(new El({}, c), 'click');
out.log = log.join();
''',
        (out) => expect(out['log'], 'outer:null'),
      );

      attack(
        'a click on a text input inside a clickable card fires the card, without the input\'s text',
        tree,
        r'''
const card = new El({ 'data-t-on': 'click:S.outer' });
const input = new El({ 'data-t-on': 'input:S.inner' }, card, 'INPUT');
input.value = 'hi'; input.type = 'text';
fire(input, 'click');
out.log = log.join();
''',
        (out) => expect(out['log'], 'outer:null'),
      );

      attack(
        'a submit button click inside a form inside a clickable card: one action per handler type, no double',
        tree,
        r'''
const card = new El({ 'data-t-on': 'click:S.outer' });
const form = new El({ 'data-t-on': 'submit:S.inner' }, card, 'FORM');
const btn = new El({}, form, 'BUTTON'); btn.type = 'submit';
fire(btn, 'click');
out.click = log.splice(0).join();
const e = fire(btn, 'submit');
out.submit = log.splice(0).join();
out.prevented = e.defaultPrevented ?? 'n/a';
''',
        (out) {
          // The browser fires the card's click for a click on the button; the
          // form's submit is its own event. Both once.
          expect(out['click'], 'outer:null');
          expect(out['submit'], 'inner:null');
        },
      );

      attack(
        'submit preventDefault is called on the handling form, not skipped when a parent handles click',
        tree,
        r'''
const card = new El({ 'data-t-on': 'click:S.outer' });
const form = new El({ 'data-t-on': 'submit:S.inner' }, card, 'FORM');
let prevented = 0;
fire(new El({}, form), 'submit', { preventDefault() { prevented++; } });
out.prevented = prevented;
// a parent that handles submit while the closest element does not
const outerForm = new El({ 'data-t-on': 'submit:S.outer' });
const inner = new El({ 'data-t-on': 'click:S.mid' }, outerForm);
prevented = 0;
fire(new El({}, inner), 'submit', { preventDefault() { prevented++; } });
out.prevented2 = prevented;
out.log = log.join();
''',
        (out) {
          expect(out['prevented'], 1);
          expect(out['prevented2'], 1);
        },
      );

      attack(
        'submit button (click) preventDefault only when the handling element is the submit button',
        tree,
        r'''
const parent = new El({ 'data-t-on': 'click:S.outer' });
const btn = new El({}, parent, 'BUTTON'); btn.type = 'submit';
let prevented = 0;
fire(btn, 'click', { preventDefault() { prevented++; } });
out.viaParent = prevented; // parent div handles it; the button is only the target
const b2 = new El({ 'data-t-on': 'click:S.inner' }, null, 'BUTTON'); b2.type = 'submit';
prevented = 0;
fire(b2, 'click', { preventDefault() { prevented++; } });
out.own = prevented;
''',
        (out) {
          expect(out['own'], 1);
          // the click of a submit button whose card (not the button) handles it
          // still submits the enclosing form natively: must not be prevented
          expect(out['viaParent'], 0);
        },
      );

      attack(
        'transitionend / animationend from a child never reach a handling ancestor',
        tree,
        r'''
const p = new El({ 'data-t-on': 'transitionend:S.outer;animationend:S.mid' });
const c = new El({}, p);
fire(c, 'transitionend'); fire(c, 'animationend');
out.child = log.splice(0).join();
fire(p, 'transitionend'); fire(p, 'animationend');
out.own = log.join();
''',
        (out) {
          expect(out['child'], '');
          expect(out['own'], 'outer:null,mid:null');
        },
      );

      attack(
        'a child with its own transitionend handler beside a clickable parent does not fire click',
        tree,
        r'''
const p = new El({ 'data-t-on': 'click:S.outer' });
const c = new El({ 'data-t-on': 'transitionend:S.inner' }, p);
fire(c, 'transitionend');
out.log = log.join();
''',
        (out) => expect(out['log'], 'inner:null'),
      );

      attack(
        'cancelBubble set by the innermost handler when it handles: parent does not fire',
        tree,
        r'''
thor.def('Stop', ($) => ({ go: () => { log.push('go'); ev.stopPropagation(); } }));
let ev;
const p = new El({ 'data-t-on': 'click:S.outer' });
const c = new El({ 'data-t-on': 'click:Stop.go' }, p);
listeners.click = ((orig) => (e) => { ev = e; orig(e); })(listeners.click);
fire(c, 'click');
out.log = log.join();
''',
        (out) => expect(out['log'], 'go'),
      );

      attack(
        'cancelBubble already true on arrival: nothing skipped ahead of the first match',
        tree,
        r'''
const p = new El({ 'data-t-on': 'click:S.outer' });
const c = new El({}, p);
fire(c, 'click', { cancelBubble: true });
out.log = log.join();
''',
        (out) {
          // The browser would not deliver an event whose propagation was
          // stopped below the root at all; the runtime only sees the flag if a
          // capture listener set it. Either way the outcome must be explicit.
          expect(out['log'], anyOf('', 'outer:null'));
        },
      );

      attack(
        'a handler that removes its own element leaves the flush and later events fine',
        tree,
        r'''
victim = new El({ 'data-t-on': 'click:S.rm' });
const p = new El({ 'data-t-on': 'click:S.outer' });
victim.parent = p;
out.e1 = msg(() => fire(victim, 'click'));
out.e2 = msg(() => fire(new El({}, p), 'click'));
out.log = log.join();
''',
        (out) {
          expect(out['e1'], 'no error');
          expect(out['log'], 'rm,outer:null');
        },
      );

      attack(
        'Enter on role=button inside a handler: one click, no second from the ancestor loop',
        tree,
        r'''
const p = new El({ 'data-t-on': 'click:S.outer;enter:S.key' });
const btn = new El({ role: 'button', 'data-t-on': 'click:S.inner' }, p);
let clicks = 0;
btn.click = () => { clicks++; fire(btn, 'click'); };
const e = fire(btn, 'keydown', { key: 'Enter' });
out.clicks = clicks;
out.log = log.join();
''',
        (out) {
          expect(out['clicks'], 1);
          expect(out['log'], 'inner:null');
        },
      );

      attack(
        'Enter on a native button (no data-t-on) inside a container that handles enter fires that handler',
        tree,
        r'''
const box = new El({ 'data-t-on': 'enter:S.key;click:S.outer' });
const btn = new El({ role: 'button' }, box, 'BUTTON');
fire(btn, 'keydown', { key: 'Enter' });
out.log = log.join();
''',
        (out) {
          // Documented, deliberate consequence of bubbling: the keydown Enter
          // reaches the container's `enter` (a real browser would too).
          expect(out['log'], 'key:null');
        },
      );

      attack(
        'an input event keeps reading the value of the target, not of the handling ancestor',
        tree,
        r'''
const p = new El({ 'data-t-on': 'input:S.outer' });
const wrap = new El({}, p, 'DIV'); wrap.value = 'wrong';
const input = new El({}, wrap, 'INPUT'); input.value = 'right'; input.type = 'text';
fire(input, 'input');
out.log = log.join();
''',
        (out) => expect(out['log'], 'outer:right'),
      );

      attack(
        'data-tx on the handling ancestor (not the target) is the fixed argument',
        tree,
        r'''
const p = new El({ 'data-t-on': 'click:S.outer', 'data-tx': 'FIXED' });
const c = new El({ 'data-tx': 'child' }, p);
fire(c, 'click');
out.log = log.join();
''',
        (out) => expect(out['log'], 'outer:FIXED'),
      );

      attack(
        'a very deep ancestor chain (5000) resolves without stack or time trouble',
        tree,
        r'''
let node = new El({ 'data-t-on': 'click:S.outer' });
for (let i = 0; i < 5000; i++) node = new El({ 'data-t-on': 'input:S.mid' }, node);
const t0 = Date.now();
fire(new El({}, node), 'click');
out.log = log.join();
out.fast = Date.now() - t0 < 1000;
''',
        (out) {
          expect(out['log'], 'outer:null');
          expect(out['fast'], isTrue);
        },
      );

      attack(
        'an ancestor with an empty or junk data-t-on is skipped, not a stopper',
        tree,
        r'''
const a = new El({ 'data-t-on': 'click:S.outer' });
const b = new El({ 'data-t-on': '' }, a);
const c = new El({ 'data-t-on': ';;;::' }, b);
fire(new El({}, c), 'click');
out.log = log.join();
''',
        (out) => expect(out['log'], 'outer:null'),
      );

      attack(
        'an ancestor handling the type with an unknown state id does not fall through to a further ancestor',
        tree,
        r'''
const a = new El({ 'data-t-on': 'click:S.outer' });
const b = new El({ 'data-t-on': 'click:Nope.x' }, a);
fire(new El({}, b), 'click');
out.log = log.join();
''',
        (out) => expect(out['log'], ''),
      );

      attack(
        'an ancestor click handler does not receive the text of a child input as its argument',
        tree,
        r'''
const card = new El({ 'data-t-on': 'click:S.outer' });
const input = new El({}, card, 'INPUT');
input.value = 'typed text'; input.type = 'text';
fire(input, 'click');
out.log = log.join();
''',
        (out) => expect(out['log'], 'outer:null'),
      );

      // ---------------------------------------------------------- cross-cutting
      attack(
        'cross: effects that throw and cycle in the same flush: engine alive and the state consistent',
        '',
        r'''
const s = thor.signal(0), a = thor.signal(0), b = thor.signal(0), seen = [];
thor.effect(() => { if (s.value === 1) throw Error('plain'); });
thor.effect(() => { seen.push(s.value); });
out.e0 = msg(() => { s.value = 1; });
const t = thor.signal(0);
thor.effect(() => { t.value; a.value = b.value + 1; });
out.cyc = msg(() => thor.effect(() => { b.value = a.value + 1; }));
out.e1 = msg(() => { s.value = 2; });
out.seen = seen.join();
''',
        (out) {
          expect(out['e0'], 'plain');
          expect(out['seen'], anyOf('0,1,2', '0,1'));
        },
      );

      attack(
        'cross: batching inside a handler defers effects to the outermost end',
        counter,
        r'''
const seen = [];
thor.effect(() => seen.push(thor.use('S').count()));
thor.def('B', ($) => ({ go: () => { thor.use('S').inc(); thor.batch(() => { thor.use('S').inc(); }); seen.push('mid'); thor.use('S').inc(); } }));
fire(new El({ 'data-t-on': 'click:B.go' }), 'click');
out.seen = seen.join();
''',
        (out) => expect(out['seen'], '0,mid,3'),
      );

      attack(
        'cross: a thrown effect error in a handler does not lose the state change or block later events',
        counter,
        r'''
let boom = true;
const label = new El({ 'data-tt': 'S.count' });
scanEls = [label];
thor.effect(() => { if (thor.use('S').count() === '1' && boom) throw Error('fx'); });
const btn = new El({ 'data-t-on': 'click:S.inc' });
out.e1 = msg(() => fire(btn, 'click'));
out.l1 = label.textContent;
boom = false;
out.e2 = msg(() => fire(btn, 'click'));
out.l2 = label.textContent;
''',
        (out) {
          expect(out['e1'], 'fx');
          expect(out['l1'], '1');
          expect(out['e2'], 'no error');
          expect(out['l2'], '2');
        },
      );

      attack(
        'cross: a throwing text effect (data-tt) mid-flush does not stop the sibling labels',
        r'''
thor.def('T', ($) => {
  const n = $.state('n', 0);
  return { bad: () => { if (n.value === 1) throw Error('bad'); return `b${n.value}`; }, good: () => `g${n.value}`, inc: () => { n.value++; } };
});
''',
        r'''
const bad = new El({ 'data-tt': 'T.bad' }), good = new El({ 'data-tt': 'T.good' });
scanEls = [bad, good];
const btn = new El({ 'data-t-on': 'click:T.inc' });
out.err1 = msg(() => fire(btn, 'click')); // activation scan + n=1: the bad text throws in the flush
out.err = msg(() => fire(btn, 'click'));
out.good = good.textContent;
out.bad = bad.textContent;
''',
        (out) {
          expect(out['good'], 'g2');
          expect(out['bad'], 'b2');
        },
      );
    });
  }
}
