import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../core/framework.dart' show buildingContext;
import '../engine/watch.dart' show engineAttributes;
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/parent_data.dart';

CssDeclarations _textCss({
  TextStyle? style,
  TextAlign? textAlign,
  bool softWrap = true,
  int? maxLines,
  TextOverflow? overflow,
  bool lineBreaks = false,
}) => {
  ...?style?.toCss(),
  if (textAlign != null) 'text-align': textAlign.css,
  // Flutter never wraps it, and still breaks at `\n` and keeps spaces.
  if (!softWrap)
    'white-space': 'pre'
  // A `\n` in the text is a line break in Flutter (HTML folds it into a
  // space).
  else if (lineBreaks && maxLines == null && overflow == null)
    'white-space': 'pre-wrap',
  if (maxLines != null && maxLines > 1 && _drawsEllipsis(overflow))
    '-webkit-line-clamp': '$maxLines',
  if (overflow == TextOverflow.clip && maxLines == null) 'overflow': 'hidden',
};

// Headings/paragraphs lose UA margins; long words wrap like in Flutter.
const _textBase = <String, String>{
  'margin': '0',
  'min-width': '0',
  'overflow-wrap': 'break-word',
};

// An unset `overflow` is `clip`, as in Flutter; only `ellipsis` draws dots.
bool _drawsEllipsis(TextOverflow? overflow) =>
    overflow == TextOverflow.ellipsis;

CssDeclarations _overflowCss(int? maxLines, TextOverflow? overflow) {
  if (maxLines != null &&
      (overflow == TextOverflow.clip || overflow == TextOverflow.fade)) {
    // No ellipsis and no line-clamp: the box is `maxLines` lines tall and
    // cuts there, keeping the browser's word wrapping.
    return {
      'overflow': 'hidden',
      if (maxLines == 1) ...const {
        'white-space': 'nowrap',
        'max-width': '100%',
      },
      if (maxLines > 1) ...{
        'display': 'block',
        'max-height': 'calc($maxLines * 1lh)',
      },
      if (overflow == TextOverflow.fade)
        'mask-image': maxLines == 1
            ? 'linear-gradient(to right, #000 calc(100% - 1.5em), transparent)'
            // web: the fade of a multi-line text is its last line in
            // Flutter; here the bottom line fades out.
            : 'linear-gradient(to bottom, #000 calc(100% - 1lh), transparent)',
    };
  }
  if (overflow == TextOverflow.visible) {
    return maxLines == 1 ? const {'white-space': 'nowrap'} : const {};
  }
  return (maxLines == 1 ||
          (overflow == TextOverflow.ellipsis && maxLines == null))
      ? const {
          'overflow': 'hidden',
          'text-overflow': 'ellipsis',
          'white-space': 'nowrap',
          // Flutter caps a child at its parent's width: a start-aligned flex
          // item is fit-content, which with `nowrap` is the whole line.
          'max-width': '100%',
        }
      : (maxLines != null && maxLines > 1)
      ? const {
          'display': '-webkit-box',
          '-webkit-box-orient': 'vertical',
          'overflow': 'hidden',
        }
      : const {};
}

/// Whether any text of [span] and its children has a `\n`.
bool _hasLineBreak(InlineSpan? span) =>
    span is TextSpan &&
    ((span.text?.contains('\n') ?? false) ||
        (span.children?.any(_hasLineBreak) ?? false));

