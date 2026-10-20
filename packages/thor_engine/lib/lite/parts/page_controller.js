// thor-lite part "page_controller": PageController (needs "scroll_controller").
//
// A ScrollController over a PageView's scroll-snap row: `page` is the offset
// in viewports (the view's size), `jumpToPage` / `animateToPage` move it to
// `page * size` with the controller's own jumpTo / animateTo (duration, curve). The same
// controller object, with the page members added: nothing here touches the
// scroll part. `initialPage` is applied when the view shows up (unless it is
// already scrolled: a restored position wins), and a page asked for while
// there is no view, or it has no size yet (hidden), waits for it.
((T, D) => {
  const { find } = T.ctl;
  const size = (el) => (el.hasAttribute('data-tsc-h') ? el.clientWidth : el.clientHeight);
  T.ctl.page = (id, initialPage = 0) => {
    const c = T.ctl.scroll(id, 0);
    let want = initialPage || null; // a page asked for, not applied yet
    c.initialPage = initialPage;
    // The view's size is needed: where a view shows up that has none, the page waits.
    const at = c.at.bind(c);
    c.at = (el) => {
      if (want != null && size(el)) {
        c.w = want * size(el);
        want = null;
      }
      // Hidden: the page waits for the view's first size, then starts there (page_view: not a change).
      if (want != null && !size(el))
        T.ctl.sized(el, (e) => {
          if (find('data-tsc', id) !== e) return true;
          const asked = want;
          c.at(e);
          asked != null && want == null && e.dispatchEvent(new CustomEvent('thor:pagestart', { bubbles: true }));
          return want == null;
        });
      at(el);
    };
    Object.defineProperty(c, 'page', {
      get() {
        const v = c.vd.value;
        return v ? c.p.value / v : want ?? initialPage;
      },
    });
    const view = (n) => {
      const el = find('data-tsc', id);
      if (el && size(el)) return size(el);
      want = n;
    };
    c.jumpToPage = (n) => {
      const v = view(n);
      if (v) (want = null), c.jumpTo(n * v);
    };
    c.animateToPage = (n, dur, ease) => {
      const v = view(n);
      if (!v) return Promise.resolve();
      want = null;
      return c.animateTo(n * v, dur, ease);
    };
    // The controller is made when the state is, maybe with its view already
    // there: apply the initial page now.
    const el = find('data-tsc', id);
    if (el) c.at(el);
    return c;
  };
})(thor, document);
