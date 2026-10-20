import 'package:thor_ui/thor_ui.dart';

/// A card of the board.
class Task {
  const Task(this.id, this.title);
  final String id;
  final String title;
}

const _todo = [Task('t1', 'Pedir café'), Task('t2', 'Contar caja')];
const _doing = [Task('t3', 'Armar pedido')];

List<Object?> _encode(List<Task> v) => [
  for (final t in v) [t.id, t.title],
];
List<Task> _decode(Object? j) => [
  for (final t in j! as List) Task((t as List)[0] as String, t[1] as String),
];

/// A board of three columns that cards are dragged between, a chip that
/// carries a number, and a target that adds them up.
class BoardState extends ThorState {
  final todo = state(_todo, encode: _encode, decode: _decode);
  final doing = state(_doing, encode: _encode, decode: _decode);
  final done = state(const <Task>[], encode: _encode, decode: _decode);
  final last = state('Arrastra una tarjeta');
  final where = state('');
  final total = state(0);
  final starts = state(0);
  var _next = 4;

  String status() => last.value;
  String whereLabel() => where.value;
  String totalLabel() => 'Total: ${total.value}';
  String startsLabel() => 'Inicios: ${starts.value}';
  String taskKey(Task t) => t.id;
  String taskTitle(Task t) => t.title;

  List<Task> _all() => [...todo.value, ...doing.value, ...done.value];

  /// "Hecho" takes only what is in progress.
  bool canDrop(String column, String id) {
    if (column == 'done') return doing.value.any((t) => t.id == id);
    return true;
  }

  void moveTo(String column, String id) => batch(() {
    final task = _all().firstWhere((t) => t.id == id);
    List<Task> without(List<Task> l) => [
      for (final t in l)
        if (t.id != id) t,
    ];
    todo.value = without(todo.value);
    doing.value = without(doing.value);
    done.value = without(done.value);
    switch (column) {
      case 'todo':
        todo.value = [...todo.value, task];
      case 'doing':
        doing.value = [...doing.value, task];
      default:
        done.value = [...done.value, task];
    }
    last.value = '$id a $column';
  });

  void left(String column, String id) => last.value = '$id salió de $column';

  void moved(String column, double x, double y) =>
      where.value = '$column ${x.round()},${y.round()}';

  void started() => starts.value++;
  void completed() => last.value = 'Completada';
  void canceled(double x, double y) => last.value = 'Cancelada';
  void ended(bool accepted) =>
      where.value = accepted ? 'fin: aceptada' : 'fin: no';

  void add() => batch(() {
    todo.value = [...todo.value, Task('t${_next++}', 'Nueva ${_next - 1}')];
    last.value = 'Tarjeta añadida';
  });

  void addNumber(int n) => batch(() {
    total.value += n;
    last.value = 'Sumaste $n';
  });
}

final board = BoardState();
