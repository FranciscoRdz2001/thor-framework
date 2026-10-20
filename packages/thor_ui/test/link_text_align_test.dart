// `Link(child: Padding(child: Text(textAlign: …)))` fuses into one `<a>`:
// the Text's alignment must survive the fusion.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Widget _link(TextAlign align) => Link(
  href: const RouteUrl('/p'),
  child: Padding(
    padding: const EdgeInsets.all(8),
    child: Text('Café', textAlign: align),
  ),
);

Future<String> _page(Widget w) => renderDocument(ThorApp(child: w));

/// The declarations of the class of the first element with [tag].
String _classOf(String html, String tag) {
  final cls = RegExp('<$tag class="([^"]+)"').firstMatch(html)![1]!;
  return RegExp(
    '\\.$cls\\{([^}]*)\\}',
  ).firstMatch(html)![1]!.replaceAll(' ', '');
}

void main() {
  setUpAll(initializeThorTests);

  for (final align in TextAlign.values) {
    test('one <a> keeps text-align: ${align.css}', () async {
      final html = await _page(_link(align));
      expect('<a'.allMatches(html), hasLength(1));
      expect('<span'.allMatches(html), isEmpty);
      final css = _classOf(html, 'a');
      expect(css, contains('text-align:${align.css}'));
      expect(css, contains('padding:8px'));
    });
  }

  test('in a stretched Column the link fills the width and keeps it', () async {
    final html = await _page(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_link(TextAlign.start)],
      ),
    );
    final css = _classOf(html, 'a');
    expect(css, contains('text-align:start'));
    expect(css, isNot(contains('align-self')));
  });

  test('the Link wrapper never sets an alignment of its own', () async {
    final css = _classOf(await _page(_link(TextAlign.end)), 'a');
    expect(css, isNot(contains('justify-content')));
    expect(css, isNot(contains('align-items')));
    expect(css, isNot(contains('display:flex')));
  });
}
