// The render clock: what a widget reads as "now" (the date picker marks
// today and opens on the current month when it has no `currentDate`). A
// test or a golden fixes it with `withThorNow`, or a whole
// process with `THOR_NOW`; the default is the real time.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_ui/src/foundation/clock.dart' show thorNow;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> picker() async => bodyOfPage(
  await renderDocument(
    ThorApp(
      child: CalendarDatePicker(
        initialDate: null,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        onDateChanged: (_) {},
      ),
    ),
  ),
);

String label(String html) =>
    RegExp(r'role="grid" aria-label="([^"]*)"').firstMatch(html)![1]!;

void main() {
  initializeThorTests();

  test(
    'under a fixed clock the picker opens on that month, every time',
    () async {
      final a = await withThorNow(DateTime(2026, 3, 10), picker);
      final b = await withThorNow(DateTime(2026, 3, 10), picker);
      expect(label(a), 'March 2026');
      expect(a, b);
      final other = await withThorNow(DateTime(2031, 11, 2), picker);
      expect(label(other), 'November 2031');
      expect(other, isNot(a));
    },
  );

  test('the fixed day is the one marked as today', () async {
    final html = await withThorNow(DateTime(2026, 3, 10), picker);
    final noon = await withThorNow(DateTime(2026, 3, 10, 23, 59), picker);
    // The time of day does not change the page; the day does.
    expect(noon, html);
    final next = await withThorNow(DateTime(2026, 3, 11), picker);
    expect(next, isNot(html));
  });

  test(
    'without a clock it reads the real time',
    skip: Platform.environment['THOR_NOW'] == null ? false : 'THOR_NOW is set',
    () async {
      final before = DateTime.now();
      final html = await picker();
      final after = DateTime.now();
      expect([
        for (final d in {before, after})
          '${const [
            'January', 'February', 'March', 'April', 'May', 'June', 'July',
            'August', 'September', 'October', 'November', 'December', //
          ][d.month - 1]} ${d.year}',
      ], contains(label(html)));
    },
  );

  test('a currentDate of the app still wins over the clock', () async {
    final html = await withThorNow(
      DateTime(2031, 11, 2),
      () async => bodyOfPage(
        await renderDocument(
          ThorApp(
            child: CalendarDatePicker(
              initialDate: null,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              currentDate: DateTime(2026, 9, 20),
              onDateChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(label(html), 'September 2026');
  });

  group('the zone value stays with its own async chain', () {
    test('two renders at once each read their own date', () async {
      final a = withThorNow(DateTime(2026, 3, 10), () async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return label(await picker());
      });
      final b = withThorNow(DateTime(2031, 11, 2), () async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return label(await picker());
      });
      expect(await Future.wait([a, b]), ['March 2026', 'November 2031']);
    });

    test('it does not leak out of the call, and the inner one wins', () async {
      final inner = await withThorNow(
        DateTime(2026, 3, 10),
        () => withThorNow(DateTime(2031, 11, 2), picker),
      );
      expect(label(inner), 'November 2031');
      expect(thorNow().year, isNot(2031));
    });

    test('a timer or a microtask started inside keeps the date', () async {
      final seen = await withThorNow(DateTime(2026, 3, 10, 23, 30), () {
        final done = Completer<DateTime>();
        Timer(const Duration(milliseconds: 5), () {
          scheduleMicrotask(() => done.complete(thorNow()));
        });
        return done.future;
      });
      expect(seen, DateTime(2026, 3, 10, 23, 30));
    });
  });

  group('THOR_NOW pins a whole process', () {
    Future<ProcessResult> run(String? now) => Process.run(
      Platform.resolvedExecutable,
      ['run', 'test/fixtures/render_clock.dart'],
      environment: {'THOR_NOW': ?now},
      includeParentEnvironment: false,
    );

    test('the page of a process with it is the one of that date', () async {
      final r = await run('2029-07-04T12:00:00');
      expect(r.stderr, '');
      expect((r.stdout as String).trim(), 'July 2029');
      // Not read from the parent: the same one, whatever the day.
      expect(((await run('2029-07-04')).stdout as String).trim(), 'July 2029');
    });

    test(
      'a value that is not a date fails loudly, never the real time',
      () async {
        final r = await run('tomorrow');
        expect(r.exitCode, isNot(0));
        expect(r.stderr, contains('THOR_NOW'));
      },
    );
  });
}
