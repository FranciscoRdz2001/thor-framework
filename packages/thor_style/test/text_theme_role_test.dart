import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

void main() {
  test('a role reads the theme variables, the field as the fallback', () {
    const style = TextStyle(role: TextThemeRole.headlineLarge);
    final css = style.toCss();
    expect(css['font-size'], 'var(--t-headline-large-size)');
    // A role's own values (what `TextTheme` sets) are the fallbacks; any other
    // value is an override.
    final themed = const TextStyle(
      fontSize: 32,
    ).withRole(TextThemeRole.headlineLarge);
    expect(themed.toCss()['font-size'], 'var(--t-headline-large-size, 32px)');
  });

  test('role is the typed role and withRole sets it', () {
    const typed = TextStyle(fontSize: 24, role: TextThemeRole.titleLarge);
    expect(typed.role, TextThemeRole.titleLarge);
    const base = TextStyle(fontSize: 14, height: 1.4);
    expect(
      base.withRole(TextThemeRole.bodyMedium).role,
      TextThemeRole.bodyMedium,
    );
    expect(
      base.withRole(TextThemeRole.bodyMedium).toCss()['font-size'],
      'var(--t-body-medium-size, 14px)',
    );
  });

  test('copyWith, merge and when keep the role', () {
    const style = TextStyle(role: TextThemeRole.labelSmall, fontSize: 11);
    expect(style.copyWith(color: const Color(0xFF000000)).role, isNotNull);
    expect(const TextStyle().merge(style).role, TextThemeRole.labelSmall);
  });

  test('every role has the CSS name of its camelCase', () {
    for (final r in TextThemeRole.values) {
      final words = r.name.replaceAllMapped(
        RegExp('[A-Z]'),
        (m) => '-${m[0]!.toLowerCase()}',
      );
      expect(r.cssName, words);
      expect(TextThemeRole.fromCssName(r.cssName), r);
    }
    expect(TextThemeRole.fromCssName('nope'), isNull);
    expect(TextThemeRole.fromCssName(null), isNull);
  });
}
