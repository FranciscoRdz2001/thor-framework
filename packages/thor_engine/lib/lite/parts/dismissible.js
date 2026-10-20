// thor-lite part "dismissible": thor_ui's `Dismissible` (`data-t-dm`; the
// dart2js engine's DismissibleFeature).
//
// The body (`data-t-dm-body`) follows the pointer through `--t-dm-x/y`,
// which its own class maps to `translate`; the backgrounds under it are
// shown by `data-t-dm-on`. Nothing runs in Dart while it moves. Past the
// threshold (or a fling) the body slides out, `confirm` is asked (a state
// method returning a bool or a promise of one), the root collapses (a CSS
// transition of a grid track, `data-t-dm-gone`) and `dismissed` runs once
// with the DismissDirection. Delete / Backspace and Shift+arrow do the same
// from the keyboard.
((D) => {
  const SLOP = 8, FLING = 0.7, DIRS = ['startToEnd', 'endToStart', 'up', 'down'];
  const R = D.documentElement;
  const EDIT = 'input,textarea,select,[contenteditable]';
  let press = null, suppress = null;

  const rootOf = (n) => (n instanceof Element ? n.closest('[data-t-dm]') : null);
  const bodyOf = (root) => root.querySelector(':scope > [data-t-dm-body]');
  const rtl = (el) => getComputedStyle(el).direction === 'rtl';
  const calm = () => W.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
  // The setup: the axis and, per direction, its threshold (null: not allowed).
  const setup = (root) => {
    const a = (root.getAttribute('data-t-dm-cfg') ?? '').split('|');
    return { v: a[0] === 'v', t: DIRS.map((_, i) => (a[i + 1] == null || a[i + 1] === '-' ? null : parseFloat(a[i + 1]))), move: +a[5] || 0, resize: +a[6] || 0 };
  };
  // Where a movement of sign `s` along the axis goes: the vertical ones are
  // up/down, the horizontal ones follow the reading direction.
  const dirOf = (root, c, s) => (c.v ? (s > 0 ? 'down' : 'up') : s > 0 !== rtl(root) ? 'startToEnd' : 'endToStart');
  const signOf = (root, c, dir) => (c.v ? (dir === 'down' ? 1 : -1) : (dir === 'startToEnd') !== rtl(root) ? 1 : -1);
  const allowed = (c, dir) => c.t[DIRS.indexOf(dir)] != null;
  const px = (b, c, v) => b.style.setProperty(c.v ? '--t-dm-y' : '--t-dm-x', `${Math.round(v * 10) / 10}px`);
  // The room the body has to leave: its own size along the axis.
  const room = (b, c) => (c.v ? b.offsetHeight : b.offsetWidth);

  // Shows the backgrounds that are for `dir` (none: all hidden).
  function reveal(root, dir) {
    for (const bg of root.querySelectorAll(':scope > [data-t-dm-bg]')) bg.toggleAttribute('data-t-dm-on', !!dir && bg.getAttribute('data-t-dm-bg').split(' ').includes(dir));
  }

  // A state method of the row by id: its fixed argument, then `dir`; returns
  // what the method returns (the confirm asks for it).
  function call(root, id, dir) {
    const fn = fnOf(id, activate);
    if (!fn) return;
    const fixed = root.getAttribute('data-tx');
    return fn(fixed == null ? dir : `${fixed}~${dir}`);
  }

  // Sets a timer that takes "reduce motion" as no wait.
  const later = (fn, ms) => setTimeout(fn, calm() ? 20 : ms + 20);

  // Back to its place.
  function back(root, b, c) {
    b.setAttribute('data-t-dm-out', '');
    b.style.setProperty('--t-dm-x', '0px');
    b.style.setProperty('--t-dm-y', '0px');
    later(() => {
      b.removeAttribute('data-t-dm-out');
      if (!b.hasAttribute('data-t-dm-drag')) reveal(root, null);
    }, c.move);
  }

  // After a dismissal the focus goes to the next row (or the one before),
  // or it would fall to the page when the row is gone.
  function refocus(root) {
    if (!root.contains(D.activeElement) && D.activeElement !== root) return;
    for (const dir of ['nextElementSibling', 'previousElementSibling'])
      for (let s = root[dir]; s; s = s[dir])
        if (s.hasAttribute('data-t-dm') && !s.hasAttribute('data-t-dm-gone')) return s.focus({ preventScroll: true });
  }

  // Slides out, asks, collapses and tells the state.
  function leave(root, b, c, dir) {
    if (b.hasAttribute('data-t-dm-out') || root.hasAttribute('data-t-dm-gone')) return;
    const ids = parseOn(root.getAttribute('data-t-dm'));
    reveal(root, dir);
    b.removeAttribute('data-t-dm-drag');
    b.setAttribute('data-t-dm-out', '');
    b.style.setProperty(c.v ? '--t-dm-y' : '--t-dm-x', `${signOf(root, c, dir) * room(b, c)}px`);
    const dismiss = () => {
      if (!root.isConnected) return;
      refocus(root);
      const done = () => run(ids.dismissed, root, dir);
      if (c.resize) {
        root.setAttribute('data-t-dm-gone', '');
        later(done, c.resize);
      } else done();
    };
    const decide = (ok) => (ok === true ? dismiss() : root.isConnected && back(root, b, c));
    later(() => {
      if (!root.isConnected) return;
      if (!ids.confirm) return dismiss();
      let r;
      try {
        r = call(root, ids.confirm, dir);
      } catch (x) {
        fail(x);
      }
      if (r && typeof r.then === 'function') r.then(decide, (x) => (fail(x), decide(false)));
      else decide(r);
    }, c.move);
  }

  R.addEventListener('pointerdown', (e) => {
    if (e.button !== 0 && e.pointerType === 'mouse') return;
    const root = rootOf(e.target);
    const b = root && bodyOf(root);
    if (!b || !b.contains(e.target) || press || b.hasAttribute('data-t-dm-out') || root.hasAttribute('data-t-dm-gone')) return;
    // The text of a field is the field's.
    if (e.target.closest(EDIT)) return;
    press = { root, b, c: setup(root), id: e.pointerId, x: e.clientX, y: e.clientY, on: false, ext: 0, last: [] };
  });

  R.addEventListener('pointermove', (e) => {
    const p = press;
    if (!p || e.pointerId !== p.id) return;
    const dx = e.clientX - p.x, dy = e.clientY - p.y;
    if (!p.on) {
      if (Math.hypot(dx, dy) < SLOP) return;
      // Movement along the other axis is the page's (a scroll).
      if ((Math.abs(dx) >= Math.abs(dy)) === p.c.v) {
        press = null;
        return;
      }
      p.on = true;
      p.b.setAttribute('data-t-dm-drag', '');
      p.b.removeAttribute('data-t-dm-out');
      try {
        p.b.setPointerCapture(e.pointerId);
      } catch {
        // A pointer the browser no longer tracks.
      }
      suppress = p.root;
    }
    let d = p.c.v ? dy : dx;
    // A direction that is not allowed does not move.
    if (d && !allowed(p.c, dirOf(p.root, p.c, d))) d = 0;
    p.ext = d;
    px(p.b, p.c, d);
    reveal(p.root, d ? dirOf(p.root, p.c, d) : null);
    const now = performance.now();
    p.last.push([now, d]);
    while (p.last.length > 1 && now - p.last[0][0] > 100) p.last.shift();
  });

  R.addEventListener('pointerup', (e) => {
    const p = press;
    if (!p || e.pointerId !== p.id) return;
    press = null;
    if (!p.on) return;
    // The click of this drag (if the browser sends one) comes right after.
    const el = p.root;
    setTimeout(() => suppress === el && (suppress = null), 60);
    const { root, b, c } = p, d = p.ext;
    b.removeAttribute('data-t-dm-drag');
    if (!d) return back(root, b, c);
    const dir = dirOf(root, c, d), size = room(b, c) || 1;
    const [t0, d0] = p.last[0], dt = Math.max(performance.now() - t0, 16);
    const speed = (d - d0) / dt;
    const far = Math.abs(d) >= c.t[DIRS.indexOf(dir)] * size || (Math.abs(speed) >= FLING && Math.sign(speed) === Math.sign(d));
    if (far) leave(root, b, c, dir);
    else back(root, b, c);
  });

  R.addEventListener('pointercancel', (e) => {
    const p = press;
    if (!p || e.pointerId !== p.id) return;
    press = null;
    suppress = null;
    if (!p.on) return;
    p.b.removeAttribute('data-t-dm-drag');
    back(p.root, p.b, p.c);
  });

  // A drag that moved must not also click.
  R.addEventListener(
    'click',
    (e) => {
      const el = suppress;
      if (!el) return;
      suppress = null;
      if (e.target instanceof Node && el.contains(e.target)) {
        e.stopImmediatePropagation();
        e.preventDefault();
      }
    },
    true,
  );

  // The browser's own drag of an image or a link must not start one.
  R.addEventListener('dragstart', (e) => press?.on && e.preventDefault());

  // The keyboard's way (WCAG 2.5.1): Delete / Backspace dismisses the row
  // the focus is in (toward the start of the line, or whichever direction is
  // the only one); Shift+arrow along the axis picks the direction.
  R.addEventListener('keydown', (e) => {
    const root = rootOf(e.target);
    if (!root || e.defaultPrevented || e.altKey || e.ctrlKey || e.metaKey) return;
    if (e.target.closest(EDIT) || e.target.isContentEditable) return;
    const b = bodyOf(root);
    if (!b) return;
    const c = setup(root), k = e.key;
    let dir;
    if ((k === 'Delete' || k === 'Backspace') && !e.shiftKey) dir = ['endToStart', 'startToEnd', 'up', 'down'].find((d) => allowed(c, d));
    else if (e.shiftKey && k.startsWith('Arrow') && (k === 'ArrowUp' || k === 'ArrowDown') === c.v) {
      dir = dirOf(root, c, k === 'ArrowRight' || k === 'ArrowDown' ? 1 : -1);
      if (!allowed(c, dir)) dir = null;
    }
    if (!dir) return;
    e.preventDefault();
    leave(root, b, c, dir);
  });
})(document);
