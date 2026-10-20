import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/web.dart';

/// `Theme.of(context).colorScheme.x` used to be the light color, written
/// into the page by the server: in dark mode the UI was wrong and nothing
/// said so. It is now the theme's variable (with the color as fallback), the
/// way `ThemeColor` and `TextTheme` already were.
const _light = ColorScheme.light(primary: Color(0xFF1D4ED8));
const _dark = ColorScheme.dark(primary: Color(0xFF93C5FD));

/// Renders [read] of the theme in scope, as a box background.
Widget _probe(Color? Function(ThemeData theme) read) => Builder(
  builder: (context) => Container(
    key: const ValueKey('probe'),
    color: read(Theme.of(context)),
    child: const Text('x'),
  ),
);

Future<String> _page(
  Widget child, {
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode mode = ThemeMode.system,
}) => renderDocument(
  ThorApp(theme: theme, darkTheme: darkTheme, themeMode: mode, child: child),
);

/// The `primary` a widget reads from `Theme.of` under [theme]/[darkTheme].
Future<Color> _primaryOf({
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode mode = ThemeMode.system,
}) async {
  late Color seen;
  await _page(
    Builder(
      builder: (context) {
        seen = Theme.of(context).colorScheme.primary;
        return const Text('x');
      },
    ),
    theme: theme,
    darkTheme: darkTheme,
    mode: mode,
  );
  return seen;
}

