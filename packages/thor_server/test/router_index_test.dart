import 'dart:math';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

// The router indexes its routes by their first URL segment. These tests keep
// the plain linear scan (the router before the index) as the reference and
// compare both on random route tables and paths: same route, same
// parameters, for hits and for 404s.

const _statics = ['a', 'b', 'c', 'ñ', 'item', 'x y'];

String _segment(Random r) => switch (r.nextInt(10)) {
  0 => '[p${r.nextInt(3)}]',
  1 => '[n${r.nextInt(3)}=int]',
  2 => '[...rest]',
  _ => _statics[r.nextInt(_statics.length)],
};

/// A relative path of 0–2 segments, sometimes a `(group)`.
String _path(Random r, {required bool page}) {
  if (!page && r.nextInt(4) == 0) return '(g${r.nextInt(3)})';
  final n = r.nextInt(page ? 3 : 2);
  final segs = <String>[];
  for (var i = 0; i < n; i++) {
    final s = _segment(r);
    segs.add(s);
    if (s.startsWith('[...')) break; // a rest segment ends the pattern
  }
  if (!page && segs.any((s) => s.startsWith('[...'))) return '';
  return segs.join('/');
}

List<RouteNode<String>> _nodes(Random r, int depth) => [
  for (var i = 0, n = 1 + r.nextInt(5); i < n; i++)
    if (depth < 3 && r.nextInt(3) == 0)
      LayoutRoute<String, void>(
        path: _path(r, page: false),
        build: (s, c) => c,
        children: _nodes(r, depth + 1),
      )
    else
      PageRoute<String, void>(path: _path(r, page: true), build: (s) => ''),
];

const _values = [
  'a', 'b', 'c', 'item', '%C3%B1', 'x%20y', '7', '-3', '99999999999999999999',
  'abc', 'z', '%E0%A4%A', //
];

String _url(Random r) {
  final n = r.nextInt(5);
  return '/${[for (var i = 0; i < n; i++) _values[r.nextInt(_values.length)]].join('/')}';
}

// --- The reference: the linear scan. ---

String _decode(String s) {
  try {
    return Uri.decodeComponent(s);
  } on ArgumentError {
    return s;
  } on FormatException {
    return s;
  }
}

bool _fits(String value, String type) {
  if (type != 'int') return true;
  final digits = value.startsWith('-') ? value.substring(1) : value;
  if (digits.isEmpty) return false;
  for (final c in digits.codeUnits) {
    if (c < 0x30 || c > 0x39) return false;
  }
  return int.tryParse(value) != null;
}

Map<String, String>? _matchSegments(List<String> pattern, List<String> parts) {
  final params = <String, String>{};
  for (var i = 0; i < pattern.length; i++) {
    final seg = pattern[i];
    if (seg.startsWith('[...')) {
      if (i >= parts.length) return null;
      params[RouteIndex.parameter(seg).$1] = parts
          .sublist(i)
          .map(_decode)
          .join('/');
      return params;
    }
    if (i >= parts.length) return null;
    if (seg.startsWith('[')) {
      final value = _decode(parts[i]);
      final (name, type) = RouteIndex.parameter(seg);
      if (!_fits(value, type)) return null;
      params[name] = value;
    } else if (seg != _decode(parts[i])) {
      return null;
    }
  }
  return parts.length == pattern.length ? params : null;
}

List<String> _parts(String path) =>
    path.split('/').where((s) => s.isNotEmpty).toList();

(RouteEntry<String>, Map<String, String>)? _linear(
  RouteIndex<String> router,
  String path,
) {
  final parts = _parts(path);
  for (final e in router.entries) {
    final params = _matchSegments(e.segments, parts);
    if (params != null) return (e, params);
  }
  return null;
}

void _expectSame(
  RouteMatch<String>? got,
  (RouteEntry<String>, Map<String, String>)? want,
  String reason,
) {
  if (want == null) {
    expect(got, isNull, reason: reason);
    return;
  }
  expect(got, isNotNull, reason: reason);
  expect(identical(got!.entry, want.$1), isTrue, reason: reason);
  expect(got.pathParameters, want.$2, reason: reason);
}

