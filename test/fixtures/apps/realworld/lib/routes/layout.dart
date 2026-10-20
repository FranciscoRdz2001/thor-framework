import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../api.dart';
import '../session.dart';
import '../widgets/nav.dart';

/// The layout of `/` and the pages below it.
class RootLayout extends ThorLayout<User?> {
  /// Pages whose data is slow answer early: status and the `Link` preload
  /// of the shared stylesheets go out while the API answers.
  const RootLayout() : super(earlyHints: true);

  /// The signed-in user (from the session cookie).
  @override
  User? load(PageRequest request) => request.user;

  /// Default title.
  @override
  PageMeta meta(PageState<User?> state) => const PageMeta(title: 'Conduit');

  /// Navbar above every page.
  @override
  Widget build(BuildContext context, PageState<User?> state, Widget child) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NavBar(user: state.data, path: state.uri.path),
          Semantics(
            role: SemanticsRole.main,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [child],
            ),
          ),
        ],
      );
}
