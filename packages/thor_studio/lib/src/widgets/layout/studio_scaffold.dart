import 'package:thor_ui/thor_ui.dart';

import '../../attributes.dart';
import '../../icons.dart';
import '../../l10n/studio_localizations.dart';
import '../../studio_id.dart';
import '../../theme/component_themes/studio_nav_theme.dart';
import '../../tokens/shape/studio_radii.dart';
import '../../tokens/spacing/studio_layout.dart';
import '../../tokens/spacing/studio_spacing.dart';
import '../navigation/studio_markup.dart';
import 'studio_scaffold_scope.dart';

/// The page of a docs site, like Flutter's `Scaffold`: an [appBar], an
/// optional [drawer], the [body], an optional [tableOfContents] and a
/// [footer].
///
/// ```dart
/// StudioScaffold(
///   appBar: StudioTopBar(brand: StudioBrand(name: 'thor'), search: …),
///   drawer: StudioSideNav(sections: …),
///   tableOfContents: StudioTableOfContents(entries: …),
///   body: Column(children: [StudioPageHeader(title: 'Widgets'), …]),
///   footer: StudioFooter(…),
/// )
/// ```
///
/// Responsive with no script: from `lg` the sidebar is a sticky column, and
/// below it the same widgets are a native `<dialog>` drawer that the top bar's
/// menu button opens (focus trap, Esc and a click outside close it); the table
/// of contents shows from `xl`. The first Tab stop is a skip link to the
/// page's `<main>`.
///
/// Every string it writes (the skip link, the menu button, the drawer's name
/// and close button) comes from `StudioLocalizations` unless a parameter
/// ([skipLabel], [menuLabel], [sidebarLabel], [closeLabel]) says otherwise.
///
/// `// web:` Flutter's `Scaffold.drawer` is a modal on every size; here the
/// drawer becomes an in-flow column on a desktop (`Drawer.permanentFrom`),
/// and the body is a `<main>` landmark with a width to read in; [sidebarId]
/// is the drawer's DOM id, which the app bar's menu button targets.
class StudioScaffold extends StatelessWidget implements ThorElementWidget {
  /// A page of [body] under [appBar].
  const StudioScaffold({
    super.key,
    required this.appBar,
    required this.body,
    this.drawer,
    this.skipLabel,
    this.sidebarLabel,
    this.menuLabel,
    this.tableOfContents,
    this.footer,
    this.closeLabel,
    this.sidebarId,
    this.sidebarRestorationId,
    this.maxContentWidth = StudioLayout.readingWidth,
    this.maxPageWidth,
    this.drawerHeader,
  });

  /// A `StudioTopBar` (Flutter's `Scaffold.appBar`).
  final Widget appBar;

  /// The page's content, a column of `StudioPageHeader`, prose, code…
  final Widget body;

  /// Usually a `StudioSideNav`: a column from `lg`, a drawer below (Flutter's
  /// `Scaffold.drawer`).
  final Widget? drawer;

  /// The skip link's text: the first Tab stop, to the `<main>` (default:
  /// `StudioLocalizations.skipToContent`).
  final String? skipLabel;

  /// The accessible name of the drawer (default:
  /// `StudioLocalizations.navigation`).
  final String? sidebarLabel;

  /// The accessible name of the app bar's button that opens the drawer
  /// (default: `StudioLocalizations.openNavigation`).
  final String? menuLabel;

  /// Usually a `StudioTableOfContents`; shown from `xl`.
  final Widget? tableOfContents;

  /// Usually a `StudioFooter`.
  final Widget? footer;

  /// The accessible name of the drawer's close button (a visible X at the
  /// top of the drawer, below `lg`), so closing it never depends on Esc or a
  /// click outside (default: `StudioLocalizations.close`).
  final String? closeLabel;

  /// The drawer's DOM id. Optional: the page names it, so a page that holds
  /// two scaffolds needs nothing.
  final String? sidebarId;

  /// Keeps the sidebar's scroll across pages under this id, as
  /// `SingleChildScrollView.restorationId` does: the visitor finds the list
  /// where they left it, and the current page's link in sight. Null starts
  /// it at the top on every page.
  final String? sidebarRestorationId;

  /// The widest the body grows to; null lets it fill the column.
  final double? maxContentWidth;

  /// The widest the row of sidebar, body and table of contents grows to,
  /// centred in the window; null lets it fill the window.
  final double? maxPageWidth;

