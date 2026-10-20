# Lista con CRUD

Una lista de personas que se filtra por el inicio del apellido, con botones para crear, actualizar y borrar.

:::flutter Flutter: `ListView.builder` y `setState` · Thor: `Watch.list` sobre un valor calculado

:::example recipe-crud
:::

## El filtro es un valor calculado

`people` guarda todas las personas y `visible`, un valor calculado (`derived`), las filtra una vez por cambio. Crear, actualizar y borrar reemplazan la lista dentro de un `batch`, así la página se actualiza una sola vez.

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

## Una fila por persona

`Watch.list` renderiza las filas en el servidor; en el navegador agrega, quita o actualiza solo la fila que cambió, identificada por `itemKey`. `row.watch` y `row.text` actualizan lo que cambia dentro de cada fila sin reconstruirla.

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

Actualizar y Borrar leen `hasSelection` con un `Watch`: sin selección reciben `onPressed: null` y quedan deshabilitados.

Relacionado: [Estado](../estado.md) · [Listas largas](../listas-largas.md)
