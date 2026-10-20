@TestOn('vm')
library;

// A panel that slides takes its dimmed backdrop with it: transparent at
// rest, dimmed while open, fading from transparent on open (starting
// style) and back on close, and kept in the top layer until the fade ends.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _css(Widget child) async {
  final page = await renderDocument(ThorApp(child: child));
  return RegExp(
    r'<style id="thor-styles">(.*?)</style>',
    dotAll: true,
  ).firstMatch(page)![1]!;
}

void _expectFading(String css) {
  expect(
    RegExp(
      r'::backdrop\{background-color: rgba\(0, 0, 0, 0\); transition: '
      r'background-color 250ms, overlay 250ms allow-discrete, '
      r'display 250ms allow-discrete\}',
    ).hasMatch(css),
    isTrue,
    reason: css,
  );
  expect(
    css,
    contains('[open]::backdrop{background-color: rgba(0, 0, 0, 0.32)}'),
  );
  expect(
    RegExp(
      r'@starting-style\{\.\w+\[open\]::backdrop\{'
      r'background-color: rgba\(0, 0, 0, 0\)\}\}',
    ).hasMatch(css),
    isTrue,
    reason: css,
  );
  // Never a backdrop that is always dimmed (it would stay dark on close).
  expect(
    RegExp(
      r'\w::backdrop\{background-color: rgba\(0, 0, 0, 0\.32\)',
    ).hasMatch(css),
    isFalse,
  );
}

void main() {
  setUpAll(initializeThorTests);

  test('a Drawer fades its backdrop in and out', () async {
    _expectFading(await _css(const Drawer(id: 'nav', child: Text('x'))));
  });

  test('a ModalBottomSheet does too', () async {
    _expectFading(
      await _css(const ModalBottomSheet(id: 'sheet', child: Text('x'))),
    );
  });

  test('the panel itself keeps its display/overlay transition (the '
      'backdrop stays in the top layer only through it)', () async {
    final css = await _css(const Drawer(id: 'nav', child: Text('x')));
    expect(css, contains('transition-property: translate, display, overlay'));
    expect(css, contains('transition-behavior: allow-discrete'));
  });
}
