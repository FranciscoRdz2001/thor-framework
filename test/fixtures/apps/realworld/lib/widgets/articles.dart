import 'dart:convert';

import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/thor_ui.dart';

import '../api.dart';
import '../router.dart';
import '../routes/article/[slug]/page.dart' as article_page;
import '../ui.dart';
import 'nav.dart' show ConduitIcons;

const _author = TextStyle(color: brand, fontWeight: FontWeight.w500, height: 1);
const _date = TextStyle(
  color: light,
  fontSize: 12.8,
  fontWeight: FontWeight.w300,
  height: 1.25,
);

/// `.article-meta`: avatar, author and date, then [actions].
class ArticleMeta extends StatelessWidget implements ThorElementWidget {
  /// Meta of [article].
  const ArticleMeta(
    this.article, {
    super.key,
    this.actions = const [],
    this.authorColor,
  });

  /// The article.
  final Article article;

  /// Buttons after the date (favorite, follow, edit…).
  final List<Widget> actions;

  /// Author name color (the article banner uses the text color).
  final Color? authorColor;

  @override
  Widget build(BuildContext context) {
    final a = article.author;
    final profile = '/profile/${Uri.encodeComponent(a.username)}';
    return cls(
      'article-meta',
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        children: [
          Link(
            href: RouteUrl(profile),
            child: Avatar(a.image, name: a.username),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 24),
            child: cls(
              'info',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  cls(
                    'author',
                    Link(
                      href: RouteUrl(profile),
                      child: Text(
                        a.username,
                        style: _author.copyWith(color: authorColor),
                      ),
                    ),
                  ),
                  cls(
                    'date',
                    Text(dateString(article.createdAt), style: _date),
                  ),
                ],
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Favorite / unfavorite: a form posting to the article's action (works
/// without JS; the page reloads with the new count).
class FavoriteButton extends StatelessWidget implements ThorElementWidget {
  /// For [article]; [compact] = the list's heart and count.
  const FavoriteButton(this.article, {super.key, this.compact = false});

  /// The article.
  final Article article;

  /// Heart + count only.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final on = article.favorited;
    final label = compact
        ? '${article.favoritesCount}'
        : '${on ? 'Unfavorite' : 'Favorite'} Article (${article.favoritesCount})';
    return Form(
      action: '/article/${Uri.encodeComponent(article.slug)}',
      onPost: const article_page.ArticlePage().toggleFavorite,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HiddenField(name: 'favorited', value: '$on'),
          submitButton(
            label,
            on ? ButtonKind.primary : ButtonKind.outlinePrimary,
            size: ButtonSize.small,
            icon: const Icon(ConduitIcons.heart, size: 14),
          ),
        ],
      ),
    );
  }
}

/// Follow / unfollow [username] (a form posting to the page's action
/// method [onPost], of the page at [action] when it is another one).
class FollowButton extends StatelessWidget implements ThorElementWidget {
  /// Button for [username], [following] or not.
  const FollowButton({
    super.key,
    required this.username,
    required this.following,
    required this.onPost,
    this.action,
  });

  /// Who.
  final String username;

  /// Whether the viewer follows them.
  final bool following;

  /// The page's `toggleFollow`.
  final PagePost onPost;

  /// The URL of the page [onPost] belongs to, when it is not this one.
  final String? action;

  @override
  Widget build(BuildContext context) => Form(
    action: action,
    onPost: onPost,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HiddenField(name: 'following', value: '$following'),
        submitButton(
          '${following ? 'Unfollow' : 'Follow'} $username',
          following ? ButtonKind.secondary : ButtonKind.outlineSecondary,
          size: ButtonSize.small,
          icon: const Icon(ConduitIcons.plus, size: 14),
        ),
      ],
    ),
  );
}

/// `.article-preview`: meta, title, description and tags, linking to the
/// article.
class ArticlePreview extends StatelessWidget implements ThorElementWidget {
  /// Preview of [article]; [signedIn] shows the favorite button.
  const ArticlePreview(this.article, {super.key, required this.signedIn});

  /// The article.
  final Article article;

  /// Whether a user is signed in.
  final bool signedIn;

