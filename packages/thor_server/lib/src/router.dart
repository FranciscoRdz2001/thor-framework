import 'errors.dart';
import 'results.dart';
import 'routes.dart';

/// A page with the layouts around it and its full URL pattern.
class RouteEntry<P> {
  RouteEntry._(this.page, this.layouts, this.segments, {this.notFound = false});

  /// The page.
  final PageRoute<P, Object?> page;

  /// Its layouts, outermost first.
  final List<LayoutRoute<P, Object?>> layouts;

  /// The middleware of its layouts, outermost first: listed once, not per
  /// request.
  late final List<Middleware> middleware = [
    for (final l in layouts) ?l.middleware,
  ];

  /// URL segments: `article`, `[slug]`, `[id=int]`, `[...rest]`.
  final List<String> segments;

  /// The pattern, e.g. `/article/[slug]`.
  String get pattern => '/${segments.join('/')}';

  /// Whether the pattern has no parameters (it can be pre-rendered as is).
  bool get isStatic => segments.every((s) => !s.startsWith('['));

  /// Whether this is the `404` of a group (a URL under it that no page
  /// matches), not a page.
  final bool notFound;

  /// The page's `cache`, else the nearest layout's.
  Duration? get cache =>
      page.cache ?? layouts.reversed.map((l) => l.cache).nonNulls.firstOrNull;

  /// The page's `prefetch`, else the nearest layout's, else `true`.
  bool get prefetch =>
      page.prefetch ??
      layouts.reversed.map((l) => l.prefetch).nonNulls.firstOrNull ??
      true;

  /// The page's cache tags.
  List<String> get tags => page.tags;

  /// Whether a write clears the page from the cache (`PageRoute.invalidateOnWrite`).
  bool get invalidateOnWrite => page.invalidateOnWrite;

  /// The page's `personalized`, else the nearest layout's.
  bool? get personalized =>
      page.personalized ??
      layouts.reversed.map((l) => l.personalized).nonNulls.firstOrNull;

  /// The page's `earlyHints`, else the nearest layout's.
  bool get earlyHints =>
      page.earlyHints ??
      layouts.reversed.map((l) => l.earlyHints).nonNulls.firstOrNull ??
      false;

  /// The page's `prerender`, else the nearest layout's.
  bool get prerender =>
      page.prerender ??
      layouts.reversed.map((l) => l.prerender).nonNulls.firstOrNull ??
      false;
}

/// A matched request path.
class RouteMatch<P> {
  RouteMatch._(this.entry, this.pathParameters);

  /// The route.
  final RouteEntry<P> entry;

  /// Decoded values of its `[param]` segments.
  final Map<String, String> pathParameters;
}

/// Matches paths against a route tree. Static segments beat `[param]`,
/// which beats `[...rest]`, segment by segment (`/article/new` wins over
/// `/article/[slug]`). A typed parameter (`[id=int]`) only matches values of
/// its type: `/item/abc` is not `/item/[id=int]` (a 404, before any load).
class RouteIndex<P> {
  /// Flattens [routes].
  RouteIndex(List<RouteNode<P>> routes) {
    void walk(
      List<RouteNode<P>> nodes,
      List<LayoutRoute<P, Object?>> layouts,
      List<String> prefix,
    ) {
      for (final node in nodes) {
        final segments = [...prefix, ..._segments(node.path)];
        for (final seg in segments) {
          if (!seg.startsWith('[')) continue;
          final type = parameter(seg).$2;
          if (type != 'String' && type != 'int') {
            throw ArgumentError(
              'route segment $seg: a parameter is a String or an int '
              '([id=int])',
            );
          }
        }
        // `is` rather than a switch: a `RouteNode<P>` may be a route of a
        // subtype of `P`, which no pattern on `P` covers exhaustively.
        if (node is PageRoute<P, Object?>) {
          entries.add(RouteEntry._(node, layouts, segments));
        } else if (node is LayoutRoute<P, Object?>) {
          final chain = [...layouts, node];
          _folders.add(
            RouteEntry._(_notFoundPage<P>(), chain, segments, notFound: true),
          );
          walk(node.children, chain, segments);
        }
      }
    }

    walk(routes, const [], const []);
    entries.sort((a, b) => _compare(a.segments, b.segments));
    final seen = <String, String>{};
    for (final e in entries) {
      final shape = e.segments
          .map(
            (s) => s.startsWith('[...')
                ? '*'
                : s.startsWith('[')
                ? ':'
                : s,
          )
          .join('/');
      final other = seen[shape];
      if (other != null) {
        throw StateError(
          thorError(
            'THOR-P001',
            'routes ${e.pattern} and $other match the same URLs',
          ),
        );
      }
      seen[shape] = e.pattern;
    }
    _entryIndex = _FirstSegmentIndex(entries);
    _folderIndex = _FirstSegmentIndex(_folders);
    final below = Map<LayoutRoute<P, Object?>, List<RouteEntry<P>>>.identity();
    for (final e in entries) {
      for (final l in e.layouts) {
        (below[l] ??= []).add(e);
      }
    }
    below.forEach((l, pages) => _below[l] = _FirstSegmentIndex(pages));
  }

