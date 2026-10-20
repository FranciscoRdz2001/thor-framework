/// One order of the signed-in user.
class Order {
  const Order({required this.id, required this.item, required this.total});

  factory Order.fromJson(Map<String, Object?> json) => Order(
    id: json['id']! as int,
    item: json['item']! as String,
    total: json['total']! as int,
  );

  final int id;
  final String item;

  /// In pesos.
  final int total;

  Map<String, Object?> toJson() => {'id': id, 'item': item, 'total': total};
}
