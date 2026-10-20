import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:thor_lints/lite.dart';
import 'package:thor_lints/src/lite_subset_rule.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(LiteSubsetTest);
  });
}

/// A stand-in for thor_engine: what a state needs to be one.
const _engine = r'''
abstract class ThorState {}
class StateSignal<T> {
  StateSignal(this.value);
  T value;
  T call() => value;
}
StateSignal<T> state<T>(T initial) => StateSignal(initial);
class ServerEventStream<T> {}
ServerEventStream<T> events<T>(String url, {String? event}) =>
    ServerEventStream<T>();
class ServerQuery<A, T> {}
ServerQuery<Null, T> query<T>(Future<T> Function() fn) =>
    ServerQuery<Null, T>();
''';

const _header = '''
import 'dart:async';

import 'package:thor_engine/thor_engine.dart';
''';

@reflectiveTest
class LiteSubsetTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = LiteSubsetRule();
    newPackage('thor_engine').addFile('lib/thor_engine.dart', _engine);
    super.setUp();
  }

  /// [code] and the offset of [needle] in it.
  (String, int) _at(String code, String needle) {
    final offset = code.indexOf(needle);
    expect(offset, greaterThanOrEqualTo(0), reason: needle);
    return (code, offset);
  }

  /// What the build says of the test file: the translator's errors.
  List<LiteError> _buildErrors() {
    try {
      translateLiteStates([LiteUnit(result.path, result.unit)]);
    } on LiteTranslationException catch (e) {
      return e.errors;
    }
    return const [];
  }

  // The message and the fix the build prints, in the editor.
  Future<void> test_completerSync() async {
    const construct = 'Completer<int>.sync()';
    final (code, at) = _at('''
$_header
class PState extends ThorState {
  final a = state(0);
  Object f() => $construct;
}
''', construct);
    await assertDiagnostics(code, [
      error(
        LiteSubsetRule.code,
        at,
        construct.length,
        messageContainsAll: ['Completer.sync', 'THOR-B012'],
        correctionContains: '`Completer()`',
      ),
    ]);
    // Parity: the build's error, at the same place, with the same text.
    final built = _buildErrors().single;
    final shown = result.diagnostics.single;
    expect(shown.message, startsWith(built.message));
    expect(shown.correctionMessage, built.hint);
    final loc = result.lineInfo.getLocation(shown.offset);
    expect((loc.lineNumber, loc.columnNumber), (built.line, built.column));
  }

  // Parity with the build for constructs of the hint table: one diagnostic
  // per build error, same place, same message, same fix.
  Future<void> test_parityWithTheBuild() async {
    const bodies = [
      'Future<List<int>> f() => Future.wait([], cleanUp: (x) {});',
      'void f() { Timer.run(() {}); }',
      'void f() { final c = StreamController<int>(); c.add(1); }',
      'Iterable<int> f() sync* { yield 1; }',
      r'String f(Object o) => "${o.runtimeType}";',
      'int f(List<int> l) => l.getRange(0, 1).length;',
    ];
    for (final body in bodies) {
      final file = newFile('$testPackageLibPath/s.dart', '''
$_header
class PState extends ThorState {
  final a = state(0);
  $body
}
''');
      result = await resolveFile(file.path);
      final built = _buildErrors();
      final shown = [
        for (final d in result.diagnostics)
          if (d.diagnosticCode == LiteSubsetRule.code) d,
      ];
      expect(built, isNotEmpty, reason: body);
      expect(shown, hasLength(built.length), reason: body);
      for (var i = 0; i < built.length; i++) {
        final loc = result.lineInfo.getLocation(shown[i].offset);
        expect(
          (loc.lineNumber, loc.columnNumber),
          (built[i].line, built[i].column),
          reason: body,
        );
        expect(shown[i].message, startsWith(built[i].message), reason: body);
        expect(shown[i].correctionMessage, built[i].hint, reason: body);
      }
    }
  }

  Future<void> test_withinTheSubset() async {
    await assertNoDiagnostics('''
import 'package:thor_engine/thor_engine.dart';

class PState extends ThorState {
  final a = state(0);
  void increment() => a.value++;
  String label() => 'count: \${a.value}';
}
''');
  }

  // Code that is not a state's (a widget's, the server's) runs in the VM.
  Future<void> test_notAState() async {
    await assertNoDiagnostics('''
import 'dart:async';

class Service {
  Object f() => Completer<int>.sync();
}
''');
  }

  // Only what a state reaches is translated.
  Future<void> test_helperNoStateReaches() async {
    await assertNoDiagnostics('''
$_header
Object unused() => Completer<int>.sync();
class PState extends ThorState {
  final a = state(0);
}
''');
  }

  Future<void> test_helperTheStateCalls() async {
    const construct = 'Completer<int>.sync()';
    final (code, at) = _at('''
$_header
Object make() => $construct;
class PState extends ThorState {
  final a = state(0);
  Object f() => make();
}
''', construct);
    await assertDiagnostics(code, [
      error(LiteSubsetRule.code, at, construct.length),
    ]);
  }

  // Another library of the app is opaque: no error for naming it, the one
  // of this library still is.
  Future<void> test_otherLibraryOfTheApp() async {
    newFile('$testPackageLibPath/model.dart', '''
class Item {
  Item(this.name);
  final String name;
}
String describe(Item i) => i.name;
''');
    const construct = 'Completer<int>.sync()';
    final (code, at) = _at('''
$_header
import 'model.dart';

class PState extends ThorState {
  final items = state(<Item>[]);
  void add(String name) => items.value = [...items.value, Item(name)];
  String first() => describe(items.value.first);
  Object f() => $construct;
}
''', construct);
    await assertDiagnostics(code, [
      error(LiteSubsetRule.code, at, construct.length),
    ]);
    // Alone, the translator takes `Item` and `describe` for code outside
    // the app: the rule leaves those to the build.
    expect(_buildErrors().length, greaterThan(1));
  }

  // A state in a part: the error is reported in the part.
  Future<void> test_part() async {
    const construct = 'Completer<int>.sync()';
    final part = newFile('$testPackageLibPath/p.dart', '''
part of 'test.dart';

class PState extends ThorState {
  final a = state(0);
  Object f() => $construct;
}
''');
    newFile('$testPackageLibPath/test.dart', '''
$_header
part 'p.dart';
''');
    final at = part.readAsStringSync().indexOf(construct);
    await assertDiagnosticsInFile(part.path, [
      error(LiteSubsetRule.code, at, construct.length),
    ]);
    await assertNoDiagnosticsInFile('$testPackageLibPath/test.dart');
  }

  // The bundle holds `lib/`: a state in a test never reaches the browser.
  Future<void> test_outsideLib() async {
    final file = newFile('$testPackageRootPath/test/s_test.dart', '''
$_header
class PState extends ThorState {
  final a = state(0);
  Object f() => Completer<int>.sync();
}
''');
    await assertNoDiagnosticsInFile(file.path);
  }

  // A data class of another library that travels to the browser (the type
  // argument of events/query/state) is translated by the build too: its
  // errors show in its own file.
  Future<void> _dataClassFile(
    String field, {
    String body = "Uri.parse(j['u'] as String).path",
    String extraState = '',
    String extraModel = '',
  }) async {
    newFile('$testPackageLibPath/s.dart', '''
$_header
import 'model.dart';

class PState extends ThorState {
  $field
  $extraState
}
''');
    final model = newFile('$testPackageLibPath/model.dart', '''
class Status {
  Status(this.path);
  factory Status.fromJson(Map<String, Object?> j) => Status($body);
  final String path;
  Map<String, Object?> toJson() => {'u': path};
  $extraModel
}
''');
    result = await resolveFile(model.path);
  }

  List<Diagnostic> _shown() => [
    for (final d in result.diagnostics)
      if (d.diagnosticCode == LiteSubsetRule.code) d,
  ];

  Future<void> _expectInModel(String field, {String extraState = ''}) async {
    await _dataClassFile(field, extraState: extraState);
    // The test SDK has no `Uri`: its `.path` is a second error.
    final shown = _shown().first;
    expect(shown.message, contains('Uri.parse'));
    expect(shown.message, contains('THOR-B012'));
    expect(shown.offset, result.content.indexOf("Uri.parse(j['u']"));
    expect(result.path, endsWith('model.dart'));
  }

  Future<void> _expectClean(String field) async {
    await _dataClassFile(field, body: "j['u'] as String");
    expect(_shown(), isEmpty);
  }

  Future<void> test_dataClassOfEvents() async =>
      _expectInModel("final f = events<Status>('/s');");

  Future<void> test_dataClassOfQuery() async =>
      _expectInModel('final f = query<Status>(() => Status("a"));');

  Future<void> test_dataClassOfState() async =>
      _expectInModel('final f = state<Status>(Status("a"));');

  Future<void> test_cleanDataClassOfEvents() async =>
      _expectClean("final f = events<Status>('/s');");

  Future<void> test_cleanDataClassOfQuery() async =>
      _expectClean('final f = query<Status>(() => Status("a"));');

  Future<void> test_cleanDataClassOfState() async =>
      _expectClean('final f = state<Status>(Status("a"));');

  // A data class no state names is the server's: it may use any package.
  Future<void> test_dataClassNoStateNames() async {
    await _dataClassFile('final f = state(0);');
    expect(_shown(), isEmpty);
  }

  // A protocol package: its states live in the app that uses it, so
  // `thor: lite_data: true` says all its data classes go to the browser.
  Future<void> _protocolFile({required String pubspec}) async {
    newFile('$testPackageRootPath/pubspec.yaml', pubspec);
    final model = newFile('$testPackageLibPath/model.dart', '''
class Status {
  Status(this.u);
  factory Status.fromJson(Map<String, Object?> j) =>
      Status(Uri.parse(j['u'] as String));
  final Uri u;
  Map<String, Object?> toJson() => {};
  String host() => Uri.parse('x').host;
}
''');
    result = await resolveFile(model.path);
  }

  Future<void> test_protocolPackageDataClassesTravel() async {
    await _protocolFile(pubspec: 'name: protocol\nthor:\n  lite_data: true\n');
    final offsets = [for (final d in _shown()) d.offset];
    expect(offsets, contains(result.content.indexOf("Uri.parse(j['u']")));
    // Its methods too: any of them may be called from the app's state.
    expect(offsets, contains(result.content.indexOf("Uri.parse('x')")));
  }

  Future<void> test_protocolPackageWithoutTheFlag() async {
    await _protocolFile(
      pubspec: 'name: protocol\nthor:\n  share_styles: true\n',
    );
    expect(_shown(), isEmpty);
  }

  Future<void> test_protocolFlagOff() async {
    await _protocolFile(pubspec: 'name: protocol\nthor:\n  lite_data: false\n');
    expect(_shown(), isEmpty);
  }

  // A method of the data class: only when the state calls it.
  Future<void> test_methodTheStateCalls() async {
    await _dataClassFile(
      "final f = state<Status>(Status('a'));",
      body: "j['u'] as String",
      extraState: 'String g() => f.value.host();',
      extraModel: "String host() => Uri.parse(path).host;",
    );
    final shown = _shown().first;
    expect(shown.offset, result.content.indexOf('Uri.parse(path)'));
  }

  Future<void> test_methodTheStateDoesNotCall() async {
    await _dataClassFile(
      "final f = state<Status>(Status('a'));",
      body: "j['u'] as String",
      extraModel: "String host() => Uri.parse(path).host;",
    );
    expect(_shown(), isEmpty);
  }

  // Through the fields: the class a data class holds is a data class too.
  Future<void> test_throughTheFields() async {
    newFile('$testPackageLibPath/s.dart', '''
$_header
import 'model.dart';

class PState extends ThorState {
  final f = events<Status>('/s');
}
''');
    final model = newFile('$testPackageLibPath/model.dart', '''
class Detail {
  Detail(this.u);
  factory Detail.fromJson(Map<String, Object?> j) =>
      Detail(Uri.parse(j['u'] as String));
  final Uri u;
}
class Status {
  Status(this.detail);
  factory Status.fromJson(Map<String, Object?> j) =>
      Status(Detail.fromJson(j['d'] as Map<String, Object?>));
  final Detail detail;
  Map<String, Object?> toJson() => {};
}
''');
    result = await resolveFile(model.path);
    expect(_shown().first.offset, result.content.indexOf('Uri.parse('));
  }
}
