// thor-lite part "lists": keyed lists (`Watch.list`, `AnimatedList`; the
// dart2js engine's ListsFeature). A `data-tl` container holds the rows
// (`data-tk`, their key) and the `<template data-tlt>` new rows are cloned
// from (`data-tf` fields, `{{key}}` in its attributes). Loaded when the page
// has a `data-tl` list.
//
// A tree (`Watch.tree`) is a list whose rows hold their children in a slot
// (`data-tlc`, the id of the method giving an item's children): each slot
// is a container of its own that shares the list's one template, so a row
// at any depth is cloned from it, and its rows render with their row.
//
// The runtime hands it the lists a scan found (`lw`), the subtree a finite
// state swapped in (`la`) and the `{{key}}` of a state's patch inside a row
// (`fk`). The row parts (row_states, row_attributes, animated_list,
// virtual_list) extend its containers through `rowParts`: they come after
// this one in the bundle.
lw = (ls) => {
  for (const id in ls) {
    try {
      list(id, ls[id].flatMap(hosts));
    } catch (x) {
      fail(x);
    }
  }
};

// Lists of states already running (one that wakes later scans the page and
// finds them): the copy's containers join their list.
la = (sub, old) => {
  const found = nul();
  for (const el of self(sub, '[data-tl]')) {
    const id = el.getAttribute('data-tl');
    if (live[id.slice(0, id.lastIndexOf('.'))]?.on) (found[id] ||= []).push(...hosts(el));
  }
  for (const id in runs) found[id] ||= [];
  for (const id in found) {
    try {
      list(id, found[id], old);
    } catch (x) {
      fail(x);
    }
  }
};

