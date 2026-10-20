// Flutter's GestureDetector, InkWell and InkResponse over `Gesture`.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// The member list thor generates for [_Board], by hand.
abstract class _BoardMembers extends ThorState {
  @override
  String get $type => 'Board';

  @override
  List<ThorMember> get $members {
    final s = this as _Board;
    return [
      ThorMember('open', s.open, call: (_) => s.open()),
      ThorMember('like', s.like, call: (_) => s.like()),
      ThorMember('hold', s.hold, call: (_) => s.hold()),
      ThorMember(
        'moved',
        s.moved,
        arity: 2,
        call: (a) {
          final x = splitArgs(a, 2);
          return s.moved(double.parse(x[0]), double.parse(x[1]));
        },
      ),
      ThorMember(
        'panned',
        s.panned,
        arity: 1,
        call: (a) => s.panned(DragUpdateDetails.fromArg(a)),
      ),
      ThorMember(
        'released',
        s.released,
        arity: 1,
        call: (a) => s.released(DragEndDetails.fromArg(a)),
      ),
      ThorMember(
        'swiped',
        s.swiped,
        arity: 1,
        call: (a) => s.swiped(SwipeDirection.values.byName(a!)),
      ),
      ThorMember(
        'zoomed',
        s.zoomed,
        arity: 1,
        call: (a) => s.zoomed(double.parse(a!)),
      ),
    ];
  }
}

class _Board extends _BoardMembers {
  void open() {}
  void like() {}
  void hold() {}
  void moved(double dx, double dy) {}
  void panned(DragUpdateDetails details) {}
  void released(DragEndDetails details) {}
  void swiped(SwipeDirection d) {}
  void zoomed(double scale) {}
}

final _board = _Board();

class _Wrapped extends StatelessWidget {
  const _Wrapped();
  @override
  Widget build(BuildContext context) =>
      const TextButton(onPressed: null, child: Text('x'));
}

const _box = SizedBox(width: 10, height: 10);
const _card = Container(width: 100, child: Text('card'));

/// [w] as markup, without its stylesheets.
Future<String> _html(Widget w) async =>
    (await renderHtml(w)).replaceAll(RegExp(r'<style>[\s\S]*?</style>'), '');

Future<String> _css(Widget w) async => RegExp(r'<style[^>]*>([\s\S]*?)</style>')
    .allMatches(await renderDocument(ThorApp(child: w)))
    .map((m) => m[1])
    .join()
    .replaceAll(' ', '');

/// The message of the error [w] throws while it renders.
Future<String> _error(Widget w) async {
  try {
    await renderHtml(w);
  } on Object catch (e) {
    return e.toString();
  }
  fail('it rendered');
}

int _count(String html, String needle) => needle.allMatches(html).length;

