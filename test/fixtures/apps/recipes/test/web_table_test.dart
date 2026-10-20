// /web/table: the table of /table as a real <table>, with the same filter
// and order in the URL.
import 'package:recipes/app.dart';
import 'package:recipes/data.dart';
import 'package:recipes/router.dart';
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';
import 'package:thor_ui/router.dart';

void main() {
  final handler = RouteHandler(
    routes: router.routes,
    renderer: recipesRenderer(),
  );

  Future<String> get(String path) async {
    final r = await handler.client().get(path);
    expect(r.status, 200, reason: path);
    return r.text;
  }

  /// The row headers (`<th scope="row">`) in order: one per product.
  List<String> rowNames(String html) => [
    for (final m in RegExp(
      r'<th[^>]*scope="row"[^>]*>([^<]*)</th>',
    ).allMatches(html))
      m[1]!,
  ]..remove('Existencias');

  test('a table with its caption, column headers and a footer', () async {
    final html = await get(webTableRoute.link());
    expect(html, contains(RegExp(r'<table[\s>]')));
    expect(html, contains('>Productos</caption>'));
    expect(RegExp(r'<th[^>]*scope="col"').allMatches(html), hasLength(4));
    expect(RegExp(r'<tfoot[\s>]').hasMatch(html), isTrue);
    expect(rowNames(html), hasLength(products.length));
    expect(html, contains('aria-sort="ascending"'));
  });

  test('sorted by price, descending, from the URL', () async {
    final html = await get('${webTableRoute.link()}?sort=price&dir=desc');
    final byPrice = [...products]..sort((a, b) => b.price.compareTo(a.price));
    expect(rowNames(html), [for (final p in byPrice) p.name]);
    expect(html, contains('aria-sort="descending"'));
  });

  test(
    'a search keeps only the matches; an unknown order is the default',
    () async {
      final first = products.first.name;
      final html = await get(
        '${webTableRoute.link()}?q=${Uri.encodeQueryComponent(first)}&sort=nothing',
      );
      expect(rowNames(html), everyElement(contains(first)));
      expect(html, contains('aria-sort="ascending"'));
    },
  );
}
