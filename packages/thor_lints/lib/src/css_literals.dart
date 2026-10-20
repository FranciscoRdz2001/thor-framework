import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

// The framework itself turns the types into CSS: it is the one place
// strings belong.
const _framework = [
  'package:thor_ui/',
  'package:thor_style/',
  'package:thor_engine/',
  'package:thor_server/',
];

bool _inFramework(RuleContext context) {
  final uri = context.libraryElement?.uri.toString() ?? '';
  return _framework.any(uri.startsWith);
}

/// `Length.variable(CssVariable('--x'))` or `Color.variable(…)` (written
/// either way), with its name, when the name is a string literal.
String? _variableName(AstNode node) {
  final (
    String? type,
    String? ctor,
    String? library,
    NodeList<Expression>? args,
  ) = switch (node) {
    InstanceCreationExpression(:final constructorName, :final argumentList) => (
      constructorName.type.element?.name,
      constructorName.name?.name,
      constructorName.type.element?.library?.uri.toString(),
      argumentList.arguments,
    ),
    MethodInvocation(:final target, :final methodName, :final argumentList) => (
      target is SimpleIdentifier ? target.name : null,
      methodName.name,
      target is SimpleIdentifier
          ? target.element?.library?.uri.toString()
          : null,
      argumentList.arguments,
    ),
    _ => (null, null, null, null),
  };
  if (ctor != 'variable' || (type != 'Length' && type != 'Color')) return null;
  if (library == null || !library.startsWith('package:thor_style/')) {
    return null;
  }
  final first = switch (args?.firstOrNull) {
    // `CssVariable('--x')`, with or without `const`.
    InstanceCreationExpression(:final constructorName, :final argumentList)
        when constructorName.type.element?.name == 'CssVariable' =>
      argumentList.arguments.firstOrNull,
    MethodInvocation(:final methodName, :final argumentList, target: null)
        when methodName.name == 'CssVariable' =>
      argumentList.arguments.firstOrNull,
    final other => other,
  };
  return first is SimpleStringLiteral ? first.value : null;
}

/// `duplicate_css_variable_name`: the same custom property written as a
/// string more than once in a file (`Length.variable(CssVariable('--row-h'))`
/// in two places).
///
/// The name is a string the compiler can't check: a typo in one copy is a
/// variable nobody sets, silently. Declare it once as a `const`
/// (`const _rowH = Length.variable(CssVariable('--row-h'))`) and use that.
class DuplicateCssVariableName extends AnalysisRule {
  /// The diagnostic reported on every copy after the first.
  static const LintCode code = LintCode(
    'duplicate_css_variable_name',
    "The custom property '{0}' is written as a string again in this file.",
    correctionMessage:
        'Declare it once as a const (const _name = Length.variable(…)) and '
        'use that.',
    uniqueName: 'LintCode.duplicate_css_variable_name',
  );

  /// Creates the rule.
  DuplicateCssVariableName()
    : super(
        name: 'duplicate_css_variable_name',
        description:
            'Declare a CSS custom property name once instead of repeating '
            'the string.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (_inFramework(context) || context.isInTestDirectory) return;
    registry.addCompilationUnit(this, _Unit(this));
  }
}

class _Unit extends SimpleAstVisitor<void> {
  _Unit(this.rule);

  final AnalysisRule rule;

  @override
  void visitCompilationUnit(CompilationUnit node) {
    final seen = <String>{};
    node.accept(_Finder(rule, seen));
  }
}

class _Finder extends RecursiveAstVisitor<void> {
  _Finder(this.rule, this.seen);

  final AnalysisRule rule;
  final Set<String> seen;

  void _check(AstNode node) {
    final name = _variableName(node);
    if (name == null) return;
    if (!seen.add(name)) rule.reportAtNode(node, arguments: [name]);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _check(node);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _check(node);
    super.visitMethodInvocation(node);
  }
}

/// `avoid_color_css_string`: `Color.css('#16a34a')` or
/// `Color.css('var(--brand)')`, where a typed color exists: `Color(0xFF16A34A)`
/// for a hex, `Color.variable(CssVariable('--brand'))` (or a theme token) for a variable.
///
/// `Color.css` is for color functions with no type (`color-mix(…)`, `hsl()`).
/// A hex string skips the checks of the type, and `var(--x)` in a string
/// loses the fallback the server writes.
class AvoidColorCssString extends AnalysisRule {
  /// The diagnostic reported on the string.
  static const LintCode code = LintCode(
    'avoid_color_css_string',
    'A color written as a CSS string where a typed one exists.',
    correctionMessage:
        "Use Color(0xFF16A34A) for '#16a34a', Color.variable(CssVariable('--x')) for "
        "'var(--x)'.",
    uniqueName: 'LintCode.avoid_color_css_string',
  );

  /// Creates the rule.
  AvoidColorCssString()
    : super(
        name: 'avoid_color_css_string',
        description:
            "Prefer Color(0x…) and Color.variable over Color.css('#…') and "
            "Color.css('var(--…)').",
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (_inFramework(context)) return;
    final visitor = _ColorVisitor(this);
    registry
      ..addInstanceCreationExpression(this, visitor)
      ..addMethodInvocation(this, visitor);
  }
}

class _ColorVisitor extends SimpleAstVisitor<void> {
  _ColorVisitor(this.rule);

  final AnalysisRule rule;

  static final _hex = RegExp(r'^\s*#[0-9a-fA-F]{3,8}\s*$');
  static final _variable = RegExp(r'^\s*var\(\s*--');

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final c = node.constructorName;
    if (c.type.element?.name != 'Color' || c.name?.name != 'css') return;
    if (c.type.element?.library?.uri.toString().startsWith(
          'package:thor_style/',
        ) !=
        true) {
      return;
    }
    _check(node.argumentList.arguments);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    if (target is! SimpleIdentifier ||
        target.name != 'Color' ||
        node.methodName.name != 'css') {
      return;
    }
    if (target.element?.library?.uri.toString().startsWith(
          'package:thor_style/',
        ) !=
        true) {
      return;
    }
    _check(node.argumentList.arguments);
  }

  void _check(NodeList<Expression> args) {
    final first = args.firstOrNull;
    if (first is! SimpleStringLiteral) return;
    if (_hex.hasMatch(first.value) || _variable.hasMatch(first.value)) {
      rule.reportAtNode(first);
    }
  }
}
