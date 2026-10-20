@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thor_engine_oracle/client.dart';
import 'package:web/web.dart' as web;

web.HTMLElement mount(String html) {
  final root = web.document.createElement('div') as web.HTMLElement
    ..innerHTML = html.toJS;
  web.document.body!.append(root);
  // ignore: unnecessary_lambdas
  addTearDown(() => root.remove());
  return root;
}

void pointer(
  web.EventTarget el,
  String type,
  double x,
  double y, {
  int id = 1,
  String kind = 'mouse',
}) {
  el.dispatchEvent(
    web.PointerEvent(
      type,
      web.PointerEventInit(
        bubbles: true,
        cancelable: true,
        clientX: x.round(),
        clientY: y.round(),
        pointerId: id,
        pointerType: kind,
        isPrimary: true,
        button: 0,
      ),
    ),
  );
}

web.KeyboardEvent key(
  web.EventTarget el,
  String k, {
  bool shift = false,
  String type = 'keydown',
}) {
  final e = web.KeyboardEvent(
    type,
    web.KeyboardEventInit(
      key: k,
      shiftKey: shift,
      bubbles: true,
      cancelable: true,
    ),
  );
  el.dispatchEvent(e);
  return e;
}

/// A draggable and its feedback template, as thor_ui writes them.
String source(
  String id, {
  String data = 'task-1',
  String type = 'String',
  String cfg = 'f|0|c|1|0|0',
  String left = '10',
  String top = '10',
  String ids =
      'start:Board.started;done:Board.done;cancel:Board.canceled;end:Board.ended',
  String extra = '',
}) =>
    '<div id="$id" tabindex="0" role="button" data-t-dg="$ids" data-tx="x" '
    'data-t-dg-data="$data" data-t-dg-type="$type" data-t-dg-cfg="$cfg" '
    'style="position:fixed;left:${left}px;top:${top}px;width:80px;height:30px;'
    'background:#ccc">Tarea $id'
    '<template data-t-dg-fb><div data-t-dg-ghost id="ghost" style="position:fixed;'
    'inset:0 auto auto 0;margin:0;width:80px;height:30px;'
    'translate:var(--t-dg-x,0px) var(--t-dg-y,0px);pointer-events:none">fantasma'
    '</div></template>$extra</div>';

String target(
  String id, {
  String type = 'String',
  String left = '200',
  String top = '10',
  String ids =
      'accept:Board.canDrop;drop:Board.dropped;leave:Board.left;move:Board.moved',
}) =>
    '<div id="$id" data-t-dt="$ids" data-tx="$id" data-t-dg-type="$type" '
    'style="position:fixed;left:${left}px;top:${top}px;width:150px;height:100px;'
    'background:#9cf">Columna $id</div>';

