import 'adaptive.dart';
import 'color.dart';
import 'css.dart';
import 'equality.dart';
import 'geometry.dart';
import 'length.dart';

/// Flutter's `FontWeight`: the nine named weights, or any value from 1 to
/// 1000 for a variable font (`FontWeight(650)`), as in current Flutter.
class FontWeight {
  /// A weight of [value], from 1 (thinnest) to 1000 (heaviest); the CSS
  /// `font-weight` number. A static font draws the nearest weight it has.
  const FontWeight(this.value)
    : assert(
        value >= 1 && value <= 1000,
        'FontWeight takes a value from 1 to 1000',
      );

  /// The CSS `font-weight` number (1-1000; the named weights are 100-900).
  final int value;

  /// Thin, CSS `font-weight: 100`.
  static const w100 = FontWeight(100);

  /// Extra light, CSS `font-weight: 200`.
  static const w200 = FontWeight(200);

  /// Light, CSS `font-weight: 300`.
  static const w300 = FontWeight(300);

  /// Normal, CSS `font-weight: 400`.
  static const w400 = FontWeight(400);

  /// Medium, CSS `font-weight: 500`.
  static const w500 = FontWeight(500);

  /// Semi bold, CSS `font-weight: 600`.
  static const w600 = FontWeight(600);

  /// Bold, CSS `font-weight: 700`.
  static const w700 = FontWeight(700);

  /// Extra bold, CSS `font-weight: 800`.
  static const w800 = FontWeight(800);

  /// Black, CSS `font-weight: 900`.
  static const w900 = FontWeight(900);

  /// Alias for `w400`, the default weight.
  static const normal = w400;

  /// Alias for `w700`.
  static const bold = w700;

  /// The nine named weights, thinnest first.
  static const values = [w100, w200, w300, w400, w500, w600, w700, w800, w900];

  /// The weight between [a] and [b] at [t] (a null one is [normal]),
  /// rounded to a whole value; null when both are.
  static FontWeight? lerp(FontWeight? a, FontWeight? b, double t) {
    if (a == null && b == null) return null;
    final x = (a ?? normal).value, y = (b ?? normal).value;
    return FontWeight((x + (y - x) * t).round().clamp(1, 1000));
  }

  @override
  bool operator ==(Object other) => other is FontWeight && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'FontWeight($value)';
}

/// Flutter's `FontStyle`.
enum FontStyle {
  /// Upright glyphs.
  normal,

  /// Slanted glyphs (`font-style: italic`).
  italic,
}

/// Flutter's `TextAlign`.
enum TextAlign {
  /// Aligns text to the left edge.
  left('left'),

  /// Aligns text to the right edge.
  right('right'),

  /// Centers text.
  center('center'),

  /// Stretches lines to fill the width, except the last line.
  justify('justify'),

  /// Aligns text to the start edge (left in LTR).
  start('start'),

  /// Aligns text to the end edge (right in LTR).
  end('end');

  /// Associates this value with its `text-align` [css] keyword.
  const TextAlign(this.css);

  /// The `text-align` keyword.
  final String css;
}

/// Flutter's `TextOverflow`.
enum TextOverflow {
  /// Clips overflowing text at the box edge.
  clip,

  /// Fades overflowing text to transparent.
  fade,

  /// Truncates overflowing text with an ellipsis (`…`).
  ellipsis,

  /// Allows text to overflow its box without clipping.
  visible,
}

/// Flutter's `TextDecoration` (combinable).
class TextDecoration {
  const TextDecoration._(this._lines);
  final Set<String> _lines;

  /// No decoration line.
  static const none = TextDecoration._({});

  /// A line under the text.
  static const underline = TextDecoration._({'underline'});

  /// A line over the text.
  static const overline = TextDecoration._({'overline'});

  /// A line through the middle of the text.
  static const lineThrough = TextDecoration._({'line-through'});

  /// Combines several decorations into one (e.g. underline + line-through).
  factory TextDecoration.combine(List<TextDecoration> decorations) =>
      TextDecoration._({for (final d in decorations) ...d._lines});

