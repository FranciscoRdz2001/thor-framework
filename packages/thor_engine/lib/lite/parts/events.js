// thor-lite part "events": `events(url, event:)` fields of translated states.
// A query (part "query": the server's value drew the page, the
// four signals, `refresh`) that a native `EventSource` keeps up to date.
//
// One `EventSource` per URL on the page: the states that name it share a hub
// (`hubs`, by absolute URL), which adds one listener per event name and is
// closed when its last subscriber lets go. The state's `onHydrated` opens it
// (`start`, so only a page that names the state opens it) and its `dispose`
// (`stop`: no element names the state any more, or the page is leaving)
// releases it. A hidden page closes every stream (`pagehide`, also a page
// kept for the back button, and a hidden tab: `visibilitychange`); showing it
// opens them again and asks the server for the value (`refresh`, when the
// field has an `initial`), since a new connection has no `Last-Event-ID`.
//
// The browser reconnects by itself after a drop, sending `Last-Event-ID`; the
// state's `connection` is `waiting` meanwhile, `active` when it is open and
// `done` when the browser gave up (the server answered with an error or not
// with an event stream) or the hub was closed: `reconnect()` opens it again.
// Only a path of the page's own origin opens (the translator and `events()`
// check the text; here the resolved URL is compared too).
//
// Every stream also listens for `thor-toast` (`ServerEvent.toast` on the
// server): a message for the page's snack bar, no state involved.
//
// An event's data is JSON (`thor.parse`). Without a key it is the new value
// of `data` (`d` decodes it, as for a query). With a key (`o.k`) `data` is a
// list and the event is a list of items to add or replace, or an object with
// `upsert`, `remove` (keys) and `replace`: the items that did not change are
// the same objects, in the same place; the keys come from the JSON the list
// was made from (the page's state, an answer, an event), parallel to it.
((T) => {
  const hubs = Object.create(null);

  // `tell`s each subscriber where the hub's stream is: an index of
  // `thor.CS` (1 waiting, 2 active, 3 done).
  const tell = (h, k) => {
    h.st = k;
    for (const s of [...h.subs]) s.c(k);
  };
  // `{message, kind?, duration?}`: the page's snack bar (part "toast" of the
  // feedback script: `document.thorToast`) draws it as text. A message that
  // isn't one, or a page without the bar, is dropped (the last one says so).
  const toast = (text) => {
    try {
      const j = T.parse(text), g = (k) => (j instanceof Map ? j.get(k) : undefined);
      const m = g('message'), k = g('kind'), d = g('duration');
      if (typeof m !== 'string' || !m) return;
      if (!document.thorToast) throw Error('thor: this page has no snack bar (THOR-S031)');
      document.thorToast(m.slice(0, 300), k === 'success' || k === 'error' ? k : 'info', typeof d === 'number' && d > 0 ? Math.min(d, 60000) : null);
    } catch (x) {
      fail(x);
    }
  };
  const listen = (h, ev) =>
    h.es.addEventListener(ev, (e) => {
      for (const s of [...h.subs]) s.e === ev && s.f(e.data);
    });
  const open = (h) => {
    // A page that loads hidden opens when it is shown (`on`).
    if (document.hidden) return tell(h, 3);
    let es;
    try {
      es = h.es = new EventSource(h.u);
    } catch (x) {
      h.es = null;
      fail(x);
      return tell(h, 3);
    }
    es.onopen = () => tell(h, 2);
    // A closed source is final (the server refused it): a source that is
    // still connecting is the browser's own reconnection.
    es.onerror = () => tell(h, es.readyState === 2 ? 3 : 1);
    for (const ev of h.evs) listen(h, ev);
    // The server's own `thor-toast` event (`ServerEvent.toast`) shows a
    // message in the page's snack bar, whatever the state listening is.
    es.addEventListener('thor-toast', (e) => toast(e.data));
    tell(h, 1);
  };

  // A subscriber `{e: event, f: data handler, c: connection, r: resumed}`
  // of [u]; the function it returns lets go, and its `o` opens a closed
  // stream again.
  const acquire = (u, s) => {
    let url;
    try {
      url = new URL(u, location.href);
      if (url.origin !== location.origin || !/^https?:$/.test(url.protocol)) throw 0;
    } catch {
      fail(Error(`thor: events('${u}') is not a path of this page's origin`));
      s.c(3);
      const none = () => {};
      return (none.o = none), none;
    }
    let h = hubs[url.href];
    if (!h) {
      h = hubs[url.href] = { u: url.href, subs: new Set(), evs: new Set(), st: 1 };
      h.subs.add(s);
      h.evs.add(s.e);
      open(h);
    } else {
      h.subs.add(s);
      if (!h.evs.has(s.e)) {
        h.evs.add(s.e);
        h.es && listen(h, s.e);
      }
      s.c(h.st);
    }
    const rel = () => {
      if (!h.subs.delete(s) || h.subs.size) return;
      h.es?.close();
      h.es = null;
      if (hubs[h.u] === h) delete hubs[h.u];
    };
    rel.o = () => h.subs.has(s) && (!h.es || h.es.readyState === 2) && open(h);
    return rel;
  };

  // The page is hidden (a background tab, or for good) or kept for the back
  // button: every stream closes, since over HTTP/1.1 a browser allows 6
  // connections per host and 6 tabs with a stream would stall the 7th. It
  // opens again when the page is visible (`visibilitychange`, `pageshow` of
  // a kept page) and asks the server for the value (`refresh`).
  const off = () => {
    for (const h of Object.values(hubs)) {
      h.es?.close();
      h.es = null;
      tell(h, 3);
    }
  };
  const on = () => {
    for (const h of Object.values(hubs))
      if (!h.es) {
        open(h);
        for (const s of [...h.subs]) s.r?.();
      }
  };
  W.addEventListener('pagehide', off);
  W.addEventListener('pageshow', (e) => e.persisted && !document.hidden && on());
  document.addEventListener('visibilitychange', () => (document.hidden ? off : on)());

  // `o`: `{u: url, e: event name, k: key field or null, m: timeout ms or
  // null, i: 1 when the server drew the page with a value}`. [d] decodes the
  // JSON of the whole value.
  T.events = ($, c, n, d, o) => {
    const k = o.k;
    let keys = [];
    const keyOf = (x) => (x instanceof Map ? x.get(k) : x?.[k]);
    const dec = (j) => {
      if (k != null && Array.isArray(j)) keys = j.map(keyOf);
      return d ? d(j) : j;
    };
    const item = (x) => (d ? d([x])[0] : x);
    const q = T.query($, c, n, null, dec, 0, o.m);
    // The server draws a query without a value waiting; so does this one
    // until the first event.
    // ... and there is nothing to ask for: `refresh` does nothing.
    if (!o.i) (q.ssrOff = 1), (q.refresh = () => {});
    const conn = $.state(`${n}$connection`, T.CS[1], (j) => T.CS.find((v) => v.name === j) ?? T.CS[1]);
    q.connection = conn;
    // Nothing to keep across a `thor dev` reload: it re-subscribes (`nr`).
    for (const g of [q.data, q.loading, q.error, conn]) g.nr = 1;
    const snap = q.snapshot;
    q.snapshot = () => {
      const s = snap(), p = q.phase();
      if (p < 3) s.connectionState = p == 2 ? conn.value : T.CS[1];
      return s;
    };
    const list = (v) => {
      if (v == null) return [];
      if (Array.isArray(v)) return v;
      throw Error('thor: an event of a keyed list brings a list of items');
    };
    const apply = (j) => {
      // `{replace: value}` is also an unkeyed field's value (one stream feeds
      // keyed and unkeyed states).
      if (k == null) return (q.data.value = dec(j instanceof Map && j.size == 1 && j.has('replace') ? j.get('replace') : j));
      const m = j instanceof Map;
      if (!m && !Array.isArray(j)) throw Error('thor: an event of a keyed list is a list or an object');
      const up = m ? list(j.get('upsert')) : j, rm = m ? list(j.get('remove')) : [], rep = m && j.get('replace') != null ? list(j.get('replace')) : null;
      let items = rep ? rep.map(item) : [...(q.data.peek() ?? [])];
      let ks = rep ? rep.map(keyOf) : [...keys];
      // A list set by something that left no keys: every item is unknown.
      if (ks.length != items.length) ks = items.map(() => null);
      const at = new Map();
      ks.forEach((x, i) => x != null && at.set(x, i));
      for (const e of up) {
        // No key: it can't be matched, so it is appended (never replaces).
        const id = keyOf(e), i = id == null ? undefined : at.get(id), v = item(e);
        if (i === undefined) {
          if (id != null) at.set(id, items.length);
          items.push(v);
          ks.push(id);
        } else items[i] = v;
      }
      if (rm.length) {
        const gone = new Set(rm), keep = ks.flatMap((x, i) => (gone.has(x) ? [] : [i]));
        items = keep.map((i) => items[i]);
        ks = keep.map((i) => ks[i]);
      }
      keys = ks;
      q.data.value = items;
    };
    const onMsg = (text) => {
      try {
        const j = T.parse(text);
        batch(() => {
          apply(j);
          q.ssrOff = 0;
          q.error.value = null;
        });
      } catch (x) {
        fail(x);
      }
    };
    let rel;
    q.start = () => {
      rel ||= acquire(o.u, { e: o.e, f: onMsg, c: (i) => (conn.value = T.CS[i]), r: () => o.i && q.refresh() });
    };
    q.stop = () => {
      if (!rel) return;
      rel();
      rel = null;
      conn.value = T.CS[3];
    };
    q.reconnect = () => (rel ? rel.o() : q.start());
    return q;
  };
})(thor);
