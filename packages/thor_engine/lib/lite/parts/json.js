// thor-lite part "json": JSON ⇄ JS Map at every level. A Dart Map is a JS Map
// (insertion order, any string as a key: like dart2js's LinkedHashMap), never
// an object: JSON.parse puts integer-like keys first and `__proto__` is no
// key at all. `parse` reads every object into a Map in the order of the text
// (JSON.parse only checks the syntax: its errors are the caller's, and it
// keeps the runtime's minimal `parse` out of the way); `str` writes Maps in
// their order (a plain object, like the server parts' envelope, by its own
// keys). It replaces `thor.parse` / `thor.str`. The string token is written
// unrolled (`"[^"\\]*(?:\\.[^"\\]*)*"`): `(?:[^"\\]|\\.)*` keeps a backtrack frame per
// character and a string of 10 MB overflowed the regex stack.
((T) => {
  T.parse = (s) => {
    JSON.parse(s);
    const up = [];
    let cur, k, res;
    const put = (v) => (cur === undefined ? (res = v) : Array.isArray(cur) ? cur.push(v) : k === undefined ? (k = v) : (cur.set(k, v), (k = undefined)));
    for (const [t] of s.matchAll(/"[^"\\]*(?:\\.[^"\\]*)*"|[-\d.eE+]+|true|false|null|[{}[\]]/g)) {
      const c = t[0];
      if (c === '{' || c === '[') {
        const o = c === '{' ? new Map() : [];
        put(o);
        up.push(cur);
        cur = o;
      } else if (c === '}' || c === ']') cur = up.pop();
      else put(c === '"' ? JSON.parse(t) : c === 't' ? true : c === 'f' ? false : c === 'n' ? null : +t);
    }
    return res;
  };
  const str = (T.str = (v) =>
    v instanceof Map
      ? `{${[...v].map(([k, x]) => `${JSON.stringify(`${k}`)}:${str(x)}`).join(',')}}`
      : Array.isArray(v)
        ? `[${v.map(str).join(',')}]`
        : v && typeof v === 'object'
          ? str(new Map(Object.entries(v).filter((e) => e[1] !== undefined)))
          : (JSON.stringify(v) ?? 'null'));
})(thor);
