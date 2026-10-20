/// The home module: the page `/`.
library;

import 'package:thor_ui/router.dart';

import 'home_page.dart';

/// The home page, `/`.
final homeRoute = ThorRoute('/', const HomePage());
