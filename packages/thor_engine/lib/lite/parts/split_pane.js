// thor-lite part "split_pane": thor_ui's `SplitPane`, the WAI-ARIA window
// splitter. The root carries `data-t-split="x|y"` (panes side by side or
// stacked) and `data-t-split-min="first,second"` (pixels); its divider is
// `[data-t-split-bar]` with `role="separator"`.
//
// The server writes the first size as CSS (`clamp()` of a number on the root,
// `--tsp`, the share of the room the divider leaves), so the page is right
// with no JS and the bounds hold when the window resizes. This part only
// moves that one number and keeps `aria-valuenow/min/max` true:
//
//  - a pointer drags the divider (it keeps the point it was grabbed at);
//  - ArrowLeft/Right (or Up/Down when stacked) move 2 %, 10 % with Shift;
//    Home and End go to the smallest and the largest first pane. In a
//    right-to-left row the horizontal arrows are mirrored.
//
// The state hears the fraction (`data-t-ev="split:id"`, 0 to 1) when a drag
// ends or a key moves it, not on every pixel. A few page-wide listeners: the
// markup costs nothing until it is used.
((W, D) => {
  const A = 'data-t-split';
  const BAR = '[data-t-split-bar]';
  const R = D.documentElement;
  let drag = null;

  const rootOf = (bar) => bar.closest(`[${A}]`);
  const barOf = (root) => root.querySelector(BAR);

  // The geometry of a root, in pixels along its axis. `rtl` mirrors a row;
  // `start` is where the axis begins (the right edge of a right-to-left row).
  function geometry(root, bar) {
    const x = root.getAttribute(A) === 'x';
    const r = root.getBoundingClientRect(), b = bar.getBoundingClientRect();
    const rtl = x && W.getComputedStyle(root).direction === 'rtl';
    const total = x ? r.width : r.height, thick = x ? b.width : b.height;
    const [m1 = 0, m2 = 0] = (root.getAttribute('data-t-split-min') || '').split(',').map((n) => +n || 0);
    const avail = Math.max(total - thick, 0);
    // The first pane's size can't go under m1 nor leave the second under m2
    // (when both can't hold, the first minimum wins, as `clamp()` says).
    const lo = Math.min(m1, avail), hi = Math.max(lo, avail - m2);
    const edge = x ? (rtl ? r.right : r.left) : r.top, at = x ? (rtl ? b.right : b.left) : b.top;
    // Where the divider starts along the axis: the first pane's size.
    return { x, rtl, avail, thick, lo, hi, edge, barAt: (at - edge) * (rtl ? -1 : 1) };
  }

  const clamp = (v, lo, hi) => Math.min(Math.max(v, lo), hi);
  const round = (n, d) => Math.round(n * 10 ** d) / 10 ** d;

  // Puts the first pane at `size` pixels (clamped) and reports it as aria.
  function place(root, bar, g, size) {
    const first = clamp(size, g.lo, g.hi);
    const f = g.avail ? first / g.avail : 0;
    root.style.setProperty('--tsp', `${round(f, 4)}`);
    aria(bar, g, f);
    return f;
  }

  function aria(bar, g, f) {
    const pct = (px) => (g.avail ? (px / g.avail) * 100 : 0);
    bar.setAttribute('aria-valuenow', `${Math.round(f * 100)}`);
    bar.setAttribute('aria-valuemin', `${Math.ceil(pct(g.lo))}`);
    bar.setAttribute('aria-valuemax', `${Math.floor(pct(g.hi))}`);
  }

  const report = (root, f) => {
    const id = parseOn(root.getAttribute('data-t-ev') ?? '').split;
    if (id) run(id, root, `${round(f, 4)}`);
  };

  // Where the pointer is along the axis, counted from the root's start.
  const along = (g, e) => ((g.x ? e.clientX : e.clientY) - g.edge) * (g.rtl ? -1 : 1);

  R.addEventListener('pointerdown', (e) => {
    const bar = e.target?.closest?.(BAR);
    const root = bar && rootOf(bar);
    if (!root || (e.button != null && e.button !== 0)) return;
    const g = geometry(root, bar);
    // The point of the divider that was grabbed stays under the pointer.
    drag = { root, bar, grab: along(g, e) - g.barAt, id: e.pointerId };
    bar.setAttribute('data-dragging', '');
    bar.focus?.();
    bar.setPointerCapture?.(e.pointerId);
    e.preventDefault();
  });

  R.addEventListener('pointermove', (e) => {
    if (!drag || (drag.id != null && e.pointerId !== drag.id)) return;
    const g = geometry(drag.root, drag.bar);
    drag.f = place(drag.root, drag.bar, g, along(g, e) - drag.grab);
  });

  function end(e) {
    if (!drag || (drag.id != null && e.pointerId !== drag.id)) return;
    const { root, bar, f } = drag;
    drag = null;
    bar.removeAttribute('data-dragging');
    bar.releasePointerCapture?.(e.pointerId);
    if (f != null) report(root, f);
  }
  R.addEventListener('pointerup', end);
  R.addEventListener('pointercancel', end);

  R.addEventListener('keydown', (e) => {
    const bar = e.target?.closest?.(BAR);
    const root = bar && rootOf(bar);
    if (!root || e.altKey || e.ctrlKey || e.metaKey) return;
    const g = geometry(root, bar);
    const dir = g.rtl ? -1 : 1;
    const step = (e.shiftKey ? 0.1 : 0.02) * g.avail;
    const now = clamp(g.barAt, g.lo, g.hi);
    let to;
    if (e.key === (g.x ? 'ArrowRight' : 'ArrowDown')) to = now + step * (g.x ? dir : 1);
    else if (e.key === (g.x ? 'ArrowLeft' : 'ArrowUp')) to = now - step * (g.x ? dir : 1);
    else if (e.key === 'Home') to = g.lo;
    else if (e.key === 'End') to = g.hi;
    else return;
    e.preventDefault();
    report(root, place(root, bar, g, to));
  });

  // The first paint is the server's; the bounds in aria need the layout.
  const scan = () => {
    for (const bar of D.querySelectorAll(BAR)) {
      const root = rootOf(bar);
      if (!root) continue;
      const g = geometry(root, bar);
      const f = parseFloat(bar.getAttribute('aria-valuenow')) / 100;
      aria(bar, g, g.avail ? clamp(f * g.avail, g.lo, g.hi) / g.avail : f);
    }
  };
  W.addEventListener('pageshow', scan);
  D.addEventListener('thor:hydrated', scan);
  if (D.readyState === 'loading') D.addEventListener('DOMContentLoaded', scan);
  else scan();
})(window, document);
