// thor-lite part "animated_list": the rows of an `AnimatedList` that enter
// and leave (the list container has `data-tlx` = ms a row takes to leave).
// A row that leaves stays, marked `data-tlo` and inert, for that long, so the
// CSS transitions the server wrote run to their start; the rows added by the
// browser carry `data-tli` (from the template) until they have appeared, which
// is what the `@starting-style` of those transitions waits for.
(() => {
  rowParts.push((c) => {
    const ms = +c.el.getAttribute('data-tlx');
    if (!ms) return;
    const prev = c.a;
    c.x = (r) => {
      const e = r.el;
      if (matchMedia('(prefers-reduced-motion: reduce)').matches) return e.remove();
      e.setAttribute('data-tlo', '');
      e.inert = true;
      setTimeout(() => e.remove(), ms);
    };
    c.a = (r, it) => {
      prev?.(r, it);
      const e = r.el;
      if (e.hasAttribute('data-tli')) requestAnimationFrame(() => requestAnimationFrame(() => e.removeAttribute('data-tli')));
    };
  });
})();