void main() {
  test('the indexed match equals the linear scan on random tables', () {
    var tables = 0;
    var hits = 0;
    for (var seed = 0; seed < 800; seed++) {
      final r = Random(seed);
      final RouteIndex<String> router;
      try {
        router = RouteIndex<String>(_nodes(r, 0));
      } on StateError {
        continue; // two routes for the same URLs: not a valid table
      }
      tables++;
      for (var i = 0; i < 60; i++) {
        final url = _url(r);
        final want = _linear(router, url);
        if (want != null) hits++;
        _expectSame(router.match(url), want, 'seed $seed, $url');
      }
    }
    expect(tables, greaterThan(250));
    expect(hits, greaterThan(2000));
  });

  test('a 404 picks the same folder as before on random tables', () {
    // The folder choice is compared through the handler-visible result:
    // the same layouts chain and parameters for every path.
    var folders = 0;
    for (var seed = 0; seed < 300; seed++) {
      final r = Random(1000 + seed);
      final nodes = _nodes(r, 0);
      final wrappedNodes = <RouteNode<String>>[
        LayoutRoute<String, void>(build: (s, c) => c, children: nodes),
      ];
      final RouteIndex<String> router;
      final RouteIndex<String> wrapped;
      try {
        router = RouteIndex<String>(nodes);
        wrapped = RouteIndex<String>(wrappedNodes);
      } on StateError {
        continue;
      }
      for (var i = 0; i < 40; i++) {
        final url = _url(r);
        for (final (rt, tree) in [(router, nodes), (wrapped, wrappedNodes)]) {
          final got = rt.matchNotFound(url);
          final want = _linearNotFound(rt, tree, url);
          if (want == null) {
            expect(got, isNull, reason: 'seed $seed, $url');
            continue;
          }
          folders++;
          expect(got, isNotNull, reason: 'seed $seed, $url');
          expect(got!.entry.notFound, isTrue);
          expect(
            _sameList(got.entry.layouts, want.$1),
            isTrue,
            reason: 'seed $seed, $url',
          );
          expect(got.pathParameters, want.$2, reason: 'seed $seed, $url');
        }
      }
    }
    expect(folders, greaterThan(3000));
  });

  test('static first segments are indexed by their decoded value', () {
    final router = RouteIndex<String>([
      PageRoute<String, void>(path: 'ñ/[id=int]', build: (s) => 'n'),
      PageRoute<String, void>(path: 'x y', build: (s) => 'xy'),
      PageRoute<String, void>(path: '[slug]', build: (s) => 'slug'),
      PageRoute<String, void>(path: '[...rest]', build: (s) => 'rest'),
      PageRoute<String, void>(build: (s) => 'home'),
    ]);
    String? page(String p) => router.match(p)?.entry.page.path;
    expect(page('/%C3%B1/3'), 'ñ/[id=int]');
    expect(page('/x%20y'), 'x y');
    expect(page('/%C3%B1/x'), '[...rest]');
    expect(page('/other'), '[slug]');
    expect(page('/'), '');
    expect(page('/a/b'), '[...rest]');
  });
}

bool _sameList(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!identical(a[i], b[i])) return false;
  }
  return true;
}

typedef _Folder = ({
  List<LayoutRoute<String, Object?>> layouts,
  List<String> segments,
});

/// Every layout of [nodes] with its chain and URL pattern, in tree order.
List<_Folder> _folders(List<RouteNode<String>> nodes) {
  final out = <_Folder>[];
  void walk(
    List<RouteNode<String>> nodes,
    List<LayoutRoute<String, Object?>> chain,
    List<String> prefix,
  ) {
    for (final node in nodes) {
      final segments = [
        ...prefix,
        ...node.path
            .split('/')
            .where(
              (s) => s.isNotEmpty && !(s.startsWith('(') && s.endsWith(')')),
            ),
      ];
      if (node is LayoutRoute<String, Object?>) {
        final layouts = [...chain, node];
        out.add((layouts: layouts, segments: segments));
        walk(node.children, layouts, segments);
      }
    }
  }

  walk(nodes, const [], const []);
  return out;
}

/// The linear 404 folder choice (the router before the index).
(List<LayoutRoute<String, Object?>>, Map<String, String>)? _linearNotFound(
  RouteIndex<String> router,
  List<RouteNode<String>> nodes,
  String path,
) {
  final parts = _parts(path);
  final folders = _folders(nodes);
  (List<LayoutRoute<String, Object?>>, Map<String, String>)? best;
  var bestPrefix = -1;
  var bestReach = -1;
  var bestDepth = 0;
  for (final folder in folders) {
    final params = _matchPrefix(folder.segments, parts);
    if (params == null) continue;
    final prefix = folder.segments.length;
    var reach = prefix;
    for (final e in router.entries) {
      if (!e.layouts.contains(folder.layouts.last)) continue;
      final n = _reach(e.segments, parts);
      if (n > reach) reach = n;
    }
    final deeper = folder.layouts.length > bestDepth;
    final better =
        prefix > bestPrefix ||
        (prefix == bestPrefix &&
            (reach > bestReach ||
                (reach == bestReach && reach > prefix && deeper)));
    if (better) {
      best = (folder.layouts, params);
      bestPrefix = prefix;
      bestReach = reach;
      bestDepth = folder.layouts.length;
    }
  }
  return best;
}

Map<String, String>? _matchPrefix(List<String> pattern, List<String> parts) {
  if (pattern.length > parts.length) return null;
  final params = <String, String>{};
  for (var i = 0; i < pattern.length; i++) {
    final seg = pattern[i];
    if (seg.startsWith('[...')) return null;
    if (seg.startsWith('[')) {
      final value = _decode(parts[i]);
      final (name, type) = RouteIndex.parameter(seg);
      if (!_fits(value, type)) return null;
      params[name] = value;
    } else if (seg != _decode(parts[i])) {
      return null;
    }
  }
  return params;
}

int _reach(List<String> pattern, List<String> parts) {
  var n = 0;
  for (; n < pattern.length && n < parts.length; n++) {
    final seg = pattern[n];
    if (seg.startsWith('[...')) return parts.length;
    if (seg.startsWith('[')) {
      if (!_fits(_decode(parts[n]), RouteIndex.parameter(seg).$2)) break;
    } else if (seg != _decode(parts[n])) {
      break;
    }
  }
  return n;
}
