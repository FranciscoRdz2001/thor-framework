/// Corner radii, one rule for the whole system: cards are 28, what you
/// press is a pill, what sits inside a card is 12.
abstract final class StudioRadii {
  /// Cards, the bench stage and its panel.
  static const double card = 28;

  /// Buttons, chips, segmented controls and fields: a full pill.
  static const double control = 999;

  /// What sits inside a card: code blocks, callouts, level bars, rows.
  static const double inner = 12;

  /// Small details: keyboard keys, inline code.
  static const double small = 6;
}
