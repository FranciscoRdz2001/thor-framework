import 'package:thor_ui/router.dart';

import '../auth/middleware/session.dart';
import 'pages/cart_page.dart';

/// `/cart`.
final cartRoute = ThorRoute('/cart', const CartPage());

/// The cart module: its page, its queries and its commands go through the
/// session middleware.
final cartModule = Group(middleware: [requireSession], children: [cartRoute]);
