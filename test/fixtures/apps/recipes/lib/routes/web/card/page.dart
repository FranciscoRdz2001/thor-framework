// Recipe: the product card of /card, written with the web layer's
// utilities (`tw()`). Same screen, same one-element-one-class output.
import 'package:thor_ui/web.dart';

import '../../../data.dart';
import '../../../web/web_ui.dart';

/// The page `/web/card`.
class WebCardPage extends ThorPage<void> {
  /// The one instance the build shares between requests.
  const WebCardPage();

  /// `/web/card`.
  @override
  PageMeta meta(PageState<void> state) => const PageMeta(title: 'Tarjeta (tw)');

  /// Two cards: one in a narrow column, one wide.
  @override
  Widget build(BuildContext context, PageState<void> state) => FlexBox(
    direction: FlexDirection.column,
    gap: 24.px,
    children: [
      const WebTitle(
        'Tarjeta',
        description: 'Menos de 440 px de ancho propio: apilada. Más: en fila.',
      ),
      Box(
        style: tw('grid grid-cols-1 gap-4 medium:grid-cols-3'),
        children: [WebProductCard(products[0]), WebProductCard(products[3])],
      ),
    ],
  );
}
