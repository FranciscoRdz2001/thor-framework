@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  initializeThorTests();

  test('NoScript hides its child element when scripting is on', () async {
    const view = NoScript(
      child: FilledButton(buttonType: ButtonType.submit, child: Text('View')),
    );
    final html = await renderHtml(view);
    final page = await renderDocument(const ThorApp(child: view));
    // One element: the button itself carries the rule; no wrapper, no
    // <noscript>.
    expect(RegExp('<button').allMatches(html), hasLength(1));
    expect(page, isNot(contains('<noscript')));
    expect(
      RegExp(
        r'@media \(scripting: ?enabled\)\{[^}]*\{display: none\}',
      ).hasMatch(page),
      isTrue,
      reason: page,
    );
  });
}
