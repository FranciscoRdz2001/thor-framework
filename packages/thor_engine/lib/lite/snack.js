// A `SnackBar` put by hand on a page (`SnackBar(visible: …)`): a
// `popover="manual"` that this script puts in the top layer while its state
// says it shows (`data-snack="on"`, a variant of its `Watch`), so an
// ancestor with `container-type`, `transform` or `overflow` (a `LayoutScope`)
// cannot become the box its `position: fixed` is measured against. The page's
// own bar (`#thor-toast`) is driven by toast.js.
//
// With no JS the bar is never opened and stays the plain fixed bar it was
// (its CSS shows it: the author's `display` beats the browser's for a closed
// popover). Its CSS animation hides it; when that ends the popover closes.
((D) => {
  if (!('showPopover' in HTMLElement.prototype)) return;
  const sel = '[data-snack]:not(#thor-toast)';
  const sync = (el) => {
    const on = el.getAttribute('data-snack') === 'on';
    if (on) el.removeAttribute('data-snack-closed');
    try {
      if (on && !el.matches(':popover-open')) el.showPopover();
      else if (!on && el.matches(':popover-open')) el.hidePopover();
    } catch {}
  };
  const scan = (node) => {
    if (node.nodeType !== 1) return;
    if (node.matches(sel)) sync(node);
    for (const el of node.querySelectorAll(sel)) sync(el);
  };
  scan(D.documentElement);
  new MutationObserver((records) => {
    for (const r of records) {
      if (r.type === 'attributes') {
        if (r.target.matches(sel)) sync(r.target);
      } else for (const n of r.addedNodes) scan(n);
    }
  }).observe(D, { subtree: true, childList: true, attributes: true, attributeFilter: ['data-snack'] });
  // The close button of a bar (`showCloseIcon`): hides it until its state
  // shows it again (the attribute's CSS is the hidden look of the animation's
  // end). The page's own bar (`#thor-toast`) is toast.js's.
  D.addEventListener('click', (e) => {
    const bar = e.target.closest?.('[data-snack-close]')?.closest(sel);
    if (!bar) return;
    bar.setAttribute('data-snack-closed', '');
    try {
      if (bar.matches(':popover-open')) bar.hidePopover();
    } catch {}
  });
  // The bar's own animation ended (it hides itself after its duration).
  D.addEventListener('animationend', (e) => {
    const el = e.target;
    if (el.matches?.(sel) && el.matches(':popover-open')) {
      try {
        el.hidePopover();
      } catch {}
    }
  }, true);
})(document);
