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
      ThorMember('started', s.started, call: (_) => s.started()),
      ThorMember('done', s.done, call: (_) => s.done()),
      ThorMember(
        'canceled',
        s.canceled,
        arity: 2,
        call: (a) {
          final x = splitArgs(a, 2);
          return s.canceled(double.parse(x[0]), double.parse(x[1]));
        },
      ),
      ThorMember('ended', s.ended, arity: 1, call: (a) => s.ended(a == 'true')),
      ThorMember(
        'canDrop',
        s.canDrop,
        arity: 2,
        call: (a) {
          final x = splitArgs(a, 2);
          return s.canDrop(x[0], x[1]);
        },
      ),
      ThorMember(
        'dropped',
        s.dropped,
        arity: 2,
        call: (a) {
          final x = splitArgs(a, 2);
          return s.dropped(x[0], x[1]);
        },
      ),
      ThorMember(
        'left',
        s.left,
        arity: 2,
        call: (a) {
          final x = splitArgs(a, 2);
          return s.left(x[0], x[1]);
        },
      ),
      ThorMember(
        'moved',
        s.moved,
        arity: 3,
        call: (a) {
          final x = splitArgs(a, 3);
          return s.moved(x[0], double.parse(x[1]), double.parse(x[2]));
        },
      ),
      ThorMember(
        'dropNumber',
        s.dropNumber,
        arity: 1,
        call: (a) => s.dropNumber(int.parse(a!)),
      ),
    ];
  }
}

class _Board extends _BoardMembers {
  void started() {}
  void done() {}
  void canceled(double x, double y) {}
  void ended(bool accepted) {}
  bool canDrop(String column, String data) => true;
  void dropped(String column, String data) {}
  void left(String column, String data) {}
  void moved(String column, double x, double y) {}
  void dropNumber(int n) {}
}

abstract class _DndOnlyMembers extends ThorState {
  @override
  String get $type => 'DndOnly';

  @override
  List<ThorMember> get $members {
    final s = this as _DndOnly;
    return [
      ThorMember.state('n', s.n),
      ThorMember('picked', s.picked, call: (_) => s.picked()),
      ThorMember(
        'dropped',
        s.dropped,
        arity: 2,
        call: (a) {
          final x = splitArgs(a, 2);
          return s.dropped(x[0], x[1]);
        },
      ),
    ];
  }
}

// A state a page uses only through drag and drop.
class _DndOnly extends _DndOnlyMembers {
  final n = state(0);
  void picked() {}
  void dropped(String column, String data) {}
}

final _board = _Board();
final _dndOnly = _DndOnly();
const _chip = SizedBox(width: 40, height: 20);

Future<String> _page(Widget body) =>
    renderDocument(ThorApp(child: body)).then(headOfPage);

String _sheet(String page) =>
    RegExp(
      r'<style id="thor-styles">(.*?)</style>',
      dotAll: true,
    ).firstMatch(page)?[1] ??
    '';

