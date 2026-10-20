/// `:::bench bench-position`: `AnimatedAlign` and `AnimatedPositioned`. The
/// box goes to the spot you tap (or pick in the panel): one animates the
/// alignment and the other the offsets and the size, both with the same
/// transition of the browser.
///
/// Every value is finite, so the stage is a `Watch.field` per control whose
/// variants the server compiled.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';
import 'motion_curve.dart';

/// Where the box is.
enum Spot {
  /// Top left corner.
  topLeft,

  /// The middle (a bigger box in `AnimatedPositioned`).
  center,

  /// Bottom right corner.
  bottomRight,
}

/// Which widget moves the box.
enum PositionKind {
  /// `AnimatedAlign`.
  align,

  /// `AnimatedPositioned`.
  positioned,
}

// The field is 280 × 168, the box 44 and its margin 12; the middle spot of
// `AnimatedPositioned` is a box of 84.
const _fieldW = 280.0;
const _fieldH = 168.0;
const _box = 44.0;
const _margin = 12.0;
const _big = 84.0;

/// What the panel controls and the stage reads.
class PositionViewModel extends ThorState {
  /// Where the box is.
  final spot = state(Spot.topLeft);

  /// The widget that moves it.
  final kind = state(PositionKind.align);

  /// The duration, as a step of 100 ms.
  final step = state(1);

  /// The number next to the duration Level's bar.
  String durationText() => '${coarseDuration(step.value).inMilliseconds} ms';

  /// The `duration` line of the Code view.
  String durationCode() =>
      'duration: Duration(milliseconds: ${coarseDuration(step.value).inMilliseconds}),';

  /// The widget's name in the Code view.
  String widgetCode() => kind.value == PositionKind.align
      ? 'AnimatedAlign('
      : 'AnimatedPositioned(';

  /// The line that says where the box goes.
  String placeCode() {
    final s = spot.value;
    if (kind.value == PositionKind.align) {
      return 'alignment: Alignment.${s.name},';
    }
    final (left, top, size) = _frame(s);
    return 'left: ${left.round()}, top: ${top.round()}, '
        'width: ${size.round()}, height: ${size.round()},';
  }

  /// What the spot Switch and the tap targets call.
  void setSpot(Spot? value) => spot.value = value ?? Spot.topLeft;

  /// What a tap target calls: the spot's index.
  void goTo(int index) => spot.value = Spot.values[index];

  /// What the kind Switch calls.
  void setKind(PositionKind? value) => kind.value = value ?? PositionKind.align;

  /// What the duration Level calls.
  void setDuration(double ms) => step.value = coarseStepOf(ms);
}

(double, double, double) _frame(Spot s) => switch (s) {
  Spot.topLeft => (_margin, _margin, _box),
  Spot.bottomRight => (
    _fieldW - _margin - _box,
    _fieldH - _margin - _box,
    _box,
  ),
  Spot.center => ((_fieldW - _big) / 2, (_fieldH - _big) / 2, _big),
};

/// One instance, at the top level: the browser boots with it.
final positionState = PositionViewModel();

