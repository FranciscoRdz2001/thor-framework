/// The language of a piece of code, for the highlighter and the header of a
/// `StudioCodeBlock`.
///
/// ```dart
/// StudioCodeBlock(source, language: StudioCodeLanguage.bash)
/// ```
///
/// `// web:` Flutter has no code widgets; the highlighter runs at render time,
/// so the language is data, not a plugin. The widgets' `language:` is this
/// enum. Code that gets a name at run time (a markdown fence) uses
/// [StudioCodeLanguage.fromName].
enum StudioCodeLanguage {
  /// Dart: keywords, strings, numbers, types and comments are colored.
  dart,

  /// Shell commands.
  bash,

  /// YAML (`pubspec.yaml`).
  yaml,

  /// JSON.
  json,

  /// HTML (shown as such in the header, not colored).
  html,

  /// CSS (shown as such in the header, not colored).
  css,

  /// No coloring.
  plain;

  /// The language called [name] (`sh` and `shell` are [bash], `yml` is
  /// [yaml]); a name that is not here, or null, is [plain].
  static StudioCodeLanguage fromName(String? name) => switch (name) {
    'sh' || 'shell' => bash,
    'yml' => yaml,
    _ => values.asNameMap()[name] ?? plain,
  };
}
