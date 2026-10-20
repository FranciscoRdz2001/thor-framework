// thor-lite part "server_call": the POST to the page's own URL that `query`
// and `command` make (parts "query" and "server_command"). The server
// answers through that page's middleware; the header names the query or the
// command.
//
// `thor.call(header, id, body, ms, ctl)` never throws: it gives `{ok, m, k,
// e}`, the answer as a Map `m` (objects keep their key order, see `parse`)
// when `ok` (a 2xx whose body is a JSON object), else the kind `k` (a name of `ServerErrorKind`) and the message
// `e` for the visitor. The call ends by itself: a network error, an `ms`
// timeout or an abort of `ctl` (an AbortController the caller
// keeps to cancel it) are errors here, and the timer is always cleared. A
// 401 with `redirect` (no session) goes there, like the page (a web address
// only), once: the page is leaving, so for the next 5 s no other call goes
// out (each would be a 401 and a second `assign` would abort the first
// navigation) and no other `assign` starts.
//
// `ms` (the call's `timeout:`) is null when it has none: then the page's
// (`!t`, `ThorApp(callTimeout:)`) or 30 s. 0, in either, is no timeout.
//
// The browser writes no text of its own: the messages of the errors it finds
// (`network`, `timeout`, `aborted`, and `generic` for an answer that isn't
// the server's) come from the page (`!m` in #thor-state, the app's
// `ServerMessages`), and the server's own answers carry theirs.
((T) => {
  const msg = (k) => {
    const t = saved().get('!m');
    return t instanceof Map && typeof t.get(k) === 'string' ? t.get(k) : k;
  };
  // The enum value of kind [n] (`thor.K`: the translator writes it when the
  // app reads `errorKind`), or null.
  T.kind = (n) => T.K?.find((v) => v.name === n) ?? null;
  // `{ok, v}` with what [f] (a decoder of an answer) gives, or the error of
  // an answer the decoder can't read (the server and the app disagree on its
  // shape): a failure like any other, never a throw out of the promise.
  T.dec = (f) => {
    try {
      return { ok: 1, v: f() };
    } catch (x) {
      reportError(x);
      return { k: 'server', e: msg('generic') };
    }
  };
  // Until when the page is leaving for a sign-in (ms since the epoch).
  let leaving = 0;
  T.call = async (h, id, body, ms, ctl = new AbortController()) => {
    let late, r, s;
    if (leaving > Date.now()) return { k: 'aborted', e: msg('aborted') };
    if (ms == null) ms = typeof (r = saved().get('!t')) === 'number' ? r : 30000;
    const t = ms > 0 && setTimeout(() => ((late = 1), ctl.abort()), ms);
    try {
      r = await fetch(location.pathname + location.search, {
        method: 'POST',
        credentials: 'same-origin',
        signal: ctl.signal,
        headers: { 'content-type': 'application/json', [h]: id },
        body: T.str(body),
      });
      s = await r.text();
    } catch (x) {
      const k = late ? 'timeout' : x?.name === 'AbortError' ? 'aborted' : 'network';
      return { k, e: msg(k) };
    } finally {
      clearTimeout(t);
    }
    let m;
    try {
      m = T.parse(s);
    } catch {}
    // Every answer of the server is a JSON object: anything else (a captive
    // portal's page, a proxy's) is not its answer, whatever the status.
    const ok = r.ok && m instanceof Map;
    if (!(m instanceof Map)) m = new Map();
    // Only to a web address: `javascript:` in a `redirect` would run here.
    const to = m.get('redirect');
    // A call already in flight (a query next to the command) may answer 401
    // too: only the first one navigates.
    if (r.status === 401 && typeof to === 'string' && leaving <= Date.now()) {
      try {
        if (/^https?:$/.test(new URL(to, location.href).protocol)) {
          leaving = Date.now() + 5000;
          location.assign(to);
        }
      } catch {}
    }
    // `thor dev` only: the server's error and stack, to its overlay.
    if (m.get('detail')) reportError(Object.assign(new Error(m.get('detail').split('\n')[0]), { stack: m.get('detail') }));
    const z = r.status;
    return {
      ok,
      m,
      k: z === 401 ? 'unauthorized' : z === 403 ? 'forbidden' : z === 400 || z === 422 ? 'validation' : z >= 500 || r.ok ? 'server' : 'client',
      e: typeof m.get('error') === 'string' ? m.get('error') : msg('generic'),
    };
  };
})(thor);
