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
  bool alt = false,
  bool shift = false,
  String type = 'keydown',
}) {
  final e = web.KeyboardEvent(
    type,
    web.KeyboardEventInit(
      key: k,
      altKey: alt,
      shiftKey: shift,
      bubbles: true,
      cancelable: true,
    ),
  );
  el.dispatchEvent(e);
  return e;
}

// The list as thor_ui writes it (what its classes say is inline): a fixed box
// at (20, 20), four items of 40 px with a 10 px gap, each with a handle.
const _css =
    '<style>[data-t-ro-item]{position:relative;height:40px;margin-bottom:10px;'
    'background:#ddd;translate:var(--t-ro-x,0px) var(--t-ro-y,0px)}'
    '[data-t-ro-shift],[data-t-ro-settle]{transition:translate 120ms}'
    '[data-t-ro-h]{position:absolute;right:0;top:5px;width:30px;height:30px}'
    '</style>';

String items(
  int n, {
  String handle = 'data-t-ro-h aria-label="Reorder"',
  String extra = '',
}) => [
  for (var i = 1; i <= n; i++)
    '<div id="i$i" data-t-ro-item role="listitem">Fila $i$extra<button id="h$i" type="button" $handle>::</button></div>',
].join();

String list(
  String body, {
  String ids = 'reorder:L.reorder;start:L.start;end:L.end',
  String cfg = 'v|1',
  String extra = '',
  String dir = 'ltr',
}) =>
    '$_css<div id="list" dir="$dir" data-t-ro="$ids" data-tx="x" data-t-ro-cfg="$cfg" '
    'style="position:fixed;left:20px;top:20px;width:200px" $extra>$body</div>';

