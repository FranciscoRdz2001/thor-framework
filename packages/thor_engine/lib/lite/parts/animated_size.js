// thor-lite part "animated_size": thor_ui's `AnimatedSize` and
// `AnimatedCrossFade` (`data-tsz="<ms>|<easing>|<ms shrinking>"`): a
// clipping element whose only child measures the content. CSS cannot
// animate `auto` -> `auto`, so the size is animated after the fact, the way
// Flutter's RenderAnimatedSize does it in layout and Motion / AutoAnimate
// do it with FLIP: a ResizeObserver on the measuring element, then the
// Web Animations API from the height the shell has to the new one. A change
// in the middle of an animation starts from the current height (the
// observer sees the content, not the animated shell); prefers-reduced-motion
// and no JS both just let the size follow the content. With `|w` as the
// fourth field the width follows too (the measuring element then has the
// content's own width, so animating the shell does not feed back into it).
// A `transitionend` fires on the shell when the animation finishes: that is
// what `onEnd` listens to.
(() => {
  const A = 'data-tsz';
  const seen = new WeakSet(), state = new WeakMap();
  const rect = (el) => el.getBoundingClientRect();
  const end = (el) => el.dispatchEvent(new Event('transitionend', { bubbles: true }));

  const ro = new ResizeObserver((entries) => {
    for (const e of entries) follow(e.target);
  });

  function follow(inner) {
    const s = state.get(inner);
    if (!s) return;
    const el = s.el;
    // Not rendered (a hidden tab, a closed details): its size is unknown, not
    // zero, so showing it later is not a growth from nothing.
    if (inner.getClientRects().length === 0) {
      s.anim?.cancel();
      s.anim = null;
      s.h = -1;
      return;
    }
    const r = rect(inner), h = r.height, w = r.width;
    if (s.h < 0) {
      s.h = h;
      s.w = w;
      return;
    }
    const [ms, easing, back, axis] = (el.getAttribute(A) ?? '').split('|');
    const both = axis === 'w';
    if (Math.abs(h - s.h) < 0.5 && !(both && Math.abs(w - s.w) >= 0.5)) return;
    // Before cancelling: without the animation the shell is at `h` already.
    const now = s.anim ? rect(el) : null;
    const from = now ? now.height : s.h, fromW = now ? now.width : s.w;
    s.anim?.cancel();
    s.anim = null;
    s.h = h;
    s.w = w;
    const same = Math.abs(from - h) < 0.5 && !(both && Math.abs(fromW - w) >= 0.5);
    if (!el.isConnected || same) return;
    if (matchMedia('(prefers-reduced-motion: reduce)').matches) return end(el);
    const duration = Number(h < from && !(both && w > fromW) ? back : ms);
    if (!(duration > 0)) return end(el);
    const a = el.animate(
      [
        { height: `${from}px`, ...(both && { width: `${fromW}px` }) },
        { height: `${h}px`, ...(both && { width: `${w}px` }) },
      ],
      { duration, easing: easing || 'linear' },
    );
    s.anim = a;
    a.onfinish = () => {
      if (s.anim === a) s.anim = null;
      end(el);
    };
    a.oncancel = () => {
      if (s.anim === a) s.anim = null;
    };
  }

  function watch() {
    for (const el of D.querySelectorAll(`[${A}]`)) {
      const inner = el.firstElementChild;
      if (!inner || seen.has(el)) continue;
      seen.add(el);
      // The size now, read before anything changes it: the change that wakes
      // the engine may land before the observer's first report.
      const shown = inner.getClientRects().length > 0;
      state.set(inner, { el, h: shown ? rect(inner).height : -1, w: shown ? rect(inner).width : -1, anim: null });
      ro.observe(inner);
    }
  }

  watch();
  // Elements the page gained (a replaced subtree, a row): found when a state wakes.
  scanParts.push(watch);
  D.addEventListener('thor:hydrated', watch);
})();
