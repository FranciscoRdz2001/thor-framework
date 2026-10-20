import 'package:thor_ui/router.dart';

import 'pages/edit_page.dart';
import 'pages/orders_page.dart';

/// `/orders`.
final ordersListRoute = ThorRoute('/orders', const OrdersListPage());

/// `/edit`.
final recordEditRoute = ThorRoute('/edit', const RecordEditPage());

/// The lists and forms lab: lists in the URL, forms that refill, a class argument.
final ordersModule = Group(children: [ordersListRoute, recordEditRoute]);