  /// The `text-decoration-line` value (`none` or space-separated keywords).
  String get css => _lines.isEmpty ? 'none' : _lines.join(' ');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextDecoration &&
          other._lines.length == _lines.length &&
          other._lines.containsAll(_lines);

  @override
  int get hashCode => Object.hashAllUnordered(_lines);
}

/// Flutter's `TextDecorationStyle`.
enum TextDecorationStyle {
  /// A single solid line.
  solid,

  /// Two parallel solid lines.
  double,

  /// A dotted line.
  dotted,

  /// A dashed line.
  dashed,

  /// A wavy line.
  wavy,
}

/// Flutter's `Shadow` (text shadow).
class Shadow {
  /// Creates a text shadow, defaulting to an opaque black shadow with no
  /// offset or blur.
  const Shadow({
    this.color = const Color(0xFF000000),
    this.offset = Offset.zero,
    this.blurRadius = 0,
  });

  /// Color of the shadow.
  final Color color;

  /// Translation of the shadow from the text, in logical pixels.
  final Offset offset;

  /// Standard deviation of the blur, in logical pixels.
  final double blurRadius;

  /// The `text-shadow` value: `offsetX offsetY blur color`.
  String get css =>
      '${cssPx(offset.dx)} ${cssPx(offset.dy)} ${cssPx(blurRadius)} ${color.css}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Shadow &&
          other.color == color &&
          other.offset == offset &&
          other.blurRadius == blurRadius;

  @override
  int get hashCode => Object.hash(color, offset, blurRadius);
}

/// Flutter's `FontFeature`: an OpenType feature of the font
/// (`font-feature-settings`).
class FontFeature {
  /// Feature [feature] (a four-letter tag) set to [value].
  const FontFeature(this.feature, [this.value = 1]);

  /// Turns [feature] on.
  const FontFeature.enable(this.feature) : value = 1;

  /// Turns [feature] off.
  const FontFeature.disable(this.feature) : value = 0;

  /// Digits of equal width, for columns of figures (`tnum`).
  const FontFeature.tabularFigures() : feature = 'tnum', value = 1;

  /// Digits of their natural width (`pnum`).
  const FontFeature.proportionalFigures() : feature = 'pnum', value = 1;

  /// Old-style digits (`onum`).
  const FontFeature.oldstyleFigures() : feature = 'onum', value = 1;

  /// Lining digits (`lnum`).
  const FontFeature.liningFigures() : feature = 'lnum', value = 1;

  /// A zero with a slash (`zero`).
  const FontFeature.slashedZero() : feature = 'zero', value = 1;

  /// The four-letter OpenType tag.
  final String feature;

  /// Its value (0 off, 1 on, or an alternate's index).
  final int value;

  /// The `font-feature-settings` entry: `"tnum" 1`.
  String get css =>
      '"${feature.replaceAll(RegExp('[^A-Za-z0-9]'), '')}" $value';

  @override
  bool operator ==(Object other) =>
      other is FontFeature && other.feature == feature && other.value == value;

  @override
  int get hashCode => Object.hash(feature, value);
}

/// Flutter's `FontVariation`: a value on one axis of a variable font
/// (`font-variation-settings`), such as the optical size of an icon font.
///
/// ```dart
/// TextStyle(fontVariations: [FontVariation('FILL', 1), FontVariation.opticalSize(24)])
/// ```
class FontVariation {
  /// Axis [axis] (a four-letter tag) set to [value].
  const FontVariation(this.axis, this.value)
    : assert(axis.length == 4, 'a font axis is a four-letter tag');

  /// Italic or not (`ital`): 0 upright, 1 italic.
  const FontVariation.italic(this.value) : axis = 'ital';

  /// The size the glyphs are drawn for (`opsz`), in points.
  const FontVariation.opticalSize(this.value) : axis = 'opsz';

  /// The slant of the glyphs (`slnt`), in degrees counterclockwise.
  const FontVariation.slant(this.value) : axis = 'slnt';

  /// The width of the glyphs (`wdth`), in percent of the normal width.
  const FontVariation.width(this.value) : axis = 'wdth';

