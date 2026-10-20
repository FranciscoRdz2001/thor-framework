/// The orders of the `/acts` lab page: a list in memory, per isolate (the
/// server runs one). What a page action changes (`delete`, `assign`).
class ActsOrder {
  ActsOrder(this.id, this.customer, {this.owner = 'nobody'});

  final int id;
  final String customer;
  String owner;
}

/// Who an order is assigned to (an enum argument of a page action).
enum Owner { ana, luis }

/// The lab's orders.
class ActsRepository {
  List<ActsOrder> orders = _seed();

  static List<ActsOrder> _seed() => [
    ActsOrder(3, 'Ana'),
    ActsOrder(4, 'Luis'),
    ActsOrder(5, 'Marta ~ "50%" <b>'),
  ];

  /// Puts the seed back.
  void reset() => orders = _seed();

  /// Removes order [id]; false when there is none.
  bool remove(int id) {
    final before = orders.length;
    orders = [
      for (final o in orders)
        if (o.id != id) o,
    ];
    return orders.length != before;
  }

  /// Assigns order [id] to [owner]; false when there is none.
  bool assign(int id, Owner owner) {
    for (final o in orders) {
      if (o.id == id) {
        o.owner = owner.name;
        return true;
      }
    }
    return false;
  }
}

/// The lab's orders.
final actsRepository = ActsRepository();
