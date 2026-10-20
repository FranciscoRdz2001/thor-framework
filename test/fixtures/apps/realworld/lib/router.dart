// The app's routes: the table the server serves and every link uses.
// The pages keep their `routes/` folders (one per URL, `(guest)` and
// `(member)` for the groups) on purpose: this fixture checks that a router
// written by code serves an app laid out by path as well as one laid out by
// feature (`server_query`, `lazy_pieces`).
import 'package:thor_ui/router.dart';

import 'routes/(guest)/login/page.dart' show LoginPage;
import 'routes/(guest)/middleware.dart' as guest_only;
import 'routes/(guest)/register/page.dart' show RegisterPage;
import 'routes/(member)/editor/[slug]/page.dart' show EditorBySlugPage;
import 'routes/(member)/editor/page.dart' show EditorPage;
import 'routes/(member)/middleware.dart' as member_only;
import 'routes/(member)/settings/page.dart' show SettingsPage;
import 'routes/article/[slug]/page.dart' show ArticlePage;
import 'routes/article/styles.dart' as styles;
import 'routes/error.dart' show AppErrorPage;
import 'routes/layout.dart' show RootLayout;
import 'routes/middleware.dart' as root_middleware;
import 'routes/page.dart' show HomePage;
import 'routes/profile/[user]/favorites/page.dart' show ProfileFavoritesPage;
import 'routes/profile/[user]/layout.dart' show ProfileLayout;
import 'routes/profile/[user]/page.dart' show ProfilePage;
import 'routes/robots.dart' as robots;
import 'routes/sitemap.dart' as sitemap;
import 'routes/tag/[tag]/page.dart' show TagPage;

/// A route of the table below.
final homeRoute = ThorRoute('/', const HomePage());

/// A route of the table below.
final loginRoute = ThorRoute('/login', const LoginPage());

/// A route of the table below.
final registerRoute = ThorRoute('/register', const RegisterPage());

/// A route of the table below.
final editorRoute = ThorRoute('/editor', const EditorPage());

/// A route of the table below.
final editorBySlugRoute = ThorRoute('/editor/:slug', const EditorBySlugPage());

/// A route of the table below.
final settingsRoute = ThorRoute('/settings', const SettingsPage());

/// A route of the table below.
final articleRoute = ThorRoute('/article/:slug', const ArticlePage());

/// A route of the table below.
final profileRoute = ThorRoute('/profile/:user', const ProfilePage());

/// A route of the table below.
final profileFavoritesRoute = ThorRoute(
  '/profile/:user/favorites',
  const ProfileFavoritesPage(),
);

/// A route of the table below.
final tagRoute = ThorRoute('/tag/:tag', const TagPage());

/// Every route of the app.
final ThorRouter router = ThorRouter([
  Group(
    layout: const RootLayout(),
    middleware: [root_middleware.handle],
    error: const AppErrorPage(),
    children: [
      homeRoute,
      Group(
        middleware: [guest_only.handle],
        children: [loginRoute, registerRoute],
      ),
      Group(
        middleware: [member_only.handle],
        children: [editorRoute, editorBySlugRoute, settingsRoute],
      ),
      Group(
        prefix: '/article',
        styles: styles.styles,
        children: [articleRoute],
      ),
      Group(
        layout: const ProfileLayout(),
        children: [profileRoute, profileFavoritesRoute],
      ),
      tagRoute,
    ],
  ),
  const RobotsRoute(robots.robots),
  const SitemapRoute(sitemap.sitemap),
]);
