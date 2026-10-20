// thor-lite part "stream": content the server sends after the page (a
// `FutureBuilder`, streaming SSR; the swap script of the page fires
// `thor:stream` on <html> with the nodes it put in place).
//
// The values of its states join the ones the engine already read, and the
// states that are running bind the new nodes (the others wire them when
// they wake, scanning the page). Loaded when the app builds a `FutureBuilder`.
(() => {
  D.documentElement.addEventListener('thor:stream', (e) => {
    const s = D.getElementById('thor-state');
    try {
      if (json && s) for (const [k, v] of W.thor.parse(s.textContent)) json.has(k) || json.set(k, v);
    } catch (x) {
      fail(x);
    }
    for (const el of e.detail?.nodes || [])
      if (el.nodeType === 1)
        for (const p in live) {
          if (!live[p].on) continue;
          const prev = own;
          own = live[p].fx;
          try {
            untracked(() => scan(el, `${p}.`));
          } finally {
            own = prev;
          }
        }
  });
})();
