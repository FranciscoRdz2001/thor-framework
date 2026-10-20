/// The live examples of the "Arquitectura" pages: two benches that simulate
/// what a `command` does in the browser (the docs site is static, so no
/// server answers; a timer plays the server's part).
///
/// * `:::bench bench-command`: a command with `pending`, `error` and
///   `result`: press, wait, succeed or fail.
/// * `:::bench bench-optimistic`: the same button, optimistic or not.
///
/// Both follow the bench contract of `bench/bench_example.dart`: one
/// `ThorState` per example, controls that call its methods, a stage that
/// reads it with `Watch` and a Code view of live lines.
library;

import 'dart:async';

import 'package:thor_ui/thor_ui.dart';

import 'bench/bench_example.dart';

/// The latencies the Levels offer: from [_minLatency] to [_maxLatency]
/// seconds, in [_latencySteps] steps. A step is what the bar shows.
const _minLatency = 0.2;
const _maxLatency = 3.0;
const _latencySteps = 15;
const _barWidth = 200.0;

/// The step (0 to 14) of a latency in seconds.
int _stepOf(double seconds) =>
    ((seconds - _minLatency) /
            (_maxLatency - _minLatency) *
            (_latencySteps - 1))
        .round();

/// What a simulated command is doing.
enum CommandPhase {
  /// Nothing yet.
  idle,

  /// Called, waiting for the answer.
  running,

  /// The answer was ok.
  done,

  /// The answer was an error.
  failed,
}

/// The state behind `bench-command`.
class CancelCommandViewModel extends ThorState {
  /// What the command is doing.
  final phase = state(CommandPhase.idle);

  /// Whether the simulated server answers with an error.
  final fails = state(false);

  /// How long the simulated server takes, in seconds.
  final latency = state(1.0);

  /// Which of the Level's steps [latency] is: what the bar draws.
  final latencyStep = state(_stepOf(1.0));

  /// What the button calls. In an app `cancel.run` queues a second press
  /// behind the first; here the button is replaced by "Cancelling…" while
  /// the answer is on its way, so a second press can't happen (like the
  /// `Command` of Flutter's architecture guide, which ignores `execute`
  /// while it runs).
  Future<void> run() async {
    if (phase.value == CommandPhase.running) return;
    phase.value = CommandPhase.running;
    await Future<void>.delayed(
      Duration(milliseconds: (latency.value * 1000).round()),
    );
    phase.value = fails.value ? CommandPhase.failed : CommandPhase.done;
  }

  /// What "reset" calls.
  void reset() => phase.value = CommandPhase.idle;

  /// What the server Switch calls.
  void setFails(Set<bool> value) => fails.value = value.first;

  /// What the latency Level calls.
  void setLatency(double value) {
    latency.value = value;
    latencyStep.value = _stepOf(value);
  }

  /// The number next to the latency Level's bar.
  String latencyText() => '${latency.value.toStringAsFixed(1)} s';

  /// The comment of the Code view that says what the timer plays.
  String serverCode() =>
      '// A timer plays the server: ${fails.value ? 'it fails' : 'it answers ok'} '
      'after ${latency.value.toStringAsFixed(1)} s';
}

/// One instance, at the top level: the browser boots with it.
final cancelCommand = CancelCommandViewModel();

/// `:::bench bench-command`.
final commandBench = BenchExample(
  title: (t) => t.exArchCommandTitle,
  description: (t) => t.exArchCommandDescription,
  stage: const CancelCommandStage(),
  code: BenchCode([
    const BenchCodeLine('class OrdersViewModel extends ThorState {'),
    const BenchCodeLine('final list = query(listOrders);', indent: 1),
    BenchCodeLine.live(cancelCommand.serverCode, indent: 1),
    const BenchCodeLine('final cancel = commandWith(', indent: 1),
    const BenchCodeLine('cancelOrder,', indent: 2),
    const BenchCodeLine(
      'invalidates: (OrdersViewModel s) => [s.list],',
      indent: 2,
    ),
    const BenchCodeLine(');', indent: 1),
    const BenchCodeLine(' '),
    const BenchCodeLine(
      '// pending, error and result of the command',
      indent: 1,
    ),
    const BenchCodeLine('bool busy() => cancel.pending.value;', indent: 1),
    const BenchCodeLine(
      "String failure() => cancel.error.value ?? '';",
      indent: 1,
    ),
    const BenchCodeLine('}'),
  ], appCode: true),
  controls: [
    BenchSwitch<bool>(
      label: (t) => t.exArchServer,
      value: cancelCommand.fails.value,
      onChanged: cancelCommand.setFails,
      segments: [
        BenchSegment(false, label: (t) => t.exArchServerOk),
        BenchSegment(true, label: (t) => t.exArchServerFails),
      ],
    ),
    BenchLevel(
      label: (t) => t.exArchLatency,
      value: cancelCommand.latency.value,
      min: 0.2,
      max: 3,
      divisions: 14,
      onChanged: cancelCommand.setLatency,
      valueText: cancelCommand.latencyText,
    ),
  ],
);

