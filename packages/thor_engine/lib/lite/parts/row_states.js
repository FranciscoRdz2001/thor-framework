// thor-lite part "row_states": finite states of list rows (`row.watch`, the
// dart2js engine's row states in ListsFeature). Loaded when the page has a
// `data-tvf` element.
//
// A row part `data-tvf="State.method"` has its current index in `data-tvi`;
// in the row template its other states are patches of it (`data-tp-<n>`),
// or, when a state has another structure, `<template data-tvft data-i>`
// right after it (a nested part), or after the row element (the row itself).
// On every render of a row whose item changed, each part whose index moved
// is patched from that state (classes, state attributes, texts), like a
// finite state outside a list.
//
// A selector part (`row.selected`, `data-tvs`) is not asked of every row: its
// state is whether the row's key is the value of a field of a state (`data-tvf`
// is that field). The value is kept once per list; when it changes only the
// row that was and the one that is now selected are patched, like Solid's
// `createSelector`, and the rows that render for another reason read the kept
// value instead of the signal (so the list's rows never subscribe to it).
//
// The row templates are prepared at load, as the dart2js engine does when
// it starts (so the page's DOM is the same with both engines): the row's own
// states move into the row, the element cloned for new rows leaves every
// state template out, and the state sources lose the templates nested in
// them.
(() => {
  const TVFT = 'template[data-tvft]';
  const prepared = new WeakMap(); // row template → {p: prototype, s: sources}

  // Live rows never carry the row-state patches; a finite state's own
  // (`data-tv`) stay.
  function drop(root) {
    for (const el of self(root, '[data-tvf]'))
      for (const a of [...el.attributes]) if (a.name.startsWith('data-tp-')) el.removeAttribute(a.name);
  }

  // The template's content (an `<svg>` one has none: its children are the row).
  const rootOf = (t) => t.content || t;

  function prepare(tpl) {
    const row = rootOf(tpl).firstElementChild;
    if (!row) return null;
    for (let n = row.nextElementSibling; n; ) {
      const s = n;
      n = n.nextElementSibling;
      if (s.hasAttribute('data-tvft')) row.append(s);
    }
    const s = {};
    // The sources of the states in `root`: the row, or the variant of
    // another state (a `row.watch` inside the structural variant of another
    // is a state of the row too).
    const collect = (root) => {
      for (const el of self(root, '[data-tvf]')) {
        const id = el.getAttribute('data-tvf');
        if (s[id]) continue;
        const l = (s[id] = [el]);
        // A state that only differs in attributes and texts ships as a patch
        // of the template's element: its source is that element patched.
        for (const a of [...el.attributes]) {
          if (!a.name.startsWith('data-tp-')) continue;
          const src = el.cloneNode(true), i = +a.name.slice(8);
          drop(src);
          apply(src, decodePatch(a.value));
          while (l.length <= i) l.push(src);
          l[i] = src;
        }
      }
    };
    collect(row);
    drop(row);
    const p = row.cloneNode(true);
    for (const t of p.querySelectorAll(TVFT)) t.remove();
    // The variants: the row's templates, and those nested in a variant (its
    // own come after it in the template, as the row's after the row).
    const variants = (root) => {
      for (const t of root.querySelectorAll(TVFT)) {
        const l = s[t.getAttribute('data-tvft')], f = t.content.firstElementChild, i = +t.getAttribute('data-i');
        if (!f || !l) continue;
        while (l.length <= i) l.push(f);
        l[i] = f;
        for (let n = f.nextElementSibling; n; ) {
          const x = n;
          n = n.nextElementSibling;
          if (x.hasAttribute('data-tvft')) f.append(x);
        }
        collect(f);
        variants(f);
        drop(f);
      }
    };
    variants(row);
    // Sources are compared node by node with live rows, which never carry
    // nested state templates.
    for (const id in s) for (const el of s[id]) for (const t of el.querySelectorAll(TVFT)) t.remove();
    const out = { p, s };
    prepared.set(tpl, out);
    return out;
  }

  for (const t of document.querySelectorAll('template[data-tlt]')) if (rootOf(t).querySelector('[data-tvf]')) prepare(t);

  rowParts.push((c, fieldOf) => {
    // A template that came in a subtree that replaced another (a list inside
    // a state's variant) is prepared now.
    const x = prepared.get(c.tpl) || (c.tpl && rootOf(c.tpl).querySelector('[data-tvf]') && prepare(c.tpl));
    if (!x) return;
    c.proto = x.p;
    const S = x.s, F = {}, SEL = {}, sv = {}; // sv: selector id → the selected key, as text
    for (const id in S) {
      const [fn, arg] = member(id);
      if (!fn) continue;
      if (S[id][0].hasAttribute('data-tvs')) SEL[id] = arg == null ? fn : () => fn(arg);
      else F[id] = arg == null ? fn : (it) => fn(arg, it);
    }
    // The element of a state that has another structure is replaced by
    // `patch`: the row keeps pointing at what is in the page (its states,
    // fields and bound attributes), and the fresh nodes get the item again.
    const swapped = (r, el, n) => {
      if (el === r.el) {
        r.el = n;
        n.setAttribute('data-tk', r.k);
      }
      // The key in the attributes of the variant's markup, as in a clone.
      for (const e of [n, ...n.querySelectorAll('*')])
        for (const a of e.attributes) if (a.value.includes('{{key}}')) e.setAttribute(a.name, fillKey(a.value, r.k, a.name.startsWith('data-t')));
      const f = [];
      for (const e of mine(c, r.el, '[data-tf]')) f.push(fieldOf(e.getAttribute('data-tf')), e);
      r.f = f;
      r.a = null;
      r.s = null;
      // A tree row's slots are found again in the new nodes.
      r.n = null;
      // The fields write again after this (render writes every field of the
      // row; the new nodes hold the template's text).
      c.w && wire(n);
    };
    // `only`: the selector states alone (the selection moved, the item did not).
    // True when an element was replaced (the row's fields write again then).
    const states = (r, it, only) => {
      let sw = 0;
      // A swap can bring nested states: they are read again after it.
      for (let again = 8; again--; ) {
        let s = r.s, moved = 0;
        if (!s) {
          s = r.s = {};
          for (const el of mine(c, r.el, '[data-tvf]')) s[el.getAttribute('data-tvf')] = el;
        }
        for (const id in s) {
          const src = S[id], fn = F[id];
          let v;
          if (SEL[id]) v = r.k === sv[id] ? 1 : 0;
          else if (only || !src || !fn) continue;
          else {
            v = fn(it);
            if (typeof v === 'boolean') v = +v;
            else if (v?.index != null) v = v.index;
          }
          if (!src || !(v < src.length)) continue;
          const el = s[id], i = `${v}`;
          if (el.getAttribute('data-tvi') === i) continue;
          // A variant whose root is itself another state (a `row.watch`
          // inside the variant of this one) brings that state in: it is read
          // again after this, from its own first variant.
          const own = src[v].getAttribute('data-tvf'), nested = own && own !== id;
          const n = patch(el, src[v]);
          if (nested) {
            n.setAttribute('data-tvf', own);
            n.setAttribute('data-tvi', src[v].getAttribute('data-tvi') || '0');
          } else n.setAttribute('data-tvi', i);
          if (n === el) {
            if (nested) {
              r.s = null;
              moved = 1;
              break;
            }
            continue;
          }
          // `replace` keeps the handlers of the element it took the place
          // of (right for a Watch's box); a row's variant brings its own, or
          // none.
          for (const a of ['data-t-on', 'data-tx']) {
            const own = src[v].getAttribute(a);
            own == null ? n.removeAttribute(a) : n.setAttribute(a, own);
          }
          swapped(r, el, n);
          moved = sw = 1;
          break;
        }
        if (!moved) break;
      }
      return sw;
    };
    c.b = (r, it) => states(r, it, 0);
    for (const id in SEL) {
      const read = SEL[id];
      let first = 1;
      effect(() => {
        const n = `${read()}`, o = sv[id];
        sv[id] = n;
        // The first run only reads the value: the rows render with it.
        if (first) return void (first = 0);
        if (o === n || !c.el.isConnected) return;
        // Rows that never rendered take the value when they do; one whose
        // element was replaced writes its fields again.
        // A tree's rows at every depth.
        allRows(c, (c, r) => {
          if ((r.k !== o && r.k !== n) || r.it === c) return;
          const it = r.it;
          if (states(r, it, 1)) {
            r.it = c;
            render(c, r, it);
          }
        });
      });
    }
  });
})();
