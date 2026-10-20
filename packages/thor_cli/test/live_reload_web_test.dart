@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:test/test.dart';
import 'package:thor_cli/src/live_reload.dart';
import 'package:web/web.dart' as web;

// An iframe page's path (`about:srcdoc`): the keys it uses.
const _path = 'srcdoc';
const _form = '$liveReloadFormKey$_path';
const _state = '$liveReloadStateKey$_path';
const _scroll = '$liveReloadScrollKey$_path';

web.Storage get storage => web.window.sessionStorage;

/// Before the script: an EventSource the test drives (`__es.fire('reload')`)
/// and a count of the `pointerdown`s the page gets.
const _fakes =
    '<script>'
    'window.EventSource=class{constructor(){window.__es=this;window.__opened=(window.__opened||0)+1;'
    'this.l={}}close(){window.__closed=(window.__closed||0)+1}'
    'addEventListener(t,f){this.l[t]=f}fire(t,d){this.l[t]({data:d})}};'
    'window.__pointers=0;'
    "addEventListener('pointerdown',()=>window.__pointers++);"
    '</script>';

/// A page like the dev proxy serves: [head], [body], the script.
String page(String body, {String head = ''}) =>
    '<!DOCTYPE html><html><head>$_fakes$head</head><body>$body'
    '$liveReloadScript</body></html>';

/// Loads [html] in an iframe and waits for it.
Future<web.HTMLIFrameElement> open(String html) async {
  final frame = web.document.createElement('iframe') as web.HTMLIFrameElement;
  // ignore: unnecessary_lambdas
  addTearDown(() => frame.remove());
  final loaded = frame.onLoad.first;
  frame.srcdoc = html.toJS;
  web.document.body!.append(frame);
  await loaded;
  return frame;
}

/// What the dev proxy sends on a change, then the reloaded page.
Future<void> reload(web.HTMLIFrameElement frame) async {
  final loaded = frame.onLoad.first;
  _win(frame)
      .getProperty<JSObject>('__es'.toJS)
      .callMethod<JSAny?>('fire'.toJS, 'reload'.toJS);
  await loaded.timeout(const Duration(seconds: 5));
}

JSObject _win(web.HTMLIFrameElement f) => f.contentWindow! as JSObject;
web.Document _doc(web.HTMLIFrameElement f) => f.contentDocument!;
T _el<T extends web.Element>(web.HTMLIFrameElement f, String selector) =>
    _doc(f).querySelector(selector)! as T;

/// The [i]th field named q.
web.HTMLInputElement _q(web.HTMLIFrameElement f, int i) =>
    _doc(f).querySelectorAll('[name=q]').item(i)! as web.HTMLInputElement;

