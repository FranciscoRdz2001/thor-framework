import 'package:thor_ui/thor_ui.dart';

class Pending {
  const Pending({required this.id, required this.title, this.done = false});

  final int id;
  final String title;
  final bool done;
}

/// Pendings whose rows are `CheckboxListTile`s with a delete button as the
/// `secondary`; they are added in the browser.
class PendingState extends ThorState {
  final todos = state<List<Pending>>(const [
    Pending(id: 1, title: 'Comprar leche'),
    Pending(id: 2, title: 'Llamar a Ana'),
  ]);
  final newText = state('');
  var _nextId = 3;

  String titleOf(Pending t) => t.title;
  String idOf(Pending t) => '${t.id}';
  bool isDone(Pending t) => t.done;

  String completionLabel() =>
      '${todos.value.where((t) => t.done).length} de ${todos.value.length} completadas';

  void setNewText(String value) => newText.value = value;

  void addPending() {
    final text = newText.value.trim();
    if (text.isEmpty) return;
    todos.value = [...todos.value, Pending(id: _nextId++, title: text)];
    newText.value = '';
  }

  void addPendingOnSubmit(String _) => addPending();

  void toggleDone(String id, bool? value) {
    final todoId = int.parse(id);
    todos.value = [
      for (final t in todos.value)
        if (t.id == todoId)
          Pending(id: t.id, title: t.title, done: value ?? false)
        else
          t,
    ];
  }

  void removePending(String id) {
    final todoId = int.parse(id);
    todos.value = [
      for (final t in todos.value)
        if (t.id != todoId) t,
    ];
  }
}

final pending = PendingState();
