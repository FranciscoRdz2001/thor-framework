@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _render(Widget w) => renderDocument(ThorApp(child: w));

void main() {
  setUpAll(initializeThorTests);

  test('a Ratio is written as text by a CSS counter', () async {
    final html = await _render(
      const RatioText(
        Ratio.min([Ratio.value(1), Ratio.of(Length.cqw(100), Length.px(844))]),
        suffix: '%',
      ),
    );
    // The browser computes the number; the page has no text node for it.
    expect(
      html,
      contains(
        'counter-reset: thor-ratio calc(min(1, tan(atan2(100cqw, 844px))) * 100)',
      ),
    );
    expect(html, contains('::before{content: counter(thor-ratio) "%"'));
    expect(html, isNot(contains('>66<')));
  });

  test('the scale and the digits are options', () async {
    final html = await _render(
      const RatioText(Ratio.value(0.5), scale: 1000, suffix: ' ms'),
    );
    expect(html, contains('calc(0.5 * 1000)'));
    expect(html, contains('counter(thor-ratio) " ms"'));
  });

  test('a style and a label go to the element', () async {
    final html = await _render(
      const RatioText(
        Ratio.value(1),
        style: TextStyle(fontSize: 12),
        semanticsLabel: 'Zoom',
      ),
    );
    expect(html, contains('font-size: 12px'));
    expect(html, contains('aria-label="Zoom"'));
  });
}
