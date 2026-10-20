import 'package:thor_ui/thor_ui.dart';

import '../../l10n/studio_localizations.dart';
import '../../theme/component_themes/studio_nav_theme.dart';
import '../../theme/studio_extra_colors.dart';
import '../../tokens/spacing/studio_spacing.dart';
import '../../tokens/typography/studio_font_weights.dart';
import '../../tokens/typography/studio_type_scale.dart';
import '../feedback/studio_status_label.dart';
import '../inputs/state_styles.dart';
import 'studio_nav_destination.dart';
import 'studio_nav_section.dart';

/// The sidebar of a docs page: every page in sight, grouped under section
/// headings, each section a list on a hairline rail where the current page
/// is marked by an accent bar and accent text.
///
/// ```dart
/// StudioSideNav(
///   sections: [
///     StudioNavSection(
///       title: 'Learn',
///       items: [StudioNavDestination('Widgets', href: '/widgets')],
///     ),
///   ],
///   selectedIndex: 0, // counts the items of every section, top to bottom
/// )
/// ```
///
/// An item may end in a count pill (`StudioNavDestination(count:,
/// countTone:, countLabel:)`) or any [StudioNavDestination.trailing] widget:
/// "Issues 31" without a nav of the app's own. With [touchTargets] the rows
/// are at least 44 px tall on touch screens (`pointer: coarse`), as the
/// phone drawer wants; the desktop column keeps its 32 px rows. With
/// [pressFeedback] a row squeezes under the finger or the pointer
/// ([pressScale], 0.985: a wide row squeezes less than a small pill); off by
/// default.
///
/// It is a `<nav>` of `<ul>` lists, each under its `<h2>`; the current
/// page's link carries `aria-current="page"`. Put it in
/// `StudioScaffold(drawer:)`: there it is the column of a desktop and the
/// drawer of a phone (with `sidebarRestorationId` the current page scrolls
/// into view).
///
/// `// web:` Flutter's `NavigationDrawer` has no landmark: this is a `<nav>`
/// named by [label] (default `StudioLocalizations.navigation`).
class StudioSideNav extends StatelessWidget implements ThorElementWidget {
  /// A navigation of [sections].
  const StudioSideNav({
    super.key,
    required this.sections,
    this.selectedIndex,
    this.label,
    this.touchTargets = false,
    this.pressFeedback = false,
    this.pressScale = _rowPressScale,
  });

  /// The groups of links.
  final List<StudioNavSection> sections;

  /// The index of the current item, counting the items of every section from
  /// the first (like `NavigationDrawer.selectedIndex`).
  final int? selectedIndex;

  /// The landmark's accessible name (`aria-label`; default:
  /// `StudioLocalizations.navigation`).
  final String? label;

  /// Makes every row at least 44 px tall where the pointer is coarse (a
  /// finger), leaving the mouse's 32 px rows alone.
  final bool touchTargets;

  /// Squeezes a row while it is pressed (`:active`, [pressScale], eased with
  /// the nav theme's duration and curve). Off by default.
  final bool pressFeedback;

  /// The scale of a pressed row when [pressFeedback] is on.
  final double pressScale;

  @override
  Widget build(BuildContext context) {
    var offset = 0;
    final children = <Widget>[];
    for (final section in sections) {
      children.add(
        _Section(
          section,
          offset: offset,
          selectedIndex: selectedIndex,
          touchTargets: touchTargets,
          pressScale: pressFeedback ? pressScale : null,
        ),
      );
      offset += section.items.length;
    }
    return Semantics(
      role: SemanticsRole.navigation,
      label: label ?? StudioLocalizations.of(context).navigation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        // The space above each section.
        spacing: StudioSpacing.lg + StudioSpacing.xxs,
        children: children,
      ),
    );
  }
}

/// Where an item's text and a section heading start: past the rail.
const double _textStart = StudioSpacing.sm;

/// The scale of a pressed row (a full-width row squeezes less than a pill).
const double _rowPressScale = 0.985;

/// The current item's bar: 2 px, centred over the list's 1 px rail.
const double _barWidth = 2;
const double _barShift = -1.5;

class _Section extends StatelessWidget implements ThorElementWidget {
  const _Section(
    this.section, {
    required this.offset,
    required this.selectedIndex,
    required this.touchTargets,
    required this.pressScale,
  });

  final StudioNavSection section;

