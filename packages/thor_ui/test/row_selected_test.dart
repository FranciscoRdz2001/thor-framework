@TestOn('vm')
library;

// `row.selected` (a row's state follows whether its key is the value of a
// field), `row.length` (CSS custom properties per row) and the boolean
// attributes `row.attribute` can bind (`disabled`, `readonly`, `hidden`).
import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart'
    show isBindableAttribute, safeAttributeValue;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class Dot {
  const Dot(this.id, this.x, this.on);
  final int id;
  final double x;
  final bool on;
}

// The member list thor generates for [DotsState], by hand.
abstract class _DotsMembers extends ThorState {
  @override
  String get $type => 'DotsState';

  @override
  List<ThorMember> get $members {
    final s = this as DotsState;
    return [
      ThorMember.state('dots', s.dots),
      ThorMember.state('selected', s.selected),
      ThorMember(
        'dotKey',
        s.dotKey,
        arity: 1,
        callWithItem: (i) => s.dotKey(i as Dot),
      ),
      ThorMember(
        'left',
        s.left,
        arity: 1,
        callWithItem: (i) => s.left(i as Dot),
      ),
      ThorMember(
        'isOff',
        s.isOff,
        arity: 1,
        callWithItem: (i) => s.isOff(i as Dot),
      ),
    ];
  }
}

class DotsState extends _DotsMembers {
  final dots = state<List<Dot>>(const [Dot(1, 10, true), Dot(2, 12.5, false)]);
  final selected = state<int>(2);

  int dotKey(Dot d) => d.id;
  double left(Dot d) => d.x;
  bool isOff(Dot d) => !d.on;
}

final dotsState = DotsState();

Future<String> rows(Widget Function(WatchRow<Dot, int> row) each) => renderHtml(
  Watch.list(dotsState.dots.call, itemKey: dotsState.dotKey, each: each),
);

// A row component: `row.length` runs in `build`, after the row is fixed.
class _Row extends StatelessWidget {
  const _Row(this.row);
  final WatchRow<Dot, int> row;
  @override
  Widget build(BuildContext context) =>
      SizedBox(widthLength: row.length(dotsState.left));
}

