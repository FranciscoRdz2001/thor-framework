/// One order of the lists and forms lab.
class Order {
  const Order(this.id, this.customer, this.status, this.total);

  final int id;
  final String customer;
  final String status;
  final int total;

  @override
  String toString() => '#$id $customer';
}

/// In-memory orders for the lists and forms lab (`/orders`,
/// `/edit`): 45 rows, no database.
class OrdersRepository {
  OrdersRepository();

  static const customers = ['Ana', 'Beto', 'Carla', 'Dani', 'Ñandú', '日本'];

  final all = [
    for (var i = 1; i <= 45; i++)
      Order(
        i,
        customers[i % customers.length],
        i.isEven ? 'open' : 'closed',
        i * 10,
      ),
  ];

  /// What `/orders` saw of each POST (`touch`), in order.
  final touched = <String>[];

  /// The rows of one page, filtered and sorted.
  ({List<Order> rows, int total}) page({
    String q = '',
    String? status,
    String? sort,
    bool descending = false,
    int offset = 0,
    int limit = 10,
  }) {
    var rows = [
      for (final o in all)
        if ((q.isEmpty || o.customer.toLowerCase().contains(q.toLowerCase())) &&
            (status == null || o.status == status))
          o,
    ];
    if (sort != null) {
      int by(Order a, Order b) => switch (sort) {
        'total' => a.total.compareTo(b.total),
        _ => a.customer.compareTo(b.customer),
      };
      rows.sort(by);
      if (descending) rows = rows.reversed.toList();
    }
    return (rows: rows.skip(offset).take(limit).toList(), total: rows.length);
  }

  /// The rows a class argument asks for, as text (what a query answers).
  Future<List<String>> search(OrdersFilter f) async => [
    for (final o in page(
      q: f.q,
      status: f.status,
      offset: (f.page - 1) * 5,
      limit: 5,
    ).rows)
      '${o.id}:${o.customer}',
  ];
}

/// The argument of the class-argument query: a search, a status and a page,
/// with a list inside to prove nested values travel.
class OrdersFilter {
  const OrdersFilter({
    this.q = '',
    this.page = 1,
    this.tags = const [],
    this.status,
  });

  factory OrdersFilter.fromJson(Map<String, Object?> json) => OrdersFilter(
    q: json['q']! as String,
    page: json['page']! as int,
    tags: [for (final t in json['tags']! as List<Object?>) t! as String],
    status: json['status'] as String?,
  );

  final String q;
  final int page;
  final List<String> tags;
  final String? status;

  OrdersFilter copyWith({String? q, int? page, List<String>? tags}) =>
      OrdersFilter(
        q: q ?? this.q,
        page: page ?? this.page,
        tags: tags ?? this.tags,
        status: status,
      );

  Map<String, Object?> toJson() => {
    'q': q,
    'page': page,
    'tags': tags,
    'status': status,
  };
}

/// The repository.
final ordersRepository = OrdersRepository();
