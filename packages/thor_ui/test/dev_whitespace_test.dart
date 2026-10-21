@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// The text of `<div class="…">…</div>`-like elements: what the browser reads
// between the tags of the first element with [needle] in its opening tag.
String _bodyOf(String html, String text) {
  final at = html.indexOf(text.split('\n').first);
  expect(at, greaterThan(-1), reason: 'text not found');
  return html.substring(at, html.indexOf('</', at));
}

void main() {
  // Text with line breaks (`white-space: pre-wrap`) must be the same bytes in
  // the indented dev page and in the release page.
  test('text with line breaks is written alike in dev and release', () async {
    const text = 'First line\n  second, indented\n\nlast line';
    final app = ThorApp(
      child: Column(
        children: [
          const Container(padding: EdgeInsets.all(4), child: Text(text)),
          for (var i = 0; i < 12; i++) Text('filler number $i'),
          const Text(text, softWrap: false),
        ],
      ),
    );
    initializeThorTests(compactHtml: true);
    final release = await renderDocument(app);
    initializeThorTests(compactHtml: false);
    final dev = await renderDocument(app);
    expect(_bodyOf(release, text), text);
    expect(_bodyOf(dev, text), text);
    expect(
      RegExp(r'last line</').allMatches(dev).length,
      2,
      reason: 'both texts are written untouched',
    );
  });
}
