import 'css.dart';
import 'curves.dart';
import 'layout_enums.dart' show Axis;

// web: the values below have no Flutter type: Flutter animates with
// controllers and paints with layers, the browser does both from one CSS
// declaration. Each one is typed so the declaration never has to be a
// string.

/// A property that [Transition] can name, so the property is not a string
/// typed by hand.
abstract final class CssProperty {
  /// `all`: every property that can animate.
  static const all = 'all';

  /// `opacity`.
  static const opacity = 'opacity';

  /// `transform`.
  static const transform = 'transform';

  /// `scale`.
  static const scale = 'scale';

  /// `rotate`.
  static const rotate = 'rotate';

  /// `translate`.
  static const translate = 'translate';

  /// `color`.
  static const color = 'color';

  /// `background-color`.
  static const backgroundColor = 'background-color';

  /// `border-color`.
  static const borderColor = 'border-color';

  /// `box-shadow`.
  static const boxShadow = 'box-shadow';

  /// `filter`.
  static const filter = 'filter';

  /// `width`.
  static const width = 'width';

  /// `height`.
  static const height = 'height';

  /// `left`.
  static const left = 'left';

  /// `top`.
  static const top = 'top';

  /// `right`.
  static const right = 'right';

  /// `bottom`.
  static const bottom = 'bottom';

  /// `inset`.
  static const inset = 'inset';

  /// A custom property (`--t-primary`): `CssProperty.custom('--t-primary')`.
  static String custom(String name) {
    assert(name.startsWith('--'), 'A custom property starts with --: $name');
    return name;
  }
}

/// One property animating to its new value (`transition`): what
/// `AnimatedContainer` does with a duration and a curve, as one CSS
/// declaration the browser runs.
///
/// ```dart
/// StyleProps(transition: [
///   Transition(CssProperty.scale, Duration(milliseconds: 150), curve: Curves.easeOut),
/// ])
/// ```
final class Transition {
  /// Animates [property] over [duration].
  const Transition(
    this.property,
    this.duration, {
    this.curve = Curves.ease,
    this.delay = Duration.zero,
  });

  /// The CSS property that animates ([CssProperty]).
  final String property;

  /// How long it takes.
  final Duration duration;

  /// The speed over time.
  final Curve curve;

  /// How long before it starts.
  final Duration delay;

  /// `scale 150ms cubic-bezier(…)`.
  String get css =>
      '$property ${cssDuration(duration)} ${_easing(curve)}'
      '${delay == Duration.zero ? '' : ' ${cssDuration(delay)}'}';

  /// The `transition` declaration of [transitions]; none writes `none`.
  static CssDeclarations toCss(List<Transition> transitions) => {
    'transition': transitions.isEmpty
        ? 'none'
        : transitions.map((t) => t.css).join(', '),
  };

  @override
  bool operator ==(Object other) => other is Transition && other.css == css;

  @override
  int get hashCode => css.hashCode;
}

/// Which way a [CssAnimation] runs.
enum AnimationDirection {
  /// Start to end each time.
  normal('normal'),

  /// End to start.
  reverse('reverse'),

  /// Forward, then back.
  alternate('alternate');

  const AnimationDirection(this.css);

  /// The CSS keyword.
  final String css;
}

/// What an animation leaves on the box before and after it runs
/// (`animation-fill-mode`).
enum AnimationFill {
  /// Nothing.
  none('none'),

  /// The last keyframe stays.
  forwards('forwards'),

  /// The first keyframe applies during the delay.
  backwards('backwards'),

  /// Both of the above.
  both('both');

  const AnimationFill(this.css);

  /// The CSS keyword.
  final String css;
}

/// A named `@keyframes` run on a box (`animation`): the browser plays the
/// frames, so no ticker runs in Dart.
///
/// ```dart
/// CssAnimation('marquee', Duration(seconds: 25), curve: Curves.linear, repeat: 0)
/// ```
final class CssAnimation {
  /// Runs the keyframes called [name] over [duration].
  const CssAnimation(
    this.name,
    this.duration, {
    this.curve = Curves.ease,
    this.delay = Duration.zero,
    this.repeat = 1,
    this.direction = AnimationDirection.normal,
    this.fill = AnimationFill.none,
  });

  /// The `@keyframes` name (`css.keyframes(name, …)`).
  final String name;

  /// One run's length.
  final Duration duration;

  /// The speed over time.
  final Curve curve;

