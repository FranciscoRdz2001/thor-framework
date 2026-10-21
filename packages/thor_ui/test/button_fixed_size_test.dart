@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  setUpAll(() => initializeThorTests(compactHtml: false));

  Future<String> css(Widget child) async {
    final html = await renderDocument(ThorApp(child: child));
    final start = html.indexOf('id="thor-styles">');
    return html
        .substring(start, html.indexOf('</style>', start))
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  test('fixedSize is the width and height of the button', () async {
    final out = await css(
      FilledButton(
        style: const ButtonStyle(
          fixedSize: WidgetStatePropertyAll(Size(120, 44)),
        ),
        onPressed: null,
        child: const Text('x'),
      ),
    );
    expect(out, contains('width: 120px'));
    expect(out, contains('height: 44px'));
  });

  test('an infinite dimension of fixedSize stays free', () async {
    final out = await css(
      TextButton(
        style: ButtonStyle(
          fixedSize: WidgetStatePropertyAll(Size(double.infinity, 40)),
        ),
        onPressed: null,
        child: const Text('x'),
      ),
    );
    expect(out, contains('height: 40px'));
    expect(out, isNot(contains('width: 100%')));
  });

  test('IconButton takes fixedSize from styleFrom', () async {
    final out = await css(
      IconButton(
        style: IconButton.styleFrom(fixedSize: const Size(44, 44)),
        onPressed: null,
        icon: const Icon(Icons.close),
      ),
    );
    expect(out, contains('width: 44px'));
    expect(out, contains('height: 44px'));
  });
}
