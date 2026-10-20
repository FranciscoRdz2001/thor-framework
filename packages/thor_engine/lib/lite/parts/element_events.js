// thor-lite part "element_events": thor_ui's `MouseRegion.onEnter/onExit`,
// `Focus.onFocusChange` and `ExpansionTile.onExpansionChanged`
// (`data-t-ev="enter:id;leave:id;focus:id;toggle:id"`).
//
// Not `data-t-on`: `toggle` does not bubble, and enter/leave/focus need the
// related target to tell a boundary between two children (no event) from
// the region's own edge. The usual recipe
// (enter/leave from `mouseover`/`mouseout` + `relatedTarget`, and
// `focusin`/`focusout` + `contains(relatedTarget)`): a pair per element,
// dedupe by a WeakSet so an event the page missed never unbalances it.
//
// A finger never hovers (Flutter's MouseRegion is a mouse's), so only mouse
// and pen count. The engine wakes on the first click/key/focus, not on a
// hover: at that moment the pointer may already be inside a region and the
// focus inside a `Focus`, so `thor:hydrated` reports the state as it is.
((D) => {
  const A = 'data-t-ev';
  const R = D.documentElement;
  const over = new WeakSet(), focus = new WeakSet(), open = new WeakMap();
  const spec = (el) => parseOn(el.getAttribute(A) ?? '');
  const fire = (el, k, v) => {
    const id = spec(el)[k];
    if (id) run(id, el, v);
  };
  // The elements from `t` up that handle `k`.
  const chain = (t, k) => {
    const out = [];
    for (let el = t instanceof Element ? t.closest(`[${A}]`) : null; el; el = el.parentElement?.closest(`[${A}]`)) if (k in spec(el)) out.push(el);
    return out;
  };
  const inside = (el, r) => r instanceof Node && el.contains(r);
  const enter = (el) => {
    if (over.has(el)) return;
    over.add(el);
    fire(el, 'enter');
  };
  const leave = (el) => {
    if (!over.delete(el)) return;
    fire(el, 'leave');
  };
  const gain = (el) => {
    if (focus.has(el)) return;
    focus.add(el);
    fire(el, 'focus', 'true');
  };
  const lose = (el) => {
    if (!focus.delete(el)) return;
    fire(el, 'focus', 'false');
  };

  R.addEventListener(
    'pointerover',
    (e) => {
      if (e.pointerType !== 'touch') for (const el of chain(e.target, 'enter')) if (!inside(el, e.relatedTarget)) enter(el);
    },
    true,
  );
  R.addEventListener(
    'pointerout',
    (e) => {
      if (e.pointerType !== 'touch') for (const el of chain(e.target, 'leave')) if (!inside(el, e.relatedTarget)) leave(el);
    },
    true,
  );
  R.addEventListener(
    'focusin',
    (e) => {
      for (const el of chain(e.target, 'focus')) if (!inside(el, e.relatedTarget)) gain(el);
    },
    true,
  );
  R.addEventListener(
    'focusout',
    (e) => {
      for (const el of chain(e.target, 'focus')) if (!inside(el, e.relatedTarget)) lose(el);
    },
    true,
  );
  // `toggle` does not bubble: capture. It also fires while the parser sets
  // `open` on a tile the server rendered open, and a burst of changes
  // arrives as one event: the report is the state now, once per change.
  // The new state of `el` if it changed since this part last saw it (`old`:
  // what its toggle event says it was), else undefined.
  const change = (el, old) => {
    const now = el.open === true;
    // A tile this part never saw that is open now arrived open (a row the
    // server inserted): its first toggle is its first state, not a change.
    // A user's open is seen first, by the click on its summary (below).
    const before = open.has(el) ? open.get(el) : now ? true : old ? old === 'open' : !now;
    open.set(el, now);
    if (D.readyState !== 'loading' && before !== now) return now;
  };
  // A tile of an exclusive group (`name`): opening one closes another, and the
  // browsers send those two toggles in either order. The group is settled in a
  // microtask (every attribute is final by then) and reports closes first.
  let queued = [];
  const settle = () => {
    const events = queued;
    queued = [];
    const names = new Set(events.map(([el]) => el.getAttribute('name')));
    const seen = new Set(), changes = [];
    const visit = (el, old, known) => {
      if (seen.has(el)) return;
      seen.add(el);
      if (!known && !open.has(el)) return; // a sibling never seen has no state to compare with
      const now = change(el, old);
      if (now !== undefined) changes.push([el, now]);
    };
    for (const [el, old] of events) visit(el, old, true);
    for (const el of D.querySelectorAll('details[name]')) if (names.has(el.getAttribute('name')) && 'toggle' in spec(el)) visit(el, undefined, false);
    for (const close of [false, true]) for (const [el, now] of changes) if (now === close) fire(el, 'toggle', `${now}`);
  };
  R.addEventListener(
    'toggle',
    (e) => {
      const el = e.target;
      if (!(el instanceof Element) || !el.hasAttribute(A) || !('toggle' in spec(el))) return;
      if (el.getAttribute('name')) {
        queued.push([el, e.oldState]);
        if (queued.length === 1) queueMicrotask(settle);
        return;
      }
      const now = change(el, e.oldState);
      if (now !== undefined) fire(el, 'toggle', `${now}`);
    },
    true,
  );

  // The state a tile has before the user changes it: the click (or Enter /
  // Space) on its summary comes before the toggle, so a tile that arrived
  // after the load is known by the time it reports.
  R.addEventListener(
    'click',
    (e) => {
      const s = e.target instanceof Element ? e.target.closest('summary') : null;
      const el = s?.parentElement;
      if (el && el.hasAttribute(A) && !open.has(el) && 'toggle' in spec(el)) open.set(el, el.open === true);
    },
    true,
  );

  D.addEventListener('thor:hydrated', () => {
    const hover = matchMedia('(hover: hover)').matches;
    for (const el of D.querySelectorAll(`[${A}]`)) {
      const s = spec(el);
      if ('toggle' in s) open.set(el, el.open === true);
      if (hover && 'enter' in s && el.matches(':hover')) enter(el);
      if ('focus' in s && el.contains(D.activeElement)) gain(el);
    }
  });
})(document);
