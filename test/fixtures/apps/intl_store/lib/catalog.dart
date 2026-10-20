/// The shop's products: data, not UI text, so their names travel with
/// them in every language (UI strings live in `lib/l10n/`).
library;

class Product {
  const Product(this.id, this.names, this.price, this.stock, this.since);

  final String id;

  /// Language code → name.
  final Map<String, String> names;
  final double price;
  final int stock;
  final DateTime since;

  String nameIn(String languageCode) => names[languageCode] ?? names['en']!;
}

final catalog = [
  Product(
    'mug',
    const {'en': 'Enamel mug', 'es': 'Taza de peltre'},
    12.5,
    7,
    DateTime(2024, 3, 14),
  ),
  Product(
    'notebook',
    const {'en': 'Dotted notebook', 'es': 'Libreta punteada'},
    1234.5,
    1,
    DateTime(2025, 11, 2),
  ),
  Product(
    'pencil',
    const {'en': 'Cedar pencil', 'es': 'Lápiz de cedro'},
    0.9,
    0,
    DateTime(2026, 1, 20),
  ),
];

Product? productById(String id) => catalog.where((p) => p.id == id).firstOrNull;
