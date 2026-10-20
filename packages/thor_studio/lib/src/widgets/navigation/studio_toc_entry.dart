/// A heading of the page in a `StudioTableOfContents`.
///
/// ```dart
/// const StudioTocEntry('Installing', href: '#installing')
/// const StudioTocEntry('With pub', href: '#pub', depth: 1)
/// ```
class StudioTocEntry {
  /// An entry labelled [label] that jumps to [href] (`#anchor`), nested
  /// [depth] levels (0 for an `h2`, 1 for an `h3`).
  const StudioTocEntry(this.label, {required this.href, this.depth = 0});

  /// The heading's text.
  final String label;

  /// The heading's anchor (`#installing`).
  final String href;

  /// 0 for a section, 1 for a subsection.
  final int depth;
}
