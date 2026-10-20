# Buttons

Material buttons with Flutter's API: `onPressed` takes a ViewModel method (`ThorState`) and, without `onPressed`, the button is disabled.

## FilledButton

:::flutter Flutter: `FilledButton` · Thor: the same, and `href:` turns it into a link

:::bench cat-filled-button
:::

The main action of a screen. `FilledButton.tonal` has less emphasis.

| Parameter | What it does |
| --- | --- |
| `onPressed` | the method that runs when it's pressed; `null` disables it |
| `child` | a `Text`, or a `Row` with an icon and text |
| `style` | colors, size and shape ([ButtonStyle](#buttonstyle)) |
| `href` | turns it into a link to another page |
| `buttonType` | `ButtonType.submit` submits the enclosing `Form`; `ButtonType.button` submits nothing |

## ElevatedButton

:::bench cat-elevated-button
:::

A button raised above the surface, with emphasis between `FilledButton` and `OutlinedButton`. It takes the same parameters as `FilledButton`.

## Buttons with an icon

:::bench cat-icon-labels
:::

The `.icon` constructors take `icon` and `label` and are still a single button. `.tonal` and `.tonalIcon` exist only on `FilledButton`.

> **Note:** The spacing next to the icon is Material 3's and flips in right-to-left languages.

## OutlinedButton

:::bench cat-outlined-button
:::

A secondary action, with a border and no fill. With `href` it is a link and navigates with no state and no JavaScript.

## TextButton

:::bench cat-text-button
:::

The lowest-emphasis action, for dialogs, cards and bars. It takes the same parameters as `FilledButton`.

## IconButton

:::bench cat-icon-button
:::

A 48 × 48 button with an icon. `tooltip` is its accessible name and the text that appears on hover.

| Parameter | What it does |
| --- | --- |
| `icon` | the `Icon` it shows |
| `tooltip` | the accessible name and the bubble |
| `href` | turns it into a link; requires `tooltip` |
| `color`, `iconSize` | the icon's color and size |
| `isSelected`, `selectedIcon` | a toggle button, with its selected icon |
| `visualDensity`, `padding`, `constraints` | the size of the box |

> **Important:** An icon is decorative: an `IconButton` without `tooltip` is announced only as "button". The analyzer flags it with `icon_button_without_name`.

### Variants

:::bench cat-icon-button-variants
:::

`IconButton.filled`, `.filledTonal` and `.outlined` are the Material 3 variants. Icon names are in [Content](components-content.md#icon).

## FloatingActionButton

:::bench cat-fab
:::

The main action of the screen. Inside `Scaffold(floatingActionButton:)` it stays fixed in the corner.

| Parameter | What it does |
| --- | --- |
| `child` | the icon; with `FloatingActionButton.extended`, `icon` and `label` |
| `tooltip` | the accessible name of an icon-only button |
| `backgroundColor`, `foregroundColor` | replace the theme colors |
| `href` | turns it into a link; requires `tooltip` |

> **Difference from Flutter:** A `label` wider than the screen wraps onto several lines instead of overflowing.

## ButtonStyle

:::bench cat-button-style
:::

Every button takes `style`. `FilledButton.styleFrom`, `OutlinedButton.styleFrom` and `TextButton.styleFrom` build it from simple values, as in Flutter; `ButtonStyle(animationDuration:)` animates the change between states.

| `styleFrom` parameter | What it changes |
| --- | --- |
| `backgroundColor`, `foregroundColor` | background and text |
| `overlayColor` | the background on hover |
| `padding`, `minimumSize` | the size |
| `shape`, `side` | the shape (`RoundedRectangleBorder`, `StadiumBorder`, `CircleBorder`) and the border |
| `textStyle` | the typography |
| `disabledBackgroundColor` | the background without `onPressed` |

### Per-state style

`ButtonStyle` fields are `WidgetStateProperty`, as in Flutter: a value can depend on `hovered`, `focused`, `pressed`, `selected` or `disabled`. The server compiles each state; the browser computes nothing.

```dart
FilledButton(
  onPressed: save,
  style: ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return Colors.grey;
      if (states.contains(WidgetState.hovered)) return Colors.teal;
      return null; // the variant's color
    }),
  ),
  child: const Text('Save'),
)
```

> **Difference from Flutter:** Only `backgroundColor`, `foregroundColor`, `side` and `overlayColor` change per state. A value for a combination of states (`hovered` and `focused` at once) is resolved with each state separately.

`disabled` covers a button without `onPressed` (`disabled`) and one with `aria-disabled="true"`, which stays focusable: both look disabled and neither gets the hover.
