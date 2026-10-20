# Theme and styles

Define colors, typography and component themes once in `ThemeData`, and vary
any value by width, state or dark mode with `.when()`.

:::flutter Flutter: `ThemeData`, `ColorScheme`, `TextTheme` · Thor: the same ones, plus variants with `.when()`

## Theme colors

Widgets read the theme with `ThemeColor` or `Theme.of(context)`, without
repeating any color: when the theme changes, everything that reads it
updates.

:::bench bench-theme-colors
:::

:::flutter
@flutter
```dart no-check
final theme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
  textTheme: textTheme,
);

MaterialApp(theme: theme, darkTheme: darkTheme, home: page);
```
@thor
```dart
final theme = ThemeData(
  colorScheme: const ColorScheme.light(primary: Color(0xFF0F766E)),
  textTheme: TextTheme(),
);

ThorApp(theme: theme, darkTheme: darkTheme, child: page);
```
:::

| Part of `ThemeData` | Read with |
|---|---|
| `colorScheme` | `ThemeColor.primary` or `Theme.of(context).colorScheme.primary` |
| `tokens`, `colorTokens` | the token itself (`AppColors.band`) or `ThemeColor.token('brand')` |
| `textTheme` | `ThemeText.headlineLarge`, `ThemeText.bodyMedium`… |
| `breakpoints` | every `.when(medium: …)` and `ResponsiveVisibility` |
| `extensions` | `Theme.of(context).extension<BrandShape>()` |
| `fonts`, `fontFamily` | every `Text` in the app |
| `scaffoldBackgroundColor` | the page's `body` and every `Scaffold` (without it, `surface`) |
| `scrollbarTheme` | every scrollbar: `ScrollbarThemeData(thickness: WidgetStatePropertyAll(6), thumbColor: …)` |

> **Difference from Flutter:** `ColorScheme.fromSeed` does not exist. Write
> the roles that change (`ColorScheme.light(primary: …)`); the rest take the
> Material 3 values.

### Color roles

Each `colorScheme` role has one value in the light theme and another in the
dark one. These are the most used:

| Role | Use |
|---|---|
| `primary` | main actions, links and focus |
| `onPrimary` | text and icons on `primary` |
| `surface` | the page background |
| `onSurface` | the page text |
| `surfaceContainer` | cards and panels |
| `error` | errors and destructive actions |

