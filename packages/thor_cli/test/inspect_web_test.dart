@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:test/test.dart';
import 'package:thor_cli/src/dev/inspect.dart';
import 'package:web/web.dart' as web;

/// Records where the page tries to go instead of leaving (`location.href`
/// to `vscode://` would open the editor).
const _fakes =
    '<script>window.__opened=[];'
    "Object.defineProperty(window,'__go',{value:u=>window.__opened.push(u)});"
    '</script>';

const _body =
    '<main data-thor="Column" data-thor-src="/app/lib/modules/home/pages/home_page.dart:12:1">'
    '<section data-thor="Container" '
    'data-thor-src="/app/lib/widgets/card.dart:30:3">'
    '<button id="b" data-thor="FilledButton" '
    'data-thor-src="/app/lib/widgets/card.dart:30:3">Buy</button>'
    '</section><p id="plain">no source</p>'
    '<i id="odd" data-thor="Text" '
    'data-thor-src="/app/my dir/a#b?.dart:4:2">odd</i></main>';

String page(InspectEditor editor) =>
    '<!DOCTYPE html><html><head>$_fakes</head><body>$_body'
    '${inspectScript(editor).replaceAll('location.href=u', 'window.__go(u)')}'
    '</body></html>';

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

void altClick(web.HTMLIFrameElement f, String id, {bool alt = true}) {
  final doc = f.contentDocument!;
  final win = f.contentWindow!;
  final event = web.MouseEvent(
    'click',
    web.MouseEventInit(bubbles: true, cancelable: true, altKey: alt, view: win),
  );
  doc.getElementById(id)!.dispatchEvent(event);
}

List<String> opened(web.HTMLIFrameElement f) => (f.contentWindow! as JSObject)
    .getProperty<JSArray<JSString>>('__opened'.toJS)
    .toDart
    .map((s) => s.toDart)
    .toList();

web.ShadowRoot? shadow(web.HTMLIFrameElement f) =>
    f.contentDocument!.querySelector('thor-inspect')?.shadowRoot;

void main() {
  test('Alt+click opens the nearest source and lists the chain', () async {
    final f = await open(page(InspectEditor.vscode));
    var clicks = 0;
    f.contentDocument!
        .getElementById('b')!
        .addEventListener('click', ((web.Event _) => clicks++).toJS);
    altClick(f, 'b');
    expect(opened(f), ['vscode://file/app/lib/widgets/card.dart:30:3']);
    // The app's own handler never runs: Alt+click belongs to the inspector.
    expect(clicks, 0);
    final links = shadow(f)!.querySelectorAll('nav a');
    // Same source twice (Container, FilledButton) is one row.
    expect(links.length, 2);
    expect(links.item(0)!.textContent, contains('lib/widgets/card.dart:30'));
    expect(
      links.item(1)!.textContent,
      contains('lib/modules/home/pages/home_page.dart:12'),
    );
  });

  test('a path with a space, # or ? is one link', () async {
    for (final editor in [InspectEditor.vscode, InspectEditor.cursor]) {
      final f = await open(page(editor));
      altClick(f, 'odd');
      expect(opened(f), [
        '${editor.name}://file/app/my%20dir/a%23b%3F.dart:4:2',
      ]);
    }
  });

  test('a plain click is the app\'s', () async {
    final f = await open(page(InspectEditor.vscode));
    altClick(f, 'b', alt: false);
    expect(opened(f), isEmpty);
    expect(shadow(f), isNull);
  });

  test('other editors and none', () async {
    final idea = await open(page(InspectEditor.idea));
    altClick(idea, 'b');
    expect(opened(idea).single, startsWith('idea://open?file=%2Fapp%2Flib'));
    final none = await open(page(InspectEditor.none));
    altClick(none, 'b');
    expect(opened(none), isEmpty);
    // The panel still shows where it is.
    expect(shadow(none)!.querySelectorAll('nav a').length, 2);
  });

  test('THOR_EDITOR names', () {
    expect(InspectEditor.parse(null), InspectEditor.vscode);
    expect(InspectEditor.parse(' Cursor '), InspectEditor.cursor);
    expect(InspectEditor.parse('emacs'), InspectEditor.vscode);
  });
}
