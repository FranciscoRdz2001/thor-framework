// thor-lite part "page_view": thor_ui's `PageView(onPageChanged:)`
// (`data-t-ev="page:id"` on the scroller, `data-tsc-h` when it is a row).
//
// The page is `round(offset / size)` of the scroll-snap view, read when the
// scroll ends (`scrollend`, or, where there is none -- Safari before 26.2 --
// when no `scroll` has come for 120 ms), and reported only when it differs
// from the last one: the index, to the state's method. Offsets count from the
// first page whatever the direction (a right-to-left or reversed view's
// `scrollLeft` is negative). The page the view shows when the engine wakes is
// the first one reported against (a controller's `initialPage` is not a change).
((D) => {
  const A = 'data-t-ev';
  const R = D.documentElement;
  const last = new WeakMap(), timers = new WeakMap();
  const view = (el) => (el instanceof Element && el.hasAttribute(A) && 'page' in parseOn(el.getAttribute(A)) ? el : null);
  const at = (el) => {
    const h = el.hasAttribute('data-tsc-h'), s = h ? el.clientWidth : el.clientHeight;
    return s ? Math.round(Math.abs(h ? el.scrollLeft : el.scrollTop) / s) : 0;
  };
  const settled = (el) => {
    timers.delete(el);
    // A controller's own run (animateToPage) is still going: its end reports.
    if (el.thorMoving) return;
    const i = at(el);
    if (i === (last.get(el) ?? 0)) return;
    last.set(el, i);
    run(parseOn(el.getAttribute(A)).page, el, `${i}`);
  };
  // Scroll events don't bubble: captured.
  R.addEventListener(
    'scroll',
    (e) => {
      const el = view(e.target);
      if (!el) return;
      clearTimeout(timers.get(el));
      timers.set(el, setTimeout(() => settled(el), 120));
    },
    { capture: true, passive: true },
  );
  R.addEventListener(
    'scrollend',
    (e) => {
      const el = view(e.target);
      if (!el) return;
      clearTimeout(timers.get(el));
      settled(el);
    },
    true,
  );
  // A view that arrives on a page (a late part, a copy in place of another)
  // starts there: where a controller put it is not a change. The controller's
  // scroll part runs first or after; either way its jump is synchronous.
  const arrived = (n) => {
    if (n.nodeType !== 1) return;
    queueMicrotask(() => {
      for (const el of [n, ...n.querySelectorAll(`[${A}]`)]) if (view(el)) last.set(el, at(el));
    });
  };
  R.addEventListener('thor:adopted', (e) => arrived(e.target), true);
  R.addEventListener('thor:stream', (e) => (e.detail?.nodes || []).forEach(arrived));
  // A controller put the view on its page once it had a size: that is its start too.
  R.addEventListener('thor:pagestart', (e) => view(e.target) && last.set(e.target, at(e.target)), true);
  D.addEventListener('thor:hydrated', () => {
    for (const el of D.querySelectorAll(`[${A}]`)) if (view(el)) last.set(el, at(el));
  });
})(document);
