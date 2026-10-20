@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

String bodyOf(String html) => html.substring(html.indexOf('<body'));

String stylesOf(String html) =>
    html.substring(html.indexOf('@layer thor.props'), html.indexOf('</style>'));

String ruleOf(String html, String name) {
  final cls = RegExp(
    'class="(t\\w+)"[^>]*data-thor="$name"',
  ).firstMatch(bodyOf(html))![1]!;
  final css = stylesOf(html);
  final start = css.indexOf('.$cls{');
  return css.substring(start, css.indexOf('}', start) + 1);
}

abstract class _RailMembers extends ThorState {
  @override
  String get $type => 'Rail';

  @override
  List<ThorMember> get $members {
    final s = this as _Rail;
    return [ThorMember('go', s.go, arity: 1, call: (a) => s.go(a! as int))];
  }
}

class _Rail extends _RailMembers {
  void go(int index) {}
}

final _rail = _Rail();

const _home = NavigationRailDestination(icon: Text('h'), label: Text('Home'));
const _cart = NavigationRailDestination(
  icon: Text('c'),
  selectedIcon: Text('C'),
  label: Text('Cart'),
);

void main() {
  group('NavigationRail', () {
    test('asserts like Flutter', () {
      expect(
        () => NavigationRail(
          selectedIndex: 2,
          destinations: const [_home, _cart],
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => NavigationRail(
          selectedIndex: -1,
          destinations: const [_home, _cart],
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => NavigationRail(
          selectedIndex: 0,
          minWidth: 0,
          destinations: const [_home, _cart],
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => NavigationRail(
          selectedIndex: 0,
          minWidth: 100,
          minExtendedWidth: 50,
          destinations: const [_home, _cart],
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => NavigationRail(
          selectedIndex: 0,
          extended: true,
          labelType: NavigationRailLabelType.all,
          destinations: const [_home, _cart],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('zero destinations and a null selection are fine', () async {
      final html = bodyOf(
        await page(NavigationRail(selectedIndex: null, destinations: const [])),
      );
      expect(html, startsWith('<body><nav '));
      expect(html, isNot(contains('aria-current')));
    });

    test(
      'is a <nav>; links and buttons; aria-current on the selected',
      () async {
        final html = bodyOf(
          await page(
            NavigationRail(
              selectedIndex: 0,
              destinations: const [
                NavigationRailDestination(
                  icon: Text('h'),
                  label: Text('Home'),
                  href: '/',
                ),
                _cart,
              ],
            ),
          ),
        );
        expect(html, contains('<nav '));
        expect(html, contains('href="/" aria-current="page"'));
        expect(html, contains('<button class="'));
        expect('aria-current'.allMatches(html), hasLength(1));
        final byButton = bodyOf(
          await page(
            NavigationRail(
              selectedIndex: 1,
              destinations: const [_home, _cart],
            ),
          ),
        );
        expect(byButton, contains('type="button" aria-current="true"'));
        expect(byButton, contains('>C<'), reason: 'selectedIcon when selected');
        expect(byButton, isNot(contains('>c<')));
      },
    );

    test('a click calls the state method with the index', () async {
      final html = bodyOf(
        await page(
          NavigationRail(
            selectedIndex: 0,
            onDestinationSelected: _rail.go,
            destinations: const [_home, _cart],
          ),
        ),
      );
      expect(html, contains('data-t-on="click:Rail.go" data-tx="1"'));
    });

    test('no handler: nothing is wired', () async {
      final html = bodyOf(
        await page(
          NavigationRail(selectedIndex: 0, destinations: const [_home, _cart]),
        ),
      );
      expect(html, isNot(contains('data-t-on')));
    });

    test('disabled destination is not interactive', () async {
      final html = bodyOf(
        await page(
          NavigationRail(
            selectedIndex: 0,
            onDestinationSelected: _rail.go,
            destinations: const [
              _home,
              NavigationRailDestination(
                icon: Text('c'),
                label: Text('Cart'),
                disabled: true,
              ),
            ],
          ),
        ),
      );
      expect(html, contains('type="button" disabled'));
      expect('data-t-on'.allMatches(html), hasLength(1));
    });

    test(
      'labelType: none (default) keeps the label as the name, hidden',
      () async {
        final html = await page(
          NavigationRail(selectedIndex: 0, destinations: const [_home, _cart]),
        );
        expect(bodyOf(html), contains('Home'));
        expect(stylesOf(html), contains('clip-path: inset(50%)'));
      },
    );

    test('labelType all shows every label', () async {
      final html = await page(
        NavigationRail(
          selectedIndex: 0,
          labelType: NavigationRailLabelType.all,
          destinations: const [_home, _cart],
        ),
      );
      expect(stylesOf(html), isNot(contains('clip-path: inset(50%)')));
    });

    test('labelType selected shows only the current label', () async {
      final html = await page(
        NavigationRail(
          selectedIndex: 0,
          labelType: NavigationRailLabelType.selected,
          destinations: const [_home, _cart],
        ),
      );
      final css = stylesOf(html);
      expect(css, contains('clip-path: inset(50%)'));
      expect(css, contains('clip-path: none'));
    });

    test(
      'extended: wide rail, destinations in a row with their label',
      () async {
        final html = await page(
          NavigationRail(
            selectedIndex: 0,
            extended: true,
            destinations: const [_home, _cart],
          ),
        );
        expect(ruleOf(html, 'NavigationRail'), contains('min-width: 256px'));
        expect(
          ruleOf(html, 'NavigationRailDestination'),
          contains('flex-direction: row'),
        );
        expect(stylesOf(html), isNot(contains('clip-path: inset(50%)')));
      },
    );

    test('minWidth and minExtendedWidth set the width', () async {
      final html = await page(
        NavigationRail(
          selectedIndex: 0,
          minWidth: 96,
          destinations: const [_home],
        ),
      );
      expect(ruleOf(html, 'NavigationRail'), contains('min-width: 96px'));
      final wide = await page(
        NavigationRail(
          selectedIndex: 0,
          extended: true,
          minExtendedWidth: 300,
          destinations: const [_home],
        ),
      );
      expect(ruleOf(wide, 'NavigationRail'), contains('min-width: 300px'));
    });

    test(
      'leading and trailing sit around the destinations, in order',
      () async {
        final html = bodyOf(
          await page(
            NavigationRail(
              selectedIndex: 0,
              leading: const Text('LEAD'),
              trailing: const Text('TRAIL'),
              destinations: const [_home, _cart],
            ),
          ),
        );
        final lead = html.indexOf('LEAD');
        final first = html.indexOf('Home');
        final last = html.indexOf('Cart');
        final trail = html.indexOf('TRAIL');
        expect(lead, lessThan(first));
        expect(first, lessThan(last));
        expect(last, lessThan(trail));
      },
    );

    test('groupAlignment moves the group with auto margins', () async {
      Future<String> rule(double a) async => ruleOf(
        await page(
          NavigationRail(
            selectedIndex: 0,
            groupAlignment: a,
            destinations: const [_home, _cart],
          ),
        ),
        'NavigationRail',
      );
      expect(await rule(-1), isNot(contains('justify-content')));
      expect(await rule(0), contains('justify-content: center'));
      expect(await rule(1), contains('justify-content: flex-end'));
    });

    test(
      'useIndicator false drops the pill; indicatorColor tints it',
      () async {
        final off = await page(
          NavigationRail(
            selectedIndex: 0,
            useIndicator: false,
            destinations: const [_home],
          ),
        );
        expect(stylesOf(off), isNot(contains('secondary-container')));
        final tinted = await page(
          NavigationRail(
            selectedIndex: 0,
            indicatorColor: const Color(0xFFFF0000),
            destinations: const [_home],
          ),
        );
        expect(stylesOf(tinted), contains('#ff0000'));
      },
    );

    test(
      'escapes labels and tooltips; one class per destination kind',
      () async {
        final html = await page(
          NavigationRail(
            selectedIndex: 0,
            destinations: [
              for (var i = 0; i < 6; i++)
                NavigationRailDestination(
                  icon: const Text('i'),
                  label: Text('<img src=x onerror=alert($i)>'),
                ),
            ],
          ),
        );
        final body = bodyOf(html);
        expect(body, isNot(contains('<img')));
        final classes = {
          for (final m in RegExp(r'<button class="(t\w+)"').allMatches(body))
            m[1],
        };
        expect(classes, hasLength(1));
        for (final m in RegExp('class="([^"]*)"').allMatches(body)) {
          expect(m[1]!.split(' '), hasLength(1));
        }
      },
    );

    test('is as tall as its Row, like Flutter\'s rail', () async {
      final html = await page(
        Row(
          children: [
            NavigationRail(selectedIndex: 0, destinations: const [_home]),
            const Expanded(child: Text('body')),
          ],
        ),
      );
      expect(ruleOf(html, 'NavigationRail'), contains('align-self: stretch'));
    });

    test(
      'useIndicator: false with an indicatorColor asserts, like Flutter',
      () {
        expect(
          () => NavigationRail(
            selectedIndex: 0,
            useIndicator: false,
            indicatorColor: const Color(0xFFFF0000),
            destinations: const [_home],
          ),
          throwsA(isA<AssertionError>()),
        );
      },
    );

    test(
      'keyboard: every destination is natively focusable with a ring',
      () async {
        final html = await page(
          NavigationRail(
            selectedIndex: 0,
            destinations: const [
              NavigationRailDestination(
                icon: Text('h'),
                label: Text('Home'),
                href: '/',
              ),
              _cart,
            ],
          ),
        );
        final body = bodyOf(html);
        expect(body, isNot(contains('tabindex="-1"')));
        // Links with href and buttons are in the tab order; the ring shows on
        // :focus-visible only (keyboard), and is not clipped by the rail.
        expect(stylesOf(html), contains(':focus-visible'));
        expect(stylesOf(html), contains('outline: 2px solid'));
      },
    );

    test('RTL: no physical left/right in the rail\'s CSS', () async {
      final html = await page(
        NavigationRail(
          selectedIndex: 0,
          extended: true,
          destinations: const [_home],
        ),
      );
      // The page's `dir` flips it: nothing physical in the rail's CSS.
      final css = stylesOf(html);
      expect(css, isNot(contains('margin-left')));
      expect(css, isNot(contains('padding-left')));
      expect(css, isNot(contains('text-align: left')));
    });

    test(
      'NavigationRailTheme: ThemeData and a subtree set the defaults',
      () async {
        final themed = await renderDocument(
          ThorApp(
            theme: ThemeData(
              navigationRailTheme: const NavigationRailThemeData(
                backgroundColor: Color(0xFF112233),
                minWidth: 100,
                labelType: NavigationRailLabelType.all,
                indicatorColor: Color(0xFF445566),
                groupAlignment: 1,
                elevation: 4,
              ),
            ),
            child: NavigationRail(selectedIndex: 0, destinations: [_home]),
          ),
        );
        final rule = ruleOf(themed, 'NavigationRail');
        expect(rule, contains('min-width: 100px'));
        expect(rule, contains('justify-content: flex-end'));
        expect(rule, contains('box-shadow'));
        expect(rule.toLowerCase(), contains('#112233'));
        expect(stylesOf(themed).toLowerCase(), contains('#445566'));
        // Labels all shown: not clipped to screen readers only.
        expect(stylesOf(themed), isNot(contains('clip-path: inset(50%)')));

        // The widget's own value wins; a subtree theme beats the app's.
        final own = await page(
          NavigationRailTheme(
            data: const NavigationRailThemeData(minWidth: 120),
            child: NavigationRail(
              selectedIndex: 0,
              minWidth: 90,
              destinations: [_home],
            ),
          ),
        );
        expect(ruleOf(own, 'NavigationRail'), contains('min-width: 90px'));
        final sub = await page(
          NavigationRailTheme(
            data: const NavigationRailThemeData(minWidth: 120),
            child: NavigationRail(selectedIndex: 0, destinations: [_home]),
          ),
        );
        expect(ruleOf(sub, 'NavigationRail'), contains('min-width: 120px'));
      },
    );

    test(
      'inside a Scaffold body Row it stays one column of the body',
      () async {
        final html = await page(
          Scaffold(
            body: Row(
              children: [
                NavigationRail(selectedIndex: 0, destinations: [_home]),
                const Expanded(child: Text('body')),
              ],
            ),
          ),
        );
        expect('<nav '.allMatches(html), hasLength(1));
        expect(ruleOf(html, 'NavigationRail'), contains('align-self: stretch'));
      },
    );
  });
}
