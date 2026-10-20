// The app's routes. Each module brings its group; the profile and cart
// modules' middleware guards their pages and the queries and commands
// they use.
import 'package:thor_ui/router.dart';

import 'modules/auth/auth_routes.dart';
import 'modules/cart/cart_routes.dart';
import 'modules/defer/defer_routes.dart';
import 'modules/home/home_routes.dart';
import 'modules/lab/lab_routes.dart';
import 'modules/orders/orders_routes.dart';
import 'modules/piece/piece_routes.dart';
import 'modules/profile/profile_routes.dart';

/// Every route of the app.
final ThorRouter router = ThorRouter([
  Group(
    children: [
      homeModule,
      authModule,
      profileModule,
      cartModule,
      labModule,
      ordersModule,
      deferModule,
      pieceModule,
    ],
  ),
]);
