import 'studio_line_range.dart';

/// Which lines of a piece of code are not in another one: what a diff step
/// adds, what differs between the Flutter and the Thor version of an example.
abstract final class StudioCodeDiff {
  /// The 1-based lines of [to] that [from] does not have, as ranges.
  ///
  /// Lines are compared by their trimmed text and blank lines never count
  /// (an indentation change or an empty line is not a difference). The
  /// match is the longest common subsequence, so a line that moved or got
  /// repeated is not reported twice.
  static List<StudioLineRange> added(String from, String to) {
    final a = from.split('\n').map((l) => l.trim()).toList();
    final b = to.split('\n').map((l) => l.trim()).toList();
    final common = _commonLines(a, b);
    final lines = [
      for (var i = 0; i < b.length; i++)
        if (b[i].isNotEmpty && !common.contains(i)) i + 1,
    ];
    return _ranges(lines);
  }

  // The indexes of [b] that belong to the longest common subsequence.
  static Set<int> _commonLines(List<String> a, List<String> b) {
    final n = a.length, m = b.length;
    final table = List.generate(n + 1, (_) => List.filled(m + 1, 0));
    for (var i = n - 1; i >= 0; i--) {
      for (var j = m - 1; j >= 0; j--) {
        table[i][j] = a[i] == b[j]
            ? table[i + 1][j + 1] + 1
            : (table[i + 1][j] >= table[i][j + 1]
                  ? table[i + 1][j]
                  : table[i][j + 1]);
      }
    }
    final out = <int>{};
    var i = 0, j = 0;
    while (i < n && j < m) {
      if (a[i] == b[j]) {
        out.add(j);
        i++;
        j++;
      } else if (table[i + 1][j] >= table[i][j + 1]) {
        i++;
      } else {
        j++;
      }
    }
    return out;
  }

  static List<StudioLineRange> _ranges(List<int> lines) {
    final out = <StudioLineRange>[];
    for (final line in lines) {
      if (out.isNotEmpty && out.last.end == line - 1) {
        out[out.length - 1] = StudioLineRange(out.last.start, line);
      } else {
        out.add(StudioLineRange(line));
      }
    }
    return out;
  }
}
