import 'package:thor_ui/router.dart';

import '../auth/middleware/session.dart';
import 'pages/profile_page.dart';

/// `/profile`.
final profileRoute = ThorRoute('/profile', const ProfilePage());

/// The signed-in module: every page, and every query those pages use,
/// goes through the session middleware.
final profileModule = Group(
  middleware: [requireSession],
  children: [profileRoute],
);