void main() {
  initializeThorTests();

  group('row.selected', () {
    Widget on(WatchRow<Dot, int> row) => row.selected(
      dotsState.selected,
      builder: (selected) => Text(selected ? 'on' : 'off'),
    );

    test('only the row whose key is the field value is in state 1', () async {
      final html = await rows(on);
      final first = html.substring(html.indexOf('data-tk="1"'));
      final second = html.substring(html.indexOf('data-tk="2"'));
      expect(first, contains('data-tvf="DotsState.selected" data-tvi="0"'));
      expect(second, contains('data-tvf="DotsState.selected" data-tvi="1"'));
      expect(first, contains('data-tvs'));
    });

    test('the template carries the other state as a patch, the mark on '
        'both', () async {
      final html = await rows(on);
      final template = html.substring(html.indexOf('<template data-tlt='));
      expect(template, isNot(contains('data-tvft')));
      expect(template, contains('data-tvf="DotsState.selected"'));
      expect(template, contains('data-tvs'));
      expect(template, contains('data-tp-1="|#|=on"'));
    });
  });

  group('row.length', () {
    Widget dot(WatchRow<Dot, int> row) {
      final x = row.length(dotsState.left);
      return Styled(
        classes: const ['dot'],
        style: StyleProps(minWidth: x),
        child: const SizedBox(),
      );
    }

    test(
      'writes the first value in px and binds the property per row',
      () async {
        final html = await rows(dot);
        expect(html, contains('--tr-DotsState-left: 10px'));
        expect(html, contains('--tr-DotsState-left: 12.5px'));
        expect(html, contains('data-tfa="--tr-DotsState-left:DotsState.left"'));
        // The template has no item: 0px, and the same binding.
        final template = html.substring(html.indexOf('<template data-tlt='));
        expect(template, contains('--tr-DotsState-left: 0px'));
        expect(
          template,
          contains('data-tfa="--tr-DotsState-left:DotsState.left"'),
        );
      },
    );

    test('Positioned and SizedBox lengths bind with no wrapper', () async {
      final html = await rows((row) {
        final x = row.length(dotsState.left);
        return Stack(
          children: [
            Positioned(leftLength: x, child: const SizedBox()),
            SizedBox(widthLength: x),
          ],
        );
      });
      expect(html, contains('data-tfa="--tr-DotsState-left:DotsState.left"'));
      expect(html, contains('--tr-DotsState-left: 10px'));
      expect(html, contains('--tr-DotsState-left: 12.5px'));
    });

    void expectBoundPerRow(String html) {
      expect(html, contains('data-tfa="--tr-DotsState-left:DotsState.left'));
      expect(html, contains('--tr-DotsState-left: 10px'));
      expect(html, contains('--tr-DotsState-left: 12.5px'));
      final template = html.substring(html.indexOf('<template data-tlt='));
      expect(template, contains('--tr-DotsState-left: 0px'));
    }

    test('works in the build of a row component', () async {
      expectBoundPerRow(await rows(_Row.new));
    });

    test('works in a Builder inside the row', () async {
      expectBoundPerRow(
        await rows(
          (row) => Builder(
            builder: (_) => SizedBox(widthLength: row.length(dotsState.left)),
          ),
        ),
      );
    });

    test('works in a row component under row.attribute', () async {
      final html = await rows(
        (row) => row.attribute(
          AttributeName.hidden,
          dotsState.isOff,
          child: _Row(row),
        ),
      );
      expectBoundPerRow(html);
      expect(html, contains('hidden'));
    });

    test('without a style registry the element gets one style', () async {
      final html = await renderHtml(
        Watch.list(
          dotsState.dots.call,
          itemKey: dotsState.dotKey,
          each: (row) => SizedBox(
            height: 3,
            child: Styled(
              style: StyleProps(minWidth: row.length(dotsState.left)),
              child: const SizedBox(),
            ),
          ),
        ),
      );
      for (final tag in RegExp('<[^>]+>').allMatches(html)) {
        expect(RegExp(r'\sstyle=').allMatches(tag[0]!).length, lessThan(2));
      }
    });

    test('a RowLength outside its row fails loudly', () async {
      late RowLength escaped;
      await rows((row) => Text('${escaped = row.length(dotsState.left)}'));
      await expectLater(
        renderHtml(SizedBox(widthLength: escaped)),
        throwsA(predicate((e) => '$e'.contains('THOR-S042'))),
      );
    });

    test('an outer row\'s length read inside a nested row fails', () async {
      await expectLater(
        rows(
          (outer) => Watch.list(
            dotsState.dots.call,
            itemKey: dotsState.dotKey,
            each: (inner) =>
                SizedBox(widthLength: outer.length(dotsState.left)),
          ),
        ),
        throwsA(predicate((e) => '$e'.contains('THOR-S042'))),
      );
    });

    test('merges with row.attribute on the same element', () async {
      final html = await rows(
        (row) => row.attribute(
          AttributeName.hidden,
          dotsState.isOff,
          child: dot(row),
        ),
      );
      expect(html, contains('hidden:DotsState.isOff'));
      expect(html, contains('--tr-DotsState-left:DotsState.left'));
      // The server drew the first values: row 1 is on, row 2 is hidden.
      final second = html.substring(html.indexOf('data-tk="2"'));
      expect(second, contains('hidden'));
    });
  });

  group('list attribute', () {
    test('list (the id of a <datalist>) is bindable, with an id value', () {
      expect(isBindableAttribute('list'), isTrue);
      expect(safeAttributeValue('list', 'colors'), 'colors');
    });
  });

  group('boolean attributes', () {
    test('disabled, readonly, hidden, checked and autofocus are bindable', () {
      for (final name in [
        'disabled',
        'readonly',
        'hidden',
        'checked',
        'autofocus',
      ]) {
        expect(isBindableAttribute(name), isTrue, reason: name);
      }
      // Still left out: what changes what an element is, and handlers.
      for (final name in ['type', 'onclick', 'style', 'class', 'is']) {
        expect(isBindableAttribute(name), isFalse, reason: name);
      }
    });

    test('true is present (empty), anything else removes it', () {
      expect(safeAttributeValue('disabled', 'true'), '');
      expect(safeAttributeValue('disabled', 'false'), isNull);
      expect(safeAttributeValue('hidden', ''), isNull);
      expect(safeAttributeValue('readonly', 'yes'), isNull);
      expect(safeAttributeValue('value', 'false'), 'false');
    });
  });
}
