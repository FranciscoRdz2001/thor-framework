// Recipe: a data table with filters and sorting. Search and order live in
// the URL: a header is a link to the same page sorted by its column, so
// the table works without JavaScript and a sorted view can be shared; the
// server filters and sorts, the table only paints.
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../data.dart';
import '../../router.dart';
import '../../ui/page_title.dart';
import '../../ui/tokens.dart';

/// A column the table sorts by (a real enum: the URL value is its name).
enum SortBy {
  /// By name.
  product('Nombre'),

  /// By category.
  category('Categoría'),

  /// By price.
  price('Precio'),

  /// By units in stock.
  stock('Existencias');

  const SortBy(this.label);

  /// The header's text.
  final String label;

  /// Numbers align to the end.
  bool get numeric => this == price || this == stock;
}

/// What the page shows: the filter, the order and the rows.
typedef Sorted = ({
  String q,
  SortBy sortBy,
  bool ascending,
  List<Product> results,
});

/// The page `/table`.
class TablePage extends ThorPage<Sorted> {
  /// The one instance the build shares between requests.
  const TablePage();

  /// `?q=café&sort=price&dir=desc`; an unknown order is the default.
  @override
  Sorted load(PageRequest request) {
    final query = request.queryParameters;
    final q = (query['q'] ?? '').trim();
    final sortBy =
        SortBy.values.where((s) => s.name == query['sort']).firstOrNull ??
        SortBy.product;
    final ascending = query['dir'] != 'desc';
    final needle = q.toLowerCase();
    final results = [
      for (final p in products)
        if (needle.isEmpty || p.name.toLowerCase().contains(needle)) p,
    ];
    int compare(Product a, Product b) => switch (sortBy) {
      SortBy.product => a.name.compareTo(b.name),
      SortBy.category => a.category.label.compareTo(b.category.label),
      SortBy.price => a.price.compareTo(b.price),
      SortBy.stock => a.stock.compareTo(b.stock),
    };
    results.sort((a, b) => ascending ? compare(a, b) : compare(b, a));
    return (q: q, sortBy: sortBy, ascending: ascending, results: results);
  }

  /// `/table`.
  @override
  PageMeta meta(PageState<Sorted> state) => const PageMeta(title: 'Tabla');

  /// The search, the count and the table.
  @override
  Widget build(BuildContext context, PageState<Sorted> state) {
    final s = state.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        const PageTitle('Tabla con filtros y orden'),
        Form(
          formMethod: FormMethod.get,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SizedBox(
                width: 260,
                child: TextFormField(
                  name: 'q',
                  initialValue: s.q,
                  decoration: const InputDecoration(labelText: 'Buscar'),
                ),
              ),
              // The order survives a new search.
              HiddenField(name: 'sort', value: s.sortBy.name),
              if (!s.ascending) const HiddenField(name: 'dir', value: 'desc'),
              FilledButton(
                buttonType: ButtonType.submit,
                onPressed: () {},
                child: const Text('Buscar'),
              ),
            ],
          ),
        ),
        Semantics(
          role: SemanticsRole.status,
          child: Text(
            '${s.results.length} de ${products.length} productos',
            style: const TextStyle(color: muted),
          ),
        ),
        Container(
          decoration: surface,
          // Narrow screens scroll the table sideways, not the page.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              sortColumnIndex: s.sortBy.index,
              sortAscending: s.ascending,
              columns: [
                for (final column in SortBy.values)
                  DataColumn(
                    numeric: column.numeric,
                    label: Link(
                      href: RouteUrl(_sortUrl(s, column)),
                      child: Text(column.label),
                    ),
                  ),
              ],
              rows: [
                for (final p in s.results)
                  DataRow(
                    cells: [
                      DataCell(Text(p.name)),
                      DataCell(Text(p.category.label)),
                      DataCell(Text(money(p.price))),
                      DataCell(
                        Text(p.stock == 0 ? 'Agotado' : '${p.stock}'),
                        placeholder: p.stock == 0,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The URL of this page sorted by [column] (a sorted column flips).
String _sortUrl(Sorted s, SortBy column) {
  final ascending = s.sortBy != column || !s.ascending;
  return Uri(
    path: tableRoute.link(),
    queryParameters: {
      if (s.q.isNotEmpty) 'q': s.q,
      'sort': column.name,
      if (!ascending) 'dir': 'desc',
    },
  ).toString();
}
