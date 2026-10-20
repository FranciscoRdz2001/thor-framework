// thor-lite part "local_storage": `state(…, local: 'k')` (the dart2js engine's
// PersistedStatesFeature, its `localStorage` half). Loaded when a state
// persists a field there.
//
// `thor.local(s, k, e, t, d)` moves signal `s` to the value stored at
// `thor-s.<k>` when it holds one of the field's type (`t` checks it, `d`
// decodes it) — in a microtask, once the state's bindings took the server's
// markup — and stores it back (through `e`) when it changes. The writes are
// coalesced like the cookie ones: one per frame with the value it has then,
// at once when the page hides (no frames there) or on `pagehide`. Another
// tab's write arrives as a `storage` event and becomes the field's value; a
// write of the value already stored is skipped, so two tabs never echo.
// Where storage throws (blocked: a private window, a sandboxed frame; or a
// full quota) the value lives in memory for the page, with no error.
// `thor.local.has(state, ...keys)`: whether any key is stored (the runtime
// then starts that state at load, as it does for a set cookie); a state not
// started yet starts when another tab stores one of its keys.
((T, W, D) => {
  const N = {}, P = 'thor-s.', mem = new Map(), subs = new Map(), owner = new Map(), q = new Map();
  let st, h = 0, on = 0;
  const store = () => {
    if (st === undefined)
      try {
        // A blocked storage throws here, or on its first use in some engines.
        (st = W.localStorage).getItem(P);
      } catch {
        st = null;
      }
    return st;
  };
  const get = (k) => {
    if (mem.has(k)) return mem.get(k);
    try {
      return store()?.getItem(k) ?? null;
    } catch {
      return null;
    }
  };
  const set = (k, v) => {
    try {
      store().setItem(k, v);
      mem.delete(k);
    } catch {
      mem.set(k, v);
    }
  };
  // A stored value is the visitor's to write: one of another type or shape
  // is ignored (the page keeps the value it has).
  const read = (r, t, d) => {
    try {
      const y = T.parse(r), z = d ? d(y) : y;
      if (!t || t(z)) return [z];
    } catch {}
  };
  // A field's listener whose state is still alive (its effect not stopped).
  const live = (f) => !f.x?.dead;
  const flush = () => {
    h = 0;
    const l = [...q.values()];
    q.clear();
    // An encode that throws is reported without losing the other writes.
    l.forEach((w) => {
      try {
        w();
      } catch (x) {
        (W.reportError || console.error)(x);
      }
    });
  };
  const listen = () => {
    if (on) return;
    on = 1;
    W.addEventListener?.('pagehide', flush);
    D.addEventListener?.('visibilitychange', () => D.visibilityState === 'hidden' && flush());
    // Another tab stored a value: the fields take it (a state not started
    // yet starts, reading it). A removed key (or a cleared storage) leaves
    // the page as it is.
    W.addEventListener?.('storage', (x) => {
      const k = x.key, l = subs.get(k)?.filter(live);
      if (k == null || x.newValue == null || (x.storageArea && x.storageArea !== store())) return;
      mem.delete(k);
      if (l?.length) l.forEach((f) => f(x.newValue));
      else if (owner.has(k)) T.use(owner.get(k));
    });
  };
  const local = (s, c, e, t, d) => {
    // `p`: the value the field just took from the storage. It is there
    // already, so that change writes nothing (no echo between tabs).
    const k = P + c, r = get(k), v = r != null && read(r, t, d), take = (v) => (s.value = p = v[0]);
    let p = N, f = 1;
    if (v) queueMicrotask(() => take(v));
    listen();
    const w = () => {
      const j = T.str(e ? e(s.peek()) : s.peek());
      if (j !== get(k)) set(k, j);
    };
    const x = T.effect(() => {
      const v = s.value, o = p;
      p = N;
      if (f) {
        f = 0;
        return;
      }
      if (v === o) return;
      q.set(s, w);
      if (D.visibilityState === 'hidden') return flush();
      if (!h) {
        h = 1;
        W.requestAnimationFrame ? W.requestAnimationFrame(flush) : setTimeout(flush, 16);
      }
    });
    // The other tabs' writes reach this field while its state lives: a
    // disposed state stopped the effect (the part `lifecycle`), so its
    // listener goes when the same state starts again, not one per start.
    const u = (n) => {
      const v = read(n, t, d);
      if (v) take(v);
    };
    u.x = x;
    subs.set(k, [...(subs.get(k) || []).filter(live), u]);
    return s;
  };
  local.has = (n, ...c) => {
    listen();
    c.forEach((c) => owner.set(P + c, n));
    return c.some((c) => get(P + c) != null);
  };
  T.local = local;
})(thor, globalThis, document);
