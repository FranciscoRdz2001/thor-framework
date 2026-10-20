// thor-lite part "dev_state" (only in `thor dev`: `lite_bundle --dev`): the
// dart2js engine's dev_state.dart + dev_client.dart. Before `thor dev`
// reloads a page, its live-reload script asks `__thorDevState()` for a
// snapshot of the fields of every state that started ({"v": 1, "s":
// {"CounterState.count": 3, …}}) and keeps it in sessionStorage per tab and
// path; the reloaded page takes it back once, after the eager states start.
// Field by field: what still fits comes back, the rest keeps the server's
// value. A value that is not plain JSON (a date, an app's class) is left
// out, unless its `state(...)` has `encode:`/`decode:` (the translator, in
// `thor dev`, puts them on the signal as `enc`/`dec`): it is saved through
// the one and comes back through the other. An `events()` stream's fields
// are not kept (they re-subscribe). If the page throws with the restored
// values, every field goes back.
// Never throws. Uses the runtime's `live`, `activate` and `batch` (it is
// sewn inside its scope).
((W, D) => {
  W.thor.dev = 1; // the runtime warns about ignored ids only here
  // A finite state the server did not draw was reached (the runtime calls
  // this): a QueryBuilder skeleton that would never go away.
  W.thor.miss = (el, n) =>
    console.error(
      `thor dev: ${el.getAttribute('data-tv')} reached state ${n}, which the server did not draw: a QueryBuilder builder that reads snapshot.data (or requireData) can't be drawn before the data is there. Bind what changes (Watch, row.text, QueryError) or pass initialData:. (THOR-S037)`,
    );
  const KEY = 'thor:state:' + location.pathname, LIMIT = 512 * 1024, V = 1;
  const plain = (v) =>
    v === null ||
    typeof v === 'boolean' ||
    typeof v === 'string' ||
    (typeof v === 'number' && isFinite(v)) ||
    (Array.isArray(v)
      ? v.every(plain)
      : v instanceof Map && [...v].every(([k, x]) => typeof k === 'string' && plain(x)));
  const kind = (v) =>
    v == null ? null : Array.isArray(v) ? 'list' : v instanceof Map ? 'map' : typeof v === 'number' ? 'number' : typeof v === 'string' ? 'string' : 'bool';
  // Every field of the states that started, by id (`State.field`). A
  // `derived` (a computed) is left out: it is recomputed, and assigning it
  // throws, which would send every restored field back. So is a signal
  // flagged `nr` (an `events()` stream's: it re-subscribes).
  const fields = () => {
    const out = {};
    for (const p in live) {
      const s = live[p].m?.$s;
      if (s) for (const n in s) s[n] instanceof Computed || s[n].nr || (out[`${p}.${n}`] = s[n]);
    }
    return out;
  };

  // Never throws: a field that does not encode (a cycle, 10k levels deep, a
  // computed in error) is left out like any other that is not plain JSON.
  W.__thorDevState = () => {
    const values = {}, sizes = {}, dropped = [];
    try {
      const all = fields();
      let total = 0;
      for (const id in all) {
        try {
          const g = all[id], v = g.enc ? g.enc(g.peek()) : g.peek();
          if (!plain(v)) throw 0;
          const n = W.thor.str(v).length + id.length + 4;
          values[id] = v;
          total += sizes[id] = n;
        } catch {
          dropped.push(id);
        }
      }
      // Too big: the largest fields go first.
      for (const id of Object.keys(sizes).sort((a, b) => sizes[b] - sizes[a])) {
        if (total <= LIMIT) break;
        delete values[id];
        total -= sizes[id];
        dropped.push(id);
      }
    } catch {}
    if (dropped.length) console.warn(`thor dev: not kept across the reload (not JSON, or too big): ${dropped.join(', ')}`);
    return W.thor.str(new Map([['v', V], ['s', new Map(Object.entries(values))]]));
  };

  D.addEventListener(
    'thor:hydrated',
    () => {
      let text, snap;
      try {
        text = sessionStorage.getItem(KEY);
        if (text == null) return;
        sessionStorage.removeItem(KEY);
      } catch {
        return;
      }
      try {
        snap = W.thor.parse(text);
      } catch {
        return console.warn('thor dev: the saved state was not JSON; ignored');
      }
      const saved = snap instanceof Map && snap.get('v') === V && snap.get('s') instanceof Map ? snap.get('s') : null;
      if (!saved) return;
      // The states it names start first: their bindings show the values.
      for (const id of saved.keys()) {
        try {
          activate(id.slice(0, id.lastIndexOf('.')));
        } catch {}
      }
      const all = fields(), before = new Map(), dropped = {};
      try {
        batch(() => {
          for (const [id, v] of saved) {
            const s = all[id];
            if (!s) {
              dropped[id] = 'no longer on the page';
              continue;
            }
            const now = s.enc ? s.enc(s.peek()) : s.peek();
            if (!plain(now)) {
              dropped[id] = 'its value does not encode';
              continue;
            }
            const was = kind(v), is = kind(now);
            if (was && is && was !== is) {
              dropped[id] = `was ${was}, now ${is}`;
              continue;
            }
            let next = v;
            if (s.dec) {
              try {
                next = s.dec(v);
              } catch {
                dropped[id] = 'its decode rejected it';
                continue;
              }
            }
            before.set(s, s.peek());
            s.value = next;
          }
        });
      } catch {
        // An effect threw with the restored values: back to the server's.
        try {
          batch(() => {
            for (const [s, v] of before) s.value = v;
          });
        } catch {}
        return console.warn("thor dev: the page failed with the saved state; it starts from the server's values");
      }
      for (const id in dropped) console.info(`thor dev: ${id} not restored: ${dropped[id]}`);
    },
    { once: true },
  );
})(window, document);
