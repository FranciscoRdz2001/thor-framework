import 'package:thor_server/thor_server.dart' show ListQuery;

import '../core/core.dart';
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/material_localizations.dart' show ThorLocalizations;
import '../foundation/style_registry.dart' show ConditionalCss, CssCondition;
import '../foundation/theme_tokens.dart';

/// The links of a list whose page lives in the URL: a `<nav>` with real
/// links (they work with no JavaScript, open in a new tab and are
/// bookmarkable), the current page marked with `aria-current="page"`,
/// `rel="prev"`/`rel="next"` on its neighbours, and every other parameter
/// of the URL (`q`, `sort`, the filters) kept.
///
/// ```dart
/// // in load: final list = request.listQuery(pageSize: 20);
/// Pagination(list: data.list, total: data.total)
/// ```
///
/// Shows the first and last pages and [window] pages around the current
/// one, with a gap (`…`, hidden from assistive tech) where pages are left
/// out; a list of one page shows nothing. A page past the end is shown as
/// the last one.
///
/// web: Flutter has no such widget (its `PaginatedDataTable` keeps the page
/// in memory); Laravel's paginator (`links()`) and Django's paginator
/// pattern in the docs render the same nav of links, from `?page=`.
class Pagination extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// The links of [list] for [total] rows.
  Pagination({
    super.key,
    required ListQuery list,
    required int total,
    this.window = 1,
    this.previousLabel,
    this.nextLabel,
    this.semanticLabel,
    this.pageLabel,
  }) : page = list.clampTo(total).page,
       pageCount = list.pageCount(total),
       _href = list.withPage;

  /// The links of a list of [pageCount] pages whose page `n` is at
  /// [href]`(n)`, for a list that is not read with `request.listQuery`.
  const Pagination.custom({
    super.key,
    required this.page,
    required this.pageCount,
    required String Function(int page) href,
    this.window = 1,
    this.previousLabel,
    this.nextLabel,
    this.semanticLabel,
    this.pageLabel,
  }) : _href = href;

  /// The current page, from 1.
  final int page;

  /// How many pages there are.
  final int pageCount;

  /// Pages shown on each side of the current one.
  final int window;

  /// The text of the link to the previous page (the locale's by default).
  final String? previousLabel;

  /// The text of the link to the next page (the locale's by default).
  final String? nextLabel;

  /// The accessible name of the navigation (`aria-label`).
  final String? semanticLabel;

  /// The accessible name of a page link is `"$pageLabel 3"` (the link's
  /// text is just the number).
  final String? pageLabel;

  final String Function(int page) _href;

  // The page numbers shown, `null` for a gap: the ends, the window around
  // the current page, and a page that would leave a gap of one.
  List<int?> _slots(int page) {
    final wanted = <int>{
      1,
      pageCount,
      for (var n = page - window; n <= page + window; n++)
        if (n >= 1 && n <= pageCount) n,
    }.toList()..sort();
    final out = <int?>[];
    for (var i = 0; i < wanted.length; i++) {
      if (i > 0) {
        final gap = wanted[i] - wanted[i - 1] - 1;
        if (gap == 1) {
          out.add(wanted[i] - 1);
        } else if (gap > 1) {
          out.add(null);
        }
      }
      out.add(wanted[i]);
    }
    return out;
  }

  static const _item = <String, String>{
    'display': 'inline-flex',
    'align-items': 'center',
    'justify-content': 'center',
    'box-sizing': 'border-box',
    'min-width': '40px',
    'height': '40px',
    'padding': '0 12px',
    'border-radius': '20px',
    'text-decoration': 'none',
    'font': 'inherit',
    'color': 'inherit',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = ThorLocalizations.of(context);
    final previousLabel = this.previousLabel ?? l10n.paginationPrevious;
    final nextLabel = this.nextLabel ?? l10n.paginationNext;
    final pageLabel = this.pageLabel ?? l10n.paginationPage;
    final semanticLabel = this.semanticLabel ?? l10n.paginationLabel;
    if (pageCount <= 1) return const Widget.fragment([]);
    // A page past the end is the last one (the main constructor clamps it
    // already).
    final page = this.page.clamp(1, pageCount);
    Widget item(Widget child) =>
        thorElement('li', debugName: 'PaginationItem', children: [child]);
    Widget link(
      String label,
      int to, {
      String? rel,
      bool current = false,
      bool number = false,
    }) => item(
      thorElement(
        'a',
        debugName: 'PaginationLink',
        css: {
          ..._item,
          if (current) ...{
            'background-color': ThemeTokens.primary,
            'color': ThemeTokens.onPrimary,
            'font-weight': '500',
          },
        },
        conditions: [
          if (!current)
            const ConditionalCss(CssCondition.selector(':hover'), {
              'background-color':
                  'color-mix(in srgb, ${ThemeTokens.onSurface} 8%, transparent)',
            }),
          const ConditionalCss(CssCondition.focused, {
            'outline': '2px solid ${ThemeTokens.primary}',
            'outline-offset': '2px',
          }),
        ],
        attributes: {
          'href': _href(to),
          'rel': ?rel,
          if (number) 'aria-label': '$pageLabel $label',
          if (current) 'aria-current': 'page',
        },
        children: [Widget.text(label)],
      ),
    );
    Widget off(String label) => item(
      thorElement(
        'span',
        debugName: 'PaginationLink',
        css: {..._item, 'opacity': '0.38'},
        attributes: const {'aria-disabled': 'true'},
        children: [Widget.text(label)],
      ),
    );
    return thorElement(
      'nav',
      debugName: 'Pagination',
      attributes: {'aria-label': semanticLabel},
      children: [
        thorElement(
          'ul',
          css: const {
            'display': 'flex',
            'flex-wrap': 'wrap',
            'align-items': 'center',
            'gap': '4px',
            'list-style': 'none',
            'margin': '0',
            'padding': '0',
          },
          childRules: ChildRules.row,
          children: [
            if (page > 1)
              link(previousLabel, page - 1, rel: 'prev')
            else
              off(previousLabel),
            for (final n in _slots(page))
              if (n == null)
                item(
                  thorElement(
                    'span',
                    css: _item,
                    attributes: const {'aria-hidden': 'true'},
                    children: [const Widget.text('…')],
                  ),
                )
              else
                link('$n', n, current: n == page, number: true),
            if (page < pageCount)
              link(nextLabel, page + 1, rel: 'next')
            else
              off(nextLabel),
          ],
        ),
      ],
    );
  }
}
