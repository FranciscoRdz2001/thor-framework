@TestOn('vm')
library;

// `ListTile(minTileHeight:, minVerticalPadding:)`.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Widget w) => renderDocument(ThorApp(child: w));

String _head(String html) => html.substring(0, html.indexOf('</head>'));

void main() {
  setUpAll(initializeThorTests);

  group('ListTile minTileHeight (59)', () {
    test('minTileHeight and minVerticalPadding replace the defaults', () async {
      final head = _head(
        await _page(
          const ListTile(
            minTileHeight: 47,
            minVerticalPadding: 6,
            title: Text('Rail'),
          ),
        ),
      );
      expect(head, contains('min-height: 47px'));
      expect(head, contains('padding-block: 6px'));
    });

    test('the theme gives them to every tile', () async {
      final head = _head(
        await renderDocument(
          ThorApp(
            theme: ThemeData(
              listTileTheme: const ListTileThemeData(minTileHeight: 40),
            ),
            child: const ListTile(title: Text('Rail')),
          ),
        ),
      );
      expect(head, contains('min-height: 40px'));
    });
  });
}
