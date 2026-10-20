# thor_studio

The thor design system. Its visual language: a near-black (or near-white)
page, big cards with 28 px corners, pill controls, hairline borders instead
of shadows, Inter and IBM Plex Mono, and short motion with a purpose. It is themed like Flutter's Material (a full Material 3 color
scheme and text theme, Flutter's component themes, and one `ThemeExtension<T>` per studio component) and built only
from public `thor_ui` widgets: no JavaScript, and it doubles as a test of
thor's public API.

## Wire it up

```dart
// One instance each (top-level finals): palette, text roles, component
// themes, fonts, selection and focus ring. There is no stylesheet to wire up.
final theme = StudioTheme.light(fontsPath: '/fonts');
final darkTheme = StudioTheme.dark(fontsPath: '/fonts');

ThorApp(
  theme: theme,
  darkTheme: darkTheme, // follows the system; `ThemeToggle` switches it
  child: StudioScaffold(
    appBar: StudioTopBar(brand: const StudioBrand(name: 'thor')),
    body: Column(children: [StudioPageHeader(title: 'Widgets'), ...]),
  ),
)
```

`StudioTheme.light` / `StudioTheme.dark` are the whole setup, like Flutter's
`theme:` / `darkTheme:`. Through `ThemeData` they publish every color as a
`--t-*` variable (`ThemeData(tokens:)`), map the Material roles onto the
palette, set the text roles, register the component themes as
`ThemeExtension`s, declare the fonts (`FontFace`: Inter as one variable
file, preloaded; IBM Plex Mono 400/500), the selection color and the focus
ring.

The fonts ship in `fonts/` (SIL Open Font License, `fonts/LICENSE-*`) and the
package declares them in its pubspec (`thor: public: fonts: fonts`), so the
`thor` CLI copies them, with their licenses, into the app's `web/fonts/`.
Without the CLI, copy the folder by hand and pass its URL path as
`fontsPath`.

## Reading the theme

```dart
final scheme = Theme.of(context).colorScheme;   // Material 3 roles: surface, onSurfaceVariant, primary…
final text = Theme.of(context).textTheme;       // display…label
final extra = StudioExtraColors.of(context);    // what Material lacks: hover, onSurfaceFaint, tones…
final code = StudioExtraTextStyles.of(context); // codeMedium, codeSmall
final accent = scheme.accent;                   // the accent is `tertiary`
final button = StudioButtonThemeData.of(context); // effective radius, height, pressScale…

// A parameter on the widget wins over the theme, the theme over the default,
// and the default is derived from the color scheme, so changing a role
// reaches every component:
final base = StudioTheme.light();
final theme = base.copyWith(colorScheme: myScheme);
// A component override sits next to the extras (`extensions:` replaces the list):
final themed = base.copyWith(extensions: [
  ...base.extensions,
  const StudioButtonThemeData(radius: 8),
]);
```

`web:` Flutter's `ColorScheme` is one palette per `ThemeData`. Here each role
is a `ColorToken` carrying its light and its dark value, published as a CSS
variable, so the same roles serve both themes and the browser switches them with
no rebuild. Sizes, radii and durations do not change with the theme, so the
component themes hold them as plain values. `ThemeExtension.lerp` is the
base step: a theme change is CSS.

### Roles

