// Renders every route of the app with the render caches on (cold), off
// (the reference) and on again (warm: memo hits and kept `Cached`
// fragments), for a guest and two signed-in users, and prints one line per
// page that differs. Run by test/render_caches_test.dart, in debug and in
// release (`-Dthor.release=true`), against test/e2e/mock_api.
import 'dart:convert';
import 'dart:io';

import 'package:realworld/api.dart';
import 'package:realworld/router.dart';
import 'package:realworld/session.dart';
import 'package:realworld/styles.dart';
import 'package:realworld/ui.dart' show conduitTheme;
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart' as testing;
import 'package:thor_ui/thor_ui.dart';

Future<void> main() async {
  const secret = 'render-caches-session-secret-of-32-bytes';
  configureSessions(secret);
  // The app's own renderer (bin/server.dart), every page rendered (no page
  // cache: a hit would compare nothing).
  final handler = RouteHandler(
    routes: router.routes,
    personalized: (_) => true,
    renderer: WidgetRenderer(
      app: (page) => ThorApp(
        theme: conduitTheme,
        engineSrc: '/engine.dart.js',
        child: page,
      ),
      styles: conduitStyles,
      head: const [html.link(rel: 'icon', href: '/favicon.ico')],
    ),
  );
  String cookie(User u) =>
      'session=${SignedCookies(secret, purpose: 'session').sign(jsonEncode(u.toJson()))}';
  final john = await api.login('johndoe@example.com', 'password123');
  final jane = await api.login('janedoe@example.com', 'password123');
  final articles = (await api.articles()).articles;
  final johns = (await api.articles(token: john.token)).articles;
  final janes = (await api.articles(token: jane.token)).articles;
  // The global feed shows each user's own `favorited`: some article must
  // differ between the two, or the cross-user check proves nothing.
  final personal = [
    for (var i = 0; i < johns.length && i < janes.length; i++)
      if (johns[i].slug == janes[i].slug &&
          johns[i].favorited != janes[i].favorited)
        i,
  ].isNotEmpty;
  final tag = (await api.tags()).first;
  final public = [
    '/',
    '/?page=2',
    '/tag/${Uri.encodeComponent(tag)}',
    '/article/${Uri.encodeComponent(articles.first.slug)}',
    '/profile/johndoe',
    '/profile/johndoe/favorites',
    '/profile/janedoe',
    '/login',
    '/register',
    '/no-such-page',
  ];
  // Signed in, /login and /register redirect home.
  final signedIn = [
    for (final p in public)
      if (p != '/login' && p != '/register') p,
  ];
  final visitors = <String, (String?, List<String>)>{
    'guest': (null, public),
    'johndoe': (
      cookie(john),
      [...signedIn, '/?feed=following', '/settings', '/editor'],
    ),
    'janedoe': (
      cookie(jane),
      [...signedIn, '/?feed=following', '/settings', '/editor'],
    ),
  };

  Future<String> render(String path, String? cookie) async {
    final r = await handler.handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://x$path'),
        headers: {HttpHeader.host: 'x', HttpHeader.cookie: ?cookie},
      ),
    );
    return '${r.status}\n${utf8.decode(r.body)}';
  }

  Future<Map<String, String>> pass(Iterable<String> order) async => {
    for (final who in order)
      for (final path in visitors[who]!.$2)
        '$who $path': await render(path, visitors[who]!.$1),
  };

  testing.renderCachesEnabled = true;
  final cold = await pass(visitors.keys);
  testing.renderCachesEnabled = false;
  final reference = await pass(visitors.keys);
  testing.renderCachesEnabled = true;
  // Reversed: a fragment kept for one visitor is replayed for another.
  final warm = await pass(visitors.keys.toList().reversed);

  var differ = 0;
  for (final MapEntry(:key, :value) in reference.entries) {
    for (final (name, pass) in [('cold', cold), ('warm', warm)]) {
      final other = pass[key]!;
      if (other == value) continue;
      differ++;
      var at = 0;
      while (at < value.length && at < other.length && value[at] == other[at]) {
        at++;
      }
      String around(String s) => s.substring(
        (at - 60).clamp(0, s.length),
        (at + 60).clamp(0, s.length),
      );
      stdout.writeln(
        'DIFF $name $key at $at\n  off: ${around(value)}\n  on:  ${around(other)}',
      );
    }
  }
  // What makes the comparison meaningful: the two users' feeds differ in
  // their own favorites, and a release build kept fragments.
  stdout
    ..writeln('pages ${reference.length}')
    ..writeln('ok ${reference.values.where((v) => v.startsWith('200')).length}')
    ..writeln('differ $differ')
    ..writeln('personal $personal')
    ..writeln('kept ${Cached.length}');
  exit(0);
}
