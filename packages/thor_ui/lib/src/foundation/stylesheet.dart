import 'package:thor_style/thor_style.dart';

import '../core/core.dart' show BuildContext;
import '../widgets/theme.dart' show Theme;
import 'css_rules.dart';
import 'foundation.dart' show kDebugMode;
import 'parent_data.dart';
import 'responsive.dart' show StyleProps;
import 'style_registry.dart' show ConditionalCss, CssCondition;

// Warnings said once per process (Styled with a widget's values).
final _warned = <String>{};

// web: not in Flutter. Flutter has no CSS classes; this adds the app
// stylesheet's classes and the web-only values (`StyleProps`) to the child's
// element, with no extra node.
/// Adds CSS classes (from the app's stylesheets) to the child element without
/// creating a DOM node.
///
/// [style] sets loose values ([StyleProps]) on the child element, per
/// breakpoint or state with `.when()`; with [duration] the state changes
/// transition in CSS (what Flutter does with an `AnimatedContainer` driven
/// by widget state).
class Styled extends ParentDataWrapper {
  /// Wraps `child` with [classes], [style] and inline [css].
  const Styled({
    super.key,
    this.classes = const [],
    this.style,
    this.duration,
    this.curve = Curves.easeOut,
    this.descendants = const {},
    this.whenWithin = const {},
    required super.child,
  });

  /// Classes from the app's stylesheets to add to the element.
  final List<String> classes;

  /// Loose style values (`StyleProps(...).when(...)`).
  final StyleProps? style;

  /// Transition of the values that change with a state or breakpoint.
  final Duration? duration;

  /// Easing curve of [duration]'s transition.
  final Curve curve;

  /// Styles for HTML inside the element that no widget builds (rendered
  /// markdown, a CMS body): selector → values, scoped to this element.
  /// They stop at thor elements inside it: a widget nested in the prose
  /// (a `Card` after a paragraph) keeps its own styles.
  ///
  /// ```dart
  /// Styled(descendants: {
  ///   'h2': StyleProps(textStyle: TextStyle(fontSize: 20), margin: EdgeInsets.only(top: 36)),
  ///   'a:hover': StyleProps(textStyle: TextStyle(decorationColor: accent)),
  ///   'th, td': StyleProps(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
  /// }, child: Container(child: html.RawText(markup)))
  /// ```
  final Map<String, StyleProps> descendants;

  /// Values this element takes while it is inside an ancestor that matches
  /// a selector: selector → values. For a widget (or a state of the page)
  /// that an ancestor changes without a rebuild, e.g. a grid dimmed while
  /// its box has `data-selection="none"`.
  ///
  /// ```dart
  /// Styled(
  ///   whenWithin: {'[data-selection="none"]': StyleProps(opacity: 0.7)},
  ///   child: Grid(...),
  /// )
  /// ```
  ///
  /// `// web:` Flutter reads an ancestor with `InheritedWidget`; here the
  /// browser matches the ancestor (`:where(sel) .x`, no extra specificity).
  final Map<String, StyleProps> whenWithin;

  @override
  WrapData get wrapData {
    // Values a Flutter widget owns: said once per kind in the server's
    // console while developing (the `widget_props_in_styled` lint catches
    // the literal ones in the editor).
    if (kDebugMode && style != null) {
      for (final taken in style!.widgetProps()) {
        if (_warned.add(taken)) {
          print(
            '[thor] Styled(style:) sets a value a Flutter widget owns: '
            '$taken. Styled is for web-only values and numbers that vary '
            'with .when().',
          );
        }
      }
    }
    assert(
      !whenWithin.values.any((p) => p.toCss().values.any(isAdaptive)),
      'Styled.whenWithin varies with its ancestor selectors, not with '
      'StyleProps.when(): use `style:` for values per breakpoint or state.',
    );
    assert(
      !descendants.values.any((p) => p.toCss().values.any(isAdaptive)),
      'Styled.descendants vary with their selectors (`a:hover`), not with '
      'StyleProps.when(): use `style:` for values per breakpoint or state.',
    );
    final props = style?.toCss() ?? const <String, String>{};
    final animated = duration == null
        ? const <String>[]
        : [
            for (final e in props.entries)
              if (isAdaptive(e.value)) e.key,
          ];
    return WrapData(
      classes: classes,
      // Read only, like every WrapData's: no copy when nothing is added.
      css: animated.isEmpty
          ? props
          : {
              ...props,
              ...cssTransition(animated, duration: duration!, curve: curve),
            },
      conditions: [
        for (final MapEntry(key: selector, value: props) in descendants.entries)
          ConditionalCss(CssCondition.descendant(selector), props.toCss()),
        for (final MapEntry(key: ancestor, value: props) in whenWithin.entries)
          ConditionalCss(CssCondition.within(ancestor), props.toCss()),
        if (animated.isNotEmpty)
          const ConditionalCss(CssCondition.reducedMotion, {
            'transition-duration': '1ms',
          }),
      ],
    );
  }
}

