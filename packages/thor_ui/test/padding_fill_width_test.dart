@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  test(
    'Padding around a full-width Container is not folded into a margin',
    () async {
      final html = await renderDocument(
        const ThorApp(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Container(width: double.infinity, height: 50),
          ),
        ),
      );
      expect(html, contains('width: 100%'));
      expect(html, isNot(contains('margin: 16px')));
      expect(html, contains('padding: 16px'));
    },
  );

  test(
    'Padding around a full-height Container is not folded into a margin',
    () async {
      final html = await renderDocument(
        const ThorApp(
          child: SizedBox(
            height: 200,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Container(width: 40, height: double.infinity),
            ),
          ),
        ),
      );
      expect(html, contains('height: 100%'));
      expect(html, isNot(contains('margin: 16px')));
      expect(html, contains('padding: 16px'));
    },
  );

  test(
    'Padding around a fixed-size Container still folds into a margin',
    () async {
      final html = await renderDocument(
        const ThorApp(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Container(width: 40, height: 50),
          ),
        ),
      );
      expect(html, contains('margin: 16px'));
    },
  );
}
