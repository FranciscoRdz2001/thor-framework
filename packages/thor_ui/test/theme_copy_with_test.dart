// ThemeData.copyWith (Flutter's): every field, the component themes
// included, and the typed tokens that joined colorTokens.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/thor_ui.dart';

class _Ext extends ThemeExtension<_Ext> {
  const _Ext();
}

void main() {
  const brand = ColorToken(
    'brand',
    light: Color(0xFF111111),
    dark: Color(0xFFEEEEEE),
  );
  final base = ThemeData(
    colorTokens: const {'plain': Color(0xFF010203)},
    tokens: const [brand],
    extensions: const [_Ext()],
    focusColor: const Color(0xFF0000FF),
    inputDecorationTheme: const InputDecorationTheme(isDense: true),
    cardTheme: const CardThemeData(elevation: 2),
    chipTheme: const ChipThemeData(),
    expansionTileTheme: const ExpansionTileThemeData(),
    filledButtonTheme: const FilledButtonThemeData(),
    elevatedButtonTheme: const ElevatedButtonThemeData(),
    outlinedButtonTheme: const OutlinedButtonThemeData(),
    textButtonTheme: const TextButtonThemeData(),
    iconButtonTheme: const IconButtonThemeData(),
  );

  test('with nothing, every field is kept (tokens do not collide)', () {
    final c = base.copyWith();
    expect(c.colorScheme, same(base.colorScheme));
    expect(c.textTheme, same(base.textTheme));
    expect(c.breakpoints, same(base.breakpoints));
    expect(c.tokens, base.tokens);
    expect(c.colorTokens.keys, base.colorTokens.keys);
    expect(c.extensions, base.extensions);
    expect(c.fontFamily, base.fontFamily);
    expect(c.fonts, base.fonts);
    expect(c.focusColor, base.focusColor);
    expect(c.inputDecorationTheme, same(base.inputDecorationTheme));
    expect(c.cardTheme, same(base.cardTheme));
    expect(c.chipTheme, same(base.chipTheme));
    expect(c.expansionTileTheme, same(base.expansionTileTheme));
    expect(c.filledButtonTheme, same(base.filledButtonTheme));
    expect(c.elevatedButtonTheme, same(base.elevatedButtonTheme));
    expect(c.outlinedButtonTheme, same(base.outlinedButtonTheme));
    expect(c.textButtonTheme, same(base.textButtonTheme));
    expect(c.iconButtonTheme, same(base.iconButtonTheme));
    expect(c.toCssVariables(), base.toCssVariables());
  });

  test('each given field replaces its own and only its own', () {
    const card = CardThemeData(elevation: 9);
    const chip = ChipThemeData();
    const tile = ExpansionTileThemeData();
    const filled = FilledButtonThemeData();
    const elevated = ElevatedButtonThemeData();
    const outlined = OutlinedButtonThemeData();
    const text = TextButtonThemeData();
    const icon = IconButtonThemeData();
    const input = InputDecorationTheme(filled: true);
    final c = base.copyWith(
      cardTheme: card,
      chipTheme: chip,
      expansionTileTheme: tile,
      filledButtonTheme: filled,
      elevatedButtonTheme: elevated,
      outlinedButtonTheme: outlined,
      textButtonTheme: text,
      iconButtonTheme: icon,
      inputDecorationTheme: input,
      fontFamily: 'Figtree',
      focusColor: const Color(0xFFFF0000),
    );
    expect(c.cardTheme, same(card));
    expect(c.chipTheme, same(chip));
    expect(c.expansionTileTheme, same(tile));
    expect(c.filledButtonTheme, same(filled));
    expect(c.elevatedButtonTheme, same(elevated));
    expect(c.outlinedButtonTheme, same(outlined));
    expect(c.textButtonTheme, same(text));
    expect(c.iconButtonTheme, same(icon));
    expect(c.inputDecorationTheme, same(input));
    expect(c.fontFamily, 'Figtree');
    expect(c.focusColor, const Color(0xFFFF0000));
    // The rest is the base's.
    expect(c.colorScheme, same(base.colorScheme));
    expect(c.tokens, base.tokens);
    expect(base.cardTheme!.elevation, 2, reason: 'the original is untouched');
  });

  test('a dark scheme re-resolves the typed tokens to their dark side', () {
    final dark = base.copyWith(colorScheme: const ColorScheme.dark());
    expect(dark.brightness, Brightness.dark);
    expect(dark.colorTokens['brand'], brand.dark);
    expect(dark.colorTokens['plain'], const Color(0xFF010203));
    expect(base.colorTokens['brand'], brand.light);
  });

  test('new tokens/colorTokens replace theirs; a duplicate still throws', () {
    final c = base.copyWith(colorTokens: const {'other': Color(0xFF000001)});
    expect(c.colorTokens.keys, containsAll(['other', 'brand']));
    expect(c.colorTokens.containsKey('plain'), isFalse);
    expect(
      () => base.copyWith(colorTokens: const {'brand': Color(0xFF000002)}),
      throwsArgumentError,
    );
  });

  test('Theme.of of a copy keeps the component themes', () {
    final c = base.copyWith(cardTheme: const CardThemeData(elevation: 7));
    expect(c.cardTheme!.elevation, 7);
  });

  test('TextTheme.copyWith on a .when() theme keeps the variants', () {
    final base = TextTheme(displayLarge: const TextStyle(fontSize: 48));
    final adaptive = base.when(
      medium: base.copyWith(displayLarge: const TextStyle(fontSize: 60)),
    );
    const body = TextStyle(fontSize: 17);
    final copy = adaptive.copyWith(bodyLarge: body);
    expect(copy.bodyLarge.fontSize, 17);
    expect(copy.displayLarge.fontSize, 48);
    final medium = copy.variants!.medium!;
    expect(medium.bodyLarge.fontSize, 17);
    expect(medium.displayLarge.fontSize, 60);
  });
}
