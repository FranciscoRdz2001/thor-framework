# `thor_ui`

Everything an app can import, by topic. `import 'package:thor_ui/thor_ui.dart';` brings the widgets and `thor_style`; the other imports are for the server, the routes, raw HTML and the tests.

| Page |
|---|
| [The widget model](thor_ui.md#widgets) |
| [Layout](thor_ui.md#layout) |
| [Text, icons and images](thor_ui.md#texto) |
| [Controls, forms and gestures](thor_ui.md#controles) |
| [Material and navigation](thor_ui.md#material) |
| [Styles and theme](thor_ui.md#estilos) |
| [Animation and effects](thor_ui.md#animacion) |
| [State in the browser](thor_ui.md#estado) |

| Import | Page |
|---|---|
| `server.dart` | [`server`](thor_ui.md#server) |
| `router.dart` | [`router`](thor_ui.md#router) |
| `html.dart` | [`html`](thor_ui.md#html) |
| `testing.dart` | [`testing`](thor_ui.md#testing) |
| `intl.dart` | [`intl`](thor_ui.md#intl) |
| `package:thor_test/thor_test.dart` | [`thor_test`](thor_ui.md#thor_test) |
| `package:thor_studio/thor_studio.dart` | [`thor_studio`](thor_ui.md#thor_studio) |

## `widgets` · The widget model

### `AsyncCallback` · typedef

Flutter's `AsyncCallback`.


### `AsyncValueGetter` · typedef

Flutter's `AsyncValueGetter`.


### `AsyncValueSetter` · typedef

Flutter's `AsyncValueSetter`.


### `BuildContext` · abstract class

Where a widget is built: its place in the tree, the widgets above it and what they publish.

- `BuildContext()`

### `Builder` · class

Builds [builder] with the context at this place in the tree.

- `Builder({Key? key, required Widget Function(BuildContext) builder})` — Builds [builder] here.

### `Cached` · class

Keeps the HTML of [child] for later requests of the same process: the next page that builds a `Cached` with the same [cacheKey], at the same place, adds the kept HTML instead of building [child] again.

- `Cached({Key? key, required Object cacheKey, Duration? ttl, required Widget child})` — Keeps [child]'s HTML under [cacheKey] (for [ttl], if given).

### `ChangeNotifier` · class

A [Listenable] that notifies with [notifyListeners].

- `ChangeNotifier()`

### `DefaultMaterialLocalizations` · class

English [MaterialLocalizations] (Flutter's `DefaultMaterialLocalizations`): the fallback of every locale `thor_ui` has no texts for.

- `DefaultMaterialLocalizations()` — The English texts and dates.

### `DefaultWidgetsLocalizations` · class

English [WidgetsLocalizations] (Flutter's `DefaultWidgetsLocalizations`).

- `DefaultWidgetsLocalizations()` — The English texts.

### `GlobalKey` · class

Flutter's global key. `// web:` the server keeps no tree between builds, so [currentState] and [currentContext] are always null.

- `GlobalKey<T>()` — A global key (see the class).

### `InheritedWidget` · abstract class

Data published to the widgets below it (`context.dependOnInheritedWidgetOfExactType<T>()`).

- `InheritedWidget({Key? key, required Widget child})` — Publishes this widget to [child] and below.

### `Key` · abstract class

Identifies a component among its siblings (see [Widget.key]).

- `Key()` — A key.

### `Listenable` · abstract class

An object that notifies its listeners when it changes.

- `Listenable()` — A listenable.

### `ListenableBuilder` · class

Builds [builder] with [listenable]'s current state (see the library).

- `ListenableBuilder({Key? key, required Listenable listenable, required Widget Function(BuildContext, Widget?) builder, Widget? child})` — Builds [builder] with [listenable] and [child].

### `Locale` · class

Flutter's `Locale`: a language, optionally with a script and a region.

- `Locale(String languageCode, [String? countryCode])` — A locale for [languageCode] (`es`) and optionally [countryCode] (`MX`).
- `Locale.fromSubtags({String languageCode = 'und', String? scriptCode, String? countryCode})` — A locale from its subtags (`und` when there is no language).

### `LocaleListResolutionCallback` · typedef

Flutter's `LocaleListResolutionCallback`: the app's locale from the visitor's preferred ones, in order.


### `LocaleResolutionCallback` · typedef

Flutter's `LocaleResolutionCallback`: the app's locale from the visitor's first preferred one.


### `Localizations` · class

Flutter's `Localizations`: the page's [locale] and the resources its [delegates] load for it, for the widgets below.

- `Localizations({Key? key, required Locale locale, required List<LocalizationsDelegate<Object?>> delegates, required Widget child})` — Publishes [locale] and [delegates] to [child].

### `LocalizationsDelegate` · abstract class

Flutter's `LocalizationsDelegate`: loads the resources of type [T] (an `AppLocalizations`) for a locale. `thor_builder` generates one per app from its ARB files.

- `LocalizationsDelegate<T>()` — A delegate.

### `MaterialLocalizations` · abstract class

Flutter's `MaterialLocalizations`: the texts and date formats of the Material widgets (date picker, app bar, chips, pagination…), for the page's locale.

- `MaterialLocalizations()` — The texts of one language.

### `MaterialLocalizationsEs` · class

Spanish [MaterialLocalizations].

- `MaterialLocalizationsEs()` — The Spanish texts and dates.

### `RouteUrl` · extension type

The URL of a link, a redirect or a canonical address: a page of this site (`/orders/7?tab=items`), a section (`#pricing`) or another site (`https://example.com/docs`).

- `RouteUrl(String value)`
- `RouteUrl.external(String url)` — A URL on another site: `http`, `https`, `mailto` or `tel`. Any other scheme (`javascript:`, `data:`) throws, so a link made from data a visitor sent can never run code.

### `State` · abstract class

The state of a [StatefulWidget], for one page.

- `State<T>()`

### `StatefulWidget` · abstract class

A widget with a [State]. On the server it is built once: `initState`, `didChangeDependencies`, `build`, and `dispose` when the page is done.

- `StatefulWidget({Key? key})` — A stateful widget.

### `StatelessWidget` · abstract class

A widget described by what it builds.

- `StatelessWidget({Key? key})` — A stateless widget.

### `SynchronousFuture` · class

Flutter's `SynchronousFuture`: a future whose value is already there. Generated delegates return one, so a page renders in one pass.

- `SynchronousFuture<T>(T _value)` — A future completed with [_value].

### `ThorApp` · class

Root of a thor app, like `MaterialApp`: turns widget styles into deduplicated, conditional stylesheets instead of inline `style` attributes.

- `ThorApp(…)` — Wraps [child] with style extraction, like `MaterialApp` wraps an app.
- `ThorApp.router(…)` — An app with routes, like `MaterialApp.router`: one value, declared once (top level), that the server reads when it starts. A request resolves its locale from [supportedLocales] and [localeStrategy] (the URL prefix, the [localeCookieName] cookie, `Accept-Language`), then matches [routerConfig], runs its middleware and loads, and draws the page inside this app ([page]): theme, locale, navigation and [styles] set here only.

### `ThorLocalizations` · abstract class

The texts thor's widgets write that Flutter's localizations don't have: the theme switch, the carousel, pagination, drag and reorder announcements, autocomplete results, the upload progress, the language switcher, the default error pages and the messages of form validation.

- `ThorLocalizations()` — The texts of one language.

### `ThorLocalizationsEn` · class

English [ThorLocalizations].

- `ThorLocalizationsEn()` — The English texts.

### `ThorLocalizationsEs` · class

Spanish [ThorLocalizations].

- `ThorLocalizationsEs()` — The Spanish texts.

### `UniqueKey` · class

A key equal only to itself.

- `UniqueKey()` — A key equal only to itself.

### `ValueChanged` · typedef

Flutter's `ValueChanged`: called with a new value.


### `ValueGetter` · typedef

Flutter's `ValueGetter`: returns a value.


### `ValueKey` · class

A key made of a [value]: equal values, equal keys.

- `ValueKey<T>(T value)` — A key for [value].

### `ValueListenable` · abstract class

A [Listenable] with a current [value].

- `ValueListenable<T>()` — A listenable with a value.

### `ValueNotifier` · class

A [ChangeNotifier] holding a [value]: setting a different one notifies.

- `ValueNotifier<T>(T _value)` — A notifier starting at the given value.

### `ValueSetter` · typedef

Flutter's `ValueSetter`: sets a value.


### `VoidCallback` · typedef

Flutter's `VoidCallback`: a callback with no arguments.


### `Widget` · abstract class

A piece of the page: what `build` returns.

- `Widget({Key? key})` — A widget; its [key] is accepted and unused.
- `Widget.element({Key? key, required String tag, String? id, String? classes, Styles? styles, Map<String, String>? attributes, List<Widget>? children})` — An HTML element [tag] with its [id], [classes], inline [styles], [attributes] and [children]. The wrappers above it ([Widget.wrapElement]) merge into it.
- `Widget.text(String text, {Key? key})` — A text node, escaped.
- `Widget.fragment(List<Widget> children, {Key? key})` — [children] with no element around them.
- `Widget.empty({Key? key})` — Nothing.
- `Widget.wrapElement({Key? key, String? tag, String? id, String? classes, Styles? styles, Map<String, String>? attributes, required Widget child})` — [child] whose next HTML element(s) take these [id], [classes], [styles] and [attributes] too: the element's own values win, then the innermost wrapper's. A [tag] replaces the element's (`Link` makes a `div` an `<a>`), except an element that keeps its own (an `svg`, an `img`, a control).

### `WidgetsLocalizations` · abstract class

Flutter's `WidgetsLocalizations`: the texts of the basic widgets, for the page's locale.

- `WidgetsLocalizations()` — The texts of one language.

### `WidgetsLocalizationsEs` · class

Spanish [WidgetsLocalizations].

- `WidgetsLocalizationsEs()` — The Spanish texts.

### `basicLocaleListResolution` · function

Flutter's `basicLocaleListResolution`: the supported locale that best matches [preferredLocales] (same language, script and region; then language and script, language and region, language, region), else the first of [supportedLocales].

- `Locale basicLocaleListResolution(List<Locale>? preferredLocales, Iterable<Locale> supportedLocales)`

### `immutable` · getter


### `inspectAtAttribute` · getter


### `kDebugMode` · getter


### `kIsWeb` · getter


### `kReleaseMode` · getter


### `mustCallSuper` · getter


### `protected` · getter


## `layout` · Layout

### `Align` · class

Flutter's `Align`. Expands in both axes (when bounded) and positions its child with loose constraints; fractional alignments work too.

- `Align({Key? key, AlignmentGeometry alignment = Alignment.center, Widget? child})` — Creates a widget that aligns [child] within itself.

### `Alignment` · class

Flutter's `Alignment`: `x`/`y` in [-1, 1], (0, 0) is the center.

- `Alignment(double x, double y)` — Creates an alignment from fractional [x]/[y] coordinates.

### `AlignmentDirectional` · class

Flutter's `AlignmentDirectional`: like [Alignment], but the horizontal axis follows the text direction: [start] is -1 at the start edge (the left in left-to-right text) and 1 at the end edge.

- `AlignmentDirectional(double start, double y)` — Creates an alignment from fractional [start]/[y] coordinates.

### `AlignmentGeometry` · abstract class

Flutter's `AlignmentGeometry`: a position in a box that may or may not depend on the text direction ([Alignment], [AlignmentDirectional]).

- `AlignmentGeometry()` — Creates an alignment geometry.

### `AlwaysScrollableScrollPhysics` · class

Flutter's `AlwaysScrollableScrollPhysics`; no effect on the web.

- `AlwaysScrollableScrollPhysics()` — Creates physics that always scroll in Flutter.

### `AnimationDirection` · enum

Which way a [CssAnimation] runs.

- values: `normal`, `reverse`, `alternate`

### `AnimationFill` · enum

What an animation leaves on the box before and after it runs (`animation-fill-mode`).

- values: `none`, `forwards`, `backwards`, `both`

### `Appearance` · enum

Whether a form control paints itself (`appearance`).

- values: `auto`, `none`

### `AspectRatio` · class

Flutter's `AspectRatio` (`width / height`).

- `AspectRatio({Key? key, required double aspectRatio, Widget? child})` — Creates a widget with a specific [aspectRatio].

### `Axis` · enum

Flutter's `Axis`.

- values: `horizontal`, `vertical`

### `BlendMode` · enum

How a box mixes with what is under it (`mix-blend-mode`): Flutter's `BlendMode` for a layer.

- values: `srcOver`, `multiply`, `screen`, `overlay`, `darken`, `lighten`, `colorDodge`, `colorBurn`, `hardLight`, `softLight`, `difference`, `exclusion`, `hue`, `saturation`, `color`, `luminosity`, `plus`

### `BorderCollapse` · enum

Whether a table's cell borders merge (`border-collapse`).

- values: `separate`, `collapse`

### `BorderRadius` · class

Flutter's `BorderRadius`.

- `BorderRadius.only({Radius topLeft = Radius.zero, Radius topRight = Radius.zero, Radius bottomRight = Radius.zero, Radius bottomLeft = Radius.zero})` — Creates a border radius with each corner set independently, defaulting to no rounding.
- `BorderRadius.all(Radius radius)` — Creates a border radius where all four corners use the same [radius].
- `BorderRadius.circular(double radius)` — Creates a border radius with a uniform circular [radius] on every corner.
- `BorderRadius.circularLength(Length length)` — A uniform circular radius of [length] on every corner (see [Radius.circularLength]).
- `BorderRadius.vertical({Radius top = Radius.zero, Radius bottom = Radius.zero})` — Creates a border radius with [top] corners and [bottom] corners set independently.
- `BorderRadius.horizontal({Radius left = Radius.zero, Radius right = Radius.zero})` — Creates a border radius with [left] corners and [right] corners set independently.

### `BorderRadiusDirectional` · class

Flutter's `BorderRadiusDirectional`: a rounding whose horizontal corners follow the text direction (`topStart` is the top left corner in left-to-right text).

- `BorderRadiusDirectional.only({Radius topStart = Radius.zero, Radius topEnd = Radius.zero, Radius bottomStart = Radius.zero, Radius bottomEnd = Radius.zero})` — Creates a border radius with each corner set independently, defaulting to no rounding.
- `BorderRadiusDirectional.all(Radius radius)` — Creates a border radius where all four corners use the same [radius].
- `BorderRadiusDirectional.circular(double radius)` — Creates a border radius with a uniform circular [radius] on every corner.
- `BorderRadiusDirectional.circularLength(Length length)` — A uniform circular radius of [length] on every corner (see [Radius.circularLength]).
- `BorderRadiusDirectional.vertical({Radius top = Radius.zero, Radius bottom = Radius.zero})` — Creates a border radius with [top] corners and [bottom] corners set independently.
- `BorderRadiusDirectional.horizontal({Radius start = Radius.zero, Radius end = Radius.zero})` — Creates a border radius with [start] corners and [end] corners set independently.

### `BorderRadiusGeometry` · abstract class

Flutter's `BorderRadiusGeometry`: a rounding that may or may not depend on the text direction ([BorderRadius], [BorderRadiusDirectional]).

- `BorderRadiusGeometry()` — Creates a border radius geometry.

### `BorderStyle` · enum

Flutter's `BorderStyle`.

- values: `none`, `solid`, `dashed`, `dotted`

### `BouncingScrollPhysics` · class

Flutter's `BouncingScrollPhysics`; no effect on the web.

- `BouncingScrollPhysics()` — Creates iOS-style physics.

### `BoxConstraints` · class

Flutter's `BoxConstraints` (min/max width & height).

- `BoxConstraints({double minWidth = 0, double maxWidth = double.infinity, double minHeight = 0, double maxHeight = double.infinity})` — Creates constraints, defaulting to unbounded (0 to infinity) on both axes.
- `BoxConstraints.tightFor({double? width, double? height})` — Creates constraints that force [width] and/or [height] to an exact value; an omitted dimension stays unbounded.
- `BoxConstraints.expand({double? width, double? height})` — Creates constraints that force [width] and/or [height] to fill the available space; an omitted dimension stays unbounded.

### `BoxFit` · enum

Flutter's `BoxFit` → `object-fit` / `background-size`.

- values: `fill`, `contain`, `cover`, `fitWidth`, `fitHeight`, `none`, `scaleDown`

### `BoxFloat` · enum

Which side a box floats to, the text wrapping around it (`float`): an image beside a paragraph in rendered markdown.

- values: `none`, `left`, `right`, `start`, `end`

### `BoxPosition` · class

How a box is placed outside the normal flow (`position` and its offsets). Inside a `Stack` use Flutter's `Positioned`; this covers what Flutter does with slivers or overlays:

- `BoxPosition.sticky({Length? top, Length? right, Length? bottom, Length? left})` — Scrolls with the page until it reaches [top] (or the other offsets) from its scrolling ancestor's edge, then stays there while its parent is in view (`position: sticky`, Flutter's pinned sliver header).
- `BoxPosition.fixed({Length? top, Length? right, Length? bottom, Length? left})` — Placed against the window and kept there while scrolling (`position: fixed`).
- `BoxPosition.absolute({Length? top, Length? right, Length? bottom, Length? left})` — Placed against the nearest positioned ancestor (`position: absolute`; in a `Stack`, `Positioned` is the Flutter way, with `leftLength:`, `topLength:`… for a state's `card.x.px`).
- `BoxPosition.relative({Length? top, Length? right, Length? bottom, Length? left})` — In the flow, moved by the offsets, and the anchor of absolutely placed descendants (`position: relative`).

### `BoxShape` · enum

Flutter's `BoxShape`.

- values: `rectangle`, `circle`

### `BoxSizing` · enum

What `width` and `height` measure (`box-sizing`).

- values: `contentBox`, `borderBox`

### `CarouselArrowPosition` · enum

Where a [CarouselView]'s arrows sit.

- values: `inside`, `outside`

### `CarouselIndicatorPosition` · enum

Where a [CarouselView]'s dots sit.

- values: `below`, `inside`

### `CarouselIndicatorStyle` · class

The dots of a [CarouselView] (web extra).

- `CarouselIndicatorStyle(…)` — A dots style; unset fields keep the theme's look.

### `CarouselLayout` · class

Whole items per view and the space between them for a [CarouselView] (web extra); per breakpoint with `.when()`.

- `CarouselLayout(…)` — Items per view and spacing; unset ones keep the carousel's (1, 16).

### `CarouselView` · class

Flutter's `CarouselView`: a horizontal row of items that scrolls and snaps item by item, on native scroll snapping (touch, trackpad and keyboard scrolling for free, no JS).

- `CarouselView(…)` — Creates a carousel.

### `Center` · class

Flutter's `Center`.

- `Center({Key? key, Widget? child})` — Creates a widget that centers [child].

### `ClampingScrollPhysics` · class

Flutter's `ClampingScrollPhysics`; no effect on the web.

- `ClampingScrollPhysics()` — Creates Android-style physics.

### `Clip` · enum

Flutter's `Clip` → `overflow`.

- values: `none`, `hardEdge`, `antiAlias`, `antiAliasWithSaveLayer`

### `ColoredBox` · class

Flutter's `ColoredBox`.

- `ColoredBox({Key? key, required Color color, Widget? child})` — Creates a widget that paints [color] behind [child].

### `Column` · class

Flutter's `Column`.

- `Column(…)` — Creates a vertical Flex.

### `ConstrainedBox` · class

Flutter's `ConstrainedBox`. Applies min/max directly to the child element.

- `ConstrainedBox({Key? key, required BoxConstraints constraints, required Widget child})` — Creates a widget that imposes additional constraints on [child].

### `Container` · class

Flutter's `Container`.

- `Container(…)` — Creates a box that positions, sizes and decorates [child].

### `ContentVisibility` · enum

Whether the browser skips the work of a box that is off screen (`content-visibility`).

- values: `visible`, `auto`, `hidden`

### `CrossAxisAlignment` · enum

Flutter's `CrossAxisAlignment` → `align-items`.

- values: `start`, `end`, `center`, `stretch`, `baseline`

### `CssAnimation` · class

A named `@keyframes` run on a box (`animation`): the browser plays the frames, so no ticker runs in Dart.

- `CssAnimation(…)` — Runs the keyframes called [name] over [duration].

### `CssColorScheme` · enum

Which color schemes the element and the browser's own UI (form controls, scrollbars, `light-dark()`) may use (`color-scheme`).

- values: `normal`, `light`, `dark`, `lightDark`

### `CssProperty` · abstract class

A property that [Transition] can name, so the property is not a string typed by hand.

- `CssProperty()`

### `CustomScrollView` · class

Flutter's `CustomScrollView`: slivers (`SliverAppBar`, `SliverList`, `SliverGrid`, `SliverToBoxAdapter`, `SliverPadding`, `SliverFillRemaining`) stacked in one scrolling box.

- `CustomScrollView(…)` — Creates a scroll view of [slivers].

### `DecoratedBox` · class

Flutter's `DecoratedBox`.

- `DecoratedBox({Key? key, required BoxDecoration decoration, Widget? child})` — Creates a widget that paints [decoration] behind [child].

### `Divider` · class

Flutter's `Divider` → `<hr>`. Its defaults come from `ThemeData.dividerTheme`.

- `Divider({Key? key, double? height, double? thickness, double? indent, double? endIndent, Color? color})` — Creates a horizontal divider.

### `EdgeInsets` · class

Flutter's `EdgeInsets`: padding / margin in logical pixels.

- `EdgeInsets.fromLTRB(double left, double top, double right, double bottom)` — Creates insets from the left, top, right and bottom values.
- `EdgeInsets.all(double value)` — Insets of [value] on every side.
- `EdgeInsets.symmetric({double vertical = 0, double horizontal = 0})` — Insets of [horizontal] on the left/right and [vertical] on the top/bottom.
- `EdgeInsets.only({double left = 0, double top = 0, double right = 0, double bottom = 0})` — Insets with each side set independently, defaulting to 0.

### `EdgeInsetsDirectional` · class

Flutter's `EdgeInsetsDirectional`: insets whose horizontal sides follow the text direction (`start` is the left in left-to-right text).

- `EdgeInsetsDirectional.fromSTEB(double start, double top, double end, double bottom)` — Creates insets from the start, top, end and bottom values.
- `EdgeInsetsDirectional.all(double value)` — Insets of [value] on every side.
- `EdgeInsetsDirectional.only({double start = 0, double top = 0, double end = 0, double bottom = 0})` — Insets with each side set independently, defaulting to 0.

### `EdgeInsetsGeometry` · abstract class

Flutter's `EdgeInsetsGeometry`: insets that may or may not depend on the text direction ([EdgeInsets], [EdgeInsetsDirectional]), or that carry a [Length] (`EdgeInsetsGeometry.allLength`).

- `EdgeInsetsGeometry()` — Creates insets geometry.
- `EdgeInsetsGeometry.allLength(Length value)` — Insets of [value] on every side, as a [Length]: a CSS variable the browser keeps current, a percentage, a `calc()`.
- `EdgeInsetsGeometry.symmetricLength({Length vertical, Length horizontal})` — [horizontal] on the left/right and [vertical] on the top/bottom, as [Length]s (see [EdgeInsetsGeometry.allLength]).
- `EdgeInsetsGeometry.onlyLength({Length left, Length top, Length right, Length bottom, Length start, Length end})` — Each side set independently as a [Length], defaulting to [Length.zero] (see [EdgeInsetsGeometry.allLength]). [start] and [end] follow the text direction, as in [EdgeInsetsDirectional].
- `EdgeInsetsGeometry.sides({Length? left, Length? top, Length? right, Length? bottom, Length? start, Length? end})` — Only the sides given, as [Length]s; the others are left alone (each side is its own declaration: `margin-top`, not the `margin` shorthand). What a rule for HTML no widget builds needs to change one side of a margin the browser or another rule gives (`p { margin: 1em 0 }`):

### `EdgeInsetsGeometryAdaptive` · extension

Breakpoints and states for any [EdgeInsetsGeometry] (an [EdgeInsets] has its own, which keeps it an [EdgeInsets]).


### `EdgeInsetsGeometryOperators` · extension

`+` on any geometry (an [EdgeInsets] has its own, numeric one).


### `Expanded` · class

Flutter's `Expanded` (`Flexible` with `FlexFit.tight`).

- `Expanded({Key? key, int flex = 1, required Widget child})` — Creates a widget that forces [child] to fill the available space.

### `FittedBox` · class

Flutter's `FittedBox`: sizes and positions [child] inside itself by [fit], in CSS only (no measuring, no transform).

- `FittedBox({Key? key, BoxFit fit = BoxFit.contain, AlignmentGeometry alignment = Alignment.center, Clip clipBehavior = Clip.none, Widget? child})` — Creates a widget that fits [child] inside itself.

### `FixedColumnWidth` · class

Flutter's `FixedColumnWidth`: [value] logical pixels.

- `FixedColumnWidth(double value)` — A column [value] logical pixels wide.

### `Flex` · class

Flutter's `Flex`: a CSS flexbox with Flutter's defaults (`crossAxisAlignment: center`, non-flex children never shrink).

- `Flex(…)` — Creates a flex container along [direction].

### `FlexColumnWidth` · class

Flutter's `FlexColumnWidth`: a share of the width the fixed columns leave.

- `FlexColumnWidth([double value = 1])` — A column taking [value] shares of the remaining width.

### `FlexFit` · enum

Flutter's `FlexFit`.

- values: `tight`, `loose`

### `FlexLayout` · class

Flex values a `Row`/`Column` switches per breakpoint (web extra), giving only what changes. The variants are named parameters, so the value stays `const`; `.when()` is the same thing as a method call:

- `FlexLayout(…)` — Flex values; unset ones keep the widget's own.

### `Flexible` · class

Flutter's `Flexible`. Decorates the child element as a flex item; no extra DOM node is created.

- `Flexible({Key? key, int flex = 1, FlexFit fit = FlexFit.loose, required Widget child})` — Creates a widget that controls how [child] flexes in a Row/Column.

### `FloatingActionButtonLocation` · class

Flutter's `FloatingActionButtonLocation`: where the `Scaffold` puts its `floatingActionButton`.


### `FontSmoothing` · enum

How text edges are smoothed on macOS (`-webkit-font-smoothing` and `-moz-osx-font-smoothing`; other systems ignore both). Inherited, so set once on the page's root.

- values: `auto`, `antialiased`

### `FractionColumnWidth` · class

Flutter's `FractionColumnWidth`: [value] of the table's width.

- `FractionColumnWidth(double value)` — A column taking [value] (0 to 1) of the table's width.

### `FractionallySizedBox` · class

Flutter's `FractionallySizedBox`: sizes the child element to a fraction of the available space (a percentage width/height, no extra node).

- `FractionallySizedBox({Key? key, double? widthFactor, double? heightFactor, required Widget child})` — Sizes `child` to [widthFactor] × [heightFactor] of the parent.

### `Grid` · class

A grid that doesn't scroll and whose rows fit their content (CSS grid): its [layout] sets the columns and gaps. Cells stretch to the row's height, so cards in a row line up.

- `Grid({Key? key, GridLayout layout = const GridLayout(), CrossAxisAlignment alignItems = CrossAxisAlignment.stretch, List<Widget> children = const []})` — Creates a grid.

### `GridItem` · class

Places [child] in its [Grid] by [placement] (spans, lines or a named area), without a node of its own, like `Expanded` in a `Row`.

- `GridItem({Key? key, required GridPlacement placement, required Widget child})` — Places [child] by [placement].

### `GridLayout` · class

The columns and gaps of a [Grid]; change them per breakpoint with `.when()`, giving only what changes:

- `GridLayout(…)` — Columns and gaps; unset values keep the grid's (or the base's).

### `GridPlacement` · class

Where a child sits in its [Grid]: the columns and rows it spans or the lines it runs between, or a named area of the grid's [GridLayout.areas]. Change it per breakpoint with `.when()`:

- `GridPlacement(…)` — A placement; unset values leave the child where the grid puts it.

### `GridSize` · class

The size of one column of a [GridLayout.columnSizes].

- `GridSize.flex([double flex = 1])` — A share of the free space, like `Expanded(flex:)` (`2` takes twice what `1` does); `minmax(0, Nfr)`, so long content cannot widen it.
- `GridSize.fixed(double width)` — Exactly [width] logical pixels.

### `GridView` · class

Flutter's `GridView.count` / `GridView.extent` → CSS grid; also `GridView(gridDelegate:)` and `GridView.builder(gridDelegate:, itemCount:, itemBuilder:)` with Flutter's delegates, which give the same CSS.

- `GridView.count(…)` — Creates a grid with a fixed [crossAxisCount] of columns.
- `GridView.extent(…)` — Creates a grid with as many columns as fit [maxCrossAxisExtent].
- `GridView(…)` — Creates a grid laid out by [gridDelegate] (Flutter's spelling of [GridView.count] and [GridView.extent]) from an explicit list of [children].
- `GridView.builder(…)` — Creates a grid laid out by [gridDelegate] with [itemCount] items built by [itemBuilder].

### `ImageFilter` · class

Flutter's `ImageFilter` for a box: `blur` and the color filters the browser applies to the box and what is inside it (`filter`).

- `ImageFilter.blur({double sigmaX = 0, double sigmaY = 0})` — A Gaussian blur of [sigmaX] logical pixels. `// web:` CSS blurs with one radius for both axes: [sigmaY] is used only when [sigmaX] is 0. There is no `tileMode`: the browser decides the edges.
- `ImageFilter.saturate(double amount)` — Color saturation: `0` grey, `1` as is, above 1 vivid.
- `ImageFilter.brightness(double amount)` — Brightness: `0` black, `1` as is.
- `ImageFilter.contrast(double amount)` — Contrast: `0` flat grey, `1` as is.
- `ImageFilter.grayscale(double amount)` — Share of grey: `0` as is, `1` fully grey.
- `ImageFilter.invert(double amount)` — Share of inverted colors: `0` as is, `1` a negative (a dark-mode version of a black-on-white diagram).
- `ImageFilter.compose({required ImageFilter outer, required ImageFilter inner})` — [inner] applies first, then [outer] (Flutter's `ImageFilter.compose`).

### `IndexedStack` · class

Flutter's `IndexedStack`: a [Stack] that shows one child, the one at [index], and keeps the others in the page.

- `IndexedStack(…)` — Shows the child at [index] (`null`: none).
- `IndexedStack.watch(…)` — Shows the child at the index [source] returns (a `ThorState` method returning `int?`), kept current in the browser.

### `IndexedWidgetBuilder` · typedef

Flutter's `IndexedWidgetBuilder`: builds the widget at `index`.


### `IntrinsicColumnWidth` · class

Flutter's `IntrinsicColumnWidth`: as wide as its widest cell; with [flex], also a share of the width left over.

- `IntrinsicColumnWidth({double? flex})` — A column as wide as its content.

### `LazyLayout` · class

Skips the layout and paint of [child] while it is off screen (`content-visibility: auto`), the page-level version of `ListView(lazyLayout: true)`. [extentEstimate] is its height until it is first rendered (then the browser remembers the real one).

- `LazyLayout({Key? key, double extentEstimate = 600, required Widget child})` — Renders `child` only when it nears the viewport.

### `Length` · class

A CSS length: what a web layout needs beyond Flutter's logical pixels (`double`), like the window's height or a share of the parent.

- `Length.px(double value)` — Logical pixels (`px`); `double.infinity` is the full width (`100%`), as in `SizedBox(width: double.infinity)`.
- `Length.percent(double value)` — A share of the parent's size (`%`).
- `Length.em(double value)` — Times the element's font size (`em`).
- `Length.rem(double value)` — Times the page's root font size (`rem`).
- `Length.ch(double value)` — Times the width of the `0` glyph (`ch`): a line of about N characters.
- `Length.vw(double value)` — Percent of the window's width (`vw`).
- `Length.vh(double value)` — Percent of the window's height (`vh`).
- `Length.dvh(double value)` — Percent of the window's height as it is now (`dvh`: follows a phone's browser bars showing and hiding).
- `Length.svh(double value)` — Percent of the window's smallest height (`svh`: with the phone's browser bars shown).
- `Length.lvh(double value)` — Percent of the window's largest height (`lvh`: with the phone's browser bars hidden).
- `Length.cqw(double value)` — Percent of the nearest size container's width (`cqw`; the container is an element with `container-type`, see `StyleProps(containerType:)`).
- `Length.cqh(double value)` — Percent of the nearest size container's height (`cqh`); the container needs `ContainerType.size`.
- `Length.cqi(double value)` — Percent of the nearest container's inline size (`cqi`).
- `Length.cqb(double value)` — Percent of the nearest container's block size (`cqb`).
- `Length.cqmin(double value)` — Percent of the smaller of the container's width and height (`cqmin`).
- `Length.cqmax(double value)` — Percent of the larger of the container's width and height (`cqmax`).
- `Length.variable(CssVariable<Length> variable, {Length? fallback})` — A theme or page variable (`var(--name)`), with the length to use where it isn't defined.
- `Length.min(List<Length> values)` — The smallest of [values] (`min()`).
- `Length.max(List<Length> values)` — The largest of [values] (`max()`).
- `Length.clamp(Length min, Length preferred, Length max)` — [preferred], kept between [min] and [max] (`clamp()`): a size that follows the window within limits, and a `const` one.

### `LengthUnits` · extension

The units as number extensions: `16.px`, `50.percent`, `100.dvh`.


### `ListView` · class

Flutter's `ListView` (children, `.builder` and `.separated`).

- `ListView(…)` — Creates a list view from an explicit list of [children].
- `ListView.builder(…)` — Creates a list view that builds [itemCount] items lazily with [itemBuilder].
- `ListView.separated(…)` — Same as [ListView.builder], with a [separatorBuilder] between items.

### `MainAxisAlignment` · enum

Flutter's `MainAxisAlignment` → `justify-content`.

- values: `start`, `end`, `center`, `spaceBetween`, `spaceAround`, `spaceEvenly`

### `MainAxisSize` · enum

Flutter's `MainAxisSize`.

- values: `min`, `max`

### `MaterialTapTargetSize` · enum

Flutter's `MaterialTapTargetSize`: how big the touch area around a Material control is.

- values: `padded`, `shrinkWrap`

### `Matrix4` · class

Flutter's `Matrix4` (the subset a CSS transform needs): a 4x4 matrix in column-major order that compiles to `matrix()` / `matrix3d()`.

- `Matrix4.identity()` — The identity matrix (no transform).
- `Matrix4.fromList(List<double> values)` — A matrix from 16 [values] in column-major order, like Flutter's `Matrix4.fromList`.
- `Matrix4.translationValues(double x, double y, double z)` — Moves by `(x, y, z)` logical pixels.
- `Matrix4.diagonal3Values(double x, double y, double z)` — Scales by `(x, y, z)` (a diagonal matrix).
- `Matrix4.rotationZ(double radians)` — Rotates around the z axis by [radians] (what a 2D rotation is).
- `Matrix4.rotationX(double radians)` — Rotates around the x axis by [radians].
- `Matrix4.rotationY(double radians)` — Rotates around the y axis by [radians].

### `MaxColumnWidth` · class

Flutter's `MaxColumnWidth`: the larger of two widths (`MaxColumnWidth(FixedColumnWidth(120), FlexColumnWidth())`: a flex column never under 120).

- `MaxColumnWidth(TableColumnWidth a, TableColumnWidth b)` — The larger of [a] and [b].

### `MinColumnWidth` · class

Flutter's `MinColumnWidth`: the smaller of two widths (`MinColumnWidth(FixedColumnWidth(320), FractionColumnWidth(0.5))`).

- `MinColumnWidth(TableColumnWidth a, TableColumnWidth b)` — The smaller of [a] and [b].

### `NeverScrollableScrollPhysics` · class

Flutter's `NeverScrollableScrollPhysics`. `// web:` the view clips its overflow (`overflow: hidden`) instead of scrolling, and is not a tab stop.

- `NeverScrollableScrollPhysics()` — Creates physics that Flutter would not let scroll.

### `NullableIndexedWidgetBuilder` · typedef

Flutter's `NullableIndexedWidgetBuilder`: like [IndexedWidgetBuilder], but it may return null to say there are no more items (what ends a [ListView.builder] with no `itemCount`).


### `Offset` · class

Flutter's `Offset`.

- `Offset(double dx, double dy)` — Creates an offset from [dx]/[dy] displacement in logical pixels.

### `Overflow` · enum

What a box does with content bigger than itself, on one axis (`overflow-x` / `overflow-y`). `// web:` Flutter clips with `Clip` and scrolls with a scroll view; CSS decides it per box.

- values: `visible`, `hidden`, `clip`, `scroll`, `auto`

### `OverflowWrap` · enum

Whether a word too long for its line may break (`overflow-wrap`).

- values: `normal`, `breakWord`, `anywhere`

### `Padding` · class

Flutter's `Padding`.

- `Padding({Key? key, required EdgeInsetsGeometry padding, Widget? child})` — Creates a widget that insets [child] by [padding].

### `PageView` · class

Flutter's `PageView`: swipeable full-size pages that snap into place.

- `PageView(…)` — Creates a page view of [children].
- `PageView.builder(…)` — Creates a page view whose pages [itemBuilder] builds, [itemCount] of them.

### `Positioned` · class

Flutter's `Positioned`. Decorates the child element; no extra node.

- `Positioned(…)` — Positions `child` inside its `Stack`.
- `Positioned.fill({Key? key, double? left = 0, double? top = 0, double? right = 0, double? bottom = 0, required Widget child})` — Pins `child` to all four edges of its `Stack`.

### `Radius` · class

Flutter's `Radius`.

- `Radius.circular(double radius)` — Creates a circular radius of [radius] on both axes.
- `Radius.elliptical(double x, double y)` — Creates an elliptical radius with independent [x]/[y] values.
- `Radius.circularLength(Length length)` — A circular radius of [length]: a CSS variable the browser keeps current, a percentage, a `calc()`.

### `Ratio` · class

A plain number the browser computes: how many times one length fits in another (`StyleProps(scaleRatio:)`).

- `Ratio.of(Length numerator, Length denominator)` — [numerator] divided by [denominator] (`tan(atan2(…))`).
- `Ratio.value(double value)` — A fixed number (`1`).
- `Ratio.min(List<Ratio> values)` — The smallest of [values] (`min()`).
- `Ratio.max(List<Ratio> values)` — The largest of [values] (`max()`).

### `Resize` · enum

Which axes the reader may resize a box on (`resize`).

- values: `none`, `both`, `horizontal`, `vertical`

### `Row` · class

Flutter's `Row`.

- `Row(…)` — Creates a horizontal Flex.

### `SafeArea` · class

Flutter's `SafeArea` → `env(safe-area-inset-*)` (notches, home indicator). Requires `<meta name="viewport" content="…, viewport-fit=cover">`.

- `SafeArea({Key? key, bool left = true, bool top = true, bool right = true, bool bottom = true, EdgeInsets minimum = EdgeInsets.zero, required Widget child})` — Pads [child] away from unsafe screen areas on the given sides.

### `Scaffold` · class

Flutter's `Scaffold`, as a semantic page grid: `header` (appBar) / `main` (body) / `footer` (bottomNavigationBar), at least one viewport tall (`100dvh`, correct on mobile browsers).

- `Scaffold(…)` — Creates a page scaffold.

### `ScrollPhysics` · class

Scrolling behavior of a scroll view (Flutter's `ScrollPhysics`).

- `ScrollPhysics()` — Creates the default physics.

### `ScrollSnapAlign` · enum

Where a child of a snapping scroller rests (`scroll-snap-align`).

- values: `none`, `start`, `center`, `end`

### `ScrollSnapStrictness` · enum

How strictly a scroll lands on the snap points.

- values: `mandatory`, `proximity`

### `ScrollSnapType` · class

A scroller that snaps to its children (`scroll-snap-type`): what Flutter's `PageScrollPhysics` does.

- `ScrollSnapType(Axis axis, {ScrollSnapStrictness strictness = ScrollSnapStrictness.mandatory})` — Snaps along [axis].

### `ScrollTargetGroup` · enum

Whether the links to the children of a box mark the one in view as current (`scroll-target-group`: the browser's own scroll spy).

- values: `none`, `auto`

### `ScrollbarWidth` · enum

How much room the scrollbar takes (`scrollbar-width`).

- values: `auto`, `thin`, `none`

### `SingleChildScrollView` · class

Flutter's `SingleChildScrollView` → native `overflow: auto` (the browser does the scrolling, momentum, scrollbars and a11y).

- `SingleChildScrollView(…)` — Creates a scroll view around [child].

### `Size` · class

Flutter's `Size`: a width and a height in logical pixels.

- `Size(double width, double height)` — A size of [width] × [height].
- `Size.square(double dimension)` — A square of [dimension].
- `Size.fromWidth(double width)` — Only a width (the height is unconstrained).
- `Size.fromHeight(double height)` — Only a height (the width is unconstrained).

### `SizedBox` · class

Flutter's `SizedBox`. `double.infinity` maps to `100%`.

- `SizedBox({Key? key, double? width, double? height, Length? widthLength, Length? heightLength, Widget? child})` — Creates a box with a fixed [width] and [height].
- `SizedBox.expand({Key? key, Widget? child})` — Creates a box that fills the available space.
- `SizedBox.shrink({Key? key, Widget? child})` — Creates a box with zero width and height.
- `SizedBox.square({Key? key, double? dimension, Widget? child})` — Creates a box with `width` and `height` both set to [dimension].

### `SkipLinkProvided` · class

Tells the [Scaffold]s below that the page already has a skip link (the first Tab stop, to its `<main>`): they do not add theirs. A layout that draws its own (`StudioScaffold`) wraps its page in this.

- `SkipLinkProvided({Key? key, required Widget child})` — Marks [child] as a page that has its own skip link.

### `SliverChildBuilder` · typedef

Flutter's `IndexedWidgetBuilder`-like callback of a sliver delegate: builds the widget at `index`, or null when there are no more.


### `SliverChildBuilderDelegate` · class

Flutter's `SliverChildBuilderDelegate`: [childCount] items made by [builder].

- `SliverChildBuilderDelegate(SliverChildBuilder builder, {int? childCount, bool addAutomaticKeepAlives = true, bool addRepaintBoundaries = true, bool addSemanticIndexes = true})` — Creates a delegate that builds its items with [builder].

### `SliverChildDelegate` · abstract class

Flutter's `SliverChildDelegate`: where a sliver list or grid gets its items. [SliverChildBuilderDelegate] and [SliverChildListDelegate] are the two Flutter has.

- `SliverChildDelegate()` — Creates a delegate.

### `SliverChildListDelegate` · class

Flutter's `SliverChildListDelegate`: an explicit list of [children].

- `SliverChildListDelegate(List<Widget> children, {bool addAutomaticKeepAlives = true, bool addRepaintBoundaries = true, bool addSemanticIndexes = true})` — Creates a delegate over [children].

### `SliverFillRemaining` · class

Flutter's `SliverFillRemaining`: a box that takes what is left of the view after the slivers before it (all of it, if they are shorter).

- `SliverFillRemaining({Key? key, Widget? child, bool hasScrollBody = true, bool fillOverscroll = false})` — Creates a box that fills the rest of the view.

### `SliverFixedExtentList` · class

Flutter's `SliverFixedExtentList`: like [SliverList], every item [itemExtent] tall.

- `SliverFixedExtentList({Key? key, required SliverChildDelegate delegate, required double itemExtent})` — Creates a list of the items [delegate] makes, each [itemExtent] tall.
- `SliverFixedExtentList.builder({Key? key, required NullableIndexedWidgetBuilder itemBuilder, required double itemExtent, int? itemCount})` — Creates a list of [itemCount] items made by [itemBuilder].

### `SliverGrid` · class

Flutter's `SliverGrid`: a grid of tiles inside a [CustomScrollView], laid out by a [SliverGridDelegate] (the browser's CSS grid, see [GridView]).

- `SliverGrid({Key? key, required SliverChildDelegate delegate, required SliverGridDelegate gridDelegate})` — Creates a grid of the tiles [delegate] makes, laid out by [gridDelegate].
- `SliverGrid.builder({Key? key, required SliverGridDelegate gridDelegate, required IndexedWidgetBuilder itemBuilder, int? itemCount})` — Creates a grid of [itemCount] tiles made by [itemBuilder].
- `SliverGrid.count({Key? key, required int crossAxisCount, double mainAxisSpacing = 0, double crossAxisSpacing = 0, double childAspectRatio = 1, List<Widget> children = const []})` — Creates a grid of [children] with a fixed [crossAxisCount] of columns.
- `SliverGrid.extent(…)` — Creates a grid of [children] with as many columns as fit [maxCrossAxisExtent].

### `SliverGridDelegate` · abstract class

Flutter's `SliverGridDelegate`: how a [GridView] lays out its tiles. [SliverGridDelegateWithFixedCrossAxisCount] and [SliverGridDelegateWithMaxCrossAxisExtent] are the two that map to CSS grid.

- `SliverGridDelegate()` — Creates a grid delegate.

### `SliverGridDelegateWithFixedCrossAxisCount` · class

A grid with a fixed number of columns (`GridView.count`'s CSS: `repeat(n, minmax(0, 1fr))`).

- `SliverGridDelegateWithFixedCrossAxisCount(…)` — Creates a delegate with [crossAxisCount] columns.

### `SliverGridDelegateWithMaxCrossAxisExtent` · class

A grid whose tiles are at most [maxCrossAxisExtent] wide: like Flutter's `getLayout`, `ceil(width / (max + crossAxisSpacing))` columns (a 360px phone with `max: 200` gets two), counted by container-query steps.

- `SliverGridDelegateWithMaxCrossAxisExtent(…)` — Creates a delegate with tiles about [maxCrossAxisExtent] wide.

### `SliverList` · class

Flutter's `SliverList`: items stacked down a `CustomScrollView`.

- `SliverList({Key? key, required SliverChildDelegate delegate})` — Creates a list of the items [delegate] makes.
- `SliverList.builder({Key? key, required NullableIndexedWidgetBuilder itemBuilder, int? itemCount})` — Creates a list of [itemCount] items made by [itemBuilder].
- `SliverList.list({Key? key, required List<Widget> children})` — Creates a list of [children].
- `SliverList.separated({Key? key, required NullableIndexedWidgetBuilder itemBuilder, required IndexedWidgetBuilder separatorBuilder, int? itemCount})` — Creates a list of [itemCount] items with a separator between each.

### `SliverPadding` · class

Flutter's `SliverPadding`: space around a [sliver].

- `SliverPadding({Key? key, required EdgeInsetsGeometry padding, Widget? sliver})` — Creates padding around [sliver].

### `SliverToBoxAdapter` · class

Flutter's `SliverToBoxAdapter`: an ordinary widget inside a `CustomScrollView`.

- `SliverToBoxAdapter({Key? key, Widget? child})` — Creates an adapter around [child].

### `Spacer` · class

Flutter's `Spacer`.

- `Spacer({Key? key, int flex = 1})` — Creates a flexible empty space.

### `SplitPane` · class

Two panes with a draggable divider between them: the editors' split view.

- `SplitPane(…)` — Creates a split view of [first] and [second].

### `Stack` · class

Flutter's `Stack`.

- `Stack({Key? key, AlignmentGeometry alignment = Alignment.topLeft, StackFit fit = StackFit.loose, Clip clipBehavior = Clip.hardEdge, List<Widget> children = const []})` — Creates a stack.

### `StackFit` · enum

Flutter's `StackFit`.

- values: `loose`, `expand`, `passthrough`

### `Table` · class

Flutter's `Table` → a native `<table>`.

- `Table(…)` — Creates a table.

### `TableBorder` · class

Flutter's `TableBorder`: the lines of a [Table], outside and between its rows and columns.

- `TableBorder(…)` — The lines of a table; each defaults to none.
- `TableBorder.all({Color color = const Color(0xFF000000), double width = 1, BorderStyle style = BorderStyle.solid, BorderRadius borderRadius = BorderRadius.zero})` — The same line around and inside the table.
- `TableBorder.symmetric({BorderSide inside = BorderSide.none, BorderSide outside = BorderSide.none, BorderRadius borderRadius = BorderRadius.zero})` — One line inside, another around.

### `TableCell` · class

Flutter's `TableCell`: a cell of a [Table] with its own vertical alignment.

- `TableCell({Key? key, TableCellVerticalAlignment? verticalAlignment, required Widget child})` — Places [child] in its row by [verticalAlignment] (null: the table's default).

### `TableCellVerticalAlignment` · enum

Flutter's `TableCellVerticalAlignment`: where a cell sits in its row.

- values: `top`, `middle`, `bottom`, `baseline`, `fill`, `intrinsicHeight`

### `TableColumnWidth` · abstract class

Flutter's `TableColumnWidth`: how wide a column of a [Table] is.

- `TableColumnWidth()` — Const constructor for subclasses.

### `TableRow` · class

Flutter's `TableRow`: the cells of one row of a [Table].

- `TableRow({Key? key, BoxDecoration? decoration, List<Widget> children = const []})` — A row of [children] cells, painted with [decoration] behind them.

### `TextBaseline` · enum

Flutter's `TextBaseline`: which baseline `CrossAxisAlignment.baseline` lines children up on.

- values: `alphabetic`, `ideographic`

### `TextDirection` · enum

Flutter's `TextDirection` (in a `Row`, the order of its children).

- values: `ltr`, `rtl`

### `TextWrap` · enum

How lines break (`text-wrap`).

- values: `wrap`, `nowrap`, `balance`, `pretty`

### `Transition` · class

One property animating to its new value (`transition`): what `AnimatedContainer` does with a duration and a curve, as one CSS declaration the browser runs.

- `Transition(String property, Duration duration, {Curve curve = Curves.ease, Duration delay = Duration.zero})` — Animates [property] over [duration].

### `VerticalAlign` · enum

An inline box against its line (`vertical-align`).

- values: `baseline`, `top`, `middle`, `bottom`, `sub`, `superscript`

### `VerticalDirection` · enum

Flutter's `VerticalDirection`: the order a `Column` stacks its children.

- values: `up`, `down`

### `VerticalDivider` · class

Flutter's `VerticalDivider`. Its defaults come from `ThemeData.dividerTheme`.

- `VerticalDivider({Key? key, double? width, double? thickness, double? indent, double? endIndent, Color? color})` — Creates a vertical divider.

### `VisualDensity` · class

Flutter's `VisualDensity`: how compact a control's layout is. Each step of [horizontal]/[vertical] moves its minimum size by 4 logical pixels ([baseSizeAdjustment]); negative is denser.

- `VisualDensity({double horizontal = 0.0, double vertical = 0.0})` — A density; 0 on both axes is [standard].

### `Wrap` · class

Flutter's `Wrap` → `flex-wrap` with `gap`.

- `Wrap(…)` — Creates a widget that lays children out and wraps onto new lines.

### `WrapAlignment` · enum

Flutter's `WrapAlignment` → `justify-content` / `align-content`.

- values: `start`, `end`, `center`, `spaceBetween`, `spaceAround`, `spaceEvenly`

### `WrapCrossAlignment` · enum

Flutter's `WrapCrossAlignment` → `align-items`.

- values: `start`, `end`, `center`

## `texto` · Text, icons and images

### `DefaultTextStyle` · class

Flutter's `DefaultTextStyle`.

- `DefaultTextStyle({Key? key, required TextStyle style, TextAlign? textAlign, bool? softWrap, TextOverflow? overflow, int? maxLines, required Widget child})` — Creates a widget that establishes a default text style for its descendants.
- `DefaultTextStyle.merge({Key? key, TextStyle? style, TextAlign? textAlign, bool? softWrap, TextOverflow? overflow, int? maxLines, required Widget child})` — Flutter's `DefaultTextStyle.merge`: a default that is added to the ones above it.

### `FontFeature` · class

Flutter's `FontFeature`: an OpenType feature of the font (`font-feature-settings`).

- `FontFeature(String feature, [int value = 1])` — Feature [feature] (a four-letter tag) set to [value].
- `FontFeature.enable(String feature)` — Turns [feature] on.
- `FontFeature.disable(String feature)` — Turns [feature] off.
- `FontFeature.tabularFigures()` — Digits of equal width, for columns of figures (`tnum`).
- `FontFeature.proportionalFigures()` — Digits of their natural width (`pnum`).
- `FontFeature.oldstyleFigures()` — Old-style digits (`onum`).
- `FontFeature.liningFigures()` — Lining digits (`lnum`).
- `FontFeature.slashedZero()` — A zero with a slash (`zero`).

### `FontStyle` · enum

Flutter's `FontStyle`.

- values: `normal`, `italic`

### `FontVariation` · class

Flutter's `FontVariation`: a value on one axis of a variable font (`font-variation-settings`), such as the optical size of an icon font.

- `FontVariation(String axis, double value)` — Axis [axis] (a four-letter tag) set to [value].
- `FontVariation.italic(double value)` — Italic or not (`ital`): 0 upright, 1 italic.
- `FontVariation.opticalSize(double value)` — The size the glyphs are drawn for (`opsz`), in points.
- `FontVariation.slant(double value)` — The slant of the glyphs (`slnt`), in degrees counterclockwise.
- `FontVariation.width(double value)` — The width of the glyphs (`wdth`), in percent of the normal width.
- `FontVariation.weight(double value)` — The weight of the glyphs (`wght`), from 1 to 1000.

### `FontWeight` · class

Flutter's `FontWeight`: the nine named weights, or any value from 1 to 1000 for a variable font (`FontWeight(650)`), as in current Flutter.

- `FontWeight(int value)` — A weight of [value], from 1 (thinnest) to 1000 (heaviest); the CSS `font-weight` number. A static font draws the nearest weight it has.

### `HtmlPolicy` · class

What [sanitizeHtml] lets through.

- `HtmlPolicy(…)` — Creates a policy; every value has a safe default.

### `HtmlWidget` · class

HTML you do not control (a catalog description, a CMS body, a comment) as safe markup, styled with the theme.

- `HtmlWidget(String html, {Key? key, HtmlPolicy policy = const HtmlPolicy()})` — Shows [html] sanitized with [policy].

### `Icon` · class

Flutter's `Icon`: a glyph from an icon font, sized as a square box.

- `Icon(IconData icon, {Key? key, double? size, Color? color, String? semanticLabel})` — Creates an icon glyph.

### `IconButton` · class

Flutter's `IconButton`: a real `<button>`, 48×48 touch target with a circular hover/press highlight. With [href] a link that looks the same.

- `IconButton(…)` — Creates an icon button.
- `IconButton.filled(…)` — Flutter's `IconButton.filled`: on a primary fill, for a high emphasis.
- `IconButton.filledTonal(…)` — Flutter's `IconButton.filledTonal`: on a secondary container fill.
- `IconButton.outlined(…)` — Flutter's `IconButton.outlined`: with a 1 px outline.

### `IconData` · class

Flutter's `IconData`, in two flavors:

- `IconData(int codePoint, {required String fontFamily, bool matchTextDirection = false})` — Creates a font-glyph icon from a font's [codePoint] and [fontFamily].
- `IconData.svg(String svgId, String svgBody, {String viewBox = '0 0 24 24', double? strokeWidth, int? codePoint, String? fontFamily, bool matchTextDirection = false})` — Creates an SVG icon with a unique sprite [svgId] and inline [svgBody] markup.

### `Icons` · abstract class

Flutter's `Icons`: 8757 Material icons by name, as SVG icons (`Icon(Icons.search)`), each with its `_outlined`, `_rounded` and `_sharp` variants.

- `Icons()`

### `Iframe` · class

Another page inside this one: a web-only widget (Flutter has no equivalent; the nearest is `HtmlElementView`, which also hosts a browser element) that renders an `<iframe>`.

- `Iframe(…)` — Frames the page at [src] (or the document [srcdoc]).

### `IframeSandbox` · enum

The `sandbox` tokens of an [Iframe]: what the framed page may still do. An [Iframe] with no `sandbox` set has no restrictions; an empty set restricts everything.

- values: `forms`, `modals`, `popups`, `sameOrigin`, `scripts`, `downloads`, `topNavigationByUserActivation`

### `Image` · class

Flutter's `Image` (`.network` / `.asset`) → `<img>`.

- `Image.network(…)` — Creates an image from the URL [src].
- `Image.asset(…)` — [name] is resolved relative to the site root, e.g. `images/logo.png`.

### `ImageChunkEvent` · class

Flutter's `ImageChunkEvent`: how much of an image has arrived.

- `ImageChunkEvent({required int cumulativeBytesLoaded, int? expectedTotalBytes})` — Creates a progress report.

### `ImageEntry` · class

One image: its intrinsic size and the files the build made from it.

- `ImageEntry({required int width, required int height, required String src, List<ImageVariant> variants = const []})` — An image [width]×[height] px whose fallback is [src].

### `ImageErrorWidgetBuilder` · typedef

Flutter's `ImageErrorWidgetBuilder`: the widget shown when the image fails to load.


### `ImageLoadError` · class

What `Image(errorBuilder:)` receives as its `error`: the browser reports that the image failed, not why (a 404, a network error and an invalid file look the same).

- `ImageLoadError(String url)` — An image that failed to load from [url].

### `ImageLoadingBuilder` · typedef

Flutter's `ImageLoadingBuilder`: the widget shown while the image loads.


### `ImageManifest` · class

Every image a build knows, by the name `Image.asset` uses.

- `ImageManifest(Map<String, ImageEntry> images)` — A manifest with [images].
- `ImageManifest.fromJson(Object? json)` — Reads the JSON the build writes. A shape it doesn't know throws a [FormatException] naming the entry.

### `ImageVariant` · class

A file the build made from an image: [width] px wide, of [type].

- `ImageVariant({required int width, required String type, required String src})` — A variant at [src].

### `InlineSpan` · abstract class

Flutter's `InlineSpan`.

- `InlineSpan()` — Creates an inline span.

### `RatioText` · class

A number the browser computes, written as text: a [Ratio] (the scale of a canvas, a share of its container) times [scale], as whole digits, then [suffix].

- `RatioText(Ratio ratio, {Key? key, double scale = 100, String suffix = '%', TextStyle? style, String? semanticsLabel})` — The [ratio] times [scale] (`100`: a percentage), then [suffix].

### `RichText` · class

Flutter's `RichText`: a tree of [InlineSpan]s.

- `RichText({Key? key, required InlineSpan text, TextAlign? textAlign, bool softWrap = true, TextOverflow? overflow, int? maxLines})` — Creates a paragraph of styled spans.

### `SelectableText` · class

Flutter's `SelectableText`: text the person can select and copy.

- `SelectableText(String data, {Key? key, TextStyle? style, TextAlign? textAlign, int? maxLines, String? semanticsLabel})` — Creates selectable text from a plain string.
- `SelectableText.rich(InlineSpan textSpan, {Key? key, TextStyle? style, TextAlign? textAlign, int? maxLines, String? semanticsLabel})` — Creates selectable text from a tree of [InlineSpan]s.

### `Shadow` · class

Flutter's `Shadow` (text shadow).

- `Shadow({Color color = const Color(0xFF000000), Offset offset = Offset.zero, double blurRadius = 0})` — Creates a text shadow, defaulting to an opaque black shadow with no offset or blur.

### `Text` · class

Flutter's `Text`.

- `Text(String data, {Key? key, TextStyle? style, TextAlign? textAlign, bool? softWrap, TextOverflow? overflow, int? maxLines, String? semanticsLabel})` — Creates a text widget from a plain string.
- `Text.rich(InlineSpan textSpan, {Key? key, TextStyle? style, TextAlign? textAlign, bool? softWrap, TextOverflow? overflow, int? maxLines, String? semanticsLabel})` — Creates a text widget from a tree of [InlineSpan]s.

### `TextAlign` · enum

Flutter's `TextAlign`.

- values: `left`, `right`, `center`, `justify`, `start`, `end`

### `TextDecoration` · class

Flutter's `TextDecoration` (combinable).

- `TextDecoration.combine(List<TextDecoration> decorations)` — Combines several decorations into one (e.g. underline + line-through).

### `TextDecorationStyle` · enum

Flutter's `TextDecorationStyle`.

- values: `solid`, `double`, `dotted`, `dashed`, `wavy`

### `TextOverflow` · enum

Flutter's `TextOverflow`.

- values: `clip`, `fade`, `ellipsis`, `visible`

### `TextSpan` · class

Flutter's `TextSpan`. [onTap] is a web convenience replacing `recognizer: TapGestureRecognizer()..onTap`.

- `TextSpan({String? text, TextStyle? style, List<InlineSpan>? children, void Function()? onTap, String? semanticsLabel, String? href, bool newTab = false})` — Creates a run of text with its own style.

### `TextStyle` · class

Flutter's `TextStyle`. All fields are optional and inherit through the DOM exactly like Flutter's `DefaultTextStyle` does, because CSS font properties are inherited.

- `TextStyle(…)` — Creates a text style. Every field is optional and unset fields inherit through the DOM.

### `TextThemeRole` · enum

The roles of Flutter's `TextTheme`: what a [TextStyle.role] names.

- values: `displayLarge`, `displayMedium`, `displaySmall`, `headlineLarge`, `headlineMedium`, `headlineSmall`, `titleLarge`, `titleMedium`, `titleSmall`, `bodyLarge`, `bodyMedium`, `bodySmall`, `labelLarge`, `labelMedium`, `labelSmall`

### `WidgetSpan` · class

Flutter's `WidgetSpan`: embeds any component inline.

- `WidgetSpan({required Widget child})` — Creates an inline span that embeds [child].

### `sanitizeHtml` · function

[source] as HTML that is safe to put in a page: parsed with the HTML5 algorithm (the browser's own, so what is checked is what the browser will build), walked against [policy], and written back by this function (not by the parser), so the output never depends on how a browser re-parses it.

- `String sanitizeHtml(String source, {HtmlPolicy policy = const HtmlPolicy()})`

## `controles` · Controls, forms and gestures

### `Action` · abstract class

Flutter's `Action`: what an intent does. In the page, a [CallbackAction] (a method of a `ThorState`) or a [DoNothingAction].

- `Action<T>()` — An action.

### `Actions` · class

Flutter's `Actions`: what each intent type does for the shortcuts of the focus inside [child] (see [Shortcuts]).

- `Actions({Key? key, required Map<Type, Action<Intent>> actions, required Widget child})` — The actions for the intents of `child`.

### `AriaAttribute` · enum

A WAI-ARIA state or property: `aria-<name>`.

- values: `activedescendant`, `atomic`, `autocomplete`, `busy`, `checked`, `colcount`, `colindex`, `colspan`, `controls`, `current`, `describedby`, `details`, `disabled`, `errormessage`, `expanded`, `haspopup`, `hidden`, `invalid`, `keyshortcuts`, `label`, `labelledby`, `level`, `live`, `modal`, `multiline`, `multiselectable`, `orientation`, `owns`, `placeholder`, `posinset`, `pressed`, `readonly`, `relevant`, `required`, `roledescription`, `rowcount`, `rowindex`, `rowspan`, `selected`, `setsize`, `sort`, `valuemax`, `valuemin`, `valuenow`, `valuetext`

### `AttributeName` · extension type

The name of an HTML attribute that a state value can bind to (`WatchAttributes`, `row.attribute`): the common ones as constants, the rest from [AttributeName.ariaOf] and [AttributeName.data].

- `AttributeName(String name)`
- `AttributeName.data(String key)` — `data-<key>`: [key] is lowercase letters, digits and `-`.

### `Autocomplete` · class

Flutter's `Autocomplete<T>` (Material): a text field that suggests [optionsBuilder]'s options as the visitor types, in a panel under it.

- `Autocomplete<T>(…)` — Creates an autocomplete.

### `AutocompleteFieldViewBuilder` · typedef

Flutter's `AutocompleteFieldViewBuilder`: the field widget.


### `AutocompleteOnSelected` · typedef

Flutter's `AutocompleteOnSelected`.


### `AutocompleteOptionToString` · typedef

Flutter's `AutocompleteOptionToString`: the text of an option.


### `AutocompleteOptionsBuilder` · typedef

Flutter's `AutocompleteOptionsBuilder`: the options for what the field holds.


### `AutocompleteOptionsViewBuilder` · typedef

Flutter's `AutocompleteOptionsViewBuilder`: the widget that shows the [options] and calls [onSelected] for the one the visitor picks.


### `AutofillContextAction` · enum

Flutter's `AutofillContextAction`: what happens to the autofill data of an [AutofillGroup] when it goes away.

- values: `commit`, `cancel`

### `AutofillGroup` · class

Flutter's `AutofillGroup`: the fields inside are one group for the browser's autofill and password manager (a login's username and password).

- `AutofillGroup({Key? key, required Widget child, AutofillContextAction onDisposeAction = AutofillContextAction.commit, String? section})` — Creates a group of autofillable fields.

### `AutofillHints` · abstract class

Flutter's `AutofillHints`: the names for `TextField.autofillHints`. They go to the browser as their HTML `autocomplete` token (Flutter's own mapping for the web); a string that is not one of these (`shipping`, `home`, `off`) goes as it is, so an HTML token works too.

- `AutofillHints()`

### `BooleanAttribute` · enum

An HTML attribute that is on or off: written bare when on, left out when off.

- values: `autofocus`, `checked`, `disabled`, `hidden`, `inert`, `multiple`, `open`, `readonly`, `required`, `selected`

### `ButtonSegment` · class

Flutter's `ButtonSegment<T>`: one choice of a [SegmentedButton].

- `ButtonSegment<T>({required T value, Widget? icon, Widget? label, String? tooltip, bool enabled = true})` — A segment that stands for [value]. It needs an [icon], a [label] or both; give an icon-only segment a [tooltip], its accessible name.

### `ButtonStyle` · class

Flutter's `ButtonStyle`: overrides the variant's colors, spacing, size, shape and text. Each field is a [WidgetStateProperty], so a value can depend on the button's state (`WidgetStateProperty.resolveWith`); for plain values use `FilledButton.styleFrom(...)` and its siblings.

- `ButtonStyle(…)` — A style; null fields keep the variant's default.

### `ButtonType` · enum

What a button does inside a `<form>` (the `type` of the `<button>`).

- values: `button`, `submit`

### `CalendarDatePicker` · class

Flutter's `CalendarDatePicker`: a month grid to pick a day, with previous / next month and a year list.

- `CalendarDatePicker(…)` — Creates a calendar showing [initialDate]'s month (or today's).

### `CallbackAction` · class

Flutter's `CallbackAction`: [onInvoke] runs when its intent is invoked.

- `CallbackAction<T>({required Object? Function(T) onInvoke})` — Runs [onInvoke] for the intent.

### `CallbackShortcuts` · class

Flutter's `CallbackShortcuts`: key presses inside [child] (while the focus is in it) call methods of a `ThorState`.

- `CallbackShortcuts({Key? key, required Map<ShortcutActivator, void Function()> bindings, void Function(String)? onCharacter, required Widget child})` — Calls `bindings[activator]` when its keys are pressed inside `child`.

### `CharacterActivator` · class

Flutter's `CharacterActivator`: the key press that types [character] (whatever keys the layout needs for it: `?` is Shift+/ on a US keyboard), with exactly these modifiers. Shift is not checked (it is part of the character).

- `CharacterActivator(…)` — The press that types [character] with the given modifiers held.

### `Checkbox` · class

Flutter's `Checkbox`. `tristate` + `value: null` renders the indeterminate state (`aria-checked="mixed"`).

- `Checkbox(…)` — Creates a Material checkbox.

### `CheckboxListTile` · class

Flutter's `CheckboxListTile`.

- `CheckboxListTile(…)` — Creates a list tile with a checkbox.

### `Datalist` · class

The suggestions a text field offers while the user types, native and with no JS: a `<datalist>`. A field names it with `TextField(datalist: id)`.

- `Datalist({Key? key, required String id, required List<String> options})` — A list [id] with a suggestion per [options] value.

### `DatePickerDialog` · class

Flutter's `DatePickerDialog` (what `showDatePicker` shows): a Material 3 dialog with a [CalendarDatePicker], a headline with the chosen date, and Cancel / OK.

- `DatePickerDialog(…)` — Creates a date picker dialog.

### `DatePickerFormField` · class

A date field with a calendar button — what Flutter apps build from a read-only `TextFormField` whose tap awaits `showDatePicker`.

- `DatePickerFormField(…)` — Creates a date field with a picker dialog.

### `DatePickerMode` · enum

Flutter's `DatePickerMode`: what the calendar shows first.

- values: `day`, `year`

### `DatePickerTheme` · class

Flutter's `DatePickerTheme`: a [DatePickerThemeData] for the pickers below.

- `DatePickerTheme({Key? key, required DatePickerThemeData data, required Widget child})` — Applies [data] to the date pickers in [child].

### `DatePickerThemeData` · class

Flutter's `DatePickerThemeData`: how the date pickers look. Put it in `ThemeData(datePickerTheme:)`, or around a subtree with [DatePickerTheme]. Null fields keep the Material 3 defaults (the theme's color roles).

- `DatePickerThemeData(…)` — A date picker theme; null fields keep the defaults.

### `DateUtils` · abstract class

Flutter's `DateUtils` (the parts a calendar needs).

- `DateUtils()`

### `DayPeriod` · enum

Flutter's `DayPeriod`.

- values: `am`, `pm`

### `DismissDirection` · enum

The directions a [Dismissible] can be dismissed in (Flutter's `DismissDirection`).

- values: `vertical`, `horizontal`, `endToStart`, `startToEnd`, `up`, `down`, `none`

### `Dismissible` · class

Flutter's `Dismissible`: a widget that is dismissed by dragging it away.

- `Dismissible(…)` — Dismisses [child] when it is dragged away.

### `DoNothingAction` · class

Flutter's `DoNothingAction`: the intent does nothing; with [consumesKey] (the default) the key stops there, which turns off an outer shortcut inside a subtree.

- `DoNothingAction({bool consumesKey = true})` — Does nothing, and stops the key unless [consumesKey] is false.

### `Drag` · class

How an element drags: along [axis] (null: freely). With [snapBack] it returns to its place on release; otherwise it stays where it was dropped. The arrow keys move it by [step] pixels.

- `Drag({Axis? axis, bool snapBack = true, double step = 10})` — A drag setup.

### `DragAnchorStrategy` · typedef

Where the feedback of a [Draggable] starts relative to the pointer (Flutter's `DragAnchorStrategy`). Only [childDragAnchorStrategy] and [pointerDragAnchorStrategy] have an equivalent in the browser.


### `DragEffect` · enum

The `dataTransfer.effectAllowed` / `dropEffect` values: what a drop may do with what was dragged.

- values: `none`, `copy`, `copyLink`, `copyMove`, `link`, `linkMove`, `move`, `all`

### `DragEndDetails` · class

Flutter's `DragEndDetails`: how a drag ended.

- `DragEndDetails({Velocity velocity = Velocity.zero, double? primaryVelocity, Offset globalPosition = Offset.zero, Offset? localPosition})` — Details of a drag that ended at [localPosition] with [velocity].
- `DragEndDetails.fromArg(String? arg)` — What the browser reports as `vx~vy~lx~ly~gx~gy`; the page builds the details with it.

### `DragLabels` · class

The words a [Draggable] says to assistive technology (a live region). `{item}` and `{target}` stand for the draggable's and the drop target's names (their `aria-label`, or their text).

- `DragLabels({String? roleDescription, String? pickedUp, String? over, String? cannotDrop, String? dropped, String? cancelled})` — The texts; what is null comes from `ThorLocalizations`.

### `DragTarget` · class

Flutter's `DragTarget`: where a [Draggable] of the same type can be dropped.

- `DragTarget<T>(…)` — Takes the drops of a [Draggable]`<T>`.

### `DragTargetBuilder` · typedef

The look of a draggable's feedback over a target is not drawn from a list of candidates: see [DragTarget.overStyle].


### `DragUpdateDetails` · class

Flutter's `DragUpdateDetails`: how far the pointer moved since the last update.

- `DragUpdateDetails({Offset delta = Offset.zero})` — Details of a drag that moved by [delta].
- `DragUpdateDetails.fromArg(String? arg)` — What the browser reports as `dx~dy`; the page builds the details with it.

### `Draggable` · class

Flutter's `Draggable`: a widget that can be dragged to a [DragTarget].

- `Draggable<T>(…)` — Makes [child] draggable; [feedback] is what follows the pointer.

### `DropdownButton` · class

Flutter's `DropdownButton<T>` on a native `<select>`: the OS picker on mobile, full keyboard and type-ahead for free.

- `DropdownButton<T>(…)` — Creates a Material dropdown button.

### `DropdownButtonFormField` · class

Flutter's `DropdownButtonFormField<T>`: a [DropdownButton] inside the field's decoration, like `TextFormField`: [decoration]'s `labelText` is a visible `<label for>` the `<select>`, and its helper or error line sits below (the select's `aria-describedby`).

- `DropdownButtonFormField<T>(…)` — Creates a dropdown inside a decorated form field.

### `DropdownMenu` · class

Flutter's `DropdownMenu<T>` (Material 3): a button that opens a list of entries to pick one from, with type-ahead and an optional filter field. A styled select: every part takes the app's look, unlike a native `<select>` (`DropdownButton`).

- `DropdownMenu<T>(…)` — Creates a dropdown menu.

### `DropdownMenuEntry` · class

Flutter's `DropdownMenuEntry<T>`: one entry of a [DropdownMenu].

- `DropdownMenuEntry<T>({required T value, required String label, Widget? leadingIcon, Widget? trailingIcon, bool enabled = true, ButtonStyle? style, Widget? labelWidget})` — Creates an entry.

### `DropdownMenuItem` · class

Flutter's `DropdownMenuItem<T>`.

- `DropdownMenuItem<T>({required T value, required Widget child, bool enabled = true})` — Creates a dropdown menu entry.

### `DropdownMenuSelectedIcon` · class

`// web:` shows [child] only on the picked entry of a [DropdownMenu], keeping its space on the others (like the checkmark of a select menu). Put it in a [DropdownMenuEntry]'s `leadingIcon` or `trailingIcon`.

- `DropdownMenuSelectedIcon({Key? key, required Widget child})` — Wraps [child] (usually a check `Icon`).

### `ElevatedButton` · class

Flutter's `ElevatedButton`: a raised button on the surface, for the emphasis between [FilledButton] and [OutlinedButton].

- `ElevatedButton(…)` — Creates an elevated button.
- `ElevatedButton.icon(…)` — Flutter's `ElevatedButton.icon`: an [icon] before the [label].

### `FileField` · class

`// web:` a file input (`<input type="file">`): Flutter has none (apps use a plugin), the browser has a native one that works without JS. Put it in a `Form(encoding: FormEncoding.multipart)`; the server reads it with `(await request.form()).file(name)`.

- `FileField({Key? key, required String name, String? label, List<String> accept = const [], bool multiple = false, bool required = false, bool enabled = true})` — A file input named [name].

### `FilledButton` · class

Flutter's `FilledButton`.

- `FilledButton(…)` — Creates a filled button.
- `FilledButton.icon(…)` — Flutter's `FilledButton.icon`: an [icon] before the [label].
- `FilledButton.tonal(…)` — Flutter's `FilledButton.tonal`: a filled button in the secondary container's colors, for a lower emphasis than the primary fill.
- `FilledButton.tonalIcon(…)` — Flutter's `FilledButton.tonalIcon`: an [icon] before the [label].

### `FloatingActionButton` · class

Flutter's `FloatingActionButton`: the screen's main action, a raised button in the primary container's colors. Inside `Scaffold(floatingActionButton:)` it floats in the bottom corner.

- `FloatingActionButton({Key? key, required void Function()? onPressed, required Widget child, String? tooltip, Color? backgroundColor, Color? foregroundColor, String? href})` — A 56 px round-cornered button around [child] (usually an `Icon`).
- `FloatingActionButton.small({Key? key, required void Function()? onPressed, required Widget child, String? tooltip, Color? backgroundColor, Color? foregroundColor, String? href})` — A 40 px button.
- `FloatingActionButton.large({Key? key, required void Function()? onPressed, required Widget child, String? tooltip, Color? backgroundColor, Color? foregroundColor, String? href})` — A 96 px button with a 36 px icon.
- `FloatingActionButton.extended(…)` — A button with a [label] and, before it, an optional [icon].

### `FloatingLabelBehavior` · enum

Flutter's `FloatingLabelBehavior`.

- values: `never`, `auto`, `always`

### `Focus` · class

Flutter's `Focus`: makes [child]'s element able to take the keyboard focus (`tabindex`), optionally owned by a [focusNode] of a `ThorState` that moves the focus from a method (`node.requestFocus()`).

- `Focus(…)` — Wraps `child` as a focus target.

### `FocusOnKeyEventCallback` · typedef

Flutter's `FocusOnKeyEventCallback`: a key event for a [Focus] and what it did with it.


### `Form` · class

Flutter's `Form` → a native `<form>`: the browser checks every field's rules on submit (focusing the first invalid one), with or without JS.

- `Form<S>(…)` — Creates a form.

### `FormEncoding` · enum

How a [Form] encodes what it sends (its `enctype`).

- values: `urlEncoded`, `multipart`

### `FormFieldError` · class

The messages of the field [name] of the enclosing `Form`, where you put them: for a control that has no message line of its own (a `Checkbox`, a `Radio` group). Nothing when the field has no message.

- `FormFieldError(String name, {Key? key})` — The messages of [name].

### `FormMethod` · enum

The HTTP method of a [Form]'s plain-HTML submit (its `method`).

- values: `post`, `get`, `dialog`

### `FormScope` · class

What a `Form` gives the named fields below it: the values and the messages of a failed submission (`failed:`), the saved values of an edit form (`defaults:`) and the rules of its schema.

- `FormScope({Key? key, FormInvalid? failed, Map<String, Object?> defaults = const {}, FormSchema? schema, required Widget child})` — Publishes [failed], [defaults] and [schema] to [child].

### `Gesture` · class

Every touch and mouse gesture in one widget: tap, double tap, long press (hold), swipe (to dismiss), drag and pinch, plus press feedback.

- `Gesture(…)` — Wraps `child`, handling the given gestures.

### `GestureDetector` · class

Flutter's `GestureDetector`: a thin wrapper over [Gesture] with Flutter's names.

- `GestureDetector(…)` — Wraps [child], handling the given gestures.

### `HardwareKeyboard` · class

Flutter's `HardwareKeyboard`: which modifiers are held right now, for a state method that reacts to a click differently with Shift (`HardwareKeyboard.instance.isShiftPressed`).


### `HiddenField` · class

A value the form posts along with its fields and the visitor never sees: `<input type="hidden">`.

- `HiddenField({Key? key, required String name, required String value})` — Posts [name]=[value] with the enclosing form.

### `HitTestBehavior` · enum

Flutter's `HitTestBehavior`. web: accepted and not used: the element the gesture wraps is the hit target, as with [opaque].

- values: `deferToChild`, `opaque`, `translucent`

### `HtmlAttributes` · class

The attributes of one element, typed: ARIA states, `data-*`, the global attributes and the boolean ones, and a validated escape for any other name.

- `HtmlAttributes(…)` — The attributes given: [aria] (`aria-*`, a value is a `String`, `bool` or `num`), [data] (`data-<key>`), the globals [id], [title] and [tabIndex], and the [flags] that are on. [custom] adds any other attribute (see [HtmlAttributes.custom]).
- `HtmlAttributes.custom(Map<String, String> attributes)` — Any attributes by name. Each name must be a valid attribute name (letters, digits, `_`, `:`, `.`, `-`) and not an event handler (`on…`): scripts do not travel in attributes.

### `InkResponse` · class

Flutter's `InkResponse`: a tap target with hover, focus and pressed feedback.

- `InkResponse(…)` — Creates a tap target around [child].

### `InkWell` · class

Flutter's `InkWell`: [InkResponse] whose feedback fills the element (see [InkResponse] for how the web does it).

- `InkWell(…)` — Creates a tap target whose feedback fills [child].

### `InputBorder` · sealed class

Flutter's `InputBorder` family.

- `InputBorder()`

### `InputDatePickerFormField` · class

Flutter's `InputDatePickerFormField`: a field to type a date.

- `InputDatePickerFormField(…)` — Creates a date entry field.

### `InputDecoration` · class

Flutter's `InputDecoration`, subset.

- `InputDecoration(…)` — Creates the visual properties for a `TextField`.

### `InputDecorationTheme` · class

Flutter's `InputDecorationTheme`, subset: the default look of fields (`ThemeData.inputDecorationTheme`, under each field's own `InputDecoration`) and of a field that builds its own decoration (a `DropdownMenu`'s `inputDecorationTheme`).

- `InputDecorationTheme(…)` — Creates the default look of input fields.

### `Intent` · abstract class

Flutter's `Intent`: what a key press means (`SaveIntent`), apart from what it does (an action of an `Actions` widget, found by the intent's type).

- `Intent()` — An intent.

### `KeyDownEvent` · class

A key pressed.

- `KeyDownEvent({required LogicalKeyboardKey logicalKey, String? character})` — A key pressed.

### `KeyEvent` · sealed class

Flutter's `KeyEvent`: a key press, as `Focus.onKeyEvent` gets it.

- `KeyEvent({required LogicalKeyboardKey logicalKey, String? character})`

### `KeyEventResult` · enum

Flutter's `KeyEventResult`: what `Focus.onKeyEvent` did with a key.

- values: `handled`, `ignored`, `skipRemainingHandlers`

### `KeyRepeatEvent` · class

A held key, pressed again by the keyboard's auto-repeat.

- `KeyRepeatEvent({required LogicalKeyboardKey logicalKey, String? character})` — A held key's repeat.

### `KeyUpEvent` · class

A key released. `// web:` never sent to `Focus.onKeyEvent`; it is here so code from Flutter that tests `event is KeyUpEvent` compiles.

- `KeyUpEvent({required LogicalKeyboardKey logicalKey, String? character})` — A key released.

### `ListBox` · class

A list of entries always shown, of which one, or several with [multiSelectionEnabled], are chosen: a native `<select size>` (with `multiple`). No JS: the browser gives the keyboard (arrows, Home/End, type-ahead; Shift and Ctrl/Cmd to choose several), and the form sends the chosen values under [name].

- `ListBox<T>(…)` — Creates a list box over [items].

### `ListBoxItem` · class

An entry of a [ListBox]: like Flutter's `DropdownMenuItem`, a [value] and what shows it.

- `ListBoxItem<T>({required T value, required Widget child, bool enabled = true})` — Creates a list box entry.

### `ListTileControlAffinity` · enum

Where the control sits in a `*ListTile` (Flutter's `ListTileControlAffinity`).

- values: `leading`, `trailing`, `platform`

### `LogicalKeyboardKey` · class

Flutter's `LogicalKeyboardKey`: a key by what it means, not where it is. `// web:` identified by the DOM's `KeyboardEvent.key` value ([keyLabel]), so it follows the user's layout like Flutter's logical keys do.

- `LogicalKeyboardKey(String keyLabel)` — A key whose `KeyboardEvent.key` is [keyLabel].

### `LongPressDraggable` · class

Flutter's `LongPressDraggable`: a [Draggable] that starts after the pointer is held for [delay], so a touch can still scroll the page.

- `LongPressDraggable<T>(…)` — Makes [child] draggable after a hold of [delay].

### `MenuStyle` · class

Flutter's `MenuStyle` (plain values, like `ButtonStyle` here): the look of a menu's panel.

- `MenuStyle(…)` — A style; null fields keep the menu's default.

### `MouseCursor` · class

Flutter's `MouseCursor`, mapped to CSS `cursor`.


### `MouseRegion` · class

Flutter's `MouseRegion`.

- `MouseRegion({Key? key, MouseCursor? cursor, void Function()? onEnter, void Function()? onExit, required Widget child})` — Wraps `child`, applying [cursor] and pointer listeners.

### `NativeDragTarget` · class

Where a [NativeDraggable] of the same type (or a drag from outside the page that carries one of [acceptMimeTypes]) can be dropped: the browser's own drag and drop, next to [DragTarget].

- `NativeDragTarget<T>(…)` — Takes the drops of a [NativeDraggable]`<T>`.

### `NativeDraggable` · class

A widget the browser drags with its own drag and drop (HTML5, the `dataTransfer` the drop receives): web-only, next to Flutter's pointer-driven [Draggable] (Flutter has no equivalent, as its drags never leave the app).

- `NativeDraggable<T>(…)` — Makes [child] draggable with the browser's drag and drop.

### `OptionsViewOpenDirection` · enum

Flutter's `OptionsViewOpenDirection`: where the options view opens.

- values: `up`, `down`, `mostSpace`

### `OutlineInputBorder` · class

Flutter's `OutlineInputBorder`.

- `OutlineInputBorder({BorderRadius borderRadius = const BorderRadius.all(Radius.circular(4)), BorderSide borderSide = const BorderSide()})` — Creates a border that outlines the field on every side.

### `OutlinedButton` · class

Flutter's `OutlinedButton`.

- `OutlinedButton(…)` — Creates an outlined button.
- `OutlinedButton.icon(…)` — Flutter's `OutlinedButton.icon`: an [icon] before the [label].

### `Pinch` · class

How an element pinches (two fingers): between [min] and [max] times its size; `+`/`-` zoom by [step] from the keyboard.

- `Pinch({double min = 1, double max = 4, bool snapBack = false, double step = 0.25})` — A pinch setup.

### `Press` · class

Visual feedback while the element is pressed (CSS `:active`, no JS).

- `Press({double scale = 0.97, double? opacity})` — Scale to [scale] and fade to [opacity] while pressed.

### `Radio` · class

Flutter's `Radio<T>`: selected when [value] equals the value of the [RadioGroup] above it.

- `Radio<T>({Key? key, bool stateLayer = true, required T value, T? groupValue, ValueChanged<T?>? onChanged, Color? activeColor, String? name, String? semanticLabel})` — Creates a Material radio button.

### `RadioGroup` · class

Flutter's `RadioGroup<T>` (3.32+): the selection of the [Radio]s below it.

- `RadioGroup<T>({Key? key, T? groupValue, ValueChanged<T?>? onChanged = _omittedChange, ValueChanged<Set<T>>? onSelectionChanged, String? name, required Widget child})` — Creates a radio group around [child].

### `RadioListTile` · class

Flutter's `RadioListTile<T>`.

- `RadioListTile<T>(…)` — Creates a list tile with a radio button.

### `RawAutocomplete` · class

Flutter's `RawAutocomplete<T>`: a field with an options view anchored to it, drawn by you ([fieldViewBuilder], [optionsViewBuilder]). Use [Autocomplete] for the Material look.

- `RawAutocomplete<T>(…)` — Creates an autocomplete.

### `ReorderCallback` · typedef

Flutter's `ReorderCallback`: where an item came from and where it goes. [newIndex] counts the list before the item leaves, as in Flutter: moving down, subtract one.


### `ReorderItemProxyDecorator` · typedef

Flutter's `ReorderItemProxyDecorator`. Not supported (see [ReorderableListView.draggingStyle]).


### `ReorderLabels` · class

The words a [ReorderableListView] says to assistive technology (a live region). `{item}` is the item's name (its text), `{position}` its place and `{count}` how many there are.

- `ReorderLabels({String? handle, String? pickedUp, String? moved, String? dropped, String? cancelled})` — The texts; what is null comes from `ThorLocalizations`.

### `ReorderableDelayedDragStartListener` · class

Flutter's `ReorderableDelayedDragStartListener`: its child starts the drag after the pointer is held on it (a long press), so a touch can still scroll the list.

- `ReorderableDelayedDragStartListener({Key? key, required Widget child, required int index, bool enabled = true})` — Makes [child] a handle that waits for a hold.

### `ReorderableDragStartListener` · class

Flutter's `ReorderableDragStartListener`: its child starts the drag of the item it is in, at once. Place it where the handle should be, with `buildDefaultDragHandles: false`.

- `ReorderableDragStartListener({Key? key, required Widget child, required int index, bool enabled = true})` — Makes [child] a drag handle.

### `ReorderableListView` · class

Flutter's `ReorderableListView`: a list whose items are reordered by dragging.

- `ReorderableListView(…)` — A list of [children] (each one with a key in Flutter) reordered by dragging; [onReorder] hears the change.
- `ReorderableListView.builder(…)` — A list of [itemCount] items built by [itemBuilder].

### `SegmentedButton` · class

Flutter's `SegmentedButton<T>`: a row of [segments] to choose one value (or several) from.

- `SegmentedButton<T>(…)` — A control over [segments] whose chosen ones are in [selected].

### `SelectableDayPredicate` · typedef

Flutter's `SelectableDayPredicate`: whether [day] can be picked.


### `ShortcutActivator` · abstract class

Flutter's `ShortcutActivator`: what a key press must be to trigger a shortcut.

- `ShortcutActivator()`

### `Shortcuts` · class

Flutter's `Shortcuts`: key presses inside [child] (while the focus is in it) become [Intent]s, and the nearest [Actions] around the focus that has an action for the intent's type runs it.

- `Shortcuts({Key? key, required Map<ShortcutActivator, Intent> shortcuts, String? debugLabel, required Widget child})` — Maps the activators to intents inside `child`.

### `SingleActivator` · class

Flutter's `SingleActivator`: [trigger] pressed with exactly these modifiers.

- `SingleActivator(…)` — [trigger] with the given modifiers held.

### `Slider` · class

Flutter's `Slider` on `<input type=range>`.

- `Slider(…)` — Creates a Material slider.
- `Slider.watch(…)` — A slider whose value is the number [source] returns (a `ThorState` method returning `double`, or a field's `call`), kept current in the browser: the page is not rebuilt.

### `Swipe` · class

How an element swipes: along [axis]; past [threshold] (a fraction of its size, or a quick fling) the swipe counts. With [dismiss] the element flies out and fades before `onSwipe` runs, so the state can remove it (swipe to dismiss).

- `Swipe({Axis axis = Axis.horizontal, bool dismiss = false, double threshold = 0.4})` — A swipe setup.

### `SwipeDirection` · enum

Where a swipe went.

- values: `up`, `down`, `start`, `end`

### `Switch` · class

Flutter's `Switch` (Material 3): `<input type=checkbox role=switch>`.

- `Switch(…)` — Creates a Material 3 switch.

### `SwitchListTile` · class

Flutter's `SwitchListTile`.

- `SwitchListTile(…)` — Creates a list tile with a switch.

### `SystemMouseCursors` · abstract class

Flutter's `SystemMouseCursors`.

- `SystemMouseCursors()`

### `TapDownDetails` · class

Flutter's `TapDownDetails`: where the pointer went down.

- `TapDownDetails({Offset localPosition = Offset.zero})` — Details of a pointer that went down at [localPosition].
- `TapDownDetails.fromArg(String? arg)` — What the browser reports as `x~y`; the page builds the details with it.

### `TapUpDetails` · class

Flutter's `TapUpDetails`: where the pointer was released as a tap.

- `TapUpDetails({Offset localPosition = Offset.zero})` — Details of a tap that ended at [localPosition].
- `TapUpDetails.fromArg(String? arg)` — What the browser reports as `x~y`; the page builds the details with it.

### `TextButton` · class

Flutter's `TextButton`.

- `TextButton(…)` — Creates a text button.
- `TextButton.icon(…)` — Flutter's `TextButton.icon`: an [icon] before the [label].

### `TextCapitalization` · enum

Flutter's `TextCapitalization` → `autocapitalize`.

- values: `words`, `sentences`, `characters`, `none`

### `TextField` · class

Flutter's `TextField` → a native `<input>` inside a decorated row.

- `TextField(…)` — Creates a native text input field.

### `TextFormField` · class

Flutter's `TextFormField`: a [TextField] with a label, validation rules and the helper/error line below it.

- `TextFormField(…)` — Creates a labeled, validated form field.

### `TextInputAction` · enum

Flutter's `TextInputAction` → the virtual keyboard's enter key (`enterkeyhint`).

- values: `none`, `unspecified`, `done`, `go`, `search`, `send`, `next`, `previous`, `continueAction`, `join`, `route`, `emergencyCall`, `newline`

### `TextInputType` · class

Flutter's `TextInputType` → `<input type>` / `inputmode`.

- `TextInputType.numberWithOptions({bool signed, bool decimal})` — Numeric input with Flutter's options: [signed] allows a minus sign and [decimal] a decimal separator.

### `TimeOfDay` · class

Flutter's `TimeOfDay`: an hour and a minute, no date or time zone.

- `TimeOfDay({required int hour, required int minute})` — [hour] (0–23) and [minute] (0–59).
- `TimeOfDay.fromDateTime(DateTime time)` — The time of day of [time].
- `TimeOfDay.now()` — The current time of day (on the server: the server's clock).

### `TimePickerDialog` · class

Flutter's `TimePickerDialog` (what `showTimePicker` shows), in its input mode: a native `<input type="time">` in a Material 3 dialog with Cancel / OK.

- `TimePickerDialog(…)` — Creates a time picker dialog.

### `UnderlineInputBorder` · class

Flutter's `UnderlineInputBorder`.

- `UnderlineInputBorder({BorderSide borderSide = const BorderSide()})` — Creates a border that draws a line under the field.

### `Validator` · class

A validation rule of a [TextFormField].

- `Validator.all(List<Validator> rules)` — Several rules as one, in order: `validator: Validator.all([...])`.
- `Validator.required(String message)` — Field must not be empty.
- `Validator.minLength(int length, String message)` — At least [length] characters.
- `Validator.maxLength(int length, String message)` — At most [length] characters.
- `Validator.pattern(Pattern regExp, String message)` — Must match [regExp]: a `String` (a JavaScript-compatible pattern that must match the **whole** value; `const`-friendly) or a `RegExp`, what a Flutter validator writes.
- `Validator.notBlank(String message)` — Not empty and not only whitespace: Flutter's `value == null || value.trim().isEmpty`, the check nearly every required text field writes. [Validator.required] alone accepts `'   '`, like the browser's `required`.
- `Validator.email(String message)` — Must be an e-mail address (sets `type=email`).
- `Validator.min(num value, String message)` — Number not below [value] (sets `type=number`).
- `Validator.max(num value, String message)` — Number not above [value] (sets `type=number`).
- `Validator.minDate(String date, String message)` — A date (`yyyy-mm-dd`) not before [date], for a `DateSchemaField`.
- `Validator.maxDate(String date, String message)` — A date (`yyyy-mm-dd`) not after [date], for a `DateSchemaField`.
- `Validator.custom(String? Function(String) check)` — A rule only the server checks (a `FormSchema` from `package:thor_ui/router.dart`): [check] returns the message, or `null` when the value passes. The browser can't run it: it adds no attribute, and its message shows after the form is sent.

### `Velocity` · class

Flutter's `Velocity`: a speed in logical pixels per second.

- `Velocity({required Offset pixelsPerSecond})` — A velocity of [pixelsPerSecond].

### `WidgetPropertyResolver` · typedef

Flutter's `WidgetPropertyResolver`.


### `WidgetState` · enum

Flutter's `WidgetState`.

- values: `hovered`, `focused`, `pressed`, `dragged`, `selected`, `scrolledUnder`, `disabled`, `error`

### `WidgetStateMap` · typedef

Flutter's `WidgetStateMap`: the constraints of a [WidgetStateProperty.fromMap] and the value of each.


### `WidgetStateOperators` · mixin

Flutter's `WidgetStateOperators`: `a & b`, `a | b` and `~a` on constraints.


### `WidgetStateProperty` · abstract class

Flutter's `WidgetStateProperty`: a value of type [T] for a set of [WidgetState]s.

- `WidgetStateProperty<T>()` — Const constructor for subclasses.
- `WidgetStateProperty<T>.fromMap(WidgetStateMap<T> map)` — The value of the first entry of [map] whose constraint the states satisfy (the declarative form of [resolveWith]: a value, not a closure, so a tool can read and write it).

### `WidgetStatePropertyAll` · class

Flutter's `WidgetStatePropertyAll`: the same value in every state.

- `WidgetStatePropertyAll<T>(T value)` — [value] in every state.

### `WidgetStatesConstraint` · abstract class

Flutter's `WidgetStatesConstraint`: a condition on a set of [WidgetState]s. A [WidgetState] is one (it holds when the set has it); [WidgetState.any] always holds; `&`, `|` and `~` combine them.

- `WidgetStatesConstraint()`

### `childDragAnchorStrategy` · function

The feedback starts where the child is, and keeps its distance from the pointer (Flutter's default).

- `Offset childDragAnchorStrategy(Draggable<Object> draggable, BuildContext context, Offset position)`

### `pointerDragAnchorStrategy` · function

The feedback's corner is at the pointer.

- `Offset pointerDragAnchorStrategy(Draggable<Object> draggable, BuildContext context, Offset position)`

### `resolveFieldBorders` · function

What a field paints in its enabled and focused states, from its decoration (Flutter's `_getDefaultBorder`): the `box-shadow` of each (null for none) and the shape's radius. Not exported.

- `({String? enabled, String? focused, BorderRadius? radius}) resolveFieldBorders(InputDecoration d)`

### `selectBorderCss` · function

The border a `<select>` draws for [d]: the real `border` of its `enabledBorder` (else `border`), with the scheme's role where the border gives no color; null when the decoration names none (the select keeps its own outline). Not exported.

- `CssDeclarations? selectBorderCss(InputDecoration d)`

## `material` · Material and navigation

### `ActionChip` · class

Flutter's `ActionChip`. With [href] it is a link.

- `ActionChip({Key? key, Widget? avatar, required Widget label, required VoidCallback? onPressed, String? tooltip, String? href})` — Creates a Material action chip that triggers `onPressed`.

### `AlertDialog` · class

Flutter's `AlertDialog`, rendered in place as a closed native `<dialog>` (top layer, focus trap, Esc and backdrop for free).

- `AlertDialog(…)` — Creates a Material alert dialog.

### `AppBar` · class

Flutter's `AppBar` (Material 3 small top app bar) as one `<header>`: a grid with the [leading] widget, the [title] and the [actions] on the toolbar row, and [bottom] (e.g. a `TabBar`) under it.

- `AppBar(…)` — Creates a Material 3 app bar.

### `Badge` · class

Flutter's `Badge`: a small label on the top-right corner of [child].

- `Badge(…)` — Creates a Material badge on top of `child`.
- `Badge.count(…)` — Creates a badge with the number [count] (`999+` past [maxCount]).

### `Card` · class

Flutter's `Card` (Material 3 elevated card).

- `Card({Key? key, Color? color, double? elevation, EdgeInsetsGeometry? margin, Clip? clipBehavior, OutlinedBorder? shape, Widget? child})` — Creates a Material 3 elevated card.

### `Chip` · class

Flutter's `Chip`: a label, with an optional avatar and delete control.

- `Chip(…)` — Creates a Material chip.

### `ChoiceChip` · class

Flutter's `ChoiceChip`: one of a group; `onSelected(true)`.

- `ChoiceChip(…)` — Creates a Material choice chip, one of a group.

### `CircleAvatar` · class

Flutter's `CircleAvatar`: initials ([child]) or an image.

- `CircleAvatar({Key? key, double radius = 20, Color? backgroundColor, Color? foregroundColor, String? backgroundImage, Widget? child})` — Creates a circular avatar.

### `CircularProgressIndicator` · class

Flutter's `CircularProgressIndicator` as SVG. Indeterminate spins with a CSS rotation on the compositor: no JS.

- `CircularProgressIndicator({Key? key, double? value, Color? color, double? strokeWidth, double size = 40, String? semanticsLabel})` — Creates a circular Material progress indicator.

### `DataCell` · class

Flutter's `DataCell`: one cell of a [DataRow].

- `DataCell(Widget child, {bool placeholder = false, bool showEditIcon = false, VoidCallback? onTap})` — A cell showing [child].

### `DataColumn` · class

Flutter's `DataColumn`: a column header of a [DataTable].

- `DataColumn({required Widget label, String? tooltip, bool numeric = false, DataColumnSortCallback? onSort, MainAxisAlignment? headingRowAlignment, TableColumnWidth? columnWidth})` — A column labeled [label].

### `DataColumnSortCallback` · typedef

Flutter's `DataColumnSortCallback`: the column tapped and the order it asks for.


### `DataRow` · class

Flutter's `DataRow`: one row of a [DataTable].

- `DataRow({Key? key, bool selected = false, ValueChanged<bool?>? onSelectChanged, WidgetStateProperty<Color?>? color, required List<DataCell> cells})` — A row of [cells].
- `DataRow.byIndex({int? index, bool selected = false, ValueChanged<bool?>? onSelectChanged, WidgetStateProperty<Color?>? color, required List<DataCell> cells})` — A row keyed by its [index].

### `DataTable` · class

Flutter's `DataTable` (Material 3) → a native `<table>` with `<thead>`, `<th scope=col>` headers, `aria-sort` and a native checkbox per selectable row.

- `DataTable(…)` — Creates a data table.

### `DefaultTabController` · class

Flutter's `DefaultTabController`: the shared selection of the `TabBar` and `TabBarView` below it.

- `DefaultTabController({Key? key, String? id, required int length, int initialIndex = 0, required Widget child})` — Creates the selection scope for [length] tabs.

### `Dialog` · class

Flutter's `Dialog`: a modal surface for any content, as a native `<dialog>` like [AlertDialog], with the look given by the caller. Open it with [DialogTrigger] or a [controller]; close it with [DialogClose].

- `Dialog(…)` — A dialog with [child] as its content.

### `DialogClose` · class

Makes its `<button>` child close a dialog: the nearest one above it, or the one with the id [id].

- `DialogClose({Key? key, String? id, bool enabled = true, required Widget child})` — Wraps a `button` child so it closes the dialog with the given id (or, without one, the dialog it is inside).

### `DialogTrigger` · class

Makes its `<button>` child open a dialog (Invoker Commands). Three ways to say which one, the first needing no name at all:

- `DialogTrigger({Key? key, Widget? dialog, String? id, DialogController? controller, bool enabled = true, WindowSizeClass? hiddenFrom, required Widget child})` — Wraps a `button` child so it opens a dialog: the one it carries ([dialog]), the one with the given [id] or the one of the given [controller] (exactly one of the three).

### `Drawer` · class

Flutter's `Drawer`: a side panel over the page, on a native modal `<dialog>` (focus trap, Esc and a click on the backdrop close it; no JS). It slides in on open (`@starting-style`). Open it with a `DialogTrigger(id: id, …)` button and close it with `DialogClose`, or from a state method with a [controller] (`details.open()`).

- `Drawer(…)` — Creates a drawer.

### `DrawerButton` · class

Flutter's `DrawerButton`: the menu button that opens the `Scaffold`'s `drawer:`. An [AppBar] adds one by itself; use it directly to put the button somewhere else in the scaffold.

- `DrawerButton({Key? key, void Function()? onPressed, ButtonStyle? style})` — A button that opens the nearest `Scaffold`'s drawer.

### `DrawerHeader` · class

Flutter's `DrawerHeader`: the block at the top of a [Drawer], 160 px tall, with [child] at the bottom start and a divider underneath.

- `DrawerHeader(…)` — Creates a drawer header.

### `DrawerSide` · enum

Which edge a [Drawer] slides from.

- values: `start`, `end`

### `EndDrawerButton` · class

Flutter's `EndDrawerButton`: opens the `Scaffold`'s `endDrawer:`.

- `EndDrawerButton({Key? key, void Function()? onPressed, ButtonStyle? style})` — A button that opens the nearest `Scaffold`'s end drawer.

### `ExpansionPanelList` · class

Flutter's `ExpansionPanelList.radio`-like group: only one tile open.

- `ExpansionPanelList({Key? key, required String name, required List<ExpansionTile> children})` — Creates an exclusive-open group of `ExpansionTile`s.

### `ExpansionTile` · class

Flutter's `ExpansionTile` on `<details>`/`<summary>`: opens and closes with no JS, keyboard and screen readers included.

- `ExpansionTile(…)` — Creates a Material expansion tile.

### `FilterChip` · class

Flutter's `FilterChip`: toggles; `onSelected(!selected)`.

- `FilterChip(…)` — Creates a toggleable Material filter chip.

### `Hero` · class

Flutter's `Hero`: an element that travels from one page to the next.

- `Hero({Key? key, required Object tag, required Widget child})` — Marks [child] as the element [tag] names across pages.

### `InputChip` · class

Flutter's `InputChip`: a piece of user input (a tag, a filter) that can be pressed or selected and removed with its delete control.

- `InputChip(…)` — Creates a Material input chip.

### `LinearProgressIndicator` · class

Flutter's `LinearProgressIndicator` on `<progress>`: determinate with a [value], the browser's own indeterminate animation without one.

- `LinearProgressIndicator({Key? key, double? value, Color? color, double? minHeight, String? semanticsLabel})` — Creates a horizontal Material progress indicator.
- `LinearProgressIndicator.watch(double? Function() source, {Key? key, Color? color, double? minHeight, String? semanticsLabel})` — A bar whose progress is the number [source] returns (0 to 1; a `ThorState` method or a field's `call`; null is indeterminate), kept current in the browser: the page is not rebuilt.
- `LinearProgressIndicator.upload({Key? key, Color? color, double? minHeight, String? semanticsLabel})` — `// web:` the bar of a `Form` that sends files: it is hidden, and the page that has it ships a small script of its own that sends the files with an `XMLHttpRequest` (`fetch` has no upload progress), shows the bar and fills it as the bytes leave; the result is then the browser's own navigation. Put it inside a `Form(encoding: FormEncoding.multipart)` with a `FileField`. Without JavaScript the form is the plain post and the bar stays hidden.

### `Link` · class

A link: makes its child's element an `<a href>` (no extra node), like Flutter's `Link` from `url_launcher`. With [newTab] it opens in a new tab (`target="_blank"`, `rel="noopener noreferrer"`).

- `Link({Key? key, RouteUrl href = const RouteUrl('#'), bool newTab = false, String? label, bool prefetch = true, bool current = false, required Widget child})` — Links `child` to [href].

### `ListTile` · class

Flutter's `ListTile`: one row with optional leading, title, subtitle and trailing. With [onTap] (or [href]) the whole row is the native control.

- `ListTile(…)` — Creates a Material list tile.

### `MenuAnchor` · class

Flutter's `MenuAnchor`: a button that opens a menu of [MenuItemButton]s and [SubmenuButton]s, on the Popover API (the same as `PopupMenuButton`): no JS, light dismiss and Esc are native, CSS anchor positioning places the menu under the anchor (flipping where it doesn't fit). Choosing a button item closes it natively; following a link item closes it on the tap ([closeOnNavigate]).

- `MenuAnchor(…)` — Creates a menu anchored to a button.

### `MenuController` · class

Flutter's `MenuController` (what a [MenuAnchor]'s `builder` receives).

- `MenuController()` — Creates a controller.

### `MenuItemButton` · class

Flutter's `MenuItemButton`: an entry of a [MenuAnchor]. A `<button>` that closes the menu natively (`closeOnActivate`) and calls [onPressed] (a `ThorState` method); with [href] an `<a>` that goes there. Without either it is disabled, as in Flutter.

- `MenuItemButton({Key? key, VoidCallback? onPressed, Widget? leadingIcon, Widget? trailingIcon, ButtonStyle? style, bool closeOnActivate = true, String? href, Widget? child})` — Creates a menu entry.

### `ModalBottomSheet` · class

Flutter's `showModalBottomSheet`: a native modal `<dialog>` anchored to the bottom, sliding up on open (`@starting-style`, no JS). Open it with [DialogTrigger] and close it with [DialogClose], Esc or the backdrop, or both from a state method with a [controller].

- `ModalBottomSheet(…)` — Creates a Material modal bottom sheet.

### `NavigationBar` · class

Flutter's `NavigationBar` (Material 3 bottom navigation) as a `<nav>` landmark: each [NavigationDestination] is a link (with `href`) or a button; the selected one carries `aria-current` (`page` for a link, `true` for a button).

- `NavigationBar(…)` — Creates a Material 3 navigation bar.

### `NavigationDestination` · class

One entry of a [NavigationBar]: an icon (a pill indicator behind it when selected) over a label.

- `NavigationDestination({Key? key, required Widget icon, Widget? selectedIcon, required String label, String? tooltip, bool enabled = true, String? href})` — Creates a navigation bar destination.

### `NavigationDestinationLabelBehavior` · enum

Flutter's `NavigationDestinationLabelBehavior`: when a [NavigationDestination]'s label is shown. Hidden labels stay the destination's accessible name.

- values: `alwaysShow`, `alwaysHide`, `onlyShowSelected`

### `NavigationRail` · class

Flutter's `NavigationRail` (Material 3 side navigation) as a `<nav>` landmark: each [NavigationRailDestination] is a link (with `href`) or a button; the selected one carries `aria-current` (`page` for a link, `true` for a button).

- `NavigationRail(…)` — Creates a Material 3 navigation rail.

### `NavigationRailDestination` · class

One entry of a [NavigationRail]: an icon (a pill indicator behind it when selected) and a label.

- `NavigationRailDestination(…)` — Creates a destination for [NavigationRail.destinations].

### `NavigationRailLabelType` · enum

Flutter's `NavigationRailLabelType`: when a [NavigationRailDestination]'s label is shown under its icon. Hidden labels stay the destination's accessible name.

- values: `none`, `selected`, `all`

### `NavigationRailTheme` · class

Flutter's `NavigationRailTheme`: a [NavigationRailThemeData] for the rails in [child].

- `NavigationRailTheme({Key? key, required NavigationRailThemeData data, required Widget child})` — Applies [data] to the rails in [child].

### `NavigationRailThemeData` · class

Flutter's `NavigationRailThemeData` (the parts that are not text or icon themes: style those on the destination's widgets): the defaults of the rails below. A `NavigationRail` parameter wins; a null field keeps the Material 3 default. Put it in `ThemeData(navigationRailTheme:)` or around a subtree with [NavigationRailTheme].

- `NavigationRailThemeData(…)` — A rail theme; null fields keep the defaults.

### `PageNavigation` · class

How a multi-page app moves between its pages, with no JavaScript: [Speculation Rules](https://developer.chrome.com/docs/web-platform/prerender-pages) that fetch a linked page before the click, and cross-document [view transitions](https://developer.chrome.com/docs/web-platform/view-transitions/cross-document).

- `PageNavigation(…)` — Navigation settings; the defaults prefetch a same-origin link on hover.

### `PageTransition` · class

How a page enters when the visitor comes from another page of the app: a cross-document view transition (`@view-transition`), drawn by the browser between two documents. No JavaScript, no client router: each page is still a plain document, and a browser without view transitions (or with `prefers-reduced-motion`) just navigates.

- `PageTransition.fade({Duration? duration, Curve? curve})` — The browser's cross-fade. [duration] and [curve] (`null`: the browser's, 0.25 s ease) apply to every element that transitions, `Hero`es included.
- `PageTransition.slide({Duration? duration = const Duration(milliseconds: 300), Curve? curve = Curves.fastOutSlowIn})` — The new page slides in from the end while the old one slides out.
- `PageTransition.fadeUp({Duration? duration = const Duration(milliseconds: 300), Curve? curve = Curves.fastOutSlowIn})` — The new page rises a quarter of the screen and fades in over the old one: Flutter's `FadeUpwardsPageTransitionsBuilder`.

### `Pagination` · class

The links of a list whose page lives in the URL: a `<nav>` with real links (they work with no JavaScript, open in a new tab and are bookmarkable), the current page marked with `aria-current="page"`, `rel="prev"`/`rel="next"` on its neighbours, and every other parameter of the URL (`q`, `sort`, the filters) kept.

- `Pagination({Key? key, required ListQuery list, required int total, int window = 1, String? previousLabel, String? nextLabel, String? semanticLabel, String? pageLabel})` — The links of [list] for [total] rows.
- `Pagination.custom(…)` — The links of a list of [pageCount] pages whose page `n` is at [href]`(n)`, for a list that is not read with `request.listQuery`.

### `Popover` · class

A button that opens arbitrary content anchored under it (Flutter's `PopupMenuButton` / `MenuAnchor` with any widgets), on the Popover API: light dismiss and Esc are native, CSS anchor positioning places the panel (with fallbacks when it doesn't fit). Following a link inside closes it on the tap ([closeOnNavigate]).

- `Popover(…)` — Creates a popover.

### `PopupMenuButton` · class

Flutter's `PopupMenuButton` / `MenuAnchor` on the Popover API: the trigger opens it with `popovertarget` (no JS), light dismiss and Esc are native, and CSS anchor positioning places it under the trigger (centered by the browser where anchoring is unsupported).

- `PopupMenuButton<T>(…)` — Creates a Material popup menu button.

### `PopupMenuItem` · class

One entry of a [PopupMenuButton]. Choosing it calls `onSelected` with its [value]; choosing an item closes the menu natively (`popovertargetaction="hide"`).

- `PopupMenuItem<T>({required T value, required Widget child, bool enabled = true, double height = 48, EdgeInsetsGeometry? padding, TextStyle? textStyle})` — Creates a popup menu entry.

### `Skeleton` · class

A placeholder for content that is still loading: a rounded box with a light that sweeps across it (the look of `skeletonizer` and `shimmer`).

- `Skeleton({Key? key, double? width, double height = 16, double borderRadius = 6})` — A box of [width] by [height] (the width of its parent by default).
- `Skeleton.expand({Key? key, double borderRadius = 6})` — A box that fills its parent in both directions, like `SizedBox.expand`: the placeholder of an image in an `AspectRatio` or a `SizedBox`.
- `Skeleton.circle({Key? key, required double diameter})` — A circle of [diameter] (an avatar).

### `SliverAppBar` · class

Flutter's `SliverAppBar`: an [AppBar] inside a `CustomScrollView`. It scrolls away with the content, or, with [pinned], sticks to the top of the view (`position: sticky`).

- `SliverAppBar(…)` — Creates a sliver app bar.

### `SnackBar` · class

Flutter's `SnackBar`: a short message at the bottom (`role=status`, read by screen readers). Show and hide it by switching [visible] with a thor_engine variant; the transition is CSS. It hides itself after [duration] with a CSS animation (no JS), paused while the pointer or the focus is on it.

- `SnackBar(…)` — Creates a Material snack bar.

### `SnackBarBehavior` · enum

Flutter's `SnackBarBehavior`: where a [SnackBar] sits.

- values: `fixed`, `floating`

### `SpeculationDelivery` · enum

Where a page's speculation rules travel.

- values: `inline`, `header`

### `SpeculationEagerness` · enum

When the browser starts loading a linked page ahead of the click (`eagerness` of the Speculation Rules API).

- values: `immediate`, `eager`, `moderate`, `conservative`

### `SubmenuButton` · class

Flutter's `SubmenuButton`: an entry of a [MenuAnchor] that opens [menuChildren] in a second popover beside it. Choosing an item of the submenu closes the whole menu.

- `SubmenuButton({Key? key, String? id, Widget? leadingIcon, Widget? trailingIcon, ButtonStyle? style, MenuStyle? menuStyle, required List<Widget> menuChildren, Widget? child})` — Creates an entry with a submenu.

### `Tab` · class

Flutter's `Tab`: a [text], an [icon] (above the text when both), or a custom [child].

- `Tab({Key? key, String? text, Widget? icon, EdgeInsetsGeometry? iconMargin, double? height, Widget? child})` — Creates a tab's content.

### `TabBar` · class

Flutter's `TabBar` (Material 3 primary tabs), with no JS: each tab is a `<label>` around a visually hidden radio of the `DefaultTabController`'s group. Arrow keys move the selection natively; the checked tab shows the indicator and its `TabBarView` panel (`:has()`).

- `TabBar(…)` — Creates a Material 3 tab bar.

### `TabBarView` · class

Flutter's `TabBarView`: one panel per tab; only the selected tab's panel is shown, by CSS (`:has()` on the checked radio), with no JS.

- `TabBarView({Key? key, required List<Widget> children})` — Creates the panels of a `DefaultTabController`.

### `Tooltip` · class

Flutter's `Tooltip`: a bubble with [message] (or [richMessage]) that shows while the pointer is over [child] or it has keyboard focus, with no JS.

- `Tooltip(…)` — Shows [message] (or [richMessage] or [messageWatch], exactly one) over [child].

## `estilos` · Styles and theme

### `Adaptable` · abstract class

Makes a value type changeable per breakpoint and per interaction state with one inherited method (Flutter's `WidgetStateProperty` idea, as a value):

- `Adaptable<T>()`

### `Adaptive` · class

A value that changes from breakpoints up (mobile-first), the shared core of [Adaptable.when].

- `Adaptive<T>(…)` — [base] below the first breakpoint, each variant from its breakpoint up.

### `AppBarThemeData` · class

Flutter's `AppBarThemeData`, subset: the default look of `AppBar`.

- `AppBarThemeData({Color? backgroundColor, Color? foregroundColor, double? elevation, bool? centerTitle, double? titleSpacing, double? toolbarHeight, TextStyle? titleTextStyle})` — An app bar theme; null fields keep the defaults.

### `Border` · class

Flutter's `Border`.

- `Border({BorderSide top = BorderSide.none, BorderSide right = BorderSide.none, BorderSide bottom = BorderSide.none, BorderSide left = BorderSide.none})` — Creates a border from independent sides, each defaulting to none.
- `Border.fromBorderSide(BorderSide side)` — Creates a border where all four sides use the same [side].
- `Border.symmetric({BorderSide vertical = BorderSide.none, BorderSide horizontal = BorderSide.none})` — Creates a border with [vertical] sides (top/bottom) and [horizontal] sides (left/right).
- `Border.all({Color color = const Color(0xFF000000), double width = 1, BorderStyle style = BorderStyle.solid})` — Creates a uniform border with the given [color], [width] and [style] on all four sides.

### `BorderSide` · class

Flutter's `BorderSide`.

- `BorderSide({Color color = const Color(0xFF000000), double width = 1, BorderStyle style = BorderStyle.solid})` — Creates a border side, defaulting to a solid 1-pixel black line.

### `BottomSheetThemeData` · class

Flutter's `BottomSheetThemeData`, subset: the default look of `ModalBottomSheet`.

- `BottomSheetThemeData(…)` — A bottom sheet theme; null fields keep the defaults.

### `BoxDecoration` · class

Flutter's `BoxDecoration`.

- `BoxDecoration(…)` — Creates a box decoration, defaulting to a plain rectangle with no fill, border or shadow.

### `BoxShadow` · class

Flutter's `BoxShadow`. [inset] is a web extra.

- `BoxShadow({Color color = const Color(0xFF000000), Offset offset = Offset.zero, double blurRadius = 0, double spreadRadius = 0, bool inset = false})` — Creates a box shadow, defaulting to an opaque black shadow with no offset or blur.

### `BreakpointCondition` · extension

The [CssCondition] equivalent of a [WindowSizeClass].


### `Breakpoints` · class

The widths of the [WindowSizeClass]es, part of the theme (`ThemeData(breakpoints: Breakpoints(medium: 640))`): every `.when()`, `Grid`, `Flex` and `ResponsiveVisibility` follows them.

- `Breakpoints({double medium = 600, double expanded = 840, double large = 1200, double extraLarge = 1600})` — Window size class widths in logical pixels (defaults: Material 3's).

### `Brightness` · enum

Flutter's `Brightness`.

- values: `light`, `dark`

### `CardThemeData` · class

Flutter's `CardThemeData`, subset: the default look of `Card`.

- `CardThemeData({Color? color, double? elevation, EdgeInsetsGeometry? margin, OutlinedBorder? shape, Clip? clipBehavior})` — A card theme; null fields keep the defaults.

### `CheckboxThemeData` · class

Flutter's `CheckboxThemeData`, subset: the default look of `Checkbox` (and the checkbox of `CheckboxListTile`).

- `CheckboxThemeData({WidgetStateProperty<Color?>? fillColor, WidgetStateProperty<Color?>? checkColor, BorderSide? side, OutlinedBorder? shape})` — A checkbox theme; null fields keep the defaults.

### `ChipThemeData` · class

Flutter's `ChipThemeData`, subset: the default look of `Chip`, `InputChip`, `FilterChip`, `ChoiceChip` and `ActionChip`.

- `ChipThemeData(…)` — A chip theme; null fields keep the defaults.

### `CircleBorder` · class

Flutter's `CircleBorder`: a circle (an avatar, a round button).

- `CircleBorder({BorderSide side = BorderSide.none, double eccentricity = 0.0})` — A circle with an optional [side]; [eccentricity] 1 is an oval.

### `Color` · class

A color in `0xAARRGGBB` form, exactly like Flutter's `Color`.

- `Color(int value)` — Creates a color from a 32-bit `0xAARRGGBB` [value].
- `Color.fromARGB(int a, int r, int g, int b)` — Creates a color from alpha, red, green and blue channel values (0-255).
- `Color.fromRGBO(int r, int g, int b, double opacity)` — Creates a color from red, green, blue (0-255) and a fractional [opacity] (0.0-1.0).
- `Color.css(String raw)` — Any valid CSS color expression. Its channels are not known on the server: reading them throws (THOR-R023, see [hasChannels]).
- `Color.variable(CssVariable<Color> variable, {Color? fallback})` — References a CSS custom property, e.g. `Color.variable(CssVariable('--primary'))`.
- `Color.token(String name, {Color? fallback})` — The theme variable `--t-<name>` (a role or a token), the way `ColorToken` names itself.

### `ColorScale` · class

A color scale of eleven steps, 50 to 950: the one web design systems use, one step darker than [MaterialColor]. Every shade is a required argument, so a scale can't miss one.

- `ColorScale(…)` — A scale whose own value is [primary] (its 500 shade).

### `ColorScheme` · class

Flutter's (Material 3) `ColorScheme`, subset.

- `ColorScheme(…)` — Creates a color scheme from every role.
- `ColorScheme.light(…)` — Material 3 baseline (light).
- `ColorScheme.dark(…)` — Material 3 baseline (dark).
- `ColorScheme.highContrastLight(…)` — Material 3 baseline with high contrast (light), like Flutter's `ColorScheme.highContrastLight`: the roles of [ColorScheme.light] with text, borders and brand colors dark enough for 7:1 (WCAG AAA) against their backgrounds. What a `ThorApp(highContrastTheme:)` is made of. `// web:` the defaults are derived from the Material 3 baseline like [ColorScheme.light], not Flutter's M2 high-contrast values (primary `0xff0000ba`, secondary `0xff66fff9`).
- `ColorScheme.highContrastDark(…)` — Material 3 baseline with high contrast (dark), like Flutter's `ColorScheme.highContrastDark` (see [ColorScheme.highContrastLight]).

### `ColorSwatch` · class

Flutter's `ColorSwatch`: a color that also holds a family of related colors, looked up by [T] (`swatch[500]`). The swatch itself is its primary color.

- `ColorSwatch<T>(int primary, Map<T, Color> swatch)` — A swatch whose own value is [primary], with the colors of [swatch].

### `ColorToken` · class

A color of the app's theme, typed: it IS the theme variable a widget uses (`var(--t-<name>)`, `const` like any [Color]), and it carries its value in the light and in the dark theme. The name and both values are written once:

- `ColorToken(String name, {required Color light, required Color dark})` — The token `--t-<name>`, with its [light] and [dark] values.

### `Colors` · abstract class

Flutter's material base palette (500 shades) plus common tones.

- `Colors()`

### `ConstAdaptable` · abstract class

An [Adaptable] value whose variants can also be written in its `const` constructor (named parameters), so a value that changes per breakpoint or state is still a constant expression:

- `ConstAdaptable<T>(…)` — The variants given to the constructor; none means a plain value.

### `ContainerType` · enum

`container-type`: what a descendant's container query measures.

- values: `normal`, `inlineSize`, `size`

### `ContinuousRectangleBorder` · class

Flutter's `ContinuousRectangleBorder`: the squircle corners of iOS.

- `ContinuousRectangleBorder({BorderSide side = BorderSide.none, BorderRadius borderRadius = BorderRadius.zero})` — A rectangle with [borderRadius] corners and an optional [side].

### `CssDeclarations` · typedef

A set of CSS declarations, e.g. `{'padding': '8px', 'color': '#fff'}`.


### `CssVariable` · extension type

A CSS custom property (`--gutter`) that holds a [T] (`Length`, `Color`).

- `CssVariable<T>(String name)`

### `Decoration` · typedef

Flutter's `Decoration` (what `DecoratedBoxTransition` animates).


### `DecorationImage` · class

Flutter's `DecorationImage` (network/asset URL).

- `DecorationImage({required String url, BoxFit? fit, Alignment alignment = Alignment.center, bool repeat = false})` — Creates a background image from [url].

### `DialogThemeData` · class

Flutter's `DialogThemeData`, subset: the default look of `AlertDialog` and `Dialog`.

- `DialogThemeData(…)` — A dialog theme; null fields keep the defaults.

### `Display` · enum

`display`.

- values: `block`, `inline`, `inlineBlock`, `flex`, `inlineFlex`, `grid`, `inlineGrid`, `contents`, `none`

### `DividerThemeData` · class

Flutter's `DividerThemeData`: the default look of `Divider` and `VerticalDivider`.

- `DividerThemeData({Color? color, double? space, double? thickness, double? indent, double? endIndent})` — A divider theme; null fields keep the defaults.

### `DrawerThemeData` · class

Flutter's `DrawerThemeData`, subset: the default look of `Drawer`.

- `DrawerThemeData({Color? backgroundColor, Color? scrimColor, double? elevation, OutlinedBorder? shape, double? width})` — A drawer theme; null fields keep the defaults.

### `ElevatedButtonThemeData` · class

Flutter's `ElevatedButtonThemeData`: the default [ButtonStyle] of `ElevatedButton`.

- `ElevatedButtonThemeData({ButtonStyle? style})` — A theme for `ElevatedButton`.

### `ExpansionTileThemeData` · class

Flutter's `ExpansionTileThemeData`, subset: the default look of `ExpansionTile`.

- `ExpansionTileThemeData(…)` — An expansion tile theme; null fields keep the defaults.

### `FilledButtonThemeData` · class

Flutter's `FilledButtonThemeData`: the default [ButtonStyle] of `FilledButton` (the button's own `style` wins, field by field).

- `FilledButtonThemeData({ButtonStyle? style})` — A theme for `FilledButton`.

### `FontDisplay` · enum

When text in a font that hasn't loaded yet shows (`font-display`).

- values: `swap`, `fallback`, `optional`, `block`

### `FontFace` · class

A font file of the app (`@font-face`): [family] as `TextStyle` and `ThemeData.fontFamily` name it, served at [url].

- `FontFace(…)` — A face of [family].

### `FontFallback` · class

A local font resized to a [FontFace]'s metrics (the numbers `size-adjust` and the overrides take, as fractions: `1.07` = 107 %). Get them from the font's own tables (`thor fonts metrics`, or tools like fontaine/capsize) against the [local] font.

- `FontFallback({List<String> local = const ['Arial', 'Helvetica Neue', 'Helvetica'], double? sizeAdjust, double? ascentOverride, double? descentOverride, double? lineGapOverride})` — The first of [local] the system has, with these overrides.

### `Gradient` · sealed class

Base for gradients.

- `Gradient({required List<Color> colors, List<double>? stops, Size? tile})`

### `GridTrack` · class

One grid track's size.

- `GridTrack.fr(num n)` — [n] parts of the free space (`1fr`).
- `GridTrack.length(Length length)` — A fixed [length] (`200px`, `Length.min([100.percent, 24.rem])`).
- `GridTrack.minmax(GridTrack min, GridTrack max)` — At least [min] and at most [max] (`minmax(200px, 1fr)`).

### `GridTracks` · class

`grid-template-columns` / `grid-template-rows`.

- `GridTracks.repeat(int count)` — [count] equal tracks that may shrink below their content (`repeat(3, minmax(0, 1fr))`, Tailwind's `grid-cols-3`).
- `GridTracks.sizes(List<GridTrack> sizes)` — One track per size (`200px 1fr`: `[GridTrack.length(200.px), GridTrack.fr(1)]`).
- `GridTracks.autoFit(GridTrack track)` — As many [track]s as fit, the empty ones collapsed so the others share the row (`repeat(auto-fit, …)`).
- `GridTracks.autoFill(GridTrack track)` — As many [track]s as fit, the empty ones kept (`repeat(auto-fill, …)`): a short row leaves room at its end.

### `HoverGroup` · class

Marks its child as a hover group: descendants' `.when(groupHover: …)` apply while the pointer is anywhere over it. No extra node.

- `HoverGroup({Key? key, String? name, required Widget child})` — Makes `child` a hover group, named [name] or not.

### `IconButtonThemeData` · class

Flutter's `IconButtonThemeData`: the default [ButtonStyle] of every `IconButton` (plain, `.filled`, `.filledTonal` and `.outlined`).

- `IconButtonThemeData({ButtonStyle? style})` — A theme for `IconButton`.

### `LayoutScope` · class

Makes a size container around its child, so descendants can respond to *its* width (`.when(container: {...})`, `GridView.count(containerBreakpoints:)`, `Flex(layoutBreakpoints:)`) instead of the viewport's.

- `LayoutScope({Key? key, required Widget child})` — Creates a container query scope around [child].

### `LinearGradient` · class

Flutter's `LinearGradient`.

- `LinearGradient({Alignment begin = Alignment.centerLeft, Alignment end = Alignment.centerRight, required List<Color> colors, List<double>? stops, Size? tile})` — Creates a linear gradient running from [begin] to [end], defaulting to left-to-right.

### `ListTileThemeData` · class

Flutter's `ListTileThemeData`, subset: the default look of `ListTile`.

- `ListTileThemeData(…)` — A list tile theme; null fields keep the defaults.

### `MaterialColor` · class

Flutter's `MaterialColor`: the ten shades of the Material palette, 50 to 900, with the 500 one as its own value.

- `MaterialColor(int primary, Map<int, Color> swatch)` — A Material swatch; [swatch] holds the shades 50, 100 … 900.

### `NavigationBarThemeData` · class

Flutter's `NavigationBarThemeData`, subset: the default look of `NavigationBar`.

- `NavigationBarThemeData({double? height, Color? backgroundColor, double? elevation, Color? indicatorColor, NavigationDestinationLabelBehavior? labelBehavior})` — A navigation bar theme; null fields keep the defaults.

### `OutlinedBorder` · sealed class

Flutter's `OutlinedBorder`: the shape of a button or a card.

- `OutlinedBorder({BorderSide side = BorderSide.none})`

### `OutlinedButtonThemeData` · class

Flutter's `OutlinedButtonThemeData`: the default [ButtonStyle] of `OutlinedButton`.

- `OutlinedButtonThemeData({ButtonStyle? style})` — A theme for `OutlinedButton`.

### `OvalBorder` · class

Flutter's `OvalBorder`: `CircleBorder(eccentricity: 1)`.

- `OvalBorder({BorderSide side = BorderSide.none, double eccentricity = 1.0})` — An oval that fills its box, with an optional [side].

### `PopupMenuThemeData` · class

Flutter's `PopupMenuThemeData`, subset: the default look of `PopupMenuButton`'s menu.

- `PopupMenuThemeData({Color? color, OutlinedBorder? shape, double? elevation, TextStyle? textStyle, EdgeInsetsGeometry? menuPadding})` — A popup menu theme; null fields keep the defaults.

### `ProgressIndicatorThemeData` · class

Flutter's `ProgressIndicatorThemeData`, subset: the default look of `LinearProgressIndicator` and `CircularProgressIndicator`.

- `ProgressIndicatorThemeData({Color? color, double? linearMinHeight, double? circularStrokeWidth})` — A progress indicator theme; null fields keep the defaults.

### `RadialGradient` · class

Flutter's `RadialGradient`: a circle of [radius] times the shortest side of the box.

- `RadialGradient({Alignment center = Alignment.center, double radius = 0.5, required List<Color> colors, List<double>? stops, Size? tile})` — Creates a circular gradient centered at [center] with the given [radius] (a fraction of the box's shortest side, 0.5 by default: the circle touches the sides of a centered gradient).

### `RadioThemeData` · class

Flutter's `RadioThemeData`, subset: the default look of `Radio`.

- `RadioThemeData({WidgetStateProperty<Color?>? fillColor})` — A radio theme; null fields keep the defaults.

### `ResponsiveLayout` · class

Different layouts per screen size — the web counterpart of switching on `MediaQuery.sizeOf(context).width` or `LayoutBuilder`.

- `ResponsiveLayout(…)` — Renders [mobile], [tablet] or [desktop] depending on the viewport.

### `ResponsiveVisibility` · class

Shows its child only between window size classes (CSS only: correct on the first server-rendered paint, no resize listeners).

- `ResponsiveVisibility(…)` — Wraps `child`, hiding it outside `[visibleFrom, hiddenFrom)`.

### `RoundedRectangleBorder` · class

Flutter's `RoundedRectangleBorder`.

- `RoundedRectangleBorder({BorderSide side = BorderSide.none, BorderRadius borderRadius = BorderRadius.zero})` — A rectangle with [borderRadius] corners and an optional [side].

### `ScrollbarThemeData` · class

Flutter's `ScrollbarThemeData`: the look of the scrollbars.

- `ScrollbarThemeData({WidgetStateProperty<double?>? thickness, WidgetStateProperty<Color?>? thumbColor, WidgetStateProperty<Color?>? trackColor})` — Scrollbar values; null ones keep the browser's.

### `ShowValueIndicator` · enum

Flutter's `ShowValueIndicator`: when a `Slider` shows the bubble with its value above the thumb.

- values: `onlyForDiscrete`, `onlyForContinuous`, `onDrag`, `alwaysVisible`, `never`

### `SliderThemeData` · class

Flutter's `SliderThemeData`, subset: the default look of `Slider`.

- `SliderThemeData({Color? activeTrackColor, Color? thumbColor, ShowValueIndicator? showValueIndicator, Color? valueIndicatorColor, TextStyle? valueIndicatorTextStyle})` — A slider theme; null fields keep the defaults.

### `SnackBarThemeData` · class

Flutter's `SnackBarThemeData`, subset: the default look of `SnackBar`.

- `SnackBarThemeData(…)` — A snack bar theme; null fields keep the defaults.

### `StadiumBorder` · class

Flutter's `StadiumBorder`: fully rounded ends.

- `StadiumBorder({BorderSide side = BorderSide.none})` — A pill shape with an optional [side].

### `StyleProps` · class

Loose style values for `Styled(style:)`: the numbers and effects that have no value type of their own (`widthFactor`, `opacity`, `scale`, `zIndex`…). Changes per breakpoint or state with `.when()`:

- `StyleProps(…)` — Creates loose style values; unset ones don't apply.

### `StyleRule` · sealed class

A rule of the app's stylesheet (`styles:` of `initializeThor` or `WidgetRenderer`): what no widget covers (`::before`, `:nth-child`, classes of markup thor didn't build, keyframes). Built with [css].

- `StyleRule()`

### `Styled` · class

Adds CSS classes (from the app's stylesheets) to the child element without creating a DOM node.

- `Styled(…)` — Wraps `child` with [classes], [style] and inline [css].

### `SwitchThemeData` · class

Flutter's `SwitchThemeData`, subset: the default look of `Switch`.

- `SwitchThemeData(…)` — A switch theme; null fields keep the defaults.

### `TabBarThemeData` · class

Flutter's `TabBarThemeData`, subset: the default look of `TabBar`.

- `TabBarThemeData({Color? indicatorColor, Color? labelColor, Color? unselectedLabelColor, Color? dividerColor, TextStyle? labelStyle, EdgeInsetsGeometry? labelPadding})` — A tab bar theme; null fields keep the defaults.

### `TextButtonThemeData` · class

Flutter's `TextButtonThemeData`: the default [ButtonStyle] of `TextButton`.

- `TextButtonThemeData({ButtonStyle? style})` — A theme for `TextButton`.

### `TextSelectionThemeData` · class

Flutter's `TextSelectionThemeData`: the colors of selected text and of the caret.

- `TextSelectionThemeData({Color? selectionColor, Color? selectionTextColor, Color? cursorColor})` — Selection and caret colors; null ones keep the browser's.

### `TextTheme` · class

Flutter's (Material 3) `TextTheme`.

- `TextTheme(…)` — Creates a text theme, filling gaps with the Material 3 defaults.

### `Theme` · class

Flutter's `Theme`.

- `Theme({Key? key, required ThemeData data, ThemeData? darkData, ThemeMode themeMode = ThemeMode.system, required Widget child})` — Creates a theme scope around `child`.

### `ThemeColor` · abstract class

The theme's colors as CSS variables, for building widgets: they follow the light/dark switch, which `Theme.of(context)` (resolved on the server) can't.

- `ThemeColor()`

### `ThemeData` · class

Flutter's `ThemeData`, subset.

- `ThemeData(…)` — Creates a theme, defaulting to the Material 3 light scheme.
- `ThemeData.light()` — A theme using the Material 3 light color scheme.
- `ThemeData.dark()` — A theme using the Material 3 dark color scheme.

### `ThemeExtension` · abstract class

Flutter's `ThemeExtension<T>`: the app's own theme values, typed (`ThemeData(extensions: [BrandShape(radius: 8)])`, read with `Theme.of(context).extension<BrandShape>()`).

- `ThemeExtension<T>()` — Const constructor for subclasses.

### `ThemeMode` · enum

Flutter's `ThemeMode`.

- values: `system`, `light`, `dark`

### `ThemeText` · abstract class

The theme's text roles for building widgets without a `BuildContext` (`Text('x', style: ThemeText.headlineLarge)`); like `ThemeColor`, they follow the theme's CSS variables. `Theme.of(context).textTheme` gives the same roles with the values as fallbacks.

- `ThemeText()`

### `ThemeToggle` · class

The theme switch: a label of the page's hidden checkbox (rendered by `ThorApp` when it has a `darkTheme`), showing [light] in the light theme and [dark] in the dark one. Works with no JavaScript; the checkbox is the focusable control (Tab + Space), its focus ring shows on the label.

- `ThemeToggle({Key? key, required Widget light, required Widget dark, double size = 40})` — Creates a theme switch.

### `TooltipThemeData` · class

Flutter's `TooltipThemeData`: the default look and timing of `Tooltip`.

- `TooltipThemeData(…)` — A tooltip theme; null fields keep the defaults.

### `UserSelect` · enum

`user-select`.

- values: `auto`, `none`, `text`, `all`

### `WindowSizeClass` · enum

Material 3's window size classes, emitted as CSS media queries instead of being resolved in Dart: no resize listeners, no rebuilds, correct on first SSR paint. Mobile-first: [compact] is the base (what applies below [medium]); the rest are widths up. Their widths come from `ThemeData.breakpoints` (the values below are the defaults, Material's).

- values: `compact`, `medium`, `expanded`, `large`, `extraLarge`

## `animacion` · Animation and effects

### `AbsorbPointer` · class

Flutter's `AbsorbPointer`: [child] takes pointer events away from what is behind it without answering them.

- `AbsorbPointer({Key? key, bool absorbing = true, bool? ignoringSemantics, required Widget child})` — Creates a widget that absorbs pointer events when [absorbing].

### `AlwaysStoppedAnimation` · class

Flutter's `AlwaysStoppedAnimation`: [value], forever. A transition with one is a static style.

- `AlwaysStoppedAnimation<T>(T value)` — Always [value].

### `Animatable` · abstract class

Flutter's `Animatable<T>`: maps a `double` (usually 0 to 1) to a `T`.

- `Animatable<T>()` — Const constructor for subclasses.

### `AnimatedAlign` · class

Flutter's `AnimatedAlign`.

- `AnimatedAlign({Key? key, required Alignment alignment, required Duration duration, Curve curve = Curves.linear, VoidCallback? onEnd, Widget? child})` — Creates a widget that animates the alignment of [child].

### `AnimatedContainer` · class

Flutter's `AnimatedContainer`: every box property transitions (size, padding, margin, colors, radius, border, shadow). Alignment changes are applied instantly: auto margins can't be interpolated by CSS.

- `AnimatedContainer(…)` — Creates a Container that animates changes to its box properties.

### `AnimatedCrossFade` · class

Flutter's `AnimatedCrossFade`: fades between two children while its size goes from the one's to the other's.

- `AnimatedCrossFade(…)` — Fades between [firstChild] and [secondChild].

### `AnimatedCrossFadeBuilder` · typedef

Lays out the children of an [AnimatedCrossFade] (Flutter's `AnimatedCrossFadeBuilder`).


### `AnimatedDefaultTextStyle` · class

Flutter's `AnimatedDefaultTextStyle`.

- `AnimatedDefaultTextStyle(…)` — Creates a widget that animates changes to the default text style of [child].

### `AnimatedList` · class

Flutter's `AnimatedList`: a list whose rows animate when they come in and when they go out.

- `AnimatedList<I, K>(…)` — Animates the rows of [source] (a `List` of the state: `notes.items.call`, like [Watch.list]), each built by [itemBuilder].

### `AnimatedOpacity` · class

Flutter's `AnimatedOpacity` (compositor-only).

- `AnimatedOpacity({Key? key, required double opacity, required Duration duration, Curve curve = Curves.linear, VoidCallback? onEnd, required Widget child})` — Creates a widget that animates the opacity of [child].

### `AnimatedPadding` · class

Flutter's `AnimatedPadding`.

- `AnimatedPadding({Key? key, required EdgeInsetsGeometry padding, required Duration duration, Curve curve = Curves.linear, VoidCallback? onEnd, Widget? child})` — Creates a widget that animates the padding around [child].

### `AnimatedPositioned` · class

Flutter's `AnimatedPositioned` (inside a `Stack`). Offsets and size interpolate in CSS; switching a side between set and unset jumps, as it does in Flutter.

- `AnimatedPositioned(…)` — Creates a widget that animates the position of [child] inside a `Stack`.

### `AnimatedRotation` · class

Flutter's `AnimatedRotation` ([turns] = full rotations, like Flutter).

- `AnimatedRotation(…)` — Creates a widget that animates the rotation of [child].

### `AnimatedScale` · class

Flutter's `AnimatedScale` (CSS `scale`: composes with other transforms).

- `AnimatedScale(…)` — Creates a widget that animates the scale of [child].

### `AnimatedSize` · class

Flutter's `AnimatedSize`: animates its own size when [child]'s changes.

- `AnimatedSize(…)` — Animates the height of [child].

### `AnimatedSlide` · class

Flutter's `AnimatedSlide`: [offset] is a fraction of the child's size.

- `AnimatedSlide({Key? key, required Offset offset, required Duration duration, Curve curve = Curves.linear, VoidCallback? onEnd, required Widget child})` — Creates a widget that animates the position of [child].

### `AnimatedSwitcher` · class

Flutter's `AnimatedSwitcher`: animates the switch between the states of the `Watch` it wraps.

- `AnimatedSwitcher(…)` — Animates the state switches of [child] (a `Watch`).

### `Animation` · abstract class

Flutter's `Animation<T>`: a value that changes over time, and a status.

- `Animation<T>()` — Const constructor for subclasses.

### `AnimationController` · class

Flutter's `AnimationController`: a value from [lowerBound] to [upperBound] that plays over [duration].

- `AnimationController({double? value, Duration? duration, Duration? reverseDuration, String? debugLabel, double lowerBound = 0.0, double upperBound = 1.0})` — Creates a controller at [value] (default [lowerBound]).
- `AnimationController.inView({ViewRange range = ViewRange.entry, String? debugLabel})` — A controller that runs as its element scrolls through [range] of the viewport instead of over time: an element that appears as it comes into view, with no JavaScript (a CSS view timeline).
- `AnimationController.onVisible({required Duration duration, ViewRange range = const ViewRange.span(ViewPhase.entry, 0.3, ViewPhase.exit, 1), String? debugLabel})` — A controller that plays forward over [duration], once, when its element becomes visible: an entrance for what is below the first screen, with no JavaScript (a CSS scroll trigger). [range] is the stretch of the element's pass through the viewport where it counts as visible (by default, from 30% into its entry until it has left).

### `AnimationDrive` · extension

Flutter's `Animation.drive`: `controller.drive(Tween(begin: 0.8, end: 1.0))`.


### `AnimationStatus` · enum

Flutter's `AnimationStatus`.

- values: `dismissed`, `forward`, `reverse`, `completed`

### `AnimationStatusListener` · typedef

Flutter's `AnimationStatusListener`.


### `BackdropFilter` · class

Flutter's `BackdropFilter`: filters what is behind [child], not [child] itself (a translucent panel over a blurred canvas).

- `BackdropFilter({Key? key, required ImageFilter filter, bool enabled = true, required Widget child})` — Creates a widget that applies [filter] to what is behind [child].

### `BlockSemantics` · class

Flutter's `BlockSemantics`: assistive technology ignores what is behind [child] (a modal route).

- `BlockSemantics({Key? key, bool blocking = true, required Widget child})` — Creates a widget that blocks the semantics behind [child].

### `ClipOval` · class

Flutter's `ClipOval`.

- `ClipOval({Key? key, required Widget child})` — Creates a widget that clips [child] to an oval/circle.

### `ClipRRect` · class

Flutter's `ClipRRect`. Clips the child element itself (no wrapper node).

- `ClipRRect({Key? key, BorderRadiusGeometry borderRadius = BorderRadius.zero, Clip clipBehavior = Clip.antiAlias, required Widget child})` — Creates a widget that clips [child] to a rounded rectangle.

### `ColorTween` · class

Flutter's `ColorTween`. Between theme colors (variables), the value in Dart is a `color-mix()`; the page interpolates them itself.

- `ColorTween({Color? begin, Color? end})` — A tween from [begin] to [end].

### `ConstantTween` · class

Flutter's `ConstantTween`: always the same value.

- `ConstantTween<T>(T value)` — A tween that is always `value`.

### `CountTransition` · class

A whole number that counts as [count] animates, from where it starts to where it ends: a figure of a dashboard that fills up. [prefix] and [suffix] go around it (`' %'`), in [style].

- `CountTransition({Key? key, required Animation<int> count, String prefix = '', String suffix = '', TextStyle? style, String Function(int)? format})` — Counts along [count].

### `CrossFadeState` · enum

Which child [AnimatedCrossFade] shows.

- values: `showFirst`, `showSecond`

### `Cubic` · class

A cubic Bézier curve (`cubic-bezier(a, b, c, d)`), like Flutter's `Cubic`.

- `Cubic(double a, double b, double c, double d)` — Creates a cubic Bézier curve from its four control values.

### `Curve` · abstract class

Flutter's `Curve`: maps animation progress `t` (0..1) to a value.

- `Curve()` — Const constructor for subclasses.

### `CurveTween` · class

Flutter's `CurveTween`: [curve] as an animatable.

- `CurveTween({required Curve curve})` — Applies [curve].

### `CurvedAnimation` · class

Flutter's `CurvedAnimation`: [parent] (0 to 1) through [curve], and through [reverseCurve] while it runs in reverse.

- `CurvedAnimation({required Animation<double> parent, required Curve curve, Curve? reverseCurve})` — [parent] through [curve].

### `Curves` · abstract class

Flutter's `Curves`, with the same constants.

- `Curves()`

### `DecoratedBoxTransition` · class

Flutter's `DecoratedBoxTransition`: a [DecoratedBox] whose [decoration] animates.

- `DecoratedBoxTransition({Key? key, required Animation<Decoration> decoration, DecorationPosition position = DecorationPosition.background, Widget? child})` — Animates [decoration] behind [child].

### `DecorationPosition` · enum

Where Flutter's `DecoratedBoxTransition` paints its decoration.

- values: `background`, `foreground`

### `DecorationTween` · class

Flutter's `DecorationTween`: a [BoxDecoration] from [begin] to [end].

- `DecorationTween({BoxDecoration? begin, BoxDecoration? end})` — A tween from [begin] to [end].

### `ElasticInCurve` · class

Flutter's `ElasticInCurve`.

- `ElasticInCurve([double period = 0.4])` — Creates an elastic-in curve with the given oscillation [period].

### `ElasticInOutCurve` · class

Flutter's `ElasticInOutCurve`.

- `ElasticInOutCurve([double period = 0.4])` — Creates an elastic-in-out curve with the given oscillation [period].

### `ElasticOutCurve` · class

Flutter's `ElasticOutCurve` (and In/InOut).

- `ElasticOutCurve([double period = 0.4])` — Creates an elastic-out curve with the given oscillation [period].

### `ExcludeSemantics` · class

Flutter's `ExcludeSemantics`: hides decorative content (image placeholders, duplicated labels) from assistive technology.

- `ExcludeSemantics({Key? key, bool excluding = true, required Widget child})` — Creates a widget that excludes [child] from the accessibility tree.

### `FadeTransition` · class

Flutter's `FadeTransition`: [opacity] of the child (compositor-only).

- `FadeTransition({Key? key, required Animation<double> opacity, bool alwaysIncludeSemantics = false, Widget? child})` — Fades [child] by [opacity].

### `FlippedCurve` · class

Flutter's `FlippedCurve`.

- `FlippedCurve(Curve curve)` — Creates a curve that plays [curve] backwards.

### `IgnorePointer` · class

Flutter's `IgnorePointer`: [child] doesn't take pointer events, and neither does its content; the events go through to what is behind.

- `IgnorePointer({Key? key, bool ignoring = true, bool? ignoringSemantics, required Widget child})` — Creates a widget that is invisible to pointers when [ignoring].

### `ImplicitlyAnimatedWidget` · abstract class

Common API of the `Animated*` widgets.

- `ImplicitlyAnimatedWidget({Key? key, required Duration duration, Curve curve = Curves.linear, VoidCallback? onEnd})` — Creates a base for widgets that implicitly animate their properties.

### `IntTween` · class

Flutter's `IntTween`: whole numbers from [begin] to [end], rounded (a count).

- `IntTween({int? begin, int? end})` — A tween from [begin] to [end].

### `Interval` · class

Flutter's `Interval`: [curve] runs between [begin] and [end] of the parent animation (staggered animations).

- `Interval(double begin, double end, {Curve curve = Curves.linear})` — Creates an interval curve running from [begin] to [end], easing with [curve] in between.

### `MergeSemantics` · class

Flutter's `MergeSemantics`: [child]'s content is one node for assistive technology.

- `MergeSemantics({Key? key, required Widget child})` — Creates a widget that merges the semantics of [child] into one node.

### `NoScript` · class

Shows [child] only when the page runs without JavaScript: the fallback a native-first page keeps for no JS (the submit button of a form whose controls apply on their own with the engine), gone and out of the accessibility tree when scripting is on.

- `NoScript({Key? key, required Widget child})` — Shows [child] only without scripting.

### `Offstage` · class

Flutter's `Offstage`.

- `Offstage({Key? key, bool offstage = true, required Widget child})` — Creates a widget that hides [child] without removing it from the tree.

### `Opacity` · class

Flutter's `Opacity` (GPU-composited `opacity`).

- `Opacity({Key? key, required double opacity, required Widget child})` — Creates a widget that makes [child] partially transparent.

### `OrdinalSortKey` · class

Flutter's `OrdinalSortKey`: nodes are read by increasing [order].

- `OrdinalSortKey(double order, {String? name})` — Creates a sort key at position [order].

### `ReverseAnimation` · class

Flutter's `ReverseAnimation`: 1 minus [parent]'s value, status flipped.

- `ReverseAnimation(Animation<double> parent)` — The reverse of [parent].

### `RotationTransition` · class

Flutter's `RotationTransition`: [turns] full rotations (1.0 = 360°).

- `RotationTransition({Key? key, required Animation<double> turns, Alignment alignment = Alignment.center, Widget? child})` — Rotates [child] by [turns] around [alignment].

### `ScaleTransition` · class

Flutter's `ScaleTransition` (CSS `scale`: composes with the other transforms of the element).

- `ScaleTransition({Key? key, required Animation<double> scale, Alignment alignment = Alignment.center, Widget? child})` — Scales [child] by [scale] around [alignment].

### `Semantics` · class

Flutter's `Semantics`, reduced to what maps onto ARIA.

- `Semantics(…)` — Creates a widget that attaches accessibility metadata to [child].

### `SemanticsRole` · enum

Flutter's `SemanticsRole`: what a widget is for assistive technology. On the web most roles are HTML elements; the rest are ARIA roles.

- values: `none`, `list`, `listItem`, `main`, `navigation`, `complementary`, `contentInfo`, `region`, `form`, `table`, `toolbar`, `row`, `cell`, `columnHeader`, `grid`, `gridCell`, `rowHeader`, `dragHandle`, `status`, `alert`, `note`, `radioGroup`, `tooltip`, `progressBar`, `loadingSpinner`, `spinButton`, `hotKey`, `slider`, `listBox`, `image`, `tab`, `tabBar`, `tabPanel`, `dialog`, `alertDialog`, `menu`, `menuBar`, `menuItem`, `menuItemCheckbox`, `menuItemRadio`, `comboBox`, `searchBox`, `checkbox`, `radio`, `switchRole`, `option`, `article`, `paragraph`, `header`, `preformatted`, `keyboardKey`, `figure`, `figureCaption`, `blockquote`, `label`

### `SemanticsSortKey` · abstract class

Flutter's `SemanticsSortKey`: the order a node is read in.

- `SemanticsSortKey({String? name})` — Creates a sort key.

### `SizeTransition` · class

Flutter's `SizeTransition`: [sizeFactor] (0 to 1) is the fraction of the child's size that shows along [axis], clipped, with the child aligned by [axisAlignment] (-1 start, 0 center, 1 end).

- `SizeTransition({Key? key, Axis axis = Axis.vertical, required Animation<double> sizeFactor, double axisAlignment = 0.0, Widget? child})` — Shows [sizeFactor] of [child] along [axis].

### `SlideTransition` · class

Flutter's `SlideTransition`: [position] is a fraction of the child's size (CSS `translate` in %).

- `SlideTransition({Key? key, required Animation<Offset> position, bool transformHitTests = true, TextDirection? textDirection, Widget? child})` — Moves [child] by [position].

### `ThreePointCubic` · class

Flutter's `ThreePointCubic`: two cubics sharing a [midpoint]. Sampled into `linear()` in CSS (it is not one `cubic-bezier()`).

- `ThreePointCubic(Offset a1, Offset b1, Offset midpoint, Offset a2, Offset b2)` — Creates two cubic curves that share the control point [midpoint]; the ends (0, 0) and (1, 1) are implied.

### `Threshold` · class

Flutter's `Threshold`: jumps from 0 to 1 at [threshold].

- `Threshold(double threshold)` — Creates a threshold curve that jumps from 0 to 1 at [threshold].

### `Transform` · class

Flutter's `Transform` with its named constructors. Uses CSS transforms, which run on the compositor and do not trigger layout.

- `Transform.rotate({Key? key, required double angle, Alignment alignment = Alignment.center, required Widget child})` — Creates a widget that rotates [child] by [angle] radians.
- `Transform.scale({Key? key, required double scale, Alignment alignment = Alignment.center, required Widget child})` — Creates a widget that scales [child] by [scale].
- `Transform.flip({Key? key, bool flipX = false, bool flipY = false, required Widget child})` — Creates a widget that mirrors [child] horizontally ([flipX]) and/or vertically ([flipY]).
- `Transform.translate({Key? key, required Offset offset, required Widget child})` — Creates a widget that translates [child] by [offset].

### `Tween` · class

Flutter's `Tween`: a linear interpolation from [begin] to [end].

- `Tween<T>({T? begin, T? end})` — A tween from [begin] to [end].

### `TweenAnimationBuilder` · class

Flutter's `TweenAnimationBuilder`: builds [builder] with the tween's target and animates the change when the target changes.

- `TweenAnimationBuilder<T>(…)` — Builds [builder] with the target of [tween] and transitions what it returns when the target changes.

### `TweenSequence` · class

Flutter's `TweenSequence`: several tweens one after another.

- `TweenSequence<T>(List<TweenSequenceItem<T>> items)` — Plays [items] in order, each over its share of 0 to 1.

### `TweenSequenceItem` · class

Flutter's `TweenSequenceItem`: a [tween] over a share ([weight]) of the sequence.

- `TweenSequenceItem<T>({required Animatable<T> tween, required double weight})` — An item of a [TweenSequence].

### `ViewPhase` · enum

A stage of an element's pass through the viewport, as it scrolls: the named ranges of a CSS view timeline.

- values: `cover`, `contain`, `entry`, `exit`

### `ViewRange` · class

The stretch of scrolling over which an [AnimationController.inView] runs from its lower bound to its upper bound: from [start] of [startPhase] to [end] of [endPhase], each a fraction of its phase (0 to 1).

- `ViewRange({ViewPhase phase = ViewPhase.entry, double start = 0, double end = 1})` — From [start] to [end] of one [phase].
- `ViewRange.span(ViewPhase startPhase, double start, ViewPhase endPhase, double end)` — From [start] of [startPhase] to [end] of [endPhase].

### `Visibility` · class

Flutter's `Visibility`.

- `Visibility({Key? key, bool visible = true, bool maintainSize = false, required Widget child})` — Creates a widget that shows or hides [child].

## `estado` · State in the browser

### `AsyncSnapshot` · class

The latest outcome of a query, as Flutter's `AsyncSnapshot<T>`.

- `AsyncSnapshot<T>.nothing()` — A snapshot connected to nothing: no data, no error.
- `AsyncSnapshot<T>.waiting([T? data])` — A snapshot waiting for a call, with the [data] of the last one if any.
- `AsyncSnapshot<T>.done([T? data])` — A snapshot of a finished call with [data] (null for a call that answered null).
- `AsyncSnapshot<T>.withData(ConnectionState connectionState, T data)` — A snapshot in [connectionState] with [data].
- `AsyncSnapshot<T>.placeholder(ConnectionState connectionState)` — A snapshot that says it has data it doesn't hold: [hasData] is true and reading [data] throws. `QueryBuilder` draws its "has data" states with it when the server has no data to draw them with (a query the browser runs, or one that failed), so the browser can switch to them once the data arrives: a builder that only reads [hasData] and binds what changes (`Watch`, `row.text`) draws them right; one that reads [data] or [requireData] throws, and that state is not shipped.
- `AsyncSnapshot<T>.withError(ConnectionState connectionState, String error, [ServerErrorKind? errorKind = ServerErrorKind.server])` — A snapshot in [connectionState] with an [error] message and its [errorKind].

### `BoundLength` · class

A length that follows a `ThorState` value, in logical pixels: padding, a radius, a font size, a size or a position that change in the browser without a rebuild.

- `BoundLength(num Function() source)` — Follows [source]: a field of a `ThorState` (`card.radius.px`) or a method of one that returns pixels, torn off or with `withArg`.

### `BoundLengthOfField` · extension

`card.radius.px`: a [BoundLength] that follows a state field of pixels, as `16.px` is a fixed one.


### `BoundLengthOfMethod` · extension

`card.radiusPx.px`: a [BoundLength] that follows a state method that returns pixels (`withArg` too: `grid.width.withArg(2).px`).


### `Clipboard` · abstract class

Flutter's `Clipboard`, from a state method:

- `Clipboard()`

### `ClipboardData` · class

Flutter's `ClipboardData`: the text on the clipboard.

- `ClipboardData({required String text})` — Clipboard contents holding [text].

### `Computed` · class

A derived value, recomputed lazily when a dependency changes.

- `Computed<T>(T Function() _compute)` — Creates a value derived from [_compute].
- `Computed<T>.scoped(T Function() _compute)` — What `derived(...)` makes: inside a request's scope the value is also kept (until a signal is written there), so a derivation read by several `Watch`es of one page runs once on the server too.

### `ConfirmSpec` · class

The question of a confirmation: what [confirm] asks and what a button's `confirm:` shows before it submits.

- `ConfirmSpec(String title, {String? message, String? confirmLabel, String? cancelLabel})` — Asks [title] (the question), with an optional [message] under it and the labels of its two buttons (the app's `ServerMessages.ok` and `.cancel` when null).

### `ConnectionState` · enum

Where an asynchronous computation is (Flutter's `ConnectionState`).

- values: `none`, `waiting`, `active`, `done`

### `DialogController` · class

Opens and closes a native dialog (`Drawer`, `AlertDialog`, `ModalBottomSheet`) from a state method, as a field of a `ThorState`:

- `DialogController()` — A controller for a closed dialog.

### `EngineLoading` · enum

When the browser runs the page's engine script.

- values: `eager`, `onIdle`

### `FlutterView` · class

A region of the page drawn by a Flutter web app ("hybrid mode"): a chart, an editor or a game inside an otherwise thor (HTML) page.

- `FlutterView(…)` — Creates a view of the Flutter build at [src].

### `FlutterViewLoading` · enum

When a [FlutterView] downloads Flutter and draws itself.

- values: `eager`, `idle`, `visible`, `interaction`

### `FocusNode` · class

Flutter's `FocusNode`, as a field of a `ThorState`: moves the keyboard focus from a method (`editorFocus.requestFocus()` after opening an editor). The widget that owns it is `Focus(focusNode:)` or `TextField(focusNode:)`.

- `FocusNode()` — A focus node.

### `FrameMessages` · abstract class

Talks to an `<iframe>` of the page (or to the page that holds this one) from a state method, with `postMessage`:

- `FrameMessages()`

### `FrameSubscription` · class

A running [FrameMessages.listen]: [cancel] it from `dispose()`.

- `FrameSubscription(void Function() onCancel)` — A subscription that runs [onCancel] once.

### `FutureBuilder` · class

Flutter's `FutureBuilder`: draws [builder] with the state of [future].

- `FutureBuilder<T>({Key? key, required Future<T>? future, required Widget Function(BuildContext, AsyncSnapshot<T>) builder, T? initialData})` — Draws [builder] with [future]'s state.

### `LazyPiece` · class

A part of the page the server draws only when the browser asks for it: the lazy content of an accordion, a drawer or a tab, which the page does not carry (a menu with 750 entries, the reviews of a product).

- `LazyPiece<T>(…)` — A piece called [id] that draws [builder] with what [load] returns.

### `LazyTrigger` · enum

What makes a [LazyPiece] load.

- values: `open`, `visible`, `idle`

### `PageController` · class

Flutter's `PageController`, as a field of a `ThorState`: the page a `PageView(controller:)` shows, and the way to move it.

- `PageController({int initialPage = 0, bool keepPage = true, double viewportFraction = 1.0})` — A controller starting at [initialPage].

### `PageNavigator` · abstract class

Goes to another page from a state method, like following a link: the browser loads [go]'s location as a new document (its server render, its speculation rules, its history entry). There is no client router.

- `PageNavigator()`

### `QueryBuilder` · class

Flutter's `FutureBuilder` for a `query`: [builder] draws the query's [AsyncSnapshot], on the server for the first paint and, in the browser, by switching among the states the server shipped.

- `QueryBuilder<T>({Key? key, required ServerQuery<Object?, T> query, required Widget Function(BuildContext, AsyncSnapshot<T>) builder, T? initialData})` — Draws [query] with [builder].

### `QueryError` · class

The visitor's message of a failed [query], bound to the page (a text that follows the query in the browser): the error state of a [QueryBuilder] shows it with this, since its builder runs on the server.

- `QueryError(ServerQuery<Object?, Object?> query, {Key? key, TextStyle? style})` — Shows the message of [query], styled with [style].

### `ReadSignal` · abstract class

What can be read as `.value` and tracked: a [Signal] is one of those to its readers, and so is the result of `derived(...)`, which cannot be written.

- `ReadSignal<T>()`

### `RowColor` · class

A [Color] that follows a value of the item per list row: what `row.color(…)` returns. It goes wherever a `Color` does (a `Container`'s `color`, a `BoxDecoration`, a `TextStyle`); the row's element gets its binding and first value, the app never names the variable.


### `RowLength` · class

A [Length] that follows a method of the state per list row: what `row.length(…)` returns. It goes wherever a `Length` does; the row's element gets its binding and first value, the app never names the variable.


### `ScrollController` · class

Flutter's `ScrollController`, as a field of a `ThorState`:

- `ScrollController({double initialScrollOffset = 0})` — A controller starting at [initialScrollOffset].

### `ScrollPosition` · class

Flutter's `ScrollPosition`, reduced to what a page reads.


### `ServerCommand` · class

A command without an argument ([command]): `onPressed: cart.clear.run`.


### `ServerCommandWith` · class

A command with an argument ([commandWith]): `onPressed: cart.add.run.withArg(sku)`.


### `ServerErrorKind` · enum

The reason a server call failed.

- values: `network`, `timeout`, `aborted`, `unauthorized`, `forbidden`, `validation`, `client`, `server`

### `ServerEventStream` · class

A [ServerQuery] that stays up to date from the server's events: `final feed = events<List<Quote>>('/quotes/stream', ...)`.


### `ServerMessages` · class

What the visitor reads when a `query` or a `command` fails: the ones the server writes (a sign-in, a bad request, a generic failure) and the ones the browser shows for what it finds itself (no network, a timeout), and the buttons of the page that stands in for the confirm dialog. Set once in `ThorApp(serverMessages:)`; the server puts the browser's in the page, so the client never carries a string of its own.

- `ServerMessages(…)` — Pass only what the app wants to say itself; the rest is the visitor's language ([forLocale]), English by default.

### `ServerQuery` · class

A value a [ServerQuery] computes on the server (see [query]).


### `Signal` · class

A reactive value (Flutter's `ValueNotifier`, but tracked automatically).

- `Signal<T>(T _value)` — Creates a signal holding [_value].

### `StateBoolToggle` · extension

`StateSignal<bool>.toggle()`: `open.toggle()` instead of `open.value = !open.value`.


### `StateSetOps` · extension

A set field (`final picked = state(<String>{});`) with the operations a selection needs. `// web:` a set changes by a new value, like a list (`todos.value = [...]`): `add`, `remove`, `toggle` and `clear` assign a new set, so `Watch`, `row.watch` and listeners notice, and one already read is never mutated. A change that changes nothing (`add` of a member) assigns nothing. The value stays immutable: nothing is changed in place.


### `StateSignal` · class

A reactive field of a [ThorState] (see [state]). The server writes its value into the page and the browser starts from it.


### `SystemNavigator` · abstract class

Flutter's `SystemNavigator`, for the address bar: `SystemNavigator.routeInformationUpdated(uri: …, replace: true)` from a state method keeps the URL in step with the page's state (a filter in the query), so a reload renders the same view. No-op on the server.

- `SystemNavigator()`

### `TextEditingController` · class

Flutter's `TextEditingController`, as a field of a `ThorState`: the text of the fields that use it (`TextField(controller: form.name)`). Typing updates [text]; setting [text] in a method updates the fields.

- `TextEditingController({String? text})` — A controller holding [text].

### `TextEditingValue` · class

Flutter's `TextEditingValue`: the text of a field and where its caret is (what `TextEditingController.value` holds, and what an `AutocompleteOptionsBuilder` is asked about).

- `TextEditingValue({String text = '', TextSelection selection = const TextSelection.collapsed(offset: -1)})` — A value with [text] and [selection] (a caret nowhere by default).

### `TextSelection` · class

Flutter's `TextSelection`, reduced to offsets: where a field's caret or selected range is ([baseOffset] is where it started, [extentOffset] where it ends; a collapsed one is a caret).

- `TextSelection({required int baseOffset, required int extentOffset})` — A range from [baseOffset] to [extentOffset].
- `TextSelection.collapsed({required int offset})` — A caret at [offset].

### `ThorController` · abstract class

A field type a `ThorState` exposes by id (the generator lists it as a controller member): [ScrollController], [TextEditingController], [FocusNode], and `AnimationController`.

- `ThorController()`

### `ThorFeedback` · abstract class

Where the page's dialog and snack bar plug in. The engine installs these when the page loads; a test installs its own.

- `ThorFeedback()`

### `ThorState` · abstract class

Base of every screen state: `class CartState extends ThorState`.

- `ThorState({String? key})` — Creates the state. With [key], several instances of one class can live on the same page (`CounterState(key: 'left')`).

### `ToastKind` · enum

What a message is about: how a [toast] (or a server flash) looks.

- values: `info`, `success`, `error`

### `ValueListenableBuilder` · class

Flutter's `ValueListenableBuilder` on a field of a [ThorState]: a [Watch]. The server renders the builder once per value (`bool` or enum fields) and the browser shows the one that matches, like any `Watch`.

- `ValueListenableBuilder<T>({Key? key, required ValueListenable<T> valueListenable, required Widget Function(BuildContext, T, Widget?) builder, Widget? child})` — Builds [builder] for each value of [valueListenable].

### `Watch` · class

The part of a page that changes in the browser, bound to a field or a method of a [ThorState]:

- `Watch<T>(T Function() source, {Key? key, Widget Function(T)? builder, int? count, TextStyle? style})` — Watches [source]: a method torn off from a ThorState (`counter.label`, `cart.isSelected.withArg(i)`) or a reactive field (`counter.count`). With a [builder] use [Watch.field] for a field: passed here as is, the compiler infers `Object?` for the builder's value (the analyzer doesn't; the `watch_field_with_builder` lint catches it), unless the builder names the type (`(bool visible) => …`).
- `Watch<T>.field(StateSignal<T> field, {Key? key, Widget Function(T)? builder, int? count, TextStyle? style})` — Watches a `state(...)` field of a [ThorState] directly, with or without a [builder]:

### `WatchAttributes` · class

HTML attributes of [child]'s element whose values come from a `ThorState` (outside a list; in a list row use `row.attribute`): each method returns the attribute's value, kept current in the browser.

- `WatchAttributes(Map<AttributeName, Object? Function()> attributes, {Key? key, Set<AttributeName> clientOnly = const {}, required Widget child})` — Binds each attribute of [attributes] to its method.

### `WatchItem` · class

One row of a list [Watch]: its [key] and its changing texts.


### `WatchRow` · class

One row of a [Watch.list]: [key] typed like `itemKey`'s result, and the methods of [WatchItem] taking the item type [I], so a lambda or a tear-off is checked against it.


### `WatchVariables` · class

CSS custom properties of [child]'s element whose values come from a `ThorState`: each method returns a number of pixels, written as `--name: <n>px` and kept current in the browser.

- `WatchVariables(Map<CssVariable<Length>, num Function()> variables, {Key? key, required Widget child})` — Binds each variable of [variables] to its method.

### `batch` · function

Groups several writes: each dependent effect runs once, at the end.

- `void batch(void Function() fn)`

### `clearToasts` · function

Ends the message the snack bar is showing and forgets the ones waiting.

- `void clearToasts()`

### `command` · function

A change made on the server: `final clear = command(cart.clear);`.

- `ServerCommand<R> command<R, S extends ThorState>(FutureOr<R> Function() fn, {List<ServerQuery<Object?, Object?>> Function(S)? invalidates, Duration? timeout, bool writes = true})`

### `commandWith` · function

[command] with an argument: `final add = commandWith(cart.add);` and `onPressed: cartState.add.run.withArg(sku)`. The argument is a simple value (`int`, `double`, `num`, `String`, `bool`), a record of them or a class of the app with `toJson()` and a `fromJson` factory, as in [queryWith] (THOR-B021); the server checks it before [fn] runs.

- `ServerCommandWith<A, R> commandWith<A, R, S extends ThorState>(…)`

### `confirm` · function

Asks [title] in the page's one native `<dialog>` and completes with whether the visitor confirmed: `false` for Cancel, Esc or a click outside. Two calls at once are asked one after the other, in order.

- `Future<bool> confirm(String title, {String? message, String? confirmLabel, String? cancelLabel})`

### `defer` · function

Starts [future] for a page that shows it later (`FutureBuilder`): the same future, marked as handled, so a failure that happens before the page reads it (or on a page that never does) is not an unhandled error that stops the server. The error still reaches whoever listens.

- `Future<T> defer<T>(Future<T> future, {bool head = false, Duration? headBudget})`

### `derived` · function

A value computed from other fields and kept: `late final visible = derived(() => rows.value.where(...).toList());`, read as `visible.value` (or `Watch(visible.call, …)`, `Watch.list(visible.call, …)`). The function runs once per change of the fields it reads, however many `Watch`es or methods read the result, and not at all while they don't change; a method that computes the same list in each `Watch` runs it in each one.

- `ReadSignal<T> derived<T>(T Function() compute)`

### `effect` · function

Runs [fn] now and again whenever a signal it read changes. Returns a function that stops it.

- `void Function() effect(void Function() fn)`

### `events` · function

[query]'s function, kept up to date by the server's events: an `EventSource` the browser opens on [url].

- `ServerEventStream<T> events<T>(String url, {String event = 'message', FutureOr<T> Function()? initial, String? key, Duration? timeout})`

### `hideToast` · function

Ends the message the snack bar is showing now; the next one waiting (if any) shows. Does nothing when none is showing.

- `void hideToast()`

### `query` · function

A value computed on the server: `final info = query(repo.info);`.

- `ServerQuery<Null, T> query<T>(FutureOr<T> Function() fn, {Duration? timeout, bool ssr = true})`

### `queryWith` · function

[query] with an argument: `queryWith(orders.page, arg: 0)`. [arg] is a simple value (`int`, `double`, `num`, `String`, `bool`), a record of them or a class of the app with `toJson()` and a `fromJson` factory (THOR-B021):

- `ServerQuery<A, T> queryWith<A, T>(FutureOr<T> Function(A) fn, {required A arg, Duration? timeout, bool ssr = true})`

### `registerJsonModel` · function

Teaches the engine to read and write a class of the app as JSON, so a `state<List<Order>>(...)` (or `state<Order>`, `state<Map<String, Order>>`) needs no `encode:`/`decode:`: the class has `toJson()` and a `factory fromJson(Map<String, Object?> json)`, like a query's result does.

- `void registerJsonModel<M extends Object>(M Function(Map<String, Object?>) fromJson, Object? Function(M) toJson)`

### `state` · function

A reactive field of a [ThorState]: `final count = state(0);`. Values that are not JSON (numbers, strings, bools, lists and maps of them) need [encode] and [decode] to travel from the server to the page.

- `StateSignal<T> state<T>(T initial, {Object? Function(T)? encode, T Function(Object?)? decode, String? cookie, String? local})`

### `toast` · function

Shows [message] in the page's one snack bar, for [duration] (4 s by default). Calls that come while one is showing wait their turn (a few at most: a flood keeps the newest); the same message twice in a row shows once. Screen readers hear it (`role=status`).

- `void toast(String message, {ToastKind kind = ToastKind.info, Duration? duration})`

### `untracked` · function

Reads signals inside [fn] without subscribing the current effect.

- `T untracked<T>(T Function() fn)`

## `server` · `package:thor_ui/server.dart`

### `Document` · abstract class

A whole page: `<html>`, its `<head>` and `<body>`, the entry of a static app (`runApp(Document(...))`).

- `Document({Key? key, String? title, Locale? lang, String? dir, String? base, String? charset, String? viewport, Map<String, String> meta, List<Widget> head, required Widget body})`
- `Document.head({Key? key, String? title, Map<String, String>? meta, List<Widget>? children})` — Elements for the `<head>` from anywhere in the page (a stylesheet a widget needs, the page title). See [HeadPortal] for which one wins when two say the same.

### `Locale` · class

Flutter's `Locale`: a language, optionally with a script and a region.

- `Locale(String languageCode, [String? countryCode])` — A locale for [languageCode] (`es`) and optionally [countryCode] (`MX`).
- `Locale.fromSubtags({String languageCode = 'und', String? scriptCode, String? countryCode})` — A locale from its subtags (`und` when there is no language).

### `initializeThor` · function

Initializes thor on the server. Call it once, before `runApp`.

- `void initializeThor({List<StyleRule>? styles})`

### `runApp` · function

Serves [app] (a `Document`): the entry of a static app.

- `void runApp(Widget app)`

## `router` · `package:thor_ui/router.dart`

### `ActionOutcome` · abstract class

A value an action can return that knows its own [ActionResult]: a failed form (`FormInvalid` of `thor_ui/router.dart`) is a `422` with itself as `state.form`, never a `200` that drops it.

- `ActionOutcome()`

### `ActionResult` · class

What an action returns: a [Redirect], or the page again ([ActionResult.fail], [ActionResult.success]).

- `ActionResult.fail(int status, [Object? data])` — The action failed: the page renders again with [status] and [data] as its `state.form` (the values to re-fill and the errors to show).
- `ActionResult.success([Object? data])` — The action worked and the page renders again (no redirect) with [data] as its `state.form`.

### `ChangeFrequency` · enum

`<changefreq>` values.

- values: `always`, `hourly`, `daily`, `weekly`, `monthly`, `yearly`, `never`

### `CheckboxSchemaField` · class

A checkbox: `true` when it was sent checked. `Validator.required` means it must be checked.

- `CheckboxSchemaField(String name, {List<Validator> validators = const [], bool Function(FormData)? when})` — A checkbox field.

### `ChoiceSchemaField` · class

One of [choices] (a `<select>` or radio buttons): any other value is refused with [invalid], whatever the browser allowed (a tampered form).

- `ChoiceSchemaField(String name, {required List<String> choices, List<Validator> validators = const [], String? invalid, bool Function(FormData)? when})` — A choice field.

### `CommandAnswer` · class

What a command answered ([ServerCommands.runCommand]).

- `CommandAnswer(…)` — The command's [result], the new values of the page's [queries] (by id), the visitor's message and the kind of each query that failed ([errors], [kinds]) and what those threw ([thrown], reported like a load's error).

### `ContentSecurityPolicy` · class

A Content-Security-Policy, typed (use it with [contentSecurityPolicy]).

- `ContentSecurityPolicy(…)` — A policy. The defaults are strict: everything from the site itself, no plugins, no framing, `<base>` and forms to the site only.

### `ContextKey` · class

The key of a typed value in [RequestContext]: declare it once, next to the middleware that sets it.

- `ContextKey<T>(String name, {bool personal = true})` — A key; [name] shows in errors.

### `CspHashAlgorithm` · enum

Hash algorithms of a [CspSource.hash].

- values: `sha256`, `sha384`, `sha512`

### `CspSource` · class

One source of a [ContentSecurityPolicy] directive: a keyword ([CspSource.self]), a scheme ([CspSource.data]), a host ([CspSource.host]) or a hash ([CspSource.hash]). Typed so a typo in a quote (`self` for `'self'`) cannot silently turn a keyword into a host.

- `CspSource.host(String host)` — A host source: `https://cdn.example.com`, `*.example.com`, `example.com:8443`. Throws on a character that would end the source or the directive (space, `;`, `,`, quotes).
- `CspSource.scheme(String scheme)` — A scheme source (`https`, `wss`): `https:`.
- `CspSource.hash(CspHashAlgorithm algorithm, String base64Digest)` — The base64 digest of an inline script, style or handler.

### `DateSchemaField` · class

A calendar date, `yyyy-mm-dd` (what `<input type=date>` sends): a UTC `DateTime` at midnight (`null` when empty). An impossible date (`2023-02-29`) or another format fails with [invalid]. Bound it with `Validator.minDate` / `Validator.maxDate`.

- `DateSchemaField(String name, {List<Validator> validators = const [], String? invalid, bool Function(FormData)? when})` — A date field.

### `DeferredRender` · abstract class

A [PageRenderer] that can answer with the page first and the values that are still loading after it (streaming SSR).

- `DeferredRender()`

### `DiscoveredLinks` · abstract class

A [PageRenderer] that finds, while it draws a page, files worth fetching early that it couldn't know before (the page's main image). The handler adds them to the `Link` header of that response and, for a page every visitor sees alike, remembers them for the next request of the same path: its early answer and a CDN's `103 Early Hints` get them before the render.

- `DiscoveredLinks()`

### `DoubleSchemaField` · class

A decimal number (`null` when empty). A value that is not one (`abc`, `NaN`, `Infinity`, `0x10`, `1,5`) fails with [invalid].

- `DoubleSchemaField(String name, {List<Validator> validators = const [], String? invalid, bool Function(FormData)? when})` — A decimal number field.

### `EarlyHints` · abstract class

A [PageRenderer] that knows, before a page is rendered, the files it will link (its shared stylesheets): the `Link` header of every page it draws, and what `earlyHints` sends ahead of a slow one.

- `EarlyHints()`

### `EnvBool` · class

`true`/`false` (also `1`/`0`, `yes`/`no`, any case).

- `EnvBool(String name, {bool? fallback, bool public = false})` — [name], with [fallback] when it is not set.

### `EnvError` · class

The environment was missing variables or had invalid ones (THOR-P011).

- `EnvError(List<String> problems)` — An error with every [problems] line.

### `EnvInt` · class

A whole number.

- `EnvInt(String name, {int? fallback, bool public = false})` — [name], with [fallback] when it is not set.

### `EnvOptional` · class

[variable] made optional: `null` when it is not set, checked like [variable] when it is (`EnvOptional(EnvSecret('SESSION_SECRET'))`, `EnvOptional(EnvInt('ISOLATES'))`).

- `EnvOptional<T>(EnvVar<T> variable)` — [variable], or `null` when unset.

### `EnvSchema` · class

An app's environment, declared once and checked at startup.

- `EnvSchema(List<EnvVar<Object?>> vars)` — A schema with [vars] (names must be unique).

### `EnvSecret` · class

A secret: required (no fallback), never public, at least [minLength] characters.

- `EnvSecret(String name, {int minLength = 16})` — [name], at least [minLength] characters.

### `EnvString` · class

A text variable.

- `EnvString(String name, {String? fallback, bool public = false})` — [name], with [fallback] when it is not set.

### `EnvUrl` · class

An absolute `http`/`https` URL.

- `EnvUrl(String name, {String? fallback, bool public = false})` — [name], with [fallback] (a URL) when it is not set.

### `EnvValues` · class

The loaded environment.


### `EnvVar` · sealed class

One environment variable of an [EnvSchema].

- `EnvVar<T>(String name, {bool public = false})`

### `ErrorPage` · abstract class

The page a [Group] shows when something below it fails: a `NotFound` from a `load`, a URL with no route, an exception. Like [ThorPage] and [ThorLayout], one const instance in the table; it renders inside the group's layout, with the failure in [ErrorState] (`status`, `message`).

- `ErrorPage()` — An error page.

### `ErrorState` · class

State of an error page.

- `ErrorState({required PageRequest request, required int status, String? message})` — An error with [status].

### `FlashKind` · enum

What a flash is about: how the page draws it.

- values: `info`, `success`, `error`

### `FlashMessage` · class

A flash: its [kind] and its [message] (text: the page escapes it).

- `FlashMessage(String message, [FlashKind kind = FlashKind.info])` — A flash with [message], cut to [flashMaxLength].

### `FormAction` · typedef

Handles a form `POST` (`<form method=post action="?/name">`). Returns a `Redirect`, an `ActionResult` or `null` (= redirect back to the page).


### `FormData` · class

A submitted form: every field with all its values, in order, and the files of its file inputs.

- `FormData(Map<String, List<String>> fields, {Map<String, List<UploadedFile>> files = const {}})` — Wraps [fields] (and [files]).
- `FormData.parse(String body)` — Parses an `application/x-www-form-urlencoded` body.

### `FormInvalid` · class

Some rule failed (or the backend refused): what the page shows again.

- `FormInvalid(…)` — A failure with field [errors] (one message per field) and [fieldErrors] (several), the [formErrors] and the [values] to re-fill (never a secret field's). [valueLists] are the values of a field sent more than once (a repeated input), in order.

### `FormResult` · sealed class

The outcome of [FormSchema.parse].

- `FormResult()`

### `FormSchema` · class

A form declared once: the fields, their types and their rules.

- `FormSchema(List<SchemaField<Object?>> fields)` — A schema with [fields] (names must be unique).

### `FormValid` · class

Every rule passed: the typed values.


### `FormValues` · class

The values of a submitted form of schema [S] that passed every rule: what an `onValid:` action method receives. The method never runs with an invalid form (the page answers `422` with the messages first).

- `FormValues<S>.from(FormValid form)` — The values of a valid form (a test builds them with `FormValues.from(schema.validate(data) as FormValid)`).

### `FrameOptions` · enum

`X-Frame-Options`: who may put the page in a frame.

- values: `deny`, `sameOrigin`

### `Group` · class

Routes that share what a folder used to give: a [layout] around them, a [middleware], the [error] and [notFound] pages, a stylesheet ([styles]) and settings the pages below inherit. It adds nothing to the URL.

- `Group(…)` — Routes and groups with what they share.

### `Guard` · typedef

Runs before `load`: a path to redirect to (e.g. `/login`), or `null`.


### `HiddenField` · class

A value the form posts along with its fields and the visitor never sees: `<input type="hidden">`.

- `HiddenField({Key? key, required String name, required String value})` — Posts [name]=[value] with the enclosing form.

### `HttpError` · class

Ends the request with an error [status]: the error page of the nearest group (`Group(error:)`) renders it. [message] is shown to the user; keep it free of internals.

- `HttpError(int status, [String? message])` — An error with [status].

### `HttpHeader` · extension type

The name of an HTTP header: the key type of every header map (a request's [PageRequest.headers], a response's `headers`, a client call's), with typed constants for the common ones in the lowercase spelling those maps use.

- `HttpHeader(String name)`

### `HttpMethod` · enum

An HTTP request method.

- values: `get`, `head`, `post`, `put`, `patch`, `delete`, `options`, `trace`, `connect`

### `ImageEntry` · class

One image: its intrinsic size and the files the build made from it.

- `ImageEntry({required int width, required int height, required String src, List<ImageVariant> variants = const []})` — An image [width]×[height] px whose fallback is [src].

### `ImageManifest` · class

Every image a build knows, by the name `Image.asset` uses.

- `ImageManifest(Map<String, ImageEntry> images)` — A manifest with [images].
- `ImageManifest.fromJson(Object? json)` — Reads the JSON the build writes. A shape it doesn't know throws a [FormatException] naming the entry.

### `ImageVariant` · class

A file the build made from an image: [width] px wide, of [type].

- `ImageVariant({required int width, required String type, required String src})` — A variant at [src].

### `IntSchemaField` · class

A whole number (`null` when empty). A value that is not one fails with [invalid].

- `IntSchemaField(String name, {List<Validator> validators = const [], String? invalid, bool Function(FormData)? when})` — A number field.

### `LayoutRoute` · class

A layout: what a `Group(layout:)` of the route table becomes. Wraps every page below it.

- `LayoutRoute<P, T>(…)` — A layout at [path] with its [children].

### `LinkHint` · class

A file the pages of a request link, for the browser to fetch before it reads the document: one entry of the `Link` header of the response. A proxy that sends `103 Early Hints` (a CDN) turns these into hints before the page; with `earlyHints` the server sends them itself ahead of a slow page.

- `LinkHint(…)` — [href] with [rel] (`preload` by default), [as], [type] and whether it is fetched [crossOrigin] (fonts must be).
- `LinkHint.style(String href)` — A stylesheet the page links.
- `LinkHint.speculationRules(String href)` — The page's speculation rules, as a file the browser fetches instead of an inline `<script type="speculationrules">` (a strict CSP refuses it): sent as the `Speculation-Rules` response header, not in `Link`. [href] is served as `application/speculationrules+json`.
- `LinkHint.font(String href, {String type = 'font/woff2'})` — A font the page uses (fetched in CORS mode, like `@font-face`).
- `LinkHint.image(String href, {String? srcset, String? sizes, String? type, String? media})` — The page's main image (its LCP, `Image(priority: true)`): [href] is the fallback, [srcset]/[sizes] what its `<img>` or `<source>` has, [type] that source's (`image/avif`), [media] the theme it is for.

### `ListQuery` · class

The state of a list page, read from its URL: the search text, the page (1-based), the sort and the filters. The URL is the state, so a link, a bookmark and «back» work with no JavaScript.


### `ListQueryRequest` · extension

The list state in the URL (see [ListQuery]).


### `ListSchemaField` · class

[item] repeated: every value sent under its name, as a `List<T>` (repeated inputs, a `<select multiple>`, a checkbox group), in the order they came. Blank entries are skipped. Each item is checked with the item's rules (every failing item adds its message), and [min] / [max] count the items.

- `ListSchemaField<T>(SchemaField<T> item, {int min = 0, int? max, String? tooFew, String? tooMany})` — A repeated [item] with at least [min] and at most [max] entries.

### `Loader` · typedef

Loads a route's data before it renders.


### `LocaleRouting` · class

The languages a routed app speaks and how a request picks one (`RouteHandler(locales:)`).

- `LocaleRouting({required List<Locale> supportedLocales, Locale? defaultLocale, LocaleStrategy strategy = LocaleStrategy.prefix, String cookieName = 'locale', String? baseUrl})` — Routing for [supportedLocales], the first one being the default unless [defaultLocale] says otherwise.

### `LocaleStrategy` · enum

Where the locale of a page comes from.

- values: `prefix`, `prefixExceptDefault`, `negotiate`

### `LocaleSwitcher` · class

Links to the page in every language of the app (`RouteHandler(locales:)`), a `<nav>` of `<a hreflang lang>`.

- `LocaleSwitcher({Key? key, Map<Locale, String> labels = const {}, String? semanticsLabel, double spacing = 12, TextStyle? style, TextStyle? selectedStyle})` — A switcher; [labels] by locale (a locale without one shows its language's own name when thor knows it, else its tag).

### `MemoryRateLimitStore` · class

Counters in this isolate's memory, bounded by [maxKeys]: a client that invents a key per request (a new account name each time) cannot grow it. When full, expired windows go first, then the keys with the fewest attempts (oldest first): a flood of new keys pushes out other one-off keys, never the counter of a client that is being blocked.

- `MemoryRateLimitStore({int maxKeys = 10000})` — A store of at most [maxKeys] counters.

### `Middleware` · typedef

Wraps every request to the pages of a `Group` of the route table (`Group(middleware: [session])`), outermost group first: read the session into `request.context`, end the request early (throw a `Redirect` or an `HttpError`, or return a response without calling [Next]), or change the response [Next] returns (`response.withHeaders(…)`).


### `MiddlewareError` · class

A middleware of a list threw: which one, and what ([error]).

- `MiddlewareError({required String? name, required int position, required int count, required String owner, required Object error})` — [error] from the middleware at [position] (from 1) of [owner].

### `Next` · typedef

The rest of the request below a [Middleware]: the middleware of the groups below, the page cache, guards, the form action, loads and the render. Call it at most once.


### `NotFound` · class

`404 Not Found`.

- `NotFound([String? message])` — A 404, optionally with a [message].

### `OpenGraph` · class

The Open Graph tags of a page (`og:*`), plus `twitter:card`.

- `OpenGraph({String? title, String? description, String? url, String? image, String? imageAlt, String? type, String? siteName, Locale? locale, String? twitterCard})` — Open Graph data; unset fields are left out.

### `OpenerPolicy` · enum

`Cross-Origin-Opener-Policy`: whether windows opened from or to other origins keep a handle on this one.

- values: `sameOrigin`, `sameOriginAllowPopups`, `unsafeNone`

### `OptionalSchemaField` · class

[field] that may be left empty: an empty value is `null` (not `''`) and its rules apply only when there is a value. `values.of(field)` is a `T?`.

- `OptionalSchemaField<T>(SchemaField<T> field)` — [field], optional.

### `PageMeta` · class

Title, description and tags of the page's `<head>`.

- `PageMeta(…)` — Page metadata.

### `PageRenderer` · abstract class

Draws a page (a `P`, e.g. a widget tree) as a full HTML document. The only point where thor_server meets a render engine.

- `PageRenderer<P>()`

### `PageRequest` · class

The request a page's `load`, `actions` and `redirect` receive, with the response being built next to it ([response]).

- `PageRequest(…)` — A request for [uri]. [headers] keys are case-insensitive (stored lowercase); [body] is read once, by [form] or [text].

### `PageRoute` · class

A page: what a `ThorRoute` of the route table (`lib/router.dart`) becomes.

- `PageRoute<P, T>(…)` — A page at [path].

### `PageState` · class

What a page (or layout) builds from.

- `PageState<T>({required PageRequest request, required T data, Object? form, int status = 200, List<Object?> levels = const [], List<Object> pageValues = const []})` — The state of one route level.

### `RateLimit` · class

At most [max] attempts per key in [window]: for login, password reset, anything that guesses or costs. Counts in a fixed window (a client can spend `max` at the end of one and `max` at the start of the next).

- `RateLimit({required int max, required Duration window, int trustedProxies = 0, String? Function(PageRequest)? key, RateLimitStore? store, DateTime Function()? clock})` — [max] attempts per key in [window].

### `RateLimitCount` · class

Attempts counted for a key in the current window.

- `RateLimitCount(int count, DateTime resetsAt)` — [count] attempts so far (this one included) in a window that ends at [resetsAt].

### `RateLimitResult` · class

What one attempt got.

- `RateLimitResult({required bool allowed, required int remaining, required Duration retryAfter})` — An attempt that was [allowed] or not.

### `RateLimitStore` · abstract class

Where [RateLimit] keeps its counters.

- `RateLimitStore()`

### `Redirect` · class

Ends the request with a redirect to [location]. Thrown from a `load` or returned (or thrown) from an action.

- `Redirect(RouteUrl location, {int status = 303, bool resetScroll = false})` — `303 See Other` to [location].
- `Redirect.back(PageRequest request, {int status = 303, bool resetScroll = false})` — The page [request] was posted from, its query kept and the action key (`?/save`) gone: the very URL the visitor was on, so the browser keeps their scroll and the pressed button (`thor_ui`'s form script). A hand-written `Redirect(request.uri.path)` drops the query (`/orders? status=paid` lands on `/orders`): that is another page and it starts at the top. Not the `Referer`: that header is the client's to send or not, and an action may also be posted from another page.
- `Redirect.found(RouteUrl location)` — `302 Found`: a temporary redirect (e.g. a protected page → `/login`).
- `Redirect.temporary(RouteUrl location)` — `307 Temporary Redirect`: keeps the method and body.
- `Redirect.permanent(RouteUrl location)` — `308 Permanent Redirect`.

### `ReferrerPolicy` · enum

`Referrer-Policy`: how much of the page's URL a request leaves in `Referer`.

- values: `noReferrer`, `noReferrerWhenDowngrade`, `origin`, `originWhenCrossOrigin`, `sameOrigin`, `strictOrigin`, `strictOriginWhenCrossOrigin`, `unsafeUrl`

### `RenderContext` · class

What a [PageRenderer] needs besides the page.

- `RenderContext(…)` — For [request], answered with [status].

### `RequestContext` · class

Typed values of one request, by [ContextKey] (identity: two keys with the same name are different keys).


### `RequestScope` · class

The request the page is rendering for, visible to every widget below (the current path for an active link, the signed-in user in `locals`).

- `RequestScope({Key? key, required PageRequest request, required Widget child})` — Publishes [request] to [child].

### `ResourceRoute` · class

A route that answers something other than a page (a file, XML, text, JSON) at a place of the route tree: the layouts' middleware and guards run around it, but no `load`, no render and no page cache (it sets its own `cache-control`). `GET` and `HEAD`, plus its [methods].

- `ResourceRoute<P>({String path = '', required FutureOr<ThorResponse> Function(PageRequest) respond, Guard? redirect, Set<HttpMethod> methods = const {}})` — [respond] at [path].
- `ResourceRoute<P>.sitemap(FutureOr<Sitemap> Function(PageRequest) sitemap)` — `/sitemap.xml` from [sitemap].
- `ResourceRoute<P>.robots(FutureOr<Robots> Function(PageRequest) robots)` — `/robots.txt` from [robots].

### `Robots` · class

`robots.txt`: what the function of a `RobotsRoute` in the route table (or `ResourceRoute.robots`) returns.

- `Robots(List<RobotsRule> rules, {bool sitemap = true, String? baseUrl, int maxAge = 86400})` — Robots with [rules] (default: everyone may crawl everything).

### `RobotsMeta` · class

What crawlers may do with a page: `<meta name="robots">`.

- `RobotsMeta({bool index = true, bool follow = true, bool noArchive = false, bool noSnippet = false, bool noImageIndex = false, List<String> other = const []})` — Directives; by default a page may be indexed and its links followed.
- `RobotsMeta.parse(String? content)` — Reads the content of a `robots` meta (`'noindex, nofollow'`). A directive it does not know goes to [other].

### `RobotsRoute` · class

`/robots.txt`, from [robots] (only in the table's top level).

- `RobotsRoute(FutureOr<Robots> Function(PageRequest) robots)` — The robots rules [robots] returns for each request.

### `RobotsRule` · class

One `User-agent` group of [Robots].

- `RobotsRule({String userAgent = '*', List<String> allow = const [], List<String> disallow = const []})` — [userAgent] (`*`: everyone) with its paths.

### `RouteHandler` · class

Handles requests for a route tree: guards, form actions, data loading, rendering and error pages. The HTTP server feeds it; tests call [handle] directly.

- `RouteHandler<P>(…)` — Handles [routes], drawing pages with [renderer].

### `RouteIndex` · class

Matches paths against a route tree. Static segments beat `[param]`, which beats `[...rest]`, segment by segment (`/article/new` wins over `/article/[slug]`). A typed parameter (`[id=int]`) only matches values of its type: `/item/abc` is not `/item/[id=int]` (a 404, before any load).

- `RouteIndex<P>(List<RouteNode<P>> routes)` — Flattens [routes].

### `RouteUrl` · extension type

The URL of a link, a redirect or a canonical address: a page of this site (`/orders/7?tab=items`), a section (`#pricing`) or another site (`https://example.com/docs`).

- `RouteUrl(String value)`
- `RouteUrl.external(String url)` — A URL on another site: `http`, `https`, `mailto` or `tel`. Any other scheme (`javascript:`, `data:`) throws, so a link made from data a visitor sent can never run code.

### `SchemaField` · sealed class

A field of a [FormSchema] that yields a [T].

- `SchemaField<T>()`

### `Secret` · class

A secret value: `toString` hides it and it can't become JSON; read it with [reveal] where it is used (signing a cookie, a backend header).


### `SecurityHeaders` · class

The headers of [securityHeaders] as a value, for what no route middleware wraps: `ThorServer(securityHeaders: SecurityHeaders(...))` puts them on static files, the health check, host refusals and the global 500, besides every page.

- `SecurityHeaders(…)` — The headers of [securityHeaders]; a null argument leaves that one out.

### `ServerEvent` · class

One server-sent event (`text/event-stream`): what an `EventSource` in the browser receives as a `MessageEvent`.

- `ServerEvent(String data, {String? event, String? id, Duration? retry})` — An event with [data] (any text; a line break splits it into several `data:` lines, which the browser joins back with `\n`).
- `ServerEvent.toast(String message, {FlashKind kind = FlashKind.info, Duration? duration, String? id})` — A message for the page's snack bar (the browser's `toast`), sent from the server: `ServerEvent.toast('main.dart changed on disk')`.

### `ServerMessages` · class

What the visitor reads when a `query` or a `command` fails: the ones the server writes (a sign-in, a bad request, a generic failure) and the ones the browser shows for what it finds itself (no network, a timeout), and the buttons of the page that stands in for the confirm dialog. Set once in `ThorApp(serverMessages:)`; the server puts the browser's in the page, so the client never carries a string of its own.

- `ServerMessages(…)` — Pass only what the app wants to say itself; the rest is the visitor's language ([forLocale]), English by default.

### `SetCookie` · class

A cookie to set on the response.

- `SetCookie(String name, String value, {Duration? maxAge, String path = '/', bool httpOnly = true, String sameSite = 'Lax', bool? secure})` — Cookie [name] = [value]. [secure] `null` = decided by the server (`Secure` when the request came over HTTPS: `secureCookies` of `RouteHandler`).

### `SignedCookies` · class

Signs cookie values with HMAC-SHA256 so the client can read but not forge them (a session holding a user id or an API token).

- `SignedCookies(String secret, {List<String> previousSecrets = const [], Duration? maxAge, String? purpose, DateTime Function()? clock})` — Signs with [secret] (at least 32 bytes: generate it once and keep it out of the repo).

### `Sitemap` · class

`sitemap.xml` (the sitemaps.org protocol): what the function of a `SitemapRoute` in the route table returns.

- `Sitemap(List<SitemapUrl> urls, {String? baseUrl, int maxAge = 3600})` — A sitemap of [urls].

### `SitemapRoute` · class

`/sitemap.xml`, from [sitemap] (only in the table's top level).

- `SitemapRoute(FutureOr<Sitemap> Function(PageRequest) sitemap)` — The sitemap [sitemap] returns for each request.

### `SitemapUrl` · class

One page of a [Sitemap].

- `SitemapUrl(String path, {DateTime? lastModified, ChangeFrequency? changeFrequency, double? priority})` — [path] (`articleRoute.link({'slug': …})`) or an absolute URL.

### `StaticFiles` · class

Serves the files of a folder: content type, gzip for text (compressed once and kept), `immutable` for content-hashed names, ETag otherwise.

- `StaticFiles(String root, {bool compress = true, bool? index, bool? sourceMaps})` — Files under [root].

### `StatusCode` · extension type

An HTTP status code: the typed constants of the ones thor answers with (`StatusCode.notFound`), usable wherever an `int` is.

- `StatusCode(int code)`

### `TextSchemaField` · class

A text field: its value as submitted (`''` when empty), or trimmed.

- `TextSchemaField(String name, {List<Validator> validators = const [], bool secret = false, bool Function(FormData)? when, bool? trim})` — A text field; [secret] is never re-filled (passwords). [trim]: see the class.

### `ThorHttpClient` · class

An HTTP client for `load`, actions and guards: the backend calls a page makes, with defaults that suit a server talking to an API.

- `ThorHttpClient(…)` — A client. [headers] go with every request (a call's own headers win). [maxRedirects] bounds the redirects one call follows (more is a `502`). [allowPrivateNetworks] `false` refuses every private, loopback, link-local and metadata address (see the class); the default reaches them, as an app that calls its own backends needs. [maxConnectionsPerHost] bounds the sockets open to one backend (the rest wait for one to free up). [warmUp] is a list of backend URLs (`String` or `Uri`) to [preconnect] to as the client is built, without waiting for them: one connection per distinct origin, at most 8 opening at once, invalid URLs skipped.

### `ThorHttpResponse` · class

A complete response from a backend.

- `ThorHttpResponse({required Uri uri, required HttpMethod method, required int statusCode, required Uint8List bytes, Map<HttpHeader, String> headers = const {}})` — A response to [method] [uri].

### `ThorLayout` · abstract class

A layout: the frame a [Group] puts around its pages ([build]'s `child`). Like [ThorPage]: [T] is its [load]'s data (a page below reads it with `request.parent<T>()`), one const instance, settings in `super(…)`; the pages below inherit them.

- `ThorLayout<T>({Duration? cache, bool? personalized, bool? prerender, bool? earlyHints, PageTransition? transition, bool? prefetch})` — A layout with its settings.

### `ThorPage` · abstract class

A page: what a [ThorRoute] shows.

- `ThorPage<T>(…)` — A page with its settings.

### `ThorResponse` · class

A response, ready to write to the socket (or to a file).

- `ThorResponse(int status, {Map<HttpHeader, String> headers = const {}, List<String> cookies = const [], List<int> body = const [], Stream<List<int>>? stream})` — A response with [status].
- `ThorResponse.json(Object? data, {int status = 200, Duration? maxAge, bool private = false, Map<HttpHeader, String> headers = const {}})` — A JSON answer for a resource route (`ThorRoute.resource`): [data] as UTF-8 JSON (`<` escaped, so it is never HTML whatever sniffs it), with an `ETag` (a matching `If-None-Match` gets a `304`) and `Cache-Control`: `public, max-age=` [maxAge], or `private` for [private]; without [maxAge] the browser keeps it but asks again every time (`no-cache`, cheap with the `ETag`).
- `ThorResponse.bytes(…)` — Bytes for a resource route (an image, a file made on demand) as [contentType], with an `ETag` and `Cache-Control` like [ThorResponse.json]; [immutable] says the bytes at this URL never change (a hashed name). `X-Content-Type-Options: nosniff`: the browser never guesses another type.
- `ThorResponse.events(Stream<ServerEvent> events, {Duration heartbeat = const Duration(seconds: 15), Map<HttpHeader, String> headers = const {}})` — A server-sent event stream (`text/event-stream`, for an `EventSource`): each [ServerEvent] of [events] goes out as it is added; a `: heartbeat` comment every [heartbeat] of silence keeps proxies from closing it (`Duration.zero`: none). Never cached, compressed or buffered by a proxy (`X-Accel-Buffering: no`). When the client leaves, the subscription to [events] is cancelled at once: put the cleanup (a `finally`, `onCancel`) there. The stream ends when [events] does.

### `ThorRoute` · class

A page at a URL: `ThorRoute('/article/:slug', const ArticlePage())`.

- `ThorRoute<T>(String path, ThorPage<T> page, {List<Middleware> middleware = const []})` — [page] at [path]. A malformed [path] is THOR-P014 (at startup, where the table is built).
- `ThorRoute<T>.resource(String path, FutureOr<ThorResponse> Function(PageRequest) respond, {Set<HttpMethod> methods = const {}, List<Middleware> middleware = const []})` — A route that answers something other than a page (JSON, bytes, a file made on demand): [respond] gets the request (its [path] parameters included) and returns a `ThorResponse`, usually `ThorResponse.json(…)` or `ThorResponse.bytes(…)` with their `ETag` and `Cache-Control`. The middleware and guards of its groups run around it; there is no `load`, no render and no page cache. It answers `GET` and `HEAD`, plus the [methods] it names (any other is a `405` with an `Allow` header). It is no page: not in [ThorRouter.pages], the sitemap or `thor export`.
- `ThorRoute<T>.stream(String path, Stream<ServerEvent> Function(PageRequest) events, {Duration heartbeat = const Duration(seconds: 15), List<Middleware> middleware = const []})` — A server-sent events endpoint (`text/event-stream`): [events] returns the stream for each request, and every [ServerEvent] reaches the browser's `EventSource` as it is added. A `: heartbeat` comment every [heartbeat] of silence keeps proxies from closing the connection. When the client leaves, the subscription to [events] is cancelled at once: an `async*` function's `finally` runs. Read `Last-Event-ID` from `request.headers` to resume.

### `ThorRouter` · class

The app's routes, written in code: what `RouteHandler(routes:)` serves.

- `ThorRouter(List<RouteTableNode> children)` — The table of [children]. Its languages, theme and navigation are the app's (`ThorApp.router(routerConfig: router, supportedLocales: …)`).

### `ThorServer` · class

thor's HTTP server: static files first, then the routes.

- `ThorServer(…)` — Serves [handler], and the files of [publicDir] (the built site: engine, images, fonts) before it.

### `TooManyRequests` · class

`429 Too Many Requests`: the client must wait [retryAfter] (sent as `Retry-After`). What `RateLimit.middleware` ends a request with.

- `TooManyRequests(Duration retryAfter, [String? message])` — A 429 that asks to wait [retryAfter].

### `UploadedFile` · class

A file sent with a form (`<input type="file">`), held in memory (the whole body is bounded by the server's `maxBodyBytes`).

- `UploadedFile(String filename, String contentType, Uint8List bytes)` — A file named [filename] of [contentType] with [bytes].

### `UpstreamError` · class

A backend call failed: timed out (`504`), or no usable response (`502`). An [HttpError] with no message: the error page says only that something failed; [reason], [method] and [uri] are for the logs (the route handler passes this error to its `onError`).

- `UpstreamError(int status, {required HttpMethod method, required Uri uri, required String reason})` — A failed call to [method] [uri], answered to the visitor with [status].

### `Validator` · class

A validation rule of a [TextFormField].

- `Validator.all(List<Validator> rules)` — Several rules as one, in order: `validator: Validator.all([...])`.
- `Validator.required(String message)` — Field must not be empty.
- `Validator.minLength(int length, String message)` — At least [length] characters.
- `Validator.maxLength(int length, String message)` — At most [length] characters.
- `Validator.pattern(Pattern regExp, String message)` — Must match [regExp]: a `String` (a JavaScript-compatible pattern that must match the **whole** value; `const`-friendly) or a `RegExp`, what a Flutter validator writes.
- `Validator.notBlank(String message)` — Not empty and not only whitespace: Flutter's `value == null || value.trim().isEmpty`, the check nearly every required text field writes. [Validator.required] alone accepts `'   '`, like the browser's `required`.
- `Validator.email(String message)` — Must be an e-mail address (sets `type=email`).
- `Validator.min(num value, String message)` — Number not below [value] (sets `type=number`).
- `Validator.max(num value, String message)` — Number not above [value] (sets `type=number`).
- `Validator.minDate(String date, String message)` — A date (`yyyy-mm-dd`) not before [date], for a `DateSchemaField`.
- `Validator.maxDate(String date, String message)` — A date (`yyyy-mm-dd`) not after [date], for a `DateSchemaField`.
- `Validator.custom(String? Function(String) check)` — A rule only the server checks (a `FormSchema` from `package:thor_ui/router.dart`): [check] returns the message, or `null` when the value passes. The browser can't run it: it adds no attribute, and its message shows after the form is sent.

### `WidgetRenderer` · class

Draws widget pages as HTML documents: the only place routes meet the render engine.

- `WidgetRenderer(…)` — A renderer. [app] wraps every page (a `ThorApp` with the theme); [head] goes in every `<head>` (icons, fonts, stylesheets); [styles] is the app's own stylesheet (the page basics no widget covers).
- `WidgetRenderer.router(…)` — The renderer of a [ThorApp.router]: each page drawn in [app] (its theme, locale, navigation) with its `styles`. The rest are the renderer's own options, as in the default constructor.

### `contentSecurityPolicy` · function

Adds [policy] to the pages below, with a fresh nonce per request.

- `Middleware contentSecurityPolicy([ContentSecurityPolicy policy = const ContentSecurityPolicy()])`

### `cors` · function

Cross-origin requests from [origins] (`https://app.example.com`; `*` for any): a preflight (`OPTIONS` with `Access-Control-Request-Method`) is answered here with `204` and what they may send ([methods], [headers], for [maxAge]); any other request from an allowed origin gets `Access-Control-Allow-Origin` (the origin itself with [credentials], never `*`) and `Vary: Origin`. An origin not in the list gets no CORS headers (the browser blocks it), only `Vary: Origin`, so a shared cache keeps the two answers apart.

- `Middleware cors(…)`

### `isRtlLanguageTag` · function

Whether text in [tag] runs right to left (`ar`, `he`, `fa`, `ur`… or an Arabic, Hebrew, Syriac or Thaana script subtag): the `dir="rtl"` of its pages.

- `bool isRtlLanguageTag(String tag)`

### `matchLocale` · function

The first of [supported] that a locale of [preferred] (in order) accepts: the same locale, else the same language (`es-MX` → `es`, `pt` → `pt-BR`), else `null`.

- `Locale? matchLocale(Iterable<Locale> preferred, List<Locale> supported)`

### `parseAcceptLanguage` · function

The locales of an `Accept-Language` header, most preferred first (RFC 9110 §12.5.4: by `q`, ties in header order).

- `List<Locale> parseAcceptLanguage(String header)`

### `parseCookies` · function

Parses a `Cookie` header into name → value (first wins).

- `Map<String, String> parseCookies(String? header)`

### `parseIsoDateTime` · function

`DateTime.parse(text)`, fast for the UTC form backends send (`2026-09-26T12:00:00Z`, with up to six fraction digits); any other form goes to `DateTime.parse` itself, so the result is always the same.

- `DateTime parseIsoDateTime(String text)`

### `revalidateTag` · function

Drops the cached pages that declare [tag] (`PageRoute.tags`, `ThorPage(tags:)`) in every isolate of the server: call it from an action or a command after the data those pages show changed.

- `void revalidateTag(String tag)`

### `safeNext` · function

Where to go after an action (a login that came from `/login?next=/cart`): [value] when it is a path on this site, else [fallback]. Never an open redirect: only a path that starts with one `/` passes, or an absolute URL of this request's own origin (reduced to its path). Another origin, `//host`, a backslash, a control character, `javascript:`, more than 2048 characters, and any of those hidden behind percent-encoding (also double) give [fallback].

- `RouteUrl safeNext(PageRequest request, String? value, {RouteUrl fallback = const RouteUrl('/')})`

### `securityHeaders` · function

Headers most pages should carry, added to every response below that doesn't set its own: `X-Content-Type-Options: nosniff`, a `Referrer-Policy`, `X-Frame-Options` and `Cross-Origin-Opener-Policy` against framing and window handles, a `Permissions-Policy` that turns off the camera, microphone and location, and, with [hsts], HTTPS only for that long. A null argument leaves that header out.

- `Middleware securityHeaders(…)`

### `signInOn401` · function

Turns the `401` of what runs below it into a redirect to the sign-in page (`/login?next=/orders`), the way a Flutter route guard sends someone with no session to the login screen.

- `Middleware signInOn401(String signIn, {String next = 'next'})`

## `html` · `package:thor_ui/html.dart`

### `AriaAttribute` · enum

A WAI-ARIA state or property: `aria-<name>`.

- values: `activedescendant`, `atomic`, `autocomplete`, `busy`, `checked`, `colcount`, `colindex`, `colspan`, `controls`, `current`, `describedby`, `details`, `disabled`, `errormessage`, `expanded`, `haspopup`, `hidden`, `invalid`, `keyshortcuts`, `label`, `labelledby`, `level`, `live`, `modal`, `multiline`, `multiselectable`, `orientation`, `owns`, `placeholder`, `posinset`, `pressed`, `readonly`, `relevant`, `required`, `roledescription`, `rowcount`, `rowindex`, `rowspan`, `selected`, `setsize`, `sort`, `valuemax`, `valuemin`, `valuenow`, `valuetext`

### `AttributeName` · extension type

The name of an HTML attribute that a state value can bind to (`WatchAttributes`, `row.attribute`): the common ones as constants, the rest from [AttributeName.ariaOf] and [AttributeName.data].

- `AttributeName(String name)`
- `AttributeName.data(String key)` — `data-<key>`: [key] is lowercase letters, digits and `-`.

### `BooleanAttribute` · enum

An HTML attribute that is on or off: written bare when on, left out when off.

- values: `autofocus`, `checked`, `disabled`, `hidden`, `inert`, `multiple`, `open`, `readonly`, `required`, `selected`

### `Css` · class

The builder behind [css].


### `HtmlAttributes` · class

The attributes of one element, typed: ARIA states, `data-*`, the global attributes and the boolean ones, and a validated escape for any other name.

- `HtmlAttributes(…)` — The attributes given: [aria] (`aria-*`, a value is a `String`, `bool` or `num`), [data] (`data-<key>`), the globals [id], [title] and [tabIndex], and the [flags] that are on. [custom] adds any other attribute (see [HtmlAttributes.custom]).
- `HtmlAttributes.custom(Map<String, String> attributes)` — Any attributes by name. Each name must be a valid attribute name (letters, digits, `_`, `:`, `.`, `-`) and not an event handler (`on…`): scripts do not travel in attributes.

### `InputType` · enum

The `type` of an `<input>`.

- values: `text`, `button`, `checkbox`, `color`, `date`, `dateTimeLocal`, `email`, `file`, `hidden`, `image`, `month`, `number`, `password`, `radio`, `range`, `reset`, `search`, `submit`, `tel`, `time`, `url`, `week`

### `NestedStyleRule` · class

A selector with its declarations and nested rules (what [css] returns).


### `RawText` · class

HTML written as is, not escaped: markup that is already HTML (an SVG sprite, a stylesheet). Never data from a user.

- `RawText(String text, {Key? key})` — [text] written as HTML.

### `StyleRule` · sealed class

A rule of the app's stylesheet (`styles:` of `initializeThor` or `WidgetRenderer`): what no widget covers (`::before`, `:nth-child`, classes of markup thor didn't build, keyframes). Built with [css].

- `StyleRule()`

### `a` · class

`<a>`.

- `a(List<Widget> children, {String? href, String? target, String? download, String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<a>` element.

### `button` · class

`<button>`.

- `button(List<Widget> children, {bool autofocus = false, bool disabled = false, String? type, String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<button>` element.

### `caption` · class

`<caption>`: the table's title.

- `caption(List<Widget> children, {String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<caption>` element.

### `col` · class

`<col>`: a column of a [colgroup].

- `col({int? span, String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<col>` element.

### `colgroup` · class

`<colgroup>`.

- `colgroup(List<Widget> children, {String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<colgroup>` element.

### `css` · getter


### `details` · class

`<details>`.

- `details(List<Widget> children, {bool open = false, String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<details>` element.

### `div` · class

`<div>`.

- `div(List<Widget> children, {String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<div>` element.

### `h1` · class

`<h1>`.

- `h1(List<Widget> children, {String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<h1>` element.

### `h2` · class

`<h2>`.

- `h2(List<Widget> children, {String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<h2>` element.

### `h3` · class

`<h3>`.

- `h3(List<Widget> children, {String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<h3>` element.

### `h4` · class

`<h4>`.

- `h4(List<Widget> children, {String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<h4>` element.

### `h5` · class

`<h5>`.

- `h5(List<Widget> children, {String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<h5>` element.

### `h6` · class

`<h6>`.

- `h6(List<Widget> children, {String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<h6>` element.

### `i` · class

`<i>`.

- `i(List<Widget> children, {String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<i>` element.

### `img` · class

`<img>`.

- `img({String? alt, int? width, int? height, required String src, String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<img>` element.

### `input` · class

`<input>`.

- `input({InputType? type, String? name, String? value, bool disabled = false, bool? checked, String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<input>` element.

### `label` · class

`<label>`.

- `label(List<Widget> children, {String? htmlFor, String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<label>` element.

### `li` · class

`<li>`.

- `li(List<Widget> children, {int? value, String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<li>` element.

### `link` · class

`<link>`.

- `link({required String href, String? rel, String? type, String? as, String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<link>` element.

### `meta` · class

`<meta>`.

- `meta({String? name, String? content, String? charset, String? httpEquiv, String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<meta>` element.

### `nav` · class

`<nav>`.

- `nav(List<Widget> children, {String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<nav>` element.

### `ol` · class

`<ol>`.

- `ol(List<Widget> children, {bool reversed = false, int? start, String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<ol>` element.

### `p` · class

`<p>`.

- `p(List<Widget> children, {String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<p>` element.

### `script` · class

`<script>`.

- `script({String? src, bool async = false, bool defer = false, String? content, String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<script>` element.

### `span` · class

`<span>`.

- `span(List<Widget> children, {String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<span>` element.

### `summary` · class

`<summary>`.

- `summary(List<Widget> children, {String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<summary>` element.

### `table` · class

`<table>`.

- `table(List<Widget> children, {String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<table>` element.

### `tbody` · class

`<tbody>`.

- `tbody(List<Widget> children, {String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<tbody>` element.

### `td` · class

`<td>`: a table data cell.

- `td(List<Widget> children, {int? colSpan, int? rowSpan, String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<td>` element.

### `textarea` · class

`<textarea>`.

- `textarea(…)` — A `<textarea>` element.

### `tfoot` · class

`<tfoot>`.

- `tfoot(List<Widget> children, {String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<tfoot>` element.

### `th` · class

`<th>`: a table header cell.

- `th(List<Widget> children, {String? scope, int? colSpan, int? rowSpan, String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<th>` element.

### `thead` · class

`<thead>`.

- `thead(List<Widget> children, {String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<thead>` element.

### `tr` · class

`<tr>`.

- `tr(List<Widget> children, {String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<tr>` element.

### `ul` · class

`<ul>`.

- `ul(List<Widget> children, {String? id, String? classes, Styles? styles, Map<String, String>? attributes, Key? key})` — A `<ul>` element.

## `testing` · `package:thor_ui/testing.dart`

### `WidgetTrace` · class

The widgets that built each element of a page (see `renderHtmlTraced`): a test tool, since the HTML does not say which widget wrote an element.

- `WidgetTrace()`

### `bodyOfPage` · function

The `<body>…</body>` part of a rendered page.

- `String bodyOfPage(String html)`

### `headOfPage` · function

The `<head>` part of a rendered page (styles, sprite, state).

- `String headOfPage(String html)`

### `initializeThorTests` · function

Initializes rendering for tests. With [compactHtml] (the default) the output has no pretty-printing whitespace, exactly like a release build.

- `void initializeThorTests({bool compactHtml = true})`

### `renderCachesEnabled` · getter

Whether the render-time caches are on (the default): the memo of each element's styles and the fragments kept by `Cached`. Off, every element computes its styles and every `Cached` builds its child: the reference a differential test compares the cached output against, byte for byte.


### `renderDocument` · function

Renders a full page (`<html>`, `<head>` with the generated stylesheet, `<body>`) whose body is [body].

- `Future<String> renderDocument(Widget body)`

### `renderHtml` · function

Renders [component] alone (no document) and returns its HTML.

- `Future<String> renderHtml(Widget component)`

### `renderHtmlTraced` · function

[renderHtml] with the widgets that built each element recorded: every element carries `data-thor-w` with indexes into `widgets`. What `find.byType` and `find.byKey` of `thor_test` read; the render caches are off while it runs, so every widget builds. It must not overlap another render in the same isolate (the trace is global).

- `Future<({String html, List<({Key? key, Type type})> widgets})> renderHtmlTraced(Widget component)`

### `runAppScript` · function

Runs [script] of the app (a path like `test/fixtures/pages.dart`) with `dart run`, the way thor runs the app: with its states and its pages' action methods registered first. For a test that renders in another process (a compile-time define, a fresh isolate). [dartArgs] go before the script (`-Dthor.release=true`), [args] after it. [appDir] is the app (default: the current folder, where `thor test` runs).

- `Future<ProcessResult> runAppScript(String script, {List<String> args = const [], List<String> dartArgs = const [], Map<String, String>? environment, String? appDir})`

### `withThorNow` · function

Runs [body] with [now] as what widgets read as the current time (the date picker's today and the month it opens on, when the app gives no `currentDate`). Zone-scoped, like `withClock` of `package:clock`: the asynchronous work [body] starts sees it too, so `await withThorNow(DateTime(2026, 3, 10), () => renderHtml(widget))` is stable any day.

- `R withThorNow<R>(DateTime now, R Function() body)`

## `intl` · `package:thor_ui/intl.dart`

### `GlobalMaterialLocalizations` · abstract class

Flutter's `GlobalMaterialLocalizations`: [MaterialLocalizations] whose dates, month and weekday names and first day of the week come from CLDR (`package:intl`) for **any** locale, with the texts of English and Spanish (another language keeps English texts until the app adds its own delegate).

- `GlobalMaterialLocalizations(Locale locale)` — The CLDR dates of [locale].
- `GlobalMaterialLocalizations.forLocale(Locale locale)` — The localizations for [locale]: Spanish texts for `es`, English otherwise, CLDR dates of [locale] in both.

### `LocaleFormat` · class

Formatting in one locale (a thin layer over `NumberFormat` and `DateFormat`). A locale `intl` has no data for formats like its language, else like English: never an exception in a page.

- `LocaleFormat(Locale locale)` — Formats for [locale].
- `LocaleFormat.of(BuildContext context)` — Formats for the page's locale (`Localizations.localeOf`).

## `thor_test` · `package:thor_test/thor_test.dart`

### `CommonFinders` · class

The set of finders behind [find].


### `ContrastPair` · class

One foreground / background pair of a theme and how it fares.

- `ContrastPair({required String foreground, required String background, required double ratio, required double minimum})` — Creates a measured pair.

### `Finder` · class

A query over the HTML a [ThorTester] rendered: the counterpart of Flutter's `Finder`.

- `Finder(String description, bool Function(Element) matches, {Finder? roots})` — Creates a finder described by [description] that keeps the elements [matches] accepts, searching below [roots] (default: the rendered page).

### `HttpHeader` · extension type

The name of an HTTP header: the key type of every header map (a request's [PageRequest.headers], a response's `headers`, a client call's), with typed constants for the common ones in the lowercase spelling those maps use.

- `HttpHeader(String name)`

### `MockTransport` · class

Answers `ThorHttpClient` calls from a test.

- `MockTransport(FutureOr<Object?> Function(ThorHttpRequest) answer, {String hint = ''})` — A transport that asks [answer]: a [ThorHttpFixture] (or [ThorHttpResponse], or any JSON value, sent as a `200`), or `null` when nothing matches the request.
- `MockTransport.fixtures(Map<String, Object?> fixtures)` — Matches `'METHOD url'` or `'url'` (any method) to an answer: a [ThorHttpFixture], a [ThorHttpResponse], a function of the [ThorHttpRequest] returning one of those, or any other value (JSON, a `200`). A key ending in `*` matches by prefix. The exact keys win over the prefixes.
- `MockTransport.recorded(String directory, {bool? record})` — Replays the responses saved in [directory] (`test/fixtures`), one JSON file per request. With [record] (default: `THOR_HTTP_RECORD=1` in the environment, what `thor test --record` sets) the call goes over the real network and its response is saved instead. The request's headers are not saved (no tokens in the repo).

### `ThorCallResponse` · class

The answer to a query or a command ([ThorTestClient.query], [ThorTestClient.command]): the JSON the browser's engine reads.


### `ThorHttpFixture` · class

A canned answer for [MockTransport] and [withHttpFixtures].

- `ThorHttpFixture(List<int> body, {int status = 200, Map<HttpHeader, String> headers = const {}})` — An answer with [status], [headers] and a raw [body].
- `ThorHttpFixture.json(Object? value, {int status = 200, Map<HttpHeader, String> headers = const {}})` — A JSON answer (`content-type: application/json`).
- `ThorHttpFixture.text(String value, {int status = 200, Map<HttpHeader, String> headers = const {}})` — A text answer.

### `ThorTestClient` · class

A visitor of a [RouteHandler] in a test: keeps the cookies the server sets and sends them back, sends what a browser's same-origin request carries (`Host`, and `Origin` on a `POST`, so the CSRF check passes exactly as it does for a real form), and follows redirects when asked.

- `ThorTestClient(RouteHandler<Object?> handler, {String origin = 'http://localhost', int maxRedirects = 10, DateTime Function()? now, MockTransport? httpOverrides})` — A client of [handler]; see [ThorTestClientOf.client].

### `ThorTestClientOf` · extension

Adds [client] to a [RouteHandler].


### `ThorTestResponse` · class

What the server answered to a [ThorTestClient] request.


### `ThorTester` · class

The widget tester of [testThor]: Flutter's `WidgetTester` over the HTML a widget renders (no engine, no browser).


### `UnmockedHttpRequest` · class

A call no fixture answered. An [Error], not an exception: the page's `load` does not turn it into a `502`, and [withHttpFixtures] and `ThorTestClient(httpOverrides:)` rethrow it even when the page caught it, so a test never passes over an accidental network call.

- `UnmockedHttpRequest(HttpMethod method, Uri uri, [String hint = ''])` — A call to [method] [uri] that nothing answered.

### `contrastRatio` · function

The WCAG 2 contrast ratio between [a] and [b] (1 to 21), for two plain colors (the alpha is ignored: blend a translucent one first).

- `double contrastRatio(Color a, Color b)`

### `expectThemeContrast` · function

Fails the test, naming every pair, when [theme] has text on a background under WCAG AA (4.5:1) or an `outline` under 3:1.

- `void expectThemeContrast(ThemeData theme, {String? reason, Set<String> skip = const {}, double text = 4.5, double nonText = 3, List<(String, Color, Color)> extra = const []})`

### `find` · getter


### `findsNWidgets` · function

Matches a [Finder] that finds [count] elements.

- `Matcher findsNWidgets(int count)`

### `findsNothing` · getter


### `findsOneWidget` · getter


### `findsWidgets` · getter


### `hasStatus` · function

Matches a response whose status matches [status] (a number, or a matcher such as `inInclusiveRange(200, 299)`). When it fails it says what came: the request, the status, the `Location` of a redirect and the start of the page's text.

- `Matcher hasStatus(Object? status)`

### `redirectsTo` · function

Matches a redirect (`3xx` with a `Location`) to [location]: a path (`/account`) or a URL; an absolute URL of the same path matches too. [status] narrows it (`redirectsTo('/x', status: 302)`).

- `Matcher redirectsTo(String location, {Object? status})`

### `schemeContrast` · function

The measured pairs of [scheme]: every `onX` role on its `X`, the text roles on the surfaces they are used on, and `outline` against `surface`.

- `List<ContrastPair> schemeContrast(ColorScheme scheme, {double text = 4.5, double nonText = 3, List<(String, Color, Color)> extra = const []})`

### `testThor` · function

Flutter's `testWidgets` for Thor: [body] gets a [ThorTester] and the `find` finders work inside it.

- `void testThor(Object description, Future<void> Function(ThorTester) body, {Object? skip, Timeout? timeout, dynamic tags})`

### `themeContrast` · function

The measured pairs of [theme]'s color scheme (see [schemeContrast]).

- `List<ContrastPair> themeContrast(ThemeData theme, {double text = 4.5, double nonText = 3, List<(String, Color, Color)> extra = const []})`

### `withHttpFixtures` · function

Runs [body] with [fixtures] answering every `ThorHttpClient` call in it, whatever client holds (a global one too). A call nothing matches throws [UnmockedHttpRequest] naming the method and URL, and the run fails with it even if the page swallowed the error.

- `Future<T> withHttpFixtures<T>(Map<String, Object?> fixtures, FutureOr<T> Function() body)`

### `withHttpMock` · function

[withHttpFixtures] with a ready [MockTransport] (to read its [MockTransport.requests] afterwards).

- `Future<T> withHttpMock<T>(MockTransport mock, FutureOr<T> Function() body)`

## `thor_studio` · `package:thor_studio/thor_studio.dart`

### `CodeToken` · enum

A highlighted token kind.

- values: `keyword`, `string`, `number`, `type`, `comment`, `plain`

### `StudioAccentColors` · abstract class

The brand accent, an electric indigo: the primary pill, focus rings, the current item, links, selected text and the tinted squares behind section icons. It is at least 3:1 on every surface in both themes (the ring is a non-text control) and 4.5:1 where it paints text (on its tint too).

- `StudioAccentColors()`

### `StudioAccentRoles` · extension

The studio's accent (a blue for focus rings, the current item, links and selected text) as roles of Material's `ColorScheme`: the accent is its `tertiary` color, a contrasting hue next to the `primary` pill.


### `StudioActionColors` · abstract class

The primary action: the pill filled with the brand indigo (the accent's hue), the strongest thing on screen in both themes. Secondary actions stay neutral (an outline), so the one filled pill is where to go next.

- `StudioActionColors()`

### `StudioAttributes` · class

Adds HTML attributes (`aria-*`, `role`, `id`) to its child's element, without a node of its own.

- `StudioAttributes(Map<String, String> attributes, {Key? key, required Widget child})` — Puts [attributes] on [child]'s element.

### `StudioBench` · class

The frame every example of the docs lives in: a big card-like stage with the live demo, a side panel with its controls, and a toggle that swaps the demo for the code that makes it.

- `StudioBench(…)` — A bench showing [stage] and [code]; the page names it unless [id] does.

### `StudioBenchColors` · abstract class

The bench: a big stage for the demo and a side panel with Switches (a segmented control) and Levels (a bar you drag).

- `StudioBenchColors()`

### `StudioBenchGroup` · class

A labelled set of controls in a bench panel: "Switches" holds the segmented controls, "Levels" the bars.

- `StudioBenchGroup({Key? key, required String label, required List<Widget> children, double spacing = 16})` — A group named [label] around [children].

### `StudioBenchPanel` · class

The side panel of a `StudioBench`: the example's name and description, its controls in labelled groups, and the actions at the bottom.

- `StudioBenchPanel({Key? key, String? title, String? description, List<Widget> groups = const [], List<Widget> footer = const [], int headingLevel = 3, StudioBenchThemeData? theme})` — A panel with [groups] and a [footer] of actions.

### `StudioBenchRow` · class

One line of a bench panel's Switches: the name on the left, the control on the right.

- `StudioBenchRow({Key? key, required String label, required Widget child})` — A row naming [child] as [label].

### `StudioBenchThemeData` · class

The look of the bench: a big stage for a live example and a side panel with its controls, Switches (a segmented control) and Levels (a bar you drag, name on the left, value on the right, filled up to the value).

- `StudioBenchThemeData(…)` — Creates a bench theme; a null field keeps the default.

### `StudioBenchThemeResolved` · class

The effective look of a bench: [StudioBenchThemeData.of] with every field set. It is a [StudioBenchThemeData] too, so it can be handed to a widget's `theme:` parameter.

- `StudioBenchThemeResolved(…)` — Creates the resolved values.

### `StudioBorderColors` · abstract class

Hairlines. Borders carry the structure instead of shadows: one pixel, barely there, a notch stronger on hover.

- `StudioBorderColors()`

### `StudioBrand` · class

The product mark and name, linking home: the accent square with one letter, then the name in the title role.

- `StudioBrand({Key? key, required String name, String href = '/', String? mark, String? version})` — A brand linking to [href].

### `StudioBreadcrumbs` · class

Where the page sits in the site: a trail of links ending in the current page.

- `StudioBreadcrumbs({Key? key, required List<StudioNavDestination> trail, int? selectedIndex, String? label})` — A trail of [trail]; [label] names the landmark.

### `StudioButtonSegment` · class

One choice of a [StudioSegmentedControl] (Flutter's `ButtonSegment`): a [value], shown as a [label], an [icon] or both.

- `StudioButtonSegment<T>({required T value, Widget? icon, Widget? label, String? tooltip})` — A segment that stands for [value]. Without a [label] (icon only) give a [tooltip]: it is the segment's accessible name.

### `StudioButtonThemeData` · class

The look of buttons, like Flutter's `FilledButtonThemeData` plus the tonal and text variants in one: a filled pill (white on dark, ink on light), a gray tonal pill and a plain text one. Every button squeezes to [pressScale] when pressed.

- `StudioButtonThemeData(…)` — Creates a button theme; a null field keeps the default.

### `StudioButtonThemeResolved` · class

The effective look of a button: [StudioButtonThemeData.of] with every field set. It is a [StudioButtonThemeData] too, so it can be handed to a widget's `theme:` parameter.

- `StudioButtonThemeResolved(…)` — Creates the resolved values.

### `StudioCallout` · class

A note in the reading flow: a tone's icon and color, a [title] and a body, on the tone's tint with its color as a bar down the left edge.

- `StudioCallout({Key? key, StudioTone tone = StudioTone.info, required String title, String? body, Widget? child})` — A callout of [tone]: give it a [body] (text) or a [child] (widgets).

### `StudioCalloutThemeData` · class

The look of a callout (a note, a tip, a warning): a tinted inner block with a tone's icon, border and background.

- `StudioCalloutThemeData(…)` — Creates a callout theme; a null field keeps the default.

### `StudioCalloutThemeResolved` · class

The effective look of a callout: [StudioCalloutThemeData.of] with every field set. It is a [StudioCalloutThemeData] too, so it can be handed to a widget's `theme:` parameter.

- `StudioCalloutThemeResolved(…)` — Creates the resolved values.

### `StudioCardGrid` · class

A responsive grid of cards: one column on a phone, [columns] from the `md` breakpoint up (three or more: two at `md`, [columns] from `expanded`).

- `StudioCardGrid({Key? key, required List<Widget> children, int columns = 2})` — A grid of [children].

### `StudioCardThemeData` · class

The look of a studio card, like Flutter's `CardThemeData`: a big (28) surface with a hairline border and no shadow.

- `StudioCardThemeData(…)` — Creates a card theme; a null field keeps the default.

### `StudioCardThemeResolved` · class

The effective look of a card: [StudioCardThemeData.of] with every field set. It is a [StudioCardThemeData] too, so it can be handed to a widget's `theme:` parameter.

- `StudioCardThemeResolved(…)` — Creates the resolved values.

### `StudioChipThemeData` · class

The look of chips, like Flutter's `ChipThemeData`: gray pills for filters and the "New" label, filled with the primary color when selected, and tinted ones for tones.

- `StudioChipThemeData(…)` — Creates a chip theme; a null field keeps the default.

### `StudioChipThemeResolved` · class

The effective look of a chip: [StudioChipThemeData.of] with every field set. It is a [StudioChipThemeData] too, so it can be handed to a widget's `theme:` parameter.

- `StudioChipThemeResolved(…)` — Creates the resolved values.

### `StudioCodeBlock` · class

A code block: an optional file-name title bar (`file.dart — note`, the note in the faint ink) holding the copy button, the code highlighted at render time, and lines you can highlight or mark as changed. Without a title the copy button floats in the top corner.

- `StudioCodeBlock(…)` — A block showing [code].

### `StudioCodeDiff` · abstract class

Which lines of a piece of code are not in another one: what a diff step adds, what differs between the Flutter and the Thor version of an example.

- `StudioCodeDiff()`

### `StudioCodeLanguage` · enum

The language of a piece of code, for the highlighter and the header of a `StudioCodeBlock`.

- values: `dart`, `bash`, `yaml`, `json`, `html`, `css`, `plain`

### `StudioCodeTab` · class

One tab of a [StudioCodeTabs]: a [label] and the [code] behind it.

- `StudioCodeTab(…)` — A tab labeled [label] (often a file name or a package manager).

### `StudioCodeTabs` · class

Several code blocks behind tabs, in one frame.

- `StudioCodeTabs({Key? key, required List<StudioCodeTab> tabs, String? id, int initialIndex = 0, bool copyButton = true, String? copyLabel, String? copiedLabel})` — Tabs over [tabs]; the first one is open.

### `StudioCodeThemeData` · class

The look of a code block: a raised surface, a hairline, mono type, a header strip for the file name and the marks of its lines. Syntax colors are `StudioSyntaxColors`.

- `StudioCodeThemeData(…)` — Creates a code theme; a null field keeps the default.

### `StudioCodeThemeResolved` · class

The effective look of a code: [StudioCodeThemeData.of] with every field set. It is a [StudioCodeThemeData] too, so it can be handed to a widget's `theme:` parameter.

- `StudioCodeThemeResolved(…)` — Creates the resolved values.

### `StudioCompareSummary` · class

The two-line version of `StudioFlutterCompare`, for the top of a page: what you would use in Flutter, and what you use in Thor.

- `StudioCompareSummary({Key? key, required String flutter, required String thor, String? flutterLabel, String? thorLabel})` — A summary of [flutter] against [thor].

### `StudioContentColors` · abstract class

Text and icon colors, from the loudest to the quietest. Every one is at least 4.5:1 on the surfaces it is used on (the contrast test checks the pairs), except where its doc says otherwise.

- `StudioContentColors()`

### `StudioContentIcons` · abstract class

The icons of the content widgets (callouts, file trees, cards). The rest of the studio's icons are in `StudioIcons`.

- `StudioContentIcons()`

### `StudioCurves` · abstract class

Easing curves. A strong ease-out for what responds or enters (it starts fast, so the interface feels instant), an ease-in-out for what moves across the screen. Never an ease-in.

- `StudioCurves()`

### `StudioDataTable` · class

A data table in the studio's frame: Flutter's `DataTable` ([columns] of `DataColumn`, [rows] of `DataRow` and `DataCell`) in a rounded card.

- `StudioDataTable({Key? key, required List<DataColumn> columns, required List<DataRow> rows, int? sortColumnIndex, bool sortAscending = true})` — A table with [columns] as headers and [rows] of cells.

### `StudioDurations` · abstract class

How long things take. Nothing in the interface goes over 200 ms: motion confirms an action, it never makes you wait for one.

- `StudioDurations()`

### `StudioExtraColors` · class

The studio's colors that Material's `ColorScheme` has no role for, as a `ThemeExtension` like the ones a Flutter app writes for its own palette: the neutral hover, the two quieter text tones, the stronger hairline, the primary pill under the pointer, the accent wash and the colors of each [StudioTone].

- `StudioExtraColors(…)` — Creates the extras; every color defaults to the studio's token.

### `StudioExtraTextStyles` · class

The text styles Material's `TextTheme` has no role for: the monospace ones, as a `ThemeExtension`.

- `StudioExtraTextStyles(…)` — Creates the extras; every style defaults to the studio's.

### `StudioFileEntry` · class

A file or a folder of a [StudioFileTree].

- `StudioFileEntry(String name, {String? note, List<StudioFileEntry>? children})` — A file named [name]; give it [children] to make it a folder.

### `StudioFileTree` · class

A project's folders and files, as a nested list.

- `StudioFileTree({Key? key, required List<StudioFileEntry> entries, String? label})` — A tree of [entries].

### `StudioFilterChip` · class

A pill for filtering (Flutter's `FilterChip`): gray when off, the selected fill when on.

- `StudioFilterChip(…)` — A chip showing [label].

### `StudioFlutterCompare` · class

The "In Flutter / In Thor" pair: the same example written both ways behind a Flutter / Thor selector, with the lines that differ marked on each side.

- `StudioFlutterCompare(…)` — The same example, [flutterCode] and [thorCode].

### `StudioFontFamilies` · abstract class

Font stacks. `StudioTheme` self-hosts Inter (one variable file, every weight) and IBM Plex Mono, both under the SIL Open Font License, with `font-display: swap`.

- `StudioFontFamilies()`

### `StudioFontWeights` · abstract class

The three weights of the hierarchy: it is made of size and these, not of bold everywhere (Inter is variable, so 500 and 600 are real weights).

- `StudioFontWeights()`

### `StudioFooter` · class

The end of the page: columns of links, the [brand] and a line of [legal] text with the site's [actions] (theme toggle, locale switcher).

- `StudioFooter({Key? key, Widget? brand, List<StudioNavSection> sections = const [], String? legal, List<Widget> actions = const [], double? maxWidth})` — A footer of [sections].

### `StudioIconButton` · class

A round icon button of the top bar (the repository, settings), the same size and look as the search magnifier and the theme toggle: no border, the hover surface under the pointer, a press that squeezes it.

- `StudioIconButton({Key? key, required Widget icon, required String tooltip, VoidCallback? onPressed, String? href, bool newTab = false, double? size})` — A button showing [icon], named [tooltip].

### `StudioIcons` · abstract class

The studio's icons.

- `StudioIcons()`

### `StudioKbd` · class

A keyboard key, drawn as a key cap.

- `StudioKbd(String keys, {Key? key, String? semanticLabel})` — A key cap showing [keys].

### `StudioLayer` · class

One layer of a [StudioLayerDiagram].

- `StudioLayer({required String title, String? kind, required String description, required String flutterCode, required String thorCode})` — A layer named [title] with its [description] and the code of both frameworks.

### `StudioLayerDiagram` · class

An architecture diagram whose layers you open: View → ViewModel → Repository → Service, each with what it is for and its code in Flutter and in Thor.

- `StudioLayerDiagram(…)` — A diagram over [layers]; the first one is open.

### `StudioLayout` · abstract class

The fixed measures of the page frame, in one place: sticky panels are placed from the bars' heights, so changing a bar here moves them with it.

- `StudioLayout()`

### `StudioLetterSpacing` · abstract class

Letter spacing in logical pixels. Big type tightens (Inter's default is loose at display sizes); small type keeps its natural spacing.

- `StudioLetterSpacing()`

### `StudioLevelSlider` · class

A bar you drag to set a number: the name on the left, the value on the right and a fill that follows the value.

- `StudioLevelSlider(…)` — A bar at [value].

### `StudioLineHeights` · abstract class

Line heights as multipliers of the font size.

- `StudioLineHeights()`

### `StudioLineRange` · class

A run of lines of a code block, counted from 1 and inclusive.

- `StudioLineRange(int start, [int? end])` — Lines [start] to [end] (just [start] when [end] is omitted).

### `StudioLinkCard` · class

A card that is one link: an optional icon (in the accent, on a square of its tint), a title and a description.

- `StudioLinkCard({Key? key, required String title, required String href, String? description, IconData? icon, bool external = false})` — A card titled [title] that goes to [href].

### `StudioLocaleOption` · class

A language a `StudioLocaleSwitcher` offers: the page's address in that language.

- `StudioLocaleOption({required Locale locale, required String label, required String href})` — A language [label]led in its own language, at [href].

### `StudioLocaleSwitcher` · class

The language menu: a pill showing the current language that opens a list of links, one per language, each to the same page translated.

- `StudioLocaleSwitcher({Key? key, String? id, required List<StudioLocaleOption> locales, int? selectedIndex, String? label})` — A menu of [locales]; [label] names the button.

### `StudioLocalizations` · abstract class

Every string the studio's widgets write themselves, for the locale of the page (Flutter's `MaterialLocalizations`): "Copy", "Previous", "Skip to content", "On this page"…

- `StudioLocalizations()` — The strings of one language.

### `StudioLocalizationsEn` · class

English.

- `StudioLocalizationsEn()` — The English strings.

### `StudioLocalizationsEs` · class

Spanish.

- `StudioLocalizationsEs()` — The Spanish strings.

### `StudioMotion` · abstract class

Motion values that are not a duration or a curve.

- `StudioMotion()`

### `StudioMotionStyles` · abstract class

Page rules of the studio's motion that no widget can carry: they belong to the whole document, so the app lists them in `ThorApp(styles:)`.

- `StudioMotionStyles()`

### `StudioNavDestination` · class

A place in the site: a label and where it goes. The data every navigation widget of the studio takes (top bar links, sidebar items, breadcrumbs, the footer, the pager).

- `StudioNavDestination(String label, {required String href, IconData? icon, int? count, StudioTone countTone = StudioTone.neutral, String? countLabel, Widget? trailing})` — A destination called [label] at [href].

### `StudioNavSection` · class

A titled group of [StudioNavDestination]s: a sidebar section or a column of the footer.

- `StudioNavSection({required String title, required List<StudioNavDestination> items, IconData? icon})` — A section called [title] holding [items], with an optional [icon] before its heading.

### `StudioNavThemeData` · class

The look of navigation: the top bar, its links and the sidebar items, like Flutter's `NavigationBarThemeData` and `NavigationRailThemeData` in one. Items are pills; the current one carries `aria-current="page"` and the raised surface.

- `StudioNavThemeData(…)` — Creates a nav theme; a null field keeps the default.

### `StudioNavThemeResolved` · class

The effective look of a nav: [StudioNavThemeData.of] with every field set. It is a [StudioNavThemeData] too, so it can be handed to a widget's `theme:` parameter.

- `StudioNavThemeResolved(…)` — Creates the resolved values.

### `StudioPageHeader` · class

The opening of a page: an optional [eyebrow] pill, the `h1` [title] and a [lead] paragraph.

- `StudioPageHeader({Key? key, String? eyebrow, required String title, String? lead, String? leadMarkup})` — A header titled [title].

### `StudioPagerLinks` · class

Previous and next page at the end of an article: two big cards, one at each side.

- `StudioPagerLinks({Key? key, StudioNavDestination? previous, StudioNavDestination? next, String? previousLabel, String? nextLabel, String? label})` — A pager with [previous] and/or [next].

### `StudioPalette` · abstract class

Every color token of the system, in one list: what `ThemeData(tokens:)` publishes as `--t-*` variables (each theme writes the side of its brightness, and the page switches them with `light-dark()`).

- `StudioPalette()`

### `StudioPanelThemeData` · class

The look of the floating side panels (navigation, "on this page"): a card that sticks under the top bar and scrolls inside itself.

- `StudioPanelThemeData({Color? color, Color? borderColor, Color? titleColor, double? radius, EdgeInsets? padding, double? width, double? gap, List<BoxShadow>? shadows})` — Creates a panel theme; a null field keeps the default.

### `StudioPanelThemeResolved` · class

The effective look of a panel: [StudioPanelThemeData.of] with every field set. It is a [StudioPanelThemeData] too, so it can be handed to a widget's `theme:` parameter.

- `StudioPanelThemeResolved(…)` — Creates the resolved values.

### `StudioProse` · class

The body of a documentation page: HTML rendered from markdown, in the studio's reading typography.

- `StudioProse(String markup, {Key? key, bool anchors = true, String? anchorLabel})` — Shows [markup].
- `StudioProse.lead(String markup, {Key? key})` — Shows [markup] (one paragraph) as a page's lead: the 17 px subtitle in the soft ink, with its links and inline code. `StudioPageHeader` builds it from `leadMarkup`.

### `StudioRadii` · abstract class

Corner radii, one rule for the whole system: cards are 28, what you press is a pill, what sits inside a card is 12.

- `StudioRadii()`

### `StudioScaffold` · class

The page of a docs site, like Flutter's `Scaffold`: an [appBar], an optional [drawer], the [body], an optional [tableOfContents] and a [footer].

- `StudioScaffold(…)` — A page of [body] under [appBar].

### `StudioSearchDialog` · class

The search dialog a `StudioSearchPill` can open: a modal `<dialog>` 640 px wide, 12 % from the top, with a borderless 48 px field, the [results] under it and a line of key [hints] at the bottom.

- `StudioSearchDialog(…)` — A search dialog with the DOM [id] whose field submits to [action].

### `StudioSearchPill` · class

The search entry of the top bar: a pill with a magnifier, a placeholder and an optional keyboard hint. It is a plain link to the search page, so it works with no JavaScript; a site that has a command palette can open it from the same pill. On a phone it shrinks to the magnifier.

- `StudioSearchPill({Key? key, required String href, String? placeholder, String? shortcut})` — A pill that leads to [href], showing [placeholder].

### `StudioSegmentedButtonThemeData` · class

The look of a `StudioSegmentedControl`: a groove with the chosen segment raised in it (Flutter's `SegmentedButtonThemeData`).

- `StudioSegmentedButtonThemeData(…)` — Creates the theme; a null field keeps the default.

### `StudioSegmentedButtonThemeResolved` · class

The effective look of the segmented control: [StudioSegmentedButtonThemeData.of] with every field set. It is a [StudioSegmentedButtonThemeData] too, so it can be handed to a widget's `theme:` parameter.

- `StudioSegmentedButtonThemeResolved(…)` — Creates the resolved values.

### `StudioSegmentedControl` · class

A pill-shaped control that picks one of a few values (Flutter's `SegmentedButton`): a groove with the chosen segment raised in it.

- `StudioSegmentedControl<T>(…)` — A control over [segments] whose chosen one is in [selected].

### `StudioShadowColors` · abstract class

Shadow colors. Shadows are rare in this language (borders do the work); these stay for what lifts off the page, and the scrim behind a modal.

- `StudioShadowColors()`

### `StudioShadows` · abstract class

Box shadows. Cards are flat (a hairline border); only what floats gets one, and it follows the theme because its color is a token.

- `StudioShadows()`

### `StudioSideNav` · class

The sidebar of a docs page: every page in sight, grouped under section headings, each section a list on a hairline rail where the current page is marked by an accent bar and accent text.

- `StudioSideNav(…)` — A navigation of [sections].

### `StudioSliderThemeData` · class

The look of a `StudioLevelSlider`: a bar with the name on the left, the value on the right and a fill up to the grip (Flutter's `SliderThemeData`).

- `StudioSliderThemeData(…)` — Creates the theme; a null field keeps the default.

### `StudioSliderThemeResolved` · class

The effective look of the level slider: [StudioSliderThemeData.of] with every field set. It is a [StudioSliderThemeData] too, so it can be handed to a widget's `theme:` parameter.

- `StudioSliderThemeResolved(…)` — Creates the resolved values.

### `StudioSpacing` · abstract class

The spacing scale (a 4 px grid): gaps, paddings and rhythm come from here, never from a loose number.

- `StudioSpacing()`

### `StudioStatusColors` · abstract class

States: info, ok, warning, danger and flutter, each with a foreground (text and icon, 4.5:1 on its own background and on the cards), a tinted background and a border. `info` borrows the accent family.

- `StudioStatusColors()`

### `StudioStatusLabel` · class

A small pill that labels something: "New", a version, a status.

- `StudioStatusLabel({Key? key, required Widget label, StudioTone tone = StudioTone.neutral, StudioChipThemeData? theme})` — A pill showing [label] in [tone].

### `StudioStep` · class

One step of a [StudioSteps].

- `StudioStep({required String title, String? body, Widget? child, String? code, StudioCodeLanguage language = StudioCodeLanguage.dart, String? codeTitle, String? id})` — A step titled [title] with a text [body], a [child], or neither (just a title and its [code]).

### `StudioSteps` · class

Numbered steps down a line, for a tutorial.

- `StudioSteps({Key? key, required List<StudioStep> steps, int headingLevel = 3, bool copyButton = true, String? copyLabel, String? copiedLabel})` — Steps that show their code as it is.
- `StudioSteps.diff({Key? key, required List<StudioStep> steps, int headingLevel = 3, bool copyButton = true, String? copyLabel, String? copiedLabel})` — Steps whose code marks what it adds over the previous step's.

### `StudioSurfaceColors` · abstract class

The surfaces things sit on, from the page down to a hovered row.

- `StudioSurfaceColors()`

### `StudioSyntaxColors` · abstract class

Code highlighting colors, saturated around the indigo accent (violet keywords, emerald strings, sky numbers, orange or amber types), 4.5:1 on the code's canvas, the cards, the raised rows and a highlighted line in both themes.

- `StudioSyntaxColors()`

### `StudioTableOfContents` · class

"On this page": the headings of the current page as a list of anchors, with a rule that marks the section being read.

- `StudioTableOfContents({Key? key, required List<StudioTocEntry> entries, String? title, String? current, bool scrollSpy = false, String? backToTopLabel, String backToTopHref = '#'})` — A table of contents titled [title] listing [entries].

### `StudioTheme` · abstract class

The studio's themes, the one thing an app wires up: the palette as `--t-*` variables, a full Material 3 `ColorScheme` and `TextTheme` built from it, Flutter's component themes (`filledButtonTheme`, `chipTheme`, `cardTheme`…) so the plain Material widgets look studio, the two extension groups for what Material has no role for, the self-hosted fonts, the selection color and the focus ring.

- `StudioTheme()`

### `StudioThemeChoice` · class

The three-way theme choice: System (follow the operating system), Light or Dark, as a segmented control of native radios.

- `StudioThemeChoice({Key? key, StudioThemeMode initial = StudioThemeMode.system, String? semanticLabel})` — A System / Light / Dark choice; [initial] is checked when the page loads (default: System). Its labels come from [StudioLocalizations].

### `StudioThemeMode` · enum

What [StudioThemeChoice] picks.

- values: `system`, `light`, `dark`

### `StudioThemeToggle` · class

The light/dark switch of the top bar: thor's `ThemeToggle` (a label of the page's hidden checkbox, so it works with no JavaScript) wearing the studio's sun and moon.

- `StudioThemeToggle({Key? key, double? size})` — A theme switch; [size] is its square target (default: the search pill's height, so the bar's controls line up).

### `StudioTocEntry` · class

A heading of the page in a `StudioTableOfContents`.

- `StudioTocEntry(String label, {required String href, int depth = 0})` — An entry labelled [label] that jumps to [href] (`#anchor`), nested [depth] levels (0 for an `h2`, 1 for an `h3`).

### `StudioTone` · enum

The tone of a callout, a chip or a badge: one enum for every widget that says "info", "ok", "warning" or "danger".

- values: `info`, `ok`, `warn`, `danger`, `neutral`, `flutter`

### `StudioToneColors` · class

One state's three colors: the text or icon, the tinted background and the border. Callouts and chips take one per tone.

- `StudioToneColors({required Color foreground, required Color background, required Color border})` — Creates a tone from its colors.

### `StudioTopBar` · class

The bar at the top of every page: [brand] and the primary [links] on the left, the [search] pill in the middle and the [actions] on the right. It sticks to the top while the page scrolls.

- `StudioTopBar(…)` — A bar with [brand] and the optional [links], [search] and [actions].

### `StudioTypeScale` · abstract class

The font sizes, in logical pixels. A short scale: the page changes between steps by size and weight, never by color alone.

- `StudioTypeScale()`

### `codeTokenColor` · function

The color of a token kind (null: the text color).

- `Color? codeTokenColor(CodeToken kind)`

### `highlightCode` · function

Splits [source] into highlighted runs (adjacent plain text is one run): the same as [highlightSource], which it delegates to.

- `List<(CodeToken, String)> highlightCode(String source, {String language = 'dart'})`

### `highlightSource` · function

Splits [source] into highlighted runs (adjacent plain text is one run). Dart, shell (`bash`, `sh`, `shell`, `zsh`), YAML, TOML and JSON are colored; other languages are one plain run. What the v2 code widgets use.

- `List<(CodeToken, String)> highlightSource(String source, {String language = 'dart'})`

### `highlightToHtml` · function

[source] as escaped HTML with a `studio-tok-<kind>` span per highlighted token (colored by `StudioProse`): for code inside rendered markdown.

- `String highlightToHtml(String source, {String language = 'dart'})`

### `studioThemeChoiceName` · getter

