// thor-lite part "lifecycle": `onHydrated()` and `dispose()` of a state,
// and the listeners of a StateSignal (`thor.stop`). Loaded when a state
// overrides one of them or listens to a signal; without it the runtime only
// keeps the list of effects each state made (`fx`).
//
// Life of a state (Flutter's initState / dispose). A state that overrides
// `onHydrated()` or `dispose()` lists them in `$l: {h, d}` (never callable
// from the page). `h` runs once, right after the state is created and its
// bindings are wired (in a batch: its writes paint once). A state with `h`
// wakes at idle (`idle` in def) so its timers start without waiting for an event:
// a state without it stays lazy. `named` (def option: the builder writes it
// for every state with `onHydrated` unless it has `bool get global => true`)
// wakes it only on a page whose elements name it. `d` makes the state live as long as its
// elements: when none is left in the page (a keyed row removed, a variant
// replaced for good) or the page is unloaded, `d` runs once, the effects
// the state made stop and it is forgotten; the same id in the page again
// is a new instance, from the server's values. Removals are seen by one
// MutationObserver, which exists only once a state with `d` is created; it
// looks at what the removed elements name, never at the whole page per state.
(() => {
  // Stops an effect or a computed: it leaves the subscribers of every source
  // it read and never runs again.
  function stop(t) {
    t.dead = 1;
    for (let l = t.dh; l; l = l.n) {
      const s = l.s;
      l.p ? (l.p.q = l.q) : (s.sh = l.q);
      l.q ? (l.q.p = l.p) : (s.st = l.p);
    }
    t.dh = t.dt = null;
  }

  let mo;

  // The id prefix of a binding id (`State#key.member`, maybe `~value`).
  const pre = (id) => {
    const t = id.indexOf('~');
    id = t < 0 ? id : id.slice(0, t);
    return id.slice(0, id.lastIndexOf('.'));
  };

  // The attributes that name a state: an id (the first nine), or a list of
  // `event:id` split by `;`.
  const ATTRS = 'tt tv tl tf tvf tdc tsc ttc tfn t-on tca tcv tfa tks tg'.split(' ').map((a) => `data-${a}`);
  const SEL = ATTRS.map((a) => `[${a}]`).join();

  // The states these elements name.
  const named = (els) => {
    const s = new Set();
    for (const el of els)
      ATTRS.forEach((a, k) => {
        const v = el.getAttribute(a);
        if (v != null) for (const x of k < 9 ? [v] : v.split(';')) s.add(pre(k < 9 ? x : x.slice(x.indexOf(':') + 1)));
      });
    return s;
  };

  // The observer and `pagehide`, once. Removals: dispose what lost its
  // elements. Additions: wake the states with `h` that come in (a row added
  // again).
  function watch() {
    if (mo || !W.MutationObserver) return;
    mo = new MutationObserver((rs) => {
      const add = [], out = [];
      for (const r of rs) {
        for (const n of r.removedNodes) n.nodeType === 1 && out.push(n);
        for (const n of r.addedNodes) n.nodeType === 1 && add.push(n);
      }
      out.length && sweep(named(out.flatMap((n) => self(n, SEL))));
      add.length && wake(add);
    });
    mo.observe(D.documentElement, { childList: true, subtree: true });
    W.addEventListener('pagehide', (e) => e.persisted || sweep());
  }

  // The runtime's hook: a state was wired (`abort`: its factory threw).
  life = (i, abort) => {
    if (abort) return void i.fx.forEach(stop);
    const l = i.m.$l;
    if (!l) return;
    if (l.d || l.h) watch();
    if (!l.h) return;
    const prev = own;
    own = i.fx;
    try {
      // A rejection is reported too (an async `onHydrated`).
      const r = batch(l.h);
      r?.then?.(null, fail);
    } catch (x) {
      fail(x);
    } finally {
      own = prev;
    }
  };

  // Disposes the states with `d` that `gone` (the states removed elements
  // name) or an earlier wait (`g`) say may have lost their elements, if the
  // page really names them no more; with no `gone`, all of them (the page is
  // going). Users before what they use. A state a staying one uses waits
  // (`g`) for it to end: a cycle (A uses B uses A) goes together.
  function sweep(gone) {
    if (gone && !gone.size) return;
    let here;
    const dead = [];
    // The live states that use others (few, if any), and whether one of them
    // other than `skip` uses i's class.
    const users = Object.values(live).filter((i) => defs[clsOf(i.p)].u);
    const used = (i, skip) => users.some((j) => j !== i && live[j.p] === j && !skip?.includes(j) && defs[clsOf(j.p)].u.includes(clsOf(i.p)));
    for (const p in live) {
      const i = live[p];
      if (!i.on || !i.m?.$l?.d || (gone && !gone.has(p) && !i.g)) continue;
      if (!gone || !(here ||= named(D.querySelectorAll(SEL))).has(p)) dead.push(i);
      else i.g = 0;
    }
    if (gone)
      for (let more = 1; more; ) {
        more = 0;
        for (const i of dead) if (used(i, dead)) (more = i.g = 1), dead.splice(dead.indexOf(i), 1);
      }
    const ended = new Set();
    while (dead.length) {
      const i = dead.find((j) => !used(j)) || dead[0];
      dead.splice(dead.indexOf(i), 1);
      ended.add(i.p);
      kill(i);
    }
    // Their bindings, in one pass however many ended.
    if (ended.size) for (const r of [texts, groups]) for (const id in r) ended.has(pre(id)) && delete r[id];
  }

  function kill(i) {
    delete live[i.p];
    try {
      untracked(() => i.m.$l.d());
    } catch (x) {
      fail(x);
    }
    i.fx.forEach(stop);
    // A listener added to one of its signals now is a mistake (Flutter's
    // ChangeNotifier asserts): the translator's addListener checks this.
    for (const k in i.m.$s) i.m.$s[k].off = 1;
  }

  // The states with `h` the page shows, woken: a keyed instance if a text, a
  // state or a list of it is in the page (`ns`: only in these new nodes); at
  // idle, an unkeyed class the page never names with a key too, by its name
  // (it may have no element at all: a ticker).
  function wake(ns) {
    const ps = new Set(), keyed = new Set();
    const els = ns ? ns.flatMap((n) => self(n, '[data-tt],[data-tv],[data-tl]')) : D.querySelectorAll('[data-tt],[data-tv],[data-tl]');
    for (const el of els)
      for (const a of ['data-tt', 'data-tv', 'data-tl']) {
        const v = el.getAttribute(a);
        if (!v) continue;
        const p = pre(v), c = clsOf(p);
        if (defs[c]?.i) (ps.add(p), v.includes('#') && keyed.add(c));
      }
    if (!ns) {
      // A class that only the templates name with a key (`Row#{{key}}`) has
      // no default instance. One with `n` (named: its idle wake is only to
      // start the browser's queries) wakes only where an element of the page
      // names it: a page that doesn't use the state asks for nothing.
      const html = D.documentElement.innerHTML;
      let names;
      // `Class#` starting at a name boundary (`Clock#` is not `WorldClock#`).
      const keyedIn = (c) => {
        for (let i = html.indexOf(`${c}#`); i >= 0; i = html.indexOf(`${c}#`, i + 1)) if (!/[\w$]/.test(html[i - 1] || '')) return true;
        return false;
      };
      for (const c in defs)
        if (defs[c].i && !keyed.has(c) && !keyedIn(c)) {
          // A state a named one uses counts as named (it woke before for it).
          if (defs[c].n && !names) {
            names = new Set([...named(D.querySelectorAll(SEL))].map(clsOf));
            for (const x of names) for (const u of defs[x]?.u || []) names.add(u);
          }
          if (!defs[c].n || names.has(c)) ps.add(c);
        }
    }
    for (const p of ps) activate(p);
  }

  W.thor.stop = stop;
  // At idle, once the page's script has defined its states: the states with
  // `h` wake without waiting for an event (a timer starts).
  queueMicrotask(() => {
    for (const n in defs)
      if (defs[n].i) return void (watch(), (W.requestIdleCallback || setTimeout)(() => wake()));
  });
})();
