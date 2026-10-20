@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';
import 'package:web/web.dart' as web;

// A `SnackBar` inside an ancestor with `container-type` (a `LayoutScope`, what
// `StudioBench` and any app with container queries adds) used to be measured
// against that box: CSS containment makes the container the containing block
// of `position: fixed`, so the bar sat at the end of a tall column, far from
// the window. As a `popover="manual"` in the top layer (snack.js) it is not.

void main() {
  late web.HTMLElement host;

  /// Renders [bar] as the page ships it (`ThorApp`: styles, markup and the
  /// snack script) and puts it in a tall, contained column.
  Future<web.Element> mount(Widget bar) async {
    final html = await renderDocument(ThorApp(child: bar));
    final doc = web.DOMParser().parseFromString(html.toJS, 'text/html');
    final styles = doc.head!.querySelectorAll('style');
    for (var i = 0; i < styles.length; i++) {
      web.document.head!.append(web.document.importNode(styles.item(i)!, true));
      addTearDown(() => web.document.head!.lastElementChild?.remove());
    }
    host = web.document.createElement('div') as web.HTMLElement
      ..setAttribute(
        'style',
        'container-type:inline-size;width:600px;height:3000px;'
            'position:relative',
      );
    web.document.body!.append(host);
    addTearDown(() => host.remove());
    final nodes = doc.body!.children;
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes.item(i)!;
      if (node.localName == 'script') {
        // Scripts made by the parser do not run: make a live one.
        final live = web.document.createElement('script')
          ..textContent = node.textContent;
        host.append(live);
      } else {
        host.append(web.document.importNode(node, true));
      }
    }
    return host.querySelector('[data-snack]')!;
  }

  Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 50));

  test(
    'a shown SnackBar in a container-type ancestor is in the viewport',
    () async {
      final bar = await mount(const SnackBar(content: Text('Saved')));
      await tick();
      expect(bar.getAttribute('popover'), 'manual');
      expect(bar.matches(':popover-open'), isTrue);
      final r = bar.getBoundingClientRect();
      expect(r.bottom, lessThanOrEqualTo(web.window.innerHeight));
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.height, greaterThan(0));
    },
  );

  test(
    'the state switching the attribute opens and closes the popover',
    () async {
      final bar = await mount(
        const SnackBar(visible: false, content: Text('Saved')),
      );
      await tick();
      expect(bar.getAttribute('data-snack'), 'off');
      expect(bar.matches(':popover-open'), isFalse);
      // What a `Watch` variant patch does.
      bar.setAttribute('data-snack', 'on');
      await tick();
      // The attribute alone opens it; the slide in is the variant's class,
      // which the patch swaps in a page (not what is simulated here).
      expect(bar.matches(':popover-open'), isTrue);
      bar.setAttribute('data-snack', 'off');
      await tick();
      expect(bar.matches(':popover-open'), isFalse);
    },
  );

  test(
    'a fixed SnackBar spans the window; a floating one keeps its look',
    () async {
      final fixed = await mount(const SnackBar(content: Text('Saved')));
      await tick();
      final fr = fixed.getBoundingClientRect();
      expect(fr.width, web.window.innerWidth);
      expect(fr.left, 0);
      expect(fr.bottom, web.window.innerHeight);
      expect(web.window.getComputedStyle(fixed).borderTopLeftRadius, '0px');
      host.remove();

      final floating = await mount(
        const SnackBar(
          content: Text('Saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await tick();
      final r = floating.getBoundingClientRect();
      expect(r.width, lessThan(web.window.innerWidth - 31));
      expect(
        r.left + r.width / 2,
        closeTo(web.window.innerWidth / 2, 1),
        reason: 'centered',
      );
      expect(web.window.getComputedStyle(floating).borderTopLeftRadius, '4px');
      expect(r.bottom, lessThan(web.window.innerHeight));
    },
  );
}
