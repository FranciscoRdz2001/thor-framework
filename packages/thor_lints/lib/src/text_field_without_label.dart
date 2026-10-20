import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// `text_field_without_label`: a `TextField` or `TextFormField` a screen
/// reader announces with no name (THOR-L004).
///
/// thor names the `<input>` from `InputDecoration.labelText` (or, with no
/// label, `hintText`) as `aria-label`. A `Text('Name')` written beside the
/// field is not linked to it, so the field is just "edit text". A
/// `Semantics(label:)` around it, an `aria-label`/`aria-labelledby`/`title`
/// in `inputAttributes`, or a decoration that comes from a variable (not
/// known here) also name it.
class TextFieldWithoutLabel extends AnalysisRule {
  /// The diagnostic reported on the field's constructor.
  static const DiagnosticCode code = LintCode(
    'text_field_without_label',
    'This text field has no accessible name: a screen reader announces just '
        '"edit text" (THOR-L004).',
    correctionMessage:
        "Add `decoration: InputDecoration(labelText: 'Name')` (or `hintText:`),"
        ' or wrap it in `Semantics(label:)`. A `Text` beside it names nothing.',
    uniqueName: 'LintCode.text_field_without_label',
  );

  /// Creates the rule.
  TextFieldWithoutLabel()
    : super(
        name: 'text_field_without_label',
        description:
            'A text field needs a labelText, a hintText or a Semantics label.',
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
    if (type != 'TextField' && type != 'TextFormField') return;
    for (final arg in node.argumentList.arguments) {
      if (arg is! NamedExpression) continue;
      final value = arg.expression;
      switch (arg.name.label.name) {
        case 'decoration':
          if (_decorationNames(value)) return;
        case 'inputAttributes':
          if (_attributesName(value)) return;
      }
    }
    if (_namedByAncestor(node)) return;
    rule.reportAtNode(node.constructorName);
  }

  /// Whether the decoration may name the field: it has a non-empty
  /// `labelText`/`hintText`, or it is not written here (a variable).
  static bool _decorationNames(Expression e) {
    if (e is NullLiteral) return false;
    if (e is! InstanceCreationExpression) return true;
    for (final a in e.argumentList.arguments) {
      if (a is NamedExpression &&
          (a.name.label.name == 'labelText' ||
              a.name.label.name == 'hintText' ||
              a.name.label.name == 'label') &&
          a.expression.namesSomething) {
        return true;
      }
    }
    return false;
  }

  /// Whether `inputAttributes` may name it: an `aria-label`,
  /// `aria-labelledby` or `title` key, or a map not written here.
  static bool _attributesName(Expression e) {
    if (e is! SetOrMapLiteral) return true;
    for (final el in e.elements) {
      if (el is! MapLiteralEntry) return true;
      final key = el.key;
      if (key is! SimpleStringLiteral) return true;
      if (const {
        'aria-label',
        'aria-labelledby',
        'title',
      }.contains(key.value)) {
        return true;
      }
    }
    return false;
  }

  /// A `Semantics(label: …)` around the field.
  static bool _namedByAncestor(AstNode node) {
    for (
      AstNode? p = node.parent;
      p != null && p is! FunctionBody && p is! Declaration;
      p = p.parent
    ) {
      if (p is! InstanceCreationExpression ||
          p.constructorName.type.name.lexeme != 'Semantics') {
        continue;
      }
      if (p.argumentList.arguments.any(
        (a) =>
            a is NamedExpression &&
            a.name.label.name == 'label' &&
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
          (this as SimpleStringLiteral).value.trim().isEmpty);
}
