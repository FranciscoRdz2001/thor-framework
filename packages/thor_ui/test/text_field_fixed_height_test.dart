// Fixture: fields without a label on purpose.
// ignore_for_file: thor_lints/text_field_without_label
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Widget w) => renderDocument(ThorApp(child: w));

Future<String> _css(Widget w) async => RegExp(
  r'<style[^>]*>([\s\S]*?)</style>',
).allMatches(await _page(w)).map((m) => m[1]).join().replaceAll(' ', '');

String _ruleOf(String html, String css, RegExp tag) {
  final cls = RegExp(
    r'class="([^"]+)"',
  ).firstMatch(tag.firstMatch(html)![0]!)![1]!;
  return RegExp('\\.$cls\\{([^}]*)\\}').firstMatch(css)![1]!;
}

void main() {
  setUpAll(initializeThorTests);

  test('a tight height starts a multi-line field at it, resizable', () async {
    const field = TextField(
      name: 'code',
      maxLines: 3,
      decoration: InputDecoration(
        constraints: BoxConstraints.tightFor(height: 36),
      ),
    );
    final html = await _page(field);
    final css = await _css(field);
    final area = _ruleOf(html, css, RegExp(r'<textarea\b[^>]*>'));
    expect(area, contains('height:36px'));
    expect(area, contains('resize:vertical'));
    // web: the row grows when the user resizes the textarea.
    final row = _ruleOf(html, css, RegExp(r'<label\b[^>]*>'));
    expect(row, contains('min-height:36px'));
    expect(RegExp(r'(^|;)height:36px').hasMatch(row), isFalse);
  });
}
