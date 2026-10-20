import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../api.dart';
import '../../../session.dart';
import '../../../widgets/articles.dart';

/// The page `/profile/:user`.
class ProfilePage extends ThorPage<(ArticlePage, int)> {
  /// Shared by every visitor without a session ([publicPageCache]).
  const ProfilePage() : super(cache: publicPageCache);

  /// Page `?page=N` of the user's articles.
  @override
  Future<(ArticlePage, int)> load(PageRequest request) async {
    final page = int.tryParse(request.queryParameters['page'] ?? '') ?? 1;
    return (
      await api.articles(
        token: request.user?.token,
        author: request.pathParameters['user'],
        page: page,
      ),
      page,
    );
  }

  /// Follow / unfollow (the button in the profile header).
  Future<ActionResult?> toggleFollow(PageRequest request) async {
    final user = request.signedIn;
    final following = (await request.form())['following'] == 'true';
    await api.follow(
      user.token,
      request.pathParameters['user']!,
      on: !following,
    );
    return null;
  }

  /// The user's articles.
  @override
  Widget build(BuildContext context, PageState<(ArticlePage, int)> state) =>
      ArticleList(
        articles: state.data.$1,
        page: state.data.$2,
        pageHref: (n) => '${state.uri.path}?page=$n',
        signedIn: state.request.user != null,
      );
}
