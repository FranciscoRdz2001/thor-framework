@TestOn('vm')
library;

// Fixed grid tracks per breakpoint (`GridLayout(columnWidth:)`),
// fractional `container:` thresholds, and a `Drawer(permanentFrom:)` that is
// a modal on a phone and an inline panel from a breakpoint up (one DOM).
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Widget body) => renderDocument(ThorApp(child: body));

String _head(String html) => html.substring(0, html.indexOf('</head>'));

List<Widget> _items(int n) => [for (var i = 0; i < n; i++) Text('item $i')];

void main() {
  setUpAll(initializeThorTests);

  group('GridLayout(columnWidth:)', () {
    const tracks = 'repeat(auto-fill, minmax(min(260px, 100%), 260px))';

    test('fixed tracks only from md: two fluid columns below', () async {
      final html = await _page(
        Grid(
          layout: const GridLayout(
            columns: 2,
            gap: 16,
          ).when(medium: const GridLayout(columnWidth: 260, gap: 73)),
          children: _items(4),
        ),
      );
      final css = _head(html);
      expect(css, contains('grid-template-columns: repeat(2, minmax(0, 1fr))'));
      expect(
        RegExp(
          r'@media screen and \(min-width: 600px\)\{\.t\w+\{[^}]*'
          'grid-template-columns: ${RegExp.escape(tracks)}',
        ).hasMatch(css),
        isTrue,
        reason: css,
      );
      expect(css, contains('column-gap: 73px'));
    });

    test('alignment places the space left over', () async {
      final html = await _page(
        Grid(
          layout: const GridLayout(
            columnWidth: 260,
            alignment: WrapAlignment.center,
          ),
          children: _items(2),
        ),
      );
      expect(_head(html), contains('justify-content: center'));
      expect(_head(html), contains('grid-template-columns: $tracks'));
    });

    test('works in a GridView, and by container width', () async {
      final html = await _page(
        LayoutScope(
          child: GridView.count(
            crossAxisCount: 2,
            layout: const GridLayout().when(
              container: {600: const GridLayout(columnWidth: 260, gap: 73)},
            ),
            children: _items(3),
          ),
        ),
      );
      expect(
        _head(html),
        matches(
          RegExp(
            r'@container \(min-width: 600px\)\{\.t\w+\{[^}]*'
            'grid-template-columns: ${RegExp.escape(tracks)}',
          ),
        ),
      );
    });

    test('a column width and a column count are different things', () {
      expect(
        () => GridLayout(columns: 3, columnWidth: 200),
        throwsA(isA<AssertionError>()),
      );
      expect(() => GridLayout(columnWidth: 0), throwsA(isA<AssertionError>()));
    });
  });

  group('GridView.extent with a layout', () {
    // The container steps count the columns of a capped grid; a layout that
    // sets the columns must win over them from where it applies.
    Future<String> extent(GridLayout layout) => _page(
      GridView.extent(
        maxCrossAxisExtent: 200,
        layout: layout,
        children: _items(4),
      ),
    );

    test('a breakpoint variant switches the steps off from there', () async {
      final css = _head(
        await extent(
          const GridLayout().when(medium: const GridLayout(columnWidth: 260)),
        ),
      );
      expect(
        css,
        contains(
          '@media screen and (max-width: 599.98px){'
          '@container (min-width: 200.02px){',
        ),
      );
      expect(css, isNot(contains('}@container (min-width: 200.02px){')));
    });

    test('a container variant switches the steps off from there', () async {
      final css = _head(
        await extent(
          const GridLayout().when(
            container: {600: const GridLayout(columns: 2)},
          ),
        ),
      );
      expect(
        css,
        contains(
          '@container (max-width: 599.98px){@container (min-width: 200.02px){',
        ),
      );
    });

    test('columns in the base layout replace the steps', () async {
      final css = _head(await extent(const GridLayout(columns: 3)));
      expect(css, isNot(contains('min-width: 200.02px')));
    });

    test('a layout without columns leaves the steps alone', () async {
      final css = _head(await extent(const GridLayout(gap: 8)));
      expect(css, contains('@container (min-width: 200.02px){'));
      expect(css, isNot(contains('max-width: 599.98px){@container')));
    });
  });

  group('.when(container:) keys', () {
    Future<String> padded(Map<num, EdgeInsets> container) => _page(
      LayoutScope(
        child: Container(
          padding: const EdgeInsets.all(8).when(container: container),
          child: const Text('x'),
        ),
      ),
    );

    test('a fractional threshold is accepted and written as is', () async {
      final html = await padded({592.02: const EdgeInsets.all(16)});
      expect(_head(html), contains('@container (min-width: 592.02px)'));
    });

    test('a whole double and an int are the same threshold', () async {
      final html = await padded({400.0: const EdgeInsets.all(16)});
      expect(_head(html), contains('@container (min-width: 400px)'));
    });

    test('a breakpoint width can be the key', () async {
      final html = await padded({
        WindowSizeClass.medium.minWidth: const EdgeInsets.all(16),
      });
      expect(_head(html), contains('@container (min-width: 600px)'));
    });

    test('fractional widths cascade among themselves', () async {
      final html = await padded({
        592.02: const EdgeInsets.all(16),
        925.5: const EdgeInsets.all(24),
      });
      final css = _head(html);
      expect(css, contains('@container (min-width: 592.02px)'));
      expect(css, contains('@container (min-width: 925.5px)'));
    });
  });

  group('GridLayout(childAspectRatio:)', () {
    test('a GridView changes the ratio of its tiles per breakpoint', () async {
      final css = _head(
        await _page(
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            layout: const GridLayout().when(
              medium: const GridLayout(
                childAspectRatio: 0.75,
                columnWidth: 260,
              ),
            ),
            children: _items(2),
          ),
        ),
      );
      // The ratio belongs to the tiles, not to the grid: they carry it.
      expect(css, contains('aspect-ratio: 1.5'));
      expect(
        RegExp(
          r'@media screen and \(min-width: 600px\)\{[^@]*\.t\w+\{aspect-ratio: 0.75\}',
        ).hasMatch(css),
        isTrue,
        reason: css,
      );
      expect(
        RegExp(r'\.t\w+\{[^}]*display: grid[^}]*aspect-ratio').hasMatch(css),
        isFalse,
      );
    });

    test('by container width, and in a plain Grid', () async {
      final css = _head(
        await _page(
          LayoutScope(
            child: Grid(
              layout: const GridLayout(
                columns: 2,
              ).when(container: {500: const GridLayout(childAspectRatio: 2)}),
              children: _items(2),
            ),
          ),
        ),
      );
      expect(
        RegExp(
          r'@container \(min-width: 500px\)\{[^@]*\.t\w+\{aspect-ratio: 2\}',
        ).hasMatch(css),
        isTrue,
        reason: css,
      );
    });

    test('a ratio and no variants is written once, at the base', () async {
      final css = _head(
        await _page(
          Grid(
            layout: const GridLayout(childAspectRatio: 1.5),
            children: _items(2),
          ),
        ),
      );
      expect(css, contains('aspect-ratio: 1.5'));
      expect(css, isNot(contains('@media screen and (min-width: 600px){.t')));
    });
  });

  group('Scaffold(drawer:) that is permanent from a breakpoint', () {
    Widget scaffold({Widget? drawer, Widget? endDrawer}) => Scaffold(
      appBar: const AppBar(title: Text('Home')),
      drawer: drawer,
      endDrawer: endDrawer,
      bottomNavigationBar: const Text('foot'),
      body: const Text('body'),
    );
    const permanent = Drawer(
      permanentFrom: WindowSizeClass.medium,
      label: 'Menu',
      child: Text('menu'),
    );

    test(
      'the scaffold gets a column for each side, the content in the middle',
      () async {
        final html = await _page(scaffold(drawer: permanent));
        final css = _head(html);
        expect(
          css,
          contains(
            'grid-template-columns: auto minmax(0, 1fr) auto; '
            'grid-template-rows: auto minmax(0, 1fr) auto',
          ),
        );
        // The bars span every column, the body is the middle one.
        expect(css, contains('grid-column: 1 / -1'));
        expect(css, contains('grid-column: 2'));
        // The drawer, closed and wide, takes the first column of the body's row.
        expect(
          RegExp(
            r'\.t\w+:not\(\[open\]\)\{[^}]*grid-column: 1; grid-row: 2',
          ).hasMatch(css),
          isTrue,
          reason: css,
        );
      },
    );

    test('an end drawer takes the last column', () async {
      final css = _head(
        await _page(
          scaffold(
            endDrawer: const Drawer(
              permanentFrom: WindowSizeClass.expanded,
              label: 'Details',
              child: Text('details'),
            ),
          ),
        ),
      );
      expect(
        css,
        contains(
          'grid-template-columns: auto minmax(0, 1fr) auto; '
          'grid-template-rows: auto minmax(0, 1fr) auto',
        ),
      );
      expect(
        RegExp(
          r'\.t\w+:not\(\[open\]\)\{[^}]*grid-column: 3; grid-row: 2',
        ).hasMatch(css),
        isTrue,
        reason: css,
      );
    });

    test('the AppBar menu button is hidden from the breakpoint up', () async {
      final html = await _page(scaffold(drawer: permanent));
      final button = RegExp(
        r'<button[^>]*command="show-modal"[^>]*>',
      ).firstMatch(html)![0]!;
      final cls = RegExp(r'class="([^"]*)"').firstMatch(button)![1]!;
      expect(
        RegExp(
          '@media screen and \\(min-width: 600px\\)\\{[^@]*'
          '\\.${cls.split(' ').last}\\{display: none\\}',
        ).hasMatch(_head(html)),
        isTrue,
        reason: _head(html),
      );
    });

    test('only the side that is permanent loses its button', () async {
      final html = await _page(
        scaffold(
          drawer: const Drawer(child: Text('menu')),
          endDrawer: const Drawer(
            permanentFrom: WindowSizeClass.medium,
            child: Text('d'),
          ),
        ),
      );
      final buttons = RegExp(
        r'<button[^>]*command="show-modal"[^>]*>',
      ).allMatches(html).map((m) => m[0]!).toList();
      expect(buttons, hasLength(2));
      final css = _head(html);
      String hidden(String button) {
        final cls = RegExp(r'class="([^"]*)"').firstMatch(button)![1]!;
        return RegExp(
          '\\.${cls.split(' ').last}\\{display: none\\}',
        ).hasMatch(css).toString();
      }

      expect(
        buttons.map(hidden),
        unorderedEquals(['true', 'false']),
        reason: css,
      );
    });

    test('a scaffold with plain drawers is as before', () async {
      final css = _head(
        await _page(scaffold(drawer: const Drawer(child: Text('menu')))),
      );
      expect(
        css,
        isNot(
          contains(
            'grid-template-columns: auto minmax(0, 1fr) auto; '
            'grid-template-rows: auto minmax(0, 1fr) auto',
          ),
        ),
      );
      expect(css, isNot(contains('grid-column: 1 / -1')));
    });
  });

  group('Drawer(permanentFrom:)', () {
    String dialog(String html) => RegExp('<dialog[^>]*>').firstMatch(html)![0]!;

    Widget panel() => Row(
      children: [
        const Drawer(
          permanentFrom: WindowSizeClass.medium,
          label: 'Filters',
          child: Text('filter list'),
        ),
        Expanded(
          child: Column(
            children: [
              DialogTrigger(
                id: 'filters',
                hiddenFrom: WindowSizeClass.medium,
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Filters'),
                ),
              ),
              const Text('results'),
            ],
          ),
        ),
      ],
    );

    test('one <dialog>, shown by CSS from the breakpoint up', () async {
      final html = await _page(panel());
      expect('<dialog'.allMatches(html), hasLength(1));
      expect(dialog(html), contains('aria-label="Filters"'));
      final css = _head(html);
      // Closed (not modal) and wide: a static block in the flow.
      expect(
        RegExp(
          r'@media screen and \(min-width: 600px\)\{\.t\w+:not\(\[open\]\)\{'
          r'[^}]*display: flex[^}]*position: static',
        ).hasMatch(css),
        isTrue,
        reason: css,
      );
      expect(css, contains('translate: none'));
    });

    test('the panel is as tall as its content (a basis of 0 is not)', () async {
      final css = _head(await _page(panel()));
      // The Expanded child has `flex: 1 1 0%`: inline, the row would not
      // grow with a panel taller than the page and its content would spill.
      expect(
        RegExp(r'\.t\w+:not\(\[open\]\) > \*\{flex: 1 1 auto\}').hasMatch(css),
        isTrue,
        reason: css,
      );
    });

    test('a modal open when the window grows closes itself', () async {
      final html = await _page(panel());
      final css = _head(html);
      expect(
        RegExp(
          r'\.t\w+\[open\]\{animation: t-drawer-permanent 1ms\}',
        ).hasMatch(css),
        isTrue,
        reason: css,
      );
      expect(css, contains('@keyframes t-drawer-permanent{'));
      expect(
        dialog(html),
        contains('onanimationstart="if(event.target===this)this.close()"'),
      );
    });

    test('the open modal keeps its look at any width', () async {
      final css = _head(await _page(panel()));
      // The only rule for `[open]` from the breakpoint up starts the
      // animation that closes it: nothing restyles the modal in place (the
      // top layer cannot be undone, only closed).
      final wide = css.substring(css.indexOf('min-width: 600px'));
      final rules = RegExp(
        r'\.t\w+\[open\]\{([^}]*)\}',
      ).allMatches(wide).map((m) => m[1]).toList();
      expect(rules, ['animation: t-drawer-permanent 1ms']);
    });

    test('the panel is not a Tab stop of its own', () async {
      expect(dialog(await _page(panel())), contains('tabindex="-1"'));
      final plain = await _page(const Drawer(label: 'Menu', child: Text('m')));
      expect(dialog(plain), isNot(contains('tabindex')));
    });

    test('the trigger is hidden from the breakpoint up', () async {
      final html = await _page(panel());
      final button = RegExp(
        r'<button[^>]*commandfor="filters"[^>]*>',
      ).firstMatch(html)![0]!;
      expect(button, contains('command="show-modal"'));
      expect(
        RegExp(
          r'@media screen and \(min-width: 600px\)\{\.t\w+\{display: none',
        ).hasMatch(_head(html)),
        isTrue,
      );
    });

    test('a drawer without permanentFrom is as before', () async {
      final html = await _page(
        const Drawer(label: 'Menu', child: Text('menu')),
      );
      expect(_head(html), isNot(contains('min-width: 600px')));
    });
  });
}
