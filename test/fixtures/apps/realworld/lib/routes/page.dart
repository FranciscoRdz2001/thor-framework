import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../session.dart';
import '../widgets/home.dart';

/// The page `/`.
class HomePage extends ThorPage<HomeData> {
  /// Shared by every visitor without a session ([publicPageCache]).
  const HomePage() : super(cache: publicPageCache);

  /// `/`: the global feed (or "Your Feed" with `?feed=following`).
  @override
  Future<HomeData> load(PageRequest request) => loadHome(request);

  /// Home.
  @override
  Widget build(BuildContext context, PageState<HomeData> state) =>
      HomeView(state.data, user: state.request.user);
}
