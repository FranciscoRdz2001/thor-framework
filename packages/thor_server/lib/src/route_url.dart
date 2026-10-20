/// A URL a link or a redirect points to.
library;

/// The URL of a link, a redirect or a canonical address: a page of this
/// site (`/orders/7?tab=items`), a section (`#pricing`) or another site
/// (`https://example.com/docs`).
///
/// ```dart
/// Link(href: ordersRoute.link(), child: Text('Orders'))   // a RouteUrl
/// Link(href: const RouteUrl('#pricing'), child: Text('Pricing'))
/// Link(href: RouteUrl.external('https://example.com'), newTab: true, …)
/// return Redirect(orderRoute.link({'id': 7}).withQuery({'saved': '1'}));
/// ```
///
/// `ThorRoute.link` returns one, so the table and every link share one
/// definition of the URL. It *is* a `String` (an API that still takes a
/// `String` accepts it), but an API that takes a [RouteUrl] refuses a raw
/// `String`: a literal path is `const RouteUrl('/about')` and another site
/// is spelled [RouteUrl.external], so it is always on purpose.
///
/// `// web:` no Flutter counterpart; Flutter's `Link` takes a `Uri` and its
/// navigator takes route names.
extension type const RouteUrl(String value) implements String {
  /// A URL on another site: `http`, `https`, `mailto` or `tel`. Any other
  /// scheme (`javascript:`, `data:`) throws, so a link made from data a
  /// visitor sent can never run code.
  factory RouteUrl.external(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        !const {'http', 'https', 'mailto', 'tel'}.contains(uri.scheme)) {
      throw ArgumentError.value(
        url,
        'url',
        'must be an http, https, mailto or tel URL',
      );
    }
    return RouteUrl(url);
  }

  /// The parsed URL.
  Uri get uri => Uri.parse(value);

  /// Whether it leaves this site: it has a scheme (`https://…`) or starts
  /// with `//`.
  bool get isExternal =>
      RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*:').hasMatch(value) ||
      value.startsWith('//');

  /// This URL with its query replaced by [query]: a value is a `String` or,
  /// for a repeated key, an `Iterable<String>` (an empty one writes
  /// nothing). A `#fragment` stays.
  RouteUrl withQuery(Map<String, Object> query) {
    final hash = value.indexOf('#');
    final fragment = hash < 0 ? '' : value.substring(hash);
    final withoutFragment = hash < 0 ? value : value.substring(0, hash);
    final mark = withoutFragment.indexOf('?');
    final base = mark < 0
        ? withoutFragment
        : withoutFragment.substring(0, mark);
    final pairs = <String, Iterable<String>>{
      for (final MapEntry(:key, :value) in query.entries)
        key: switch (value) {
          final String v => [v],
          final Iterable<String> v => v,
          _ => throw ArgumentError.value(
            value,
            'query',
            'a query value is a String or an Iterable<String>',
          ),
        },
    }..removeWhere((_, v) => v.isEmpty);
    final queryString = pairs.isEmpty
        ? ''
        : '?${Uri(queryParameters: pairs).query}';
    return RouteUrl('$base$queryString$fragment');
  }

  /// This URL with `#fragment` as its fragment (an anchor of the page).
  RouteUrl withFragment(String fragment) {
    final hash = value.indexOf('#');
    final base = hash < 0 ? value : value.substring(0, hash);
    return RouteUrl(
      fragment.isEmpty ? base : '$base#${Uri.encodeFull(fragment)}',
    );
  }
}
