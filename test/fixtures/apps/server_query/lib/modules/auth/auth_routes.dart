import 'package:thor_ui/router.dart';

import 'pages/login_page.dart';

/// `/login`.
final loginRoute = ThorRoute('/login', const LoginPage());

/// The public auth pages.
final authModule = Group(children: [loginRoute]);
