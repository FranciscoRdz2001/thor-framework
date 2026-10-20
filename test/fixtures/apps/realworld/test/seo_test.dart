@TestOn('vm')
library;

import 'package:realworld/router.dart';
import 'package:realworld/session.dart';
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

/// `robots.dart` answers `/robots.txt` from the routes (no API call); the
/// member pages it names are the typed routes, so a renamed folder can't
/// leave a stale rule behind.
void main() {
  configureSessions('seo-test-session-secret-at-least-32-bytes');
  final handler = RouteHandler(
    routes: router.routes,
    renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
  );

  test('robots.txt keeps crawlers out of member pages', () async {
    final r = await handler
        .client(origin: 'https://conduit.test')
        .get('/robots.txt');
    expect(r, hasStatus(200));
    expect(
      r.text,
      'User-agent: *\nDisallow: /editor\nDisallow: /settings\n\n'
      'Sitemap: https://conduit.test/sitemap.xml\n',
    );
  });

  test('the static paths the sitemap starts from', () {
    expect(router.staticPaths, [
      '/',
      '/login',
      '/register',
      '/editor',
      '/settings',
    ]);
  });
}
