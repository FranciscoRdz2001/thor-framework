// Dot shorthands (Dart 3.10) in a ThorState: `.loading`, `.make(1)`,
// `.named()` translate as the explicit `Type.member`, and run as lite JS in
// node printing what the same Dart prints on the web (dart2js).
@Timeout(Duration(minutes: 3))
library;

import 'package:test/test.dart';

import 'lite_oracle.dart';

const _types = r'''
enum Status { idle, loading, done }

class Point {
  const Point(this.x, this.y);
  factory Point.origin() => const Point(0, 0);
  factory Point.diag(int n) => Point(n, n);
  static const Point unit = Point(1, 1);
  static Point make(int n) => Point(n, 0);
  final int x;
  final int y;
  String show() => '$x,$y';
}

String label(Status s) => s.name;
''';

void main() {
  test('assignment, argument and comparison of an enum value', () async {
    await sameAsWeb('''
$_types
String t0() {
  Status s = .idle;
  s = .loading;
  return '\${label(.done)} \${s == .loading} \${s != .done} \$s';
}
''', 1);
  });

  test('switch statement and expression with enum shorthands', () async {
    await sameAsWeb('''
$_types
String t0() {
  final out = <String>[];
  for (final s in Status.values) {
    switch (s) {
      case .idle:
        out.add('i');
      case .loading || .done:
        out.add('x');
    }
    out.add(switch (s) { .idle => 'a', .loading => 'b', .done => 'c' });
  }
  return out.join();
}
''', 1);
  });

  test('static const, static method and named constructors', () async {
    await sameAsWeb('''
$_types
String t0() {
  Point a = .unit;
  Point b = .make(4);
  Point c = .origin();
  Point d = .diag(3);
  Point e = .new(7, 8);
  return [a, b, c, d, e].map((p) => p.show()).join(' ');
}
String t1() {
  final list = <Point>[.unit, .make(2), .origin()];
  return list.map((p) => p.show()).join(' ');
}
''', 2);
  });

  test('a shorthand that cannot be resolved keeps the error', () async {
    final errors = await liteErrors('''
$header
class PState extends ThorState {
  void f() {
    final x = .nothing;
  }
}
''');
    expect(errors, isNotEmpty);
  });
}
