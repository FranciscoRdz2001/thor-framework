/// A typed CSS custom property: its name and the type of value it holds.
library;

/// A CSS custom property (`--gutter`) that holds a [T] (`Length`, `Color`).
///
/// ```dart
/// const gutter = CssVariable<Length>('--gutter');
///
/// Length.variable(gutter, fallback: 16.px)   // var(--gutter, 16px)
/// WatchVariables({gutter: grid.gutter}, child: …)
/// ```
///
/// `// web:` no Flutter equivalent (Flutter has no style cascade). It is
/// the low-level layer: the name belongs to the app (a stylesheet or a
/// theme defines it). A value that follows a `ThorState` needs no name:
/// `BoundLength` (`card.radius.px`).
///
/// The name starts with `--` and holds letters, digits, `-` and `_`
/// ([isValidName]); `WatchVariables` refuses anything else so a name never
/// opens another declaration.
extension type const CssVariable<T>(String name) implements String {
  /// The reference to the variable: `var(--gutter)`.
  String get css => 'var($name)';

  /// Whether [name] is a custom property name (`--letters-digits`).
  static bool isValidName(String name) =>
      RegExp(r'^--[A-Za-z0-9_-]+$').hasMatch(name);
}
