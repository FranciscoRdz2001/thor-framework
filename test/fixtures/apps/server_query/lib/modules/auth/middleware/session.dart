import 'package:thor_ui/router.dart';

import '../../../core/db/database.dart';

/// The signed-in user's login, for the pages (and queries) below.
const currentUser = ContextKey<String>('user');

/// The session cookie (a demo: an unsigned login; use `SignedCookies` in a
/// real app).
const sessionCookie = 'sq-session';

/// Pages behind it need a session: without one, to `/login`. A query of
/// those pages goes through here too (the browser gets a 401 with the
/// redirect).
Future<ThorResponse> requireSession(PageRequest request, Next next) async {
  final login = request.cookies[sessionCookie];
  final known =
      login != null &&
      database.select('SELECT 1 FROM users WHERE login = ?', [
        login,
      ]).isNotEmpty;
  if (!known) throw const Redirect.found(RouteUrl('/login'));
  request.context.set(currentUser, login);
  return next();
}
