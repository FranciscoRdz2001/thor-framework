import 'dart:math';

import 'package:test/test.dart';
import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

double _luminance(Color c) {
  double lin(int v) {
    final s = v / 255;
    return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4) * 1.0;
  }

  final argb = c.value;
  return 0.2126 * lin((argb >> 16) & 0xFF) +
      0.7152 * lin((argb >> 8) & 0xFF) +
      0.0722 * lin(argb & 0xFF);
}

double _ratio(Color a, Color b) {
  final (l1, l2) = (_luminance(a), _luminance(b));
  return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05);
}

void main() {
  setUpAll(initializeThorTests);

  group('Material 3 roles', () {
    final cs = StudioTheme.colorScheme(Brightness.light);

    test('every role of the scheme is set and is a token', () {
      for (final c in [
        cs.primary,
        cs.onPrimary,
        cs.primaryContainer!,
        cs.onPrimaryContainer!,
        cs.secondary,
        cs.onSecondary,
        cs.secondaryContainer!,
        cs.onSecondaryContainer!,
        cs.tertiary!,
        cs.onTertiary!,
        cs.tertiaryContainer!,
        cs.onTertiaryContainer!,
        cs.error,
        cs.onError,
        cs.errorContainer!,
        cs.onErrorContainer!,
        cs.surface,
        cs.onSurface,
        cs.onSurfaceVariant!,
        cs.surfaceContainerLowest!,
        cs.surfaceContainerLow!,
        cs.surfaceContainer,
        cs.surfaceContainerHigh!,
        cs.surfaceContainerHighest!,
        cs.outline,
        cs.outlineVariant,
        cs.inverseSurface!,
        cs.onInverseSurface!,
        cs.inversePrimary!,
      ]) {
        expect(c, isA<ColorToken>());
      }
    });

    test('the text theme has every role', () {
      final t = StudioTheme.textTheme;
      expect(t.roles.length, 15);
      expect(t.displayLarge.fontSize, 48);
      expect(t.displayMedium.fontSize, 40);
      expect(t.headlineSmall.fontSize, 20);
      expect(t.labelSmall.fontSize, 11);
      expect(t.bodyMedium.fontWeight, FontWeight.w400);
    });

    test('the accent reads as tertiary, with a fallback to primary', () {
      expect(cs.accent, StudioAccentColors.accent);
      expect(cs.onAccent, StudioAccentColors.accentInk);
      expect(
        const ColorScheme.light().accent,
        const ColorScheme.light().primary,
      );
    });

    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      Color side(Color c) =>
          dark ? (c as ColorToken).dark : (c as ColorToken).light;
      final s = StudioTheme.colorScheme(
        dark ? Brightness.dark : Brightness.light,
      );
      test('role pairs meet 4.5:1 in the $mode theme', () {
        final pairs = <(String, Color, Color)>[
          ('onPrimary/primary', s.onPrimary, s.primary),
          ('onSecondary/secondary', s.onSecondary, s.secondary),
          (
            'onPrimaryContainer/primaryContainer',
            s.onPrimaryContainer!,
            s.primaryContainer!,
          ),
          (
            'onSecondaryContainer/secondaryContainer',
            s.onSecondaryContainer!,
            s.secondaryContainer!,
          ),
          ('onTertiary/tertiary', s.onTertiary!, s.tertiary!),
          (
            'onTertiaryContainer/tertiaryContainer',
            s.onTertiaryContainer!,
            s.tertiaryContainer!,
          ),
          ('onError/error', s.onError, s.error),
          (
            'onErrorContainer/errorContainer',
            s.onErrorContainer!,
            s.errorContainer!,
          ),
          (
            'onInverseSurface/inverseSurface',
            s.onInverseSurface!,
            s.inverseSurface!,
          ),
          for (final (name, bg) in [
            ('surface', s.surface),
            ('surfaceContainerLowest', s.surfaceContainerLowest!),
            ('surfaceContainerLow', s.surfaceContainerLow!),
            ('surfaceContainer', s.surfaceContainer),
            ('surfaceContainerHigh', s.surfaceContainerHigh!),
            ('surfaceContainerHighest', s.surfaceContainerHighest!),
          ]) ...[
            ('onSurface/$name', s.onSurface, bg),
            ('onSurfaceVariant/$name', s.onSurfaceVariant!, bg),
          ],
        ];
        for (final (name, fg, bg) in pairs) {
          expect(
            _ratio(side(fg), side(bg)),
            greaterThanOrEqualTo(4.5),
            reason: name,
          );
        }
      });

      test(
        'outlines, the accent and the primary meet 3:1 in the $mode theme',
        () {
          for (final (name, bg) in [
            ('surface', s.surface),
            ('surfaceContainerLowest', s.surfaceContainerLowest!),
            ('surfaceContainer', s.surfaceContainer),
            ('surfaceContainerHighest', s.surfaceContainerHighest!),
          ]) {
            expect(
              _ratio(side(s.outline), side(bg)),
              greaterThanOrEqualTo(3),
              reason: 'outline on $name',
            );
            expect(
              _ratio(side(s.accent), side(bg)),
              greaterThanOrEqualTo(3),
              reason: 'accent on $name',
            );
            expect(
              _ratio(side(s.primary), side(bg)),
              greaterThanOrEqualTo(3),
              reason: 'primary on $name',
            );
          }
        },
      );
    }

    test('dark and light share the same variables', () async {
      final head = headOfPage(
        await renderDocument(
          ThorApp(
            theme: StudioTheme.light(),
            darkTheme: StudioTheme.dark(),
            child: const Text('x'),
          ),
        ),
      );
      expect(head, contains('--t-surface-container-lowest:var(--t-canvas)'));
      expect(head, contains('--t-outline:var(--t-field-line)'));
      expect(head, contains('--t-outline-variant:var(--t-line)'));
      expect(head, contains('--t-tertiary:var(--t-accent)'));
    });
  });

  group('Flutter component themes', () {
    test('the theme fills the Material component themes', () {
      for (final t in [StudioTheme.light(), StudioTheme.dark()]) {
        expect(t.filledButtonTheme?.style?.shape, isNotNull);
        expect(t.elevatedButtonTheme, isNotNull);
        expect(t.outlinedButtonTheme?.style?.side, isNotNull);
        expect(t.textButtonTheme, isNotNull);
        expect(t.iconButtonTheme, isNotNull);
        expect(t.chipTheme?.showCheckmark, isFalse);
        expect(t.cardTheme?.elevation, 0);
        expect(t.expansionTileTheme, isNotNull);
        expect(t.navigationRailTheme, isNotNull);
        expect(t.inputDecorationTheme?.border, isNotNull);
      }
    });

    test('a plain FilledButton, FilterChip and Card look studio', () async {
      final html = await renderDocument(
        ThorApp(
          theme: StudioTheme.dark(),
          child: Column(
            children: [
              FilledButton(onPressed: () {}, child: const Text('Go')),
              FilterChip(
                label: const Text('A'),
                selected: false,
                onSelected: (_) {},
              ),
              const Card(child: Text('c')),
            ],
          ),
        ),
      );
      // The pill (999 px), the card radius and the studio's hairline.
      expect(html, contains('border-radius: 999px'));
      expect(html, contains('border-radius: 28px'));
      expect(html, contains('var(--t-line)'));
    });
  });

  group('component theme data', () {
    final light = StudioTheme.light();

    test('every field resolves: widget, then theme, then the scheme', () {
      final byDefault = StudioButtonThemeData.resolve(light);
      expect(byDefault.filledColor, StudioActionColors.action);
      expect(byDefault.textStyle.fontSize, 14);

      final installed = light.copyWith(
        extensions: [
          ...light.extensions,
          const StudioButtonThemeData(radius: 8, height: 44),
        ],
      );
      final themed = StudioButtonThemeData.resolve(installed);
      expect(themed.radius, 8);
      expect(themed.height, 44);
      expect(themed.smallHeight, 32);

      final overridden = StudioButtonThemeData.resolve(
        installed,
        const StudioButtonThemeData(radius: 4),
      );
      expect(overridden.radius, 4);
      expect(overridden.height, 44);
    });

    test('copyWith(primary:) on the color scheme cascades to the defaults', () {
      const brand = Color(0xFF123456);
      final t = light.copyWith(
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: brand,
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFF000000),
          onSecondary: Color(0xFFFFFFFF),
          error: Color(0xFFB00020),
          onError: Color(0xFFFFFFFF),
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF000000),
          surfaceContainer: Color(0xFFEEEEEE),
          outline: Color(0xFF777777),
          outlineVariant: Color(0xFFCCCCCC),
        ),
      );
      expect(StudioButtonThemeData.resolve(t).filledColor, brand);
      expect(StudioChipThemeData.resolve(t).selectedColor, brand);
      expect(StudioCardThemeData.resolve(t).color, const Color(0xFFEEEEEE));
    });

    test('== and hashCode follow the fields; lerp is the base step', () {
      const a = StudioCardThemeData(radius: 8);
      const b = StudioCardThemeData(radius: 8);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(radius: 9), isNot(a));
      expect(a.lerp(const StudioCardThemeData(radius: 2), 0.2), a);
      expect(a.lerp(const StudioCardThemeData(radius: 2), 0.8).radius, 2);
    });
  });

  group('extras', () {
    test('StudioExtraColors holds what Material has no role for', () {
      const x = StudioExtraColors.standard;
      expect(x.tone(StudioTone.ok), x.okTone);
      expect(x.tone(StudioTone.neutral), x.neutralTone);
      expect(
        x.copyWith(hover: StudioSurfaceColors.raised).hover,
        StudioSurfaceColors.raised,
      );
      expect(StudioTheme.light().extension<StudioExtraColors>(), isNotNull);
      expect(StudioTheme.light().extension<StudioExtraTextStyles>(), isNotNull);
    });

    test('the callout names are StudioTone aliases', () {
      expect(StudioTone.note, StudioTone.info);
      expect(StudioTone.tip, StudioTone.ok);
      expect(StudioTone.warning, StudioTone.warn);
    });
  });

  group('component themes', () {
    test('the studio fills the themes of the plain Material widgets', () {
      final t = StudioTheme.light();
      expect(t.dialogTheme, isNotNull);
      expect(t.bottomSheetTheme, isNotNull);
      expect(t.snackBarTheme, isNotNull);
      expect(t.tooltipTheme, isNotNull);
      expect(t.popupMenuTheme, isNotNull);
      expect(t.appBarTheme, isNotNull);
      expect(t.tabBarTheme, isNotNull);
      expect(t.navigationBarTheme, isNotNull);
    });

    test('a plain AlertDialog is a studio card', () async {
      final theme = StudioTheme.light();
      final plain = await renderHtml(
        Theme.provide(
          data: theme,
          child: const AlertDialog(title: Text('x')),
        ),
      );
      expect(plain, contains('border-radius: 28px'));
    });
  });
}
