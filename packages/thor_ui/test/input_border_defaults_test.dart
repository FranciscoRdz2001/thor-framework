// Fixture: fields without a label on purpose.
// ignore_for_file: thor_lints/text_field_without_label
// Flutter's InputBorder: `borderSide` is never null (`BorderSide()`), and the
// field paints a border that gives no color with the color scheme, like
// `InputDecorator._getDefaultBorder` (M3).
@TestOn('vm')
library;

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _css(Widget w, {ThemeData? theme}) async {
  final html = await renderDocument(ThorApp(theme: theme, child: w));
  return RegExp(
    r'<style[^>]*>([\s\S]*?)</style>',
  ).allMatches(html).map((m) => m[1]).join().replaceAll(' ', '');
}

double _luminance(String hex) {
  final v = int.parse(hex.substring(1, 7), radix: 16);
  double channel(int c) {
    final s = c / 255;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4) * 1.0;
  }

  return 0.2126 * channel((v >> 16) & 255) +
      0.7152 * channel((v >> 8) & 255) +
      0.0722 * channel(v & 255);
}

double _contrast(String a, String b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  setUpAll(initializeThorTests);

  test('borderSide is Flutter\'s non-nullable BorderSide()', () {
    final BorderSide outline = const OutlineInputBorder().borderSide;
    final BorderSide underline = const UnderlineInputBorder().borderSide;
    expect(outline.width, 1);
    expect(underline.width, 1);
    expect(InputBorder.none.borderSide.style, BorderStyle.none);
    expect(
      const OutlineInputBorder()
          .copyWith(borderSide: const BorderSide(width: 3))
          .borderSide
          .width,
      3,
    );
  });

  test('an own border paints its own color, black included', () {
    expect(const OutlineInputBorder().shadow, contains('inset 0 0 0 1px'));
    expect(
      const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF123456)),
      ).shadow!.toLowerCase(),
      contains('#123456'),
    );
    expect(InputBorder.none.shadow, isNull);
  });

  test(
    'no border: the enabled underline is onSurfaceVariant, focus primary',
    () async {
      final css = await _css(const TextField());
      expect(css, contains('inset0-1px00var(--t-on-surface-variant'));
      expect(css, contains('inset0-2px00var(--t-primary'));
    },
  );

  test(
    'border: OutlineInputBorder() takes outline, focus primary 2px',
    () async {
      final css = await _css(
        const TextField(
          decoration: InputDecoration(border: OutlineInputBorder()),
        ),
      );
      expect(css, contains('inset0001pxvar(--t-outline'));
      expect(css, contains('inset0002pxvar(--t-primary'));
      expect(css, isNot(contains('rgb(0')));
    },
  );

  test(
    'an error takes the error role when no errorBorder says otherwise',
    () async {
      final css = await _css(
        const TextField(
          decoration: InputDecoration(border: OutlineInputBorder()),
        ),
      );
      expect(css, contains('var(--t-error'));
    },
  );

  test('an explicit enabledBorder / focusedBorder keeps its color', () async {
    final css = (await _css(
      const TextField(
        decoration: InputDecoration(
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF123456)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF654321), width: 3),
          ),
        ),
      ),
    )).toLowerCase();
    expect(css, contains('#123456'));
    expect(css, contains('inset0003px#654321'));
    // Nothing takes the roles in their place.
    expect(css, isNot(contains('var(--t-outline,')));
    expect(css, isNot(contains('var(--t-on-surface-variant,#49454f)')));
  });

  test('a border with a color of its own is the same when focused', () async {
    final css = (await _css(
      const TextField(
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF123456)),
          ),
        ),
      ),
    )).toLowerCase();
    expect(css, contains('#123456'));
    expect(css, isNot(contains('var(--t-primary')));
  });

  test(
    'a theme border with no color is painted like the field\'s own',
    () async {
      final css = await _css(
        const TextField(),
        theme: ThemeData(
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
      );
      expect(css, contains('inset0001pxvar(--t-outline'));
      expect(css, contains('inset0002pxvar(--t-primary'));
    },
  );

  test('dark mode keeps the borders at 3:1 against the surface', () {
    const dark = ColorScheme.dark();
    final surface = dark.surface.css;
    for (final role in [dark.outline, dark.onSurfaceVariant!, dark.primary]) {
      expect(
        _contrast(role.css, surface),
        greaterThanOrEqualTo(3),
        reason: role.css,
      );
    }
    const light = ColorScheme.light();
    for (final role in [
      light.outline,
      light.onSurfaceVariant!,
      light.primary,
    ]) {
      expect(
        _contrast(role.css, light.surface.css),
        greaterThanOrEqualTo(3),
        reason: role.css,
      );
    }
  });

  test('the dark theme publishes the roles the borders read', () async {
    final css = await _css(
      const TextField(),
      theme: ThemeData(colorScheme: const ColorScheme.dark()),
    );
    expect(css.toLowerCase(), contains('--t-on-surface-variant:#cac4d0'));
    expect(css.toLowerCase(), contains('--t-primary:#d0bcff'));
  });
}
