@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body, {ThemeData? theme}) =>
    renderDocument(ThorApp(theme: theme, child: body));

String bodyOf(String html) => html.substring(html.indexOf('<body'));

String stylesOf(String html) =>
    html.substring(html.indexOf('@layer thor.props'), html.indexOf('</style>'));

/// Every `class="…"` in [html] holds exactly one class.
void expectOneClassPerElement(String html) {
  for (final m in RegExp('class="([^"]*)"').allMatches(bodyOf(html))) {
    expect(m[1]!.split(' '), hasLength(1), reason: 'element ${m[0]}');
  }
}

/// The declarations of the rule `.cls{…}` of the element tagged
/// `data-thor="<name>"` (its first one).
String ruleOf(String html, String name) {
  final cls = RegExp(
    'class="(t\\w+)"[^>]*data-thor="$name"',
  ).firstMatch(bodyOf(html))![1]!;
  final css = stylesOf(html);
  final start = css.indexOf('.$cls{');
  return css.substring(start, css.indexOf('}', start) + 1);
}

// The member list thor generates for [_Nav], by hand.
abstract class _NavMembers extends ThorState {
  @override
  String get $type => 'Nav';

  @override
  List<ThorMember> get $members {
    final s = this as _Nav;
    return [ThorMember('go', s.go, arity: 1, call: (a) => s.go(a! as int))];
  }
}

class _Nav extends _NavMembers {
  void go(int index) {}
}

final _nav = _Nav();

const _home = NavigationDestination(icon: Text('h'), label: 'Home');
const _cart = NavigationDestination(icon: Text('c'), label: 'Cart');

Widget _tabs(
  String id,
  List<Widget> tabs, {
  List<Widget>? views,
  int initialIndex = 0,
  bool isScrollable = false,
  ValueChanged<int>? onTap,
}) => DefaultTabController(
  id: id,
  length: tabs.length,
  initialIndex: initialIndex,
  child: Column(
    children: [
      TabBar(tabs: tabs, isScrollable: isScrollable, onTap: onTap),
      TabBarView(
        children: views ?? [for (var i = 0; i < tabs.length; i++) Text('p$i')],
      ),
    ],
  ),
);

