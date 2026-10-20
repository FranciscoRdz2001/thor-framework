import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

void main() {
  test('any weight from 1 to 1000, for variable fonts', () {
    expect(
      const TextStyle(fontWeight: FontWeight(650)).toCss()['font-weight'],
      '650',
    );
    expect(FontWeight.bold.value, 700);
    expect(() => FontWeight(0), throwsA(isA<AssertionError>()));
    expect(() => FontWeight(1001), throwsA(isA<AssertionError>()));
  });

  test('equal by value, the named ones among them', () {
    // ignore: prefer_const_constructors
    expect(FontWeight(700), FontWeight.w700);
    expect(FontWeight.values, hasLength(9));
    expect(FontWeight.values.first, FontWeight.w100);
  });

  test('lerp rounds between the two, null is normal', () {
    expect(FontWeight.lerp(FontWeight.w400, FontWeight.w700, 0.5)!.value, 550);
    expect(FontWeight.lerp(null, FontWeight.w900, 0.25)!.value, 525);
    expect(FontWeight.lerp(null, null, 0.5), isNull);
  });
}
