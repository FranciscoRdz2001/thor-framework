/// `:::bench bench-stack`: a `Stack` whose size comes from its first child;
/// a Switch picks the corner a `Positioned` badge sticks to, a Level how far
/// from the edges.
library;

import 'package:thor_ui/thor_ui.dart';

import '../bench/bench_example.dart';
import 'learn_parts.dart';

const _stepPx = 4;
const _steps = 7;

/// The corners of the Switch.
enum StackCorner {
  /// `top`, `left`.
  topLeft,

  /// `top`, `right`.
  topRight,

  /// `bottom`, `left`.
  bottomLeft,

  /// `bottom`, `right`.
  bottomRight,
}

/// What the panel controls and the stage reads.
class StackViewModel extends ThorState {
  /// The badge's corner.
  final corner = state(StackCorner.topRight);

  /// The distance from the edges, in steps of 4 px.
  final inset = state(2);

  /// The edges line of the Code view.
  String edgesCode() {
    final px = inset.value * _stepPx;
    return switch (corner.value) {
      StackCorner.topLeft => 'top: $px, left: $px,',
      StackCorner.topRight => 'top: $px, right: $px,',
      StackCorner.bottomLeft => 'bottom: $px, left: $px,',
      StackCorner.bottomRight => 'bottom: $px, right: $px,',
    };
  }

  /// The number next to the Level.
  String insetText() => '${inset.value * _stepPx} px';

  /// What the Switch calls.
  void setCorner(Set<StackCorner> value) => corner.value = value.first;

  /// What the Level calls.
  void setInset(double value) => inset.value = (value / _stepPx).round();
}

/// One instance, at the top level: the browser boots with it.
final stackDemo = StackViewModel();

/// The example.
final stackBench = BenchExample(
  title: (t) => t.exLayoutStackTitle,
  description: (t) => t.exLayoutStackDescription,
  stage: const StackStage(),
  code: BenchCode([
    const BenchCodeLine('Stack('),
    const BenchCodeLine('children: [', indent: 1),
    const BenchCodeLine(
      'Container(height: 160), // sizes the Stack',
      indent: 2,
    ),
    const BenchCodeLine('Positioned(', indent: 2),
    BenchCodeLine.live(stackDemo.edgesCode, indent: 3),
    const BenchCodeLine('child: Badge(),', indent: 3),
    const BenchCodeLine('),', indent: 2),
    const BenchCodeLine('],', indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchSwitch<StackCorner>(
      label: (t) => t.exLayoutStackCorner,
      value: stackDemo.corner.value,
      onChanged: stackDemo.setCorner,
      segments: [
        BenchSegment(StackCorner.topLeft, label: (t) => t.exLayoutStackTopLeft),
        BenchSegment(
          StackCorner.topRight,
          label: (t) => t.exLayoutStackTopRight,
        ),
        BenchSegment(
          StackCorner.bottomLeft,
          label: (t) => t.exLayoutStackBottomLeft,
        ),
        BenchSegment(
          StackCorner.bottomRight,
          label: (t) => t.exLayoutStackBottomRight,
        ),
      ],
    ),
    BenchLevel(
      label: (t) => t.exLayoutStackInset,
      value: stackDemo.inset.value * _stepPx,
      max: (_steps - 1) * _stepPx.toDouble(),
      divisions: _steps - 1,
      onChanged: stackDemo.setInset,
      valueText: stackDemo.insetText,
    ),
  ],
);

/// The stage: a base that gives the `Stack` its size, and the badge.
class StackStage extends StatelessWidget {
  /// The stage of the example.
  const StackStage({super.key});

  @override
  Widget build(BuildContext context) => Watch.field(
    stackDemo.corner,
    builder: (corner) => Watch.field(
      stackDemo.inset,
      count: _steps,
      builder: (step) {
        final px = step * _stepPx.toDouble();
        const badge = LearnTile(label: 'New');
        return LearnFrame(
          width: 480,
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: ThemeColor.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              switch (corner) {
                StackCorner.topLeft => Positioned(
                  top: px,
                  left: px,
                  child: badge,
                ),
                StackCorner.topRight => Positioned(
                  top: px,
                  right: px,
                  child: badge,
                ),
                StackCorner.bottomLeft => Positioned(
                  bottom: px,
                  left: px,
                  child: badge,
                ),
                StackCorner.bottomRight => Positioned(
                  bottom: px,
                  right: px,
                  child: badge,
                ),
              },
            ],
          ),
        );
      },
    ),
  );
}
