// thor-lite part "gestures": thor_ui's `Gesture` (`data-tg`): double tap,
// long press, swipe, drag and pinch, with mouse, touch and pen (the dart2js
// engine's GesturesFeature).
//
// While a gesture runs no state changes: the element follows the pointer
// through CSS variables (`--tg-x`, `--tg-y`, `--tg-s`) its own class maps
// to translate/scale. On release the state's method runs once, with the
// result. A drag with `onDragUpdate` (`dragu`) is the exception: the state
// follows the pointer, at most once per animation frame.
((D) => {
  const SLOP = 8, LONG = 500, DOUBLE = 300, FLING = 0.6;
  const CONTROLS = 'input,button,select,textarea,a[href],label,summary';
  const R = D.documentElement;
  let press = null, suppress = null, lastTap = null, lastAt = 0, lastLong = null, longAt = 0;

  const num = (s) => {
    const n = parseFloat(s);
    return Number.isNaN(n) ? null : n;
  };
  const setup = (el, a) => (el.getAttribute(a) ?? '').split('|');
  const cssVar = (el, n, f) => {
    const v = el.style.getPropertyValue(n);
    return v ? num(v) ?? f : f;
  };
  // v with at most `d` decimals, no trailing zeros (Dart's round: half
  // away from zero).
  const round = (v, d = 1) => {
    const f = 10 ** d, x = v * f;
    return `${(x < 0 ? -Math.round(-x) : Math.round(x)) / f}`;
  };
  const tenth = (v) => {
    const x = v * 10;
    return (x < 0 ? -Math.round(-x) : Math.round(x)) / 10;
  };
  const set = (el, n, v, unit) => el.style.setProperty(n, `${round(v, unit == null ? 2 : 1)}${unit ?? ''}`);
  const target = (e) => (e.target instanceof Element ? e.target.closest('[data-tg]') : null);
  const spec = (el) => parseOn(el.getAttribute('data-tg') ?? '');
  // A point of the viewport relative to the element's top-left corner, as
  // the `x~y` argument of a state method (Flutter's `localPosition`, in CSS
  // pixels).
  const local = (el, x, y) => {
    const r = el.getBoundingClientRect();
    return `${round(x - r.left)}~${round(y - r.top)}`;
  };
  // Flutter's `DragEndDetails` (a `GestureDetector.onPanEnd`, the drag's 4th
  // setup field is `1`): the release velocity in px/s from the pointer's
  // last 100 ms (the release itself is the last sample, so a pause before
  // letting go reads as no speed), clamped to Flutter's 8000, then the
  // pointer's local and viewport positions, `vx~vy~lx~ly~gx~gy`. The local
  // position is from where the element rests: a drag that follows the
  // finger (and snaps back) has its translate taken out, since Flutter's
  // widget never moved.
  const rest = (el) => {
    const r = el.getBoundingClientRect();
    return [r.left - cssVar(el, '--tg-x', 0), r.top - cssVar(el, '--tg-y', 0), r.width, r.height];
  };
  const track = (p, e) => {
    p.trail.push([performance.now(), e.clientX, e.clientY]);
    if (p.trail.length > 24) p.trail.shift();
  };
  const ended = (p, e) => {
    const t = performance.now();
    const first = p.trail.find((s) => t - s[0] <= 100);
    const dt = first ? t - first[0] : 0;
    const v = (a, b) => (dt > 0 ? Math.max(-8000, Math.min(8000, ((a - b) / dt) * 1000)) : 0);
    const vx = first ? v(e.clientX, first[1]) : 0, vy = first ? v(e.clientY, first[2]) : 0;
    const [left, top] = rest(p.el);
    return [vx, vy, e.clientX - left, e.clientY - top, e.clientX, e.clientY].map((n) => round(n)).join('~');
  };
  const distance = (p) => {
    const pts = [...p.ptrs.values()];
    if (pts.length < 2) return 0;
    return Math.hypot(pts[0][0] - pts[1][0], pts[0][1] - pts[1][1]);
  };

  // Where a swipe went. `d` > 0 is toward the physical right/bottom. A
  // horizontal swipe is `start`/`end` by the element's direction (RTL flips
  // them).
  function dirOf(el, h, d) {
    if (!h) return d > 0 ? 'down' : 'up';
    return d > 0 !== (getComputedStyle(el).direction === 'rtl') ? 'end' : 'start';
  }

  // A long press once: the timer, the browser's own contextmenu (Android
  // sends it around the same time, sometimes after a pointercancel) and a
  // right click are one request, however they interleave.
  function fireLong(el, id) {
    const now = performance.now();
    if (lastLong === el && now - longAt < 300) return;
    lastLong = el;
    longAt = now;
    suppress = el;
    run(id, el);
  }

  function release(el, x, y, s) {
    el.setAttribute('data-tg-release', '');
    if (x != null) set(el, '--tg-x', x, 'px');
    if (y != null) set(el, '--tg-y', y, 'px');
    if (s != null) set(el, '--tg-s', s);
    setTimeout(() => el.removeAttribute('data-tg-release'), 260);
  }

  function begin(p, id) {
    p.el.setAttribute('data-tg-active', '');
    p.el.removeAttribute('data-tg-release');
    if (id != null) {
      try {
        p.el.setPointerCapture(id);
      } catch {
        // A pointer the browser no longer tracks.
      }
    }
    suppress = p.el;
  }

  function flush(p) {
    const id = p.spec.dragu;
    if (!id) return;
    const dx = tenth(p.lx - p.sx), dy = tenth(p.ly - p.sy);
    if (dx === 0 && dy === 0) return;
    p.sx += dx;
    p.sy += dy;
    run(id, p.el, `${round(dx)}~${round(dy)}`);
  }

  const cancelFrame = (p) => {
    if (p.frame != null) cancelAnimationFrame(p.frame);
    p.frame = null;
  };

  function swiped(el, id, dir, dismiss, h, sign) {
    // Already on its way out (a held key repeats): dismissed once.
    if (dismiss && el.hasAttribute('data-tg-out')) return;
    if (!dismiss) {
      release(el, 0, 0);
      run(id, el, dir);
      return;
    }
    const size = h ? el.offsetWidth : el.offsetHeight;
    el.setAttribute('data-tg-out', '');
    release(el, h ? sign * size * 1.2 : null, h ? null : sign * size * 1.2);
    setTimeout(() => run(id, el, dir), 200);
  }

  R.addEventListener('pointerdown', (e) => {
    if (e.button !== 0 && e.pointerType === 'mouse') return;
    const el = target(e);
    if (!el) return;
    const p0 = press;
    if (p0 && p0.el === el) {
      // A second finger on the same element: pinch.
      p0.ptrs.set(e.pointerId, [e.clientX, e.clientY]);
      if (p0.ptrs.size === 2 && 'scale' in p0.spec) {
        p0.mode = 'pinch';
        p0.d0 = distance(p0);
        p0.s = cssVar(el, '--tg-s', 1);
        clearTimeout(p0.long);
        begin(p0);
      }
      return;
    }
    const s = spec(el);
    const p = { el, spec: s, x: e.clientX, y: e.clientY, t: performance.now(), ptrs: new Map(), mode: null, dx: 0, dy: 0, sx: 0, sy: 0, lx: 0, ly: 0, frame: null, long: null, fired: false, trail: [[performance.now(), e.clientX, e.clientY]] };
    p.ptrs.set(e.pointerId, [p.x, p.y]);
    const c = e.target.closest(CONTROLS);
    p.ctl = !!c && c !== el && el.contains(c);
    press = p;
    // `onTapDown`: where the pointer went down (a tap on a native control
    // inside is that control's).
    if (s.tapd && !p.ctl) run(s.tapd, el, local(el, p.x, p.y));
    if (s.long) {
      p.long = setTimeout(() => {
        if (press !== p || p.mode) return;
        p.fired = true;
        fireLong(el, s.long);
      }, LONG);
    }
  });

  R.addEventListener('pointermove', (e) => {
    const p = press;
    if (!p || !p.ptrs.has(e.pointerId)) return;
    p.ptrs.set(e.pointerId, [e.clientX, e.clientY]);
    track(p, e);
    if (p.mode === 'pinch') {
      // One finger left: the scale rests where it was.
      if (p.ptrs.size < 2) return;
      const st = setup(p.el, 'data-tg-scale');
      const min = num(st[0]) ?? 1, max = num(st[1] ?? '') ?? 4;
      set(p.el, '--tg-s', Math.min(Math.max((p.s * distance(p)) / Math.max(p.d0, 1), min), max));
      return;
    }
    const dx = e.clientX - p.x, dy = e.clientY - p.y;
    if (!p.mode) {
      if (Math.sqrt(dx * dx + dy * dy) < SLOP) return;
      clearTimeout(p.long);
      const h = Math.abs(dx) >= Math.abs(dy);
      const sw = 'swipe' in p.spec ? setup(p.el, 'data-tg-swipe')[0] : null;
      const dr = 'drag' in p.spec || 'dragu' in p.spec ? setup(p.el, 'data-tg-drag')[0] : null;
      if (sw != null && (sw === 'h') === h) p.mode = 'swipe';
      else if (dr != null && (dr === 'f' || (dr === 'h') === h)) {
        p.mode = 'drag';
        p.dx = cssVar(p.el, '--tg-x', 0);
        p.dy = cssVar(p.el, '--tg-y', 0);
      } else {
        // Movement this element doesn't handle (a vertical scroll).
        press = null;
        return;
      }
      begin(p, e.pointerId);
    }
    if (p.mode === 'swipe') {
      const h = setup(p.el, 'data-tg-swipe')[0] === 'h';
      set(p.el, h ? '--tg-x' : '--tg-y', h ? dx : dy, 'px');
    } else {
      const axis = setup(p.el, 'data-tg-drag')[0];
      if ('dragu' in p.spec) {
        p.lx = axis === 'v' ? 0 : dx;
        p.ly = axis === 'h' ? 0 : dy;
        p.frame ??= requestAnimationFrame(() => {
          p.frame = null;
          flush(p);
        });
        return;
      }
      if (axis !== 'v') set(p.el, '--tg-x', p.dx + dx, 'px');
      if (axis !== 'h') set(p.el, '--tg-y', p.dy + dy, 'px');
    }
  });

  R.addEventListener('pointerup', (e) => {
    const p = press;
    if (!p || !p.ptrs.has(e.pointerId)) return;
    p.ptrs.delete(e.pointerId);
    if (p.mode === 'pinch' && p.ptrs.size) return;
    press = null;
    clearTimeout(p.long);
    p.el.removeAttribute('data-tg-active');
    // The click of this gesture (if the browser sends one) comes right
    // after the pointerup; a touch that moved never gets one, and the flag
    // must not wait for the next tap to swallow it.
    if (suppress === p.el) {
      const el = p.el;
      setTimeout(() => {
        if (suppress === el) suppress = null;
      }, 60);
    }
    const dx = e.clientX - p.x, dy = e.clientY - p.y;
    const dt = Math.max(performance.now() - p.t, 1);
    if (!p.mode) {
      if (p.fired) return;
      if (p.ctl) {
        lastTap = null;
        return;
      }
      if (p.spec.tapu) run(p.spec.tapu, p.el, local(p.el, e.clientX, e.clientY));
      const id = p.spec.dtap;
      if (!id) return;
      const now = performance.now();
      if (lastTap === p.el && now - lastAt < DOUBLE) {
        lastTap = null;
        run(id, p.el);
      } else {
        lastTap = p.el;
        lastAt = now;
      }
    } else if (p.mode === 'swipe') {
      const st = setup(p.el, 'data-tg-swipe');
      const h = st[0] === 'h', dismiss = st[1] === '1', threshold = num(st[2] ?? '') ?? 0.4;
      const d = h ? dx : dy, size = h ? p.el.offsetWidth : p.el.offsetHeight;
      if (!(Math.abs(d) >= threshold * size || Math.abs(d) / dt >= FLING)) return release(p.el, 0, 0);
      swiped(p.el, p.spec.swipe, dirOf(p.el, h, d), dismiss, h, Math.sign(d));
    } else if (p.mode === 'drag') {
      const st = setup(p.el, 'data-tg-drag'), axis = st[0], snap = st[1] === '1';
      const mx = axis === 'v' ? 0 : dx, my = axis === 'h' ? 0 : dy;
      // Measured before the snap back moves the element.
      const end = st[3] === '1' ? ended(p, e) : `${round(mx)}~${round(my)}`;
      if ('dragu' in p.spec) {
        // The last moves reach the state before the release does.
        cancelFrame(p);
        p.lx = mx;
        p.ly = my;
        flush(p);
      } else if (snap) release(p.el, 0, 0);
      if (p.spec.drag) run(p.spec.drag, p.el, end);
    } else {
      const st = setup(p.el, 'data-tg-scale');
      const s = cssVar(p.el, '--tg-s', 1);
      if (st[2] === '1') release(p.el, null, null, 1);
      run(p.spec.scale, p.el, round(s, 2));
    }
  });

  // The browser took the touch (a scroll, a system gesture) or the pointer
  // is gone: no result, everything back in place, and no click to swallow.
  // Another finger's cancel is not this press's.
  R.addEventListener('pointercancel', (e) => {
    const p = press;
    if (!p || !p.ptrs.has(e.pointerId)) return;
    press = null;
    suppress = null;
    clearTimeout(p.long);
    cancelFrame(p);
    p.el.removeAttribute('data-tg-active');
    if (p.mode) release(p.el, 0, 0, p.mode === 'pinch' ? p.s : null);
  });

  // Right click or the context-menu key: a long press.
  R.addEventListener('contextmenu', (e) => {
    const el = target(e);
    const id = el && spec(el).long;
    if (!id) return;
    e.preventDefault();
    if (press?.el === el) {
      // The hold is now the browser's: the timer must not fire it again.
      clearTimeout(press.long);
      press.fired = true;
    }
    fireLong(el, id);
  });

  // A gesture that moved (or a long press) must not also click.
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

  // Keyboard alternatives: Delete dismisses, Shift+arrows swipe, arrows drag,
  // +/- zoom.
  R.addEventListener('keydown', (e) => {
    const el = e.target;
    if (!(el instanceof HTMLElement) || !el.hasAttribute('data-tg')) return;
    // A text field (or an editable element) that is the gesture keeps its
    // keys: Shift+arrow selects, Delete and Backspace erase.
    if (el.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(el.tagName)) return;
    const s = spec(el), k = e.key;
    // Enter/Space on the focused element is a tap in its middle.
    if ((k === 'Enter' || k === ' ') && e.target === el && s.tapu) {
      e.preventDefault();
      run(s.tapu, el, `${round(el.offsetWidth / 2)}~${round(el.offsetHeight / 2)}`);
      return;
    }
    if ((k === 'Delete' || k === 'Backspace') && s.swipe) {
      const st = setup(el, 'data-tg-swipe');
      if (st[1] === '1') {
        e.preventDefault();
        const h = st[0] === 'h';
        // Toward the start of the line (the physical left in RTL text is its end).
        const sign = h && getComputedStyle(el).direction === 'rtl' ? 1 : -1;
        swiped(el, s.swipe, dirOf(el, h, sign), true, h, sign);
      }
      return;
    }
    // The keyboard's swipe (WCAG 2.5.1 and 2.1.1: a path gesture needs a
    // single-key way): Shift+arrow along the swipe's axis, with or without
    // `dismiss`. A plain arrow is left to reading and scrolling.
    if (e.shiftKey && !e.altKey && !e.ctrlKey && !e.metaKey && k.startsWith('Arrow') && s.swipe) {
      const st = setup(el, 'data-tg-swipe'), h = st[0] === 'h';
      const d = h ? (k === 'ArrowRight' ? 1 : k === 'ArrowLeft' ? -1 : 0) : k === 'ArrowDown' ? 1 : k === 'ArrowUp' ? -1 : 0;
      if (d) {
        e.preventDefault();
        swiped(el, s.swipe, dirOf(el, h, d), st[1] === '1', h, d);
        return;
      }
    }
    if (k.startsWith('Arrow') && (s.drag || s.dragu)) {
      const st = setup(el, 'data-tg-drag'), axis = st[0], step = num(st[2] ?? '') ?? 10;
      const [dx, dy] =
        k === 'ArrowLeft' && axis !== 'v' ? [-step, 0]
        : k === 'ArrowRight' && axis !== 'v' ? [step, 0]
        : k === 'ArrowUp' && axis !== 'h' ? [0, -step]
        : k === 'ArrowDown' && axis !== 'h' ? [0, step]
        : [0, 0];
      if (dx === 0 && dy === 0) return;
      e.preventDefault();
      const moved = `${round(dx)}~${round(dy)}`;
      if (s.dragu) run(s.dragu, el, moved);
      else if (st[1] !== '1') {
        set(el, '--tg-x', cssVar(el, '--tg-x', 0) + dx, 'px');
        set(el, '--tg-y', cssVar(el, '--tg-y', 0) + dy, 'px');
      }
      if (s.drag) {
        // A key has no velocity: the details are at the element's center.
        const [left, top, w, h] = rest(el);
        run(s.drag, el, st[3] === '1' ? `0~0~${round(w / 2)}~${round(h / 2)}~${round(left + w / 2)}~${round(top + h / 2)}` : moved);
      }
      return;
    }
    if ((k === '+' || k === '=' || k === '-') && s.scale) {
      const st = setup(el, 'data-tg-scale');
      const min = num(st[0]) ?? 1, max = num(st[1] ?? '') ?? 4, step = num(st[3] ?? '') ?? 0.25;
      const v = Math.min(Math.max(cssVar(el, '--tg-s', 1) + (k === '-' ? -step : step), min), max);
      e.preventDefault();
      set(el, '--tg-s', v);
      run(s.scale, el, round(v, 2));
    }
  });
})(document);
