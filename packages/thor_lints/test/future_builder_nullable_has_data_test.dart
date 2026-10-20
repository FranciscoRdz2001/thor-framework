import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:thor_lints/src/future_builder_nullable_has_data.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(FutureBuilderNullableHasDataTest);
  });
}

/// A stand-in for thor: a snapshot, FutureBuilder and a widget.
const _thor = r'''
abstract class Widget {}
class Text extends Widget {
  Text(this.text);
  final String text;
}
enum ConnectionState { none, waiting, active, done }
class AsyncSnapshot<T> {
  T? get data => null;
  bool get hasData => data != null;
  bool get hasError => false;
  ConnectionState get connectionState => ConnectionState.done;
}
class FutureBuilder<T> extends Widget {
  FutureBuilder({required this.future, required this.builder});
  final Future<T>? future;
  final Widget Function(Object context, AsyncSnapshot<T> snapshot) builder;
}
Future<String?> maybe() async => null;
Future<String> sure() async => 'x';
''';

@reflectiveTest
class FutureBuilderNullableHasDataTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = FutureBuilderNullableHasData();
    super.setUp();
  }

  Future<void> test_hasDataAloneOnANullableFutureIsReported() async {
    const code = '''
Widget a() => FutureBuilder<String?>(
  future: maybe(),
  builder: (context, snapshot) =>
      snapshot.hasData ? Text(snapshot.data!) : Text('skeleton'),
);
''';
    final all = '$_thor$code';
    await assertDiagnostics(all, [
      lint(
        all.indexOf('snapshot.hasData'),
        'snapshot.hasData'.length,
        messageContainsAll: ['THOR-R033', 'hasData'],
        correctionContains: 'ConnectionState.done',
      ),
    ]);
  }

  Future<void> test_theTypeIsInferredFromTheFuture() async {
    final code = '''
Widget a() => FutureBuilder(
  future: maybe(),
  builder: (context, snap) =>
      snap.hasError ? Text('e') : snap.hasData ? Text(snap.data!) : Text('...'),
);
''';
    final all = '$_thor$code';
    await assertDiagnostics(all, [
      lint(all.indexOf('snap.hasData'), 'snap.hasData'.length),
    ]);
  }

  Future<void> test_connectionStateMakesItFine() async {
    await assertNoDiagnostics('''
$_thor
Widget a() => FutureBuilder<String?>(
  future: maybe(),
  builder: (context, snapshot) =>
      snapshot.connectionState != ConnectionState.done
      ? Text('skeleton')
      : snapshot.hasData ? Text(snapshot.data!) : Text('nothing'),
);
''');
  }

  Future<void> test_aNonNullableFutureIsFine() async {
    await assertNoDiagnostics('''
$_thor
Widget a() => FutureBuilder<String>(
  future: sure(),
  builder: (context, snapshot) =>
      snapshot.hasData ? Text(snapshot.data!) : Text('skeleton'),
);
''');
  }

  Future<void> test_notReadingHasDataIsFine() async {
    await assertNoDiagnostics('''
$_thor
Widget a() => FutureBuilder<String?>(
  future: maybe(),
  builder: (context, snapshot) => Text(snapshot.data ?? 'nothing'),
);
''');
  }

  Future<void> test_aSnapshotPassedAlongIsNotJudged() async {
    await assertNoDiagnostics('''
$_thor
Widget show(AsyncSnapshot<String?> s) =>
    s.hasData ? Text(s.data!) : Text('...');
Widget a() => FutureBuilder<String?>(
  future: maybe(),
  builder: (context, snapshot) => show(snapshot),
);
Widget b() => FutureBuilder<String?>(
  future: maybe(),
  builder: (context, snapshot) =>
      snapshot.hasData ? show(snapshot) : Text('...'),
);
''');
  }

  Future<void> test_otherClassesAreFine() async {
    await assertNoDiagnostics('''
$_thor
class Box<T> {
  Box(this.builder);
  final Widget Function(Object, AsyncSnapshot<T>) builder;
}
final b = Box<String?>((context, snapshot) =>
    snapshot.hasData ? Text(snapshot.data!) : Text('...'));
''');
  }
}
