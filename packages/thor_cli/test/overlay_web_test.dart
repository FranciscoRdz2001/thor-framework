// The overlay in a real browser with hostile and endless input:
// an error that repeats every frame must not freeze the page.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:test/test.dart';
import 'package:thor_cli/src/dev/inspect.dart' show InspectEditor;
import 'package:thor_cli/src/dev/overlay_script.dart';
import 'package:web/web.dart' as web;

Map<String, Object?> entry(String path, {String message = 'm'}) => {
  'phase': 'diagnostics',
  'title': 't',
  'severity': 'error',
  'message': message,
  'where': '',
  'at': {
    'file': 'lib/x.dart',
    'path': path,
    'line': 3,
    'column': 5,
    'code': [
      [3, 'code </script><b>x</b>'],
    ],
  },
  'frames': const <Object?>[],
};

Future<web.HTMLIFrameElement> open(
  List<Map<String, Object?>> entries, {
  bool ui = true,
}) async {
  final frame = web.document.createElement('iframe') as web.HTMLIFrameElement;
  // ignore: unnecessary_lambdas
  addTearDown(() => frame.remove());
  final loaded = frame.onLoad.first;
  frame.srcdoc =
      '<!DOCTYPE html><html><body><p>hola</p>${overlayScript(entries, InspectEditor.vscode, ui)}'
          .toJS;
  web.document.body!.append(frame);
  await loaded;
  return frame;
}

web.ShadowRoot root(web.HTMLIFrameElement f) =>
    f.contentDocument!.querySelector('thor-dev-overlay')!.shadowRoot!;

void fire(web.HTMLIFrameElement f, String message) {
  final win = f.contentWindow! as JSObject;
  win.callMethod(
    'dispatchEvent'.toJS,
    web.ErrorEvent('error', web.ErrorEventInit(message: message)),
  );
}

void main() {
  test(
    'with the ui off nothing is drawn and the list is on the window',
    () async {
      final f = await open([entry('/a.dart')], ui: false);
      final win = f.contentWindow! as JSObject;
      expect(f.contentDocument!.querySelector('thor-dev-overlay'), isNull);
      expect(
        (win.getProperty('__thorDevErrors'.toJS)! as JSArray).length,
        greaterThanOrEqualTo(1),
      );
      var events = 0;
      int? seen;
      win.callMethod(
        'addEventListener'.toJS,
        'thor:dev-errors'.toJS,
        ((web.CustomEvent e) {
          events++;
          seen = (e.detail! as JSArray).length;
        }).toJS,
      );
      fire(f, 'boom');
      expect(f.contentDocument!.querySelector('thor-dev-overlay'), isNull);
      expect((win.getProperty('__thorDevErrors'.toJS)! as JSArray).length, 2);
      expect(events, 1, reason: 'the host hears about the new error');
      expect(seen, 2);
    },
  );

  test('with the ui off a clean page still reports browser errors', () async {
    final f = await open(const [], ui: false);
    final win = f.contentWindow! as JSObject;
    fire(f, 'late');
    expect(f.contentDocument!.querySelector('thor-dev-overlay'), isNull);
    expect((win.getProperty('__thorDevErrors'.toJS)! as JSArray).length, 1);
  });

  test('a path with a space, # and ? makes one working link', () async {
    final f = await open([entry('/Users/me/my app/a#b?.dart')]);
    final href = root(f).querySelector('.loc a')!.getAttribute('href')!;
    expect(href, 'vscode://file/Users/me/my%20app/a%23b%3F.dart:3:5');
  });

  test('markup in a message and a path is text and a plain link', () async {
    final f = await open([
      entry('/a"><img src=x>.dart', message: '<img src=x onerror=1>'),
    ]);
    final r = root(f);
    expect(r.querySelector('img'), isNull);
    expect(
      r.querySelector('.loc a')!.getAttribute('href'),
      startsWith('vscode:'),
    );
  });

  test('the same browser error again is one entry', () async {
    final f = await open([entry('/a.dart')]);
    for (var i = 0; i < 500; i++) {
      fire(f, 'boom');
    }
    // The server's entry and one for the browser error.
    expect(root(f).querySelectorAll('.msg').length, 2);
  });

  test('errors that are all different are cut, and it stays fast', () async {
    final f = await open([entry('/a.dart')]);
    final clock = Stopwatch()..start();
    for (var i = 0; i < 2000; i++) {
      fire(f, 'boom $i');
    }
    expect(clock.elapsed, lessThan(const Duration(seconds: 5)));
    expect(root(f).querySelectorAll('.msg').length, lessThanOrEqualTo(51));
  });
}
