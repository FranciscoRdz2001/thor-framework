// thor-lite part "share": thor_ui's `ShareRequest`
// (`data-t-share="result:id"`, `data-t-share-d='{"title","text","url"}'`).
//
// A click opens the device's share sheet (`navigator.share`, which needs a
// click). Where there is none: a child that is a link keeps its `href` (the
// page's own fallback, followed by the browser; reported as `link`); any
// other child copies the text and the link to the clipboard (`copied`).
// `result` gets `shared`, `cancelled` (the sheet was closed), `link`,
// `copied` or `failed`. A second click while the sheet is open is ignored.
((D, W) => {
  const A = 'data-t-share', J = 'data-t-share-d';
  const busy = new WeakSet();
  D.documentElement.addEventListener(
    'click',
    (e) => {
      const el = e.target instanceof Element ? e.target.closest(`[${J}]`) : null;
      if (!el || busy.has(el)) return;
      const id = parseOn(el.getAttribute(A) ?? '').result;
      const say = (r) => id && run(id, el, r);
      let d;
      try {
        d = JSON.parse(el.getAttribute(J));
      } catch {
        return;
      }
      // A path is this site's: the sheet needs an absolute link.
      const url = new URL(d.url ?? W.location.href, W.location.href).href;
      const data = { title: d.title, text: d.text, url };
      const nav = W.navigator;
      if (nav?.share && (!nav.canShare || nav.canShare(data))) {
        e.preventDefault();
        busy.add(el);
        nav.share(data).then(
          () => say('shared'),
          (x) => say(x?.name === 'AbortError' ? 'cancelled' : 'failed'),
        ).finally(() => busy.delete(el));
        return;
      }
      // The child's link is the way without a share sheet.
      if (el.closest('a[href]')) return say('link');
      e.preventDefault();
      const text = [d.text, url].filter(Boolean).join(' ');
      busy.add(el);
      Promise.resolve(nav?.clipboard?.writeText?.(text) ?? Promise.reject()).then(
        () => say('copied'),
        () => say('failed'),
      ).finally(() => busy.delete(el));
    },
    true,
  );
})(document, window);
