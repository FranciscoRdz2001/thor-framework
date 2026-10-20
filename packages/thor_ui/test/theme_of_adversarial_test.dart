import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/web.dart';

// Adversarial tests of `Theme.of(context)` handing out the theme's variables:
// the CSS every use of those colors writes, nested themes built from
// them, and what reading their channels does.
const _light = ColorScheme.light(
  primary: Color(0xFF1D4ED8),
  secondary: Color(0xFF00AA00),
);
const _dark = ColorScheme.dark(
  primary: Color(0xFF93C5FD),
  secondary: Color(0xFF00FF00),
);

Future<String> _page(
  Widget Function(BuildContext context, ColorScheme scheme) build, {
  ThemeMode mode = ThemeMode.system,
}) => renderDocument(
  ThorApp(
    theme: ThemeData(
      colorScheme: _light,
      colorTokens: const {'band': Color(0xFFF7F6F2)},
    ),
    darkTheme: ThemeData(
      colorScheme: _dark,
      colorTokens: const {'band': Color(0xFF111111)},
    ),
    themeMode: mode,
    child: Builder(builder: (c) => build(c, Theme.of(c).colorScheme)),
  ),
);

void main() {
  setUpAll(initializeThorTests);

  group('the CSS every use of a Theme.of color writes', () {
    test('gradient stops are variables', () async {
      final html = await _page(
        (c, s) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [s.primary, s.surface],
              stops: const [0, 1],
            ),
          ),
          child: const Text('x'),
        ),
      );
      expect(
        html,
        contains(
          'linear-gradient(90deg, var(--t-primary) 0%, '
          'var(--t-surface) 100%)',
        ),
      );
    });

    test('a shadow is a color-mix of the variable', () async {
      final html = await _page(
        (c, s) => Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(color: s.primary.withValues(alpha: .3), blurRadius: 4),
            ],
          ),
          child: const Text('x'),
        ),
      );
      expect(
        html,
        contains('color-mix(in srgb, var(--t-primary) 30%, transparent)'),
      );
    });

    test('a border, an icon (svg and font) and a divider', () async {
      final html = await _page(
        (c, s) => Column(
          children: [
            Container(
              decoration: BoxDecoration(border: Border.all(color: s.outline)),
              child: const Text('x'),
            ),
            Icon(
              const IconData.svg('adv-x', '<path d="M1 1"/>'),
              color: s.primary,
            ),
            Icon(const IconData(0xe151, fontFamily: 'L'), color: s.primary),
            Divider(color: s.outlineVariant),
          ],
        ),
      );
      expect(html, contains('var(--t-outline)'));
      expect(html, contains('var(--t-outline-variant)'));
      // Both icons take it as CSS `color`, which is what currentColor reads:
      // never as an svg attribute, where a var() would be invalid.
      expect('color: var(--t-primary)'.allMatches(html), hasLength(2));
      expect(html, isNot(contains('fill="var(')));
      expect(html, isNot(contains('stroke="var(')));
    });

    test('a hover variant keeps the variables in its own rule', () async {
      final html = await _page(
        (c, s) => Container(
          color: s.surface.when(hover: s.primary),
          child: Text(
            'x',
            style: TextStyle(
              color: s.onSurface,
            ).when(hover: TextStyle(color: s.secondary)),
          ),
        ),
      );
      expect(html, contains(':hover{background-color: var(--t-primary)'));
      expect(html, contains('color: var(--t-secondary)'));
    });

    test('a tween between two theme colors, or one and a literal', () async {
      final html = await _page(
        (c, s) => Column(
          children: [
            Container(
              color: ColorTween(begin: s.primary, end: s.surface).lerp(.5),
              child: const Text('a'),
            ),
            Container(
              color: ColorTween(
                begin: s.primary,
                end: const Color(0xFF000000),
              ).lerp(.25),
              child: const Text('b'),
            ),
            Container(
              color: ColorTween(
                begin: const Color(0xFFFFFFFF),
                end: s.primary,
              ).lerp(.75),
              child: const Text('c'),
            ),
            Container(
              color: ColorTween(begin: null, end: s.primary).lerp(.5),
              child: const Text('d'),
            ),
          ],
        ),
      );
      expect(
        html,
        contains('color-mix(in srgb, var(--t-primary) 50%, var(--t-surface))'),
      );
      expect(
        html,
        contains('color-mix(in srgb, var(--t-primary) 75%, #000000)'),
      );
      expect(
        html,
        contains('color-mix(in srgb, #ffffff 25%, var(--t-primary))'),
      );
    });

    test('withAlpha(0) and withAlpha(255) keep following the theme', () async {
      final html = await _page(
        (c, s) => Column(
          children: [
            Container(color: s.primary.withAlpha(0), child: const Text('a')),
            Container(color: s.primary.withAlpha(255), child: const Text('b')),
          ],
        ),
      );
      expect(html, contains('color-mix(in srgb, var(--t-primary) 0%'));
      expect(html, contains('color-mix(in srgb, var(--t-primary) 100%'));
    });
  });

  group('dark mode', () {
    test(
      'the page defines both sides, the variable picks in the browser',
      () async {
        final html = await _page((c, s) => Container(color: s.primary));
        expect(html, contains('--t-primary:light-dark(#1d4ed8, #93c5fd)'));
        expect(html, contains('background-color: var(--t-primary)'));
      },
    );

    test(
      'themeMode dark: what Theme.of falls back to is the dark color',
      () async {
        late Color primary;
        await _page((c, s) {
          primary = s.primary;
          return const Text('x');
        }, mode: ThemeMode.dark);
        expect(primary.css, 'var(--t-primary, #93c5fd)');
      },
    );

    test('a widget with no ThorApp keeps the fallback in the page', () async {
      final html = await renderHtml(
        Builder(
          builder: (c) => Container(
            color: Theme.of(c).colorScheme.primary,
            child: const Text('x'),
          ),
        ),
      );
      expect(html, contains('var(--t-primary, #6750a4)'));
    });
  });

  group('nested themes', () {
    test('a dark island in a light page publishes its own colors', () async {
      final html = await renderDocument(
        ThorApp(
          theme: ThemeData(colorScheme: _light),
          themeMode: ThemeMode.light,
          child: Theme(
            data: ThemeData(colorScheme: _dark),
            child: Builder(
              builder: (c) => Container(
                color: Theme.of(c).colorScheme.surface,
                child: const Text('x'),
              ),
            ),
          ),
        ),
      );
      expect(html, contains('color-scheme: dark'));
      expect(html, contains('--t-primary: #93c5fd'));
      expect(html, contains('background-color: var(--t-surface)'));
    });

    test(
      'a theme built from the colors of another role is not a cycle',
      () async {
        // An inverted section: primary and secondary swapped, from Theme.of.
        final html = await _page(
          (c, s) => Theme(
            data: ThemeData(
              colorScheme: ColorScheme.light(
                primary: s.secondary,
                secondary: s.primary,
              ),
            ),
            child: Container(color: s.primary, child: const Text('x')),
          ),
        );
        // `--t-primary: var(--t-secondary)` next to `--t-secondary:
        // var(--t-primary)` is invalid at computed time (both empty), and a
        // role read from the parent must not read the nested theme's own.
        expect(html, contains('--t-primary: #00aa00'));
        expect(html, contains('--t-secondary: #1d4ed8'));
      },
    );

    test(
      'a role taken from another role publishes that role\'s color',
      () async {
        final vars = ThemeData(
          colorScheme: const ColorScheme.light(
            primary: Color.variable(
              CssVariable('--t-secondary'),
              fallback: Color(0xFF00AA00),
            ),
          ),
        ).toCssVariables();
        expect(vars['--t-primary'], '#00aa00');
      },
    );

    test('a role that is the user\'s own variable stays an alias', () async {
      final vars = ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color.variable(
            CssVariable('--brand'),
            fallback: Color(0xFF00AA00),
          ),
        ),
      ).toCssVariables();
      expect(vars['--t-primary'], 'var(--brand, #00aa00)');
    });
  });

  group('reading the channels', () {
    test(
      'the color the server knows is .fallback, with every channel',
      () async {
        late Color primary;
        await _page((c, s) {
          primary = s.primary;
          return const Text('x');
        });
        expect(primary.fallback!.value, 0xFF1D4ED8);
        expect(primary.fallback!.red, 0x1D);
      },
    );

    test('the message names that way out', () async {
      late Color primary;
      await _page((c, s) {
        primary = s.primary;
        return const Text('x');
      });
      expect(
        () => primary.red,
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('.fallback'),
          ),
        ),
      );
    });

    test(
      'a widget that reads them fails the page, in light and dark alike',
      () async {
        for (final mode in [
          ThemeMode.light,
          ThemeMode.dark,
          ThemeMode.system,
        ]) {
          await expectLater(
            _page((c, s) => Text('${s.primary.value}'), mode: mode),
            throwsA(isA<UnsupportedError>()),
          );
        }
      },
    );

    test(
      '== against a literal is false: a variable is not its color',
      () async {
        late Color primary;
        await _page((c, s) {
          primary = s.primary;
          return const Text('x');
        });
        expect(primary == const Color(0xFF1D4ED8), isFalse);
        expect(primary.fallback == const Color(0xFF1D4ED8), isTrue);
      },
    );

    test('Theme.of hands out the same view every time', () async {
      late ThemeData a, b;
      await _page((c, s) {
        a = Theme.of(c);
        b = Theme.of(c);
        return const Text('x');
      });
      expect(identical(a, b), isTrue);
      expect(identical(a.colorScheme, b.colorScheme), isTrue);
    });
  });
}
