// thor-lite part "row_attributes": HTML attributes of list rows bound to row
// fields (`row.attribute`: `data-tfa="href:State.urlOf;aria-label:…"`), the
// dart2js engine's RowAttributes. Loaded when the page has one.
//
// After the row's fields, each bound attribute gets its field's text through
// the same checks as the server (part "attributes").
(() => {
  rowParts.push((c, fieldOf) => {
    const p = c.proto;
    if (!p.hasAttribute('data-tfa') && !p.querySelector('[data-tfa]')) return;
    const prev = c.a;
    c.a = (r, it) => {
      prev?.(r, it);
      let l = r.a;
      if (!l) {
        l = r.a = [];
        for (const el of mine(c, r.el, '[data-tfa]')) {
          const o = parseOn(el.getAttribute('data-tfa'));
          for (const n in o) l.push(el, n, fieldOf(o[n]));
        }
      }
      for (let i = 0; i < l.length; i += 3) writeAttr(l[i], l[i + 1], l[i + 2](it));
    };
  });
})();
