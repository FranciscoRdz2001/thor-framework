/// `:::bench bench-text-style`: a `TextStyle` you change. A Level sets the
/// size and another the weight; the heading and its paragraph follow.
///
/// The size is continuous, so it reaches the stage as a `BoundLength`
/// (`textStyleState.size.px`) that the style reads with `fontSizeLength`; the weight
/// has four values, so each is a variant the server compiled.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';

/// The weights the Level offers, from `w400` to `w700`.
const _weights = 4;

/// What the panel controls and the stage reads.
class TextStyleViewModel extends ThorState {
  /// The heading's size, in px.
  final size = state(28.0);

  /// The weight, as a step: 0 is `w400`, 3 is `w700`.
  final weight = state(2);

  /// The number next to the size Level's bar.
  String sizeText() => '${size.value.round()} px';

  /// The number next to the weight Level's bar.
  String weightText() => 'w${400 + weight.value * 100}';

  /// The `fontSize` line of the Code view.
  String sizeCode() => 'fontSize: ${size.value.round()},';

  /// The `fontWeight` line of the Code view.
  String weightCode() => 'fontWeight: FontWeight.w${400 + weight.value * 100},';

  /// What the size Level calls.
  void setSize(double value) => size.value = value;

  /// What the weight Level calls.
  void setWeight(double value) => weight.value = value.round();
}

/// One instance, at the top level: the browser boots with it.
final textStyleState = TextStyleViewModel();

/// The example: two Levels, the stage and its code.
final textStyleBench = BenchExample(
  title: (t) => t.exThemeTextTitle,
  description: (t) => t.exThemeTextDescription,
  stage: const TextStyleStage(),
  code: BenchCode([
    const BenchCodeLine('Text('),
    const BenchCodeLine("'Cold brew',", indent: 1),
    const BenchCodeLine('style: TextStyle(', indent: 1),
    BenchCodeLine.live(textStyleState.sizeCode, indent: 2),
    BenchCodeLine.live(textStyleState.weightCode, indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    BenchLevel(
      label: (t) => t.exThemeTextSize,
      value: textStyleState.size.value,
      min: 12,
      max: 56,
      divisions: 44,
      onChanged: textStyleState.setSize,
      valueText: textStyleState.sizeText,
    ),
    BenchLevel(
      label: (t) => t.exThemeTextWeight,
      value: textStyleState.weight.value,
      max: (_weights - 1).toDouble(),
      divisions: _weights - 1,
      onChanged: textStyleState.setWeight,
      valueText: textStyleState.weightText,
    ),
  ],
);

/// The stage: a heading and a paragraph.
class TextStyleStage extends StatelessWidget {
  /// The stage of the example.
  const TextStyleStage({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Watch.field(
        textStyleState.weight,
        count: _weights,
        builder: (step) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text(
              'Spiced coffee',
              style: TextStyle(
                fontSize: 28,
                // web: the size follows the Level in the browser
                // (`BoundLength`); the number above is the one Dart reads.
                fontSizeLength: textStyleState.size.px,
                fontWeight: switch (step) {
                  0 => FontWeight.w400,
                  1 => FontWeight.w500,
                  2 => FontWeight.w600,
                  _ => FontWeight.w700,
                },
                height: 1.1,
                letterSpacingLength: const Length.em(-0.02),
                color: ThemeColor.onSurface,
              ),
            ),
            const Text(
              'Cinnamon, cane sugar and a clay pot at a slow simmer.',
              style: TextStyle(color: ThemeColor.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
