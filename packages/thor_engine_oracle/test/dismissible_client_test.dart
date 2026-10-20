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
  web.Element el,
  String type,
  double x,
  double y, {
  int id = 1,
  String kind = 'touch',
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
      ),
    ),
  );
}

web.KeyboardEvent key(
  web.Element el,
  String k, {
  bool shift = false,
  bool alt = false,
}) {
  final e = web.KeyboardEvent(
    'keydown',
    web.KeyboardEventInit(
      key: k,
      shiftKey: shift,
      altKey: alt,
      bubbles: true,
      cancelable: true,
    ),
  );
  el.dispatchEvent(e);
  return e;
}

/// A row as thor_ui's Dismissible writes it (the CSS is what its class says).
String row(
  String id, {
  String cfg = 'h|0.4|0.4|-|-|40|60',
  String ids = 'dismissed:Inbox.dismissed',
  String dir = 'ltr',
  String extra = '',
}) =>
    '<div id="$id" dir="$dir" tabindex="0" data-tx="$id" data-t-dm="$ids" '
    'data-t-dm-cfg="$cfg" style="display:grid;overflow:clip;width:200px;height:40px">'
    '<div data-t-dm-bg="startToEnd" aria-hidden="true" style="grid-area:1/1;visibility:hidden">A</div>'
    '<div data-t-dm-bg="endToStart" aria-hidden="true" style="grid-area:1/1;visibility:hidden">B</div>'
    '<div id="$id-body" data-t-dm-body style="grid-area:1/1;translate:var(--t-dm-x,0px) var(--t-dm-y,0px)">Mensaje $extra</div>'
    '</div>';

