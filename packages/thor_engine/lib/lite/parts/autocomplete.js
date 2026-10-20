// thor-lite part "autocomplete": thor_ui's `Autocomplete` / `RawAutocomplete`,
// an options panel on the Popover API anchored to a text field (the dart2js
// engine's AutocompleteFeature). Loaded when the page has a `data-t-ac` root.
//
// The panel is a manual popover (top layer: no sibling covers it, no
// `overflow` clips it); this opens it while the field has focus and there is
// an option to show, moves a highlight with the arrows (`aria-activedescendant`
// on the field), picks with Enter or a click (the field takes the option's
// text and tells its controller with an `input` event, the option's own
// handler runs from the click), hides the options the typed text does not
// match when the root says `f` (`w`: every typed word must appear, any order,
// accents ignored), and closes on Esc, Tab or the focus leaving.
// Options the page changes (a state's list) are followed with a
// MutationObserver while the field has focus. A few page-wide listeners: the
// markup costs nothing until it is used.
//
// Inline (`i` in the root's value, the panel has `data-t-inl`): the panel is
// in the flow, not a popover: it is shown while there is an option and
// `hidden` otherwise, and Esc is left to the page (a `<dialog>` closes with
// one press). `h`: the first usable option is kept active whenever the list
// shows or changes. With the list inline, PageDown / PageUp move the
// highlight a page and Ctrl or Cmd with Home / End go to the first / last
// option (plain Home / End stay the caret's).
//
// Accessibility (APG "editable combobox with list autocomplete"): a polite
// live region says how many options there are when they change; ArrowDown /
// ArrowUp wrap around the options (as the APG example does); Home / End give
// the highlight back to the field and move its caret (the text field's keys);
// and the panel opens above the field when the visual viewport (the on-screen
// keyboard) leaves no room below.
((W, D) => {
  const R = D.documentElement;
  const ACTIVE = 'data-active';
  const UP = 'data-t-up';
  const ROOM = '--t-ac-room';

  const rootOf = (t) => t?.closest?.('[data-t-ac]');
  const panelOf = (root) => root.querySelector('[popover],[data-t-inl]');
  const parts = (root) => {
    const panel = panelOf(root);
    const flags = root.getAttribute('data-t-ac');
    return {
      root,
      panel,
      field: [...root.querySelectorAll('input,textarea')].find((i) => !panel.contains(i)),
      filter: flags.includes('f'),
      up: flags.includes('u'),
      inline: flags.includes('i'),
      first: flags.includes('h'),
      words: flags.includes('w'),
    };
  };
  const options = (m) => [...m.panel.querySelectorAll('[role="option"]')];
  const usable = (o) => !o.hasAttribute('hidden') && o.getAttribute('aria-disabled') !== 'true';
  // The highlighted option: a row the app took out of the list (its role or
  // `hidden` changed by a Watch) is no option, whatever mark it kept.
  const active = (m) => m.panel.querySelector(`[role="option"][${ACTIVE}]`);
  const isOpen = (m) => (m.inline ? !m.panel.hidden : m.panel.matches(':popover-open'));
  const textOf = (o) => o.textContent.trim();

  // Per root: the observer while the field has focus, and whether Esc or a
  // pick closed the panel (it stays closed until the visitor types again).
  const armed = new WeakMap();
  const dismissed = new WeakSet();
  let picking = false;
  let optionIds = 0;

  // The field is the combobox (set when it first gets the focus: without JS
  // it is a plain text field).
  function ready(m) {
    const f = m.field;
    if (f.getAttribute('role') === 'combobox') return;
    f.setAttribute('role', 'combobox');
    f.setAttribute('aria-autocomplete', 'list');
    f.setAttribute('aria-haspopup', 'listbox');
    f.setAttribute('aria-expanded', 'false');
    if (m.panel.id) f.setAttribute('aria-controls', m.panel.id);
    f.setAttribute('autocomplete', 'off');
  }

  function setActive(m, o, scroll = true) {
    // Every mark goes, not only the option's: a row that stopped being an
    // option keeps its attribute otherwise, and stays highlighted.
    for (const a of m.panel.querySelectorAll(`[${ACTIVE}]`)) if (a !== o) a.removeAttribute(ACTIVE);
    if (!o) return m.field.removeAttribute('aria-activedescendant');
    o.setAttribute(ACTIVE, '');
    // Ids only once an option is highlighted: the server writes none.
    // A counter, not the position: rows move, and an id must stay unique.
    if (!o.id) o.id = `${m.panel.id || 't-ac'}-${++optionIds}`;
    m.field.setAttribute('aria-activedescendant', o.id);
    if (scroll) o.scrollIntoView({ block: 'nearest' });
  }

  // Which side of the field has the room, measured on the visual viewport:
  // the on-screen keyboard shrinks it without touching the layout viewport
  // (which is all CSS anchoring knows). The client only flips an attribute and
  // writes the room as a value: the rules are the server's.
  const fit = (m) => {
    const p = m.panel;
    p.removeAttribute(UP);
    p.style.removeProperty(ROOM);
    const vv = W.visualViewport;
    if (!vv || m.up) return { up: false, room: null };
    const r = m.root.getBoundingClientRect();
    const below = vv.offsetTop + vv.height - r.bottom - 8;
    const above = r.top - vv.offsetTop - 8;
    // The panel's own height (its cap included), whichever side it is on.
    const need = Math.min(p.scrollHeight + (p.offsetHeight - p.clientHeight), parseFloat(getComputedStyle(p).maxHeight) || Infinity);
    if (below >= need) return { up: false, room: null };
    const up = above > below;
    return { up, room: Math.max(up ? above : below, 0) };
  };
  const apply = (m, f) => {
    m.panel.toggleAttribute(UP, f.up);
    if (f.room == null) m.panel.style.removeProperty(ROOM);
    else m.panel.style.setProperty(ROOM, `${f.room}px`);
  };

  // Where the panel goes: above or below (see fit), and in a browser without
  // CSS anchor positioning, under or over the field with a fixed position.
  const anchored = W.CSS?.supports?.('position-area', 'block-end');
  function place(m) {
    const f = fit(m);
    if (anchored) return apply(m, f);
    const r = m.root.getBoundingClientRect();
    const edge = f.up ? `bottom:${R.clientHeight - r.top}px` : `top:${r.bottom}px`;
    m.panel.style.cssText = `position:fixed;inset:auto;margin:0;left:${r.left}px;${edge};min-width:${r.width}px`;
    apply(m, f);
  }

  // Opening listens to the page's scroll and resize, and the visual
  // viewport's (the keyboard): the panel follows its field and the room.
  let following = false;
  function follow() {
    if (following) return;
    following = true;
    let frame = 0;
    const go = () => {
      if (frame) return;
      frame = requestAnimationFrame(() => {
        frame = 0;
        for (const root of D.querySelectorAll('[data-t-ac]')) {
          const m = parts(root);
          if (isOpen(m)) place(m);
        }
      });
    };
    W.addEventListener('scroll', go, true);
    W.addEventListener('resize', go);
    W.visualViewport?.addEventListener('resize', go);
    W.visualViewport?.addEventListener('scroll', go);
  }

  // The polite live region says how many options the field has now. It waits
  // for the typing to pause (a screen reader would read every step of
  // "apple"); closing empties it at once and cancels what was pending.
  const SAY = 200;
  const saying = new WeakMap();
  const say = (m, el) => {
    let text = '';
    if (!dismissed.has(m.root) && armed.has(m.root)) {
      const n = options(m).filter(usable).length;
      if (n === 1) text = el.getAttribute('data-t-ac-one');
      else if (n > 1) text = el.getAttribute('data-t-ac-status').replaceAll('{count}', n);
      // Nothing typed and nothing to show is not news.
      else if (m.field.value.trim()) text = el.getAttribute('data-t-ac-none');
    }
    return text;
  };
  function announce(m, clear) {
    const el = m.root.querySelector('[data-t-ac-status]');
    if (!el) return;
    clearTimeout(saying.get(el));
    if (clear) {
      if (el.textContent) el.textContent = '';
      return;
    }
    if (el.textContent === say(m, el)) return;
    saying.set(
      el,
      setTimeout(() => {
        const text = say(m, el);
        if (el.textContent !== text) el.textContent = text;
      }, SAY),
    );
  }

  function show(m) {
    follow();
    if (!isOpen(m)) {
      if (m.inline) m.panel.hidden = false;
      else m.panel.showPopover?.();
    }
    m.field.setAttribute('aria-expanded', 'true');
    if (m.inline) return;
    // Open, so its height can be measured; before the next paint.
    place(m);
  }

  function hide(m) {
    if (isOpen(m)) {
      if (m.inline) m.panel.hidden = true;
      else m.panel.hidePopover();
    }
    m.field.setAttribute('aria-expanded', 'false');
    setActive(m, null);
    announce(m, true);
  }

  // Open while there is something to show; closed otherwise.
  function refresh(m) {
    if (!armed.has(m.root)) return;
    const a = active(m);
    if (a && (!m.panel.contains(a) || !usable(a))) setActive(m, null);
    else if (!a && m.panel.querySelector(`[${ACTIVE}]`)) setActive(m, null);
    const want = !dismissed.has(m.root) && options(m).some(usable);
    if (want) {
      show(m);
      // Nothing active: the first option is (Enter picks it).
      if (m.first && !active(m)) setActive(m, options(m).find(usable));
    } else if (isOpen(m)) hide(m);
    announce(m);
  }

  // Lower case without accents (NFD, the combining marks stripped).
  const fold = (t) => t.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();

  // Whether the option's text matches what was typed. Default: the whole
  // phrase appears in the text, any case (Flutter's example filter,
  // `option.toLowerCase().contains(text.toLowerCase())`). With `w`: every
  // whitespace-separated word appears, in any order, ignoring case and
  // accents ("new york" finds "York, New"; "cafe" finds "Café").
  const matches = (m, text, q) => {
    if (!m.words) return text.toLowerCase().includes(q.toLowerCase());
    const t = fold(text);
    return fold(q).split(/\s+/).every((w) => t.includes(w));
  };

  // The options the typed text does not match go (a view the app builds is
  // already the matching one).
  function narrow(m) {
    if (!m.filter) return;
    const q = m.field.value.trim();
    for (const o of options(m)) o.toggleAttribute('hidden', !!q && !matches(m, textOf(o), q));
  }

  function arm(m) {
    if (armed.has(m.root)) return;
    ready(m);
    const watcher = new MutationObserver(() => refresh(m));
    watcher.observe(m.panel, { childList: true, subtree: true, attributes: true, attributeFilter: ['hidden', 'role', 'aria-disabled'] });
    armed.set(m.root, watcher);
    // A panel the page kept (a client navigation back, a re-render) can
    // carry marks from an earlier focus that this field does not point at.
    setActive(m, null, false);
    narrow(m);
    refresh(m);
  }

  function disarm(m) {
    armed.get(m.root)?.disconnect();
    armed.delete(m.root);
    dismissed.delete(m.root);
    // An inline list stays where it is: it is not a popup that leaves.
    if (m.inline) announce(m, true);
    else hide(m);
  }

  function pick(m, o) {
    if (!usable(o)) return;
    for (const x of options(m)) x.setAttribute('aria-selected', `${x === o}`);
    picking = true;
    m.field.value = textOf(o);
    // The field's controller (if any) hears it.
    m.field.dispatchEvent(new Event('input', { bubbles: true }));
    picking = false;
    dismissed.add(m.root);
    hide(m);
    m.field.focus({ preventScroll: true });
  }

  // To the first / last usable option (inline: Ctrl or Cmd with Home / End).
  function edge(m, last) {
    const u = options(m).filter(usable);
    if (u.length) setActive(m, u[last ? u.length - 1 : 0]);
  }

  // A page of options (inline): as many as the panel shows, at least one;
  // clamped at the ends (APG: PageUp / PageDown do not wrap).
  function page(m, by) {
    const u = options(m).filter(usable);
    if (!u.length) return;
    const at = u.indexOf(active(m));
    const row = u[0].offsetHeight || 1;
    const n = Math.max(1, Math.floor(m.panel.clientHeight / row) - 1);
    const to = at < 0 ? (by > 0 ? n - 1 : u.length - n) : at + by * n;
    setActive(m, u[Math.min(Math.max(to, 0), u.length - 1)]);
  }

  function move(m, by) {
    const u = options(m).filter(usable);
    if (!u.length) return;
    const at = u.indexOf(active(m));
    // APG: past either end it wraps (none highlighted: Down is the first,
    // Up the last).
    setActive(m, u[at < 0 ? (by > 0 ? 0 : u.length - 1) : (at + by + u.length) % u.length]);
  }

  const fieldOf = (t) => {
    const root = rootOf(t);
    if (!root) return null;
    const m = parts(root);
    return m.field === t ? m : null;
  };

  // Capture: before the field's own handlers and the page's shortcuts, which
  // must not see the keys the options use.
  R.addEventListener(
    'keydown',
    (e) => {
      if (e.isComposing || e.defaultPrevented) return;
      const m = fieldOf(e.target);
      if (!m) return;
      const key = e.key;
      let handled = true;
      if (key === 'ArrowDown' || key === 'ArrowUp') {
        arm(m);
        dismissed.delete(m.root);
        refresh(m);
        if (!isOpen(m)) return;
        move(m, key === 'ArrowDown' ? 1 : -1);
      } else if (key === 'Enter') {
        // Nothing highlighted: Enter is the field's (a form submits).
        const a = isOpen(m) && active(m);
        if (!a) return;
        a.click();
      } else if (key === 'Escape') {
        // Inline: the list is not a popup to dismiss; a dialog around it
        // closes with this one press.
        if (m.inline || !isOpen(m)) return;
        dismissed.add(m.root);
        hide(m);
      } else if (key === 'Tab') {
        if (isOpen(m)) hide(m);
        return; // focus moves on as usual
      } else if (m.inline && isOpen(m) && (key === 'PageDown' || key === 'PageUp')) {
        page(m, key === 'PageDown' ? 1 : -1);
      } else if (m.inline && isOpen(m) && (e.ctrlKey || e.metaKey) && (key === 'Home' || key === 'End')) {
        edge(m, key === 'End');
      } else if (key === 'Home' || key === 'End') {
        // The field's own keys (the caret): the highlight returns to it
        // (unless the first option is kept active).
        if (isOpen(m) && active(m) && !m.first) setActive(m, null);
        return;
      } else handled = false;
      if (!handled) return;
      e.preventDefault();
      e.stopPropagation();
    },
    true,
  );

  R.addEventListener('focusin', (e) => {
    const m = fieldOf(e.target);
    if (m) arm(m);
  });

  R.addEventListener('focusout', (e) => {
    const m = fieldOf(e.target);
    if (m && !m.root.contains(e.relatedTarget)) disarm(m);
  });

  // Composing text (IME) is not yet the query: it is acted on when the
  // composition ends.
  const typed = (e) => {
    const m = fieldOf(e.target);
    if (!m || picking || e.isComposing) return;
    arm(m);
    // Typing opens it again after Esc or a pick.
    dismissed.delete(m.root);
    setActive(m, null);
    narrow(m);
    refresh(m);
  };
  R.addEventListener('input', typed);
  R.addEventListener('compositionend', typed);

  // The pointer takes no focus from the field: it would close the panel
  // before the click lands.
  R.addEventListener('mousedown', (e) => {
    const root = rootOf(e.target);
    if (root && panelOf(root).contains(e.target)) e.preventDefault();
  });

  R.addEventListener('click', (e) => {
    const o = e.target?.closest?.('[role="option"]');
    const root = o && rootOf(o);
    if (root && panelOf(root).contains(o)) pick(parts(root), o);
  });

  R.addEventListener('pointerover', (e) => {
    const o = e.target?.closest?.('[role="option"]');
    const root = o && rootOf(o);
    if (!o || !root || o.hasAttribute(ACTIVE) || !usable(o)) return;
    const m = parts(root);
    if (m.panel.contains(o)) setActive(m, o, false);
  });
})(window, document);
