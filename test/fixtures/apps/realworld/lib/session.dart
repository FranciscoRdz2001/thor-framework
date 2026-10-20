/// The signed-in user: a signed, HTTP-only cookie read on every request.
library;

import 'dart:convert';
import 'dart:math';

import 'package:thor_server/thor_server.dart';

import 'api.dart';
import 'env.dart';
import 'router.dart';

const _cookie = 'session';

late SignedCookies _signer;

/// Sets the signing secret (once per isolate, before serving). Every
/// isolate must use the same one, or a cookie signed by one fails in
/// another.
///
/// A cookie older than [sessionLifetime] is refused by the server, not only
/// by the browser. To rotate the secret, pass the old one as
/// [previousSecret] for one [sessionLifetime].
void configureSessions(String secret, {String? previousSecret}) =>
    _signer = SignedCookies(
      secret,
      previousSecrets: [?previousSecret],
      purpose: 'session',
      maxAge: sessionLifetime,
    );

/// How long a session lasts.
const sessionLifetime = Duration(days: 30);

/// `SESSION_SECRET`, or a fresh random one (sessions then end on restart).
String sessionSecret() =>
    env.of(RealworldEnv.sessionSecret)?.reveal() ??
    base64Url.encode(List.generate(32, (_) => Random.secure().nextInt(256)));

/// The signed-in user in `request.context` (set by the root group's
/// middleware). Personal: a signed-in request skips the shared page
/// cache, a guest's uses it.
const currentUser = ContextKey<User>('currentUser');

/// The user of the session cookie, or `null` (no cookie, a bad signature
/// or a cookie from another version of the app: signed out).
User? readSession(PageRequest request) {
  final value = _signer.verify(request.cookies[_cookie]);
  if (value == null) return null;
  try {
    return User.fromJson(jsonDecode(value) as Map<String, Object?>);
  } on Object {
    return null;
  }
}

/// A redirect for a guard in a group's middleware: `303` after a form
/// post, `302` otherwise (like a page's `redirect`).
Redirect guardRedirect(PageRequest request, RouteUrl to) =>
    request.method == HttpMethod.post ? Redirect(to) : Redirect.found(to);

/// Signs [user] in (or refreshes the cookie after a profile change).
void startSession(PageRequest request, User user) {
  request.response.setCookie(
    _cookie,
    _signer.sign(jsonEncode(user.toJson())),
    maxAge: sessionLifetime,
  );
  request.context.set(currentUser, user);
}

/// Signs out.
void endSession(PageRequest request) {
  request.response.deleteCookie(_cookie);
}

/// The signed-in user, if any.
extension CurrentUser on PageRequest {
  /// The signed-in user or `null`.
  User? get user => context.maybeGet(currentUser);

  /// The signed-in user; a guest is sent to `/login`.
  User get signedIn => user ?? (throw Redirect.found(loginRoute.link()));
}

/// How long a public page is shared by every visitor without a session. A
/// form action clears it; otherwise a guest sees a change within this.
const publicPageCache = Duration(seconds: 5);
