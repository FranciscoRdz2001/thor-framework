// thor-lite part "drag_kit": what thor_ui's Draggable / DragTarget and
// ReorderableListView share (the dart2js engine's drag_kit.dart): the live
// region that says what a keyboard drag does, the page scrolling while the
// pointer is near an edge, and the way a state method is called with the
// row's fixed argument and what it returns.
((T, D) => {
  // Words with `{item}` and `{target}` filled in, said by a live region the
  // first announcement creates (visually hidden, assertive: each step of a
  // keyboard drag replaces the one before).
  let live, said;
  const say = (text) => {
    if (!live) {
      live = D.createElement('div');
      live.setAttribute('aria-live', 'assertive');
      live.setAttribute('aria-atomic', 'true');
      live.style.cssText = 'position:fixed;width:1px;height:1px;margin:-1px;padding:0;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap;border:0';
      D.body.append(live);
    }
    // The same words twice are read twice: empty it first.
    live.textContent = '';
    clearTimeout(said);
    said = setTimeout(() => (live.textContent = text), 30);
  };

  // The name of an element for a screen reader: its label, or its text.
  const name = (el) => (el.getAttribute('aria-label') || el.textContent.replace(/\s+/g, ' ').trim()).slice(0, 80);

  const fill = (text, item, target) => text.replaceAll('{item}', item ?? '').replaceAll('{target}', target ?? '');

  // The words of an element: its attribute `attr` (a line each) over the English ones.
  const words = (el, attr, fallback) => {
    const mine = el.getAttribute(attr);
    return mine == null ? fallback : mine.split('\n');
  };

  // A part of a multi-argument value (`<fixed>~<part>~…`): `%` and `~` escaped.
  const esc = (s) => s.replace(/%/g, '%25').replace(/~/g, '%7E');

  // A state method by id with the element's fixed argument and `value`;
  // returns what the method returns (a confirmation, a `bool`).
  function call(el, id, value) {
    const fn = fnOf(id, activate);
    if (!fn) return;
    const fixed = el.getAttribute('data-tx');
    return fn(fixed == null ? value ?? null : value == null ? fixed : `${fixed}~${value}`);
  }

  // Reduced motion: nothing animated.
  const calm = () => W.matchMedia?.('(prefers-reduced-motion: reduce)').matches;

  // Scrolls the container under the pointer (the nearest one that can scroll
  // that way) or the page while the pointer is within EDGE px of its edge,
  // up to MAX px per frame. `where()` gives the pointer's [x, y]; returns
  // the function that stops it.
  const EDGE = 56, MAX = 18;
  const room = (el, h) => (h ? el.scrollWidth > el.clientWidth : el.scrollHeight > el.clientHeight);
  const scrolls = (el, h) => /auto|scroll/.test(getComputedStyle(el)[h ? 'overflowX' : 'overflowY']) && room(el, h);
  // How far to go, along one axis, for a pointer at `p` in [lo, hi].
  const speed = (p, lo, hi) => (p < lo + EDGE ? -Math.ceil((MAX * (lo + EDGE - p)) / EDGE) : p > hi - EDGE ? Math.ceil((MAX * (p - (hi - EDGE))) / EDGE) : 0);
  function autoscroll(where) {
    let frame = 0, on = true;
    const step = () => {
      if (!on) return;
      const [x, y] = where();
      let moved = false;
      for (let el = D.elementFromPoint(x, y); el && !moved && el !== D.body && el !== D.documentElement; el = el.parentElement) {
        const r = el.getBoundingClientRect();
        for (const h of [false, true]) {
          if (!scrolls(el, h)) continue;
          const v = h ? speed(x, r.left, r.right) : speed(y, r.top, r.bottom);
          if (!v) continue;
          const before = h ? el.scrollLeft : el.scrollTop;
          if (h) el.scrollLeft += v;
          else el.scrollTop += v;
          if ((h ? el.scrollLeft : el.scrollTop) !== before) moved = true;
        }
      }
      if (!moved) {
        const v = speed(y, 0, R_h()), h = speed(x, 0, R_w());
        if (v || h) scrollBy(h, v);
      }
      frame = requestAnimationFrame(step);
    };
    const R_w = () => D.documentElement.clientWidth, R_h = () => D.documentElement.clientHeight;
    frame = requestAnimationFrame(step);
    return () => {
      on = false;
      cancelAnimationFrame(frame);
    };
  }

  // A draggable fits a target when the type does: `Object` and `dynamic`
  // take all, `num` an int or a double.
  const fits = (target, drag) => target === drag || /^(Object\??|dynamic)$/.test(target) || (target === 'num' && (drag === 'int' || drag === 'double'));

  T.dnd = { say, name, fill, words, esc, call, calm, autoscroll, fits };
})(thor, document);
