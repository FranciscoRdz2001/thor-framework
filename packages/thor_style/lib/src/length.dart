import 'adaptive.dart';
import 'css.dart';
import 'css_variable.dart';

// web: Flutter has no CSS lengths; its sizes are `double` logical pixels.
// A `Length` is for the values only the browser knows (`dvh`, `%`, `calc`).
/// A CSS length: what a web layout needs beyond Flutter's logical pixels
/// (`double`), like the window's height or a share of the parent.
///
/// `// web:` Flutter sizes are `double`s in logical pixels; the browser also
/// has relative units and `calc()`, so a [Length] is the CSS value itself.
///
/// Flutter's own parameters (`EdgeInsets`, `SizedBox.width`…) stay
/// `double`; a [Length] appears where the web has no Flutter equivalent
/// (`StyleProps(minHeight: 100.dvh)`). Built from a number with the unit
/// extensions, and combined into `calc()` with arithmetic:
///
/// ```dart
/// 16.px            // 16px
/// 100.dvh - 48.px  // calc(100dvh - 48px)
/// 50.percent * 2   // calc(50% * 2)
/// Length.variable(CssVariable('--gutter'), fallback: 16.px)
/// 40.px.when(expanded: 56.px) // per breakpoint (see [Adaptable])
/// ```
base class Length with Adaptable<Length> {
  const Length._(this._value, this._unit)
    : _expr = null,
      _fallback = null,
      _args = null;

  const Length._expr(String this._expr)
    : _value = 0,
      _unit = '',
      _fallback = null,
      _args = null;

  // A CSS function of other lengths (`min`, `max`, `clamp`): the operands
  // are kept and written out when the CSS is asked for, so it stays const.
  const Length._function(this._unit, List<Length> this._args)
    : _value = 0,
      _expr = null,
      _fallback = null;

  /// The variants travel inside the CSS value, like a `Color`'s:
  /// `SizedBox(heightLength: 40.px.when(expanded: 56.px))` is a box (or,
  /// between the children of a `Column`, a margin) that is 40px high below
  /// `expanded` and 56px from it up.
  @override
  Length withVariants(Adaptive<Length> variants) =>
      Length._expr(variants.css((l) => l.css));

  /// Logical pixels (`px`); `double.infinity` is the full width (`100%`),
  /// as in `SizedBox(width: double.infinity)`.
  const Length.px(double value) : this._(value, 'px');

  /// A share of the parent's size (`%`).
  const Length.percent(double value) : this._(value, '%');

  /// Times the element's font size (`em`).
  const Length.em(double value) : this._(value, 'em');

  /// Times the page's root font size (`rem`).
  const Length.rem(double value) : this._(value, 'rem');

  /// Times the width of the `0` glyph (`ch`): a line of about N characters.
  const Length.ch(double value) : this._(value, 'ch');

  /// Percent of the window's width (`vw`).
  const Length.vw(double value) : this._(value, 'vw');

  /// Percent of the window's height (`vh`).
  const Length.vh(double value) : this._(value, 'vh');

  /// Percent of the window's height as it is now (`dvh`: follows a phone's
  /// browser bars showing and hiding).
  const Length.dvh(double value) : this._(value, 'dvh');

  /// Percent of the window's smallest height (`svh`: with the phone's
  /// browser bars shown).
  const Length.svh(double value) : this._(value, 'svh');

  /// Percent of the window's largest height (`lvh`: with the phone's
  /// browser bars hidden).
  const Length.lvh(double value) : this._(value, 'lvh');

  /// Percent of the nearest size container's width (`cqw`; the container
  /// is an element with `container-type`, see `StyleProps(containerType:)`).
  ///
  /// `// web:` Flutter's `LayoutBuilder` hands the builder the parent's
  /// constraints; the browser measures the container itself, with no rebuild.
  const Length.cqw(double value) : this._(value, 'cqw');

  /// Percent of the nearest size container's height (`cqh`); the container
  /// needs `ContainerType.size`.
  const Length.cqh(double value) : this._(value, 'cqh');

  /// Percent of the nearest container's inline size (`cqi`).
  const Length.cqi(double value) : this._(value, 'cqi');

  /// Percent of the nearest container's block size (`cqb`).
  const Length.cqb(double value) : this._(value, 'cqb');

  /// Percent of the smaller of the container's width and height (`cqmin`).
  const Length.cqmin(double value) : this._(value, 'cqmin');

  /// Percent of the larger of the container's width and height (`cqmax`).
  const Length.cqmax(double value) : this._(value, 'cqmax');

  /// A theme or page variable (`var(--name)`), with the length to use
  /// where it isn't defined.
  ///
  /// `// web:` the low-level layer: the name is the app's (a stylesheet
  /// that defines it, `WatchVariables({CssVariable<Length>('--name'): …})`).
  /// A value that follows a `ThorState` needs no name: `BoundLength`
  /// (`card.radius.px`).
  const Length.variable(CssVariable<Length> variable, {Length? fallback})
    : _expr = variable,
      _value = 0,
      _unit = 'var',
      _fallback = fallback,
      _args = null;

  /// The notch or the system bar at the top of the screen
  /// (`env(safe-area-inset-top)`, 0 where there is none).
  ///
  /// `// web:` not in Flutter (its `MediaQuery.paddingOf` is read in `build`);
  /// the browser knows these, so they are CSS lengths, combinable
  /// (`Length.safeAreaBottom + 16.px`). For a whole box use `SafeArea`.
  static const safeAreaTop = Length._expr('env(safe-area-inset-top, 0px)');

  /// The right edge's safe area (`env(safe-area-inset-right)`).
  static const safeAreaRight = Length._expr('env(safe-area-inset-right, 0px)');

  /// The home indicator at the bottom (`env(safe-area-inset-bottom)`).
  static const safeAreaBottom = Length._expr(
    'env(safe-area-inset-bottom, 0px)',
  );

  /// The left edge's safe area (`env(safe-area-inset-left)`).
  static const safeAreaLeft = Length._expr('env(safe-area-inset-left, 0px)');

  /// The value of the parent (`inherit`): `font-size: inherit` in a reset.
  static const inherit = Length._expr('inherit');

  /// No length.
  static const zero = Length._expr('0');

  /// The browser decides (`auto`): the content's size, or what is left.
  static const auto = Length._expr('auto');

  /// As wide as the content on one line (`max-content`).
  ///
  /// `// web:` content-based sizes are the browser's; Flutter's equivalent is
  /// `IntrinsicWidth`.
  static const maxContent = Length._expr('max-content');

  /// As narrow as the content can get (`min-content`).
  static const minContent = Length._expr('min-content');

  /// The content's size, but never more than the space left
  /// (`fit-content`).
  static const fitContent = Length._expr('fit-content');

  /// The smallest of [values] (`min()`).
  const Length.min(List<Length> values) : this._function('min', values);

  /// The largest of [values] (`max()`).
  const Length.max(List<Length> values) : this._function('max', values);

  /// [preferred], kept between [min] and [max] (`clamp()`): a size that
  /// follows the window within limits, and a `const` one.
  ///
  /// ```dart
  /// const Length.clamp(Length.px(14), Length.vw(3), Length.px(28))
  /// ```
  const factory Length.clamp(Length min, Length preferred, Length max) =
      _ClampLength;

  final double _value;
  final String _unit;
  final String? _expr;
  final Length? _fallback;
  final List<Length>? _args;

  bool get _isCalc => _unit.isEmpty && (_expr?.startsWith('(') ?? false);

  /// The CSS value (`16px`, `calc(100dvh - 48px)`).
  String get css {
    if (_isCalc) return 'calc${_expr!}';
    return _write();
  }

  /// The value inside another expression: an arithmetic one stays in
  /// parentheses instead of a nested `calc()`.
  ///
  /// `// web:` a unitless `0` is a `<number>` inside `calc()`/`min()`/`max()`,
  /// where `number + length` is invalid, so it is written `0px` there.
  String get _inner => _expr == '0' && _unit.isEmpty ? '0px' : _write();

  String _write() {
    if (_unit == 'var') {
      final fallback = _fallback;
      return fallback == null
          ? 'var(${_expr!})'
          : 'var(${_expr!}, ${fallback.css})';
    }
    if (_args case final args?) {
      return '$_unit(${args.map((a) => a._inner).join(', ')})';
    }
    if (_expr case final expr?) return expr;
    if (_unit == 'px') return cssPx(_value);
    return '${cssNum(_value)}$_unit';
  }

  /// `calc(this + other)`.
  Length operator +(Length other) =>
      Length._expr('($_inner + ${other._inner})');

  /// `calc(this - other)`.
  Length operator -(Length other) =>
      Length._expr('($_inner - ${other._inner})');

  /// `calc(this * factor)`.
  Length operator *(num factor) =>
      Length._expr('($_inner * ${cssNum(factor)})');

  /// `calc(this / divisor)`.
  Length operator /(num divisor) {
    assert(divisor != 0, 'Division by zero.');
    return Length._expr('($_inner / ${cssNum(divisor)})');
  }

  /// `calc(-this)`.
  Length operator -() => Length._expr('($_inner * -1)');

  @override
  bool operator ==(Object other) => other is Length && other.css == css;

  @override
  int get hashCode => css.hashCode;

  @override
  String toString() => 'Length($css)';
}