  /// How long before it starts.
  final Duration delay;

  /// How many times it runs; `0` is forever (`infinite`).
  final int repeat;

  /// Which way each run goes.
  final AnimationDirection direction;

  /// What stays on the box outside the run.
  final AnimationFill fill;

  /// `docs-rise 200ms ease 0ms 1 normal both`.
  String get css =>
      '$name ${cssDuration(duration)} ${_easing(curve)} ${cssDuration(delay)} '
      '${repeat == 0 ? 'infinite' : '$repeat'} ${direction.css} ${fill.css}';

  /// The `animation` declaration of [animations]; none writes `none`.
  static CssDeclarations toCss(List<CssAnimation> animations) => {
    'animation': animations.isEmpty
        ? 'none'
        : animations.map((a) => a.css).join(', '),
  };

  @override
  bool operator ==(Object other) => other is CssAnimation && other.css == css;

  @override
  int get hashCode => css.hashCode;
}

/// Flutter's `ImageFilter` for a box: `blur` and the color filters the
/// browser applies to the box and what is inside it (`filter`).
///
/// ```dart
/// ImageFilter.saturate(0)               // black and white
/// ImageFilter.compose(outer: ImageFilter.blur(sigmaX: 8), inner: ImageFilter.brightness(1.1))
/// ```
final class ImageFilter {
  const ImageFilter._(this.css);

  /// A Gaussian blur of [sigmaX] logical pixels. `// web:` CSS blurs with
  /// one radius for both axes: [sigmaY] is used only when [sigmaX] is 0. There
  /// is no `tileMode`: the browser decides the edges.
  factory ImageFilter.blur({double sigmaX = 0, double sigmaY = 0}) =>
      ImageFilter._('blur(${cssPx(sigmaX == 0 ? sigmaY : sigmaX)})');

  /// Color saturation: `0` grey, `1` as is, above 1 vivid.
  // web: not a Flutter `ImageFilter` constructor (Flutter does this with
  // `ColorFilter.matrix`); it is the CSS `saturate()` filter function.
  factory ImageFilter.saturate(double amount) =>
      ImageFilter._('saturate(${cssNum(amount)})');

  /// Brightness: `0` black, `1` as is.
  // web: not a Flutter `ImageFilter` constructor (Flutter does this with
  // `ColorFilter.matrix`); it is the CSS `brightness()` filter function.
  factory ImageFilter.brightness(double amount) =>
      ImageFilter._('brightness(${cssNum(amount)})');

  /// Contrast: `0` flat grey, `1` as is.
  // web: not a Flutter `ImageFilter` constructor (Flutter does this with
  // `ColorFilter.matrix`); it is the CSS `contrast()` filter function.
  factory ImageFilter.contrast(double amount) =>
      ImageFilter._('contrast(${cssNum(amount)})');

  /// Share of grey: `0` as is, `1` fully grey.
  // web: not a Flutter `ImageFilter` constructor (Flutter does this with
  // `ColorFilter.matrix`); it is the CSS `grayscale()` filter function.
  factory ImageFilter.grayscale(double amount) =>
      ImageFilter._('grayscale(${cssNum(amount)})');

  /// Share of inverted colors: `0` as is, `1` a negative (a dark-mode
  /// version of a black-on-white diagram).
  // web: not a Flutter `ImageFilter` constructor (Flutter does this with
  // `ColorFilter.matrix`); it is the CSS `invert()` filter function.
  factory ImageFilter.invert(double amount) =>
      ImageFilter._('invert(${cssNum(amount)})');

  /// Share of sepia tone: `0` as is, `1` fully sepia.
  // web: not a Flutter `ImageFilter` constructor (Flutter does this with
  // `ColorFilter.matrix`); it is the CSS `sepia()` filter function.
  factory ImageFilter.sepia(double amount) =>
      ImageFilter._('sepia(${cssNum(amount)})');

  /// Turns every hue by [degrees] around the color wheel.
  // web: not a Flutter `ImageFilter` constructor (Flutter does this with
  // `ColorFilter.matrix`); it is the CSS `hue-rotate()` filter function.
  factory ImageFilter.hueRotate(double degrees) =>
      ImageFilter._('hue-rotate(${cssNum(degrees)}deg)');

