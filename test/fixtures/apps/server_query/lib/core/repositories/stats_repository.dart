import '../db/database.dart';

/// Public numbers of the site (no session needed).
class StatsRepository {
  const StatsRepository();

  /// How many orders exist.
  Future<int> orderCount() async =>
      database.select('SELECT count(*) AS n FROM orders').single['n'] as int;
}

/// The repository the states use.
const statsRepository = StatsRepository();
