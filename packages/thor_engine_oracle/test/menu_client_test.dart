@TestOn('browser')
library;

// The menu markup on the dart2js engine follows the lite `menu` part (the
// conformance compares the DOM): roles as a panel first opens, its items out
// of the Tab order while it is open.
import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thor_engine_oracle/client.dart';
import 'package:web/web.dart' as web;

void main() {
  late void Function()? undo;
  late web.HTMLElement box;

  setUp(() {
    box = web.document.createElement('div') as web.HTMLElement
      ..innerHTML =
          '<button id="t" popovertarget="m" aria-haspopup="menu">More</button>'
                  '<div id="m" popover="auto" data-t-menu="">'
                  '<button id="a" type="button">Copy</button>'
                  '<a id="b" href="#x">Help</a>'
                  '<button id="c" type="button" role="menuitemradio">Big'
                  '</button></div>'
              .toJS;
    web.document.body!.append(box);
    undo = const MenuFeature().install(web.document.body!, (_, _, [_]) => null);
  });
  tearDown(() {
    undo?.call();
    box.remove();
  });

  web.HTMLElement el(String id) =>
      web.document.getElementById(id)! as web.HTMLElement;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('a closed panel keeps the markup the server wrote', () {
    expect(el('m').hasAttribute('role'), isFalse);
    expect(el('a').hasAttribute('role'), isFalse);
  });

  test('opening makes it a menu and takes its items out of the Tab order, '
      'closing puts them back', () async {
    el('m').showPopover();
    await settle();
    expect(el('m').getAttribute('role'), 'menu');
    expect(el('a').getAttribute('role'), 'menuitem');
    expect(el('b').getAttribute('role'), 'menuitem');
    expect(el('c').getAttribute('role'), 'menuitemradio');
    expect(el('a').getAttribute('tabindex'), '-1');
    el('m').hidePopover();
    await settle();
    expect(el('m').getAttribute('role'), 'menu');
    expect(el('a').hasAttribute('tabindex'), isFalse);
  });
}
