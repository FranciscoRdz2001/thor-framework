// Value equality helpers for the style types (Flutter's `listEquals` and
// `Object.hashAll` over a nullable list), kept apart from `foundation` so
// thor_style stays Dart-only.

/// Whether [a] and [b] are both null or hold equal elements in order.
bool listsEqual<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Whether [a] and [b] are both null or hold equal entries.
bool mapsEqual<K, V>(Map<K, V>? a, Map<K, V>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (final e in a.entries) {
    if (!b.containsKey(e.key) || b[e.key] != e.value) return false;
  }
  return true;
}

/// A hash for [list], null-safe, in order.
int hashList(List<Object?>? list) => list == null ? 0 : Object.hashAll(list);

/// A hash for [map], independent of the order of its entries.
int hashMap(Map<Object?, Object?> map) => Object.hashAllUnordered([
  for (final e in map.entries) Object.hash(e.key, e.value),
]);
