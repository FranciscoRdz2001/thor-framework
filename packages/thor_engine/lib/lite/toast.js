// The page's one snack bar: `document.thorToast(message, kind, ms)` for
// a state's `toast(...)`. Inlined next to the `<div id="thor-toast">` the
// server wrote (`role=status`, so a screen reader reads what is put in it)
// and the `<template id="thor-toast-kinds">` holding its looks (`off` and
// one visible look per kind): the classes are the server's, the browser
// never makes a style.
//
// `document.thorToastHide(all)` ends the one showing (`hideToast()`), with
// `all` the waiting ones too (`clearToasts()`).
//
// One at a time: the next waits until the one showing ends (its CSS
// animation hides it after its duration, paused while hovered or focused).
// At most three wait, the newest kept; the same message as the one showing
// or the last waiting is not queued again. A server flash (`data-t-on` on
// the bar) counts as the one showing.
//
// Over modals (Flutter's ScaffoldMessenger draws the snack bar over routes,
// dialogs and drawers included): the bar is a `popover="manual"` shown with
// `showPopover()`, which puts it in the top layer, above what was there
// before. A modal <dialog> makes everything outside it inert, though (no
// pointer, and out of the accessibility tree: a screen reader would never
// read it), so while one is open the bar lives inside it, and goes back
// to the page when that dialog closes. A browser without popovers keeps the
// old fixed bar (under a modal's backdrop). With no JS the bar is the
// server's markup, neither a popover nor moved.
//
// A bar with a close button (`SnackBarThemeData(showCloseIcon: true)`) keeps
// its message in a `[data-snack-text]` node, so the text goes there and the
// button stays; the button (`[data-snack-close]`) ends the toast showing, the
// next waiting one shows (as `thorToastHide()` does).
((D) => {
  const bar = D.getElementById('thor-toast'), tpl = D.getElementById('thor-toast-kinds');
  if (!bar || !tpl) return;
  const looks = {};
  for (const k of tpl.content.children) looks[k.dataset.k] = k.className;
  const queue = [];
  const home = bar.parentNode, pop = 'showPopover' in bar;
  // The key of the toast showing (`kind|message`) and a count that tells a
  // toast's own timer from a later one's.
  let now = bar.hasAttribute('data-t-on') ? '.' : null, gen = 0;
  // Where the bar belongs now: the modal on top (the confirm dialog when it
  // is open, else the last open modal), or the page.
  const host = () => {
    const confirm = D.getElementById('thor-confirm');
    if (confirm?.open && confirm.matches(':modal')) return confirm;
    const open = D.querySelectorAll('dialog[open]');
    for (let i = open.length; i--;) if (open[i].matches(':modal')) return open[i];
    return home;
  };
  const showing = () => bar.matches(':popover-open');
  // How far its CSS animation (the delay is its time on screen) had gone:
  // read from the animation, or from the clock when moving already took it.
  let since = 0;
  const elapsed = () => {
    const a = bar.getAnimations?.().find((x) => x.animationName);
    return a && a.currentTime != null ? Number(a.currentTime) : performance.now() - since;
  };
  // Puts the bar in the top layer (again: the last in is the one on top),
  // in the place `host()` says. Moving it hides it and its animation starts
  // over, so it is given back the time it had already run (`keep`).
  const raise = (keep) => {
    if (!pop) return;
    const where = host(), done = keep ? elapsed() : 0;
    try {
      if (showing()) bar.hidePopover();
      if (bar.parentNode !== where) where.append(bar);
      bar.showPopover();
      const a = done > 0 && bar.getAnimations?.().find((x) => x.animationName);
      if (a) a.currentTime = done;
    } catch {}
  };
  // A modal opening over a toast that is showing (no new toast asks for it):
  // the bar was in the top layer first, so the modal's backdrop would cover it.
  new MutationObserver(() => {
    if (pop && bar.hasAttribute('data-t-on') && bar.parentNode !== host()) raise(true);
  }).observe(D, { subtree: true, attributes: true, attributeFilter: ['open'] });
  // The dialog the bar is in closed: back to the page, and up again if a
  // toast is still showing.
  D.addEventListener('close', (e) => {
    if (!pop || e.target === bar || !e.target.contains?.(bar)) return;
    if (bar.hasAttribute('data-t-on')) raise(true);
    else home.append(bar);
  }, true);
  const hide = () => {
    gen++;
    try {
      if (showing()) bar.hidePopover();
    } catch {}
    bar.className = looks.off;
    bar.removeAttribute('data-t-on');
    bar.style.animationDelay = '';
    now = null;
    next();
  };
  // The timer's turn to hide it: not while the bar's own animation is still
  // to play, paused because it is hovered or focused (WCAG 2.2.1).
  const end = () => {
    const pending = bar.getAnimations?.().some((a) => a.playState === 'paused');
    if (pending) return setTimeout(end, 500);
    hide();
  };
  const next = () => {
    if (now || !queue.length) return;
    const [message, kind, ms, key] = queue.shift();
    now = key;
    const mine = ++gen;
    bar.className = looks.off;
    // Made visible before the text goes in: a live region says what changes.
    void bar.offsetWidth;
    bar.className = looks[kind] || looks.info;
    bar.style.animationDelay = ms > 0 ? `${ms}ms` : '';
    bar.setAttribute('data-t-on', '');
    (bar.querySelector('[data-snack-text]') || bar).textContent = message;
    since = performance.now();
    raise(false);
    // The animation ends after its delay; this timer is for a browser that
    // never plays it (a hidden tab, animations turned off).
    setTimeout(() => mine === gen && end(), (ms > 0 ? ms : 4000) + 1000);
  };
  bar.addEventListener('animationend', () => bar.hasAttribute('data-t-on') && hide());
  bar.addEventListener('click', (e) => {
    if (e.target.closest?.('[data-snack-close]')) hide();
  });
  if (now) setTimeout(() => now === '.' && end(), 6000);
  // `hideToast()` / `clearToasts()`: end the one showing (the next waiting
  // one shows) and, with `all`, forget the waiting ones first.
  D.thorToastHide = (all) => {
    if (all) queue.length = 0;
    if (now || bar.hasAttribute('data-t-on')) hide();
  };
  D.thorToast = (message, kind, ms) => {
    const key = `${kind}|${message}`;
    if (key === now || key === queue[queue.length - 1]?.[3]) return;
    queue.push([message, kind, ms, key]);
    // A flood keeps the newest few.
    while (queue.length > 3) queue.shift();
    next();
    // One is already showing, under a modal that opened after it: over it.
    if (now && bar.hasAttribute('data-t-on') && bar.parentNode !== host()) raise(true);
  };
})(document);