  /// The weight of the glyphs (`wght`), from 1 to 1000.
  const FontVariation.weight(this.value) : axis = 'wght';

  /// The four-letter axis tag.
  final String axis;

  /// The value on the axis.
  final double value;

  /// The variation between [a] and [b] at [t]; they must be on the same
  /// axis. Null when both are.
  static FontVariation? lerp(FontVariation? a, FontVariation? b, double t) {
    if (a == null || b == null) return t < 0.5 ? a : b;
    assert(a.axis == b.axis, 'lerp between two different font axes');
    return FontVariation(a.axis, a.value + (b.value - a.value) * t);
  }

  /// The `font-variation-settings` entry: `"opsz" 24`.
  String get css =>
      '"${axis.replaceAll(RegExp('[^A-Za-z0-9]'), '')}" ${cssNum(value)}';

  @override
  bool operator ==(Object other) =>
      other is FontVariation && other.axis == axis && other.value == value;

  @override
  int get hashCode => Object.hash(axis, value);

  @override
  String toString() => "FontVariation('$axis', $value)";
}

/// Flutter's `TextStyle`. All fields are optional and inherit through the
/// DOM exactly like Flutter's `DefaultTextStyle` does, because CSS font
/// properties are inherited.
class TextStyle with Adaptable<TextStyle> {
  /// Creates a text style. Every field is optional and unset fields
  /// inherit through the DOM.
  const TextStyle({
    this.color,
    this.backgroundColor,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.letterSpacing,
    this.wordSpacing,
    this.height,
    this.fontFamily,
    this.fontFamilyFallback,
    this.decoration,
    this.decorationColor,
    this.decorationStyle,
    this.decorationThickness,
    this.shadows,
    this.fontFeatures,
    this.fontVariations,
    this.role,
    this.themeDefaults,
    this.fontSizeLength,
    this.letterSpacingLength,
    this.heightLength,
  });

  @override
  TextStyle withVariants(Adaptive<TextStyle> variants) =>
      _AdaptiveTextStyle(variants);

  // web: not in Flutter.
  /// The `TextTheme` role this style comes from
  /// ([TextThemeRole.headlineLarge]). Its size, line height, weight and
  /// letter spacing are then read from the theme's CSS variables
  /// (`var(--t-headline-large-size, 32px)`), so a role can change per
  /// breakpoint or theme; the field values are the fallbacks. A field set to
  /// something else (`copyWith(letterSpacing: 0.9)`) is emitted as is, and
  /// the other three still follow the role.
  final TextThemeRole? role;

  // The role's name for the CSS variables.
  String? get _roleName => role?.cssName;

  /// The role's own values (set by `TextTheme`): a field equal to its
  /// default follows the theme variable, a different one overrides it.
  final TextStyle? themeDefaults;

  /// Text color.
  final Color? color;

  /// Background color painted behind the text.
  final Color? backgroundColor;

  /// Font size, in logical pixels.
  final double? fontSize;

  // web: not in Flutter.
  /// The font size as a CSS [Length], for what a number can't
  /// say: a size that follows the window within limits
  /// (`Length.clamp(Length.px(40), Length.vw(4.5) + Length.rem(1),
  /// Length.px(72))`) or one relative to the page (`1.25.rem`). It wins over
  /// [fontSize] in the CSS; keep [fontSize] as the number Dart code reads.
  final Length? fontSizeLength;

  /// Weight of the glyphs.
  final FontWeight? fontWeight;

  /// Upright or italic glyphs.
  final FontStyle? fontStyle;

  /// Extra horizontal space between characters, in logical pixels.
  final double? letterSpacing;

  // web: not in Flutter.
  /// The letter spacing as a CSS [Length], usually relative to
  /// the font size (`Length.em(-0.02)`): one value that stays right at
  /// every size, where [letterSpacing] would need one per size. It wins
  /// over [letterSpacing] in the CSS.
  final Length? letterSpacingLength;

  /// The `font-size` value: [fontSizeLength], else [fontSize] in pixels.
  String? get cssFontSize =>
      fontSizeLength?.css ?? (fontSize == null ? null : cssPx(fontSize!));

