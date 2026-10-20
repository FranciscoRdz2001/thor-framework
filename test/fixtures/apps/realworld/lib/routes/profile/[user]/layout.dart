import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../api.dart';
import '../../../router.dart';
import '../../../session.dart';
import '../../../ui.dart';
import '../../../widgets/articles.dart';
import 'page.dart' show ProfilePage;

/// The layout of `/profile/:user` and the pages below it.
class ProfileLayout extends ThorLayout<Profile> {
  /// The one instance the build shares between requests.
  const ProfileLayout();

  /// The profile (404 when there is no such user).
  @override
  Future<Profile> load(PageRequest request) =>
      api.profile(request.pathParameters['user']!, token: request.user?.token);

  /// `username • Conduit`.
  @override
  PageMeta meta(PageState<Profile> state) =>
      PageMeta(title: '${state.data.username} • Conduit');

  /// User info, then the "My Articles" / "Favorited Articles" tabs above the
  /// page (the list).
  @override
  Widget build(BuildContext context, PageState<Profile> state, Widget child) {
    final p = state.data;
    final user = state.request.user;
    final base = '/profile/${Uri.encodeComponent(p.username)}';
    final favorites = state.uri.path.endsWith('/favorites');
    Widget tab(String href, String label, bool active) => cls(
      'nav-item',
      Semantics(
        role: SemanticsRole.listItem,
        child: Container(
          child: cls(
            active ? 'nav-link active' : 'nav-link',
            Link(
              href: RouteUrl(href),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? brand : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  style: active
                      ? const TextStyle(color: brand)
                      : _tab.copyWith(
                          color: lighter.when(hover: const Color(0xFF555555)),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return cls(
      'profile-page',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cls(
            'user-info',
            Container(
              padding: const EdgeInsets.only(top: 32, bottom: 16),
              decoration: const BoxDecoration(
                color: white,
                border: Border(
                  top: BorderSide(color: hairline),
                  bottom: BorderSide(color: hairline),
                ),
              ),
              child: PageContainer(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Avatar(
                        p.image,
                        name: p.username,
                        size: 100,
                        classes: 'user-img',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Semantics(
                        headingLevel: 4,
                        child: Text(
                          p.username,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Semantics(
                          role: SemanticsRole.paragraph,
                          child: Text(
                            p.bio ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: lighter,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: user?.username == p.username
                          ? cls(
                              'btn btn-sm btn-outline-secondary action-btn',
                              Link(
                                href: settingsRoute.link(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: muted),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Edit Profile Settings',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: muted,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : user != null
                          ? FollowButton(
                              username: p.username,
                              following: p.following,
                              // The profile page's action, from its
                              // favorites tab too.
                              action: base,
                              onPost: const ProfilePage().toggleFollow,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cls(
                  'articles-toggle',
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: cls(
                      'nav nav-pills outline-active',
                      Semantics(
                        role: SemanticsRole.list,
                        child: Row(
                          children: [
                            tab(base, 'My Articles', !favorites),
                            tab(
                              '$base/favorites',
                              'Favorited Articles',
                              favorites,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _tab = TextStyle(color: lighter);
