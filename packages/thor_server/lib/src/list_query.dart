import 'dart:convert';

import 'request.dart';
import 'results.dart' show Redirect;
import 'route_url.dart';

/// [path] as a link to this site: one leading `/`. A request for
/// `//evil.example/x` has that path, and a redirect or a link made from it
/// (`Location: //evil.example/x`) leaves the site, since `//host` is a
/// protocol-relative URL. Django's `APPEND_SLASH` had it
/// (CVE-2018-14574; `escape_leading_slashes`). Not exported.
String sitePath(String path) => RegExp(r'^/[/\\]').hasMatch(path)
    // `//host` and `/\host`: browsers read both as another site.
    ? path.replaceFirst(RegExp(r'^[/\\]+'), '/')
    : path;

/// [location] as a `Location` header value that cannot leave the site by
/// accident: control characters are gone first (anywhere, which also closes
/// header injection and keeps `dart:io` from failing on one), leading spaces
/// too, and what is not ASCII is percent-encoded; `javascript:`, `data:` and
/// `vbscript:` become `/`. Then a path that starts with two slashes or
/// backslashes (`//host`, `/\host`, `\\host`, `\/host`) keeps one `/`. An
/// absolute URL (`https://sso.example/…`) is the app's choice and stays.
/// Not exported.
String safeLocation(String location) {
  var clean = location
      .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '')
      .replaceFirst(RegExp(r'^ +'), '');
  // A header value is ASCII: what is not (`/café`, U+2215, U+2028) is sent
  // as the UTF-8 percent-encoding a browser would make of it anyway.
  if (RegExp(r'[^\x20-\x7e]', unicode: true).hasMatch(clean)) {
    clean = clean.replaceAllMapped(
      RegExp(r'[^\x20-\x7e]', unicode: true),
      (m) => utf8
          .encode(m[0]!)
          .map((b) => '%${b.toRadixString(16).toUpperCase().padLeft(2, '0')}')
          .join(),
    );
  }
  // A scheme that runs code or inlines a document is never a place to go.
  if (RegExp(
    r'^(?:javascript|data|vbscript):',
    caseSensitive: false,
  ).hasMatch(clean)) {
    return '/';
  }
  return RegExp(r'^[/\\][/\\]').hasMatch(clean) || clean.startsWith('\\')
      ? clean.replaceFirst(RegExp(r'^[/\\]+'), '/')
      : clean;
}

/// Where to go after an action (a login that came from `/login?next=/cart`):
/// [value] when it is a path on this site, else [fallback]. Never an open
/// redirect: only a path that starts with one `/` passes, or an absolute
/// URL of this request's own origin (reduced to its path). Another origin,
/// `//host`, a backslash, a control character, `javascript:`, more than 2048 characters, and any of
/// those hidden behind percent-encoding (also double) give [fallback].
///
/// ```dart
/// return Redirect(safeNext(request, form.text('next'), fallback: '/account'));
/// ```
RouteUrl safeNext(
  PageRequest request,
  String? value, {
  RouteUrl fallback = const RouteUrl('/'),
}) {
  // Django's MAX_URL_LENGTH: no target is worth a longer Location header.
  if (value == null || value.isEmpty || value.length > 2048) return fallback;
  var path = value;
  if (!path.startsWith('/') && !path.startsWith('\\')) {
    // Only an absolute URL of this very origin is a place on this site.
    final uri = Uri.tryParse(value);
    final here = request.uri;
    if (uri == null ||
        !uri.hasScheme ||
        uri.userInfo.isNotEmpty ||
        uri.scheme != here.scheme ||
        uri.host.toLowerCase() != here.host.toLowerCase() ||
        uri.port != here.port) {
      return fallback;
    }
    path = uri.path.isEmpty ? '/' : uri.path;
    if (uri.hasQuery) path += '?${uri.query}';
    if (uri.hasFragment) path += '#${uri.fragment}';
  }
  if (!_isSitePath(path)) return fallback;
  // What a browser would read after decoding (once or more) must still be
  // a path of this site: `/%2F/host`, `/%5Chost`, `/%252F%252Fhost`.
  // A malformed escape is not a target worth guessing at.
  if (RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(path)) return fallback;
  var decoded = path;
  for (var i = 0; i < 4; i++) {
    // Only the ASCII escapes: the dangerous characters are all ASCII.
    final next = decoded.replaceAllMapped(RegExp(r'%([0-7][0-9a-fA-F])'), (m) {
      return String.fromCharCode(int.parse(m[1]!, radix: 16));
    });
    if (next == decoded) break;
    if (!_isSitePath(next)) return fallback;
    decoded = next;
  }
  final clean = safeLocation(path);
  return _isSitePath(clean) ? RouteUrl(clean) : fallback;
}

