// Fixture: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
// The pages of the browser checks that need no app (tool/thor e2e drawer):
// each is rendered like a request would, and written as `<name>.html` in the
// directory given (`dart run tool/e2e_pages.dart <dir>`).
import 'dart:io';

import 'package:thor_ui/src/engine/engine_script.dart' show EngineScript;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

/// A Scaffold with a drawer and an end drawer: no ids anywhere.
class _DrawerPage extends StatelessWidget {
  const _DrawerPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppBar(title: Text('Fixture')),
    drawer: Drawer(
      label: 'Main menu',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Link(
            // The page has a `<base href="/">`: a bare `#inside` would leave it.
            href: RouteUrl('/drawer.html#inside'),
            child: Padding(padding: EdgeInsets.all(12), child: Text('Inside')),
          ),
          DialogClose(
            child: TextButton(onPressed: () {}, child: const Text('Close')),
          ),
        ],
      ),
    ),
    endDrawer: Drawer(
      label: 'Settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Settings body'),
          DialogClose(
            child: TextButton(
              onPressed: () {},
              child: const Text('Close settings'),
            ),
          ),
        ],
      ),
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton(onPressed: () {}, child: const Text('Behind')),
        // Dialogs with no id inside a list: keys name them.
        for (final n in [1, 2, 3])
          AlertDialog(
            key: ValueKey(n),
            title: Text('Dialog $n'),
            actions: [
              DialogClose(
                child: TextButton(onPressed: () {}, child: Text('Close $n')),
              ),
            ],
          ),
        DialogTrigger(
          id: 'dlg-2',
          child: FilledButton(onPressed: () {}, child: const Text('Open 2')),
        ),
      ],
    ),
  );
}

/// A state whose code calls `toast(…)` and one that calls `confirm(…)`: the
/// build lists that in `uses`, and the page then ships the snack bar, the
/// dialog and their inline scripts (the check calls `document.thorToast` and
/// `document.thorConfirm`, what the engine's `toast`/`confirm` do).
class _TellsState extends ThorState {
  @override
  String get $type => 'TellsState';

  @override
  Set<String> get uses => const {'toast', 'confirm'};

  @override
  List<ThorMember> get $members => [
    ThorMember('save', save, call: (_) => save()),
  ];

  void save() {}
}

final _tells = _TellsState();

/// A drawer whose items toast, a dialog with an id, and the page's shared
/// snack bar and confirm dialog: the snack bar over modals.
class _ToastPage extends StatelessWidget {
  const _ToastPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppBar(title: Text('Toasts')),
    drawer: Drawer(
      label: 'Main menu',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DialogClose(
            child: ListTile(onTap: _tells.save, title: const Text('Settings')),
          ),
          ListTile(onTap: _tells.save, title: const Text('Stays open')),
        ],
      ),
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton(onPressed: _tells.save, child: const Text('Save')),
        DialogTrigger(
          id: 'mine',
          child: FilledButton(onPressed: () {}, child: const Text('Open mine')),
        ),
        const AlertDialog(id: 'mine', title: Text('Mine'), actions: []),
      ],
    ),
  );
}

/// GridView.extent at several widths, and an IndexedStack with inputs.
class _GridPage extends StatelessWidget {
  const _GridPage();

  static List<Widget> _tiles(int n) => [
    for (var i = 0; i < n; i++) const Container(color: Color(0xFFCCDDEE)),
  ];

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 300,
        child: GridView.extent(
          key: const ValueKey('plain'),
          maxCrossAxisExtent: 200,
          children: _tiles(30),
        ),
      ),
      SizedBox(
        height: 300,
        child: GridView.extent(
          key: const ValueKey('spaced'),
          maxCrossAxisExtent: 150,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: _tiles(30),
        ),
      ),
      SizedBox(
        width: 330,
        height: 300,
        child: GridView(
          key: const ValueKey('narrow'),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 100,
            crossAxisSpacing: 6,
          ),
          children: _tiles(30),
        ),
      ),
      const IndexedStack(
        index: 1,
        children: [
          Column(children: [TextField(key: ValueKey('a'))]),
          Column(children: [TextField(key: ValueKey('b'))]),
        ],
      ),
    ],
  );
}