/// The units as number extensions: `16.px`, `50.percent`, `100.dvh`.
extension LengthUnits on num {
  /// See [Length.px].
  Length get px => Length.px(toDouble());

  /// See [Length.percent].
  Length get percent => Length.percent(toDouble());

  /// See [Length.em].
  Length get em => Length.em(toDouble());

  /// See [Length.rem].
  Length get rem => Length.rem(toDouble());

  /// See [Length.ch].
  Length get ch => Length.ch(toDouble());

  /// See [Length.vw].
  Length get vw => Length.vw(toDouble());

  /// See [Length.vh].
  Length get vh => Length.vh(toDouble());

  /// See [Length.dvh].
  Length get dvh => Length.dvh(toDouble());

  /// See [Length.svh].
  Length get svh => Length.svh(toDouble());

  /// See [Length.lvh].
  Length get lvh => Length.lvh(toDouble());

  /// See [Length.cqw].
  Length get cqw => Length.cqw(toDouble());

  /// See [Length.cqh].
  Length get cqh => Length.cqh(toDouble());

  /// See [Length.cqi].
  Length get cqi => Length.cqi(toDouble());

  /// See [Length.cqb].
  Length get cqb => Length.cqb(toDouble());

  /// See [Length.cqmin].
  Length get cqmin => Length.cqmin(toDouble());

