import '../core/core.dart';
import '../core/framework.dart' show ReplayableWidget, TypePath, typePathOf;
import '../core/markup.dart';
import '../foundation/child_rules.dart';
import '../foundation/errors.dart';
import '../foundation/layout_hint.dart';
import '../foundation/style_registry.dart';

/// Keeps the HTML of [child] for later requests of the same process: the
/// next page that builds a `Cached` with the same [cacheKey], at the same
/// place, adds the kept HTML instead of building [child] again.
///
/// ```dart
/// for (final a in articles)
///   Cached(
///     // Everything the preview shows: the key *is* its content.
///     cacheKey: (a.slug, a.title, a.favorited, a.favoritesCount),
///     child: ArticlePreview(a),
///   )
/// ```
///
/// The contract:
///
/// - **[cacheKey] identifies everything [child] shows.** Two pages that
///   build the same key get the same HTML, whoever asks: never cache
///   something personal under a key that doesn't include whose it is.
///   A key made of the values the subtree renders (a record of fields) is
///   correct by construction and needs no invalidation.
/// - **The place is part of the key**: the widgets above (their types) and
///   the layout rules of the parent. The inherited values the subtree reads
///   (`Theme`, `DefaultTextStyle`, the current route) must be the same for
///   every page that uses the key.
/// - The classes, keyframes and SVG symbols the subtree registered are
///   registered again on each page that reuses it, in the same order, so the
///   page is byte for byte the one a fresh build gives.
/// - Not allowed (a `StateError`, in every build mode): a `ThorState` in
///   the subtree (its HTML carries per-request values), `Document.head` or
///   `<html>`/`<head>`/`<body>` inside, and a wrapper right around
///   `Cached` (`Padding`, `Expanded`…: put it inside).
/// - Entries expire after [ttl] (none: until evicted), are evicted least
///   recently used beyond [maxEntries], and are dropped with [invalidate]
///   or [clear].
///
/// `// web:` Flutter has no equivalent (it never renders HTML twice).
/// Without a `ThorApp` the child is always built. In debug builds a
/// subtree inside one of your components is always built too: its classes
/// are named after the component (`product-card__row`) and the names
/// depend on the page.
class Cached extends StatelessWidget
    implements ThorBuiltIn, LayoutHint, HeightHint {
  /// Keeps [child]'s HTML under [cacheKey] (for [ttl], if given).
  const Cached({
    super.key,
    required this.cacheKey,
    this.ttl,
    required this.child,
  });

  /// What [child] shows; equal keys (`==`) share one entry.
  final Object cacheKey;

  /// How long an entry is reused; null: until evicted or invalidated.
  final Duration? ttl;

  /// The subtree whose HTML is kept.
  final Widget child;

  /// Most entries kept per process (the least recently used go first).
  static int maxEntries = 1000;

  /// Drops every entry of [cacheKey] (at every place).
  static void invalidate(Object cacheKey) =>
      _entries.removeWhere((k, _) => k.cacheKey == cacheKey);

  /// Drops every entry.
  static void clear() => _entries.clear();

  /// Number of entries kept (tests, monitoring).
  static int get length => _entries.length;

  static final _entries = <_PlaceKey, _Entry>{};
  static final _clock = Stopwatch()..start();

  @override
  bool get fillsWidth => layoutFillsWidth(child);

  @override
  bool get fillsHeight => layoutFillsHeight(child);

  @override
  Widget build(BuildContext context) =>
      ReplayableWidget(child: child, replayOrBuild: _replayOrBuild);

  Node _replayOrBuild(
    Element element, {
    required bool wrapped,
    required ({FragmentNode node, bool head}) Function() build,
  }) {
    final scope = ChildRulesScope.maybeOf(element);
    if (wrapped || scope?.pending != null) {
      throw StateError(
        thorError(
          'THOR-R002',
          'Cached($cacheKey) is inside a wrapper that decorates its first '
              'element (Expanded, Semantics, Link, Opacity…): put the wrapper '
              'inside Cached, so the kept HTML includes it.',
        ),
      );
    }
    final registry = ThorStyleRegistry.active(element);
    if (registry == null) return _checked(build());
    final key = renderCachesEnabled
        ? _PlaceKey(cacheKey, scope?.rules, element)
        : null;
    if (key != null) {
      final entry = _entries.remove(key);
      if (entry != null &&
          (entry.expires == null || entry.expires! > _clock.elapsed) &&
          replayFragmentRecord(registry, entry.record)) {
        _entries[key] = entry; // most recently used
        return entry.node;
      }
    }
    beginFragmentRecord(registry);
    final ({FragmentNode node, bool head}) built;
    try {
      built = build();
    } catch (_) {
      endFragmentRecord(registry);
      rethrow;
    }
    final record = endFragmentRecord(registry);
    if (record.usedState) {
      throw StateError(
        thorError(
          'THOR-S007',
          'Cached($cacheKey) contains widgets bound to a ThorState: their HTML '
              'carries values of this request. Keep them out of Cached.',
        ),
      );
    }
    final node = _checked(built);
    if (key != null && record.replayable) {
      while (_entries.length >= maxEntries && _entries.isNotEmpty) {
        _entries.remove(_entries.keys.first);
      }
      if (maxEntries > 0) {
        final ttl = this.ttl;
        _entries[key] = _Entry(
          node..kept = true,
          record,
          ttl == null ? null : _clock.elapsed + ttl,
        );
      }
    }
    return node;
  }

  FragmentNode _checked(({FragmentNode node, bool head}) built) {
    if (built.head || _hasDocumentElement(built.node)) {
      throw StateError(
        thorError(
          'THOR-R003',
          'Cached($cacheKey) contains Document.head or <html>/<head>/<body>: '
              'the page moves them, so they cannot be kept. Keep them out of '
              'Cached.',
        ),
      );
    }
    return built.node;
  }

  static bool _hasDocumentElement(ParentNode node) {
    for (final child in node.children) {
      if (child is ElementNode &&
          const {'html', 'head', 'body'}.contains(child.tag.toLowerCase())) {
        return true;
      }
      if (child is FragmentNode && _hasDocumentElement(child)) return true;
    }
    return false;
  }
}

final class _Entry {
  _Entry(this.node, this.record, this.expires);

  final FragmentNode node;
  final FragmentRecord record;
  final Duration? expires;
}

/// [cacheKey] at a place: the parent's layout rules and the types of the
/// widgets above.
final class _PlaceKey {
  _PlaceKey(Object cacheKey, ChildRules? rules, Element element)
    : this._(
        cacheKey,
        rules,
        element.parent == null ? null : typePathOf(element.parent!),
      );

  _PlaceKey._(this.cacheKey, this.rules, this.above)
    : hashCode = Object.hash(cacheKey, rules, identityHashCode(above));

  final Object cacheKey;
  final ChildRules? rules;

  /// The types of the widgets above (canonical: compared by identity).
  final TypePath? above;

  @override
  final int hashCode;

  @override
  bool operator ==(Object other) =>
      other is _PlaceKey &&
      other.hashCode == hashCode &&
      identical(other.above, above) &&
      other.cacheKey == cacheKey &&
      other.rules == rules;
}
