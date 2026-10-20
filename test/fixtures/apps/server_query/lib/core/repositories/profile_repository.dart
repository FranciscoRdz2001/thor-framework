import 'package:thor_ui/router.dart';

import '../../modules/auth/middleware/session.dart';
import '../db/database.dart';
import '../models/order.dart';
import '../models/profile.dart';

/// The signed-in user's data, read with sqlite3. Its methods are what the
/// profile state passes to `query(...)`: they run on the server only and
/// read the session the route's middleware put in the request.
class ProfileRepository {
  const ProfileRepository();

  /// Orders per page.
  static const pageSize = 3;

  /// The profile, one more visit each time.
  Future<Profile> info() async {
    final login = PageRequest.current.context.get(currentUser);
    // A slow backend: long enough to see `loading` in the page.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    database.execute('UPDATE users SET visits = visits + 1 WHERE login = ?', [
      login,
    ]);
    final row = database.select(
      'SELECT name, email, visits FROM users WHERE login = ?',
      [login],
    ).single;
    return Profile(
      name: row['name'] as String,
      email: row['email'] as String,
      visits: row['visits'] as int,
    );
  }

  /// Page [page] (from 0) of the user's orders.
  Future<List<Order>> orders(int page) async {
    if (page < 0) {
      throw const HttpError(StatusCode.badRequest, 'Esa página no existe.');
    }
    final login = PageRequest.current.context.get(currentUser);
    return [
      for (final row in database.select(
        'SELECT id, item, total FROM orders WHERE login = ? '
        'ORDER BY id LIMIT ? OFFSET ?',
        [login, pageSize, page * pageSize],
      ))
        Order(
          id: row['id'] as int,
          item: row['item'] as String,
          total: row['total'] as int,
        ),
    ];
  }

  /// A backend that fails: the visitor sees a generic message, never this.
  Future<int> ledger() async =>
      throw StateError('ledger table is locked (internal detail)');
}

/// The repository the states use.
const profileRepository = ProfileRepository();
