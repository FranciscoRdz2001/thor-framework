@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  setUpAll(() => initializeThorTests(compactHtml: false));

  const accent = CssVariable<Color>('--accent');
  const gap = CssVariable<Length>('--gap');

  Future<String> render(Widget child) => renderDocument(ThorApp(child: child));

  test('values land in the element class, once per distinct value', () async {
    final html = await render(
      Column(
        children: [
          ElementVariables({
            accent: const Color(0xFF3366FF),
            gap: 12.px,
          }, child: const Text('a')),
          ElementVariables({
            accent: const Color(0xFF3366FF),
            gap: 12.px,
          }, child: const Text('b')),
          ElementVariables({
            accent: const Color(0xFFFF0000),
            gap: 12.px,
          }, child: const Text('c')),
        ],
      ),
    );
    expect(html, contains('--accent: #3366ff'));
    expect(html, contains('--accent: #ff0000'));
    expect('--accent: #3366ff'.allMatches(html), hasLength(1));
    expect(html, contains('--gap: 12px'));
    expect(html, isNot(contains(' style="')));
  });

  test('a bad name or value is refused', () {
    expect(
      () => const ElementVariables({
        CssVariable<Color>('color: red'): Color(0xFF000000),
      }, child: Text('x')).wrapData,
      throwsArgumentError,
    );
    expect(
      () => const ElementVariables({
        accent: 'red; x: y',
      }, child: Text('x')).wrapData,
      throwsArgumentError,
    );
  });
}
