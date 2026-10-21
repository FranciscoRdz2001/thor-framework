// Constructor tear-offs (`Item.fromJson`, `Item.new`) in lite code, as the
// callback of `map`: they translate and print what dart2js prints.
@Timeout(Duration(minutes: 3))
library;

import 'package:test/test.dart';

import 'lite_oracle.dart';

const _types = r'''
class Item {
  const Item(this.name, [this.count = 1]);
  factory Item.fromJson(Map<String, Object?> j) =>
      Item(j['name']! as String, (j['count'] as int?) ?? 1);
  factory Item.named(String name) => Item(name, 9);
  final String name;
  final int count;
  String show() => '$name:$count';
}

List<T> decode<T>(List<Object?> raw, T Function(Map<String, Object?>) f) => [
  for (final r in raw) f(r! as Map<String, Object?>),
];
''';

void main() {
  test('named factory and unnamed constructor tear-offs', () async {
    await sameAsWeb('''
$_types
String t0() {
  final raw = <Map<String, Object?>>[
    {'name': 'a'},
    {'name': 'b', 'count': 3},
  ];
  return raw.map(Item.fromJson).map((i) => i.show()).join(' ');
}
String t1() => ['x', 'y'].map(Item.named).map((i) => i.show()).join(' ');
String t2() => ['p', 'q'].map(Item.new).map((i) => i.show()).join(' ');
String t3() {
  final f = Item.fromJson;
  return f({'name': 'z', 'count': 5}).show();
}
''', 4);
  });

  test('a tear-off passed to a function', () async {
    await sameAsWeb('''
$_types
String t0() => decode<Item>([{'name': 'k'}], Item.fromJson)
    .map((i) => i.show())
    .join();
''', 1);
  });

  test('a tear-off of a constructor outside the app keeps the error', () async {
    final errors = await liteErrors('''
$header
class PState extends ThorState {
  final a = state(0);
  List<String> f() => [1, 2].map(Duration.new).map((d) => '\$d').toList();
}
''');
    expect(errors.map((e) => e.message), contains(contains('lite subset')));
  });
}
