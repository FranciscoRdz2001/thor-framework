// The app's routes: the table the server serves and every link uses.
import 'package:thor_ui/router.dart';

import 'routes/(private)/account/page.dart' show AccountPage;
import 'routes/(private)/middleware.dart' as middleware;
import 'routes/card/page.dart' show CardPage;
import 'routes/counter/page.dart' show CounterPage;
import 'routes/dialog/page.dart' show DialogPage;
import 'routes/error.dart' show AppErrorPage;
import 'routes/form/page.dart' show FormPage;
import 'routes/layout.dart' show RootLayout;
import 'routes/list/page.dart' show ListPage;
import 'routes/login/page.dart' show LoginPage;
import 'routes/page.dart' show HomePage;
import 'routes/panel/page.dart' show PanelPage;
import 'routes/table/page.dart' show TablePage;
import 'routes/web/card/page.dart' show WebCardPage;
import 'routes/web/card/style/page.dart' show WebCardStylePage;
import 'routes/web/panel/page.dart' show WebPanelPage;
import 'routes/web/panel/style/page.dart' show WebPanelStylePage;
import 'routes/web/table/page.dart' show WebTablePage;

/// A route of the table below.
final homeRoute = ThorRoute('/', const HomePage());

/// A route of the table below.
final accountRoute = ThorRoute('/account', const AccountPage());

/// A route of the table below.
final counterRoute = ThorRoute('/counter', const CounterPage());

/// A route of the table below.
final dialogRoute = ThorRoute('/dialog', const DialogPage());

/// A route of the table below.
final formRoute = ThorRoute('/form', const FormPage());

/// A route of the table below.
final listRoute = ThorRoute('/list', const ListPage());

/// A route of the table below.
final loginRoute = ThorRoute('/login', const LoginPage());

/// A route of the table below.
final panelRoute = ThorRoute('/panel', const PanelPage());

/// A route of the table below.
final tableRoute = ThorRoute('/table', const TablePage());

/// A route of the table below.
final cardRoute = ThorRoute('/card', const CardPage());

/// A route of the table below.
final webPanelRoute = ThorRoute('/web/panel', const WebPanelPage());

/// A route of the table below.
final webPanelStyleRoute = ThorRoute(
  '/web/panel/style',
  const WebPanelStylePage(),
);

/// A route of the table below.
final webTableRoute = ThorRoute('/web/table', const WebTablePage());

/// A route of the table below.
final webCardRoute = ThorRoute('/web/card', const WebCardPage());

/// A route of the table below.
final webCardStyleRoute = ThorRoute(
  '/web/card/style',
  const WebCardStylePage(),
);

/// Every route of the app.
final ThorRouter router = ThorRouter([
  Group(
    layout: const RootLayout(),
    error: const AppErrorPage(),
    children: [
      homeRoute,
      Group(middleware: [middleware.handle], children: [accountRoute]),
      counterRoute,
      dialogRoute,
      formRoute,
      listRoute,
      loginRoute,
      panelRoute,
      tableRoute,
      cardRoute,
      webPanelRoute,
      webPanelStyleRoute,
      webTableRoute,
      webCardRoute,
      webCardStyleRoute,
    ],
  ),
]);
