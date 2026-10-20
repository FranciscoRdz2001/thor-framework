/// `:::bench bench-animated-list`: an `AnimatedList`. A Level sets how long a
/// row takes to enter and leave; the buttons on the stage add and remove rows
/// through the state.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';
import 'motion_curve.dart';

/// A row of the list.
class Task {
  /// A task.
  const Task(this.id, this.title);

  /// Its key.
  final int id;

  /// Its text.
  final String title;
}

/// What the panel controls and the stage reads.
class TaskListViewModel extends ThorState {
  /// The rows.
  final items = state<List<Task>>(const [
    Task(1, 'Grind the coffee'),
    Task(2, 'Warm the milk'),
  ]);

  /// The duration of a row's entrance, as a step of 100 ms.
  final step = state(2);

  /// The next row's key.
  var next = 3;

  /// A row's key.
  int idOf(Task t) => t.id;

  /// A row's text.
  String titleOf(Task t) => t.title;

  /// The number next to the duration Level's bar.
  String durationText() => '${motionDuration(step.value).inMilliseconds} ms';

  /// The `duration` line of the Code view.
  String durationCode() =>
      'duration: Duration(milliseconds: ${motionDuration(step.value).inMilliseconds}),';

  /// What the add button calls.
  void add() {
    final id = next;
    next = id + 1;
    items.value = [Task(id, 'Step $id'), ...items.value];
  }

  /// The rows the list draws.
  List<Task> rows() => items.value;

  /// What a row's remove button calls.
  void remove(int id) => items.value = [
    for (final t in items.value)
      if (t.id != id) t,
  ];

  /// What the duration Level calls.
  void setDuration(double ms) => step.value = motionStepOf(ms);
}

/// One instance, at the top level: the browser boots with it.
final taskList = TaskListViewModel();

/// The example: a Level, the stage and its code.
final animatedListBench = BenchExample(
  title: (t) => t.exMotionListTitle,
  description: (t) => t.exMotionListDescription,
  stage: const AnimatedListStage(),
  code: BenchCode([
    const BenchCodeLine('AnimatedList<Task, int>('),
    const BenchCodeLine('tasks.rows,', indent: 1),
    const BenchCodeLine('itemKey: tasks.idOf,', indent: 1),
    BenchCodeLine.live(taskList.durationCode, indent: 1),
    const BenchCodeLine(
      'itemBuilder: (context, row, animation) => SizeTransition(',
      indent: 1,
    ),
    const BenchCodeLine('sizeFactor: animation,', indent: 2),
    const BenchCodeLine('child: FadeTransition(', indent: 2),
    const BenchCodeLine('opacity: animation,', indent: 3),
    const BenchCodeLine('child: TaskTile(row),', indent: 3),
    const BenchCodeLine('),', indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchLevel(
      label: (t) => t.exMotionDuration,
      value: motionMs(taskList.step.value),
      min: motionMinMs.toDouble(),
      max: (motionMinMs + (motionSteps - 1) * motionStepMs).toDouble(),
      divisions: motionSteps - 1,
      onChanged: taskList.setDuration,
      valueText: taskList.durationText,
    ),
  ],
);

/// The stage: the add button and the list.
class AnimatedListStage extends StatelessWidget {
  /// The stage of the example.
  const AnimatedListStage({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          OutlinedButton(onPressed: taskList.add, child: const Text('Add')),
          Watch.field(
            taskList.step,
            count: motionSteps,
            builder: (step) => AnimatedList<Task, int>(
              taskList.rows,
              itemKey: taskList.idOf,
              duration: motionDuration(step),
              itemBuilder: (context, row, animation) => SizeTransition(
                sizeFactor: animation,
                child: FadeTransition(
                  opacity: animation,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      width: 300,
                      padding: const EdgeInsets.only(left: 14),
                      decoration: BoxDecoration(
                        color: ThemeColor.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: row.text(taskList.titleOf)),
                          TextButton(
                            onPressed: taskList.remove.withArg(row.key),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
