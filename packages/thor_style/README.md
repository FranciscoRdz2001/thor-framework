# thor_style

Flutter's value types that compile to CSS. Pure Dart, no DOM dependency: the
same code runs on the server, in the browser and in VM tests.

| Type | CSS |
|---|---|
| `Color`, `Colors` | `#rrggbb` / `rgba()` |
| `EdgeInsets` | `padding` / `margin` |
| `BorderRadius`, `Border`, `BorderSide`, `BoxShadow`, `BoxDecoration`, `Gradient` | `border-radius`, `border`, `box-shadow`, `background` |
| `Alignment`, `AlignmentDirectional` | flex alignment or fractional position |
| `TextStyle`, `FontWeight`, `TextAlign`, `TextDecoration` | font and text properties |
| `Curve`, `Curves`, `Cubic`, `Interval`, `Threshold` | `cubic-bezier()`, `linear()` sampled, `steps` |
| `IconData` | SVG sprite symbol |
| `MainAxisAlignment`, `CrossAxisAlignment`, `Axis`, `BoxFit`… | flex / object-fit values |

```dart
const d = BoxDecoration(
  color: Color(0xFFF7F8FA),
  borderRadius: BorderRadius.all(Radius.circular(16)),
);
d.toCss(); // {background-color: #f7f8fa, border-radius: 16px}

Curves.easeOutBack.css;  // cubic-bezier(0.175, 0.885, 0.32, 1.275)
Curves.bounceOut.css;    // linear(0, 0.0119 2.5%, …)
Curves.bounceOut.transform(0.5); // same value Flutter computes
```

Every value is sanitized before it reaches a stylesheet (`cssSafeValue`).

API reference: `thor_ui` re-exports all of it ([docs/api/en/thor_ui.md](../../docs/api/en/thor_ui.md): layout, text, styles and animation pages).

```bash
dart test
```