/// Full-width carousels: arrows inside, arrows outside (nothing past the
/// viewport), dots, and an autoplaying one.
class _CarouselPage extends StatelessWidget {
  const _CarouselPage();

  static List<Widget> _slides(String name) => [
    for (final (i, c) in const [
      Color(0xFFCCDDEE),
      Color(0xFFEEDDCC),
      Color(0xFFDDEECC),
      Color(0xFFEECCDD),
    ].indexed)
      Container(height: 160, color: c, child: Text('$name ${i + 1}')),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CarouselView(
        key: const ValueKey('hero'),
        label: 'Hero',
        showIndicators: true,
        arrowStyle: IconButton.styleFrom(
          backgroundColor: const Color(0xFF1B2A6B),
          foregroundColor: const Color(0xFFFFFFFF),
          minimumSize: const Size.square(34),
        ),
        indicatorStyle: const CarouselIndicatorStyle(
          color: Color(0xFFCCCCCC),
          activeColor: Color(0xFF1B2A6B),
        ),
        children: _slides('hero'),
      ),
      const Text('after hero'),
      CarouselView(
        key: const ValueKey('outside'),
        label: 'Outside',
        arrowPosition: CarouselArrowPosition.outside,
        layout: const CarouselLayout(itemsPerView: 2),
        children: _slides('outside'),
      ),
      const Text('after outside'),
      CarouselView(
        key: const ValueKey('plain'),
        label: 'Plain',
        showArrows: false,
        children: _slides('plain'),
      ),
      CarouselView(
        key: const ValueKey('icon'),
        label: 'Icon',
        arrowIcon: const IconData.svg(
          'e2e-forward',
          '<path d="M8 4l8 8-8 8"/>',
        ),
        arrowInset: 20,
        children: _slides('icon'),
      ),
      CarouselView(
        key: const ValueKey('auto'),
        label: 'Auto',
        autoPlay: const Duration(milliseconds: 400),
        showArrows: false,
        children: _slides('auto'),
      ),
    ],
  );
}

/// One carousel and nothing else: the page ships the engine only where the
/// browser draws no arrows of its own.
class _StaticCarouselPage extends StatelessWidget {
  const _StaticCarouselPage();

  @override
  Widget build(BuildContext context) => CarouselView(
    label: 'Static',
    showIndicators: true,
    children: _CarouselPage._slides('static'),
  );
}

/// A carousel (the head carries the conditional loader) and the engine's own
/// loader after it, as a streamed piece that also needs the engine brings it:
/// a browser without `::scroll-button` must still download the engine once.
class _LateEngineCarouselPage extends StatelessWidget {
  const _LateEngineCarouselPage();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      CarouselView(
        label: 'Late',
        showIndicators: true,
        children: _CarouselPage._slides('late'),
      ),
      const EngineScript(),
    ],
  );
}

/// Edge cases of the fallback controls: a carousel of items wider than the
/// viewport, two with controls side by side, and one with autoplay and
/// controls together.
class _CarouselEdgePage extends StatelessWidget {
  const _CarouselEdgePage();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CarouselView(
        label: 'Wide',
        showIndicators: true,
        itemExtent: 600,
        children: _CarouselPage._slides('wide').take(3).toList(),
      ),
      CarouselView(
        label: 'A',
        showIndicators: true,
        children: _CarouselPage._slides('a'),
      ),
      CarouselView(
        label: 'B',
        showIndicators: true,
        children: _CarouselPage._slides('b'),
      ),
      CarouselView(
        label: 'Both',
        showIndicators: true,
        autoPlay: const Duration(milliseconds: 400),
        children: _CarouselPage._slides('both'),
      ),
      CarouselView(
        label: 'One',
        showIndicators: true,
        children: _CarouselPage._slides('one').take(1).toList(),
      ),
    ],
  );
}

abstract class _LiveMembers extends ThorState {
  @override
  String get $type => 'LiveSlides';

  @override
  List<ThorMember> get $members {
    final s = this as LiveSlides;
    return [
      ThorMember.state('slides', s.slides),
      ThorMember(
        'idOf',
        s.idOf,
        arity: 1,
        callWithItem: (i) => s.idOf(i as int),
      ),
    ];
  }
}

