import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/web.dart';

abstract final class _Colors {
  static const band = ColorToken(
    'band',
    light: Color(0xFFF7F6F2),
    dark: Color(0xFF22252A),
  );
  static const ink = ColorToken(
    'ink',
    light: Color(0xFF17191C),
    dark: Color(0xFF17191C),
  );
  static const values = [band, ink];
}

final _light = ThemeData(tokens: _Colors.values);
final _dark = ThemeData(
  colorScheme: const ColorScheme.dark(),
  tokens: _Colors.values,
);

Future<String> _head(ThemeMode mode, Widget child) async => headOfPage(
  await renderDocument(
    ThorApp(theme: _light, darkTheme: _dark, themeMode: mode, child: child),
  ),
);

void main() {
  setUpAll(initializeThorTests);

  test('a token is the theme variable, const like any color', () {
    expect(_Colors.band.css, 'var(--t-band)');
    expect(_Colors.band.variableName, '--t-band');
    const style = TextStyle(color: _Colors.band);
    expect(style.toCss()['color'], 'var(--t-band)');
  });

  test('each theme takes the side of its brightness', () {
    expect(_light.colorTokens['band'], _Colors.band.light);
    expect(_dark.colorTokens['band'], _Colors.band.dark);
  });

  test('the page publishes the light side, the dark one or both', () async {
    const child = Text('x');
    expect(await _head(ThemeMode.light, child), contains('--t-band:#f7f6f2'));
    expect(await _head(ThemeMode.dark, child), contains('--t-band:#22252a'));
    final system = await _head(ThemeMode.system, child);
    expect(system, contains('--t-band:light-dark(#f7f6f2, #22252a)'));
    // Same value in both: no light-dark() for it.
    expect(system, contains('--t-ink:#17191c'));
  });

  test('they join the map: tw() finds them by name', () async {
    // Without the typed tokens in the map this throws THOR-R013.
    final html = await renderDocument(
      ThorApp(
        theme: _light,
        child: P(text: 'x', style: tw('bg-band text-ink')),
      ),
    );
    expect(html, contains('var(--t-band)'));
  });

  test('a name declared twice fails, never silently wins (THOR-R021)', () {
    expect(
      () => ThemeData(
        colorTokens: const {'band': Color(0xFF000000)},
        tokens: _Colors.values,
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('THOR-R021'),
        ),
      ),
    );
    expect(
      () => ThemeData(tokens: const [_Colors.band, _Colors.band]),
      throwsArgumentError,
    );
  });

  test('the map alone keeps working as before', () {
    final theme = ThemeData(colorTokens: const {'soft': Color(0xFFEEEEEE)});
    expect(theme.tokens, isEmpty);
    expect(theme.toCssVariables()['--t-soft'], '#eeeeee');
  });
}
