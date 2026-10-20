/// The font sizes, in logical pixels. A short scale: the page changes
/// between steps by size and weight, never by color alone.
abstract final class StudioTypeScale {
  /// Hero titles.
  static const double display = 48;

  /// A hero title one step down (a landing section).
  static const double displayMedium = 40;

  /// The smallest hero title.
  static const double displaySmall = 36;

  /// A page's title.
  static const double headline = 32;

  /// A section title.
  static const double title = 22;

  /// A small section title (between the title and the lead).
  static const double headlineSmall = 20;

  /// A card title and the lead paragraph.
  static const double subtitle = 17;

  /// Reading text.
  static const double body = 16;

  /// Interface text: buttons, navigation, panels.
  static const double ui = 14;

  /// Labels and metadata.
  static const double caption = 12;

  /// The smallest label (a key hint, a counter).
  static const double micro = 11;

  /// Code in a block.
  static const double code = 13;
}
