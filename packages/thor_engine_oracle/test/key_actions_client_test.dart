// Shortcuts + Actions and Focus(onKeyEvent:) in the dart2js oracle: the
// same markup and scenarios as the lite engine's
// test/e2e/checks/lite_key_actions_check.mjs, with the same results.
@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thor_engine_oracle/client.dart';
import 'package:thor_ui/src/engine/engine_script.dart';
import 'package:web/web.dart' as web;

web.HTMLElement mount(String html) {
  final root = web.document.createElement('div') as web.HTMLElement;
  root.innerHTML = html.toJS;
  web.document.body!.append(root);
  // ignore: unnecessary_lambdas
  addTearDown(() => root.remove());
  return root;
}

web.KeyboardEvent keydown(
  String key,
  String code, {
  bool meta = false,
  bool control = false,
  bool shift = false,
  bool repeat = false,
}) => web.KeyboardEvent(
  'keydown',
  web.KeyboardEventInit(
    key: key,
    code: code,
    metaKey: meta,
    ctrlKey: control,
    shiftKey: shift,
    repeat: repeat,
    bubbles: true,
    cancelable: true,
  ),
);

const _tree =
    '<div id="outer" data-tks="m+s>K.outerSave;+escape>K.outerEsc;+x>K.outerX" data-tai="Save>K.save">'
    '<div id="shell" data-tsi="m+s>Save;+enter>Open;+escape>Close;+delete>Gone;c+1>Pass" data-tai="Open>K.open;Gone>;Pass>!">'
    '<div id="inner" data-tai="Save>K.innerSave"><span id="deep" tabindex="0">deep</span></div>'
    '<span id="page" tabindex="0">page</span><input id="field" type="text">'
    '<div id="keys" tabindex="0" data-tke="K.onKey">keys <span id="child" tabindex="0">child</span></div>'
    '</div></div>';

const _root =
    '<div id="app" data-tsi="m+k>Search" data-tai="Search>K.search" data-tke="K.onKey">'
    '<span id="a" tabindex="0">a</span></div>';