/// The stage of `bench-command`: an order, its Cancel button and what each
/// phase of the command draws.
class CancelCommandStage extends StatelessWidget {
  /// The stage.
  const CancelCommandStage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 16,
      children: [
        const Text(
          'Order #1042',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        Watch.field(
          cancelCommand.phase,
          builder: (phase) => switch (phase) {
            CommandPhase.idle => FilledButton(
              onPressed: cancelCommand.run,
              child: const Text('Cancel order'),
            ),
            CommandPhase.running => const Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                // web: the indicator takes its own `size`, not its parent's box.
                CircularProgressIndicator(size: 18, strokeWidth: 2),
                Text('Cancelling…'),
              ],
            ),
            CommandPhase.done => Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                const Text('Order cancelled'),
                TextButton(
                  onPressed: cancelCommand.reset,
                  child: const Text('Reset'),
                ),
              ],
            ),
            CommandPhase.failed => Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                const Text(
                  'Could not cancel',
                  style: TextStyle(color: ThemeColor.error),
                ),
                OutlinedButton(
                  onPressed: cancelCommand.run,
                  child: const Text('Retry'),
                ),
              ],
            ),
          },
        ),
        _ServerPlan(
          status: Watch.field(
            cancelCommand.fails,
            builder: (fails) => Text(
              fails
                  ? 'The server answers with an error'
                  : 'The server answers ok',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: fails ? ThemeColor.error : ThemeColor.onSurface,
              ),
            ),
          ),
          bar: Watch.field(
            cancelCommand.latencyStep,
            count: _latencySteps,
            builder: (step) => LinearProgressIndicator(
              value:
                  (_minLatency +
                      step *
                          (_maxLatency - _minLatency) /
                          (_latencySteps - 1)) /
                  _maxLatency,
              semanticsLabel: 'Latency',
            ),
          ),
          latency: Watch(cancelCommand.latencyText, style: _latencyStyle),
        ),
      ],
    );
  }
}

/// What the simulated server will do the next time the button is pressed:
/// whether it answers well or with an error ([status]) and a bar as long as
/// its latency ([bar]) with the number next to it ([latency]). The two
/// controls that only act on a press show their setting here, before any
/// press.
class _ServerPlan extends StatelessWidget {
  const _ServerPlan({
    required this.status,
    required this.bar,
    required this.latency,
  });

  final Widget status;
  final Widget bar;
  final Widget latency;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    spacing: 8,
    children: [
      status,
      Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          SizedBox(width: _barWidth, child: bar),
          latency,
        ],
      ),
    ],
  );
}

const _latencyStyle = TextStyle(
  fontFamily: 'IBM Plex Mono',
  fontFamilyFallback: ['ui-monospace', 'monospace'],
  fontSize: 13,
  color: ThemeColor.onSurfaceVariant,
);

/// What the optimistic example's save is doing.
enum SavePhase {
  /// Nothing on its way.
  idle,

  /// The request is on its way.
  saving,

  /// The request failed and the star went back.
  failed,
}

/// The state behind `bench-optimistic`.
class StarOrderViewModel extends ThorState {
  /// Whether the order is starred, as the view shows it.
  final starred = state(false);

  /// What the request is doing.
  final phase = state(SavePhase.idle);

  /// Whether the star changes before the answer.
  final optimistic = state(true);

  /// Whether the simulated server answers with an error.
  final fails = state(false);

  /// How long the simulated server takes, in seconds.
  final latency = state(1.5);

  /// Which of the Level's steps [latency] is: what the bar draws.
  final latencyStep = state(_stepOf(1.5));

  /// What the star button calls. In an app the command queues a second tap
  /// behind the first; here the button waits for the answer, like the
  /// `Command` of Flutter's architecture guide, which ignores `execute`
  /// while it runs.
  Future<void> toggle() async {
    if (phase.value == SavePhase.saving) return;
    final before = starred.value;
    phase.value = SavePhase.saving;
    if (optimistic.value) starred.value = !before;
    await Future<void>.delayed(
      Duration(milliseconds: (latency.value * 1000).round()),
    );
    if (fails.value) {
      starred.value = before;
      phase.value = SavePhase.failed;
    } else {
      starred.value = !before;
      phase.value = SavePhase.idle;
    }
  }

  /// What the optimistic Switch calls.
  void setOptimistic(bool value) => optimistic.value = value;

  /// What the server Switch calls.
  void setFails(Set<bool> value) => fails.value = value.first;

