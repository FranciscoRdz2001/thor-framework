@TestOn('vm')
library;

// A compact `Switch` is Flutter's idiom: `Transform.scale` over the fixed
// Material 3 size (52x32). The transform fuses into the switch's own element.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  setUpAll(initializeThorTests);

  test('Transform.scale fuses into the Switch element', () async {
    final html = await renderDocument(
      ThorApp(
        child: Transform.scale(
          scale: 40 / 52,
          child: const Switch(value: true),
        ),
      ),
    );
    final head = html.substring(0, html.indexOf('</head>'));
    expect(head, contains('transform: scale(0.7692)'));
    expect(head, contains('width: 52px'));
    // One element: the scaled switch is the `<input>` itself.
    expect('role="switch"'.allMatches(html), hasLength(1));
    expect(html, isNot(contains('<div style')));
  });
}
