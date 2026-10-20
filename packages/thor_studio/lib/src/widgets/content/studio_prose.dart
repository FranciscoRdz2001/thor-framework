import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/thor_ui.dart';
import 'package:thor_ui/web.dart' show Display, WhiteSpace;

import '../../l10n/studio_localizations.dart';

import '../../theme/component_themes/studio_code_theme.dart';
import '../../theme/studio_extra_colors.dart';
import '../../theme/studio_extra_text_styles.dart';
import '../../tokens/color/studio_surface_colors.dart';
import '../../tokens/color/studio_syntax_colors.dart';
import '../../tokens/shape/studio_radii.dart';
import '../../tokens/typography/studio_line_heights.dart';
import '../navigation/studio_markup.dart';

/// The body of a documentation page: HTML rendered from markdown, in the
/// studio's reading typography.
///
/// ```dart
/// StudioProse(
///   markdownHtml,                       // trusted: the site's own docs
///   anchorLabel: l10n.linkToSection,    // 'Link to this section'
/// )
/// ```
///
/// What it styles: headings (`h2`–`h4`, with an anchor link that appears on
/// hover and keyboard focus), paragraphs and lists at a readable ~68
/// characters, links, inline `code`, highlighted `pre` blocks (the
/// `studio-tok-*` classes `highlightToHtml` writes), tables that scroll
/// inside themselves, blockquotes, images, `hr`, `kbd`. Every color is a
/// token, so light and dark need no extra CSS.
///
/// The HTML must be trusted (the site's own docs) or sanitized before.
/// Headings must carry an `id` to get an anchor.
///
/// `// web:` Flutter's `Markdown` widget builds a widget per node; here the
/// server renders the HTML once and the browser lays it out, so a long page
/// costs a handful of elements. Styles reach the markdown's tags through
/// `Styled(descendants:)`, which stops at thor widgets nested inside (a
/// `StudioCallout` between paragraphs keeps its own look).
class StudioProse extends StatelessWidget implements ThorElementWidget {
  /// Shows [markup].
  const StudioProse(
    this.markup, {
    super.key,
    this.anchors = true,
    this.anchorLabel,
  }) : _lead = false;

  /// Shows [markup] (one paragraph) as a page's lead: the 17 px subtitle in
  /// the soft ink, with its links and inline code. `StudioPageHeader`
  /// builds it from `leadMarkup`.
  const StudioProse.lead(this.markup, {super.key})
    : anchors = false,
      anchorLabel = null,
      _lead = true;

  /// The rendered markdown.
  final String markup;

  // Whether it is a page's lead (see `StudioProse.lead`).
  final bool _lead;

  /// Whether each heading gets an anchor link.
  final bool anchors;

