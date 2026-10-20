import 'package:thor_ui/router.dart';

import 'pages/defer_page.dart';

/// `/defer`.
final deferRoute = ThorRoute('/defer', const DeferPage());

/// The streaming lab: a page whose data arrives after it.
final deferModule = Group(children: [deferRoute]);
