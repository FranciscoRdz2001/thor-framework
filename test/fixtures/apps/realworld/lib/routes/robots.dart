import 'package:thor_ui/router.dart';

import '../router.dart';

/// `/robots.txt`: a member's pages are not for crawlers.
Robots robots(PageRequest request) => Robots([
  RobotsRule(disallow: [editorRoute.link(), settingsRoute.link()]),
]);
