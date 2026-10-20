/// The deprecation policy (CONTRIBUTING.md) on the public API snapshot
/// (`docs/api/public_api.txt`): one line per public name (import, name and
/// signature, tab-separated), ending in a tab and a marker when the name is
/// on its way out or only a guide:
///
///  * `@deprecated`: a real deprecation, to be removed after a minor version;
///  * `@tombstone`: a Flutter name thor does not have, kept only to tell the
///    developer what to write instead (`@Tombstone()`). It is no API
///    contract, so it never counts as a deprecation. A tombstone that is a
///    real parameter (GestureDetector, InkResponse callbacks) must also stay
///    `@Deprecated` for one minor version: removing the line from the
///    snapshot is silent, the analyzer warning is what protects callers.
library;

/// The marker of a real deprecation.
const deprecatedMark = '\t@deprecated';

/// The marker of a tombstone.
const tombstoneMark = '\t@tombstone';

/// What changed from the recorded snapshot to the current one.
sealed class ApiChange {
  const ApiChange();
}

/// Nothing: the snapshot is current.
final class ApiUnchanged extends ApiChange {
  const ApiUnchanged(this.names, {this.deprecated = 0, this.tombstones = 0});

  /// How many public names there are (tombstones included).
  final int names;

  /// How many of them are real deprecations.
  final int deprecated;

  /// How many of them are tombstones.
  final int tombstones;
}

/// Names that were public and neither deprecated nor tombstones are gone:
/// not allowed.
final class ApiRemoved extends ApiChange {
  const ApiRemoved(this.names);

  /// `import name` of each, sorted.
  final List<String> names;
}

/// Allowed, but to be recorded: names added, signatures changed, names
/// deprecated, or deprecated names (or tombstones) removed.
final class ApiChanged extends ApiChange {
  const ApiChanged({required this.added, required this.removed});

  /// New names.
  final int added;

  /// Deprecated names that are gone (their deprecation was recorded).
  final int removed;
}

/// Compares the [recorded] snapshot with the [current] one.
ApiChange compareApi(String recorded, String current) {
  final before = _byName(recorded);
  final now = _byName(current);
  final removed = [
    for (final MapEntry(:key, :value) in before.entries)
      if (!now.containsKey(key) &&
          !value.endsWith(deprecatedMark) &&
          !value.endsWith(tombstoneMark))
        key.replaceAll('\t', ' '),
  ]..sort();
  if (removed.isNotEmpty) return ApiRemoved(removed);
  if (_normalize(recorded) == _normalize(current)) {
    return ApiUnchanged(
      now.length,
      deprecated: now.values.where((l) => l.endsWith(deprecatedMark)).length,
      tombstones: now.values.where((l) => l.endsWith(tombstoneMark)).length,
    );
  }
  return ApiChanged(
    added: now.keys.where((k) => !before.containsKey(k)).length,
    removed: before.keys.where((k) => !now.containsKey(k)).length,
  );
}

Map<String, String> _byName(String text) => {
  for (final line in _normalize(text).split('\n'))
    if (line.isNotEmpty) line.split('\t').take(2).join('\t'): line,
};

/// Line endings and trailing whitespace don't count.
String _normalize(String text) => text
    .replaceAll('\r\n', '\n')
    .split('\n')
    .map((l) => l.trimRight())
    .where((l) => l.isNotEmpty)
    .join('\n');
