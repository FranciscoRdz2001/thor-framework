// ignore_for_file: public_member_api_docs
// (the `dialog-permanent-drawer` region is shown as written; a doc comment
// would sit outside the code the site shows)
/// The component catalog: navigation (`docs/guia/es/componentes-navegacion.md`).
/// Every example is a bench: a stage, a panel with Switches and Levels, and
/// a Code view that follows them. The ids (`cat-app-bar`…) are the ones the
/// widget pages of the API reference reuse.
library;

import 'package:thor_ui/thor_ui.dart';

import '../../../core/i18n/docs_locale.dart';
import 'bench/bench_example.dart';
import 'bench/bench_kit.dart';
import 'bench/bench_kit_preview.dart';
import 'catalog_shared.dart';

// ---------------------------------------------------------------------- AppBar

/// What the AppBar panel controls.
class AppBarViewModel extends ThorState {
  /// Whether the title is centered.
  final centered = state(false);

  /// Whether there is a menu button before the title.
  final leading = state(true);

  /// Whether there is a search action.
  final search = state(true);

  /// The elevation, in steps of 2 from 0.
  final elevation = state(0);

  /// The number next to the elevation Level.
  String elevationText() => '${elevation.value * 2}';

  /// The `leading` line of the Code view.
  String leadingCode() => leading.value
      ? "leading: IconButton(icon: Icon(Icons.menu), tooltip: 'Menu'),"
      : '// leading: null,';

  /// The `title` line.
  String titleCode() => "title: Text('Orders'),";

  /// The `centerTitle` line.
  String centerCode() => 'centerTitle: ${centered.value},';

  /// The `actions` line.
  String actionsCode() => search.value
      ? "actions: [IconButton(icon: Icon(Icons.search), tooltip: 'Search')],"
      : 'actions: [],';

  /// The `elevation` line.
  String elevationCode() => 'elevation: ${elevation.value * 2},';

  /// What the centerTitle Switch calls.
  void setCentered(bool value) => centered.value = value;

  /// What the leading Switch calls.
  void setLeading(bool value) => leading.value = value;

  /// What the search Switch calls.
  void setSearch(bool value) => search.value = value;

  /// What the elevation Level calls.
  void setElevation(double value) => elevation.value = (value / 2).round();
}

/// One instance, at the top level.
final appBar = AppBarViewModel();

