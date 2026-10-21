@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  setUpAll(() => initializeThorTests(compactHtml: false));

  test(
    'ExpandableText is a clamped text and a checkbox label, no JS',
    () async {
      final html = await renderDocument(
        const ThorApp(
          child: ExpandableText(
            'A long description',
            maxLines: 3,
            moreLabel: 'Read more',
            lessLabel: 'Show less',
          ),
        ),
      );
      expect(html, contains('A long description'));
      expect(html, contains('<label'));
      expect(html, contains('type="checkbox"'));
      expect(html, contains('Read more'));
      expect(html, contains('Show less'));
      expect(html, contains('-webkit-line-clamp: 3'));
      expect(html, contains(':has(> label > input:checked) > :first-child'));
      expect(html, isNot(contains('<script src')));
    },
  );
}
