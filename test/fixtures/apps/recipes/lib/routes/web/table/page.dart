// Recipe: the table of /table written with the web layer's HTML table
// elements and `tw()`. Same data and the same URL filter and order; the
// table is a real `<table>` (caption, header scopes, a footer total), and a
// narrow screen scrolls it sideways inside its card.
import 'package:thor_ui/web.dart';

import '../../../data.dart';
import '../../../router.dart';
import '../../../web/web_ui.dart';
import '../../table/page.dart' as table show TablePage;
import '../../table/page.dart' show SortBy, Sorted;

/// The page `/web/table`.
class WebTablePage extends ThorPage<Sorted> {
  /// The one instance the build shares between requests.
  const WebTablePage();

  /// `?q=café&sort=price&dir=desc`, as /table.
  @override
  Sorted load(PageRequest request) => const table.TablePage().load(request);

  /// `/web/table`.
  @override
  PageMeta meta(PageState<Sorted> state) =>
      const PageMeta(title: 'Tabla (web)');

  /// The count and the table.
  @override
  Widget build(BuildContext context, PageState<Sorted> state) {
    final s = state.data;
    final units = s.results.fold<int>(0, (sum, p) => sum + p.stock);
    return FlexBox(
      direction: FlexDirection.column,
      gap: 16.px,
      children: [
        const WebTitle(
          'Tabla',
          description: 'Un <table> de verdad: encabezados con scope y total.',
        ),
        P(
          text: '${s.results.length} de ${products.length} productos',
          style: tw('text-muted'),
          attributes: const {'role': 'status'},
        ),
        Box(
          style: tw('overflow-x-auto rounded-xl border border-line bg-white'),
          children: [
            Table(
              style: tw('w-full text-sm'),
              children: [
                Caption(text: 'Productos', style: tw('sr-only')),
                Thead(
                  children: [
                    Tr(
                      children: [
                        for (final column in SortBy.values)
                          Th(
                            scope: 'col',
                            style: tw(
                              'border-b border-line px-4 py-3 font-medium '
                              'whitespace-nowrap '
                              '${column.numeric ? 'text-right' : 'text-left'}',
                            ),
                            attributes: {'aria-sort': _sortState(s, column)},
                            children: [
                              A(href: _sortUrl(s, column), text: column.label),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
                Tbody(
                  children: [
                    for (final p in s.results)
                      Tr(
                        children: [
                          Th(
                            scope: 'row',
                            text: p.name,
                            style: tw('px-4 py-2 text-left font-medium'),
                          ),
                          Td(
                            text: p.category.label,
                            style: tw('px-4 py-2 text-muted'),
                          ),
                          Td(
                            text: money(p.price),
                            style: tw('px-4 py-2 text-right tabular-nums'),
                          ),
                          Td(
                            text: p.stock == 0 ? 'Agotado' : '${p.stock}',
                            style: tw(
                              p.stock == 0
                                  ? 'px-4 py-2 text-right text-muted'
                                  : 'px-4 py-2 text-right tabular-nums',
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Tfoot(
                  children: [
                    Tr(
                      children: [
                        Th(
                          scope: 'row',
                          colSpan: 3,
                          text: 'Existencias',
                          style: tw('border-t border-line px-4 py-3 text-left'),
                        ),
                        Td(
                          text: '$units',
                          style: tw(
                            'border-t border-line px-4 py-3 text-right '
                            'tabular-nums font-medium',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// The URL of this page sorted by [column] (a sorted column flips).
String _sortUrl(Sorted s, SortBy column) {
  final ascending = s.sortBy != column || !s.ascending;
  return Uri(
    path: webTableRoute.link(),
    queryParameters: {
      if (s.q.isNotEmpty) 'q': s.q,
      'sort': column.name,
      if (!ascending) 'dir': 'desc',
    },
  ).toString();
}

String _sortState(Sorted s, SortBy column) => s.sortBy != column
    ? 'none'
    : s.ascending
    ? 'ascending'
    : 'descending';
