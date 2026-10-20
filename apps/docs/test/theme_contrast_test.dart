import 'package:docs/core/theme/docs_theme.dart';
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';

void main() {
  // The site's themes (light and dark) at WCAG AA: text roles on the
  // surfaces they are drawn on, `outline` at 3:1.
  test('the light theme reads at AA', () {
    expectThemeContrast(docsTheme, reason: 'docsTheme');
  });

  test('the dark theme reads at AA', () {
    expectThemeContrast(docsDarkTheme, reason: 'docsDarkTheme');
  });
}
