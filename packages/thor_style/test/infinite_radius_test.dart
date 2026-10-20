import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

void main() {
  test('an infinite radius is a pill, not 100%', () {
    expect(BorderRadius.circular(double.infinity).css, '9999px');
    expect(const Radius.elliptical(double.infinity, 8).css, '9999px 8px');
    expect(const StadiumBorder().radiusCss, '9999px');
  });

  test('finite radii are unchanged', () {
    expect(BorderRadius.circular(8).css, '8px');
    expect(const Radius.elliptical(8, 4).css, '8px 4px');
  });

  test('an infinite length is still 100%', () {
    expect(cssPx(double.infinity), '100%');
  });

  test('a non-finite number is a clear ArgumentError', () {
    expect(() => cssNum(double.infinity), throwsArgumentError);
    expect(() => cssNum(double.negativeInfinity), throwsArgumentError);
    expect(() => cssPx(double.negativeInfinity), throwsArgumentError);
  });
}
