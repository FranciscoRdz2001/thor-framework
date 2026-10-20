// DefaultTextStyle.merge (Flutter's): the same wrapper, style optional.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  setUpAll(initializeThorTests);

  test('merge adds its style to the child element', () async {
    final html = await renderDocument(
      const ThorApp(
        child: DefaultTextStyle.merge(
          style: TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          child: Text('x'),
        ),
      ),
    );
    final css = RegExp(
      r'<style[^>]*>([\s\S]*?)</style>',
    ).allMatches(html).map((m) => m[1]).join().replaceAll(' ', '');
    expect(css, contains('font-weight:700'));
    expect(css, contains('text-align:center'));
  });

  test('merge without a style only sets what it is given', () {
    const merged = DefaultTextStyle.merge(
      textAlign: TextAlign.end,
      child: Text('x'),
    );
    expect(merged.wrapData.css['text-align'], 'end');
    expect(merged.wrapData.css.containsKey('font-weight'), isFalse);
  });
}
