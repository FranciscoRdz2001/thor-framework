import 'package:thor_ui/router.dart';

import 'pages/acts_page.dart';
import 'pages/lab_page.dart';
import 'pages/lazy_page.dart';
import 'pages/qb_page.dart';
import 'pages/scroll_page.dart';

/// `/lab`.
final labRoute = ThorRoute('/lab', const LabPage());

/// `/acts`.
final actsRoute = ThorRoute('/acts', const ActsPage());

/// `/acts/other`.
final actsOtherRoute = ThorRoute('/acts/other', const ActsOtherPage());

/// `/acts/next`.
final actsNextRoute = ThorRoute('/acts/next', const ActsNextPage());

/// `/scroll`.
final scrollRoute = ThorRoute('/scroll', const ScrollPage());

/// `/scroll/:slug`: the same page under a path of any shape.
final scrollSlugRoute = ThorRoute('/scroll/:slug', const ScrollPage());

/// `/qb`.
final qbRoute = ThorRoute('/qb', const QbPage());

/// `/lazy`.
final lazyRoute = ThorRoute('/lazy', const LazyPage());

/// The lab module: public.
final labModule = Group(
  children: [
    labRoute,
    qbRoute,
    lazyRoute,
    actsRoute,
    actsNextRoute,
    actsOtherRoute,
    scrollRoute,
    scrollSlugRoute,
  ],
);
