/// `:::bench bench-responsive`: a card that is a column when its box is
/// narrow and a row from 420 px, in one tree, with `.when(container:)`. A
/// Level sets the box's width, so you can cross the breakpoint by hand.
///
/// The width is continuous, so it reaches the stage as a CSS variable; the
/// switch from column to row is a container query the server wrote.
library;

import 'package:thor_ui/thor_ui.dart';

import '../bench/bench_example.dart';
import 'learn_parts.dart';

const _breakpoint = 420;

/// What the panel controls and the stage reads.
class ResponsiveViewModel extends ThorState {
  /// The box's width, in px.
  final width = state(300.0);

  /// The number next to the Level.
  String widthText() => '${width.value.round()} px';

  /// The comment of the Code view: what the box is at this width.
  String resultCode() =>
      '// ${width.value.round()} px wide: ${width.value >= _breakpoint ? 'a row' : 'a column'}';

  /// What the Level calls.
  void setWidth(double value) => width.value = value;
}

/// One instance, at the top level: the browser boots with it.
final responsiveDemo = ResponsiveViewModel();

/// The example.
final responsiveBench = BenchExample(
  title: (t) => t.exLayoutResponsiveTitle,
  description: (t) => t.exLayoutResponsiveDescription,
  stage: const ResponsiveStage(),
  code: BenchCode([
    const BenchCodeLine('LayoutScope('),
    const BenchCodeLine('child: Flex(', indent: 1),
    const BenchCodeLine('direction: Axis.vertical,', indent: 2),
    const BenchCodeLine('spacing: 12,', indent: 2),
    const BenchCodeLine('layout: FlexLayout().when(', indent: 2),
    const BenchCodeLine(
      'container: {$_breakpoint: FlexLayout(direction: Axis.horizontal)},',
      indent: 3,
    ),
    const BenchCodeLine('),', indent: 2),
    const BenchCodeLine('children: [Photo(), Details()],', indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine('),'),
    BenchCodeLine.live(responsiveDemo.resultCode),
  ], appCode: true),
  controls: [
    BenchLevel(
      label: (t) => t.exLayoutResponsiveWidth,
      value: responsiveDemo.width.value,
      min: 240,
      max: 560,
      divisions: 32,
      onChanged: responsiveDemo.setWidth,
      valueText: responsiveDemo.widthText,
    ),
  ],
);

/// The stage: the card, inside a box whose width is the Level's.
class ResponsiveStage extends StatelessWidget {
  /// The stage of the example.
  const ResponsiveStage({super.key});

  @override
  Widget build(BuildContext context) {
    return Styled(
      // web: the box's width follows the Level in the browser
      // (`BoundLength`).
      style: StyleProps(maxWidth: responsiveDemo.width.px),
      child: LearnFrame(
        width: double.infinity,
        child: LayoutScope(
          child: Flex(
            direction: Axis.vertical,
            spacing: 12,
            layout: const FlexLayout().when(
              container: {
                _breakpoint: const FlexLayout(direction: Axis.horizontal),
              },
            ),
            children: [
              const LearnTile(label: 'IMG', width: 96, height: 72),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    'Pottery workshop',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Saturdays from 10 am to 1 pm, eight seats.',
                    style: TextStyle(
                      fontSize: 14,
                      color: ThemeColor.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