  /// The `letter-spacing` value: [letterSpacingLength], else
  /// [letterSpacing] in pixels.
  String? get cssLetterSpacing =>
      letterSpacingLength?.css ??
      (letterSpacing == null ? null : cssPx(letterSpacing!));

  /// Extra horizontal space between words, in logical pixels.
  final double? wordSpacing;

  /// Line height as a multiple of [fontSize] (unitless in CSS), like Flutter.
  final double? height;

  // web: not in Flutter.
  /// The line height as a CSS [Length]: a fixed one (`20.px`, a line
  /// that must land on the pixel) or one relative to the font (`1.75.em`).
  /// It wins over [height] in the CSS; keep [height] as the number Dart
  /// code reads.
  ///
  /// `// web:` the browser lays a unitless `line-height` (what [height]
  /// writes) out up to 1/64 px off the same value in `em` or `px` (Chrome's
  /// layout unit rounds the computed factor), which adds up over a code
  /// block or a long list: the length is the exact line box.
  final Length? heightLength;

  /// The `line-height` value: [heightLength], else [height] unitless.
  String? get cssLineHeight =>
      heightLength?.css ?? (height == null ? null : cssNum(height!));

  /// Primary font family name.
  final String? fontFamily;

  /// Font families tried, in order, if [fontFamily] is unavailable.
  final List<String>? fontFamilyFallback;

  /// Underline, overline and/or line-through decoration.
  final TextDecoration? decoration;

  /// Color of [decoration]'s line, if different from [color].
  final Color? decorationColor;

  /// Line style of [decoration] (solid, dashed, wavy, …).
  final TextDecorationStyle? decorationStyle;

  /// Thickness of [decoration]'s line, in logical pixels.
  final double? decorationThickness;

  /// Shadows painted behind the text.
  final List<Shadow>? shadows;

  /// OpenType features of the font (`font-feature-settings`), like tabular
  /// figures.
  final List<FontFeature>? fontFeatures;

  /// Values on the axes of a variable font (`font-variation-settings`),
  /// like the optical size of an icon font.
  final List<FontVariation>? fontVariations;

  /// Returns a copy with the given fields replaced (on every variant too,
  /// when built with `.when()`).
  TextStyle copyWith({
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    double? height,
    String? fontFamily,
    List<String>? fontFamilyFallback,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    List<FontVariation>? fontVariations,
    Length? fontSizeLength,
    Length? letterSpacingLength,
    Length? heightLength,
  }) => _each(
    (t) => TextStyle(
      role: t.role,
      themeDefaults: t.themeDefaults,
      color: color ?? t.color,
      backgroundColor: backgroundColor ?? t.backgroundColor,
      fontSize: fontSize ?? t.fontSize,
      fontWeight: fontWeight ?? t.fontWeight,
      fontStyle: fontStyle ?? t.fontStyle,
      letterSpacing: letterSpacing ?? t.letterSpacing,
      wordSpacing: wordSpacing ?? t.wordSpacing,
      height: height ?? t.height,
      fontFamily: fontFamily ?? t.fontFamily,
      fontFamilyFallback: fontFamilyFallback ?? t.fontFamilyFallback,
      decoration: decoration ?? t.decoration,
      decorationColor: decorationColor ?? t.decorationColor,
      decorationStyle: decorationStyle ?? t.decorationStyle,
      decorationThickness: decorationThickness ?? t.decorationThickness,
      shadows: shadows ?? t.shadows,
      fontFeatures: fontFeatures ?? t.fontFeatures,
      fontVariations: fontVariations ?? t.fontVariations,
      // A new number replaces a Length too: `copyWith(fontSize: 20)` must
      // show 20px, not the old `clamp()`.
      fontSizeLength:
          fontSizeLength ?? (fontSize != null ? null : t.fontSizeLength),
      letterSpacingLength:
          letterSpacingLength ??
          (letterSpacing != null ? null : t.letterSpacingLength),
      heightLength: heightLength ?? (height != null ? null : t.heightLength),
    ),
  );