bool _isSitePath(String p) =>
    p.startsWith('/') &&
    !p.startsWith('//') &&
    !RegExp(r'[\\\x00-\x1f\x7f]').hasMatch(p);

/// The action key of a form post (`?/save`) never belongs to the page: what
/// [rawQuery] (as the browser sent it) keeps once the keys that start with
/// `/` are gone (`%2Fsave` too), in the same order and encoding.
String queryWithoutAction(String rawQuery) => [
  for (final piece in rawQuery.split('&'))
    if (piece.isNotEmpty && !_isAction(piece)) piece,
].join('&');

bool _isAction(String piece) {
  final eq = piece.indexOf('=');
  final key = eq < 0 ? piece : piece.substring(0, eq);
  if (key.startsWith('/')) return true;
  if (!key.contains('%')) return false;
  try {
    return Uri.decodeQueryComponent(key).startsWith('/');
    // A broken escape is not an action key; the router doesn't see one.
    // ignore: avoid_catches_without_on_clauses
  } catch (_) {
    return false;
  }
}

/// The state of a list page, read from its URL: the search text, the page
/// (1-based), the sort and the filters. The URL is the state, so a link, a
/// bookmark and «back» work with no JavaScript.
///
/// ```dart
/// @override
/// Future<Orders> load(PageRequest request) async {
///   final list = request.listQuery(
///     pageSize: 20,
///     sorts: const {'customer', 'total'},
///     defaultSort: '-total',
///     filters: const {'status'},
///   );
///   final page = await repo.orders(
///     q: list.q, offset: list.offset, limit: list.limit,
///     sort: list.sort, descending: list.descending,
///     status: list.filter('status'),
///   );
///   return Orders(page.rows, list, page.total);
/// }
/// // in build: Pagination(list: data.list, total: data.total)
/// ```
///
/// web: Flutter keeps a list's page in a widget's state; on the web that is
/// lost on reload and can't be linked. Laravel's paginator and Rails'
/// `will_paginate`/Pagy read `?page=` the same way and build their links
/// from it.
final class ListQuery {
  ListQuery._({
    required this.q,
    required this.page,
    required this.pageSize,
    required this.sort,
    required this.descending,
    required this.filters,
    required Set<String> sorts,
    required Set<String> filterNames,
    required String path,
    required List<String> extra,
    required this.searchParameter,
    required this.pageParameter,
    required this.sortParameter,
    required String? defaultSort,
  }) : _sorts = sorts,
       _defaultSort = defaultSort,
       _filterNames = filterNames,
       _path = path,
       _extra = extra;

  /// The largest page number: a bigger one in the URL is this one, so an
  /// offset never overflows.
  static const maxPage = 1000000;

  /// The longest search text kept, in characters.
  static const maxQueryLength = 256;

  /// The search text (`?q=`), trimmed; `''` when there is none.
  final String q;

  /// The page, from 1 (`?page=`): anything that is not a whole page number
  /// is 1, and none is above [maxPage].
  final int page;

  /// Rows per page.
  final int pageSize;

  /// The column to sort by (one of `sorts`), or `null`.
  final String? sort;

  /// Whether [sort] goes from the last to the first (`?sort=-name`).
  final bool descending;

  /// The declared filters that have a value, by name.
  final Map<String, String> filters;

  /// The URL parameter of [q].
  final String searchParameter;

  /// The URL parameter of [page].
  final String pageParameter;

  /// The URL parameter of [sort].
  final String sortParameter;

  final Set<String> _sorts;

