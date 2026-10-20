@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thor_ui/src/foundation/style_registry.dart';
import 'package:thor_ui/src/widgets/backdrop.dart';
import 'package:web/web.dart' as web;

// A real `<dialog>` opened with `showModal()`, with the rule and the panel
// styles thor writes (a drawer taller than the window): the page stops
// scrolling under it and the panel scrolls on its own, with no JS.

web.HTMLDialogElement? dialog;
web.Element? style;
web.Element? tall;

void main() {
  setUp(() {
    style = web.document.createElement('style')
      ..textContent =
          '$thorLayerOrder'
          '${ThorStyleRegistry.renderRule('lock', const {}, conditions: const [modalScrollLock])}'
          '${ThorStyleRegistry.renderRule('drawer', {'box-sizing': 'border-box', 'height': '300px', 'max-height': '300px', 'padding': '0', 'overflow-y': 'auto', ...modalOverscroll})}';
    tall = web.document.createElement('div')
      ..setAttribute('style', 'height:5000px');
    dialog = (web.document.createElement('dialog') as web.HTMLDialogElement)
      ..className = 'drawer'
      ..innerHTML = '<div style="height:2000px">long list</div>'.toJS;
    web.document.head!.append(style!);
    web.document.body!.append(tall!);
    web.document.body!.append(dialog!);
  });

  tearDown(() {
    dialog!.close();
    dialog!.remove();
    tall!.remove();
    style!.remove();
    web.window.scrollTo(0.toJS, 0);
  });

  String root(String prop) => web.window
      .getComputedStyle(web.document.documentElement!)
      .getPropertyValue(prop);

  test('the page scrolls while nothing is modal', () {
    expect(root('overflow'), 'visible');
    web.window.scrollBy(0.toJS, 100);
    expect(web.window.scrollY, 100);
  });

  test('a modal dialog locks the document scroll, and only while open', () {
    dialog!.showModal();
    expect(dialog!.matches(':modal'), isTrue);
    expect(root('overflow'), 'hidden');
    expect(root('overscroll-behavior'), contains('none'));
    expect(root('scrollbar-gutter'), contains('stable'));
    dialog!.close();
    expect(root('overflow'), 'visible');
  });

  test('a non-modal dialog (show()) does not lock the page', () {
    dialog!.show();
    expect(dialog!.matches(':modal'), isFalse);
    expect(root('overflow'), 'visible');
  });

  test('a panel taller than the window scrolls inside, contained', () {
    dialog!.showModal();
    final d = dialog!;
    expect(d.scrollHeight, greaterThan(d.clientHeight));
    final cs = web.window.getComputedStyle(d);
    expect(cs.getPropertyValue('overflow-y'), 'auto');
    expect(cs.getPropertyValue('overscroll-behavior'), contains('contain'));
    d.scrollTop = 150;
    expect(d.scrollTop, 150);
    expect(web.window.scrollY, 0);
  });
}
