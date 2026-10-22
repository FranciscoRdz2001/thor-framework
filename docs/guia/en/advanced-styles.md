# Advanced styles

Apply what no widget expresses: fixed positioning, inner scrolling,
viewport units, your components' classes, and HTML that doesn't come from
widgets.

## What to use, in order

Start at the top and go down a level only when the previous one isn't enough.

:::ladder
### Widget props
Almost everything: `Container(padding:, decoration:)`, `Text(style:)`,
`Row(spacing:)`. It's what you would write in Flutter.
### Wrappers
To decorate without adding elements: `Padding`, `Opacity`, `Transform`,
`BackdropFilter` (blurs what is behind), `ClipRRect`, `Link`. They merge into their child's element.
### Variants with `.when()`
What changes with width, state, theme or container size:
`EdgeInsets.all(16).when(medium: EdgeInsets.all(32))`. See
[Theme and styles](theme-and-styles.md#variants-with-when).
### `StyleProps` in `Styled`
What no widget expresses: fixed positioning, inner scrolling,
units like `100.dvh`, and numbers that change with `.when()`. See
[StyleProps in Styled](#styleprops-in-styled).
### Your own stylesheets
Your components' classes and the states no widget expresses. See
[Your own stylesheets](#your-own-stylesheets).
### `Styled(descendants:)`
HTML that no widget builds, such as markdown or content from a CMS.
See [HTML without widgets](#html-without-widgets).
:::

Every level is typed: the analyzer catches a typo, the editor
autocompletes, and values that come from your data are escaped before they
reach the page.

## `StyleProps` in `Styled`

`Styled(style:)` applies a `StyleProps` to its child's element, without adding
another one. In the list, each letter sticks to the top (`BoxPosition.sticky`)
until the next one pushes it away.

```dart
Styled(
  style: StyleProps(
    position: BoxPosition.sticky(top: 0.px),
    zIndex: 20,
    maxHeight: 100.dvh - 72.px,
    overflowY: Overflow.auto,
  ),
  child: TableOfContents(),
)
```

:::example sticky-list
:::

| Prop | Type | Effect |
|---|---|---|
| `position` | `BoxPosition` | `sticky`, `fixed`, `absolute` or `relative` |
| `overflowX`, `overflowY` | `Overflow` | inner scrolling when the content doesn't fit |
| `minWidth`, `maxWidth`, `minHeight`, `maxHeight` | `Length` | limits in any unit |
| `zIndex` | `int` | order among overlapping elements |
| `backdropFilter` | `ImageFilter` | filters what is behind (`ImageFilter.blur(sigmaX: 8)`; also `saturate`, `brightness`, `contrast`, `grayscale`, `invert`, `sepia`, `hueRotate`, `opacity`, chained with `ImageFilter.compose`); or `BackdropFilter` |
| `scrollbarWidth`, `scrollbarThumbColor`, `scrollbarTrackColor` | `ScrollbarWidth`, `Color` | the element's scrollbar |
| `opacity`, `scale`, `offset`, `turns` | numbers | only with `.when()`; a fixed value goes in `Opacity` or `Transform` |
| `textTransform`, `textOverflow`, `textUnderlineOffset`, `lineClamp` | `TextTransform`, `TextOverflow`, `Length`, `int` | text of HTML no widget builds; for a `Text`, `maxLines:` and `overflow:` |
| `inset`, `scrollPadding` | `Length`, `EdgeInsetsGeometry` | `inset: 0.px` covers the box with a `position`; `scrollPadding` keeps room when scrolling to a child |
| `backgroundClip` | `BackgroundClip` | `BackgroundClip.text` shows the background through the letters (with transparent text) |
| `aspectRatio` | `double` | a fraction comes out as a fraction: `4 / 3` writes `aspect-ratio: 4 / 3` |

`BoxPosition` takes its distances as `Length`:
`BoxPosition.fixed(bottom: 16.px, right: 16.px)`. Inside a `Stack`, use
`Positioned` as in Flutter.

`Styled` doesn't replace widgets. What a widget already expresses (`padding`,
`decoration`, `color`, a fixed number) goes in that widget; the
`widget_props_in_styled` lint flags it.

```dart
// WRONG (widget_props_in_styled): padding belongs to a widget
Styled(style: StyleProps(padding: EdgeInsets.all(12)), child: child)

// RIGHT
Padding(padding: EdgeInsets.all(12), child: child)
```

A number that changes with `.when()` does go in `Styled`, and its `duration:`
turns the change into a transition:

:::example hover-effects
:::

The [API reference](../../api/thor_ui.md#estilos) lists the
rest of the `StyleProps` props.

### Per-element values, mixes and gradients

A color or a size that comes from data (a store's accent) is not written with
`raw:`. `ElementVariables` puts it as a CSS variable on the element, once per
distinct value, and the stylesheet reads it:

```dart no-check
const accent = CssVariable<Color>('--accent');

ElementVariables(
  {accent: Color(store.primaryColor)},
  child: const StoreCard(), // its rules read Color.variable(accent)
)
```

`Color.lerp(a, b, t)` mixes two colors (with a theme color the browser does a
`color-mix`), `color.withOpacity(.22)` makes it translucent, and
`RadialGradient.ellipse` takes the ellipse and the point as CSS does:

```dart
BoxDecoration(
  gradient: RadialGradient.ellipse(
    center: Alignment(-0.48, -0.68), // 26% 16%
    radiusX: 1.2,
    radiusY: 1,
    colors: [accent.withOpacity(.22), Colors.transparent],
  ),
)
```

A negative margin (`StyleProps(margin: EdgeInsets.symmetric(vertical: -12))`)
goes in `Styled`: `Container(margin:)` refuses it, as Flutter does. In a
stylesheet, `css.container('(min-width: 36rem)', […])` writes an
`@container`.

## Units

Flutter props are measured in logical pixels (`double`): `EdgeInsets.all(16)`
is 16 pixels. For things measured differently, such as the window's height
or a fraction of the parent, there is `Length`.

```dart
16.px            // 16 logical pixels
50.percent       // half of the parent
1.5.em           // 1.5 × the element's font size
1.rem            // 1 × the page's font size
60.ch            // about 60 characters: a good reading width
100.vw           // the window's width
100.dvh          // the window's height now (follows a phone's bars)
```

:::example units
:::

Operations combine units, and limits are written with `min`, `max`
and `clamp`:

```dart
100.dvh - 48.px                          // the window minus a bar
(100.vw - 2.rem) / 3                     // a third of the window, minus margins
Length.min([100.percent, 720.px])        // the parent, at most 720 px
Length.clamp(1.rem, 2.vw + 1.rem, 3.rem) // grows with the window, with limits
card.gap.px * 2                          // follows a state field
```

`Length.px(16)`, `Length.min`, `Length.max` and `Length.clamp` are `const`;
`16.px` is the short form.

An element with `containerType: ContainerType.size` is a measuring box:
inside it, `100.cqw` and `100.cqh` are its width and height (also `cqi`,
`cqb`, `cqmin`, `cqmax`). That box doesn't grow with its content: give it
a height of its own (`Expanded`, `heightLength`). `Ratio.of(a, b)` is `a`
divided by `b` (how many times `b` fits in `a`), a plain number the browser
computes; with `StyleProps(scaleRatio:)` it scales a box to fit its
container, with no JS and no breakpoints:

```dart
Expanded(
  child: Styled(
    style: const StyleProps(containerType: ContainerType.size),
    child: SizedBox.expand( // the stage
      child: Styled(
        style: StyleProps(
          transformOrigin: Alignment.topLeft,
          scaleRatio: Ratio.min([
            Ratio.value(1), // never above 100%
            Ratio.of(100.cqh, 844.px),
            Ratio.of(100.cqw, 390.px),
          ]),
        ),
        child: device, // 390 x 844
      ),
    ),
  ),
)
```

`Styled` melts into its child's element, so the stage is a widget with its
own element (here `SizedBox.expand`): `cq` units measure an ancestor, never
the element itself.

> **Difference from Flutter:** Flutter computes layout in Dart and doesn't need
> units. On the web the browser computes it, and sometimes the value is "the
> window's height" or "half of the parent". `Length` shows up only where Flutter
> has no equivalent.

## Your own stylesheets

For your components' classes, write rules with `css()` and give them values
with `.props()`, the same `StyleProps` as above. A component's stylesheet lives
with it, in `css.components`:

```dart
import 'package:thor_ui/html.dart' show css;
import 'package:thor_ui/thor_ui.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key});

  static final styles = css.components([
    css('.product-card', [
      css('&').props(const StyleProps(padding: EdgeInsets.all(12))),
      css('&:hover').props(const StyleProps(offset: Offset(0, -2))),
    ]),
  ]);

  @override
  Widget build(BuildContext context) =>
      Styled(classes: const ['product-card'], child: const Text('Cold brew'));
}
```

`Styled(classes:)` adds the class to the child's element. A stylesheet for the
whole app is passed once in `ThorApp.router(styles:)`, and one used only by the
routes of a group goes in `Group(styles:)`, so other pages don't download it:

```dart
// lib/styles.dart
import 'package:thor_ui/html.dart' show css;
import 'package:thor_ui/thor_ui.dart';

final List<StyleRule> appStyles = [
  css('.card', [
    css('&').props(StyleProps(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
    )),
    css('&:hover').props(const StyleProps(offset: Offset(0, -2))),
  ]),
  WindowSizeClass.medium.media([
    css('.card').props(const StyleProps(padding: EdgeInsets.all(16))),
  ]),
];
```

A rule varies with its selector and with `WindowSizeClass.media`; `.when()` is
for widgets.

A width that is no size class goes in a sheet with `css.minWidth(920, [...])`
or `css.maxWidth(919.98, [...])`. A sheet is one text for every request, so
`WindowSizeClass.media` uses the default widths unless it is given the app's
own: keep them in one `const` and pass it to the theme and to the sheet.

```dart no-check
const siteBreakpoints = Breakpoints(medium: 640, expanded: 768, large: 1024);
// ThemeData(breakpoints: siteBreakpoints)
WindowSizeClass.medium.media(breakpoints: siteBreakpoints, [...]);
css.minWidth(920, [css('.card').props(const StyleProps(padding: EdgeInsets.all(20)))]);
```

Widgets (`.when(...)`) see the theme's four size classes; for any other width
of their own box use `.when(container: {920: …})`.

> **Important:** Rules in your stylesheets always win over widget styles.
> Use them for your own classes, not to change every element of a type, and
> don't put a transition on an element that an `Animated*` already animates:
> it replaces it.

A component's stylesheet (`css.components`) sits below the elements' own
props: `.row:hover .name` does not beat the `fontWeight` of the `Text` inside.
For a descendant that changes with an ancestor's state (`:hover`,
`:has([aria-current])`, `[open]`), use `css.states`, which comes after them:

```dart
import 'package:thor_ui/html.dart' show css;
import 'package:thor_ui/thor_ui.dart';

final styles = css.states([
  css('.tree-row:has(a[aria-current]) .tree-name')
      .props(const StyleProps(textStyle: TextStyle(fontWeight: FontWeight.w600))),
]);
```

A rule nested in another is a descendant: inside `css('.mb', [...])`,
`css('.row')` writes `.mb .row` (specificity 0,2,0). A breakpoint for it
written *outside* the parent (`css.minWidth(480, [css('.row')...])`) writes
`.row` (0,1,0) and loses. Put the media query inside the same parent, so the
selector is the same and the later rule wins at its width:

```dart no-check
css('.mb', [
  css('.row').props(const StyleProps(padding: EdgeInsets.symmetric(vertical: 8))),
  css.minWidth(480, [
    css('.row').props(const StyleProps(padding: EdgeInsets.symmetric(vertical: 10))),
  ]),
  WindowSizeClass.large.media([
    css('.row').props(const StyleProps(padding: EdgeInsets.symmetric(vertical: 12))),
  ]),
]),
```

Two classes on one element, one from a shared reset (a `.ctl` that clears
`padding`) and one from your component (`.ctl.own` or `.own` with its
`padding`), compete by specificity and then by *order*. In the same layer
(`css.components`) with the same specificity, the rule listed later in
`styles:` wins, so list the reset before the components that use it. A rule
listed twice is written once, in its first place. A widget's own props
(`thor.props`) are above `css.components`; unlayered rules are above all.
If the order can't be arranged, make the selector heavier
(`.ctl.own`) instead of dropping the reset class.

### Stylesheets by level

Each stylesheet belongs to a level (theme, components, app, module or page);
[Build and deploy](build-and-deploy.md) explains how to share them across pages
so the browser caches them.

## HTML without widgets

Rendered markdown or content from a CMS doesn't come from widgets, so it
has no props. `Styled(descendants:)` styles it with types, scoped to the
element that wraps it.

```dart
Styled(
  descendants: {
    '> * + *': const StyleProps(margin: EdgeInsets.only(top: 14)),
    'h2': const StyleProps(
      textStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      margin: EdgeInsets.only(top: 36),
    ),
    'a': const StyleProps(
      textStyle: TextStyle(decoration: TextDecoration.underline),
    ),
    'img': StyleProps(maxWidth: 100.percent),
  },
  child: DefaultTextStyle(
    style: const TextStyle(fontSize: 16, height: 1.7),
    child: Container(child: html.RawText(markup)),
  ),
)
```

:::example descendants
:::

Each key is a selector inside the element (`h2`, `a:hover`, `pre code`) and
each value is a `StyleProps` without variants. The container's text still
goes through its widget (`DefaultTextStyle`).

No `raw:` for the common cases: `EdgeInsetsGeometry.sides` sets only the
sides it is given (the browser's others stay), and a `Length` in `em`
follows the text around it.

```dart
Styled(
  descendants: {
    '> :first-child': StyleProps(
      margin: EdgeInsetsGeometry.sides(top: Length.zero),
    ),
    ':not(pre) > code': StyleProps(
      textStyle: TextStyle(fontSizeLength: 0.9.em, heightLength: 1.25.em),
    ),
    'h2': StyleProps(textStyle: TextStyle(fontWeight: FontWeight(650))),
    'img.right': StyleProps(float: BoxFloat.right),
  },
  child: Container(child: html.RawText(markup)),
)
```

`Styled(descendants:)` styles only the markup no widget built. A Thor element
inside it (a `Text`, a `Semantics(headingLevel:)`, a `Container`) is a limit:
the rule skips it and what it holds, because that element already has its own
class, and a rule from outside would fight it. To restyle the headings or
links that widgets draw, give the elements their style where they are built
(`Styled(style:)`, `TextStyle`), or write a rule in your own stylesheet, which
wins over the widgets' styles:

```dart
import 'package:thor_ui/html.dart' show css;
import 'package:thor_ui/thor_ui.dart';

final articleStyles = [
  css('.article', [
    css('h1, h2, h3').props(
      const StyleProps(textStyle: TextStyle(fontFamily: 'Gabarito')),
    ),
  ]),
];
```

## Margins and inline boxes

A `Column` or `Row` is a flex box, as in Flutter: the bottom margin of one child
and the top margin of the next add up, they don't collapse as in HTML block
content. Space things the Flutter way, with `spacing:`, `SizedBox` or
`Padding`, and keep one value per gap:

```dart
Column(
  spacing: 20,
  children: [Text('Title'), Text('Subtitle'), Grid()],
)
```

Content that must flow like HTML, because it collapses margins or puts a small
box in a line of text (a pill next to a heading), opts in with
`display: Display.block` on its container. The children are then block or
inline boxes: give one `Display.inlineFlex` to keep it on the line.

```dart
Styled(
  style: const StyleProps(display: Display.block),
  child: Column(
    children: [
      Styled(
        style: const StyleProps(display: Display.inlineFlex),
        child: Row(children: [Text('New')]),
      ),
      Text('Title'),
    ],
  ),
)
```

> **Difference from Flutter:** Flutter has no margin collapsing and no inline
> boxes (`WidgetSpan` is the closest, and Thor's `Text.rich` doesn't draw
> widgets in a line). `Display.block` is the way back to the browser's flow,
> for markup ported as it is.

## Gradient patterns

A gradient with `tile:` repeats as a tile: a dotted or striped background with
no images.

```dart
BoxDecoration(
  color: const Color(0xFFECEEF3),
  gradient: RadialGradient(
    colors: [const Color(0xFF4F46E5).withValues(alpha: 0.16), const Color(0x00000000)],
    stops: const [0.125, 0.125],      // a 1px dot (0.125 of the 8px radius)
    tile: const Size.square(16),      // every 16px
  ),
)
```

:::example patterns
:::

> **Difference from Flutter:** In Flutter a pattern like this is a `CustomPainter`;
> in Thor it's a repeated gradient that the browser paints.

## Next steps

:::cards
- [Theme and styles](theme-and-styles.md) — colors, typography and variants with `.when()`
- [Animations](animations.md) — transitions, curves and reduced motion
- [Build and deploy](build-and-deploy.md) — what the browser receives and how it's cached
:::
