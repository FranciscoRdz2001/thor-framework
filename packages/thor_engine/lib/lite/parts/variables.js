// thor-lite part "variables": `WatchVariables` (`data-tcv`: CSS custom
// properties in px) and `WatchAttributes` (`data-tca`: attributes) — the
// dart2js engine's VariablesFeature (needs "attributes"). The server wrote
// the first values; when a state is created, an effect per binding of its
// keeps them current. The pairs (name, id) a late part, a copy put in place
// of a subtree or a row cloned from a template brings join the ones of the
// states that run; one with no element left in the page is released.
(() => {
  // `name:id;…` (variables need `--x`: the colon after the third char).
  const pairs = (v, min) =>
    v.split(';').flatMap((p) => {
      const i = p.indexOf(':');
      return i > min ? [[p.slice(0, i), p.slice(i + 1)]] : [];
    });

  const Q = '[data-tcv],[data-tca]';
  // (attribute?, name, id) → {a, n: name, e: its elements, f: its effect, o: the
  // list of the effects of its state}: one effect per pair, however many
  // elements carry it.
  const rec = nul();
  let count = 0, cap = 256;
  const put = (r, el, v) => {
    if (r.a) return writeAttr(el, r.n, `${v ?? ''}`);
    const p = cssPx(v);
    if (el.style.getPropertyValue(r.n) !== p) el.style.setProperty(r.n, p);
  };
  // A pair with no element in the page: its effect reads nothing from now on,
  // so it leaves the signals, and its state's list forgets it.
  const drop = (key, r) => {
    if (rec[key] !== r) return;
    r.g = 1;
    delete rec[key];
    count--;
    // Out of the state's list in O(1): the last one takes its place (`x`: where it is).
    const o = r.o, f = r.f;
    if (f && o[f.x] === f) {
      const l = o.pop();
      if (l !== f) o[(l.x = f.x)] = l;
    }
  };
  const free = (key) => {
    const r = rec[key];
    drop(key, r);
    r.f.run();
  };
  // The pairs of rows that left while their signal did not change again.
  const sweep = () => {
    for (const k in rec) {
      const r = rec[k], e = r.e;
      if (e.length === 1) e[0].isConnected || free(k);
      else (r.e = e.filter((el) => el.isConnected)).length || free(k);
    }
    cap = Math.max(256, 2 * count);
  };
  // The state a binding id names (`State#key.member~arg`), if it runs.
  const stateOf = (id) => {
    const t = id.indexOf('~');
    id = t < 0 ? id : id.slice(0, t);
    const i = live[id.slice(0, id.lastIndexOf('.'))];
    return i?.on ? i : null;
  };
  function add(el, a, name, id) {
    const key = `${+a}${name}|${id}`;
    let r = rec[key];
    if (r?.f.dead) (free(key), (r = null)); // its state ended
    if (r) return void (r.e.includes(el) || (r.e.push(el), 'v' in r && put(r, el, r.v)));
    const i = stateOf(id);
    if (!i || (!a && !/^--[A-Za-z0-9_-]+$/.test(name))) return;
    const [fn, arg] = member(id);
    if (!fn) return;
    r = { a, n: name, e: [el], o: i.fx };
    r.f = effect(() => {
      if (r.g) return;
      r.e = r.e.filter((x) => x.isConnected);
      if (!r.e.length) return drop(key, r);
      // A method that throws is reported and keeps its pair (and the server's value): it
      // must not leave the effect unrecorded, or each put of its element in the page makes another.
      let v;
      try {
        v = r.v = fn(arg);
      } catch (x) {
        return fail(x);
      }
      for (const x of r.e) put(r, x, v);
    }, i.fx);
    if (!r.g) {
      r.f.x = r.o.lastIndexOf(r.f);
      rec[key] = r;
      if (++count > cap) sweep();
    }
  }
  // The pairs in root (and root itself) whose state id starts with `pre`.
  function bind(root, pre) {
    const all = root.querySelectorAll(Q);
    for (let n = root.matches(Q) ? -1 : 0; n < all.length; n++) {
      const el = n < 0 ? root : all[n];
      try {
        for (const [n, id] of pairs(el.getAttribute('data-tcv') ?? '', 2)) id.startsWith(pre) && add(el, 0, n, id);
        for (const [n, id] of pairs(el.getAttribute('data-tca') ?? '', 0)) id.startsWith(pre) && add(el, 1, n, id);
      } catch (x) {
        fail(x);
      }
    }
  }

  // `clientOnly` (`data-tcs`): the server left those attributes out, so the
  // states the element names start now, not on the first event (the runtime
  // is lazy), and write them before the user can act.
  const S = '[data-tcs][data-tca]';
  const start = (root) => {
    const els = [...root.querySelectorAll(S)];
    root.matches(S) && els.push(root);
    for (const el of els)
      for (const [, id] of pairs(el.getAttribute('data-tca'), 0)) {
        const t = id.indexOf('~');
        try {
          activate((t < 0 ? id : id.slice(0, t)).replace(/\.[^.]*$/, ''));
        } catch (x) {
          fail(x);
        }
      }
  };

  scanParts.push((pre) => bind(D.documentElement, pre));
  // What the page gains once its states run: the pairs of the states that run
  // join; the others are found when their state wakes.
  new MutationObserver((ms) => {
    for (const m of ms) for (const n of m.addedNodes) if (n.nodeType === 1 && n.isConnected) (bind(n, ''), start(n));
  }).observe(D.documentElement, { childList: true, subtree: true });
  // Once the page's script has defined its states.
  queueMicrotask(() => start(D.documentElement));
})();
