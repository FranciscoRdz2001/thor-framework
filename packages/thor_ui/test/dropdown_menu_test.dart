import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// The member list thor generates for [_Order], by hand (tests don't run the build).
abstract class _OrderMembers extends ThorState {
  @override
  String get $type => 'Order';

  @override
  List<ThorMember> get $members {
    final s = this as _Order;
    return [
      ThorMember.state('fruit', s.fruit),
      ThorMember('setFruit', s.setFruit, arity: 1, call: s.setFruit),
    ];
  }
}

class _Order extends _OrderMembers {
  final fruit = state<String?>(null);
  void setFruit(String? v) => fruit.value = v;
}

final _order = _Order();

enum Fruit { apple, banana, cherry }

const _entries = [
  DropdownMenuEntry(value: Fruit.apple, label: 'Apple'),
  DropdownMenuEntry(value: Fruit.banana, label: 'Banana'),
  DropdownMenuEntry(value: Fruit.cherry, label: 'Cherry', enabled: false),
];

Future<String> _render(Widget w) => renderDocument(ThorApp(child: w));

String _attr(String html, String tag, String attr) =>
    RegExp('<$tag[^>]*\\s$attr="([^"]*)"').firstMatch(html)!.group(1)!;

void main() {
  initializeThorTests();

  group('DropdownMenu', () {
    test(
      'a combobox button controlling a listbox popover of options',
      () async {
        final html = await _render(
          const DropdownMenu<Fruit>(
            label: Text('Fruit'),
            initialSelection: Fruit.banana,
            dropdownMenuEntries: _entries,
          ),
        );
        final button = RegExp('<button[^>]*>').firstMatch(html)!.group(0)!;
        expect(button, contains('role="combobox"'));
        expect(button, contains('aria-haspopup="listbox"'));
        expect(button, contains('aria-expanded="false"'));
        expect(button, contains('aria-label="Fruit"'));
        final list = _attr(html, 'button', 'aria-controls');
        final menu = _attr(html, 'button', 'popovertarget');
        expect(list, menu, reason: 'without a filter the panel is the listbox');
        expect(
          html,
          matches(
            RegExp('<div id="$menu"[^>]*popover="auto"[^>]*role="listbox"'),
          ),
        );
        expect(RegExp('role="option"').allMatches(html), hasLength(3));
        expect(
          RegExp(
            r'role="option" aria-selected="(\w+)"',
          ).allMatches(html).map((m) => m.group(1)),
          ['false', 'true', 'false'],
        );
        expect(html, contains('aria-disabled="true">Cherry<'));
        expect(html, contains('data-t-dd="s"'), reason: 'enableSearch');
        // Option ids are the engine's (only the highlighted one needs it).
        expect(html, isNot(contains('role="option" id=')));
      },
    );

    test('the button shows the initial label; the hidden select holds the '
        'value a form posts', () async {
      final html = await _render(
        const DropdownMenu<Fruit>(
          name: 'fruit',
          initialSelection: Fruit.banana,
          hintText: 'Pick one',
          dropdownMenuEntries: _entries,
        ),
      );
      expect(html, contains('data-tdl>Banana</span>'));
      expect(html, isNot(contains('data-tdl data-hint')));
      final select = RegExp('<select.*?</select>').firstMatch(html)!.group(0)!;
      expect(select, contains('name="fruit"'));
      expect(select, contains('<option value="banana" selected>Banana'));
      expect(select, contains('<option value="cherry" disabled>Cherry'));
      expect(select, isNot(contains('hidden>Pick one')), reason: 'no hint');
    });

    test('without a selection: the hint, and nothing posted', () async {
      final html = await _render(
        const DropdownMenu<Fruit>(
          name: 'fruit',
          initialSelection: Fruit.cherry, // not an entry
          hintText: 'Pick one',
          dropdownMenuEntries: [
            DropdownMenuEntry(value: Fruit.apple, label: 'Apple'),
          ],
        ),
      );
      expect(html, contains('data-tdl data-hint>Pick one</span>'));
      // A disabled selected placeholder: the form posts no value.
      expect(
        html,
        contains('<option value disabled selected hidden>Pick one</option>'),
      );
      expect(html, isNot(contains('aria-selected="true"')));
    });

    test('with JS the select only sizes the column; without JS it is the '
        'control and the button hides', () async {
      final html = await _render(
        const DropdownMenu<Fruit>(dropdownMenuEntries: _entries),
      );
      expect(
        RegExp(
          r'@media \(scripting: none\)\{(?:[^{}]*\{[^{}]*\})*?'
          r'\.\w+\{display: none\}',
        ).hasMatch(html),
        isTrue,
      );
      expect(html, contains('visibility: hidden; height: 0'));
      expect(
        RegExp(
          r'@media \(scripting: none\)\{(?:[^{}]*\{[^{}]*\})*?'
          r'\.\w+\{[^}]*visibility: visible',
        ).hasMatch(html),
        isTrue,
      );
    });

    test(
      'onSelected with a ThorState method binds the select change',
      () async {
        final html = await _render(
          DropdownMenu<Fruit>(
            // The inert case on purpose: a closure is not translated.
            // ignore: thor_lints/state_callback_closure
            onSelected: (f) => _order.setFruit(f?.name),
            dropdownMenuEntries: _entries,
          ),
        );
        expect(
          html,
          isNot(matches(RegExp('<select[^>]*data-t-on'))),
          reason: 'a closure: inert',
        );
        final bound = await _render(
          DropdownMenu<String>(
            onSelected: _order.setFruit,
            dropdownMenuEntries: const [
              DropdownMenuEntry(value: 'a', label: 'A'),
            ],
          ),
        );
        expect(
          bound,
          matches(RegExp(r'<select[^>]*data-t-on="change:Order\.setFruit"')),
        );
      },
    );

    test('the page ships the engine without any ThorState', () async {
      final html = await _render(
        const DropdownMenu<Fruit>(dropdownMenuEntries: _entries),
      );
      expect(html, contains('data-thor-engine'));
    });

    test('ids are unique per page, or the given one', () async {
      final html = await _render(
        const Column(
          children: [
            DropdownMenu<Fruit>(dropdownMenuEntries: _entries),
            DropdownMenu<Fruit>(dropdownMenuEntries: _entries),
            DropdownMenu<Fruit>(id: 'size', dropdownMenuEntries: _entries),
          ],
        ),
      );
      final targets = RegExp(
        r'popovertarget="([^"]+)"',
      ).allMatches(html).map((m) => m.group(1)).toList();
      expect(targets.toSet(), hasLength(3));
      expect(targets.last, 'size-menu');
      // One anchor name, scoped per menu: equal menus share their classes.
      expect(RegExp('anchor-scope: --t-dd').allMatches(html), hasLength(1));
    });

    test(
      'the filter field: a combobox input above a separate listbox',
      () async {
        final html = await _render(
          const DropdownMenu<Fruit>(
            enableFilter: true,
            requestFocusOnTap: false,
            dropdownMenuEntries: _entries,
          ),
        );
        final list = _attr(html, 'button', 'aria-controls');
        expect(list, endsWith('-list'));
        final input = RegExp('<input[^>]*>').firstMatch(html)!.group(0)!;
        expect(input, contains('role="combobox"'));
        expect(input, contains('aria-controls="$list"'));
        expect(input, contains('aria-autocomplete="list"'));
        expect(input, contains('autocomplete="off"'));
        expect(input, contains('aria-label="Search"'));
        expect(html, matches(RegExp('id="$list" [^>]*role="listbox"')));
        expect(html, contains('data-t-dd="sn"'));
        // The panel lays out field + list only while open.
        expect(html, contains(':popover-open{display: flex'));
      },
    );

    test('flags: no type-ahead, always focus the filter', () async {
      final html = await _render(
        const DropdownMenu<Fruit>(
          enableSearch: false,
          requestFocusOnTap: true,
          dropdownMenuEntries: _entries,
        ),
      );
      expect(html, contains('data-t-dd="f"'));
    });

    test('disabled: the button and the select', () async {
      final html = await _render(
        const DropdownMenu<Fruit>(
          enabled: false,
          dropdownMenuEntries: _entries,
        ),
      );
      expect(html, matches(RegExp('<button[^>]* disabled')));
      expect(html, matches(RegExp('<select[^>]* disabled')));
    });

    test('helper and error texts describe the button', () async {
      final html = await _render(
        const DropdownMenu<Fruit>(
          helperText: 'Required',
          errorText: 'Pick a fruit',
          dropdownMenuEntries: _entries,
        ),
      );
      final help = _attr(html, 'button', 'aria-describedby');
      expect(html, contains('id="$help"'));
      expect(html, contains('>Pick a fruit</span>'));
      expect(html, isNot(contains('Required')), reason: 'the error wins');
      expect(html, contains('aria-invalid="true"'));
      expect(html, contains('inset 0 0 0 2px var(--t-error'));
    });

    test('styling hooks: a shadcn select', () async {
      const radius = BorderRadius.all(Radius.circular(6));
      const border = Color(0xFFE4E4E7);
      final html = await _render(
        const DropdownMenu<Fruit>(
          width: 200,
          alignmentOffset: Offset(0, 4),
          textStyle: TextStyle(fontSize: 14),
          inputDecorationTheme: InputDecorationTheme(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints: BoxConstraints.tightFor(height: 40),
            border: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: border),
            ),
          ),
          menuStyle: MenuStyle(
            backgroundColor: Colors.white,
            padding: EdgeInsets.all(4),
            side: BorderSide(color: border),
            shape: RoundedRectangleBorder(borderRadius: radius),
            shadows: [BoxShadow(color: Color(0x1A000000), blurRadius: 6)],
          ),
          dropdownMenuEntries: [
            DropdownMenuEntry(
              value: Fruit.apple,
              label: 'Apple',
              leadingIcon: DropdownMenuSelectedIcon(child: Text('✓')),
              style: ButtonStyle(
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                minimumSize: WidgetStatePropertyAll(Size(0, 0)),
                overlayColor: WidgetStatePropertyAll(Color(0xFFF4F4F5)),
              ),
            ),
          ],
        ),
      );
      expect(html, contains('width: 200px'));
      expect(html, contains('padding: 8px 12px'));
      expect(html, contains('height: 40px'));
      expect(html, contains('inset 0 0 0 1px #e4e4e7'));
      expect(html, contains('border-radius: 6px'));
      expect(html, contains('margin: 4px 0 4px 0px'));
      expect(html, contains('background-color: #ffffff'));
      expect(html, contains('padding: 4px'));
      expect(html, contains('border: 1px solid #e4e4e7'));
      expect(html, contains('padding: 6px 8px'));
      expect(html, contains('min-height: 0'));
      expect(html, contains('[data-active]{background-color: #f4f4f5}'));
      expect(
        html,
        contains(':where([aria-selected="true"]) '),
        reason: 'the check shows only on the picked entry',
      );
    });

    test('MenuStyle elevation 0 removes the shadow', () async {
      final html = await _render(
        const DropdownMenu<Fruit>(
          menuStyle: MenuStyle(elevation: 0),
          dropdownMenuEntries: _entries,
        ),
      );
      expect(html, contains('box-shadow: none'));
    });

    test('default icons: one arrow that turns; given icons swap', () async {
      final html = await _render(
        const DropdownMenu<Fruit>(dropdownMenuEntries: _entries),
      );
      expect(html, contains('thor-arrow-drop-down'));
      expect(html, isNot(contains('thor-arrow-drop-up')));
      expect(html, contains(':where([aria-expanded="true"]) '));
      expect(html, contains('{rotate: 180deg}'));
      final swapped = await _render(
        const DropdownMenu<Fruit>(
          trailingIcon: Text('▾'),
          dropdownMenuEntries: _entries,
        ),
      );
      expect(swapped, contains('▾'));
      expect(swapped, contains('thor-arrow-drop-up'), reason: "Flutter's pair");
    });

    test('expandedInsets fills the width', () async {
      final html = await _render(
        const DropdownMenu<Fruit>(
          expandedInsets: EdgeInsets.zero,
          dropdownMenuEntries: _entries,
        ),
      );
      expect(html, contains('display: grid'));
    });
  });
}
