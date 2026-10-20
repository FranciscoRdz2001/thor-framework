/// `:::bench bench-tap-position`: where a tap landed. A Switch picks
/// `onTapDown` or `onTapUp`, a Level the size of the dot; tap anywhere on the
/// canvas and the state receives the position inside the element. The dot
/// starts in the middle, so the Level shows before any tap.
///
/// The position and the size reach the stage as `BoundLength`s
/// (`taps.size.px`): the browser moves the dot without building a style.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';

/// The size of the canvas, in px.
const _maxWidth = 440.0;
const _height = 220.0;

/// Where the dot rests until the first tap, from the canvas's corner.
const _startX = 150.0;
const _startY = 110.0;

/// Which callback of `Gesture` receives the tap.
enum TapEvent {
  /// `onTapDown`: when the pointer goes down.
  down,

  /// `onTapUp`: when a tap ends as a tap.
  up,
}

/// What the panel controls and the stage reads.
class TapPositionViewModel extends ThorState {
  /// Which callback the canvas uses.
  final event = state(TapEvent.up);

  /// Where the last tap landed, from the element's left, in px.
  final x = state(_startX);

  /// Where the last tap landed, from the element's top, in px.
  final y = state(_startY);

  /// The dot's size, in px.
  final size = state(24.0);

  /// The dot's left edge, in px, which the stage follows.
  double leftPx() => x.value - size.value / 2;

  /// The dot's top edge, in px, which the stage follows.
  double topPx() => y.value - size.value / 2;

  /// The number next to the size Level's bar.
  String sizeText() => '${size.value.round()} px';

  /// What the canvas shows under the tap: the callback and the position.
  String readout() =>
      '${event.value == TapEvent.down ? 'onTapDown' : 'onTapUp'}  '
      'x: ${x.value.round()}  y: ${y.value.round()}';

  /// The line of the Code view that sizes the dot.
  String dotCode() => 'child: Dot(size: ${size.value.round()}),';

  /// The line of the Code view that names the callback.
  String eventCode() => event.value == TapEvent.down
      ? 'onTapDown: taps.at, // void at(double x, double y)'
      : 'onTapUp: taps.at, // void at(double x, double y)';

  /// What both callbacks call.
  void at(double dx, double dy) => batch(() {
    x.value = dx;
    y.value = dy;
  });

  /// What the event Switch calls.
  void setEvent(Set<TapEvent> value) => event.value = value.first;

  /// What the size Level calls.
  void setSize(double value) => size.value = value;
}

/// One instance, at the top level: the browser boots with it.
final taps = TapPositionViewModel();

/// The example: a Switch, a Level, the stage and its code.
final tapPositionBench = BenchExample(
  title: (t) => t.exGestureTapTitle,
  description: (t) => t.exGestureTapDescription,
  stage: const TapPositionStage(),
  code: BenchCode([
    const BenchCodeLine('Gesture('),
    BenchCodeLine.live(taps.eventCode, indent: 1),
    const BenchCodeLine('child: Stack(', indent: 1),
    const BenchCodeLine('children: [', indent: 2),
    const BenchCodeLine('Positioned(', indent: 3),
    const BenchCodeLine('left: taps.x.value - size / 2,', indent: 4),
    const BenchCodeLine('top: taps.y.value - size / 2,', indent: 4),
    BenchCodeLine.live(taps.dotCode, indent: 4),
    const BenchCodeLine('),', indent: 3),
    const BenchCodeLine('],', indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchSwitch<TapEvent>(
      label: (t) => t.exGestureTapEvent,
      value: taps.event.value,
      onChanged: taps.setEvent,
      code: true,
      segments: [
        BenchSegment(TapEvent.down, label: (t) => t.exGestureTapDown),
        BenchSegment(TapEvent.up, label: (t) => t.exGestureTapUp),
      ],
    ),
    BenchLevel(
      label: (t) => t.exGestureTapSize,
      value: taps.size.value,
      min: 8,
      max: 64,
      divisions: 14,
      onChanged: taps.setSize,
      valueText: taps.sizeText,
    ),
  ],
);

/// The stage: the canvas, the dot and the position it reports.
class TapPositionStage extends StatelessWidget {
  /// The stage of the example.
  const TapPositionStage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        Watch.field(
          taps.event,
          builder: (event) => Gesture(
            onTapDown: event == TapEvent.down ? taps.at : null,
            onTapUp: event == TapEvent.up ? taps.at : null,
            child: const Semantics(
              label: 'Canvas: tap to place a dot',
              child: _Canvas(),
            ),
          ),
        ),
        Watch(
          taps.readout,
          style: const TextStyle(
            fontFamily: 'IBM Plex Mono',
            fontFamilyFallback: ['ui-monospace', 'monospace'],
            fontSize: 13,
            color: ThemeColor.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Canvas extends StatelessWidget {
  const _Canvas();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(maxWidth: _maxWidth),
    height: _height,
    decoration: BoxDecoration(
      color: ThemeColor.surfaceContainer,
      border: Border.all(color: ThemeColor.outlineVariant),
      borderRadius: BorderRadius.circular(16),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        Positioned(
          leftLength: taps.leftPx.px,
          topLength: taps.topPx.px,
          widthLength: taps.size.px,
          heightLength: taps.size.px,
          child: const Styled(
            style: StyleProps(ignorePointer: true),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ThemeColor.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