  /// What the latency Level calls.
  void setLatency(double value) {
    latency.value = value;
    latencyStep.value = _stepOf(value);
  }

  /// The number next to the latency Level's bar.
  String latencyText() => '${latency.value.toStringAsFixed(1)} s';

  /// The comment of the Code view that says what the timer plays.
  String serverCode() =>
      '// A timer plays the server: ${fails.value ? 'it fails' : 'it answers ok'} '
      'after ${latency.value.toStringAsFixed(1)} s';

  /// The line of the Code view that runs before the command.
  String beforeCode() => optimistic.value
      ? 'starred.value = !before; // the star changes at once'
      : '// the star waits for the answer';

  /// The line of the Code view that runs after the command.
  String afterCode() => optimistic.value
      ? 'if (star.error.value != null) starred.value = before; // back'
      : 'if (star.error.value == null) starred.value = !before;';
}

/// One instance, at the top level: the browser boots with it.
final starOrder = StarOrderViewModel();

/// `:::bench bench-optimistic`.
final optimisticBench = BenchExample(
  title: (t) => t.exArchOptimisticTitle,
  description: (t) => t.exArchOptimisticDescription,
  stage: const StarOrderStage(),
  code: BenchCode([
    const BenchCodeLine('class StarViewModel extends ThorState {'),
    const BenchCodeLine('final starred = state(false);', indent: 1),
    BenchCodeLine.live(starOrder.serverCode, indent: 1),
    const BenchCodeLine('final star = commandWith(starOrder);', indent: 1),
    const BenchCodeLine(' '),
    const BenchCodeLine('Future<void> toggle(String id) async {', indent: 1),
    const BenchCodeLine('final before = starred.value;', indent: 2),
    BenchCodeLine.live(starOrder.beforeCode, indent: 2),
    const BenchCodeLine('await star.run(id);', indent: 2),
    BenchCodeLine.live(starOrder.afterCode, indent: 2),
    const BenchCodeLine('}', indent: 1),
    const BenchCodeLine('}'),
  ], appCode: true),
  controls: [
    BenchToggle(
      label: (t) => t.exArchOptimistic,
      value: starOrder.optimistic.value,
      onChanged: starOrder.setOptimistic,
    ),
    BenchSwitch<bool>(
      label: (t) => t.exArchServer,
      value: starOrder.fails.value,
      onChanged: starOrder.setFails,
      segments: [
        BenchSegment(false, label: (t) => t.exArchServerOk),
        BenchSegment(true, label: (t) => t.exArchServerFails),
      ],
    ),
    BenchLevel(
      label: (t) => t.exArchLatency,
      value: starOrder.latency.value,
      min: 0.2,
      max: 3,
      divisions: 14,
      onChanged: starOrder.setLatency,
      valueText: starOrder.latencyText,
    ),
  ],
);

/// The stage of `bench-optimistic`: an order with a star and a line that
/// says how the request is going.
class StarOrderStage extends StatelessWidget {
  /// The stage.
  const StarOrderStage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 16,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            const Text(
              'Order #1042',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            Watch.field(
              starOrder.starred,
              builder: (starred) => OutlinedButton(
                onPressed: starOrder.toggle,
                child: Text(starred ? '★' : '☆'),
              ),
            ),
          ],
        ),
        Watch.field(
          starOrder.phase,
          builder: (phase) => switch (phase) {
            SavePhase.idle => const Text(' '),
            SavePhase.saving => const Text('Saving…'),
            SavePhase.failed => const Text(
              'Could not save: the star went back',
              style: TextStyle(color: ThemeColor.error),
            ),
          },
        ),
        Watch.field(
          starOrder.optimistic,
          builder: (optimistic) => Text(
            optimistic
                ? 'The star changes on tap and goes back if it fails'
                : 'The star waits for the answer',
            style: const TextStyle(
              fontSize: 14,
              color: ThemeColor.onSurfaceVariant,
            ),
          ),
        ),
        _ServerPlan(
          status: Watch.field(
            starOrder.fails,
            builder: (fails) => Text(
              fails
                  ? 'The server answers with an error'
                  : 'The server answers ok',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: fails ? ThemeColor.error : ThemeColor.onSurface,
              ),
            ),
          ),
          bar: Watch.field(
            starOrder.latencyStep,
            count: _latencySteps,
            builder: (step) => LinearProgressIndicator(
              value:
                  (_minLatency +
                      step *
                          (_maxLatency - _minLatency) /
                          (_latencySteps - 1)) /
                  _maxLatency,
              semanticsLabel: 'Latency',
            ),
          ),
          latency: Watch(starOrder.latencyText, style: _latencyStyle),
        ),
      ],
    );
  }
}
