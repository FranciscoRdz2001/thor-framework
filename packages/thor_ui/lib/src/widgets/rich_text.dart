import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../foundation/parent_data.dart';
import 'text.dart';

/// Flutter's `RichText`: a tree of [InlineSpan]s.
///
/// ```dart
/// RichText(
///   text: TextSpan(
///     text: 'Hello ',
///     children: [TextSpan(text: 'bold', style: TextStyle(fontWeight: FontWeight.bold))],
///   ),
/// )
/// ```
///
/// web: the same as `Text.rich` (which Flutter recommends over `RichText`
/// for the default text style, and which the web has no other use for): one
/// element, wrappers fuse into it. There is no `DefaultTextStyle` lookup;
/// the [text]'s own style, or a `DefaultTextStyle` above (CSS inheritance),
/// decides.
class RichText extends StatelessWidget {
  /// Creates a paragraph of styled spans.
  const RichText({
    super.key,
    required this.text,
    this.textAlign,
    this.softWrap = true,
    this.overflow,
    this.maxLines,
  });

  /// The spans to display.
  final InlineSpan text;

  /// How the text aligns horizontally.
  final TextAlign? textAlign;

  /// Whether the text breaks at soft line breaks (see `Text.softWrap`).
  final bool softWrap;

  /// How overflowing text is shown (with [maxLines]).
  final TextOverflow? overflow;

  /// The most lines the text takes.
  final int? maxLines;

  // Flutter's `RichText` reads no `DefaultTextStyle`.
  @override
  Widget build(BuildContext context) => withoutTextDefaults(
    Text.rich(
      text,
      textAlign: textAlign,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
    ),
  );
}

/// Flutter's `SelectableText`: text the person can select and copy.
///
/// web: the browser selects any text, so this is a [Text] that says so: it
/// stays selectable (`user-select: text`) inside a card, button or `Gesture`
/// that turns selection off, and its pointer is the text cursor. Flutter's
/// cursor, toolbar and `onSelectionChanged` are the browser's own.
class SelectableText extends StatelessWidget {
  /// Creates selectable text from a plain string.
  const SelectableText(
    String this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.semanticsLabel,
  }) : textSpan = null;

  /// Creates selectable text from a tree of [InlineSpan]s.
  const SelectableText.rich(
    InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.semanticsLabel,
  }) : data = null;

  /// The text, or null with [SelectableText.rich].
  final String? data;

  /// The spans, or null with the plain constructor.
  final InlineSpan? textSpan;

  /// The style of the text.
  final TextStyle? style;

  /// How the text aligns horizontally.
  final TextAlign? textAlign;

  /// The most lines the text takes.
  final int? maxLines;

  /// An accessible label instead of the text.
  final String? semanticsLabel;

  // Flutter's `SelectableText` has no `overflow` and reads no
  // `DefaultTextStyle` line limits.
  @override
  Widget build(BuildContext context) => WrapWith(
    const WrapData(
      css: {
        'user-select': 'text',
        '-webkit-user-select': 'text',
        'cursor': 'text',
      },
    ),
    child: withoutTextDefaults(
      data != null
          ? Text(
              data!,
              style: style,
              textAlign: textAlign,
              maxLines: maxLines,
              semanticsLabel: semanticsLabel,
            )
          : Text.rich(
              textSpan!,
              style: style,
              textAlign: textAlign,
              maxLines: maxLines,
              semanticsLabel: semanticsLabel,
            ),
    ),
  );
}
