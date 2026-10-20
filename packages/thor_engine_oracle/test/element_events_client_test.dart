@TestOn('browser')
library;

// The dart2js engine's ElementEventsFeature: hover, focus and `<details>`
// toggles as balanced pairs (the lite engine's part does the same, checked
// in test/e2e/checks/lite_widgets_check.mjs).
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:test/test.dart';
import 'package:thor_engine_oracle/client.dart';
import 'package:web/web.dart' as web;

web.HTMLElement mount(String html) {
  final root = web.document.createElement('div') as web.HTMLElement;
  root.innerHTML = html.toJS;
  web.document.body!.append(root);
  // ignore: unnecessary_lambdas
  addTearDown(() => root.remove());
  return root;
}

void pointer(web.Element on, String type, {web.Node? related, String? kind}) {
  final init = JSObject()
    ..['bubbles'] = true.toJS
    ..['pointerType'] = (kind ?? 'mouse').toJS
    ..['relatedTarget'] = related as JSAny?;
  on.dispatchEvent(
    (globalContext['PointerEvent']! as JSFunction).callAsConstructor<web.Event>(
      type.toJS,
      init,
    ),
  );
}

void main() {
  test('enter/leave: children and nested regions do not flicker', () {
    final log = <String>[];
    final root = mount('''
<div id="a" data-t-ev="enter:a;leave:b"><i id="c1"></i><i id="c2"></i></div>
<div id="out"></div>''');
    final off = hydrate(
      [
        Action('a', (_) => log.add('enter')),
        Action('b', (_) => log.add('leave')),
      ],
      root: root,
      features: const [ElementEventsFeature()],
    );
    addTearDown(off);
    final a = root.querySelector('#a')!;
    final c1 = root.querySelector('#c1')!;
    final c2 = root.querySelector('#c2')!;
    final out = root.querySelector('#out')!;
    pointer(c1, 'pointerover', related: out);
    pointer(c1, 'pointerout', related: c2);
    pointer(c2, 'pointerover', related: c1);
    expect(log, ['enter'], reason: 'moving between children is no exit');
    pointer(c2, 'pointerout', related: out);
    pointer(out, 'pointerover', related: c2);
    expect(log, ['enter', 'leave']);
    pointer(a, 'pointerout');
    expect(log, ['enter', 'leave'], reason: 'an exit with no enter is silent');
    pointer(c1, 'pointerover', kind: 'touch');
    expect(log, ['enter', 'leave'], reason: 'a finger never hovers');
  });

  test('focus and toggle report true/false once per change', () async {
    final log = <String>[];
    final root = mount('''
<div id="f" data-t-ev="focus:f"><input id="i1"><input id="i2"></div>
<input id="o">
<details id="d" data-t-ev="toggle:t"><summary>s</summary>c</details>''');
    final off = hydrate(
      [
        Action('f', (a) => log.add('focus:$a')),
        Action('t', (a) => log.add('toggle:$a')),
      ],
      root: root,
      features: const [ElementEventsFeature()],
    );
    addTearDown(off);
    (root.querySelector('#i1')! as web.HTMLElement).focus();
    (root.querySelector('#i2')! as web.HTMLElement).focus();
    expect(log, ['focus:true'], reason: 'between two inner inputs: no change');
    (root.querySelector('#o')! as web.HTMLElement).focus();
    expect(log, ['focus:true', 'focus:false']);
    log.clear();
    final d = root.querySelector('#d')! as web.HTMLDetailsElement;
    d
      ..open = true
      ..open = false
      ..open = true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(log, ['toggle:true'], reason: 'a burst ends on the real state');
    d.open = false;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(log, ['toggle:true', 'toggle:false']);
  });

  test('an accordion closing one tile and opening another reports the close '
      'first, whatever order the browser sends the toggles in', () async {
    final log = <String>[];
    final root = mount(
      '''
<details id="a" name="g" open data-t-ev="toggle:t" data-tx="a"><summary>a</summary>c</details>
<details id="b" name="g" data-t-ev="toggle:t" data-tx="b"><summary>b</summary>c</details>
<details id="c" data-t-ev="toggle:t" data-tx="c"><summary>c</summary>c</details>''',
    );
    final off = hydrate(
      [Action('t', (a) => log.add(a ?? ''))],
      root: root,
      features: const [ElementEventsFeature()],
    );
    addTearDown(off);
    final a = root.querySelector('#a')! as web.HTMLDetailsElement;
    final b = root.querySelector('#b')! as web.HTMLDetailsElement;
    void toggle(web.Element el) => el.dispatchEvent(web.Event('toggle'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    log.clear();

    // The browser has already closed `a` by the time `b` reports opening
    // (the events of Firefox and WebKit come the other way round).
    b.open = true;
    expect(a.open, isFalse, reason: 'the browser closes the sibling');
    toggle(b);
    toggle(a);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(log, ['a~false', 'b~true']);

    // Back, with the events in the other order.
    log.clear();
    a.open = true;
    toggle(a);
    toggle(b);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(log, ['b~false', 'a~true']);

    // A tile outside a group reports at once and alone.
    log.clear();
    (root.querySelector('#c')! as web.HTMLDetailsElement).open = true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(log, ['c~true']);
  });

  // What the lite engine's part does for what arrives after the load: the state a
  // tile has before the user changes it is read on the click, so a late tile
  // reports right.
  group('tiles and regions that arrive after the load', () {
    late web.HTMLElement root;
    late List<String> log;

    void start() {
      log = [];
      root = mount('<div id="host"></div>');
      addTearDown(
        hydrate(
          [
            Action('t', (a) => log.add('t:$a')),
            Action('f', (a) => log.add('f:$a')),
          ],
          root: root,
          features: const [ElementEventsFeature()],
        ),
      );
    }

    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 60));

    test(
      'a tile that arrives open reports nothing; its first close does',
      () async {
        start();
        root.querySelector('#host')!.innerHTML =
            '<details id="n" open data-t-ev="toggle:t"><summary>n</summary>x</details>'
                .toJS;
        await settle();
        expect(log, isEmpty);
        (root.querySelector('#n > summary')! as web.HTMLElement).click();
        await settle();
        expect(log, ['t:false']);
      },
    );

    test('a tile that arrives closed reports true when opened', () async {
      start();
      root.querySelector('#host')!.innerHTML =
          '<details id="n" data-t-ev="toggle:t"><summary>n</summary>x</details>'
              .toJS;
      (root.querySelector('#n > summary')! as web.HTMLElement).click();
      await settle();
      expect(log, ['t:true']);
    });

    test('late tiles of an exclusive group: the close comes first', () async {
      start();
      root.querySelector('#host')!.innerHTML =
          '<details id="a" name="g" open data-t-ev="toggle:t" data-tx="a"><summary>a</summary>x</details>'
                  '<details id="b" name="g" data-t-ev="toggle:t" data-tx="b"><summary>b</summary>x</details>'
              .toJS;
      await settle();
      expect(log, isEmpty);
      (root.querySelector('#b > summary')! as web.HTMLElement).click();
      await settle();
      expect(log, ['t:a~false', 't:b~true']);
      log.clear();
      (root.querySelector('#a > summary')! as web.HTMLElement).click();
      await settle();
      expect(log, ['t:b~false', 't:a~true']);
    });

    test('a region that was replaced still reports enter and leave', () {
      start();
      root.querySelector('#host')!.innerHTML =
          '<div id="r" data-t-ev="enter:f;leave:f"><i id="c"></i></div><b id="out"></b>'
              .toJS;
      final r = root.querySelector('#r')!;
      final copy = r.cloneNode(true) as web.Element;
      r.replaceWith(copy);
      final out = root.querySelector('#out')!;
      pointer(copy.querySelector('#c')!, 'pointerover', related: out);
      expect(log, ['f:null']);
      pointer(copy, 'pointerout', related: out);
      expect(log, ['f:null', 'f:null']);
    });

    test(
      'a focused button that leaves the page leaves the state consistent',
      () async {
        start();
        root.querySelector('#host')!.innerHTML =
            '<div id="r" data-t-ev="focus:f"><button id="b">b</button></div><input id="o">'
                .toJS;
        (root.querySelector('#b')! as web.HTMLElement).focus();
        expect(log, ['f:true']);
        root.querySelector('#b')!.remove();
        (root.querySelector('#o')! as web.HTMLElement).focus();
        await settle();
        // The browser fires no focusout for a removed element: the region is
        // told it lost the focus when it is next gained elsewhere or the
        // engine finds the focus is not inside it any more.
        expect(log.last, isNot('f:true'), reason: log.join(','));
      },
    );
  });
}
