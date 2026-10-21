# Accessibility

Thor generates native controls with keyboard and focus already handled; you
provide names, headings and contrast with `Semantics` and the theme.

:::flutter Flutter: `Semantics`, `ExcludeSemantics` · Thor: the same, and they choose the HTML element

## What Thor handles

Each widget reaches the browser as the equivalent native control, with its
keyboard handling. The Tab order is the order of the widget tree.

| Widget | Result | Keyboard |
|---|---|---|
| `FilledButton`, `IconButton`, `Link` | native button, or a link with `href:` | Tab, Enter and Space |
| `TextField`, `Checkbox`, `Switch`, `Slider` | native field | the control's keys |
| `AlertDialog`, `Drawer`, `ModalBottomSheet` | modal dialog | focus stays inside; Esc closes and focus returns to the button |
| `PopupMenuButton`, `MenuAnchor`, `Popover` | button and panel | Enter opens, Esc closes; arrows, Home and End |
| `ExpansionTile` | native disclosure section | Enter and Space |
| `TabBar` | tab group | arrows, Home and End; a single Tab stop |

## `Semantics`

`Semantics` draws nothing: it says what its child is, and Thor writes it as the
element or attribute a screen reader reads.

:::bench bench-semantics
:::

:::flutter
@flutter
```dart no-check
Semantics(
  header: true,
  child: Text('Orders', style: Theme.of(context).textTheme.headlineMedium),
)
```
@thor
```dart
Semantics(
  headingLevel: 2,      // web: <h2>, as in Flutter's headingLevel
  child: const Text('Orders'),
)
```
:::

Headings let users jump through the page: one `h1` per page and the rest in
order. `headingLevel` only sets the level; the size comes from the `TextStyle`.

> **Difference from Flutter:** `Semantics(header: true)` marks a heading with no
> level; use `headingLevel` for the real level. `obscured`,
> `explicitChildNodes` and `sortKey` are accepted with no effect, and `MergeSemantics`
> isn't needed: the screen reader already reads the whole element. There is no
> `SemanticsService.announce`: use `liveRegion` or `toast()`.

### Names, headings and regions

```dart
Column(children: [
  // A name for what has no text
  Semantics(
    label: 'Order shipped',
    image: true,
    child: const Icon(Icons.local_shipping),
  ),
  // Announced when its text changes, without moving the focus
  Semantics(liveRegion: true, child: Watch(cart.summary)),
  // The page's landmarks
  Semantics(role: SemanticsRole.navigation, child: const Nav()),
  Semantics(role: SemanticsRole.main, child: const Content()),
  // Decoration a screen reader should skip
  const ExcludeSemantics(child: Text('★ ★ ★')),
])
```

| You need | Write |
|---|---|
| a heading | `Semantics(headingLevel: 2, …)` |
| a name that isn't visible | `Semantics(label: '…', …)`; `tooltip:` on an `IconButton` |
| a notice read when it changes | `Semantics(liveRegion: true, …)` |
| a page region | `Semantics(role: SemanticsRole.navigation, …)`, also `main`, `complementary` (`<aside>`) and `region` (`<section>`) |
| a list of steps, or with bullets | `role: SemanticsRole.orderedList` (`<ol>`) or `list` (`<ul>`) with `listItem`; the indent and the marker, `StyleProps(listStyleType:, padding:)` |
| important or stressed text | `role: SemanticsRole.strong` (`<strong>`), `emphasis` (`<em>`) |
| a figure with a caption | `role: SemanticsRole.figure` and `figureCaption`; a named icon or chart, `role: SemanticsRole.image` (`role="img"`) |
| the current item of a set | `Semantics(current: SemanticsCurrent.page, …)` (`aria-current`), also `step`, `location` and `date` |
| a `data-*` or an `aria-*` without an extra element | `ElementAttributes(HtmlAttributes(data: {'track': 'cta'}), child: …)` |
| hide something decorative | `ExcludeSemantics`, or `Semantics(hidden: true, …)` |
| a link target (`#section`) | `Semantics(identifier: 'section', …)` |

### States and values

| You need | Write |
|---|---|
| a button or a switch | `Semantics(button: true, …)`, `Semantics(toggled: …, …)` |
| a value or a hint | `Semantics(value: '50%', hint: '…', …)` |
| a state | `checked:`, `expanded:`, `readOnly:`, `selected:` |
| a control without its own label | `textField: true`, `slider: true`, `container: true` |
| only its label counts | `Semantics(excludeSemantics: true, label: '…', …)` |
| what's behind isn't read (a modal) | `BlockSemantics(…)` |

