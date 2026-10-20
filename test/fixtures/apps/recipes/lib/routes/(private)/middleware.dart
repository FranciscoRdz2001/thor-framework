// Recipe: a protected module. Every page under `(private)/` runs this
// first (and before the page cache): no valid session → /login, with the
// way back. The user goes into the request's typed context.
import 'package:thor_ui/router.dart';

import '../../router.dart';
import '../../session.dart';

/// Checks the session cookie and publishes the user to the pages below.
Future<ThorResponse> handle(PageRequest request, Next next) async {
  final user = cookies.verify(request.cookies[sessionCookie]);
  if (user == null) {
    throw Redirect(loginRoute.link().withQuery({'back': request.uri.path}));
  }
  request.context.set(currentUser, user);
  return next();
}
