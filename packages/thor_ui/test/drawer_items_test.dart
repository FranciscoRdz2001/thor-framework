// These tests are about the markup, not the names.
// ignore_for_file: thor_lints/icon_button_without_name
@TestOn('vm')
library;

// What a Flutter drawer is made of. `DrawerHeader`, the `secondary:` of
// the control tiles, and the item that closes the drawer and runs a state
// method with no closure (`DialogClose(child: ListTile(onTap: …))`, Flutter's
// `Navigator.pop(context)` in `onTap`).
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class _Members extends ThorState {
  @override
  String get $type => 'ItemsState';

  @override
  List<ThorMember> get $members {
    final s = this as ItemsState;
    return [ThorMember('open', s.open, call: (_) => s.open())];
  }
}

class ItemsState extends _Members {
  void open() {}
}

final items = ItemsState();

Future<String> _html(Widget w) => renderHtml(ThorApp(child: w));

/// The opening tag of the first element with [attr]="[value]".
String _tag(String html, String attr, String value) =>
    RegExp('<[a-z]+[^>]*$attr="$value"[^>]*>').firstMatch(html)![0]!;

/// The CSS rule of the class of [tag] (the page's own `<style>`).
String _rule(String html, String tag) {
  final cls = RegExp('class="([^"]*)"').firstMatch(tag)![1]!.split(' ').first;
  return RegExp('\\.$cls\\{([^}]*)\\}').firstMatch(html)![1]!;
}

