import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/style_registry.dart';
import '../foundation/theme_tokens.dart';
import 'text.dart';

/// Text cut at [maxLines] lines with a button that shows the rest, and
/// another that cuts it again: the "read more" of a description or a review.
///
/// ```dart
/// ExpandableText(
///   description,
///   maxLines: 3,
///   moreLabel: 'Read more',
///   lessLabel: 'Show less',
/// )
/// ```
///
/// `// web:` no Flutter counterpart. It works without JavaScript: the button
/// is a `<label>` of a visually hidden checkbox, and the rule that lifts the
/// cut is `:has(:checked)`, so it is right on the first paint and keyboard
/// reachable (the checkbox takes the focus). The server cannot know whether
/// the text fills [maxLines], so the button is always there: give it text
/// long enough to need it (or show a plain `Text` for short ones).
class ExpandableText extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Shows [text] cut at [maxLines] lines until the visitor expands it.
  const ExpandableText(
    this.text, {
    super.key,
    this.maxLines = 3,
    required this.moreLabel,
    required this.lessLabel,
    this.style,
    this.toggleStyle,
  }) : assert(maxLines > 0, 'maxLines is at least 1');

  /// The text.
  final String text;

  /// How many lines show while it is cut.
  final int maxLines;

  /// The button while the text is cut ("Read more").
  final String moreLabel;

  /// The button while the text is whole ("Show less").
  final String lessLabel;

  /// The text's style.
  final TextStyle? style;

  /// The buttons' style (default: bold in the theme's primary color).
  final TextStyle? toggleStyle;

  @override
  Widget build(BuildContext context) => thorElement(
    'div',
    debugName: 'ExpandableText',
    css: const {
      'display': 'flex',
      'flex-direction': 'column',
      'align-items': 'flex-start',
      'gap': '4px',
      'min-width': '0',
    },
    conditions: const [
      // The cut text is the first child.
      ConditionalCss(
        CssCondition.selector(':has(> label > input:checked) > :first-child'),
        {
          'display': 'block',
          '-webkit-line-clamp': 'unset',
          'line-clamp': 'unset',
          'overflow': 'visible',
        },
      ),
      ConditionalCss(
        CssCondition.selector(
          ':not(:has(> label > input:checked)) > label > [data-less]',
        ),
        {'display': 'none'},
      ),
      ConditionalCss(
        CssCondition.selector(
          ':has(> label > input:checked) > label > [data-more]',
        ),
        {'display': 'none'},
      ),
      ConditionalCss(
        CssCondition.selector(':has(> label > input:focus-visible) > label'),
        {
          'outline': '2px solid ${ThemeTokens.primary}',
          'outline-offset': '2px',
        },
      ),
    ],
    children: [
      Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
      thorElement(
        'label',
        debugName: 'ExpandableTextToggle',
        css: {
          'position': 'relative',
          'cursor': 'pointer',
          'border-radius': '4px',
          'font-weight': '600',
          'color': ThemeTokens.primary,
          ...?toggleStyle?.toCss(),
        },
        children: [
          // A native checkbox the label toggles; hidden to the eye, not to
          // the keyboard or a screen reader (its name is the label's text).
          thorElement(
            'input',
            debugName: 'ExpandableTextCheckbox',
            attributes: const {'type': 'checkbox'},
            css: const {
              'position': 'absolute',
              'inset': '0',
              'width': '100%',
              'height': '100%',
              'margin': '0',
              'opacity': '0',
              'cursor': 'pointer',
            },
          ),
          thorElement(
            'span',
            debugName: 'ExpandableTextMore',
            attributes: const {'data-more': ''},
            children: [Text(moreLabel)],
          ),
          thorElement(
            'span',
            debugName: 'ExpandableTextLess',
            attributes: const {'data-less': ''},
            children: [Text(lessLabel)],
          ),
        ],
      ),
    ],
  );
}