/// Flutter's `Text`.
///
/// A heading is `Semantics(headingLevel: n, child: Text(…))`, which renders
/// a real `<h1>`…`<h6>`, as Flutter's semantics do.
class Text extends StatelessWidget implements ThorElementWidget, ThorBuiltIn {
  /// Creates a text widget from a plain string.
  const Text(
    String this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.softWrap,
    this.overflow,
    this.maxLines,
    this.semanticsLabel,
  }) : textSpan = null;

  /// Creates a text widget from a tree of [InlineSpan]s.
  const Text.rich(
    InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.textAlign,
    this.softWrap,
    this.overflow,
    this.maxLines,
    this.semanticsLabel,
  }) : data = null;

  /// The text to display, or null when built with `Text.rich`.
  final String? data;

  /// The span tree to display, or null when built with the plain
  /// constructor.
  final InlineSpan? textSpan;

  /// The style to apply.
  final TextStyle? style;

  /// How to align the text horizontally.
  final TextAlign? textAlign;

  /// Whether the text breaks at soft line breaks. `false`: one line per
  /// `\n`, spaces kept (`white-space: pre`), as in Flutter. Null is `true`.
  /// Null reads `DefaultTextStyle.softWrap` (`true` without one).
  final bool? softWrap;

  /// How to visually handle text that overflows its box. Null reads
  /// `DefaultTextStyle.overflow`; without one it is [TextOverflow.clip]
  /// (no dots: ask for [TextOverflow.ellipsis] to draw them).
  final TextOverflow? overflow;

  /// The maximum number of lines before truncating
  /// (`-webkit-line-clamp`). Null reads `DefaultTextStyle.maxLines`.
  final int? maxLines;

  /// An alternative accessible label, overriding the raw text
  /// (`aria-label`).
  final String? semanticsLabel;

  /// Styles for rendering this text directly as the content of a box
  /// (`Container(child: Text('x'))` → one element, the text node being an
  /// anonymous flex item). `null` when it needs its own element: rich text,
  /// line limits / ellipsis (they need a block container), or semantics.
  /// A `DefaultTextStyle` line limit above (read through the context being
  /// built, the parent's) also needs one.
  CssDeclarations? get boxContentCss =>
      data == null ||
          maxLines != null ||
          overflow != null ||
          semanticsLabel != null ||
          key != null ||
          _limitedByDefaults()
      ? null
      : {
          // The anonymous item has no `min-width: 0`: `anywhere` lets long
          // words break instead of overflowing the box, like the span did.
          'overflow-wrap': 'anywhere',
          ..._textCss(
            style: style,
            textAlign: textAlign,
            softWrap: softWrap ?? true,
            lineBreaks: data!.contains('\n'),
          ),
        };

  @override
  Widget build(BuildContext context) {
    // Flutter: a null field reads the nearest `DefaultTextStyle`; an unset
    // `overflow` under a line limit is `clip`.
    final found = _defaultsOf(context);
    final defaults = found == null || _readsNoDefaults[this] == true
        ? null
        : found;
    final lines = maxLines ?? defaults?.maxLines;
    final over =
        overflow ??
        defaults?.overflow ??
        (lines != null ? TextOverflow.clip : null);
    return thorElement(
      'span',
      debugName: 'Text',
      baseCss: _textBase,
      css: _elementCss(
        style,
        textAlign,
        softWrap ?? defaults?.softWrap ?? true,
        lines,
        over,
        lineBreaks: data?.contains('\n') ?? _hasLineBreak(textSpan),
      ),
      attributes: semanticsLabel == null
          ? null
          : {'aria-label': semanticsLabel!},
      children: [
        if (data != null) Widget.text(data!) else textSpan!.toComponent(),
      ],
    );
  }

  /// A text element's declarations: a pure function of its style (by
  /// identity, like `TextStyle.toCss`) and a few values, built once per
  /// process for each combination (every Text of every page asks).
  static CssDeclarations _elementCss(
    TextStyle? style,
    TextAlign? textAlign,
    bool softWrap,
    int? maxLines,
    TextOverflow? overflow, {
    bool lineBreaks = false,
  }) {
    final key = (style, textAlign, softWrap, maxLines, overflow, lineBreaks);
    final known = _cssMemo[key];
    if (known != null) return known;
    // Bounded: styles made per build (not const) must not grow it forever.
    if (_cssMemo.length >= 1024) _cssMemo.clear();
    return _cssMemo[key] = Map.unmodifiable({
      ..._overflowCss(maxLines, overflow),
      ..._textCss(
        style: style,
        textAlign: textAlign,
        softWrap: softWrap,
        maxLines: maxLines,
        overflow: overflow,
        lineBreaks: lineBreaks,
      ),
    });
  }

  static final _cssMemo =
      <
        (TextStyle?, TextAlign?, bool, int?, TextOverflow?, bool),
        CssDeclarations
      >{};
}

/// Flutter's `InlineSpan`.
abstract class InlineSpan {
  /// Creates an inline span.
  const InlineSpan();

  /// Renders this span as a widget.
  Widget toComponent();
}

/// Flutter's `TextSpan`. [onTap] is a web convenience replacing
/// `recognizer: TapGestureRecognizer()..onTap`.
class TextSpan extends InlineSpan {
  /// Creates a run of text with its own style.
  const TextSpan({
    this.text,
    this.style,
    this.children,
    this.onTap,
    this.semanticsLabel,
    this.href,
    this.newTab = false,
  });

  /// The text to display.
  final String? text;

  /// The style to apply to `text`, inherited by `children`.
  final TextStyle? style;

  /// Additional spans to display after `text`.
  final List<InlineSpan>? children;

  /// Called when this span is tapped.
  final void Function()? onTap;

  /// An alternative accessible label for this span.
  final String? semanticsLabel;

  // web: not in Flutter.
  /// Makes the span a link (`<a href>`) that flows with the
  /// text, e.g. a link inside a sentence. (`WidgetSpan(child: Link(…))`
  /// is atomic, like any `WidgetSpan`: it wraps as one piece.)
  final String? href;

  /// With [href]: open in a new tab (`rel="noopener noreferrer"`).
  final bool newTab;

  @override
  Widget toComponent() {
    // A span with nothing of its own (no style, link, tap or label) is
    // just its text: no element (a highlighted code block's plain runs, the
    // root span of a Text.rich).
    final css = style?.toCss() ?? const {};
    if (css.isEmpty &&
        href == null &&
        onTap == null &&
        semanticsLabel == null) {
      return Widget.fragment([
        if (text case final text?) Widget.text(text),
        for (final c in children ?? const <InlineSpan>[]) c.toComponent(),
      ]);
    }
    return _element();
  }

