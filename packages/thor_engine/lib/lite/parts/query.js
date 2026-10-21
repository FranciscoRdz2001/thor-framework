// thor-lite part "query": `query(fn)` / `queryWith(fn, arg:)` fields of
// translated states. The function stays on the server; here a query is its
// four signals (restored from #thor-state, so the page starts with the
// server's value) and `refresh`, a call to the page's own URL (part
// "server_call").
//
// A newer call wins and replaces the one in flight: it is aborted (a
// `setArg` per keystroke leaves one request on the wire), and an answer
// that arrives after another call started is dropped. `ms` (`timeout:`)
// ends a call that doesn't answer in an error. `loading` goes back to false
// whatever happens to the last call.
// `phase()` is the finite state a page switches on (QueryBuilder): 0 waiting
// with nothing to show, 1 waiting with the last value, 2 done, 3 failed (a
// call on its way hides the error of the one before), 4 done with no value
// (the answer was null; a `ssr: false` query nothing has asked yet is 0, as the
// server drew it: the translator sets `ssrOff`). `snapshot()` is
// Flutter's AsyncSnapshot over the same signals, as the translator reads it
// (`connectionState` from `thor.CS`, set when a state uses it).
// Every query is in `thor.qs` by id: a command's answer (part
// "server_command") brings the page's new values and puts them there.
// An argument that is a class or a record travels as JSON: `ad` decodes it
// (the page's state, the class's `fromJson`), `ae` writes it (`toJson`; a
// record is written as it is). Two arguments are the same when their JSON
// is: `setArg` with an equal value asks nothing (unless the last call
// failed), and an answer for the argument the command sent lands even if
// the state holds another object of that value.
// A `Form(stay: true)` that was answered (`thor:stay`, form_stay.js) asks the
// page's queries again, the ones the server drew included: what the form saved
// shows without a reload.
((T) => {
  T.query = ($, c, n, a, d, w, ms, ad, ae = (x) => x) => {
    const id = `${$.p}.${n}`;
    const data = $.state(`${n}$data`, null, d),
      loading = $.state(`${n}$loading`, false),
      error = $.state(`${n}$error`, null),
      kind = $.state(`${n}$errorKind`, null, T.kind),
      arg = $.state(`${n}$arg`, a, ad);
    // The argument as the server gets it, and as text to compare.
    // Compared with the keys sorted (TanStack Query hashes its keys that way):
    // `(page: 2, q: 'x')` and `(q: 'x', page: 2)` are one record in Dart.
    const wire = () => ae(arg.peek()),
      sorted = (v) =>
        Array.isArray(v)
          ? v.map(sorted)
          : v instanceof Map || v?.constructor === Object
            ? new Map(
                (v instanceof Map ? [...v] : Object.entries(v))
                  .map(([k, e]) => [`${k}`, sorted(e)])
                  .sort((x, y) => (x[0] < y[0] ? -1 : x[0] > y[0] ? 1 : 0)),
              )
            : v,
      key = (x) => T.str(sorted(x)),
      same = (x) => key(x) === key(wire());
    let seq = 0, ctl;
    const done = (my, f) =>
      my === seq &&
      batch(() => {
        try {
          f();
        } finally {
          loading.value = false;
        }
      });
    // What lands from an answer [r]: `{ok, v}` (the value) or `{k, e}`.
    const land = (r) => {
      if (r.ok) data.value = r.v;
      error.value = r.ok ? null : r.e;
      kind.value = r.ok ? null : T.kind(r.k);
    };
    const q = {
      data,
      loading,
      error,
      errorKind: kind,
      arg,
      phase: () => (loading.value ? (data.value == null ? 0 : 1) : error.value != null ? 3 : data.value == null ? (q.ssrOff ? 0 : 4) : 2),
      snapshot() {
        const p = q.phase(), f = p == 3, v = f ? null : data.value;
        return {
          connectionState: T.CS[p < 2 ? 1 : 3],
          data: v,
          hasData: v != null,
          error: f ? error.value : null,
          errorKind: f ? kind.value : null,
          hasError: f,
        };
      },
      refresh() {
        const my = ++seq;
        ctl?.abort();
        q.ssrOff = 0;
        loading.value = true;
        T.call('x-thor-query', id, w ? { arg: wire() } : {}, ms, (ctl = new AbortController())).then((r) =>
          done(my, () => land(r.ok ? T.dec(() => (d ? d(r.m.get('data')) : r.m.get('data'))) : r)),
        );
      },
      setArg(v) {
        // The same value, and nothing wrong with the last call: nothing new
        // to ask (`refresh` reloads).
        const t = key(ae(v)) === key(wire()) && error.peek() == null;
        arg.value = v;
        if (!t) q.refresh();
      },
      // A value (or an error) from another answer, computed for the argument
      // [sent] (what the browser had when it asked): if the argument moved on
      // since, it is stale and dropped (page 1's rows never overwrite page
      // 2's). Otherwise it is newer than any call on its way, which is
      // aborted and dropped.
      put(v, e, sent, k) {
        if (w && sent !== undefined && !same(sent)) return;
        const my = ++seq;
        ctl?.abort();
        q.ssrOff = 0;
        done(my, () => land(e == null ? T.dec(() => (d ? d(v) : v)) : { e, k }));
      },
      w,
      wire,
    };
    (T.qs ||= Object.create(null))[id] = q;
    return q;
  };
  document.documentElement.addEventListener('thor:stay', (e) => {
    if (!e.detail?.ok) return;
    const drawn = saved().get('!q');
    if (Array.isArray(drawn)) for (const q of drawn) T.use(`${q}`.slice(0, `${q}`.lastIndexOf('.')));
    for (const q in T.qs) if (live[q.slice(0, q.lastIndexOf('.'))]?.m) T.qs[q].refresh();
  });
})(thor);
