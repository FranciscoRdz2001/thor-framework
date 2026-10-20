@TestOn('vm')
library;

// The markup and the CSS the keyboard parts of the lite engine (`tabs`,
// `menu`) rely on, `highContrastTheme` as `@media (prefers-contrast: more)`
// and the forced-colors rules of the controls that draw state with color.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _doc(Widget w, {ThemeData? theme}) =>
    renderDocument(ThorApp(theme: theme, child: w));

String _styles(String html) {
  final start = html.indexOf('<style id="thor-styles">');
  return html.substring(start, html.indexOf('</style>', start));
}

// The `@media` blocks of [css] that start with [query].
List<String> _media(String css, String query) {
  final out = <String>[];
  var at = css.indexOf('@media $query');
  while (at >= 0) {
    var depth = 0, end = at;
    for (var i = css.indexOf('{', at); i < css.length; i++) {
      if (css[i] == '{') depth++;
      if (css[i] == '}' && --depth == 0) {
        end = i + 1;
        break;
      }
    }
    out.add(css.substring(at, end));
    at = css.indexOf('@media $query', end);
  }
  return out;
}

void main() {
  setUpAll(initializeThorTests);

  group('tabs', () {
    const tabs = DefaultTabController(
      id: 'p',
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: 'One'),
              Tab(text: 'Two'),
            ],
          ),
          TabBarView(children: [Text('a'), Text('b')]),
        ],
      ),
    );

    test(
      'the bar is marked for the tabs part and starts as a radio group',
      () async {
        final html = await _doc(tabs);
        expect(html, contains('role="radiogroup" data-t-tabs'));
        expect(html, contains('type="radio" name="p" value="0" checked'));
        expect(html, contains('aria-controls="p-panel-0"'));
        expect(html, contains('id="p-tab-0"'));
      },
    );

    test(
      'a focused tab (the part makes the label the tab) has a ring',
      () async {
        final css = _styles(await _doc(tabs));
        expect(css, contains(':focus-visible{outline: 2px solid'));
        expect(css, contains(':has(:focus-visible){outline'));
      },
    );

    test(
      'forced colors underline the selected tab (the shadow is dropped)',
      () async {
        final css = _styles(await _doc(tabs));
        final forced = _media(css, '(forced-colors: active)').join();
        expect(
          forced,
          contains(
            ':has(:checked){box-shadow: none; text-decoration: underline',
          ),
        );
      },
    );
  });

  group('menus', () {
    test('PopupMenuButton marks its panel for the menu part', () async {
      final html = await _doc(
        const PopupMenuButton(
          id: 'pm',
          items: [
            PopupMenuItem(value: 'a', child: Text('Alpha')),
            PopupMenuItem(value: 'b', child: Text('Beta')),
          ],
          child: Text('Pop'),
        ),
      );
      expect(html, contains('popover="auto" data-t-menu'));
      // Without JS it is a disclosure: the part adds the roles when the menu opens.
      expect(html, isNot(contains('role="menu"')));
    });

    test('a current item keeps its menuitemradio role', () async {
      final html = await _doc(
        const PopupMenuButton(
          id: 'pm',
          initialValue: 'a',
          items: [
            PopupMenuItem(value: 'a', child: Text('Alpha')),
            PopupMenuItem(value: 'b', child: Text('Beta')),
          ],
          child: Text('Pop'),
        ),
      );
      expect('role="menuitemradio"'.allMatches(html), hasLength(2));
    });

    test('MenuAnchor and its submenus are marked, links stay links', () async {
      final html = await _doc(
        MenuAnchor(
          id: 'm',
          builder: (context, controller, child) =>
              TextButton(onPressed: () {}, child: const Text('Acct')),
          menuChildren: [
            MenuItemButton(onPressed: () {}, child: const Text('Share')),
            const MenuItemButton(href: '/orders', child: Text('Orders')),
            SubmenuButton(
              id: 'sm',
              menuChildren: [
                MenuItemButton(onPressed: () {}, child: const Text('Deep')),
              ],
              child: const Text('More'),
            ),
          ],
        ),
      );
      expect(' data-t-menu'.allMatches(html), hasLength(2));
      expect(html, contains('<a class="'));
      expect(html, contains('aria-haspopup="true"'));
    });

    test('forced colors give the popover an edge', () async {
      final css = _styles(
        await _doc(
          const PopupMenuButton(
            id: 'pm',
            items: [PopupMenuItem(value: 'a', child: Text('Alpha'))],
            child: Text('Pop'),
          ),
        ),
      );
      expect(
        _media(css, '(forced-colors: active)').join(),
        contains('border: 1px solid CanvasText'),
      );
    });
  });

  group('selection controls under forced colors', () {
    test(
      'checkbox, switch and radio get the browser\'s own look back',
      () async {
        final css = _styles(
          await _doc(
            Column(
              children: [
                Checkbox(value: true, onChanged: (_) {}),
                Switch(value: true, onChanged: (_) {}),
                Radio<int>(value: 1, groupValue: 1, onChanged: (_) {}),
              ],
            ),
          ),
        );
        final forced = _media(css, '(forced-colors: active)').join();
        // The checkbox and the radio: the browser's own look; the switch keeps
        // its shape, drawn in system colors.
        expect(
          'appearance: auto'.allMatches(forced).length,
          greaterThanOrEqualTo(2),
        );
        expect(forced, contains('background-image: none !important'));
        expect(forced, contains('forced-color-adjust: none'));
        expect(forced, contains('background-color: Highlight !important'));
      },
    );
  });

  group('highContrastTheme', () {
    final light = ThemeData();
    final dark = ThemeData(colorScheme: const ColorScheme.dark());
    final highLight = ThemeData(
      colorScheme: const ColorScheme.highContrastLight(),
    );
    final highDark = ThemeData(
      colorScheme: const ColorScheme.highContrastDark(),
    );

    Future<String> app({
      ThemeData? hc,
      ThemeData? hcDark,
      ThemeData? darkTheme,
    }) async => _styles(
      await renderDocument(
        ThorApp(
          theme: light,
          darkTheme: darkTheme,
          highContrastTheme: hc,
          highContrastDarkTheme: hcDark,
          child: const Text('x'),
        ),
      ),
    );

    test(
      'only the variables that differ, under prefers-contrast: more',
      () async {
        final css = await app(hc: highLight);
        final blocks = _media(css, '(prefers-contrast: more)');
        expect(blocks, hasLength(1));
        expect(blocks.single, contains(':root{'));
        expect(blocks.single, contains('--t-on-surface:#000000'));
        expect(blocks.single, contains('--t-surface:#ffffff'));
        // The same variables as the base theme are not repeated.
        expect(blocks.single, isNot(contains('--t-error-container')));
      },
    );

    test('without one the page has no such block', () async {
      expect(_media(await app(), '(prefers-contrast: more)'), isEmpty);
    });

    test('a light and a dark pair become light-dark() colors', () async {
      final css = await app(darkTheme: dark, hc: highLight, hcDark: highDark);
      final block = _media(css, '(prefers-contrast: more)').single;
      expect(block, contains('--t-surface:light-dark(#ffffff, #000000)'));
      expect(block, contains('--t-on-surface:light-dark(#000000, #ffffff)'));
    });

    test('a dark theme without a high contrast one stays as it is', () async {
      final css = await app(darkTheme: dark, hc: highLight);
      final block = _media(css, '(prefers-contrast: more)').single;
      // Light side from the high contrast theme, dark side the dark theme's.
      expect(block, contains('light-dark(#ffffff, #141218)'));
    });

    test(
      'themeMode dark picks highContrastDarkTheme without a darkTheme',
      () async {
        final css = _styles(
          await renderDocument(
            ThorApp(
              theme: light,
              themeMode: ThemeMode.dark,
              highContrastTheme: highLight,
              highContrastDarkTheme: highDark,
              child: const Text('x'),
            ),
          ),
        );
        final block = _media(css, '(prefers-contrast: more)').single;
        expect(block, contains('--t-surface:#000000'));
      },
    );

    test('ThorApp.page keeps both', () {
      final app = ThorApp(
        highContrastTheme: highLight,
        highContrastDarkTheme: highDark,
        child: const Text('x'),
      );
      final paged = app.page(const Text('y'));
      expect(paged.highContrastTheme, same(highLight));
      expect(paged.highContrastDarkTheme, same(highDark));
    });
  });
}
