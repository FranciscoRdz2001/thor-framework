/// In-memory data the recipes read: stands in for a database or an API.
library;

/// A product.
class Product {
  /// A product.
  const Product(
    this.id,
    this.name,
    this.category,
    this.price, {
    this.stock = 0,
  });

  /// Its id (the key in URLs and lists).
  final int id;

  /// Its name.
  final String name;

  /// Its category.
  final Category category;

  /// Price in cents (money is never a double).
  final int price;

  /// Units in stock.
  final int stock;
}

/// A product's category (a real enum, never strings).
enum Category {
  /// Coffee.
  coffee('Café'),

  /// Tea.
  tea('Té'),

  /// Accessories.
  accessories('Accesorios');

  const Category(this.label);

  /// What the page shows.
  final String label;
}

/// The catalog.
const products = [
  Product(1, 'Chiapas lavado', Category.coffee, 18900, stock: 12),
  Product(2, 'Veracruz natural', Category.coffee, 21500, stock: 3),
  Product(3, 'Oolong de montaña', Category.tea, 15900),
  Product(4, 'Matcha ceremonial', Category.tea, 34900, stock: 8),
  Product(5, 'Prensa francesa', Category.accessories, 59900, stock: 5),
  Product(6, 'Molino manual', Category.accessories, 89900, stock: 1),
];

/// `18900` → `$189.00`.
String money(int cents) =>
    '\$${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
