import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../foundation/element.dart';
import '../foundation/style_registry.dart';

/// A number the browser computes, written as text: a [Ratio] (the scale of a
/// canvas, a share of its container) times [scale], as whole digits, then
/// [suffix].
///
/// ```dart
/// // 66% when the canvas is at two thirds of its design width.
/// RatioText(Ratio.of(100.cqw, 1200.px))
/// ```
///
/// web: no Flutter counterpart (Flutter reads a size in Dart; here the
/// browser lays out, so only it knows the number). The text is a CSS counter
/// (`counter-reset` takes the `calc()`, a `::before` prints it): the same
/// [Ratio] that drives `scale` or a length writes the label, with no second
/// computation and no text per value. The digits are the counter's, so they
/// are whole numbers (the value is rounded) and not selectable; give
/// [semanticsLabel] for a reader that skips generated content.
class RatioText extends StatelessWidget {
  /// The [ratio] times [scale] (`100`: a percentage), then [suffix].
  const RatioText(
    this.ratio, {
    super.key,
    this.scale = 100,
    this.suffix = '%',
    this.style,
    this.semanticsLabel,
  });

  /// The number the browser computes.
  final Ratio ratio;

  /// What the ratio is multiplied by before it is rounded to whole digits.
  final double scale;

  /// Text after the digits.
  final String suffix;

  /// The text style.
  final TextStyle? style;

  /// An accessible label for the element (`aria-label`).
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => thorElement(
    'span',
    debugName: 'RatioText',
    css: {
      'counter-reset': 'thor-ratio calc(${ratio.css} * ${cssNum(scale)})',
      ...?style?.toCss(),
    },
    conditions: [
      ConditionalCss(const CssCondition.selector('::before'), {
        'content': 'counter(thor-ratio) ${_quoted(suffix)}',
      }),
    ],
    attributes: semanticsLabel == null
        ? null
        : {'role': 'img', 'aria-label': semanticsLabel!},
  );

  /// [text] as a CSS string.
  static String _quoted(String text) =>
      '"${text.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\a ')}"';
}
