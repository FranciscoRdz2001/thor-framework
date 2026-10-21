@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  setUpAll(() => initializeThorTests(compactHtml: false));

  test('DialogTrigger(dialog:) takes a dialog wrapped in Styled', () async {
    final html = await renderDocument(
      ThorApp(
        child: DialogTrigger(
          dialog: ElementAttributes(
            HtmlAttributes(data: {'panel': 'filters'}),
            child: Styled(
              style: StyleProps(maxWidth: 400.px),
              child: const Drawer(child: Text('Filters')),
            ),
          ),
          child: const TextButton(child: Text('Open')),
        ),
      ),
    );
    final trigger = RegExp(
      r'<button[^>]*commandfor="([^"]+)"',
    ).firstMatch(html);
    expect(trigger, isNotNull, reason: html);
    final id = trigger!.group(1)!;
    final dialog = RegExp('<dialog[^>]*id="$id"[^>]*>').firstMatch(html);
    expect(dialog, isNotNull, reason: html);
    expect(dialog!.group(0), contains('data-panel="filters"'));
    expect(html, contains('max-width: 400px'));
  });
}
