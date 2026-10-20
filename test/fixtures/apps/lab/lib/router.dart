// The app's routes: one page per widget behaviour the browser checks drive.
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import 'animated_list/page.dart';
import 'animations/page.dart';
import 'controls/page.dart';
import 'dates/page.dart';
import 'drag/page.dart';
import 'edge_cases/app.dart';
import 'gestures/page.dart';
import 'list_box/page.dart';
import 'nested_watch/page.dart';
import 'rows/page.dart';
import 'store_lists/page.dart';
import 'widgets/page.dart';

/// A fixture page: [page] with the [title] the old one-page app had.
class FixturePage extends ThorPage<void> {
  /// The page of [page] titled [title].
  const FixturePage(this.title, this.page);

  /// The document title.
  final String title;

  /// What the page shows.
  final Widget page;

  @override
  PageMeta meta(PageState<void> state) => PageMeta(title: title);

  @override
  Widget build(BuildContext context, PageState<void> state) => page;
}

/// The index: a link to every fixture.
class IndexPage extends ThorPage<void> {
  /// The index.
  const IndexPage();

  @override
  PageMeta meta(PageState<void> state) => const PageMeta(title: 'Fixtures');

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    children: [
      for (final path in fixturePaths)
        Link(href: RouteUrl(path), child: Text(path)),
    ],
  );
}

/// The path of every fixture page.
const fixturePaths = [
  '/animated-list',
  '/animations',
  '/controls',
  '/dates',
  '/drag',
  '/edge-cases',
  '/gestures',
  '/nested-watch',
  '/list-box',
  '/rows',
  '/store-lists',
  '/widgets',
];

/// Every route of the app.
final ThorRouter router = ThorRouter([
  Group(
    children: [
      ThorRoute('/', const IndexPage()),
      ThorRoute(
        '/animated-list',
        const FixturePage('Lista animada', NotesPage()),
      ),
      ThorRoute(
        '/animations',
        const FixturePage('Animaciones', AnimationsPage()),
      ),
      ThorRoute(
        '/controls',
        const FixturePage('Controladores', ControlsPage()),
      ),
      ThorRoute('/dates', const FixturePage('Fechas', DatesPage())),
      ThorRoute('/drag', const FixturePage('Arrastrar', DragPage())),
      ThorRoute('/edge-cases', const FixturePage('thor_ui edge cases', App())),
      ThorRoute('/gestures', const FixturePage('Gestos', GesturesPage())),
      ThorRoute(
        '/nested-watch',
        const FixturePage('Nested Watch', NestedWatchPage()),
      ),
      ThorRoute('/list-box', const FixturePage('ListBox', ListBoxPage())),
      ThorRoute('/rows', const FixturePage('Tareas', RowsPage())),
      ThorRoute('/store-lists', const FixturePage('Store lists', StorePage())),
      ThorRoute('/widgets', const FixturePage('Widgets', LabPage())),
    ],
  ),
]);