  @override
  Widget build(BuildContext context) => cls(
    'article-preview',
    Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: ArticleMeta(article)),
                if (signedIn)
                  cls('pull-xs-right', FavoriteButton(article, compact: true)),
              ],
            ),
          ),
          cls(
            'preview-link',
            Link(
              href: articleRoute.link({'slug': article.slug}),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    // The same tag as the article page's heading: the
                    // title travels there.
                    child: Hero(
                      tag: 'article-${article.slug}',
                      child: Semantics(
                        headingLevel: 1,
                        child: Text(
                          article.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                            color: ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Semantics(
                      role: SemanticsRole.paragraph,
                      child: Text(
                        article.description,
                        style: const TextStyle(
                          fontWeight: FontWeight.w300,
                          color: muted,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                  // One 24 px line: the tags float at its right and may run
                  // below it (the theme floats them; they add no height).
                  SizedBox(
                    height: 24,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Read more...',
                          style: TextStyle(
                            fontSize: 12.8,
                            fontWeight: FontWeight.w300,
                            color: light,
                          ),
                        ),
                        const Spacer(),
                        TagList(article.tagList, outline: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// `ul.tag-list` of [tags]; [linked] makes each a link to its tag page.
class TagList extends StatelessWidget {
  /// Tags as pills.
  const TagList(
    this.tags, {
    super.key,
    this.outline = false,
    this.linked = false,
  });

  /// The tags.
  final List<String> tags;

  /// `.tag-outline` pills.
  final bool outline;

  /// Links to `/tag/…`.
  final bool linked;

  @override
  Widget build(BuildContext context) => linked
      ? html.div(classes: 'tag-list', [
          for (final t in tags) TagPill(t, href: tagRoute.link({'tag': t})),
        ])
      : html.ul(classes: 'tag-list', [
          for (final t in tags) TagPill(t, outline: outline, tagName: 'li'),
        ]);
}

/// The list of previews (or the empty message) and its pagination.
class ArticleList extends StatelessWidget implements ThorElementWidget {
  /// [page] of [articles]; [pageHref] builds each page's link.
  const ArticleList({
    super.key,
    required this.articles,
    required this.page,
    required this.pageHref,
    required this.signedIn,
    this.empty = 'No articles are here... yet.',
    this.emptyLink = false,
  });

  /// The page.
  final ArticlePage articles;

  /// Current page (1-based).
  final int page;

  /// URL of page n.
  final String Function(int n) pageHref;

  /// Whether a user is signed in.
  final bool signedIn;

  /// Text when there are none.
  final String empty;

  /// Add a link to the global feed after [empty].
  final bool emptyLink;

  @override
  Widget build(BuildContext context) {
    final pages = (articles.count / pageSize).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (articles.articles.isEmpty)
          cls(
            'article-preview empty-feed-message',
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: hairline)),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: empty),
                    if (emptyLink) ...[
                      const TextSpan(text: ' Browse the '),
                      TextSpan(
                        text: 'Global Feed',
                        href: homeRoute.link(),
                        style: const TextStyle(color: brand),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ],
                ),
              ),
            ),
          )
        else
          for (final a in articles.articles)
            // The same preview for every visitor who sees the same values:
            // the key is everything it shows (the viewer's own `favorited`
            // included), so a personal feed shares only identical HTML.
            Cached(
              cacheKey: previewKey(a, signedIn: signedIn),
              child: ArticlePreview(a, signedIn: signedIn),
            ),
        if (pages > 1) Pagination(pages: pages, current: page, href: pageHref),
      ],
    );
  }
}

/// Everything an [ArticlePreview] of [a] shows, as a [Cached] key: two
/// previews with equal keys are the same HTML.
Object previewKey(Article a, {required bool signedIn}) => (
  signedIn,
  a.slug,
  a.title,
  a.description,
  jsonEncode(a.tagList),
  a.createdAt,
  a.author.username,
  a.author.image,
  a.favorited,
  a.favoritesCount,
);

/// `ul.pagination`: one link per page, the current one `.active`.
class Pagination extends StatelessWidget {
  /// Links to [pages] pages.
  const Pagination({
    super.key,
    required this.pages,
    required this.current,
    required this.href,
  });

  /// How many.
  final int pages;

  /// The current one.
  final int current;

  /// URL of page n.
  final String Function(int n) href;

  @override
  Widget build(BuildContext context) => html.nav([
    html.ul(classes: 'pagination', [
      for (var n = 1; n <= pages; n++)
        html.li(classes: n == current ? 'page-item active' : 'page-item', [
          html.a(href: href(n), classes: 'page-link', [Widget.text('$n')]),
        ]),
    ]),
  ]);
}
