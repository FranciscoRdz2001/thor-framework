// thor-lite part "key_actions" (needs "shortcuts"): Flutter's `Shortcuts`
// (`data-tsi`) + `Actions` (`data-tai`) and `Focus(onKeyEvent:)`
// (`data-tke`), in the `shortcuts` part's walk from the focused element
// outward. On one element, onKeyEvent goes first, then the shortcuts.
((T) => {
  const k = T.ks, { h, matches, phys } = k;
  // The key's action: the Actions nearest `from` with one for intent i
  // (Flutter looks from the focus). Undefined: none, the key goes on.
  function act(from, i, e) {
    for (let a = from.closest('[data-tai]'); a; a = a.parentElement?.closest('[data-tai]')) {
      for (const p of a.getAttribute('data-tai').split(';')) {
        const gt = p.indexOf('>');
        if (p.slice(0, gt) !== i) continue;
        const id = p.slice(gt + 1);
        // DoNothingAction(consumesKey: false): found, but the key goes on.
        if (id === '!') return false;
        e.preventDefault();
        e.stopPropagation();
        if (id) run(id);
        return true;
      }
    }
    return false;
  }
  // Shortcuts: the first activator that matches names the intent.
  const intents = (el, e, root) => {
    for (const p of el.getAttribute('data-tsi').split(';')) {
      const gt = p.lastIndexOf('>');
      if (gt > 0 && matches(p.slice(0, gt), e, k.own)) return act(root ? el : e.target, p.slice(gt + 1), e);
    }
    return false;
  };
  // Focus(onKeyEvent:): the method gets [repeat, keyLabel, character] and
  // says what it did. Not with nothing focused (no Focus has it).
  const onKey = (el, e) => {
    const k = e.key;
    const ch = [...k].length === 1 && k >= ' ' && k !== '\x7f' ? k : null;
    const r = run(el.getAttribute('data-tke'), null, JSON.stringify([e.repeat ? 1 : 0, phys(e) || (ch ? k.toLowerCase() : k), ch]))?.name;
    if (r === 'handled') {
      e.preventDefault();
      e.stopPropagation();
    }
    return r === 'handled' || r === 'skipRemainingHandlers';
  };
  k.s = '[data-tke],[data-tsi],[data-tks]';
  k.r = '[data-tsi],[data-tks]';
  const has = (el, a) => el.hasAttribute(a);
  k.h = (el, e, r) => (!r && !k.own && has(el, 'data-tke') && onKey(el, e)) || (has(el, 'data-tsi') && intents(el, e, r)) || (has(el, 'data-tks') && h(el, e));
})(thor);