  // `name` or `-name`: the sort a URL without `sort` has (not written).
  final String? _defaultSort;
  final Set<String> _filterNames;
  final String _path;

  // The other pieces of the query, as they came (raw, in order).
  final List<String> _extra;

  /// Rows to skip: `(page - 1) * pageSize`.
  int get offset => (page - 1) * pageSize;

  /// Rows to read: [pageSize].
  int get limit => pageSize;

  /// The value of the declared filter [name], or `null`. A name that
  /// `listQuery` was not given is an [ArgumentError].
  String? filter(String name) {
    if (!_filterNames.contains(name)) {
      throw ArgumentError.value(
        name,
        'name',
        'not a filter of this list (declare it in listQuery(filters:))',
      );
    }
    return filters[name];
  }

  /// How many pages [total] rows make (1 at least).
  int pageCount(int total) =>
      total <= 0 ? 1 : (total + pageSize - 1) ~/ pageSize;

  /// This list with its page brought back to the last one when [total]
  /// rows don't reach it (the rows read were none: prefer [within], which
  /// sends the visitor to the last page).
  ListQuery clampTo(int total) {
    final last = pageCount(total);
    return page <= last ? this : _copy(page: last);
  }

  /// This list, or a redirect to its last page when [total] rows don't
  /// reach [page] (`?page=9` on a list of three pages): [Redirect] is
  /// thrown, so `load` can call it after counting. The rows read for a page
  /// past the end are none, and a page that draws an empty table under a
  /// «last page» link is a lie; Pagy's `overflow: :last_page` and Django's
  /// `Paginator.get_page` go to the last page the same way.
  ///
  /// ```dart
  /// return Orders(rows, list.within(total), total);
  /// ```
  ListQuery within(int total) {
    if (page <= pageCount(total)) return this;
    throw Redirect.found(withPage(pageCount(total)));
  }

  /// The URL of page [n] (1 leaves `page` out), with every other
  /// parameter of this one: `/orders?q=caf%C3%A9&page=3`.
  RouteUrl withPage(int n) => _url(page: n);

  /// The URL that searches for [text] (empty clears it), from page 1.
  RouteUrl withSearch(String text) => _url(q: text.trim(), page: 1);

  /// The URL that sorts by [column] (one of `sorts`; `null` clears it),
  /// from page 1.
  RouteUrl withSort(String? column, {bool descending = false}) {
    if (column != null && !_sorts.contains(column)) {
      throw ArgumentError.value(
        column,
        'column',
        'not a sort of this list (declare it in listQuery(sorts:))',
      );
    }
    return _url(sort: (column, descending), page: 1);
  }

  /// The URL that sorts by [column]: the other direction when it is the
  /// current sort, ascending otherwise.
  RouteUrl toggleSort(String column) =>
      withSort(column, descending: sort == column && !descending);

  /// The URL that sets the filter [name] to [value] (`null` or empty
  /// clears it), from page 1.
  RouteUrl withFilter(String name, String? value) {
    filter(name); // declared?
    return _url(filter: (name, value), page: 1);
  }

  ListQuery _copy({required int page}) => ListQuery._(
    q: q,
    page: page,
    pageSize: pageSize,
    sort: sort,
    descending: descending,
    filters: filters,
    sorts: _sorts,
    filterNames: _filterNames,
    path: _path,
    extra: _extra,
    searchParameter: searchParameter,
    pageParameter: pageParameter,
    sortParameter: sortParameter,
    defaultSort: _defaultSort,
  );