  // The index of the section's first item among all the items.
  final int offset;
  final int? selectedIndex;
  final bool touchTargets;
  final double? pressScale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The rail: one hairline the items sit on.
    final items = Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Semantics(
        role: SemanticsRole.list,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, item) in section.items.indexed)
              _Item(
                item,
                current: offset + i == selectedIndex,
                touchTargets: touchTargets,
                pressScale: pressScale,
              ),
          ],
        ),
      ),
    );
    if (section.title.isEmpty) return items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: StudioSpacing.xs,
      children: [
        _Heading(section.title, icon: section.icon),
        items,
      ],
    );
  }
}

/// A section's heading: a small semibold label in the muted ink, after the
/// section's icon when it has one; it starts where the items' text does.
class _Heading extends StatelessWidget implements ThorElementWidget {
  const _Heading(this.title, {this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final nav = StudioNavThemeData.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(left: _textStart),
      child: Row(
        spacing: StudioSpacing.xs,
        children: [
          if (icon case final icon?)
            Icon(icon, size: 16, color: nav.sectionTitleColor),
          Expanded(
            child: Semantics(
              headingLevel: 2,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall.copyWith(
                  fontSize: StudioTypeScale.code,
                  letterSpacing: 0.2,
                  color: nav.sectionTitleColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _clear = Colors.transparent;

/// A row of the sidebar: 14 px text, about 32 px tall; the muted text turns
/// to ink and the rail darkens under the pointer; the current page has the
/// accent bar and medium accent text, no fill.
class _Item extends StatelessWidget implements ThorElementWidget {
  const _Item(
    this.item, {
    required this.current,
    required this.touchTargets,
    required this.pressScale,
  });

  final StudioNavDestination item;
  final bool current;
  final bool touchTargets;

  /// The scale while pressed; null: no press feedback.
  final double? pressScale;

  @override
  Widget build(BuildContext context) {
    final nav = StudioNavThemeData.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final extra = StudioExtraColors.of(context);
    final count = item.count;
    final color = current
        ? scheme.accent
        : nav.itemColor.when(hover: scheme.onSurface);
    final scale = pressScale;
    Widget row = Link(
      href: RouteUrl(item.href),
      current: current,
      // The label's color lives on the whole row (the link), so the text
      // and the rail change together under the pointer anywhere on the
      // row, and fade with the same timing.
      child: AnimatedDefaultTextStyle(
        duration: nav.duration,
        curve: nav.curve,
        style: TextStyle(color: color),
        child: AnimatedContainer(
          duration: nav.duration,
          curve: nav.curve,
          // The text starts at `_textStart` from the section's edge: past
          // the 1 px rail, the shift and the bar.
          padding: const EdgeInsets.fromLTRB(
            _textStart - 1 - _barShift - _barWidth,
            6,
            StudioSpacing.xs,
            6,
          ),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: current
                    ? scheme.accent
                    : _clear.when(hover: extra.lineStrong),
                width: _barWidth,
              ),
            ),
          ),
          child: StateStyles(
            states: [
              if (touchTargets)
                StateStyle(
                  const CssCondition.media('(pointer: coarse)'),
                  StyleProps(minHeight: (_touchHeight - 12).px),
                ),
            ],
            child: Row(
              spacing: StudioSpacing.xs,
              children: [
                if (item.icon != null)
                  ExcludeSemantics(
                    child: Icon(
                      item.icon!,
                      size: 16,
                      color: current ? scheme.accent : nav.sectionTitleColor,
                    ),
                  ),
                Expanded(
                  // A long title wraps (never cut).
                  child: Text(
                    item.label,
                    style: text.bodyMedium.copyWith(
                      fontWeight: current ? StudioFontWeights.medium : null,
                    ),
                  ),
                ),
                if (count != null && count > 0) _Count(item, count),
                ?item.trailing,
              ],
            ),
          ),
        ),
      ),
    );
    if (scale != null) {
      // The squeeze is on the link itself (its own `scale`, apart from the
      // bar's `translate`), so the whole row gives under the finger.
      row = Styled(
        duration: nav.duration,
        curve: nav.curve,
        style: const StyleProps(
          scale: 1,
        ).when(pressed: StyleProps(scale: scale)),
        child: row,
      );
    }
    return Semantics(
      role: SemanticsRole.listItem,
      child: Transform.translate(
        offset: const Offset(_barShift, 0),
        child: row,
      ),
    );
  }
}

/// The least height of a row under a finger.
const double _touchHeight = 44;

/// The pill at the end of an item: the number (tabular figures, `99+` from a
/// hundred), named for a screen reader by `countLabel` or the number itself.
class _Count extends StatelessWidget implements ThorElementWidget {
  const _Count(this.item, this.count);

  final StudioNavDestination item;
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: item.countLabel ?? '$count',
    child: ExcludeSemantics(
      child: StudioStatusLabel(
        tone: item.countTone,
        label: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
        ),
      ),
    ),
  );
}
