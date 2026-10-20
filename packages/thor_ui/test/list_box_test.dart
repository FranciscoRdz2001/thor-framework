@TestOn('vm')
library;

// ListBox: a native `<select size>` (`multiple` for several), static or
// over a list of the state (`ListBox.list`).
import 'package:test/test.dart';
import 'package:thor_ui/router.dart' show FormInvalid;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class Person {
  const Person(this.id, this.name);
  final int id;
  final String name;
}

// The member list thor generates for [PeopleState], by hand.
abstract class _PeopleMembers extends ThorState {
  @override
  String get $type => 'PeopleState';

  @override
  List<ThorMember> get $members {
    final s = this as PeopleState;
    return [
      ThorMember.state('people', s.people),
      ThorMember.state('selected', s.selected),
      ThorMember(
        'idOf',
        s.idOf,
        arity: 1,
        callWithItem: (i) => s.idOf(i as Person),
      ),
      ThorMember(
        'label',
        s.label,
        arity: 1,
        callWithItem: (i) => s.label(i as Person),
      ),
      ThorMember(
        'isPicked',
        s.isPicked,
        arity: 1,
        callWithItem: (i) => s.isPicked(i as Person),
        variants: const [false, true],
      ),
      ThorMember('select', s.select, arity: 1),
      ThorMember('pick', s.pick, arity: 1),
    ];
  }
}

class PeopleState extends _PeopleMembers {
  final people = state<List<Person>>(const [
    Person(1, 'Emil, Hans'),
    Person(2, 'Mustermann, Max'),
  ]);
  final selected = state<int>(2);
  final picked = state<Set<int>>(const {1});

  int idOf(Person p) => p.id;
  String label(Person p) => p.name;
  bool isPicked(Person p) => picked.value.contains(p.id);
  void select(int? id) => selected.value = id ?? 0;
  void pick(Set<int> ids) => picked.value = ids;
}

final people = PeopleState();

const _items = [
  ListBoxItem(value: 'es', child: Text('Español')),
  ListBoxItem(value: 'en', child: Text('English')),
  ListBoxItem(value: 'fr', enabled: false, child: Text('Français')),
];

void _noop(Object? _) {}

String _select(String html) {
  final at = html.indexOf('<select');
  return html.substring(at, html.indexOf('>', at) + 1);
}

// The `selected` attribute (not a binding id that has the word).
final _chosen = matches(RegExp(r'\sselected(?=[\s>=])'));
final _notChosen = isNot(_chosen);

List<String> _options(String html) =>
    RegExp(r'<option[^>]*>[^<]*').allMatches(html).map((m) => m[0]!).toList();

