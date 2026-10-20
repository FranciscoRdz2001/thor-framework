// Recipe: the product card of /card with the web layer's typed
// `Style` (CSS names, thor's value types).
import 'package:thor_ui/web.dart';

import '../../../../data.dart';
import '../../../../web/web_ui.dart';

/// The page `/web/card/style`.
class WebCardStylePage extends ThorPage<void> {
  /// The one instance the build shares between requests.
  const WebCardStylePage();

  /// `/web/card/style`.
  @override
  PageMeta meta(PageState<void> state) =>
      const PageMeta(title: 'Tarjeta (Style)');

  /// Two cards: one in a narrow column, one wide.
  @override
  Widget build(BuildContext context, PageState<void> state) => FlexBox(
    direction: FlexDirection.column,
    gap: 24.px,
    children: [
      const StyleTitle(
        'Tarjeta',
        description: 'Menos de 440 px de ancho propio: apilada. Más: en fila.',
      ),
      Box(
        style: Style(
          display: Display.grid,
          gridTemplateColumns: const GridTracks.repeat(1),
          gap: 16.px,
        ).when(medium: const Style(gridTemplateColumns: GridTracks.repeat(3))),
        children: [
          StyleProductCard(products[0]),
          StyleProductCard(products[3]),
        ],
      ),
    ],
  );
}
