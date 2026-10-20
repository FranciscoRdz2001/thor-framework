/// `:::bench bench-drag`: `Gesture` with `onDragEnd`. A Switch picks the axis
/// the puck follows, another whether it springs back; the state receives how
/// far it was dragged when it is dropped.
///
/// While the pointer is down the browser moves the element in the compositor;
/// the state only hears about the result.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';

/// The axis the puck follows.
enum DragAxis {
  /// Any direction.
  free,

  /// `Axis.horizontal`.
  horizontal,

  /// `Axis.vertical`.
  vertical,
}

/// Whether the puck returns to its place.
enum DragRest {
  /// `snapBack: true`.
  snap,

  /// `snapBack: false`.
  stay,
}

/// What the panel controls and the stage reads.
class DragViewModel extends ThorState {
  /// The axis.
  final axis = state(DragAxis.free);

  /// Whether it springs back.
  final rest = state(DragRest.snap);

  /// How far it went on the last drop.
  final last = state('dx: 0  dy: 0');

  /// The last drop, as text.
  String lastText() => last.value;

  /// The `drag` line of the Code view.
  String dragCode() {
    final parts = [
      if (axis.value == DragAxis.horizontal) 'axis: Axis.horizontal',
      if (axis.value == DragAxis.vertical) 'axis: Axis.vertical',
      if (rest.value == DragRest.stay) 'snapBack: false',
    ];
    return 'drag: Drag(${parts.join(', ')}),';
  }

  /// What `onDragEnd` calls.
  void moved(double dx, double dy) =>
      last.value = 'dx: ${dx.round()}  dy: ${dy.round()}';

  /// What the axis Switch calls.
  void setAxis(DragAxis? value) => axis.value = value ?? DragAxis.free;

  /// What the rest Switch calls.
  void setRest(Set<DragRest> value) => rest.value = value.first;
}

/// One instance, at the top level: the browser boots with it.
final dragState = DragViewModel();

/// The example: two Switches, the stage and its code.
final dragBench = BenchExample(
  title: (t) => t.exGestureDragTitle,
  description: (t) => t.exGestureDragDescription,
  stage: const DragStage(),
  code: BenchCode([
    const BenchCodeLine('Gesture('),
    const BenchCodeLine(
      'onDragEnd: drag.moved, // void moved(double dx, double dy)',
      indent: 1,
    ),
    BenchCodeLine.live(dragState.dragCode, indent: 1),
    const BenchCodeLine('child: puck,', indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchDropdown<DragAxis>(
      label: (t) => t.exGestureDragAxis,
      value: dragState.axis.value,
      onChanged: dragState.setAxis,
      items: [
        BenchSegment(DragAxis.free, label: (t) => t.exGestureDragFree),
        BenchSegment(
          DragAxis.horizontal,
          label: (t) => t.exGestureDragHorizontal,
        ),
        BenchSegment(DragAxis.vertical, label: (t) => t.exGestureDragVertical),
      ],
    ),
    BenchSwitch<DragRest>(
      label: (t) => t.exGestureDragRest,
      value: dragState.rest.value,
      onChanged: dragState.setRest,
      segments: [
        BenchSegment(DragRest.snap, label: (t) => t.exGestureDragSnap),
        BenchSegment(DragRest.stay, label: (t) => t.exGestureDragStay),
      ],
    ),
  ],
);

/// A line the puck can slide along.
class _Rail extends StatelessWidget {
  const _Rail({required this.horizontal});

  final bool horizontal;

  @override
  Widget build(BuildContext context) => Container(
    width: horizontal ? double.infinity : 2,
    height: horizontal ? 2 : 200,
    color: ThemeColor.outlineVariant,
  );
}

/// The stage: the puck in its lane, and what the last drop reported.
class DragStage extends StatelessWidget {
  /// The stage of the example.
  const DragStage({super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 12,
    children: [
      Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 440),
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ThemeColor.surfaceContainer,
          border: Border.all(
            color: ThemeColor.outlineVariant,
            style: BorderStyle.dashed,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The rails the puck can follow, and the place it starts from.
            Watch.field(
              dragState.axis,
              builder: (axis) => Stack(
                alignment: Alignment.center,
                children: [
                  if (axis != DragAxis.vertical) const _Rail(horizontal: true),
                  if (axis != DragAxis.horizontal)
                    const _Rail(horizontal: false),
                ],
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                border: Border.all(color: ThemeColor.outline),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            Watch.field(
              dragState.axis,
              builder: (axis) => Watch.field(
                dragState.rest,
                builder: (rest) => Gesture(
                  onDragEnd: dragState.moved,
                  drag: Drag(
                    axis: switch (axis) {
                      DragAxis.free => null,
                      DragAxis.horizontal => Axis.horizontal,
                      DragAxis.vertical => Axis.vertical,
                    },
                    snapBack: rest == DragRest.snap,
                  ),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: ThemeColor.primary,
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      Watch.field(
        dragState.rest,
        builder: (rest) => Text(
          rest == DragRest.snap
              ? 'On release, it returns to the circle where it started'
              : 'On release, it stays where you leave it',
          style: const TextStyle(
            fontSize: 14,
            color: ThemeColor.onSurfaceVariant,
          ),
        ),
      ),
      Watch(
        dragState.lastText,
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
