import 'package:thor_ui/thor_ui.dart';

/// The `/piece` page's state: a counter inside content the browser asked for
/// after the page loaded (`LazyPiece`), and a list the pieces of `/burst` show.
class PieceState extends ThorState {
  final count = state(0);
  final rows = state(const ['x', 'y']);

  void increment() => count.value++;

  void addRow() => rows.value = [...rows.value, 'r${rows.value.length}'];

  String label() => 'clicks=${count.value}';

  /// A list per instance: `Watch.list(pieceState.rowsOf.withArg(prefix))`.
  List<String> rowsOf(String prefix) => [
    for (final r in rows.value)
      if (r.startsWith(prefix)) r,
  ];

  String rowKey(String row) => row;
  String rowName(String row) => row;
}

/// The `/piece` page's state.
final pieceState = PieceState();