  /// The same style as the `TextTheme` role [role] (see [TextStyle.role]).
  TextStyle withRole(TextThemeRole role) => _each(
    (t) => TextStyle(
      color: t.color,
      backgroundColor: t.backgroundColor,
      fontSize: t.fontSize,
      fontWeight: t.fontWeight,
      fontStyle: t.fontStyle,
      letterSpacing: t.letterSpacing,
      wordSpacing: t.wordSpacing,
      height: t.height,
      fontFamily: t.fontFamily,
      fontFamilyFallback: t.fontFamilyFallback,
      decoration: t.decoration,
      decorationColor: t.decorationColor,
      decorationStyle: t.decorationStyle,
      decorationThickness: t.decorationThickness,
      shadows: t.shadows,
      fontFeatures: t.fontFeatures,
      fontVariations: t.fontVariations,
      fontSizeLength: t.fontSizeLength,
      letterSpacingLength: t.letterSpacingLength,
      heightLength: t.heightLength,
      role: role,
      themeDefaults: TextStyle(
        fontSize: t.fontSize,
        fontWeight: t.fontWeight,
        letterSpacing: t.letterSpacing,
        height: t.height,
        fontSizeLength: t.fontSizeLength,
        letterSpacingLength: t.letterSpacingLength,
        heightLength: t.heightLength,
      ),
    ),
  );

  /// Returns a style where non-null fields of [other] win (variants of
  /// either included).
  TextStyle merge(TextStyle? other) {
    if (other == null) return this;
    return _with(other, (a, b) => a._mergePlain(b));
  }

  TextStyle _mergePlain(TextStyle other) {
    if (other._roleName != null) {
      // A themed style keeps its role; this style's other fields fill gaps.
      return TextStyle(
        color: other.color ?? color,
        backgroundColor: other.backgroundColor ?? backgroundColor,
        fontSize: other.fontSize,
        fontWeight: other.fontWeight,
        fontStyle: other.fontStyle ?? fontStyle,
        letterSpacing: other.letterSpacing,
        wordSpacing: other.wordSpacing ?? wordSpacing,
        height: other.height,
        fontFamily: other.fontFamily ?? fontFamily,
        fontFamilyFallback: other.fontFamilyFallback ?? fontFamilyFallback,
        decoration: other.decoration ?? decoration,
        decorationColor: other.decorationColor ?? decorationColor,
        decorationStyle: other.decorationStyle ?? decorationStyle,
        decorationThickness: other.decorationThickness ?? decorationThickness,
        shadows: other.shadows ?? shadows,
        fontFeatures: other.fontFeatures ?? fontFeatures,
        fontVariations: other.fontVariations ?? fontVariations,
        role: other.role,
        themeDefaults: other.themeDefaults,
        fontSizeLength: other.fontSizeLength,
        letterSpacingLength: other.letterSpacingLength,
        heightLength: other.heightLength,
      );
    }
    return copyWith(
      color: other.color,
      backgroundColor: other.backgroundColor,
      fontSize: other.fontSize,
      fontWeight: other.fontWeight,
      fontStyle: other.fontStyle,
      letterSpacing: other.letterSpacing,
      wordSpacing: other.wordSpacing,
      height: other.height,
      fontFamily: other.fontFamily,
      fontFamilyFallback: other.fontFamilyFallback,
      decoration: other.decoration,
      decorationColor: other.decorationColor,
      decorationStyle: other.decorationStyle,
      decorationThickness: other.decorationThickness,
      shadows: other.shadows,
      fontFeatures: other.fontFeatures,
      fontVariations: other.fontVariations,
      fontSizeLength: other.fontSizeLength,
      letterSpacingLength: other.letterSpacingLength,
      heightLength: other.heightLength,
    );
  }