  Widget _element() => thorElement(
    href == null ? 'span' : 'a',
    css: {
      if (href != null) ...{'color': 'inherit', 'text-decoration': 'none'},
      ...?style?.toCss(),
      if (onTap != null) 'cursor': 'pointer',
    },
    attributes: {
      'href': ?href,
      if (href != null && newTab) ...{
        'target': '_blank',
        'rel': 'noopener noreferrer',
      },
      'aria-label': ?semanticsLabel,
      // web: a tap on a span is a button for the keyboard and the reader
      // (an `<a href>` already is one).
      if (onTap != null) ...{
        if (href == null) ...{'role': 'button', 'tabindex': '0'},
        ...engineAttributes({'click': onTap}),
      },
    },
    children: [
      if (text case final text?) Widget.text(text),
      for (final c in children ?? const <InlineSpan>[]) c.toComponent(),
    ],
  );
}

/// Flutter's `WidgetSpan`: embeds any component inline.
class WidgetSpan extends InlineSpan {
  /// Creates an inline span that embeds [child].
  const WidgetSpan({required this.child});

  /// The widget to embed inline.
  final Widget child;

  @override
  Widget toComponent() => thorElement(
    'span',
    css: const {'display': 'inline-block', 'vertical-align': 'middle'},
    children: [child],
  );
}

_TextDefaults? _defaultsOf(BuildContext? context) =>
    context?.getElementForInheritedWidgetOfExactType<_TextDefaults>()?.widget
        as _TextDefaults?;

// Whether a `DefaultTextStyle` above the widget being built gives its
// `Text` children something a box's anonymous text can't hold.
bool _limitedByDefaults() {
  final d = _defaultsOf(buildingContext());
  return d != null &&
      (d.maxLines != null || d.overflow != null || d.softWrap != null);
}

/// [text] (what a `RichText` or `SelectableText` builds) without the
/// `maxLines`, `overflow` and `softWrap` of a `DefaultTextStyle` above:
/// Flutter's `RichText` and `SelectableText` don't read them. No node: the
/// tree is the same.
@internal
Text withoutTextDefaults(Text text) {
  _readsNoDefaults[text] = true;
  return text;
}

final _readsNoDefaults = Expando<bool>();

/// What a [DefaultTextStyle] with `maxLines`, `overflow` or `softWrap`
/// publishes to the `Text` widgets below it. It exists only when one is
/// used: a page without them renders as before.
class _TextDefaults extends InheritedWidget {
  const _TextDefaults({
    required this.maxLines,
    required this.overflow,
    required this.softWrap,
    required super.child,
  });

  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}

/// Flutter's `DefaultTextStyle`.
///
/// No extra node: the style is applied to the child element and descendants
/// inherit it through the CSS cascade.
// web: [maxLines], [overflow] and [softWrap] cannot ride the cascade
// (`display: -webkit-box`, `text-overflow` and `-webkit-line-clamp` are not
// inherited and a custom property cannot switch `display`), so a
// `DefaultTextStyle` that sets one publishes it to the `Text` widgets below,
// which compile the same class as if they had been given the values.
class DefaultTextStyle extends ParentDataWrapper {
  /// Creates a widget that establishes a default text style for its
  /// descendants.
  const DefaultTextStyle({
    super.key,
    required this.style,
    this.textAlign,
    this.softWrap,
    this.overflow,
    this.maxLines,
    required super.child,
  }) : _merge = false;

  /// Flutter's `DefaultTextStyle.merge`: a default that is added to the
  /// ones above it.
  // web: the CSS cascade already merges the style, so this is the same
  // wrapper with an optional style (what is left out is inherited as it
  // is); the line limits left out are the ones above.
  const DefaultTextStyle.merge({
    super.key,
    TextStyle? style,
    this.textAlign,
    this.softWrap,
    this.overflow,
    this.maxLines,
    required super.child,
  }) : style = style ?? const TextStyle(),
       _merge = true;

  /// The default style, inherited by descendant `Text` widgets.
  final TextStyle style;

  /// The default text alignment.
  final TextAlign? textAlign;

  /// Default for `Text.softWrap`.
  final bool? softWrap;

  /// Default for `Text.overflow`.
  final TextOverflow? overflow;

  /// Default for `Text.maxLines`.
  final int? maxLines;

  final bool _merge;

  @override
  WrapData get wrapData => WrapData(
    css: {
      ...style.toCss(),
      if (textAlign != null) 'text-align': textAlign!.css,
      if (softWrap != null) 'white-space': softWrap! ? 'pre-wrap' : 'pre',
    },
  );

  @override
  bool get opensScope =>
      maxLines != null || overflow != null || softWrap != null;

  @override
  Widget scoped(BuildContext context, Widget built) {
    if (!opensScope) return built;
    final above = _merge ? _defaultsOf(context) : null;
    return _TextDefaults(
      maxLines: maxLines ?? above?.maxLines,
      overflow: overflow ?? above?.overflow,
      softWrap: softWrap ?? above?.softWrap,
      child: built,
    );
  }
}
