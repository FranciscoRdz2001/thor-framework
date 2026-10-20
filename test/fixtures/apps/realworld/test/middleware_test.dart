@TestOn('vm')
library;

import 'dart:convert';

import 'package:realworld/api.dart';
import 'package:realworld/router.dart';
import 'package:realworld/session.dart';
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

/// The session and the guards are the groups' middleware: the root
/// group's reads the cookie, `(member)` sends guests to sign in, `(guest)`
/// sends a signed-in user home. None of these requests reaches the API.
void main() {
  const secret = 'middleware-test-session-secret-32-bytes!';
  configureSessions(secret);
  final handler = RouteHandler(
    routes: router.routes,
    renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
  );
  final signedIn = SignedCookies(secret, purpose: 'session').sign(
    jsonEncode(
      const User(
        username: 'ana',
        email: 'ana@example.com',
        token: 't',
      ).toJson(),
    ),
  );

  /// A visitor of the site; [session] is the cookie it arrives with.
  ThorTestClient visitor([String? session]) {
    final client = handler.client(origin: 'http://site.test');
    if (session != null) client.setCookie('session', session);
    return client;
  }

  for (final path in ['/editor', '/editor/some-slug', '/settings']) {
    test('a guest asking for $path goes to sign in', () async {
      final r = await visitor().get(path);
      expect(r, hasStatus(302));
      expect(r, redirectsTo('/login'));
    });
  }

  test('a guest posting a member form gets a 303 to sign in', () async {
    final r = await visitor().post('/settings?/save');
    expect(r, hasStatus(303));
    expect(r, redirectsTo('/login'));
  });

  test('a forged session cookie is a guest', () async {
    final r = await visitor('forged.value').get('/settings');
    expect(r, redirectsTo('/login'));
  });

  for (final path in ['/login', '/register']) {
    test('a signed-in user asking for $path goes home', () async {
      final r = await visitor(signedIn).get(path);
      expect(r, hasStatus(302));
      expect(r, redirectsTo('/'));
    });

    test('a guest sees $path, shared by every guest', () async {
      final r = await visitor().get(path);
      expect(r, hasStatus(200));
      expect(handler.cachedPaths, contains(endsWith(path)));
    });
  }

  test("a signed-in user's page is private and never shared", () async {
    final r = await visitor(signedIn).get('/editor');
    expect(r, hasStatus(200));
    expect(r.headers['cache-control'], 'private, no-cache');
    expect(handler.cachedPaths, isNot(contains(endsWith('/editor'))));
  });
}
