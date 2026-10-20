// Recipe: the dashboard of /panel with the web layer's typed `Style`.
import 'package:thor_ui/web.dart';

import '../../../../data.dart';
import '../../../../web/web_ui.dart';
import '../../../panel/page.dart' as flutter show Stats, PanelPage;

/// The page `/web/panel/style`.
class WebPanelStylePage extends ThorPage<flutter.Stats> {
  /// The one instance the build shares between requests.
  const WebPanelStylePage();

  /// Same numbers as /panel.
  @override
  flutter.Stats load(PageRequest request) =>
      const flutter.PanelPage().load(request);

  /// `/web/panel/style`.
  @override
  PageMeta meta(PageState<flutter.Stats> state) =>
      const PageMeta(title: 'Panel (Style)');

  /// Four stat tiles and a bar per product.
  @override
  Widget build(BuildContext context, PageState<flutter.Stats> state) {
    final s = state.data;
    final maxStock = products.fold(1, (m, p) => p.stock > m ? p.stock : m);
    return FlexBox(
      direction: FlexDirection.column,
      gap: 16.px,
      children: [
        const StyleTitle('Panel'),
        Box(
          style:
              Style(
                display: Display.grid,
                gridTemplateColumns: const GridTracks.repeat(1),
                gap: 12.px,
              ).when(
                medium: Style(
                  gridTemplateColumns: const GridTracks.repeat(2),
                  gap: 16.px,
                ),
                expanded: const Style(
                  gridTemplateColumns: GridTracks.repeat(4),
                ),
              ),
          children: [
            _Stat('Productos', '${s.products}'),
            _Stat('Unidades', '${s.stock}'),
            _Stat('Valor del inventario', money(s.value)),
            _Stat('Agotados', '${s.empty}', alert: s.empty > 0),
            Section(
              style: _card.merge(
                Style(
                  gridColumn: GridLine.full,
                  display: Display.flex,
                  flexDirection: FlexDirection.column,
                  gap: 10.px,
                  padding: 20.px,
                ),
              ),
              children: [
                const H2(
                  text: 'Existencias',
                  style: Style(fontWeight: FontWeight.w600),
                ),
                for (final p in products)
                  FlexBox(
                    align: AlignItems.center,
                    gap: 12.px,
                    children: [
                      Span(
                        text: p.name,
                        style: Style(width: 140.px, flexShrink: 0),
                      ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: p.stock / maxStock,
                          semanticsLabel: 'Existencias de ${p.name}',
                        ),
                      ),
                      Span(
                        text: '${p.stock}',
                        style: Style(
                          width: 32.px,
                          flexShrink: 0,
                          textAlign: TextAlign.end,
                        ),
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

final _card = Style(
  borderRadius: 12.px,
  borderWidth: 1.px,
  borderColor: _line,
  backgroundColor: const Color(0xFFFFFFFF),
);

class _Stat extends StatelessWidget implements ThorElementWidget {
  const _Stat(this.label, this.value, {this.alert = false});

  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) => Box(
    style: _card.merge(
      Style(
        display: Display.flex,
        flexDirection: FlexDirection.column,
        alignItems: AlignItems.flexStart,
        gap: 4.px,
        padding: 16.px,
      ),
    ),
    children: [
      Span(
        text: label,
        style: Style(fontSize: 13.px, color: _muted),
      ),
      Span(
        text: value,
        style: Style(
          fontSize: 26.px,
          fontWeight: FontWeight.w700,
          fontVariantNumeric: FontVariantNumeric.tabularNums,
          color: alert ? _danger : _ink,
        ),
      ),
    ],
  );
}

// The theme's tokens by name, like `tw('text-ink')`: both modes write the
// same declarations.
final _ink = ThemeColor.token('ink');
final _muted = ThemeColor.token('muted');
final _line = ThemeColor.token('line');
final _danger = ThemeColor.token('danger');
