import 'package:thor_ui/thor_ui.dart';

import 'store_state.dart';

const _departments = ['food', 'home', 'toys'];

/// A menu of departments: an exclusive accordion, one list per department
/// over the same state (`branchOf.withArg(slug)`), rows that are links
/// (`Link` with no href under `row.attribute(AttributeName.href, …)`), and what the
/// accordion's `onExpansionChanged` heard.
class StorePage extends StatelessWidget implements ThorElementWidget {
  const StorePage({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Store'),
      for (final slug in _departments)
        ExpansionTile(
          name: 'menu',
          title: Text('Dept $slug'),
          onExpansionChanged: store.toggled.withArg(slug),
          children: [
            Watch.list(
              store.branchOf.withArg(slug),
              itemKey: store.rowKey,
              // Flutter's Column centers: rows from the start edge say so.
              container: (rows) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rows,
              ),
              each: (row) => row.attribute(
                AttributeName.href,
                store.rowUrl,
                child: Link(child: row.text(store.rowName)),
              ),
            ),
            TextButton(
              onPressed: store.addTo.withArg(slug),
              child: Text('Add to $slug'),
            ),
          ],
        ),
      const Text('Log'),
      Watch(store.logText),
      // The default container: Flutter's Column, which centers.
      SizedBox(
        width: 300,
        child: Watch.list(
          store.branchOf.withArg('food'),
          itemKey: store.rowKey,
          each: (row) => row.text(store.rowName),
        ),
      ),
    ],
  );
}
