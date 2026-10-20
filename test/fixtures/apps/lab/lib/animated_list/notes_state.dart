import 'package:thor_ui/thor_ui.dart';

class Note {
  const Note(this.id, this.title);

  final int id;
  final String title;
}

const _first = [
  Note(1, 'Comprar pan'),
  Note(2, 'Llamar a Ana'),
  Note(3, 'Pagar la luz'),
];

/// The list the page animates: adding or removing a note is changing the
/// list; the rows enter and leave by themselves.
class NotesState extends ThorState {
  final notes = state<List<Note>>(_first);
  var _next = 4;

  int idOf(Note n) => n.id;
  String titleOf(Note n) => n.title;
  String countLabel() => '${notes.value.length} notas';

  void add() {
    final id = _next;
    _next = id + 1;
    notes.value = [Note(id, 'Nota $id'), ...notes.value];
  }

  void remove(int id) => notes.value = [
    for (final n in notes.value)
      if (n.id != id) n,
  ];

  void clear() => notes.value = const [];
  void reset() => notes.value = _first;
}

final notes = NotesState();
