@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _css(Widget child) async {
  final html = await renderDocument(ThorApp(child: child));
  final start = html.indexOf('id="thor-styles">');
  final style = html.substring(start, html.indexOf('</style>', start));
  return style.replaceAll(RegExp(r'\s+'), ' ');
}

void main() {
  setUpAll(() => initializeThorTests(compactHtml: false));

  test(
    'a padding chained with two .when() calls is one set of rules',
    () async {
      final css = await _css(
        Container(
          constraints: const BoxConstraints(maxWidth: 1280),
          padding:
              const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 64)
                  .when(
                    medium: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 24,
                      bottom: 64,
                    ),
                  )
                  .when(
                    large: const EdgeInsets.only(
                      left: 32,
                      right: 32,
                      top: 24,
                      bottom: 64,
                    ),
                  ),
        ),
      );
      expect(css, isNot(contains('⟦')));
      expect(css, isNot(contains('␟')));
      expect(css, isNot(contains('␞')));
      expect(css, contains('padding: 24px 16px 64px'));
      expect(css, contains('padding: 24px 24px 64px'));
      expect(css, contains('padding: 24px 32px 64px'));
    },
  );

  test('chained const-constructor variants merge too', () async {
    final css = await _css(
      Styled(
        style: const StyleProps(
          medium: StyleProps(opacity: 0.5),
        ).when(large: const StyleProps(opacity: 0.2)),
        child: const SizedBox(width: 10),
      ),
    );
    expect(css, isNot(contains('⟦')));
    expect(css, contains('opacity: 0.5'));
    expect(css, contains('opacity: 0.2'));
  });
}
