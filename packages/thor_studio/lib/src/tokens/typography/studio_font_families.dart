/// Font stacks. `StudioTheme` self-hosts Inter (one variable file, every
/// weight) and IBM Plex Mono, both under the SIL Open Font License, with
/// `font-display: swap`.
abstract final class StudioFontFamilies {
  /// Interface and reading text.
  static const sans =
      'Inter, ui-sans-serif, system-ui, -apple-system, "Segoe UI", sans-serif';

  /// Code and technical data (paths, slugs, sizes).
  static const mono =
      '"IBM Plex Mono", ui-monospace, "SF Mono", Menlo, Consolas, monospace';
}
