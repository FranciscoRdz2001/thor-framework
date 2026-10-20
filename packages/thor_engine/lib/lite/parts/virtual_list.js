// thor-lite part "virtual_list": windowing for a keyed list that asks for it
// (`Watch.list(itemExtent:, virtual: true)`: `data-tlv="34"`, the rows' extent
// in px; the dart2js engine's VirtualLists). Loaded when the app has one.
//
// The server draws every row (works without JS, find in page, SEO); once the
// list runs, only the rows near the viewport stay in the page and two
// spacers (`aria-hidden`, the one thing the client sizes) stand in for the
// others, so the scrollbar and the offsets stay as if all were there. Rows
// have the fixed extent (the server sets it as their height), so which rows
// are visible is arithmetic over the scroller's position: no measuring rows.
// The window moves only when the visible rows come within half the overscan
// of its edge. A row with the focus in it stays in the page (next to the
// window, off screen) so a scroll does not drop the focus. Rows say their
// place in the whole list (`aria-setsize`, `aria-posinset`) for screen
// readers. The keyed reconcile (`update`) is the same one, given the window.
(() => {
  const scrollerOf = (el) => {
    for (let p = el; p && p !== D.body; p = p.parentElement) {
      const o = W.getComputedStyle(p).overflowY;
      if (o === 'auto' || o === 'scroll' || o === 'overlay') return p;
    }
    return null;
  };
  rowParts.push((c) => {
    const x = +c.el.getAttribute('data-tlv');
    if (!(x > 0)) return;
    const el = c.el;
    const spacer = () => {
      const d = D.createElement('div');
      d.setAttribute('aria-hidden', 'true');
      d.style.flex = 'none';
      return d;
    };
    const top = spacer(), bot = spacer();
    el.insertBefore(top, el.firstChild);
    el.insertBefore(bot, c.tpl);
    c.an = bot;
    let all = [], ks = [], s = 0, e = 0, raf = 0, sc, on = 0;
    const sync = (force) => {
      if (!el.isConnected) return;
      const n = ks.length;
      const v = sc ? sc.getBoundingClientRect() : { top: 0, bottom: W.innerHeight };
      const o = top.getBoundingClientRect().top;
      const over = Math.max(8, Math.ceil((v.bottom - v.top) / x / 2));
      const va = Math.max(0, Math.floor((v.top - o) / x)), vb = Math.min(n, Math.ceil((v.bottom - o) / x));
      // The window still covers the visible rows with half the overscan to spare.
      if (!force && (s === 0 || va - over / 2 >= s) && (e === n || vb + over / 2 <= e)) return;
      s = Math.min(n, Math.max(0, va - over));
      e = Math.max(s, Math.min(n, vb + over));
      let it = all.slice(s, e), k = ks.slice(s, e), pin = -1, above = 0;
      const f = D.activeElement;
      if (f && f !== D.body && el.contains(f)) {
        const r = c.rows.find((r) => r.el.contains(f));
        const i = r ? ks.indexOf(r.k) : -1;
        if (i >= 0 && (i < s || i >= e)) {
          pin = i;
          above = i < s;
          above ? (it.unshift(all[i]), k.unshift(ks[i])) : (it.push(all[i]), k.push(ks[i]));
        }
      }
      update(c, it, k);
      top.style.height = (s - (pin >= 0 && above ? 1 : 0)) * x + 'px';
      bot.style.height = (n - e - (pin >= 0 && !above ? 1 : 0)) * x + 'px';
      const rows = c.rows;
      for (let j = 0; j < rows.length; j++) {
        const at = pin >= 0 && (above ? j === 0 : j === rows.length - 1) ? pin : s + j - (pin >= 0 && above ? 1 : 0);
        const r = rows[j].el;
        r.getAttribute('aria-posinset') !== `${at + 1}` && r.setAttribute('aria-posinset', at + 1);
        r.getAttribute('aria-setsize') !== `${n}` && r.setAttribute('aria-setsize', n);
      }
    };
    const later = () => raf || (raf = requestAnimationFrame(() => ((raf = 0), untracked(() => sync()))));
    c.u = (it, keys) => {
      all = it;
      ks = keys;
      if (!on) {
        on = 1;
        sc = scrollerOf(el);
        (sc || W).addEventListener('scroll', later, { passive: true });
        W.addEventListener('resize', later);
        W.ResizeObserver && new W.ResizeObserver(later).observe(sc || el);
      }
      sync(true);
    };
  });
  // The page draws every row, so the state that owns a windowed list starts at
  // idle, without waiting for an event (the runtime is lazy): the page is
  // trimmed as soon as it is quiet.
  queueMicrotask(() =>
    (W.requestIdleCallback || setTimeout)(() => {
      const seen = new Set();
      for (const el of D.querySelectorAll('[data-tlv]')) {
        const id = el.getAttribute('data-tl') || '', t = id.indexOf('~');
        const p = (t < 0 ? id : id.slice(0, t)).replace(/\.[^.]*$/, '');
        seen.has(p) || (seen.add(p), activate(p));
      }
    }),
  );
})();
