import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../state/piece_state.dart';

/// How many times the server drew each piece (`/piece` shows it inside the
/// piece, so the check sees one request per opening).
final _drawn = <String, int>{};

/// A department of the lazy accordion.
const _departments = {
  'food': ['fruit', 'bread', 'cheese'],
  'home': ['lamp', 'sofa'],
  'broken': ['never'],
};

/// What `/piece` loads: `?engine=1` also uses the state outside the pieces, so
/// the page ships the engine itself (without it, only the piece brings it).
class PieceData {
  const PieceData({required this.engine});

  final bool engine;
}

/// `/piece`: parts of the page the browser asks for when they are needed
/// (`LazyPiece`): the branches of an accordion, a dialog and a block
/// far down the page, plus one whose first request fails.
class PiecePage extends ThorPage<PieceData> {
  const PiecePage();

  @override
  Future<PieceData> load(PageRequest request) async =>
      PieceData(engine: request.queryParameters['engine'] == '1');

  @override
  PageMeta meta(PageState<PieceData> state) => const PageMeta(title: 'Pieces');

  @override
  Widget build(BuildContext context, PageState<PieceData> state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: [
      const Text('Header (not lazy)'),
      if (state.data.engine) ...[
        FilledButton(
          onPressed: pieceState.increment,
          child: const Text('Count page'),
        ),
        Watch(pieceState.label),
      ],
      for (final MapEntry(key: slug, value: _) in _departments.entries)
        ExpansionTile(
          key: ValueKey('tile-$slug'),
          name: 'departments',
          title: Text('Department $slug'),
          children: [
            LazyPiece<List<String>>(
              id: 'branch-$slug',
              load: (request) async {
                final n = _drawn[slug] = (_drawn[slug] ?? 0) + 1;
                // The first request of this one fails: the next opening retries.
                if (slug == 'broken' && n == 1) throw const NotFound();
                await Future<void>.delayed(const Duration(milliseconds: 120));
                return _departments[slug]!;
              },
              builder: (context, rows) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Branch $slug drawn ${_drawn[slug]}'),
                  for (final r in rows)
                    Link(
                      href: RouteUrl('/piece?item=$r'),
                      child: Text('Item $r'),
                    ),
                  FilledButton(
                    onPressed: pieceState.increment,
                    child: Text('Count $slug'),
                  ),
                  Watch(pieceState.label),
                ],
              ),
              fallback: Link(
                href: RouteUrl('/piece?all=$slug'),
                child: Text('See all of $slug'),
              ),
            ),
          ],
        ),
      DialogTrigger(
        id: 'more',
        child: FilledButton(onPressed: () {}, child: const Text('Open more')),
      ),
      Dialog(
        id: 'more',
        child: LazyPiece<String>(
          id: 'dialog',
          load: (request) async => 'Inside the dialog',
          builder: (context, text) => Text(text),
          fallback: const Text('Dialog content needs JavaScript'),
        ),
      ),
      const SizedBox(height: 2400),
      LazyPiece<String>(
        id: 'footer',
        trigger: LazyTrigger.visible,
        load: (request) async => 'Footer piece',
        builder: (context, text) => Text(text),
        fallback: const Text('Footer waits'),
      ),
      const Text('Footer (not lazy)'),
    ],
  );
}