  /// [entries] by their first URL segment (built once, after sorting).
  late final _FirstSegmentIndex<P> _entryIndex;

  /// [_folders] by their first URL segment.
  late final _FirstSegmentIndex<P> _folderIndex;

  /// The pages below each layout, by first segment.
  final Map<LayoutRoute<P, Object?>, _FirstSegmentIndex<P>> _below =
      Map.identity();

  /// Every page, most specific first.
  final List<RouteEntry<P>> entries = [];

  /// One `404` entry per layout: its chain and its URL prefix.
  final List<RouteEntry<P>> _folders = [];

  /// The paths of the static pages whose `prerender` is true (their own or
  /// a layout's): what `exportSite` writes.
  List<String> get prerenderPaths => [
    for (final e in entries)
      if (e.isStatic && e.prerender) e.pattern,
  ];

  /// For a [path] no page matches: the `404` of the group that owns it
  /// (its layouts, middleware and guards apply, then its `notFound` or
  /// `error` page), or `null` when the app has no layout.
  ///
  /// The group with the longest URL prefix of [path]; among groups with
  /// the same prefix, the deepest one with a page that matches more of
  /// [path] (`/clients/x` → the group that has `/clients/…`), else the
  /// outermost.
  RouteMatch<P>? matchNotFound(String path) {
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    RouteMatch<P>? best;
    var bestPrefix = -1;
    var bestReach = -1;
    for (final folder in _folderIndex.candidates(parts)) {
      final params = _matchPrefix(folder.segments, parts);
      if (params == null) continue;
      final prefix = folder.segments.length;
      // How far the pages below this folder follow the path.
      var reach = prefix;
      final pages = _below[folder.layouts.last];
      for (final e in pages?.candidates(parts) ?? const <Never>[]) {
        final n = _reach(e.segments, parts);
        if (n > reach) reach = n;
      }
      final deeper = folder.layouts.length > (best?.entry.layouts.length ?? 0);
      final better =
          prefix > bestPrefix ||
          (prefix == bestPrefix &&
              (reach > bestReach ||
                  (reach == bestReach && reach > prefix && deeper)));
      if (better) {
        best = RouteMatch._(folder, params);
        bestPrefix = prefix;
        bestReach = reach;
      }
    }
    return best;
  }

  static PageRoute<P, Object?> _notFoundPage<P>() => PageRoute<P, Object?>(
    load: (_) => throw const NotFound(),
    build: (_) => throw StateError('a 404 entry has no page'),
  );

  /// Parameters of [pattern] as a prefix of [parts], or `null`.
  static Map<String, String>? _matchPrefix(
    List<String> pattern,
    List<String> parts,
  ) {
    if (pattern.length > parts.length) return null;
    final params = <String, String>{};
    for (var i = 0; i < pattern.length; i++) {
      final seg = pattern[i];
      if (seg.startsWith('[...')) return null;
      if (seg.startsWith('[')) {
        final value = _decode(parts[i]);
        final (name, type) = parameter(seg);
        if (!_fits(value, type)) return null;
        params[name] = value;
      } else if (seg != _decode(parts[i])) {
        return null;
      }
    }
    return params;
  }

  /// How many leading [parts] [pattern] matches.
  static int _reach(List<String> pattern, List<String> parts) {
    var n = 0;
    for (; n < pattern.length && n < parts.length; n++) {
      final seg = pattern[n];
      if (seg.startsWith('[...')) return parts.length;
      if (seg.startsWith('[')) {
        if (!_fits(_decode(parts[n]), parameter(seg).$2)) break;
      } else if (seg != _decode(parts[n])) {
        break;
      }
    }
    return n;
  }

  /// The route for [path] (already without query), or `null`.
  RouteMatch<P>? match(String path) {
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    for (final e in _entryIndex.candidates(parts)) {
      final params = _matchSegments(e.segments, parts);
      if (params != null) return RouteMatch._(e, params);
    }
    return null;
  }

