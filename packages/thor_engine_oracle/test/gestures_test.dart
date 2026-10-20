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

void pointer(web.Element el, String type, double x, double y, {int id = 1}) {
  el.dispatchEvent(
    web.PointerEvent(
      type,
      web.PointerEventInit(
        bubbles: true,
        cancelable: true,
        clientX: x.round(),
        clientY: y.round(),
        pointerId: id,
        pointerType: 'touch',
        isPrimary: id == 1,
      ),
    ),
  );
}

void main() {
  late List<String> calls;
  List<Binding> actions(List<String> ids) => [
    for (final id in ids) Action(id, (arg) => calls.add('$id($arg)')),
  ];

  setUp(() => calls = []);

  test(
    'swipe to dismiss: fly out, then the action with the direction',
    () async {
      final root = mount(
        '<div id="row" style="width:200px;height:40px" data-tx="m1" '
        'data-tg="swipe:swiped" data-tg-swipe="h|1|0.4">Mensaje</div>',
      );
      addTearDown(
        hydrate(
          actions(['swiped']),
          root: root,
          features: const [GesturesFeature()],
        ),
      );
      final row = root.querySelector('#row')! as web.HTMLElement;
      pointer(row, 'pointerdown', 180, 20);
      for (var x = 170.0; x >= 60; x -= 10) {
        pointer(row, 'pointermove', x, 20);
      }
      expect(row.style.getPropertyValue('--tg-x'), '-120px');
      expect(row.hasAttribute('data-tg-active'), isTrue);
      pointer(row, 'pointerup', 60, 20);
      expect(row.hasAttribute('data-tg-out'), isTrue);
      expect(calls, isEmpty, reason: 'runs after the fly-out');
      await Future<void>.delayed(const Duration(milliseconds: 260));
      expect(calls, ['swiped(m1~start)']);
    },
  );

  test(
    'a swipe is start/end by the direction: the same drag flips in rtl',
    () async {
      // The same physical drag, toward the physical right, in ltr and rtl.
      final root = mount(
        '<div dir="ltr"><div id="a" style="width:200px;height:40px" '
        'data-tg="swipe:swiped" data-tg-swipe="h|0|0.4">a</div></div>'
        '<div dir="rtl"><div id="b" style="width:200px;height:40px" '
        'data-tg="swipe:swiped" data-tg-swipe="h|0|0.4">b</div></div>',
      );
      addTearDown(
        hydrate(
          actions(['swiped']),
          root: root,
          features: const [GesturesFeature()],
        ),
      );
      for (final id in ['a', 'b']) {
        final el = root.querySelector('#$id')!;
        pointer(el, 'pointerdown', 20, 20);
        for (var x = 30.0; x <= 160; x += 10) {
          pointer(el, 'pointermove', x, 20);
        }
        pointer(el, 'pointerup', 160, 20);
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(calls, ['swiped(end)', 'swiped(start)']);
    },
  );

  test('a short swipe snaps back and calls nothing', () async {
    final root = mount(
      '<div id="row" style="width:200px;height:40px" '
      'data-tg="swipe:swiped" data-tg-swipe="h|1|0.4">x</div>',
    );
    addTearDown(
      hydrate(
        actions(['swiped']),
        root: root,
        features: const [GesturesFeature()],
      ),
    );
    final row = root.querySelector('#row')!;
    pointer(row, 'pointerdown', 100, 20);
    pointer(row, 'pointermove', 90, 20);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    pointer(row, 'pointerup', 85, 20);
    expect((row as web.HTMLElement).style.getPropertyValue('--tg-x'), '0px');
    await Future<void>.delayed(const Duration(milliseconds: 260));
    expect(calls, isEmpty);
  });

  test('drag reports dx/dy; double tap; long press', () async {
    final root = mount(
      '<div id="d" data-tg="drag:moved" data-tg-drag="f|0|10">d</div>'
      '<div id="t" data-tg="dtap:liked;long:menu">t</div>',
    );
    addTearDown(
      hydrate(
        actions(['moved', 'liked', 'menu']),
        root: root,
        features: const [GesturesFeature()],
      ),
    );
    final d = root.querySelector('#d')!;
    pointer(d, 'pointerdown', 10, 10);
    pointer(d, 'pointermove', 40, 30);
    pointer(d, 'pointermove', 60, 50);
    pointer(d, 'pointerup', 60, 50);
    expect(calls, ['moved(50~40)']);
    expect((d as web.HTMLElement).style.getPropertyValue('--tg-x'), '50px');

    final t = root.querySelector('#t')!;
    for (var i = 0; i < 2; i++) {
      pointer(t, 'pointerdown', 5, 5);
      pointer(t, 'pointerup', 5, 5);
    }
    expect(calls.last, 'liked(null)');

    pointer(t, 'pointerdown', 5, 5);
    await Future<void>.delayed(const Duration(milliseconds: 560));
    expect(calls.last, 'menu(null)');
    pointer(t, 'pointerup', 5, 5);
  });

  test('tap down and up report where inside the element, up not after a '
      'drag, Enter at the middle', () {
    final root = mount(
      '<div id="a" tabindex="0" style="width:100px;height:60px" '
      'data-tg="tapd:down;tapu:up">a</div>'
      '<div id="b" style="width:100px;height:60px" '
      'data-tg="tapu:up;drag:moved" data-tg-drag="f|0|10">b</div>'
      '<div id="c" style="width:100px;height:60px" data-tg="tapu:up">'
      '<input type="checkbox"></div>',
    );
    addTearDown(
      hydrate(
        actions(['down', 'up', 'moved']),
        root: root,
        features: const [GesturesFeature()],
      ),
    );
    final a = root.querySelector('#a')!;
    final r = a.getBoundingClientRect();
    final x = r.left + 30, y = r.top + 20;
    pointer(a, 'pointerdown', x, y);
    expect(calls, ['down(30~20)']);
    pointer(a, 'pointerup', x + 2, y + 1);
    expect(calls, ['down(30~20)', 'up(32~21)']);

    // A drag is not a tap.
    calls.clear();
    final b = root.querySelector('#b')!;
    final rb = b.getBoundingClientRect();
    pointer(b, 'pointerdown', rb.left + 10, rb.top + 10);
    pointer(b, 'pointermove', rb.left + 50, rb.top + 10);
    pointer(b, 'pointerup', rb.left + 50, rb.top + 10);
    expect(calls, ['moved(40~0)']);

    // A tap on a native control inside is the control's.
    calls.clear();
    final box = root.querySelector('input')!;
    pointer(box, 'pointerdown', 5, 5);
    pointer(box, 'pointerup', 5, 5);
    expect(calls, isEmpty);

    // Enter on the focused element: its middle.
    calls.clear();
    a.dispatchEvent(
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: 'Enter', bubbles: true, cancelable: true),
      ),
    );
    expect(calls, ['up(${(r.width / 2).round()}~${(r.height / 2).round()})']);
  });

  test('a tap on a native control inside is the control\'s: no double tap '
      '(a checkbox in a cell that edits on double click)', () {
    final root = mount(
      '<div id="c" data-tg="dtap:edit"><span>7</span>'
      '<input type="checkbox"></div>',
    );
    addTearDown(
      hydrate(
        actions(['edit']),
        root: root,
        features: const [GesturesFeature()],
      ),
    );
    final cell = root.querySelector('#c')!;
    final box = root.querySelector('input')!;
    void tap(web.Element on) {
      pointer(on, 'pointerdown', 5, 5);
      pointer(on, 'pointerup', 5, 5);
    }

    tap(cell);
    tap(box);
    tap(box);
    expect(calls, isEmpty);
    tap(cell);
    tap(cell);
    expect(calls, ['edit(null)'], reason: 'the cell itself still double taps');
  });

  test('onPanEnd (4th drag field 1): the release velocity and positions, '
      'zero after a pause; the arrows end at the center', () async {
    final root = mount(
      // The translate thor_ui gives an element that follows the finger.
      '<div id="p" tabindex="0" style="width:100px;height:60px;'
      'translate:var(--tg-x, 0px) var(--tg-y, 0px)" '
      'data-tg="drag:ended" data-tg-drag="f|1|10|1">p</div>',
    );
    addTearDown(
      hydrate(
        actions(['ended']),
        root: root,
        features: const [GesturesFeature()],
      ),
    );
    final p = root.querySelector('#p')! as web.HTMLElement;
    final r = p.getBoundingClientRect();
    final x0 = r.left + 10, y0 = r.top + 10;
    List<double> details() => [
      for (final n in calls.last.split('(')[1].split(')')[0].split('~'))
        double.parse(n),
    ];

    // A quick flick to the right: fast along x, still along y. The element
    // follows the finger and snaps back; the local position is from where
    // it rests, as Flutter's widget never moved.
    pointer(p, 'pointerdown', x0, y0);
    for (var i = 1; i <= 4; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      pointer(p, 'pointermove', x0 + 10.0 * i, y0);
    }
    pointer(p, 'pointerup', x0 + 40, y0);
    var d = details();
    expect(d, hasLength(6));
    expect(d[0], greaterThan(300), reason: 'vx in px/s: ${calls.last}');
    expect(d[0], lessThanOrEqualTo(8000));
    expect(d[1], 0);
    expect(d.sublist(2), [50, 10, (x0 + 40).roundToDouble(), y0.round()]);

    // A pause before letting go reads as no speed.
    pointer(p, 'pointerdown', x0, y0);
    pointer(p, 'pointermove', x0 + 30, y0 + 20);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    pointer(p, 'pointerup', x0 + 30, y0 + 20);
    d = details();
    expect(d.sublist(0, 2), [0, 0]);
    expect(d.sublist(2, 4), [40, 30]);

    // The keyboard: no velocity, at the element's center.
    p.dispatchEvent(
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: 'ArrowRight', bubbles: true),
      ),
    );
    final c = p.getBoundingClientRect();
    expect(details(), [
      0,
      0,
      50,
      30,
      (c.left + 50).roundToDouble(),
      (c.top + 30).roundToDouble(),
    ]);
  });

  test('keyboard: Delete dismisses, arrows drag, + zooms', () async {
    final root = mount(
      '<div id="s" tabindex="0" data-tg="swipe:swiped" data-tg-swipe="h|1|0.4">s</div>'
      '<div id="d" tabindex="0" data-tg="drag:moved" data-tg-drag="h|1|10">d</div>'
      '<div id="z" tabindex="0" data-tg="scale:zoomed" data-tg-scale="1|3|0|0.25">z</div>',
    );
    addTearDown(
      hydrate(
        actions(['swiped', 'moved', 'zoomed']),
        root: root,
        features: const [GesturesFeature()],
      ),
    );
    void key(String id, String k) => root
        .querySelector('#$id')!
        .dispatchEvent(
          web.KeyboardEvent(
            'keydown',
            web.KeyboardEventInit(key: k, bubbles: true, cancelable: true),
          ),
        );
    key('d', 'ArrowRight');
    key('d', 'ArrowUp'); // horizontal only: ignored
    key('z', '+');
    key('s', 'Delete');
    await Future<void>.delayed(const Duration(milliseconds: 260));
    expect(calls, ['moved(10~0)', 'zoomed(1.25)', 'swiped(start)']);
  });

  test('onDragUpdate: one call per frame with the movement since the last, '
      'then the end; the element stays put', () async {
    final root = mount(
      '<div id="e" style="width:6px;height:30px" data-tx="3" '
      'data-tg="dragu:live;drag:done" data-tg-drag="h|1|10">e</div>',
    );
    addTearDown(
      hydrate(
        actions(['live', 'done']),
        root: root,
        features: const [GesturesFeature()],
      ),
    );
    final e = root.querySelector('#e')! as web.HTMLElement;
    Future<void> frame() {
      final c = Completer<void>();
      web.window.requestAnimationFrame(((num _) => c.complete()).toJS);
      return c.future;
    }

    pointer(e, 'pointerdown', 10, 10);
    for (var x = 12.0; x <= 30; x += 2) {
      pointer(e, 'pointermove', x, 11);
    }
    expect(calls, isEmpty, reason: 'coalesced into the next frame');
    await frame();
    expect(calls, ['live(3~20~0)']);
    pointer(e, 'pointermove', 25.25, 11);
    pointer(e, 'pointermove', 24.5, 11);
    await frame();
    expect(calls.last, 'live(3~-5~0)');
    pointer(e, 'pointermove', 40, 11);
    pointer(e, 'pointerup', 40, 11);
    expect(calls.skip(2), ['live(3~15~0)', 'done(3~30~0)']);
    expect(e.style.getPropertyValue('--tg-x'), '', reason: 'no translate');
    await frame();
    expect(calls, hasLength(4), reason: 'the flushed frame does not repeat');

    calls.clear();
    e.dispatchEvent(
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(
          key: 'ArrowLeft',
          bubbles: true,
          cancelable: true,
        ),
      ),
    );
    expect(calls, ['live(3~-10~0)', 'done(3~-10~0)']);
  });
}