/// The state of [_LiveCarouselPage]: no rows when the server draws it.
class LiveSlides extends _LiveMembers {
  final slides = state<List<int>>(const []);
  int idOf(int n) => n;
}

/// A carousel whose items are a live list: the server draws only the row
/// template; the check adds rows in the browser, as the engine would.
class _LiveCarouselPage extends StatelessWidget {
  const _LiveCarouselPage();

  @override
  Widget build(BuildContext context) => Watch.list(
    LiveSlides().slides.call,
    itemKey: LiveSlides().idOf,
    container: (rows) => CarouselView(
      label: 'Live',
      showIndicators: true,
      indicatorStyle: const CarouselIndicatorStyle(
        color: Color(0xFFCCCCCC),
        activeColor: Color(0xFF1B2A6B),
        size: 12,
        activeSize: Size(48, 12),
      ),
      arrowStyle: IconButton.styleFrom(
        backgroundColor: const Color(0xFF1B2A6B),
        foregroundColor: const Color(0xFFFFFFFF),
        minimumSize: const Size.square(44),
        iconSize: 28,
      ),
      children: rows,
    ),
    each: (row) => const Container(height: 160, child: Text('live')),
  );
}

/// PageViews: free, vertical, locked, and one with a link in a page.
class _PageViewPage extends StatelessWidget {
  const _PageViewPage();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      Container(
        height: 160,
        width: 300,
        child: PageView(
          key: ValueKey('free'),
          children: [Text('one'), Text('two'), Text('three')],
        ),
      ),
      Container(
        height: 160,
        width: 300,
        child: PageView(
          key: ValueKey('vertical'),
          scrollDirection: Axis.vertical,
          children: [Text('a'), Text('b')],
        ),
      ),
      Container(
        height: 160,
        width: 300,
        child: PageView(
          key: ValueKey('locked'),
          physics: NeverScrollableScrollPhysics(),
          children: [Text('x'), Text('y')],
        ),
      ),
      Container(
        height: 160,
        width: 300,
        child: PageView(
          key: ValueKey('links'),
          children: [
            Text('first'),
            Link(href: RouteUrl('#second'), child: Text('second page link')),
          ],
        ),
      ),
    ],
  );
}

/// A login group outside any form, and one inside a dialog.
class _AutofillPage extends StatelessWidget {
  const _AutofillPage();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AutofillGroup(
        child: Column(
          children: [
            const TextField(
              id: 'user',
              name: 'user',
              autofillHints: [AutofillHints.username],
            ),
            const TextField(
              id: 'pass',
              name: 'pass',
              obscureText: true,
              autofillHints: [AutofillHints.password],
            ),
            FilledButton(
              buttonType: ButtonType.submit,
              onPressed: () {},
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
      const AutofillGroup(
        section: 'billing',
        child: TextField(
          id: 'zip',
          name: 'zip',
          autofillHints: ['shipping', AutofillHints.postalCode],
        ),
      ),
      DialogTrigger(
        id: 'login',
        child: FilledButton(onPressed: () {}, child: const Text('Open')),
      ),
      const AlertDialog(
        id: 'login',
        content: AutofillGroup(
          child: TextField(
            id: 'dlguser',
            name: 'dlguser',
            autofillHints: [AutofillHints.username],
          ),
        ),
      ),
    ],
  );
}

/// The theme switch with a link to the other page (`theme-persist`).
class _ThemePage extends StatelessWidget {
  const _ThemePage(this.title, this.next);

  final String title;
  final String next;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(title),
      const ThemeToggle(light: Text('sun'), dark: Text('moon')),
      Link(href: RouteUrl(next), child: const Text('Next page')),
    ],
  );
}

/// One product grid: two fluid columns on a phone, fixed 260 px tracks with a
/// 73 px gap from md.
class _AdaptiveGridPage extends StatelessWidget {
  const _AdaptiveGridPage();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Grid(
      layout: const GridLayout(
        columns: 2,
        gap: 16,
      ).when(medium: const GridLayout(columnWidth: 260, gap: 73)),
      children: [
        for (var i = 0; i < 8; i++)
          Container(
            height: 80,
            color: const Color(0xFFCCCCCC),
            child: Text('card $i'),
          ),
      ],
    ),
  );
}

