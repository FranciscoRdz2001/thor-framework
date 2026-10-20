/// The search module: the page `/buscar`, where the top bar's search field
/// lands.
library;

import 'package:thor_ui/router.dart';

import 'pages/search_page.dart';

/// The search page, `/buscar` (`?q=` is the query).
final searchRoute = ThorRoute('/buscar', const SearchPage());

/// Every route of the search.
final searchModule = Group(children: [searchRoute]);
