import 'package:thor_ui/router.dart';

import 'pages/home_page.dart';

/// `/`.
final homeRoute = ThorRoute('/', const HomePage());

/// The public module.
final homeModule = Group(children: [homeRoute]);
