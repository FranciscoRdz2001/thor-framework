@TestOn('vm')
library;

// `.when()` inside a state (a hover that also changes by breakpoint) and
// named hover groups: all server-compiled into the element's class.
import 'package:test/test.dart';
import 'package:thor_ui/src/foundation/element.dart' show thorElement;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Widget child) => renderDocument(ThorApp(child: child));

String _css(String page) => RegExp(
  r'<style id="thor-styles">(.*?)</style>',
  dotAll: true,
).firstMatch(page)![1]!;

const _black = Color(0xFF000000);
const _white = Color(0xFFFFFFFF);
const _gray = Color(0xFF888888);

void main() {
  setUpAll(initializeThorTests);

  group('variants inside a state', () {
    test('hover that changes from md up: one class, a compound rule', () async {
      final page = await _page(
        Container(
          color: _black.when(hover: _white.when(medium: _gray)),
          child: const Text('x'),
        ),
      );
      final css = _css(page);
      // Plain hover guarded by the pointer media, then the same under md.
      expect(css, contains('@media (hover: hover){'));
      final plain = css.indexOf(':hover{background-color: #ffffff');
      final compound = RegExp(
        r'@media screen and \(min-width: \d+px\)\{@media \(hover: hover\)\{[^}]*:hover\{background-color: #888888',
      ).firstMatch(css);
      expect(plain, greaterThan(-1), reason: css);
      expect(compound, isNotNull, reason: css);
      expect(compound!.start, greaterThan(plain), reason: 'wins by order');
      expect(RegExp(r'class="([^" ]+)"').allMatches(page).length, 1);
    });

    test('a breakpoint with its own hover is the same rule', () async {
      final css = _css(
        await _page(
          Container(
            color: _black.when(medium: _white.when(hover: _gray)),
            child: const Text('x'),
          ),
        ),
      );
      expect(
        css,
        contains('@media (hover: hover){'),
        reason: 'hover stays guarded',
      );
      expect(css, contains('background-color: #888888'));
    });

    test('a ConditionalCss whose values carry breakpoints', () async {
      final css = _css(
        await _page(
          Builder(
            builder: (context) => thorElement(
              'div',
              css: const {},
              conditions: [
                ConditionalCss(CssCondition.hover, {
                  'color': markAdaptive('red', {'medium': 'blue'}),
                }),
              ],
              children: const [Text('x')],
            ),
          ),
        ),
      );
      expect(css, contains(':hover{color: red'));
      expect(css, contains('@media screen and (min-width:'));
      expect(css, contains(':hover{color: blue'));
    });

    test('in dark mode: the compound keeps both rules of the scheme', () async {
      final css = _css(
        await _page(
          Container(
            color: _black.when(dark: _white.when(medium: _gray)),
            child: const Text('x'),
          ),
        ),
      );
      expect(css, contains('prefers-color-scheme: dark'));
      expect(css, contains('#888888'));
    });
  });

  group('named HoverGroup', () {
    test('a name makes its own class and its own selector', () async {
      final page = await _page(
        HoverGroup(
          name: 'card',
          child: Column(
            children: [
              Styled(
                style: const StyleProps(
                  opacity: 1,
                ).when(groupHovers: {'card': const StyleProps(opacity: 0.5)}),
                child: const Text('a'),
              ),
              Styled(
                style: const StyleProps(
                  opacity: 1,
                ).when(groupHover: const StyleProps(opacity: 0.25)),
                child: const Text('b'),
              ),
            ],
          ),
        ),
      );
      final css = _css(page);
      expect(page, contains('t-group-card'));
      expect(page, isNot(contains('class="t-group"')));
      expect(css, contains(':where(.t-group-card:hover) '));
      expect(css, contains('opacity: 0.5'));
      // The unnamed group is another one.
      expect(css, contains(':where(.t-group:hover) '));
      expect(
        RegExp(
          r'\.t-group-card:hover\) [^{]*\{[^}]*opacity: 0.25',
        ).hasMatch(css),
        isFalse,
      );
    });

    test('guarded like every hover', () async {
      final css = _css(
        await _page(
          HoverGroup(
            name: 'card',
            child: Styled(
              style: const StyleProps().when(
                groupHovers: {'card': const StyleProps(opacity: 0.5)},
              ),
              child: const Text('a'),
            ),
          ),
        ),
      );
      expect(
        css,
        contains('@media (hover: hover){:where(.t-group-card:hover)'),
      );
    });

    test('two groups nest and are addressed apart', () async {
      final css = _css(
        await _page(
          HoverGroup(
            name: 'outer',
            child: HoverGroup(
              name: 'inner',
              child: Styled(
                style: const StyleProps().when(
                  groupHovers: {
                    'outer': const StyleProps(opacity: 0.4),
                    'inner': const StyleProps(opacity: 0.6),
                  },
                ),
                child: const Text('a'),
              ),
            ),
          ),
        ),
      );
      expect(css, contains('.t-group-outer:hover'));
      expect(css, contains('.t-group-inner:hover'));
    });

    test('a name is one plain token', () async {
      for (final bad in ['', 'a b', 'a+b', '1a', 'a/b']) {
        await expectLater(
          _page(HoverGroup(name: bad, child: const Text('x'))),
          throwsA(anything),
          reason: '"$bad"',
        );
      }
    });

    test('a named group variant composes with a breakpoint', () async {
      final css = _css(
        await _page(
          HoverGroup(
            name: 'card',
            child: Container(
              color: _black.when(
                groupHovers: {'card': _white.when(medium: _gray)},
              ),
              child: const Text('x'),
            ),
          ),
        ),
      );
      expect(
        RegExp(
          r'@media screen and \(min-width: \d+px\)\{@media \(hover: hover\)\{:where\(\.t-group-card:hover\)',
        ).hasMatch(css),
        isTrue,
        reason: css,
      );
    });
  });
}
