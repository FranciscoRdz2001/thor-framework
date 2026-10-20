// thor-lite part "native_drag": thor_ui's `NativeDraggable` and
// `NativeDragTarget` (`data-t-nd`, `data-t-nt`). Needs "drag_kit".
//
// The browser's own drag and drop (HTML5, `dataTransfer`), as opposed to
// "drag_drop"'s pointer events: the drag image is the browser's, the data
// travels in `dataTransfer` (so a page in an `<iframe>`, another window or
// the desktop can take it) and it can come from outside (files, links). A
// native draggable writes its data to `dataTransfer` at `dragstart`; a native
// target takes a drag of this page (the type, then its `accept` method) or a
// foreign one that carries one of its MIME types, and runs `drop` on release.
// The source hears how it ended from `dropEffect` (`none`: nobody took it),
// which also holds when the drop was in another document.
((T, D) => {
  const { call, fits } = T.dnd;
  const R = D.documentElement;
  const EDIT = 'input,textarea,select,[contenteditable]';
  const SOURCE = '[data-t-nd]', TARGET = '[data-t-nt]';
  // The drag that started in this page, the target marked and the depth of
  // dragenter / dragleave (zero: the drag left the document).
  let cur = null, hot = null, depth = 0, pending = 0;

  const num = (v) => `${Math.round(v * 10) / 10}`;
  const el = (e) => (e.target?.nodeType === 1 ? e.target : e.target?.parentElement);
  const mimesOf = (t) => (t.getAttribute('data-t-nt-mime') ?? '').split('\n').filter(Boolean);

  // Whether target `t` takes the drag `e` belongs to.
  function accepts(t, e) {
    if (cur) {
      let ok = cur.asked.get(t);
      if (ok === undefined) {
        ok = fits(t.getAttribute('data-t-nd-type') ?? 'Object', cur.type);
        const accept = ok && parseOn(t.getAttribute('data-t-nt') ?? '').accept;
        if (accept) {
          try {
            ok = call(t, accept, cur.data) === true;
          } catch (x) {
            fail(x);
            ok = false;
          }
        }
        cur.asked.set(t, ok);
      }
      return ok;
    }
    const types = [...(e.dataTransfer?.types ?? [])];
    return mimesOf(t).some((m) => types.includes(m));
  }

  // The first target under the event that takes the drag, else the innermost
  // that does not.
  function targetAt(e) {
    let first = null;
    for (let t = el(e)?.closest(TARGET); t; t = t.parentElement?.closest(TARGET)) {
      if (accepts(t, e)) return [t, true];
      first ??= t;
    }
    return [first, false];
  }

  // Marks `t` as the one under the drag (`ok`: it takes it); the one before
  // hears `leave`.
  function mark(t, ok) {
    if (hot?.t === t && hot.ok === ok) return;
    const was = hot;
    hot = t ? { t, ok } : null;
    if (was) {
      was.t.removeAttribute('data-t-dt-over');
      was.t.removeAttribute('data-t-dt-reject');
      cur?.asked.delete(was.t);
      const leave = parseOn(was.t.getAttribute('data-t-nt') ?? '').leave;
      if (was.ok && leave) run(leave, was.t, cur?.data ?? '');
    }
    if (t) t.toggleAttribute(ok ? 'data-t-dt-over' : 'data-t-dt-reject', true);
  }

  // The `dropEffect` for `t`: its own, else the first the drag allows.
  function effectFor(t, e) {
    const own = t.getAttribute('data-t-nt-effect');
    if (own) return own;
    const allowed = (cur?.effect ?? e.dataTransfer.effectAllowed ?? 'all').toLowerCase();
    if (allowed === 'all' || allowed === 'uninitialized') return 'copy';
    return ['copy', 'move', 'link'].find((w) => allowed.includes(w)) ?? 'none';
  }

  // --- the source ------------------------------------------------------------

  R.addEventListener('dragstart', (e) => {
    const src = el(e)?.closest(SOURCE);
    if (!src || cur) return;
    // A field inside the draggable keeps its own selection drag.
    if (el(e).closest(EDIT)) return;
    const dt = e.dataTransfer;
    if (!dt) return;
    const [mime, allowed] = (src.getAttribute('data-t-nd-cfg') ?? '').split('|');
    if (allowed) dt.effectAllowed = allowed;
    const data = src.getAttribute('data-t-nd-data') ?? '';
    if (src.hasAttribute('data-t-nd-data')) dt.setData(mime || 'text/plain', data);
    let extra = {};
    try {
      extra = JSON.parse(src.getAttribute('data-t-nd-xfer') ?? '{}');
    } catch {
      // A malformed map writes nothing.
    }
    for (const [k, v] of Object.entries(extra)) dt.setData(k, `${v}`);
    const ids = parseOn(src.getAttribute('data-t-nd') ?? '');
    const d = (cur = { src, ids, data, type: src.getAttribute('data-t-nd-type') ?? 'Object', effect: dt.effectAllowed, asked: new Map() });
    // After the browser took the drag image: a style that changes the
    // element now would be in it.
    setTimeout(() => cur === d && src.setAttribute('data-t-nd-active', ''), 0);
    if (ids.start) run(ids.start, src);
  });

  R.addEventListener('dragend', (e) => {
    const d = cur;
    if (!d) return;
    cur = null;
    depth = 0;
    mark(null, false);
    d.src.removeAttribute('data-t-nd-active');
    // `none`: nothing took it (a drop in another document counts).
    const taken = e.dataTransfer?.dropEffect !== 'none';
    if (taken) {
      if (d.ids.done) run(d.ids.done, d.src);
      if (d.ids.end) run(d.ids.end, d.src, 'true');
    } else {
      if (d.ids.cancel) run(d.ids.cancel, d.src, `${num(e.clientX)}~${num(e.clientY)}`);
      if (d.ids.end) run(d.ids.end, d.src, 'false');
    }
  });

  // --- the target ------------------------------------------------------------

  R.addEventListener('dragenter', (e) => {
    depth++;
    const [t, ok] = targetAt(e);
    if (t && ok) e.preventDefault();
  });

  R.addEventListener('dragleave', () => {
    // The drag left the document (the pointer went out of the window or into
    // a frame): nothing is under it any more.
    if (--depth <= 0) {
      depth = 0;
      mark(null, false);
    }
  });

  R.addEventListener('dragover', (e) => {
    const [t, ok] = targetAt(e);
    mark(t, ok);
    if (!t || !ok) return;
    e.preventDefault();
    e.dataTransfer.dropEffect = effectFor(t, e);
    const move = parseOn(t.getAttribute('data-t-nt') ?? '').move;
    // At most once a frame.
    if (move && !pending) {
      pending = requestAnimationFrame(() => (pending = 0));
      const r = t.getBoundingClientRect();
      run(move, t, `${num(e.clientX - r.left)}~${num(e.clientY - r.top)}`);
    }
  });

  R.addEventListener('drop', (e) => {
    depth = 0;
    const [t, ok] = targetAt(e);
    if (!t || !ok) return mark(null, false);
    // The browser would open a dropped link or file.
    e.preventDefault();
    const dt = e.dataTransfer;
    let data = cur?.data ?? '';
    if (!cur) {
      const m = mimesOf(t).find((x) => dt.types.includes(x));
      data = m && m !== 'Files' ? dt.getData(m) : '';
    }
    // It heard the drop, not that the drag left.
    t.removeAttribute('data-t-dt-over');
    hot = null;
    const drop = parseOn(t.getAttribute('data-t-nt') ?? '').drop;
    if (drop) run(drop, t, data);
  });
})(thor, document);
