@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  setUpAll(() => initializeThorTests(compactHtml: false));

  test('a chevron of your own turns with .when(open:)', () async {
    final html = await renderDocument(
      ThorApp(
        child: ExpansionTile(
          showTrailingIcon: false,
          title: Row(
            children: [
              const Text('Hours'),
              Styled(
                style: const StyleProps(
                  turns: 0,
                ).when(open: const StyleProps(turns: 0.5)),
                child: const Icon(Icons.expand_more),
              ),
            ],
          ),
          children: const [Text('Mon 9-5')],
        ),
      ),
    );
    final start = html.indexOf('id="thor-styles">');
    final css = html.substring(start, html.indexOf('</style>', start));
    expect(css, contains('rotate: 0turn'));
    expect(css, contains('@scope (details[open]) to (:scope details)'));
    expect(css, contains('rotate: 0.5turn'));
  });
}
