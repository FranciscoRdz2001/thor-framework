import 'package:thor_ui/html.dart' as dom;
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';
import 'package:thor_ui/web.dart' as web;

import '../../../api.dart';
import '../../../markdown.dart';
import '../../../router.dart';
import '../../../session.dart';
import '../../../ui.dart';
import '../../../widgets/articles.dart';
import '../../../widgets/auth.dart' show FormFailure, safeRedirect;
import '../../../widgets/nav.dart' show ConduitIcons, ionIcon;

/// The article and its comments.
typedef ArticleData = ({Article article, List<Comment> comments});

/// The page `/article/:slug`.
class ArticlePage extends ThorPage<ArticleData> {
  /// Shared by every visitor without a session ([publicPageCache]).
  const ArticlePage() : super(cache: publicPageCache);

  /// Loads the article and its comments in parallel.
  @override
  Future<ArticleData> load(PageRequest request) async {
    final slug = request.pathParameters['slug']!;
    final token = request.user?.token;
    final (article, comments) = await (
      api.article(slug, token: token),
      api.comments(slug, token: token),
    ).wait;
    return (article: article, comments: comments);
  }

  // Comments, favorites, follows and deletion; each redirects back.

  /// Adds a comment.
  Future<ActionResult?> createComment(PageRequest request) async {
    final user = request.signedIn;
    final body = ((await request.form())['comment'] ?? '').trim();
    if (body.isEmpty) {
      return const ActionResult.fail(
        422,
        FormFailure(["comment can't be blank"]),
      );
    }
    await api.addComment(user.token, _slug(request), body);
    return null;
  }

  /// Deletes the comment of the form's `id`.
  Future<ActionResult?> deleteComment(PageRequest request) async {
    final user = request.signedIn;
    await api.deleteComment(
      user.token,
      _slug(request),
      (await request.form())['id'] ?? '',
    );
    return null;
  }

  /// Favorite / unfavorite (also from the lists, which post here).
  Future<ActionResult?> toggleFavorite(PageRequest request) async {
    final user = request.signedIn;
    final favorited = (await request.form())['favorited'] == 'true';
    await api.favorite(user.token, _slug(request), on: !favorited);
    return _back(
      request,
      RouteUrl('/article/${Uri.encodeComponent(_slug(request))}'),
    );
  }

  /// Follow / unfollow the author.
  Future<ActionResult?> toggleFollow(PageRequest request) async {
    final user = request.signedIn;
    final form = await request.form();
    final article = await api.article(_slug(request), token: user.token);
    await api.follow(
      user.token,
      article.author.username,
      on: form['following'] != 'true',
    );
    return null;
  }

  /// Deletes the article.
  Future<ActionResult?> deleteArticle(PageRequest request) async {
    await api.deleteArticle(request.signedIn.token, _slug(request));
    return Redirect(homeRoute.link());
  }

  /// The article's title, description, Open Graph and structured data.
  @override
  PageMeta meta(PageState<ArticleData> state) {
    final article = state.data.article;
    return PageMeta(
      title: article.title,
      description: article.description,
      openGraph: OpenGraph(
        type: 'article',
        title: article.title,
        description: article.description,
        siteName: 'Conduit',
      ),
      jsonLd: [
        {
          '@context': 'https://schema.org',
          '@type': 'Article',
          'headline': article.title,
          'description': article.description,
          'datePublished': article.createdAt.toUtc().toIso8601String(),
          'author': {'@type': 'Person', 'name': article.author.username},
        },
      ],
    );
  }

