import 'package:thor_ui/thor_ui.dart';

/// Three precompiled states (colors, sizes, alignments) plus an `onEnd`
/// counter: the browser only swaps classes and the transitions run.
class CyclerState extends ThorState {
  final step = state(0);
  final ends = state(0);

  int current() => step.value % 3;
  String cycleLabel() => 'Cycle (${step.value})';
  String endsLabel() => 'onEnd: ${ends.value}';

  void cycle() => step.value++;
  void animationEnded() => ends.value++;
}

final cycler = CyclerState();
