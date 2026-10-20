import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:thor_lints/src/env_var_not_in_schema.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(EnvVarNotInSchemaTest);
  });
}

const _env = r'''
sealed class EnvVar<T> {
  const EnvVar(this.name);
  final String name;
}
final class EnvString extends EnvVar<String> {
  const EnvString(super.name, {String? fallback});
}
final class EnvInt extends EnvVar<int> {
  const EnvInt(super.name, {int? fallback});
}
final class EnvOptional<T> extends EnvVar<T?> {
  const EnvOptional(this.variable) : super('');
  final EnvVar<T> variable;
}
class EnvSchema {
  const EnvSchema(this.vars);
  final List<EnvVar<Object?>> vars;
}
''';

@reflectiveTest
class EnvVarNotInSchemaTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = EnvVarNotInSchema();
    super.setUp();
  }

  Future<void> _check(String code, [List<String> lints = const []]) {
    final source = '$_env\n$code';
    return assertDiagnostics(source, [
      for (final l in lints)
        lint(
          _env.length + 1 + code.indexOf('static const $l =') + 13,
          l.length,
        ),
    ]);
  }

  Future<void> test_missingFromSchema() => _check(
    '''
abstract final class AppEnv {
  static const api = EnvString('API');
  static const port = EnvInt('PORT', fallback: 1);
  static const schema = EnvSchema([api]);
}
''',
    ['port'],
  );

  Future<void> test_severalMissing_optionalToo() => _check(
    '''
abstract final class AppEnv {
  static const a = EnvString('A');
  static const b = EnvOptional(EnvInt('B'));
  static const c = EnvString('C');
  static const schema = EnvSchema([a]);
}
''',
    ['b', 'c'],
  );

  Future<void> test_allListed() => assertNoDiagnostics('''
$_env
abstract final class AppEnv {
  static const a = EnvString('A');
  static const b = EnvInt('B');
  static const schema = EnvSchema([a, b]);
}
''');

  Future<void> test_qualifiedNames() => assertNoDiagnostics('''
$_env
abstract final class AppEnv {
  static const a = EnvString('A');
  static const b = EnvInt('B');
  static const schema = EnvSchema([AppEnv.a, AppEnv.b]);
}
''');

  Future<void> test_inlineVarInSchemaIsNotAField() => assertNoDiagnostics('''
$_env
abstract final class AppEnv {
  static const a = EnvString('A');
  static const schema = EnvSchema([a, EnvInt('B')]);
}
''');

  Future<void> test_noSchemaInClass() => assertNoDiagnostics('''
$_env
abstract final class AppEnv {
  static const a = EnvString('A');
}
final schema = EnvSchema([AppEnv.a]);
''');

  Future<void> test_unknowableListIsLeftAlone() => assertNoDiagnostics('''
$_env
const more = [EnvInt('M')];
abstract final class AppEnv {
  static const a = EnvString('A');
  static const b = EnvInt('B');
  static const schema = EnvSchema([a, ...more]);
}
''');

  Future<void> test_nonEnvFieldsIgnored() => assertNoDiagnostics('''
$_env
abstract final class AppEnv {
  static const a = EnvString('A');
  static const label = 'x';
  static final n = 3;
  static const schema = EnvSchema([a]);
}
''');

  Future<void> test_instanceFieldsAndTwoSchemas() => assertNoDiagnostics('''
$_env
class Other {
  final x = EnvString('X');
}
abstract final class AppEnv {
  static const a = EnvString('A');
  static const schema = EnvSchema([a]);
}
''');

  // env.of looks a variable up by its name, so a base listed through its
  // EnvOptional wrapper (or an equal inline variable) is in the schema.
  Future<void> test_baseListedThroughOptionalWrapper() =>
      assertNoDiagnostics('''
$_env
abstract final class AppEnv {
  static const base = EnvInt('B');
  static const opt = EnvOptional(base);
  static const schema = EnvSchema([opt]);
}
''');

  Future<void> test_sameNameListedInline() => assertNoDiagnostics('''
$_env
abstract final class AppEnv {
  static const b = EnvInt('B');
  static const schema = EnvSchema([EnvInt('B')]);
}
''');

  Future<void> test_staticFinalAndPrivateAreChecked() => _check(
    '''
abstract final class AppEnv {
  static const a = EnvString('A');
  static const _p = EnvString('P');
  static const schema = EnvSchema([a]);
}
''',
    ['_p'],
  );
}
