// thor-lite: hand-written browser runtime for thor's server HTML protocol
// (the protocol `thor_ui` writes and this file reads). Plain modern JS, no
// build step, no dependencies.
//
// It reads the markup thor_ui emits today, unchanged: `data-tt` texts,
// `data-tv` finite states (`data-tp-<n>` patches and `<template data-tvt>`
// copies), `data-t-on` / `data-tx` / `data-txv` actions and the
// `#thor-state` JSON. Keyed lists (`data-tl`) are the part `lists`.
//
// Lazy start ("resume"): at load it only installs one delegated listener per
// event type on <html> and dispatches `thor:hydrated`. Nothing is scanned,
// no effect runs and the state JSON is not parsed until the first event that
// reaches an action of a ThorState: then that state is created (its fields
// restored from `#thor-state`), its bindings are found in the page and wired
// (texts, finite states, lists), and only after that the action runs, in a
// batch. A state that must run at load (a controller, an animation already
// running) opts in with `thor.def(name, factory, {eager: true})`.
//
// Optional parts (lib/lite/parts/*.js) load after this file
// only when an app needs them, like the dart2js engine's features:
// DateTime/Duration/TimeOfDay/DateUtils for translated states, keyed lists,
// the view transitions of an AnimatedSwitcher, the controllers, the date
// picker and the Invoker Commands polyfill.
//
// States are registered by the same ids the Dart engine uses:
//
//   thor.def('CounterState', ($) => {
//     const count = $.state('count', 0);        // restored from #thor-state
//     return {
//       count: () => count.value,
//       label: () => `${count.value}`,          // data-tt: a string
//       isZero: () => count.value === 0,        // data-tv: bool → 0/1, enum value → its index
//       inc: () => { count.value++; },          // data-t-on: an action (arg: string|null)
//       rowLabel: (item) => item.label,         // data-tf: an item method
//     };
//   }, {uses: ['OtherState']});                  // states whose signals it reads
((W) => {
  const D = document;

  // ---------------------------------------------------------------------------
  // Signals: versioned links, like Preact signals / Vue 3.5 / alien-signals.
  // A link joins one source and one target; it sits in the target's deps
  // (singly linked, in read order) and in the source's subscribers (doubly
  // linked, O(1) unsubscribe). Each source has a version; a link remembers
  // the version its target last saw. Writes push "maybe stale" marks; effects
  // pull (recompute computeds) and re-run only if a version they saw moved.
  // No Set/Map/Array in the graph; the queue is a flat array flushed once.
  let cur = null; // the computed/effect being evaluated
  let own = null; // where the effects and computeds being made are listed (a state's)
  let life; // the part `lifecycle`: onHydrated / dispose of a state
  let kw; // the part `map_keys`: a write to a signal whose entries are read one by one
  let depth = 0; // batch depth
  let gv = 0; // global version: bumps on every write (computed fast path)
  const queue = [];
  const OUT = 1, NOTIFIED = 2, RUN = 4, ERR = 8;

  class Signal {
    constructor(v) {
      this.x = v;
      this.ver = 0;
      this.sh = this.st = null; // subscriber links, head / tail
    }
    get value() {
      track(this);
      return this.x;
    }
    set value(v) {
      const o = this.x;
      if (v === o) return;
      this.x = v;
      this.ver++;
      gv++;
      depth++;
      try {
        notify(this);
        this.k && kw(this.k, o, v); // the part `map_keys`
      } finally {
        end();
      }
    }
    peek() {
      return this.x;
    }
  }

  class Computed extends Signal {
    constructor(fn) {
      super();
      this.fn = fn;
      this.f = OUT;
      this.g = -1;
      this.dh = this.dt = null; // dependency links, head / tail
    }
    get value() {
      upd(this);
      track(this); // also in error: the reader re-runs when the source recovers
      return this.get();
    }
    set value(_) {
      throw TypeError('computed');
    }
    peek() {
      upd(this);
      return this.get();
    }
    // The value, or its error again (Preact's HAS_ERROR, Angular's ERRORED).
    get() {
      if (this.f & ERR) throw this.x;
      return this.x;
    }
  }

  function track(s) {
    const t = cur;
    if (!t) return;
    let l = t.c; // the link expected next (same deps, same order: no search)
    if (l && l.s === s) t.c = l.n;
    else {
      for (l = t.dh; l && l.s !== s; l = l.n);
      if (!l) {
        l = { s, t, v: 0, n: null, p: s.st, q: null };
        t.dt ? (t.dt.n = l) : (t.dh = l);
        t.dt = l;
        s.st ? (s.st.q = l) : (s.sh = l);
        s.st = l;
      }
    }
    l.v = s.ver;
  }

  // Runs fn as t keeping the deps t has: what fn reads is added.
  function added(t, fn) {
    const prev = cur;
    cur = t;
    t.c = null;
    try {
      return fn();
    } finally {
      cur = prev;
    }
  }

  // Runs fn as t, rebuilding t's deps: links not read this time are dropped.
  function tracked(t, fn) {
    for (let l = t.dh; l; l = l.n) l.v = -1;
    t.c = t.dh;
    const prev = cur;
    cur = t;
    try {
      return fn();
    } finally {
      cur = prev;
      let last = null;
      for (let l = t.dh; l; l = l.n) {
        if (l.v < 0) {
          const s = l.s;
          l.p ? (l.p.q = l.q) : (s.sh = l.q);
          l.q ? (l.q.p = l.p) : (s.st = l.p);
          last ? (last.n = l.n) : (t.dh = l.n);
        } else last = l;
      }
      t.dt = last;
    }
  }

  function notify(s) {
    for (let l = s.sh; l; l = l.q) {
      const t = l.t;
      if (!(t.f & NOTIFIED)) {
        t.f |= NOTIFIED | OUT;
        t.run ? queue.push(t) : notify(t);
      }
    }
  }

  function stale(t) {
    for (let l = t.dh; l; l = l.n) {
      if (l.s.fn) upd(l.s);
      if (l.v !== l.s.ver) return true;
    }
    return false;
  }

  // Brings computed c up to date. A throw is kept as its value (flag ERR,
  // version bumped so readers see the change), never thrown from here. A
  // computed read while it runs is a cycle (flag RUN), not a stale value.
  function upd(c) {
    if (c.f & RUN) throw Error('thor: cycle: a computed reads itself');
    if (c.g === gv) return;
    c.g = gv;
    if (!(c.f & OUT)) return;
    c.f = (c.f & ERR) | RUN;
    let v, f = c.f & ERR, same;
    try {
      same = c.ok && !stale(c);
      if (!same) (v = tracked(c, c.fn)), (f = 0);
    } catch (x) {
      (v = x), (f = ERR);
    }
    c.f = (c.f & (OUT | NOTIFIED)) | f;
    c.ok = 1;
    if (!same && (f || v !== c.x)) {
      c.x = v;
      c.ver++;
    }
  }

  // Leaves a batch; the outermost one flushes the queue. Like Preact's
  // endBatch: every queued effect runs (one that throws does not skip the
  // rest), flags and depth are always reset, and the first error is rethrown
  // at the end. Rethrowing (not reportError) keeps the failure visible to the
  // caller: a click handler's error reaches the console, a test sees it.
  // Effects that keep re-queuing each other never drain: after 1000 rounds
  // (a round = what was queued when the previous one ended) the flush stops
  // with a `thor: cycle` error. Preact stops at 100 and Solid at 1e5 updates;
  // a legitimate chain of effects each feeding the next can pass 100 (150 was
  // seen), while a real loop hits 1000 rounds in microseconds.
  function end() {
    if (depth > 1) return void depth--;
    let err, bad, mark = queue.length, round = 0;
    for (let i = 0; i < queue.length; i++) {
      if (i === mark) {
        mark = queue.length;
        if (++round > 1000) {
          bad || ((bad = 1), (err = Error('thor: cycle: effects keep triggering each other')));
          // Leave the graph alive: the queued effects and the computeds
          // between them (still NOTIFIED, so never notified again) get
          // their flags cleared.
          for (; i < queue.length; i++) {
            const q = queue[i];
            q.f = 0;
            for (let l = q.dh; l; l = l.n) if (l.s.fn) upd(l.s);
          }
          break;
        }
      }
      const e = queue[i];
      e.f = 0;
      try {
        if (!e.dead && stale(e)) e.run();
      } catch (x) {
        bad || ((bad = 1), (err = x));
      }
    }
    queue.length = 0;
    depth--;
    if (bad) throw err;
  }

  // `o`: the list of effects and computeds of the state that made it, so
  // its disposal stops them (an owner tree; the part `lifecycle`).
  function effect(fn, o = own) {
    const e = { f: 0, dh: null, dt: null, run: () => tracked(e, fn) };
    o?.push(e);
    e.run();
    return e;
  }

  function batch(fn) {
    depth++;
    try {
      return fn();
    } finally {
      end();
    }
  }

  function untracked(fn) {
    const prev = cur;
    cur = null;
    try {
      return fn();
    } finally {
      cur = prev;
    }
  }

  // ---------------------------------------------------------------------------
  // States: registry, lazy activation, the server's JSON.
  // Every map an id from the HTML indexes has no prototype (`__proto__`,
  // `constructor` are plain keys, nothing to pollute or to call by accident):
  // a closed registry, which rules out the prototype-pollution class of bug
  // behind CVE-2025-55182.
  const nul = () => Object.create(null);
  // An error in one binding is reported, not thrown: the rest still wires.
  const fail = (x) => (W.reportError || console.error)(x);
  const defs = nul(); // class name → {f: factory, u: uses, e: eager, k: persisted cookies, i: idle, n: idle only where named}
  const live = nul(); // id prefix (`CounterState`, `CounterState#izq`) → instance
  let json; // #thor-state, parsed on first use

  function def(name, f, o = {}) {
    defs[name] = { f, u: o.uses, e: o.eager, k: o.cookies, i: o.idle, n: o.named };
  }

  function saved() {
    if (json === undefined) {
      const s = D.getElementById('thor-state');
      // A broken or non-object payload must not kill the page: the states
      // start from the values in their code.
      try {
        json = W.thor.parse(s?.textContent || '{}');
      } catch (x) {
        console.error('thor: #thor-state is not valid JSON', x);
      }
      if (!(json instanceof Map)) json = new Map();
    }
    return json;
  }

  const clsOf = (p) => p.split('#')[0];

  function inst(p) {
    let i = live[p];
    if (i || !defs[clsOf(p)]) return i;
    i = live[p] = { p, fx: [] };
    const h = p.indexOf('#'), prev = own;
    own = i.fx;
    try {
      i.m = defs[clsOf(p)].f({
        p,
        key: h < 0 ? null : p.slice(h + 1).replace(/%(25|7E|3B)/g, (_, c) => (c === '25' ? '%' : c === '3B' ? ';' : '~')),
        state: (n, v, decode) => {
          const j = saved(), k = `${p}.${n}`, g = new Signal(j.has(k) ? (decode ? decode(j.get(k)) : j.get(k)) : v);
          // Kept by name: a fragment that syncs the state's values sets them (part `stream`).
          (i.s ||= nul())[n] = [g, decode];
          return g;
        },
        computed: (fn) => {
          const c = new Computed(fn);
          own?.push(c);
          return c;
        },
        use: (q) => activate(q).m,
      });
    } catch (x) {
      // A factory that throws leaves no half-made instance (no `m`, ignored
      // for good): the next event creates the state again. Reported like the
      // other failures; the event that needed it does nothing.
      delete live[p];
      life?.(i, 1);
      fail(x);
      return;
    } finally {
      own = prev;
    }
    return i;
  }

  // Creates state p and wires its bindings in the page (once).
  function activate(p) {
    const i = inst(p);
    // No `m`: its factory is running (a state that `use`s one that `use`s it back).
    if (!i || i.on || !i.m) return i;
    i.on = 1;
    const prev = own;
    own = i.fx;
    try {
      untracked(() => {
        for (const f of scanParts) f(`${p}.`);
        scan(D.documentElement, `${p}.`);
        // Rows made in this task that are not in the page yet (a field of a row
        // woke this state): the scan above did not see them.
        for (const r of fresh) r.isConnected || scan(r, `${p}.`);
      });
    } finally {
      own = prev;
    }
    life?.(i);
    const c = clsOf(p);
    for (const n in defs) if (defs[n].u?.includes(c)) activate(n);
    return i;
  }

  // What a `State.member` id may look like (`State#key.member`): checked
  // before anything is looked up, so a made-up id is ignored, never run.
  // The key may hold anything (a row's key: `E#2024~01`); linear to test.
  const ID = /^[A-Za-z_$][\w$]*(#[\s\S]*)?\.[A-Za-z_$][\w$]*$/;
  // Made-up ids are ignored; `thor dev` (its part sets thor.dev) says so.
  const warn = (id) => void (W.thor.dev && console.warn(`thor dev: ignored id ${id.slice(0, 80)}`));

  // The function a `State.member` id names (get: `inst` to only look, or
  // `activate`), or undefined: a malformed id, no such state, or a member
  // that is not an own function.
  function fnOf(id, get) {
    if (!ID.test(id)) return warn(id);
    const d = id.lastIndexOf('.');
    const m = get(id.slice(0, d))?.m, k = id.slice(d + 1);
    const f = m && Object.hasOwn(m, k) ? m[k] : undefined;
    if (typeof f === 'function') return f;
    if (m) warn(id);
  }

  // `State.member~arg` → [function, arg].
  function member(id) {
    const t = id.indexOf('~');
    return [fnOf(t < 0 ? id : id.slice(0, t), inst), t < 0 ? null : id.slice(t + 1)];
  }

  // Optional parts with bindings of their own (variables): each gets the
  // id prefix of a state being activated (`State.`) and wires its markup.
  const scanParts = [];

  // A method of a state by id (`State.member`), as the dart2js engine's
  // features call it (a shortcut, a gesture): its element's `data-tx`
  // first, then the value (`fixed~value`), in a batch. Returns the method's
  // result (a `Focus.onKeyEvent`'s KeyEventResult).
  function run(id, el, value) {
    const fn = fnOf(id, activate);
    if (!fn) return;
    const fixed = el?.getAttribute('data-tx');
    return batch(() => fn(fixed == null ? value ?? null : value == null ? fixed : `${fixed}~${value}`));
  }


  // ---------------------------------------------------------------------------
  // Bindings.
  const texts = nul(); // text id → {e: elements}
  const groups = nul(); // finite-state id → {a: instances, x: index(), i: server's index}

  function scan(root, pre) {
    const lists = nul();
    const q = '[data-tt],[data-tv],[data-tl]';
    for (const el of [...(root.matches?.(q) ? [root] : []), ...root.querySelectorAll(q)]) {
      try {
        let id = el.getAttribute('data-tt');
        if (id?.startsWith(pre)) addText(id, el);
        id = el.getAttribute('data-tv');
        if (id?.startsWith(pre)) {
          const g = group(id, null, el);
          if (g && !g.a.some((x) => x.l === el)) instance(g, el);
        }
        id = el.getAttribute('data-tl');
        if (id?.startsWith(pre)) (lists[id] ||= []).push(el);
      } catch (x) {
        fail(x);
      }
    }
    lw?.(lists);
  }

  function addText(id, el) {
    let b = texts[id], fresh;
    if (!b) {
      const [fn, arg] = member(id);
      if (!fn) return;
      b = texts[id] = { e: [], t: () => `${fn(arg) ?? ''}` }; // null is no text, as on the server
      fresh = 1;
    }
    if (b.e.includes(el)) return;
    b.e.push(el); // registered first: a first run that throws still leaves the binding
    if (!fresh) return setText(el, untracked(b.t));
    let ran;
    effect(() => {
      const s = b.t();
      // What left the page (a removed row) is not kept.
      if (ran) b.e = b.e.filter((el) => el.isConnected);
      ran = 1;
      for (const el of b.e) setText(el, s);
    });
  }

  function setText(el, s) {
    if (el.tagName === 'INPUT') {
      if (el.value !== s) el.value = s;
      return;
    }
    const f = el.firstChild;
    if (f && !f.nextSibling && f.nodeType === 3) {
      if (f.data !== s) f.data = s;
    } else if (el.textContent !== s) el.textContent = s;
  }

  // --- finite states ---------------------------------------------------------
  // `si`: the state the server drew, when it isn't the current one (a state
  // met only inside a state's template, drawn there when the page was made).
  // `el`: the first element met for it; when the client's value is a state
  // that element doesn't draw (the server drew another: an `events()` field
  // that starts at its default in the browser), the group starts at the state
  // the server drew, not at the client's value (THOR-S037 would fire on the
  // first value that arrives).
  function group(id, si, el) {
    let g = groups[id];
    if (!g) {
      const [fn, arg] = member(id);
      if (!fn) return;
      const x = () => {
        const v = fn(arg);
        return typeof v === 'boolean' ? +v : v?.index ?? v;
      };
      let i = si ?? x();
      if (si == null && el && seenOf(el)[i]) i = drawn(el);
      g = groups[id] = { a: [], x, i };
      effect(() => {
        const n = x();
        g.a = g.a.filter((inst) => inst.l.isConnected);
        for (const inst of g.a) sync(inst, n);
      });
    }
    return g;
  }

  function instance(g, el) {
    const x = { g, s: nul(), o: nul() };
    g.a.push(x);
    bind(x, el);
    return x;
  }

  // Points instance x at el: its templates (the siblings after it) and its
  // patches (`data-tp-<n>`), as the server rendered them there.
  function bind(x, el) {
    x.l = el;
    const id = el.getAttribute('data-tv');
    const s = nul(), o = nul();
    let ns = 0, no = 0;
    for (let t = el.nextElementSibling; t?.getAttribute('data-tvt') === id; t = t.nextElementSibling) {
      const f = t.content.firstElementChild;
      if (f) (s[t.getAttribute('data-i')] = f), ns++;
    }
    for (const a of el.attributes) {
      if (a.name.startsWith('data-tp-')) (o[a.name.slice(8)] = decodePatch(a.value)), no++;
    }
    if (ns) x.s = s;
    if (no) x.o = o;
    x.c = x.g.i;
    x.b = null;
    x.p = ns && el.querySelector('[data-tv]') ? el.cloneNode(true) : null;
  }

  // The state the server drew in el: the first index that its other states
  // (patches and templates) don't cover.
  function drawn(el) {
    const seen = seenOf(el);
    let i = 0;
    while (seen[i]) i++;
    return i;
  }

  // The states el ships as a patch or a template: not the one it draws.
  function seenOf(el) {
    const id = el.getAttribute('data-tv'), seen = nul();
    for (const a of el.attributes) if (a.name.startsWith('data-tp-')) seen[a.name.slice(8)] = 1;
    for (let t = el.nextElementSibling; t?.getAttribute('data-tvt') === id; t = t.nextElementSibling) seen[t.getAttribute('data-i')] = 1;
    return seen;
  }

  // A swap would end an IME composition in progress in a field inside the
  // state: it waits for the composition to end (compositionend).
  let ime;
  const late = new Set();
  // Wired in start(), with the other listeners on the root.
  function composing(root) {
    root.addEventListener('compositionstart', (e) => (ime = e.target), true);
    root.addEventListener('compositionend', () => {
      ime = null;
      setTimeout(() => {
        for (const x of late) x.l.isConnected && sync(x, untracked(x.g.x));
        late.clear();
      });
    }, true);
  }
  // The part `view_transition` (an AnimatedSwitcher's `data-t-vt`) takes
  // the switches it runs in a view transition: `vs` says it did.
  let vs;
  function sync(x, n) {
    if (ime && x.l.contains(ime)) return void late.add(x);
    vs?.(x, n) || step(x, n);
  }

  function step(x, n) {
    if (n === x.c) return;
    let el = x.l;
    const S = x.s, O = x.o;
    for (const _ in S) {
      x.p ||= el.cloneNode(true); // the server's state, to come back to it
      break;
    }
    x.b ||= baseOf(el, O);
    // What binds inside each: patch() leaves a bound element alone, so
    // states that bind other members there are another structure.
    const bound = (n) => [...n.querySelectorAll('[data-tt],[data-tf],[data-tv],[data-tvf],[data-tl]')].map((e) => [e.dataset.tt, e.dataset.tf, e.dataset.tv, e.dataset.tvf, e.dataset.tl]).join();
    const to = (src) => {
      const next = src.querySelector('[data-tv]') || bound(el) !== bound(src) ? replace(el, src) : patch(el, src);
      if (next !== el) {
        const old = el;
        x.l = el = next;
        adopt(next, old);
      }
    };
    if (x.c !== x.g.i) {
      if (O[x.c]) apply(el, x.b);
      if (S[x.c]) to(x.p);
    }
    if (O[n]) apply(el, O[n]);
    if (S[n]) to(S[n]);
    // A state the server left out (a QueryBuilder whose builder reads
    // snapshot.data has no way to draw its "has data" states with no data):
    // nothing changes on the page, which is what a visitor would see
    // as a skeleton that never goes away. `thor dev` says why.
    else if (!O[n] && n !== x.g.i) W.thor.miss?.(el, n);
    mixed(el);
    x.l = el;
    x.c = n;
  }

  // A state with another structure put a copy in place of `old`: the states
  // and texts inside move to the copy, in document order.
  function adopt(sub, old) {
    const gone = [...old.querySelectorAll('[data-tv]')];
    const moved = [];
    for (const el of sub.querySelectorAll('[data-tv]')) {
      // A state that only this subtree binds (its Watch lived inside a state's
      // template) has no group yet: make it, at the state the template drew.
      const g = groups[el.getAttribute('data-tv')] || group(el.getAttribute('data-tv'), drawn(el));
      if (!g) continue;
      let x;
      for (let i = 0; i < gone.length && !x; i++) {
        x = g.a.find((y) => y.l === gone[i]);
        if (x) gone.splice(i, 1);
      }
      x ? bind(x, el) : (x = instance(g, el));
      moved.push(x);
    }
    for (const o of gone) {
      const a = groups[o.getAttribute('data-tv')]?.a;
      const i = a ? a.findIndex((y) => y.l === o) : -1;
      if (i >= 0) a.splice(i, 1);
    }
    for (const x of moved) if (sub.contains(x.l)) sync(x, untracked(x.g.x));
    sub.dispatchEvent(new CustomEvent('thor:adopted'));
    for (const el of self(old, '[data-tt]')) {
      const e = texts[el.getAttribute('data-tt')]?.e;
      const i = e ? e.indexOf(el) : -1;
      if (i >= 0) e.splice(i, 1);
    }
    for (const el of self(sub, '[data-tt]')) {
      try {
        addText(el.getAttribute('data-tt'), el);
      } catch (x) {
        fail(x);
      }
    }
    la?.(sub, old);
  }

  const self = (root, sel) => [...(root.matches(sel) ? [root] : []), ...root.querySelectorAll(sel)];

  const unescape = (v) => v.replaceAll('%3B', ';').replaceAll('%7C', '|').replaceAll('%25', '%');

  // `path|attr|=value;path|attr|-` → [[path], attr, value|null]
  const decodePatch = (s) =>
    s
      ? s.split(';').map((r) => {
          const f = r.split('|');
          return [f[0] ? f[0].split('.').map(Number) : [], f[1], f[2] === '-' ? null : unescape(f[2].slice(1))];
        })
      : [];

  function at(el, path) {
    for (let i of path) for (el = el.firstElementChild; i--; ) el = el.nextElementSibling;
    return el;
  }

  // The live values of every (path, attribute) a patch touches.
  function baseOf(el, O) {
    const seen = {}, out = [];
    for (const k in O)
      for (const [p, a] of O[k]) {
        const key = `${p}|${a}`;
        if (seen[key]) continue;
        seen[key] = 1;
        const e = at(el, p);
        // A `<details>` the visitor toggled before this: its `open` is what the
        // server drew (see `handle`), not what the visitor left.
        out.push([p, a, a === '#' ? e.textContent : a === 'open' && e.o0 != null ? (e.o0 ? '' : null) : e.getAttribute(a)]);
      }
    return out;
  }

  function apply(root, ops) {
    for (const [p, a, v] of ops) {
      const el = at(root, p);
      if (a === '#') el.textContent = v ?? '';
      else if (v == null) el.removeAttribute(a);
      else if (el.getAttribute(a) !== v) el.setAttribute(a, v);
      if (a === 'checked' || a === 'selected') control(el, a, v != null);
    }
  }

  function control(el, a, on) {
    if (a === 'checked' && el.tagName === 'INPUT') {
      if (el.checked !== on) el.checked = on;
    } else if (a === 'selected' && el.tagName === 'OPTION' && el.selected !== on) el.selected = on;
  }

  const WRONG = '[autofocus][aria-invalid=true]';

  function replace(live, src) {
    const c = src.cloneNode(true);
    for (const a of ['data-tv', 'data-t-on', 'data-tx', 'data-tvf']) {
      const v = live.getAttribute(a);
      if (v != null) c.setAttribute(a, v);
    }
    const f = held(live);
    live.replaceWith(c);
    if (f) f(c);
    // New nodes with a field the server marked wrong take the focus, as
    // after a page's `422` (form_submit.js), unless the focus was kept.
    else (c.matches(WRONG) ? c : c.querySelector(WRONG))?.focus();
    return c;
  }

  // The focused element inside [old] is destroyed by the swap: returns what
  // puts focus, text, selection and scroll back on its counterpart in the new
  // node, or null. The counterpart is found by id, else name (the n-th of
  // several that repeat), else by its index among the same tag, but only for
  // a field with neither and only while the count is the same (an inserted
  // field would shift it). The typed text comes back only when the user typed
  // it (differs from its default) and the new variant did not change that
  // default on purpose (a reset, a value from the server).
  function held(old) {
    const a = document.activeElement, t = a?.tagName;
    if (!a || !old.contains(a)) return null;
    const same = (r) => [r, ...r.getElementsByTagName(t)].filter((e) => e.tagName === t);
    const list = same(old), { id, name, value } = a, text = 'defaultValue' in a, def = a.defaultValue;
    const nth = (k, v) => list.filter((e) => e[k] === v).indexOf(a);
    const [ni, nn] = [id && nth('id', id), name && nth('name', name)];
    const s = [a.selectionStart, a.selectionEnd, a.selectionDirection, a.scrollTop, a.scrollLeft];
    return (c) => {
      if (document.activeElement !== document.body) return;
      const all = same(c);
      const pick = (k, v, i) => { const m = all.filter((e) => e[k] === v); return m[i] ?? m[0]; };
      const b = (id && pick('id', id, ni)) || (name && pick('name', name, nn)) || (!id && !name && all.length === list.length && all[list.indexOf(a)]);
      if (!b?.focus) return;
      b.focus({ preventScroll: true });
      if (text && 'defaultValue' in b && value !== def && b.defaultValue === def && b.value !== value) b.value = value;
      if (s[0] != null)
        try {
          if (b.value === value) b.setSelectionRange(s[0], s[1], s[2]);
          else b.setSelectionRange(b.value.length, b.value.length);
        } catch {}
      b.scrollTop = s[3];
      b.scrollLeft = s[4];
    };
  }

  const COPIED = ['aria-label', 'title', 'aria-pressed', 'aria-checked', 'aria-selected', 'aria-expanded', 'aria-current', 'disabled', 'style', 'data-tx', 'href', 'src', 'alt', 'viewBox'];

  // Copies classes, state attributes and texts from src onto live, node by
  // node; another structure replaces the subtree.
  // A bound text (`data-tt`, `data-tf`) keeps its content, but its look
  // (class, state attributes) is the state's: [look] copies only that.
  function patch(live, src, look) {
    if (live.tagName !== src.tagName || (!look && live.childNodes.length !== src.childNodes.length)) return replace(live, src);
    const bound = [];
    for (const m of ['data-tfa', 'data-tca']) {
      const ids = live.getAttribute(m);
      if (ids) bound.push(...Object.keys(parseOn(ids)));
    }
    // A row's custom properties (`row.length`) live in its `style`: a state
    // does not copy the template's over them.
    if (bound.some((n) => n.startsWith('--'))) bound.push('style');
    for (const a of ['class', ...COPIED]) {
      if (bound.includes(a)) continue;
      let v = src.getAttribute(a);
      if (fk && v?.includes('{{key}}')) v = fk(live, v, a);
      if (live.getAttribute(a) !== v) v == null ? live.removeAttribute(a) : live.setAttribute(a, v);
    }
    for (const a of ['checked', 'selected']) {
      const on = src.hasAttribute(a);
      if (live.hasAttribute(a) !== on) on ? live.setAttribute(a, '') : live.removeAttribute(a);
      control(live, a, on);
    }
    if (look) return live;
    const A = live.childNodes, B = src.childNodes;
    for (let i = 0; i < A.length; i++) {
      const x = A[i], y = B[i];
      if (x.nodeType === 1 && y.nodeType === 1) {
        if (!['data-tv', 'data-tvf'].some((a) => x.hasAttribute(a))) {
          const n = patch(x, y, ['data-tt', 'data-tf'].some((a) => x.hasAttribute(a)));
          // A subtree this brought in holds the template's `{{key}}`: the
          // row's key goes in it, as in a clone.
          if (n !== x && fk)
            for (const e of [n, ...n.querySelectorAll('*')])
              for (const a of [...e.attributes]) if (a.value.includes('{{key}}')) e.setAttribute(a.name, fk(e, a.value, a.name));
        }
      } else if (x.nodeType === 3 && x.data !== y.textContent) x.data = y.textContent;
    }
    return live;
  }

  function mixed(root) {
    for (const b of self(root, 'input[type=checkbox]')) b.indeterminate = b.getAttribute('aria-checked') === 'mixed';
  }

  // The part `lists` (keyed lists, `data-tl`): `lw` wires the lists a scan
  // found, `la` the ones in a subtree a state swapped in, `fk` puts a row's
  // key in a state's patch; `fresh`: the rows it cloned in this task.
  let lw, la, fk;
  const fresh = [];

  // ---------------------------------------------------------------------------
  // Events: one delegated listener per type on <html>. The parsed
  // `data-t-on` of an element is cached on it (reparsed only if the
  // attribute changed, e.g. by a state patch).
  const parseOn = (v) => {
    const o = nul();
    for (const p of v.split(';')) {
      const i = p.indexOf(':');
      if (i > 0) o[p.slice(0, i)] = p.slice(i + 1);
    }
    return o;
  };

  // The live `maxLength` counter of a field (`#<id>-cnt`, written by its
  // inline `oninput`): a value the engine sets does not fire `input`, so it
  // recounts here (the graphemes, like the inline handler). Only a field
  // with that handler: a `counterText` or `counter` widget is the app's.
  const count = (el) => {
    const c = el?.getAttribute?.('oninput')?.includes('-cnt') && el.id && D.getElementById(`${el.id}-cnt`);
    if (!c) return;
    const v = el.value;
    c.textContent = (W.Intl?.Segmenter ? [...new Intl.Segmenter().segment(v)].length : [...v].length) + (el.maxLength > 0 ? `/${el.maxLength}` : '');
  };

  function handle(e) {
    let type = e.type;
    const o = e.target;
    if (!o?.closest) return;
    // The `open` a `<details>` had before the visitor first toggled it is the
    // server's: a state that patches `open` comes back to that one (`baseOf`).
    // The click reaches the root before the browser toggles it.
    if (type === 'click') {
      const d = o.closest('summary')?.parentElement;
      if (d?.tagName === 'DETAILS' && d.o0 == null) d.o0 = d.open;
    }
    if (type === 'keydown') {
      const k = e.key;
      // Enter / Space on a `role="button"` tap target (KeyboardFeature), or on
      // a focusable `role="row"` / `role="cell"` (a selectable table row
      // without checkboxes, a DataCell with onTap).
      const role = o.getAttribute('role');
      if ((k === 'Enter' || k === ' ') && (role === 'button' || ((role === 'row' || role === 'cell') && o.hasAttribute('tabindex'))) && o.hasAttribute('data-t-on')) {
        e.preventDefault();
        return o.click();
      }
      if (k !== 'Enter' || e.isComposing) return;
      type = 'enter';
    }
    // Bubbling like the browser's (Solid's dom-expressions eventHandler): the
    // closest `data-t-on` that handles this type wins; one that does not lets
    // the event go on to the next ancestor, until stopPropagation. Transition
    // / animation events only count for the element itself.
    const own = /^(transition|animation)/.test(type);
    let el = own ? o : o.closest('[data-t-on]'), id;
    for (; el; el = own || e.cancelBubble ? null : el.parentElement?.closest('[data-t-on]')) {
      const spec = el.getAttribute('data-t-on');
      if (!spec) continue;
      let h = el.__thor;
      if (h?.s !== spec) h = el.__thor = { s: spec, m: parseOn(spec) };
      if ((id = h.m[type])) break;
    }
    if (!id) return;
    // A checkbox / radio that handles `change` fires it right after its click:
    // that click bubbling to a handling ancestor (a table row) would run the
    // action twice.
    if (type === 'click' && el !== o && o.tagName === 'INPUT' && (o.type === 'checkbox' || o.type === 'radio') && /(^|;)change:/.test(o.getAttribute('data-t-on') || '')) return;
    const fn = fnOf(id, activate);
    if (!fn) return;
    // One `transitionend` per change, like Flutter's `onEnd`: the browser
    // fires one per animated longhand. Wait for the last transition still
    // running, and take those that end together (same task) once.
    if (type === 'transitionend') {
      if (el.__te || (el.getAnimations ? el.getAnimations() : []).some((a) => a.transitionProperty && a.playState === 'running')) return;
      el.__te = 1;
      setTimeout(() => { el.__te = 0; });
    }
    if (type === 'submit' || type === 'enter' || (type === 'click' && ((el.tagName === 'BUTTON' && el.type === 'submit') || plainLink(el, e)))) e.preventDefault();
    const fixed = el.getAttribute('data-tx');
    // The value comes from the element that was acted on: a control's own, or
    // (input / change / enter) from the field inside a handling ancestor; a
    // click that bubbled up from a child does not hand its text to an ancestor.
    const src = o === el || type === 'input' || type === 'change' || type === 'enter' ? o : el;
    const t = src.tagName;
    const value =
      // A segmented button's checkbox: every checked value of its group (U+001F apart).
      t === 'INPUT' && src.hasAttribute('data-t-set')
        ? [...D.querySelectorAll('input[data-t-set]:checked')].filter((i) => i.getAttribute('data-t-set') === src.getAttribute('data-t-set')).map((i) => i.value).join('\u001f')
      : t === 'INPUT' ? (src.type === 'checkbox' ? `${src.checked}` : src.value)
      // A `<select multiple>` (ListBox): every chosen value, U+001F apart.
      : t === 'SELECT' && src.multiple ? [...src.selectedOptions].map((x) => x.value).join('\u001f')
      : t === 'SELECT' || t === 'TEXTAREA' ? src.value
      : typeof e.detail === 'string' ? e.detail
      : null;
    batch(() => fn(fixed == null ? value : el.hasAttribute('data-txv') ? `${fixed}~${value ?? ''}` : fixed));
    if (type === 'enter' && el.hasAttribute('data-t-clear') && t === 'INPUT') {
      o.value = '';
      count(o);
    }
    // A controlled checkbox / radio shows what its state says, not the click.
    if (type === 'change' && t === 'INPUT' && (o.type === 'checkbox' || o.type === 'radio') && o.isConnected && o.closest('[data-tv],[data-tvf]'))
      control(o, 'checked', o.hasAttribute('checked'));
  }

  // A plain primary click on an <a href> with a click handler runs the handler
  // and stays on the page; a modified or middle click, a target other than
  // _self and a download keep the native behavior.
  function plainLink(el, e) {
    const t = el.getAttribute('target');
    return el.tagName === 'A' && el.hasAttribute('href') && !e.button && !e.ctrlKey && !e.metaKey && !e.shiftKey && !e.altKey &&
      (!t || t === '_self') && !el.hasAttribute('download');
  }

  function start() {
    const root = D.documentElement;
    // Every event a thor widget binds (a part adds its own to thorEvents);
    // `thor-flutter-message`: a message from an embedded Flutter view.
    for (const t of ['click', 'input', 'change', 'submit', 'keydown', 'transitionend', 'animationend', 'thor-flutter-message', ...(W.thorEvents || [])])
      root.addEventListener(t, handle);
    composing(root);
    // A form's reset puts the values back after the event: recount then.
    root.addEventListener('reset', (e) => setTimeout(() => e.target.querySelectorAll?.('[oninput][id]').forEach(count)));
    for (const b of D.querySelectorAll('input[aria-checked=mixed]')) b.indeterminate = true;
    // A state with a persisted field whose cookie is set starts now: the
    // page shows the persisted value before any event.
    const jar = D.cookie;
    for (const n in defs) if (defs[n].e || defs[n].k?.some((c) => jar.includes(`thor-s.${c}=`))) activate(n);
    D.dispatchEvent(new CustomEvent('thor:hydrated'));
  }

  // `use`: a state's members by id, creating it first (the optional parts
  // create the state that owns a controller on its element's first event).
  W.thor = {
    def,
    use: (p) => activate(p)?.m,
    signal: (v) => new Signal(v),
    computed: (fn) => new Computed(fn),
    // JSON ⇄ JS Map. A Dart Map is a JS Map (insertion order, any string as
    // a key: like dart2js's LinkedHashMap). These are the minimal ones: the
    // top level (`#thor-state`) as a Map. The part `json` replaces them with
    // parse/str that keep the order of the text at every level; it ships
    // with the code that has Maps, JSON or the server parts.
    parse: (s) => {
      const j = JSON.parse(s);
      return j && typeof j === 'object' && !Array.isArray(j) ? new Map(Object.entries(j)) : j;
    },
    str: JSON.stringify,
    effect,
    batch,
    untracked,
    count,
  };
  // Optional parts go here (lite_bundle.dart in thor_engine): inside this scope, so the
  // ones that extend the runtime (rows) use its functions directly.
  // @thor-lite-parts
  // States are defined right after this file (same script): start once they are.
  queueMicrotask(start);
})(window);