  /// See [Length.cqmax].
  Length get cqmax => Length.cqmax(toDouble());
}

// `clamp()` keeps its three operands (a list literal of them couldn't be
// const).
final class _ClampLength extends Length {
  const _ClampLength(this._min, this._preferred, this._max)
    : super._expr('clamp');

  final Length _min;
  final Length _preferred;
  final Length _max;

  @override
  String _write() =>
      'clamp(${_min._inner}, ${_preferred._inner}, ${_max._inner})';
}

/// A plain number the browser computes: how many times one length fits in
/// another (`StyleProps(scaleRatio:)`).
///
/// `// web:` Flutter's `Transform.scale(scale:)` gets a `double` it computed
/// from the constraints while laying out; in the browser the sizes are only
/// known to the browser, so the division is written as CSS. Dividing two
/// lengths of different units is `tan(atan2(a, b))`, which is `a / b`.
///
/// ```dart
/// // Scale a 390 x 844 device to fit its stage, never above 1 (the stage
/// // has ContainerType.size):
/// Ratio.min([
///   Ratio.value(1),
///   Ratio.of(100.cqh, 844.px),
///   Ratio.of(100.cqw, 390.px),
/// ])
/// ```
final class Ratio {
  /// [numerator] divided by [denominator] (`tan(atan2(…))`).
  const Ratio.of(Length numerator, Length denominator)
    : _fn = 'ratio',
      _value = 0,
      _numerator = numerator,
      _denominator = denominator,
      _parts = null;

  /// A fixed number (`1`).
  const Ratio.value(double value)
    : _fn = '',
      _value = value,
      _numerator = null,
      _denominator = null,
      _parts = null;

  /// The smallest of [values] (`min()`).
  const Ratio.min(List<Ratio> values)
    : _fn = 'min',
      _value = 0,
      _numerator = null,
      _denominator = null,
      _parts = values;

  /// The largest of [values] (`max()`).
  const Ratio.max(List<Ratio> values)
    : _fn = 'max',
      _value = 0,
      _numerator = null,
      _denominator = null,
      _parts = values;

  final String _fn;
  final double _value;
  final Length? _numerator;
  final Length? _denominator;
  final List<Ratio>? _parts;

  /// The CSS number (`1`, `tan(atan2(100cqh, 844px))`, `min(1, …)`).
  String get css {
    if (_parts case final parts?) {
      return '$_fn(${parts.map((p) => p.css).join(', ')})';
    }
    if (_fn == 'ratio') {
      return 'tan(atan2(${_numerator!._inner}, ${_denominator!._inner}))';
    }
    return cssNum(_value);
  }

  @override
  bool operator ==(Object other) => other is Ratio && other.css == css;

  @override
  int get hashCode => css.hashCode;

  @override
  String toString() => 'Ratio($css)';
}