  /// Opacity of the filtered result: `0` invisible, `1` as is.
  // web: not a Flutter `ImageFilter` constructor; it is the CSS `opacity()`
  // filter function (it composes with the others, unlike the `opacity`
  // property).
  factory ImageFilter.opacity(double amount) =>
      ImageFilter._('opacity(${cssNum(amount)})');

  /// [inner] applies first, then [outer] (Flutter's `ImageFilter.compose`).
  factory ImageFilter.compose({
    required ImageFilter outer,
    required ImageFilter inner,
  }) => ImageFilter._('${inner.css} ${outer.css}');

  /// The CSS value (`blur(8px) brightness(1.1)`).
  final String css;

  @override
  bool operator ==(Object other) => other is ImageFilter && other.css == css;

  @override
  int get hashCode => css.hashCode;
}

/// How a box mixes with what is under it (`mix-blend-mode`): Flutter's
/// `BlendMode` for a layer.
///
/// `// web:` only the modes `mix-blend-mode` has: Flutter's Porter-Duff
/// members (`clear`, `src`, `dst`, `srcIn`, `dstOut`, `srcATop`, `xor`,
/// `modulate`…) have no keyword and are left out.
enum BlendMode {
  /// Plain painting (`normal`).
  srcOver('normal'),

  /// Darkens: the colors multiply.
  multiply('multiply'),

  /// Lightens: the opposite of [multiply].
  screen('screen'),

  /// [multiply] or [screen] by the backdrop.
  overlay('overlay'),

  /// The darker of both.
  darken('darken'),

  /// The lighter of both.
  lighten('lighten'),

  /// Brightens the backdrop.
  colorDodge('color-dodge'),

  /// Darkens the backdrop.
  colorBurn('color-burn'),

  /// [multiply] or [screen] by the source.
  hardLight('hard-light'),

  /// A softer [hardLight].
  softLight('soft-light'),

  /// The distance between both colors.
  difference('difference'),

  /// A softer [difference].
  exclusion('exclusion'),

  /// The source's hue.
  hue('hue'),

  /// The source's saturation.
  saturation('saturation'),

  /// The source's hue and saturation.
  color('color'),

  /// The source's luminosity.
  luminosity('luminosity'),

  /// Adds the colors, so two equal layers don't double what they share
  /// (`plus-lighter`).
  plus('plus-lighter');

  const BlendMode(this.css);

  /// The CSS keyword.
  final String css;
}

/// Whether a form control paints itself (`appearance`).
enum Appearance {
  /// The browser draws the control.
  auto('auto'),

  /// The control draws nothing of its own: the page does.
  none('none');

  const Appearance(this.css);

  /// The CSS keyword.
  final String css;
}

/// How much room the scrollbar takes (`scrollbar-width`).
enum ScrollbarWidth {
  /// The browser's classic bar.
  auto('auto'),

  /// A thinner bar.
  thin('thin'),

  /// No bar; the box still scrolls.
  none('none');

  const ScrollbarWidth(this.css);

  /// The CSS keyword.
  final String css;
}

/// How lines break (`text-wrap`).
enum TextWrap {
  /// Breaks where the line is full.
  wrap('wrap'),

  /// One line.
  nowrap('nowrap'),

  /// Lines of a similar length (headings).
  balance('balance'),

  /// Avoids a last line with one word (paragraphs).
  pretty('pretty');

  const TextWrap(this.css);

  /// The CSS keyword.
  final String css;
}

/// Whether a word too long for its line may break (`overflow-wrap`).
enum OverflowWrap {
  /// Never.
  normal('normal'),

  /// Only when the word alone does not fit.
  breakWord('break-word'),

  /// As [breakWord], and it counts for the box's minimum width.
  anywhere('anywhere');

  const OverflowWrap(this.css);

  /// The CSS keyword.
  final String css;
}

/// An inline box against its line (`vertical-align`).
enum VerticalAlign {
  /// On the baseline.
  baseline('baseline'),

  /// Top of the line.
  top('top'),

  /// Middle of the line.
  middle('middle'),

  /// Bottom of the line.
  bottom('bottom'),

  /// Lowered, like a subscript.
  sub('sub'),

  /// Raised, like a superscript.
  superscript('super');

  const VerticalAlign(this.css);

  /// The CSS keyword.
  final String css;
}

/// Which axes the reader may resize a box on (`resize`).
enum Resize {
  /// Fixed.
  none('none'),

  /// Both ways.
  both('both'),

  /// Wider and narrower.
  horizontal('horizontal'),

