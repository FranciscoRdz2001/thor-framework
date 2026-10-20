/// One product in the signed-in user's cart.
class CartLine {
  const CartLine({
    required this.sku,
    required this.name,
    required this.qty,
    required this.price,
  });

  factory CartLine.fromJson(Map<String, Object?> json) => CartLine(
    sku: json['sku']! as String,
    name: json['name']! as String,
    qty: json['qty']! as int,
    price: json['price']! as int,
  );

  final String sku;
  final String name;
  final int qty;

  /// In pesos, per unit.
  final int price;

  Map<String, Object?> toJson() => {
    'sku': sku,
    'name': name,
    'qty': qty,
    'price': price,
  };
}