/// The example: three Switches, a Level, the stage and its code.
final positionBench = BenchExample(
  title: (t) => t.exMotion2PositionTitle,
  description: (t) => t.exMotion2PositionDescription,
  stage: const PositionStage(),
  code: BenchCode([
    BenchCodeLine.live(positionState.widgetCode),
    BenchCodeLine.live(positionState.durationCode, indent: 1),
    const BenchCodeLine('curve: Curves.easeOut,', indent: 1),
    BenchCodeLine.live(positionState.placeCode, indent: 1),
    const BenchCodeLine('child: box,', indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchDropdown<PositionKind>(
      label: (t) => t.exMotion2Widget,
      value: positionState.kind.value,
      onChanged: positionState.setKind,
      code: true,
      items: [
        BenchSegment(PositionKind.align, label: (t) => 'AnimatedAlign'),
        BenchSegment(
          PositionKind.positioned,
          label: (t) => 'AnimatedPositioned',
        ),
      ],
    ),
    BenchDropdown<Spot>(
      label: (t) => t.exMotion2Spot,
      value: positionState.spot.value,
      onChanged: positionState.setSpot,
      code: true,
      items: [
        for (final spot in Spot.values)
          BenchSegment(spot, label: (_) => spot.name),
      ],
    ),
    BenchLevel(
      label: (t) => t.exMotionDuration,
      value: coarseMs(positionState.step.value),
      min: coarseMinMs.toDouble(),
      max: coarseMaxMs.toDouble(),
      divisions: coarseSteps - 1,
      onChanged: positionState.setDuration,
      valueText: positionState.durationText,
    ),
  ],
);

/// The stage: a field with a ghost per spot, and the box that goes to the one
/// that is chosen.
class PositionStage extends StatelessWidget {
  /// The stage of the example.
  const PositionStage({super.key});

  @override
  Widget build(BuildContext context) => Watch.field(
    positionState.step,
    count: coarseSteps,
    builder: (step) => Watch.field(
      positionState.kind,
      builder: (kind) => Watch.field(
        positionState.spot,
        builder: (spot) =>
            _Field(duration: coarseDuration(step), kind: kind, spot: spot),
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.duration,
    required this.kind,
    required this.spot,
  });

  final Duration duration;
  final PositionKind kind;
  final Spot spot;

  @override
  Widget build(BuildContext context) {
    final (left, top, size) = _frame(spot);
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        Container(
          width: _fieldW,
          height: _fieldH,
          decoration: BoxDecoration(
            color: ThemeColor.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              if (kind == PositionKind.align)
                Padding(
                  padding: const EdgeInsets.all(_margin),
                  child: AnimatedAlign(
                    alignment: switch (spot) {
                      Spot.topLeft => Alignment.topLeft,
                      Spot.bottomRight => Alignment.bottomRight,
                      Spot.center => Alignment.center,
                    },
                    duration: duration,
                    curve: Curves.easeOut,
                    child: const _Box(size: _box),
                  ),
                )
              else
                AnimatedPositioned(
                  left: left,
                  top: top,
                  width: size,
                  height: size,
                  duration: duration,
                  curve: Curves.easeOut,
                  child: const _Box(),
                ),
              // A ghost per spot: where the box can go, and a tap target.
              for (final s in Spot.values)
                Positioned(
                  left: _ghostLeft(s),
                  top: _ghostTop(s),
                  child: Semantics(
                    label: switch (s) {
                      Spot.topLeft => 'Top left',
                      Spot.bottomRight => 'Bottom right',
                      Spot.center => 'Center',
                    },
                    child: Gesture(
                      onTap: positionState.goTo.withArg(s.index),
                      child: Container(
                        width: _box,
                        height: _box,
                        alignment: Alignment.center,
                        child: s == spot
                            ? null
                            : Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: ThemeColor.outline,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Text(
          kind == PositionKind.align ? 'AnimatedAlign' : 'AnimatedPositioned',
          style: const TextStyle(
            fontSize: 12,
            fontFamily: 'IBM Plex Mono',
            fontFamilyFallback: ['ui-monospace', 'monospace'],
            color: ThemeColor.onSurfaceVariant,
          ),
        ),
        const Text(
          'Tap a spot to move the box.',
          style: TextStyle(fontSize: 14, color: ThemeColor.onSurfaceVariant),
        ),
      ],
    );
  }
}

// The ghost of a spot is a 44 px target centered where the box's center is
// (the middle one, where the bigger box is centered).
double _ghostLeft(Spot s) {
  final (left, _, size) = _frame(s);
  return left + size / 2 - _box / 2;
}

double _ghostTop(Spot s) {
  final (_, top, size) = _frame(s);
  return top + size / 2 - _box / 2;
}

class _Box extends StatelessWidget {
  const _Box({this.size});

  final double? size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: ThemeColor.primary,
      borderRadius: BorderRadius.circular(12),
    ),
  );
}
