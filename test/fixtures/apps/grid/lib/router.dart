// The app's routes: the table the server serves and every link uses.
import 'package:thor_ui/router.dart';

import 'routes/error.dart' show AppErrorPage;
import 'routes/layout.dart' show RootLayout;
import 'routes/page.dart' show HomePage;

/// A route of the table below.
final homeRoute = ThorRoute('/', const HomePage());

/// Every route of the app.
final ThorRouter router = ThorRouter([
  Group(
    layout: const RootLayout(),
    error: const AppErrorPage(),
    children: [homeRoute],
  ),
]);
