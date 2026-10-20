@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/src/js_rename.dart';

/// What node prints running [js].
String _run(String js) {
  final r = Process.runSync('node', ['-e', js]);
  if (r.exitCode != 0) fail('node failed:\n${r.stderr}\n$js');
  return (r.stdout as String).trim();
}

final _hasNode = () {
  try {
    return Process.runSync('node', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();

/// [js] renamed prints the same as [js] (and something did change).
void _same(String js, {bool changes = true}) {
  final renamed = renameLocals(js);
  if (changes) expect(renamed, isNot(js));
  if (!_hasNode) return markTestSkipped('node is not installed');
  expect(_run(renamed), _run(js), reason: renamed);
}

void main() {
  test('locals, parameters and closures get short names', () {
    const js = '''
((W) => {
  const counter = { total: 0 };
  function increment(amount, ...rest) {
    const doubled = amount * 2;
    counter.total += doubled + rest.length;
    return counter.total;
  }
  const values = [1, 2, 3].map((element) => increment(element, element));
  console.log(values.join(','), counter.total);
})(globalThis);
''';
    final out = renameLocals(js);
    for (final gone in ['counter', 'increment', 'amount', 'doubled']) {
      expect(out, isNot(contains(' $gone')), reason: out);
    }
    // Properties and globals stay.
    expect(out, contains('.total'));
    expect(out, contains('console.log'));
    _same(js);
  });

  test('keys, properties, methods and class members keep their names', () {
    const js = '''
((W) => {
  const total = 3, label = 'x';
  const make = (value) => ({ total: value, label, value() { return 1; }, get size() { return 2; } });
  class Box {
    constructor(size) { this.size = size; }
    total() { return this.size; }
  }
  const box = new Box(total);
  const o = make(total);
  console.log(o.total, o.label, o.value(), o.size, box.total(), JSON.stringify(o));
})(globalThis);
''';
    final out = renameLocals(js);
    // `label` (a shorthand key) becomes `label: <new>`.
    expect(out, contains('label: '));
    // `total` is a class member: never renamed.
    expect(out, contains('const total = 3'));
    _same(js);
  });

  test('shadowing, destructuring and template expressions', () {
    const js = r'''
((W) => {
  const name = 'outer';
  const { first, second: other = 5 } = { first: 1 };
  const [left, right] = [2, 3];
  const inner = () => {
    const name = 'inner';
    return `${name}:${first}:${other}`;
  };
  if (left) {
    let name = 'block';
    console.log(name, `${name + right}`);
  }
  console.log(name, inner(), left + right);
})(globalThis);
''';
    _same(js);
  });

  test('strings, regular expressions and labels are left alone', () {
    const js = r'''
((W) => {
  const pattern = /counter\/[a-z]+/g;
  const counter = 'counter';
  outer: for (const x of [1, 2]) {
    for (const y of [1, 2]) {
      if (y === 2) continue outer;
      console.log(counter, 'counter', x, y, pattern.source);
    }
  }
})(globalThis);
''';
    final out = renameLocals(js);
    expect(out, contains("'counter'"));
    expect(out, contains(r'/counter\/[a-z]+/g'));
    expect(out, contains('outer:'));
    _same(js);
  });

  test('a new name never captures a name the code already uses', () {
    // `a` and `b` are globals the code reads: no local may become them.
    const js = '''
globalThis.a = 'global a'; globalThis.b = 'global b';
((W) => {
  const longName = 1, otherName = 2;
  const read = () => a + b + longName + otherName;
  console.log(read());
})(globalThis);
''';
    final out = renameLocals(js);
    expect(RegExp(r'const a\b').hasMatch(out), isFalse, reason: out);
    _same(js);
  });

  test('statements without semicolons end a declaration', () {
    const js = '''
let outside = 1
((W) => {
  const inside = 2
  outside = inside + outside
  console.log(outside)
})(globalThis)
''';
    // `outside` is not a local of the arrow: it stays.
    final out = renameLocals(js);
    expect(out, contains('outside = '));
    expect(out, isNot(contains('const outside')));
  });
}
