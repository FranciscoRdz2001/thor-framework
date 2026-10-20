// Recipe: a responsive dashboard. One Grid whose column count changes per
// breakpoint (`.when()` on the layout value, no LayoutBuilder): 1 on a
// phone, 2 from md, 4 from lg; the chart card spans every column
// (`GridItem`), in the same grid.
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../data.dart';
import '../../ui/page_title.dart';
import '../../ui/tokens.dart';

/// The numbers the page shows (from the server, like any `load`).
typedef Stats = ({int products, int stock, int value, int empty});

/// The page `/panel`.
class PanelPage extends ThorPage<Stats> {
  /// The one instance the build shares between requests.
  const PanelPage();

  /// Computed on the server.
  @override
  Stats load(PageRequest request) => (
    products: products.length,
    stock: products.fold(0, (sum, p) => sum + p.stock),
    value: products.fold(0, (sum, p) => sum + p.stock * p.price),
    empty: products.where((p) => p.stock == 0).length,
  );

  /// `/panel`.
  @override
  PageMeta meta(PageState<Stats> state) => const PageMeta(title: 'Panel');

  /// Four stat tiles and a bar per product.
  @override
  Widget build(BuildContext context, PageState<Stats> state) {
    final s = state.data;
    final maxStock = products.fold(1, (m, p) => p.stock > m ? p.stock : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        const PageTitle('Panel'),
        Grid(
          layout: const GridLayout(columns: 1, gap: 12).when(
            medium: const GridLayout(columns: 2, gap: 16),
            expanded: const GridLayout(columns: 4, gap: 16),
          ),
          children: [
            _Stat('Productos', '${s.products}'),
            _Stat('Unidades', '${s.stock}'),
            _Stat('Valor del inventario', money(s.value)),
            _Stat('Agotados', '${s.empty}', alert: s.empty > 0),
            GridItem(
              placement: GridPlacement.fullWidth,
              child: _Stock(maxStock: maxStock),
            ),
          ],
        ),
      ],
    );
  }
}

class _Stock extends StatelessWidget implements ThorElementWidget {
  const _Stock({required this.maxStock});

  final int maxStock;

  @override
  Widget build(BuildContext context) => Container(
    decoration: surface,
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        const Semantics(
          headingLevel: 2,
          child: Text(
            'Existencias',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        for (final p in products)
          Row(
            spacing: 12,
            children: [
              SizedBox(width: 140, child: Text(p.name)),
              Expanded(
                child: LinearProgressIndicator(
                  value: p.stock / maxStock,
                  semanticsLabel: 'Existencias de ${p.name}',
                ),
              ),
              SizedBox(
                width: 32,
                child: Text('${p.stock}', textAlign: TextAlign.end),
              ),
            ],
          ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget implements ThorElementWidget {
  const _Stat(this.label, this.value, {this.alert = false});

  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) => Container(
    decoration: surface,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text(label, style: const TextStyle(color: muted, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: alert ? danger : ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}