  static Map<String, String>? _matchSegments(
    List<String> pattern,
    List<String> parts,
  ) {
    final params = <String, String>{};
    for (var i = 0; i < pattern.length; i++) {
      final seg = pattern[i];
      if (seg.startsWith('[...')) {
        if (i >= parts.length) return null; // a rest segment needs one part
        params[parameter(seg).$1] = parts.sublist(i).map(_decode).join('/');
        return params;
      }
      if (i >= parts.length) return null;
      if (seg.startsWith('[')) {
        final value = _decode(parts[i]);
        final (name, type) = parameter(seg);
        if (!_fits(value, type)) return null;
        params[name] = value;
      } else if (seg != _decode(parts[i])) {
        return null;
      }
    }
    return parts.length == pattern.length ? params : null;
  }

  /// Name and type of a `[name]` / `[name=int]` segment (`String` when
  /// untyped). A `[...rest]` is `(rest, String)`.
  static (String, String) parameter(String segment) {
    var inner = segment.substring(1, segment.length - 1);
    if (inner.startsWith('...')) inner = inner.substring(3);
    final colon = inner.indexOf('=');
    return colon < 0
        ? (inner, 'String')
        : (inner.substring(0, colon), inner.substring(colon + 1));
  }

  /// Whether [value] parses as [type] (`int`: optional `-` and digits that
  /// fit in 64 bits; anything for `String`).
  static bool _fits(String value, String type) {
    if (type != 'int') return true;
    final digits = value.startsWith('-') ? value.substring(1) : value;
    if (digits.isEmpty) return false;
    for (final c in digits.codeUnits) {
      if (c < 0x30 || c > 0x39) return false;
    }
    return int.tryParse(value) != null;
  }

  static String _decode(String s) {
    try {
      return Uri.decodeComponent(s);
    } on ArgumentError {
      return s;
    } on FormatException {
      return s; // invalid UTF-8: matched as written
    }
  }

  static List<String> _segments(String path) => path
      .split('/')
      .where((s) => s.isNotEmpty && !(s.startsWith('(') && s.endsWith(')')))
      .toList();

  static int _rank(String s) => s.startsWith('[...')
      ? 0
      : s.startsWith('[')
      ? 1
      : 2;

  static int _compare(List<String> a, List<String> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      final r = _rank(b[i]).compareTo(_rank(a[i]));
      if (r != 0) return r;
    }
    // Longer first: `/a/[b]` is tried before `/a/[...rest]` would swallow it
    // (ranks already differ); among equal prefixes, more segments first.
    return b.length.compareTo(a.length);
  }
}

/// Routes by their first URL segment: a path whose first part is `item`
/// only tries the routes that start with `item` and those that start with a
/// parameter, a `[...rest]` or nothing, in their original order (so the
/// first match, and precedence, is the same as a scan of every route).
class _FirstSegmentIndex<P> {
  _FirstSegmentIndex(List<RouteEntry<P>> routes) {
    final byKey = <String, List<int>>{};
    for (var i = 0; i < routes.length; i++) {
      final segs = routes[i].segments;
      if (segs.isEmpty || segs.first.startsWith('[')) {
        _open.add(routes[i]);
      } else {
        (byKey[segs.first] ??= []).add(i);
      }
    }
    // Merge each key's routes with the open ones, by original position.
    final openAt = [
      for (var i = 0; i < routes.length; i++)
        if (routes[i].segments.isEmpty ||
            routes[i].segments.first.startsWith('['))
          i,
    ];
    byKey.forEach((key, own) {
      final merged = <RouteEntry<P>>[];
      var a = 0;
      var b = 0;
      while (a < own.length || b < openAt.length) {
        final takeOwn =
            b >= openAt.length || (a < own.length && own[a] < openAt[b]);
        merged.add(routes[takeOwn ? own[a++] : openAt[b++]]);
      }
      _byFirst[key] = merged;
    });
  }

  final Map<String, List<RouteEntry<P>>> _byFirst = {};

  /// The routes whose first segment is not a literal.
  final List<RouteEntry<P>> _open = [];

  /// The routes that may match [parts] (URL-encoded, as requested), in
  /// their original order.
  List<RouteEntry<P>> candidates(List<String> parts) => parts.isEmpty
      ? _open
      : _byFirst[RouteIndex._decode(parts.first)] ?? _open;
}