void main() {
  initializeThorTests();

  group('ListBox', () {
    test(
      'one selection: a <select size> with one class, the value chosen',
      () async {
        final html = await renderHtml(
          const ListBox<String>(
            items: _items,
            value: 'en',
            onChanged: _noop,
            visibleItemCount: 5,
            semanticLabel: 'Language',
          ),
        );
        final select = _select(html);
        expect(select, contains('size="5"'));
        expect(select, isNot(contains('multiple')));
        expect(select, contains('aria-label="Language"'));
        expect(select, isNot(contains('disabled')));
        expect(RegExp('<select').allMatches(html), hasLength(1));
        // One element of thor's per concept: the options carry no class.
        expect(RegExp(r'class="[^"]+"').allMatches(html), hasLength(1));
        final options = _options(html);
        expect(options, hasLength(3));
        expect(options[0], allOf(contains('value="es"'), endsWith('>Español')));
        expect(options[0], _notChosen);
        expect(options[1], _chosen);
        expect(options[2], contains('disabled'));
      },
    );

    test('several: multiple, every value of selected chosen', () async {
      final html = await renderHtml(
        const ListBox<String>(
          items: _items,
          multiSelectionEnabled: true,
          selected: {'es', 'fr'},
          onSelectionChanged: _noop,
          semanticLabel: 'Languages',
        ),
      );
      expect(_select(html), allOf(contains('multiple'), contains('size="4"')));
      final options = _options(html);
      expect(options[0], _chosen);
      expect(options[1], _notChosen);
      expect(options[2], _chosen);
    });

    test('disabled without a handler, or with onChanged: null', () async {
      for (final box in const [
        ListBox<String>(items: _items),
        ListBox<String>(items: _items, onChanged: null),
        ListBox<String>(
          items: _items,
          multiSelectionEnabled: true,
          onSelectionChanged: null,
        ),
      ]) {
        expect(_select(await renderHtml(box)), contains('disabled'));
      }
    });

    test('the look: theme tokens, the chosen option a condition', () async {
      final html = await renderDocument(
        ThorApp(
          theme: ThemeData(
            listTileTheme: const ListTileThemeData(
              selectedTileColor: Color(0xFF112233),
            ),
          ),
          child: const ListBox<String>(items: _items, onChanged: _noop),
        ),
      );
      expect(html, contains('option:checked'));
      expect(html, contains('#112233'));
      expect(html, contains('forced-colors'));
      expect(html, contains('Highlight'));
    });

    test('a named field of a Form, its handler left out, is enabled and '
        'sends its values', () async {
      final html = await renderHtml(
        Form(
          child: Column(
            children: [
              const ListBox<String>(items: _items, name: 'lang'),
              const ListBox<String>(
                items: _items,
                name: 'langs',
                multiSelectionEnabled: true,
              ),
              FilledButton(onPressed: () {}, child: const Text('Save')),
            ],
          ),
        ),
      );
      final selects = RegExp(
        r'<select[^>]*>',
      ).allMatches(html).map((m) => m[0]!).toList();
      expect(selects, hasLength(2));
      expect(
        selects[0],
        allOf(contains('name="lang"'), isNot(contains('disabled'))),
      );
      expect(selects[1], allOf(contains('name="langs"'), contains('multiple')));
      expect(selects[1], isNot(contains('disabled')));
    });

    test('a failed form refills what was sent', () async {
      final html = await renderHtml(
        Form(
          failed: FormInvalid(
            values: const {'lang': 'fr'},
            valueLists: const {
              'langs': ['es', 'en'],
            },
          ),
          child: const Column(
            children: [
              ListBox<String>(items: _items, name: 'lang', value: 'es'),
              ListBox<String>(
                items: _items,
                name: 'langs',
                multiSelectionEnabled: true,
              ),
            ],
          ),
        ),
      );
      final options = _options(html);
      expect(options, hasLength(6));
      expect(options[0], _notChosen);
      expect(options[2], _chosen);
      expect(options[3], _chosen);
      expect(options[4], _chosen);
      expect(options[5], _notChosen);
    });
  });

  group('ListBox.list', () {
    test(
      'an option per item, keyed, with its text bound, and a template',
      () async {
        final html = await renderHtml(
          ListBox.list(
            people.people.call,
            itemKey: people.idOf,
            itemLabel: people.label,
            selected: people.selected,
            onChanged: people.select,
            semanticLabel: 'People',
          ),
        );
        final select = _select(html);
        expect(select, contains('size="4"'));
        expect(select, contains('data-tl="PeopleState.people"'));
        expect(select, contains('change:PeopleState.select'));
        final body = html.substring(html.indexOf('<select'));
        final first = body.substring(body.indexOf('<option'));
        expect(first, startsWith('<option'));
        expect(first, contains('value="1"'));
        expect(first, contains('data-tk="1"'));
        expect(first, contains('data-tf="PeopleState.label"'));
        // Only the row whose key is the field's value is chosen.
        final rows = _options(body.substring(0, body.indexOf('<template')));
        expect(rows, hasLength(2));
        expect(rows[0], _notChosen);
        expect(rows[0], endsWith('>Emil, Hans'));
        expect(rows[1], _chosen);
        expect(rows[1], contains('data-tvs'));
        // The browser clones the template for new items: the key and the text
        // are filled in there.
        final template = body.substring(body.indexOf('<template'));
        expect(template, contains('value="{{key}}"'));
        expect(template, contains('data-tf="PeopleState.label"'));
      },
    );

    test('several: multiple, chosen while isSelected says so', () async {
      final html = await renderHtml(
        ListBox.list(
          people.people.call,
          itemKey: people.idOf,
          itemLabel: people.label,
          isSelected: people.isPicked,
          multiSelectionEnabled: true,
          onSelectionChanged: people.pick,
          semanticLabel: 'People',
        ),
      );
      expect(_select(html), contains('multiple'));
      expect(_select(html), contains('change:PeopleState.pick'));
      final body = html.substring(html.indexOf('<select'));
      final rows = _options(body.substring(0, body.indexOf('<template')));
      expect(rows[0], _chosen);
      expect(rows[1], _notChosen);
      expect(rows[0], contains('data-tvf="PeopleState.isPicked"'));
    });

    test('a failed form refills what was sent, over the state; the rows '
        'keep their binding, the template both states', () async {
      // A ListBox.list inside a failed form, or alone.
      Future<String> render(ListBox<int> list, {bool failed = true}) =>
          renderHtml(
            failed
                ? Form(
                    failed: FormInvalid(
                      values: const {'person': '1'},
                      valueLists: const {
                        'people': ['2'],
                      },
                    ),
                    child: list,
                  )
                : list,
          );
      List<String> rows(String html) {
        final list = html.substring(html.indexOf('<select'));
        return _options(list.substring(0, list.indexOf('<template')));
      }

      String template(String html) => html.substring(
        html.indexOf('<template'),
        html.indexOf('</template>'),
      );
      // The state chooses 2; the form sent 1.
      ListBox<int> one() => ListBox.list(
        people.people.call,
        itemKey: people.idOf,
        itemLabel: people.label,
        selected: people.selected,
        onChanged: people.select,
        name: 'person',
      );
      final single = await render(one());
      expect(rows(single)[0], allOf(_chosen, contains('data-tvs')));
      expect(rows(single)[1], _notChosen);
      expect(template(single), template(await render(one(), failed: false)));
      // The state picks 1; the form sent 2.
      final several = await render(
        ListBox.list(
          people.people.call,
          itemKey: people.idOf,
          itemLabel: people.label,
          isSelected: people.isPicked,
          multiSelectionEnabled: true,
          onSelectionChanged: people.pick,
          name: 'people',
        ),
      );
      expect(rows(several)[0], _notChosen);
      expect(rows(several)[1], _chosen);
      // No binding: only the form chooses.
      final plain = await render(
        ListBox.list(
          people.people.call,
          itemKey: people.idOf,
          itemLabel: people.label,
          name: 'person',
        ),
      );
      expect(rows(plain)[0], _chosen);
      expect(rows(plain)[1], _notChosen);
    });
  });
}
