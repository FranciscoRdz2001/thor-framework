@TestOn('vm')
library;

// a `<select>` takes its border, shadow and arrow from its
// decoration and its own parameters.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _doc(Widget w) => renderDocument(ThorApp(child: w));

Future<String> _head(Widget w) async {
  final html = await _doc(w);
  return html.substring(0, html.indexOf('</head>'));
}

const _items = [DropdownMenuItem(value: 'a', child: Text('A'))];

void main() {
  setUpAll(initializeThorTests);

  group('select decoration (69)', () {
    test("the outline border side is the select's border", () async {
      final css = await _head(
        const DropdownButtonFormField<String>(
          items: _items,
          initialValue: 'a',
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF123456), width: 1),
            ),
          ),
        ),
      );
      expect(css, contains('border: 1px solid #123456'));
    });

    test('a border with no color takes the outline role', () async {
      final css = await _head(
        const DropdownButtonFormField<String>(
          items: _items,
          initialValue: 'a',
          decoration: InputDecoration(border: OutlineInputBorder()),
        ),
      );
      expect(css, contains('border: 1px solid var(--t-outline'));
    });

    test('boxShadow paints a shadow on the select', () async {
      final css = await _head(
        const DropdownButtonFormField<String>(
          items: _items,
          initialValue: 'a',
          boxShadow: [
            BoxShadow(color: Color(0x1A000000), offset: Offset(0, 1)),
          ],
        ),
      );
      expect(css, contains('box-shadow: 0px 1px 0px 0px'));
      final plain = await _head(
        const DropdownButton<String>(
          items: _items,
          value: 'a',
          boxShadow: [BoxShadow(blurRadius: 2)],
        ),
      );
      expect(plain, contains('box-shadow: 0px 0px 2px 0px'));
    });

    test('iconEnabledColor swaps the native arrow for its own', () async {
      final css = await _head(
        const DropdownButtonFormField<String>(
          items: _items,
          initialValue: 'a',
          iconEnabledColor: Color(0xFF445566),
          iconSize: 16,
          decoration: InputDecoration(
            contentPadding: EdgeInsets.fromLTRB(8, 0, 32, 0),
          ),
        ),
      );
      expect(css, contains('appearance: none'));
      expect(css, contains('background-image'));
      expect(css, contains('linear-gradient'));
      expect(css, contains('#445566'));
      // No 36 px floor for the right padding: the app gave 32.
      expect(css, contains('padding: 0px 32px 0px 8px'));
      final native = await _head(
        const DropdownButton<String>(items: _items, value: 'a'),
      );
      expect(native, isNot(contains('appearance: none')));
    });

    test('a theme-token arrow color never goes inside a data: image', () async {
      final css = await _head(
        const DropdownButton<String>(
          items: _items,
          value: 'a',
          iconEnabledColor: Color.token('faint', fallback: Color(0xFF888888)),
        ),
      );
      // A custom property does not resolve inside `url(data:...)`.
      expect(
        RegExp(r'url\("data:[^)]*var\(|url\("data:[^)]*var%28').hasMatch(css),
        isFalse,
      );
      expect(css, contains('var(--t-faint'));
      expect(css, contains('linear-gradient'));
    });

    test(
      'the own arrow is arrow_drop_down sized: 10x5 in a 24 px icon',
      () async {
        final css = await _head(
          const DropdownButton<String>(
            items: _items,
            value: 'a',
            iconEnabledColor: Color(0xFF445566),
          ),
        );
        // Two 5 px halves centered in the 24 px icon box that sits 8 px from
        // the right edge (center at 20 px).
        expect(css, contains('background-size: 5px 5px'));
        expect(
          css,
          contains('background-position: right 20px center, right 15px center'),
        );
      },
    );

    test('semanticLabel names the form field select', () async {
      final html = await _doc(
        const DropdownButtonFormField<String>(
          items: _items,
          initialValue: 'a',
          semanticLabel: 'Device',
        ),
      );
      expect(html, contains('aria-label="Device"'));
    });
  });
}
