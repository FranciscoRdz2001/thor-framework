// Forms that save where the page stands (`Form(stay: true)`) and file inputs
// that send their form when files are chosen (`FileField(submitOnChange:)`),
// inlined at the end of a page that has one of them and only there, before the
// form script (a submit this one takes is cancelled, so that one leaves it
// alone). Without it, or with scripting off, the form posts, the server
// answers a redirect and the next page shows the flash, as any form does.
//
// A `<form data-t-stay>` is posted by `fetch` (the same fields and action;
// `multipart/form-data` when the form says so, urlencoded otherwise) with
// `x-thor-stay` in the request. The form is «sending» meanwhile
// (`data-pending`, `aria-busy`, its submit buttons disabled) and the page does
// not navigate. The server answers in headers:
// - `x-thor-flash` (percent-encoded) and `x-thor-flash-kind`: the toast
//   (`document.thorToast`, the page's one snack bar);
// - `x-thor-location`: the action sent the visitor to another page, the one
//   place that does navigate (`location.assign`; its flash rides the cookie);
// - the status: a failure (`4xx`, `5xx`) shows its message as an error toast and
//   keeps what the visitor typed; a success clears the files chosen.
// After an answer the form fires `thor:stay` (bubbles; `detail`: `{ok, status,
// kind, message}`): the engine reloads the page's queries on it, and an app can
// listen to update anything else. An answer that is not the server's (no
// `x-thor-stay` back: a login page a middleware redirected to) navigates there.
// A request that fails leaves the form free again (`thor:stay` with `ok: false`).
//
// An input marked `data-t-submit-on-files` sends its form as soon as files
// are chosen in it; the attribute's value names the button that sends it (the
// one with that `name`, or whose `formaction` is that action: `?/store`), or is
// empty for the form's first.
((D) => {
  const lock = (f, bs, on) => {
    f.toggleAttribute('data-pending', on);
    on ? f.setAttribute('aria-busy', true) : f.removeAttribute('aria-busy');
    for (const b of bs) b.disabled = on;
  };
  const toast = (m, k) => {
    if (m && D.thorToast) D.thorToast(m, k === 'success' || k === 'error' ? k : 'info', null);
  };
  D.addEventListener('change', (e) => {
    const i = e.target, f = i.form, a = i.getAttribute?.('data-t-submit-on-files');
    if (a == null || i.type !== 'file' || !i.files?.length || !f || f.hasAttribute('data-pending')) return;
    const by = a && [...f.elements].find((b) => /^(submit|image)$/.test(b.type) && (b.name === a || b.getAttribute('formaction')?.endsWith('/' + a)));
    f.requestSubmit(by || undefined);
  });
  D.addEventListener('submit', (e) => {
    const f = e.target, s = e.submitter, t = s?.formTarget || f.target;
    if (e.defaultPrevented || !f.hasAttribute?.('data-t-stay') || !window.fetch || !window.FormData || (t && t !== '_self')) return;
    const url = new URL(s?.hasAttribute('formaction') ? s.formAction : f.action, location.href);
    if ((s?.formMethod || f.method) !== 'post' || url.origin !== location.origin) return;
    e.preventDefault();
    if (f.hasAttribute('data-pending')) return;
    let body;
    try {
      body = new FormData(f, s);
    } catch {
      body = new FormData(f);
      if (s?.name) body.append(s.name, s.value);
    }
    const bs = [...f.elements].filter((b) => /^(submit|image)$/.test(b.type) && !b.disabled);
    lock(f, bs, true);
    const done = (detail) => {
      lock(f, bs, false);
      f.dispatchEvent(new CustomEvent('thor:stay', { bubbles: true, detail }));
    };
    fetch(url, {
      method: 'POST',
      body: /multipart/i.test(s?.formEnctype || f.enctype) ? body : new URLSearchParams(body),
      headers: { 'x-thor-stay': '1' },
      credentials: 'same-origin',
    }).then(
      (r) => {
        const h = (n) => r.headers.get(n);
        if (!h('x-thor-stay')) {
          // Not the server's answer: if it was sent somewhere, go there.
          if (r.redirected) return location.assign(r.url);
          return done({ ok: false, status: r.status });
        }
        const go = h('x-thor-location');
        if (go) {
          const u = new URL(go, location.href);
          if (/^https?:/.test(u.protocol)) return location.assign(u);
          return done({ ok: false, status: r.status });
        }
        let message = '';
        try {
          message = decodeURIComponent(h('x-thor-flash') || '');
        } catch {}
        const kind = h('x-thor-flash-kind') || (r.ok ? '' : 'error');
        toast(message, kind);
        // A file sent is not chosen again.
        if (r.ok) for (const i of f.elements) if (i.type === 'file') i.value = '';
        done({ ok: r.ok, status: r.status, kind, message });
      },
      () => done({ ok: false, status: 0 }),
    );
  });
})(document);
