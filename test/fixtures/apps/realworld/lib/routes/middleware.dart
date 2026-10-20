import 'package:thor_ui/router.dart';

import '../session.dart';

/// Every request: the session cookie's user, if any, into the context.
Future<ThorResponse> handle(PageRequest request, Next next) {
  if (readSession(request) case final user?) {
    request.context.set(currentUser, user);
  }
  return next();
}
