// Recipe: a product card that stacks when its box is narrow (container
// query: it follows its own width, not the window's).
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../data.dart';
import '../../router.dart';
import '../../ui/page_title.dart';
import '../../ui/tokens.dart';

/// The page `/card`.
class CardPage extends ThorPage<void> {
  /// The one instance the build shares between requests.
  const CardPage();

  /// `/card`.
  @override
  PageMeta meta(PageState<void> state) => const PageMeta(title: 'Tarjeta');

  /// Two cards: one in a narrow column, one wide.
  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 24,
    children: [
      const PageTitle(
        'Tarjeta',
        description: 'Menos de 440 px de ancho propio: apilada. Más: en fila.',
      ),
      Grid(
        layout: const GridLayout(
          columns: 1,
          gap: 16,
        ).when(medium: const GridLayout(columns: 3, gap: 16)),
        children: [ProductCard(products[0]), ProductCard(products[3])],
      ),
    ],
  );
}

/// A product: color block, name, category, price and a button.
class ProductCard extends StatelessWidget implements ThorElementWidget {
  /// The card of [product].
  const ProductCard(this.product, {super.key});

  /// What it shows.
  final Product product;

  @override
  Widget build(BuildContext context) => LayoutScope(
    child: Container(
      decoration: surface,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        // The breakpoint is the card's own width (LayoutScope above).
        layout: const FlexLayout().when(
          container: {
            440: const FlexLayout(
              direction: Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.stretch,
            ),
          },
        ),
        children: [
          Styled(
            style: StyleProps(minHeight: 120.px).when(
              container: {440: StyleProps(minWidth: 160.px, maxWidth: 160.px)},
            ),
            child: const ColoredBox(color: Color(0xFFC7D2FE)),
          ),
          // Flexible, not Expanded: stacked, the column has no height to
          // share and Expanded would collapse the text.
          Flexible(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Semantics(
                    headingLevel: 2,
                    child: Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                  ),
                  Text(
                    product.category.label,
                    style: const TextStyle(color: muted),
                  ),
                  Text(
                    money(product.price),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  FilledButton(
                    onPressed: () {},
                    href:
                        '${listRoute.link()}?q=${Uri.encodeQueryComponent(product.name)}',
                    child: const Text('Ver en la lista'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