void main() {
  setUpAll(initializeThorTests);

  group('AppBar', () {
    test(
      'is one <header>; no actions or leading element when absent',
      () async {
        for (final actions in [null, <Widget>[]]) {
          final html = await page(
            AppBar(title: const Text('Sales'), actions: actions),
          );
          final body = bodyOf(html);
          expect('<header'.allMatches(body), hasLength(1));
          // header + the title's span, nothing else.
          expect(
            RegExp('<(div|span|header|button)').allMatches(body),
            hasLength(2),
          );
          expectOneClassPerElement(html);
        }
      },
    );

    test('a long title is cut with an ellipsis on one line', () async {
      final html = await page(AppBar(title: Text('Sales ' * 40)));
      final rule = ruleOf(html, 'Text');
      expect(rule, contains('overflow: hidden'));
      expect(rule, contains('text-overflow: ellipsis'));
      expect(rule, contains('white-space: nowrap'));
      // The grid track can shrink below the text (else it never cuts).
      expect(rule, contains('min-width: 0'));
      expect(ruleOf(html, 'AppBar'), contains('minmax(0, 1fr)'));
    });

    test('centerTitle centers on the whole bar; default is start', () async {
      final start = ruleOf(
        await page(const AppBar(title: Text('A'))),
        'AppBar',
      );
      expect(
        start,
        contains('grid-template-columns: auto minmax(0, 1fr) auto'),
      );
      final html = await page(
        const AppBar(title: Text('A'), centerTitle: true),
      );
      expect(
        ruleOf(html, 'AppBar'),
        contains('grid-template-columns: 1fr minmax(0, max-content) 1fr'),
      );
      expect(ruleOf(html, 'Text'), contains('text-align: center'));
    });

    test('escapes the title and bottom text', () async {
      final html = bodyOf(
        await page(const AppBar(title: Text('<script>alert(1)</script>&'))),
      );
      expect(html, isNot(contains('<script>alert')));
      expect(html, contains('&lt;script&gt;alert(1)&lt;/script&gt;&amp;'));
    });

    test('without a theme the colors keep their fallbacks', () async {
      final bare = stylesOf(await page(const AppBar(title: Text('A'))));
      expect(bare, contains('var(--t-surface, #fef7ff)'));
      expect(bare, contains('var(--t-on-surface, #1d1b20)'));
      final themed = stylesOf(
        await page(const AppBar(title: Text('A')), theme: ThemeData()),
      );
      expect(themed, contains('var(--t-surface)'));
      expect(themed, isNot(contains('var(--t-surface, ')));
    });

    test('explicit colors and elevation win over the theme', () async {
      final rule = ruleOf(
        await page(
          const AppBar(
            title: Text('A'),
            backgroundColor: Color(0xFF112233),
            foregroundColor: Color(0xFFFFFFFF),
            elevation: 4,
          ),
        ),
        'AppBar',
      );
      expect(rule, contains('background-color: #112233'));
      expect(rule, contains('color: #ffffff'));
      expect(rule, contains('box-shadow'));
      final flat = ruleOf(await page(const AppBar(title: Text('A'))), 'AppBar');
      expect(flat, isNot(contains('box-shadow')));
    });

    test(
      'in a Scaffold it is the banner itself and sticks to the top',
      () async {
        final html = bodyOf(
          await page(
            const Scaffold(
              appBar: AppBar(title: Text('A')),
              body: Text('x'),
            ),
          ),
        );
        expect('<header'.allMatches(html), hasLength(1));
        expect(html, contains('data-thor="AppBar"'));
        final css = await page(
          const Scaffold(
            appBar: AppBar(title: Text('A')),
            body: Text('x'),
          ),
        );
        final rule = ruleOf(css, 'AppBar');
        expect(rule, contains('position: sticky'));
        expect(rule, contains('top: 0'));
        // Any other widget is still wrapped in a <header> (no regression).
        final other = bodyOf(
          await page(const Scaffold(appBar: Text('A'), body: Text('x'))),
        );
        expect('<header'.allMatches(other), hasLength(1));
        expect(other, isNot(contains('sticky')));
      },
    );

    test('bottom spans the whole width under the toolbar row', () async {
      final html = await page(
        const AppBar(title: Text('A'), bottom: Divider()),
      );
      final rule = ruleOf(html, 'Divider');
      expect(rule, contains('grid-row: -2 / -1'));
      expect(rule, contains('grid-column: 1 / -1'));
    });
  });

  group('NavigationBar', () {
    test('asserts like Flutter: at least two destinations', () {
      expect(
        () => NavigationBar(destinations: const []),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => NavigationBar(destinations: const [_home]),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts like Flutter: selectedIndex inside the destinations', () {
      for (final i in [-1, 2, 99]) {
        expect(
          () => NavigationBar(
            selectedIndex: i,
            destinations: const [_home, _cart],
          ),
          throwsA(isA<AssertionError>()),
          reason: 'selectedIndex $i',
        );
      }
    });

    test(
      'is a <nav>; links and buttons; aria-current only on the selected',
      () async {
        final html = bodyOf(
          await page(
            NavigationBar(
              selectedIndex: 0,
              destinations: const [
                NavigationDestination(
                  icon: Text('h'),
                  label: 'Home',
                  href: '/',
                ),
                _cart,
              ],
            ),
          ),
        );
        expect(html, startsWith('<body><nav '));
        expect(html, contains('<a class="'));
        expect(html, contains('href="/" aria-current="page"'));
        expect(html, contains('<button class="'));
        expect('aria-current'.allMatches(html), hasLength(1));
        final buttonSelected = bodyOf(
          await page(
            NavigationBar(selectedIndex: 1, destinations: const [_home, _cart]),
          ),
        );
        expect(buttonSelected, contains('type="button" aria-current="true"'));
        expect('aria-current'.allMatches(buttonSelected), hasLength(1));
      },
    );

    test('selectedIndex null selects nothing', () async {
      final html = bodyOf(
        await page(
          NavigationBar(
            selectedIndex: null,
            destinations: const [_home, _cart],
          ),
        ),
      );
      expect(html, isNot(contains('aria-current')));
    });

    test('many destinations share the bar and one class; labels cut', () async {
      final html = await page(
        NavigationBar(
          destinations: [
            for (var i = 0; i < 8; i++)
              NavigationDestination(
                icon: const Text('i'),
                label: 'A very long destination $i',
              ),
          ],
        ),
      );
      final classes = {
        for (final m in RegExp(
          r'<button class="(t\w+)"',
        ).allMatches(bodyOf(html)))
          m[1],
      };
      expect(RegExp('<button ').allMatches(bodyOf(html)), hasLength(8));
      expect(classes, hasLength(1));
      final rule = ruleOf(html, 'NavigationDestination');
      expect(rule, contains('flex: 1 1 0'));
      expect(rule, contains('min-width: 0'));
      expect(stylesOf(html), contains('text-overflow: ellipsis'));
      expectOneClassPerElement(html);
    });

    test('escapes labels and tooltips', () async {
      final html = bodyOf(
        await page(
          NavigationBar(
            destinations: const [
              NavigationDestination(
                icon: Text('h'),
                label: '<img src=x onerror=alert(1)>',
                tooltip: '"><script>',
              ),
              _cart,
            ],
          ),
        ),
      );
      expect(html, isNot(contains('<img')));
      expect(html, isNot(contains('<script>')));
      expect(html, contains('&lt;img src=x onerror=alert(1)&gt;'));
    });

    test('selectedIcon only on the selected destination', () async {
      final html = bodyOf(
        await page(
          NavigationBar(
            destinations: const [
              NavigationDestination(
                icon: Text('o'),
                selectedIcon: Text('SEL'),
                label: 'A',
              ),
              NavigationDestination(
                icon: Text('o2'),
                selectedIcon: Text('SEL2'),
                label: 'B',
              ),
            ],
          ),
        ),
      );
      expect(html, contains('>SEL<'));
      expect(html, isNot(contains('>o<')));
      expect(html, contains('>o2<'));
      expect(html, isNot(contains('SEL2')));
    });

    test('disabled: button disabled, link loses href; never wired', () async {
      final html = bodyOf(
        await page(
          NavigationBar(
            onDestinationSelected: _nav.go,
            destinations: const [
              NavigationDestination(
                icon: Text('h'),
                label: 'A',
                href: '/a',
                enabled: false,
              ),
              NavigationDestination(
                icon: Text('c'),
                label: 'B',
                enabled: false,
              ),
            ],
          ),
        ),
      );
      expect(html, isNot(contains('href=')));
      expect(html, contains('aria-disabled="true"'));
      expect(html, contains(' disabled'));
      expect(html, isNot(contains('data-t-on')));
    });

    test('onDestinationSelected sends the index to a ThorState', () async {
      final html = bodyOf(
        await page(
          NavigationBar(
            onDestinationSelected: _nav.go,
            destinations: const [_home, _cart],
          ),
        ),
      );
      expect(html, contains('data-t-on="click:Nav.go" data-tx="0"'));
      expect(html, contains('data-t-on="click:Nav.go" data-tx="1"'));
    });

    test('hidden labels stay in the DOM as the accessible name', () async {
      final hide = await page(
        NavigationBar(
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          destinations: const [_home, _cart],
        ),
      );
      expect(bodyOf(hide), contains('>Home<'));
      expect(stylesOf(hide), contains('clip-path: inset(50%)'));
      expect(stylesOf(hide), isNot(contains('clip-path: none')));
      final selected = await page(
        NavigationBar(
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: const [_home, _cart],
        ),
      );
      expect(stylesOf(selected), contains('clip-path: none'));
      final always = await page(
        NavigationBar(destinations: const [_home, _cart]),
      );
      expect(stylesOf(always), isNot(contains('clip-path')));
    });

    test(
      'in a Scaffold it replaces the footer and sticks to the bottom',
      () async {
        final html = await page(
          Scaffold(
            body: const Text('x'),
            bottomNavigationBar: NavigationBar(
              destinations: const [_home, _cart],
            ),
          ),
        );
        expect(bodyOf(html), isNot(contains('<footer')));
        final rule = ruleOf(html, 'NavigationBar');
        expect(rule, contains('position: sticky'));
        expect(rule, contains('bottom: 0'));
        expect(rule, contains('padding-bottom: env(safe-area-inset-bottom)'));
      },
    );

    test('a widget that is not a destination takes an equal share', () async {
      final html = await page(
        NavigationBar(destinations: const [_home, Text('other')]),
      );
      final cls = RegExp(
        r'class="(t\w+)"[^>]*>other<',
      ).firstMatch(bodyOf(html))![1];
      final css = stylesOf(html);
      final start = css.indexOf('.$cls{');
      expect(
        css.substring(start, css.indexOf('}', start)),
        contains('flex: 1 1 0'),
      );
    });

    test('a NavigationDestination outside a NavigationBar throws', () async {
      await expectLater(page(_home), throwsA(isA<StateError>()));
    });
  });

  group('TabBar', () {
    test('needs a DefaultTabController, like Flutter', () async {
      await expectLater(
        page(const TabBar(tabs: [Tab(text: 'A')])),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        page(const TabBarView(children: [Text('A')])),
        throwsA(isA<StateError>()),
      );
    });

    test('tabs and panels must match the controller length', () async {
      await expectLater(
        page(
          const DefaultTabController(
            id: 't',
            length: 3,
            child: TabBar(
              tabs: [
                Tab(text: 'A'),
                Tab(text: 'B'),
              ],
            ),
          ),
        ),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        page(
          const DefaultTabController(
            id: 't',
            length: 1,
            child: TabBarView(children: [Text('A'), Text('B')]),
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('asserts like Flutter on length and initialIndex', () {
      var length = 2;
      expect(
        () => DefaultTabController(
          id: 't',
          length: length,
          initialIndex: length,
          child: const Text('x'),
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => DefaultTabController(
          id: 't',
          length: -length,
          child: const Text('x'),
        ),
        throwsA(isA<AssertionError>()),
      );
      length = 0;
      // Zero tabs is allowed (and any initialIndex then), like Flutter.
      DefaultTabController(id: 't', length: length, child: const Text('x'));
    });

    test('an id that is not a plain identifier fails closed', () async {
      for (final id in ['', '1x', 'a"b', 'a]b', 'a b', 'a:has(*)']) {
        await expectLater(
          page(DefaultTabController(id: id, length: 0, child: const Text('x'))),
          throwsA(isA<ArgumentError>()),
          reason: 'id "$id"',
        );
      }
    });

    test('a native radio group: one per tab, same name, one checked', () async {
      final html = bodyOf(
        await page(
          _tabs('order', const [
            Tab(text: 'Details'),
            Tab(text: 'Payments'),
            Tab(text: 'Shipping'),
          ], initialIndex: 1),
        ),
      );
      expect(html, contains('role="radiogroup"'));
      final radios = RegExp('<input [^>]*>').allMatches(html).toList();
      expect(radios, hasLength(3));
      for (final (i, r) in radios.indexed) {
        expect(r[0], contains('type="radio"'));
        expect(r[0], contains('name="order"'));
        expect(r[0], contains('value="$i"'));
        expect(r[0], contains('aria-controls="order-panel-$i"'));
        expect(r[0]!.contains(' checked'), i == 1, reason: 'radio $i');
      }
      // Each panel is named by its tab; each tab is the <label> of its radio
      // (the whole tab is clickable with no JS, the radio takes the focus).
      for (var i = 0; i < 3; i++) {
        expect(html, contains('<label id="order-tab-$i"'));
        expect(html, contains('id="order-panel-$i"'));
        expect(html, contains('aria-labelledby="order-tab-$i"'));
      }
      // Keyboard is native: no tabindex games on the tabs, no JS handlers.
      expect(html, isNot(contains('<label tabindex')));
      expect(html, isNot(contains('data-t-on')));
    });

    test('the panel of the checked radio shows; hidden fails open', () async {
      final html = await page(
        _tabs('t', const [Tab(text: 'A'), Tab(text: 'B')]),
      );
      final css = stylesOf(html);
      for (var i = 0; i < 2; i++) {
        expect(
          css,
          contains(
            ':where(:root:has(input[name="t"]:checked:not([value="$i"]))) ',
          ),
        );
      }
      // No panel is hidden by its own rule: with no :has() all are visible.
      for (final m in RegExp(
        r'id="t-panel-\d" class="(t\w+)"',
      ).allMatches(bodyOf(html))) {
        final start = css.indexOf('.${m[1]}{');
        expect(
          css.substring(start, css.indexOf('}', start)),
          isNot(contains('display: none')),
        );
      }
    });

    test('two controllers in a page never touch each other', () async {
      final html = await page(
        Column(
          children: [
            _tabs('a', const [Tab(text: 'A1'), Tab(text: 'A2')]),
            _tabs('b', const [Tab(text: 'B1'), Tab(text: 'B2')]),
          ],
        ),
      );
      final body = bodyOf(html);
      expect('name="a"'.allMatches(body), hasLength(2));
      expect('name="b"'.allMatches(body), hasLength(2));
      expect(' checked'.allMatches(body), hasLength(2));
      expect(stylesOf(html), contains('input[name="a"]'));
      expect(stylesOf(html), contains('input[name="b"]'));
    });

    test('zero tabs renders an empty bar and no panels', () async {
      final html = bodyOf(await page(_tabs('t', const [])));
      expect(html, isNot(contains('<input')));
      expect(html, isNot(contains('role="group"')));
      expect(html, contains('role="radiogroup"'));
    });

    test('escapes tab labels', () async {
      final html = bodyOf(
        await page(_tabs('t', const [Tab(text: '<b>x</b>&'), Tab(text: 'y')])),
      );
      expect(html, isNot(contains('<b>')));
      expect(html, contains('&lt;b&gt;x&lt;/b&gt;&amp;'));
    });

    test(
      'text tabs: one element and one shared class each; long labels cut',
      () async {
        final html = await page(
          _tabs('t', [
            for (var i = 0; i < 5; i++) Tab(text: 'A very long tab $i ' * 5),
          ]),
        );
        final body = bodyOf(html);
        final labels = RegExp(
          r'<label id="t-tab-\d" class="(t\w+)"',
        ).allMatches(body).map((m) => m[1]).toSet();
        expect(labels, hasLength(1));
        // The text is the label's own: label + radio, no inner span.
        expect(
          RegExp(r'<label[^>]*><input[^>]*/>[^<]+</label>').allMatches(body),
          hasLength(5),
        );
        final rule = ruleOf(html, 'Tab');
        expect(rule, contains('flex: 1 1 0'));
        expect(rule, contains('min-width: 0'));
        expect(rule, contains('text-overflow: ellipsis'));
        expectOneClassPerElement(html);
      },
    );

    test(
      'selected look and focus ring are conditions of the tab class',
      () async {
        final html = await page(
          _tabs('t', const [Tab(text: 'A'), Tab(text: 'B')]),
        );
        final cls = RegExp(
          r'<label id="t-tab-0" class="(t\w+)"',
        ).firstMatch(bodyOf(html))![1];
        final css = stylesOf(html);
        expect(css, contains('.$cls:has(:checked){'));
        expect(css, contains('.$cls:has(:focus-visible){'));
      },
    );

    test(
      'isScrollable: tabs as wide as their content, the bar scrolls',
      () async {
        final html = await page(
          _tabs('t', const [
            Tab(text: 'A'),
            Tab(text: 'B'),
          ], isScrollable: true),
        );
        expect(ruleOf(html, 'TabBar'), contains('overflow-x: auto'));
        expect(ruleOf(html, 'Tab'), contains('flex: none'));
      },
    );

    test('icon and text: 72 px, icon above the text', () async {
      final html = await page(
        _tabs('t', const [
          Tab(icon: Text('i'), text: 'A'),
          Tab(icon: Text('j'), text: 'B'),
        ]),
      );
      final rule = ruleOf(html, 'Tab');
      expect(rule, contains('min-height: 72px'));
      expect(rule, contains('flex-direction: column'));
    });

    test('onTap sends the new index to a ThorState on change', () async {
      final html = bodyOf(
        await page(
          _tabs('t', const [Tab(text: 'A'), Tab(text: 'B')], onTap: _nav.go),
        ),
      );
      expect(html, contains('data-t-on="change:Nav.go" data-tx="0"'));
      expect(html, contains('data-t-on="change:Nav.go" data-tx="1"'));
    });

    test('Tab asserts like Flutter', () {
      String? none;
      expect(() => Tab(text: none), throwsA(isA<AssertionError>()));
      expect(
        () => Tab(text: 'a', child: Text(none ?? 'b')),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  test(
    'RTL: only logical inline properties (the bars mirror with dir)',
    () async {
      final html = await page(
        DefaultTabController(
          id: 't',
          length: 2,
          child: Column(
            children: [
              AppBar(
                leading: IconButton(icon: const Text('m'), onPressed: () {}),
                title: const Text('A'),
                actions: [IconButton(icon: const Text('x'), onPressed: () {})],
                bottom: const TabBar(
                  tabs: [
                    Tab(text: 'A'),
                    Tab(text: 'B'),
                  ],
                ),
              ),
              NavigationBar(destinations: const [_home, _cart]),
            ],
          ),
        ),
      );
      final css = stylesOf(html);
      expect(css, contains('margin-inline-start'));
      expect(css, contains('margin-inline-end'));
      expect(css, contains('inset-inline-start'));
      expect(
        css,
        isNot(
          matches(
            RegExp(
              r'(margin|padding|inset|border)-(left|right)|[;{ ](left|right):',
            ),
          ),
        ),
      );
    },
  );
}