void main() {
  late List<String> log;

  // The state of the lite check: each method logs; onKey answers by the
  // key's label (Enter handled, x skips the rest, anything else ignored).
  List<Binding> actions() => [
    for (final n in [
      'save',
      'innerSave',
      'open',
      'outerSave',
      'outerEsc',
      'outerX',
      'search',
    ])
      Action('K.$n', (_) => log.add(n)),
    Action('K.onKey', (a) {
      final e = KeyEvent.decode(a!);
      final kind = e is KeyRepeatEvent ? 1 : 0;
      final meta = HardwareKeyboard.instance.isMetaPressed ? ':meta' : '';
      log.add('key:${e.logicalKey.keyLabel}:${e.character ?? ''}:$kind$meta');
      return switch (e.logicalKey.keyLabel) {
        'Enter' => KeyEventResult.handled,
        'x' => KeyEventResult.skipRemainingHandlers,
        _ => KeyEventResult.ignored,
      };
    }),
  ];

  setUp(() => log = []);

  // A keydown on [id] (focused first), or on <body> with nothing focused:
  // what the state logged, and whether the key was stopped.
  (String, bool) press(web.Element root, String? id, web.KeyboardEvent e) {
    (web.document.activeElement as web.HTMLElement?)?.blur();
    final target = id == null
        ? web.document.body!
        : root.querySelector('#$id')! as web.HTMLElement;
    if (id != null) target.focus();
    target.dispatchEvent(e);
    final out = (log.join(','), e.defaultPrevented);
    log.clear();
    return out;
  }

  test('Shortcuts, Actions and onKeyEvent, like the lite part', () {
    final root = mount(_tree);
    addTearDown(
      hydrate(actions(), root: root, features: const [ShortcutsFeature()]),
    );
    expect(press(root, 'page', keydown('s', 'KeyS', meta: true)), (
      'save',
      true,
    ));
    expect(
      press(root, 'deep', keydown('s', 'KeyS', meta: true)).$1,
      'innerSave',
      reason: 'the Actions nearest the focus wins',
    );
    expect(press(root, 'page', keydown('Enter', 'Enter')).$1, 'open');
    expect(
      press(root, 'page', keydown('Escape', 'Escape')).$1,
      'outerEsc',
      reason: 'no action: the key goes on',
    );
    expect(press(root, 'page', keydown('Delete', 'Delete')), (
      '',
      true,
    ), reason: 'DoNothingAction');
    expect(
      press(root, 'page', keydown('1', 'Digit1', control: true)),
      ('', false),
      reason: 'DoNothingAction(consumesKey: false)',
    );
    expect(press(root, 'page', keydown('ы', 'KeyS', meta: true)), (
      'save',
      true,
    ));
    expect(press(root, 'field', keydown('a', 'KeyA')).$1, '');
    expect(press(root, 'field', keydown('Enter', 'Enter')).$1, 'open');

    expect(press(root, 'keys', keydown('Enter', 'Enter')), (
      'key:Enter::0',
      true,
    ));
    expect(press(root, 'child', keydown('s', 'KeyS', meta: true)), (
      'key:s:s:0:meta,save',
      true,
    ));
    expect(press(root, 'keys', keydown('x', 'KeyX')), ('key:x:x:0', false));
    expect(press(root, 'keys', keydown('ArrowUp', 'ArrowUp', repeat: true)), (
      'key:ArrowUp::1',
      false,
    ));
    expect(
      press(root, 'keys', keydown('X', 'KeyX', shift: true)).$1,
      'key:x:X:0',
    );
    expect(press(root, 'keys', keydown('ы', 'KeyS')).$1, 'key:s:ы:0');
  });

  test('nothing focused: the outermost Shortcuts answer, not onKeyEvent', () {
    final root = mount(_root);
    addTearDown(
      hydrate(actions(), root: root, features: const [ShortcutsFeature()]),
    );
    expect(press(root, null, keydown('k', 'KeyK', meta: true)), (
      'search',
      true,
    ));
    expect(
      press(root, 'a', keydown('k', 'KeyK', meta: true)).$1,
      'key:k:k:0:meta,search',
    );
  });

  test('the loader replays a key a Shortcuts or onKeyEvent saw before the '
      'engine', () {
    final root = mount(_tree);
    web.document.head!.append(
      web.document.createElement('script')
        ..setAttribute(engineSrcAttr, 'data:text/javascript,')
        ..textContent = engineLoaderScript,
    );
    (root.querySelector('#page')! as web.HTMLElement).focus();
    root.querySelector('#page')!.dispatchEvent(keydown('Enter', 'Enter'));
    (root.querySelector('#keys')! as web.HTMLElement).focus();
    root.querySelector('#keys')!.dispatchEvent(keydown('q', 'KeyQ'));
    addTearDown(
      hydrate(actions(), root: root, features: const [ShortcutsFeature()]),
    );
    expect(log, ['open', 'key:q:q:0']);
  });

  test('skipWithTextSelection leaves the key to the browser while the page '
      'has selected text', () {
    final root = mount(
      '<div id="box" data-tks="mt+c>K.save;m+x>K.outerX">'
      '<p id="text">some text</p><span id="a" tabindex="0">a</span></div>',
    );
    addTearDown(
      hydrate(actions(), root: root, features: const [ShortcutsFeature()]),
    );
    final selection = web.window.getSelection()!;
    // ignore: unnecessary_lambdas
    addTearDown(() => selection.removeAllRanges());
    selection.removeAllRanges();
    expect(press(root, 'a', keydown('c', 'KeyC', meta: true)), ('save', true));
    selection.selectAllChildren(root.querySelector('#text')!);
    // The browser copies: not run, not prevented.
    expect(press(root, 'a', keydown('c', 'KeyC', meta: true)), ('', false));
    // A shortcut without the flag still runs over a selection.
    expect(press(root, 'a', keydown('x', 'KeyX', meta: true)), (
      'outerX',
      true,
    ));
  });
}
