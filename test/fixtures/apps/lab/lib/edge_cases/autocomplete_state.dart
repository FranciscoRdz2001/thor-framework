import 'package:thor_ui/thor_ui.dart';

/// What the `Autocomplete` case picks (a pick reaches the state with the
/// option) and a list of suggestions that follows the typed text (the way a
/// store search keeps it).
class AutocompleteState extends ThorState {
  final picked = state('none');
  final picks = state(0);
  final suggestions = state(const <String>[]);

  /// Rows that each hold an `Autocomplete` (ids stay unique per row).
  final rows = state(const <String>['one', 'two']);

  void addRow() => rows.value = [...rows.value, 'row${rows.value.length + 1}'];

  void pick(String value) => batch(() {
    picked.value = value;
    picks.value++;
  });

  String pickedLabel() => 'Picked: ${picked.value} (${picks.value})';

  /// The names that contain [text] (the state's own search).
  void search(String text) {
    final q = text.toLowerCase();
    suggestions.value = q.isEmpty
        ? const <String>[]
        : [
            for (final n in const ['Café', 'Cacao', 'Té verde', 'Té negro'])
              if (n.toLowerCase().contains(q)) n,
          ];
  }

  String nameOf(String name) => name;
}

final autocomplete = AutocompleteState();