  // Like Flutter's: by value (every field, the web-only ones too). A style
  // built with `.when()` equals another with the same base and variants
  // (`_AdaptiveTextStyle`), never a plain one.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other.runtimeType == runtimeType &&
          other is TextStyle &&
          other.color == color &&
          other.backgroundColor == backgroundColor &&
          other.fontSize == fontSize &&
          other.fontWeight == fontWeight &&
          other.fontStyle == fontStyle &&
          other.letterSpacing == letterSpacing &&
          other.wordSpacing == wordSpacing &&
          other.height == height &&
          other.fontFamily == fontFamily &&
          listsEqual(other.fontFamilyFallback, fontFamilyFallback) &&
          other.decoration == decoration &&
          other.decorationColor == decorationColor &&
          other.decorationStyle == decorationStyle &&
          other.decorationThickness == decorationThickness &&
          listsEqual(other.shadows, shadows) &&
          listsEqual(other.fontFeatures, fontFeatures) &&
          listsEqual(other.fontVariations, fontVariations) &&
          other.role == role &&
          other.themeDefaults == themeDefaults &&
          other.fontSizeLength == fontSizeLength &&
          other.letterSpacingLength == letterSpacingLength &&
          other.heightLength == heightLength;

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    color,
    backgroundColor,
    fontSize,
    fontWeight,
    fontStyle,
    letterSpacing,
    wordSpacing,
    height,
    fontFamily,
    hashList(fontFamilyFallback),
    decoration,
    decorationColor,
    decorationStyle,
    decorationThickness,
    hashList(shadows),
    hashList(fontFeatures),
    hashList(fontVariations),
    role,
    themeDefaults,
    fontSizeLength,
    letterSpacingLength,
    heightLength,
  ]);

  // The operations above work on plain styles; on one built with `.when()`
  // they map over the base and every variant, so the variants are kept.
  TextStyle _each(TextStyle Function(TextStyle plain) f) => f(this);

  TextStyle _with(TextStyle o, TextStyle Function(TextStyle a, TextStyle b) f) {
    final a = this;
    if (a is _AdaptiveTextStyle && o is _AdaptiveTextStyle) {
      return _AdaptiveTextStyle(
        a.adaptive.zip(o.adaptive, (x, y) => x._with(y, f)),
      );
    }
    if (a is _AdaptiveTextStyle) {
      return _AdaptiveTextStyle(a.adaptive.map((x) => x._with(o, f)));
    }
    if (o is _AdaptiveTextStyle) {
      return _AdaptiveTextStyle(o.adaptive.map((y) => _with(y, f)));
    }
    return f(a, o);
  }

  /// Memoized per instance (value types are mostly `const`); callers must
  /// not mutate the result.
  CssDeclarations toCss() => _cssCache[this] ??= _computeCss();

  CssDeclarations _computeCss() {
    final families = [?fontFamily, ...?fontFamilyFallback].map(
      (f) => f.contains(' ') && !f.startsWith('"') && !f.startsWith("'")
          ? '"$f"'
          : f,
    );
    // A role reads the theme's variable, with the field as the fallback.
    // Unset → the variable; equal to the role's value → the variable with
    // that value as fallback; anything else → an override, as is.
    final d = themeDefaults;
    String? themed(String key, Object? field, Object? byDefault, String? v) =>
        _roleName == null || (field != null && field != byDefault)
        ? v
        : 'var(--t-$_roleName-$key${v == null ? '' : ', $v'})';
    return {
      if (color != null) 'color': color!.css,
      if (backgroundColor != null) 'background-color': backgroundColor!.css,
      'font-size': ?themed(
        'size',
        fontSizeLength ?? fontSize,
        d?.fontSizeLength ?? d?.fontSize,
        cssFontSize,
      ),
      'font-weight': ?themed(
        'weight',
        fontWeight,
        d?.fontWeight,
        fontWeight == null ? null : '${fontWeight!.value}',
      ),
      if (fontStyle != null) 'font-style': fontStyle!.name,
      'letter-spacing': ?themed(
        'tracking',
        letterSpacingLength ?? letterSpacing,
        d?.letterSpacingLength ?? d?.letterSpacing,
        cssLetterSpacing,
      ),
      if (wordSpacing != null) 'word-spacing': cssPx(wordSpacing!),
      'line-height': ?themed(
        'line',
        heightLength ?? height,
        d?.heightLength ?? d?.height,
        cssLineHeight,
      ),
      if (families.isNotEmpty) 'font-family': families.join(', '),
      if (decoration != null) 'text-decoration-line': decoration!.css,
      if (decorationColor != null)
        'text-decoration-color': decorationColor!.css,
      if (decorationStyle != null)
        'text-decoration-style': decorationStyle!.name,
      if (decorationThickness != null)
        'text-decoration-thickness': cssPx(decorationThickness!),
      if (shadows != null && shadows!.isNotEmpty)
        'text-shadow': shadows!.map((s) => s.css).join(', '),
      if (fontFeatures != null && fontFeatures!.isNotEmpty)
        'font-feature-settings': fontFeatures!.map((f) => f.css).join(', '),
      if (fontVariations case final v? when v.isNotEmpty)
        'font-variation-settings': v.map((f) => f.css).join(', '),
    };
  }
}

