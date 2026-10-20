// The form's "sending" state and the first error's focus,
// inlined at the end of a page with a `Form` (with or without the engine:
// it doesn't use it, so it works before the engine loads and with either).
//
// On submit, once nobody cancelled it: the form gets `data-pending` (for
// CSS) and `aria-busy`, and its submit bs are disabled. It happens one
// task after the event, when the browser already built the data it sends:
// the clicked button's name/value goes along, and a submit another handler
// cancelled leaves nothing behind. A second submit meanwhile (double click,
// Enter twice) is cancelled. It ends by leaving the page; on a bfcache
// restore (`pageshow` persisted) everything goes back; and 15 s after the
// submit, when the page is still here (the browser's Stop, a download): no
// event says it ended, and a form locked forever is worse than the double
// submit a plain HTML form would allow. Not touched: a
// `method=dialog`, a `target` other than `_self`, a URL that isn't
// http(s) (`mailto:`, a download stays on the page) or `data-t-nopending`.
//
// Keeps the visitor's place (Remix `preventScrollReset`, Turbo's morph/
// same-URL visits): a POST answered with the same page (the page itself,
// a `422`, or a redirect to its path, whatever the query: a quantity
// stepper `?quantity=4`) is a new navigation that starts at the top. So a
// post of the page saves where it was (scroll and the pressed button) in
// sessionStorage when the page is left (a submit that goes nowhere saves
// nothing); the next load of that same PATH, coming from it (`navigate`,
// referrer included), scrolls there and focuses the button (again once the
// document is complete: streamed content or images move the layout).
// Another path, a link, back/forward, a `#hash`, an entry older than 20 s:
// nothing. Opt-outs for a same-path answer that should start at the top
// (back to page 1 of a list): `Form(resetScroll: true)` (`data-t-reset`:
// nothing is saved) or `Redirect(url, resetScroll: true)`: a post leaves a
// nonce in the `thor-tab` cookie and in its saved place; the server echoes
// the cookie's in `thor-scroll`, and the landing page resets when it is its
// own (cookies are shared by tabs, sessionStorage is not). Without JS the
// browser starts at the top.
//
// After a server validation error (`422`) the server marks the first
// invalid field `autofocus`: here it is focused too (also when the form
// is in a closed `<details>` or another tab).
((D) => {
  // form -> the submit buttons it disabled (empty in the task between the
  // event and the lock). Being in it is being busy.
  const held = new Map();
  const k = (f, bs, on) => {
    f.toggleAttribute('data-pending', on);
    on ? f.setAttribute('aria-busy', true) : f.removeAttribute('aria-busy');
    for (const b of bs) b.disabled = on;
  };
  const K = 'thor:keep';
  const ss = (() => {
    try {
      return sessionStorage;
    } catch {}
  })();
  // A path as the server writes it back (`Redirect.back` normalizes the
  // escapes: `%c3` is `%C3`, `%7e` is `~`) and without its trailing slash.
  const P = (p) => {
    try {
      p = decodeURI(p);
    } catch {}
    return p.replace(/(.)\/$/, '$1');
  };
  // What makes a button the same one on the next page: its action key and value
  // (`?qty=4&/step` and `?/step` are one: a form carries the page's query). A
  // button with no key (the page's only action posts to its path) is
  // its path: `?qty=4` and `?qty=5` are one too.
  const Z = (b) => b.getAttribute('formaction')?.replace(/\?(?:[^&]*&)*(?=\/)|\?.*/, '?') + b.value;
  // Submit buttons in document order: the pressed one is found again by its place.
  const BS = 'button:not([type=button],[type=reset]),input[type=submit],input[type=image]';
  const free = (f) => {
    sub = 0;
    k(f, held.get(f), false);
    held.delete(f);
  };
  // The place of the post in flight: it is written when the page is really
  // left (`pagehide`), so a submit that never navigates (a 204, a download, a
  // cancelled one, a link followed meanwhile) leaves nothing to restore on a
  // later visit to the same URL.
  let sub;
  D.addEventListener('submit', (e) => {
    const f = e.target, s = e.submitter, t = s?.formTarget || f.target;
    if (held.has(f)) return e.preventDefault();
    sub = 0;
    if (!f.elements || f.hasAttribute('data-t-nopending') || (s?.formMethod || f.method) === 'dialog' || !/^https?:/.test(s?.hasAttribute('formaction') ? s.formAction : f.action) || (t && t !== '_self')) return;
    held.set(f, []);
    if ((s?.formMethod || f.method) === 'post') {
      // This tab's mark, for `Redirect(resetScroll: true)` to echo back.
      const n = (1 + Math.random()).toString(36).slice(2, 10);
      try {
        D.cookie = `thor-tab=${n};Path=/;Max-Age=60;SameSite=Lax${location.protocol === 'https:' ? ';Secure' : ''}`;
      } catch {}
      if (!f.hasAttribute('data-t-reset')) sub = [P(location.pathname), scrollY | 0, [...D.querySelectorAll(BS)].indexOf(s), 0, s ? Z(s) : '', n];
    }
    setTimeout(() => {
      if (e.defaultPrevented) return (sub = 0), held.delete(f);
      // `elements` leaves out `<input type=image>`.
      const bs = [...f.elements, ...f.querySelectorAll('input[type=image]')].filter((b) => /^(submit|image)$/.test(b.type) && !b.disabled);
      k(f, bs, true);
      held.set(f, bs);
      // Nothing tells the page its submit ended without leaving it (Stop, Esc,
      // a download, a new tab): a lock nobody lifts would be forever.
      setTimeout(() => held.get(f) === bs && free(f), 15e3);
    });
  });
  D.addEventListener('click', (e) => e.target.closest?.('a[href]') && (sub = 0));
  D.defaultView.addEventListener('pagehide', () => {
    if (sub) try {
      sub[3] = Date.now();
      ss[K] = JSON.stringify(sub);
    } catch {}
  });
  D.defaultView.addEventListener('pageshow', (e) => e.persisted && ((sub = 0), held.forEach((_, f) => free(f))));

  // The first wrong field: open what hides it, then focus it.
  const bad = D.querySelector('[autofocus][aria-invalid=true]');
  for (let p = bad; (p = p?.parentElement); ) {
    if (p.matches('details:not([open])')) p.open = true;
    if (p.matches('[role=group][id]')) D.querySelector(`input[type=radio]:not(:checked)[aria-controls="${CSS.escape(p.id)}"]`)?.click();
  }
  bad?.focus();

  // The place of the post that brought us here.
  try {
    const r = JSON.parse(ss[K]);
    ss.removeItem(K);
    // `Redirect(resetScroll: true)`: the server echoed this post's mark. It is
    // used up when it is ours; another tab's is left for it (it expires).
    let reset;
    try {
      reset = r[5] && /(?:^|; )thor-scroll=([^;]*)/.exec(D.cookie)?.[1] === r[5];
      if (reset) D.cookie = 'thor-scroll=;Max-Age=0;Path=/';
    } catch {}
    const l = P(location.pathname), ref = D.referrer && new URL(D.referrer);
    if (!bad && !reset && !D.prerendering && !location.hash && Date.now() - r[3] < 2e4 && l === r[0] && (!ref || (ref.origin === location.origin && P(ref.pathname) === r[0])) && performance.getEntriesByType('navigation')[0]?.type === 'navigate') {
      // `at`: where we left the page. Another place later is the visitor's
      // (a scrollbar drag fires no wheel, key or pointer event on the page).
      // Scroll anchoring is off meanwhile: it would keep the view steady
      // over a late image, steady at the wrong place.
      let user, at;
      const root = D.documentElement.style;
      const done = () => (root.overflowAnchor = '');
      const take = () => ((user = 1), done());
      const go = () => {
        const b = [...D.querySelectorAll(BS)][r[2]];
        scrollTo({ top: r[1], behavior: 'instant' });
        at = scrollY;
        // The same button: its action and value are the ones it had.
        if (b && Z(b) === r[4]) b.focus({ preventScroll: true });
      };
      root.overflowAnchor = 'none';
      go();
      // The layout may still move (a streamed chunk, an image): once the
      // document is complete, unless the visitor already took over.
      for (const n of ['wheel', 'keydown', 'pointerdown']) addEventListener(n, take, { once: true, passive: true });
      addEventListener('DOMContentLoaded', () => user || scrollY !== at || go(), { once: true });
      addEventListener('load', () => (user || scrollY !== at || go(), done()), { once: true });
    }
  } catch {}
})(document);