void main() {
  late List<String> calls;
  late Future<bool> Function(String) confirmWith;
  List<Binding> actions(List<String> ids) => [
    for (final id in ids) Action(id, (arg) => calls.add('$id($arg)')),
  ];
  ThorMember member(String id) => ThorMember(
    id,
    () {},
    call: (arg) {
      calls.add('$id($arg)');
      return confirmWith('$arg');
    },
  );

  Future<void> start(web.HTMLElement root) async {
    const feature = DismissibleFeature();
    feature.collect(root, member, [], {});
    addTearDown(
      hydrate(
        actions(['Inbox.dismissed']),
        root: root,
        features: const [DismissibleFeature()],
      ),
    );
  }

  setUp(() {
    calls = [];
    confirmWith = (_) async => true;
  });

  // The Dismissible's root (`mount` returns the box around the rows).
  web.Element row1(web.Element mounted) =>
      mounted.querySelector('[data-t-dm]')!;

  web.HTMLElement body(web.Element root, String id) =>
      root.querySelector('#$id-body')! as web.HTMLElement;

  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  // Waits for [ok] (a loaded machine only makes it slower, not wrong).
  Future<void> until(bool Function() ok, {int ms = 2000}) async {
    final end = DateTime.now().millisecondsSinceEpoch + ms;
    while (!ok() && DateTime.now().millisecondsSinceEpoch < end) {
      await wait(10);
    }
  }

  void drag(web.Element el, double from, double to, {double y = 20}) {
    pointer(el, 'pointerdown', from, y);
    final step = to > from ? 10.0 : -10.0;
    for (var x = from + step; step > 0 ? x <= to : x >= to; x += step) {
      pointer(el, 'pointermove', x, y);
    }
    pointer(el, 'pointerup', to, y);
  }

  test('a drag past the threshold slides out, collapses, then reports the '
      'direction', () async {
    final root = mount(row('m1'));
    await start(root);
    final b = body(root, 'm1');
    pointer(b, 'pointerdown', 180, 20);
    for (var x = 170.0; x >= 60; x -= 10) {
      pointer(b, 'pointermove', x, 20);
    }
    expect(b.style.getPropertyValue('--t-dm-x'), '-120px');
    expect(b.hasAttribute('data-t-dm-drag'), isTrue);
    // The background of that direction is shown, the other is not.
    final shown = root.querySelectorAll('[data-t-dm-on]');
    expect(shown.length, 1);
    expect(
      (shown.item(0)! as web.Element).getAttribute('data-t-dm-bg'),
      'endToStart',
    );
    pointer(b, 'pointerup', 60, 20);
    expect(b.hasAttribute('data-t-dm-drag'), isFalse);
    expect(b.hasAttribute('data-t-dm-out'), isTrue);
    expect(b.style.getPropertyValue('--t-dm-x'), '-200px');
    expect(calls, isEmpty, reason: 'it is still sliding out');
    await until(() => row1(root).hasAttribute('data-t-dm-gone'));
    expect(row1(root).hasAttribute('data-t-dm-gone'), isTrue);
    expect(calls, isEmpty, reason: 'it is still collapsing');
    await until(() => calls.isNotEmpty);
    expect(calls, ['Inbox.dismissed(m1~endToStart)']);
  });

  test('a short drag snaps back and calls nothing', () async {
    final root = mount(row('m1'));
    await start(root);
    final b = body(root, 'm1');
    pointer(b, 'pointerdown', 100, 20);
    pointer(b, 'pointermove', 90, 20);
    pointer(b, 'pointermove', 70, 20);
    await wait(150);
    pointer(b, 'pointerup', 70, 20);
    expect(b.style.getPropertyValue('--t-dm-x'), '0px');
    await wait(150);
    expect(b.hasAttribute('data-t-dm-out'), isFalse);
    expect(root.querySelectorAll('[data-t-dm-on]').length, 0);
    expect(calls, isEmpty);
    expect(row1(root).hasAttribute('data-t-dm-gone'), isFalse);
  });

  test('a quick fling dismisses below the threshold', () async {
    final root = mount(row('m1'));
    await start(root);
    final b = body(root, 'm1');
    pointer(b, 'pointerdown', 100, 20);
    pointer(b, 'pointermove', 88, 20);
    pointer(b, 'pointermove', 60, 20);
    pointer(b, 'pointerup', 60, 20);
    expect(b.hasAttribute('data-t-dm-out'), isTrue);
    await until(() => calls.isNotEmpty);
    expect(calls, ['Inbox.dismissed(m1~endToStart)']);
  });

  test('a direction that is not allowed does not move', () async {
    final root = mount(row('m1', cfg: 'h|0.4|-|-|-|40|60'));
    await start(root);
    final b = body(root, 'm1');
    // toward the start: not allowed
    drag(b, 180, 60);
    expect(b.style.getPropertyValue('--t-dm-x'), '0px');
    await wait(100);
    expect(calls, isEmpty);
    // toward the end: allowed
    drag(b, 20, 160);
    await until(() => calls.isNotEmpty);
    expect(calls, ['Inbox.dismissed(m1~startToEnd)']);
  });

  test('right-to-left flips startToEnd and endToStart', () async {
    final root = mount(row('m1', dir: 'rtl'));
    await start(root);
    final b = body(root, 'm1');
    drag(b, 20, 160);
    await until(() => calls.isNotEmpty);
    expect(calls, ['Inbox.dismissed(m1~endToStart)']);
  });

  test('vertical dismissals use the y axis and up/down', () async {
    final root = mount(
      row(
        'm1',
        cfg: 'v|-|-|0.4|0.4|40|60',
      ).replaceFirst('width:200px;height:40px', 'width:200px;height:100px'),
    );
    await start(root);
    final b = body(root, 'm1');
    pointer(b, 'pointerdown', 20, 80);
    for (var y = 70.0; y >= 20; y -= 10) {
      pointer(b, 'pointermove', 20, y);
    }
    expect(b.style.getPropertyValue('--t-dm-y'), '-60px');
    pointer(b, 'pointerup', 20, 20);
    await until(() => calls.isNotEmpty);
    expect(calls, ['Inbox.dismissed(m1~up)']);
  });

  test('movement along the other axis is the page\'s: no drag', () async {
    final root = mount(row('m1'));
    await start(root);
    final b = body(root, 'm1');
    pointer(b, 'pointerdown', 100, 5);
    pointer(b, 'pointermove', 102, 30);
    pointer(b, 'pointermove', 60, 32);
    pointer(b, 'pointerup', 60, 32);
    expect(b.hasAttribute('data-t-dm-drag'), isFalse);
    expect(b.style.getPropertyValue('--t-dm-x'), isEmpty);
    await wait(100);
    expect(calls, isEmpty);
  });

  test('confirm false brings the row back, true dismisses it (a Future, '
      'and a plain bool)', () async {
    final root = mount(
      row('m1', ids: 'dismissed:Inbox.dismissed;confirm:Inbox.confirm'),
    );
    await start(root);
    final b = body(root, 'm1');
    confirmWith = (_) async => false;
    drag(b, 180, 40);
    await until(() => calls.isNotEmpty);
    expect(calls, ['Inbox.confirm(m1~endToStart)']);
    await until(() => !b.hasAttribute('data-t-dm-out'));
    expect(b.style.getPropertyValue('--t-dm-x'), '0px');
    expect(b.hasAttribute('data-t-dm-out'), isFalse);
    expect(row1(root).hasAttribute('data-t-dm-gone'), isFalse);
    expect(calls, hasLength(1), reason: 'not dismissed');
    // Now it agrees (after a delay: the row waits for the answer).
    calls.clear();
    confirmWith = (_) async {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      return true;
    };
    drag(b, 180, 40);
    await until(() => calls.length == 2);
    expect(calls, [
      'Inbox.confirm(m1~endToStart)',
      'Inbox.dismissed(m1~endToStart)',
    ]);
  });

  test('without a resize the state is told right after it slid out', () async {
    final root = mount(row('m1', cfg: 'h|0.4|0.4|-|-|40|0'));
    await start(root);
    drag(body(root, 'm1'), 180, 40);
    await until(() => calls.isNotEmpty);
    expect(calls, ['Inbox.dismissed(m1~endToStart)']);
    expect(row1(root).hasAttribute('data-t-dm-gone'), isFalse);
  });

  test(
    'Delete and Backspace dismiss the focused row; focus moves on',
    () async {
      final root = mount(row('a') + row('b'));
      await start(root);
      final a = root.querySelector('#a')! as web.HTMLElement;
      final b = root.querySelector('#b')! as web.HTMLElement;
      a.focus();
      expect(key(a, 'Delete').defaultPrevented, isTrue);
      await until(() => calls.isNotEmpty);
      expect(calls, ['Inbox.dismissed(a~endToStart)']);
      expect(
        web.document.activeElement,
        b,
        reason: 'focus goes to the next row',
      );
      calls.clear();
      key(b, 'Backspace');
      await until(() => calls.isNotEmpty);
      expect(calls, ['Inbox.dismissed(b~endToStart)']);
    },
  );

  test(
    'Shift+arrow dismisses toward that side; a plain arrow does nothing',
    () async {
      final root = mount(row('a') + row('b', cfg: 'h|0.4|-|-|-|40|60'));
      await start(root);
      final a = root.querySelector('#a')! as web.HTMLElement;
      final b = root.querySelector('#b')! as web.HTMLElement;
      expect(key(a, 'ArrowRight').defaultPrevented, isFalse);
      key(a, 'ArrowRight', shift: true);
      // Not allowed there: nothing.
      expect(key(b, 'ArrowLeft', shift: true).defaultPrevented, isFalse);
      await until(() => calls.isNotEmpty);
      await wait(150);
      expect(calls, ['Inbox.dismissed(a~startToEnd)']);
    },
  );

  test('a text field inside keeps its keys and its pointer', () async {
    final root = mount(row('a', extra: '<input id="field" value="x">'));
    await start(root);
    final field = root.querySelector('#field')! as web.HTMLElement;
    expect(key(field, 'Delete').defaultPrevented, isFalse);
    expect(key(field, 'ArrowLeft', shift: true).defaultPrevented, isFalse);
    pointer(field, 'pointerdown', 150, 20);
    pointer(field, 'pointermove', 60, 20);
    pointer(field, 'pointerup', 60, 20);
    await wait(100);
    expect(calls, isEmpty);
    expect(body(root, 'a').hasAttribute('data-t-dm-out'), isFalse);
  });

  test('a drag does not click, a tap does', () async {
    final root = mount(row('a'));
    await start(root);
    var clicks = 0;
    final b = body(root, 'a');
    b.addEventListener('click', ((web.Event _) => clicks++).toJS);
    pointer(b, 'pointerdown', 100, 20);
    pointer(b, 'pointermove', 90, 20);
    pointer(b, 'pointermove', 80, 20);
    await wait(100);
    pointer(b, 'pointerup', 80, 20);
    b.click();
    expect(clicks, 0, reason: 'the click that ends a drag is swallowed');
    await wait(100);
    b.click();
    expect(clicks, 1);
  });

  test('a row that is already leaving ignores a second dismissal', () async {
    final root = mount(row('a'));
    await start(root);
    final a = root.querySelector('#a')! as web.HTMLElement;
    key(a, 'Delete');
    key(a, 'Delete');
    key(a, 'Backspace');
    await until(() => calls.isNotEmpty);
    await wait(200);
    expect(calls, ['Inbox.dismissed(a~endToStart)']);
  });
}
