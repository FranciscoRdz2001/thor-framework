// thor-lite part "attributes": writing a bound attribute through the same
// checks as the server (protocol.dart `safeAttributeValue`), shared by
// "row_attributes" and "variables": only `aria-*`, `data-*` (not
// `data-t*`) and a fixed set of plain attributes; a URL attribute with an
// empty value or an unsafe scheme is removed. A boolean attribute (`disabled`,
// `readonly`, `hidden`, `checked`, `open`) is present for `true` and removed otherwise.
// `aria-invalid` is `true` for any text but `false` or none (a field's error
// message), removed otherwise.
// A name that is a custom property (`--x`, a row's `row.length`) writes a
// number of pixels into the element's style; a row's `row.color` one
// (`--tr-color-…`) writes a color (protocol.dart `safeCssColor`) or, for
// anything that is not one, leaves the property unset.
//
// web: an <input>, <textarea> or <select> the user already touched ignores its
// `value` attribute (a checkbox its `checked` one), so the property is written
// too when it differs: a bound value moves a control the user edited.

// A number of pixels as a custom property takes it: finite, at most two
// decimals (rounded half away from zero, like Dart), `0px` otherwise.
const cssPx = (v) => {
  if (typeof v !== 'number' || !Number.isFinite(v)) return '0px';
  const r = v * 100;
  return `${(r < 0 ? -Math.round(-r) : Math.round(r)) / 100}px`;
};

// A color a custom property may take: a hex, a plain rgb/hsl/oklch function
// of numbers or a keyword; null otherwise.
const cssColor = (v) => {
  const s = v.trim();
  return s.length <= 64 && (/^#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(s) || /^(?:rgba?|hsla?|oklch|oklab)\([0-9a-zA-Z.,%\/ +-]*\)$/.test(s) || /^[a-zA-Z]{3,24}$/.test(s)) ? s : null;
};

const writeAttr = (() => {
  const URL = ['href', 'src', 'action', 'formaction', 'poster', 'cite'];
  const BOOL = ['disabled', 'readonly', 'hidden', 'checked', 'open', 'autofocus'];
  const PLAIN = [...URL, ...BOOL, 'alt', 'title', 'value', 'placeholder', 'list', 'label', 'lang', 'dir', 'id', 'name', 'role', 'target', 'rel', 'download', 'hreflang', 'datetime', 'min', 'max', 'step', 'width', 'height', 'tabindex'];

  // Per name, once: the same few names come back for every row.
  const known = new Map();
  const bindable = (n) => {
    let b = known.get(n);
    if (b === undefined)
      known.set(n, (b = /^[a-z][a-z0-9-]*$/.test(n) && (n.startsWith('aria-') ? n.length > 5 : n.startsWith('data-') ? n.length > 5 && !n.startsWith('data-t') : PLAIN.includes(n))));
    return b;
  };

  // Relative, or http(s)/mailto/tel, as the browser reads it (no controls,
  // spaces or DEL).
  function safeUrl(u) {
    let s = '';
    for (const ch of u) {
      const c = ch.charCodeAt(0);
      if (c > 0x20 && c !== 0x7f) s += ch;
    }
    const i = s.indexOf(':');
    if (i < 1) return true;
    const scheme = s.slice(0, i).toLowerCase();
    if (!/^[a-z][a-z0-9+.-]*$/.test(scheme)) return true;
    return ['http', 'https', 'mailto', 'tel'].includes(scheme);
  }

  // The property behind a written attribute (`s`: its value, null: removed).
  const prop = (el, n, s) => {
    if (n === 'value') {
      const t = el.tagName, x = s ?? '';
      if ((t === 'INPUT' ? el.type !== 'file' : t === 'TEXTAREA' || t === 'SELECT') && el.value !== x) el.value = x;
      // A group of radios (a SegmentedButton) takes the value of the one that is on.
      else if (el.getAttribute('role') === 'radiogroup')
        for (const r of el.querySelectorAll('input[type=radio]')) {
          const on = r.value === x;
          if (r.checked !== on) r.checked = on;
        }
    } else if (n === 'checked' && el.tagName === 'INPUT' && el.checked !== (s != null)) el.checked = s != null;
  };

  return (el, n, v) => {
    if (n.startsWith('--')) {
      if (!/^--[A-Za-z0-9_-]+$/.test(n)) return;
      if (n.startsWith('--tr-color-')) {
        const c = cssColor(v);
        if (c == null) el.style.removeProperty(n);
        else if (el.style.getPropertyValue(n) !== c) el.style.setProperty(n, c);
        return;
      }
      const p = cssPx(+v);
      if (el.style.getPropertyValue(n) !== p) el.style.setProperty(n, p);
      return;
    }
    const safe = !bindable(n) ? null : n === 'aria-invalid' ? (v === '' || v === 'false' ? null : v === 'grammar' || v === 'spelling' ? v : 'true') : BOOL.includes(n) ? (v === 'true' ? '' : null) : URL.includes(n) && (!v.trim() || !safeUrl(v)) ? null : v;
    // A <textarea> keeps its text as content, a <select> and a radio group
    // (a SegmentedButton) their chosen option or radio: `value` is only the
    // property, never an attribute of theirs.
    if (n === 'value' && (el.tagName === 'TEXTAREA' || el.tagName === 'SELECT' || el.getAttribute('role') === 'radiogroup')) {
      prop(el, n, safe);
      return;
    }
    if (safe == null) el.hasAttribute(n) && el.removeAttribute(n);
    else if (el.getAttribute(n) !== safe) el.setAttribute(n, safe);
    prop(el, n, safe);
  };
})();
