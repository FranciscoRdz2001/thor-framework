import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../grid_state.dart';
import '../view.dart';
import '../widgets/drawer.dart';
import '../widgets/table.dart';
import '../widgets/toolbar.dart';

/// The page `/`.
class HomePage extends ThorPage<ViewConfig> {
  /// The one instance the build shares between requests.
  const HomePage();

  /// The view from the URL: filters, sorts, grouping, hidden fields,
  /// search and row height.
  @override
  ViewConfig load(PageRequest request) =>
      ViewConfig.fromQuery(request.uri.queryParametersAll);

  /// Title and description of `/`.
  @override
  PageMeta meta(PageState<ViewConfig> state) => const PageMeta(
    title: 'Launches · Grid view',
    description: 'Product launches: a grid of 2,000 records built with thor.',
  );

  /// `/`: the grid, its first screen rendered for the URL's view.
  @override
  Widget build(BuildContext context, PageState<ViewConfig> state) {
    grid.applyView(state.data);
    return const GridPage();
  }
}

class GridPage extends StatelessWidget implements ThorElementWidget {
  const GridPage({super.key});

  @override
  Widget build(BuildContext context) => Styled(
    style: StyleProps(minHeight: 100.dvh, maxHeight: 100.dvh),
    child: const Semantics(
      role: SemanticsRole.main,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TopBar(),
          ViewToolbar(),
          BulkBar(),
          Expanded(child: GridTable()),
          RecordDrawer(),
        ],
      ),
    ),
  );
}
