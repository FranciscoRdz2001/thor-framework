import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

void main() {
  test('a backslash-escaped `<` inside a string cannot close the style', () {
    for (final input in [
      '"\\</style><script>alert(1)</script>"',
      "'\\</style>'",
      '"a\\\n b"',
    ]) {
      final out = cssSafeValue(input);
      expect(out, isNot(contains('<')), reason: input);
      expect(out, isNot(contains('\n')), reason: input);
    }
  });

  test('a valid escape inside a string is kept', () {
    expect(cssSafeValue(r'"a\"b"'), r'"a\"b"');
    expect(cssSafeValue(r'"\\"'), r'"\\"');
  });
}
