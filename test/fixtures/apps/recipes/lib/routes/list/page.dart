// Recipe: a list with filters. Search and category live in the URL (GET
// form): the page is shareable, survives a reload and works without
// JavaScript; the server filters.
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../data.dart';
import '../../ui/page_title.dart';
import '../../ui/tokens.dart';

/// The filters, read from the query (`?q=café&cat=tea`).
typedef Filters = ({String q, Category? category, List<Product> results});

/// The page `/list`.
class ListPage extends ThorPage<Filters> {
  /// The one instance the build shares between requests.
  const ListPage();

  /// Filters on the server: the page only paints.
  @override
  Filters load(PageRequest request) {
    final q = (request.queryParameters['q'] ?? '').trim();
    final category = Category.values
        .where((c) => c.name == request.queryParameters['cat'])
        .firstOrNull;
    final needle = q.toLowerCase();
    return (
      q: q,
      category: category,
      results: [
        for (final p in products)
          if ((category == null || p.category == category) &&
              (needle.isEmpty || p.name.toLowerCase().contains(needle)))
            p,
      ],
    );
  }

  /// `/list`.
  @override
  PageMeta meta(PageState<Filters> state) => const PageMeta(title: 'Lista');

  /// The filter bar, the count and the rows.
  @override
  Widget build(BuildContext context, PageState<Filters> state) {
    final f = state.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        const PageTitle('Lista con filtros'),
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
                  initialValue: f.q,
                  decoration: const InputDecoration(labelText: 'Buscar'),
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButton<String>(
                  name: 'cat',
                  semanticLabel: 'Categoría',
                  value: f.category?.name ?? '',
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Todas')),
                    for (final c in Category.values)
                      DropdownMenuItem(value: c.name, child: Text(c.label)),
                  ],
                ),
              ),
              FilledButton(
                buttonType: ButtonType.submit,
                onPressed: () {},
                child: const Text('Filtrar'),
              ),
            ],
          ),
        ),
        Semantics(
          role: SemanticsRole.status,
          child: Text(
            '${f.results.length} de ${products.length} productos',
            style: const TextStyle(color: muted),
          ),
        ),
        if (f.results.isEmpty)
          const Text('Nada coincide con los filtros.')
        else
          Container(
            decoration: surface,
            child: Semantics(
              role: SemanticsRole.list,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final p in f.results)
                    Semantics(
                      role: SemanticsRole.listItem,
                      child: ListTile(
                        title: Text(p.name),
                        subtitle: Text(p.category.label),
                        trailing: Text(money(p.price)),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
