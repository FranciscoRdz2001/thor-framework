// The app's routes: the table the server serves and every link uses.
import 'package:thor_ui/router.dart';

import 'routes/error.dart' show AppErrorPage;
import 'routes/layout.dart' show RootLayout;
import 'routes/page.dart' show HomePage;
import 'routes/product/[id]/page.dart' show ProductPage;

/// A route of the table below.
final homeRoute = ThorRoute('/', const HomePage());

/// A route of the table below.
final productRoute = ThorRoute('/product/:id', const ProductPage());

/// Every route of the app.
final ThorRouter router = ThorRouter([
  Group(
    layout: const RootLayout(),
    error: const AppErrorPage(),
    children: [homeRoute, productRoute],
  ),
]);
