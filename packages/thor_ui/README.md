# thor_ui

Flutter's widget API rendered to semantic HTML with generated CSS. Layout,
animation and controls are executed by the browser (flex, grid, transitions,
native form elements, `<dialog>`, popover), not re-implemented in Dart.

Guides: [widgets](../../docs/guia/en/widgets.md) ·
[layout](../../docs/guia/en/layout.md) ·
[theme and styles](../../docs/guia/en/theme-and-styles.md) ·
[animations](../../docs/guia/en/animations.md) ·
[components](../../docs/guia/en/components.md). API reference:
[docs/api/en/thor_ui.md](../../docs/api/en/thor_ui.md).

## Libraries

| Import | Use |
|---|---|
| `package:thor_ui/thor_ui.dart` | widgets (`Row`, `Column`, `Container`, `Text`, `Checkbox`, `AlertDialog`, `Animated*`…), `ThorApp`, `Theme`, `Watch`, `ThorState`/`state`, and everything from `thor_style` |
| `package:thor_ui/server.dart` | server entry: `initializeThor`, `runApp`, `Document` |
| `package:thor_ui/router.dart` | routes, pages, server data and form actions: `ThorRouter`, `ThorRoute`, `ThorPage`, `ThorLayout`, `ThorServer`, `RouteHandler` |
| `package:thor_ui/intl.dart` | numbers, money and dates in the page's locale (`LocaleFormat`) |
| `package:thor_ui/html.dart` | raw HTML elements (`div`, `span`, `script`…) for the rare case a widget is not enough |
| `package:thor_ui/testing.dart` | `initializeThorTests`, `renderHtml`, `renderDocument`, `headOfPage`, `bodyOfPage` |

## Minimal app

```dart
// lib/main.server.dart
import 'package:thor_ui/server.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  initializeThor(styles: const []);
  runApp(
    const Document(
      title: 'Hello',
      body: ThorApp(child: Center(child: Text('Hello, world'))),
    ),
  );
}
```

## Source map

| Folder | Contents |
|---|---|
| `lib/src/core/` | the render core: element tree, `BuildContext`, `Document`, HTML output |
| `lib/src/foundation/` | `thorElement` (the one place that emits an element), style registry and stylesheet, `ChildRules`, `LayoutHint`, parent data, responsive conditions, base styles |
| `lib/src/widgets/` | the widget catalog: basic/flex/stack/scroll/text, implicit animations, selection controls, text fields and forms, Material components, scaffold, theme |
| `lib/src/engine/` | `Watch`, the wiring of widget callbacks to `ThorState` methods, and the engine loader |
| `lib/src/router/` | route table, page actions, form schemas, lazily loaded pieces, locale switcher |
| `lib/src/animation/` | tweens and curves |

## Tests

```bash
dart test                                  # render tests (VM)
dart test -p chrome test/layer_order_web_test.dart # a browser test (any *_web_test.dart)
```
