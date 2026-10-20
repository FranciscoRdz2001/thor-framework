/// Flutter's `IconData`, in two flavors:
///
/// - **Font glyph** (`IconData(0xe151, fontFamily: 'Lucide')`): same model as
///   Flutter, so icon packs port by copying codepoints. The whole font is
///   downloaded (hundreds of KB for a big pack), so prefer SVG on the web.
/// - **SVG** (`IconData.svg('lucide-search', '<path d="…"/>')`): only the
///   icons a page uses are shipped, deduplicated into one sprite by `ThorApp`.
///   The SVG markup is trusted developer content (like `RawText`).
class IconData {
  /// Creates a font-glyph icon from a font's [codePoint] and [fontFamily].
  const IconData(
    int this.codePoint, {
    required String this.fontFamily,
    this.matchTextDirection = false,
  }) : svgId = null,
       svgBody = null,
       viewBox = '0 0 24 24',
       strokeWidth = null;

  /// Creates an SVG icon with a unique sprite [svgId] and inline
  /// [svgBody] markup.
  const IconData.svg(
    String this.svgId,
    String this.svgBody, {
    this.viewBox = '0 0 24 24',
    this.strokeWidth,
    this.codePoint,
    this.fontFamily,
    this.matchTextDirection = false,
  });

  /// Font glyph codepoint (font icons only).
  final int? codePoint;

  /// Font family the codepoint is drawn from (font icons only).
  final String? fontFamily;

  /// Sprite symbol id (must be unique per icon, e.g. `lucide-search`).
  final String? svgId;

  /// Inner SVG markup (`<path …/>`, `<circle …/>`).
  final String? svgBody;

  /// SVG `viewBox` attribute value.
  final String viewBox;

  /// For stroke-based packs (Lucide, Feather…): draws with `currentColor`
  /// strokes instead of fills.
  final double? strokeWidth;

  /// Flutter's `IconData.matchTextDirection`: the icon flips horizontally in
  /// right-to-left text (`Icons.arrow_back`, `Icons.send`).
  // web: an `:dir(rtl)` rule of the icon's class flips it (the browser knows
  // the direction, no widget reads a `Directionality`).
  final bool matchTextDirection;

  /// Whether this icon is drawn from SVG markup rather than a font glyph.
  bool get isSvg => svgBody != null;

  /// The glyph as a string (font icons only).
  String get character => String.fromCharCode(codePoint!);

  @override
  bool operator ==(Object other) =>
      other is IconData &&
      other.codePoint == codePoint &&
      other.fontFamily == fontFamily &&
      other.svgId == svgId;

  @override
  int get hashCode => Object.hash(codePoint, fontFamily, svgId);
}
