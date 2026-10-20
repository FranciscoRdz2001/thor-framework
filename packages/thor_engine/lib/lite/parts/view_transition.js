// thor-lite part "view_transition": an AnimatedSwitcher's states
// (`data-t-vt`) switch in a view transition; its timing goes on <html> while
// it runs, where the page's rules read it. Another switch of the same states
// before the update only moves its target. Inside an update (states within
// states) the switch is part of it. Loaded when the page has an
// AnimatedSwitcher (`data-t-vt`); without it a switch is the plain step.
let vt, busy;
// The runtime's `sync` asks first: true when the switch is this part's.
vs = (x, n) => {
  if ('q' in x) return (x.q = n), 1;
  const k = x.l.getAttribute('data-t-vt'), h = D.documentElement;
  if (n === x.c || !k || busy || !D.startViewTransition || matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  x.q = n;
  h.setAttribute('data-t-vt', k);
  const t = (vt = D.startViewTransition(() => {
    busy = 1;
    try {
      const m = x.q;
      delete x.q;
      step(x, m);
    } finally {
      busy = 0;
    }
  }));
  const done = () => vt === t && ((vt = null), h.removeAttribute('data-t-vt'));
  t.finished.then(done, done);
  return 1;
};
