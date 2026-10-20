import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../api.dart';
import '../router.dart';
import '../session.dart';
import '../ui.dart';
import 'articles.dart';
import 'nav.dart' show ConduitIcons;

/// What the home page shows.
class HomeData {
  /// Articles of the tab ([tag] when filtered), [page], and the popular tags.
  const HomeData({
    required this.articles,
    required this.tags,
    required this.page,
    required this.feed,
    this.tag,
  });

  /// The articles.
  final ArticlePage articles;

  /// Popular tags.
  final List<String> tags;

  /// Current page.
  final int page;

  /// "Your Feed" (followed authors).
  final bool feed;

  /// The tag filter.
  final String? tag;
}

/// Loads `/`, `/?feed=following`, `/?page=N` and `/tag/:tag` (articles and
/// tags in parallel). "Your Feed" needs a user.
Future<HomeData> loadHome(PageRequest request, {String? tag}) async {
  final feed = tag == null && request.queryParameters['feed'] == 'following';
  final user = request.user;
  if (feed && user == null) throw Redirect.found(loginRoute.link());
  final page = int.tryParse(request.queryParameters['page'] ?? '') ?? 1;
  final (articles, tags) = await (
    api.articles(
      token: user?.token,
      feed: feed,
      page: page < 1 ? 1 : page,
      tag: tag,
    ),
    api.tags(),
  ).wait;
  return HomeData(
    articles: articles,
    tags: tags,
    page: page,
    feed: feed,
    tag: tag,
  );
}

const _tab = TextStyle(color: lighter);
const _tabOn = TextStyle(color: brand);

/// The home page: banner (guests), feed tabs, articles, popular tags.
class HomeView extends StatelessWidget implements ThorElementWidget {
  /// For [data], signed in as [user].
  const HomeView(this.data, {super.key, required this.user});

  /// What to show.
  final HomeData data;

  /// Signed-in user.
  final User? user;

  @override
  Widget build(BuildContext context) {
    final tag = data.tag;
    String pageHref(int n) => tag != null
        ? '/tag/${Uri.encodeComponent(tag)}?page=$n'
        : data.feed
        ? '/?feed=following&page=$n'
        : '/?page=$n';
    return cls(
      'home-page',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (user == null) const _Banner(),
          Padding(
            padding: EdgeInsets.only(top: user == null ? 0 : 24),
            child: PageContainer(
              classes: 'container page',
              child: GridRow(
                children: [
                  Col(
                    md: 9,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        cls(
                          'feed-toggle',
                          Padding(
                            padding: EdgeInsets.zero,
                            child: cls(
                              'nav nav-pills outline-active',
                              Semantics(
                                role: SemanticsRole.list,
                                child: Row(
                                  children: [
                                    _tabItem(
                                      '/',
                                      const Text('Global Feed'),
                                      active: !data.feed && tag == null,
                                    ),
                                    if (user != null)
                                      _tabItem(
                                        '/?feed=following',
                                        const Text('Your Feed'),
                                        active: data.feed,
                                      ),
                                    if (tag != null)
                                      _tabItem(
                                        '/tag/${Uri.encodeComponent(tag)}',
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          spacing: 2,
                                          children: [
                                            const Icon(
                                              ConduitIcons.pound,
                                              size: 14,
                                            ),
                                            Text(tag),
                                          ],
                                        ),
                                        active: true,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        ArticleList(
                          articles: data.articles,
                          page: data.page,
                          pageHref: pageHref,
                          signedIn: user != null,
                          empty: data.feed
                              ? 'Your feed is empty. Follow some authors to see their articles here.'
                              : 'No articles are here... yet.',
                          emptyLink: data.feed,
                        ),
                      ],
                    ),
                  ),
                  Col(
                    md: 3,
                    // The sidebar is its own element: its margin must not
                    // add to the column's width.
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        cls(
                          'sidebar',
                          Container(
                            padding: const EdgeInsets.only(left: 20),
                            margin: const EdgeInsets.only(left: 10),
                            decoration: const BoxDecoration(
                              border: Border(left: BorderSide(color: hairline)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 3.2),
                                  child: Semantics(
                                    role: SemanticsRole.paragraph,
                                    child: Text('Popular Tags'),
                                  ),
                                ),
                                TagList(data.tags, linked: true),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabItem(String href, Widget label, {required bool active}) => cls(
    'nav-item',
    Semantics(
      role: SemanticsRole.listItem,
      child: Container(
        child: cls(
          active ? 'nav-link active' : 'nav-link',
          Link(
            href: RouteUrl(href),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: active ? brand : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: DefaultTextStyle(
                style: active
                    ? _tabOn
                    : _tab.copyWith(
                        color: lighter.when(hover: const Color(0xFF555555)),
                      ),
                child: label,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Banner extends StatelessWidget implements ThorElementWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) => cls(
    'banner',
    const Container(
      padding: EdgeInsets.all(32),
      margin: EdgeInsets.only(bottom: 32),
      decoration: BoxDecoration(
        color: white,
        border: Border(
          top: BorderSide(color: hairline),
          bottom: BorderSide(color: hairline),
        ),
      ),
      child: PageContainer(
        child: Column(
          children: [
            // The theme's h1: 3.5rem × 1.1 line, the 3rem logo centered in it.
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: SizedBox(
                height: 61.6,
                child: Center(
                  child: html.h1(classes: 'logo-font', [
                    html.img(
                      src: '/conduit-logo.svg',
                      alt: 'Conduit',
                      attributes: {'style': 'height:3rem;display:block'},
                    ),
                  ]),
                ),
              ),
            ),
            Semantics(
              role: SemanticsRole.paragraph,
              child: Text(
                'A place to share your knowledge.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w300, color: muted),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
