// thor-lite part "frame_messages": `FrameMessages.postToParent` /
// `postToFrame` / `listen` from translated states (`window.postMessage`).
//
// Origins are always explicit (`new URL(o).origin === o`, http(s) only): no
// `'*'` to send or to accept, ever. A listener runs its method only for a
// string from the parent window or an `<iframe>` of this document whose
// `origin` is in its list, up to 1 MiB; anything else is dropped without a
// trace. A throw of the method is reported and does not stop the listener.
((T, D, W) => {
  const MAX = 1 << 20;
  const ok = (o) => {
    if (typeof o !== 'string' || o.includes('*')) return false;
    try {
      const u = new URL(o);
      return /^https?:$/.test(u.protocol) && u.origin === o && o === o.toLowerCase();
    } catch {
      return false;
    }
  };
  const need = (o, what) => {
    if (!ok(o)) throw new Error(`thor: ${what} needs an explicit origin like "https://host:port" (no "*", "null", path or default port) (THOR-S044)`);
    return o;
  };
  const frames = () => [...D.getElementsByTagName('iframe')];
  T.frame = {
    // id: the iframe's id, or null for the parent window.
    post(id, msg, origin) {
      need(origin, id == null ? 'postToParent' : 'postToFrame');
      const w = id == null ? (W.parent !== W ? W.parent : null) : D.getElementById(id)?.contentWindow;
      w?.postMessage(msg, origin);
    },
    listen(origins, fn) {
      if (!Array.isArray(origins) || !origins.length) throw new Error('thor: listen needs at least one explicit origin (THOR-S044)');
      const set = new Set(origins.map((o) => need(o, 'listen')));
      const on = (e) => {
        const s = e.source;
        if (!s || !set.has(e.origin) || typeof e.data !== 'string' || e.data.length > MAX) return;
        if (!((s === W.parent && W.parent !== W) || frames().some((f) => f.contentWindow === s))) return;
        try {
          batch(() => fn(e.origin, e.data))?.then?.(null, fail);
        } catch (x) {
          fail(x);
        }
      };
      W.addEventListener('message', on);
      return {
        cancel() {
          W.removeEventListener('message', on);
        },
      };
    },
  };
})(thor, document, W);
