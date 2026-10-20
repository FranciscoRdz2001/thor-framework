/// `:::bench bench-counter-step`: the state reference example. A Level sets
/// how much each press adds; the buttons call methods of the same
/// `ThorState`, and the Code view shows the state as it is now.
///
/// The number is `Watch(counter.countText)`: a text the state writes, kept
/// current by the browser. Everything the example changes in the page goes
/// through the state, never through a closure.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';

/// What the buttons, the Level and the stage share.
class StepCounterViewModel extends ThorState {
  /// The number on the stage.
  final count = state(0);

  /// How much each press adds or subtracts.
  final step = state(1);

  /// The number on the stage, as text.
  String countText() => '${count.value}';

  /// The number next to the step Level's bar.
  String stepText() => '${step.value}';

  /// What the "+" button says it adds.
  String addText() => '+${step.value}';

  /// What the "−" button says it takes away.
  String subtractText() => '−${step.value}';

  /// The `step` line of the Code view.
  String stepCode() => 'final step = state(${step.value});';

  /// What the "+" button calls.
  void add() => count.value += step.value;

  /// What the "−" button calls.
  void subtract() => count.value -= step.value;

  /// What the reset button calls.
  void reset() => count.value = 0;

  /// What the step Level calls.
  void setStep(double value) => step.value = value.round();
}

/// One instance, at the top level: the browser boots with it.
final stepCounter = StepCounterViewModel();

/// The example: a Level, the stage and its code.
final stepCounterBench = BenchExample(
  title: (t) => t.benchCounterTitle,
  description: (t) => t.benchCounterDescription,
  stage: const StepCounterStage(),
  code: BenchCode([
    const BenchCodeLine('class CounterViewModel extends ThorState {'),
    const BenchCodeLine('final count = state(0);', indent: 1),
    BenchCodeLine.live(stepCounter.stepCode, indent: 1),
    const BenchCodeLine(' '),
    const BenchCodeLine('void add() => count.value += step.value;', indent: 1),
    const BenchCodeLine(
      'void subtract() => count.value -= step.value;',
      indent: 1,
    ),
    const BenchCodeLine('void reset() => count.value = 0;', indent: 1),
    const BenchCodeLine('}'),
  ]),
  controls: [
    BenchLevel(
      label: (t) => t.benchCounterStep,
      value: stepCounter.step.value,
      min: 1,
      max: 10,
      divisions: 9,
      onChanged: stepCounter.setStep,
      valueText: stepCounter.stepText,
    ),
  ],
);

/// The stage: two buttons around the number, and a reset.
class StepCounterStage extends StatelessWidget {
  /// The stage of the example.
  const StepCounterStage({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 8,
    children: [
      OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(72, 56)),
        onPressed: stepCounter.subtract,
        child: Watch(stepCounter.subtractText),
      ),
      Watch(
        stepCounter.countText,
        style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w700),
      ),
      OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(72, 56)),
        onPressed: stepCounter.add,
        child: Watch(stepCounter.addText),
      ),
      TextButton(onPressed: stepCounter.reset, child: const Text('Reset')),
    ],
  );
}
