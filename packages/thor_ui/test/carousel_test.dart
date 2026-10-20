@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// CarouselView's arrows (`::scroll-button`), dots (`::scroll-marker`) and
// autoplay: what the server writes, in the CSS and the markup.

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));
String head(String html) => html.substring(0, html.indexOf('</head>'));
String bodyOf(String html) => html.substring(html.indexOf('<body'));

/// The declarations of the rule whose selector ends with [selector].
String rule(String css, String selector) {
  final i = css.indexOf('$selector{');
  expect(i, isNonNegative, reason: 'no rule for $selector in\n$css');
  return css.substring(i, css.indexOf('}', i));
}

CarouselView carousel({
  bool showArrows = true,
  ButtonStyle? arrowStyle,
  CarouselArrowPosition arrowPosition = CarouselArrowPosition.inside,
  bool showIndicators = false,
  CarouselIndicatorStyle? indicatorStyle,
  Duration? autoPlay,
  IconData? arrowIcon,
  double? arrowInset,
}) => CarouselView(
  label: 'Hero',
  showArrows: showArrows,
  arrowStyle: arrowStyle,
  arrowPosition: arrowPosition,
  showIndicators: showIndicators,
  indicatorStyle: indicatorStyle,
  autoPlay: autoPlay,
  arrowIcon: arrowIcon,
  arrowInset: arrowInset,
  children: const [Text('a'), Text('b'), Text('c')],
);

