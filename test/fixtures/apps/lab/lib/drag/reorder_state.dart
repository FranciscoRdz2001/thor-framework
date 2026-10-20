import 'package:thor_ui/thor_ui.dart';

/// An entry of the to-do list.
class Todo {
  const Todo(this.id, this.title);
  final String id;
  final String title;
}

const _seed = [
  Todo('a', 'Pedir café'),
  Todo('b', 'Contar caja'),
  Todo('c', 'Armar pedido'),
  Todo('d', 'Cerrar turno'),
];

/// A list whose rows are reordered, and a row of chips with handles of its own.
class ReorderState extends ThorState {
  final todos = state(
    _seed,
    encode: (v) => [
      for (final t in v) [t.id, t.title],
    ],
    decode: (j) => [
      for (final t in j! as List)
        Todo((t as List)[0] as String, t[1] as String),
    ],
  );
  final last = state('Reordena la lista');
  final events = state('');
  final chips = state(
    const ['uno', 'dos', 'tres'],
    encode: (v) => v,
    decode: (j) => [for (final s in j! as List) s as String],
  );
  var _next = 0;

  String status() => last.value;
  String eventsLabel() => events.value;
  String todoKey(Todo t) => t.id;
  String todoTitle(Todo t) => t.title;
  String order() => 'Orden: ${todos.value.map((t) => t.id).join(',')}';
  String chipOrder() => 'Fichas: ${chips.value.join(',')}';

  /// Flutter's convention: `newIndex` counts the list before the item leaves.
  void reorder(int oldIndex, int newIndex) => batch(() {
    final list = [...todos.value];
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, moved);
    todos.value = list;
    last.value = '${moved.id}: $oldIndex a $newIndex';
  });

  void started(int index) => events.value = 'inicio $index';
  void ended(int index) => events.value = '${events.value} fin $index';

  void reorderChips(int oldIndex, int newIndex) => batch(() {
    final list = [...chips.value];
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, moved);
    chips.value = list;
  });

  void add() => batch(() {
    todos.value = [...todos.value, Todo('n$_next', 'Nueva ${_next++}')];
    last.value = 'Añadida';
  });
}

final reorders = ReorderState();
