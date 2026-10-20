@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _css(Widget w) => renderDocument(w);

void main() {
  setUpAll(initializeThorTests);

  group('EdgeInsetsGeometry given as a Length', () {
    test('a variable with and without fallback', () {
      const bare = EdgeInsetsGeometry.allLength(
        Length.variable(CssVariable('--pad')),
      );
      expect(bare.toCss('padding'), {'padding': 'var(--pad)'});
      const fallback = EdgeInsetsGeometry.allLength(
        Length.variable(CssVariable('--pad'), fallback: Length.px(16)),
      );
      expect(fallback.toCss('padding'), {'padding': 'var(--pad, 16px)'});
    });

    test('each side and the shortest shorthand', () {
      const v = Length.variable(CssVariable('--x'));
      expect(
        const EdgeInsetsGeometry.symmetricLength(horizontal: v).toCss('margin'),
        {'margin': '0 var(--x)'},
      );
      expect(
        const EdgeInsetsGeometry.onlyLength(
          left: v,
          top: Length.px(4),
        ).toCss('padding'),
        {'padding': '4px 0 0 var(--x)'},
      );
      expect(
        const EdgeInsetsGeometry.allLength(Length.percent(5)).toCss('padding'),
        {'padding': '5%'},
      );
    });

    test('equal by CSS and addable into calc()', () {
      expect(
        const EdgeInsetsGeometry.allLength(Length.px(8)),
        const EdgeInsetsGeometry.allLength(Length.px(8)),
      );
      expect(
        (const EdgeInsetsGeometry.allLength(Length.px(8)) + EdgeInsets.zero)
            .toCss('padding'),
        {'padding': '8px'},
      );
      expect(
        (const EdgeInsetsGeometry.allLength(
                  Length.variable(CssVariable('--g')),
                ) +
                const EdgeInsets.all(4))
            .toCss('padding'),
        {'padding': 'calc(var(--g) + 4px)'},
      );
    });

    test('a pixel inset is unchanged', () {
      expect(const EdgeInsets.all(8).css, '8px');
      expect(const EdgeInsets.symmetric(horizontal: 4).css, '0px 4px');
    });

    test('the stylesheet writes the variable (padding)', () async {
      final css = await _css(
        const Container(
          padding: EdgeInsetsGeometry.allLength(
            Length.variable(CssVariable('--pad'), fallback: Length.px(16)),
          ),
          child: Text('a'),
        ),
      );
      expect(css, contains('padding: var(--pad, 16px)'));
      final bare = await _css(
        const Container(
          padding: EdgeInsetsGeometry.symmetricLength(
            vertical: Length.variable(CssVariable('--v')),
          ),
          child: Text('a'),
        ),
      );
      expect(bare, contains('padding: var(--v) 0'));
    });

    test('inside breakpoint variants', () async {
      // `EdgeInsets.when` keeps an EdgeInsets (its variants are EdgeInsets):
      // a Length variant is given on the geometry.
      const EdgeInsetsGeometry base = EdgeInsets.all(8);
      final css = await _css(
        Container(
          padding: base.when(
            medium: const EdgeInsetsGeometry.allLength(
              Length.variable(CssVariable('--pad')),
            ),
          ),
          child: const Text('a'),
        ),
      );
      expect(css, contains('padding: 8px'));
      expect(css, contains('padding: var(--pad)'));
    });

    test('a Length geometry carries variants of its own', () async {
      final css = await _css(
        Container(
          padding: const EdgeInsetsGeometry.allLength(
            Length.variable(CssVariable('--pad')),
          ).when(medium: const EdgeInsets.all(32)),
          child: const Text('a'),
        ),
      );
      expect(css, contains('padding: var(--pad)'));
      expect(css, contains('padding: 32px'));
    });
  });

  group('BorderRadius given as a Length', () {
    test('a variable with and without fallback', () {
      expect(
        const BorderRadius.circularLength(
          Length.variable(CssVariable('--radius')),
        ).css,
        'var(--radius)',
      );
      expect(
        const BorderRadius.circularLength(
          Length.variable(CssVariable('--radius'), fallback: Length.px(16)),
        ).css,
        'var(--radius, 16px)',
      );
    });

    test('a corner as a Length next to pixel corners', () {
      const r = BorderRadius.only(
        topLeft: Radius.circularLength(Length.variable(CssVariable('--r'))),
        bottomRight: Radius.circular(4),
      );
      expect(r.css, 'var(--r) 0px 4px 0px');
    });

    test('a pixel radius is unchanged', () {
      expect(BorderRadius.circular(8).css, '8px');
      expect(
        const BorderRadius.only(topLeft: Radius.elliptical(4, 2)).css,
        '4px 0px 0px 0px / 2px 0px 0px 0px',
      );
    });

    test('the stylesheet writes the variable (border-radius)', () async {
      final css = await _css(
        const Container(
          decoration: BoxDecoration(
            color: Color(0xff112233),
            borderRadius: BorderRadius.circularLength(
              Length.variable(CssVariable('--radius'), fallback: Length.px(16)),
            ),
          ),
          child: Text('a'),
        ),
      );
      expect(css, contains('border-radius: var(--radius, 16px)'));
    });
  });
}
