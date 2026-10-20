// Adversarial oracle tests for the lite futures: error ordering, flattening,
// whenComplete and microtask/timer ordering must match dart2js exactly.
@Timeout(Duration(minutes: 3))
library;

import 'package:test/test.dart';

import 'lite_oracle.dart';

void main() {
  test('Future.wait: several failures, eagerError both ways', () async {
    await sameAsWeb(r"""
Future<int> bad(int ms, String m, List<String> log) =>
    Future.delayed(Duration(milliseconds: ms), () { log.add('bad $m'); throw StateError(m); });
Future<int> ok(int ms, int v, List<String> log) =>
    Future.delayed(Duration(milliseconds: ms), () { log.add('ok $v'); return v; });
Future<String> t0() async {
  final log = <String>[];
  try {
    await Future.wait([bad(30, 'c', log), ok(10, 1, log), bad(5, 'a', log), bad(20, 'b', log)]);
  } on StateError catch (e) { log.add('caught $e'); }
  return log.join(',');
}
Future<String> t1() async {
  final log = <String>[];
  try {
    await Future.wait([bad(30, 'c', log), ok(10, 1, log), bad(5, 'a', log), bad(20, 'b', log)], eagerError: true);
  } on StateError catch (e) { log.add('caught $e'); }
  await Future.delayed(const Duration(milliseconds: 60));
  return log.join(',');
}
Future<String> t2() async {
  final log = <String>[];
  try {
    await Future.wait([bad(30, 'c', log), ok(10, 1, log)], eagerError: false);
  } on StateError catch (e) { log.add('caught $e'); }
  return log.join(',');
}
// A failing future that is already complete.
Future<String> t3() async {
  try {
    await Future.wait([Future.value(1), Future<int>.error(StateError('now')), Future.delayed(const Duration(milliseconds: 5), () => 2)]);
    return 'none';
  } on StateError catch (e) { return '$e'; }
}
// Mixed types
Future<String> t4() async {
  final r = await Future.wait([Future.value(1), Future.value('s')]);
  return '${r.length}';
}
""", 5);
  });

  test('whenComplete: value, error, throwing, returning a future', () async {
    await sameAsWeb(r"""
Future<String> t0() async {
  final log = <String>[];
  final v = await Future.value(1).whenComplete(() { log.add('wc'); });
  return '$v ${log.join(',')}';
}
Future<String> t1() async {
  final log = <String>[];
  try {
    await Future<int>.error(StateError('orig')).whenComplete(() { log.add('wc'); });
  } on StateError catch (e) { log.add('caught $e'); }
  return log.join(',');
}
Future<String> t2() async {
  final log = <String>[];
  try {
    await Future.value(1).whenComplete(() { log.add('wc'); throw ArgumentError('from wc'); });
    log.add('no error');
  } on ArgumentError catch (e) { log.add('caught arg'); }
  return log.join(',');
}
Future<String> t3() async {
  final log = <String>[];
  try {
    await Future<int>.error(StateError('orig')).whenComplete(() { throw ArgumentError('wc wins'); });
  } on ArgumentError catch (e) { log.add('caught arg'); }
  return log.join(',');
}
// the future returned by whenComplete's action is awaited (value ignored)
Future<String> t4() async {
  final log = <String>[];
  final v = await Future.value(5).whenComplete(() => Future.delayed(const Duration(milliseconds: 10), () { log.add('slow'); }));
  log.add('v $v');
  return log.join(',');
}
// action's future fails: replaces the result
Future<String> t5() async {
  try {
    await Future.value(5).whenComplete(() => Future<void>.error(StateError('late')));
    return 'none';
  } on StateError catch (e) { return '$e'; }
}
""", 6);
  });

  test('Completer completed with a Future, double completion', () async {
    await sameAsWeb(r"""
Future<String> t0() async {
  final c = Completer<int>();
  final log = <String>[];
  c.complete(Future.delayed(const Duration(milliseconds: 10), () => 42));
  log.add('completed ${c.isCompleted}');
  log.add('v ${await c.future}');
  return log.join(',');
}
Future<String> t1() async {
  final c = Completer<int>();
  c.complete(Future<int>.error(StateError('inner')));
  try { await c.future; return 'none'; } on StateError catch (e) { return '$e'; }
}
Future<String> t2() async {
  final c = Completer<int>();
  c.complete(1);
  try { c.complete(2); return 'no throw'; } on StateError catch (e) { return 'state'; }
}
Future<String> t3() async {
  final c = Completer<int>();
  c.future.catchError((Object e) => 0);
  c.completeError(StateError('e'));
  try { c.complete(2); return 'no throw'; } on StateError catch (e) { return 'state'; }
}
Future<String> t4() async {
  final c = Completer<int>();
  final f = c.future.then((v) => v + 1);
  c.complete(1);
  return '${await f}';
}
Future<String> t5() async {
  final c = Completer<void>();
  Future.delayed(Duration.zero, () => c.complete());
  await c.future;
  return 'done ${c.isCompleted}';
}
""", 6);
  });

  // Not an oracle against dart2js: under node its microtask loop runs on
  // setImmediate, after zero timers. The expected order is the Dart VM's and
  // the browser's: every microtask before any timer.
  test('microtask vs timer vs sync ordering (the Dart VM order)', () async {
    const src =
        '''
$header
${r"""
Future<String> t0() async {
  final log = <String>[];
  Future.delayed(Duration.zero, () => log.add('future'));
  Future.microtask(() => log.add('micro'));
  Future.sync(() { log.add('sync'); return 1; }).then((_) => log.add('sync-then'));
  Future.value(1).then((_) => log.add('value-then'));
  Future.delayed(Duration.zero, () => log.add('delayed0'));
  log.add('end');
  await Future.delayed(const Duration(milliseconds: 20));
  return log.join(',');
}
Future<String> t1() async {
  final log = <String>[];
  Future.delayed(Duration.zero, () { log.add('a'); }).then((_) => log.add('a-then'));
  Future.delayed(Duration.zero, () { log.add('b'); });
  Future.microtask(() { log.add('m1'); Future.microtask(() => log.add('m2')); });
  await Future.delayed(const Duration(milliseconds: 20));
  return log.join(',');
}
Future<String> t2() async {
  final log = <String>[];
  Future<void> f() async { log.add('f1'); await null; log.add('f2'); }
  f();
  log.add('after f');
  await Future.delayed(const Duration(milliseconds: 5));
  return log.join(',');
}
Future<String> t3() async {
  final log = <String>[];
  Future<int>.sync(() { throw StateError('s'); }).catchError((Object e) { log.add('caught'); return 0; });
  log.add('after');
  await Future.delayed(const Duration(milliseconds: 5));
  return log.join(',');
}
Future<String> t4() async {
  final log = <String>[];
  final f = Future<int>.error(StateError('x'));
  f.catchError((Object e) { log.add('c1'); return 0; });
  f.then((_) => log.add('never'), onError: (Object e) { log.add('c2'); });
  await Future.delayed(const Duration(milliseconds: 5));
  return log.join(',');
}
"""}
class PState extends ThorState {
  Future<String> e0() => t0();
  Future<String> e1() => t1();
  Future<String> e2() => t2();
  Future<String> e3() => t3();
  Future<String> e4() => t4();
}
''';
    final js = await translate(src);
    if (!hasNode) return markTestSkipped('node is not installed');
    final out = runJs(
      js,
      'out.all = [await S.e0(), await S.e1(), await S.e2(), await S.e3(), await S.e4()];',
    );
    expect(out['all'], [
      'sync,end,micro,sync-then,value-then,future,delayed0',
      'm1,m2,a,a-then,b',
      'f1,after f,f2',
      'after,caught',
      'c1,c2',
    ]);
  });

  test('then chain flattening, nested futures and thrown values', () async {
    await sameAsWeb(r"""
Future<String> t0() async {
  final v = await Future.value(1).then((v) => Future.value(Future.value(v + 1)));
  return '$v';
}
Future<String> t1() async {
  final log = <String>[];
  try {
    await Future.value(1).then((v) => Future<int>.error(StateError('flat')));
  } on StateError catch (e) { log.add('$e'); }
  return log.join(',');
}
Future<String> t2() async {
  try { await Future.value(1).then((v) { throw 'a string'; }); return 'none'; }
  catch (e) { return 'caught ${e is String}'; }
}
Future<String> t3() async {
  final log = <String>[];
  await Future.value(1).catchError((Object e) { log.add('never'); return 0; });
  log.add('done');
  return log.join(',');
}
Future<String> t4() async {
  // catchError with test returning false lets the error through to the next handler
  final log = <String>[];
  try {
    await Future<int>.error(StateError('x'))
      .catchError((Object e) { log.add('first'); return 1; }, test: (e) => false)
      .catchError((Object e) { log.add('second'); return 2; });
  } on StateError catch (e) { log.add('outer'); }
  return log.join(',');
}
Future<String> t5() async {
  final r = await Future<int>.error(StateError('x')).then((v) => 1, onError: (Object e) => 99);
  return '$r';
}
Future<String> t6() async {
  final r = await Future.value(3).then<int>((v) => v).then((v) => v * 2).whenComplete(() {}).then((v) => v + 1);
  return '$r';
}
""", 7);
  });
}
