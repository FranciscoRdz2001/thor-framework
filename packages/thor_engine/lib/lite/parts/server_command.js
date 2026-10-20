// thor-lite part "server_command": `command(fn)` / `commandWith(fn)` fields
// of translated states. The function stays on the server; here a command is
// its signals and `run`, a POST to the page's own URL: the server answers
// through that page's middleware (x-thor-command names it).
//
// Runs queue: a `run` while another is on its way waits its turn and goes
// out after it, in order (a double click sends twice; deleting row B while
// row A is deleting loses neither). `run` returns a promise that never
// rejects: the run's result, or null when it failed (`error` says why).
// `pendingFor(arg)` tells whether that argument is waiting or on its way.
// An argument that is a class travels as JSON: `ae` writes it (`toJson`); a
// simple value or a record goes as it is. `pendingFor` compares by that JSON.
// `ms` (`timeout:`) ends a call that doesn't answer in an error (the change
// may still have happened on the server), and the queue goes on.
// The call names every query of the page (`thor.qs`, part "query", and the
// ones the server drew) with its argument: after the command, the server
// runs those the command changes (`invalidates:`, else all of them) and
// their new values come back in the same answer, `{result, queries,
// errors}`; they go to their queries here. A 401 with `redirect`
// (no session) goes there, like the page (part "server_call").
((T) => {
  T.command = ($, c, n, d, w, ms, ae) => {
    const id = `${$.p}.${n}`;
    const pending = $.state(`${n}$pending`, false),
      error = $.state(`${n}$error`, null),
      kind = $.state(`${n}$errorKind`, null, T.kind),
      result = $.state(`${n}$result`, null, d),
      // The arguments waiting or on their way, the oldest first.
      queue = $.state(`${n}$queue`, []);
    let tail = Promise.resolve();
    const send = async (a) => {
      // The queries the page has (of live states), with their arguments (null when a query
      // takes none): the server refreshes those and no others. The ones it
      // drew (`!q` in #thor-state) whose state nobody touched yet are made
      // now, so their arguments are here.
      const args = Object.create(null), drawn = saved().get('!q');
      if (Array.isArray(drawn)) for (const q of drawn) T.use(`${q}`.slice(0, `${q}`.lastIndexOf('.')));
      // Only the queries of states that are live: one that never woke on
      // this page (`named`, see lifecycle) or ended has nothing to refresh.
      for (const q in T.qs) if (live[q.slice(0, q.lastIndexOf('.'))]?.m) args[q] = T.qs[q].wire();
      const r = await T.call('x-thor-command', id, w ? { arg: ae ? ae(a) : a, queries: args } : { queries: args }, ms);
      let out = null;
      // Whatever happens, this run is over.
      batch(() => {
        try {
          // A result the decoder can't read is an error, yet the change was
          // made: the queries of the answer still land.
          const z = r.ok ? T.dec(() => (d ? d(r.m.get('result')) : (r.m.get('result') ?? null))) : r;
          error.value = z.ok ? null : z.e;
          kind.value = z.ok ? null : T.kind(z.k);
          if (!r.ok) return;
          if (z.ok) out = result.value = z.v;
          const x = (v) => (v instanceof Map ? v : new Map()), qs = x(r.m.get('queries')), es = x(r.m.get('errors')), ks = x(r.m.get('kinds'));
          for (const q of new Set([...qs.keys(), ...es.keys()])) {
            T.use(q.slice(0, q.lastIndexOf('.')));
            if (T.qs && Object.hasOwn(T.qs, q)) T.qs[q].put(qs.get(q), es.get(q), args[q], ks.get(q));
          }
        } finally {
          queue.value = queue.peek().slice(1);
          pending.value = queue.peek().length > 0;
        }
      });
      return out;
    };
    return {
      pending,
      error,
      errorKind: kind,
      result,
      pendingFor: (a) => queue.value.includes(a) || (!!ae && queue.value.some((x) => T.str(ae(x)) === T.str(ae(a)))),
      run(a) {
        // Nothing ahead: out at once, not a microtask later.
        const p = queue.peek().length ? tail.then(() => send(a)) : send(a);
        queue.value = [...queue.peek(), a];
        pending.value = true;
        tail = p.catch(() => {});
        return p;
      },
    };
  };
})(thor);
