// thor-lite part "visibility": thor_ui's `VisibilityDetector`
// (`data-t-ev="visible:id"` and `data-t-vis="threshold|margin|once"`).
//
// One `IntersectionObserver` per distinct threshold and margin. An element
// is reported only when it differs from what this part last told: one that
// starts out of view says nothing until it shows, and `true`/`false` follow
// its entering and leaving. `once` stops watching after the first `true`.
// Elements arrive after the load (a list's rows, a swapped `Watch`): a
// `MutationObserver` looks at what is added. Without an
// `IntersectionObserver` nothing is reported (the child, a "Load more" link,
// is the way without it).
((D, W) => {
  const A = 'data-t-ev', O = 'data-t-vis';
  if (!W.IntersectionObserver) return;
  const last = new WeakMap(), once = new WeakSet(), seen = new WeakSet(), observers = new Map();
  const mine = (el) => el instanceof Element && el.hasAttribute(A) && 'visible' in parseOn(el.getAttribute(A));
  const report = (entries) => {
    for (const { target: el, isIntersecting: now } of entries) {
      // Gone from the page, or off the attribute: nothing to tell.
      if (!el.isConnected || !mine(el)) {
        observers.forEach((o) => o.unobserve(el));
        seen.delete(el);
        continue;
      }
      if ((last.get(el) ?? false) === now) continue;
      last.set(el, now);
      if (now && once.has(el)) observers.forEach((o) => o.unobserve(el));
      run(parseOn(el.getAttribute(A)).visible, el, `${now}`);
    }
  };
  const watch = (el) => {
    if (seen.has(el) || !mine(el)) return;
    seen.add(el);
    const [t = '0', m = '0', o = '0'] = (el.getAttribute(O) ?? '').split('|');
    const k = `${t}|${m}`;
    let io = observers.get(k);
    if (!io) {
      const th = Math.min(1, Math.max(0, +t || 0)), mg = Math.max(0, +m || 0);
      io = new W.IntersectionObserver(report, { threshold: th, rootMargin: `${mg}px` });
      observers.set(k, io);
    }
    if (o === '1') once.add(el);
    io.observe(el);
  };
  const scan = (root) => {
    if (!(root instanceof Element)) return;
    watch(root);
    root.querySelectorAll(`[${A}*="visible:"]`).forEach(watch);
  };
  D.addEventListener('thor:hydrated', () => {
    scan(D.documentElement);
    if (W.MutationObserver)
      new W.MutationObserver((ms) => ms.forEach((m) => m.addedNodes.forEach(scan))).observe(D.documentElement, { childList: true, subtree: true });
  });
})(document, window);
