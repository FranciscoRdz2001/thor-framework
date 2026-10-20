@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void _noop() {}

void main() {
  setUpAll(initializeThorTests);

  Future<String> shaped(OutlinedBorder s) => renderHtml(
    TextButton(
      onPressed: _noop,
      style: TextButton.styleFrom(shape: s),
      child: const Text('x'),
    ),
  );

  cardShapeTests();
  group('ShapeBorder', () {
    test('CircleBorder and OvalBorder are border-radius 50%', () async {
      expect(
        await shaped(const CircleBorder()),
        contains('border-radius: 50%'),
      );
      expect(await shaped(const OvalBorder()), contains('border-radius: 50%'));
    });

    test('OvalBorder is a CircleBorder with eccentricity 1', () {
      expect(const OvalBorder().eccentricity, 1);
      expect(const CircleBorder().eccentricity, 0);
      expect(const OvalBorder(), isA<CircleBorder>());
    });

    test('ContinuousRectangleBorder rounds like a rectangle', () async {
      expect(
        await shaped(
          const ContinuousRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        contains('border-radius: 12px'),
      );
    });

    test('the side of the shape is the outline', () async {
      final html = await shaped(
        const CircleBorder(side: BorderSide(color: Color(0xff303030))),
      );
      expect(html, contains('border: 1px solid #303030'));
    });

    test('an eccentricity out of 0..1 is rejected', () {
      expect(
        () => CircleBorder(eccentricity: 2),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}

void cardShapeTests() {
  group('Card.shape', () {
    test('CircleBorder with a side', () async {
      final html = await renderHtml(
        const Card(
          shape: CircleBorder(side: BorderSide(width: 3)),
          child: SizedBox(width: 40, height: 40),
        ),
      );
      expect(html, contains('border-radius: 50%'));
      expect(html, contains('border: 3px solid'));
    });

    test('default keeps 12px corners', () async {
      expect(
        await renderHtml(const Card(child: SizedBox(width: 4, height: 4))),
        contains('border-radius: 12px'),
      );
    });
  });
}