void main() {
  setUpAll(initializeThorTests);

  group('GestureDetector', () {
    test('onTap, onDoubleTap and onLongPress are Gesture\'s', () async {
      final detector = await _html(
        GestureDetector(
          onTap: _board.open,
          onDoubleTap: _board.like,
          onLongPress: _board.hold,
          child: _box,
        ),
      );
      final gesture = await _html(
        Gesture(
          onTap: _board.open,
          onDoubleTap: _board.like,
          onLongPress: _board.hold,
          child: _box,
        ),
      );
      expect(detector, gesture);
      expect(detector, contains('data-t-on="click:Board.open"'));
      expect(detector, contains('dtap:Board.like'));
      expect(detector, contains('long:Board.hold'));
    });

    test('onPanUpdate and onPanEnd are the drag', () async {
      final detector = await _html(
        GestureDetector(
          onPanUpdate: _board.panned,
          onPanEnd: _board.released,
          child: _box,
        ),
      );
      final gesture = await _html(
        Gesture(
          onDragUpdate: _board.moved,
          onDragEnd: _board.moved,
          child: _box,
        ),
      );
      // The same element and attributes but for the methods that take the
      // details, and the drag's marker that asks for `DragEndDetails`.
      expect(
        detector
            .replaceAll('Board.panned', 'Board.moved')
            .replaceAll('Board.released', 'Board.moved')
            .replaceAll('|10|1"', '|10"'),
        gesture,
      );
      expect(detector, contains('dragu:Board.panned'));
      expect(detector, contains('drag:Board.released'));
      expect(detector, contains(RegExp(r'data-tg-drag="f\|1\|[\d.]+\|1"')));
    });

    test('the details are built from what the browser reports', () {
      final down = TapDownDetails.fromArg('3.5~4');
      expect(down.localPosition.dx, 3.5);
      expect(down.localPosition.dy, 4);
      expect(TapUpDetails.fromArg('7~8').localPosition.dy, 8);
      final end = DragEndDetails.fromArg('120.5~-30~4~5~104~205');
      expect(end.velocity.pixelsPerSecond, const Offset(120.5, -30));
      expect(end.localPosition, const Offset(4, 5));
      expect(end.globalPosition, const Offset(104, 205));
      expect(end.primaryVelocity, isNull);
      final pan = DragUpdateDetails.fromArg('-1~2');
      expect(pan.delta.dx, -1);
      expect(pan.delta.dy, 2);
    });

    test('onHorizontalDragEnd and onVerticalDragEnd are the swipe', () async {
      final h = await _html(
        GestureDetector(onHorizontalDragEnd: _board.swiped, child: _box),
      );
      expect(h, contains('swipe:Board.swiped'));
      expect(h, contains('data-tg-swipe="h|0|0.4"'));
      final v = await _html(
        GestureDetector(onVerticalDragEnd: _board.swiped, child: _box),
      );
      expect(v, contains('data-tg-swipe="v|0|0.4"'));
    });

    test('onScaleEnd is the pinch', () async {
      final detector = await _html(
        GestureDetector(onScaleEnd: _board.zoomed, child: _box),
      );
      final gesture = await _html(
        Gesture(onScaleEnd: _board.zoomed, child: _box),
      );
      expect(detector, gesture);
    });

    test('behavior is accepted; excludeFromSemantics drops the role', () async {
      final html = await _html(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _board.open,
          child: _box,
        ),
      );
      expect(html, contains('role="button"'));
      final excluded = await _html(
        GestureDetector(
          excludeFromSemantics: true,
          onTap: _board.open,
          child: _box,
        ),
      );
      expect(excluded, isNot(contains('role="button"')));
      expect(excluded, contains('data-t-on="click:Board.open"'));
    });

    test('an unsupported callback is an error that lists what works', () async {
      final message = await _error(
        // ignore: deprecated_member_use_from_same_package
        GestureDetector(onTapCancel: (_) {}, onTap: _board.open, child: _box),
      );
      expect(message, contains('onTapCancel'));
      expect(message, contains('THOR-R040'));
      // The alternatives, by name.
      for (final name in ['onTap', 'onLongPress', 'onPanUpdate', 'Press']) {
        expect(message, contains(name), reason: name);
      }
    });

    test('every unsupported callback is named, not just the first', () async {
      final message = await _error(
        GestureDetector(
          // ignore: deprecated_member_use_from_same_package
          onDoubleTapDown: (_) {},
          // ignore: deprecated_member_use_from_same_package
          onPanStart: (_) {},
          // ignore: deprecated_member_use_from_same_package
          onScaleUpdate: (_) {},
          child: _box,
        ),
      );
      expect(message, contains('onDoubleTapDown'));
      expect(message, contains('onPanStart'));
      expect(message, contains('onScaleUpdate'));
    });

    test(
      'a horizontal and a vertical drag end together are one too many',
      () async {
        final message = await _error(
          GestureDetector(
            onHorizontalDragEnd: _board.swiped,
            onVerticalDragEnd: _board.swiped,
            child: _box,
          ),
        );
        expect(message, contains('THOR-R040'));
        expect(message, contains('onHorizontalDragEnd'));
        expect(message, contains('Gesture'));
      },
    );
  });

  group('a native control under a gesture', () {
    // The control keeps its own role and tab stop: no role=button or
    // tabindex=0 from the gesture over it.
    final controls = <String, Widget>{
      'ElevatedButton': const ElevatedButton(onPressed: null, child: Text('x')),
      'FloatingActionButton': const FloatingActionButton(
        onPressed: null,
        child: Text('x'),
      ),
      'ListBox': const ListBox<String>(
        items: [ListBoxItem(value: 'a', child: Text('a'))],
      ),
      'CheckboxListTile': const CheckboxListTile(
        value: false,
        title: Text('t'),
      ),
      'SwitchListTile': const SwitchListTile(value: false, title: Text('t')),
      'SegmentedButton': const SegmentedButton<String>(
        segments: [
          ButtonSegment(value: 'a', label: Text('a')),
          ButtonSegment(value: 'b', label: Text('b')),
        ],
        selected: {'a'},
      ),
    };
    for (final MapEntry(:key, :value) in controls.entries) {
      test(key, () async {
        final html = await _html(
          GestureDetector(onLongPress: _board.hold, child: value),
        );
        expect(html, contains('Board.hold'));
        expect(html, isNot(contains('role="button"')), reason: html);
        expect(html, isNot(contains('tabindex="0"')), reason: html);
      });
    }
  });

  group('InkWell', () {
    test('around text it is a native button with the tap', () async {
      final html = await _html(
        InkWell(onTap: _board.open, child: const Text('Open')),
      );
      expect(html, startsWith('<button'));
      expect(html, contains('type="button"'));
      expect(html, contains('data-t-on="click:Board.open"'));
      expect(html, isNot(contains('role="button"')));
      expect(html, isNot(contains('tabindex')));
      expect(html, contains('>Open<'));
    });

    test('around a box it is a role=button element, focusable', () async {
      final html = await _html(InkWell(onTap: _board.open, child: _card));
      expect(html, isNot(contains('<button')));
      expect(html, contains('role="button"'));
      expect(html, contains('tabindex="0"'));
      expect(_count(html, '<div'), 1);
    });

    test('hover, focus and pressed states are CSS of the same class', () async {
      final css = await _css(InkWell(onTap: _board.open, child: _card));
      expect(css, contains('cursor:pointer'));
      expect(css, matches(RegExp(r'@media\(hover:hover\)\{\.t\w+:hover\{')));
      expect(css, matches(RegExp(r'\.t\w+:focus-visible\{')));
      expect(css, matches(RegExp(r'\.t\w+:active\{')));
      expect(css, contains('linear-gradient('));
    });

    test('colors and shape', () async {
      final css = await _css(
        InkWell(
          onTap: _board.open,
          borderRadius: BorderRadius.circular(8),
          hoverColor: const Color(0xFF00FF00),
          focusColor: const Color(0xFF0000FF),
          splashColor: const Color(0xFFFF0000),
          child: _card,
        ),
      );
      expect(css, contains('border-radius:8px'));
      expect(css, contains('#00ff00'));
      expect(css, contains('#0000ff'));
      expect(css, contains('#ff0000'));
      final stadium = await _css(
        InkWell(
          onTap: _board.open,
          customBorder: const StadiumBorder(),
          child: _card,
        ),
      );
      expect(stadium, contains('border-radius:9999px'));
    });

    test('InkResponse is a circle unless it is contained', () async {
      final css = await _css(InkResponse(onTap: _board.open, child: _card));
      // The circle is the state layer; the element keeps its shape.
      expect(css, contains('radial-gradient(circleclosest-side'));
      expect(css, isNot(contains('border-radius')));
      final rect = await _css(
        InkResponse(
          onTap: _board.open,
          highlightShape: BoxShape.rectangle,
          child: _card,
        ),
      );
      expect(rect, isNot(contains('radial-gradient')));
      final contained = await _css(InkWell(onTap: _board.open, child: _card));
      expect(contained, isNot(contains('radial-gradient')));
      expect(contained, contains('linear-gradient'));
    });

    test(
      'without a callback it is inert: no cursor, no states, no role',
      () async {
        const w = InkWell(child: _card);
        final html = await _html(w);
        expect(html, isNot(contains('role=')));
        expect(html, isNot(contains('tabindex')));
        final css = await _css(w);
        expect(css, isNot(contains('cursor:pointer')));
        expect(css, isNot(contains(':hover')));
      },
    );

    test('excludeFromSemantics keeps the tap and drops the role', () async {
      final html = await _html(
        InkWell(excludeFromSemantics: true, onTap: _board.open, child: _card),
      );
      expect(html, isNot(contains('role="button"')));
      expect(html, isNot(contains('tabindex')));
      expect(html, contains('data-t-on="click:Board.open"'));
    });

    test('canRequestFocus: false is not in the tab order', () async {
      final html = await _html(
        InkWell(canRequestFocus: false, onTap: _board.open, child: _card),
      );
      expect(html, isNot(contains('tabindex="0"')));
    });

    test('double tap and long press go through Gesture', () async {
      final html = await _html(
        InkWell(
          onTap: _board.open,
          onDoubleTap: _board.like,
          onLongPress: _board.hold,
          child: _card,
        ),
      );
      expect(html, contains('dtap:Board.like'));
      expect(html, contains('long:Board.hold'));
    });

    test('around a button it adds no second button, no role', () async {
      final html = await _html(
        InkWell(
          onTap: _board.open,
          child: FilledButton(onPressed: _board.like, child: const Text('Go')),
        ),
      );
      expect(_count(html, '<button'), 1);
      expect(html, isNot(contains('role="button"')));
    });

    test('around a native control it keeps the control\'s own role', () async {
      for (final child in <Widget>[
        const Checkbox(value: true, onChanged: null),
        const Switch(value: true, onChanged: null),
        const Radio<int>(value: 1),
        const Slider(value: 1, onChanged: null),
        const _Wrapped(),
      ]) {
        final html = await _html(InkWell(onTap: _board.open, child: child));
        expect(html, isNot(contains('role="button"')), reason: '$child');
        expect(html, isNot(contains('tabindex')), reason: '$child');
        expect(html, contains('Board.open'), reason: '$child');
      }
    });

    test('a button inside is never a button in a button', () async {
      final html = await _html(
        InkWell(
          onTap: _board.open,
          child: Row(
            children: [
              const Text('Row'),
              IconButton(
                onPressed: _board.like,
                tooltip: 'Like',
                icon: const Icon(IconData.svg('x', '<path d="M0 0"/>')),
              ),
            ],
          ),
        ),
      );
      // The row is the InkWell's element (role=button); the IconButton keeps
      // its own <button>, which is not inside another <button>.
      expect(_count(html, '<button'), 1);
      expect(html, startsWith('<div'));
      expect(html, contains('role="button"'));
    });

    test(
      'an InkWell inside an InkWell is one button, not nested ones',
      () async {
        final html = await _html(
          InkWell(
            onTap: _board.open,
            child: InkWell(onTap: _board.like, child: const Text('x')),
          ),
        );
        expect(_count(html, '<button'), 1);
        expect(_count(html, '</button>'), 1);
      },
    );

    test(
      'a callback the web cannot do is an error with alternatives',
      () async {
        final message = await _error(
          // ignore: deprecated_member_use_from_same_package
          InkWell(onHover: (_) {}, onTap: _board.open, child: _card),
        );
        expect(message, contains('onHover'));
        expect(message, contains('THOR-R040'));
        expect(message, contains('hoverColor'));
      },
    );
  });
}
