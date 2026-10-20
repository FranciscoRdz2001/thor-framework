@TestOn('vm')
library;

// Badge and Badge.count with Flutter's parameters.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _body(Widget w) async {
  final html = await renderDocument(ThorApp(child: w));
  return html.substring(html.indexOf('<body'));
}

Future<String> _doc(Widget w) => renderDocument(ThorApp(child: w));

const _icon = Icon(IconData.svg('x', '<path d="M0 0"/>'));

void main() {
  setUpAll(initializeThorTests);

  test('Badge.count writes the number, capped by maxCount', () async {
    expect(
      await _body(Badge.count(count: 7, child: _icon)),
      contains('>7</span>'),
    );
    expect(
      await _body(Badge.count(count: 1000, child: _icon)),
      contains('>999+</span>'),
    );
    expect(
      await _body(Badge.count(count: 100, maxCount: 99, child: _icon)),
      contains('>99+</span>'),
    );
    expect(
      await _body(Badge.count(count: 99, maxCount: 99, child: _icon)),
      contains('>99</span>'),
    );
    expect(() => Badge.count(count: -1), throwsA(isA<AssertionError>()));
  });

  test('colors, sizes and text style land in the label', () async {
    final html = await _doc(
      const Badge(
        backgroundColor: Color(0xFF112233),
        textColor: Color(0xFFAABBCC),
        largeSize: 20,
        textStyle: TextStyle(fontSize: 12),
        padding: EdgeInsets.symmetric(horizontal: 6),
        label: Text('9'),
        child: _icon,
      ),
    );
    expect(html, contains('background-color: #112233'));
    expect(html, contains('color: #aabbcc'));
    expect(html, contains('min-width: 20px'));
    expect(html, contains('min-height: 20px'));
    expect(html, contains('font-size: 12px'));
    expect(html, contains('padding: 0px 6px'));
  });

  test('smallSize sizes the dot', () async {
    final html = await _doc(const Badge(smallSize: 10, child: _icon));
    expect(html, contains('width: 10px'));
    expect(html, contains('height: 10px'));
    expect(html, isNot(contains('min-width: 16px')));
  });

  test('alignment and offset place the label', () async {
    final top = await _doc(const Badge(label: Text('1'), child: _icon));
    // Default: top end, 4px out, centered on the line 4px under the top.
    expect(top, contains('top: 4px'));
    expect(top, contains('inset-inline-start: calc(100% - 16px)'));
    expect(top, contains('translate: 4px -50%'));
    expect(top, contains(':dir(rtl)'));

    final bottomLeft = await _doc(
      const Badge(
        label: Text('1'),
        alignment: Alignment.bottomLeft,
        offset: Offset(-2, 3),
        child: _icon,
      ),
    );
    expect(bottomLeft, contains('left: 0'));
    expect(bottomLeft, contains('top: calc(100% + 11px)'));
    expect(bottomLeft, contains('translate: -2px -50%'));

    final center = await _doc(
      const Badge(label: Text('1'), alignment: Alignment.center, child: _icon),
    );
    expect(center, contains('left: calc((100% - 16px) * 0.5)'));
  });

  test('a dot sits on the corner, without the label offset', () async {
    final html = await _doc(const Badge(child: _icon));
    expect(html, contains('top: 0'));
    expect(html, contains('inset-inline-start: calc(100% - 6px)'));
    expect(html, isNot(contains('translate:')));
  });

  test(
    'isLabelVisible: false keeps only the child; no child, only the badge',
    () async {
      final hidden = await _body(
        const Badge(label: Text('3'), isLabelVisible: false, child: _icon),
      );
      expect(hidden, isNot(contains('>3<')));
      final alone = await _body(Badge.count(count: 2));
      expect(alone, contains('>2</span>'));
      // No child: the badge is the element, not a corner of something.
      expect(alone, isNot(contains('position: absolute')));
      expect('data-thor="Badge"'.allMatches(alone).length, 1);
    },
  );
}
