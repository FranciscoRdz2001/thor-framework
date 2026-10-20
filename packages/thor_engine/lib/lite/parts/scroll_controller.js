// thor-lite part "scroll_controller": ScrollController (needs "controllers").
//
// The element scrolls natively; the controller follows it and moves it.
// `animateTo(offset, duration, easing)` runs over the duration along the
// curve's CSS easing (instant under reduced motion), and its promise ends
// when it arrives or the visitor, a `jumpTo` or another `animateTo` moves it. `initialScrollOffset` is applied when a
// view shows up, unless that view is already scrolled (a restored offset
// wins). Offsets are along the axis from its start, so a horizontal view in
// RTL or `row-reverse` (negative `scrollLeft`, like a `column-reverse` one's
// `scrollTop`) still reads 0 at its start.
((T, D) => {
  const { all, find, of, on } = T.ctl;
  const INPUT = ['wheel', 'touchstart', 'pointerdown', 'keydown'];
  const hor = (el) => el.hasAttribute('data-tsc-h');
  const sign = (el) => {
    const s = getComputedStyle(el), h = hor(el);
    const rev = s.display.endsWith('flex') && s.flexDirection === (h ? 'row-reverse' : 'column-reverse');
    return ((h && s.direction === 'rtl') !== rev) ? -1 : 1;
  };
  const get = (el) => (hor(el) ? el.scrollLeft : el.scrollTop) * sign(el);
  const put = (el, v) => (hor(el) ? (el.scrollLeft = v * sign(el)) : (el.scrollTop = v * sign(el)));
  const room = (el) => (hor(el) ? el.scrollWidth - el.clientWidth : el.scrollHeight - el.clientHeight);
  const size = (el) => (hor(el) ? el.clientWidth : el.clientHeight);
  // A view with no size (hidden: a closed tab, `display: none`) cannot be moved: `fn(el)` runs
  // each time it is measured until it answers true (or the view leaves the page).
  const waits = new Map();
  let ro;
  T.ctl.sized = (el, fn) => {
    if (typeof ResizeObserver !== 'function') return;
    ro ||= new ResizeObserver((es) => {
      for (const { target } of es) {
        const f = waits.get(target);
        if (f && (!target.isConnected || f(target))) (waits.delete(target), ro.unobserve(target));
      }
    });
    waits.has(el) || ro.observe(el);
    waits.set(el, fn);
  };
  class Scroll {
    constructor(id, offset = 0) {
      all[(this.id = id)] = this;
      this.p = T.signal(offset);
      this.vd = T.signal(0);
      this.mx = T.signal(0);
      this.w = offset || null; // asked for while no view was there
      const el = find('data-tsc', id);
      if (el) this.at(el);
    }
    get offset() {
      return this.p.value;
    }
    get position() {
      return this;
    }
    get pixels() {
      return this.p.value;
    }
    get viewportDimension() {
      return this.vd.value;
    }
    get maxScrollExtent() {
      return this.mx.value;
    }
    // Not reactive (Flutter's isn't): is the view in the page now.
    get hasClients() {
      return !!find('data-tsc', this.id);
    }
    jumpTo(v) {
      this.res?.();
      const el = find('data-tsc', this.id);
      if (!el) return void ((this.p.value = this.w = Math.max(0, v)));
      put(el, v);
      this.me(el);
    }
    // A frame loop (the browser has no animation of an offset): the easing is
    // evaluated by the browser, from an animation paused at each frame's
    // time; the snap points are off while it runs; the visitor's wheel,
    // touch, pointer or key (or anything else that moves the view, or takes
    // it out of the page) ends it where it is. `dur` is a Duration (300 ms
    // without one) and `ease` the CSS easing of the curve.
    animateTo(v, dur, ease) {
      this.res?.();
      const el = find('data-tsc', this.id);
      const to = Math.max(0, Math.min(v, el ? room(el) : v));
      const ms = dur ? dur.us / 1000 : 300, from = el ? get(el) : 0;
      // (`!(… >= 1)`: NaN jumps too.)
      if (!el || matchMedia('(prefers-reduced-motion: reduce)').matches || !(ms > 0) || !(Math.abs(from - to) >= 1)) {
        this.jumpTo(to);
        return Promise.resolve();
      }
      return new Promise((ok) => {
        const snap = el.style.scrollSnapType, sg = sign(el), t0 = performance.now(), horizontal = hor(el);
        const clock = new Animation(new KeyframeEffect(null, null, { duration: ms, easing: ease || 'linear', fill: 'both' }));
        clock.pause();
        el.style.scrollSnapType = 'none';
        // Every frame's jump ends its own scroll (`scrollend`): the PageView
        // reports the page when the whole run is over.
        el.thorMoving = 1;
        let last = from, id, tm;
        const put = (x) => el.scrollTo({ [horizontal ? 'left' : 'top']: x * sg, behavior: 'instant' });
        const end = (fin) => {
          cancelAnimationFrame(id);
          clearTimeout(tm);
          for (const t of INPUT) el.removeEventListener(t, stop);
          clock.cancel();
          el.style.scrollSnapType = snap;
          el.thorMoving = 0;
          this.res = null;
          if (fin) put(to);
          this.me(el);
          // The jumps' own `scrollend`s were not reported (a PageView waits
          // for the end of the run): this one is.
          el.dispatchEvent(new Event('scrollend'));
          ok();
        };
        const stop = () => end(0);
        for (const t of INPUT) el.addEventListener(t, stop, { passive: true });
        this.res = stop;
        // A hidden tab runs no frames: the scroll still ends.
        tm = setTimeout(() => end(1), ms + 1000);
        const frame = (now) => {
          if (!el.isConnected || Math.abs(get(el) - last) > 2) return end(0);
          clock.currentTime = Math.min(now - t0, ms);
          last = Math.max(0, Math.min(from + (to - from) * (clock.effect.getComputedTiming().progress ?? 1), room(el)));
          put(last);
          now - t0 >= ms ? end(1) : (id = requestAnimationFrame(frame));
        };
        id = requestAnimationFrame(frame);
      });
    }
    // A view of this controller is there (at load, or a copy replaced it).
    at(el) {
      this.res?.(); // an animation on the view that is gone ends
      if (D.querySelectorAll(`[data-tsc="${this.id}"]`).length > 1) {
        throw Error(`thor: the ScrollController ${this.id} is attached to more than one scroll view; a controller drives one`);
      }
      if (this.w != null) {
        if (size(el)) {
          get(el) || put(el, this.w);
          this.w = null;
        } else
          // Asked for while the view is hidden: it starts there when it is shown.
          T.ctl.sized(el, (e) => (find('data-tsc', this.id) === e ? (this.at(e), this.w == null) : true));
      }
      this.me(el);
    }
    // The element scrolled or was measured.
    me(el) {
      T.batch(() => {
        this.p.value = get(el);
        this.vd.value = hor(el) ? el.clientWidth : el.clientHeight;
        this.mx.value = room(el);
      });
    }
  }
  // Scroll events don't bubble: one capturing, passive listener sees them all.
  on(
    'scroll',
    (e) => {
      const c = of('data-tsc', e.target);
      if (c instanceof Scroll) c.me(e.target);
    },
    { capture: true, passive: true },
  );
  // A copy of server markup replaced a subtree, or a late part (`thor:stream`:
  // a `FutureBuilder`, a `LazyPiece`) brought some: the views in it belong to the controllers.
  const attach = (el) => {
    for (const e of [el, ...el.querySelectorAll('[data-tsc]')]) {
      const c = all[e.getAttribute?.('data-tsc')];
      if (c instanceof Scroll) c.at(e);
    }
  };
  on('thor:adopted', (e) => attach(e.target), true);
  on('thor:stream', (e) => {
    for (const el of e.detail?.nodes || []) if (el.nodeType === 1) attach(el);
  });
  addEventListener('resize', () => {
    for (const id in all) {
      const c = all[id], el = c instanceof Scroll && find('data-tsc', id);
      if (el) c.me(el);
    }
  });

  T.ctl.scroll = (id, offset) => new Scroll(id, offset);
})(thor, document);