/// Material 3's window size classes, emitted as CSS media queries instead of
/// being resolved in Dart: no resize listeners, no rebuilds, correct on first
/// SSR paint. Mobile-first: [compact] is the base (what applies below
/// [medium]); the rest are widths up. Their widths come from
/// `ThemeData.breakpoints` (the values below are the defaults, Material's).
///
/// ```dart
/// Padding(
///   padding: const EdgeInsets.all(16).when(medium: EdgeInsets.all(24)),
///   child: ResponsiveVisibility(visibleFrom: WindowSizeClass.expanded, child: rail),
/// )
/// ```
///
/// `// web:` replaces `MediaQuery.sizeOf(context)` and `LayoutBuilder` over
/// the window: Flutter reads the size in Dart and rebuilds; here the class
/// is a media query in the element's own CSS, so it is right before any JS
/// and a resize rebuilds nothing. To adapt to the width of a box instead of
/// the window, see `LayoutScope`.
enum WindowSizeClass {
  /// Below 600px: phones. The base value of every `.when()`.
  compact(0),

  /// 600px and up: small tablets, a phone in landscape.
  medium(600),

  /// 840px and up: tablets in landscape, small windows. The size where a
  /// navigation rail or a permanent drawer fits.
  expanded(840),

  /// 1200px and up: desktops.
  large(1200),

  /// 1600px and up: ultra-wide screens.
  extraLarge(1600);

  const WindowSizeClass(this.minWidth);

  /// The default minimum viewport width, in logical pixels (the theme's
  /// `Breakpoints` may change it).
  final double minWidth;

  /// `@media screen and (min-width: …) { rules }` for an app stylesheet,
  /// with the default width (app stylesheets are static: to follow the
  /// theme's breakpoints use `Responsive`).
  StyleRule media(List<StyleRule> rules) =>
      css.media('screen and (min-width: ${cssPx(minWidth)})', rules);
}

/// The widths of the [WindowSizeClass]es, part of the theme
/// (`ThemeData(breakpoints: Breakpoints(medium: 640))`): every `.when()`,
/// `Grid`, `Flex` and `ResponsiveVisibility` follows them.
///
/// The defaults are Material 3's: 600/840/1200/1600.
class Breakpoints {
  /// Window size class widths in logical pixels (defaults: Material 3's).
  const Breakpoints({
    this.medium = 600,
    this.expanded = 840,
    this.large = 1200,
    this.extraLarge = 1600,
  });

  /// Width of `WindowSizeClass.medium`.
  final double medium;

  /// Width of `WindowSizeClass.expanded`.
  final double expanded;

  /// Width of `WindowSizeClass.large`.
  final double large;

  /// Width of `WindowSizeClass.extraLarge`.
  final double extraLarge;

  /// The breakpoints of the nearest `Theme` (the app's `ThemeData.breakpoints`;
  /// Material 3's when there is none): the widths app code reads to pick the
  /// size class for a device width, or to draw a preview at one.
  ///
  /// ```dart
  /// final phone = Breakpoints.of(context)[WindowSizeClass.medium] - 1;
  /// ```
  // web: not in Flutter, where the size classes are constants of the
  // Material guidelines; here the theme may move them.
  static Breakpoints of(BuildContext context) => Theme.of(context).breakpoints;

  /// The size class a viewport [width] falls in (the same test as the
  /// `min-width` media queries: a width equal to a breakpoint is in it).
  WindowSizeClass sizeClassFor(double width) {
    if (width >= extraLarge) return WindowSizeClass.extraLarge;
    if (width >= large) return WindowSizeClass.large;
    if (width >= expanded) return WindowSizeClass.expanded;
    if (width >= medium) return WindowSizeClass.medium;
    return WindowSizeClass.compact;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Breakpoints &&
          other.medium == medium &&
          other.expanded == expanded &&
          other.large == large &&
          other.extraLarge == extraLarge;

  @override
  int get hashCode => Object.hash(medium, expanded, large, extraLarge);

  @override
  String toString() =>
      'Breakpoints(medium: $medium, expanded: $expanded, large: $large, '
      'extraLarge: $extraLarge)';

  /// Every width, in [WindowSizeClass] order (a cache key).
  List<double> get widths => [medium, expanded, large, extraLarge];

  /// The width of [sizeClass].
  double operator [](WindowSizeClass sizeClass) => switch (sizeClass) {
    WindowSizeClass.compact => 0,
    WindowSizeClass.medium => medium,
    WindowSizeClass.expanded => expanded,
    WindowSizeClass.large => large,
    WindowSizeClass.extraLarge => extraLarge,
  };

  static final _placeholder = RegExp(
    r'\{bp:(medium|expanded|large|extraLarge)(-?)\}',
  );

  /// [css] with the breakpoint placeholders of `CssCondition.breakpoint`
  /// replaced by these widths.
  String resolve(String css) => css.contains('{bp:')
      ? css.replaceAllMapped(_placeholder, (m) {
          final px = this[WindowSizeClass.values.byName(m[1]!)];
          return cssPx(m[2]!.isEmpty ? px : px - 0.02);
        })
      : css;
}
