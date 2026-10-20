import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../session.dart';
import '../../../widgets/home.dart';

/// The page `/tag/:tag`.
class TagPage extends ThorPage<HomeData> {
  /// Shared by every visitor without a session ([publicPageCache]).
  const TagPage() : super(cache: publicPageCache);

  /// `/tag/:tag`: the global feed filtered by a tag.
  @override
  Future<HomeData> load(PageRequest request) =>
      loadHome(request, tag: request.pathParameters['tag']);

  /// `#tag • Conduit`.
  @override
  PageMeta meta(PageState<HomeData> state) =>
      PageMeta(title: '#${state.data.tag} • Conduit');

  /// Home, filtered.
  @override
  Widget build(BuildContext context, PageState<HomeData> state) =>
      HomeView(state.data, user: state.request.user);
}
