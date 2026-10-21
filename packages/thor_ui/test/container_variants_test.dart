@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

String _styles(String doc) =>
    RegExp(r'<style id="thor-styles">(.*?)</style>').firstMatch(doc)![1]!;

void main() {
  setUpAll(initializeThorTests);

  Future<String> page(Widget child) => renderDocument(ThorApp(child: child));

  test('Container.transform changes per state and breakpoint', () async {
    final css = _styles(
      await page(
        Container(
          transform: Matrix4.identity().when(
            hover: Matrix4.translationValues(0, -2, 0),
            medium: Matrix4.diagonal3Values(2, 2, 1),
          ),
          child: const Text('a'),
        ),
      ),
    );
    expect(css, contains('transform: none'));
    expect(css, contains(':hover{transform: matrix(1, 0, 0, 1, 0, -2)}'));
    expect(css, contains('min-width: 600px'));
    expect(css, contains('transform: matrix(2, 0, 0, 2, 0, 0)'));
  });

  test('ConstrainedBox constraints change per state and breakpoint', () async {
    final css = _styles(
      await page(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300).when(
            medium: const BoxConstraints(maxWidth: 600),
            hover: const BoxConstraints(maxWidth: 700),
          ),
          child: const Text('a'),
        ),
      ),
    );
    expect(css, contains('max-width: 300px'));
    expect(css, contains('max-width: 600px'));
    expect(css, contains(':hover{max-width: 700px}'));
  });

  test('a Styled around a Container is still one element', () async {
    final html = await renderHtml(
      Styled(
        style: StyleProps(position: BoxPosition.sticky(top: 0.px)),
        child: const Container(child: Text('a')),
      ),
    );
    expect(RegExp('<div[ >]').allMatches(html).length, 1);
  });

  test(
    'a LayeredGradient stacks a glow and a dot pattern in one box',
    () async {
      final css = _styles(
        await page(
          const Container(
            decoration: BoxDecoration(
              gradient: LayeredGradient([
                RadialGradient(colors: [Color(0xFF112233), Color(0x00112233)]),
                RadialGradient(
                  colors: [Color(0xFF000000), Color(0x00000000)],
                  tile: Size(16, 16),
                ),
              ]),
            ),
            child: Text('a'),
          ),
        ),
      );
      expect(css, contains('background-image: radial-gradient('));
      expect(RegExp('radial-gradient').allMatches(css).length, 2);
      expect(css, contains('background-size: auto, 16px 16px'));
    },
  );
}