  /// The accessible name of each heading's anchor link ("Link to this
  /// section"). Default: `StudioLocalizations.linkToSection`.
  final String? anchorLabel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return StudioMarkup(
      // web: the links' underline sits 3 px under the text (no typed
      // property says it).
      conditions: const [
        ConditionalCss(CssCondition.descendant('a:not([data-anchor])'), {
          'text-underline-offset': '3px',
        }),
      ],
      child: Styled(
        descendants: _styles(context),
        child: DefaultTextStyle(
          style: _lead
              ? leadStyle(context)
              : text.bodyLarge.copyWith(color: scheme.onSurface),
          child: Container(
            child: html.RawText(
              withTableFrames(
                anchors
                    ? withAnchors(
                        markup,
                        anchorLabel ??
                            StudioLocalizations.of(context).linkToSection,
                      )
                    : markup,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The style of a page's lead: 17 px, the soft ink, reading line height.
  static TextStyle leadStyle(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge.copyWith(
        color: StudioExtraColors.of(context).onSurfaceSoft,
        fontWeight: FontWeight.w400,
        height: StudioLineHeights.reading - 0.05,
        letterSpacing: 0,
      );

  static final _table = RegExp(r'<table[\s>][\s\S]*?</table>');
  // A cell that is one name in code (`onPressed`, `Icons.add`: no spaces,
  // at most 40 characters; an expression wraps like prose), or one link to
  // an error code (letters, a dash and digits).
  static final _codeCell = RegExp(
    r'<td([^>]*)>(\s*(?:<code>[^<\s]{1,40}</code>|'
    r'<a [^>]*>(?:<code>)?[A-Z]+-[A-Z]*\d+(?:</code>)?</a>)\s*)</td>',
  );

  /// [markup] with each `<table>` inside a `<div data-table>` frame (the
  /// frame draws the border and scrolls sideways; the table fills it), and
  /// each cell that holds only a name in code (a parameter) or a link to an
  /// error code marked `data-code`, so it stays on one line in mono.
  static String withTableFrames(String markup) {
    if (!markup.contains('<table')) return markup;
    return markup.replaceAllMapped(
      _table,
      (m) =>
          '<div data-table>${m[0]!.replaceAllMapped(_codeCell, (c) => '<td${c[1]} data-code>${c[2]}</td>')}</div>',
    );
  }

  // The Lucide link icon, 16 px, in the text's color.
  static const _linkIcon =
      '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" '
      'stroke="currentColor" stroke-width="2" stroke-linecap="round" '
      'stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 '
      '0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 '
      '5 0 0 0 7.07 7.07l1.71-1.71"/></svg>';

  static final _heading = RegExp(
    r'<(h[2-4])\s([^>]*?)id="([^"]+)"([^>]*)>([\s\S]*?)</\1>',
  );

  /// [markup] with an anchor link at the end of every `h2`–`h4` that has an
  /// `id`:
  ///
  /// ```html
  /// <h2 id="x" aria-labelledby="x-title"><span id="x-title">Text</span>
  ///   <a href="#x" data-anchor aria-label="…"><span aria-hidden="true"><svg…></span></a></h2>
  /// ```
  ///
  /// The heading is named by its own text (`aria-labelledby`), not by the
  /// text plus the link's label, so a screen reader announces "Text, heading
  /// level 2"; the `#` glyph is hidden from assistive technology and the
  /// link keeps its [label] as name. The link is a 16 px link icon that
  /// shows to the left of the heading on hover and focus, out of the text's
  /// flow (the heading does not move). A heading that already has a link to its
  /// own id is left alone.
  static String withAnchors(String markup, String label) {
    final escaped = label
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll('<', '&lt;');
    return markup.replaceAllMapped(_heading, (m) {
      final (tag, before, id, after, inner) = (
        m[1]!,
        m[2]!,
        m[3]!,
        m[4]!,
        m[5]!,
      );
      if (inner.contains('data-anchor')) return m[0]!;
      final named = '${before}id="$id"$after'.contains('aria-labelledby');
      return '<$tag ${before}id="$id"$after'
          '${named ? '' : ' aria-labelledby="$id-title"'}>'
          '<span id="$id-title">$inner</span>'
          '<a href="#$id" data-anchor aria-label="$escaped">'
          '<span aria-hidden="true">$_linkIcon</span></a></$tag>';
    });
  }

  Map<String, StyleProps> _styles(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final codeStyles = StudioExtraTextStyles.of(context);
    final scheme = Theme.of(context).colorScheme;
    final extra = StudioExtraColors.of(context);
    final code = StudioCodeThemeData.of(context);
    const measure = Length.ch(68);
    final inlineCode = StyleProps(
      // Relative to the text around it.
      textStyle: codeStyles.codeSmall.copyWith(
        fontSizeLength: const Length.em(0.875),
        color: scheme.onSurface,
      ),
      // A faint wash of the accent, like the links' underline.
      decoration: BoxDecoration(
        color: scheme.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(StudioRadii.small),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      // A long name breaks rather than widen the page on a phone.
      overflowWrap: OverflowWrap.anywhere,
    );
    return {
      // Blocks without the browser's margins, 16px apart.
      '> *': const StyleProps(margin: EdgeInsets.zero),
      '> * + *': const StyleProps(margin: EdgeInsets.only(top: 16)),
      // The measure: prose lines stay readable, wide blocks use the width.
      '> :first-child': const StyleProps(margin: EdgeInsets.zero),
      'p, ul, ol, blockquote, h2, h3, h4': const StyleProps(maxWidth: measure),
      'h2': StyleProps(
        textStyle: text.headlineMedium.copyWith(
          fontSize: 24,
          height: 1.3,
          letterSpacing: -0.24,
          color: scheme.onSurface,
        ),
        margin: const EdgeInsets.only(top: 56),
        scrollMargin: const EdgeInsets.only(top: 80),
        position: const BoxPosition.relative(),
      ),
      'h3': StyleProps(
        textStyle: text.titleLarge.copyWith(
          fontSize: 18,
          height: 1.4,
          letterSpacing: 0,
          color: scheme.onSurface,
        ),
        margin: const EdgeInsets.only(top: 32),
        scrollMargin: const EdgeInsets.only(top: 80),
        position: const BoxPosition.relative(),
      ),
      // What follows a heading sits close to it.
      'h2 + *': const StyleProps(margin: EdgeInsets.only(top: 12)),
      'h3 + *, h4 + *': const StyleProps(margin: EdgeInsets.only(top: 8)),
      'h4': StyleProps(
        textStyle: text.titleMedium.copyWith(color: scheme.onSurface),
        margin: const EdgeInsets.only(top: 24),
        scrollMargin: const EdgeInsets.only(top: 80),
        position: const BoxPosition.relative(),
      ),
      // The anchor: a link icon left of the heading, out of the flow, quiet
      // until the heading is hovered or the link focused.
      '[data-anchor]': StyleProps(
        textStyle: TextStyle(
          color: extra.onSurfaceFaint,
          decoration: TextDecoration.none,
        ),
        position: BoxPosition.absolute(
          left: (-24).px,
          top: const Length.em(0.35),
        ),
        display: Display.flex,
        opacity: 0,
      ),
      'h2:hover [data-anchor], h3:hover [data-anchor], h4:hover [data-anchor], '
          '[data-anchor]:focus-visible': const StyleProps(
        opacity: 1,
      ),
      'strong': const StyleProps(
        textStyle: TextStyle(fontWeight: FontWeight.w600),
      ),
      'a': StyleProps(
        textStyle: TextStyle(
          color: scheme.accent,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
          decorationColor: scheme.accent.withOpacity(0.5),
          decorationThickness: 1,
        ),
      ),
      'a:hover': StyleProps(
        textStyle: TextStyle(decorationColor: scheme.accent),
      ),
      'ul, ol': const StyleProps(padding: EdgeInsets.only(left: 24)),
      'li + li': const StyleProps(margin: EdgeInsets.only(top: 8)),
      'li > ul, li > ol': const StyleProps(margin: EdgeInsets.only(top: 8)),
      'li::marker': StyleProps(
        textStyle: TextStyle(color: scheme.onSurfaceVariant!),
      ),
      'code': inlineCode,
      // In a heading the code is the heading's own size and weight, in
      // mono, with no box.
      'h2 code, h3 code, h4 code': const StyleProps(
        textStyle: TextStyle(
          fontSizeLength: Length.em(1),
          fontWeight: FontWeight.w600,
        ),
        decoration: BoxDecoration(color: Colors.transparent),
        padding: EdgeInsets.zero,
      ),
      'pre': StyleProps(
        textStyle: codeStyles.codeMedium.copyWith(
          color: scheme.onSurface,
          height: StudioLineHeights.reading,
        ),
        decoration: BoxDecoration(
          color: code.color,
          border: Border.all(color: code.borderColor),
          borderRadius: BorderRadius.circular(code.radius),
        ),
        padding: code.padding,
        overflowX: Overflow.auto,
      ),
      // A code block's code: the block draws the box.
      'pre code': const StyleProps(
        textStyle: TextStyle(fontSizeLength: Length.em(1)),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.fromBorderSide(BorderSide.none),
        ),
        padding: EdgeInsets.zero,
      ),
      for (final (kind, color) in const [
        ('keyword', StudioSyntaxColors.keyword),
        ('string', StudioSyntaxColors.string),
        ('number', StudioSyntaxColors.number),
        ('type', StudioSyntaxColors.type),
        ('comment', StudioSyntaxColors.comment),
      ])
        '.studio-tok-$kind': StyleProps(textStyle: TextStyle(color: color)),
      // The table's frame (`withTableFrames`) draws the border and scrolls
      // sideways; the table fills it, so the header and the row lines reach
      // the frame's edge. (thor's `Table` is a grid, not the markdown's
      // `<table>`.)
      '[data-table]': StyleProps(
        overflowX: Overflow.auto,
        decoration: BoxDecoration(
          border: Border.all(color: code.borderColor),
          borderRadius: BorderRadius.circular(StudioRadii.inner),
        ),
      ),
      'table': StyleProps(
        textStyle: text.bodyMedium,
        minWidth: const Length.percent(100),
        borderCollapse: BorderCollapse.separate,
        borderSpacing: 0,
      ),
      'th, td': StyleProps(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: code.borderColor)),
        ),
      ),
      'tr:last-child td': const StyleProps(
        decoration: BoxDecoration(
          border: Border.fromBorderSide(BorderSide.none),
        ),
      ),
      'th': StyleProps(
        textStyle: text.labelMedium.copyWith(
          fontWeight: FontWeight.w600,
          color: code.headerTextColor,
        ),
        color: StudioSurfaceColors.canvas,
        // Cells start-aligned (the browser centers headers).
        textAlign: TextAlign.start,
      ),
      // A cell that is only a name (a parameter, an error code): one line,
      // in 13 px mono.
      '[data-code]': StyleProps(
        whiteSpace: WhiteSpace.nowrap,
        textStyle: codeStyles.codeSmall.copyWith(fontSize: 13),
      ),
      '[data-code] code': const StyleProps(
        textStyle: TextStyle(fontSize: 13),
        overflowWrap: OverflowWrap.normal,
      ),
      'blockquote': StyleProps(
        padding: const EdgeInsets.only(left: 16),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: extra.lineStrong, width: 2)),
        ),
        textStyle: TextStyle(color: extra.onSurfaceSoft),
      ),
      'hr': StyleProps(
        height: 1,
        color: scheme.outlineVariant,
        margin: const EdgeInsets.symmetric(vertical: 32),
        decoration: const BoxDecoration(
          border: Border.fromBorderSide(BorderSide.none),
        ),
      ),
      'img': StyleProps(
        maxWidth: 100.percent,
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(StudioRadii.inner),
        ),
      ),
      'kbd': StyleProps(
        textStyle: codeStyles.codeSmall.copyWith(color: scheme.onSurface),
        decoration: BoxDecoration(
          color: code.color,
          border: Border.all(color: code.borderColor),
          borderRadius: BorderRadius.circular(StudioRadii.small),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      ),
    };
  }
}