/// The grid tracks under attack: a column wider than its box, a gap
/// larger than the space, every alignment, container thresholds that are not
/// whole, many breakpoint variants and an item that takes the row. Every block
/// names its items `<case>-<n>`.
class _GridAttacksPage extends StatelessWidget {
  const _GridAttacksPage();

  static Widget _cell(String name, int i) => Container(
    height: 40,
    color: const Color(0xFFCCCCCC),
    child: Text('$name-$i'),
  );

  static List<Widget> _cells(String name, int n) => [
    for (var i = 0; i < n; i++) _cell(name, i),
  ];

  static Widget _aligned(String name, WrapAlignment a) => SizedBox(
    width: 1000,
    child: Grid(
      layout: GridLayout(columnWidth: 200, gap: 20, alignment: a),
      children: _cells(name, 3),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // A column wider than its box: one column that is the box.
      SizedBox(
        width: 300,
        child: Grid(
          layout: const GridLayout(columnWidth: 500, gap: 20),
          children: _cells('wide', 2),
        ),
      ),
      // A gap larger than the room: still one column, nothing sticks out.
      SizedBox(
        width: 390,
        child: Grid(
          layout: const GridLayout(columnWidth: 260, gap: 400),
          children: _cells('gap', 2),
        ),
      ),
      _aligned('start', WrapAlignment.start),
      _aligned('center', WrapAlignment.center),
      _aligned('end', WrapAlignment.end),
      _aligned('between', WrapAlignment.spaceBetween),
      // Placement: an item that runs the whole row, however many tracks fit.
      SizedBox(
        width: 700,
        child: Grid(
          layout: const GridLayout(columnWidth: 200, gap: 20),
          children: [
            GridItem(
              placement: const GridPlacement(columnStart: 1, columnEnd: -1),
              child: _cell('full', 0),
            ),
            _cell('full', 1),
          ],
        ),
      ),
      // Container thresholds that are not whole, written out of order.
      SizedBox(
        width: 1000,
        child: LayoutScope(
          child: Grid(
            layout: const GridLayout(columns: 1).when(
              container: {
                925.5: const GridLayout(columnWidth: 100),
                592.02: const GridLayout(columns: 2),
                400: const GridLayout(columns: 3),
              },
            ),
            children: _cells('cont', 6),
          ),
        ),
      ),
      // Many variants: the larger breakpoint wins.
      Grid(
        layout: const GridLayout(columns: 1).when(
          medium: const GridLayout(columns: 2),
          expanded: const GridLayout(columns: 3),
          large: const GridLayout(columnWidth: 150),
          extraLarge: const GridLayout(columns: 5),
        ),
        children: _cells('many', 6),
      ),
    ],
  );
}

/// `GridView` under the same attack: its own columns, then a variant on top.
class _GridViewAttacksPage extends StatelessWidget {
  const _GridViewAttacksPage();

  static List<Widget> _cells(String name) => [
    for (var i = 0; i < 6; i++)
      Container(color: const Color(0xFFCCCCCC), child: Text('$name-$i')),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        layout: const GridLayout().when(
          medium: const GridLayout(columnWidth: 260, gap: 73),
        ),
        children: _cells('count'),
      ),
      GridView.extent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 16,
        layout: const GridLayout().when(
          medium: const GridLayout(columnWidth: 260, gap: 73),
        ),
        children: _cells('extent'),
      ),
      GridView.extent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 16,
        layout: const GridLayout().when(medium: const GridLayout(columns: 2)),
        children: _cells('extcols'),
      ),
      // Per-breakpoint aspect ratio: the tiles are 1:1, then 2:1 from md.
      GridView.count(
        crossAxisCount: 2,
        layout: const GridLayout().when(
          medium: const GridLayout(columns: 3, childAspectRatio: 2),
        ),
        children: [
          for (var i = 0; i < 6; i++)
            Container(color: const Color(0xFFCCCCCC), child: Text('ratio-$i')),
        ],
      ),
    ],
  );
}

