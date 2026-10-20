import 'package:thor_ui/thor_ui.dart';

/// A person of the CRUD.
class Person {
  /// A person with an [id].
  const Person(this.id, this.name, this.surname);

  /// The key of its entry.
  final int id;

  /// The first name.
  final String name;

  /// The surname, what the filter matches.
  final String surname;
}

/// 7GUIs' CRUD over a `ListBox.list`: create, update and delete names,
/// filtered by a surname prefix, with no hand-made rows.
class CrudState extends ThorState {
  /// Everyone.
  final people = state(
    const [
      Person(1, 'Hans', 'Emil'),
      Person(2, 'Max', 'Mustermann'),
      Person(3, 'Roman', 'Tisch'),
    ],
    encode: (list) => [
      for (final p in list) [p.id, p.name, p.surname],
    ],
    decode: (json) => [
      for (final j in json! as List)
        Person((j as List)[0] as int, j[1] as String, j[2] as String),
    ],
  );

  /// The surname prefix.
  final prefix = state('');

  /// The key of the chosen person (0: none).
  final selected = state(0);

  /// The first-name field.
  final name = TextEditingController();

  /// The surname field.
  final surname = TextEditingController();

  /// The id the next person gets.
  final nextId = state(4);

  /// The people whose surname starts with the filter.
  late final visible = derived(
    () => [
      for (final p in people.value)
        if (p.surname.toLowerCase().startsWith(prefix.value.toLowerCase())) p,
    ],
  );

  /// The key of an entry.
  int idOf(Person p) => p.id;

  /// The text of an entry.
  String label(Person p) => '${p.surname}, ${p.name}';

  /// Whether someone is chosen.
  bool hasSelection() => selected.value != 0;

  /// What the list shows of all.
  String count() => '${visible.value.length} of ${people.value.length}';

  /// Who is chosen, for the checks.
  String chosen() => 'Selected: ${selected.value}';

  /// Filters by a surname prefix.
  void setPrefix(String text) => prefix.value = text;

  /// Chooses the person [id] (null: none) and fills the fields.
  void select(int? id) => batch(() {
    selected.value = id ?? 0;
    for (final p in people.value) {
      if (p.id == id) {
        name.text = p.name;
        surname.text = p.surname;
      }
    }
  });

  /// Adds the fields as a new person, chosen.
  void create() => batch(() {
    final id = nextId.value;
    people.value = [...people.value, Person(id, name.text, surname.text)];
    selected.value = id;
    nextId.value = id + 1;
  });

  /// Writes the fields over the chosen person.
  void update() => people.value = [
    for (final p in people.value)
      if (p.id == selected.value) Person(p.id, name.text, surname.text) else p,
  ];

  /// Deletes the chosen person.
  void remove() => batch(() {
    people.value = [
      for (final p in people.value)
        if (p.id != selected.value) p,
    ];
    selected.value = 0;
    name.text = '';
    surname.text = '';
  });
}

/// The CRUD's state.
final crud = CrudState();

/// The static lists: one value and several, reported to the state.
class PicksState extends ThorState {
  /// The chosen language.
  final language = state('en');

  /// The chosen toppings.
  final toppings = state(const <String>{'cheese'});

  /// Sets the language.
  void setLanguage(String? code) => language.value = code ?? '';

  /// Sets the toppings.
  void setToppings(Set<String> chosen) => toppings.value = chosen;

  /// What the language list says.
  String languageLabel() => 'Language: ${language.value}';

  /// What the toppings list says.
  String toppingsLabel() => 'Toppings: ${toppings.value.join(',')}';
}

/// The static lists' state.
final picks = PicksState();
