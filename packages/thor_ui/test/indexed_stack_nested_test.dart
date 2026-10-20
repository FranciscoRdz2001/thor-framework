@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  test('the shown child of an IndexedStack inherits visibility', () async {
    final html = await renderDocument(
      const ThorApp(
        child: IndexedStack(
          index: 0,
          children: [
            IndexedStack(index: 0, children: [Text('A'), Text('B')]),
            Text('Feed'),
          ],
        ),
      ),
    );
    // `visible` would override the `hidden` the outer stack inherits.
    expect(html, isNot(contains('visibility: visible')));
    expect(html, contains('visibility: inherit'));
  });
}
