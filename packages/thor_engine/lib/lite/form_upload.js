// The upload progress of a `Form` with files (`LinearProgressIndicator.upload`),
// inlined at the end of a page that has the bar and only there: the
// form script every page with a `Form` carries stays as it was.
//
// A post of a `multipart/form-data` form with a file chosen and a
// `progress[data-t-upload]` inside goes by XMLHttpRequest (`fetch` has no
// upload progress) and the bar fills as the bytes leave. The request names
// itself (`x-thor-upload`) and the server answers a redirect or a page as a `200`
// with the target in `x-thor-location` (a request would follow a redirect
// hidden: the `GET` would run twice and the first would use up the flash). Then the
// navigation is the browser's own:
// - a redirect: `location.assign` of the target (history, bfcache, view
//   transitions, scripts and CSP as on any navigation), after leaving the
//   place the form script keeps (`thor:keep`: scroll and pressed button);
// - a page (a `422`, a `2xx`, a `5xx`): the server kept it and the target is
//   its address (`/_thor/upload-result/<token>`, once, with the status it
//   had): the same `location.assign`; no second upload;
// - a page from a server that is not thor's (no `x-thor-upload` back): the only
//   case where it is written over this one;
// - a download: saved; anything else, a dropped connection: the form is free
//   (`thor:upload-error` on it when there was nothing to show).
// A kept page is shown at the address of the post (`history.replaceState`),
// before the form script runs (it comes first in the page), so the place of
// the post is kept as for a same-path answer.
// Not taken (the plain post goes on): no file, another origin or `target`,
// not `multipart`, `data-t-nopending`.
((D) => {
  // form -> the buttons it locked.
  const held = new Map();
  const lock = (f, bs, on) => {
    f.toggleAttribute('data-pending', on);
    on ? f.setAttribute('aria-busy', true) : f.removeAttribute('aria-busy');
    for (const b of bs) b.disabled = on;
  };
  // `thor:upload-error` on the form: the send ended with no page to show (the
  // connection dropped, a `204`, a file the server answered): an app that
  // wants to say so listens for it.
  const free = (f, bar, why) => {
    if (why) f.dispatchEvent(new CustomEvent('thor:upload-error', { bubbles: true, detail: why }));
    bar.hidden = true;
    lock(f, held.get(f) || [], false);
    held.delete(f);
  };
  // The page of a kept result (it has the bar again): its address goes back to
  // the post's, which `location.assign` could not keep.
  try {
    const at = sessionStorage['thor:upload-url'];
    if (at && location.pathname.startsWith('/_thor/upload-result/')) {
      history.replaceState(history.state, '', at);
      sessionStorage.removeItem('thor:upload-url');
    }
  } catch {}
  D.defaultView.addEventListener('pageshow', (e) => e.persisted && held.forEach((_, f) => free(f, f.querySelector('progress[data-t-upload]'))));
  D.addEventListener('submit', (e) => {
    const f = e.target, s = e.submitter, bar = f.querySelector?.('progress[data-t-upload]'), t = s?.formTarget || f.target;
    if (!bar || e.defaultPrevented || !window.XMLHttpRequest) return;
    // A second submit while the first goes (double click, Enter twice).
    if (held.has(f)) return e.preventDefault();
    // `formAction` is the page address when the button has no `formaction`.
    const url = new URL(s?.hasAttribute('formaction') ? s.formAction : f.action, location.href);
    if ((s?.formMethod || f.method) !== 'post' || (s?.formEnctype || f.enctype) !== 'multipart/form-data' || (t && t !== '_self') || url.origin !== location.origin || f.hasAttribute('data-t-nopending') || ![...f.elements].some((i) => i.type === 'file' && i.files?.length)) return;
    let body;
    try {
      body = new FormData(f, s);
    } catch {
      body = new FormData(f);
      if (s?.name) body.append(s.name, s.value);
    }
    e.preventDefault();
    const bs = [...f.elements].filter((b) => /^(submit|image)$/.test(b.type) && !b.disabled);
    held.set(f, bs);
    lock(f, bs, true);
    bar.max = 1;
    bar.value = 0;
    bar.hidden = false;
    const x = new XMLHttpRequest();
    x.open('POST', url);
    x.responseType = 'blob';
    x.setRequestHeader('x-thor-upload', '1');
    x.upload.onprogress = (p) => p.lengthComputable && (bar.value = p.loaded / p.total);
    // Sent: the server is working, how long is unknown.
    x.upload.onload = () => bar.removeAttribute('value');
    x.onerror = x.onabort = x.ontimeout = () => free(f, bar, 'network');
    x.onload = () => {
      const h = (n) => x.getResponseHeader(n) || '', go = h('x-thor-location');
      if (go) {
        const u = new URL(go, location.href);
        if (!/^https?:/.test(u.protocol)) return free(f, bar, 'location');
        // The place of this post for the page that answers it (form_submit.js
        // reads it): written here because this page leaves by script.
        if (u.origin === location.origin && !f.hasAttribute('data-t-reset')) {
          try {
            const n = /(?:^|; )thor-tab=([^;]*)/.exec(D.cookie)?.[1];
            const p = (q) => q.replace(/(.)\/$/, '$1');
            const z = (b) => b.getAttribute('formaction')?.replace(/\?(?:[^&]*&)*(?=\/)|\?.*/, '?') + b.value;
            sessionStorage['thor:keep'] = JSON.stringify([p(decodeURI(location.pathname)), scrollY | 0, [...D.querySelectorAll('button:not([type=button],[type=reset]),input[type=submit],input[type=image]')].indexOf(s), Date.now(), s ? z(s) : '', n]);
          } catch {}
        }
        // A kept page (`/_thor/upload-result/`) is shown at the address of the
        // post, as the browser would: relative `formaction`s resolve there.
        try {
          sessionStorage['thor:upload-url'] = url.href;
        } catch {}
        // The target may be a download or be stopped: the page stays, the
        // form must not stay locked forever (as in form_submit.js).
        setTimeout(() => held.has(f) && free(f, bar), 15e3);
        return location.assign(u);
      }
      if (/html/.test(h('content-type'))) {
        // A thor server keeps every page (`x-thor-location` above): one that
        // comes here was too big to keep. Only a server that is not thor's
        // leaves a page nobody can navigate to: written over this one.
        if (h('x-thor-upload')) return free(f, bar, x.status);
        return x.response.text().then((html) => {
          if (x.responseURL && x.responseURL !== location.href) history.pushState(0, '', x.responseURL);
          D.open();
          D.write(html);
          D.close();
        });
      }
      if (/attachment/i.test(h('content-disposition'))) {
        const a = D.createElement('a');
        a.href = URL.createObjectURL(x.response);
        a.download = /filename="?([^";]+)/i.exec(h('content-disposition'))?.[1] || '';
        a.click();
        setTimeout(() => URL.revokeObjectURL(a.href), 3e4);
        return free(f, bar);
      }
      free(f, bar, x.status);
    };
    x.send(body);
  });
})(document);
