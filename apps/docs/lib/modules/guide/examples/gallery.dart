// ignore_for_file: public_member_api_docs
// (each example is named by its region; a doc comment would sit outside
// the code the site shows)
// The live examples of the guide. Each one sits between `// region: <id>`
// and `// endregion`: the site shows that code (with its thor_ui import) and renders
// the same widget on the page (its HTML and CSS are the real output).
// Keep them free of state: every example works with the browser alone. The
// only handler is `demo.notice`, on the buttons that only have to look
// enabled.
import 'package:thor_ui/thor_ui.dart';

import 'catalog_shared.dart' show demo;

// region: card
class CoffeeCard extends StatelessWidget {
  const CoffeeCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 240,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: ThemeColor.surfaceContainer,
      border: Border.all(color: ThemeColor.outlineVariant),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        const Text(
          'Cold brew',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const Text(
          'Cinnamon and brown sugar',
          style: TextStyle(color: ThemeColor.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Text(
                r'$45.00',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            FilledButton(onPressed: demo.notice, child: const Text('Add')),
          ],
        ),
      ],
    ),
  );
}
// endregion

// region: hover
class HoverColorBox extends StatelessWidget {
  const HoverColorBox({super.key});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOut,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    decoration: BoxDecoration(
      color: ThemeColor.surfaceContainer.when(
        hover: ThemeColor.secondaryContainer,
        pressed: ThemeColor.secondaryContainer,
      ),
      border: Border.all(
        color: ThemeColor.outlineVariant.when(
          hover: ThemeColor.primary,
          pressed: ThemeColor.primary,
        ),
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Text('Hover or tap'),
  );
}
// endregion

// region: accordion
class FaqAccordion extends StatelessWidget {
  const FaqAccordion({super.key});

  @override
  Widget build(BuildContext context) => const ExpansionPanelList(
    name: 'faq',
    children: [
      ExpansionTile(
        title: Text('Can several be open?'),
        initiallyExpanded: true,
        children: [Text('No: opening one closes the others.')],
      ),
      ExpansionTile(
        title: Text('What if I open this one?'),
        children: [Text('The first one closed: they share a name.')],
      ),
      ExpansionTile(
        title: Text('Does it work with the keyboard?'),
        children: [Text('Tab to reach it, Enter to open it.')],
      ),
    ],
  );
}
// endregion

// region: carousel
class OffersCarousel extends StatelessWidget {
  const OffersCarousel({super.key});

  @override
  Widget build(BuildContext context) => CarouselView(
    label: 'Offers',
    showIndicators: true,
    arrowStyle: IconButton.styleFrom(
      backgroundColor: ThemeColor.primary,
      foregroundColor: ThemeColor.onPrimary,
      minimumSize: const Size.square(34),
    ),
    arrowIcon:
        Icons.arrow_forward_ios, // points forward; the previous one is mirrored
    arrowInset: 12, // px from the carousel's edge
    indicatorStyle: const CarouselIndicatorStyle(
      activeColor: ThemeColor.primary,
    ),
    children: [
      for (final (i, color) in [
        ThemeColor.secondaryContainer,
        ThemeColor.surfaceContainerHighest,
        ThemeColor.primary.withValues(alpha: 0.15),
      ].indexed)
        Container(
          height: 140,
          color: color,
          alignment: Alignment.center,
          child: Text('Offer ${i + 1}'),
        ),
    ],
  );
}
// endregion

// region: tabs
class OrderTabs extends StatelessWidget {
  const OrderTabs({super.key});

  @override
  Widget build(BuildContext context) => const DefaultTabController(
    length: 3,
    child: Column(
      children: [
        TabBar(
          tabs: [
            Tab(text: 'Details'),
            Tab(text: 'Payments'),
            Tab(text: 'Shipping'),
          ],
        ),
        TabBarView(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text('3 items, 1 pending.'),
            ),
            Padding(padding: EdgeInsets.all(16), child: Text('Paid by card.')),
            Padding(
              padding: EdgeInsets.all(16),
              child: Text('Arrives on Friday.'),
            ),
          ],
        ),
      ],
    ),
  );
}
// endregion

// region: dialog
// The dialog travels with its button: no id and no controller, the page
// names both.
class ConfirmChargeDialog extends StatelessWidget {
  const ConfirmChargeDialog({super.key});

