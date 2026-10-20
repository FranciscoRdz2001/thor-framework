// thor-lite part "menu": the keyboard of thor_ui's `PopupMenuButton`,
// `MenuAnchor` and `SubmenuButton` menus (WAI-ARIA menu button pattern).
// Loaded when the page has a `data-t-menu` panel.
//
// Without JS a menu is a disclosure: the popover opens and closes
// natively (the trigger's `popovertarget`, a choice's `popovertargetaction`,
// Esc, light dismiss; the browser returns the focus to the trigger) and Tab
// walks the items. As a panel opens this makes it the ARIA `menu` it now
// behaves as (`role=menu`, its buttons and links `menuitem`s) and adds the
// keys: Down/Up on the trigger open
// the menu on the first/last item; in the menu Down/Up move (wrapping),
// Home/End jump, a typed letter goes to the next item that starts with it,
// Right opens a submenu (Left closes it, mirrored in a right-to-left menu)
// and Tab closes the menu. The items leave the Tab order while the menu is
// open (the focus is moved by the keys). A few page-wide listeners: the
// markup costs nothing until it is used.
((W, D) => {
  const R = D.documentElement;
  const PANEL = '[data-t-menu]';
  const ITEM = '[role^="menuitem"]';
  // What becomes a `menuitem` (a `menuitemradio` the server wrote stays).
  const RAW = 'button,a[href],[role^="menuitem"]';

  const usable = (i) => !i.disabled && i.getAttribute('aria-disabled') !== 'true' && !i.hidden;
  // The items of this panel, not those of a submenu inside it.
  const itemsOf = (panel) => [...panel.querySelectorAll(ITEM)].filter((i) => i.closest(PANEL) === panel && usable(i));
  // A panel is a menu from its first opening on (a closed popover is not in
  // the accessibility tree, so nothing is announced before).
  function promote(panel) {
    if (panel.hasAttribute('role')) return;
    panel.setAttribute('role', 'menu');
    for (const i of panel.querySelectorAll(RAW)) {
      if (i.closest(PANEL) === panel && !i.hasAttribute('role')) i.setAttribute('role', 'menuitem');
    }
  }

  const rtl = (el) => W.getComputedStyle(el).direction === 'rtl';
  const isOpen = (p) => p.matches(':popover-open');
  // The control that opens a panel: the one whose `popovertarget` is its id.
  const triggerOf = (panel) => (panel.id ? D.querySelector(`[popovertarget="${CSS.escape(panel.id)}"][aria-haspopup]`) : null);

  function focusItem(panel, i) {
    const items = itemsOf(panel);
    if (!items.length) return;
    const item = items[((i % items.length) + items.length) % items.length];
    // Out of the Tab order: the keys move the focus while the menu is open.
    for (const x of items) x.tabIndex = x === item ? 0 : -1;
    item.focus();
  }

  function open(trigger, last) {
    const panel = D.getElementById(trigger.getAttribute('popovertarget'));
    if (!panel?.matches(PANEL)) return false;
    if (!isOpen(panel)) panel.showPopover({ source: trigger });
    focusItem(panel, last ? -1 : 0);
    return true;
  }

  // Type-ahead: the characters typed within 700 ms of each other.
  let typed = '', typedAt = 0;
  const printable = (e) => e.key.length === 1 && e.key !== ' ' && !e.ctrlKey && !e.metaKey && !e.altKey;
  function typeAhead(panel, key) {
    const now = performance.now();
    typed = now - typedAt > 700 ? key : typed + key;
    typedAt = now;
    const items = itemsOf(panel);
    let q = typed.toLowerCase();
    // The same letter again cycles through the items that start with it.
    const repeated = q.split('').every((c) => c === q[0]);
    if (repeated) q = q[0];
    const at = items.indexOf(D.activeElement), skip = repeated && at >= 0 ? 1 : 0;
    for (let k = 0; k < items.length; k++) {
      const i = (Math.max(at, 0) + skip + k) % items.length;
      if (items[i].textContent.trim().toLowerCase().startsWith(q)) return focusItem(panel, i);
    }
  }

  R.addEventListener(
    'keydown',
    (e) => {
      if (e.isComposing || e.defaultPrevented || e.altKey || e.ctrlKey || e.metaKey) return;
      const t = e.target;
      const key = e.key;
      // The trigger: Down/Up open the menu on an item.
      if ((key === 'ArrowDown' || key === 'ArrowUp') && t?.matches?.('[popovertarget][aria-haspopup]') && !t.closest(PANEL)) {
        if (open(t, key === 'ArrowUp')) {
          e.preventDefault();
          e.stopPropagation();
        }
        return;
      }
      const panel = t?.closest?.(PANEL);
      if (!panel || !t.matches(ITEM)) return;
      const items = itemsOf(panel), at = items.indexOf(t);
      const sub = key === (rtl(panel) ? 'ArrowLeft' : 'ArrowRight');
      if (key === 'ArrowDown') focusItem(panel, at + 1);
      else if (key === 'ArrowUp') focusItem(panel, at - 1);
      else if (key === 'Home') focusItem(panel, 0);
      else if (key === 'End') focusItem(panel, -1);
      else if (sub && t.matches('[popovertarget][aria-haspopup]')) {
        if (!open(t, false)) return;
      } else if (key === (rtl(panel) ? 'ArrowRight' : 'ArrowLeft') || key === 'Escape') {
        // Only a submenu closes itself (the root menu has no parent item, and
        // its native Esc already gives the focus back to the trigger); Esc in
        // a submenu would drop the focus to the body.
        const parent = triggerOf(panel);
        if (!parent?.closest(PANEL)) return;
        panel.hidePopover();
        parent.focus();
      } else if (key === 'Tab') {
        // Close it all; the focus goes back to the trigger.
        let root = panel;
        for (let p = triggerOf(root)?.closest(PANEL); p; p = triggerOf(root)?.closest(PANEL)) root = p;
        root.hidePopover();
        return;
      } else if (printable(e)) typeAhead(panel, key);
      else return;
      e.preventDefault();
      e.stopPropagation();
    },
    true,
  );

  // How the last input came: the focus goes into a menu the keyboard opened,
  // not into one the pointer did (`:focus-visible` is no sure sign: it stays
  // on after a key press).
  let byKey = false;
  R.addEventListener('keydown', () => (byKey = true), true);
  R.addEventListener('pointerdown', () => (byKey = false), true);

  // Before it shows: it is a menu by the time anything can focus it.
  R.addEventListener(
    'beforetoggle',
    (e) => {
      if (e.newState === 'open' && e.target?.matches?.(PANEL)) promote(e.target);
    },
    true,
  );

  // The items leave the Tab order as the menu opens.
  R.addEventListener(
    'toggle',
    (e) => {
      const panel = e.target;
      if (!panel?.matches?.(PANEL)) return;
      // A menu that opened before this part was loaded.
      if (e.newState === 'open') promote(panel);
      const items = itemsOf(panel);
      if (e.newState === 'open') {
        for (const x of items) x.tabIndex = x === D.activeElement ? 0 : -1;
        if (byKey && !items.includes(D.activeElement) && !panel.contains(D.activeElement)) focusItem(panel, 0);
      } else {
        // Back in the Tab order (the menu is a plain list again).
        for (const x of items) x.removeAttribute('tabindex');
        typed = '';
      }
    },
    true,
  );
})(window, document);
