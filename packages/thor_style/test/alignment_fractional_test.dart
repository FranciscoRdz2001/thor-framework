import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

void main() {
  test('fractional alignment translate negates the offset', () {
    expect(
      const Alignment(0, 0).fractionalChildCss()['translate'],
      '-50% -50%',
    );
  });

  test('an edge alignment writes a plain 0, not -0', () {
    expect(const Alignment(-1, 0).fractionalChildCss()['translate'], '0% -50%');
  });

  test('alignment beyond the box never writes a double minus', () {
    final css = const Alignment(-2, 3).fractionalChildCss();
    expect(css['translate'], '50% -200%');
    expect(css['translate'], isNot(contains('--')));
  });
}
