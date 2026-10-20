@TestOn('browser')
library;

// the `.when(open:)` rule in a browser, nested `<details>` included.
import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thor_ui/src/foundation/style_registry.dart';
import 'package:web/web.dart' as web;

void main() {
  test('the nearest details decides, not an outer open one', () {
    final style = web.document.createElement('style')
      ..textContent =
          '$thorLayerOrder'
          '${ThorStyleRegistry.renderRule('x', const {'width': '10px'}, conditions: const [
            ConditionalCss(CssCondition.detailsOpen, {'width': '20px'}),
          ])}';
    final host = web.document.createElement('div')
      ..innerHTML =
          '<details open><summary><i class="x" id="head"></i></summary>'
                  '<i class="x" id="body"></i>'
                  '<details><summary><i class="x" id="inner-head"></i>'
                  '</summary></details>'
                  '<details open><summary><i class="x" id="inner-open"></i>'
                  '</summary></details>'
                  '</details>'
                  '<details><summary><i class="x" id="closed"></i></summary>'
                  '</details>'
              .toJS;
    web.document.head!.append(style);
    web.document.body!.append(host);
    try {
      String width(String id) {
        final el = host.querySelector('#$id')! as web.HTMLElement;
        el.style.display = 'block';
        return web.window.getComputedStyle(el).width;
      }

      expect(width('head'), '20px');
      expect(width('body'), '20px');
      expect(width('inner-head'), '10px', reason: 'its own details is closed');
      expect(width('inner-open'), '20px');
      expect(width('closed'), '10px');
    } finally {
      style.remove();
      host.remove();
    }
  });
}