void main() {
  setUpAll(() => initializeThorTests(compactHtml: false));

  group('arrows', () {
    test('sit inside the carousel by default: never past its box', () async {
      final css = head(await page(carousel()));
      expect(
        rule(css, '::scroll-button(left)'),
        contains('left: calc(anchor(left) + 8px)'),
      );
      expect(
        rule(css, '::scroll-button(right)'),
        contains('left: calc(anchor(right) - 44px)'),
      );
      expect(css, isNot(contains('anchor(left) - 48px')));
    });

    test('in a right-to-left page the left arrow is the Next', () async {
      final css = head(await page(carousel()));
      expect(
        rule(css, ':dir(rtl)::scroll-button(left)'),
        contains("content: '' / 'Next'"),
      );
      expect(
        rule(css, ':dir(rtl)::scroll-button(right)'),
        contains("content: '' / 'Previous'"),
      );
    });

    test('outside never leaves the viewport', () async {
      final css = head(
        await page(carousel(arrowPosition: CarouselArrowPosition.outside)),
      );
      // Clamped: where there is no room they fall back over the carousel.
      expect(
        rule(css, '::scroll-button(left)'),
        contains('max(8px, calc(anchor(left) - 52px))'),
      );
      expect(
        rule(css, '::scroll-button(right)'),
        contains('min(calc(100% - 44px), calc(anchor(right) + 16px))'),
      );
    });

    test('are styled with a ButtonStyle', () async {
      final css = head(
        await page(
          carousel(
            arrowStyle: IconButton.styleFrom(
              backgroundColor: const Color(0xFF1B2A6B),
              foregroundColor: const Color(0xFFFFFFFF),
              minimumSize: const Size.square(34),
              shape: const StadiumBorder(),
            ),
          ),
        ),
      );
      final r = rule(css, '::scroll-button(left)');
      expect(r, contains('width: 34px'));
      expect(r, contains('height: 34px'));
      expect(r, contains('background-color: #1b2a6b'));
      expect(r, contains('border-radius: 9999px'));
      // The glyph is an image: its color is baked in the data URI.
      expect(
        rule(css, '::scroll-button(left)'),
        contains('stroke%3D%22%23ffffff%22'),
      );
    });

    test('a theme color for the glyph falls back to its fallback', () async {
      final css = head(
        await page(
          carousel(
            arrowStyle: IconButton.styleFrom(
              foregroundColor: const Color.variable(
                CssVariable('--brand'),
                fallback: Color(0xFF123456),
              ),
            ),
          ),
        ),
      );
      expect(rule(css, '::scroll-button(left)'), contains('%23123456'));
    });

    test('showArrows: false writes no arrow rules', () async {
      final css = head(await page(carousel(showArrows: false)));
      expect(css, isNot(contains('::scroll-button')));
      expect(css, isNot(contains('anchor-name')));
    });
  });

  group('arrowIcon and arrowInset', () {
    const next = IconData.svg('t-next', '<path d="M8 4l8 8-8 8"/>');
    const stroked = IconData.svg(
      't-stroked',
      '<path d="M8 4l8 8-8 8"/>',
      strokeWidth: 3,
    );
    const wide = IconData.svg(
      't-wide',
      '<path d="M0 0h40v8H0z"/>',
      viewBox: '0 0 40 16',
    );

    /// The SVG the rule's `background-image` holds, decoded.
    String svgOf(String rule) {
      final m = RegExp(
        r'url\("data:image/svg\+xml,([^"]*)"\)',
      ).firstMatch(rule);
      expect(m, isNotNull, reason: rule);
      return Uri.decodeComponent(m![1]!);
    }

    test('the glyph is the icon, drawn forward on the right and mirrored on '
        'the left, in the foreground color', () async {
      final css = head(
        await page(
          carousel(
            arrowIcon: next,
            arrowStyle: IconButton.styleFrom(
              foregroundColor: const Color(0xFFFFFFFF),
            ),
          ),
        ),
      );
      final right = svgOf(rule(css, '::scroll-button(right)'));
      final left = svgOf(rule(css, '::scroll-button(left)'));
      expect(right, contains('<path d="M8 4l8 8-8 8"/>'));
      expect(right, contains('fill="#ffffff"'));
      expect(right, contains('viewBox="0 0 24 24"'));
      expect(right, isNot(contains('matrix')));
      expect(left, contains('matrix(-1 0 0 1 24 0)'));
      expect(left, contains('<path d="M8 4l8 8-8 8"/>'));
    });

    test(
      'a stroke icon keeps its stroke; a viewBox sets the mirror axis',
      () async {
        var css = head(await page(carousel(arrowIcon: stroked)));
        var right = svgOf(rule(css, '::scroll-button(right)'));
        expect(right, contains('stroke-width="3"'));
        expect(right, contains('fill="none"'));
        css = head(await page(carousel(arrowIcon: wide)));
        right = svgOf(rule(css, '::scroll-button(left)'));
        expect(right, contains('matrix(-1 0 0 1 40 0)'));
        expect(right, contains('viewBox="0 0 40 16"'));
      },
    );

    test('the fallback buttons (Firefox, Safari) draw the same icon', () async {
      final css = head(await page(carousel(arrowIcon: next)));
      final images = RegExp(
        r'background-image: url\("data:image/svg\+xml,[^"]*M8%204l8%208-8%208[^"]*"\)',
      ).allMatches(css);
      // Native left and right, fallback prev and next.
      expect(images.length, 4, reason: css);
      expect(
        images.where(
          (m) => Uri.decodeComponent(m[0]!).contains('matrix(-1 0 0 1 24 0)'),
        ),
        hasLength(2),
        reason: 'the previous arrow, native and fallback, is the mirrored one',
      );
    });

    test('without arrowIcon the chevrons are as before', () async {
      final css = head(await page(carousel()));
      expect(
        svgOf(rule(css, '::scroll-button(left)')),
        contains('m15 18-6-6 6-6'),
      );
      expect(
        svgOf(rule(css, '::scroll-button(right)')),
        contains('m9 18 6-6-6-6'),
      );
    });

    test('a font-glyph icon cannot be a pseudo-element image', () async {
      expect(
        () => page(
          carousel(arrowIcon: const IconData(0xe5e0, fontFamily: 'Icons')),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('arrowInset moves the arrows from the edge, inside', () async {
      final doc = await page(carousel(arrowInset: 20));
      final css = head(doc);
      expect(
        rule(css, '::scroll-button(left)'),
        contains('left: calc(anchor(left) + 20px)'),
      );
      expect(
        rule(css, '::scroll-button(right)'),
        contains('left: calc(anchor(right) - 56px)'),
      );
      // The fallback buttons follow the page direction.
      expect(css, contains('margin-inline-start: 20px'));
      expect(css, contains('margin-inline-end: 20px'));
      expect(css, contains(':dir(rtl){transform: scaleX(-1)}'));
    });

    test(
      'arrowInset is the gap outside, still clamped to the viewport',
      () async {
        final css = head(
          await page(
            carousel(
              arrowInset: 24,
              arrowPosition: CarouselArrowPosition.outside,
            ),
          ),
        );
        expect(
          rule(css, '::scroll-button(left)'),
          contains('max(8px, calc(anchor(left) - 60px))'),
        );
        expect(
          rule(css, '::scroll-button(right)'),
          contains('min(calc(100% - 44px), calc(anchor(right) + 24px))'),
        );
      },
    );

    test('a negative arrowInset is a mistake', () {
      expect(
        () => CarouselView(arrowInset: -1, children: const []),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('dots', () {
    test('are off by default', () async {
      final css = head(await page(carousel()));
      expect(css, isNot(contains('scroll-marker')));
    });

    test(
      'showIndicators draws one marker per item, current one marked',
      () async {
        final doc = await page(carousel(showIndicators: true));
        final css = head(doc);
        expect(css, contains('scroll-marker-group: after'));
        expect(
          rule(css, '::scroll-marker-group'),
          contains('position: absolute'),
        );
        expect(
          rule(css, ' > *::scroll-marker'),
          contains("content: '' / 'Slide ' counter(t-slide) ' of 3'"),
        );
        expect(css, contains(':target-current'));
        // Room under the carousel for the dots.
        expect(css, contains('padding-bottom'));
      },
    );

    test('are styled and can sit over the items', () async {
      final css = head(
        await page(
          carousel(
            showIndicators: true,
            indicatorStyle: const CarouselIndicatorStyle(
              color: Color(0xFFCCCCCC),
              activeColor: Color(0xFF1B2A6B),
              size: 10,
              position: CarouselIndicatorPosition.inside,
            ),
          ),
        ),
      );
      expect(rule(css, ' > *::scroll-marker'), contains('width: 10px'));
      expect(
        rule(css, ' > *::scroll-marker'),
        contains('background-color: #cccccc'),
      );
      expect(
        rule(css, ' > *::scroll-marker:target-current'),
        contains('background-color: #1b2a6b'),
      );
      expect(css, isNot(contains('padding-bottom: 32px')));
    });

    test('labels are escaped and localizable', () async {
      final css = head(
        await page(
          const CarouselView(
            previousLabel: 'Back "x"',
            nextLabel: 'Forward',
            slideLabel: 'Diapositiva',
            slideOfLabel: 'de',
            showIndicators: true,
            children: [Text('a'), Text('b')],
          ),
        ),
      );
      expect(css, contains(r"'' / 'Back \22 x\22 '"));
      expect(css, contains("'' / 'Forward'"));
      expect(css, contains("'' / 'Diapositiva ' counter(t-slide) ' de 2'"));
    });
  });

  group('fallback controls', () {
    test('real buttons, hidden until the engine shows them', () async {
      final body = bodyOf(await page(carousel(showIndicators: true)));
      expect(body, contains('data-t-cv'));
      expect(
        RegExp(r'<button[^>]*hidden[^>]*data-t-cv-prev').hasMatch(body),
        isTrue,
        reason: body,
      );
      expect(body, contains('aria-label="Previous"'));
      expect(body, contains('aria-label="Next"'));
      expect(
        RegExp(r'<div[^>]*hidden[^>]*data-t-cv-dots').hasMatch(body),
        isTrue,
      );
      expect(
        RegExp('aria-label="Slide [123] of 3"').allMatches(body),
        hasLength(3),
        reason: 'the dot says where it is and how many there are',
      );
    });

    test('are styled like the native ones', () async {
      final doc = await page(
        carousel(
          arrowStyle: IconButton.styleFrom(
            backgroundColor: const Color(0xFF1B2A6B),
            minimumSize: const Size.square(34),
          ),
        ),
      );
      final css = head(doc);
      expect(css, contains('[hidden]{display: none}'));
      expect(css, contains('grid-area: 1 / 1'));
      expect(css, contains('width: 34px'));
    });

    test(
      'one item or none: nothing to move, so no arrows, dots or engine',
      () async {
        for (final n in [0, 1]) {
          final doc = await page(
            CarouselView(
              label: 'Hero',
              showIndicators: true,
              children: [for (var i = 0; i < n; i++) const Text('a')],
            ),
          );
          expect(bodyOf(doc), isNot(contains('data-t-cv')), reason: '$n items');
          expect(doc, isNot(contains('data-thor-engine')), reason: '$n items');
          expect(doc, isNot(contains('::scroll-button')), reason: '$n items');
          expect(doc, isNot(contains('::scroll-marker')), reason: '$n items');
          expect(doc, isNot(contains('anchor-name')), reason: '$n items');
        }
      },
    );

    test('no controls, no wrapper and no engine', () async {
      final body = bodyOf(await page(carousel(showArrows: false)));
      expect(body, isNot(contains('data-t-cv')));
    });
  });

  group('autoplay', () {
    test('is off by default', () async {
      final doc = await page(carousel());
      expect(bodyOf(doc), isNot(contains('data-t-carousel')));
    });

    test('writes the interval for the engine', () async {
      final doc = await page(carousel(autoPlay: const Duration(seconds: 5)));
      expect(bodyOf(doc), contains('data-t-carousel="5000"'));
    });

    test('a zero or negative interval is rejected', () {
      expect(
        () => carousel(autoPlay: Duration.zero),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
