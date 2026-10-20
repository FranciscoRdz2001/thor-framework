// Render a widget to HTML inside a VM test. Copy it to `test/`.
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  setUpAll(initializeThorTests);

  test('Row is a flexbox', () async {
    final html = await renderHtml(const Row(children: [Text('a')]));
    expect(html, contains('display: flex'));
  });
}
