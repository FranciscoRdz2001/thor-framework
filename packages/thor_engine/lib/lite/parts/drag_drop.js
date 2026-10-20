// thor-lite part "drag_drop": thor_ui's `Draggable`, `LongPressDraggable` and
// `DragTarget` (`data-t-dg`, `data-t-dt`; the dart2js engine's DragDropFeature).
// Needs "drag_kit".
//
// Pointer events, not the HTML5 drag-and-drop (a finger cannot start that):
// the draggable's feedback template is cloned as a fixed element (a manual
// popover, so it is above a modal dialog) and moved with `--t-dg-x/y`, which
// its own class maps to `translate`. The targets under the pointer are found
// with `elementsFromPoint` each frame; the target's state method says whether
// it accepts (`accept`, a bool) when the pointer enters it, `move` runs at
// most once a frame, `drop` runs on release. Space or Enter picks a draggable
// up from the keyboard, the arrows (and Tab) move between the targets that
// fit it, Space or Enter drops it, Escape cancels; a live region says each
// step.
((T, D) => {
  const { say, name, fill, words, call, autoscroll, fits } = T.dnd;
  const R = D.documentElement;
  const SLOP = 6, SLOP_TOUCH = 10;
  const EDIT = 'input,textarea,select,[contenteditable]';
  const ENGLISH = [
    'Picked up {item}. Use the arrow keys to choose where to drop it, Space to drop it, Escape to cancel.',
    '{target}: it can be dropped here.',
    '{target}: it cannot be dropped here.',
    'Dropped {item} on {target}.',
    'Cancelled. {item} was not moved.',
  ];
  let press = null, drag = null, suppress = null;

  const setup = (src) => {
    const a = (src.getAttribute('data-t-dg-cfg') ?? '').split('|');
    return { axis: a[0] ?? 'f', delay: +a[1] || 0, anchor: a[2] ?? 'c', max: a[3] == null ? 1 : +a[3], ox: parseFloat(a[4]) || 0, oy: parseFloat(a[5]) || 0 };
  };
  const num = (v) => `${Math.round(v * 10) / 10}`;
  const rtl = (el) => getComputedStyle(el).direction === 'rtl';
  const templateOf = (src, attr) => {
    for (const t of src.querySelectorAll(':scope > template')) if (t.hasAttribute(attr)) return t;
    // A wrapper (a `Tooltip`'s bubble) can sit between the element and the
    // templates the server put beside it: look at the next siblings, up to
    // the next draggable.
    for (let n = src.nextElementSibling; n && !n.hasAttribute('data-t-dg'); n = n.nextElementSibling) {
      if (n.tagName === 'TEMPLATE' && n.hasAttribute(attr)) return n;
    }
    return null;
  };

  // Whether a target takes this drag: the type, then its `accept` method.
  function accepts(d, t) {
    if (!fits(t.getAttribute('data-t-dg-type') ?? 'Object', d.type)) return false;
    const ids = parseOn(t.getAttribute('data-t-dt') ?? '');
    if (!ids.accept) return true;
    let r;
    try {
      r = call(t, ids.accept, d.data);
    } catch (x) {
      fail(x);
    }
    return r === true;
  }

  // Marks `t` as the one under the drag (`ok`: a draggable it takes), after
  // the one before leaves.
  function hover(d, t, ok) {
    const was = d.over;
    if (was?.t === t && was.ok === ok) return;
    if (was) {
      was.t.removeAttribute('data-t-dt-over');
      was.t.removeAttribute('data-t-dt-reject');
      d.asked.delete(was.t);
      const leave = parseOn(was.t.getAttribute('data-t-dt') ?? '').leave;
      if (was.ok && leave) run(leave, was.t, d.data);
    }
    d.over = t ? { t, ok } : null;
    if (t) t.toggleAttribute(ok ? 'data-t-dt-over' : 'data-t-dt-reject', true);
  }

  // The target under (x, y): the first one that takes the drag, else the
  // innermost one that does not.
  function targetAt(d, x, y) {
    let first = null;
    const seen = new Set();
    for (const el of D.elementsFromPoint(x, y)) {
      for (let t = el.closest?.('[data-t-dt]'); t; t = t.parentElement?.closest('[data-t-dt]')) {
        if (seen.has(t)) continue;
        seen.add(t);
        let ok = d.asked.get(t);
        if (ok === undefined) d.asked.set(t, (ok = accepts(d, t)));
        if (ok) return [t, true];
        first ??= t;
      }
    }
    return first ? [first, false] : [null, false];
  }

  function place(d) {
    const [x, y] = d.at, c = d.cfg, r = d.rect;
    let gx, gy;
    if (d.mode === 'kb') [gx, gy] = d.kb;
    else if (c.anchor === 'p') {
      // The feedback's corner is at the pointer (a locked axis keeps the child's own).
      gx = (c.axis === 'v' ? r.left : x) + c.ox;
      gy = (c.axis === 'h' ? r.top : y) + c.oy;
    } else {
      // The feedback keeps the distance the child had from the pointer.
      gx = r.left + (c.axis === 'v' ? 0 : x - d.x0) + c.ox;
      gy = r.top + (c.axis === 'h' ? 0 : y - d.y0) + c.oy;
    }
    d.ghost.style.setProperty('--t-dg-x', `${num(gx)}px`);
    d.ghost.style.setProperty('--t-dg-y', `${num(gy)}px`);
  }

  // One frame of a pointer drag: the ghost, the target under it, `move`.
  function frame(d) {
    d.frame = 0;
    if (drag !== d) return;
    place(d);
    const [t, ok] = targetAt(d, ...d.at);
    hover(d, t, ok);
    if (t && ok) {
      const move = parseOn(t.getAttribute('data-t-dt') ?? '').move;
      if (move && d.at.join() !== d.sent) {
        d.sent = d.at.join();
        const r = t.getBoundingClientRect();
        run(move, t, `${num(d.at[0] - r.left)}~${num(d.at[1] - r.top)}`);
      }
    }
  }

  // A clone of a template shows what the page showed when it was drawn: a text
  // the row binds (`data-tf`) or the page binds (`data-tt`) is the live one's.
  function live(clone, src) {
    for (const f of clone.querySelectorAll('[data-tf],[data-tt]')) {
      const a = f.hasAttribute('data-tf') ? 'data-tf' : 'data-tt', id = f.getAttribute(a);
      for (const o of a === 'data-tf' ? [src, ...src.querySelectorAll(`[${a}]`)] : D.querySelectorAll(`[${a}]`)) {
        if (o.getAttribute(a) === id) {
          f.textContent = o.textContent;
          break;
        }
      }
    }
    return clone;
  }

  // The drag starts: the ghost from the feedback template, the source marked,
  // `childWhenDragging` in its place.
  function begin(src, mode, x, y, pointer) {
    const fb = templateOf(src, 'data-t-dg-fb')?.content.firstElementChild;
    if (!fb) return null;
    const cfg = setup(src), ids = parseOn(src.getAttribute('data-t-dg') ?? '');
    const d = { src, cfg, ids, mode, type: src.getAttribute('data-t-dg-type') ?? 'Object', data: src.getAttribute('data-t-dg-data') ?? '', rect: src.getBoundingClientRect(), x0: x, y0: y, at: [x, y], over: null, asked: new Map(), frame: 0, sent: '', ph: null, ghost: live(fb.cloneNode(true), src), pointer, stop: null };
    drag = d;
    d.ghost.setAttribute('popover', 'manual');
    D.body.append(d.ghost);
    try {
      d.ghost.showPopover();
    } catch {
      // No popovers: a fixed element with a high z-index.
    }
    src.setAttribute('data-t-dg-active', '');
    // The child is replaced by `childWhenDragging` while a pointer drags it.
    const ph = mode === 'ptr' && templateOf(src, 'data-t-dg-ph')?.content.firstElementChild;
    if (ph) {
      d.ph = live(ph.cloneNode(true), src);
      src.before(d.ph);
      src.setAttribute('data-t-dg-gone', '');
    }
    if (ids.start) run(ids.start, src);
    // The page scrolls under a pointer near its edge (not under a keyboard's drag).
    if (mode === 'ptr') d.stop = autoscroll(() => d.at);
    return d;
  }

  // The drag ends: everything it put in the page goes, and the source's
  // methods hear how it ended (`accepted`).
  function finish(d, accepted, x, y) {
    if (drag !== d) return;
    drag = null;
    d.stop?.();
    cancelAnimationFrame(d.frame);
    const over = d.over, dropped = accepted && over?.ok;
    // Dropped on a target that took it: it hears the drop, not that it left.
    if (dropped) {
      over.t.removeAttribute('data-t-dt-over');
      d.over = null;
    } else hover(d, null, false);
    const drop = dropped ? parseOn(over.t.getAttribute('data-t-dt') ?? '').drop : null;
    d.ghost.remove();
    d.ph?.remove();
    d.src.removeAttribute('data-t-dg-active');
    d.src.removeAttribute('data-t-dg-gone');
    if (d.pointer != null) {
      try {
        d.src.releasePointerCapture(d.pointer);
      } catch {
        // Already released.
      }
    }
    if (dropped) {
      if (drop) run(drop, over.t, d.data);
      if (d.ids.done) run(d.ids.done, d.src);
      if (d.ids.end) run(d.ids.end, d.src, 'true');
    } else {
      if (d.ids.cancel) run(d.ids.cancel, d.src, `${num(x)}~${num(y)}`);
      if (d.ids.end) run(d.ids.end, d.src, 'false');
    }
    return over;
  }

  // --- pointer ---------------------------------------------------------------

  const stopPress = () => {
    clearTimeout(press?.timer);
    press = null;
  };

  R.addEventListener('pointerdown', (e) => {
    if (drag) return;
    if (e.button !== 0 && e.pointerType === 'mouse') return;
    const src = e.target.closest?.('[data-t-dg]');
    if (!src || e.target.closest(EDIT)) return;
    const cfg = setup(src);
    if (!cfg.max) return;
    stopPress();
    const p = (press = { src, id: e.pointerId, x: e.clientX, y: e.clientY, touch: e.pointerType !== 'mouse', cfg, ready: !cfg.delay, timer: 0 });
    // A hold first: moving before it ends is a scroll, not a drag.
    if (cfg.delay) {
      p.timer = setTimeout(() => {
        if (press !== p) return;
        press = null;
        if (begin(src, 'ptr', p.x, p.y, p.id)) {
          suppress = src;
          try {
            src.setPointerCapture(p.id);
          } catch {
            // A pointer the browser no longer tracks.
          }
          drag.frame = requestAnimationFrame(() => frame(drag));
        }
      }, cfg.delay);
    }
  });

  R.addEventListener('pointermove', (e) => {
    const d = drag;
    if (d?.mode === 'ptr' && e.pointerId === d.pointer) {
      d.at = [e.clientX, e.clientY];
      d.frame ||= requestAnimationFrame(() => frame(d));
      return;
    }
    const p = press;
    if (!p || e.pointerId !== p.id || d) return;
    if (Math.hypot(e.clientX - p.x, e.clientY - p.y) < (p.touch ? SLOP_TOUCH : SLOP)) return;
    // Past the slop: a drag at once, or (waiting for a hold) a scroll.
    if (!p.ready) return stopPress();
    stopPress();
    if (begin(p.src, 'ptr', p.x, p.y, p.id)) {
      suppress = p.src;
      drag.at = [e.clientX, e.clientY];
      drag.frame ||= requestAnimationFrame(() => frame(drag));
      try {
        p.src.setPointerCapture(p.id);
      } catch {
        // A pointer the browser no longer tracks.
      }
    }
  });
  R.addEventListener('pointerup', (e) => {
    const d = drag;
    if (d?.mode === 'ptr' && e.pointerId === d.pointer) {
      // The last position counts: the pointer may have moved since the frame.
      const [x, y] = (d.at = [e.clientX, e.clientY]);
      const [t, ok] = targetAt(d, x, y);
      hover(d, t, ok);
      finish(d, true, x, y);
      const el = d.src;
      setTimeout(() => suppress === el && (suppress = null), 60);
      return;
    }
    if (press && e.pointerId === press.id) stopPress();
  });

  R.addEventListener('pointercancel', (e) => {
    const d = drag;
    if (d?.mode === 'ptr' && e.pointerId === d.pointer) {
      finish(d, false, ...d.at);
      suppress = null;
    }
    if (press && e.pointerId === press.id) stopPress();
  });

  // A finger that is dragging must not scroll the page: the browser decides
  // that on `touchmove`, which only a non-passive listener can cancel.
  D.addEventListener('touchmove', (e) => drag?.mode === 'ptr' && e.cancelable && e.preventDefault(), { passive: false });
  // The browser's own drag of an image or a link, and a touch's menu.
  R.addEventListener('dragstart', (e) => (drag || press) && e.preventDefault());
  R.addEventListener('contextmenu', (e) => (drag || (press && !press.ready)) && e.preventDefault());

  // A drag that moved must not also click.
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

  // The targets that fit the draggable, in the page's order.
  const targetsFor = (d) => [...D.querySelectorAll('[data-t-dt]')].filter((t) => fits(t.getAttribute('data-t-dg-type') ?? 'Object', d.type) && t.getClientRects().length);

  function pick(d, i) {
    const list = d.list;
    d.i = Math.min(Math.max(i, 0), list.length - 1);
    const t = list[d.i];
    if (!t) return;
    let ok = d.asked.get(t);
    if (ok === undefined) d.asked.set(t, (ok = accepts(d, t)));
    hover(d, t, ok);
    t.scrollIntoView({ block: 'nearest', inline: 'nearest' });
    const r = t.getBoundingClientRect(), g = d.ghost.getBoundingClientRect();
    d.kb = [r.left + r.width / 2 - g.width / 2, r.top + r.height / 2 - g.height / 2];
    place(d);
    const w = words(d.src, 'data-t-dg-say', ENGLISH);
    say(fill(ok ? w[1] : w[2], name(d.src), name(t)));
  }

  function lift(src) {
    const d = begin(src, 'kb', 0, 0, null);
    if (!d) return;
    d.list = targetsFor(d);
    d.i = -1;
    d.kb = [d.rect.left, d.rect.top];
    d.at = [d.rect.left + d.rect.width / 2, d.rect.top + d.rect.height / 2];
    place(d);
    say(fill(words(src, 'data-t-dg-say', ENGLISH)[0], name(src)));
  }

  R.addEventListener(
    'keydown',
    (e) => {
      const d = drag;
      // A pointer drag: Escape gives it up.
      if (d?.mode === 'ptr') {
        if (e.key === 'Escape') {
          finish(d, false, ...d.at);
          e.preventDefault();
        }
        return;
      }
      if (d?.mode === 'kb') {
        const k = e.key, w = words(d.src, 'data-t-dg-say', ENGLISH);
        // Every key belongs to the drag while it lasts (a page that scrolls
        // under the arrows would lose the target).
        if (k === 'Escape') {
          finish(d, false, ...d.at);
          say(fill(w[4], name(d.src)));
        } else if (k === ' ' || k === 'Enter') {
          const over = d.over;
          if (over?.ok) {
            say(fill(w[3], name(d.src), name(over.t)));
            finish(d, true, ...d.at);
          } else if (over) say(fill(w[2], name(d.src), name(over.t)));
          else say(fill(w[0], name(d.src)));
        } else if (k === 'Tab' || k.startsWith('Arrow') || k === 'Home' || k === 'End') {
          const forward = k === 'Tab' ? !e.shiftKey : k === 'ArrowDown' || k === (rtl(d.src) ? 'ArrowLeft' : 'ArrowRight');
          const back = k === 'Tab' ? e.shiftKey : k === 'ArrowUp' || k === (rtl(d.src) ? 'ArrowRight' : 'ArrowLeft');
          if (k === 'Home') pick(d, 0);
          else if (k === 'End') pick(d, d.list.length - 1);
          else if (forward) pick(d, d.i + 1);
          else if (back) pick(d, d.i - 1);
        } else return;
        e.preventDefault();
        e.stopImmediatePropagation();
        if (drag !== d) d.src.isConnected && d.src.focus({ preventScroll: true });
        return;
      }
      if (drag || e.defaultPrevented || e.altKey || e.ctrlKey || e.metaKey || e.shiftKey) return;
      const src = e.target.closest?.('[data-t-dg]');
      // Space or Enter on the draggable itself (not on a field or a control inside it).
      if (!src || e.target !== src || (e.key !== ' ' && e.key !== 'Enter') || !setup(src).max) return;
      e.preventDefault();
      lift(src);
    },
    true,
  );
  // The press of a native control that picked a drag up does not click.
  R.addEventListener('keyup', (e) => drag?.mode === 'kb' && (e.key === ' ' || e.key === 'Enter') && e.preventDefault(), true);
  // A pointer that goes down elsewhere ends a keyboard drag.
  R.addEventListener('pointerdown', () => drag?.mode === 'kb' && finish(drag, false, ...drag.at), true);
})(thor, document);
