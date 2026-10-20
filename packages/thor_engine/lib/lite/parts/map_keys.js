// thor-lite part "map_keys": one entry of a map state read on its own.
// The translator writes `m.value[k]` of a `state(<K, V>{…})` field as
// `m.key(k)`: the reader depends on that entry, not on the whole map, so a
// sheet cell re-runs when a cell it reads changes, not on every edit. Other reads of
// the map (`m.value`, its length, a loop over it) still depend on all of it.
//
// Each key read gets a source of its own (`k`: key → Signal), kept while
// the signal lives; a key that is not in the map has one too (its reader
// re-runs when it appears). On a write the runtime's setter calls `kw`:
// from a Map to a Map only the keys whose value changed (`!==`, the union
// of both key sets) move; to or from anything else, all of them.
Signal.prototype.key = function (n) {
  if (cur) {
    const k = (this.k ||= new Map());
    let s = k.get(n);
    s || k.set(n, (s = new Signal()));
    track(s);
  }
  return this.x?.get?.(n);
};
kw = (k, o, v) => {
  const bump = (s) => s && (s.ver++, notify(s));
  if (!(o instanceof Map && v instanceof Map)) return k.forEach(bump);
  for (const [n, x] of o) if (v.get(n) !== x || !v.has(n)) bump(k.get(n));
  for (const n of v.keys()) o.has(n) || bump(k.get(n));
};
