import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// `icon_button_without_name`: an `IconButton` (or icon-only
/// `FloatingActionButton`) that a screen reader cannot name.
///
/// An icon is decorative (`aria-hidden`), so a button that holds only an
/// icon is announced as "button" with nothing else. Flutter's `tooltip:`
/// is the accessible name (thor writes it as `aria-label`); an `Icon` with a
/// `semanticLabel:`, a text child or a `Semantics(label:)` / `Tooltip(...)`
/// around the button also name it. Only an `Icon(...)` written right there
/// with no label is reported: an icon that comes from a variable or another
/// widget may be named where it is built.
class IconButtonWithoutName extends AnalysisRule {
  /// The diagnostic reported on the button's constructor.
  static const DiagnosticCode code = LintCode(
    'icon_button_without_name',
    'This icon button has no accessible name: a screen reader announces just '
        '"button".',
    correctionMessage:
        "Add `tooltip: 'What it does'` (it becomes the button's `aria-label`).",
    uniqueName: 'LintCode.icon_button_without_name',
  );

  /// Creates the rule.
  IconButtonWithoutName()
    : super(
        name: 'icon_button_without_name',
        description:
            'An icon button needs a tooltip (or a labelled icon): its icon '
            'is decorative.',
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
    final type = node.constructorName.type.name.lexeme;
    final ctor = node.constructorName.name?.name;
    // The widget's content that must name it: the icon of an IconButton, the
    // child of a FloatingActionButton (`.extended` has a label).
    final String contentArg;
    if (type == 'IconButton') {
      contentArg = 'icon';
    } else if (type == 'FloatingActionButton' && ctor != 'extended') {
      contentArg = 'child';
    } else {
      return;
    }
    Expression? content;
    for (final arg in node.argumentList.arguments) {
      if (arg is! NamedExpression) continue;
      final name = arg.name.label.name;
      // A tooltip that is not the literal null or '' names it.
      if (name == 'tooltip' && arg.expression.namesSomething) return;
      if (name == contentArg) content = arg.expression;
    }
    if (content == null || !_isUnlabelledIcon(content)) return;
    if (_namedByAncestor(node)) return;
    rule.reportAtNode(node.constructorName);
  }

  /// `Icon(Icons.x)` written here, without `semanticLabel:`.
  static bool _isUnlabelledIcon(Expression e) {
    if (e is! InstanceCreationExpression ||
        e.constructorName.type.name.lexeme != 'Icon') {
      return false;
    }
    return !e.argumentList.arguments.any(
      (a) =>
          a is NamedExpression &&
          a.name.label.name == 'semanticLabel' &&
          a.expression.namesSomething,
    );
  }

  /// A `Semantics(label: …)` or `Tooltip(message: …)` around the button.
  static bool _namedByAncestor(AstNode node) {
    for (
      AstNode? p = node.parent;
      p != null && p is! FunctionBody && p is! Declaration;
      p = p.parent
    ) {
      if (p is! InstanceCreationExpression) continue;
      final name = p.constructorName.type.name.lexeme;
      final arg = switch (name) {
        'Semantics' => 'label',
        'Tooltip' => 'message',
        _ => null,
      };
      if (arg != null &&
          p.argumentList.arguments.any(
            (a) =>
                a is NamedExpression &&
                a.name.label.name == arg &&
                a.expression.namesSomething,
          )) {
        return true;
      }
    }
    return false;
  }
}

extension on Expression {
  /// Not the literal `null` nor `''`: what a variable holds is not known,
  /// so it counts as a name.
  bool get namesSomething =>
      this is! NullLiteral &&
      !(this is SimpleStringLiteral &&
          (this as SimpleStringLiteral).value.isEmpty);
}