  /// What the drawer shows at its top on a phone, before its close button
  /// (usually the `StudioBrand`); null shows the close button alone.
  final Widget? drawerHeader;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = StudioLocalizations.of(context);
    final bar = appBar;
    final side = drawer;
    final sidebarId = side == null
        ? null
        : studioId(context, 'sidebar', this.sidebarId);
    final page = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SkipLink(skipLabel ?? l10n.skipToContent),
        bar,
        Styled(
          style: const StyleProps(flex: 1),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxWidth: maxPageWidth ?? double.infinity,
              ),
              // The page's side gutter: the columns sit inside it.
              padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.md)
                  .when(
                    medium: const EdgeInsets.symmetric(
                      horizontal: StudioSpacing.lg,
                    ),
                  ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (side != null)
                    _SidebarDrawer(
                      id: sidebarId!,
                      label: sidebarLabel ?? l10n.navigation,
                      closeLabel: closeLabel ?? l10n.close,
                      header: drawerHeader,
                      restorationId: sidebarRestorationId,
                      child: side,
                    ),
                  Expanded(
                    child: _Main(
                      maxWidth: maxContentWidth,
                      besideSidebar: side != null,
                      child: body,
                    ),
                  ),
                  if (tableOfContents != null)
                    ResponsiveVisibility(
                      visibleFrom: WindowSizeClass.large,
                      child: _Aside(child: tableOfContents!),
                    ),
                ],
              ),
            ),
          ),
        ),
        ?footer,
      ],
    );
    return Styled(
      // web: where the sticky columns stop, under the bar (its height and
      // its 1 px bottom border) and the device's top inset: the one value
      // CSS can only spell with `env()`.
      style: StyleProps(
        minHeight: 100.dvh,
        // ignore: thor_lints/avoid_raw_css
        raw: {
          '--studio-top':
              'calc(${StudioLayout.topbarHeight + 1}px + env(safe-area-inset-top, 0px))',
        },
      ),
      // A `Scaffold` inside the body adds no second skip link.
      child: SkipLinkProvided(
        child: Container(
          color: scheme.surface,
          child: side == null
              ? page
              : StudioScaffoldScope(
                  sidebarId: sidebarId!,
                  menuLabel: menuLabel ?? l10n.openNavigation,
                  child: page,
                ),
        ),
      ),
    );
  }
}

/// The bar's height and the device's top inset (`--studio-top`, set below).
const _studioTop = Length.variable(CssVariable('--studio-top'));

/// Where the table of contents stops under the bar: `--studio-top` and the
/// body's top padding, so its title lines up with the page's first line.
Length get _stickyTop => _studioTop + StudioSpacing.xl.px;

/// What the table of contents leaves of the window (it scrolls inside
/// beyond).
Length get _stickyMaxHeight =>
    100.dvh - (_studioTop + (StudioSpacing.xl + StudioSpacing.md).px);

/// The sidebar: an inline column from `lg`, a drawer below.
class _SidebarDrawer extends StatelessWidget implements ThorElementWidget {
  const _SidebarDrawer({
    required this.id,
    required this.label,
    required this.closeLabel,
    required this.header,
    required this.restorationId,
    required this.child,
  });

