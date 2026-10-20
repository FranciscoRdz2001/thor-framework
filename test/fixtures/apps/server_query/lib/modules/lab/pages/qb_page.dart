import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../state/qb_state.dart';

/// `/qb`: `QueryBuilder` over the ways a query can end (null, error while
/// the argument moves) for its browser check.
class QbPage extends ThorPage<void> {
  const QbPage();

  @override
  PageMeta meta(PageState<void> state) => const PageMeta(title: 'QueryBuilder');

  static String _s(String name, AsyncSnapshot<Object?> snap) =>
      '$name: ${snap.hasError ? 'error' : snap.connectionState.name}'
      '${snap.hasData ? ' con dato' : ' sin dato'}';

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 8,
    children: [
      Row(
        spacing: 8,
        children: [
          OutlinedButton(
            onPressed: qb.maybeFor.withArg(0),
            child: const Text('Maybe 0'),
          ),
          OutlinedButton(
            onPressed: qb.maybeFor.withArg(7),
            child: const Text('Maybe 7'),
          ),
          OutlinedButton(
            onPressed: qb.flakyFor.withArg(0),
            child: const Text('Flaky 0'),
          ),
          OutlinedButton(
            onPressed: qb.flakyFor.withArg(5),
            child: const Text('Flaky 5'),
          ),
        ],
      ),
      // A query that answers null: "done without data" is a state of its own.
      QueryBuilder<int?>(
        query: qb.maybe,
        builder: (context, snap) => snap.hasData
            ? Row(
                spacing: 6,
                children: [Text(_s('maybe', snap)), Watch(qb.maybeText)],
              )
            : Text(_s('maybe', snap)),
      ),
      // Two builders over one query, and one inside another.
      QueryBuilder<int>(
        query: qb.flaky,
        initialData: 0,
        builder: (context, snap) => snap.hasError
            ? Row(
                spacing: 6,
                children: [Text(_s('flaky', snap)), QueryError(qb.flaky)],
              )
            : Column(
                children: [
                  Text(_s('flaky', snap)),
                  QueryBuilder<int?>(
                    query: qb.maybe,
                    builder: (context, inner) => Text(_s('dentro', inner)),
                  ),
                ],
              ),
      ),
      QueryBuilder<int>(
        query: qb.flaky,
        initialData: 0,
        builder: (context, snap) => Text(_s('otro', snap)),
      ),
      // A builder inside the rows of a list.
      Watch.list(
        qb.rowList,
        itemKey: qb.rowKey,
        each: (row) => Row(
          spacing: 6,
          children: [
            row.text(qb.rowText),
            QueryBuilder<int?>(
              query: qb.maybe,
              builder: (context, snap) => Text(_s('fila', snap)),
            ),
          ],
        ),
      ),
    ],
  );
}
