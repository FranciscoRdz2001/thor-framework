// thor-lite part "reorderable": thor_ui's `ReorderableListView` (`data-t-ro`;
// the dart2js engine's ReorderableFeature). Needs "drag_kit".
//
// The dragged item follows the pointer through `--t-ro-x/y` (its class maps
// them to `translate`) and the others slide to make room: the engine measures
// the items' boxes each frame (their own offsets taken off), finds the place
// the dragged one would take and writes each item's offset; the CSS
// transitions do the rest. On release the dragged item settles in its place,
// then the engine moves it in the page, clears every offset and calls
// `reorder` (the old index and the new one, as Flutter counts them: before
// the item leaves). A `Watch.list` finds its rows already in order.
// The keyboard: a handle's Space or Enter picks an item up, the arrows move
// it, Space or Enter drops it, Escape puts it back; Alt+arrow moves the item
// the focus is in by one place. A live region says each step.
((T, D) => {
  const { say, name, fill, words, autoscroll, calm } = T.dnd;
  const R = D.documentElement;
  const EDIT = 'input,textarea,select,[contenteditable]';
  const SLOP = 4, SLOP_TOUCH = 8, HOLD = 500, MS = 200;
  const ENGLISH = [
    'Picked up {item}, position {position} of {count}. Use the arrow keys to move it, Space to drop it, Escape to cancel.',
    '{item}, position {position} of {count}.',
    'Dropped {item} at position {position} of {count}.',
    'Cancelled. {item} is back at position {position} of {count}.',
    'Reorder {item}',
  ];
  let press = null, drag = null, held = null, suppress = null;

  const hostOf = (el) => el?.closest?.('[data-t-ro]');
  const itemsOf = (host) => [...host.children].filter((c) => c.hasAttribute('data-t-ro-item'));
  // The item of `host` that holds `el`.
  const itemOf = (host, el) => {
    for (let n = el; n && n !== host; n = n.parentElement) if (n.parentElement === host) return n.hasAttribute('data-t-ro-item') ? n : null;
    return null;
  };
  const setup = (host) => {
    const a = (host.getAttribute('data-t-ro-cfg') ?? 'v|1').split('|');
    return { v: a[0] !== 'h', touch: a[1] === '1' };
  };
  // The axis in "u": increasing with the items' order (a right-to-left row
  // runs toward the left).
  const axis = (host) => {
    const v = setup(host).v;
    return { v, r: !v && getComputedStyle(host).direction === 'rtl' };
  };
  // An item's start and size along the axis, in the viewport's coordinates, from its layout
  // (its offsets and the box they are measured from): never from its drawn box, which has its
  // own `translate` in it (and a transition running).
  const box = (L, el) => {
    const op = el.offsetParent ?? R, r = op.getBoundingClientRect();
    if (L.v) return [r.top + (op.clientTop || 0) - (op.scrollTop || 0) + el.offsetTop, el.offsetHeight];
    const x = r.left + (op.clientLeft || 0) - (op.scrollLeft || 0) + el.offsetLeft;
    return [L.r ? -(x + el.offsetWidth) : x, el.offsetWidth];
  };
  const ptr = (L, x, y) => (L.v ? y : L.r ? -x : x);
  const round = (v) => Math.round(v * 10) / 10;
  // An offset of `v` (in u) written to an item.
  const put = (el, L, v) => el.style.setProperty(L.v ? '--t-ro-y' : '--t-ro-x', `${round(L.r ? -v : v)}px`);
  const clear = (items) => {
    for (const el of items) {
      el.removeAttribute('data-t-ro-drag');
      el.removeAttribute('data-t-ro-shift');
      el.removeAttribute('data-t-ro-settle');
      el.style.removeProperty('--t-ro-x');
      el.style.removeProperty('--t-ro-y');
    }
  };
  const later = (fn) => setTimeout(fn, calm() ? 20 : MS + 30);
  // The item's name: its text, without the handles' (they are buttons, not words).
  const label = (item) => {
    const c = item.cloneNode(true);
    for (const h of c.querySelectorAll('[data-t-ro-h]')) h.remove();
    return name(c);
  };
  const say2 = (host, k, item, pos, count) => say(fill(words(host, 'data-t-ro-say', ENGLISH)[k], label(item)).replaceAll('{position}', `${pos}`).replaceAll('{count}', `${count}`));
  // The method of the list by key (`reorder`, `start`, `end`) with `value`.
  const fire = (host, k, value) => {
    const id = parseOn(host.getAttribute('data-t-ro') ?? '')[k];
    if (id) run(id, host, value);
  };
  // A move that keeps the focus where it is (the state-preserving move where the browser has one).
  function move(host, item, ref) {
    const focus = D.activeElement;
    try {
      if (host.moveBefore) host.moveBefore(item, ref);
      else host.insertBefore(item, ref);
    } catch {
      host.insertBefore(item, ref);
    }
    if (focus && D.activeElement !== focus && focus.isConnected) focus.focus({ preventScroll: true });
  }

  // --- pointer ---------------------------------------------------------------

  // One frame: the boxes with their own offsets taken off, where the dragged
  // item would go, and each item's offset.
  function frame(d) {
    d.frame = 0;
    if (drag !== d) return;
    const { list, from, L } = d, n = list.length;
    const bs = list.map((e) => box(L, e));
    const base = bs.map((b) => b[0]), size = bs.map((b) => b[1]);
    // Where the dragged item's start is wanted, kept inside the list.
    const want = Math.min(Math.max(ptr(L, ...d.at) - d.grab, base[0]), base[n - 1] + size[n - 1] - size[from]);
    const center = want + size[from] / 2;
    let t = from;
    // (A tie is the item at the end of the list, where the box is held in.)
    while (t < n - 1 && center >= base[t + 1] + size[t + 1] / 2) t++;
    while (t > 0 && center <= base[t - 1] + size[t - 1] / 2) t--;
    // The places once the item is there, the gap between items kept.
    const gap = n > 1 ? (base[n - 1] + size[n - 1] - base[0] - size.reduce((a, b) => a + b, 0)) / (n - 1) : 0;
    const order = list.map((_, i) => i).filter((i) => i !== from);
    order.splice(t, 0, from);
    let pos = base[0];
    const next = [];
    for (const i of order) {
      next[i] = pos;
      pos += size[i] + gap;
    }
    for (let i = 0; i < n; i++) {
      const v = i === from ? want - base[i] : next[i] - base[i];
      if (Math.abs(v - d.cur[i]) < 0.1) continue;
      d.cur[i] = v;
      put(list[i], L, v);
      if (i !== from) list[i].setAttribute('data-t-ro-shift', '');
    }
    d.to = t;
    d.settle = next[from] - base[from];
  }

  const schedule = (d) => (d.frame ||= requestAnimationFrame(() => frame(d)));

  function begin(host, item, pid, x, y) {
    const list = itemsOf(host), from = list.indexOf(item);
    if (from < 0) return null;
    const L = axis(host);
    const d = { host, item, list, from, to: from, L, pid, at: [x, y], grab: ptr(L, x, y) - box(L, item)[0], cur: list.map(() => 0), settle: 0, frame: 0, stop: null };
    drag = d;
    item.setAttribute('data-t-ro-drag', '');
    fire(host, 'start', `${from}`);
    d.stop = autoscroll(() => d.at);
    return d;
  }

  // The drag ends: the item settles in its place (`drop`), or everything goes
  // back; then the page changes and the state hears it.
  function end(d, drop) {
    if (drag !== d) return;
    d.stop?.();
    // The last position counts: the pointer may have moved since the frame.
    cancelAnimationFrame(d.frame);
    d.frame = 0;
    if (drop) frame(d);
    drag = null;
    const { host, item, list, from, L } = d;
    const to = drop ? d.to : from;
    item.removeAttribute('data-t-ro-drag');
    item.setAttribute('data-t-ro-settle', '');
    for (let i = 0; i < list.length; i++) {
      if (i !== from) list[i].setAttribute('data-t-ro-shift', '');
      put(list[i], L, drop && i === from ? d.settle : drop ? d.cur[i] : 0);
    }
    later(() => {
      if (!item.isConnected) return clear(list);
      if (to !== from) move(host, item, to > from ? list[to].nextSibling : list[to]);
      clear(list);
      if (to !== from) fire(host, 'reorder', `${from}~${to > from ? to + 1 : to}`);
      fire(host, 'end', `${to}`);
    });
  }
  const stopPress = () => {
    clearTimeout(press?.timer);
    press = null;
  };

  R.addEventListener('pointerdown', (e) => {
    if (drag || held) return;
    if (e.button !== 0 && e.pointerType === 'mouse') return;
    const h = e.target.closest?.('[data-t-ro-h]');
    const host = hostOf(h ?? e.target), item = host && itemOf(host, h ?? e.target);
    if (!item) return;
    let delayed;
    if (h && hostOf(h) === host) delayed = h.getAttribute('data-t-ro-h') === 'delayed';
    // A held finger anywhere on the item drags it (not under a field).
    else if (e.pointerType !== 'mouse' && setup(host).touch && !e.target.closest(EDIT)) delayed = true;
    else return;
    stopPress();
    const p = (press = { host, item, id: e.pointerId, x: e.clientX, y: e.clientY, touch: e.pointerType !== 'mouse', delayed, timer: 0 });
    if (delayed) {
      p.timer = setTimeout(() => {
        if (press !== p) return;
        press = null;
        if (begin(host, item, p.id, p.x, p.y)) {
          suppress = item;
          try {
            item.setPointerCapture(p.id);
          } catch {
            // A pointer the browser no longer tracks.
          }
          schedule(drag);
        }
      }, HOLD);
    }
  });

  R.addEventListener('pointermove', (e) => {
    const d = drag;
    if (d && e.pointerId === d.pid) {
      d.at = [e.clientX, e.clientY];
      schedule(d);
      return;
    }
    const p = press;
    if (!p || e.pointerId !== p.id || d) return;
    if (Math.hypot(e.clientX - p.x, e.clientY - p.y) < (p.touch ? SLOP_TOUCH : SLOP)) return;
    stopPress();
    // Moving before the hold is a scroll; a handle starts at once.
    if (p.delayed) return;
    if (begin(p.host, p.item, p.id, p.x, p.y)) {
      suppress = p.item;
      drag.at = [e.clientX, e.clientY];
      schedule(drag);
      try {
        p.item.setPointerCapture(p.id);
      } catch {
        // A pointer the browser no longer tracks.
      }
    }
  });

  R.addEventListener('pointerup', (e) => {
    const d = drag;
    if (d && e.pointerId === d.pid) {
      d.at = [e.clientX, e.clientY];
      end(d, true);
      const el = d.item;
      setTimeout(() => suppress === el && (suppress = null), 60);
    } else if (press && e.pointerId === press.id) stopPress();
  });

  R.addEventListener('pointercancel', (e) => {
    const d = drag;
    if (d && e.pointerId === d.pid) {
      end(d, false);
      suppress = null;
    } else if (press && e.pointerId === press.id) stopPress();
  });

  // A finger that drags must not scroll the page: only a non-passive listener
  // can cancel the browser's decision on `touchmove`.
  D.addEventListener('touchmove', (e) => drag && e.cancelable && e.preventDefault(), { passive: false });
  R.addEventListener('dragstart', (e) => (drag || press) && e.preventDefault());
  R.addEventListener('contextmenu', (e) => (drag || press?.delayed) && e.preventDefault());
  R.addEventListener(
    'click',
    (e) => {
      const el = suppress;
      if (!el) return;
      suppress = null;
      if (e.target instanceof Node && el.contains(e.target)) {
        e.stopImmediatePropagation();
        e.preventDefault();
      }
    },
    true,
  );

  // --- keyboard --------------------------------------------------------------

  // The handle's name says which item it moves (the server cannot: a cloned
  // row has no text yet).
  R.addEventListener('focusin', (e) => {
    const h = e.target.closest?.('[data-t-ro-h]');
    const host = hostOf(h), item = host && itemOf(host, h);
    const tpl = item && words(host, 'data-t-ro-say', ENGLISH)[4];
    if (tpl?.includes('{item}')) h.setAttribute('aria-label', fill(tpl, label(item)));
  });

  // Moves `item` one place along the list; says where it is now. Returns
  // whether it moved. The two items that swap slide into their new places.
  function step(host, item, delta, k) {
    const list = itemsOf(host), i = list.indexOf(item), j = i + delta;
    if (j < 0 || j >= list.length) {
      say2(host, 1, item, i + 1, list.length);
      return false;
    }
    const other = list[j], L = axis(host);
    const a = box(L, item)[0], b = box(L, other)[0];
    move(host, item, delta > 0 ? other.nextSibling : other);
    const a2 = box(L, item)[0], b2 = box(L, other)[0];
    if (!calm()) {
      put(item, L, a - a2);
      put(other, L, b - b2);
      item.getBoundingClientRect();
      for (const el of [item, other]) el.setAttribute('data-t-ro-shift', '');
      put(item, L, 0);
      put(other, L, 0);
      later(() => clear([item, other]));
    }
    item.scrollIntoView({ block: 'nearest', inline: 'nearest' });
    say2(host, k, item, j + 1, list.length);
    return true;
  }

  // The arrow of the list's axis as a step of -1 or 1 (`ArrowRight` goes
  // backward in a right-to-left row).
  const delta = (host, key) => {
    const L = axis(host);
    if (L.v) return key === 'ArrowDown' ? 1 : key === 'ArrowUp' ? -1 : 0;
    const right = key === 'ArrowRight' ? 1 : key === 'ArrowLeft' ? -1 : 0;
    return L.r ? -right : right;
  };

  R.addEventListener(
    'keydown',
    (e) => {
      // A picked-up item: every key is the reorder's while it lasts.
      if (held) {
        const { host, item } = held, k = e.key;
        const list = itemsOf(host), here = list.indexOf(item);
        const dl = delta(host, k);
        if (dl) step(host, item, dl, 1);
        else if (k === 'Home' || k === 'End') step(host, item, (k === 'Home' ? -here : list.length - 1 - here), 1);
        else if (k === ' ' || k === 'Enter') {
          const to = here, from = held.from;
          held = null;
          if (to !== from) fire(host, 'reorder', `${from}~${to > from ? to + 1 : to}`);
          fire(host, 'end', `${to}`);
          say2(host, 2, item, to + 1, list.length);
        } else if (k === 'Escape') {
          const { from, ref } = held;
          held = null;
          move(host, item, ref?.parentNode === host ? ref : null);
          fire(host, 'end', `${from}`);
          say2(host, 3, item, from + 1, list.length);
        } else return;
        e.preventDefault();
        e.stopImmediatePropagation();
        return;
      }
      if (drag) return void (e.key === 'Escape' && (end(drag, false), e.preventDefault()));
      if (e.defaultPrevented) return;
      const h = e.target.closest?.('[data-t-ro-h]');
      const host = hostOf(e.target), item = host && itemOf(host, e.target);
      if (!item) return;
      // Space or Enter on a handle picks the item up.
      if (h && e.target === h && !e.altKey && !e.ctrlKey && !e.metaKey && !e.shiftKey && (e.key === ' ' || e.key === 'Enter')) {
        const list = itemsOf(host);
        held = { host, item, from: list.indexOf(item), ref: item.nextSibling };
        fire(host, 'start', `${held.from}`);
        say2(host, 0, item, held.from + 1, list.length);
        e.preventDefault();
        return;
      }
      // Alt+arrow anywhere in an item (not in a field): one place, at once.
      const dl = e.altKey && !e.ctrlKey && !e.metaKey && !e.shiftKey && !e.target.closest(EDIT) ? delta(host, e.key) : 0;
      if (!dl) return;
      e.preventDefault();
      const list = itemsOf(host), from = list.indexOf(item);
      if (step(host, item, dl, 2)) {
        const to = from + dl;
        fire(host, 'reorder', `${from}~${to > from ? to + 1 : to}`);
      }
    },
    true,
  );
  // The press of a native handle that picked an item up does not click.
  R.addEventListener('keyup', (e) => held && (e.key === ' ' || e.key === 'Enter') && e.preventDefault(), true);
  // The focus leaving the list drops a keyboard drag back where it was.
  R.addEventListener('focusout', (e) => {
    if (!held || held.host.contains(e.relatedTarget)) return;
    const { host, item, from, ref } = held;
    held = null;
    move(host, item, ref?.parentNode === host ? ref : null);
    fire(host, 'end', `${from}`);
  });
})(thor, document);