void main() {
  late List<String> calls;
  List<Binding> actions() => [
    for (final id in ['L.reorder', 'L.start', 'L.end'])
      Action(id, (arg) => calls.add('$id($arg)')),
  ];

  Future<void> start(web.HTMLElement root) async {
    addTearDown(
      hydrate(actions(), root: root, features: const [ReorderableFeature()]),
    );
  }

  setUp(() {
    calls = [];
    addTearDown(
      () => web.document.querySelector('[aria-live="assertive"]')?.remove(),
    );
  });

  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  Future<void> until(bool Function() ok, {int ms = 3000}) async {
    final end = DateTime.now().millisecondsSinceEpoch + ms;
    while (!ok() && DateTime.now().millisecondsSinceEpoch < end) {
      await wait(10);
    }
  }

  Future<void> frame() => wait(40);

  List<String> order(web.Element root) {
    final out = <String>[];
    final kids = root.querySelector('#list')!.children;
    for (var i = 0; i < kids.length; i++) {
      final k = kids.item(i)!;
      if (k.hasAttribute('data-t-ro-item')) out.add(k.id);
    }
    return out;
  }

  String liveText() =>
      web.document.querySelector('[aria-live="assertive"]')?.textContent ?? '';

  // Handle of item `n` (1-based) is at x = 190, y = 20 + 50 * (n - 1) + 20.
  double handleY(int n) => 20.0 + 50 * (n - 1) + 20;

  Future<void> drag(
    web.Element root,
    int n,
    double toY, {
    bool up = true,
  }) async {
    final h = root.querySelector('#h$n')!;
    pointer(h, 'pointerdown', 190, handleY(n));
    pointer(h, 'pointermove', 190, handleY(n) + (toY > handleY(n) ? 6 : -6));
    pointer(h, 'pointermove', 190, toY);
    final item = root.querySelector('#i$n')! as web.HTMLElement;
    await until(() => item.style.getPropertyValue('--t-ro-y').isNotEmpty);
    await frame();
    if (up) pointer(h, 'pointerup', 190, toY);
  }

  String? shift(web.Element root, int n) =>
      (root.querySelector('#i$n')! as web.HTMLElement).style.getPropertyValue(
        '--t-ro-y',
      );

  test('dragging a handle down: the others give way, then the item settles, '
      'moves in the page and the state hears it', () async {
    final root = mount(list(items(4)));
    await start(root);
    await drag(root, 1, handleY(1) + 110, up: false);
    // The dragged item follows the pointer; the ones it passed give way.
    final first = root.querySelector('#i1')! as web.HTMLElement;
    expect(first.hasAttribute('data-t-ro-drag'), isTrue);
    expect(first.style.getPropertyValue('--t-ro-y'), '110px');
    expect(shift(root, 2), '-50px');
    expect(root.querySelector('#i2')!.hasAttribute('data-t-ro-shift'), isTrue);
    expect(shift(root, 3), '-50px');
    expect(shift(root, 4), isEmpty);
    expect(calls, ['L.start(x~0)']);
    pointer(first, 'pointerup', 190, handleY(1) + 110);
    expect(first.hasAttribute('data-t-ro-settle'), isTrue);
    expect(first.hasAttribute('data-t-ro-drag'), isFalse);
    expect(order(root), ['i1', 'i2', 'i3', 'i4'], reason: 'it settles first');
    await until(() => calls.length == 3);
    expect(order(root), ['i2', 'i3', 'i1', 'i4']);
    expect(calls, ['L.start(x~0)', 'L.reorder(x~0~3)', 'L.end(x~2)']);
    for (final id in ['i1', 'i2', 'i3', 'i4']) {
      final el = root.querySelector('#$id')! as web.HTMLElement;
      expect(el.style.getPropertyValue('--t-ro-y'), isEmpty);
      expect(el.hasAttribute('data-t-ro-shift'), isFalse);
      expect(el.hasAttribute('data-t-ro-settle'), isFalse);
    }
  });

  test(
    'dragging up, Flutter\'s indexes: the new index is where it lands',
    () async {
      final root = mount(list(items(4)));
      await start(root);
      await drag(root, 3, handleY(3) - 110);
      await until(() => calls.length == 3);
      expect(order(root), ['i3', 'i1', 'i2', 'i4']);
      expect(calls, ['L.start(x~2)', 'L.reorder(x~2~0)', 'L.end(x~0)']);
    },
  );

  test(
    'past the ends it stays in the list; the last place is index n',
    () async {
      final root = mount(list(items(3)));
      await start(root);
      await drag(root, 1, 600);
      await until(() => calls.length == 3);
      expect(order(root), ['i2', 'i3', 'i1']);
      expect(calls[1], 'L.reorder(x~0~3)');
    },
  );

  test(
    'dropped where it was: nothing reorders, the end is still told',
    () async {
      final root = mount(list(items(3)));
      await start(root);
      await drag(root, 2, handleY(2) + 8);
      await until(() => calls.length == 2);
      expect(order(root), ['i1', 'i2', 'i3']);
      expect(calls, ['L.start(x~1)', 'L.end(x~1)']);
    },
  );

  test('Escape and a cancelled pointer put everything back', () async {
    final root = mount(list(items(3)));
    await start(root);
    await drag(root, 1, handleY(1) + 60, up: false);
    expect(key(root.querySelector('#h1')!, 'Escape').defaultPrevented, isTrue);
    await until(() => calls.length == 2);
    expect(order(root), ['i1', 'i2', 'i3']);
    expect(calls, ['L.start(x~0)', 'L.end(x~0)']);
    expect(
      (root.querySelector('#i2')! as web.HTMLElement).style.getPropertyValue(
        '--t-ro-y',
      ),
      isEmpty,
    );
    calls.clear();
    final h = root.querySelector('#h2')!;
    pointer(h, 'pointerdown', 190, handleY(2));
    pointer(h, 'pointermove', 190, handleY(2) + 10);
    pointer(h, 'pointermove', 190, handleY(2) + 70);
    await frame();
    pointer(h, 'pointercancel', 190, handleY(2) + 70);
    await until(() => calls.length == 2);
    expect(calls, ['L.start(x~1)', 'L.end(x~1)']);
    expect(order(root), ['i1', 'i2', 'i3']);
  });

  test(
    'a drag swallows its click; a press that does not move is a click',
    () async {
      final root = mount(list(items(3)));
      await start(root);
      var clicks = 0;
      final h = root.querySelector('#h1')!;
      h.addEventListener('click', ((web.Event _) => clicks++).toJS);
      pointer(h, 'pointerdown', 190, handleY(1));
      pointer(h, 'pointerup', 190, handleY(1));
      (h as web.HTMLElement).click();
      expect(clicks, 1);
      expect(calls, isEmpty);
      await drag(root, 1, handleY(1) + 60);
      h.click();
      expect(clicks, 1);
      await wait(100);
      h.click();
      expect(clicks, 2);
    },
  );

  test('header and footer are not items and are not moved', () async {
    final root = mount(
      list('<div id="head">cabecera</div>${items(2)}<div id="foot">pie</div>'),
    );
    await start(root);
    final head = root.querySelector('#head')!;
    pointer(head, 'pointerdown', 100, 25);
    pointer(head, 'pointermove', 100, 40);
    pointer(head, 'pointermove', 100, 90);
    await frame();
    expect(root.querySelector('#i1')!.hasAttribute('data-t-ro-drag'), isFalse);
    expect(calls, isEmpty);
    await drag(root, 1, handleY(1) + 200);
    await until(() => calls.length == 3);
    expect(order(root), ['i2', 'i1']);
    expect(root.querySelector('#list')!.lastElementChild!.id, 'foot');
  });

  test(
    'a header and a footer outside the list leave its indexes right',
    () async {
      final root = mount(
        '<div id="head">cabecera</div>${list(items(2))}<div id="foot">pie</div>',
      );
      await start(root);
      final host = root.querySelector('#list')!;
      expect(host.children.length, 2);
      await drag(root, 1, handleY(1) + 200);
      await until(() => calls.length == 3);
      expect(order(root), ['i2', 'i1']);
      expect(root.querySelector('#head')!.parentElement, host.parentElement);
      expect(host.nextElementSibling!.id, 'foot');
    },
  );

  test(
    'a held finger anywhere on an item drags it; moving first is a scroll',
    () async {
      final root = mount(list(items(3)));
      await start(root);
      final i1 = root.querySelector('#i1')!;
      pointer(i1, 'pointerdown', 60, 40, kind: 'touch');
      pointer(i1, 'pointermove', 60, 60, kind: 'touch');
      await wait(650);
      expect(i1.hasAttribute('data-t-ro-drag'), isFalse);
      pointer(i1, 'pointerup', 60, 60, kind: 'touch');
      expect(calls, isEmpty);
      pointer(i1, 'pointerdown', 60, 40, kind: 'touch');
      await until(() => i1.hasAttribute('data-t-ro-drag'));
      expect(i1.hasAttribute('data-t-ro-drag'), isTrue);
      pointer(i1, 'pointermove', 60, 140, kind: 'touch');
      await frame();
      pointer(i1, 'pointerup', 60, 140, kind: 'touch');
      await until(() => calls.length == 3);
      expect(order(root), ['i2', 'i3', 'i1']);
    },
  );

  test('with no touch drag (default handles off) a held finger does nothing, '
      'a delayed handle waits for its hold', () async {
    final root = mount(
      list(
        '<div id="i1" data-t-ro-item>uno<span id="d" data-t-ro-h="delayed">::</span><input id="f"></div>'
        '<div id="i2" data-t-ro-item>dos</div>',
        cfg: 'v|0',
      ),
    );
    await start(root);
    final i1 = root.querySelector('#i1')!;
    pointer(i1, 'pointerdown', 60, 20, kind: 'touch');
    await wait(650);
    expect(i1.hasAttribute('data-t-ro-drag'), isFalse);
    pointer(i1, 'pointerup', 60, 20, kind: 'touch');
    final d = root.querySelector('#d')!;
    pointer(d, 'pointerdown', 60, 20, kind: 'touch');
    await until(() => i1.hasAttribute('data-t-ro-drag'));
    expect(i1.hasAttribute('data-t-ro-drag'), isTrue);
    pointer(d, 'pointerup', 60, 20, kind: 'touch');
    await until(() => calls.contains('L.end(x~0)'));
  });

  test('a field inside an item keeps its pointer', () async {
    final root = mount(list(items(2, extra: '<input id="f">')));
    await start(root);
    final f = root.querySelector('#i1 input')!;
    pointer(f, 'pointerdown', 60, 30, kind: 'touch');
    await wait(650);
    expect(root.querySelector('#i1')!.hasAttribute('data-t-ro-drag'), isFalse);
    pointer(f, 'pointerup', 60, 30, kind: 'touch');
  });

  group('keyboard', () {
    test('Space on a handle picks up, the arrows move, Space drops', () async {
      final root = mount(list(items(3)));
      await start(root);
      final h = root.querySelector('#h1')! as web.HTMLElement;
      h.focus();
      expect(key(h, ' ').defaultPrevented, isTrue);
      expect(calls, ['L.start(x~0)']);
      await until(() => liveText().contains('Picked up'));
      expect(liveText(), startsWith('Picked up Fila 1, position 1 of 3.'));
      key(h, 'ArrowDown');
      expect(order(root), ['i2', 'i1', 'i3']);
      expect(
        web.document.activeElement,
        h,
        reason: 'the focus stays on the handle',
      );
      await until(() => liveText() == 'Fila 1, position 2 of 3.');
      expect(liveText(), 'Fila 1, position 2 of 3.');
      key(h, 'ArrowDown');
      key(h, 'ArrowDown');
      expect(order(root), [
        'i2',
        'i3',
        'i1',
      ], reason: 'the end of the list holds');
      key(h, ' ');
      expect(calls, ['L.start(x~0)', 'L.reorder(x~0~3)', 'L.end(x~2)']);
      await until(() => liveText().startsWith('Dropped'));
      expect(liveText(), 'Dropped Fila 1 at position 3 of 3.');
    });

    test('Escape puts it back where it was', () async {
      final root = mount(list(items(3)));
      await start(root);
      final h = root.querySelector('#h2')! as web.HTMLElement;
      h.focus();
      key(h, 'Enter');
      key(h, 'ArrowUp');
      expect(order(root), ['i2', 'i1', 'i3']);
      key(h, 'Escape');
      expect(order(root), ['i1', 'i2', 'i3']);
      expect(calls, ['L.start(x~1)', 'L.end(x~1)']);
      await until(() => liveText().startsWith('Cancelled'));
      expect(liveText(), 'Cancelled. Fila 2 is back at position 2 of 3.');
    });

    test('Home and End go to the ends', () async {
      final root = mount(list(items(4)));
      await start(root);
      final h = root.querySelector('#h2')! as web.HTMLElement;
      h.focus();
      key(h, ' ');
      key(h, 'End');
      expect(order(root), ['i1', 'i3', 'i4', 'i2']);
      key(h, 'Home');
      expect(order(root), ['i2', 'i1', 'i3', 'i4']);
      key(h, ' ');
      expect(calls.last, 'L.end(x~0)');
    });

    test(
      'Alt+arrow moves the item at once, from a handle or from inside it',
      () async {
        final root = mount(
          list(items(3, extra: '<a class="lnk" href="#x">enlace</a>')),
        );
        await start(root);
        final h = root.querySelector('#h1')! as web.HTMLElement;
        expect(key(h, 'ArrowDown', alt: true).defaultPrevented, isTrue);
        expect(order(root), ['i2', 'i1', 'i3']);
        expect(calls, ['L.reorder(x~0~2)']);
        calls.clear();
        final link = root.querySelector('#i3 a')!;
        key(link, 'ArrowUp', alt: true);
        expect(order(root), ['i2', 'i3', 'i1']);
        expect(calls, ['L.reorder(x~2~1)']);
        calls.clear();
        // The top of the list: nothing moves, nothing is called.
        key(root.querySelector('#h2')!, 'ArrowUp', alt: true);
        expect(calls, isEmpty);
        // A plain arrow, and a field's keys, are not ours.
        expect(key(h, 'ArrowDown').defaultPrevented, isFalse);
      },
    );

    test('a field inside an item keeps Alt+arrow', () async {
      final root = mount(list(items(2, extra: '<input id="f">')));
      await start(root);
      final f = root.querySelector('#f')!;
      expect(key(f, 'ArrowDown', alt: true).defaultPrevented, isFalse);
      expect(order(root), ['i1', 'i2']);
    });

    test('the handle is named for its item when it gets the focus', () async {
      final root = mount(list(items(2)));
      await start(root);
      final h = root.querySelector('#h2')! as web.HTMLElement;
      expect(h.getAttribute('aria-label'), 'Reorder');
      h.dispatchEvent(
        web.FocusEvent('focusin', web.FocusEventInit(bubbles: true)),
      );
      expect(h.getAttribute('aria-label'), 'Reorder Fila 2');
    });

    test('the page\'s words replace the English ones', () async {
      final root = mount(
        list(
          items(2),
          extra:
              'data-t-ro-say="Levantaste {item}, {position}/{count}\n{item}: {position}/{count}\nSoltaste {item}: {position}\nCancelado\nReordenar {item}"',
        ),
      );
      await start(root);
      final h = root.querySelector('#h1')! as web.HTMLElement;
      h.focus();
      key(h, ' ');
      await until(() => liveText().startsWith('Levantaste'));
      expect(liveText(), 'Levantaste Fila 1, 1/2');
      key(h, 'ArrowDown');
      await until(() => liveText().startsWith('Fila 1:'));
      expect(liveText(), 'Fila 1: 2/2');
      key(h, ' ');
      await until(() => liveText().startsWith('Soltaste'));
      expect(liveText(), 'Soltaste Fila 1: 2');
    });

    test('in a right-to-left row the left arrow goes on', () async {
      final root = mount(
        list(
          items(3),
          cfg: 'h|1',
          dir: 'rtl',
          extra: 'class="row"',
        ).replaceFirst(
          '<div id="list"',
          '<div id="list" style="display:flex;flex-direction:row"',
        ),
      );
      await start(root);
      final h = root.querySelector('#h1')! as web.HTMLElement;
      h.focus();
      key(h, ' ');
      key(h, 'ArrowLeft');
      expect(order(root), ['i2', 'i1', 'i3']);
      key(h, 'ArrowRight');
      expect(order(root), ['i1', 'i2', 'i3']);
      key(h, 'Escape');
    });

    test('losing the focus drops a picked-up item back', () async {
      final root = mount('${list(items(2))}<button id="out">fuera</button>');
      await start(root);
      final h = root.querySelector('#h1')! as web.HTMLElement;
      h.focus();
      key(h, ' ');
      key(h, 'ArrowDown');
      expect(order(root), ['i2', 'i1']);
      (root.querySelector('#out')! as web.HTMLElement).focus();
      await frame();
      expect(order(root), ['i1', 'i2']);
      expect(calls.last, 'L.end(x~0)');
    });
  });
}