void main() {
  initializeThorTests();

  group('DrawerHeader', () {
    test(
      'a 160 px block, the child at the bottom start, with a divider',
      () async {
        final html = await _html(
          const Drawer(child: DrawerHeader(child: Text('Menu'))),
        );
        final tag = _tag(html, 'data-thor', 'DrawerHeader');
        final css = _rule(html, tag);
        expect(css, contains('height: 160px'));
        expect(css, contains('justify-content: flex-end'));
        expect(css, contains('align-items: flex-start'));
        expect(css, contains('padding: 16px 16px 8px'));
        expect(css, contains('margin: 0px 0px 8px'));
        expect(css, contains('border-bottom: 1px solid'));
        expect(html, contains('>Menu<'));
      },
    );

    test('decoration, margin and padding are the ones given', () async {
      final html = await _html(
        const DrawerHeader(
          decoration: BoxDecoration(color: Color(0xFF123456)),
          margin: EdgeInsets.zero,
          padding: EdgeInsets.all(4),
          child: Text('x'),
        ),
      );
      final css = _rule(html, _tag(html, 'data-thor', 'DrawerHeader'));
      expect(css, contains('background-color: #123456'));
      expect(css, contains('padding: 4px'));
      expect(css, contains('margin: 0'));
      // The divider stays under it (Flutter draws it outside the decoration).
      expect(css, contains('border-bottom: 1px solid'));
    });

    test('a decoration with its own border replaces the divider', () async {
      final html = await _html(
        const DrawerHeader(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFFF0000), width: 3),
            ),
          ),
          child: Text('x'),
        ),
      );
      final css = _rule(html, _tag(html, 'data-thor', 'DrawerHeader'));
      expect(css, isNot(contains('1px solid var(--t-outline-variant')));
      expect(css, contains('border-bottom: 3px solid #ff0000'));
    });

    test('duration and curve are accepted and change nothing', () async {
      final plain = await _html(const DrawerHeader(child: Text('x')));
      final slow = await _html(
        const DrawerHeader(
          duration: Duration(seconds: 2),
          curve: Curves.bounceIn,
          child: Text('x'),
        ),
      );
      expect(slow, plain);
    });

    test('no child is fine (Flutter allows a null child)', () async {
      final html = await _html(const DrawerHeader(child: null));
      expect(html, contains('data-thor="DrawerHeader"'));
    });

    test('its place is logical: nothing physical for RTL to undo', () async {
      final html = await _html(const DrawerHeader(child: Text('x')));
      final css = _rule(html, _tag(html, 'data-thor', 'DrawerHeader'));
      expect(css, isNot(contains('text-align: left')));
      expect(css, isNot(contains('margin-left')));
    });
  });

  group('secondary:', () {
    const secondary = Icon(IconData.svg('s', '<path d="M0 0"/>'));

    int at(String html, String needle) => html.indexOf(needle);

    test(
      'CheckboxListTile: opposite the checkbox, on either affinity',
      () async {
        final trailing = await _html(
          CheckboxListTile(
            value: false,
            onChanged: (_) {},
            title: const Text('Sound'),
            secondary: secondary,
          ),
        );
        // Default affinity: the checkbox at the end, the secondary at the start.
        expect(at(trailing, '<svg'), lessThan(at(trailing, 'Sound')));
        expect(
          at(trailing, 'Sound'),
          lessThan(at(trailing, 'type="checkbox"')),
        );
        final leading = await _html(
          CheckboxListTile(
            value: false,
            onChanged: (_) {},
            title: const Text('Sound'),
            secondary: secondary,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        );
        expect(at(leading, 'type="checkbox"'), lessThan(at(leading, 'Sound')));
        expect(at(leading, 'Sound'), lessThan(at(leading, '<svg')));
      },
    );

    test(
      'the secondary is a sibling of the <label>, never inside it',
      () async {
        final button = IconButton(
          icon: secondary,
          tooltip: 'Delete',
          onPressed: () {},
        );
        final tiles = <Widget>[
          CheckboxListTile(
            value: false,
            onChanged: (_) {},
            title: const Text('Buy milk'),
            secondary: button,
          ),
          CheckboxListTile(
            value: false,
            onChanged: (_) {},
            title: const Text('Buy milk'),
            secondary: button,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          SwitchListTile(
            value: false,
            onChanged: (_) {},
            title: const Text('Buy milk'),
            secondary: button,
          ),
          RadioListTile<int>(
            value: 1,
            groupValue: 0,
            onChanged: (_) {},
            title: const Text('Buy milk'),
            secondary: button,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ];
        for (final tile in tiles) {
          final html = await _html(tile);
          final label = RegExp(
            '<label[^>]*>(.*?)</label>',
          ).firstMatch(html)![1]!;
          expect(label, isNot(contains('<button')));
          expect(label, contains('<input'));
          expect(label, contains('Buy milk'));
          expect(html, contains('aria-label="Delete"'));
          // The button follows the label's end: a sibling in the row.
          final after = html.substring(html.indexOf('</label>'));
          final before = html.substring(0, html.indexOf('<label'));
          expect(
            after.contains('<button') || before.contains('<button'),
            isTrue,
          );
        }
      },
    );

    test('the whole row presses the label: overlay above the padding and '
        'the secondary, the interactive parts above the overlay', () async {
      for (final affinity in ListTileControlAffinity.values) {
        final html = await _html(
          CheckboxListTile(
            value: false,
            onChanged: (_) {},
            title: const Text('Sound'),
            secondary: secondary,
            controlAffinity: affinity,
          ),
        );
        final row = _rule(html, _tag(html, 'data-thor', 'CheckboxListTile'));
        expect(row, contains('position: relative'));
        final label = RegExp('<label class="([^"]*)"').firstMatch(html)![1]!;
        final cls = label.split(' ').first;
        // The label's overlay covers the row; its children paint above it.
        expect(
          html,
          matches(RegExp('\\.$cls::after\\{[^}]*position: absolute; inset: 0')),
        );
        expect(html, contains('.$cls > *{position: relative; z-index: 1}'));
        // The secondary lets presses through, except what is interactive.
        final icon = _rule(html, RegExp('<svg[^>]*>').firstMatch(html)![0]!);
        expect(icon, contains('pointer-events: none'));
        expect(html, contains('input,select,textarea,summary,label'));
        expect(html, contains('{pointer-events: auto}'));
      }
    });

    test('a disabled tile keeps the default cursor on the overlay', () async {
      final html = await _html(
        const CheckboxListTile(
          value: false,
          onChanged: null,
          title: Text('Sound'),
          secondary: secondary,
        ),
      );
      expect(html, isNot(contains('cursor: pointer; }')));
      expect(html, matches(RegExp('::after\\{[^}]*cursor: default')));
    });

    test('SwitchListTile and RadioListTile take it too', () async {
      final sw = await _html(
        SwitchListTile(
          value: true,
          onChanged: (_) {},
          title: const Text('Wi-Fi'),
          subtitle: const Text('On'),
          secondary: secondary,
        ),
      );
      expect(at(sw, '<svg'), lessThan(at(sw, 'Wi-Fi')));
      expect(at(sw, 'On'), lessThan(at(sw, 'role="switch"')));
      final radio = await _html(
        RadioGroup<int>(
          groupValue: 1,
          onChanged: (_) {},
          child: const RadioListTile<int>(
            value: 1,
            title: Text('One'),
            secondary: secondary,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
      );
      expect(at(radio, 'type="radio"'), lessThan(at(radio, 'One')));
      expect(at(radio, 'One'), lessThan(at(radio, '<svg')));
    });

    test(
      'an explicit color of the secondary wins over the tile\'s gray',
      () async {
        final html = await _html(
          const CheckboxListTile(
            value: true,
            title: Text('x'),
            secondary: Icon(Icons.star, color: Color(0xFFFF0000)),
          ),
        );
        final svg = RegExp('<svg[^>]*>').firstMatch(html)![0]!;
        final css = _rule(html, svg);
        final tail = css.substring(css.lastIndexOf('color:'));
        expect(
          tail.toLowerCase(),
          anyOf(contains('ff0000'), contains('255, 0, 0')),
        );
      },
    );

    test('the secondary is colored like a ListTile\'s icon', () async {
      final html = await _html(
        const CheckboxListTile(
          value: true,
          title: Text('x'),
          secondary: secondary,
        ),
      );
      expect(html, contains('color: var(--t-on-surface-variant'));
    });

    test(
      'without it the tile is what it was (a plain title is the label text)',
      () async {
        final html = await _html(
          const CheckboxListTile(value: true, title: Text('Plain')),
        );
        expect(html, isNot(contains('<svg')));
        expect(RegExp('<label[^>]*>Plain<').hasMatch(html), isTrue);
      },
    );
  });

  group('the item that closes the drawer and runs a method', () {
    test(
      'DialogClose(child: ListTile(onTap: state.method)) does both',
      () async {
        final html = await _html(
          Drawer(
            child: DialogClose(
              child: ListTile(onTap: items.open, title: const Text('Settings')),
            ),
          ),
        );
        final button = RegExp('<button[^>]*>')
            .allMatches(html)
            .firstWhere((m) => m[0]!.contains('command="close"'))[0]!;
        // Native close (no JS) and the engine's click, on one element.
        expect(button, contains('commandfor="'));
        expect(button, contains('data-t-on="click:'));
        final drawerId = RegExp(
          '<dialog[^>]*id="([^"]*)"',
        ).firstMatch(html)![1];
        expect(button, contains('commandfor="$drawerId"'));
      },
    );

    test('a tile that only closes has no engine handler', () async {
      final html = await _html(
        Drawer(
          child: DialogClose(
            child: ListTile(onTap: () {}, title: const Text('Help')),
          ),
        ),
      );
      expect(html, contains('command="close"'));
      expect(html, isNot(contains('data-t-on')));
    });

    test('a disabled link tile is not a link', () async {
      final html = await _html(
        const Drawer(
          child: ListTile(
            href: '/settings',
            enabled: false,
            title: Text('Settings'),
          ),
        ),
      );
      expect(html, isNot(contains('href="/settings"')));
      expect(html, contains('aria-disabled="true"'));
    });
  });
}