void main() {
  setUpAll(initializeThorTests);

  group('a nested Theme built from Theme.of', () {
    test('inherits the live roles, not the light hex', () async {
      final html = await _page(
        Builder(
          builder: (context) => Theme(
            data: Theme.of(context).copyWith(cardTheme: const CardThemeData()),
            child: const Text('nested'),
          ),
        ),
        theme: ThemeData(colorScheme: _light),
        darkTheme: ThemeData(colorScheme: _dark),
      );
      final styles = RegExp(
        r'<style[^>]*>([\s\S]*?)</style>',
      ).allMatches(html).map((m) => m[1]).join();
      // The page publishes light-dark roles on :root; the nested class must
      // not override them with the light hex or force `color-scheme: light`.
      final nested = RegExp(
        r'\.[\w-]+\s*\{[^}]*color:\s*var\(--t-on-surface\)[^}]*\}',
      ).allMatches(styles).map((m) => m[0]!).toList();
      expect(nested, isNotEmpty);
      for (final rule in nested) {
        expect(rule, isNot(contains('--t-primary:')));
        expect(rule, isNot(contains('color-scheme')));
      }
    });

    test('with only an accent replaced keeps the page color-scheme', () async {
      const brand = Color(0xFF00AA55);
      final html = await _page(
        Builder(
          builder: (context) {
            final theme = Theme.of(context);
            return Theme(
              data: theme.copyWith(
                colorScheme: theme.colorScheme.copyWith(primary: brand),
              ),
              child: const Text('nested'),
            );
          },
        ),
        theme: ThemeData(colorScheme: _light),
        darkTheme: ThemeData(colorScheme: _dark),
      );
      final styles = RegExp(
        r'<style[^>]*>([\s\S]*?)</style>',
      ).allMatches(html).map((m) => m[1]).join();
      final nested = RegExp(
        r'\.[\w-]+\s*\{[^}]*--t-primary:\s*#00aa55[^}]*\}',
        caseSensitive: false,
      ).allMatches(styles).map((m) => m[0]!).toList();
      expect(nested, isNotEmpty);
      for (final rule in nested) {
        expect(rule, isNot(contains('color-scheme')));
        expect(rule, isNot(contains('--t-surface:')));
      }
    });
  });

  group('the scheme of Theme.of is the theme\'s variables', () {
    test('each role is var(--t-role, its color)', () async {
      late ThemeData seen;
      await _page(
        Builder(
          builder: (context) {
            seen = Theme.of(context);
            return const Text('x');
          },
        ),
        theme: ThemeData(colorScheme: _light),
      );
      final s = seen.colorScheme;
      expect(s.primary.css, 'var(--t-primary, #1d4ed8)');
      expect(s.onPrimary.css, 'var(--t-on-primary, #ffffff)');
      expect(s.surface.css, startsWith('var(--t-surface, '));
      expect(s.outlineVariant.css, startsWith('var(--t-outline-variant, '));
      // The optional roles that default to another one, as they publish.
      expect(
        s.onSurfaceVariant!.css,
        startsWith('var(--t-on-surface-variant, '),
      );
      // A role the theme leaves null stays null: nothing was published.
      final bare = ThemeData(
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF000001),
          onPrimary: Color(0xFF000002),
          secondary: Color(0xFF000003),
          onSecondary: Color(0xFF000004),
          error: Color(0xFF000005),
          onError: Color(0xFF000006),
          surface: Color(0xFF000007),
          onSurface: Color(0xFF000008),
          surfaceContainer: Color(0xFF000009),
          outline: Color(0xFF00000A),
          outlineVariant: Color(0xFF00000B),
        ),
      );
      late ThemeData bareSeen;
      await _page(
        Builder(
          builder: (context) {
            bareSeen = Theme.of(context);
            return const Text('x');
          },
        ),
        theme: bare,
      );
      expect(bareSeen.colorScheme.inverseSurface, isNull);
      expect(bareSeen.colorScheme.surfaceContainerLow, isNull);
    });

    test('brightness and the rest of the theme are the real ones', () async {
      late ThemeData seen;
      await _page(
        Builder(
          builder: (context) {
            seen = Theme.of(context);
            return const Text('x');
          },
        ),
        theme: ThemeData(colorScheme: _dark, fontFamily: 'Foo'),
      );
      expect(seen.brightness, Brightness.dark);
      expect(seen.colorScheme.brightness, Brightness.dark);
      expect(seen.fontFamily, 'Foo');
    });

    test('a box painted with it follows the theme in the page', () async {
      final html = await _page(
        _probe((t) => t.colorScheme.primary),
        theme: ThemeData(colorScheme: _light),
        darkTheme: ThemeData(colorScheme: _dark),
      );
      // The page defines the variable, so the fallback is dropped (no bytes).
      expect(html, contains('background-color: var(--t-primary);'));
      expect(html, isNot(contains('#1d4ed8);')));
      // The page publishes both sides: the switch changes the one variable.
      expect(html, contains('--t-primary:light-dark(#1d4ed8, #93c5fd)'));
    });

    test('the same in light, dark and system: the variable decides', () async {
      for (final mode in ThemeMode.values) {
        final html = await _page(
          _probe((t) => t.colorScheme.onSurface),
          theme: ThemeData(colorScheme: _light),
          darkTheme: ThemeData(colorScheme: _dark),
          mode: mode,
        );
        expect(
          html,
          contains('background-color: var(--t-on-surface);'),
          reason: 'themeMode $mode',
        );
      }
    });

    test('with themeMode dark the fallback is the dark color', () async {
      final seen = await _primaryOf(
        theme: ThemeData(colorScheme: _light),
        darkTheme: ThemeData(colorScheme: _dark),
        mode: ThemeMode.dark,
      );
      expect(seen.css, 'var(--t-primary, #93c5fd)');
    });

    test('only a darkTheme: the page keeps the default light theme', () async {
      final seen = await _primaryOf(darkTheme: ThemeData(colorScheme: _dark));
      expect(seen.css, 'var(--t-primary, #6750a4)');
    });

    test('without a page theme the fallback is what paints', () async {
      // Theme.provide publishes nothing: a widget under it in a test, or in
      // a page without ThorApp(theme:), still gets the theme's own color.
      final html = await renderHtml(
        Theme.provide(
          data: ThemeData(colorScheme: _light),
          child: _probe((t) => t.colorScheme.primary),
        ),
      );
      expect(html, contains('background-color: var(--t-primary, #1d4ed8)'));
    });

    test('a nested Theme gives its own colors below it', () async {
      final html = await _page(
        Column(
          children: [
            _probe((t) => t.colorScheme.primary),
            Theme(
              data: ThemeData(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF00AA00),
                ),
              ),
              child: _probe((t) => t.colorScheme.primary),
            ),
          ],
        ),
        theme: ThemeData(colorScheme: _light),
      );
      // Both boxes read the variable; the nested Theme sets it below itself.
      expect(
        'background-color: var(--t-primary);'.allMatches(html),
        hasLength(2),
      );
      expect(html, matches(RegExp(r'--t-primary:\s*#00aa00')));
      expect(html, matches(RegExp(r'--t-primary:\s*#1d4ed8')));
    });

    test(
      'a color from Theme.of through withValues(alpha:) still follows',
      () async {
        final html = await _page(
          _probe((t) => t.colorScheme.primary.withValues(alpha: 0.12)),
          theme: ThemeData(colorScheme: _light),
        );
        expect(
          html,
          contains(
            'background-color: color-mix(in srgb, var(--t-primary) 12%, '
            'transparent);',
          ),
        );
      },
    );

    test('colorTokens read from Theme.of are the token\'s variable', () async {
      late Color band;
      await _page(
        Builder(
          builder: (context) {
            band = Theme.of(context).colorTokens['band']!;
            return const Text('x');
          },
        ),
        theme: ThemeData(colorTokens: const {'band': Color(0xFFF7F6F2)}),
      );
      expect(band.css, 'var(--t-band, #f7f6f2)');
    });

    test(
      'reading its channels fails with the way out, never a wrong color',
      () async {
        late Color primary;
        await _page(
          Builder(
            builder: (context) {
              primary = Theme.of(context).colorScheme.primary;
              return const Text('x');
            },
          ),
          theme: ThemeData(colorScheme: _light),
        );
        expect(() => primary.value, throwsUnsupportedError);
        expect(() => primary.red, throwsUnsupportedError);
        expect(
          () => Color.alphaBlend(primary, const Color(0xFFFFFFFF)),
          throwsArgumentError,
        );
      },
    );
  });

  group('what the page publishes does not change', () {
    test('the scheme of Theme.of, given to a theme, is not a cycle', () async {
      late ColorScheme followed;
      await _page(
        Builder(
          builder: (context) {
            followed = Theme.of(context).colorScheme;
            return const Text('x');
          },
        ),
        theme: ThemeData(colorScheme: _light),
      );
      // A theme built from what Theme.of returned publishes the colors, not
      // `--t-primary: var(--t-primary)` (invalid at computed time).
      final vars = ThemeData(colorScheme: followed).toCssVariables();
      expect(vars['--t-primary'], '#1d4ed8');
      expect(vars['--t-on-surface'], isNot(contains('var(')));
    });

    test('a role given as another role is an alias that follows', () {
      final vars = ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color.variable(CssVariable('--t-secondary')),
        ),
      ).toCssVariables();
      expect(vars['--t-primary'], 'var(--t-secondary)');
    });

    test('ThemeColor is unchanged: the variable without a fallback', () {
      expect(ThemeColor.primary.css, 'var(--t-primary)');
      expect(ThemeColor.onSurface.variableName, '--t-on-surface');
    });

    test('the raw data of a theme still holds the real colors', () {
      final theme = ThemeData(colorScheme: _light);
      expect(theme.colorScheme.primary.value, 0xFF1D4ED8);
    });
  });
}
