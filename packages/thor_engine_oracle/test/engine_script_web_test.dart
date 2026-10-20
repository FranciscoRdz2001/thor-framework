@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thor_engine_oracle/client.dart';
import 'package:thor_ui/src/engine/engine_script.dart';
import 'package:web/web.dart' as web;

void main() {
  test('the deferred loader replays interactions made before hydration', () async {
    final root = web.document.createElement('div') as web.HTMLElement
      ..innerHTML =
          '<button id="add" data-t-on="click:add"><i>+</i></button>'
                  '<input id="sound" type="checkbox" data-t-on="change:sound">'
                  '<form id="f" data-t-on="submit:send"><button id="go">Go</button></form>'
              .toJS;
    web.document.body!.append(root);
    // ignore: unnecessary_lambdas
    addTearDown(() => root.remove());

    // The loader, as the page ships it (the script it would load is a no-op).
    final loader = web.document.createElement('script')
      ..setAttribute(engineSrcAttr, 'data:text/javascript,')
      ..textContent = engineLoaderScript;
    web.document.head!.append(loader);

    // Interactions before the engine exists.
    (root.querySelector('i')! as web.HTMLElement).click();
    final box = root.querySelector('#sound')! as web.HTMLInputElement;
    box.click(); // native toggle + change event
    expect(box.checked, isTrue);
    final submitted = web.SubmitEvent(
      'submit',
      web.SubmitEventInit(bubbles: true, cancelable: true),
    );
    root.querySelector('#f')!.dispatchEvent(submitted);
    expect(submitted.defaultPrevented, isTrue, reason: 'no navigation');

    var adds = 0, sends = 0;
    final sounds = <String?>[];
    hydrate([
      Action('add', (_) => adds++),
      Action('sound', sounds.add),
      Action('send', (_) => sends++),
    ], root: root);

    expect(adds, 1);
    expect(sounds, ['true']);
    expect(sends, 1);
    expect(box.checked, isTrue, reason: 'the replay must not toggle again');

    // After hydration the loader is out of the way: one run per click.
    (root.querySelector('i')! as web.HTMLElement).click();
    expect(adds, 2);
  });

  // The script the loader appended for [src], once it did.
  web.HTMLScriptElement? loaded(String src) =>
      web.document.head!.querySelector('script[src="$src"]')
          as web.HTMLScriptElement?;

  test('an interaction raises the engine download to high priority', () {
    const src = 'data:text/javascript,//p2-interaction';
    web.document.head!.append(
      web.document.createElement('script')
        ..setAttribute(engineSrcAttr, src)
        ..textContent = engineLoaderScript,
    );
    expect(loaded(src), isNull, reason: 'idle has not come yet');
    web.document.body!.dispatchEvent(
      web.PointerEvent(
        'pointerdown',
        web.PointerEventInit(bubbles: true, cancelable: true),
      ),
    );
    expect(loaded(src), isNotNull);
    expect(loaded(src)!.fetchPriority, 'high');
    // ignore: unnecessary_lambdas
    addTearDown(() => loaded(src)?.remove());
  });

  test('the idle load keeps the default priority (a preload in flight is '
      'not raised)', () async {
    const src = 'data:text/javascript,//p2-idle';
    web.document.head!.append(
      web.document.createElement('script')
        ..setAttribute(engineSrcAttr, src)
        ..textContent = engineLoaderScript,
    );
    final end = DateTime.now().add(const Duration(seconds: 20));
    while (loaded(src) == null && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(loaded(src), isNotNull, reason: 'the idle callback loads it');
    expect(loaded(src)!.fetchPriority, 'auto');
    // ignore: unnecessary_lambdas
    addTearDown(() => loaded(src)?.remove());
  });

  test('events on elements without engine handlers are not queued', () {
    final root = web.document.createElement('div') as web.HTMLElement
      ..innerHTML = '<button id="plain">x</button>'.toJS;
    web.document.body!.append(root);
    // ignore: unnecessary_lambdas
    addTearDown(() => root.remove());
    web.document.head!.append(
      web.document.createElement('script')
        ..setAttribute(engineSrcAttr, 'data:text/javascript,')
        ..textContent = engineLoaderScript,
    );
    var clicks = 0;
    root
        .querySelector('#plain')!
        .addEventListener('click', ((web.Event _) => clicks++).toJS);
    (root.querySelector('#plain')! as web.HTMLElement).click();
    hydrate(const [], root: root);
    expect(clicks, 1);
  });

  test('keys the engine handles are replayed as clones, others are not', () {
    final root = web.document.createElement('div') as web.HTMLElement
      ..innerHTML =
          '<input id="f" data-t-on="enter:send">'
                  '<div id="b" role="button" tabindex="0" data-t-on="click:tap"></div>'
                  '<input id="plain">'
              .toJS;
    web.document.body!.append(root);
    // ignore: unnecessary_lambdas
    addTearDown(() => root.remove());
    web.document.head!.append(
      web.document.createElement('script')
        ..setAttribute(engineSrcAttr, 'data:text/javascript,')
        ..textContent = engineLoaderScript,
    );
    web.KeyboardEvent press(String key, {bool meta = false}) =>
        web.KeyboardEvent(
          'keydown',
          web.KeyboardEventInit(
            key: key,
            metaKey: meta,
            bubbles: true,
            cancelable: true,
          ),
        );
    final replays = <String>[];
    web.document.addEventListener(
      'keydown',
      ((web.KeyboardEvent e) {
        if (!e.isTrusted) replays.add('${e.key}:${e.metaKey}');
      }).toJS,
      true.toJS,
    );

    final enter = press('Enter');
    root.querySelector('#f')!.dispatchEvent(enter);
    expect(enter.defaultPrevented, isTrue, reason: 'no form submit');
    final space = press(' ');
    root.querySelector('#b')!.dispatchEvent(space);
    expect(space.defaultPrevented, isTrue, reason: 'no page scroll');
    final letter = press('a');
    root.querySelector('#f')!.dispatchEvent(letter);
    final plain = press('Enter');
    root.querySelector('#plain')!.dispatchEvent(plain);
    expect(letter.defaultPrevented, isFalse);
    expect(plain.defaultPrevented, isFalse, reason: 'native behavior stays');

    replays.clear(); // the presses above were synthetic too
    var sends = 0, taps = 0;
    hydrate(
      [Action('send', (_) => sends++), Action('tap', (_) => taps++)],
      root: root,
      features: const [FormsFeature(), KeyboardFeature()],
    );
    expect(sends, 1);
    expect(taps, 1);
    expect(replays, ['Enter:false', ' :false'], reason: 'with their key');
  });

  // On the lite engine (and dart2js): the closest `data-t-on` that
  // handles the type wins, an ancestor is next when the closest does not.
  // The loader queues by the same rule, or a key it lets through would
  // submit the form natively while the engine, once loaded, would not.
  test('events bubble to the closest ancestor that handles their type', () {
    final root = web.document.createElement('div') as web.HTMLElement
      ..innerHTML =
          '<div id="w" data-t-on="enter:send;click:tap">'
                  '<input id="n" data-t-on="input:draft">'
                  '<button id="own" data-t-on="click:own">x</button>'
                  '</div>'
              .toJS;
    web.document.body!.append(root);
    // ignore: unnecessary_lambdas
    addTearDown(() => root.remove());
    web.document.head!.append(
      web.document.createElement('script')
        ..setAttribute(engineSrcAttr, 'data:text/javascript,')
        ..textContent = engineLoaderScript,
    );
    final enter = web.KeyboardEvent(
      'keydown',
      web.KeyboardEventInit(key: 'Enter', bubbles: true, cancelable: true),
    );
    root.querySelector('#n')!.dispatchEvent(enter);
    expect(enter.defaultPrevented, isTrue, reason: 'the ancestor handles it');
    (root.querySelector('#n')! as web.HTMLElement).click();
    (root.querySelector('#own')! as web.HTMLElement).click();

    var sends = 0, taps = 0, owns = 0;
    hydrate(
      [
        Action('send', (_) => sends++),
        Action('tap', (_) => taps++),
        Action('own', (_) => owns++),
        Action('draft', (_) => null),
      ],
      root: root,
      features: const [FormsFeature(), KeyboardFeature()],
    );
    expect(sends, 1);
    expect(taps, 1, reason: 'the click on the field reached the wrapper');
    expect(owns, 1, reason: 'the closest handler wins, not the wrapper');
  });
}
