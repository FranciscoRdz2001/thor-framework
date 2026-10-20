// A '\n' inside the spans of Text.rich is a line break, as in Flutter.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _css(Widget w) async => RegExp(r'<style[^>]*>([\s\S]*?)</style>')
    .allMatches(await renderDocument(ThorApp(child: w)))
    .map((m) => m[1])
    .join()
    .replaceAll(' ', '');

void main() {
  setUpAll(initializeThorTests);

  test('a newline in a nested span makes the text pre-wrap', () async {
    final css = await _css(
      const Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Total\n',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: r'$120'),
          ],
        ),
      ),
    );
    expect(css, contains('white-space:pre-wrap'));
  });

  test('a newline in the root span too, and none means no pre-wrap', () async {
    expect(
      await _css(const Text.rich(TextSpan(text: 'a\nb'))),
      contains('white-space:pre-wrap'),
    );
    expect(
      await _css(
        const Text.rich(
          TextSpan(
            text: 'a',
            children: [TextSpan(text: 'b')],
          ),
        ),
      ),
      isNot(contains('white-space:pre-wrap')),
    );
  });
}
