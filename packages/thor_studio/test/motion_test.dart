// The studio's motion, read in the CSS it emits: what moves, how long, on
// which curve, and that nothing moves under `prefers-reduced-motion`. These
// are the rules the browser plays; nothing here needs a browser.
import 'package:test/test.dart';
import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

final _theme = StudioTheme.light();
final _dark = StudioTheme.dark();

Future<String> _head(Widget child) async => headOfPage(
  await renderDocument(ThorApp(theme: _theme, darkTheme: _dark, child: child)),
);

/// The rules of [css] whose selector contains [selector], one per entry.
List<String> _rules(String css, String selector) => [
  for (final m in RegExp(r'([^{}]+)\{([^{}]*)\}').allMatches(css))
    if (m[1]!.contains(selector)) m[0]!.trim(),
];

/// The strong ease-out the studio enters and presses with.
const _enter = 'cubic-bezier(0.23, 1, 0.32, 1)';

void main() {
  setUpAll(initializeThorTests);

  group('tokens', () {
    test('nothing goes over 200 ms and there is no ease-in', () {
      expect(StudioDurations.fast.inMilliseconds, 120);
      expect(StudioDurations.base.inMilliseconds, 160);
      expect(StudioDurations.slow.inMilliseconds, 200);
      expect(StudioCurves.enter.css, _enter);
      expect(StudioCurves.move.css, 'cubic-bezier(0.4, 0, 0.2, 1)');
    });

    test('a press squeezes, a card squeezes less, nothing starts from 0', () {
      expect(StudioMotion.pressScale, 0.97);
      expect(StudioMotion.pressScaleLarge, greaterThan(0.97));
      expect(StudioMotion.enterScale, greaterThan(0.9));
      expect(StudioMotion.hoverLift, lessThanOrEqualTo(4));
    });
  });

  group('segmented thumb', () {
    Widget control(int n) => StudioSegmentedControl<int>(
      semanticLabel: 'Switch',
      selected: const {1},
      segments: [
        for (var i = 0; i < n; i++)
          StudioButtonSegment(value: i, label: Text('S$i')),
      ],
    );

    test(
      'is the groove\'s ::before, put on the checked cell by anchor',
      () async {
        final head = await _head(control(3));
        final thumb = _rules(head, '::before').join('\n');
        expect(thumb, contains('content: ""'));
        expect(thumb, contains('position: absolute'));
        // The checked cell is the anchor: its edges and size, nothing measured.
        expect(thumb, contains('position-anchor: --t-seg'));
        expect(thumb, contains('left: anchor(left)'));
        expect(thumb, contains('width: anchor-size(width)'));
        expect(thumb, contains('pointer-events: none'));
        expect(thumb, isNot(contains('transition: all')));
        expect(thumb, isNot(contains('calc((100% -')));
        // No rule per position: the browser follows the anchor.
        expect(head, isNot(contains(':nth-child(2) :checked')));
        // The page is right at first paint: it is a CSS rule on the checked
        // radio, not a class a script swaps.
        expect(head, isNot(contains('classList')));
      },
    );

    test('long labels wrap onto another row; the thumb follows', () async {
      final head = await _head(
        StudioSegmentedControl<int>(
          semanticLabel: 'Rows',
          selected: const {3},
          segments: [
            for (var i = 0; i < 5; i++)
              StudioButtonSegment(value: i, label: const Text('Label')),
          ],
        ),
      );
      expect(head, contains('flex-wrap: wrap'));
      expect(head, isNot(contains('repeat(5, minmax(0, 1fr))')));
      expect(head, isNot(contains('translate: 300% 0')));
    });

    test('the thumb jumps under prefers-reduced-motion', () async {
      final head = await _head(control(2));
      final guard = RegExp(
        r'@media \(prefers-reduced-motion: reduce\)\s*\{[^{}]*::before\s*\{'
        r'[^{}]*transition: none',
      );
      expect(head, matches(guard));
    });
  });

  group('level slider', () {
    test(
      'the grip grows when held or focused, a little when hovered',
      () async {
        final head = await _head(
          const StudioLevelSlider(
            title: 'Radius',
            value: 10,
            max: 20,
            onChanged: _noop,
          ),
        );
        final thumb = _rules(head, '::-webkit-slider-thumb').join('\n');
        expect(
          thumb,
          contains('transition: scale 160ms cubic-bezier(0.4, 0, 0.2, 1)'),
        );
        expect(thumb, contains(':is(:active, :focus-visible)'));
        expect(thumb, contains('scale: ${StudioMotion.gripScale}'));
        // The hover is only where there is a pointer that hovers.
        expect(head, contains('@media (hover: hover)'));
        expect(thumb, contains('scale: ${StudioMotion.gripHoverScale}'));
      },
    );

    test('the grip does not grow under prefers-reduced-motion', () async {
      final head = await _head(
        const StudioLevelSlider(
          title: 'Radius',
          value: 10,
          max: 20,
          onChanged: _noop,
        ),
      );
      expect(
        head,
        matches(
          RegExp(
            r'@media \(prefers-reduced-motion: reduce\)\s*\{[^{}]*'
            r'::-webkit-slider-thumb\s*\{[^{}]*transition: none',
          ),
        ),
      );
    });
  });

  group('press feedback', () {
    test('a nav item squeezes to .97', () async {
      final top = await _head(
        const StudioTopBar(
          brand: StudioBrand(name: 'thor'),
          links: [StudioNavDestination('Guide', href: '/guide')],
          linksLabel: 'Sections',
        ),
      );
      expect(top, contains('scale: 0.97'));
    });

    test('a chip squeezes with the studio curve', () async {
      final chip = await _head(
        const StudioFilterChip(
          label: Text('Buttons'),
          href: '/b',
          selected: false,
        ),
      );
      expect(chip, contains(':active'));
      expect(chip, contains('scale: 0.97'));
      expect(chip, contains(_enter));
    });

    test('the press is dropped under prefers-reduced-motion', () async {
      final head = await _head(
        const StudioFilterChip(
          label: Text('Buttons'),
          href: '/b',
          selected: false,
        ),
      );
      // Styled's guard: the transition collapses to 1 ms.
      expect(
        head,
        matches(
          RegExp(
            r'@media \(prefers-reduced-motion: reduce\)\s*\{[^{}]*\{[^{}]*'
            r'transition-duration: 1ms',
          ),
        ),
      );
    });
  });

  group('cards', () {
    test(
      'a link card changes its border and surface on hover and squeezes on press',
      () async {
        final head = await _head(
          const StudioLinkCard(title: 'Architecture', href: '/a'),
        );
        // No lift and no arrow: the hover is color only.
        expect(head, isNot(contains('translate: 0px -2px')));
        expect(head, contains('scale: ${StudioMotion.pressScaleLarge}'));
        // Where the pointer hovers, never on touch.
        expect(head, contains('(hover: hover)'));
        // transform-like properties only: no `top`, `margin`, `box-shadow` move.
        expect(head, isNot(contains('transition: all')));
      },
    );

    test('a pager card lifts and its arrow points where it goes', () async {
      final head = await _head(
        const StudioPagerLinks(
          label: 'Pages',
          previousLabel: 'Previous',
          nextLabel: 'Next',
          previous: StudioNavDestination('Layout', href: '/l'),
          next: StudioNavDestination('Navigation', href: '/n'),
        ),
      );
      expect(head, contains('translate: 0px -2px'));
      expect(head, contains('translate: 3px'));
      expect(head, contains('translate: -3px'));
    });
  });

  group('bench', () {
    Widget bench({String? replay}) => StudioBench(
      id: 'm1',
      replayLabel: replay,
      stage: const Text('STAGE'),
      code: const Text('CODE'),
    );

    test('the Code pane rises in as it is shown, 200 ms', () async {
      final head = await _head(bench());
      expect(head, contains('@starting-style'));
      expect(head, contains('opacity: 0'));
      expect(head, matches(RegExp(r'translate: 0px 8(\.0)?px')));
      expect(head, contains('transition-duration: 200ms'));
      expect(head, contains('transition-timing-function: $_enter'));
    });

    test('the replay icon turns half a turn on every press', () async {
      final head = await _head(bench(replay: 'Replay'));
      expect(head, contains('rotate: -0.5turn'));
      expect(head, contains('input[name="m1-replay"]:checked'));
    });
  });

  group('theme toggle', () {
    test(
      'the icon that shows turns and grows in; the switch squeezes',
      () async {
        final head = await _head(const StudioThemeToggle());
        expect(head, contains('@starting-style'));
        expect(head, contains('rotate: -0.25turn'));
        expect(head, contains('rotate: 0.25turn'));
        expect(head, contains('scale: 0.6'));
        expect(head, contains('scale: 0.97'));
      },
    );
  });

  group('table of contents', () {
    test('the scroll spy fades the color and the rule', () async {
      final head = await _head(
        const StudioTableOfContents(
          title: 'On this page',
          scrollSpy: true,
          entries: [StudioTocEntry('One', href: '#one')],
        ),
      );
      expect(head, contains('transition-property: color, border-left-color'));
      expect(head, contains(':target-current'));
    });
  });

  group('theme fade', () {
    test(
      'every color token is a registered <color> and transitions on :root',
      () {
        final rules = StudioMotionStyles.themeFade.map((r) => r.toCss()).join();
        for (final token in StudioPalette.values) {
          expect(rules, contains('@property --t-${token.name}'));
          expect(rules, contains('--t-${token.name} 160ms ease'));
        }
        expect(rules, contains('syntax: "\\3c color>"'));
        expect(rules, contains('inherits: true'));
      },
    );

    test('themeFadeWith adds the app\'s tokens once', () {
      const own = ColorToken(
        'kind-error',
        light: Color(0xFFD32020),
        dark: Color(0xFFF87171),
      );
      final rules = StudioMotionStyles.themeFadeWith([
        own,
        own,
        StudioPalette.values.first,
      ]).map((r) => r.toCss()).join();
      expect(rules, contains('@property --t-kind-error'));
      expect(rules, contains('--t-kind-error 160ms ease'));
      expect('@property --t-kind-error'.allMatches(rules), hasLength(1));
      final first = StudioPalette.values.first.name;
      expect('@property --t-$first '.allMatches(rules), hasLength(1));
      // The plain list has none of it.
      final plain = StudioMotionStyles.themeFade.map((r) => r.toCss()).join();
      expect(plain, isNot(contains('kind-error')));
    });

    test('only where motion is welcome', () {
      final css = StudioMotionStyles.themeFade.map((r) => r.toCss()).join();
      final transition = css.substring(css.indexOf('@media'));
      expect(
        transition,
        startsWith('@media (prefers-reduced-motion: no-preference)'),
      );
      expect(transition, contains(':root'));
      // The @property rules are not inside the media query.
      expect(css.indexOf('@property'), lessThan(css.indexOf('@media')));
    });
  });
}

void _noop(double _) {}
