import 'dart:async';

import 'clock_env_stub.dart' if (dart.library.io) 'clock_env_io.dart';

/// The time a widget reads as "now" while it renders (the date picker's
/// today and the month it opens on): never `DateTime.now()` directly, so a
/// render can be made reproducible.
///
/// In order: the zone's value ([withThorNow], what a test wraps the render
/// in), the `THOR_NOW` environment variable (an ISO 8601 date-time,
/// `2026-01-15T12:00:00`; without an offset it is local time: what
/// `tool/golden.sh` sets so the goldens stop changing every day, like
/// `SOURCE_DATE_EPOCH` of reproducible builds), and the real time.
///
/// `// web:` Flutter reads `DateTime.now()` at build time and a test fakes
/// it with `fake_async`; on the server the same page is rendered for every
/// visitor, so the render needs a value that can be pinned.
DateTime thorNow() {
  final zoned = Zone.current[_key];
  if (zoned is DateTime) return zoned;
  return pinnedNow() ?? DateTime.now();
}

final _key = Object();

/// Runs [body] with [now] as what widgets read as the current time (the
/// date picker's today and the month it opens on, when the app gives no
/// `currentDate`). Zone-scoped, like `withClock` of `package:clock`: the
/// asynchronous work [body] starts sees it too, so
/// `await withThorNow(DateTime(2026, 3, 10), () => renderHtml(widget))`
/// is stable any day.
///
/// ```dart
/// final html = await withThorNow(
///   DateTime(2026, 3, 10),
///   () => renderHtml(const DueDatePicker()),
/// );
/// ```
R withThorNow<R>(DateTime now, R Function() body) =>
    runZoned(body, zoneValues: {_key: now});
