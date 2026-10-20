import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../state/piece_state.dart';

Widget _piece(
  String id,
  int millis,
  LazyTrigger trigger, {
  bool withList = false,
}) => LazyPiece<String>(
  id: id,
  trigger: trigger,
  load: (request) async {
    await Future<void>.delayed(Duration(milliseconds: millis));
    return '$id ready';
  },
  builder: (context, text) => Container(
    // A class the page itself does not have: the piece brings its rule.
    color: const Color(0xFF1A2B3C),
    padding: const EdgeInsets.all(7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text),
        FilledButton(onPressed: pieceState.increment, child: Text('Count $id')),
        Watch(pieceState.label),
        if (withList)
          Watch.list(
            pieceState.rowsOf.withArg('x'),
            itemKey: pieceState.rowKey,
            each: (row) => row.text(pieceState.rowName),
          ),
      ],
    ),
  ),
  fallback: Text('$id waits'),
);

/// `/burst`: pieces that load at once and together, in a page that has no
/// state of its own (so only the pieces bring the engine), and one far down
/// that is `idle` (a visitor who saves data gets it when it comes near).
class BurstPage extends ThorPage<void> {
  const BurstPage();

  @override
  Future<void> load(PageRequest request) async {}

  @override
  PageMeta meta(PageState<void> state) => const PageMeta(title: 'Burst');

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Burst header'),
      _piece('p1', 150, LazyTrigger.idle),
      _piece('p2', 300, LazyTrigger.idle, withList: true),
      _piece('p3', 50, LazyTrigger.visible),
      const SizedBox(height: 2400),
      _piece('far', 50, LazyTrigger.idle),
    ],
  );
}