void main() {
  late List<String> calls;
  late bool Function(String arg) accepts;
  List<Binding> actions(List<String> ids) => [
    for (final id in ids) Action(id, (arg) => calls.add('$id($arg)')),
  ];
  ThorMember member(String id) => ThorMember(
    id,
    () {},
    call: (arg) {
      calls.add('$id($arg)');
      return accepts('$arg');
    },
  );

  const all = [
    'Board.started',
    'Board.done',
    'Board.canceled',
    'Board.ended',
    'Board.dropped',
    'Board.left',
    'Board.moved',
  ];

  Future<void> start(web.HTMLElement root) async {
    const DragDropFeature().collect(root, member, [], {});
    addTearDown(
      hydrate(actions(all), root: root, features: const [DragDropFeature()]),
    );
  }

  setUp(() {
    calls = [];
    accepts = (_) => true;
    // What a failed test leaves in the page (a ghost lives in the body).
    addTearDown(() {
      final left = web.document.querySelectorAll('[data-t-dg-ghost]');
      for (var i = left.length - 1; i >= 0; i--) {
        (left.item(i)! as web.Element).remove();
      }
      web.document.querySelector('[aria-live="assertive"]')?.remove();
    });
  });

  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  Future<void> until(bool Function() ok, {int ms = 2000}) async {
    final end = DateTime.now().millisecondsSinceEpoch + ms;
    while (!ok() && DateTime.now().millisecondsSinceEpoch < end) {
      await wait(10);
    }
  }

  Future<void> frame() =>
      Future<void>.delayed(const Duration(milliseconds: 40));

  web.Element? ghost() => web.document.querySelector('[data-t-dg-ghost]');

  Future<void> grab(
    web.Element src,
    double x,
    double y,
    double toX,
    double toY,
  ) async {
    pointer(src, 'pointerdown', x, y);
    pointer(src, 'pointermove', x + 8, y + 2);
    pointer(src, 'pointermove', toX, toY);
    await frame();
  }

  test('a wrapper between the draggable and its templates (a Tooltip '
      'bubble) still finds the feedback', () async {
    // What `Draggable(child: Tooltip(...))` writes: the bubble is the next
    // sibling and the template comes after it.
    final html = source('a');
    final cut = html.indexOf('<template');
    final root = mount(
      '${html.substring(0, cut)}</div>'
      '<span role="tooltip">tip</span>'
      '${html.substring(cut, html.length - '</div>'.length)}'
      '${target('todo')}',
    );
    await start(root);
    final a = root.querySelector('#a')!;
    expect(a.nextElementSibling!.getAttribute('role'), 'tooltip');
    await grab(a, 20, 20, 250, 60);
    expect(ghost(), isNotNull);
    pointer(a, 'pointerup', 250, 60);
    expect(calls, contains('Board.dropped(todo~task-1)'));
  });

  test('a drag clones the feedback under the pointer, marks the target and '
      'drops with the data', () async {
    final root = mount(source('a') + target('todo'));
    await start(root);
    final a = root.querySelector('#a')!;
    await grab(a, 20, 20, 250, 60);
    final g = ghost()!;
    expect(g.parentElement, web.document.body);
    // The feedback keeps the distance the child had from the pointer.
    expect((g as web.HTMLElement).style.getPropertyValue('--t-dg-x'), '240px');
    expect(g.style.getPropertyValue('--t-dg-y'), '50px');
    expect(a.hasAttribute('data-t-dg-active'), isTrue);
    expect(root.querySelector('#todo')!.hasAttribute('data-t-dt-over'), isTrue);
    expect(calls, contains('Board.started(x)'));
    expect(calls, contains('Board.canDrop(todo~task-1)'));
    pointer(a, 'pointerup', 250, 60);
    expect(ghost(), isNull);
    expect(a.hasAttribute('data-t-dg-active'), isFalse);
    expect(
      root.querySelector('#todo')!.hasAttribute('data-t-dt-over'),
      isFalse,
    );
    expect(calls.sublist(calls.indexOf('Board.dropped(todo~task-1)')), [
      'Board.dropped(todo~task-1)',
      'Board.done(x)',
      'Board.ended(x~true)',
    ]);
    expect(
      calls,
      isNot(contains('Board.left(todo~task-1)')),
      reason: 'a drop is not a leave',
    );
  });

  test('dropping on nothing cancels, with where the pointer was', () async {
    final root = mount(source('a') + target('todo'));
    await start(root);
    final a = root.querySelector('#a')!;
    await grab(a, 20, 20, 120, 300);
    pointer(a, 'pointerup', 120, 300);
    expect(calls, [
      'Board.started(x)',
      'Board.canceled(x~120~300)',
      'Board.ended(x~false)',
    ]);
    expect(ghost(), isNull);
  });

  test('a target of another type rejects; one that says no rejects', () async {
    final root = mount(
      source('a') +
          target('num', type: 'int', top: '10') +
          target('no', left: '200', top: '150'),
    );
    await start(root);
    accepts = (arg) => !arg.startsWith('no~');
    final a = root.querySelector('#a')!;
    await grab(a, 20, 20, 250, 60);
    final numTarget = root.querySelector('#num')!;
    expect(numTarget.hasAttribute('data-t-dt-reject'), isTrue);
    expect(numTarget.hasAttribute('data-t-dt-over'), isFalse);
    expect(
      calls.any((c) => c.startsWith('Board.canDrop(num')),
      isFalse,
      reason: 'the type decides before the method is asked',
    );
    pointer(a, 'pointermove', 250, 190);
    await frame();
    final no = root.querySelector('#no')!;
    expect(no.hasAttribute('data-t-dt-reject'), isTrue);
    expect(numTarget.hasAttribute('data-t-dt-reject'), isFalse);
    pointer(a, 'pointerup', 250, 190);
    expect(calls.any((c) => c.startsWith('Board.dropped')), isFalse);
    expect(calls, contains('Board.ended(x~false)'));
  });

  test('Object takes any draggable, num takes int and double', () async {
    final root = mount(
      source('a', type: 'double') +
          target('any', type: 'Object', top: '10') +
          target('number', type: 'num', left: '200', top: '150'),
    );
    await start(root);
    final a = root.querySelector('#a')!;
    await grab(a, 20, 20, 250, 60);
    expect(root.querySelector('#any')!.hasAttribute('data-t-dt-over'), isTrue);
    pointer(a, 'pointermove', 250, 190);
    await frame();
    expect(
      root.querySelector('#number')!.hasAttribute('data-t-dt-over'),
      isTrue,
    );
    pointer(a, 'pointerup', 250, 190);
    expect(calls, contains('Board.dropped(number~task-1)'));
  });

  test('the target is asked once per entry; leaving calls leave', () async {
    final root = mount(
      source('a') +
          target('todo', top: '10') +
          target('done', left: '200', top: '150'),
    );
    await start(root);
    final a = root.querySelector('#a')!;
    await grab(a, 20, 20, 250, 60);
    pointer(a, 'pointermove', 260, 70);
    await frame();
    pointer(a, 'pointermove', 250, 190);
    await frame();
    expect(calls.where((c) => c == 'Board.canDrop(todo~task-1)'), hasLength(1));
    expect(calls, contains('Board.left(todo~task-1)'));
    // Back in: asked again, as Flutter does on each entry.
    pointer(a, 'pointermove', 250, 60);
    await frame();
    expect(calls.where((c) => c == 'Board.canDrop(todo~task-1)'), hasLength(2));
    pointer(a, 'pointerup', 250, 60);
  });

  test('onMove: the pointer inside the target, once a frame', () async {
    final root = mount(source('a') + target('todo'));
    await start(root);
    final a = root.querySelector('#a')!;
    await grab(a, 20, 20, 250, 60);
    final first = calls.where((c) => c.startsWith('Board.moved')).toList();
    expect(first, ['Board.moved(todo~50~50)']);
    pointer(a, 'pointermove', 260, 70);
    pointer(a, 'pointermove', 270, 80);
    await frame();
    final moves = calls.where((c) => c.startsWith('Board.moved')).toList();
    expect(moves, hasLength(2));
    expect(moves.last, 'Board.moved(todo~70~70)');
    pointer(a, 'pointerup', 270, 80);
  });

  test('data with ~ or % is the last part of the drop, as it is', () async {
    final root = mount(source('a', data: 'a~b%c') + target('todo'));
    await start(root);
    final a = root.querySelector('#a')!;
    await grab(a, 20, 20, 250, 60);
    pointer(a, 'pointerup', 250, 60);
    expect(calls, contains('Board.dropped(todo~a~b%c)'));
    expect(calls, contains('Board.canDrop(todo~a~b%c)'));
  });

  test('an axis keeps the feedback on its line', () async {
    final root = mount(source('a', cfg: 'h|0|c|1|0|0') + target('todo'));
    await start(root);
    final a = root.querySelector('#a')!;
    await grab(a, 20, 20, 250, 90);
    final g = ghost()! as web.HTMLElement;
    expect(g.style.getPropertyValue('--t-dg-x'), '240px');
    expect(g.style.getPropertyValue('--t-dg-y'), '10px');
    pointer(a, 'pointerup', 250, 90);
  });

  test('the pointer anchor puts the feedback\'s corner at the pointer, '
      'with the offset', () async {
    final root = mount(source('a', cfg: 'f|0|p|1|4|-8') + target('todo'));
    await start(root);
    final a = root.querySelector('#a')!;
    await grab(a, 20, 20, 250, 60);
    final g = ghost()! as web.HTMLElement;
    expect(g.style.getPropertyValue('--t-dg-x'), '254px');
    expect(g.style.getPropertyValue('--t-dg-y'), '52px');
    pointer(a, 'pointerup', 250, 60);
  });

  test('childWhenDragging stands in for the child and goes back', () async {
    final root = mount(
      source(
            'a',
            extra:
                '<template data-t-dg-ph><div id="ph" style="width:80px;height:30px">hueco</div></template>',
          ) +
          target('todo'),
    );
    await start(root);
    final a = root.querySelector('#a')!;
    await grab(a, 20, 20, 250, 60);
    expect(root.querySelector('#ph'), isNotNull);
    expect(a.hasAttribute('data-t-dg-gone'), isTrue);
    pointer(a, 'pointerup', 250, 60);
    expect(root.querySelector('#ph'), isNull);
    expect(a.hasAttribute('data-t-dg-gone'), isFalse);
  });

  test('a press that does not move is a click, not a drag', () async {
    final root = mount(source('a') + target('todo'));
    await start(root);
    final a = root.querySelector('#a')!;
    var clicks = 0;
    a.addEventListener('click', ((web.Event _) => clicks++).toJS);
    pointer(a, 'pointerdown', 20, 20);
    pointer(a, 'pointermove', 22, 21);
    pointer(a, 'pointerup', 22, 21);
    (a as web.HTMLElement).click();
    expect(clicks, 1);
    expect(calls, isEmpty);
    // A drag swallows its own click.
    await grab(a, 20, 20, 250, 60);
    pointer(a, 'pointerup', 250, 60);
    a.click();
    expect(clicks, 1);
  });

  test('Escape gives a pointer drag up', () async {
    final root = mount(source('a') + target('todo'));
    await start(root);
    final a = root.querySelector('#a')!;
    await grab(a, 20, 20, 250, 60);
    expect(key(a, 'Escape').defaultPrevented, isTrue);
    expect(ghost(), isNull);
    expect(calls, contains('Board.ended(x~false)'));
    expect(calls, contains('Board.left(todo~task-1)'));
    pointer(a, 'pointerup', 250, 60);
    expect(calls.where((c) => c.startsWith('Board.ended')), hasLength(1));
  });

  test(
    'a LongPressDraggable waits for the hold; moving first is a scroll',
    () async {
      final root = mount(source('a', cfg: 'f|120|c|1|0|0') + target('todo'));
      await start(root);
      final a = root.querySelector('#a')!;
      pointer(a, 'pointerdown', 20, 20, kind: 'touch');
      pointer(a, 'pointermove', 60, 80, kind: 'touch');
      await wait(200);
      expect(ghost(), isNull, reason: 'it moved before the hold');
      expect(calls, isEmpty);
      pointer(a, 'pointerup', 60, 80, kind: 'touch');
      // Held still: the drag starts by itself.
      pointer(a, 'pointerdown', 20, 20, kind: 'touch');
      await until(() => ghost() != null);
      expect(ghost(), isNotNull);
      expect(calls, ['Board.started(x)']);
      pointer(a, 'pointermove', 250, 60, kind: 'touch');
      await frame();
      pointer(a, 'pointerup', 250, 60, kind: 'touch');
      expect(calls, contains('Board.dropped(todo~task-1)'));
    },
  );

  test('a text field inside the draggable keeps its pointer', () async {
    final root = mount(
      source('a', extra: '<input id="f" style="position:absolute">') +
          target('todo'),
    );
    await start(root);
    final f = root.querySelector('#f')!;
    pointer(f, 'pointerdown', 20, 20);
    pointer(f, 'pointermove', 100, 60);
    pointer(f, 'pointermove', 250, 60);
    await frame();
    expect(ghost(), isNull);
  });

  test('maxSimultaneousDrags 0 in the setup means nothing to drag', () async {
    final root = mount(source('a', cfg: 'f|0|c|0|0|0') + target('todo'));
    await start(root);
    final a = root.querySelector('#a')!;
    await grab(a, 20, 20, 250, 60);
    expect(ghost(), isNull);
  });

  group('keyboard', () {
    test('Space picks up, the arrows move between the targets that fit, '
        'Space drops', () async {
      final root = mount(
        source('a') +
            target('one', top: '10') +
            target('skip', type: 'int', left: '200', top: '120') +
            target('two', left: '200', top: '240'),
      );
      await start(root);
      final a = root.querySelector('#a')! as web.HTMLElement;
      a.focus();
      expect(key(a, ' ').defaultPrevented, isTrue);
      expect(ghost(), isNotNull);
      expect(a.hasAttribute('data-t-dg-active'), isTrue);
      await until(() => liveText().contains('Picked up'));
      expect(liveText(), contains('Picked up Tarea a'));
      key(a, 'ArrowDown');
      expect(
        root.querySelector('#one')!.hasAttribute('data-t-dt-over'),
        isTrue,
      );
      await until(() => liveText().contains('Columna one'));
      expect(liveText(), contains('Columna one: it can be dropped here.'));
      key(a, 'ArrowDown');
      expect(
        root.querySelector('#two')!.hasAttribute('data-t-dt-over'),
        isTrue,
        reason: 'the int target is skipped',
      );
      key(a, 'ArrowUp');
      expect(
        root.querySelector('#one')!.hasAttribute('data-t-dt-over'),
        isTrue,
      );
      key(a, 'Tab');
      expect(
        root.querySelector('#two')!.hasAttribute('data-t-dt-over'),
        isTrue,
      );
      key(a, ' ');
      expect(ghost(), isNull);
      expect(calls, contains('Board.dropped(two~task-1)'));
      expect(calls, contains('Board.ended(x~true)'));
      await until(() => liveText().contains('Dropped'));
      expect(liveText(), contains('Dropped Tarea a on Columna two.'));
      expect(web.document.activeElement, a, reason: 'focus comes back');
    });

    test(
      'Escape cancels; a target that says no is announced and not dropped',
      () async {
        final root = mount(
          source('a') + target('no') + target('ok', left: '200', top: '150'),
        );
        await start(root);
        accepts = (arg) => !arg.startsWith('no~');
        final a = root.querySelector('#a')! as web.HTMLElement;
        a.focus();
        key(a, 'Enter');
        key(a, 'ArrowDown');
        expect(
          root.querySelector('#no')!.hasAttribute('data-t-dt-reject'),
          isTrue,
        );
        await until(() => liveText().contains('cannot'));
        expect(liveText(), contains('Columna no: it cannot be dropped here.'));
        key(a, ' ');
        expect(ghost(), isNotNull, reason: 'it stays picked up');
        expect(calls.any((c) => c.startsWith('Board.dropped')), isFalse);
        key(a, 'Escape');
        expect(ghost(), isNull);
        expect(calls, contains('Board.ended(x~false)'));
        expect(calls.any((c) => c.startsWith('Board.canceled')), isTrue);
        await until(() => liveText().contains('Cancelled'));
        expect(liveText(), contains('Cancelled. Tarea a was not moved.'));
      },
    );

    test('the page\'s words replace the English ones', () async {
      final root = mount(
        source('a', extra: '').replaceFirst(
              'data-t-dg-type',
              'data-t-dg-say="Levantaste {item}\n{target}: cabe\n{target}: no cabe\n'
                  'Soltaste {item} en {target}\nCancelado" data-t-dg-type',
            ) +
            target('one'),
      );
      await start(root);
      final a = root.querySelector('#a')! as web.HTMLElement;
      a.focus();
      key(a, ' ');
      await until(() => liveText().contains('Levantaste'));
      expect(liveText(), 'Levantaste Tarea a');
      key(a, 'ArrowDown');
      await until(() => liveText().contains('cabe'));
      expect(liveText(), 'Columna one: cabe');
      key(a, ' ');
      await until(() => liveText().contains('Soltaste'));
      expect(liveText(), 'Soltaste Tarea a en Columna one');
    });

    test('keys inside a field of the draggable are the field\'s', () async {
      final root = mount(source('a', extra: '<input id="f">') + target('one'));
      await start(root);
      final f = root.querySelector('#f')!;
      expect(key(f, ' ').defaultPrevented, isFalse);
      expect(ghost(), isNull);
    });
  });
}

String liveText() {
  final live = web.document.querySelector('[aria-live="assertive"]');
  return live?.textContent ?? '';
}
