import 'dart:async';

import 'package:test/test.dart';
import 'package:thor_cli/src/dev/change_batch.dart';

void main() {
  const quick = Duration(milliseconds: 10);
  // The settle is wide, so a loaded machine can't stretch a wait past it, and
  // what must happen is waited for with a deadline, not for a fixed time.
  const settle = Duration(milliseconds: 1000);

  Future<void> until(bool Function() ok) async {
    final end = DateTime.now().add(const Duration(seconds: 20));
    while (!ok() && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  /// A batch that counts its fires and when the first came.
  (ChangeBatch, List<int>, Stopwatch) batch() {
    final clock = Stopwatch()..start();
    final fires = <int>[];
    final batch = ChangeBatch(
      () => fires.add(clock.elapsedMilliseconds),
      quick: quick,
      settle: settle,
    );
    return (batch, fires, clock);
  }

  test('a single saved file applies at once, not after the settle', () async {
    final (b, fires, _) = batch();
    b.add('lib/a.dart');
    await until(() => fires.isNotEmpty);
    expect(fires, hasLength(1));
    expect(fires.single, lessThan(settle.inMilliseconds ~/ 2));
  });

  test('the same file saved twice at once fires once, fast', () async {
    final (b, fires, _) = batch();
    b
      ..add('lib/a.dart')
      ..add('lib/a.dart');
    await until(() => fires.isNotEmpty);
    expect(fires, hasLength(1));
  });

  test('several files (a checkout) settle first and fire once', () async {
    final (b, fires, clock) = batch();
    b
      ..add('lib/a.dart')
      ..add('lib/b.dart');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    b.add('lib/c.dart');
    final last = clock.elapsedMilliseconds;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(fires, isEmpty, reason: 'still settling');
    await until(() => fires.isNotEmpty);
    expect(fires, hasLength(1));
    expect(fires.single, greaterThanOrEqualTo(last + settle.inMilliseconds));
  });

  test('quiet waits for the rest of a burst', () async {
    final (b, _, clock) = batch();
    b.add('lib/a.dart');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    b.add('lib/b.dart');
    final last = clock.elapsedMilliseconds;
    await b.quiet();
    expect(
      clock.elapsedMilliseconds,
      greaterThanOrEqualTo(last + settle.inMilliseconds),
    );
    // Nothing new: it doesn't wait.
    final before = clock.elapsedMilliseconds;
    await b.quiet();
    expect(
      clock.elapsedMilliseconds - before,
      lessThan(settle.inMilliseconds ~/ 2),
      reason: 'it did not wait for a settle',
    );
  });

  test('cancel drops the pending fire', () async {
    final (b, fires, _) = batch();
    b
      ..add('lib/a.dart')
      ..cancel();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(fires, isEmpty);
  });
}
