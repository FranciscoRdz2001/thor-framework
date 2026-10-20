// Recipe: the dashboard of /panel with the web layer's utilities: a grid
// whose columns change per breakpoint, a row per product. The progress bar
// is Flutter's (`Expanded` works in any flex): both layers mix.
import 'package:thor_ui/web.dart';

import '../../../data.dart';
import '../../../web/web_ui.dart';
import '../../panel/page.dart' as flutter show Stats, PanelPage;

/// The page `/web/panel`.
class WebPanelPage extends ThorPage<flutter.Stats> {
  /// The one instance the build shares between requests.
  const WebPanelPage();

  /// Same numbers as /panel.
  @override
  flutter.Stats load(PageRequest request) =>
      const flutter.PanelPage().load(request);

  /// `/web/panel`.
  @override
  PageMeta meta(PageState<flutter.Stats> state) =>
      const PageMeta(title: 'Panel (tw)');

  /// Four stat tiles and a bar per product.
  @override
  Widget build(BuildContext context, PageState<flutter.Stats> state) {
    final s = state.data;
    final maxStock = products.fold(1, (m, p) => p.stock > m ? p.stock : m);
    return FlexBox(
      direction: FlexDirection.column,
      gap: 16.px,
      children: [
        const WebTitle('Panel'),
        Box(
          style: tw(
            'grid grid-cols-1 gap-3 medium:grid-cols-2 medium:gap-4 expanded:grid-cols-4',
          ),
          children: [
            _Stat('Productos', '${s.products}'),
            _Stat('Unidades', '${s.stock}'),
            _Stat('Valor del inventario', money(s.value)),
            _Stat('Agotados', '${s.empty}', alert: s.empty > 0),
            Section(
              style: tw(
                'col-span-full flex flex-col gap-2.5 rounded-xl border '
                'border-line bg-white p-5',
              ),
              children: [
                H2(text: 'Existencias', style: tw('font-semibold')),
                for (final p in products)
                  Box(
                    style: tw('flex items-center gap-3'),
                    children: [
                      Span(text: p.name, style: tw('w-35 shrink-0')),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: p.stock / maxStock,
                          semanticsLabel: 'Existencias de ${p.name}',
                        ),
                      ),
                      Span(
                        text: '${p.stock}',
                        style: tw('w-8 shrink-0 text-end'),
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

class _Stat extends StatelessWidget implements ThorElementWidget {
  const _Stat(this.label, this.value, {this.alert = false});

  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) => Box(
    style: tw(
      'flex flex-col items-start gap-1 rounded-xl border border-line '
      'bg-white p-4',
    ),
    children: [
      Span(text: label, style: tw('text-[13px] text-muted')),
      Span(
        text: value,
        style: tw(
          'text-[26px] font-bold tabular-nums '
          '${alert ? 'text-danger' : 'text-ink'}',
        ),
      ),
    ],
  );
}
