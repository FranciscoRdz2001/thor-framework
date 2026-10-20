@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/src/foundation/element.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

/// Returns a wrapper's pending data right around a thor element (no
/// component between them).
class _Direct extends StatelessWidget implements ThorElementWidget {
  const _Direct();

  @override
  Widget build(BuildContext context) => ChildRulesScope(
    rules: ChildRulesScope.maybeOf(context)?.rules,
    pending: const WrapData(attributes: {'data-x': 'direct'}),
    child: thorElement('div', attributes: const {'data-own': ''}),
  );
}

void main() {
  initializeThorTests();

  test('a scope right around a thor element passes it its pending data', () {
    return renderHtml(const _Direct()).then((html) {
      expect(html, contains('data-x="direct"'));
      expect(RegExp('<div').allMatches(html), hasLength(1));
    });
  });
}
