// thor-lite part "shortcuts": `CallbackShortcuts` (`data-tks`) and
// `HardwareKeyboard`'s modifiers (the dart2js engine's ShortcutsFeature).
// Loaded when a page has shortcuts or a state reads the keyboard; the part
// `key_actions` adds its handlers to the same walk (`thor.ks`).
//
// One `keydown` listener: from the event's target outward, the first
// element whose shortcuts match the key runs its method and stops the key
// there (the innermost `CallbackShortcuts` wins); with nothing focused, the
// outermost ones on view take it. A text field keeps the
// keys it edits with, except for the bindings that opt in (`o` in the spec,
// `overrideTextInput: true`: an arrow that moves a palette's highlight);
// `*` (onCharacter) takes a printable character no binding of the same
// element took (never from a text field).
((T, D, W) => {
  const keys = { isShiftPressed: false, isControlPressed: false, isAltPressed: false, isMetaPressed: false };
  const sync = (e) => {
    keys.isShiftPressed = e.shiftKey;
    keys.isControlPressed = e.ctrlKey;
    keys.isAltPressed = e.altKey;
    keys.isMetaPressed = e.metaKey;
  };
  T.keys = keys;

  const EDITING = ['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Home', 'End', 'PageUp', 'PageDown', 'Backspace', 'Delete'];
  const TEXT = ['text', 'search', 'url', 'email', 'tel', 'password', 'number', 'date', 'datetime-local', 'time', 'month', 'week'];
  // Whether el uses the key itself (a field moving its caret, a checkbox
  // toggling on Space, a button pressing on Enter).
  function consumes(el, key, modified) {
    const printable = key.length === 1;
    const own = () => (modified ? 'acvxyz'.includes(key.toLowerCase()) && printable : null);
    if (el instanceof HTMLTextAreaElement || el.isContentEditable) return own() ?? (printable || EDITING.includes(key) || key === 'Enter');
    if (el instanceof HTMLInputElement) {
      const t = el.type;
      if (TEXT.includes(t)) return own() ?? (printable || EDITING.includes(key));
      if (t === 'checkbox' || t === 'radio') return key === ' ' || (t === 'radio' && key.startsWith('Arrow'));
      if (t === 'range') return key.startsWith('Arrow') || key === 'Home';
      return false;
    }
    if (el instanceof HTMLSelectElement) return key === ' ' || key === 'Enter' || key.startsWith('Arrow');
    if (el instanceof HTMLButtonElement) return key === 'Enter' || key === ' ';
    if (el instanceof HTMLAnchorElement) return key === 'Enter';
    return false;
  }

  const printableKey = (e) => {
    const k = e.key;
    if (!k || [...k].length !== 1) return false;
    const c = k.charCodeAt(0);
    if (c < 0x20 || c === 0x7f) return false;
    return !e.metaKey && (!e.ctrlKey || e.altKey);
  };

  // web: a non-Latin layout types 'ы' on KeyS; like Flutter web, a letter
  // or digit then answers to its physical key (`s`). Nothing for an ASCII
  // key: a Latin layout (Dvorak's `o` on KeyS) keeps its own letters.
  const phys = (e) => e.key > '\x7f' && /^(?:Key|Digit)(.)$/.exec(e.code)?.[1].toLowerCase();

  // own: the key is one the focused control edits with; only a spec that
  // opted in (`o`) answers then.
  function matches(spec, e, own) {
    const at = spec.indexOf('+');
    const k = e.key;
    let mods;
    if (at < 0) {
      // CharacterActivator: `<mods>=<code units>`; Shift is ignored.
      const eq = spec.indexOf('=');
      if (eq < 0) return false;
      mods = spec.slice(0, eq);
      if (spec.slice(eq + 1) !== [...Array(k.length)].map((_, i) => k.charCodeAt(i)).join('.')) return false;
    } else {
      mods = spec.slice(0, at);
      const n = spec.slice(at + 1);
      if (n !== k.toLowerCase() && n !== phys(e)) return false;
      if (mods.includes('s') !== e.shiftKey) return false;
    }
    if (own && !mods.includes('o')) return false;
    if (e.repeat && mods.includes('n')) return false;
    // `skipWithTextSelection`: the browser's key works on the selection.
    if (mods.includes('t') && W.getSelection()?.isCollapsed === false) return false;
    return mods.includes('c') === e.ctrlKey && mods.includes('a') === e.altKey && mods.includes('m') === e.metaKey;
  }

  const split = (id) => {
    const t = id.indexOf('~');
    return t < 0 ? [id, null] : [id.slice(0, t), id.slice(t + 1)];
  };

  // The shortcuts of el that match e: runs the first, stops the key (true).
  function fire(el, e) {
    for (const part of el.getAttribute('data-tks').split(';')) {
      const gt = part.lastIndexOf('>');
      if (gt <= 0) continue;
      const spec = part.slice(0, gt), [id, arg] = split(part.slice(gt + 1));
      if (spec === '*') {
        if (k.own || !printableKey(e)) continue;
        e.preventDefault();
        e.stopPropagation();
        run(id, null, arg == null ? e.key : `${arg}~${e.key}`);
        return true;
      }
      if (!matches(spec, e, k.own)) continue;
      e.stopPropagation();
      run(id, null, arg);
      // A method that copies or pastes waits for this key's own clipboard
      // event (no permission prompt): let the key through.
      if (!T.clip?.waits) e.preventDefault();
      return true;
    }
    return false;
  }

  // What the walk visits (s; r with nothing focused) and does with each
  // element (h(el, e, root) → stops the key): the part `key_actions` widens
  // them to Shortcuts and Focus.onKeyEvent.
  const k = (T.ks = { s: '[data-tks]', r: '[data-tks]', h: fire, matches, phys });

  const R = D.documentElement;
  R.addEventListener('keydown', (e) => {
    sync(e);
    if (e.isComposing || e.defaultPrevented) return;
    const o = e.target;
    if (!(o instanceof Element)) return;
    // The focused control edits with this key: only the bindings that opted
    // in (and not Focus.onKeyEvent or Shortcuts) may take it.
    k.own = consumes(o, phys(e) || e.key, e.ctrlKey || e.metaKey || e.altKey);
    for (let el = o.closest(k.s); el; el = el.parentElement?.closest(k.s)) if (k.h(el, e)) return;
    // Nothing focused (the key's target is <body>) is Flutter's root focus:
    // the outermost shortcuts on view (an app's or a layout's) answer.
    if (o !== D.body && o !== R) return;
    for (const el of R.querySelectorAll(k.r)) {
      if (!el.parentElement?.closest(k.r) && el.checkVisibility() && k.h(el, e, 1)) return;
    }
  });
  R.addEventListener('keyup', sync, true);
  R.addEventListener('pointerdown', sync, true);
  W.addEventListener('blur', () => sync({ shiftKey: false, ctrlKey: false, altKey: false, metaKey: false }));
})(thor, document, window);
