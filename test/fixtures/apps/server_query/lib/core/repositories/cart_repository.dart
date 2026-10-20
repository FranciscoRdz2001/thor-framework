import 'package:thor_ui/router.dart';

import '../../modules/auth/middleware/session.dart';
import '../db/database.dart';
import '../models/cart_line.dart';

/// The signed-in user's cart, in sqlite3. Its reads are what the cart state
/// passes to `query(...)` and its writes what it passes to `command(...)`:
/// they run on the server only and read the session the route's middleware
/// put in the request.
class CartRepository {
  const CartRepository();

  /// The first [limit] lines of the cart, by product name.
  Future<List<CartLine>> lines(int limit) async => [
    for (final row in database.select(
      'SELECT c.sku, p.name, c.qty, p.price FROM cart c '
      'JOIN products p ON p.sku = c.sku WHERE c.login = ? '
      'ORDER BY p.name LIMIT ?',
      [_login, limit],
    ))
      CartLine(
        sku: row['sku'] as String,
        name: row['name'] as String,
        qty: row['qty'] as int,
        price: row['price'] as int,
      ),
  ];

  /// The cart's total, in pesos.
  Future<int> total() async =>
      database.select(
            'SELECT SUM(c.qty * p.price) AS t FROM cart c '
            'JOIN products p ON p.sku = c.sku WHERE c.login = ?',
            [_login],
          ).single['t']
          as int? ??
      0;

  /// Adds one [sku] to the cart; the units of it now in the cart. A
  /// product without stock is a 409 the visitor reads; an unknown one a
  /// 404.
  Future<int> add(String sku) async {
    // A slow backend: long enough to see `pending` in the page.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final product = database.select(
      'SELECT stock FROM products WHERE sku = ?',
      [sku],
    );
    if (product.isEmpty) {
      throw const HttpError(StatusCode.notFound, 'Ese producto no existe.');
    }
    if (product.single['stock'] as int <= 0) {
      throw const HttpError(StatusCode.conflict, 'Ya no hay existencias.');
    }
    database.execute(
      'INSERT INTO cart (login, sku, qty) VALUES (?, ?, 1) '
      'ON CONFLICT (login, sku) DO UPDATE SET qty = qty + 1',
      [_login, sku],
    );
    return database.select('SELECT qty FROM cart WHERE login = ? AND sku = ?', [
          _login,
          sku,
        ]).single['qty']
        as int;
  }

  /// Empties the cart.
  Future<void> clear() async {
    database.execute('DELETE FROM cart WHERE login = ?', [_login]);
  }

  /// A backend that fails: the visitor sees a generic message, never this.
  Future<void> checkout() async =>
      throw StateError('payments gateway down (internal detail)');

  static String get _login => PageRequest.current.context.get(currentUser)!;
}

/// The repository the states use.
const cartRepository = CartRepository();
