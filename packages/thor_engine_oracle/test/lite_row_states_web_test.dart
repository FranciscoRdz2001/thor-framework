@TestOn('browser')
library;

// The lite runtime (not the dart2js oracle) with its real row parts in a
// real DOM: what `row.watch` does to a row whose state has another structure
// or a swapped root. The sources come from the thor_engine package as the
// test server serves them; they are sewn like `liteBundle` does.
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

Future<String> _get(String path) async {
  final res = await web.window
      .fetch(
        Uri.base.resolve('packages/thor_engine/lite/$path').toString().toJS,
      )
      .toDart;
  return (await res.text().toDart).toDart;
}

const _state = r'''
window.calls = [];
thor.def('S', ($) => {
  const items = $.state('items', ['a']);
  return {
    items: () => items.value,
    key: (i) => i,
    kind: (i) => (i === 'b' ? 1 : 0),
    set: (v) => { calls.push('set:' + v); },
    save: (v) => { calls.push('save:' + v); },
    add: () => { if (!items.value.includes('b')) items.value = [...items.value, 'b']; },
  };
});
''';

void main() {
  late web.HTMLElement root;

  setUpAll(() async {
    final runtime = await _get('runtime.js');
    final parts = [
      for (final p in ['lists', 'row_states']) await _get('parts/$p.js'),
    ];
    final js = runtime.replaceFirst('// @thor-lite-parts', parts.join('\n'));
    root = web.document.createElement('div') as web.HTMLElement
      ..innerHTML =
          // Variant 1 has another structure under the same root
          // (an <input> becomes a <select>): its attributes hold the key.
          '''
<ul id="a" data-tl="S.items" data-tlk="S.key">
<li data-tk="a" data-tvf="S.kind" data-tvi="0"><div><input data-t-on="change:S.set~a" data-tx="a"></div></li>
<template data-tlt="S.items"><li data-tvf="S.kind" data-tvi="0"><div><input data-t-on="change:S.set~{{key}}" data-tx="{{key}}"></div></li>
<template data-tvft="S.kind" data-i="1"><li><div><select data-t-on="change:S.set~{{key}}" data-tx="{{key}}" aria-label="{{key}}"><option>x</option></select></div></li></template></template>
</ul>
<ul id="b" data-tl="S.items" data-tlk="S.key">
<li data-tk="a"><form data-tvf="S.kind" data-tvi="0" data-t-on="submit:S.set" data-tx="a"><input></form></li>
<template data-tlt="S.items"><li><form data-tvf="S.kind" data-tvi="0" data-t-on="submit:S.set" data-tx="{{key}}"><input></form></li>
<template data-tvft="S.kind" data-i="1"><form data-t-on="submit:S.save" data-tx="{{key}}"><input><button>ok</button></form></template></template>
</ul>
<ul id="c" data-tl="S.items" data-tlk="S.key">
<li data-tk="a"><form data-tvf="S.kind" data-tvi="0" data-t-on="submit:S.set" data-tx="a"><input></form></li>
<template data-tlt="S.items"><li><form data-tvf="S.kind" data-tvi="0" data-t-on="submit:S.set" data-tx="{{key}}"><input></form></li>
<template data-tvft="S.kind" data-i="1"><form><input><button>ok</button></form></template></template>
</ul>
'''
              .toJS;
    web.document.body!.append(root);
    final script = web.document.createElement('script')
      ..textContent = '$js\n$_state';
    web.document.head!.append(script);
    // The runtime starts in a microtask; the first event creates the state.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    (web.window as JSObject)
        .getProperty<JSObject>('thor'.toJS)
        .callMethod('use'.toJS, 'S'.toJS);
  });

  tearDownAll(() => root.remove());

  Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 30));

  void add() => (web.window as JSObject)
      .getProperty<JSObject>('thor'.toJS)
      .callMethod<JSObject>('use'.toJS, 'S'.toJS)
      .callMethod('add'.toJS);

  test('a row state with another structure gets its key everywhere', () async {
    add();
    await tick();
    final row = root.querySelector('#a [data-tk="b"]')!;
    final select = row.querySelector('select')!;
    expect(select.getAttribute('data-tx'), 'b');
    expect(select.getAttribute('data-t-on'), 'change:S.set~b');
    expect(select.getAttribute('aria-label'), 'b');
    expect((row.outerHTML as JSString).toDart.contains('{{key}}'), isFalse);
  });

  test(
    "a swapped row root keeps its own handler, not the prototype's",
    () async {
      add();
      await tick();
      final form = root.querySelector('#b [data-tk="b"] form')!;
      expect(form.getAttribute('data-t-on'), 'submit:S.save');
      expect(form.getAttribute('data-tx'), 'b');
      final calls = (web.window as JSObject).getProperty<JSArray>('calls'.toJS);
      final before = calls.length;
      form.dispatchEvent(
        web.Event('submit', web.EventInit(bubbles: true, cancelable: true)),
      );
      await tick();
      expect(calls.getProperty<JSString>(before.toJS).toDart, 'save:b');
    },
  );

  test("a swapped row root without a handler drops the prototype's", () async {
    add();
    await tick();
    final form = root.querySelector('#c [data-tk="b"] form')!;
    expect(form.hasAttribute('data-t-on'), isFalse);
    expect(form.hasAttribute('data-tx'), isFalse);
    expect(form.querySelector('button'), isNotNull);
  });
}