  /// Taller and shorter.
  vertical('vertical');

  const Resize(this.css);

  /// The CSS keyword.
  final String css;
}

/// What `width` and `height` measure (`box-sizing`).
enum BoxSizing {
  /// The content only (padding and border add to it).
  contentBox('content-box'),

  /// Content, padding and border: what a Flutter `Container` measures.
  borderBox('border-box');

  const BoxSizing(this.css);

  /// The CSS keyword.
  final String css;
}

/// Whether the browser skips the work of a box that is off screen
/// (`content-visibility`).
enum ContentVisibility {
  /// Always rendered.
  visible('visible'),

  /// Not rendered while it is off screen.
  auto('auto'),

  /// Never rendered.
  hidden('hidden');

  const ContentVisibility(this.css);

  /// The CSS keyword.
  final String css;
}

/// Which color schemes the element and the browser's own UI (form controls,
/// scrollbars, `light-dark()`) may use (`color-scheme`).
///
/// Named `CssColorScheme` because `ColorScheme` is the theme's palette.
enum CssColorScheme {
  /// No scheme requested: the page's default (light).
  normal('normal'),

  /// Light only.
  light('light'),

  /// Dark only.
  dark('dark'),

  /// Both, following the operating system (`light dark`).
  lightDark('light dark');

  const CssColorScheme(this.css);

  /// The CSS value.
  final String css;
}

/// How strictly a scroll lands on the snap points.
enum ScrollSnapStrictness {
  /// Always lands on one.
  mandatory('mandatory'),

  /// Lands on one when close.
  proximity('proximity');

  const ScrollSnapStrictness(this.css);

  /// The CSS keyword.
  final String css;
}

/// A scroller that snaps to its children (`scroll-snap-type`): what
/// Flutter's `PageScrollPhysics` does.
final class ScrollSnapType {
  /// Snaps along [axis].
  const ScrollSnapType(
    this.axis, {
    this.strictness = ScrollSnapStrictness.mandatory,
  });

  /// The scrolling axis.
  final Axis axis;

  /// How firmly it snaps.
  final ScrollSnapStrictness strictness;

  /// `x mandatory`.
  String get css => '${axis == Axis.horizontal ? 'x' : 'y'} ${strictness.css}';
}

/// Where a child of a snapping scroller rests (`scroll-snap-align`).
enum ScrollSnapAlign {
  /// Not a snap point.
  none('none'),

  /// Its start edge meets the scroller's.
  start('start'),

  /// Its center meets the scroller's.
  center('center'),

  /// Its end edge meets the scroller's.
  end('end');

  const ScrollSnapAlign(this.css);

  /// The CSS keyword.
  final String css;
}

/// Whether the links to the children of a box mark the one in view as
/// current (`scroll-target-group`: the browser's own scroll spy).
enum ScrollTargetGroup {
  /// No.
  none('none'),

  /// Yes: the link to the child in view matches `:target-current`.
  auto('auto');

  const ScrollTargetGroup(this.css);

  /// The CSS keyword.
  final String css;
}

/// Whether a table's cell borders merge (`border-collapse`).
enum BorderCollapse {
  /// Each cell has its own border.
  separate('separate'),

  /// Neighbors share one border.
  collapse('collapse');

  const BorderCollapse(this.css);

  /// The CSS keyword.
  final String css;
}

/// How text edges are smoothed on macOS (`-webkit-font-smoothing` and
/// `-moz-osx-font-smoothing`; other systems ignore both). Inherited, so
/// set once on the page's root.
///
/// `// web:` not in Flutter, whose engine draws the glyphs itself; in the
/// browser the system rasterizes them, and macOS draws light text on a
/// dark background heavier unless it is [antialiased].
enum FontSmoothing {
  /// The system's choice (`auto`).
  auto('auto', 'auto'),

  /// Grayscale antialiasing, thinner glyphs (`antialiased` / `grayscale`).
  antialiased('antialiased', 'grayscale');

  const FontSmoothing(this._webkit, this._moz);

  final String _webkit;
  final String _moz;

  /// Its declarations, one per engine.
  CssDeclarations toCss() => {
    '-webkit-font-smoothing': _webkit,
    '-moz-osx-font-smoothing': _moz,
  };
}

// The default curve is the keyword (shorter, same curve).
String _easing(Curve curve) => curve == Curves.ease ? 'ease' : curve.css;
