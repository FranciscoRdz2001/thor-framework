@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/src/foundation/style_registry.dart'
    show foldSchemeColors, isCssColor;
import 'package:thor_ui/thor_ui.dart';

void main() {
  const scheme = {'color-scheme': 'light', '--t-a': '#111111'};

  test('a theme-like dark rule folds its colors into light-dark()', () {
    final (css, conditions) = foldSchemeColors(
      {...scheme, '--t-b': '#222222', 'font-family': 'x'},
      const [
        ConditionalCss(CssCondition.dark, {
          'color-scheme': 'dark',
          '--t-a': '#aaaaaa',
          '--t-b': '#222222',
          'font-family': 'y',
        }),
      ],
    );
    expect(css['--t-a'], 'light-dark(#111111, #aaaaaa)');
    expect(css['--t-b'], '#222222');
    // color-scheme (what picks the side) and non-colors stay in the rule;
    // equal values leave it.
    expect(conditions.single.css, {'color-scheme': 'dark', 'font-family': 'y'});
  });

  test('without color-scheme in the dark rule nothing is folded', () {
    const dark = [
      ConditionalCss(CssCondition.dark, {'--t-a': '#aaaaaa'}),
    ];
    final (css, conditions) = foldSchemeColors({'--t-a': '#111111'}, dark);
    expect(css['--t-a'], '#111111');
    expect(identical(conditions, dark), isTrue);
  });

  test('a value an earlier breakpoint sets keeps its dark rule', () {
    final (css, conditions) = foldSchemeColors(scheme, const [
      ConditionalCss(CssCondition.media('(min-width: 1px)'), {
        '--t-a': '#333333',
      }),
      ConditionalCss(CssCondition.dark, {
        'color-scheme': 'dark',
        '--t-a': '#aaaaaa',
      }),
    ]);
    expect(css['--t-a'], '#111111');
    expect(conditions.last.css, {'color-scheme': 'dark', '--t-a': '#aaaaaa'});
  });

  test('a var() or a keyword is not a color to fold', () {
    expect(isCssColor('#abc'), isTrue);
    expect(isCssColor('hsl(0 0% 3.9%)'), isTrue);
    expect(isCssColor('color-mix(in srgb, red 8%, transparent)'), isTrue);
    expect(isCssColor('var(--x)'), isFalse);
    expect(isCssColor('inherit'), isFalse);
    expect(isCssColor('0 1px 2px #000'), isFalse);
    final (css, _) = foldSchemeColors(scheme, const [
      ConditionalCss(CssCondition.dark, {
        'color-scheme': 'dark',
        '--t-a': 'var(--t-other)',
      }),
    ]);
    expect(css['--t-a'], '#111111');
  });
}
