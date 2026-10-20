@TestOn('vm')
library;

// MenuAnchor, MenuItemButton and SubmenuButton: a menu on the Popover API,
// the anchor named by CSS anchor positioning, items that close it natively.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

abstract class _ActionsMembers extends ThorState {
  @override
  String get $type => 'Actions';

  @override
  List<ThorMember> get $members {
    final s = this as _Actions;
    return [ThorMember('share', s.share, call: (_) => s.share())];
  }
}

class _Actions extends _ActionsMembers {
  void share() {}
}

final _actions = _Actions();

Future<String> _body(Widget w) async {
  final html = await renderDocument(ThorApp(child: w));
  final end = html.indexOf('<svg id="thor-sprite"');
  return html.substring(html.indexOf('<body'), end < 0 ? html.length : end);
}

Future<String> _doc(Widget w) => renderDocument(ThorApp(child: w));

int _count(String html, Pattern p) => p.allMatches(html).length;

void _noop() {}

void main() {
  setUpAll(initializeThorTests);

  group('MenuAnchor', () {
    final menu = MenuAnchor(
      builder: (context, controller, child) => TextButton(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        child: const Text('Account'),
      ),
      menuChildren: [
        MenuItemButton(onPressed: _actions.share, child: const Text('Share')),
        const MenuItemButton(href: '/orders', child: Text('Orders')),
      ],
    );

    test('the builder\'s button opens the popover natively', () async {
      final html = await _body(menu);
      // The anchor is the builder's own <button>, with the popover wiring
      // fused in: no wrapper around it.
      expect(
        html,
        matches(RegExp(r'^<body><button [^>]*popovertarget="t-menu\d*"')),
      );
      expect(html, contains('aria-haspopup="true"'));
      expect(html, contains('>Account</button>'));
      expect(_count(html, 'popover="auto"'), 1);
      final id = RegExp(r'popovertarget="([^"]+)"').firstMatch(html)![1]!;
      expect(html, contains('id="$id"'));
      final css = await _doc(menu);
      expect(css, contains('anchor-name: --$id'));
      expect(css, contains('position-anchor: --$id'));
      expect(css, contains('inset: auto'));
    });

    test(
      'the panel carries the items; a button item hides it natively',
      () async {
        final html = await _body(menu);
        final id = RegExp(r'id="(t-menu[^"]*)"').firstMatch(html)![1]!;
        expect(
          html,
          contains('popovertarget="$id" popovertargetaction="hide"'),
        );
        expect(html, contains('data-t-on="click:Actions.share"'));
        expect(html, contains('>Share</button>'));
      },
    );

    test(
      'a link item is an <a href>, and following it closes the menu',
      () async {
        final html = await _body(menu);
        expect(
          html,
          matches(RegExp(r'<a [^>]*href="/orders"[^>]*>Orders</a>')),
        );
        // No popovertarget on a link (it does nothing there): the panel's
        // handler closes it on a same-tab click, like Popover.
        expect(html, isNot(matches(RegExp(r'<a [^>]*popovertarget'))));
        expect(html, contains('onclick="if(!event.defaultPrevented'));
      },
    );

    test('closeOnNavigate: false leaves the handler out', () async {
      final html = await _body(
        MenuAnchor(
          closeOnNavigate: false,
          builder: (context, controller, child) =>
              const TextButton(onPressed: null, child: Text('x')),
          menuChildren: const [MenuItemButton(href: '/a', child: Text('A'))],
        ),
      );
      expect(html, isNot(contains('onclick')));
    });

    test('closeOnActivate: false keeps the menu open', () async {
      final html = await _body(
        MenuAnchor(
          id: 'm',
          builder: (context, controller, child) =>
              const TextButton(onPressed: null, child: Text('x')),
          menuChildren: [
            MenuItemButton(
              closeOnActivate: false,
              onPressed: _actions.share,
              child: const Text('Keep'),
            ),
          ],
        ),
      );
      expect(html, isNot(contains('popovertargetaction="hide"')));
    });

    test('without a builder, the child is the anchor', () async {
      final html = await _body(
        const MenuAnchor(
          id: 'c',
          menuChildren: [MenuItemButton(child: Text('A'))],
          child: TextButton(onPressed: null, child: Text('Menu')),
        ),
      );
      expect(html, contains('popovertarget="c"'));
      expect(html, contains('>Menu</button>'));
    });

    test('the builder gets the child it was given', () async {
      Widget? seen;
      await _body(
        MenuAnchor(
          id: 'c',
          menuChildren: const [],
          builder: (context, controller, child) {
            seen = child;
            return const TextButton(onPressed: null, child: Text('x'));
          },
          child: const Text('inner'),
        ),
      );
      expect(seen, isA<Text>());
    });

    test('a MenuItemButton without onPressed or href is disabled', () async {
      final html = await _body(
        const MenuAnchor(
          id: 'd',
          menuChildren: [MenuItemButton(child: Text('Off'))],
          child: TextButton(onPressed: null, child: Text('x')),
        ),
      );
      expect(html, matches(RegExp(r'<button [^>]*disabled[^>]*>Off</button>')));
    });

    test('icons: leading and trailing around the label', () async {
      final html = await _body(
        const MenuAnchor(
          id: 'i',
          menuChildren: [
            MenuItemButton(
              leadingIcon: Icon(Icons.add),
              trailingIcon: Icon(Icons.check),
              onPressed: _noop,
              child: Text('Add'),
            ),
          ],
          child: TextButton(onPressed: null, child: Text('x')),
        ),
      );
      expect(
        html,
        matches(RegExp(r'<svg[^>]*>.*</svg><span[^>]*>Add</span><svg')),
      );
    });

    test('MenuStyle and alignmentOffset style the panel', () async {
      final css = await _doc(
        const MenuAnchor(
          id: 's',
          style: MenuStyle(
            backgroundColor: Color(0xFF112233),
            minimumSize: Size(200, 0),
          ),
          alignmentOffset: Offset(8, 2),
          menuChildren: [MenuItemButton(child: Text('A'))],
          child: TextButton(onPressed: null, child: Text('x')),
        ),
      );
      expect(css, contains('background-color: #112233'));
      expect(css, contains('min-width: 200px'));
      expect(css, contains('translate: 8px 2px'));
    });

    test('a MenuItemButton style reaches the row', () async {
      final css = await _doc(
        const MenuAnchor(
          id: 'st',
          menuChildren: [
            MenuItemButton(
              style: ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size(0, 36)),
              ),
              child: Text('A'),
            ),
          ],
          child: TextButton(onPressed: null, child: Text('x')),
        ),
      );
      expect(css, contains('min-height: 36px'));
    });

    test('a MenuItemButton outside a menu is just a button', () async {
      final html = await _body(
        const MenuItemButton(onPressed: _noop, child: Text('Solo')),
      );
      expect(html, contains('>Solo</button>'));
      expect(html, isNot(contains('popovertarget')));
    });

    test('two menus in a page get their own ids', () async {
      final html = await _body(
        Column(
          children: [
            for (var i = 0; i < 2; i++)
              const MenuAnchor(
                menuChildren: [MenuItemButton(child: Text('A'))],
                child: TextButton(onPressed: null, child: Text('x')),
              ),
          ],
        ),
      );
      final ids = RegExp(
        r'popovertarget="([^"]+)"',
      ).allMatches(html).map((m) => m[1]).toSet();
      expect(ids.length, 2, reason: html);
    });
  });

  group('SubmenuButton', () {
    const menu = MenuAnchor(
      id: 'root',
      menuChildren: [
        SubmenuButton(
          menuChildren: [
            MenuItemButton(onPressed: _noop, child: Text('Sub A')),
          ],
          child: Text('More'),
        ),
      ],
      child: TextButton(onPressed: null, child: Text('Open')),
    );

    test('a button that opens a second popover beside it', () async {
      final html = await _body(menu);
      expect(_count(html, 'popover="auto"'), 2);
      final sub = RegExp(
        r'popovertarget="([^"]+)" aria-haspopup="true" data-thor="SubmenuButton"',
      ).firstMatch(html)![1]!;
      expect(sub, isNot('root'));
      expect(html, contains('id="$sub"'));
      expect(html, contains('aria-haspopup="true"'));
    });

    test('an item of the submenu closes the whole menu', () async {
      final html = await _body(menu);
      expect(
        html,
        matches(
          RegExp(
            r'<button [^>]*popovertarget="root" popovertargetaction="hide"[^>]*>Sub A',
          ),
        ),
      );
    });

    test('the submenu opens to the side', () async {
      final css = await _doc(menu);
      expect(css, contains('position-area: inline-end span-block-end'));
    });
  });
}
