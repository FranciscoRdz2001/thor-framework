/// `:::bench bench-load`: what a page's `load` can end in. A Switch picks what
/// the repository answers (orders, nothing, a failure), a Level how many
/// orders come; the stage is the page the visitor gets and the Code view
/// the `load` that decides it.
library;

import 'package:thor_ui/thor_ui.dart';

import '../bench/bench_example.dart';
import 'learn_parts.dart';

const _maxOrders = 5;

/// What the repository answers.
enum RepoAnswer {
  /// A list of orders.
  orders,

  /// `null`: there is no such order.
  missing,

  /// The backend fails.
  failing,
}

/// What the panel controls and the stage reads.
class LoadViewModel extends ThorState {
  /// What the repository answers.
  final answer = state(RepoAnswer.orders);

  /// How many orders come, minus one.
  final count = state(2);

  /// The line of the Code view that reflects the answer.
  String answerCode() => switch (answer.value) {
    RepoAnswer.orders => 'return orders.list(); // ${count.value + 1} orders',
    RepoAnswer.missing => 'throw const NotFound(); // the repository had none',
    RepoAnswer.failing =>
      "throw const HttpError(StatusCode.serviceUnavailable, 'Try again.'); // the backend fails",
  };

  /// The number next to the Level.
  String countText() => '${count.value + 1}';

  /// What the Switch calls.
  void setAnswer(Set<RepoAnswer> value) => answer.value = value.first;

  /// What the Level calls.
  void setCount(double value) => count.value = value.round() - 1;
}

/// One instance, at the top level: the browser boots with it.
final loadDemo = LoadViewModel();

/// The example.
final loadBench = BenchExample(
  title: (t) => t.exDataLoadTitle,
  description: (t) => t.exDataLoadDescription,
  stage: const LoadStage(),
  code: BenchCode([
    const BenchCodeLine('class OrdersPage extends ThorPage<List<Order>> {'),
    const BenchCodeLine('@override', indent: 1),
    const BenchCodeLine(
      'Future<List<Order>> load(PageRequest request) async {',
      indent: 1,
    ),
    BenchCodeLine.live(loadDemo.answerCode, indent: 2),
    const BenchCodeLine('}', indent: 1),
    const BenchCodeLine(' '),
    const BenchCodeLine('@override', indent: 1),
    const BenchCodeLine(
      'Widget build(context, PageState<List<Order>> state) =>',
      indent: 1,
    ),
    const BenchCodeLine('OrderList(orders: state.data);', indent: 2),
    const BenchCodeLine('}'),
  ], appCode: true),
  controls: [
    BenchSwitch<RepoAnswer>(
      label: (t) => t.exDataLoadAnswer,
      value: loadDemo.answer.value,
      onChanged: loadDemo.setAnswer,
      segments: [
        BenchSegment(RepoAnswer.orders, label: (t) => t.exDataLoadOrders),
        BenchSegment(RepoAnswer.missing, label: (t) => t.exDataLoadMissing),
        BenchSegment(RepoAnswer.failing, label: (t) => t.exDataLoadFailing),
      ],
    ),
    BenchLevel(
      label: (t) => t.exDataLoadCount,
      value: loadDemo.count.value + 1,
      min: 1,
      max: _maxOrders.toDouble(),
      divisions: _maxOrders - 1,
      onChanged: loadDemo.setCount,
      valueText: loadDemo.countText,
    ),
  ],
);

/// The stage: the page `load`'s result makes.
class LoadStage extends StatelessWidget {
  /// The stage of the example.
  const LoadStage({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch.field(
      loadDemo.answer,
      builder: (answer) => Watch.field(
        loadDemo.count,
        count: _maxOrders,
        builder: (count) => LearnFrame(
          width: 300,
          child: switch (answer) {
            RepoAnswer.orders => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                for (var i = 1; i <= count + 1; i++)
                  LearnTile(label: 'Order #${1000 + i}', filled: false),
              ],
            ),
            RepoAnswer.missing => const _Outcome(
              status: '404',
              text: 'We could not find that order.',
            ),
            RepoAnswer.failing => const _Outcome(
              status: '503',
              text: 'The service is not responding. Try again.',
            ),
          },
        ),
      ),
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({required this.status, required this.text});

  final String status;
  final String text;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 4,
    children: [
      Text(
        status,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      ),
      Text(text, style: const TextStyle(fontSize: 14)),
    ],
  );
}
