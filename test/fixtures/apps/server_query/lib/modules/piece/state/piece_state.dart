import 'package:thor_ui/thor_ui.dart';

/// The `/piece` page's state: a counter inside content the browser asked for
/// after the page loaded (`LazyPiece`).
class PieceState extends ThorState {
  final count = state(0);

  void increment() => count.value++;

  String label() => 'clicks=${count.value}';
}

/// The `/piece` page's state.
final pieceState = PieceState();
