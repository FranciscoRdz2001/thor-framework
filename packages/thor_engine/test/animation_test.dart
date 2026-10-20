import 'dart:async';

import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

/// Records what the controller asks the page to do; [progress] and
/// [reducedMotion] are set by the test.
class FakeDriver implements AnimationDriver {
  final plays = <AnimationPlayback>[];
  final seeks = <double>[];
  @override
  double progress = 0;
  @override
  bool reducedMotion = false;

  @override
  void play(AnimationPlayback playback) {
    plays.add(playback);
    progress = playback.from;
  }

  @override
  void seek(double t) {
    seeks.add(t);
    progress = t;
  }
}

const _ms300 = Duration(milliseconds: 300);

/// What a thor_style `Curve` is to the controller: an object with a CSS
/// easing.
class _Curve {
  const _Curve(this.css);
  final String css;
}

/// A curve with a function too: t squared.
class _FnCurve {
  const _FnCurve();
  String get css => 'ease';
  double transform(double t) => t * t;
}

(AnimationController, FakeDriver, List<AnimationStatus>) _attached({
  Duration? duration = _ms300,
  Duration? reverseDuration,
  double lowerBound = 0,
  double upperBound = 1,
}) {
  final c = AnimationController(
    duration: duration,
    reverseDuration: reverseDuration,
    lowerBound: lowerBound,
    upperBound: upperBound,
  );
  final driver = FakeDriver();
  final statuses = <AnimationStatus>[];
  c
    ..attachDriver(driver)
    ..addStatusListener(statuses.add);
  return (c, driver, statuses);
}