## Focus and keyboard

The theme's `focusColor` colors the focus ring of everything the keyboard
reaches. The ring appears when navigating with the keyboard, not when clicking.

```dart
final light = ThemeData(
  colorScheme: const ColorScheme.light(),
  focusColor: const Color(0xFF3F3AB0),
);
```

A `GestureDetector(onTap:)` over something that isn't a control gets the button
role, focus and Enter or Space (`semanticButton: true`, by default). Even so,
prefer a `TextButton` or a `Link`: they bring state, focus and a name.

> **Important:** `semanticButton: false` removes the role and the focus. Use it only
> if the child is already a control.

### Keyboard shortcuts

Flutter's `Shortcuts`, `Actions` and `Intent`, with a view model method as the
action:

```dart
class SaveIntent extends Intent {
  const SaveIntent();
}

Shortcuts(
  shortcuts: const {
    SingleActivator(LogicalKeyboardKey.keyS, meta: true): SaveIntent(),
  },
  child: Actions(
    actions: {SaveIntent: CallbackAction<SaveIntent>(onInvoke: editor.save)},
    child: Focus(child: form),
  ),
)
// in EditorViewModel: void save(SaveIntent intent) { … }
```

The `Actions` nearest the focus wins. A text field keeps its letters and
arrows; ⌘S still reaches the shortcut. An intent carries no fields to the
browser: one class per meaning. `CallbackShortcuts(bindings: {activator:
editor.save})` is the short form.

A shortcut that takes over a key the browser uses on the selection (⌘C) can
step aside while the page has selected text:
`SingleActivator(LogicalKeyboardKey.keyC, meta: true, skipWithTextSelection:
true)`. Flutter has no such flag; its selection lives in the widgets, and the
browser's is one for the whole page.

`Focus(onKeyEvent: grid.onKey)` gets every key pressed inside, with Flutter's
signature (`KeyEventResult onKey(FocusNode node, KeyEvent event)`):
`KeyEventResult.handled` stops the key.

## Contrast and motion

Theme colors come in pairs (`primary` with `onPrimary`, `surface`
with `onSurface`): use them together and the text meets contrast. With your own
colors, text needs 4.5:1 against its background, and icons and the focus
ring, 3:1, in light and in dark.

```dart
Text(
  'Overdue',
  style: TextStyle(color: ThemeColor.onSurface),   // paired with ThemeColor.surface
)
```

`expectThemeContrast` from `thor_test` measures each theme pair and names the ones
that fail:

```dart
test('the app themes read at AA', () {
  expectThemeContrast(appTheme);
  expectThemeContrast(appDarkTheme);
});
```

A user who asks their system for more contrast gets `highContrastTheme:` (and
`highContrastDarkTheme:`); `ColorScheme.highContrastLight()` and
`highContrastDark()` are the starting point.

```dart
ThorApp(
  theme: appTheme,
  highContrastTheme: ThemeData(colorScheme: const ColorScheme.highContrastLight()),
  child: const Text('Home'),
)
```

With forced colors (Windows high contrast), the system replaces the
colors and removes shadows; Thor keeps an underline on the selected tab,
a border on menus and the native look of `Checkbox`, `Radio` and `Switch`.
With reduced motion, animations finish instantly and the carousel doesn't
advance on its own ([Animations](animations.md#reduced-motion)).

## How to test it

:::steps
### Go through the page with the keyboard
Tab, Shift + Tab, Enter, Space and Esc. Every control can be reached, the focus is
visible and a dialog returns focus to the button that opened it.

### Zoom to 200%
With the browser zoom at 200% and 390 px wide, nothing gets cut off or
overflows the screen.

### Test with a screen reader
VoiceOver on macOS or iOS, NVDA on Windows, TalkBack on Android. Each control
says what it is and what it's called, and headings let you jump between sections.

### Audit with Lighthouse
The Accessibility panel in Chrome DevTools and Lighthouse flag insufficient
contrast, missing names and out-of-order headings.
:::

## Next steps

:::cards
- [Dialogs and menus](dialogs-and-menus.md) — the focus and keyboard of each overlay
- [Theme and styles](theme-and-styles.md) — `ThemeData`, `focusColor` and paired colors
- [Languages](localization.md) — the language and direction of each page
:::
