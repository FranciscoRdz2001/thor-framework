@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body) async {
  return renderDocument(ThorApp(child: body));
}

String bodyOf(String html) => html.substring(html.indexOf('<body'));

void _noop(Object? _) {}

// The member list thor generates for [_Menu], by hand.
abstract class _MenuMembers extends ThorState {
  @override
  String get $type => 'Menu';

  @override
  List<ThorMember> get $members {
    final s = this as _Menu;
    return [
      ThorMember('pick', s.pick, arity: 1, call: (a) => s.pick(a!)),
      ThorMember(
        'pickN',
        s.pickN,
        arity: 1,
        call: (a) => s.pickN(int.parse(a!)),
      ),
      ThorMember(
        'pickSize',
        s.pickSize,
        arity: 1,
        call: (a) => s.pickSize(_Size.values.byName(a!)),
      ),
    ];
  }
}

class _Menu extends _MenuMembers {
  void pick(String value) {}

  void pickN(int value) {}

  void pickSize(_Size value) {}
}

enum _Size { small, large }

final _menu = _Menu();

void main() {
  setUpAll(initializeThorTests);

  test(
    'ListTile with a plain title is one element; onTap makes it a button',
    () async {
      final html = bodyOf(await page(const ListTile(title: Text('Sales'))));
      expect(
        html,
        matches(
          RegExp(r'<body><div class="t\w+" data-thor="ListTile">Sales</div>'),
        ),
      );
      final tap = bodyOf(
        await page(ListTile(title: const Text('Ir'), onTap: () {})),
      );
      expect(tap, contains('type="button"'));
      expect(tap, contains('>Ir</button>'));
    },
  );

  test(
    'an interactive ListTile never nests a native control in its button',
    () async {
      final html = bodyOf(
        await page(
          ListTile(
            title: const Text('Wi-Fi'),
            onTap: () {},
            trailing: IconButton(
              onPressed: () {},
              tooltip: 'Edit',
              icon: const Icon(Icons.edit),
            ),
          ),
        ),
      );
      expect(
        RegExp(
          r'<button\b(?:(?!</button>).)*<button\b',
          dotAll: true,
        ).hasMatch(html),
        isFalse,
        reason: html,
      );
      final link = bodyOf(
        await page(
          ListTile(
            title: const Text('Go'),
            href: '/x',
            trailing: Switch(value: true, onChanged: (_) {}),
          ),
        ),
      );
      expect(
        RegExp(r'<a\b(?:(?!</a>).)*<input\b', dotAll: true).hasMatch(link),
        isFalse,
        reason: link,
      );
    },
  );

  test(
    'AlertDialog names itself by its title, semanticLabel or nothing',
    () async {
      final titled = bodyOf(
        await page(const AlertDialog(title: Text('T'), content: Text('c'))),
      );
      expect(titled, contains('aria-labelledby='));
      expect(titled, contains('-title"'));
      final bare = bodyOf(
        await page(const AlertDialog(content: Text('Saved'))),
      );
      expect(bare, isNot(contains('aria-labelledby')));
      final labelled = bodyOf(
        await page(
          const AlertDialog(semanticLabel: 'Saved', content: Text('ok')),
        ),
      );
      expect(labelled, contains('aria-label="Saved"'));
      expect(labelled, isNot(contains('aria-labelledby')));
    },
  );

  test(
    'ExpansionTile is <details>/<summary>; name makes an accordion',
    () async {
      final html = bodyOf(
        await page(
          const ExpansionPanelList(
            name: 'faq',
            children: [
              ExpansionTile(
                title: Text('Opening hours?'),
                children: [Text('9 a 18')],
              ),
              ExpansionTile(
                title: Text('Shipping?'),
                initiallyExpanded: true,
                children: [Text('Yes')],
              ),
            ],
          ),
        ),
      );
      expect('<details'.allMatches(html), hasLength(2));
      expect(html, contains('name="faq"'));
      expect(html, contains('open name="faq"'));
      expect(html, contains('<summary'));
    },
  );

  test('chip selection is aria-pressed on the same class', () async {
    final on = bodyOf(
      await page(
        const FilterChip(
          label: Text('Café'),
          selected: true,
          onSelected: _noop,
        ),
      ),
    );
    final off = bodyOf(
      await page(
        const FilterChip(
          label: Text('Café'),
          selected: false,
          onSelected: _noop,
        ),
      ),
    );
    final cls = RegExp(r'<button class="(t\w+)"');
    expect(on, contains('aria-pressed="true"'));
    expect(off, contains('aria-pressed="false"'));
    expect(cls.firstMatch(on)![1], cls.firstMatch(off)![1]);
    final css = await page(
      const FilterChip(label: Text('x'), selected: true, onSelected: _noop),
    );
    expect(css, matches(RegExp(r'\.t\w+\[aria-pressed="true"\]\{')));
  });

  test(
    'progress indicators: native <progress>, SVG spinner without JS',
    () async {
      final linear = bodyOf(
        await page(const LinearProgressIndicator(value: 0.4)),
      );
      expect(linear, contains('<progress'));
      expect(linear, contains('max="1" value="0.4"'));
      final indeterminate = bodyOf(await page(const LinearProgressIndicator()));
      expect(indeterminate, isNot(contains('value=')));
      final spinner = bodyOf(await page(const CircularProgressIndicator()));
      expect(spinner, contains('role="progressbar"'));
      // Compositor rotation (no SMIL: it re-lays out every frame).
      final spinnerPage = await page(const CircularProgressIndicator());
      expect(spinnerPage, contains('@keyframes thor-spin{to{rotate:1turn}}'));
      expect(
        spinnerPage,
        contains('animation: thor-spin 1.4s linear infinite'),
      );
      final determinate = bodyOf(
        await page(const CircularProgressIndicator(value: 0.5)),
      );
      expect(determinate, contains('aria-valuenow="50"'));
      expect(
        await page(const CircularProgressIndicator(value: 0.5)),
        isNot(contains('thor-spin')),
      );
    },
  );

  test('AlertDialog is a closed <dialog>, opened by commandfor', () async {
    final html = bodyOf(
      await page(
        Column(
          children: [
            DialogTrigger(
              id: 'confirm',
              child: FilledButton(onPressed: () {}, child: const Text('Pay')),
            ),
            AlertDialog(
              id: 'confirm',
              title: const Text('Pay \$187.00?'),
              actions: [
                DialogClose(
                  id: 'confirm',
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    expect(html, contains('commandfor="confirm" command="show-modal"'));
    expect(html, contains('<dialog id="confirm"'));
    expect(html, isNot(contains('<dialog id="confirm" open')));
    expect(html, contains('aria-labelledby="confirm-title"'));
    expect(html, contains('id="confirm-title"'));
    expect(html, contains('commandfor="confirm" command="close"'));
  });

  test('Badge, CircleAvatar and Card render compact native markup', () async {
    final badge = bodyOf(
      await page(
        const Badge(
          label: Text('3'),
          child: Icon(IconData.svg('x', '<path d="M0 0"/>')),
        ),
      ),
    );
    expect(badge, contains('>3</span>'));
    final avatar = bodyOf(await page(const CircleAvatar(child: Text('AN'))));
    expect(
      avatar,
      matches(RegExp(r'<span class="t\w+" data-thor="CircleAvatar">AN</span>')),
    );
    final card = bodyOf(
      await page(
        const Semantics(
          role: SemanticsRole.article,
          child: Card(child: Text('x')),
        ),
      ),
    );
    expect(card, startsWith('<body><article'));
  });

  test(
    'bottom sheet: bottom-anchored <dialog> with an entry transition',
    () async {
      final html = await page(
        const ModalBottomSheet(id: 'opts', label: 'Options', child: Text('x')),
      );
      expect(html, contains('<dialog id="opts"'));
      expect(html, contains('closedby="any"'));
      expect(
        html,
        matches(
          RegExp(r'@starting-style\{\.t\w+\[open\]\{translate: 0 100%\}\}'),
        ),
      );
    },
  );

  test(
    'popup menu: popovertarget trigger, anchored popover, hide on pick',
    () async {
      final html = await page(
        PopupMenuButton(
          id: 'more',
          tooltip: 'More',
          onSelected: _menu.pick,
          items: const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'del', child: Text('Delete')),
          ],
          child: const Text('⋮'),
        ),
      );
      expect(html, contains('popovertarget="more"'));
      expect(html, contains('id="more"'));
      expect(html, contains('popover="auto"'));
      expect(html, contains('popovertargetaction="hide"'));
      expect(html, contains('data-t-on="click:Menu.pick" data-tx="edit"'));
      expect(html, contains('anchor-name: --more'));
      expect(html, contains('position-anchor: --more'));
    },
  );

  test(
    'popup menu: the value is any encodable type, like Flutter\'s T',
    () async {
      final html = await page(
        PopupMenuButton<int>(
          id: 'num',
          onSelected: _menu.pickN,
          initialValue: 2,
          items: const [
            PopupMenuItem(value: 1, child: Text('One')),
            PopupMenuItem(value: 2, child: Text('Two')),
          ],
          child: const Text('n'),
        ),
      );
      expect(html, contains('data-t-on="click:Menu.pickN" data-tx="2"'));
      expect(html, contains('aria-checked="true"'));
      // An enum travels by its name, as a method parameter parses it.
      final sizes = await page(
        PopupMenuButton<_Size>(
          onSelected: _menu.pickSize,
          initialValue: _Size.large,
          items: const [
            PopupMenuItem(value: _Size.small, child: Text('Small')),
            PopupMenuItem(value: _Size.large, child: Text('Large')),
          ],
          child: const Text('size'),
        ),
      );
      expect(
        sizes,
        contains('data-t-on="click:Menu.pickSize" data-tx="small"'),
      );
      expect(
        RegExp(
          r'aria-checked="true"[^>]*data-tx="large"|data-tx="large"[^>]*aria-checked="true"',
        ).hasMatch(sizes),
        isTrue,
      );
    },
  );

  test('popup menu: a styled trigger and menu, the current item marked, '
      'and without them the Material look', () async {
    final plain = await page(
      PopupMenuButton(
        id: 'plain',
        onSelected: _menu.pick,
        items: const [PopupMenuItem(value: 'a', child: Text('A'))],
        child: const Text('⋮'),
      ),
    );
    expect(plain, contains('border-radius: 20px'));
    expect(plain, isNot(contains('role="menuitemradio"')));

    final html = await page(
      PopupMenuButton(
        id: 'pick',
        onSelected: _menu.pick,
        initialValue: 'b',
        style: const ButtonStyle(
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
          minimumSize: WidgetStatePropertyAll(Size(0, 36)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        ),
        color: const Color(0xFFFFFFFF),
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Color(0xFFE4E7EE)),
          borderRadius: BorderRadius.all(Radius.circular(9)),
        ),
        elevation: 8,
        constraints: const BoxConstraints(minWidth: 211),
        menuPadding: const EdgeInsets.symmetric(vertical: 4),
        items: const [
          PopupMenuItem(value: 'a', height: 32, child: Text('A')),
          PopupMenuItem(value: 'b', height: 32, child: Text('B')),
        ],
        child: const Text('B'),
      ),
    );
    // The trigger: the style's shape and size, not the round target.
    expect(html, contains('min-height: 36px'));
    expect(html, isNot(contains('border-radius: 20px')));
    // The menu.
    expect(html, contains('min-width: 211px'));
    expect(html, contains('border-radius: 9px'));
    expect(html, contains('border: 1px solid #e4e7ee'));
    expect(html, contains('background-color: #ffffff'));
    expect(html, contains('padding: 4px 0px'));
    expect(html, contains('min-height: 32px'));
    // The current item.
    expect(html, contains('role="menuitemradio" aria-checked="false"'));
    expect(html, contains('role="menuitemradio" aria-checked="true"'));
  });

  test('snackbar: a status region whose visibility is a style', () async {
    final shown = bodyOf(await page(const SnackBar(content: Text('Saved'))));
    final hidden = bodyOf(
      await page(const SnackBar(content: Text('Saved'), visible: false)),
    );
    expect(shown, contains('role="status"'));
    expect(shown, contains('>Saved</div>'));
    final cls = RegExp(r'<div class="(t\w+)"');
    expect(cls.firstMatch(shown)![1], isNot(cls.firstMatch(hidden)![1]));
  });

  test(
    'snackbar: a manual popover with its state, and the script once',
    () async {
      final shown = await renderDocument(
        const ThorApp(
          child: Column(
            children: [
              SnackBar(content: Text('A')),
              SnackBar(visible: false, content: Text('B')),
            ],
          ),
        ),
      );
      final body = bodyOf(shown);
      expect(body, contains('popover="manual"'));
      expect(body, contains('data-snack="on"'));
      expect(body, contains('data-snack="off"'));
      expect(
        RegExp(r'<script>\(\(D\)=>\{if\(!\(.showPopover').allMatches(body),
        hasLength(1),
      );
      // No ThorApp, no script: the plain fixed bar.
      final bare = await renderHtml(const SnackBar(content: Text('A')));
      expect(bare, isNot(contains('popover')));
      expect(bare, isNot(contains('data-snack')));
    },
  );

  test('Dialog: a native <dialog> with the caller\'s look', () async {
    final html = await page(
      const Dialog(
        id: 'd',
        backgroundColor: Color(0xFF112233),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        constraints: BoxConstraints(maxWidth: 480),
        shadows: [BoxShadow(color: Color(0xFF000000), blurRadius: 4)],
        barrierDismissible: false,
        label: 'Details',
        child: Text('Hello'),
      ),
    );
    final body = bodyOf(html);
    expect(body, contains('<dialog'));
    expect(body, contains('id="d"'));
    expect(body, contains('closedby="closerequest"'));
    expect(body, contains('aria-label="Details"'));
    expect(body, contains('>Hello</span></dialog>'));
    expect(html, contains('background-color: #112233'));
    expect(html, contains('border-radius: 12px'));
    expect(html, contains('max-width: 480px'));
    expect(html, contains('box-shadow: 0px 0px 4px 0px #000000'));
    expect(html, contains('::backdrop'));
    final open = bodyOf(await page(const Dialog(id: 'e', child: Text('x'))));
    expect(open, contains('closedby="any"'));
  });

  test('Drawer: 16px padding by default, none with EdgeInsets.zero, and '
      'the child fills the height', () async {
    final padded = await page(const Drawer(id: 'nav', child: Text('menu')));
    final flush = await page(
      const Drawer(id: 'nav', padding: EdgeInsets.zero, child: Text('menu')),
    );
    expect(padded, contains('padding: 16px'));
    expect(flush, isNot(contains('padding: 16px')));
    expect(flush, contains('padding: 0'));
    // The child is an Expanded item of the panel's column.
    expect(bodyOf(padded), contains('data-thor-flex-item="Expanded"'));
  });
}