void main() {
  initializeThorTests();

  test(
    'a Draggable marks its child: data, type, setup, state methods',
    () async {
      final html = await renderHtml(
        Draggable<String>(
          data: 'task-7',
          feedback: const Text('moving'),
          onDragStarted: _board.started,
          onDragCompleted: _board.done,
          child: _chip,
        ),
      );
      expect(html, contains('data-t-dg="start:Board.started;done:Board.done"'));
      expect(html, contains('data-t-dg-data="task-7"'));
      expect(html, contains('data-t-dg-type="String"'));
      expect(html, contains('data-t-dg-cfg="f|0|c|1|0|0"'));
      // The child's own element is the draggable: no wrapper box.
      expect(RegExp('<div').allMatches(html), hasLength(1));
      // Reachable and operable from the keyboard.
      expect(html, contains('tabindex="0"'));
      expect(html, contains('aria-roledescription="draggable"'));
      expect(html, contains('role="button"'));
    },
  );

  test('the feedback is a template inside the draggable\'s element', () async {
    final html = await renderHtml(
      const Draggable<String>(
        data: 'a',
        feedback: Text('moving'),
        child: Container(width: 40, height: 20),
      ),
    );
    expect(
      RegExp(
        r'<div[^>]*data-t-dg[ >][^>]*>.*<template data-t-dg-fb>.*moving.*</template></div>',
      ).hasMatch(html.replaceAll('\n', '')),
      isTrue,
      reason: html,
    );
    expect(html, contains('data-t-dg-ghost'));
  });

  test(
    'under a Tooltip the templates stay next to the marked element',
    () async {
      final html = await renderHtml(
        const Draggable<String>(
          data: 'a',
          feedback: Text('moving'),
          child: Tooltip(message: 'tip', child: Text('chip')),
        ),
      );
      // web: the engine looks for the templates inside the element with
      // `data-t-dg` or among its next siblings (the bubble sits between).
      expect(
        RegExp(
          r'data-t-dg[ >][^>]*>chip</span>(?:<style>.*?</style>)?'
          r'<span[^>]*role="tooltip">tip</span><template data-t-dg-fb>',
          dotAll: true,
        ).hasMatch(html),
        isTrue,
        reason: html,
      );
    },
  );

  test(
    'the feedback is fixed, follows the variables, ignores the pointer',
    () async {
      final page = await _page(
        const Draggable<String>(
          data: 'a',
          feedback: Container(width: 40, height: 20, color: Color(0xFF123456)),
          child: Container(width: 40, height: 20),
        ),
      );
      final css = _sheet(page);
      expect(css, contains('position: fixed'));
      expect(css, contains('translate: var(--t-dg-x, 0px) var(--t-dg-y, 0px)'));
      expect(css, contains('pointer-events: none'));
      expect(
        page,
        contains(
          "@property --t-dg-x{syntax:'<length>';inherits:false;initial-value:0px}",
        ),
      );
      expect(page, contains('@property --t-dg-y{'));
      // The draggable: not selectable, grabbable, scroll left to the page
      // only where the drag does not go.
      expect(css, contains('cursor: grab'));
      expect(css, contains('user-select: none'));
      expect(css, contains('touch-action: none'));
      expect(css, contains('[data-t-dg-active]'));
      // A page without one has none of it.
      expect(await _page(_chip), isNot(contains('--t-dg-x')));
    },
  );

  test('axis changes the touch-action and the setup', () async {
    final h = await renderHtml(
      const Draggable<String>(
        data: 'a',
        axis: Axis.horizontal,
        feedback: Text('x'),
        child: _chip,
      ),
    );
    expect(h, contains('data-t-dg-cfg="h|0|c|1|0|0"'));
    expect(h, contains('touch-action: pan-y'));
    final v = await renderHtml(
      const Draggable<String>(
        data: 'a',
        axis: Axis.vertical,
        feedback: Text('x'),
        child: _chip,
      ),
    );
    expect(v, contains('data-t-dg-cfg="v|0|c|1|0|0"'));
    expect(v, contains('touch-action: pan-x'));
  });

  test(
    'a LongPressDraggable waits for a hold and leaves the scroll alone',
    () async {
      final html = await renderHtml(
        const LongPressDraggable<String>(
          data: 'a',
          feedback: Text('x'),
          child: _chip,
        ),
      );
      expect(html, contains('data-t-dg-cfg="f|500|c|1|0|0"'));
      expect(html, contains('touch-action: manipulation'));
      final quick = await renderHtml(
        const LongPressDraggable<String>(
          data: 'a',
          delay: Duration(milliseconds: 150),
          feedback: Text('x'),
          child: _chip,
        ),
      );
      expect(quick, contains('data-t-dg-cfg="f|150|c|1|0|0"'));
    },
  );

  test('anchor, offset and the number of drags', () async {
    final html = await renderHtml(
      const Draggable<String>(
        data: 'a',
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedbackOffset: Offset(4, -8),
        feedback: Text('x'),
        child: _chip,
      ),
    );
    expect(html, contains('data-t-dg-cfg="f|0|p|1|4|-8"'));
    // Turned off: still its child, nothing to drag.
    final off = await renderHtml(
      const Draggable<String>(
        data: 'a',
        maxSimultaneousDrags: 0,
        feedback: Text('x'),
        child: _chip,
      ),
    );
    expect(off, isNot(contains('data-t-dg')));
    expect(off, isNot(contains('tabindex')));
    // A strategy of its own has nothing to run in the browser.
    expect(
      () => renderHtml(
        Draggable<String>(
          data: 'a',
          dragAnchorStrategy: (draggable, context, position) => Offset.zero,
          feedback: const Text('x'),
          child: _chip,
        ),
      ),
      throwsA(predicate((e) => '$e'.contains('THOR-R040'))),
    );
  });

  test('childWhenDragging is a second template and its own CSS', () async {
    const widget = Draggable<String>(
      data: 'a',
      feedback: Text('moving'),
      childWhenDragging: Container(
        width: 40,
        height: 20,
        color: Color(0xFFCCCCCC),
      ),
      child: Container(width: 40, height: 20),
    );
    expect(await renderHtml(widget), contains('<template data-t-dg-ph>'));
    final css = _sheet(await _page(widget));
    expect(css, contains('[data-t-dg-gone]'));
    expect(css, contains('display: none'));
  });

  test('the data is text, a number, a name or JSON', () async {
    Future<String> dataOf<T extends Object>(T data) async {
      final html = await renderHtml(
        Draggable<T>(data: data, feedback: const Text('x'), child: _chip),
      );
      return RegExp(r'data-t-dg-data="([^"]*)"').firstMatch(html)![1]!;
    }

    expect(await dataOf<int>(42), '42');
    expect(await dataOf<double>(1.5), '1.5');
    expect(await dataOf<bool>(true), 'true');
    expect(await dataOf<Axis>(Axis.vertical), 'vertical');
    expect(await dataOf<String>('a~b%c'), 'a~b%c');
    expect(
      await dataOf<Map<String, Object>>(const {
        'id': 3,
        'tags': ['a'],
      }),
      contains('&quot;id&quot;:3'),
    );
    expect(await dataOf<List<int>>(const [1, 2]), '[1,2]');
    // The type is the generic's: the target matches on it.
    final html = await renderHtml(
      const Draggable<int>(data: 3, feedback: Text('x'), child: _chip),
    );
    expect(html, contains('data-t-dg-type="int"'));
  });

  test(
    'a draggable with no data is a drag of nothing: no data attribute',
    () async {
      final html = await renderHtml(
        const Draggable<String>(feedback: Text('x'), child: _chip),
      );
      expect(html, contains('data-t-dg-type="String"'));
      expect(html, isNot(contains('data-t-dg-data')));
    },
  );

  test(
    'the labels are on the element only when they are not the defaults',
    () async {
      final plain = await renderHtml(
        const Draggable<String>(data: 'a', feedback: Text('x'), child: _chip),
      );
      expect(plain, isNot(contains('data-t-dg-say')));
      final es = await renderHtml(
        const Draggable<String>(
          data: 'a',
          labels: DragLabels(
            roleDescription: 'arrastrable',
            pickedUp: 'Levantaste {item}',
          ),
          feedback: Text('x'),
          child: _chip,
        ),
      );
      expect(es, contains('aria-roledescription="arrastrable"'));
      expect(es, contains('data-t-dg-say="'));
      expect(es, contains('Levantaste {item}'));
    },
  );

  test('a native child keeps its own role and focus', () async {
    final html = await renderHtml(
      Draggable<String>(
        data: 'a',
        feedback: const Text('x'),
        child: FilledButton(onPressed: _board.started, child: const Text('b')),
      ),
    );
    expect(RegExp('role="button"').allMatches(html), isEmpty);
    expect(html, contains('data-t-dg '));
    expect(html, isNot(contains('tabindex="0"')));
  });

  test(
    'a DragTarget marks the builder\'s element: type and state methods',
    () async {
      final html = await renderHtml(
        DragTarget<String>(
          onWillAcceptWithDetails: _board.canDrop.withArg('todo'),
          onAcceptWithDetails: _board.dropped.withArg('todo'),
          onLeave: _board.left.withArg('todo'),
          onMove: _board.moved.withArg('todo'),
          builder: (context, candidates, rejected) {
            // Drawn once, with nothing over it.
            expect(candidates, isEmpty);
            expect(rejected, isEmpty);
            return const Container(width: 100, height: 100);
          },
        ),
      );
      expect(
        html,
        contains(
          'data-t-dt="accept:Board.canDrop;drop:Board.dropped;leave:Board.left;move:Board.moved"',
        ),
      );
      expect(html, contains('data-tx="todo"'));
      expect(html, contains('data-t-dg-type="String"'));
      expect(RegExp('<div').allMatches(html), hasLength(1));
    },
  );

  test(
    'a DragTarget with no methods still takes drops (the type decides)',
    () async {
      final html = await renderHtml(
        DragTarget<int>(
          onAcceptWithDetails: _board.dropNumber,
          builder: (context, c, r) => _chip,
        ),
      );
      expect(html, contains('data-t-dt="drop:Board.dropNumber"'));
      expect(html, contains('data-t-dg-type="int"'));
    },
  );

  test('over and rejected looks are CSS on the target\'s attributes', () async {
    final css = _sheet(
      await _page(
        DragTarget<String>(
          onAcceptWithDetails: _board.dropped.withArg('a'),
          overStyle: const StyleProps(opacity: 0.5),
          rejectStyle: const StyleProps(opacity: 0.2),
          builder: (context, c, r) => const Container(width: 40, height: 20),
        ),
      ),
    );
    expect(css, contains('[data-t-dt-over]'));
    expect(css, contains('opacity: 0.5'));
    expect(css, contains('[data-t-dt-reject]'));
    expect(css, contains('opacity: 0.2'));
  });

  test('inside a Watch row the draggable is the row (one root)', () async {
    final html = await renderHtml(
      const Column(
        children: [
          Draggable<String>(
            data: 'r',
            feedback: Text('x'),
            child: Container(width: 40, height: 20),
          ),
        ],
      ),
    );
    expect(RegExp('<template data-t-dg-fb').allMatches(html), hasLength(1));
  });

  test(
    'a state used only by a Draggable or a DragTarget is registered',
    () async {
      for (final child in <Widget>[
        Draggable<String>(
          data: 'a',
          feedback: const Text('x'),
          onDragStarted: (_dndOnly..n.value = 7).picked,
          child: _chip,
        ),
        DragTarget<String>(
          onAcceptWithDetails: (_dndOnly..n.value = 7).dropped.withArg('a'),
          builder: (context, c, r) => _chip,
        ),
      ]) {
        final page = await renderDocument(ThorApp(child: child));
        expect(page, contains('DndOnly.n'), reason: '${child.runtimeType}');
      }
    },
  );

  test('wrappers around a Draggable fuse into its child\'s element', () async {
    final html = await renderHtml(
      const Row(
        children: [
          Expanded(
            child: Draggable<String>(
              data: 'a',
              feedback: Text('x'),
              child: Container(height: 20),
            ),
          ),
        ],
      ),
    );
    expect(html, contains('data-t-dg '));
    // The flex item is the child's element; the feedback template is not one.
    expect(RegExp('flex: 1 1 0%').allMatches(html), hasLength(1));
    expect(RegExp('<div').allMatches(html), hasLength(2));
  });
}
