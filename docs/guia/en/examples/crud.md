# CRUD list

A list of people filtered by the start of the surname, with buttons to create, update and delete.

:::flutter Flutter: `ListView.builder` and `setState` · Thor: `Watch.list` over a computed value

:::example recipe-crud
:::

## The filter is a computed value

`people` holds every person and `visible`, a computed value (`derived`), filters them once per change. Create, update and delete replace the list inside a `batch`, so the page updates only once.

```dart
class Person {
  const Person(this.id, this.name, this.surname);

  final int id;
  final String name;
  final String surname;

  factory Person.fromJson(Map<String, Object?> json) => Person(
    json['id']! as int,
    json['name']! as String,
    json['surname']! as String,
  );

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'surname': surname};
}

class PeopleViewModel extends ThorState {
  final people = state(const [Person(1, 'Hans', 'Emil')]);
  final prefix = state('');
  final selected = state(0);

  late final visible = derived(
    () => [
      for (final p in people.value)
        if (p.surname.toLowerCase().startsWith(prefix.value.toLowerCase())) p,
    ],
  );

  List<Person> rows() => visible.value;
  int idOf(Person p) => p.id;
  String label(Person p) => '${p.surname}, ${p.name}';
  bool isSelected(Person p) => p.id == selected.value;
  bool hasSelection() => selected.value != 0;

  void select(int id) => selected.value = id;
  void remove() => batch(() {
    people.value = [
      for (final p in people.value)
        if (p.id != selected.value) p,
    ];
    selected.value = 0;
  });
}
```

## One row per person

`Watch.list` renders the rows on the server; in the browser it adds, removes or updates only the row that changed, identified by `itemKey`. `row.watch` and `row.text` update what changes inside each row without rebuilding it.

```dart
Watch.list(
  people.rows,
  itemKey: people.idOf,
  each: (row) => row.watch(
    people.isSelected,
    builder: (on) => InkWell(
      onTap: people.select.withArg(row.key),
      child: row.text(people.label),
    ),
  ),
)
```

Update and Delete read `hasSelection` with a `Watch`: with no selection they receive `onPressed: null` and stay disabled.

Related: [State](../state.md) · [Long lists](../long-lists.md)
