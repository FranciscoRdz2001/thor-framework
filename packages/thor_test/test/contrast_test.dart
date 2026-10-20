@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  group('contrastRatio', () {
    test('black on white is 21:1 and a color on itself 1:1', () {
      expect(
        contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.001),
      );
      expect(
        contrastRatio(const Color(0xFF6750A4), const Color(0xFF6750A4)),
        closeTo(1, 0.001),
      );
    });

    test('is symmetric and follows WCAG for a known pair', () {
      const a = Color(0xFF777777), b = Color(0xFFFFFFFF);
      expect(contrastRatio(a, b), closeTo(contrastRatio(b, a), 1e-9));
      // #777 on white is the classic 4.48:1 that just fails AA.
      expect(contrastRatio(a, b), closeTo(4.48, 0.01));
    });
  });

  group('expectThemeContrast', () {
    test('the baseline Material schemes pass', () {
      expectThemeContrast(ThemeData.light(), reason: 'ThemeData.light()');
      expectThemeContrast(ThemeData.dark(), reason: 'ThemeData.dark()');
    });

    test('the high contrast schemes pass with room to spare', () {
      for (final scheme in const [
        ColorScheme.highContrastLight(),
        ColorScheme.highContrastDark(),
      ]) {
        final pairs = schemeContrast(scheme, text: 7);
        expect(
          pairs.where((p) => !p.passes),
          isEmpty,
          reason: 'every pair reaches AAA in ${scheme.brightness.name}',
        );
      }
    });

    test('a theme with a weak pair fails and names it', () {
      final weak = ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF9FB0FF),
          onPrimary: Color(0xFFFFFFFF),
        ),
      );
      expect(
        () => expectThemeContrast(weak, reason: 'weak theme'),
        throwsA(
          isA<Object>().having(
            (e) => '$e',
            'message',
            allOf(contains('weak theme'), contains('onPrimary on primary')),
          ),
        ),
      );
    });

    test('skip accepts a pair, extra adds the app\'s own', () {
      final weak = ThemeData(
        colorScheme: const ColorScheme.light(primary: Color(0xFF9FB0FF)),
      );
      expectThemeContrast(
        weak,
        skip: {'onPrimary on primary', 'primary on surface'},
      );
      expect(
        () => expectThemeContrast(
          ThemeData.light(),
          extra: const [('brand', Color(0xFFCCCCCC), Color(0xFFFFFFFF))],
        ),
        throwsA(isA<Object>()),
      );
    });

    test('a theme variable is measured through its fallback', () {
      final themed = ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color.variable(
            CssVariable('--brand'),
            fallback: Color(0xFF9FB0FF),
          ),
        ),
      );
      final pairs = themeContrast(themed);
      final p = pairs.firstWhere((p) => p.foreground == 'onPrimary');
      expect(p.passes, isFalse);
    });

    test('a translucent foreground is measured over its background', () {
      final themed = ThemeData(
        colorScheme: const ColorScheme.light(
          surface: Color(0xFFFFFFFF),
          onSurfaceVariant: Color(0x61000000),
        ),
      );
      final p = themeContrast(themed).firstWhere(
        (p) => p.foreground == 'onSurfaceVariant' && p.background == 'surface',
      );
      expect(p.ratio, lessThan(4.5));
      expect(p.passes, isFalse);
    });

    test('a translucent background is left out', () {
      final themed = ThemeData(
        colorScheme: const ColorScheme.light(surface: Color(0x80FFFFFF)),
      );
      expect(
        themeContrast(themed).where((p) => p.background == 'surface'),
        isEmpty,
      );
    });

    test('a color that is a css expression is left out', () {
      final themed = ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color.css('color-mix(in srgb, red, blue)'),
        ),
      );
      expect(
        themeContrast(themed).where((p) => p.background == 'primary'),
        isEmpty,
      );
    });
  });
}
