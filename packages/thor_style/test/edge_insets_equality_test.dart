// ignore_for_file: prefer_const_constructors
import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

void main() {
  group('EdgeInsets equality', () {
    test('is exact: numbers, not rounded CSS', () {
      expect(EdgeInsets.all(8), EdgeInsets.all(8));
      expect(EdgeInsets.all(8).hashCode, EdgeInsets.all(8).hashCode);
      // The CSS rounds to four decimals; the value does not.
      expect(EdgeInsets.all(8.00001) == EdgeInsets.all(8.00002), isFalse);
      expect(EdgeInsets.all(8) == EdgeInsets.all(9), isFalse);
      expect(
        EdgeInsets.fromLTRB(1, 2, 3, 4) == EdgeInsets.fromLTRB(1, 2, 3, 5),
        isFalse,
      );
    });

    test('a Length geometry is never an EdgeInsets', () {
      final zero = EdgeInsetsGeometry.allLength(Length.zero);
      expect(EdgeInsets.zero == zero, isFalse);
      expect(zero == EdgeInsets.zero, isFalse);
      final variable = EdgeInsetsGeometry.allLength(
        Length.variable(CssVariable('--pad')),
      );
      expect(variable == EdgeInsets.zero, isFalse);
      expect(EdgeInsets.zero == variable, isFalse);
    });

    test('equal Lengths are equal, different ones are not', () {
      final a = EdgeInsetsGeometry.allLength(
        Length.variable(CssVariable('--a')),
      );
      expect(
        a,
        EdgeInsetsGeometry.allLength(Length.variable(CssVariable('--a'))),
      );
      expect(
        a.hashCode,
        EdgeInsetsGeometry.allLength(
          Length.variable(CssVariable('--a')),
        ).hashCode,
      );
      expect(
        a == EdgeInsetsGeometry.allLength(Length.variable(CssVariable('--b'))),
        isFalse,
      );
    });

    test('adaptive insets differ from their base', () {
      final adaptive = EdgeInsets.all(8).when(medium: EdgeInsets.all(16));
      expect(adaptive == EdgeInsets.all(8), isFalse);
      expect(EdgeInsets.all(8) == adaptive, isFalse);
      expect(adaptive, EdgeInsets.all(8).when(medium: EdgeInsets.all(16)));
    });

    test('directional insets compare by their own sides', () {
      expect(
        EdgeInsetsDirectional.only(start: 4),
        EdgeInsetsDirectional.only(start: 4),
      );
      expect(
        EdgeInsetsDirectional.only(start: 4) ==
            EdgeInsetsDirectional.only(end: 4),
        isFalse,
      );
      expect(EdgeInsetsDirectional.zero == EdgeInsets.zero, isFalse);
      expect(EdgeInsets.zero == EdgeInsetsDirectional.zero, isFalse);
    });
  });

  group('value types', () {
    test('Radius, BorderRadius and Offset have value equality', () {
      expect(Radius.circular(4), Radius.circular(4));
      expect(Radius.circular(4).hashCode, Radius.circular(4).hashCode);
      expect(Radius.circular(4) == Radius.elliptical(4, 2), isFalse);
      expect(
        Radius.circularLength(Length.variable(CssVariable('--r'))),
        Radius.circularLength(Length.variable(CssVariable('--r'))),
      );
      expect(Radius.zero == Radius.circularLength(Length.zero), isFalse);
      expect(BorderRadius.circular(8), BorderRadius.circular(8));
      expect(
        BorderRadius.circular(8).hashCode,
        BorderRadius.circular(8).hashCode,
      );
      expect(BorderRadius.circular(8) == BorderRadius.circular(9), isFalse);
      expect(
        BorderRadius.circular(8).copyWith(topLeft: Radius.zero),
        BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
          bottomLeft: Radius.circular(8),
        ),
      );
      expect(Offset(1, 2), Offset(1, 2));
      expect(Offset(1, 2).hashCode, Offset(1, 2).hashCode);
      expect(Offset(1, 2) == Offset(2, 1), isFalse);
    });

    test('Offset arithmetic and lerp', () {
      expect(Offset(1, 2) + Offset(3, 4), Offset(4, 6));
      expect(Offset(3, 4) - Offset(1, 2), Offset(2, 2));
      expect(-Offset(1, 2), Offset(-1, -2));
      expect(Offset(1, 2) * 2, Offset(2, 4));
      expect(Offset(2, 4) / 2, Offset(1, 2));
      expect(Offset.lerp(Offset(0, 0), Offset(10, 20), 0.5), Offset(5, 10));
      expect(Offset.lerp(null, null, 0.5), isNull);
    });

    test('EdgeInsets arithmetic, copyWith and lerp', () {
      expect(
        EdgeInsets.all(8) + EdgeInsets.only(left: 4),
        EdgeInsets.fromLTRB(12, 8, 8, 8),
      );
      expect(EdgeInsets.all(8) - EdgeInsets.all(2), EdgeInsets.all(6));
      expect(-EdgeInsets.all(8), EdgeInsets.all(-8));
      expect(EdgeInsets.all(8) * 2, EdgeInsets.all(16));
      expect(EdgeInsets.all(8) / 2, EdgeInsets.all(4));
      expect(
        EdgeInsets.all(8).copyWith(top: 1),
        EdgeInsets.fromLTRB(8, 1, 8, 8),
      );
      expect(
        EdgeInsets.lerp(EdgeInsets.zero, EdgeInsets.all(8), 0.5),
        EdgeInsets.all(4),
      );
    });
  });

  group('EdgeInsetsGeometry', () {
    test('EdgeInsets + EdgeInsets stays an EdgeInsets', () {
      final sum = EdgeInsets.all(8).add(EdgeInsets.all(4));
      expect(sum, isA<EdgeInsets>());
      expect(sum, EdgeInsets.all(12));
    });

    test('a Length side makes a calc(), from either side', () {
      final gap = EdgeInsetsGeometry.allLength(
        Length.variable(CssVariable('--gap')),
      );
      final both = gap.add(EdgeInsets.all(8));
      expect(both.toCss('padding'), {'padding': 'calc(var(--gap) + 8px)'});
      final flipped = EdgeInsets.all(8).add(gap);
      expect(flipped.toCss('padding'), {'padding': 'calc(8px + var(--gap))'});
      expect((gap + EdgeInsets.symmetric(horizontal: 4)).toCss('padding'), {
        'padding': 'var(--gap) calc(var(--gap) + 4px)',
      });
    });

    test('a sum without Lengths is plain pixels; zero sides stay zero', () {
      final mix = EdgeInsets.only(
        top: 4,
      ).add(EdgeInsetsDirectional.only(start: 8));
      expect(mix.toCss('padding')['padding-inline-start'], '8px');
      expect(mix.toCss('padding')['padding-inline-end'], '0');
      expect(mix.toCss('padding')['padding-top'], '4px');
      expect(mix.toCss('padding')['padding-bottom'], '0');
    });

    test('a physical and a directional horizontal side cannot be summed', () {
      final mixed = EdgeInsets.only(
        left: 4,
      ).add(EdgeInsetsDirectional.only(start: 8));
      expect(
        () => mixed.toCss('padding'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('THOR-R037'),
          ),
        ),
      );
      // Resolved, it is plain physical insets.
      expect(mixed.resolve(TextDirection.ltr).toCss('padding'), {
        'padding': '0 0 0 12px',
      });
      expect(mixed.resolve(TextDirection.rtl).toCss('padding'), {
        'padding': '0 8px 0 4px',
      });
    });

    test('resolve puts start on the left in ltr and on the right in rtl', () {
      final d = EdgeInsetsDirectional.fromSTEB(1, 2, 3, 4);
      expect(d.resolve(TextDirection.ltr), EdgeInsets.fromLTRB(1, 2, 3, 4));
      expect(d.resolve(TextDirection.rtl), EdgeInsets.fromLTRB(3, 2, 1, 4));
      expect(d.flipped, EdgeInsetsDirectional.fromSTEB(3, 2, 1, 4));
      expect(EdgeInsets.all(4).resolve(TextDirection.rtl), EdgeInsets.all(4));
    });

    test('directional insets are written as logical properties', () {
      expect(
        EdgeInsetsDirectional.only(
          start: 16,
          end: 4,
          top: 8,
          bottom: 2,
        ).toCss('padding'),
        {
          'padding-top': '8px',
          'padding-bottom': '2px',
          'padding-inline-start': '16px',
          'padding-inline-end': '4px',
        },
      );
      expect(EdgeInsetsDirectional.all(8).toCss('margin'), {
        'margin-block': '8px',
        'margin-inline': '8px',
      });
      expect(EdgeInsetsDirectional.only(start: 8).toCss('scroll-margin'), {
        'scroll-margin-block': '0px',
        'scroll-margin-inline-start': '8px',
        'scroll-margin-inline-end': '0px',
      });
    });

    test('physical sides of a directional inset throw (THOR-R037)', () {
      final d = EdgeInsetsDirectional.only(start: 4);
      expect(d.cssTop, '0px');
      expect(() => d.cssLeft, throwsA(isA<StateError>()));
      expect(() => d.cssRight, throwsA(isA<StateError>()));
    });

    test('Length geometries: shorthand, start/end and breakpoints', () {
      const v = Length.variable(CssVariable('--x'));
      expect(
        EdgeInsetsGeometry.symmetricLength(horizontal: v).toCss('padding'),
        {'padding': '0 var(--x)'},
      );
      expect(
        EdgeInsetsGeometry.onlyLength(
          start: v,
          top: Length.px(4),
        ).toCss('padding'),
        {
          'padding-top': '4px',
          'padding-bottom': '0',
          'padding-inline-start': 'var(--x)',
          'padding-inline-end': '0',
        },
      );
      final adaptive = EdgeInsetsDirectional.only(
        start: 8,
      ).when(medium: EdgeInsetsDirectional.only(start: 16));
      final css = adaptive.toCss('padding');
      expect(css['padding-inline-start'], contains('8px'));
      expect(css['padding-inline-start'], contains('16px'));
    });

    test('isNonNegative', () {
      expect(EdgeInsets.all(1).isNonNegative, isTrue);
      expect(EdgeInsetsDirectional.only(start: -1).isNonNegative, isFalse);
      expect(
        EdgeInsetsGeometry.allLength(Length.px(-4)).isNonNegative,
        isFalse,
      );
      expect(
        EdgeInsetsGeometry.allLength(
          Length.variable(CssVariable('--g')),
        ).isNonNegative,
        isTrue,
      );
    });
  });

  group('EdgeInsetsGeometry.*Length', () {
    test('write the CSS and add into calc() next to numbers', () {
      final length = EdgeInsetsGeometry.allLength(
        Length.variable(CssVariable('--pad')),
      );
      expect(length.toCss('padding'), {'padding': 'var(--pad)'});
      expect(length == EdgeInsets.zero, isFalse);
      expect(length.add(EdgeInsets.all(4)).toCss('padding'), {
        'padding': 'calc(var(--pad) + 4px)',
      });
    });
  });

  group('border radius', () {
    test('directional corners are logical properties', () {
      final r = BorderRadiusDirectional.only(
        topStart: Radius.circular(8),
        bottomEnd: Radius.elliptical(4, 2),
      );
      expect(r.toCss(), {
        'border-start-start-radius': '8px',
        'border-start-end-radius': '0px',
        'border-end-end-radius': '4px 2px',
        'border-end-start-radius': '0px',
      });
    });

    test('a uniform directional radius is one border-radius', () {
      expect(BorderRadiusDirectional.circular(8).toCss(), {
        'border-radius': '8px',
      });
      expect(BorderRadiusDirectional.zero.toCss(), {'border-radius': '0px'});
    });

    test('Length corners', () {
      final r = BorderRadiusDirectional.circularLength(
        Length.variable(CssVariable('--radius'), fallback: Length.px(16)),
      );
      expect(r.toCss(), {'border-radius': 'var(--radius, 16px)'});
      final c = BorderRadiusDirectional.only(
        topStart: Radius.circularLength(Length.variable(CssVariable('--r'))),
      );
      expect(c.toCss()['border-start-start-radius'], 'var(--r)');
    });

    test('resolve and equality', () {
      final r = BorderRadiusDirectional.horizontal(start: Radius.circular(8));
      expect(
        r.resolve(TextDirection.ltr),
        BorderRadius.horizontal(left: Radius.circular(8)),
      );
      expect(
        r.resolve(TextDirection.rtl),
        BorderRadius.horizontal(right: Radius.circular(8)),
      );
      expect(r, BorderRadiusDirectional.horizontal(start: Radius.circular(8)));
      expect(
        r == BorderRadiusDirectional.horizontal(end: Radius.circular(8)),
        isFalse,
      );
      expect(BorderRadius.circular(8).toCss(), {'border-radius': '8px'});
    });
  });

  group('alignment', () {
    test('a horizontally centered child overflows both ways', () {
      // Auto margins clamp to 0 on overflow (one side only); `align-self:
      // center` is unsafe centering, as in Flutter.
      for (final css in [
        Alignment.center.flexChildCss,
        Alignment.topCenter.flexChildCss,
        AlignmentDirectional.center.flexChildCss,
      ]) {
        expect(css['align-self'], 'center');
        expect(css.keys, isNot(contains('margin-left')));
        expect(css.keys, isNot(contains('margin-inline-start')));
      }
    });

    test('AlignmentDirectional keywords are logical', () {
      expect(AlignmentDirectional.topEnd.placeItems, 'start end');
      expect(AlignmentDirectional.centerStart.placeItems, 'center start');
      expect(
        AlignmentDirectional.centerStart.flexChildCss['margin-inline-start'],
        '0',
      );
      expect(
        AlignmentDirectional.centerStart.flexChildCss['margin-inline-end'],
        'auto',
      );
      expect(AlignmentDirectional.bottomCenter.flexJustify, 'flex-end');
      expect(AlignmentDirectional.center.isHorizontallyCentered, isTrue);
      expect(AlignmentDirectional.topStart.isKeyword, isTrue);
      expect(AlignmentDirectional(0.5, 0).isKeyword, isFalse);
    });

    test('resolve flips start in rtl', () {
      expect(
        AlignmentDirectional.topStart.resolve(TextDirection.ltr),
        Alignment.topLeft,
      );
      expect(
        AlignmentDirectional.topStart.resolve(TextDirection.rtl),
        Alignment.topRight,
      );
      expect(Alignment.center.resolve(TextDirection.rtl), Alignment.center);
    });

    test('a fractional directional alignment throws (THOR-R037)', () {
      final a = AlignmentDirectional(0.5, 0);
      expect(a.fractionalChildCss, throwsA(isA<StateError>()));
      expect(() => a.cssPosition, throwsA(isA<StateError>()));
      expect(AlignmentDirectional(0, 0.5).cssPosition, '50% 75%');
    });

    test('equality', () {
      expect(AlignmentDirectional(1, 0), AlignmentDirectional.centerEnd);
      expect(AlignmentDirectional(1, 0) == Alignment(1, 0), isFalse);
      expect(Alignment(1, 0) == AlignmentDirectional(1, 0), isFalse);
    });
  });
}
