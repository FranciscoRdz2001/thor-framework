import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// `avoid_raw_css`: CSS written as strings (`StyleProps(raw: {...})`,
/// `css('.x').styles(raw: {...})`) where a typed
/// value exists: `StyleProps`, `TextStyle`, `BoxDecoration`, `Length`
/// (`16.px`), `BoxPosition`, `Overflow`… and `.props(StyleProps(...))` in
/// stylesheets.
///
/// Strings skip the types' checks (a typo is silently dropped by the
/// browser) and the sanitizing of values. When no type covers a property,
/// keep the string and say why, with
/// `// ignore: thor_lints/avoid_raw_css` under a comment with the reason.
class AvoidRawCss extends AnalysisRule {
  /// The diagnostic reported on the argument.
  static const LintCode code = LintCode(
    'avoid_raw_css',
    'CSS written as strings.',
    correctionMessage:
        'Use typed values: StyleProps(...), TextStyle, BoxDecoration, '
        'Length (16.px), BoxPosition, Overflow; .props(StyleProps(...)) '
        'in a stylesheet. If no type covers it, ignore with the reason.',
    uniqueName: 'LintCode.avoid_raw_css',
  );

  /// Creates the rule.
  AvoidRawCss()
    : super(
        name: 'avoid_raw_css',
        description:
            'Prefer typed style values over CSS declarations written as '
            'strings.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    // The framework itself turns the types into CSS: it is the one place
    // strings belong.
    final uri = context.libraryElement?.uri.toString() ?? '';
    if (_framework.any(uri.startsWith)) return;
    registry.addNamedExpression(this, _Visitor(this));
  }

  static const _framework = [
    'package:thor_ui/',
    'package:thor_style/',
    'package:thor_engine/',
    'package:thor_server/',
  ];
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitNamedExpression(NamedExpression node) {
    final name = node.name.label.name;
    if (name != 'raw') return;
    final value = node.expression;
    // Only literal declarations: a map passed along (a variable, a
    // parameter) is somebody else's decision.
    if (value is! SetOrMapLiteral || value.elements.isEmpty) return;
    final call = node.parent?.parent;
    final (target, library) = switch (call) {
      InstanceCreationExpression(:final constructorName) => (
        constructorName.type.element?.name,
        constructorName.type.element?.library?.uri.toString(),
      ),
      MethodInvocation(:final methodName) => (
        methodName.name,
        methodName.element?.library?.uri.toString(),
      ),
      _ => (null, null),
    };
    if (target == null || library == null) return;
    final flagged = switch ((target, name)) {
      ('StyleProps', 'raw') => library.startsWith('package:thor_ui/'),
      // `css('.x').styles(raw: …)`.
      ('styles', 'raw') => true,
      _ => false,
    };
    if (flagged) rule.reportAtNode(node);
  }
}
