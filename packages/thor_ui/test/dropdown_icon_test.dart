@TestOn('vm')
library;

// DropdownButton.icon: the trailing arrow is the given widget, a sibling over
// the native `<select>`.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _doc(Widget w) => renderDocument(ThorApp(child: w));

void _noop(String? _) {}

/// The declarations of the class on the element `data-thor="[name]"`.
String _rule(String html, String name) {
  final tag = RegExp(
    '<[a-z]+\\b[^>]*data-thor="$name"[^>]*>',
  ).firstMatch(html)!;
  final cls = RegExp(r'class="([^"]+)"').firstMatch(tag[0]!)![1]!;
  return RegExp('\\.$cls\\{([^}]*)\\}').firstMatch(html)![1]!;
}

const _items = [DropdownMenuItem(value: 'a', child: Text('A'))];

void main() {
  setUpAll(initializeThorTests);

  group('DropdownButton icon', () {
    test('the icon follows the select, inert, sized and colored', () async {
      final html = await _doc(
        const DropdownButton<String>(
          items: _items,
          value: 'a',
          onChanged: _noop,
          icon: Icon(Icons.search),
          iconSize: 16,
          iconEnabledColor: Color(0xFF445566),
        ),
      );
      expect(html, contains('</select>'));
      expect(html.indexOf('</select>'), lessThan(html.indexOf('<svg')));
      expect(html, contains('appearance: none'));
      expect(html, contains('pointer-events: none'));
      expect(html, contains('#445566'));
      expect(html, contains('width="16"'));
      expect(html, isNot(contains('linear-gradient')));
    });

    test('a disabled button dims the icon or uses iconDisabledColor', () async {
      final dim = await _doc(
        const DropdownButton<String>(
          items: _items,
          value: 'a',
          onChanged: null,
          icon: Icon(Icons.search),
        ),
      );
      expect(_rule(dim, 'DropdownButtonIcon'), contains('opacity: 0.38'));
      final own = await _doc(
        const DropdownButton<String>(
          items: _items,
          value: 'a',
          onChanged: null,
          icon: Icon(Icons.search),
          iconDisabledColor: Color(0xFFAA0000),
        ),
      );
      final rule = _rule(own, 'DropdownButtonIcon');
      expect(rule, contains('#aa0000'));
      expect(rule, isNot(contains('opacity')));
    });

    test('an Icon with its own size keeps it', () async {
      final html = await _doc(
        const DropdownButton<String>(
          items: _items,
          value: 'a',
          onChanged: _noop,
          icon: Icon(Icons.search, size: 20),
          iconSize: 16,
        ),
      );
      expect(html, contains('width="20"'));
    });

    test('an explicit size of 24 is kept, as Flutter\'s', () async {
      final html = await _doc(
        const DropdownButton<String>(
          items: _items,
          value: 'a',
          onChanged: _noop,
          icon: Icon(Icons.search, size: 24),
          iconSize: 32,
        ),
      );
      expect(html, contains('width="24"'));
      expect(html, isNot(contains('width="32"')));
      // The default Icon takes iconSize.
      expect(const Icon(Icons.search).size, 24);
    });

    test('the form field puts its decoration on the select', () async {
      final html = await _doc(
        const DropdownButtonFormField<String>(
          items: _items,
          initialValue: 'a',
          onChanged: _noop,
          icon: Icon(Icons.search),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.fromLTRB(8, 0, 32, 0),
          ),
        ),
      );
      expect(
        _rule(html, 'DropdownButton'),
        contains('padding: 0px 32px 0px 8px'),
      );
      expect(_rule(html, 'DropdownButtonBox'), isNot(contains('padding')));
      expect(html, contains('pointer-events: none'));
    });

    test('without icon the output has no box', () async {
      final html = await _doc(
        const DropdownButton<String>(items: _items, value: 'a'),
      );
      expect(html, isNot(contains('pointer-events: none')));
    });
  });
}
