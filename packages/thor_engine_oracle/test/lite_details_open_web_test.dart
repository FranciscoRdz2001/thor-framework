@TestOn('browser')
library;

// The lite runtime in a real DOM: a `Watch` whose states change the `open`
// attribute of a `<details>`. The base the runtime goes back to is what the
// server drew, not what the visitor had left it at.
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
thor.def('S', ($) => {
  const sec = $.state('sec', 0);
  return {
    sec: () => sec.value,
    go: (v) => { sec.value = +v; },
  };
});
''';

void main() {
  late web.HTMLElement root;

  setUpAll(() async {
    final js = (await _get(
      'runtime.js',
    )).replaceFirst('// @thor-lite-parts', '');
    root = web.document.createElement('div') as web.HTMLElement
      ..innerHTML =
          '<details id="d" open data-tv="S.sec" data-tp-1="|open|-">'
                  '<summary id="s">Style</summary>x</details>'
              .toJS;
    web.document.body!.append(root);
    final script = web.document.createElement('script')
      ..textContent = '$js\n$_state';
    web.document.head!.append(script);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    (web.window as JSObject)
        .getProperty<JSObject>('thor'.toJS)
        .callMethod('use'.toJS, 'S'.toJS);
  });

  tearDownAll(() => root.remove());

  Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 30));

  void go(int i) => (web.window as JSObject)
      .getProperty<JSObject>('thor'.toJS)
      .callMethod<JSObject>('use'.toJS, 'S'.toJS)
      .callMethod('go'.toJS, '$i'.toJS);

  test('a state goes back to the open the server drew, not the '
      'visitor\'s', () async {
    final d = root.querySelector('#d')! as web.HTMLDetailsElement;
    expect(d.open, isTrue);
    // The visitor closes the section the server drew open.
    (root.querySelector('#s')! as web.HTMLElement).click();
    await tick();
    expect(d.open, isFalse);
    go(1);
    await tick();
    expect(d.open, isFalse, reason: 'state 1 has no open');
    go(0);
    await tick();
    expect(d.open, isTrue, reason: 'state 0 is the one that draws it open');
  });
}