  // The parameters this list owns are rewritten; the others stay as they
  // came, in their place.
  RouteUrl _url({
    int? page,
    String? q,
    (String?, bool)? sort,
    (String, String?)? filter,
  }) {
    final n = page == null ? this.page : page.clamp(1, maxPage);
    final search = q ?? this.q;
    final (column, down) = sort ?? (this.sort, descending);
    final sortText = column == null ? null : '${down ? '-' : ''}$column';
    final values = {...filters};
    if (filter != null) {
      final (name, value) = filter;
      if (value == null || value.isEmpty) {
        values.remove(name);
      } else {
        values[name] = value;
      }
    }
    final owned = <String, String?>{
      pageParameter: n > 1 ? '$n' : null,
      searchParameter: search.isEmpty ? null : search,
      // A list that sorts nothing leaves `sort` to whoever uses it.
      if (_sorts.isNotEmpty)
        sortParameter: sortText == _defaultSort ? null : sortText,
      for (final name in _filterNames) name: values[name],
    };
    final out = <String>[];
    final written = <String>{};
    for (final piece in _extra) {
      final key = _keyOf(piece);
      if (!owned.containsKey(key)) {
        out.add(piece);
      } else if (written.add(key)) {
        // Its place in the URL stays where the first one was.
        if (owned[key] case final v?) out.add(_pair(key, v));
      }
    }
    for (final MapEntry(:key, :value) in owned.entries) {
      if (value != null && written.add(key)) out.add(_pair(key, value));
    }
    return RouteUrl(out.isEmpty ? _path : '$_path?${out.join('&')}');
  }

  static String _pair(String key, String value) =>
      '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value)}';

  static String _keyOf(String piece) {
    final eq = piece.indexOf('=');
    final raw = eq < 0 ? piece : piece.substring(0, eq);
    try {
      return Uri.decodeQueryComponent(raw);
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return raw;
    }
  }
}

/// The list state in the URL (see [ListQuery]).
extension ListQueryRequest on PageRequest {
  /// Reads `?q=`, `?page=`, `?sort=` and the [filters] of this request.
  ///
  /// Every value is checked here, so a hand-made URL is never an error:
  /// the page is a whole number from 1 (up to [ListQuery.maxPage]), the
  /// sort one of [sorts] (else [defaultSort], a name, `-name` for
  /// descending) and only the [filters] you declare are read. [pageSize] is
  /// the rows per page.
  ListQuery listQuery({
    int pageSize = 20,
    Set<String> sorts = const {},
    String? defaultSort,
    Set<String> filters = const {},
    String searchParameter = 'q',
    String pageParameter = 'page',
    String sortParameter = 'sort',
  }) {
    if (pageSize < 1) {
      throw ArgumentError.value(pageSize, 'pageSize', 'must be at least 1');
    }
    final pieces = [
      for (final piece in uri.query.split('&'))
        if (piece.isNotEmpty && !_isAction(piece)) piece,
    ];
    final first = <String, String>{};
    for (final piece in pieces) {
      final eq = piece.indexOf('=');
      final key = ListQuery._keyOf(piece);
      final value = eq < 0 ? '' : _decode(piece.substring(eq + 1));
      first.putIfAbsent(key, () => value);
    }
    var text = (first[searchParameter] ?? '').trim();
    if (text.runes.length > ListQuery.maxQueryLength) {
      text = String.fromCharCodes(text.runes.take(ListQuery.maxQueryLength));
    }
    final raw = first[pageParameter] ?? '';
    final page = _digits.hasMatch(raw)
        ? (int.tryParse(raw) ?? ListQuery.maxPage).clamp(1, ListQuery.maxPage)
        : 1;
    (String?, bool) pick(String? value) {
      final down = value != null && value.startsWith('-');
      final name = down ? value.substring(1) : value;
      return name != null && sorts.contains(name)
          ? (name, down)
          : (null, false);
    }

    var (sort, descending) = pick(first[sortParameter]);
    if (sort == null) (sort, descending) = pick(defaultSort);
    return ListQuery._(
      q: text,
      page: page,
      pageSize: pageSize,
      sort: sort,
      descending: descending,
      filters: {
        for (final name in filters)
          if (first[name] case final v? when v.isNotEmpty) name: v,
      },
      sorts: sorts,
      filterNames: filters,
      path: uri.path.isEmpty ? '/' : sitePath(uri.path),
      extra: pieces,
      searchParameter: searchParameter,
      pageParameter: pageParameter,
      sortParameter: sortParameter,
      defaultSort: defaultSort,
    );
  }
}

final _digits = RegExp(r'^[0-9]+$');

String _decode(String raw) {
  try {
    return Uri.decodeQueryComponent(raw);
    // ignore: avoid_catches_without_on_clauses
  } catch (_) {
    return raw;
  }
}
