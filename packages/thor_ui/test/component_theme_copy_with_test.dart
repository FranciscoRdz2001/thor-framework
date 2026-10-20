// copyWith on the component theme data classes (Flutter's): the given fields
// are replaced, the others are kept.
import 'package:test/test.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  test('CardThemeData keeps what is not given', () {
    const base = CardThemeData(elevation: 2, color: Color(0xFF111111));
    final copy = base.copyWith(elevation: 4);
    expect(copy.elevation, 4);
    expect(copy.color, const Color(0xFF111111));
    expect(copy.margin, isNull);
  });

  test('AppBarThemeData.copyWith(centerTitle:)', () {
    const base = AppBarThemeData(elevation: 3);
    final copy = base.copyWith(centerTitle: true);
    expect(copy.centerTitle, isTrue);
    expect(copy.elevation, 3);
  });

  test('DividerThemeData and ListTileThemeData', () {
    const divider = DividerThemeData(thickness: 2);
    expect(divider.copyWith(space: 8).thickness, 2);
    expect(divider.copyWith(space: 8).space, 8);
    const tile = ListTileThemeData(dense: true);
    expect(tile.copyWith().dense, isTrue);
  });

  test('a button theme replaces its style', () {
    const base = FilledButtonThemeData();
    final style = ButtonStyle(
      backgroundColor: WidgetStateProperty.all(const Color(0xFF222222)),
    );
    expect(base.copyWith(style: style).style, same(style));
    expect(base.copyWith().style, isNull);
  });
}