// The key of the row around `live` in place of `{{key}}` in v (attribute a).
fk = (live, v, a) => {
  const k = live.closest('[data-tk]')?.getAttribute('data-tk');
  return k == null ? v : fillKey(v, k, a.startsWith('data-t'));
};

  // The template of list `id` among el's own children: rows come before it,
  // and what a `container:` puts after the rows (a footer) comes after.
  function tplOf(el, id) {
    for (let t = el.lastElementChild; t; t = t.previousElementSibling)
      if (t.getAttribute('data-tlt') === id) return t;
  }

  // The elements that hold a list's rows. `container:` may wrap it in
  // another element (Center, DecoratedBox, a Column around the carousel): the
  // marker sits on the outer one, the rows and their template on the inner
  // one, which is where the list works. The marker moves there (the row parts
  // look for it). A container with several roots (a list per breakpoint) has
  // a box around them: every copy is a host.
  function hosts(el) {
    const id = el.getAttribute('data-tl');
    if (tplOf(el, id)) return [el];
    const hs = [];
    for (const t of el.querySelectorAll('template[data-tlt]')) {
      const h = t.parentElement;
      if (t.getAttribute('data-tlt') === id && h.closest('[data-tl]') === el && !hs.includes(h)) hs.push(h);
    }
    for (const h of hs)
      for (const a of ['data-tl', 'data-tlk', 'data-tlv']) el.hasAttribute(a) && h.setAttribute(a, el.getAttribute(a));
    if (hs.length) for (const a of ['data-tl', 'data-tlk', 'data-tlv']) el.removeAttribute(a);
    return hs.length ? hs : [el];
  }

  // --- keyed lists -------------------------------------------------------------
  // One effect per list id; every container (the same list shown twice)
  // keeps its own rows. A row: {k: key, el, it: item last rendered, f:
  // [field fn, element, …]}.
  const runs = nul(); // list id → adds containers to the list that runs
  function list(id, els, old) {
    // A list met again (its containers came in a subtree that replaced
    // another): the same effect serves them.
    if (runs[id]) return runs[id](els, old);
    // `State.member~arg`: a list per instance (`withArg`), the method gets the argument.
    const [fn, arg] = member(id);
    const items = fn && (arg == null ? fn : () => fn(arg));
    const [key] = member(els[0].getAttribute('data-tlk'));
    if (!items || !key) return;
    const field = nul();
    const fieldOf = (fid) => {
      if (!field[fid]) {
        const [fn, arg] = member(fid);
        field[fid] = arg == null ? (it) => `${fn(it)}` : (it) => `${fn(arg, it)}`;
      }
      return field[fid];
    };
    let cs = els.map((el) => container(el, fieldOf, key));
    // Keys of the previous items, reused for the same item at the same
    // position, or one off (a row inserted or removed before it).
    let pi = [], pk = [];
    // What the rows read outside their item (another state's field: the set
    // of starred ids a row.watch looks at). The rows render under `w`, apart
    // from the items effect, so the reads that are not the item's are known:
    // when one changes, every row of the list renders again (its generation
    // `c.g` moved) though its item is the same. A list whose rows read only
    // the item leaves `w` without links: no subscription, the fast path.
    const w = { f: 0, dh: null, dt: null, c: null, run: () => pass(1) };
    own?.push(w);
    // `all`: the whole list renders (and `w` is rebuilt); otherwise only the
    // rows whose item moved do, and what they read is added to `w`.
    const pass = (all) => (all ? (cs.forEach((c) => c.g++), tracked(w, each)) : added(w, each));
    const each = () => {
      // The containers of rows that left are not kept (a list of its own,
      // out of the page for a while, is).
      cs = cs.filter((c) => c.el.isConnected || !c.el.closest('[data-tk]'));
      for (const c of cs) go(c, pi, pk);
    };
    effect(() => {
      const it = items(), n = it.length, keys = new Array(n);
      for (let i = 0, d = 0; i < n; i++) {
        const x = it[i];
        let j = i + d;
        if (pi[j] !== x) j = pi[j + 1] === x ? (d++, j + 1) : pi[j - 1] === x ? (d--, j - 1) : -1;
        keys[i] = j < 0 ? `${key(x)}` : pk[j];
      }
      // A read outside the item moved too (both changed in one batch).
      const all = w.dh && stale(w);
      pi = it;
      pk = keys;
      pass(all);
    });
    // `old`: a subtree that left the page for good, with its containers.
    runs[id] = (more, old) => {
      if (old) cs = cs.filter((c) => !old.contains(c.el));
      for (const el of more) {
        if (cs.some((c) => c.el === el)) continue;
        const c = container(el, fieldOf, key);
        cs.push(c);
        added(w, () => go(c, pi, pk));
      }
    };
  }

  // A container that windows its rows (part "virtual_list") sets `c.u`: it
  // takes the whole items and keys and calls `update` with the window's.
  const go = (c, it, keys) => (c.u ? c.u(it, keys) : update(c, it, keys));

  // Optional row parts (lite/row_states.js, lite/row_attributes.js): each
  // gets every container with a template, and may set c.b / c.a (run on
  // every row render, before and after the fields; a part chains to one
  // already there) and replace c.proto (the element cloned for new rows).
  const rowParts = [];

  function container(el, fieldOf, key) {
    const tpl = tplOf(el, el.getAttribute('data-tl')) || null;
    const c = { el, tpl, rows: [], g: 0, fo: fieldOf, kf: key };
    // An `<svg>` template has no `.content` (its row is its first child).
    let proto = tpl && (tpl.content ? tpl.content.firstElementChild : tpl.firstElementChild);
    if (proto) {
      c.proto = proto;
      for (const f of rowParts) f(c, fieldOf);
      proto = c.proto;
      // Computed once per template: where the fields and key placeholders are.
      const f = [], k = [], sl = [];
      const walk = (e, path) => {
        const id = e.getAttribute('data-tf');
        if (id) f.push(path, fieldOf(id));
        for (const a of e.attributes) if (a.value.includes('{{key}}')) k.push(path, a.name, a.value);
        // A tree's children slot: empty in the template, its rows are the
        // same template's.
        const ch = e.getAttribute('data-tlc');
        if (ch != null) return void sl.push(path, ch);
        let i = 0;
        for (let ch = e.firstElementChild; ch; ch = ch.nextElementSibling) walk(ch, [...path, i++]);
      };
      walk(proto, []);
      c.f = f;
      c.k = k;
      c.sl = sl.length ? sl : null;
      c.w = self(proto, '[data-tt],[data-tv],[data-tl]').length > 0;
      c.m = !!proto.querySelector('input[type=checkbox]') || proto.matches('input[type=checkbox]');
    }
    c.rows = drawnRows(c, el);
    return c;
  }

  // The rows the server rendered in `el`. In a tree a row holds its
  // children's rows: what it owns is what has no row closer (`mine`).
  function drawnRows(c, el) {
    const rows = [];
    for (let r = el.firstElementChild; r; r = r.nextElementSibling) {
      const key = r.getAttribute('data-tk');
      if (key == null) continue;
      const f = [];
      for (const e of mine(c, r, '[data-tf]')) f.push(c.fo(e.getAttribute('data-tf')), e);
      rows.push({ k: key, el: r, it: c, f });
    }
    return rows;
  }

  // The elements matching `sel` in row element `r` (itself included) that
  // belong to it, not to a row of its children (a tree's).
  const mine = (c, r, sel) => (c.sl ? self(r, sel).filter((e) => e.closest('[data-tk]') === r) : self(r, sel));

  // The children of an item, by the slot's method id (`State.childrenOf`, or
  // with a fixed argument).
  const kids = nul();
  const kidsOf = (id) => {
    if (!(id in kids)) {
      const [fn, arg] = member(id);
      kids[id] = fn ? (arg == null ? fn : (it) => fn(arg, it)) : null;
    }
    return kids[id];
  };

  // The container of a tree row's slot `el`: the list's template and parts,
  // its own rows (the ones the server drew there, if any).
  function nest(c, el, id) {
    const s = { ...c, el, tpl: null, an: null, u: null, x: null, rows: [], fn: kidsOf(id) };
    s.rows = drawnRows(s, el);
    return s;
  }

  // The slots of row `r` (a row the server drew, or one whose element a
  // row state replaced: found again).
  const slots = (c, r) => mine(c, r.el, '[data-tlc]').map((e) => nest(c, e, e.getAttribute('data-tlc')));

  // Every row of container `c` and of its trees' slots, with its container.
  function allRows(c, f) {
    for (const r of c.rows) {
      f(c, r);
      if (r.n) for (const s of r.n) allRows(s, f);
    }
  }

  // The bindings of other states in a row that is new (a template's content is
  // not in the page, so no scan met them): wired to the states that run, like
  // the ones the scan wires in a row the server drew. Once the rows left are
  // few compared with what was wired, the ones gone are dropped.
  let wired = 0, cap = 256, cq;
  function wire(row) {
    for (const el of self(row, '[data-tt],[data-tv],[data-tl]'))
      for (const a of ['data-tt', 'data-tv', 'data-tl']) {
        const id = el.getAttribute(a);
        if (!id) continue;
        const t = id.indexOf('~'), o = live[(t < 0 ? id : id.slice(0, t)).replace(/\.[^.]*$/, '')];
        if (!o?.on) continue;
        const prev = own;
        own = o.fx;
        try {
          untracked(() => {
            if (a === 'data-tt') return addText(id, el);
            if (a === 'data-tl') return list(id, hosts(el));
            const g = groups[id] || group(id, drawn(el));
            if (g) sync(instance(g, el), g.x());
          });
        } catch (x) {
          fail(x);
        } finally {
          own = prev;
        }
        wired++;
      }
    if (wired > cap && !cq) {
      cq = 1;
      queueMicrotask(() => {
        cq = wired = 0;
        for (const id in texts) wired += (texts[id].e = texts[id].e.filter((e) => e.isConnected)).length;
        for (const id in groups) wired += (groups[id].a = groups[id].a.filter((x) => x.l.isConnected)).length;
        cap = Math.max(256, 2 * wired);
      });
    }
  }

  // The key in place of `{{key}}`: escaped (`%` `~`) when another argument
  // follows it in the value or it is in the id of a keyed state (`#{{key}}.`),
  // as the server escapes the rows it draws. A function replacer: a key with
  // `$&` in it is text, not a pattern.
  const esc = (k, id) => k.replace(id ? /[%~;]/g : /[%~]/g, (c) => (c === '%' ? '%25' : c === ';' ? '%3B' : '%7E'));
  const fillKey = (v, k, id) => v.replace(id ? /#\{\{key\}\}(?=\.[A-Za-z_$])|\{\{key\}\}(~)?/g : /\{\{key\}\}(~)?/g, (m, t) => (m[0] === '#' ? '#' + esc(k, 1) : t ? esc(k) + '~' : k));

  function clone(c, key) {
    const el = c.proto.cloneNode(true);
    el.setAttribute('data-tk', key);
    const k = c.k, f = c.f, out = [];
    for (let i = 0; i < k.length; i += 3) at(el, k[i]).setAttribute(k[i + 1], fillKey(k[i + 2], key, k[i + 1].startsWith('data-t')));
    for (let i = 0; i < f.length; i += 2) out.push(f[i + 1], at(el, f[i]));
    if (c.m) mixed(el);
    if (c.w) {
      wire(el);
      fresh.push(el) < 2 && queueMicrotask(() => (fresh.length = 0));
    }
    const r = { k: key, el, it: c, f: out };
    if (c.sl) {
      r.n = [];
      for (let i = 0; i < c.sl.length; i += 2) r.n.push(nest(c, at(el, c.sl[i]), c.sl[i + 1]));
    }
    return r;
  }

  function render(c, r, it) {
    if (r.it === it && r.g === c.g) return;
    r.it = it;
    r.g = c.g;
    c.b?.(r, it);
    const f = r.f;
    for (let i = 0; i < f.length; i += 2) {
      // A field that throws is reported and the row stays (its template text);
      // the row is not marked rendered, so the next render retries it.
      let s;
      try {
        s = f[i](it);
      } catch (x) {
        r.it = c;
        fail(x);
        continue;
      }
      const el = f[i + 1], t = el.firstChild;
      // The usual row field: one text node (no tagName read on the hot path).
      if (t?.nodeType === 3 && !t.nextSibling) t.data !== s && (t.data = s);
      else setText(el, s);
    }
    c.a?.(r, it);
    // A tree row: its children, with the same template, in each slot.
    if (c.sl)
      for (const s of (r.n ||= slots(c, r))) {
        if (!s.fn) continue;
        let k;
        try {
          k = s.fn(it) || [];
        } catch (x) {
          fail(x);
          continue;
        }
        s.g = c.g;
        update(s, k, k.map((x) => `${c.kf(x)}`));
      }
  }

  function row(c, key, it) {
    const r = clone(c, key);
    render(c, r, it);
    return r;
  }

  // Moves a row that is already in `p` before `ref`. `moveBefore` (Chrome
  // 133+) keeps what an `insertBefore` (remove + insert) would lose: the
  // focus and selection of a field in the row, a running CSS animation, an
  // iframe's state. Where it is missing, or refuses (the container is not
  // connected), it is the plain insert (the WHATWG DOM "state-preserving
  // atomic move", feature-detected like the platform asks).
  const MOVE = W.Element?.prototype.moveBefore;
  function move(p, n, ref) {
    if (MOVE)
      try {
        return MOVE.call(p, n, ref);
      } catch (_) {
        // falls through to the insert
      }
    p.insertBefore(n, ref);
  }

  // A row that left its list: a part (animated_list) may keep it a while.
  const gone = (c, r) => (c.x ? c.x(r) : r.el.remove());

  // Keyed reconciliation: common prefix / suffix, a swap of the two ends
  // (udomdiff), all-new and all-gone fast paths, then a map of the middle
  // and moves only for rows outside its longest increasing subsequence.
  function update(c, items, keys) {
    const a = c.rows, n = keys.length, el = c.el, anchor = c.an || c.tpl;
    if (!c.proto && n) return;
    if (!n) {
      if (a.length) {
        if (!c.x && el.childNodes.length === a.length + (anchor ? 1 : 0)) {
          el.textContent = '';
          if (anchor) el.append(anchor);
        } else for (const r of a) gone(c, r);
      }
      c.rows = [];
      return;
    }
    const b = new Array(n);
    if (!a.length) {
      const fr = D.createDocumentFragment();
      for (let j = 0; j < n; j++) fr.appendChild((b[j] = row(c, keys[j], items[j])).el);
      el.insertBefore(fr, anchor);
      c.rows = b;
      return;
    }
    let as = 0, ae = a.length - 1, bs = 0, be = n - 1;
    while (as <= ae && bs <= be) {
      if (a[as].k === keys[bs]) render(c, (b[bs] = a[as++]), items[bs++]);
      else if (a[ae].k === keys[be]) render(c, (b[be] = a[ae--]), items[be--]);
      else if (a[as].k === keys[be] && a[ae].k === keys[bs]) {
        const x = a[as++], y = a[ae--], next = y.el.nextSibling;
        move(el, y.el, x.el);
        move(el, x.el, next);
        render(c, (b[bs] = y), items[bs++]);
        render(c, (b[be] = x), items[be--]);
      } else break;
    }
    let ref = be + 1 < n ? b[be + 1].el : anchor;
    if (as > ae) {
      if (bs <= be) {
        const fr = D.createDocumentFragment();
        for (let j = bs; j <= be; j++) fr.appendChild((b[j] = row(c, keys[j], items[j])).el);
        el.insertBefore(fr, ref);
      }
    } else if (bs > be) {
      for (let j = as; j <= ae; j++) gone(c, a[j]);
    } else {
      const at = new Map();
      for (let j = bs; j <= be; j++) at.set(keys[j], j);
      const src = new Int32Array(be - bs + 1).fill(-1);
      let moved = false, last = -1, kept = 0;
      for (let j = as; j <= ae; j++) {
        const r = a[j], p = at.get(r.k);
        if (p === undefined) gone(c, r);
        else {
          kept++;
          src[p - bs] = j;
          b[p] = r;
          if (p < last) moved = true;
          else last = p;
        }
      }
      // Nothing in the middle stays (a virtual list jumping far): the new
      // rows go in at once, like the dart2js engine does.
      if (!kept) {
        const fr = D.createDocumentFragment();
        for (let j = bs; j <= be; j++) fr.appendChild((b[j] = row(c, keys[j], items[j])).el);
        el.insertBefore(fr, ref);
        c.rows = b;
        return;
      }
      const keep = moved ? lis(src) : null;
      let li = keep ? keep.length - 1 : -1;
      for (let j = be; j >= bs; j--) {
        let r = b[j];
        if (!r) el.insertBefore((r = b[j] = row(c, keys[j], items[j])).el, ref);
        else {
          render(c, r, items[j]);
          if (moved) {
            if (li >= 0 && keep[li] === j - bs) li--;
            else move(el, r.el, ref);
          }
        }
        ref = r.el;
      }
    }
    c.rows = b;
  }

  // Positions (ascending) of a longest increasing subsequence of the
  // non-negative values of s. O(n log n).
  function lis(s) {
    const tails = [], prev = new Int32Array(s.length);
    for (let i = 0; i < s.length; i++) {
      const v = s[i];
      if (v < 0) continue;
      let lo = 0, hi = tails.length;
      while (lo < hi) {
        const mid = (lo + hi) >> 1;
        s[tails[mid]] < v ? (lo = mid + 1) : (hi = mid);
      }
      prev[i] = lo ? tails[lo - 1] : -1;
      tails[lo] = i;
    }
    const out = new Array(tails.length);
    for (let i = tails.length, k = tails[i - 1]; i-- > 0; k = prev[k]) out[i] = k;
    return out;
  }
