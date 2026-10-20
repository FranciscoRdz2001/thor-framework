import 'package:thor_ui/router.dart';

import '../../session.dart';

/// Sign in and sign up: a signed-in user goes home.
Future<ThorResponse> handle(PageRequest request, Next next) {
  if (request.user != null) throw guardRedirect(request, const RouteUrl('/'));
  return next();
}