  @override
  Widget build(BuildContext context) => const DialogTrigger(
    dialog: AlertDialog(
      title: Text(r'Charge $187.00?'),
      content: Text("We'll email the receipt."),
      actions: [
        DialogClose(child: TextButton(child: Text('Cancel'))),
        DialogClose(child: FilledButton(child: Text('Charge'))),
      ],
    ),
    child: FilledButton(child: Text('Charge')),
  );
}
// endregion

// region: menu
class CatalogViewModel extends ThorState {
  void sort(String field) => toast('Sorted by $field');
}

final catalog = CatalogViewModel();

class SortMenu extends StatelessWidget {
  const SortMenu({super.key});

  @override
  Widget build(BuildContext context) => PopupMenuButton(
    // The trigger's name, the same as its visible text.
    tooltip: 'Sort',
    onSelected: catalog.sort,
    // With a style the trigger is a button, not the round icon target.
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      side: const BorderSide(color: ThemeColor.outline),
      shape: const StadiumBorder(),
    ),
    items: const [
      PopupMenuItem(value: 'price', child: Text('By price')),
      PopupMenuItem(value: 'name', child: Text('By name')),
      PopupMenuItem(value: 'date', child: Text('By date')),
    ],
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [Text('Sort'), Icon(Icons.expand_more, size: 18)],
    ),
  );
}
// endregion

// region: menu-anchor
// The anchor is the builder's button; the browser opens the menu. Pressing
// an item runs its callback and closes the menu.
class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key});

  @override
  Widget build(BuildContext context) => MenuAnchor(
    builder: (context, controller, child) => OutlinedButton(
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
      child: const Text('My account'),
    ),
    menuChildren: [
      MenuItemButton(
        onPressed: demo.notice,
        leadingIcon: const Icon(Icons.list),
        child: const Text('My orders'),
      ),
      MenuItemButton(onPressed: demo.notice, child: const Text('Help')),
      SubmenuButton(
        menuChildren: [
          MenuItemButton(onPressed: demo.notice, child: const Text('Export')),
          MenuItemButton(
            onPressed: demo.notice,
            child: const Text('Delete account'),
          ),
        ],
        child: const Text('More'),
      ),
    ],
  );
}
// endregion

// region: scale
class GrowOnHover extends StatelessWidget {
  const GrowOnHover({super.key});

  @override
  Widget build(BuildContext context) => Styled(
    style: const StyleProps(scale: 1).when(
      hover: const StyleProps(scale: 1.06),
      pressed: const StyleProps(scale: 1.06),
    ),
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeOutBack,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        color: ThemeColor.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'Grows on hover or tap',
        style: TextStyle(
          color: ThemeColor.onPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
// endregion

// region: entrance
// A controller outside any ThorState that already plays when the page
// renders: a CSS animation, with no JavaScript.
class LiveEntrance extends StatelessWidget {
  const LiveEntrance({super.key});

  @override
  Widget build(BuildContext context) => SlideTransition(
    position: Tween(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: AnimationController(duration: const Duration(milliseconds: 700))
          ..forward(),
        curve: Curves.easeOutCubic,
      ),
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: ThemeColor.surfaceContainer,
        border: Border.all(color: ThemeColor.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.3, end: 1.0).animate(
              AnimationController(duration: const Duration(milliseconds: 900))
                ..repeat(reverse: true),
            ),
            child: const Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Color(0xFF16A34A),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Flexible(
            child: Text(
              'Live: it enters on load and pulses with no JavaScript',
            ),
          ),
        ],
      ),
    ),
  );
}
// endregion

// region: chips
class ChipsAndProgress extends StatelessWidget {
  const ChipsAndProgress({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      FilterChip(
        label: const Text('Coffee'),
        selected: true,
        onSelected: (_) {},
      ),
      FilterChip(label: const Text('Tea'), selected: false, onSelected: (_) {}),
      const Chip(label: Text('Sugar free')),
      const SizedBox(width: 200, child: LinearProgressIndicator(value: 0.6)),
    ],
  );
}
// endregion

// region: product-card
class Product {
  const Product(this.name, this.origin, this.price, this.tags);
  final String name;
  final String origin;
  final double price;
  final List<String> tags;
}

