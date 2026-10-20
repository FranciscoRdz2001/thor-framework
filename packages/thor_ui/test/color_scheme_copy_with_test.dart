// ColorScheme.copyWith (Flutter's): replaces the given roles, keeps the rest.
import 'package:test/test.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  const brand = Color(0xFF123456);

  test('replaces the given roles and keeps the others', () {
    const base = ColorScheme.dark();
    final scheme = base.copyWith(primary: brand, surfaceContainerHigh: brand);
    expect(scheme.primary, brand);
    expect(scheme.surfaceContainerHigh, brand);
    expect(scheme.brightness, Brightness.dark);
    expect(scheme.secondary, base.secondary);
    expect(scheme.onSurfaceVariant, base.onSurfaceVariant);
    expect(scheme.inversePrimary, base.inversePrimary);
  });

  test('keeps null roles null and takes the brightness', () {
    final scheme = const ColorScheme.light().copyWith(
      brightness: Brightness.dark,
    );
    expect(scheme.brightness, Brightness.dark);
    expect(scheme.tertiary, isNull);
    expect(const ColorScheme.light().copyWith(tertiary: brand).tertiary, brand);
  });

  test('every role survives a copy with no arguments', () {
    const base = ColorScheme.highContrastLight();
    final copy = base.copyWith();
    expect(copy.toCssVariables(), base.toCssVariables());
  });
}
