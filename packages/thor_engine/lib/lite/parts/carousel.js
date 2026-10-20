// thor-lite part "carousel": thor_ui's `CarouselView`: its fallback controls
// (`data-t-cv`) and `autoPlay:`.
//
// Controls: where the browser draws no `::scroll-button` (Firefox, Safari)
// the server's hidden buttons are shown and wired: previous/next scroll one
// page (the scroller snaps), disabled at the ends from the scroll position,
// and a dot per item that scrolls to it and carries aria-current while it is
// the first one in view. A carousel whose items are a live list (the server
// drew only the row template) has a <template data-t-cv-dot> in the dots'
// group: a dot is cloned from it per item, and the controls hide while there
// are fewer than two. Where the browser has them (Chromium 135+) nothing
// is shown and nothing is wired. Without JS they stay hidden: no dead button.
//
// Autoplay: thor_ui's `CarouselView(autoPlay:)`
// (`data-t-carousel="<ms>"`): the carousel advances one item every <ms> and
// goes back to the first after the last. The scrolling, snapping, arrows and
// dots are the browser's (CSS); this only moves the scroller, so without it
// (no JS) the carousel is just static. Like Embla's autoplay plugin and
// Swiper's `autoplay`, it stops while the visitor interacts (pointer over,
// focus inside, touch, keys) and, because moving content is WCAG 2.2.2, it
// never runs with prefers-reduced-motion, in a hidden tab or off screen.
(() => {
  const A = 'data-t-carousel';
  const seen = new WeakSet();
  const reduced = () => matchMedia('(prefers-reduced-motion: reduce)').matches;

  function start(el) {
    const ms = Number(el.getAttribute(A));
    if (!(ms > 0)) return;
    // The fallback arrows and dots are siblings of the scroller: pointer and
    // focus on them count as being in the carousel (native ones are inside).
    const w = el.closest('[data-t-cv]') || el;
    let busy = 0; // a pointer or the focus is in; counts, never negative
    let last = 0; // when the visitor last touched it
    let visible = true;
    const touched = () => {
      last = Date.now();
    };
    w.addEventListener('pointerenter', (e) => {
      if (e.pointerType === 'mouse') busy++;
    });
    w.addEventListener('pointerleave', (e) => {
      if (e.pointerType === 'mouse') busy = Math.max(0, busy - 1);
      touched();
    });
    w.addEventListener('focusin', () => busy++);
    w.addEventListener('focusout', () => {
      busy = Math.max(0, busy - 1);
      touched();
    });
    for (const t of ['touchstart', 'pointerdown', 'wheel', 'keydown']) w.addEventListener(t, touched, { passive: true });
    if ('IntersectionObserver' in window) {
      new IntersectionObserver((es) => {
        visible = es[es.length - 1].isIntersecting;
      }).observe(el);
    }
    const tick = () => {
      if (!el.isConnected) return clearInterval(id);
      if (busy || !visible || document.hidden || reduced() || Date.now() - last < ms) return;
      const items = el.children;
      if (items.length < 2 || el.scrollWidth <= el.clientWidth + 1) return;
      const rtl = getComputedStyle(el).direction === 'rtl';
      const left = Math.abs(el.scrollLeft);
      const end = left + el.clientWidth >= el.scrollWidth - 2;
      // One item (plus the gap) ahead; the first one after the last.
      const step = items[1].getBoundingClientRect().left - items[0].getBoundingClientRect().left;
      const to = end ? 0 : left + Math.abs(step);
      el.scrollTo({ left: rtl ? -to : to, behavior: 'smooth' });
    };
    const id = setInterval(tick, ms);
  }

  const native = () => CSS.supports('selector(::scroll-button(*))');
  const behavior = () => (reduced() ? 'auto' : 'smooth');

  function controls(w) {
    if (native()) return;
    const sc = w.firstElementChild;
    const prev = w.querySelector('[data-t-cv-prev]');
    const next = w.querySelector('[data-t-cv-next]');
    const group = w.querySelector('[data-t-cv-dots]');
    // The items: the template of a live list is not one.
    const real = () => [...sc.children].filter((c) => c.localName !== 'template');
    const tpl = group && group.querySelector('template[data-t-cv-dot]');
    let dots = group ? [...group.children].filter((c) => c !== tpl) : [];
    let items = real();
    const rtl = () => getComputedStyle(sc).direction === 'rtl';
    // One page: the items in view (plus their gaps) ahead.
    const page = () => {
      if (items.length < 2) return sc.clientWidth;
      const pitch = items[1].getBoundingClientRect().left - items[0].getBoundingClientRect().left;
      const n = Math.max(1, Math.round((sc.clientWidth + 1) / Math.abs(pitch)));
      return Math.abs(pitch) * n;
    };
    const by = (d) => sc.scrollBy({ left: d, behavior: behavior() });
    // aria-disabled, not disabled: a button that disables itself under the
    // visitor's focus (Next at the end) would drop it to the page.
    const off = (b) => b.getAttribute('aria-disabled') === 'true';
    const sign = () => (rtl() ? -1 : 1);
    if (prev) prev.addEventListener('click', () => off(prev) || by(-sign() * page()));
    if (next) next.addEventListener('click', () => off(next) || by(sign() * page()));
    if (group)
      group.addEventListener('click', (e) => {
        const it = items[dots.indexOf(e.target.closest('button'))];
        if (it) by(it.getBoundingClientRect().left - sc.getBoundingClientRect().left);
      });
    let frame = 0;
    const update = () => {
      frame = 0;
      items = real();
      // Fewer than two items has nowhere to go: no controls (a live list
      // starts empty).
      const few = items.length < 2;
      for (const e of [prev, next, group]) if (e) e.hidden = few;
      if (tpl) {
        while (dots.length > items.length) dots.pop().remove();
        while (dots.length < items.length) {
          const d = tpl.content.firstElementChild.cloneNode(true);
          dots.push(group.appendChild(d));
        }
        // "Slide 2 of 5": the template's label is the prefix, its `of` word
        // joins the count (it changes as rows come and go: all are renamed).
        const prefix = tpl.content.firstElementChild.getAttribute('aria-label');
        const of = tpl.getAttribute('data-t-cv-of');
        dots.forEach((d, i) => d.setAttribute('aria-label', `${prefix}${i + 1}${of ? ` ${of} ${items.length}` : ''}`));
      }
      if (few) return;
      const left = Math.abs(sc.scrollLeft);
      const max = sc.scrollWidth - sc.clientWidth;
      const atStart = left <= 1, atEnd = left >= max - 1;
      const set = (b, v) => (v ? b.setAttribute('aria-disabled', 'true') : b.removeAttribute('aria-disabled'));
      if (prev) set(prev, atStart);
      if (next) set(next, atEnd);
      if (!dots.length) return;
      let cur = 0, best = Infinity;
      const edge = sc.getBoundingClientRect().left;
      for (let i = 0; i < items.length; i++) {
        const d = Math.abs(items[i].getBoundingClientRect().left - edge);
        if (d < best) (best = d), (cur = i);
      }
      // At the end the last item can't reach the start: it is the current one.
      if (atEnd && max > 1) cur = items.length - 1;
      dots.forEach((d, i) => (i === cur ? d.setAttribute('aria-current', 'true') : d.removeAttribute('aria-current')));
    };
    const schedule = () => {
      if (!frame) frame = requestAnimationFrame(update);
    };
    sc.addEventListener('scroll', schedule, { passive: true });
    new ResizeObserver(schedule).observe(sc);
    // A live list's rows come and go.
    if (tpl) new MutationObserver(schedule).observe(sc, { childList: true });
    update();
  }

  function watch(root = D) {
    const all = (q) => {
      const l = [...root.querySelectorAll(q)];
      if (root.matches?.(q)) l.unshift(root);
      return l;
    };
    for (const el of all(`[${A}]`)) {
      if (seen.has(el)) continue;
      seen.add(el);
      start(el);
    }
    for (const w of all('[data-t-cv]')) {
      if (seen.has(w)) continue;
      seen.add(w);
      controls(w);
    }
  }

  watch();
  scanParts.push(() => watch());
  D.addEventListener('thor:hydrated', () => watch());
  // Carousels that arrive after the page (a list's rows, a streamed piece, a
  // dialog's content): wired where they land.
  new MutationObserver((ms) => {
    for (const m of ms) for (const n of m.addedNodes) if (n.nodeType === 1) watch(n);
  }).observe(D.documentElement, { childList: true, subtree: true });
})();
