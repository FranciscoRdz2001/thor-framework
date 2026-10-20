import 'package:test/test.dart';
import 'package:thor_cli/thor_cli.dart';

void main() {
  test('icon code points: only the named family, hex or decimal, once', () {
    const a = '''
static const home = IconData(0xe88a, fontFamily: 'MaterialIcons');
static const star = IconData(
  0xE838,
  fontFamily: "MaterialIcons",
);
const x = IconData(59530, fontFamily: 'MaterialIcons'); // 0xe88a again
const l = IconData(0xe01f, fontFamily: 'Lucide');
const n = IconData(0xe000); // no family
''';
    expect(iconCodePoints([a], 'MaterialIcons'), [0xe838, 0xe88a]);
    expect(iconCodePoints([a], 'Lucide'), [0xe01f]);
    expect(iconCodePoints([a], 'Material'), isEmpty);
  });

  test('unicodes: ranges and singles; a bad or backwards one fails', () {
    expect(parseUnicodes('U+0041-0043, U+2013'), [0x41, 0x42, 0x43, 0x2013]);
    expect(parseUnicodes(latinUnicodes), contains(0xE9));
    expect(() => parseUnicodes('latin-ext'), throwsA(isA<ThorException>()));
    expect(() => parseUnicodes('U+0050-0040'), throwsA(isA<ThorException>()));
  });

  test('a unicode-range merges consecutive points', () {
    expect(
      unicodeRangeOf([0x43, 0x41, 0x42, 0x2013, 0x41]),
      'U+0041-0043,U+2013',
    );
    expect(unicodeRangeOf(const []), '');
  });
}
