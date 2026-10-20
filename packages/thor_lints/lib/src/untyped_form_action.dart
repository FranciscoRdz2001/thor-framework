import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'errors.dart';

/// `untyped_form_action`: a form action named by a string or passed as a
/// closure.
///
/// An action is a method of the page, passed by its tear-off
/// (`Form(schema: S.schema, onValid: send)`, `FilledButton(onPost:
/// delete)`): the compiler checks it exists and takes the form's values,
/// and thor finds its name. A `'?/send'` string is not checked (a typo is a
/// 404 at run time) and a closure has no name the server can call
/// (THOR-P020 when the page renders).
class UntypedFormAction extends AnalysisRule {
  /// The diagnostic reported on the argument.
  static const DiagnosticCode code = LintCode(
    'untyped_form_action',
    '{0}',
    correctionMessage: '{1}',
    uniqueName: 'LintCode.untyped_form_action',
  );

  /// Creates the rule.
  UntypedFormAction()
    : super(
        name: 'untyped_form_action',
        description:
            "A form posts to a page's action method by its tear-off, not a "
            "'?/name' string or a closure.",
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    for (final arg in node.argumentList.arguments) {
      if (arg is! NamedExpression) continue;
      final name = arg.name.label.name;
      final value = arg.expression;
      if ((name == 'action' || name == 'formAction') &&
          value is StringLiteral &&
          value.toSource().contains('?/')) {
        rule.reportAtNode(
          value,
          arguments: [
            "'$name:' names a form action with a string: nothing checks the "
                'method exists or what it receives.',
            'Write the action as a method of the page and pass it: '
                '`onValid: send` (with `schema:`) or `onPost: send`.',
          ],
        );
      } else if ((name == 'onPost' || name == 'onValid') &&
          value is FunctionExpression) {
        rule.reportAtNode(
          value,
          arguments: [
            "'$name:' gets a closure: the server calls a page's action "
                'method by its name, and a closure has none '
                '(THOR-P020 · ${errorsUrl}THOR-P020).',
            "Move the code into a public method of the page and pass it "
                '(`$name: send`).',
          ],
        );
      }
    }
  }
}
