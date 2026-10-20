@TestOn('vm')
library;

// `ListTile(hoverColor:, focusColor:, splashColor:)`.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Widget w, {ThemeData? theme}) =>
    renderDocument(ThorApp(theme: theme, child: w));

String _head(String html) => html.substring(0, html.indexOf('</head>'));

void main() {
  setUpAll(initializeThorTests);

  group('ListTile state colors (88)', () {
    test('defaults keep the 8 % hover and no focus/press fill', () async {
      final head = _head(
        await _page(const ListTile(href: '/x', title: Text('x'))),
      );
      expect(head, contains('color-mix(in srgb'));
      expect(head, isNot(contains('#112233')));
    });

    test('transparent hoverColor removes the layer', () async {
      final head = _head(
        await _page(
          const ListTile(
            href: '/x',
            hoverColor: Color(0x00000000),
            title: Text('x'),
          ),
        ),
      );
      expect(head, isNot(contains('color-mix(in srgb')));
    });

    test(
      'focusColor and splashColor fill the focused and pressed tile',
      () async {
        final head = _head(
          await _page(
            ListTile(
              onTap: () {},
              focusColor: const Color(0xFF112233),
              splashColor: const Color(0xFF445566),
              title: const Text('x'),
            ),
          ),
        );
        expect(head, contains('linear-gradient(#112233, #112233)'));
        expect(head, contains('linear-gradient(#445566, #445566)'));
      },
    );

    test('the state colors are layers over tileColor', () async {
      final head = _head(
        await _page(
          ListTile(
            onTap: () {},
            tileColor: const Color(0xFF0000FF),
            hoverColor: const Color(0x00000000),
            focusColor: const Color(0x33112233),
            splashColor: const Color(0x33445566),
            title: const Text('x'),
          ),
        ),
      );
      // The tile keeps its fill in every state; each color is drawn over it.
      expect(head, contains('background-color: #0000ff'));
      expect('background-color'.allMatches(head), hasLength(1));
      expect(head, contains('background-image: linear-gradient('));
    });

    test(
      'a split tile fills whole while its body is focused or pressed',
      () async {
        final head = _head(
          await _page(
            ListTile(
              onTap: () {},
              focusColor: const Color(0xFF112233),
              splashColor: const Color(0xFF445566),
              title: const Text('x'),
              trailing: Switch(value: true, onChanged: (_) {}),
            ),
          ),
        );
        final rules = head.split('}');
        String rule(String color) =>
            rules.firstWhere((r) => r.contains('linear-gradient($color'));
        // On the outer div (as hover), while the link/button is in the state;
        // the Switch beside it doesn't fill the tile.
        expect(
          rule('#112233'),
          contains(':has(> :nth-child(1 of :not(style)):focus-visible)'),
        );
        expect(
          rule('#445566'),
          contains(':has(> :nth-child(1 of :not(style)):active)'),
        );
        final leading = _head(
          await _page(
            ListTile(
              onTap: () {},
              focusColor: const Color(0xFF112233),
              leading: Checkbox(value: true, onChanged: (_) {}),
              title: const Text('x'),
            ),
          ),
        );
        expect(
          leading,
          contains(':has(> :nth-child(2 of :not(style)):focus-visible)'),
        );
      },
    );

    test('the theme gives them to every tile', () async {
      final head = _head(
        await _page(
          const ListTile(href: '/x', title: Text('x')),
          theme: ThemeData(
            listTileTheme: const ListTileThemeData(
              hoverColor: Color(0xFFAABBCC),
            ),
          ),
        ),
      );
      expect(head, contains('linear-gradient(#aabbcc, #aabbcc)'));
    });

    test('the control tiles take hoverColor', () async {
      final head = _head(
        await _page(
          CheckboxListTile(
            value: true,
            onChanged: (_) {},
            hoverColor: const Color(0xFF778899),
            title: const Text('x'),
          ),
        ),
      );
      expect(head, contains('background-color: #778899'));
    });
  });
}