  /// The article page.
  @override
  Widget build(BuildContext context, PageState<ArticleData> state) {
    final (:article, :comments) = state.data;
    final user = state.request.user;
    final failure = state.form as FormFailure?;
    final mine = user?.username == article.author.username;
    final slug = Uri.encodeComponent(article.slug);
    List<Widget> actions() => mine
        ? [
            cls(
              'btn btn-sm btn-outline-secondary',
              Link(
                href: editorBySlugRoute.link({'slug': slug}),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: secondary),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      Icon(ConduitIcons.edit, size: 14),
                      Text(
                        'Edit Article',
                        style: TextStyle(
                          fontSize: 14,
                          color: secondary,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Form(
                onPost: deleteArticle,
                child: submitButton(
                  'Delete Article',
                  ButtonKind.outlineDanger,
                  size: ButtonSize.small,
                  icon: const Icon(ConduitIcons.trash, size: 14),
                ),
              ),
            ),
          ]
        : user == null
        ? const []
        : [
            FollowButton(
              username: article.author.username,
              following: article.author.following,
              onPost: toggleFollow,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FavoriteButton(article),
            ),
          ];

    // The article rises in over the list (the app cross-fades); its title
    // travels from the list (Hero).
    return PageTransitionScope(
      transition: const PageTransition.fadeUp(),
      child: cls(
        'article-page',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cls(
              'banner',
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32),
                margin: const EdgeInsets.only(bottom: 32),
                decoration: const BoxDecoration(
                  color: white,
                  border: Border(
                    top: BorderSide(color: hairline),
                    bottom: BorderSide(color: hairline),
                  ),
                ),
                child: PageContainer(
                  maxWidth: 720,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'article-${article.slug}',
                        child: Semantics(
                          headingLevel: 1,
                          child: Text(
                            article.title,
                            style: const TextStyle(
                              fontSize: 44.8,
                              fontWeight: FontWeight.w600,
                              color: nearBlack,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: ArticleMeta(
                          article,
                          actions: actions(),
                          authorColor: ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            PageContainer(
              classes: 'container page',
              // The body column is 720 px of content (the banner's 720 include
              // the gutters).
              maxWidth: 750,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  cls(
                    'row article-content',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // The same for every visitor: converted once per process
                        // and kept, not on every request (the key is the body).
                        Cached(
                          cacheKey: ('article-body', article.body),
                          child: _ArticleBody(article.body),
                        ),
                        TagList(article.tagList, outline: true),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(color: hairline, height: 1),
                  ),
                  cls(
                    'article-actions',
                    Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 48),
                      child: Center(
                        child: ArticleMeta(article, actions: actions()),
                      ),
                    ),
                  ),
                  GridRow(
                    children: [
                      Col(
                        xs: 12,
                        md: 8,
                        offset: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (user != null) ...[
                              ErrorMessages(failure?.messages ?? const []),
                              _CommentForm(user),
                            ] else
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Sign in',
                                        href:
                                            '${loginRoute.link()}?redirectTo=${Uri.encodeQueryComponent(articleRoute.link({'slug': article.slug}))}',
                                        style: const TextStyle(color: brand),
                                      ),
                                      const TextSpan(text: ' or '),
                                      TextSpan(
                                        text: 'sign up',
                                        href: registerRoute.link(),
                                        style: const TextStyle(color: brand),
                                      ),
                                      const TextSpan(
                                        text:
                                            ' to add comments on this article.',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            for (final c in comments)
                              _CommentCard(
                                c,
                                mine: user?.username == c.author.username,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Back to the page the form was on (same site only), or [fallback].
Redirect _back(PageRequest request, RouteUrl fallback) {
  final referer = Uri.tryParse(request.headers['referer'] ?? '');
  final sameSite =
      referer != null && referer.authority == request.headers['host'];
  return Redirect(
    sameSite
        ? safeRedirect(
                referer.hasQuery
                    ? '${referer.path}?${referer.query}'
                    : referer.path,
              ) ??
              fallback
        : fallback,
  );
}

String _slug(PageRequest r) => r.pathParameters['slug']!;

const _card = BoxDecoration(
  color: white,
  borderRadius: BorderRadius.all(Radius.circular(12)),
  border: Border.fromBorderSide(BorderSide(color: hairline)),
  boxShadow: [
    BoxShadow(color: Color(0x0A000000), offset: Offset(0, 1), blurRadius: 2),
  ],
);

const _footer = BoxDecoration(
  color: Color(0xFFF5F5F5),
  border: Border(top: BorderSide(color: hairline)),
  borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
);

class _CommentForm extends StatelessWidget {
  const _CommentForm(this.user);

  final User user;

  @override
  Widget build(BuildContext context) => cls(
    'card comment-form',
    Form(
      onPost: const ArticlePage().createComment,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: _card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cls(
              'card-block',
              TextField(
                name: 'comment',
                maxLines: 3,
                inputAttributes: HtmlAttributes.custom({
                  'class': 'form-control',
                }),
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.25,
                  color: Color(0xFF55595C),
                ),
                decoration: const InputDecoration(
                  hintText: 'Write a comment...',
                  hintStyle: TextStyle(color: muted),
                  contentPadding: EdgeInsets.all(20),
                  border: InputBorder.none,
                ),
              ),
            ),
            cls(
              'card-footer',
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: _footer,
                child: Row(
                  children: [
                    Avatar(
                      user.image,
                      name: user.username,
                      size: 30,
                      classes: 'comment-author-img',
                    ),
                    const Spacer(),
                    submitButton(
                      'Post Comment',
                      ButtonKind.primary,
                      size: ButtonSize.small,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CommentCard extends StatelessWidget {
  const _CommentCard(this.comment, {required this.mine});

  final Comment comment;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final a = comment.author;
    final profile = '/profile/${Uri.encodeComponent(a.username)}';
    return cls(
      'card',
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: _card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cls(
              'card-block',
              Padding(
                padding: const EdgeInsets.all(20),
                child: cls(
                  'card-text',
                  Semantics(
                    role: SemanticsRole.paragraph,
                    child: Text(comment.body),
                  ),
                ),
              ),
            ),
            cls(
              'card-footer',
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: _footer,
                child: DefaultTextStyle(
                  style: const TextStyle(
                    fontSize: 12.8,
                    fontWeight: FontWeight.w300,
                  ),
                  child: Row(
                    spacing: 5,
                    children: [
                      cls(
                        'comment-author',
                        Link(
                          href: RouteUrl(profile),
                          child: Avatar(
                            a.image,
                            name: a.username,
                            size: 20,
                            classes: 'comment-author-img',
                          ),
                        ),
                      ),
                      cls(
                        'comment-author',
                        Link(
                          href: RouteUrl(profile),
                          child: Text(
                            a.username,
                            style: const TextStyle(color: brand),
                          ),
                        ),
                      ),
                      cls(
                        'date-posted',
                        Text(
                          dateString(comment.createdAt),
                          style: const TextStyle(color: light),
                        ),
                      ),
                      const Spacer(),
                      if (mine)
                        Form(
                          onPost: const ArticlePage().deleteComment,
                          child: Row(
                            children: [
                              HiddenField(name: 'id', value: '${comment.id}'),
                              cls(
                                'mod-options',
                                // The contract asks for `span.mod-options`: an
                                // exact HTML element is the web layer's job.
                                web.Span(
                                  children: [
                                    TextButton(
                                      buttonType: ButtonType.submit,
                                      onPressed: () {},
                                      style: const ButtonStyle(
                                        padding: WidgetStatePropertyAll(
                                          EdgeInsets.zero,
                                        ),
                                        minimumSize: WidgetStatePropertyAll(
                                          Size(0, 0),
                                        ),
                                        foregroundColor: WidgetStatePropertyAll(
                                          Color(0x99333333),
                                        ),
                                      ),
                                      child: ionIcon(
                                        'ion-trash-a',
                                        ConduitIcons.trash,
                                        size: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The body, rendered from markdown and sanitized (markdown.dart).
class _ArticleBody extends StatelessWidget {
  const _ArticleBody(this.markdown);

  final String markdown;

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'div',
    classes: 'article-body',
    children: [dom.RawText(renderMarkdown(markdown))],
  );
}
