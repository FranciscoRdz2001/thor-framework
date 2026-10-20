@TestOn('vm')
library;

// `ExpansionTile` control affinity, trailing, density and chevron turns.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Widget w) => renderDocument(ThorApp(child: w));

String _head(String html) => html.substring(0, html.indexOf('</head>'));

String _body(String html) => html.substring(html.indexOf('<body'));

void main() {
  setUpAll(initializeThorTests);

  group('ExpansionTile (47)', () {
    test('a leading chevron sits at the start, small and turned', () async {
      final head = _head(
        await _page(
          const ExpansionTile(
            controlAffinity: ListTileControlAffinity.leading,
            iconSize: 13,
            iconTurns: 0,
            collapsedIconTurns: -0.25,
            dense: true,
            minTileHeight: 26,
            title: Text('Layout'),
            children: [Text('Row')],
          ),
        ),
      );
      expect(head, contains('left: 16px'));
      expect(head, contains('width: 13px'));
      expect(head, contains('rotate: -90deg'));
      expect(head, contains('rotate: 0deg'));
      expect(head, contains('min-height: 26px'));
      // Room before the label: 16 + 13 + 16.
      expect(head, contains('padding: 8px 16px 8px 45px'));
    });

    test(
      'showTrailingIcon false and a trailing widget drop the chevron',
      () async {
        final hidden = _head(
          await _page(
            const ExpansionTile(
              showTrailingIcon: false,
              title: Text('A'),
              children: [Text('x')],
            ),
          ),
        );
        expect(hidden, isNot(contains('mask')));
        final custom = await _page(
          const ExpansionTile(
            trailing: Text('12'),
            title: Text('A'),
            children: [Text('x')],
          ),
        );
        expect(_head(custom), isNot(contains('mask')));
        expect(_body(custom), contains('12'));
        // As in Flutter, showTrailingIcon false hides a trailing widget too.
        final none = await _page(
          const ExpansionTile(
            showTrailingIcon: false,
            trailing: Text('99'),
            title: Text('A'),
            children: [Text('x')],
          ),
        );
        expect(_body(none), isNot(contains('99')));
      },
    );

    test('the default tile keeps its chevron on the right', () async {
      final head = _head(
        await _page(
          const ExpansionTile(title: Text('A'), children: [Text('x')]),
        ),
      );
      expect(head, contains('padding: 8px 48px 8px 16px'));
      expect(head, contains('min-height: 56px'));
      expect(head, contains('rotate: 180deg'));
    });
  });

  group('ExpansionTile gap and hover (67)', () {
    test(
      'iconGap sets the room between a leading chevron and the title',
      () async {
        final head = _head(
          await _page(
            const ExpansionTile(
              controlAffinity: ListTileControlAffinity.leading,
              iconSize: 13,
              iconGap: 4,
              title: Text('Palette'),
              children: [Text('Row')],
            ),
          ),
        );
        // 16 + 13 + 4.
        expect(head, contains('padding: 8px 16px 8px 33px'));
      },
    );

    test('hoverColor replaces the header tint, also from the theme', () async {
      final own = _head(
        await _page(
          const ExpansionTile(
            hoverColor: Color(0x00000000),
            title: Text('A'),
            children: [Text('x')],
          ),
        ),
      );
      expect(own, isNot(contains('color-mix(in srgb')));
      final themed = _head(
        await renderDocument(
          ThorApp(
            theme: ThemeData(
              expansionTileTheme: const ExpansionTileThemeData(
                hoverColor: Color(0xFF112233),
              ),
            ),
            child: const ExpansionTile(title: Text('A'), children: [Text('x')]),
          ),
        ),
      );
      expect(themed, contains('background-color: #112233'));
      final plain = _head(
        await _page(
          const ExpansionTile(title: Text('A'), children: [Text('x')]),
        ),
      );
      expect(plain, contains('color-mix(in srgb'));
    });
  });

  test("a title's own style wins over the tile's body-large", () async {
    // Flutter merges the Text's style over the tile's theme text style.
    final html = await renderHtml(
      const ExpansionTile(
        title: Text('Q', style: TextStyle(fontSize: 17, letterSpacing: -0.17)),
        children: [Text('A')],
      ),
    );
    final summary = RegExp(
      '<summary [^>]*style="([^"]*)"',
    ).firstMatch(html)![1]!;
    expect(summary, contains('font-size: 17px'));
    expect(summary, contains('letter-spacing: -0.17px'));
    expect(summary, isNot(contains('--t-body-large-size')));
    // What the title doesn't set still comes from the theme.
    expect(summary, contains('--t-body-large-line'));
  });
}
