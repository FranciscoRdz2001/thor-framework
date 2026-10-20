// thor-lite part "tabs": thor_ui's `TabBar` as the WAI-ARIA tabs pattern.
// Loaded when the page has a `data-t-tabs` bar.
//
// Without JS the bar is a native radio group: one Tab stop, arrows move
// and select, `:has()` shows the panel of the checked radio. This promotes it:
// the bar becomes a `tablist`, each `<label>` a `tab` (`aria-selected`,
// roving `tabindex`), its radio is hidden from the tree and the panels
// become `tabpanel`s. Left/Right (mirrored in a right-to-left bar), Home and
// End move the focus and select (automatic activation) by clicking the
// radio, so `onTap` and the panel's `:has()` keep working as they do without
// the engine. A few page-wide listeners: the markup costs nothing until it
// is used.
((W, D) => {
  const R = D.documentElement;
  const BAR = '[data-t-tabs]';

  const tabsOf = (bar) => [...bar.querySelectorAll(':scope > label')];
  const radioOf = (tab) => tab.querySelector('input[type="radio"]');

  // The roving tabindex and aria-selected follow the checked radio.
  function sync(bar) {
    const tabs = tabsOf(bar);
    let stop = false;
    for (const tab of tabs) {
      const on = !!radioOf(tab)?.checked;
      tab.setAttribute('aria-selected', `${on}`);
      tab.tabIndex = on ? 0 : -1;
      stop ||= on;
    }
    // Nothing checked (never from thor_ui): the first tab is the way in.
    if (!stop && tabs[0]) tabs[0].tabIndex = 0;
  }

  function promote(bar) {
    if (bar.getAttribute('role') === 'tablist') return;
    bar.setAttribute('role', 'tablist');
    for (const tab of tabsOf(bar)) {
      const radio = radioOf(tab);
      tab.setAttribute('role', 'tab');
      // The label is the tab now; its radio is only the state behind it.
      if (!radio) continue;
      const panel = radio.getAttribute('aria-controls');
      if (panel) {
        tab.setAttribute('aria-controls', panel);
        D.getElementById(panel)?.setAttribute('role', 'tabpanel');
      }
      radio.setAttribute('aria-hidden', 'true');
      radio.removeAttribute('aria-controls');
      radio.tabIndex = -1;
    }
    sync(bar);
  }

  const rtl = (el) => W.getComputedStyle(el).direction === 'rtl';

  function select(bar, tab) {
    const radio = radioOf(tab);
    if (radio && !radio.checked) radio.click();
    sync(bar);
    tab.focus();
  }

  R.addEventListener('keydown', (e) => {
    const tab = e.target?.closest?.('[role="tab"]');
    const bar = tab?.parentElement;
    if (!bar?.matches(BAR) || e.altKey || e.ctrlKey || e.metaKey || e.shiftKey) return;
    const tabs = tabsOf(bar), at = tabs.indexOf(tab), n = tabs.length;
    const forward = rtl(bar) ? 'ArrowLeft' : 'ArrowRight', back = rtl(bar) ? 'ArrowRight' : 'ArrowLeft';
    let to;
    if (e.key === forward) to = (at + 1) % n;
    else if (e.key === back) to = (at - 1 + n) % n;
    else if (e.key === 'Home') to = 0;
    else if (e.key === 'End') to = n - 1;
    else if (e.key === 'Enter' || e.key === ' ') to = at;
    else return;
    e.preventDefault();
    select(bar, tabs[to]);
  });

  // A pointer pick, and the browser restoring a radio on back/forward.
  R.addEventListener('change', (e) => {
    const bar = e.target?.closest?.(BAR);
    if (bar) sync(bar);
  });

  const scan = () => {
    for (const bar of D.querySelectorAll(BAR)) promote(bar);
  };
  // Bars that arrive late are promoted when the focus first reaches them.
  R.addEventListener('focusin', (e) => {
    const bar = e.target?.closest?.(BAR);
    if (!bar) return;
    promote(bar);
    // A click on the label focuses its hidden radio (aria-hidden): the
    // focus belongs on the tab.
    const t = e.target;
    if (t.matches?.('input[type="radio"]') && bar.getAttribute('role') === 'tablist') {
      t.closest('[role="tab"]')?.focus();
    }
  });
  W.addEventListener('pageshow', scan);
  if (D.readyState === 'loading') D.addEventListener('DOMContentLoaded', scan);
  else scan();
})(window, document);
