// A DOM reduced to what the lite runtime and its list parts touch, for
// tests that run the engine in node over thor's server HTML (no browser, no
// jsdom): elements, text nodes, `<template>` content, cloning, inserts and
// the selectors the engine uses (a tag and `[attr]` / `[attr=value]`
// conditions, in comma lists). Any other selector throws, so a test never
// passes on a selector this file reads wrong.
//
// `parseHtml(s)` builds the nodes of an HTML fragment; `outer(el)` writes
// one back with its attributes sorted (insertion order is not markup).
(() => {
  const VOID = new Set(['area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'source', 'track', 'wbr']);
  const decode = (s) =>
    s.replace(/&(#\d+|#x[0-9a-f]+|amp|lt|gt|quot|apos|#39);/gi, (m, e) =>
      e[0] === '#' ? String.fromCodePoint(e[1] === 'x' || e[1] === 'X' ? parseInt(e.slice(2), 16) : +e.slice(1)) : { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'" }[e.toLowerCase()],
    );
  const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  const escAttr = (s) => s.replace(/&/g, '&amp;').replace(/"/g, '&quot;');

  class Node {
    constructor() {
      this.parentNode = null;
      this.childNodes = [];
    }
    get parentElement() {
      return this.parentNode?.nodeType === 1 ? this.parentNode : null;
    }
    get firstChild() {
      return this.childNodes[0] || null;
    }
    get lastChild() {
      return this.childNodes[this.childNodes.length - 1] || null;
    }
    get nextSibling() {
      const p = this.parentNode;
      return p ? p.childNodes[p.childNodes.indexOf(this) + 1] || null : null;
    }
    get previousSibling() {
      const p = this.parentNode;
      return p ? p.childNodes[p.childNodes.indexOf(this) - 1] || null : null;
    }
    get nextElementSibling() {
      let n = this.nextSibling;
      while (n && n.nodeType !== 1) n = n.nextSibling;
      return n;
    }
    get previousElementSibling() {
      let n = this.previousSibling;
      while (n && n.nodeType !== 1) n = n.previousSibling;
      return n;
    }
    get isConnected() {
      let n = this;
      while (n.parentNode) n = n.parentNode;
      return n === document.documentElement;
    }
    remove() {
      const p = this.parentNode;
      if (!p) return;
      p.childNodes.splice(p.childNodes.indexOf(this), 1);
      this.parentNode = null;
    }
    replaceWith(...ns) {
      for (const n of ns) this.parentNode.insertBefore(n, this);
      this.remove();
    }
    replaceChildren(...ns) {
      for (const c of [...this.childNodes]) c.remove();
      for (const n of ns) this.appendChild(n);
    }
    contains(n) {
      for (; n; n = n.parentNode) if (n === this) return true;
      return false;
    }
    insertBefore(n, ref) {
      if (ref && ref.parentNode !== this) throw new Error('insertBefore: ref is not a child');
      const nodes = n.nodeType === 11 ? [...n.childNodes] : [n];
      for (const x of nodes) {
        if (x.contains(this)) throw new Error('insertBefore: a node inside itself');
        x.remove();
      }
      const i = ref ? this.childNodes.indexOf(ref) : this.childNodes.length;
      this.childNodes.splice(i, 0, ...nodes);
      for (const x of nodes) x.parentNode = this;
      return n;
    }
    appendChild(n) {
      return this.insertBefore(n, null);
    }
    append(...ns) {
      for (const n of ns) this.appendChild(typeof n === 'string' ? new Text(n) : n);
    }
    get textContent() {
      return this.childNodes.map((c) => c.textContent).join('');
    }
    set textContent(s) {
      for (const c of this.childNodes) c.parentNode = null;
      this.childNodes = s ? [new Text(String(s))] : [];
      for (const c of this.childNodes) c.parentNode = this;
    }
    get firstElementChild() {
      return this.childNodes.find((c) => c.nodeType === 1) || null;
    }
    get lastElementChild() {
      return [...this.childNodes].reverse().find((c) => c.nodeType === 1) || null;
    }
    get children() {
      return this.childNodes.filter((c) => c.nodeType === 1);
    }
    querySelectorAll(sel) {
      const m = compile(sel), out = [];
      const walk = (n) => {
        for (const c of n.childNodes)
          if (c.nodeType === 1) {
            if (m(c)) out.push(c);
            walk(c);
          }
      };
      walk(this);
      return out;
    }
    querySelector(sel) {
      return this.querySelectorAll(sel)[0] || null;
    }
  }

  class Text extends Node {
    constructor(data) {
      super();
      this.data = data;
      this.nodeType = 3;
    }
    get textContent() {
      return this.data;
    }
    set textContent(s) {
      this.data = String(s);
    }
    cloneNode() {
      return new Text(this.data);
    }
  }

  class Fragment extends Node {
    constructor() {
      super();
      this.nodeType = 11;
    }
    cloneNode(deep) {
      const f = new Fragment();
      if (deep) for (const c of this.childNodes) f.appendChild(c.cloneNode(true));
      return f;
    }
  }

  class Element extends Node {
    constructor(tag) {
      super();
      this.nodeType = 1;
      this.localName = tag.toLowerCase();
      this.tagName = this.localName.toUpperCase();
      this.attributes = [];
      if (this.localName === 'template') this.content = new Fragment();
    }
    // `<template>.innerHTML = '…'`: the parsed nodes become its content.
    set innerHTML(html) {
      const target = this.content || this;
      target.replaceChildren(...parseHtml(String(html)).childNodes);
    }
    focus() {
      globalThis.document.activeElement = this;
    }
    getAttribute(n) {
      return this.attributes.find((a) => a.name === n)?.value ?? null;
    }
    hasAttribute(n) {
      return this.attributes.some((a) => a.name === n);
    }
    setAttribute(n, v) {
      const a = this.attributes.find((a) => a.name === n);
      if (a) a.value = String(v);
      else this.attributes.push({ name: n, value: String(v) });
    }
    removeAttribute(n) {
      this.attributes = this.attributes.filter((a) => a.name !== n);
    }
    get id() {
      return this.getAttribute('id') || '';
    }
    matches(sel) {
      return compile(sel)(this);
    }
    closest(sel) {
      const m = compile(sel);
      for (let e = this; e; e = e.parentElement) if (m(e)) return e;
      return null;
    }
    cloneNode(deep) {
      const e = new Element(this.localName);
      e.attributes = this.attributes.map((a) => ({ ...a }));
      if (deep) {
        for (const c of this.childNodes) e.appendChild(c.cloneNode(true));
        if (this.content) e.content = this.content.cloneNode(true);
      }
      return e;
    }
    addEventListener() {}
    removeEventListener() {}
    dispatchEvent() {}
  }

  // `tag[a][b=v], …` → a predicate.
  const cache = new Map();
  function compile(sel) {
    let f = cache.get(sel);
    if (f) return f;
    const parts = sel.split(',').map((s) => {
      const m = /^\s*([a-zA-Z][\w-]*|\*)?((?:\[[\w-]+(?:=(?:"[^"]*"|[^\]]*))?\])*)\s*$/.exec(s);
      if (!m) throw new Error(`mini_dom: selector not supported: ${sel}`);
      const tag = m[1] === '*' ? null : m[1]?.toLowerCase();
      const conds = [...m[2].matchAll(/\[([\w-]+)(?:=("[^"]*"|[^\]]*))?\]/g)].map(([, n, v]) => [n, v == null ? null : v.replace(/^"|"$/g, '')]);
      return (e) => (!tag || e.localName === tag) && conds.every(([n, v]) => (v == null ? e.hasAttribute(n) : e.getAttribute(n) === v));
    });
    f = (e) => parts.some((p) => p(e));
    cache.set(sel, f);
    return f;
  }

  function parseHtml(s) {
    const root = new Fragment();
    const stack = [root];
    const top = () => stack[stack.length - 1];
    const into = () => top().content || top();
    const re = /<!--[\s\S]*?-->|<!doctype[^>]*>|<\/([a-zA-Z][\w-]*)\s*>|<([a-zA-Z][\w-]*)((?:\s+[^\s=>/]+(?:="[^"]*")?)*)\s*(\/?)>|([^<]+)/gi;
    let m;
    while ((m = re.exec(s))) {
      if (m[5] != null) into().appendChild(new Text(decode(m[5])));
      else if (m[1]) {
        const tag = m[1].toLowerCase();
        while (stack.length > 1 && top().localName !== tag) stack.pop();
        if (stack.length > 1) stack.pop();
      } else if (m[2]) {
        const e = new Element(m[2]);
        for (const [, n, v] of m[3].matchAll(/\s+([^\s=>/]+)(?:="([^"]*)")?/g)) e.setAttribute(n, v == null ? '' : decode(v));
        into().appendChild(e);
        if (!VOID.has(e.localName) && !m[4]) stack.push(e);
      }
    }
    return root;
  }

  function outer(n) {
    if (n.nodeType === 3) return esc(n.data);
    if (n.nodeType === 11) return n.childNodes.map(outer).join('');
    const attrs = [...n.attributes].sort((a, b) => (a.name < b.name ? -1 : 1)).map((a) => ` ${a.name}="${escAttr(a.value)}"`).join('');
    const kids = (n.content ? n.content.childNodes : n.childNodes).map(outer).join('');
    return VOID.has(n.localName) ? `<${n.localName}${attrs}>` : `<${n.localName}${attrs}>${kids}</${n.localName}>`;
  }

  const html = new Element('html');
  const body = new Element('body');
  html.appendChild(body);
  globalThis.window = globalThis;
  globalThis.document = {
    documentElement: html,
    body,
    activeElement: body,
    cookie: '',
    createElement: (t) => new Element(t),
    createDocumentFragment: () => new Fragment(),
    createTextNode: (s) => new Text(s),
    getElementById: (id) => html.querySelectorAll('[id]').find((e) => e.id === id) || null,
    querySelectorAll: (s) => html.querySelectorAll(s),
    querySelector: (s) => html.querySelector(s),
    addEventListener() {},
    removeEventListener() {},
    dispatchEvent() {},
  };
  globalThis.CustomEvent = class {
    constructor(type, o) {
      this.type = type;
      this.detail = o?.detail;
    }
  };
  globalThis.miniDom = { parseHtml, outer, body };
})();
