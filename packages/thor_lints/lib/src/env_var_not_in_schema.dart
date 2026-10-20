import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// `env_var_not_in_schema`: an `EnvString`/`EnvInt`/... declared as a
/// `static const` of a class whose `EnvSchema([...])` does not list it.
///
/// `EnvSchema.load()` reads only what it lists, so the variable is neither
/// required nor parsed, and `env.of(it)` fails on the first request that
/// reads it (THOR-P011). Only a class that declares both the variables and
/// a schema made of plain names is checked: a schema built from spreads,
/// calls or another class is not known here and is left alone.
class EnvVarNotInSchema extends AnalysisRule {
  /// The diagnostic reported on the variable's name.
  static const DiagnosticCode code = LintCode(
    'env_var_not_in_schema',
    '`{0}` is not in the `EnvSchema` of this class: it is never loaded, and '
        '`env.of({0})` fails on the first request (THOR-P011).',
    correctionMessage: 'Add `{0}` to the `EnvSchema([...])` list.',
    uniqueName: 'LintCode.env_var_not_in_schema',
  );

  /// Creates the rule.
  EnvVarNotInSchema()
    : super(
        name: 'env_var_not_in_schema',
        description:
            'An Env variable declared next to an EnvSchema must be in it.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addClassDeclaration(this, _Visitor(this));
  }
}

const _envTypes = {
  'EnvString',
  'EnvInt',
  'EnvBool',
  'EnvUrl',
  'EnvSecret',
  'EnvOptional',
};

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final vars = <VariableDeclaration>[];
    final byField = <String, InstanceCreationExpression>{};
    final schemas = <InstanceCreationExpression>[];
    for (final member in node.body.members) {
      if (member is! FieldDeclaration || !member.isStatic) continue;
      for (final v in member.fields.variables) {
        final init = v.initializer;
        if (init is! InstanceCreationExpression) continue;
        final type = init.constructorName.type.name.lexeme;
        if (_envTypes.contains(type)) {
          vars.add(v);
          byField[v.name.lexeme] = init;
        }
        if (type == 'EnvSchema') schemas.add(init);
      }
    }
    // Two schemas, or one this rule can't read: nothing to say.
    if (schemas.length != 1) return;
    final items = _plainItems(schemas.single);
    if (items == null) return;
    // `env.of` finds a variable by its environment name, so what counts is
    // the names the schema loads (`EnvOptional(base)` loads `base`'s name).
    final listed = <String>{};
    for (final e in items) {
      if (e is InstanceCreationExpression) {
        listed.add(_envName(e, byField) ?? '');
      } else {
        final field = e is PrefixedIdentifier
            ? e.identifier.name
            : (e as SimpleIdentifier).name;
        final init = byField[field];
        listed.add((init == null ? null : _envName(init, byField)) ?? field);
      }
    }
    for (final v in vars) {
      final name = _envName(byField[v.name.lexeme]!, byField);
      if (listed.contains(v.name.lexeme) ||
          (name != null && listed.contains(name))) {
        continue;
      }
      rule.reportAtToken(v.name, arguments: [v.name.lexeme]);
    }
  }

  /// The environment name of `EnvString('X')` (`X`), looking through
  /// `EnvOptional(...)`, or `null` when it is not a literal.
  static String? _envName(
    InstanceCreationExpression e,
    Map<String, InstanceCreationExpression> fields, [
    int depth = 0,
  ]) {
    final args = e.argumentList.arguments;
    if (args.isEmpty || depth > 4) return null;
    final first = args.first;
    if (e.constructorName.type.name.lexeme == 'EnvOptional') {
      if (first is InstanceCreationExpression) {
        return _envName(first, fields, depth + 1);
      }
      final ref = first is SimpleIdentifier
          ? fields[first.name]
          : first is PrefixedIdentifier
          ? fields[first.identifier.name]
          : null;
      return ref == null ? null : _envName(ref, fields, depth + 1);
    }
    return first is SimpleStringLiteral ? first.value : null;
  }

  /// The elements of `EnvSchema([a, AppEnv.b, EnvInt('C')])`, or `null` if
  /// the list holds anything else (a spread, a call, a condition).
  static List<Expression>? _plainItems(InstanceCreationExpression schema) {
    final args = schema.argumentList.arguments;
    if (args.length != 1) return null;
    final list = args.single;
    if (list is! ListLiteral) return null;
    final items = <Expression>[];
    for (final e in list.elements) {
      if (e is SimpleIdentifier ||
          e is PrefixedIdentifier ||
          e is InstanceCreationExpression) {
        items.add(e as Expression);
      } else {
        return null;
      }
    }
    return items;
  }
}