  final String id;
  final String label;
  final String closeLabel;
  final Widget? header;
  final String? restorationId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nav = StudioNavThemeData.of(context);
    return Drawer(
      id: id,
      label: label,
      permanentFrom: WindowSizeClass.expanded,
      width: StudioLayout.panelWidth,
      permanentWidth: StudioLayout.sidebarWidth,
      // A card as a drawer, the page itself as a column.
      backgroundColor: scheme.surfaceContainer.when(expanded: scheme.surface),
      padding: EdgeInsets.zero,
      permanentPadding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The drawer's own header: the brand and its close button; the
          // inline column has nothing to close.
          ResponsiveVisibility(
            hiddenFrom: WindowSizeClass.expanded,
            child: Container(
              height: nav.barHeight,
              padding: const EdgeInsets.only(
                left: StudioSpacing.md,
                right: StudioSpacing.xs,
              ),
              child: Row(
                children: [
                  if (header != null) header! else const Spacer(),
                  if (header != null) const Spacer(),
                  DialogClose(
                    id: id,
                    child: Styled(
                      duration: nav.pressDuration,
                      curve: nav.curve,
                      style: const StyleProps(
                        scale: 1,
                      ).when(pressed: StyleProps(scale: nav.pressScale)),
                      child: IconButton(
                        onPressed: () {},
                        tooltip: closeLabel,
                        icon: const Icon(StudioIcons.x, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // From `lg` the column is as tall as the page and this box sticks
          // under the bar, as tall as the window, scrolling inside itself.
          // It must have no scrolling ancestor but the page (the inline
          // drawer has `overflow: visible`), or it would stick to that one.
          StudioMarkup(
            attributes: const {'data-studio-sidebar-scroll': ''},
            child: Styled(
              style: restorationId == null
                  ? const StyleProps().when(
                      expanded: StyleProps(
                        position: const BoxPosition.sticky(top: _studioTop),
                        heightLength: 100.dvh - _studioTop,
                        overflowY: Overflow.auto,
                      ),
                    )
                  // The one scroll view at every size, so one offset is kept:
                  // the drawer's rest below `lg` (the panel no longer
                  // scrolls itself), the sticky box from it.
                  : StyleProps(flex: 1, flexShrink: 1, minHeight: 0.px).when(
                      expanded: StyleProps(
                        flex: 0,
                        flexShrink: 0,
                        position: const BoxPosition.sticky(top: _studioTop),
                        heightLength: 100.dvh - _studioTop,
                      ),
                    ),
              child: _restoring(
                Padding(
                  // The first group lines up with the page's first line (the
                  // body's top padding).
                  padding:
                      const EdgeInsets.fromLTRB(
                        StudioSpacing.md,
                        StudioSpacing.xs,
                        StudioSpacing.md,
                        StudioSpacing.lg,
                      ).when(
                        expanded: const EdgeInsets.fromLTRB(
                          StudioSpacing.md,
                          StudioSpacing.xl,
                          StudioSpacing.md,
                          StudioSpacing.xxl,
                        ),
                      ),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// [box] in a scroll view that keeps its offset, when there is an id.
  Widget _restoring(Widget box) => switch (restorationId) {
    final id? => SingleChildScrollView(restorationId: id, child: box),
    null => box,
  };
}

/// The `<main>`: padding, and a column to read in.
class _Main extends StatelessWidget implements ThorElementWidget {
  const _Main({
    required this.maxWidth,
    required this.besideSidebar,
    required this.child,
  });

  final double? maxWidth;
  final bool besideSidebar;
  final Widget child;

  @override
  Widget build(BuildContext context) => StudioAttributes(
    const {'id': StudioLayout.mainId},
    child: Semantics(
      role: SemanticsRole.main,
      child: Container(
        // 32 above, 96 below; beside the sidebar column, the 48 px gap.
        padding:
            const EdgeInsets.fromLTRB(
              0,
              StudioSpacing.xl,
              0,
              StudioSpacing.xxl * 2,
            ).when(
              expanded: EdgeInsets.fromLTRB(
                besideSidebar ? StudioSpacing.xxl : 0,
                StudioSpacing.xl,
                0,
                StudioSpacing.xxl * 2,
              ),
            ),
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// The right column: an `<aside>` whose content sticks under the bar.
class _Aside extends StatelessWidget implements ThorElementWidget {
  const _Aside({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    role: SemanticsRole.complementary,
    child: Container(
      // The 48 px gap, then the column.
      width: StudioLayout.tocWidth + StudioSpacing.xxl,
      padding: const EdgeInsets.fromLTRB(
        StudioSpacing.xxl,
        StudioSpacing.xl,
        0,
        StudioSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Styled(
            style: StyleProps(
              position: BoxPosition.sticky(top: _stickyTop),
              maxHeight: _stickyMaxHeight,
              overflowY: Overflow.auto,
            ),
            child: child,
          ),
        ],
      ),
    ),
  );
}

/// The skip link: off screen until the keyboard reaches it (the page's
/// first stop), then over the top bar.
class _SkipLink extends StatelessWidget implements ThorElementWidget {
  const _SkipLink(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nav = StudioNavThemeData.of(context);
    return Styled(
      style:
          StyleProps(
            position: BoxPosition.absolute(
              left: StudioSpacing.sm.px,
              top: (-100).px,
            ),
            zIndex: 50,
          ).when(
            focused: StyleProps(
              position: BoxPosition.absolute(
                left: StudioSpacing.sm.px,
                top: StudioSpacing.xs.px,
              ),
              zIndex: 50,
            ),
          ),
      child: Link(
        href: const RouteUrl('#${StudioLayout.mainId}'),
        child: Container(
          height: nav.searchHeight,
          padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.lg),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(StudioRadii.control),
          ),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge.copyWith(color: scheme.onPrimary),
          ),
        ),
      ),
    );
  }
}
