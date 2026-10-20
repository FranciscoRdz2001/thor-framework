/// A run of lines of a code block, counted from 1 and inclusive.
///
/// ```dart
/// StudioCodeBlock(code, highlight: [StudioLineRange(2, 4), StudioLineRange(7)])
/// // or the same from text, like a markdown fence's `{2-4,7}`:
/// StudioCodeBlock(code, highlight: StudioLineRange.parse('2-4,7'))
/// ```
class StudioLineRange {
  /// Lines [start] to [end] (just [start] when [end] is omitted).
  const StudioLineRange(this.start, [int? end])
    : end = end ?? start,
      assert(start >= 1);

  /// The first line (1-based).
  final int start;

  /// The last line, included.
  final int end;

  /// Whether [line] (1-based) is in the range.
  bool contains(int line) => line >= start && line <= end;

  /// The ranges of a spec like `'2-4,7'` (a bad piece is skipped).
  static List<StudioLineRange> parse(String spec) => [
    for (final part in spec.split(','))
      if (RegExp(r'^\s*(\d+)\s*(?:-\s*(\d+))?\s*$').firstMatch(part)
          case final m?)
        if (int.parse(m[1]!) >= 1)
          StudioLineRange(int.parse(m[1]!), int.tryParse(m[2] ?? '')),
  ];

  @override
  bool operator ==(Object other) =>
      other is StudioLineRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => start == end ? '$start' : '$start-$end';
}
