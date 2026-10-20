import 'package:thor_ui/router.dart';

import '../../session.dart';

/// The editor and the settings: guests go to sign in.
Future<ThorResponse> handle(PageRequest request, Next next) {
  if (request.user == null) {
    throw guardRedirect(request, const RouteUrl('/login'));
  }
  return next();
}