// Shared values, like in any Flutter app: a TextStyle, a BoxDecoration.
const _title = TextStyle(fontSize: 17, fontWeight: FontWeight.w700);

final _cardDecoration = BoxDecoration(
  color: ThemeColor.surfaceContainer,
  border: Border.all(color: ThemeColor.outlineVariant),
  borderRadius: BorderRadius.circular(18),
  boxShadow: const [
    BoxShadow(color: Color(0x140F172A), offset: Offset(0, 8), blurRadius: 24),
  ],
);

// The class names come from the component: this one's elements are
// product-card, product-card__row, product-card__chip…
class ProductCard extends StatelessWidget {
  const ProductCard(this.product, {super.key});
  final Product product;

  @override
  Widget build(BuildContext context) => Semantics(
    role: SemanticsRole.article,
    child: Container(
      width: 300,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Container(
            height: 132,
            padding: const EdgeInsets.all(10),
            alignment: Alignment.topRight,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6366F1), Color(0xFF0EA5E9)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: ThemeColor.surface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'New',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Semantics(
                      headingLevel: 3,
                      child: Text(product.name, style: _title),
                    ),
                    Semantics(
                      role: SemanticsRole.paragraph,
                      child: Text(
                        product.origin,
                        style: const TextStyle(
                          color: ThemeColor.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                role: SemanticsRole.paragraph,
                child: Text(
                  '\$${product.price.toStringAsFixed(2)}',
                  style: _title,
                ),
              ),
            ],
          ),
          Semantics(
            role: SemanticsRole.list,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final label in product.tags)
                  Semantics(
                    role: SemanticsRole.listItem,
                    child: Chip(label: Text(label)),
                  ),
              ],
            ),
          ),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: demo.notice,
                  child: const Text('Add to cart'),
                ),
              ),
              OutlinedButton(
                onPressed: demo.notice,
                child: const Text('Details'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class ColdBrewCard extends StatelessWidget {
  const ColdBrewCard({super.key});

  @override
  Widget build(BuildContext context) => const ProductCard(
    Product('Cold brew', 'Chiapas, Mexico', 45, ['Cold', 'Single origin']),
  );
}
// endregion

// region: wrappers
class TotalRow extends StatelessWidget {
  const TotalRow({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 280,
    child: Row(
      children: [
        // Expanded, Opacity and Padding add no element: they go on the Text.
        Expanded(
          child: Opacity(
            opacity: 0.8,
            child: Padding(padding: EdgeInsets.all(8), child: Text('Total')),
          ),
        ),
        Text(r'$12.00', style: TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
// endregion

// region: grid
class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 560,
    child: Grid(
      layout: const GridLayout(columns: 1, gap: 12).when(
        medium: const GridLayout(columns: 2),
        expanded: const GridLayout(columns: 3, gap: 16),
      ),
      children: [
        for (final name in [
          'Cold brew',
          'Croissant',
          'Hot chocolate',
          'Baguette',
        ])
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ThemeColor.surfaceContainer,
              border: Border.all(color: ThemeColor.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(name),
          ),
      ],
    ),
  );
}
// endregion

// region: variants
class ResponsiveVariants extends StatelessWidget {
  const ResponsiveVariants({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12).when(medium: const EdgeInsets.all(24)),
    decoration: BoxDecoration(
      color: ThemeColor.surfaceContainer.when(
        hover: ThemeColor.secondaryContainer,
        pressed: ThemeColor.secondaryContainer,
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Flex(
      direction: Axis.vertical,
      // A column on a phone, a row from md on.
      layout: const FlexLayout(
        spacing: 8,
      ).when(medium: const FlexLayout(direction: Axis.horizontal, spacing: 24)),
      children: [
        Text(
          'Resize the window',
          style: const TextStyle(fontSize: 14).when(
            medium: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        const Text('or hover (tap) the box'),
      ],
    ),
  );
}
// endregion

// region: hover-group
class HoverGroupCard extends StatelessWidget {
  const HoverGroupCard({super.key});

  @override
  Widget build(BuildContext context) => HoverGroup(
    child: Card(
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            // Scales when the pointer is anywhere over the card.
            Styled(
              style: const StyleProps().when(
                groupHover: const StyleProps(scale: 1.05),
              ),
              duration: const Duration(milliseconds: 200),
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  color: ThemeColor.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const Text(
              'Hover the card',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );
}
// endregion
