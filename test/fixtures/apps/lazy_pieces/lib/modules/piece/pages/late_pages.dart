import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../state/piece_state.dart';

/// What `/stream` waits for.
class StreamData {
  const StreamData(this.slow);

  final Future<String> slow;
}

/// `/stream`: a `FutureBuilder` whose result arrives after the page, with a
/// button and a `Watch` of a state in it (the engine binds late content).
class StreamPage extends ThorPage<StreamData> {
  const StreamPage();

  @override
  Future<StreamData> load(PageRequest request) async => StreamData(
    defer(Future.delayed(const Duration(milliseconds: 300), () => 'ready')),
  );

  @override
  PageMeta meta(PageState<StreamData> state) => const PageMeta(title: 'Stream');

  @override
  Widget build(BuildContext context, PageState<StreamData> state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Stream header'),
      FutureBuilder<String>(
        future: state.data.slow,
        builder: (context, snap) => snap.hasData
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Late ${snap.data}'),
                  FilledButton(
                    onPressed: pieceState.increment,
                    child: const Text('Count late'),
                  ),
                  Watch(pieceState.label),
                ],
              )
            : const Text('Skeleton'),
      ),
    ],
  );
}

/// `/nested`: a piece with another piece inside, and a state in each.
class NestedPage extends ThorPage<void> {
  const NestedPage();

  @override
  Future<void> load(PageRequest request) async {}

  @override
  PageMeta meta(PageState<void> state) => const PageMeta(title: 'Nested');

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Nested header'),
      ExpansionTile(
        title: const Text('Outer tile'),
        children: [
          LazyPiece<String>(
            id: 'outer',
            load: (request) async => 'outer says hi',
            builder: (context, text) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text),
                FilledButton(
                  onPressed: pieceState.increment,
                  child: const Text('Count outer'),
                ),
                ExpansionTile(
                  title: const Text('Inner tile'),
                  children: [
                    LazyPiece<String>(
                      id: 'inner',
                      load: (request) async => 'inner says hi',
                      builder: (context, text) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(text),
                          FilledButton(
                            onPressed: pieceState.increment,
                            child: const Text('Count inner'),
                          ),
                          Watch(pieceState.label),
                        ],
                      ),
                      fallback: const Text('Inner needs JavaScript'),
                    ),
                  ],
                ),
              ],
            ),
            fallback: const Text('Outer needs JavaScript'),
          ),
        ],
      ),
    ],
  );
}