/// `cat-app-bar`.
final appBarBench = BenchExample(
  title: (t) => t.exNavAppBarTitle,
  description: (t) => t.exNavAppBarDescription,
  stage: const _AppBarStage(),
  code: BenchCode([
    const BenchCodeLine('AppBar('),
    BenchCodeLine.live(appBar.leadingCode, indent: 1),
    BenchCodeLine.live(appBar.titleCode, indent: 1),
    BenchCodeLine.live(appBar.centerCode, indent: 1),
    BenchCodeLine.live(appBar.actionsCode, indent: 1),
    BenchCodeLine.live(appBar.elevationCode, indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    boolSwitch(
      label: (t) => t.exNavCenterTitle,
      value: appBar.centered.value,
      onChanged: appBar.setCentered,
    ),
    boolSwitch(
      label: (t) => t.exNavLeading,
      value: appBar.leading.value,
      onChanged: appBar.setLeading,
    ),
    boolSwitch(
      label: (t) => t.exNavSearchAction,
      value: appBar.search.value,
      onChanged: appBar.setSearch,
    ),
    BenchLevel(
      label: (t) => t.exNavElevation,
      value: appBar.elevation.value,
      max: 4,
      divisions: 2,
      onChanged: appBar.setElevation,
      valueText: appBar.elevationText,
    ),
  ],
);

class _AppBarStage extends StatelessWidget {
  const _AppBarStage();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      child: Watch.field(
        appBar.centered,
        builder: (centered) => Watch.field(
          appBar.leading,
          builder: (leading) => Watch.field(
            appBar.search,
            builder: (search) => Watch.field(
              appBar.elevation,
              count: 3,
              builder: (step) => AppBar(
                leading: leading
                    ? IconButton(
                        icon: const Icon(Icons.menu),
                        tooltip: 'Menu',
                        onPressed: demo.notice,
                      )
                    : null,
                title: const Text('Orders'),
                centerTitle: centered,
                elevation: step * 2.0,
                actions: [
                  if (search)
                    IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: 'Search',
                      onPressed: demo.notice,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------ Tabs

/// What the TabBar panel controls.
class TabsViewModel extends ThorState {
  /// How many tabs beyond the first two (0 to 2).
  final extra = state(1);

  /// Whether the bar scrolls.
  final scrollable = state(false);

  /// The number next to the tabs Level.
  String countText() => '${2 + extra.value}';

  /// The `length` line of the Code view.
  String lengthCode() => 'length: ${2 + extra.value},';

  /// The `isScrollable` line.
  String scrollCode() => 'isScrollable: ${scrollable.value},';

  /// The `tabs` line.
  String tabsCode() {
    final names = ['Details', 'Payments', 'Shipping', 'Notes'];
    final shown = [
      for (var i = 0; i < 2 + extra.value; i++) "Tab(text: '${names[i]}')",
    ];
    return 'tabs: [${shown.join(', ')}],';
  }

  /// The `children` line.
  String viewCode() => 'TabBarView(children: [… ${2 + extra.value} panels …]),';

  /// What the tabs Level calls.
  void setCount(double value) => extra.value = value.round() - 2;

  /// What the scrollable Switch calls.
  void setScrollable(bool value) => scrollable.value = value;
}

/// One instance, at the top level.
final tabs = TabsViewModel();

/// `cat-tabs`.
final tabsBench = BenchExample(
  title: (t) => t.exNavTabsTitle,
  description: (t) => t.exNavTabsDescription,
  stage: const _TabsStage(),
  code: BenchCode([
    const BenchCodeLine('DefaultTabController('),
    const BenchCodeLine("id: 'cat-tabs',", indent: 1),
    BenchCodeLine.live(tabs.lengthCode, indent: 1),
    const BenchCodeLine('child: Column(children: [', indent: 1),
    const BenchCodeLine('TabBar(', indent: 2),
    BenchCodeLine.live(tabs.scrollCode, indent: 3),
    BenchCodeLine.live(tabs.tabsCode, indent: 3),
    const BenchCodeLine('),', indent: 2),
    BenchCodeLine.live(tabs.viewCode, indent: 2),
    const BenchCodeLine(']),', indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    boolSwitch(
      label: (t) => t.exNavScrollable,
      value: tabs.scrollable.value,
      onChanged: tabs.setScrollable,
    ),
    BenchLevel(
      label: (t) => t.exNavTabCount,
      value: tabs.extra.value + 2,
      min: 2,
      max: 4,
      divisions: 2,
      onChanged: tabs.setCount,
      valueText: tabs.countText,
    ),
  ],
);

class _TabsStage extends StatelessWidget {
  const _TabsStage();

  @override
  Widget build(BuildContext context) {
    final names = ['Details', 'Payments', 'Shipping', 'Notes'];
    final panels = [
      '3 items, 1 pending.',
      'Paid by card.',
      'Arrives Friday.',
      'No notes yet.',
    ];
    return SizedBox(
      width: 340,
      child: Watch.field(
        tabs.scrollable,
        builder: (scrollable) => Watch.field(
          tabs.extra,
          count: 3,
          builder: (extra) {
            final n = 2 + extra;
            return DefaultTabController(
              // `// web:` the id names the native radios: one per variant.
              id: 'cat-tabs-$n-${scrollable ? 's' : 'f'}',
              length: n,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TabBar(
                    isScrollable: scrollable,
                    tabs: [for (var i = 0; i < n; i++) Tab(text: names[i])],
                  ),
                  TabBarView(
                    children: [
                      for (var i = 0; i < n; i++)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(panels[i]),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// region: dialog-permanent-drawer
// A filter panel written once: a modal drawer below md (opened by the
// button), a panel beside the results from md up (no button, no JS).
class PermanentDrawerDemo extends StatelessWidget {
  const PermanentDrawerDemo({super.key});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 16,
    children: [
      Drawer(
        id: 'demo-filters',
        permanentFrom: WindowSizeClass.medium,
        label: 'Filters',
        width: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Filters',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            for (final name in const ['Shirts', 'Caps', 'Shoes'])
              TextButton(onPressed: demo.notice, child: Text(name)),
            const DialogClose(child: TextButton(child: Text('Done'))),
          ],
        ),
      ),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            DialogTrigger(
              id: 'demo-filters',
              hiddenFrom: WindowSizeClass.medium,
              child: OutlinedButton(child: Text('Filters')),
            ),
            Text('Results: 12 products'),
          ],
        ),
      ),
    ],
  );
}
// endregion

// ---------------------------------------------------------------------- Drawer

/// What the Drawer panel controls.
class DrawerViewModel extends ThorState {
  /// Whether it opens from the end edge.
  final fromEnd = state(false);

  /// The width, in steps of 40 from 240.
  final width = state(1);

  /// The number next to the width Level.
  String widthText() => '${240 + width.value * 40} px';

  /// The `side` line of the Code view.
  String sideCode() => 'side: DrawerSide.${fromEnd.value ? 'end' : 'start'},';

  /// The `width` line.
  String widthCode() => 'width: ${240 + width.value * 40},';

  /// What the side Switch calls.
  void setFromEnd(Set<bool> value) => fromEnd.value = value.first;

  /// What the width Level calls.
  void setWidth(double value) => width.value = ((value - 240) / 40).round();
}

/// One instance, at the top level.
final drawer = DrawerViewModel();

/// `cat-drawer`.
final drawerBench = BenchExample(
  title: (t) => t.exNavDrawerTitle,
  description: (t) => t.exNavDrawerDescription,
  stage: const _DrawerStage(),
  code: BenchCode([
    const BenchCodeLine('DialogTrigger('),
    const BenchCodeLine('dialog: Drawer(', indent: 1),
    BenchCodeLine.live(drawer.sideCode, indent: 2),
    BenchCodeLine.live(drawer.widthCode, indent: 2),
    const BenchCodeLine("label: 'Main menu',", indent: 2),
    const BenchCodeLine(
      'child: Column(children: [ListTile(href: …)]),',
      indent: 2,
    ),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine(
      "child: OutlinedButton(child: Text('Open menu')),",
      indent: 1,
    ),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchSwitch<bool>(
      label: (t) => t.exNavSide,
      value: drawer.fromEnd.value,
      onChanged: drawer.setFromEnd,
      segments: [
        BenchSegment(false, label: (t) => t.exNavSideStart),
        BenchSegment(true, label: (t) => t.exNavSideEnd),
      ],
    ),
    pxLevel(
      label: (t) => t.exCatSize,
      value: 240 + drawer.width.value * 40,
      min: 240,
      max: 360,
      divisions: 3,
      onChanged: drawer.setWidth,
      valueText: drawer.widthText,
    ),
  ],
);

class _DrawerStage extends StatelessWidget {
  const _DrawerStage();

  @override
  Widget build(BuildContext context) {
    return Watch.field(
      drawer.fromEnd,
      builder: (fromEnd) => Watch.field(
        drawer.width,
        count: 4,
        builder: (step) {
          final px = 240.0 + step * 40;
          // The drawer is closed until the button opens it: the preview draws
          // it open on a window, at the real width (scaled to a half).
          final panel = Container(
            width: px / 2,
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: ThemeColor.surfaceContainerLow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                const Text(
                  'My shop',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ThemeColor.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Components',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                const Text('Notices', style: TextStyle(fontSize: 11)),
              ],
            ),
          );
          const scrim = Expanded(child: Container(color: Color(0x52000000)));
          return Column(
            spacing: 12,
            children: [
              PreviewFrame(
                padding: EdgeInsets.zero,
                child: SizedBox(
                  height: 150,
                  child: Row(
                    children: fromEnd ? [scrim, panel] : [panel, scrim],
                  ),
                ),
              ),
              NoteRow(label: 'Size', value: Text('${px.round()} px')),
              Column(
                children: [
                  DialogTrigger(
                    child: const OutlinedButton(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 8,
                        children: [
                          Icon(Icons.menu, size: 18),
                          Text('Open menu'),
                        ],
                      ),
                    ),
                    dialog: Drawer(
                      side: fromEnd ? DrawerSide.end : DrawerSide.start,
                      width: 240.0 + step * 40,
                      label: 'Main menu',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: Text(
                              'My shop',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.home),
                            title: const Text('Components'),
                            selected: true,
                            href: context.localized('/componentes/componentes'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.mail),
                            title: const Text('Notices'),
                            href: context.localized(
                              '/componentes/componentes-avisos',
                            ),
                          ),
                          const Spacer(),
                          const DialogClose(
                            child: TextButton(child: Text('Close')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// --------------------------------------------------------------- NavigationBar

/// How the labels of a bar or a rail show.
enum LabelMode {
  /// Every label.
  all,

  /// Only the selected one.
  selected,

  /// None.
  none,
}

/// What the NavigationBar panel controls.
class BarViewModel extends ThorState {
  /// The selected destination.
  final index = state(0);

  /// The labels.
  final labels = state(LabelMode.all);

  /// How many destinations beyond the first two (0 to 2).
  final extra = state(1);

  /// The number next to the destinations Level.
  String countText() => '${2 + extra.value}';

  /// The `selectedIndex` line of the Code view.
  String indexCode() => 'selectedIndex: ${index.value},';

  /// The `labelBehavior` line.
  String labelsCode() {
    final name = switch (labels.value) {
      LabelMode.all => 'alwaysShow',
      LabelMode.selected => 'onlyShowSelected',
      LabelMode.none => 'alwaysHide',
    };
    return 'labelBehavior: NavigationDestinationLabelBehavior.$name,';
  }

  /// The `destinations` line.
  String destinationsCode() {
    final names = ['Home', 'Search', 'Profile', 'Alerts'];
    final shown = [
      for (var i = 0; i < 2 + extra.value; i++)
        "NavigationDestination(icon: …, label: '${names[i]}')",
    ];
    return 'destinations: [${shown.join(', ')}],';
  }

  /// What the bar calls with the tapped index.
  void select(int value) => index.value = value;

  /// What the labels Switch calls.
  void setLabels(Set<LabelMode> value) => labels.value = value.first;

  /// What the destinations Level calls.
  void setCount(double value) {
    extra.value = value.round() - 2;
    if (index.value > extra.value + 1) index.value = extra.value + 1;
  }
}

/// One instance, at the top level.
final bar = BarViewModel();

/// `cat-navigation-bar`.
final navigationBarBench = BenchExample(
  title: (t) => t.exNavBarTitle,
  description: (t) => t.exNavBarDescription,
  stage: const _BarStage(),
  code: BenchCode([
    const BenchCodeLine('NavigationBar('),
    BenchCodeLine.live(bar.indexCode, indent: 1),
    const BenchCodeLine('onDestinationSelected: bar.select,', indent: 1),
    BenchCodeLine.live(bar.labelsCode, indent: 1),
    BenchCodeLine.live(bar.destinationsCode, indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    BenchSwitch<LabelMode>(
      label: (t) => t.exNavLabels,
      value: bar.labels.value,
      onChanged: bar.setLabels,
      segments: [
        BenchSegment(LabelMode.all, label: (t) => t.exNavLabelsAll),
        BenchSegment(LabelMode.selected, label: (t) => t.exNavLabelsSelected),
        BenchSegment(LabelMode.none, label: (t) => t.exNavLabelsNone),
      ],
    ),
    BenchLevel(
      label: (t) => t.exNavDestinations,
      value: bar.extra.value + 2,
      min: 2,
      max: 4,
      divisions: 2,
      onChanged: bar.setCount,
      valueText: bar.countText,
    ),
  ],
);

class _BarStage extends StatelessWidget {
  const _BarStage();

  @override
  Widget build(BuildContext context) {
    const names = ['Home', 'Search', 'Profile', 'Alerts'];
    const icons = [Icons.home, Icons.search, Icons.person, Icons.notifications];
    return SizedBox(
      width: 360,
      child: Watch.field(
        bar.labels,
        builder: (labels) => Watch.field(
          bar.extra,
          count: 3,
          builder: (extra) => Watch.field(
            bar.index,
            count: 4,
            builder: (i) {
              final n = 2 + extra;
              final selected = i < n ? i : n - 1;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 96,
                    alignment: Alignment.center,
                    child: Text(
                      names[selected],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  NavigationBar(
                    selectedIndex: selected,
                    onDestinationSelected: bar.select,
                    labelBehavior: switch (labels) {
                      LabelMode.all =>
                        NavigationDestinationLabelBehavior.alwaysShow,
                      LabelMode.selected =>
                        NavigationDestinationLabelBehavior.onlyShowSelected,
                      LabelMode.none =>
                        NavigationDestinationLabelBehavior.alwaysHide,
                    },
                    destinations: [
                      for (var d = 0; d < n; d++)
                        NavigationDestination(
                          icon: Icon(icons[d]),
                          label: names[d],
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- NavigationRail

/// What the NavigationRail panel controls.
class RailViewModel extends ThorState {
  /// The selected destination.
  final index = state(0);

  /// The labels.
  final labels = state(LabelMode.all);

  /// Whether the rail is extended (text beside the icon).
  final extended = state(false);

  /// The `selectedIndex` line of the Code view.
  String indexCode() => 'selectedIndex: ${index.value},';

  /// The `labelType` line.
  String labelsCode() => extended.value
      ? '// labelType: none (an extended rail writes its labels)'
      : 'labelType: NavigationRailLabelType.${labels.value.name},';

  /// The `extended` line.
  String extendedCode() => 'extended: ${extended.value},';

  /// What the rail calls with the tapped index.
  void select(int value) => index.value = value;

  /// What the labels Switch calls.
  void setLabels(Set<LabelMode> value) => labels.value = value.first;

  /// What the extended Switch calls.
  void setExtended(bool value) => extended.value = value;
}

/// One instance, at the top level.
final rail = RailViewModel();

/// `cat-navigation-rail`.
final navigationRailBench = BenchExample(
  title: (t) => t.exNavRailTitle,
  description: (t) => t.exNavRailDescription,
  stage: const _RailStage(),
  code: BenchCode([
    const BenchCodeLine('NavigationRail('),
    BenchCodeLine.live(rail.indexCode, indent: 1),
    const BenchCodeLine('onDestinationSelected: rail.select,', indent: 1),
    BenchCodeLine.live(rail.labelsCode, indent: 1),
    BenchCodeLine.live(rail.extendedCode, indent: 1),
    const BenchCodeLine(
      'destinations: [NavigationRailDestination(icon: …, label: …), …],',
      indent: 1,
    ),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchSwitch<LabelMode>(
      label: (t) => t.exNavLabels,
      value: rail.labels.value,
      onChanged: rail.setLabels,
      segments: [
        BenchSegment(LabelMode.all, label: (t) => t.exNavLabelsAll),
        BenchSegment(LabelMode.selected, label: (t) => t.exNavLabelsSelected),
        BenchSegment(LabelMode.none, label: (t) => t.exNavLabelsNone),
      ],
    ),
    boolSwitch(
      label: (t) => t.exNavExtended,
      value: rail.extended.value,
      onChanged: rail.setExtended,
    ),
  ],
);

class _RailStage extends StatelessWidget {
  const _RailStage();

  @override
  Widget build(BuildContext context) {
    const names = ['Home', 'Search', 'Profile'];
    const icons = [Icons.home, Icons.search, Icons.person];
    return SizedBox(
      width: 360,
      height: 220,
      child: Watch.field(
        rail.labels,
        builder: (labels) => Watch.field(
          rail.extended,
          builder: (extended) => Watch.field(
            rail.index,
            count: 3,
            builder: (i) => Row(
              children: [
                NavigationRail(
                  selectedIndex: i,
                  onDestinationSelected: rail.select,
                  extended: extended,
                  // `// web:` as in Flutter, an extended rail has no `labelType`.
                  labelType: extended
                      ? NavigationRailLabelType.none
                      : switch (labels) {
                          LabelMode.all => NavigationRailLabelType.all,
                          LabelMode.selected =>
                            NavigationRailLabelType.selected,
                          LabelMode.none => NavigationRailLabelType.none,
                        },
                  destinations: [
                    for (var d = 0; d < 3; d++)
                      NavigationRailDestination(
                        icon: Icon(icons[d]),
                        label: Text(names[d]),
                      ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      names[i],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------ Link

/// What the Link panel controls.
class LinkViewModel extends ThorState {
  /// Whether it points outside the site.
  final external = state(false);

  /// Whether it opens in another tab.
  final newTab = state(false);

  /// Whether it marks the current page.
  final current = state(false);

  /// The `href` line of the Code view.
  String hrefCode() => external.value
      ? "href: RouteUrl.external('https://dart.dev'),"
      : "href: const RouteUrl('/components/notices'),";

  /// The `child` line, with the text the stage shows.
  String childCode() =>
      "child: Row(children: [Icon(Icons.star), Text('${external.value ? 'dart.dev' : 'Next: notices'}')]),";

  /// The `newTab` line.
  String newTabCode() => 'newTab: ${newTab.value},';

  /// The `current` line.
  String currentCode() => 'current: ${current.value},';

  /// What the external Switch calls.
  void setExternal(bool value) => external.value = value;

  /// What the newTab Switch calls.
  void setNewTab(bool value) => newTab.value = value;

  /// What the current Switch calls.
  void setCurrent(bool value) => current.value = value;
}

/// The text of the Link example.
String linkLabel({required bool external}) =>
    external ? 'dart.dev' : 'Next: notices';

/// One instance, at the top level.
final link = LinkViewModel();

/// `cat-link`.
final linkBench = BenchExample(
  title: (t) => t.exNavLinkTitle,
  description: (t) => t.exNavLinkDescription,
  stage: const _LinkStage(),
  code: BenchCode([
    const BenchCodeLine('Link('),
    BenchCodeLine.live(link.hrefCode, indent: 1),
    BenchCodeLine.live(link.newTabCode, indent: 1),
    BenchCodeLine.live(link.currentCode, indent: 1),
    BenchCodeLine.live(link.childCode, indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    boolSwitch(
      label: (t) => t.exNavExternal,
      value: link.external.value,
      onChanged: link.setExternal,
    ),
    boolSwitch(
      label: (t) => t.exNavNewTab,
      value: link.newTab.value,
      onChanged: link.setNewTab,
    ),
    boolSwitch(
      label: (t) => t.exNavCurrent,
      value: link.current.value,
      onChanged: link.setCurrent,
    ),
  ],
);

class _LinkStage extends StatelessWidget {
  const _LinkStage();

  @override
  Widget build(BuildContext context) {
    final internal = context.localized('/componentes/componentes-avisos');
    return Watch.field(
      link.external,
      builder: (external) => Watch.field(
        link.newTab,
        builder: (newTab) => Watch.field(
          link.current,
          builder: (current) {
            final href = external ? 'https://dart.dev' : internal;
            // `// web:` what the link carries is attributes, not a look: the
            // page shows the `<a>` it wrote.
            final tag = StringBuffer('<a href="$href"');
            if (newTab) tag.write(' target="_blank" rel="noopener"');
            if (current) tag.write(' aria-current="page"');
            tag.write('>');
            return Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 14,
              children: [
                Link(
                  href: RouteUrl(href),
                  newTab: newTab,
                  current: current,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      const Icon(Icons.star, size: 18),
                      Text(
                        linkLabel(external: external),
                        style: const TextStyle(
                          color: ThemeColor.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
                CodeNote(label: 'Element', code: tag.toString()),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ ModalBottomSheet

/// What the ModalBottomSheet panel controls.
class SheetViewModel extends ThorState {
  /// Whether the drag handle shows.
  final handle = state(true);

  /// How many options beyond the first (0 to 2).
  final extra = state(1);

  /// The number next to the options Level.
  String countText() => '${1 + extra.value}';

  /// The `showDragHandle` line of the Code view.
  String handleCode() => 'showDragHandle: ${handle.value},';

  /// The `child` line.
  String itemsCode() =>
      'child: Column(children: [… ${1 + extra.value} ListTile …]),';

  /// What the handle Switch calls.
  void setHandle(bool value) => handle.value = value;

  /// What the options Level calls.
  void setCount(double value) => extra.value = value.round() - 1;
}

/// One instance, at the top level.
final sheet = SheetViewModel();

/// `cat-bottom-sheet`.
final bottomSheetBench = BenchExample(
  title: (t) => t.exNavSheetTitle,
  description: (t) => t.exNavSheetDescription,
  stage: const _SheetStage(),
  code: BenchCode([
    const BenchCodeLine('DialogTrigger('),
    const BenchCodeLine('dialog: ModalBottomSheet(', indent: 1),
    BenchCodeLine.live(sheet.handleCode, indent: 2),
    const BenchCodeLine("label: 'Share',", indent: 2),
    BenchCodeLine.live(sheet.itemsCode, indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine(
      "child: FilledButton(child: Text('Share')),",
      indent: 1,
    ),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    boolSwitch(
      label: (t) => t.exNavDragHandle,
      value: sheet.handle.value,
      onChanged: sheet.setHandle,
    ),
    BenchLevel(
      label: (t) => t.exNavOptions,
      value: sheet.extra.value + 1,
      min: 1,
      max: 3,
      divisions: 2,
      onChanged: sheet.setCount,
      valueText: sheet.countText,
    ),
  ],
);

class _SheetStage extends StatelessWidget {
  const _SheetStage();

  @override
  Widget build(BuildContext context) {
    return Watch.field(
      sheet.handle,
      builder: (handle) => Watch.field(
        sheet.extra,
        count: 3,
        builder: (extra) {
          final options = [
            (Icons.mail, 'Mail'),
            (Icons.send, 'Message'),
            (Icons.star, 'Save'),
          ];
          // The sheet is closed until the button opens it: the preview draws
          // it open at the bottom of a window.
          final sheetView = Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: const BoxDecoration(
              color: ThemeColor.surfaceContainerLow,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                if (handle)
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: ThemeColor.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                for (final (icon, label) in options.take(1 + extra))
                  Row(
                    spacing: 12,
                    children: [Icon(icon, size: 18), Text(label)],
                  ),
              ],
            ),
          );
          return Column(
            spacing: 12,
            children: [
              PreviewFrame(
                padding: EdgeInsets.zero,
                child: Container(
                  height: 190,
                  color: const Color(0x52000000),
                  alignment: Alignment.bottomCenter,
                  child: sheetView,
                ),
              ),
              Column(
                children: [
                  DialogTrigger(
                    child: const FilledButton(child: Text('Share')),
                    dialog: ModalBottomSheet(
                      // web: the variants swap the sheet's content, not the
                      // sheet: one id for all of them, named by its button
                      // too (a reader's app, without variants, needs neither).
                      id: 'cat-share-sheet',
                      showDragHandle: handle,
                      label: 'Share',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const ListTile(
                            leading: Icon(Icons.mail),
                            title: Text('Mail'),
                          ),
                          if (extra >= 1)
                            const ListTile(
                              leading: Icon(Icons.send),
                              title: Text('Message'),
                            ),
                          if (extra >= 2)
                            const ListTile(
                              leading: Icon(Icons.star),
                              title: Text('Save'),
                            ),
                          const DialogClose(
                            id: 'cat-share-sheet',
                            child: TextButton(child: Text('Cancel')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// --------------------------------------------------------- CustomScrollView

// region: nav-slivers
class SliversDemo extends StatelessWidget {
  const SliversDemo({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 340,
    height: 320,
    child: CustomScrollView(
      slivers: [
        const SliverAppBar(
          pinned: true,
          expandedHeight: 140,
          title: Text('Orders'),
          flexibleSpace: ColoredBox(
            color: ThemeColor.secondaryContainer,
            child: SizedBox.expand(),
          ),
        ),
        SliverList.builder(
          itemCount: 24,
          itemBuilder: (context, i) => ListTile(title: Text('Order #$i')),
        ),
      ],
    ),
  );
}

// endregion
