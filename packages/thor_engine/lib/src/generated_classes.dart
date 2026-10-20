/// Finds and renames the generated classes (`.t…`) of a thor stylesheet.
///
/// Only selectors count: `url(…)`, quoted strings and `@layer` preludes are
/// skipped, so `url("/fonts/Inter.ttf")` and `@layer thor.tokens` keep
/// their text.
library;

final _scan = RegExp(
  r'''url\([^)]*\)|"[^"]*"|'[^']*'|@layer[^;{]*|\.(t[0-9a-z]+)(?![\w-])''',
);

/// The generated class names that [css] uses in selectors.
Iterable<String> generatedClasses(String css) sync* {
  for (final m in _scan.allMatches(css)) {
    final c = m[1];
    if (c != null) yield c;
  }
}

/// [css] with every generated class selector renamed through [names].
String renameGeneratedClasses(String css, Map<String, String> names) =>
    css.replaceAllMapped(_scan, (m) {
      final c = m[1];
      return c == null ? m[0]! : '.${names[c] ?? c}';
    });
