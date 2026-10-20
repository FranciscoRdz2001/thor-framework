import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

void main() {
  test('sides writes only the sides given, one longhand each', () {
    expect(const EdgeInsetsGeometry.sides(top: Length.zero).toCss('margin'), {
      'margin-top': '0',
    });
    expect(
      EdgeInsetsGeometry.sides(bottom: 1.rem, start: 8.px).toCss('padding'),
      {'padding-bottom': '1rem', 'padding-inline-start': '8px'},
    );
    expect(
      EdgeInsetsGeometry.sides(left: 4.px, right: Length.auto).toCss('margin'),
      {'margin-right': 'auto', 'margin-left': '4px'},
    );
  });

  test('EdgeInsets.only keeps writing every side', () {
    expect(const EdgeInsets.only(top: 0).toCss('margin'), {'margin': '0px'});
  });

  test('read as numbers, a side not given is 0', () {
    final s = EdgeInsetsGeometry.sides(top: 8.px);
    expect(s.cssTop, '8px');
    expect(s.cssLeft, '0');
    expect(s.isNonNegative, isTrue);
    expect(
      const EdgeInsetsGeometry.sides(top: Length.px(-8)).isNonNegative,
      isFalse,
    );
    expect((s + const EdgeInsets.all(2)).toCss('padding'), {
      'padding': '10px 2px 2px',
    });
  });

  test('resolve turns start and end into left and right', () {
    final s = EdgeInsetsGeometry.sides(start: 8.px, top: 2.px);
    expect(() => s.cssLeft, throwsStateError);
    expect(s.resolve(TextDirection.rtl).toCss('margin'), {
      'margin-top': '2px',
      'margin-right': '8px',
    });
  });

  test('equality is by the sides given', () {
    expect(
      EdgeInsetsGeometry.sides(top: 8.px),
      EdgeInsetsGeometry.sides(top: 8.px),
    );
    expect(
      EdgeInsetsGeometry.sides(top: 8.px),
      isNot(EdgeInsetsGeometry.sides(top: 8.px, bottom: Length.zero)),
    );
  });
}
