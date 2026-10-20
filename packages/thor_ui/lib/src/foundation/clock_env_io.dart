import 'dart:io' show Platform;

/// `THOR_NOW` (an ISO 8601 date-time), read once: null when it is not set.
/// A value that is not a date-time is an error, not a silent real time: the
/// render that asked for a pinned date must not change with the day.
DateTime? pinnedNow() => _pinned;

final DateTime? _pinned = _read();

DateTime? _read() {
  final v = Platform.environment['THOR_NOW'];
  if (v == null || v.isEmpty) return null;
  final t = DateTime.tryParse(v);
  if (t == null) {
    throw FormatException(
      'THOR_NOW is not an ISO 8601 date-time (2026-01-15T12:00:00)',
      v,
    );
  }
  return t;
}
