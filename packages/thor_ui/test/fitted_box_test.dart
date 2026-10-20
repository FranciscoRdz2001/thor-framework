@TestOn('vm')
library;

// `FittedBox` in CSS only.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Widget w) => renderDocument(ThorApp(child: w));

String _head(String html) => html.substring(0, html.indexOf('</head>'));

void main() {
  setUpAll(initializeThorTests);

  group('FittedBox (54)', () {
    test('an image fills the box and object-fit scales it', () async {
      final head = _head(
        await _page(
          const SizedBox(
            width: 120,
            height: 80,
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: Image.network('/logo.png'),
            ),
          ),
        ),
      );
      expect(head, contains('object-fit: cover'));
      expect(head, contains('overflow: hidden'));
      expect(head, contains('object-position: 50% 50%'));
      expect(head, contains('width: 100%; height: 100%'));
    });

    test(
      'fitWidth fills the width at the alignment; no clip by default',
      () async {
        final head = _head(
          await _page(
            const FittedBox(
              fit: BoxFit.fitWidth,
              alignment: Alignment.bottomRight,
              child: Image.network('/logo.png'),
            ),
          ),
        );
        expect(head, contains('object-position: 100% 100%'));
        expect(head, contains('width: 100%; height: auto'));
        expect(head, contains('justify-content: flex-end'));
        expect(head, isNot(contains('overflow: hidden')));
      },
    );

    test('scaleDown only caps the child', () async {
      final head = _head(
        await _page(
          const FittedBox(fit: BoxFit.scaleDown, child: Text('Title')),
        ),
      );
      expect(head, contains('max-width: 100%'));
      expect(head, contains('object-fit: scale-down'));
    });
  });
}