/// Two permanent drawers on one page, one on each side, the first taller than
/// the page's content.
class _DrawerAttacksPage extends StatelessWidget {
  const _DrawerAttacksPage();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Drawer(
        id: 'left',
        permanentFrom: WindowSizeClass.medium,
        label: 'Start panel',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Start panel'),
            for (var i = 0; i < 12; i++)
              TextButton(onPressed: () {}, child: Text('S$i')),
            DialogClose(
              child: TextButton(onPressed: () {}, child: const Text('Done S')),
            ),
          ],
        ),
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DialogTrigger(
              id: 'left',
              hiddenFrom: WindowSizeClass.medium,
              child: FilledButton(
                onPressed: () {},
                child: const Text('Open start'),
              ),
            ),
            DialogTrigger(
              id: 'right',
              hiddenFrom: WindowSizeClass.medium,
              child: FilledButton(
                onPressed: () {},
                child: const Text('Open end'),
              ),
            ),
            const Text('Content'),
            FilledButton(onPressed: () {}, child: const Text('Behind')),
          ],
        ),
      ),
      Drawer(
        id: 'right',
        side: DrawerSide.end,
        permanentFrom: WindowSizeClass.medium,
        label: 'End panel',
        width: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('End panel'),
            TextButton(onPressed: () {}, child: const Text('E0')),
          ],
        ),
      ),
    ],
  );
}

/// A scaffold whose drawer is a panel from md and whose end drawer is one from
/// lg.
class _ScaffoldPermanentPage extends StatelessWidget {
  const _ScaffoldPermanentPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppBar(title: Text('Home')),
    drawer: Drawer(
      id: 'nav',
      permanentFrom: WindowSizeClass.medium,
      label: 'Navigation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Navigation'),
          TextButton(onPressed: () {}, child: const Text('Nav one')),
          DialogClose(
            child: TextButton(onPressed: () {}, child: const Text('Close nav')),
          ),
        ],
      ),
    ),
    endDrawer: Drawer(
      id: 'info',
      permanentFrom: WindowSizeClass.expanded,
      label: 'Details',
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Details'),
          TextButton(onPressed: () {}, child: const Text('Info one')),
        ],
      ),
    ),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Body text'),
          FilledButton(onPressed: () {}, child: const Text('Behind')),
        ],
      ),
    ),
    bottomNavigationBar: const Padding(
      padding: EdgeInsets.all(8),
      child: Text('Footer text'),
    ),
  );
}

/// A filter panel written once: a modal drawer on a phone, an inline panel
/// from md.
class _PermanentDrawerPage extends StatelessWidget {
  const _PermanentDrawerPage();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Drawer(
        id: 'filters',
        permanentFrom: WindowSizeClass.medium,
        label: 'Filters',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Filter list'),
            TextButton(onPressed: () {}, child: const Text('Brand A')),
            DialogClose(
              child: TextButton(onPressed: () {}, child: const Text('Done')),
            ),
          ],
        ),
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DialogTrigger(
              id: 'filters',
              hiddenFrom: WindowSizeClass.medium,
              child: FilledButton(
                onPressed: () {},
                child: const Text('Show filters'),
              ),
            ),
            const Text('Results'),
            FilledButton(onPressed: () {}, child: const Text('Behind')),
          ],
        ),
      ),
    ],
  );
}

