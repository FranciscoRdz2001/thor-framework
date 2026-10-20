// ignore_for_file: prefer_const_constructors
// The geometry family (EdgeInsetsGeometry, BorderRadiusGeometry,
// AlignmentGeometry) in the widgets that take it: the emitted CSS for
// directional, Length and mixed values, and the consumers that compute.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _css(Widget w) => renderDocument(w);

Matcher _throwsCode(String code) => throwsA(
  isA<StateError>().having((e) => e.message, 'message', contains(code)),
);

void main() {
  setUpAll(initializeThorTests);

  group('directional insets', () {
    test('Padding writes logical properties', () async {
      final css = await _css(
        Padding(
          padding: EdgeInsetsDirectional.only(start: 16, end: 4, top: 8),
          child: Text('a'),
        ),
      );
      expect(css, contains('padding-inline-start: 16px'));
      expect(css, contains('padding-inline-end: 4px'));
      expect(css, contains('padding-top: 8px'));
      expect(css, contains('padding-bottom: 0px'));
      expect(css, isNot(contains('padding: 8px')));
    });

    test('around a box with no margin it is that box\'s margin', () async {
      final css = await _css(
        Padding(
          padding: EdgeInsetsDirectional.only(start: 12),
          child: Container(color: Color(0xff112233), child: Text('a')),
        ),
      );
      expect(css, contains('margin-inline-start: 12px'));
      expect(css, contains('margin-inline-end: 0px'));
    });

    test('Container padding and margin', () async {
      final css = await _css(
        Container(
          padding: EdgeInsetsDirectional.only(start: 6),
          margin: EdgeInsetsDirectional.all(2),
          color: Color(0xff112233),
          child: Text('a'),
        ),
      );
      expect(css, contains('padding-inline-start: 6px'));
      expect(css, contains('margin-inline: 2px'));
      expect(css, contains('margin-block: 2px'));
    });

    test('ListView and Card', () async {
      final list = await _css(
        ListView(
          padding: EdgeInsetsDirectional.only(start: 10),
          children: const [Text('a')],
        ),
      );
      expect(list, contains('padding-inline-start: 10px'));
      final card = await _css(
        Card(margin: EdgeInsetsDirectional.only(end: 3), child: Text('a')),
      );
      expect(card, contains('margin-inline-end: 3px'));
    });

    test('a Padding with directional insets inside variants', () async {
      final css = await _css(
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: 8,
          ).when(medium: EdgeInsetsDirectional.only(start: 24)),
          child: Text('a'),
        ),
      );
      expect(css, contains('padding-inline-start: 8px'));
      expect(css, contains('padding-inline-start: 24px'));
    });
  });

  group('mixed and Length insets in widgets', () {
    test('a Length plus numbers is one calc()', () async {
      final css = await _css(
        Padding(
          padding: EdgeInsetsGeometry.allLength(
            Length.variable(CssVariable('--gap')),
          ).add(EdgeInsets.all(8)),
          child: Text('a'),
        ),
      );
      expect(css, contains('padding: calc(var(--gap) + 8px)'));
    });

    test('a physical and a directional horizontal side throw R037', () async {
      await expectLater(
        _css(
          Padding(
            padding: EdgeInsets.only(
              left: 4,
            ).add(EdgeInsetsDirectional.only(start: 4)),
            child: Text('a'),
          ),
        ),
        _throwsCode('THOR-R037'),
      );
    });

    test('SafeArea cannot add to directional insets (R037)', () async {
      await expectLater(
        renderHtml(
          SafeArea(
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: 4),
              child: Text('x'),
            ),
          ),
        ),
        _throwsCode('THOR-R037'),
      );
    });
  });

  group('consumers that compute', () {
    test('GridView.padding: numbers, directional and Length', () async {
      Widget grid(EdgeInsetsGeometry p) => GridView.extent(
        maxCrossAxisExtent: 100,
        padding: p,
        children: const [Text('a')],
      );
      await renderHtml(grid(EdgeInsets.symmetric(horizontal: 8)));
      await renderHtml(grid(EdgeInsetsDirectional.only(start: 8, end: 4)));
      await expectLater(
        renderHtml(
          grid(
            EdgeInsetsGeometry.allLength(Length.variable(CssVariable('--g'))),
          ),
        ),
        _throwsCode('THOR-R036'),
      );
    });
  });

  group('border radius', () {
    test('BoxDecoration with a directional radius', () async {
      final css = await _css(
        Container(
          decoration: BoxDecoration(
            color: Color(0xff112233),
            borderRadius: BorderRadiusDirectional.horizontal(
              start: Radius.circular(8),
            ),
          ),
          child: Text('a'),
        ),
      );
      expect(css, contains('border-start-start-radius: 8px'));
      expect(css, contains('border-end-start-radius: 8px'));
      expect(css, contains('border-start-end-radius: 0px'));
    });

    test('ClipRRect takes the geometry', () async {
      final css = await _css(
        ClipRRect(
          borderRadius: BorderRadiusDirectional.circular(6),
          child: Text('a'),
        ),
      );
      expect(css, contains('border-radius: 6px'));
    });

    test('DecorationTween keeps a pair of directional radii directional', () {
      final mid = DecorationTween(
        begin: BoxDecoration(
          borderRadius: BorderRadiusDirectional.only(topStart: Radius.zero),
        ),
        end: BoxDecoration(
          borderRadius: BorderRadiusDirectional.only(
            topStart: Radius.circular(20),
          ),
        ),
      ).transform(0.5);
      final r = mid.borderRadius! as BorderRadiusDirectional;
      expect(r.topStart.x, 10);
    });
  });

  group('alignment', () {
    test('Align with AlignmentDirectional', () async {
      final css = await _css(
        Align(alignment: AlignmentDirectional.centerStart, child: Text('a')),
      );
      expect(css, contains('margin-inline-start: 0'));
      expect(css, contains('margin-inline-end: auto'));
    });

    test('Container alignment and a fractional one (R037)', () async {
      final css = await _css(
        Container(
          alignment: AlignmentDirectional.bottomEnd,
          width: 100,
          height: 100,
          child: SizedBox(width: 10, height: 10),
        ),
      );
      expect(css, contains('justify-content: flex-end'));
      expect(css, contains('margin-inline-end: 0'));
      await expectLater(
        _css(Align(alignment: AlignmentDirectional(0.5, 0), child: Text('a'))),
        _throwsCode('THOR-R037'),
      );
    });

    test('Stack alignment', () async {
      final css = await _css(
        Stack(
          alignment: AlignmentDirectional.topEnd,
          children: const [SizedBox(width: 4, height: 4)],
        ),
      );
      expect(css, contains('place-items: start end'));
    });
  });
}