void main() {
  setUp(() {
    for (final k in [_form, _state, _scroll]) {
      storage.removeItem(k);
    }
  });

  test('fields the user changed come back, with the focus', () async {
    final frame = await open(
      page(
        '<input id="a" value="from server">'
        '<input name="q"><input name="q">'
        '<input id="pw" type="password">'
        '<input id="hid" type="hidden" value="h">'
        '<input id="bound" data-tt="S.label">'
        '<input type="checkbox" name="c" value="1">'
        '<input type="radio" name="r" value="x" checked>'
        '<input type="radio" name="r" value="y">'
        '<select id="s"><option>x</option><option>y</option></select>'
        '<textarea id="t"></textarea>'
        '<input id="untouched" value="default">',
      ),
    );
    _el<web.HTMLInputElement>(frame, '#a').value = 'typed';
    _q(frame, 1).value = 'two';
    _el<web.HTMLInputElement>(frame, '#pw').value = 'secret';
    _el<web.HTMLInputElement>(frame, '#bound').value = 'engine';
    _el<web.HTMLInputElement>(frame, '[name=c]').checked = true;
    _el<web.HTMLInputElement>(frame, '[value=y]').checked = true;
    _el<web.HTMLSelectElement>(frame, '#s').selectedIndex = 1;
    final t = _el<web.HTMLTextAreaElement>(frame, '#t')
      ..value = 'hello world'
      ..focus();
    t.setSelectionRange(2, 5);

    await reload(frame);

    String value(String s) => _el<web.HTMLInputElement>(frame, s).value;
    expect(value('#a'), 'typed');
    expect(_q(frame, 0).value, '', reason: 'the first q was not edited');
    expect(_q(frame, 1).value, 'two');
    expect(value('#pw'), '', reason: 'passwords never go to storage');
    expect(value('#hid'), 'h');
    expect(value('#bound'), '', reason: 'a Watch fills it from the state');
    expect(value('#untouched'), 'default');
    expect(_el<web.HTMLInputElement>(frame, '[name=c]').checked, isTrue);
    expect(_el<web.HTMLInputElement>(frame, '[value=y]').checked, isTrue);
    expect(_el<web.HTMLInputElement>(frame, '[value=x]').checked, isFalse);
    expect(_el<web.HTMLSelectElement>(frame, '#s').selectedIndex, 1);
    final area = _el<web.HTMLTextAreaElement>(frame, '#t');
    expect(area.value, 'hello world');
    expect(_doc(frame).activeElement?.id, 't');
    expect((area.selectionStart, area.selectionEnd), (2, 5));
    expect(storage.getItem(_form), isNull, reason: 'taken once');
  });

  test('a password is never written to storage', () async {
    final frame = await open(page('<input id="pw" type="password">'));
    _el<web.HTMLInputElement>(frame, '#pw')
      ..value = 'secret'
      ..focus();
    await reload(frame);
    // Nothing was stored (a stored field the page can't fill would stay).
    expect(storage.getItem(_form), isNull);
  });

  test('a field that changed kind or disappeared is skipped', () async {
    storage.setItem(
      _form,
      '{"f":{"#a":true,"#b":"x","#gone":"y","#s":[true]},"a":"#gone"}',
    );
    final frame = await open(
      page(
        '<input id="a" value="keep"><input id="b">'
        '<select id="s"><option>x</option><option>y</option></select>',
      ),
    );
    expect(_el<web.HTMLInputElement>(frame, '#a').value, 'keep');
    expect(_el<web.HTMLInputElement>(frame, '#b').value, 'x');
    expect(
      _el<web.HTMLSelectElement>(frame, '#s').selectedIndex,
      0,
      reason: 'the options changed',
    );
  });

  test('a page with nothing to fill keeps them for the next one', () async {
    // The error page of a failed build: no fields, no engine.
    storage
      ..setItem(_form, '{"f":{"#a":"typed"}}')
      ..setItem(_state, 'engine snapshot');
    final error = await open(page('<pre>compile error</pre>'));
    expect(storage.getItem(_form), isNotNull);
    await reload(error);
    // Its own reload wrote nothing over them.
    expect(storage.getItem(_form), '{"f":{"#a":"typed"}}');
    expect(storage.getItem(_state), 'engine snapshot');
    final fixed = await open(page('<input id="a">'));
    expect(_el<web.HTMLInputElement>(fixed, '#a').value, 'typed');
    expect(storage.getItem(_form), isNull);
    // Corrupt data is dropped, not thrown.
    storage.setItem(_form, '{oops');
    await open(page('<input id="a">'));
    expect(storage.getItem(_form), isNull);
  });

  test('the engine snapshot is stored before the reload', () async {
    final frame = await open(
      page(
        '',
        head:
            '<script>window.__thorDevState=()=>'
            "'{\"v\":1,\"s\":{\"Counter.count\":3}}'</script>",
      ),
    );
    await reload(frame);
    expect(storage.getItem(_state), '{"v":1,"s":{"Counter.count":3}}');
    // A throwing engine (or a full storage) does not stop the reload.
    final broken = await open(
      page('', head: "<script>window.__thorDevState=()=>{throw 'x'}</script>"),
    );
    await reload(broken);
  });

  test('with a snapshot the page stays hidden until the engine restored '
      'it, and the engine loads now', () async {
    storage.setItem(_state, '{"v":1,"s":{}}');
    final frame = await open(
      page('<p>x</p>', head: '<script data-thor-engine="e.js"></script>'),
    );
    final html = _doc(frame).documentElement! as web.HTMLElement;
    expect(html.style.visibility, 'hidden');
    expect(_win(frame).getProperty<JSNumber>('__pointers'.toJS).toDartInt, 1);
    _doc(frame).dispatchEvent(web.CustomEvent('thor:hydrated'));
    expect(html.style.visibility, 'hidden', reason: 'until the next frame');
    await _nextFrame(frame);
    expect(html.style.visibility, '');
  });

  test('without an engine, or without a snapshot, nothing is hidden', () async {
    storage.setItem(_state, '{"v":1,"s":{}}');
    final noEngine = await open(page('<p>x</p>'));
    expect(
      (_doc(noEngine).documentElement! as web.HTMLElement).style.visibility,
      '',
    );
    storage.removeItem(_state);
    final noSnapshot = await open(
      page('<p>x</p>', head: '<script data-thor-engine="e.js"></script>'),
    );
    expect(
      (_doc(noSnapshot).documentElement! as web.HTMLElement).style.visibility,
      '',
    );
    expect(
      _win(noSnapshot).getProperty<JSNumber>('__pointers'.toJS).toDartInt,
      0,
    );
  });

  test('an engine that never hydrates shows the page anyway', () async {
    storage.setItem(_state, '{"v":1,"s":{}}');
    final frame = await open(
      page('<p>x</p>', head: '<script data-thor-engine="e.js"></script>'),
    );
    final html = _doc(frame).documentElement! as web.HTMLElement;
    expect(html.style.visibility, 'hidden');
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    expect(html.style.visibility, '');
  });

  test(
    'a hidden tab holds no connection (HTTP/1.1 allows 6 per host)',
    () async {
      final frame = await open(page('<p>x</p>'));
      final win = _win(frame);
      int count(String k) => win.getProperty<JSNumber?>(k.toJS)?.toDartInt ?? 0;
      expect(count('__opened'), 1);
      void show(bool hidden) {
        win.callMethod<JSAny?>(
          'eval'.toJS,
          'Object.defineProperty(document,"hidden",{value:$hidden,'
                  'configurable:true});'
                  'document.dispatchEvent(new Event("visibilitychange"))'
              .toJS,
        );
      }

      show(true);
      expect(count('__closed'), 1);
      show(true);
      expect(count('__closed'), 1, reason: 'nothing left to close');
      show(false);
      expect(count('__opened'), 2);
      show(false);
      expect(count('__opened'), 2, reason: 'one connection at a time');
    },
  );
}

Future<void> _nextFrame(web.HTMLIFrameElement frame) {
  final done = Completer<void>();
  (frame.contentWindow!).requestAnimationFrame(
    ((JSNumber _) => done.complete()).toJS,
  );
  // One more: ours may run before the page's in the same frame.
  return done.future.then((_) => Future<void>.delayed(Duration.zero));
}