| Role | Use |
|---|---|
| `primary` / `onPrimary` | the action pill (white in dark, ink in light) |
| `primaryContainer` / `onPrimaryContainer` | raised, ink |
| `secondary` / `onSecondary` | soft ink, the page |
| `secondaryContainer` / `onSecondaryContainer` | the accent tint, ink (Material's selected state) |
| `tertiary`, `onTertiary`, `tertiaryContainer`, `onTertiaryContainer` | the accent blue (`scheme.accent`…) |
| `error`, `onError`, `errorContainer`, `onErrorContainer` | danger |
| `surface` / `onSurface` | the page, the ink |
| `onSurfaceVariant` | muted ink |
| `surfaceContainerLowest` | the canvas the cards float on |
| `surfaceContainerLow`, `surfaceContainer`, `surfaceContainerHigh` | the card |
| `surfaceContainerHighest` | raised rows, tracks |
| `outline` | the field line (3:1 on every surface) |
| `outlineVariant` | the hairline |
| `inverseSurface` / `onInverseSurface` | the ink, the card |

`StudioExtraColors`: `hover`, `onSurfaceSoft`, `onSurfaceFaint`, `lineStrong`,
`primaryHover`, `accentWash`, and one `StudioToneColors` per `StudioTone`
(`infoTone`, `okTone`, `warnTone`, `dangerTone`, `flutterTone`, `neutralTone`).

### Material widgets, themed

`StudioTheme` fills `filledButtonTheme`, `elevatedButtonTheme`,
`outlinedButtonTheme`, `textButtonTheme`, `iconButtonTheme`, `chipTheme`,
`cardTheme`, `expansionTileTheme`, `navigationRailTheme` and
`inputDecorationTheme`, so a plain `FilledButton`, `FilterChip`, `Card` or
`TextField` is a studio pill, card or field with no wrapper (see
`test/fixtures/apps/studio_gallery/lib/sections/material_section.dart`). It leaves
`switchTheme`, `checkboxTheme`, `radioTheme`, `sliderTheme` and `dividerTheme`
unset: those controls follow the roles.

## Tokens

One class per file, one folder per family (`lib/src/tokens/`).

| Family | Classes |
|---|---|
| Color | `StudioSurfaceColors` (app, canvas, panel, raised, hover), `StudioBorderColors` (line, lineStrong), `StudioContentColors` (ink, inkSoft, muted, faint), `StudioActionColors` (the primary pill), `StudioAccentColors` (the brand indigo: focus, the current item, links, selection, the hero glow), `StudioStatusColors`, `StudioShadowColors`, `StudioBenchColors`, `StudioSyntaxColors`; `StudioPalette.values` lists all of them; `StudioToneColors` groups a state's foreground, background and border |
| Typography | `StudioFontFamilies` (Inter, IBM Plex Mono), `StudioFontWeights` (400, 500, 600), `StudioTypeScale`, `StudioLetterSpacing`, `StudioLineHeights` |
| Spacing | `StudioSpacing` (4 px grid), `StudioLayout` (bar heights, panel width, sticky offsets) |
| Shape | `StudioRadii`: `card` 28, `control` 999 (pill), `inner` 12, `small` 6 |
| Elevation | `StudioShadows`: `none` (cards are flat), `soft`, `lift` |
| Motion | `StudioDurations` (fast 120, base 160, slow 200 ms), `StudioCurves` (`enter` = `cubic-bezier(.23, 1, .32, 1)`, `move` = `cubic-bezier(.77, 0, .175, 1)`), `StudioMotion` (`pressScale` .97, `pressScaleLarge` .985, `hoverLift` 2 px, `arrowNudge` 3 px, `enterRise` 8 px, `gripScale` 1.35), `StudioMotionStyles.themeFade` |

Key values (dark / light): page `#0B0D17` / `#F6F7FB`, cards `#12141F` /
`#FFFFFF`, raised `#1A1D2B` / `#F1F2F7`, primary pill and accent (an
electric indigo) `#818CF8` / `#4F46E5`, its tint `#1E1B4B` / `#E8EAFF` (the
current item, the square behind a section icon).

Contrast: every text pair of the Material 3 roles (`onX` on `X`, `onSurface` and
`onSurfaceVariant` on every surface container) is at least 4.5:1 and every icon,
focus ring, outline and primary pill at least 3:1, in both themes. The accent is 4.9:1 or more on
the page, the cards, the raised rows, the hover surface and its own tint; the dark muted text is 6.2:1 on the hover surface. A test
checks the pairs of the scheme and of every component theme's defaults.
No component paints a literal color (a test checks it): they all use tokens,
so the dark theme needs no per-component CSS.

Motion: see [Motion](#motion).

## Motion

Short, with a purpose, and never on the first paint of the content. Every
value is a token (`StudioDurations`, `StudioCurves`, `StudioMotion`); the
widgets take them from their theme, so a theme that changes a duration
changes the whole component.

| Where | What moves | How |
|---|---|---|
| Every pressable (pill buttons, chips, segments, nav items, icon buttons, theme toggle, drawer close) | squeezes to `scale(.97)` while pressed | `:active`, 120-160 ms, `enter` |
| Sidebar items, link cards, pager cards | the same, `scale(.985)`: a wide surface moves its edges too far at .97 | `:active` |
| Nav items, chips, pills, cards | fill, border and arrow ease on hover | 120 ms, `enter`; only where a pointer hovers |
| Link card, pager card | lifts 2 px, the arrow nudges 3 px toward where it points | hover, `translate`, 160 ms |
| `StudioSegmentedControl` | a thumb slides to the chosen cell | 200 ms, `move`; `translate` only |
| `StudioLevelSlider` | the grip grows to 1.35 while held or focused, 1.15 on hover | `scale`, 160 ms |
| `StudioBench` | the Code pane and the replayed stage rise 8 px and fade in; the replay icon turns half a turn | 200 ms, `enter` |
| Drawer (phone) | slides from its edge, the backdrop fades | thor's `Drawer`: `@starting-style`, `allow-discrete`, 250 ms |
| Sidebar sections | open and close | `::details-content` height, 200 ms |
| Table of contents | the section being read fades in as the last one fades out | `color`, `border-left-color`, 120 ms |
| Theme toggle | the icon that shows turns a quarter turn and grows from 60 % | `@starting-style`, 200 ms |
| Theme change | every color token cross-fades | `StudioMotionStyles.themeFade`, 200 ms |

Rules the components keep:

- Only `transform`-like properties and opacity move (`translate`, `scale`,
  `rotate`, `opacity`), plus color. Nothing is `transition: all`, and
  nothing is animated from `scale(0)`.
- Enter and press use the strong ease-out `enter`; what travels across the
  screen (the Switch thumb) uses `move`, an ease-in-out. Never an ease-in.
- Hover motion is gated by `(hover: hover)`: a tap on a phone is not a hover.
- Transitions, not keyframes, for what a person can trigger twice in a row
  (the thumb, the grip, the press): they retarget from where they are.
- `prefers-reduced-motion: reduce` removes the movement and keeps the
  meaning. The thumb jumps, the grip and the squeeze do not animate, panes
  and icons just appear and the theme changes at once.
  Colors that ease on hover stay (they are not movement).
- Nothing the keyboard does a hundred times a day animates beyond the
  thumb of a Switch.

`// web:` each of these is CSS the server writes (`@starting-style`,
`:has(:checked)`, `@property`): the browser plays it, no Dart or script runs
per frame, and the client never builds a style. One thing stays as the
browser draws it: a Level's grip travels with the native range input (its
position cannot be transitioned, so dragging is exactly under the finger).

### Fading the theme change

```dart
ThorApp(
  theme: StudioTheme.light(),
  darkTheme: StudioTheme.dark(),
  styles: [...StudioMotionStyles.themeFade],
  child: …,
)
```

The studio's colors are `light-dark()` tokens. `themeFade` registers each
as a `<color>` custom property and transitions them on `:root`, so flipping
`color-scheme` (the `StudioThemeToggle`, or the system) fades everything that
reads a token, without a transition on any element. It does not run on load.

An app that publishes colors of its own (`ThemeData(tokens:)`) fades them
with the rest by listing them: `StudioMotionStyles.themeFadeWith([kindError])`
is `themeFade` plus those tokens (a name already in the palette, or listed
twice, is registered once).

```dart
const kindError = ColorToken('kind-error', light: …, dark: …);
ThorApp(
  theme: StudioTheme.light().copyWith(tokens: [kindError]),
  darkTheme: StudioTheme.dark().copyWith(tokens: [kindError]),
  styles: [...StudioMotionStyles.themeFadeWith([kindError])],
  child: …,
)
```

## Component themes

| Theme data | What it styles |
|---|---|
| `StudioBenchThemeData` | the bench: demo stage and control panel (radius, padding, surfaces), the stage's motion |
| `StudioSegmentedButtonThemeData` | `StudioSegmentedControl`: the groove, the thumb, the labels, the sizes and the thumb's motion |
| `StudioSliderThemeData` | `StudioLevelSlider`: the bar, its fill, the grip, the name and value rooms and the grip's motion |
| `StudioPanelThemeData` | the sticky side panels |
| `StudioNavThemeData` | the top bar, its links and the sidebar items |
| `StudioCodeThemeData` | code blocks (surface, header, mono style) and the copy button |
| `StudioCalloutThemeData` | notes, tips and warnings, one `StudioToneColors` per tone |
| `StudioCardThemeData` | cards, link cards and pager cards (hover lift, arrow nudge) |
| `StudioChipThemeData` | filter pills, the "New" label, tone chips |
| `StudioButtonThemeData` | filled, tonal, outlined and text pills |

Each is a `ThemeExtension<T>` with nullable fields: an override. The widgets
resolve every field as their own parameter, then the theme installed in
`ThemeData.extensions`, then a default derived from
`Theme.of(context).colorScheme` and `textTheme` (Flutter's `_Defaults`), so
`copyWith(primary:)` reaches them. `StudioXThemeData.of(context, [override])`
returns the effective values (`StudioXThemeResolved`, a `StudioXThemeData`
with every field set); `maybeOf(context)` the installed override, `resolve(
ThemeData)` the same without a `BuildContext`. Each has `copyWith`, `==` and
`hashCode`.

## Flutter equivalence

| Flutter | thor_studio |
|---|---|
| `ThemeData(colorScheme:)`, `theme:` / `darkTheme:` | `StudioTheme.light()` / `StudioTheme.dark()` |
| `ColorScheme` | `StudioTheme.colorScheme(brightness)`; read `Theme.of(context).colorScheme` |
| `TextTheme` | `StudioTheme.textTheme`; read `Theme.of(context).textTheme` |
| `ThemeExtension<T>` with the app's own colors | `StudioExtraColors`, `StudioExtraTextStyles` |
| `FilledButtonThemeData`, `OutlinedButtonThemeData`, `TextButtonThemeData`, `ElevatedButtonThemeData`, `IconButtonThemeData` | filled by `StudioTheme`; `StudioButtonThemeData` for the pill's sizes (`.smallStyle`) |
| `ChipThemeData` | `chipTheme` by `StudioTheme`; `StudioChipThemeData` |
| `SegmentedButtonThemeData`, `SliderThemeData` | `StudioSegmentedButtonThemeData`, `StudioSliderThemeData` |
| `MaterialLocalizations`, `LocalizationsDelegate` | `StudioLocalizations`, `StudioLocalizations.delegate` |
| `CardThemeData` | `cardTheme` by `StudioTheme`; `StudioCardThemeData` |
| `ExpansionTileThemeData`, `NavigationRailThemeData`, `InputDecorationTheme` | filled by `StudioTheme` |
| `NavigationBarThemeData` | `StudioNavThemeData` |
| `Theme.of(context).extension<T>()` | `T.maybeOf(context)`, `T.of(context)` (effective) |
| `Curves`, `Duration` | `StudioCurves`, `StudioDurations` (read through the component themes) |
| `BorderRadius.circular(…)` | `StudioRadii` |

### Widgets

| Flutter | thor_studio | Differences (`// web:`) |
|---|---|---|
| `SegmentedButton<T>`, `ButtonSegment<T>` | `StudioSegmentedControl<T>`, `StudioButtonSegment<T>` | one choice only (native radios): no `multiSelectionEnabled`, no per-segment `enabled`; a control with no `onSelectionChanged` argument keeps the choice for the page's CSS |
| `Slider` | `StudioLevelSlider` | `title` is the visible name; no `onChangeStart` |
| `FilledButton`, `OutlinedButton` | the same, themed by `StudioTheme` | no press squeeze |
| `FilterChip` | `StudioFilterChip` | `href` makes it a link; `tone` |
| `Badge` | (none) | `StudioStatusLabel` is a pill that stands alone, not an indicator over a child |
| `DataTable`, `DataColumn`, `DataRow`, `DataCell` | `StudioDataTable` | read-only, in a rounded frame |
| `Scaffold(appBar:, drawer:)` | `StudioScaffold(appBar:, drawer:)` | the drawer is a column from `lg`; skip link and `<main>` |
| `NavigationDrawer(selectedIndex:)` | `StudioSideNav(selectedIndex:)` | every page in sight under section headings; a `<nav>` landmark |
| `NavigationBar(selectedIndex:)` | `StudioTopBar(links:, selectedIndex:)` | a sticky `<header>`, safe-area aware |
| `IconButton(icon:, tooltip:, onPressed:)` | `StudioIconButton` | `href` and `newTab` |
| `DefaultTabController(initialIndex:)` | `StudioCodeTabs`, `StudioFlutterCompare`, `StudioLayerDiagram` (`initialIndex`) | native radios |
| `Locale` | `StudioLocaleOption(locale:)` | an address per language |
| `MaterialLocalizations` | `StudioLocalizations` | optional delegate; `en`, `es` |

## Layout and navigation

```dart
StudioScaffold(
  appBar: StudioTopBar(
    brand: StudioBrand(name: 'thor'),
    links: [StudioNavDestination('Guide', href: '/guide')],
    selectedIndex: 0,                       // the current link, like NavigationBar
    search: StudioSearchPill(href: '/search', shortcut: '⌘K'),
    actions: [StudioThemeToggle()],
  ),
  drawer: StudioSideNav(sections: sections, selectedIndex: 3),
  tableOfContents: StudioTableOfContents(entries: toc, scrollSpy: true),
  body: Column(children: [StudioPageHeader(title: title, lead: lead), ...]),
  footer: StudioFooter(legal: l10n.license),
)
```

| Widget | What it is |
|---|---|
| `StudioScaffold` | the page: sticky top bar, sidebar (a column from `lg`, a native `<dialog>` drawer below), `<main>`, table of contents (from `xl`), footer, skip link |
| `StudioTopBar`, `StudioSearchPill` | the sticky `<header>` (safe-area aware) and the search link pill with its key hint, no JavaScript |
| `StudioSideNav` + `StudioNavSection` | every page in sight under small section headings, each section a list on a hairline rail; `selectedIndex` marks the current page (counting the items of every section) with a 2 px accent bar and accent text |
| `StudioTableOfContents` + `StudioTocEntry` | "On this page"; `scrollSpy` marks the section being read with CSS scroll markers |
| `StudioBreadcrumbs`, `StudioPageHeader`, `StudioPagerLinks` | the trail, the title block (eyebrow, `h1`, lead) and previous/next cards |
| `StudioFooter`, `StudioThemeToggle`, `StudioThemeChoice`, `StudioLocaleSwitcher` | the end of the page, thor's `ThemeToggle` with sun and moon, a popover of language links (`StudioLocaleOption(locale: Locale('es'), …)`, `selectedIndex`) |
| `StudioIconButton` | a round icon button of the top bar: `icon`, `tooltip`, `onPressed` or `href` (and `newTab`, web only) |

A sidebar item can end in a count pill or any widget:
`StudioNavDestination('Issues', href: '/issues', count: 31, countTone: StudioTone.danger, countLabel: '31 open')`
(`StudioStatusLabel`, tabular figures, `99+` from a hundred, nothing for
null or zero, `countLabel` is what a screen reader says) and
`trailing: Widget`. `StudioSideNav(touchTargets: true)` makes the rows at
least 44 px tall under a coarse pointer (the phone drawer); the mouse keeps
its 32 px rows. `StudioSideNav(pressFeedback: true)` squeezes a pressed row
(`pressScale`, 0.985 by default, eased with the nav theme's timing); it is
off by default.

`StudioThemeToggle` is the two-state switch. For an explicit System / Light /
Dark choice use `StudioThemeChoice()` (a segmented control of native radios,
labels from `StudioLocalizations`) with `styles: [...StudioThemeChoice.styles]`
in `ThorApp`: the checked radio sets the page's `color-scheme`, with no
JavaScript. It lasts for the page view (thor's inline script remembers only
the toggle), and brightness-switched widgets (`CssCondition.dark`) follow the
toggle or the system, not this choice.

`StudioNavDestination(label, href:)` is the one data type of every list of
links, and the page being shown is marked the Flutter way, by the container
(`selectedIndex`, like `NavigationDrawer`), not by a flag on each link.
Run `GALLERY_PAGE=scaffold thor dev` in `test/fixtures/apps/studio_gallery` to try the
whole page.

### Strings: `StudioLocalizations`

Every string a widget writes itself ("Copy", "Previous", "Skip to content",
"On this page", the bench's "Demo" / "Code" / "View", the "Flutter" / "Thor"
tabs…) is a getter of `StudioLocalizations`, like `MaterialLocalizations`:

```dart
ThorApp(
  locale: const Locale('es'),
  supportedLocales: StudioLocalizations.supportedLocales, // en, es
  localizationsDelegates: [StudioLocalizations.delegate, AppLocalizations.delegate],
  theme: StudioTheme.light(),
  child: StudioScaffold(…),   // "Saltar al contenido", "Abrir navegación"…
)
StudioLocalizations.of(context).copy;   // 'Copiar'
```

A widget's own parameter (`skipLabel:`, `copyLabel:`, `previousLabel:`…)
always wins. The delegate is optional: without one the page's locale picks
Spanish for `es` and English otherwise. Another language is a subclass of
`StudioLocalizations` behind its own delegate. `copyButton: false`
(`StudioCodeBlock`…) and `StudioProse(anchors: false)` turn the copy button
and the heading anchors off.

Browser floor: the drawer's open and close buttons, and the dialog buttons of
thor, use the invoker commands (`commandfor` / `command`), which need Chrome
and Edge 135, Firefox 144 or Safari 26.2. Older browsers keep a working
page: from `lg` the sidebar is an inline column and needs no command; below
it the drawer cannot be opened there (put the links in the footer or a page
of their own if you support them). The drawer has a visible close button
(`closeLabel:`, default `StudioLocalizations.close`), as well as Esc and a
click outside.

## Components

| Group | Widgets |
|---|---|
| Brand and icons | `StudioBrand` (mark and name; the mark defaults to the first letter) and `StudioIconButton` (a round icon button like the search magnifier and the theme toggle) |
| Building blocks | `StudioAttributes` (`aria-*`, `role`, `id`), `StudioIcons` (the Lucide subset; license in `third_party/lucide/LICENSE`) |

## Content widgets

What a documentation page is made of. Each takes its look from a component
theme (`StudioCodeThemeData`, `StudioCalloutThemeData`, `StudioCardThemeData`) and every
visible string ("Copy", "Flutter", "Thor") is a parameter.

| Widget | What it is |
|---|---|
| `StudioProse` | rendered markdown: headings with anchors, ~68ch paragraphs, lists, tables, inline code, links, quotes, images |
| `StudioCodeBlock` | file-name header, highlighted and changed lines (`StudioLineRange`), copy button |
| `StudioCodeTabs` + `StudioCodeTab` | several code blocks behind native tabs |
| `StudioFlutterCompare` | the "In Flutter / In Thor" pair behind a native selector, differing lines marked; `StudioCompareSummary` is its two-line version |
| `StudioLayerDiagram` + `StudioLayer` | View → ViewModel → Repository → Service, each layer opens its description and its Flutter and Thor code |
| `StudioCallout` | `note`, `tip`, `warning`, `danger`, `flutter`; `role="note"` named by its title |
| `StudioSteps` / `StudioSteps.diff` | numbered steps; the diff variant marks what each step adds |
| `StudioCardGrid` + `StudioLinkCard` | cards that are one link |
| `StudioFileTree`, `StudioKbd`, `StudioDataTable` | a nested list of files, a key cap, a real table of `DataColumn` / `DataRow` / `DataCell` |

The tabs, selectors and layers are native radios (thor_ui's `TabBar`): no
JavaScript, arrow keys work, and every panel is in the page. The only script
is the copy button's: `scripts/studio-code.js` (published into the app's
`web/scripts/` like the fonts; load it with `html.script(src:
'scripts/studio-code.js', defer: true)`). Without it the button is hidden
and the code stays selectable.

## The bench: an example with its controls

Every docs example lives in a `StudioBench`: a stage with the live demo, a
side panel with its controls, a Demo/Code toggle and an optional replay.

```dart
StudioBench(
  title: 'Rounded card',                       // every string is a parameter
  description: 'Change the radius and the fill.',
  replayLabel: 'Replay',                       // omit: no replay button
  stage: const DemoCard(),
  code: const DemoCode(),
  panel: StudioBenchPanel(
    groups: [
      StudioBenchGroup(label: 'Switches', children: [
        StudioBenchRow(
          label: 'Fill',
          child: StudioSegmentedControl<CardFill>(
            semanticLabel: 'Fill',
            selected: const {CardFill.soft},
            onSelectionChanged: demo.setFill,  // void (Set<CardFill>) of the state
            segments: const [
              StudioButtonSegment(value: CardFill.soft, label: Text('Soft')),
              StudioButtonSegment(value: CardFill.solid, label: Text('Solid')),
            ],
          ),
        ),
      ]),
      StudioBenchGroup(label: 'Levels', children: [
        StudioLevelSlider(
          title: 'Radius',
          label: '20 px',                      // the value as first drawn
          value: 20,
          max: 48,
          divisions: 24,
          onChanged: demo.setRadius,           // void (double) of the state
          valueText: demo.radiusText,          // String Function() of the state
        ),
      ]),
    ],
    footer: [OutlinedButton(href: url, child: Text('Share'))],
  ),
)
```

**How controls drive the demo (the contract the docs build on):**

1. One `ThorState` per example holds the controls' values as fields
   (`final radius = state(20.0)`) and a method per control
   (`void setRadius(double v)`, `void setFill(Set<CardFill> v)`), created once as a
   top-level `final demo = DemoState()`.
2. A control's `onChanged` is that method, torn off (never a closure):
   `StudioSegmentedControl.onSelectionChanged` is `ValueChanged<Set<T>>`
   (Flutter's `SegmentedButton`: the browser sends the one chosen value and
   the page hands it over as a one-element set),
   `StudioLevelSlider.onChanged` and `onChangeEnd` are `ValueChanged<double>`.
3. A continuous value follows the state as a bound length:
   `BorderRadius.circularLength(demo.radius.px)`; a finite one
   (the fill) as `Watch.field(demo.fill, builder: …)` variants. The client
   never builds a style.
4. The number on a bar follows the drag with `valueText: demo.radiusText`
   (a method returning `String`); the Code view is the same idea, a text
   made by methods of the state inside a `<pre>`.
5. Without JavaScript the bars still drag (their fill is the browser's), the
   segments still switch, and Demo/Code and replay still work; only what the
   state computes (the demo's values, the numbers, the code text) waits for
   the engine.

`test/fixtures/apps/studio_gallery/lib/sections/bench_section.dart` is the complete
working example: radius, padding and fill change the card, and the Code view
shows the matching Dart.

| Widget | What it is |
|---|---|
| `StudioBench` | the frame; Demo/Code is a native radio group, replay a native checkbox (both with no JS); the panel stacks under the stage on phones |
| `StudioBenchPanel`, `StudioBenchGroup`, `StudioBenchRow` | the side panel, its labelled groups ("Switches", "Levels") and one name-left, control-right line |
| `StudioSegmentedControl<T>` + `StudioButtonSegment<T>` | the Switch (`SegmentedButton`): a pill groove, native radios under the labels, keyboard and screen readers for free |
| `StudioLevelSlider` | the Level (`Slider`): a native `<input type=range>` drawn as a bar, title left, value right, fill to the value |
| `FilledButton`, `OutlinedButton` (`.icon`, `.tonal`) | the primary and the outline pill: `StudioTheme` styles them |
| `StudioFilterChip` | a filter pill (`FilterChip`): a toggle with `onSelected`, a link with `href`, disabled with neither |
| `StudioStatusLabel` | the "New" tag, neutral or one of the status tones |

### Bench layout rules

The numbers are `StudioBenchThemeData` fields (and, for the controls,
`StudioSegmentedButtonThemeData` and `StudioSliderThemeData`):

- **Side by side from 640 px of the bench's own width** (`sideBySideFrom`).
  The panel is a fixed 288 px (`panelWidth`) and the stage gets the rest: in
  the docs' 712 px column that is 408 / 288 px (57 / 40 %). `wide: true`
  stays opt-in: with a 288 px panel a
  prose column no longer needs the bleed, so benches do not default to it.
- **The stage sizes to its demo** with a least height of 148 px stacked
  (`stageCompactMinHeight`) and 240 px beside the panel (`stageMinHeight`);
  the demo is centered in what is left under the toolbar. Padding is
  16 px stacked (`stageCompactPadding`), 32 px beside the panel.
- **Stacked (phones) the stage is sticky** under the page's top bar
  (`--studio-top`, set by `StudioScaffold`, plus 8 px) and capped at
  `56dvh` so a tall demo scrolls inside it: dragging a Level in the panel keeps
  the demo in view. Side by side the stage is as tall as the panel, so sticky
  does nothing there. No motion is involved.
- **A Switch never clips**: `StudioSegmentedControl` is one row of equal
  cells, as wide as its widest label while there is room and no wider than
  its container (`width: fit-content; max-width: 100%`, columns of
  `minmax(0, 1fr)`): CSS only, no estimate of the text width in Dart. A line
  too narrow for the labels shrinks the cells together and each label wraps
  inside its own cell (a word breaks only when it alone is wider than the
  cell): nothing is clipped, and the radios keep their order (arrow
  keys, "1 of N"). The cells are equal, so the sliding thumb moves by
  `translate` of its own width. Where the labels would not fit one row (an
  estimate from the longest word of each `Text` label, in Dart; the text
  itself is never measured) the control becomes a list in a container query:
  one column, the thumb moving down by `translate`. The query is the nearest
  `LayoutScope`'s width (`StudioBenchPanel` is one: its Switches of four
  labels are lists, of two, rows); with no scope above it the control stays a
  row and the labels wrap. In a `StudioBenchRow` a control of more than
  two segments takes its own line under the name (`expandedInsets`).
- **Code**: a code pane with a copy button reserves a 28 px strip above the
  code below `sm`, so the button never covers a line; from `sm` it floats.

Motion: see [Motion](#motion): a sliding thumb in the Switches, a grip that
grows in the Levels, panes that rise in when the toggle shows them and a
replay icon that turns.

## Styles are typed

No CSS in strings. Sticky panels, the code block and the markdown use
`thor_ui`'s typed values (`StyleProps(position: BoxPosition.sticky(…))`,
`Text(softWrap: false)`, `Styled(descendants: …)`). The single
exception (a markdown `<table>` needs `display: block` to scroll inside
itself) is marked with `// ignore: thor_lints/avoid_raw_css` and its reason.

Images: an SVG file shown with `Image` is an `<img>`, so its own fills do not
follow the theme. Give it a dark file with `Image.network(src, dark:
darkSrc)`; inline icons (`StudioIcons`) use `currentColor` and follow the
theme by themselves.

## Tested

- `dart test`: tokens and contrast (light and dark, scheme and component
  themes), the theme extensions, landmarks, `aria-current` only on the
  current item, sticky panels, the search form without JS, highlighting edge
  cases, an element budget for a whole docs page and the layout regressions
  found in the browser.
- In a browser: `test/fixtures/apps/studio_gallery` (the docs guide page of the design),
  with and without JavaScript, at 390, 768 and 1440 px, in light and dark.
