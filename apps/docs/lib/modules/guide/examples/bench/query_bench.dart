/// `:::bench bench-state-query`: the three states a `QueryBuilder` draws.
/// This site has no server to answer a `query`, so a Switch plays the
/// snapshot (`// web:`): the branches are the ones the page carries, and the
/// browser changes between them as the query moves.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';

/// Where the query is.
enum QueryPhase {
  /// Asked, no answer yet.
  loading,

  /// Answered with data.
  ready,

  /// Failed.
  error,
}

/// What the Switch changes and the stage reads.
class QueryPhaseViewModel extends ThorState {
  /// Which branch the stage shows.
  final phase = state(QueryPhase.loading);

  /// The line of the Code view that names the branch taken.
  String branchCode() => switch (phase.value) {
    QueryPhase.loading => '// snapshot.connectionState == waiting',
    QueryPhase.ready => '// snapshot.hasData',
    QueryPhase.error => '// snapshot.hasError',
  };

  /// What the Switch calls.
  void setPhase(Set<QueryPhase> value) => phase.value = value.first;

  /// What the retry button calls: asks again.
  void retry() => phase.value = QueryPhase.loading;
}

/// One instance, at the top level: the browser boots with it.
final queryPhase = QueryPhaseViewModel();

/// The example: a Switch, the stage and its code.
final queryBench = BenchExample(
  title: (t) => t.exStateQueryTitle,
  description: (t) => t.exStateQueryDescription,
  stage: const QueryStage(),
  code: BenchCode([
    const BenchCodeLine('QueryBuilder<List<Product>>('),
    const BenchCodeLine('query: catalog.products,', indent: 1),
    const BenchCodeLine('builder: (context, snapshot) {', indent: 1),
    const BenchCodeLine('if (snapshot.hasError) return …;', indent: 2),
    const BenchCodeLine(
      'if (!snapshot.hasData) return const Skeleton();',
      indent: 2,
    ),
    const BenchCodeLine('return Watch.list(…);', indent: 2),
    const BenchCodeLine('},', indent: 1),
    const BenchCodeLine(')'),
    BenchCodeLine.live(queryPhase.branchCode),
  ], appCode: true),
  controls: [
    BenchSwitch<QueryPhase>(
      label: (t) => t.exStateQueryPhase,
      value: queryPhase.phase.value,
      onChanged: queryPhase.setPhase,
      segments: [
        BenchSegment(QueryPhase.loading, label: (t) => t.exStateQueryLoading),
        BenchSegment(QueryPhase.ready, label: (t) => t.exStateQueryReady),
        BenchSegment(QueryPhase.error, label: (t) => t.exStateQueryError),
      ],
    ),
  ],
);

const _itemStyle = TextStyle(fontSize: 22);

/// The stage: the branch of the `QueryBuilder` for the chosen phase.
class QueryStage extends StatelessWidget {
  /// The stage of the example.
  const QueryStage({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Watch.field(
        queryPhase.phase,
        builder: (phase) => switch (phase) {
          QueryPhase.loading => const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Skeleton(height: 32),
              Skeleton(height: 32),
              Skeleton(height: 32),
            ],
          ),
          QueryPhase.ready => const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              Text('Spiced coffee', style: _itemStyle),
              Text('Clay mug', style: _itemStyle),
              Text('Wooden whisk', style: _itemStyle),
            ],
          ),
          QueryPhase.error => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              const Text('Could not load the catalog.', style: _itemStyle),
              OutlinedButton(
                onPressed: queryPhase.retry,
                child: const Text('Retry'),
              ),
            ],
          ),
        },
      ),
    );
  }
}
