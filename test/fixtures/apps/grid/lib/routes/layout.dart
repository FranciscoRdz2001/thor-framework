import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

/// The layout of `/` and the pages below it.
class RootLayout extends ThorLayout<void> {
  /// The one instance the build shares between requests.
  const RootLayout();

  /// Default meta of the pages below (a page's own meta wins).
  @override
  PageMeta meta(PageState<void> state) => const PageMeta(title: 'Launch HQ');

  /// The frame: the grid fills the window.
  @override
  Widget build(BuildContext context, PageState<void> state, Widget child) =>
      DefaultTextStyle(
        style: const TextStyle(fontSize: 13, color: Color(0xFF1D1F25)),
        child: child,
      );
}
