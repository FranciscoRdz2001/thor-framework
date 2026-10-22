import 'package:thor_engine/sanitize.dart';
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/responsive.dart' show StyleProps;
import '../foundation/style_registry.dart';
import 'theme.dart';

const _primary = Color.variable(
  CssVariable('--t-primary'),
  fallback: Color(0xFF6750A4),
);
const _outline = Color.variable(
  CssVariable('--t-outline-variant'),
  fallback: Color(0xFFCAC4D0),
);

/// HTML you do not control (a catalog description, a CMS body, a comment)
/// as safe markup, styled with the theme.
///
/// The [html] goes through [sanitizeHtml] with the [policy] on the server
/// (the page never carries a script, an event handler or a `javascript:`
/// URL from it), then is written as the children of one `<div>`. Paragraphs,
/// headings, lists, links, images and tables get the theme's typography and
/// colors through descendant rules in the page's stylesheet: no inline
/// styles, and nothing nested widgets (a `Card` inside the content) can
/// inherit by accident.
///
/// ```dart
/// HtmlWidget(product.description)
/// HtmlWidget(comment.body, policy: HtmlPolicy(linkTarget: '_blank', nofollow: true))
/// HtmlWidget(post.body, policy: HtmlPolicy(eagerImages: 1)) // a cover image on top
/// ```
///
/// A block container does not fit where only text is allowed (a `<p>`,
/// a `<button>`): the parser closes the `<p>` at the first `<div>` inside
/// it. [inline] `true` writes a `<span>` and keeps only the text-level tags
/// of the policy ([HtmlPolicy.inlineTags]: `strong`, `em`, `a`, `br`…); the
/// block ones are unwrapped and their text stays.
///
/// ```dart
/// Text.rich(...)
/// HtmlWidget(product.description, inline: true) // inside a paragraph
/// ```
///
/// Images load lazily (`loading="lazy"`) except the first
/// [HtmlPolicy.eagerImages].
///
/// web: named after `flutter_widget_from_html`'s `HtmlWidget(html)` (the
/// most used package of the two; `flutter_html`'s `Html(data:)` would also
/// collide with `package:thor_ui/html.dart`, the raw elements). Unlike
/// both, nothing is parsed or laid out in Dart at runtime: the browser
/// draws the HTML, and `onLinkTap`/`customWidgetBuilder` have no
/// equivalent (links are `<a href>`).
class HtmlWidget extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Shows [html] sanitized with [policy].
  const HtmlWidget(
    this.html, {
    super.key,
    this.policy = const HtmlPolicy(),
    this.inline = false,
  });

  /// Whether the content is text-level only: a `<span>` with the policy's
  /// phrasing tags, safe inside a `<p>` or a `<button>`. `// web:` no
  /// Flutter counterpart (a Flutter widget can always be a block).
  final bool inline;

  /// The HTML, untrusted.
  final String html;

  /// What is allowed through (tags, attributes, schemes, link target).
  final HtmlPolicy policy;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const heading = EdgeInsets.only(top: 16, bottom: 8);
    const block = EdgeInsets.symmetric(vertical: 8);
    final allowed = inline
        ? policy.copyWith(tags: policy.tags.intersection(HtmlPolicy.inlineTags))
        : policy;
    return thorElement(
      inline ? 'span' : 'div',
      debugName: 'HtmlWidget',
      css: const {'overflow-wrap': 'break-word'},
      conditions: [
        for (final MapEntry(key: selector, value: props) in {
          if (!inline) ...{
            'p, ul, ol, dl, figure, blockquote, pre, table': const StyleProps(
              margin: block,
            ),
            'h2': StyleProps(textStyle: text.titleLarge, margin: heading),
            'h3': StyleProps(textStyle: text.titleMedium, margin: heading),
            'h4, h5, h6': StyleProps(
              textStyle: text.titleSmall,
              margin: heading,
            ),
            'ul, ol, dd': const StyleProps(padding: EdgeInsets.only(left: 24)),
          },
          'a': const StyleProps(
            textStyle: TextStyle(
              color: _primary,
              decoration: TextDecoration.underline,
            ),
          ),
          'img': StyleProps(maxWidth: 100.percent),
          if (!inline) ...{
            'blockquote': const StyleProps(
              padding: EdgeInsets.only(left: 16),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: _outline, width: 3)),
              ),
            ),
            'pre': const StyleProps(overflowX: Overflow.auto),
            'th, td': const StyleProps(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.fromBorderSide(BorderSide(color: _outline)),
              ),
            ),
            'table': const StyleProps(raw: {'border-collapse': 'collapse'}),
          },
        }.entries)
          ConditionalCss(CssCondition.descendant(selector), props.toCss()),
      ],
      children: [RawText(sanitizeHtml(html, policy: allowed))],
    );
  }
}
