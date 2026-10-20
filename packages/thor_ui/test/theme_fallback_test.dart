@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

String layers(String html) =>
    html.substring(html.indexOf('@layer thor.props'), html.indexOf('</style>'));

void main() {
  setUpAll(initializeThorTests);

  final button = FilledButton(onPressed: () {}, child: const Text('Add'));

  test('with a theme, theme variables carry no fallback', () async {
    final html = await renderDocument(
      ThorApp(theme: ThemeData(), child: button),
    );
    final css = layers(html);
    expect(css, contains('var(--t-primary)'));
    expect(css, isNot(contains('var(--t-primary, ')));
    expect(css, contains('var(--t-label-large-size)'));
  });

  test('without a theme, the fallbacks stay', () async {
    final html = await renderDocument(ThorApp(child: button));
    expect(layers(html), contains('var(--t-primary, #6750a4)'));
  });

  test("a variable the theme doesn't define keeps its fallback", () async {
    final html = await renderDocument(
      ThorApp(
        theme: ThemeData(),
        child: const Container(
          color: Color.variable(
            CssVariable('--t-brand'),
            fallback: Color(0xFF123456),
          ),
        ),
      ),
    );
    expect(layers(html), contains('var(--t-brand, #123456)'));
  });
}
