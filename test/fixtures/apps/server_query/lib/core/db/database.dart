import 'package:sqlite3/sqlite3.dart';

/// The app's database: sqlite3 in memory (one per server isolate), seeded
/// on first use. Native code: it only ever runs on the server.
final Database database = _open();

Database _open() {
  final db = sqlite3.openInMemory()
    ..execute('''
      CREATE TABLE users (
        login TEXT PRIMARY KEY, name TEXT NOT NULL, email TEXT NOT NULL,
        visits INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY, login TEXT NOT NULL, item TEXT NOT NULL,
        total INTEGER NOT NULL
      );
      CREATE TABLE products (
        sku TEXT PRIMARY KEY, name TEXT NOT NULL, price INTEGER NOT NULL,
        stock INTEGER NOT NULL
      );
      CREATE TABLE cart (
        login TEXT NOT NULL, sku TEXT NOT NULL, qty INTEGER NOT NULL,
        PRIMARY KEY (login, sku)
      );
    ''')
    ..execute(
      'INSERT INTO products (sku, name, price, stock) VALUES '
      "('taza', 'Taza', 120, 99), ('libreta', 'Libreta', 85, 99), "
      "('pluma', 'Pluma', 30, 99), ('termo', 'Termo', 260, 0)",
    )
    ..execute(
      'INSERT INTO users (login, name, email) VALUES '
      "('ana', 'Ana López', 'ana@example.com'), "
      "('beto', 'Beto Ruiz', 'beto@example.com')",
    );
  final items = [
    'Taza',
    'Libreta',
    'Pluma',
    'Mochila',
    'Lámpara',
    'Termo',
    'Agenda',
  ];
  final insert = db.prepare(
    'INSERT INTO orders (login, item, total) VALUES (?, ?, ?)',
  );
  for (var i = 0; i < items.length; i++) {
    insert.execute(['ana', items[i], 120 + i * 35]);
  }
  insert.close();
  return db;
}
