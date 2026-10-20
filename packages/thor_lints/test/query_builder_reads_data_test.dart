import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:thor_lints/src/query_builder_reads_data.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(QueryBuilderReadsDataTest);
  });
}

/// A stand-in for thor: a query, its snapshot, QueryBuilder and a widget.
const _thor = r'''
abstract class Widget {}
class Text extends Widget {
  Text(this.text);
  final String text;
}
class AsyncSnapshot<T> {
  T? get data => null;
  bool get hasData => data != null;
  T get requireData => data!;
}
class ServerQuery<A, T> {}
class QueryBuilder<T> extends Widget {
  QueryBuilder({
    required this.query,
    required this.builder,
    this.initialData,
  });
  final ServerQuery<Object?, T> query;
  final Widget Function(Object context, AsyncSnapshot<T> snapshot) builder;
  final T? initialData;
}
final lines = ServerQuery<Object?, List<int>>();
''';

@reflectiveTest
class QueryBuilderReadsDataTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = QueryBuilderReadsData();
    super.setUp();
  }

  Future<void> test_dataAndRequireDataAreReported() async {
    const code = '''
Widget a() => QueryBuilder<List<int>>(
  query: lines,
  builder: (context, snapshot) => Text('\${snapshot.data!.length}'),
);
Widget b() => QueryBuilder<List<int>>(
  query: lines,
  builder: (context, snap) =>
      snap.hasData ? Text('\${snap.requireData.length}') : Text('...'),
);
''';
    final all = '$_thor$code';
    await assertDiagnostics(all, [
      lint(
        all.indexOf('snapshot.data!', _thor.length),
        'snapshot.data'.length,
        messageContainsAll: ['snapshot.data'],
        correctionContains: 'hasData',
      ),
      lint(
        all.indexOf('snap.requireData'),
        'snap.requireData'.length,
        messageContainsAll: ['snap.requireData'],
      ),
    ]);
  }

  Future<void> test_hasDataAndOtherBuildersAreFine() async {
    await assertNoDiagnostics('''
$_thor
Widget a() => QueryBuilder<List<int>>(
  query: lines,
  builder: (context, snapshot) =>
      snapshot.hasData ? Text('con datos') : Text('cargando'),
);
Widget b(AsyncSnapshot<int> data) => Text('\${data.data}');
class Other {
  Other(this.builder);
  final Widget Function(Object, AsyncSnapshot<int>) builder;
}
final o = Other((context, snapshot) => Text('\${snapshot.data}'));
''');
  }
}
