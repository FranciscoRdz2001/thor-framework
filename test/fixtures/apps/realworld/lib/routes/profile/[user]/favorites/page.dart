import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../../api.dart';
import '../../../../session.dart';
import '../../../../widgets/articles.dart';

/// The page `/profile/:user/favorites`.
class ProfileFavoritesPage extends ThorPage<(ArticlePage, int)> {
  /// Shared by every visitor without a session ([publicPageCache]).
  const ProfileFavoritesPage() : super(cache: publicPageCache);

  /// Page `?page=N` of the articles the user favorited.
  @override
  Future<(ArticlePage, int)> load(PageRequest request) async {
    final page = int.tryParse(request.queryParameters['page'] ?? '') ?? 1;
    return (
      await api.articles(
        token: request.user?.token,
        favorited: request.pathParameters['user'],
        page: page,
      ),
      page,
    );
  }

  /// The favorited articles.
  @override
  Widget build(BuildContext context, PageState<(ArticlePage, int)> state) =>
      ArticleList(
        articles: state.data.$1,
        page: state.data.$2,
        pageHref: (n) => '${state.uri.path}?page=$n',
        signedIn: state.request.user != null,
      );
}