The [API reference](../../api/thor_ui.md#estilos) lists the rest of the
`ColorScheme` roles.

### Custom colors

Declare each brand color with `ColorToken`: it is a `const` `Color` that
carries its light value and its dark value.

```dart
abstract final class AppColors {
  static const band = ColorToken('band',
      light: Color(0xFFF7F6F2), dark: Color(0xFF22252A));
  static const muted = ColorToken('muted',
      light: Color(0xFF697077), dark: Color(0xFFA6ACB3));
  static const values = [band, muted];
}

final light = ThemeData(tokens: AppColors.values);
final dark = ThemeData(
    colorScheme: const ColorScheme.dark(), tokens: AppColors.values);

Container(color: AppColors.band)       // follows the theme
```

Two tokens with the same name are error
[THOR-R021](../../errores/en/THOR-R021.md). For scales from 50 to 950 there is
`ColorScale`, and `Colors.blue.shade700` works as in Flutter.

## Dark mode

With `darkTheme` and `themeMode: ThemeMode.system` (the default), the page
follows the system preference. `ThemeToggle` adds the control to switch it:

```dart
ThemeToggle(light: Icon(Icons.light_mode), dark: Icon(Icons.dark_mode))
```

:::example theme-follows-switch
:::

The user's choice is saved in the browser and applied before the page is
shown: there is no flash on reload. It requires 2024 browsers (Chrome 123,
Safari 17.5, Firefox 120).

> **Important:** A literal `Color` is the same in both themes. For a color to
> follow dark mode, read it from the theme (`ThemeColor.primary`) or declare a
> `ColorToken`.

### Reading the theme in code

`Theme.of(context).colorScheme` returns colors that follow dark mode, also
with `withValues(alpha:)`.

```dart
final scheme = Theme.of(context).colorScheme;
Container(
  color: scheme.primary.withValues(alpha: 0.15),
  child: Text('x', style: TextStyle(color: scheme.onSurface)),
)
```

| Expression | Result |
|---|---|
| `scheme.primary` in a color, border or text | follows dark mode |
| `scheme.primary.withValues(alpha: .15)` | follows dark mode |
| `.value`, `.red`, `.opacity`, `Color.alphaBlend` (also on `Color.css` and `.when()` colors; `hasChannels` tells) | error [THOR-R023](../../errores/en/THOR-R023.md) |
| `scheme.primary.fallback!.value` | the color of a single mode |
| `scheme.brightness` | the theme's |

> **Difference from Flutter:** The server renders the page once and does not
> know the user's mode, so `Theme.of` does not return a fixed color. To choose
> between two colors use `.when(dark: …)`.

## Typography

A `TextStyle` from the `TextTheme` keeps its role: if you change one value
(`ThemeText.labelLarge.copyWith(color: ThemeColor.primary)`), the rest follows
the theme.

:::bench bench-text-style
:::

To make a role grow on wide screens, give the whole `TextTheme` a variant:

```dart
textTheme: textTheme.when(
  medium: textTheme.copyWith(displayLarge: const TextStyle(fontSize: 60)),
),
```

For a size that grows with the window, `TextStyle` also accepts a `Length`
([Units](advanced-styles.md#units)):

```dart
const TextStyle(
  fontSize: 40,                                   // the number Dart reads
  fontSizeLength: Length.clamp(Length.px(40), Length.vw(5), Length.px(72)),
  letterSpacingLength: Length.em(-0.02),
)
```

### Fonts

Each `FontFace` is a font file of the app: the equivalent of the `fonts:`
section in Flutter's `pubspec.yaml`.

```dart
fonts: [
  // A variable font: every weight in one file.
  FontFace('Inter', url: '/fonts/inter.woff2',
      weight: FontWeight.w100, maxWeight: FontWeight.w900, preload: true),
  // One file per weight or style.
  FontFace('Mono', url: '/fonts/mono-400.woff2'),
  FontFace('Mono', url: '/fonts/mono-500.woff2', weight: FontWeight.w500),
],
```

| Option | Effect |
|---|---|
| `display:` | what shows while it loads; `FontDisplay.swap` (the default) never hides the text |
| `preload: true` | downloads the file earlier; use it only for the first screen's font |
| `thor fonts subset` | trims the font to the characters the app uses |
| `thor fonts metrics` | measures a `FontFallback` with the same proportions, so the text doesn't jump |

The files go in the app's `web/`. If they come from a package, the package
declares them and [`thor dev`](cli.md) copies them.

## Component themes

What repeats on every page (cards, buttons, chips) goes once in the
`ThemeData`, as in Flutter.

```dart
ThemeData(
  cardTheme: CardThemeData(elevation: 0, shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16), side: BorderSide(color: line))),
  chipTheme: ChipThemeData(shape: StadiumBorder()),
  filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(ThemeColor.primary))),
)
```

:::example component-themes
:::

Flutter's themes exist for cards, chips, buttons, fields, dividers, dialogs,
bars, lists, snackbars, menus, tabs and selection controls: `cardTheme`,
`chipTheme`, `filledButtonTheme`, `iconButtonTheme`, `inputDecorationTheme`,
`dialogTheme`, `appBarTheme`, `listTileTheme`, `snackBarTheme`,
`tabBarTheme`, `checkboxTheme`, `switchTheme` and the rest. The widget's
parameter wins, then the theme, and finally the default value.

Each `XThemeData` carries the Flutter fields the browser can apply; each
class's documentation lists the missing ones. `Theme.provide(data:)` changes
the theme of a subtree, and a `ThemeExtension` holds your brand's own values.

## Variants with `.when()`

Whatever changes by width, state or theme is a value with `.when()`. The
variant only carries what changes; the rest is inherited from the base value.

```dart
Container(padding: const EdgeInsets.all(24).when(medium: EdgeInsets.all(32)))

BoxDecoration(color: ThemeColor.surface.when(hover: ThemeColor.surfaceContainer))

Text('Pricing', style: ThemeText.titleMedium.when(medium: ThemeText.titleLarge))

Grid(layout: GridLayout(columns: 1, gap: 16).when(expanded: GridLayout(columns: 3, gap: 32)))
```

:::example variants
:::

| Variant | Applies |
|---|---|
| `medium`, `expanded`, `large`, `extraLarge` | from 600, 840, 1200 and 1600 px of window width (the Material 3 size classes) |
| `dark` | with the dark theme |
| `hover`, `focused`, `pressed` | on hover, with keyboard focus, while pressed |
| `open` | while the nearest `<details>` is open (an `ExpansionTile`: its header and its content); a nested one decides for what it holds |
| `groupHover` | on hover over the nearest `HoverGroup` |
| `groupHovers: {'card': …}` | the same, for the nearest `HoverGroup(name: 'card')` |
| `container: {400: …}` | when the nearest `LayoutScope` measures at least 400 px |

These accept `.when()`: `EdgeInsets`, `BorderRadius`, `BoxConstraints`,
`BoxDecoration`, `TextStyle`, `Color`, `TextTheme`, `GridLayout`,
`FlexLayout`, `CarouselLayout` and `StyleProps`. A bare number (`double`,
`int`) does not take variants: it goes in a `StyleProps` inside `Styled`
([Advanced styles](advanced-styles.md)). Widths are changed with
`ThemeData(breakpoints: Breakpoints(medium: 640))`, and a variant can have its
own: `color.when(hover: hover.when(medium: other))`.

Arithmetic (`padding * 2`, `padding + extra`) and `copyWith` on one of these
values apply to the base and to every variant, so the variants are kept.

> **Note:** `hover` and `groupHover` only apply with a pointer that can hover
> (mouse, trackpad). On a phone, repeat the effect in `pressed:`.

### Group hover

`HoverGroup` makes its descendants react to hovering over the whole group,
not over each one.

```dart
HoverGroup(
  child: Card(
    child: Column(children: [
      Styled(
        style: StyleProps().when(groupHover: StyleProps(scale: 1.05)),
        duration: const Duration(milliseconds: 200),
        child: Image.network(photo),
      ),
      Text(name),
    ]),
  ),
)
```

:::example hover-group
:::

With nested groups, `HoverGroup(name: 'card')` names each one and
`groupHovers: {'card': …}` picks which one the variant responds to.

### By container width

A breakpoint measures the window; `container:` measures the box of the
nearest `LayoutScope`. The same card works in a narrow column and in a wide
one: it is Flutter's `LayoutBuilder`, with no code in the browser.

:::example responsive-card
:::

## Show or hide

`ResponsiveVisibility` shows or hides a widget by size class, and
`ResponsiveLayout` picks one of three.

```dart
ResponsiveVisibility(hiddenFrom: WindowSizeClass.medium, child: MobileMenu())
ResponsiveVisibility(visibleFrom: WindowSizeClass.medium, child: DesktopMenu())
ResponsiveLayout(mobile: Compact(), tablet: Medium(), desktop: Wide())
```

## Radius and spacing

A value that changes in the browser, such as a state field driven by a
`Slider`, is written as a `BoundLength`: the field followed by `.px`.

:::bench bench-card-style
:::

Widgets take it in their `Length` variants: `EdgeInsetsGeometry.allLength`
(also `symmetricLength` and `onlyLength`), `BorderRadius.circularLength`,
`SizedBox(widthLength:)` and `Positioned(leftLength:)`.

```dart
Container(
  padding: EdgeInsetsGeometry.allLength(card.padding.px),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circularLength(card.radius.px),
  ),
)

SizedBox(widthLength: card.width.px, child: content)
Positioned(leftLength: drag.x.px, top: 0, child: handle)
```

> **Important:** An `EdgeInsetsGeometry` is not an `EdgeInsets`: it has no
> `left` or `horizontal`. Parameters that require `EdgeInsets`
> (`TextField.contentPadding`, `Dialog.insetPadding`) don't accept a `Length`.

`EdgeInsetsDirectional(start:, end:)`, `BorderRadiusDirectional` and
`AlignmentDirectional` follow the text direction, as in Flutter.

## Next steps

:::cards
- [Advanced styles](advanced-styles.md) — `StyleProps`, units and HTML without widgets
- [Animations](animations.md) — transitions, curves and reduced motion
- [Layout](layout.md) — `Row`, `Column`, `Grid` and spacing
:::