/// A drawer that is a 320 px modal and a 200 px inline panel, and
/// footer tiles that are an accordion on a phone and open from md.
class _StoreGapsPage extends StatelessWidget {
  const _StoreGapsPage();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Drawer(
        id: 'side',
        permanentFrom: WindowSizeClass.medium,
        width: 320,
        permanentWidth: 200,
        permanentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        label: 'Side',
        child: Text('Side panel'),
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DialogTrigger(
              id: 'side',
              hiddenFrom: WindowSizeClass.medium,
              child: FilledButton(
                onPressed: () {},
                child: const Text('Open side'),
              ),
            ),
            const ExpansionTile(
              key: ValueKey('help'),
              permanentFrom: WindowSizeClass.medium,
              title: Text('Help'),
              children: [Text('Shipping and returns')],
            ),
            const ExpansionTile(
              key: ValueKey('plain'),
              title: Text('Plain'),
              children: [Text('Always an accordion')],
            ),
          ],
        ),
      ),
    ],
  );
}

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/e2e_pages.dart <dir>');
    exit(64);
  }
  initializeThorTests();
  final dir = Directory(args.single)..createSync(recursive: true);
  File('${dir.path}/store-gaps.html').writeAsStringSync(
    await renderDocument(const ThorApp(child: _StoreGapsPage())),
  );
  File('${dir.path}/drawer.html').writeAsStringSync(
    await renderDocument(const ThorApp(child: _DrawerPage())),
  );
  File('${dir.path}/adaptive-grid.html').writeAsStringSync(
    await renderDocument(const ThorApp(child: _AdaptiveGridPage())),
  );
  File('${dir.path}/grid-attacks.html').writeAsStringSync(
    await renderDocument(const ThorApp(child: _GridAttacksPage())),
  );
  File('${dir.path}/grid-attacks-rtl.html').writeAsStringSync(
    await renderDocument(
      const ThorApp(
        locale: Locale('ar'),
        supportedLocales: [Locale('ar')],
        child: _GridAttacksPage(),
      ),
    ),
  );
  File('${dir.path}/gridview-attacks.html').writeAsStringSync(
    await renderDocument(const ThorApp(child: _GridViewAttacksPage())),
  );
  File('${dir.path}/drawer-attacks.html').writeAsStringSync(
    await renderDocument(const ThorApp(child: _DrawerAttacksPage())),
  );
  File('${dir.path}/drawer-attacks-rtl.html').writeAsStringSync(
    await renderDocument(
      const ThorApp(
        locale: Locale('ar'),
        supportedLocales: [Locale('ar')],
        child: _DrawerAttacksPage(),
      ),
    ),
  );
  File('${dir.path}/scaffold-permanent.html').writeAsStringSync(
    await renderDocument(const ThorApp(child: _ScaffoldPermanentPage())),
  );
  File('${dir.path}/scaffold-permanent-rtl.html').writeAsStringSync(
    await renderDocument(
      const ThorApp(
        locale: Locale('ar'),
        supportedLocales: [Locale('ar')],
        child: _ScaffoldPermanentPage(),
      ),
    ),
  );
  File('${dir.path}/permanent-drawer.html').writeAsStringSync(
    await renderDocument(const ThorApp(child: _PermanentDrawerPage())),
  );
  File(
    '${dir.path}/toast.html',
  ).writeAsStringSync(await renderDocument(const ThorApp(child: _ToastPage())));
  File(
    '${dir.path}/grid.html',
  ).writeAsStringSync(await renderDocument(const ThorApp(child: _GridPage())));
  File('${dir.path}/carousel.html').writeAsStringSync(
    await renderDocument(const ThorApp(child: _CarouselPage())),
  );
  File('${dir.path}/carousel-static.html').writeAsStringSync(
    await renderDocument(const ThorApp(child: _StaticCarouselPage())),
  );
  File('${dir.path}/carousel-late.html').writeAsStringSync(
    await renderDocument(const ThorApp(child: _LateEngineCarouselPage())),
  );
  File('${dir.path}/carousel-live.html').writeAsStringSync(
    await renderDocument(const ThorApp(child: _LiveCarouselPage())),
  );
  File('${dir.path}/carousel-edge.html').writeAsStringSync(
    await renderDocument(const ThorApp(child: _CarouselEdgePage())),
  );
  File('${dir.path}/pageview.html').writeAsStringSync(
    await renderDocument(const ThorApp(child: _PageViewPage())),
  );
  File('${dir.path}/autofill.html').writeAsStringSync(
    await renderDocument(const ThorApp(child: _AutofillPage())),
  );
  for (final (name, next) in [('theme', 'theme2'), ('theme2', 'theme')]) {
    File('${dir.path}/$name.html').writeAsStringSync(
      await renderDocument(
        ThorApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          child: _ThemePage(name, '$next.html'),
        ),
      ),
    );
  }
}
