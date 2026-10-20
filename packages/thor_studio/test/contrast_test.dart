@TestOn('vm')
library;

// WCAG AA of the studio's themes, role by role: `expectThemeContrast` of
// thor_test measures every `onX` on its `X`, the text roles on the surfaces
// they are drawn on and `outline` (3:1) on `surface`.
import 'package:test/test.dart';
import 'package:thor_studio/thor_studio.dart';
import 'package:thor_test/thor_test.dart';

void main() {
  test('the light theme reads at AA', () {
    expectThemeContrast(StudioTheme.light(), reason: 'StudioTheme.light()');
  });

  test('the dark theme reads at AA', () {
    expectThemeContrast(StudioTheme.dark(), reason: 'StudioTheme.dark()');
  });

  test('the roles are measured, not skipped (tokens resolve per side)', () {
    for (final theme in [StudioTheme.light(), StudioTheme.dark()]) {
      expect(themeContrast(theme), hasLength(greaterThan(15)));
    }
  });
}
