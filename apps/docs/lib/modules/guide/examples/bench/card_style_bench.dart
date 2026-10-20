/// `:::bench bench-card-style`: the style reference example. A Switch picks
/// the card's fill, two Levels its radius and its padding.
///
/// A continuous value (the radius, the padding) reaches the stage as a
/// `BoundLength` (`cardStyle.radius.px`) that `EdgeInsetsGeometry.allLength`
/// and `BorderRadius.circularLength` read, so dragging a bar changes no class;
/// the fill, which has two values, is `Watch.field` variants the server
/// compiled.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';

/// How the card is filled.
enum CardFill {
  /// The theme's surface.
  soft,

  /// The theme's primary color.
  solid,
}

/// What the panel controls and the stage reads.
class CardStyleViewModel extends ThorState {
  /// The card's corner radius, in px.
  final radius = state(20.0);

  /// The card's inner space, in px.
  final padding = state(24.0);

  /// The card's fill.
  final fill = state(CardFill.soft);

  /// The number next to the radius Level's bar.
  String radiusText() => '${radius.value.round()} px';

  /// The number next to the padding Level's bar.
  String paddingText() => '${padding.value.round()} px';

  /// The `borderRadius` line of the Code view.
  String radiusCode() =>
      'borderRadius: BorderRadius.circular(${radius.value.round()}),';

  /// The `padding` line of the Code view.
  String paddingCode() => 'padding: EdgeInsets.all(${padding.value.round()}),';

  /// The `color` line of the Code view.
  String fillCode() => fill.value == CardFill.solid
      ? 'color: ThemeColor.primary,'
      : 'color: ThemeColor.surfaceContainer,';

  /// What the radius Level calls.
  void setRadius(double value) => radius.value = value;

  /// What the padding Level calls.
  void setPadding(double value) => padding.value = value;

  /// What the fill Switch calls.
  void setFill(Set<CardFill> value) => fill.value = value.first;
}

/// One instance, at the top level: the browser boots with it.
final cardStyle = CardStyleViewModel();

/// The example: a Switch, two Levels, the stage and its code.
final cardStyleBench = BenchExample(
  title: (t) => t.benchCardTitle,
  description: (t) => t.benchCardDescription,
  stage: const CardStyleStage(),
  code: BenchCode([
    const BenchCodeLine('Container('),
    BenchCodeLine.live(cardStyle.paddingCode, indent: 1),
    const BenchCodeLine('decoration: BoxDecoration(', indent: 1),
    BenchCodeLine.live(cardStyle.fillCode, indent: 2),
    BenchCodeLine.live(cardStyle.radiusCode, indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine('child: content,', indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchSwitch<CardFill>(
      label: (t) => t.benchCardFill,
      value: cardStyle.fill.value,
      onChanged: cardStyle.setFill,
      segments: [
        BenchSegment(CardFill.soft, label: (t) => t.benchCardFillSoft),
        BenchSegment(CardFill.solid, label: (t) => t.benchCardFillSolid),
      ],
    ),
    BenchLevel(
      label: (t) => t.benchCardRadius,
      value: cardStyle.radius.value,
      max: 48,
      divisions: 24,
      onChanged: cardStyle.setRadius,
      valueText: cardStyle.radiusText,
    ),
    BenchLevel(
      label: (t) => t.benchCardPadding,
      value: cardStyle.padding.value,
      min: 8,
      max: 48,
      divisions: 20,
      onChanged: cardStyle.setPadding,
      valueText: cardStyle.paddingText,
    ),
  ],
);

/// The stage: the card, with the two variables the state keeps current.
class CardStyleStage extends StatelessWidget {
  /// The stage of the example.
  const CardStyleStage({super.key});

  @override
  Widget build(BuildContext context) => Watch.field(
    cardStyle.fill,
    builder: (fill) => _Card(solid: fill == CardFill.solid),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.solid});

  final bool solid;

  @override
  Widget build(BuildContext context) {
    final ink = solid ? ThemeColor.onPrimary : ThemeColor.onSurface;
    return Container(
      width: 320,
      // web: the radius and the padding follow the state in the browser
      // (`BoundLength`), so they take a `Length`.
      padding: EdgeInsetsGeometry.allLength(cardStyle.padding.px),
      decoration: BoxDecoration(
        color: solid ? ThemeColor.primary : ThemeColor.surfaceContainer,
        // The hairline keeps the corners readable on a quiet fill.
        border: Border.all(color: ThemeColor.outline),
        borderRadius: BorderRadius.circularLength(cardStyle.radius.px),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            'NEW',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: ink,
            ),
          ),
          Text(
            'Weekly summary',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
          Text(
            'What changed in your app this week.',
            style: TextStyle(fontSize: 14, color: ink),
          ),
        ],
      ),
    );
  }
}