/// The roles of Flutter's `TextTheme`: what a [TextStyle.role] names.
// web: not in Flutter: a Flutter style is its values; here the role also
// names the CSS variables (`--t-headline-large-size`…) the theme writes, so
// a role can change per breakpoint or theme.
enum TextThemeRole {
  /// `displayLarge`.
  displayLarge('display-large'),

  /// `displayMedium`.
  displayMedium('display-medium'),

  /// `displaySmall`.
  displaySmall('display-small'),

  /// `headlineLarge`.
  headlineLarge('headline-large'),

  /// `headlineMedium`.
  headlineMedium('headline-medium'),

  /// `headlineSmall`.
  headlineSmall('headline-small'),

  /// `titleLarge`.
  titleLarge('title-large'),

  /// `titleMedium`.
  titleMedium('title-medium'),

  /// `titleSmall`.
  titleSmall('title-small'),

  /// `bodyLarge`.
  bodyLarge('body-large'),

  /// `bodyMedium`.
  bodyMedium('body-medium'),

  /// `bodySmall`.
  bodySmall('body-small'),

  /// `labelLarge`.
  labelLarge('label-large'),

  /// `labelMedium`.
  labelMedium('label-medium'),

  /// `labelSmall`.
  labelSmall('label-small');

  const TextThemeRole(this.cssName);

  /// The role in the theme's CSS variables (`'headline-large'`).
  final String cssName;

  /// The role named [cssName], or null when it is none.
  static TextThemeRole? fromCssName(String? cssName) {
    for (final r in values) {
      if (r.cssName == cssName) return r;
    }
    return null;
  }
}

final _cssCache = Expando<CssDeclarations>('thor-css');

class _AdaptiveTextStyle extends TextStyle {
  _AdaptiveTextStyle(this.adaptive)
    : super(
        color: adaptive.base.color,
        backgroundColor: adaptive.base.backgroundColor,
        fontSize: adaptive.base.fontSize,
        fontWeight: adaptive.base.fontWeight,
        fontStyle: adaptive.base.fontStyle,
        letterSpacing: adaptive.base.letterSpacing,
        wordSpacing: adaptive.base.wordSpacing,
        height: adaptive.base.height,
        fontFamily: adaptive.base.fontFamily,
        fontFamilyFallback: adaptive.base.fontFamilyFallback,
        decoration: adaptive.base.decoration,
        decorationColor: adaptive.base.decorationColor,
        decorationStyle: adaptive.base.decorationStyle,
        decorationThickness: adaptive.base.decorationThickness,
        shadows: adaptive.base.shadows,
        fontFeatures: adaptive.base.fontFeatures,
        fontVariations: adaptive.base.fontVariations,
        role: adaptive.base.role,
        themeDefaults: adaptive.base.themeDefaults,
        fontSizeLength: adaptive.base.fontSizeLength,
        letterSpacingLength: adaptive.base.letterSpacingLength,
        heightLength: adaptive.base.heightLength,
      );

  final Adaptive<TextStyle> adaptive;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AdaptiveTextStyle && other.adaptive == adaptive;

  @override
  int get hashCode => adaptive.hashCode;

  @override
  TextStyle _each(TextStyle Function(TextStyle plain) f) =>
      _AdaptiveTextStyle(adaptive.map((t) => t._each(f)));

  @override
  CssDeclarations _computeCss() => adaptive.declarations((t) => t.toCss());
}