void main() {
  group('invalid input fails at the call, not in the page', () {
    test('negative durations are rejected', () {
      expect(
        () => AnimationController(duration: const Duration(milliseconds: -1)),
        throwsArgumentError,
      );
      expect(
        () => AnimationController(
          duration: _ms300,
          reverseDuration: const Duration(microseconds: -1),
        ),
        throwsArgumentError,
      );
      final c = AnimationController(duration: _ms300);
      expect(
        () => c.duration = const Duration(seconds: -1),
        throwsArgumentError,
      );
      expect(c.duration, _ms300, reason: 'a rejected value is not kept');
      expect(
        () => c.repeat(period: const Duration(milliseconds: -5)),
        throwsArgumentError,
      );
    });

    test('bounds must be finite and increasing; values finite', () {
      expect(
        () => AnimationController(lowerBound: 1, upperBound: 1),
        throwsArgumentError,
      );
      expect(
        () => AnimationController(lowerBound: 2, upperBound: 1),
        throwsArgumentError,
      );
      expect(
        () => AnimationController(upperBound: double.infinity),
        throwsArgumentError,
      );
      expect(() => AnimationController(value: double.nan), throwsArgumentError);
      final c = AnimationController();
      expect(() => c.value = double.nan, throwsArgumentError);
    });

    test('playing without a duration is a StateError', () {
      final c = AnimationController();
      expect(c.forward, throwsStateError);
      expect(c.reverse, throwsStateError);
      expect(c.repeat, throwsStateError);
      expect(c.toggle, throwsStateError);
      expect(c.status, AnimationStatus.dismissed);
      expect(c.isAnimating, isFalse);
    });

    test('repeat needs at least one pass', () {
      final c = AnimationController(duration: _ms300);
      expect(() => c.repeat(count: 0), throwsArgumentError);
      expect(() => c.repeat(count: -2), throwsArgumentError);
      expect(c.playback, isNull);
    });
  });

  test('reverse before forward does nothing: already dismissed', () {
    final (c, driver, statuses) = _attached();
    c.reverse();
    expect(c.status, AnimationStatus.dismissed);
    expect(driver.plays, isEmpty);
    expect(statuses, isEmpty, reason: 'the status did not change');
    expect(c.isAnimating, isFalse);
  });

  test('forward plays the rest of the range, then completes', () {
    final (c, driver, statuses) = _attached();
    c.forward();
    expect(driver.plays.single.from, 0);
    expect(driver.plays.single.reverse, isFalse);
    expect(driver.plays.single.sweep, _ms300);
    expect(c.status, AnimationStatus.forward);
    expect(c.isAnimating, isTrue);
    driver.progress = 1;
    c.driverFinished();
    expect(c.value, 1);
    expect(c.status, AnimationStatus.completed);
    expect(c.isAnimating, isFalse);
    expect(statuses, [AnimationStatus.forward, AnimationStatus.completed]);
    // A late finish (stale event) changes nothing.
    c.driverFinished();
    expect(statuses, hasLength(2));
  });

  test('forward when completed and zero durations jump, not play', () {
    final (c, driver, statuses) = _attached(duration: Duration.zero);
    c.forward();
    expect(driver.plays, isEmpty);
    expect(c.value, 1);
    expect(c.status, AnimationStatus.completed);
    c.duration = _ms300;
    c.forward();
    expect(driver.plays, isEmpty, reason: 'already at the end');
    expect(statuses, [AnimationStatus.completed]);
  });

  test('reverse uses reverseDuration and runs towards the lower bound', () {
    final (c, driver, _) = _attached(
      reverseDuration: const Duration(milliseconds: 100),
    );
    c.value = 1;
    c.reverse();
    final p = driver.plays.single;
    expect(p.reverse, isTrue);
    expect(p.from, 1);
    expect(p.sweep, const Duration(milliseconds: 100));
    expect(c.status, AnimationStatus.reverse);
    driver.progress = 0;
    c.driverFinished();
    expect(c.status, AnimationStatus.dismissed);
  });

  test('stop mid-way keeps the value and the status', () {
    final (c, driver, statuses) = _attached();
    c.forward();
    driver.progress = 0.4;
    c.stop();
    expect(c.value, closeTo(0.4, 1e-9));
    expect(c.isAnimating, isFalse);
    expect(c.status, AnimationStatus.forward, reason: 'like Flutter');
    expect(driver.seeks.last, closeTo(0.4, 1e-9));
    // Stopping twice, or a finish that arrives after stop, is a no-op.
    c
      ..stop()
      ..driverFinished();
    expect(statuses, [AnimationStatus.forward]);
    // Forward again continues from where it stopped.
    c.forward();
    expect(driver.plays.last.from, closeTo(0.4, 1e-9));
  });

  test('repeat(reverse: true) alternates forever, stop freezes it', () {
    final (c, driver, _) = _attached();
    c.value = 0.25;
    c.repeat(reverse: true, period: const Duration(seconds: 2));
    final p = driver.plays.single;
    expect(p.alternate, isTrue);
    expect(p.repeats, isTrue);
    expect(p.from, 0.25);
    expect(p.sweep, const Duration(seconds: 2));
    expect(c.status, AnimationStatus.forward);
    driver.progress = 0.7;
    c.stop();
    expect(c.value, closeTo(0.7, 1e-9));
    expect(c.playback, isNull);
    // A forward after a loop is a single pass again.
    c.forward();
    expect(driver.plays.last.repeats, isFalse);
    expect(driver.plays.last.alternate, isFalse);
  });

  test('repeat with a count ends where the last pass ends', () {
    final (c, driver, statuses) = _attached();
    c.repeat(reverse: true, count: 2);
    expect(driver.plays.single.iterations, 2);
    driver.progress = 0; // two alternating passes end at the start
    c.driverFinished();
    expect(c.status, AnimationStatus.dismissed);
    expect(statuses, [AnimationStatus.forward, AnimationStatus.dismissed]);
  });

  group('repeat(min:, max:)', () {
    test('loops between the two values: the playback has the window', () {
      final (c, driver, _) = _attached();
      c.repeat(min: 0.3, max: 0.8, reverse: true, period: _ms300);
      final p = driver.plays.single;
      expect([p.min, p.max], [0.3, 0.8]);
      expect(p.windowed, isTrue);
      expect(p.alternate, isTrue);
      expect(p.repeats, isTrue);
      expect(p.sweep, _ms300, reason: 'the period is one pass of the window');
      // Starts from the value, clamped into the window.
      expect(p.from, 0);
      expect(p.passAt, 0, reason: 'below the window: its start');
    });

    test('starts where the value is inside the window', () {
      final (c, driver, _) = _attached();
      c.value = 0.55;
      c.repeat(min: 0.3, max: 0.8);
      final p = driver.plays.single;
      expect(p.passAt, closeTo(0.5, 1e-9), reason: '(0.55 - 0.3) / 0.5');
    });

    test('a window with no min or max is the whole range', () {
      final (c, driver, _) = _attached();
      c.repeat(max: 0.5);
      expect([driver.plays.single.min, driver.plays.single.max], [0, 0.5]);
      c.repeat();
      final all = driver.plays.last;
      expect([all.min, all.max, all.windowed], [0, 1, false]);
      c.repeat(min: 0, max: 1);
      expect(driver.plays.last.windowed, isFalse);
    });

    test('the window is a fraction of the bounds', () {
      final (c, driver, _) = _attached(lowerBound: 10, upperBound: 20);
      c.repeat(min: 12, max: 18);
      expect([driver.plays.single.min, driver.plays.single.max], [0.2, 0.8]);
    });

    test('the bounds are asserted', () {
      final (c, _, _) = _attached();
      // Asserts, like Flutter's: a release build clamps instead.
      final bad = throwsA(isA<AssertionError>());
      expect(() => c.repeat(min: 0.8, max: 0.3), bad);
      expect(() => c.repeat(min: -0.1), bad);
      expect(() => c.repeat(max: 1.5), bad);
      expect(() => c.repeat(min: double.nan), bad);
      expect(() => c.repeat(min: 0.5, max: 0.5), returnsNormally);
    });

    test('reduced motion rests at the top of the window', () {
      final (c, driver, _) = _attached();
      driver.reducedMotion = true;
      c.repeat(min: 0.2, max: 0.6, reverse: true);
      expect(driver.plays, isEmpty);
      expect(c.value, 0.6);
    });

    test('a count ends where the last pass of the window ends', () {
      final (c, driver, statuses) = _attached();
      c.repeat(min: 0.2, max: 0.6, count: 1);
      driver.progress = 0.6; // the page reports the value
      c.driverFinished();
      expect(c.value, closeTo(0.6, 1e-9));
      expect(c.status, AnimationStatus.forward);
      expect(statuses, [AnimationStatus.forward]);
    });

    test('a loop the server started keeps its window when the page wakes', () {
      final c = AnimationController(duration: _ms300)
        ..repeat(min: 0.2, max: 0.6);
      final driver = FakeDriver();
      c.attachDriver(driver, from: 0.5); // the pass the CSS animation is at
      final p = driver.plays.single;
      expect([p.min, p.max], [0.2, 0.6]);
      expect(p.from, closeTo(0.4, 1e-9));
      expect(p.passAt, closeTo(0.5, 1e-9));
    });
  });

  test('reduced motion: nothing plays, it jumps to where it rests', () {
    final (c, driver, statuses) = _attached();
    driver.reducedMotion = true;
    c.forward();
    expect(driver.plays, isEmpty);
    expect(c.value, 1);
    expect(c.status, AnimationStatus.completed);
    c.reverse();
    expect(c.value, 0);
    c.repeat(reverse: true);
    expect(driver.plays, isEmpty);
    expect(c.value, 1, reason: 'a loop rests at the upper bound');
    expect(statuses, [
      AnimationStatus.completed,
      AnimationStatus.dismissed,
      AnimationStatus.completed,
    ]);
  });

  group('animateTo, animateBack and fling', () {
    // Whether a future is done, without waiting for it.
    Future<bool> done(Future<void> f) async {
      var ok = false;
      unawaited(f.then((_) => ok = true));
      await Future<void>.delayed(Duration.zero);
      return ok;
    }

    test('animateTo plays up to the target and completes there', () async {
      final (c, driver, statuses) = _attached();
      final f = c.animateTo(0.5);
      final p = driver.plays.single;
      expect((p.from, p.to, p.reverse), (0, 0.5, false));
      expect(p.sweep, _ms300, reason: 'a default duration is a full pass');
      expect(c.status, AnimationStatus.forward);
      expect(await done(f), isFalse);
      driver.progress = 0.5;
      c.driverFinished();
      expect(c.value, 0.5);
      expect(c.isAnimating, isFalse);
      expect(await done(f), isTrue);
      // Like Flutter, the end of a forward move reports completed.
      expect(c.status, AnimationStatus.completed);
      expect(statuses, [AnimationStatus.forward, AnimationStatus.completed]);
    });

    test('an explicit duration is this move, not a full pass', () {
      final (c, driver, _) = _attached();
      c.animateTo(0.5, duration: const Duration(milliseconds: 100));
      expect(driver.plays.single.sweep, const Duration(milliseconds: 200));
      c.value = 0.5;
      c.animateTo(1, duration: const Duration(milliseconds: 100));
      expect(
        driver.plays.last.sweep,
        const Duration(milliseconds: 200),
        reason: 'half the range in 100 ms',
      );
      c.value = 0;
      c.animateTo(1, duration: const Duration(milliseconds: 100));
      expect(driver.plays.last.sweep, const Duration(milliseconds: 100));
    });

    test('the curve reaches the playback as its CSS easing', () {
      final (c, driver, _) = _attached();
      c.animateTo(0.5, curve: const _Curve('cubic-bezier(0, 0, 0.58, 1)'));
      expect(driver.plays.single.easing, 'cubic-bezier(0, 0, 0.58, 1)');
      c.value = 1;
      c.animateBack(0.5, curve: const _Curve('linear(0, 0.7, 1)'));
      expect(driver.plays.last.easing, 'linear(0, 0.7, 1)');
      // No curve, or `linear`, is no easing; forward() never has one.
      c.value = 0;
      c.animateTo(0.5);
      expect(driver.plays.last.easing, isNull);
      c.animateTo(1, curve: const _Curve('linear'));
      expect(driver.plays.last.easing, isNull);
      c.value = 0;
      c.forward();
      expect(driver.plays.last.easing, isNull);
    });

    test('a curve is anything with a css easing; anything else is refused '
        'before it plays', () {
      final (c, driver, _) = _attached();
      expect(() => c.animateTo(0.5, curve: 3), throwsArgumentError);
      expect(() => c.animateBack(0, curve: 'ease'), throwsArgumentError);
      expect(driver.plays, isEmpty);
    });

    test('the easing keeps the stretch, the direction and the sweep of the '
        'move', () {
      final (c, driver, _) = _attached();
      c.value = 0.8;
      c.animateTo(
        0.2,
        duration: const Duration(milliseconds: 600),
        curve: const _Curve('cubic-bezier(0.4, 0, 0.2, 1)'),
      );
      final p = driver.plays.single;
      expect((p.from, p.to, p.reverse), (0.8, 0.2, true));
      expect(p.sweep, const Duration(milliseconds: 1000));
      expect(p.easing, 'cubic-bezier(0.4, 0, 0.2, 1)');
    });

    test('a target below the value plays backwards, status forward '
        '(Flutter keeps the direction of the call)', () {
      final (c, driver, _) = _attached();
      c.value = 1;
      c.animateTo(0.25);
      final p = driver.plays.single;
      expect((p.from, p.to, p.reverse), (1, 0.25, true));
      expect(c.status, AnimationStatus.forward);
      driver.progress = 0.25;
      c.driverFinished();
      expect(c.value, 0.25);
      expect(c.status, AnimationStatus.completed);
    });

    test('animateBack runs towards the target with reverseDuration; it ends '
        'dismissed', () async {
      final (c, driver, _) = _attached(
        reverseDuration: const Duration(milliseconds: 100),
      );
      c.value = 1;
      final f = c.animateBack(0.5);
      final p = driver.plays.single;
      expect((p.from, p.to, p.reverse), (1, 0.5, true));
      expect(p.sweep, const Duration(milliseconds: 100));
      expect(c.status, AnimationStatus.reverse);
      driver.progress = 0.5;
      c.driverFinished();
      expect(await done(f), isTrue);
      expect(c.value, 0.5);
      expect(c.status, AnimationStatus.dismissed);
    });

    test('animateBack falls back to duration', () {
      final (c, driver, _) = _attached();
      c.value = 1;
      c.animateBack(0);
      expect(driver.plays.single.sweep, _ms300);
      expect(driver.plays.single.to, isNull, reason: 'the bound itself');
    });

    test('a zero duration, or already there, jumps; status follows the '
        'direction', () async {
      final (c, driver, statuses) = _attached();
      final f = c.animateTo(0.5, duration: Duration.zero);
      expect(driver.plays, isEmpty);
      expect(c.value, 0.5);
      expect(c.status, AnimationStatus.completed);
      expect(await done(f), isTrue);
      unawaited(c.animateBack(0.5));
      expect(driver.plays, isEmpty, reason: 'already there');
      expect(c.status, AnimationStatus.dismissed);
      expect(statuses, [AnimationStatus.completed, AnimationStatus.dismissed]);
    });

    test('a target past the bounds stops at them', () {
      final (c, driver, _) = _attached();
      c.animateTo(5);
      expect(driver.plays.single.to, isNull);
      expect(driver.plays.single.reverse, isFalse);
      c.animateTo(-3);
      expect(driver.plays.last.reverse, isFalse, reason: 'already at 0');
      expect(c.value, 0);
    });

    test('with custom bounds the target is in the controller units', () {
      final (c, driver, _) = _attached(lowerBound: 10, upperBound: 20);
      c.animateTo(15);
      expect(driver.plays.single.to, closeTo(0.5, 1e-9));
    });

    test('another call, a value, a stop, or dispose complete the earlier '
        'future', () async {
      final (c, _, _) = _attached();
      final first = c.animateTo(0.5);
      final second = c.animateTo(1);
      expect(await done(first), isTrue);
      expect(await done(second), isFalse);
      c.value = 0.2;
      expect(await done(second), isTrue);
      final third = c.animateTo(1);
      c.stop();
      expect(await done(third), isTrue);
      final fourth = c.animateTo(1);
      c.dispose();
      expect(await done(fourth), isTrue);
    });

    test('without a page (the server) it records the move and completes '
        'at once', () async {
      final c = AnimationController(duration: _ms300);
      final f = c.animateTo(0.5);
      expect(await done(f), isTrue);
      expect(c.playback?.to, 0.5);
    });

    test('reduced motion jumps to the target', () async {
      final (c, driver, _) = _attached();
      driver.reducedMotion = true;
      final f = c.animateTo(0.5);
      expect(driver.plays, isEmpty);
      expect(c.value, 0.5);
      expect(c.status, AnimationStatus.completed);
      expect(await done(f), isTrue);
    });

    test('it needs a duration, and a live controller', () {
      final (c, _, _) = _attached(duration: null);
      expect(() => c.animateTo(1), throwsStateError);
      expect(() => c.animateBack(0), throwsStateError);
      c.animateTo(1, duration: _ms300);
      c.dispose();
      expect(() => c.animateTo(1, duration: _ms300), throwsStateError);
      expect(() => c.animateBack(0, duration: _ms300), throwsStateError);
      expect(c.fling, throwsStateError);
      expect(
        () => AnimationController.inView().animateTo(1, duration: _ms300),
        throwsStateError,
      );
    });

    test('fling goes to the bound in the velocity direction, over the time '
        'of its spring', () async {
      final (c, driver, _) = _attached();
      final f = c.fling();
      var p = driver.plays.single;
      expect((p.from, p.to, p.reverse), (0, null, false));
      // Flutter's spring (stiffness 500, critically damped) at 1 unit/s
      // takes about 0.29 s to cover the range.
      expect(p.sweep.inMilliseconds, inInclusiveRange(250, 340));
      expect(p.easing, startsWith('linear(0, '));
      expect(p.easing, endsWith(', 1)'));
      expect(c.status, AnimationStatus.forward);
      driver.progress = 1;
      c.driverFinished();
      expect(await done(f), isTrue);
      expect(c.status, AnimationStatus.completed);
      unawaited(c.fling(velocity: -2));
      p = driver.plays.last;
      expect((p.from, p.reverse), (1, true));
      expect(c.status, AnimationStatus.reverse);
      driver.progress = 0;
      c.driverFinished();
      expect(c.status, AnimationStatus.dismissed);
    });

    test('an eased move running in the server CSS goes on from the pass the '
        'page woke up at', () {
      final c = AnimationController(duration: const Duration(seconds: 1));
      c.animateTo(0.5, curve: const _Curve('ease')).ignore();
      final fn = c.playback;
      expect(fn, isNotNull);
      // No function: the page falls back to the pass itself.
      expect(fn!.valueAt(0.25), 0.25);
      final c2 = AnimationController(duration: const Duration(seconds: 1))
        ..animateTo(0.5, curve: const _FnCurve()).ignore();
      final p = c2.playback!;
      expect(p.valueAt(0.25), closeTo(0.5 * 0.5 * 0.5, 1e-9));
      expect(p.valueAt(0.75), 0.75, reason: 'identity outside the stretch');
      final driver = FakeDriver();
      c2.attachDriver(driver, from: 0.25);
      final resumed = driver.plays.single;
      expect(resumed.at, 0.25);
      expect((resumed.from, resumed.to), (0.0, 0.5));
      expect(resumed.easing, 'ease');
      expect(resumed.valueAt(resumed.at), closeTo(0.125, 1e-9));
    });

    test('a faster fling arrives sooner; one that starts near the bound, '
        'sooner too; the sign picks the bound', () {
      final (c, driver, _) = _attached();
      c.fling();
      final slow = driver.plays.last.sweep;
      c.value = 0;
      c.fling(velocity: 8);
      final fast = driver.plays.last.sweep;
      expect(fast, lessThan(slow));
      c.value = 0.9;
      c.fling();
      final p = driver.plays.last;
      // The time of the move is the sweep of the fraction it covers.
      expect(p.sweep.inMilliseconds * 0.1, lessThan(slow.inMilliseconds));
      c.value = 0.5;
      c.fling(velocity: -4);
      expect(driver.plays.last.reverse, isTrue);
      expect(driver.plays.last.to, isNull);
    });

    test(
      'a fling that is already at its bound, or has no finite velocity',
      () async {
        final (c, driver, _) = _attached();
        c.value = 1;
        await c.fling();
        expect(driver.plays, isEmpty);
        expect(c.status, AnimationStatus.completed);
        expect(() => c.fling(velocity: double.nan), throwsArgumentError);
        expect(() => c.fling(velocity: double.infinity), throwsArgumentError);
      },
    );

    test('fling needs no duration', () {
      final (c, driver, _) = _attached(duration: null);
      c.fling();
      expect(driver.plays, hasLength(1));
    });
  });

  test('toggle flips the direction', () {
    final (c, driver, _) = _attached();
    c.toggle();
    expect(c.status, AnimationStatus.forward);
    driver.progress = 0.5;
    c.toggle();
    expect(c.status, AnimationStatus.reverse);
    expect(driver.plays.last.reverse, isTrue);
    expect(driver.plays.last.from, closeTo(0.5, 1e-9));
  });

  test('custom bounds: positions are fractions of the range', () {
    final (c, driver, _) = _attached(lowerBound: 10, upperBound: 20);
    c.value = 15;
    expect(driver.seeks.last, 0.5);
    c.value = 99;
    expect(c.value, 20, reason: 'clamped');
    expect(c.status, AnimationStatus.completed);
    driver.progress = 0.25;
    expect(c.value, 12.5);
  });

  group('attaching the page', () {
    test('the value the server rendered wins (hydration mismatch)', () {
      final c = AnimationController(duration: _ms300);
      final driver = FakeDriver();
      final statuses = <AnimationStatus>[];
      c
        ..addStatusListener(statuses.add)
        ..attachDriver(driver, from: 0.5);
      expect(c.value, 0.5);
      expect(driver.seeks.single, 0.5);
      expect(statuses, [AnimationStatus.forward]);
      // A non-finite value from a tampered page is ignored.
      final d = AnimationController(duration: _ms300)
        ..attachDriver(FakeDriver(), from: double.nan);
      expect(d.value, 0);
    });

    test('a controller started before the page attached keeps playing', () {
      // `final spin = AnimationController(…)..repeat();` runs when the
      // state is created, before the engine attaches its driver.
      final c = AnimationController(duration: _ms300)..repeat();
      expect(c.playback, isNotNull);
      final driver = FakeDriver();
      c.attachDriver(driver, from: 0.3); // the CSS animation's progress
      expect(driver.plays.single.repeats, isTrue);
      expect(driver.plays.single.from, closeTo(0.3, 1e-9));
      expect(c.status, AnimationStatus.forward);
    });

    test('on the server (no driver) it records the playback', () {
      final c = AnimationController(duration: _ms300)..forward(from: 0.5);
      expect(c.value, 0.5, reason: 'nothing moves without a page');
      expect(c.playback!.from, 0.5);
      expect(c.status, AnimationStatus.forward);
    });
  });

  test('the status is a signal: an effect that reads it updates', () {
    final (c, driver, _) = _attached();
    final seen = <AnimationStatus>[];
    final stop = effect(() => seen.add(c.status));
    addTearDown(stop);
    c.forward();
    driver.progress = 1;
    c.driverFinished();
    expect(seen, [
      AnimationStatus.dismissed,
      AnimationStatus.forward,
      AnimationStatus.completed,
    ]);
  });

  test('a listener that removes itself while notified is safe', () {
    final (c, _, _) = _attached();
    final calls = <String>[];
    void first(AnimationStatus s) {
      calls.add('first');
      c.removeStatusListener(first);
    }

    c
      ..addStatusListener(first)
      ..addStatusListener((_) => calls.add('second'))
      ..forward()
      ..value = 0;
    expect(calls, ['first', 'second', 'second']);
  });

  test('each request on the server has its own controller state', () {
    final c = AnimationController(duration: _ms300);
    SignalScope.run(c.forward);
    expect(c.playback, isNull, reason: 'another request never started it');
    expect(c.status, AnimationStatus.dismissed);
  });
  group('an effect sees value, status and playback change together', () {
    // One row per run of an effect reading all three; `ops` are the calls.
    void expectCoherent(
      Map<String, void Function(AnimationController)> ops, {
      Set<String> playing = const {},
    }) {
      for (final MapEntry(key: name, value: op) in ops.entries) {
        final (c, driver, _) = _attached();
        driver.progress = 0.4;
        c.value = 0.4;
        if (playing.contains(name)) c.forward();
        final rows = <(double, AnimationStatus, AnimationPlayback?)>[];
        final other = Signal(c.status.index);
        // A status listener that writes another signal.
        c.addStatusListener((s) => other.value = s.index);
        final stop = effect(() => rows.add((c.value, c.status, c.playback)));
        final seen = <(AnimationStatus, int)>[];
        final stop2 = effect(() => seen.add((c.status, other.value)));
        final before = rows.length;
        op(c);
        stop();
        stop2();
        final runs = rows.skip(before).toList();
        expect(runs.length, lessThanOrEqualTo(1), reason: '$name: runs once');
        for (final (v, s, p) in runs) {
          if (p != null) {
            expect(
              s,
              p.reverse ? AnimationStatus.reverse : AnimationStatus.forward,
              reason: '$name: playback $p beside status $s',
            );
          } else if (v == 0 && s != AnimationStatus.dismissed ||
              v == 1 && s != AnimationStatus.completed) {
            fail('$name: value $v beside the old status $s');
          }
        }
        expect(
          seen.last.$2,
          seen.last.$1.index,
          reason: '$name: the listener lags',
        );
      }
    }

    test('forward, reverse, repeat, stop, value, from, reset', () {
      expectCoherent(
        {
          'forward': (c) => c.forward(),
          'reverse': (c) => c.reverse(),
          'forward(from)': (c) => c.forward(from: 0.25),
          'reverse(from)': (c) => c.reverse(from: 1),
          'repeat': (c) => c.repeat(reverse: true),
          'stop mid-animation': (c) => c.stop(),
          'value': (c) => c.value = 1,
          'reset': (c) => c.reset(),
          'toggle': (c) => c.toggle(),
        },
        playing: {'stop mid-animation'},
      );
    });

    test('the end of the page animation lands as one change', () {
      final (c, driver, _) = _attached();
      c.forward();
      var runs = 0;
      final stop = effect(() {
        c.value;
        c.status;
        c.playback;
        runs++;
      });
      driver.progress = 1;
      runs = 0;
      c.driverFinished();
      stop();
      expect(runs, 1);
      expect(c.status, AnimationStatus.completed);
    });
  });
}
