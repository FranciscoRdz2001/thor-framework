// thor-lite part "dropdown": thor_ui's `DropdownMenu`, a listbox select on
// the Popover API (the dart2js engine's DropdownMenuFeature).
// Loaded when the page has a `data-t-dd` menu.
//
// The popover opens and closes natively (its button's `popovertarget`, Esc,
// light dismiss); this adds what a native `<select>` would: the highlighted
// entry (arrows, Home/End, the pointer) announced through
// `aria-activedescendant`, Enter/Space/click to pick, type-ahead on the
// button, filtering as the user types in the menu's field, and on a pick the
// button's text, `aria-selected`, the value of the hidden `<select>` (what a
// form posts) and a `change` event on it (what reaches `onSelected`). A few
// page-wide listeners: the markup costs nothing until it is used.
((W, D) => {
  const R = D.documentElement;
  const ACTIVE = 'data-active';

  // The parts of one menu, from any element inside it.
  const menuOf = (t) => {
    const root = t?.closest?.('[data-t-dd]');
    return root && menu(root);
  };
  function menu(root) {
    const panel = root.querySelector('[popover]');
    const m = {
      root,
      button: root.querySelector('button[aria-haspopup]'),
      panel,
      list: panel.getAttribute('role') === 'listbox' ? panel : panel.querySelector('[role="listbox"]'),
      field: panel.querySelector('input'),
      select: root.querySelector('select'),
      flags: root.getAttribute('data-t-dd') ?? '',
    };
    m.options = () => [...m.list.querySelectorAll('[role="option"]')];
    m.open = () => panel.matches(':popover-open');
    // The hidden select's option behind entry i (a leading hint shifts them).
    m.native = (i, n) => m.select.options[m.select.options.length - n + i];
    m.labels = (n) => Array.from({ length: n }, (_, i) => m.native(i, n).text);
    return m;
  }

  const usable = (o) => !o.hasAttribute('hidden') && o.getAttribute('aria-disabled') !== 'true';
  const active = (m) => m.list.querySelector(`[${ACTIVE}]`);

  function setActive(m, o, scroll = true) {
    m.list.querySelector(`[${ACTIVE}]`)?.removeAttribute(ACTIVE);
    if (!o) {
      m.button.removeAttribute('aria-activedescendant');
      m.field?.removeAttribute('aria-activedescendant');
      return;
    }
    o.setAttribute(ACTIVE, '');
    // Ids only once an entry is highlighted: the server writes none.
    if (!o.id) o.id = `${m.list.id}-${m.options().indexOf(o)}`;
    m.button.setAttribute('aria-activedescendant', o.id);
    m.field?.setAttribute('aria-activedescendant', o.id);
    if (scroll) o.scrollIntoView({ block: 'nearest' });
  }

  // By `by` usable entries (no wrap, like a <select>), or to the first/last.
  function move(m, by, last) {
    const u = m.options().filter(usable);
    if (!u.length) return;
    const at = u.indexOf(active(m));
    const next = last != null ? (last ? u.length - 1 : 0) : at < 0 ? (by > 0 ? 0 : u.length - 1) : Math.min(Math.max(at + by, 0), u.length - 1);
    setActive(m, u[next]);
  }

  function opened(m) {
    m.button.setAttribute('aria-expanded', 'true');
    const f = m.field;
    if (f && f.value) {
      f.value = '';
      // The field's controller (if any) hears it; so does the filter.
      f.dispatchEvent(new Event('input', { bubbles: true }));
    }
    const os = m.options();
    for (const o of os) o.removeAttribute('hidden');
    setActive(m, os.find((o) => o.getAttribute('aria-selected') === 'true' && usable(o)) ?? os.find(usable) ?? null);
    if (f) {
      const focus = m.flags.includes('f') ? true : m.flags.includes('n') ? false : !W.matchMedia('(pointer: coarse)').matches;
      if (focus) f.focus({ preventScroll: true });
    }
  }

  function closed(m) {
    m.button.setAttribute('aria-expanded', 'false');
    setActive(m, null);
    typed = '';
  }

  function pick(m, o) {
    if (!usable(o)) return;
    const os = m.options(), n = m.native(os.indexOf(o), os.length);
    n.selected = true;
    for (const x of os) x.setAttribute('aria-selected', `${x === o}`);
    const label = m.root.querySelector('[data-tdl]');
    if (label) {
      label.textContent = n.text;
      label.removeAttribute('data-hint');
    }
    if (m.open()) m.panel.hidePopover();
    // Now, not on the (queued) `toggle` event.
    closed(m);
    m.button.focus({ preventScroll: true });
    // Like Flutter's onSelected: every pick, the same entry again included.
    m.select.dispatchEvent(new Event('change', { bubbles: true }));
  }

  // Type-ahead: the characters typed within 700 ms of each other.
  let typed = '', typedAt = 0;
  const typing = () => typed !== '' && performance.now() - typedAt <= 700;

  function typeAhead(m, key) {
    const now = performance.now();
    typed = now - typedAt > 700 ? key : typed + key;
    typedAt = now;
    const os = m.options(), labels = m.labels(os.length);
    let q = typed.toLowerCase();
    // The same letter again cycles through the entries that start with it.
    const repeated = q.split('').every((c) => c === q[0]);
    if (repeated) q = q[0];
    const cur = active(m), from = cur ? os.indexOf(cur) : 0, skip = repeated && cur ? 1 : 0;
    for (let k = 0; k < os.length; k++) {
      const i = (from + skip + k) % os.length;
      if (usable(os[i]) && labels[i].toLowerCase().startsWith(q)) return setActive(m, os[i]);
    }
  }

  function filter(m, text) {
    const q = text.trim().toLowerCase(), os = m.options(), labels = m.labels(os.length);
    let first = null;
    for (let i = 0; i < os.length; i++) {
      const shown = !q || labels[i].toLowerCase().includes(q);
      os[i].toggleAttribute('hidden', !shown);
      if (shown && !first && usable(os[i])) first = os[i];
    }
    setActive(m, first);
  }

  const printable = (e) => e.key.length === 1 && !e.ctrlKey && !e.metaKey && !e.altKey;

  // Capture: before the field's own handlers and the page's shortcuts,
  // which must not see the keys the menu uses.
  R.addEventListener(
    'keydown',
    (e) => {
      if (e.isComposing || e.defaultPrevented) return;
      const m = menuOf(e.target);
      if (!m) return;
      const t = e.target, onButton = t.matches('button[aria-haspopup]'), inField = !onButton && t.matches('[popover] input');
      if (!onButton && !inField) return;
      const key = e.key, ahead = onButton && m.flags.includes('s') && printable(e);
      let handled = true;
      // Opened by the pointer a moment ago: `toggle` is queued, set up now.
      if (m.open() && m.button.getAttribute('aria-expanded') !== 'true') opened(m);
      if (!m.open()) {
        if (!onButton) return;
        if (key === 'ArrowDown' || key === 'ArrowUp' || ahead) {
          m.button.click();
          if (m.open()) opened(m);
          if (ahead) typeAhead(m, key);
        } else handled = false;
      } else if (key === 'ArrowDown') move(m, 1);
      else if (key === 'ArrowUp') move(m, -1);
      else if ((key === 'Home' || key === 'End') && onButton) move(m, 0, key === 'End');
      else if (key === 'Enter' || (key === ' ' && onButton && !typing())) {
        const a = active(m);
        if (a) pick(m, a);
      } else if (key === 'Tab') return m.panel.hidePopover(); // focus moves on as usual
      else if (ahead) typeAhead(m, key);
      else handled = false;
      if (!handled) return;
      e.preventDefault();
      e.stopPropagation();
    },
    true,
  );

  R.addEventListener('click', (e) => {
    const o = e.target?.closest?.('[role="option"]');
    const m = o && menuOf(o);
    if (m) pick(m, o);
  });

  R.addEventListener('pointerover', (e) => {
    const o = e.target?.closest?.('[role="option"]');
    if (!o || o.hasAttribute(ACTIVE)) return;
    const m = menuOf(o);
    if (m && usable(o)) setActive(m, o, false);
  });

  R.addEventListener('input', (e) => {
    const t = e.target;
    if (!(t instanceof HTMLInputElement) || !t.closest('[popover]')) return;
    const m = menuOf(t);
    if (!m) return;
    // Opened by the pointer a moment ago: its (queued) `toggle` would set the
    // menu up after this input and wipe the filter; mark it set up now.
    if (m.open() && m.button.getAttribute('aria-expanded') !== 'true') m.button.setAttribute('aria-expanded', 'true');
    filter(m, t.value);
  });

  // `toggle` doesn't bubble.
  R.addEventListener(
    'toggle',
    (e) => {
      const p = e.target;
      if (!p?.hasAttribute?.('popover')) return;
      const m = menuOf(p);
      if (!m || m.panel !== p) return;
      const open = e.newState === 'open';
      // Opened by the keyboard: already set up (synchronously, so a typed
      // character could highlight its entry).
      if (open === (m.button.getAttribute('aria-expanded') === 'true')) return;
      open ? opened(m) : closed(m);
    },
    true,
  );
})(window, document);
