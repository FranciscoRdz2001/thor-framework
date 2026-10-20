@TestOn('vm')
library;

// `isDense`, `itemHeight` and `contentPadding` set the `<select>` height.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Widget w) => renderDocument(ThorApp(child: w));

String _head(String html) => html.substring(0, html.indexOf('</head>'));

void main() {
  setUpAll(initializeThorTests);

  group('dense DropdownButton (46)', () {
    const items = [DropdownMenuItem(value: 'a', child: Text('A'))];

    test('isDense is 36 px, itemHeight sets it exactly', () async {
      final plain = _head(
        await _page(const DropdownButton<String>(items: items, value: 'a')),
      );
      expect(plain, contains('min-height: 48px'));
      final dense = _head(
        await _page(
          const DropdownButton<String>(items: items, value: 'a', isDense: true),
        ),
      );
      expect(dense, contains('min-height: 36px'));
      final tall = _head(
        await _page(
          const DropdownButton<String>(
            items: items,
            value: 'a',
            itemHeight: 52,
          ),
        ),
      );
      expect(tall, contains('min-height: 52px'));
    });

    test('the form field follows isDense and contentPadding', () async {
      final dense = _head(
        await _page(
          const DropdownButtonFormField<String>(
            items: items,
            initialValue: 'a',
            isDense: true,
          ),
        ),
      );
      expect(dense, contains('min-height: 36px'));
      final padded = _head(
        await _page(
          const DropdownButtonFormField<String>(
            items: items,
            initialValue: 'a',
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ),
        ),
      );
      expect(padded, isNot(contains('min-height: 48px')));
      expect(padded, contains('padding: 6px'));
      // The old dense decoration keeps its 40 px.
      final decorated = _head(
        await _page(
          const DropdownButtonFormField<String>(
            items: items,
            initialValue: 'a',
            decoration: InputDecoration(isDense: true),
          ),
        ),
      );
      expect(decorated, contains('min-height: 40px'));
      final heightened = _head(
        await _page(
          const DropdownButtonFormField<String>(
            items: items,
            initialValue: 'a',
            itemHeight: 32,
          ),
        ),
      );
      expect(heightened, contains('min-height: 32px'));
    });
  });
}
