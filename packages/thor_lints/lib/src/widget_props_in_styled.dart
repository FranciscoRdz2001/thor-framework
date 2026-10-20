import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// `widget_props_in_styled`: `Styled(style: StyleProps(...))` setting a
/// value that a Flutter widget already sets (`padding` → `Padding`,
/// `decoration` → `Container`…).
///
/// `Styled` is for what widgets can't express: web-only values (sticky,
/// overflow, cursor, web units) and plain numbers that vary with `.when()`
/// (a `double` can't carry variants). Everything else goes through the
/// widget, so a thor page keeps Flutter's structure.
class WidgetPropsInStyled extends AnalysisRule {
  /// The diagnostic reported on the value.
  static const DiagnosticCode code = LintCode(
    'widget_props_in_styled',
    "'{0}' is set by a Flutter widget, not by Styled.",
    correctionMessage:
        'Use {1}. Styled(style:) is for web-only values and numbers that '
        'vary with .when().',
    uniqueName: 'LintCode.widget_props_in_styled',
  );

  /// Creates the rule.
  WidgetPropsInStyled()
    : super(
        name: 'widget_props_in_styled',
        description:
            'Style through the Flutter widget that owns the value, not '
            'through Styled.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final uri = context.libraryElement?.uri.toString() ?? '';
    if (uri.startsWith('package:thor_ui/')) return;
    registry.addInstanceCreationExpression(this, _Visitor(this));
  }
}

/// Values a widget owns, always.
const _widgetOwned = {
  'padding': 'Padding(padding:)',
  'margin': 'Container(margin:)',
  'constraints': 'ConstrainedBox(constraints:)',
  'color': 'Container(color:) or DecoratedBox',
  'decoration': 'Container(decoration:) or DecoratedBox',
  'textStyle': 'Text(style:) or DefaultTextStyle',
};

/// Plain values a widget owns unless they vary with `.when()`.
const _staticNumbers = {
  'width': 'SizedBox(width:)',
  'height': 'SizedBox(height:)',
  'opacity': 'Opacity(opacity:)',
  'scale': 'Transform.scale',
  'offset': 'Transform.translate',
  'turns': 'Transform.rotate',
  'widthFactor': 'FractionallySizedBox(widthFactor:)',
  'heightFactor': 'FractionallySizedBox(heightFactor:)',
  'offstage': 'Offstage(offstage:)',
};

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final type = node.constructorName.type.element;
    if (type?.name != 'Styled' ||
        !(type?.library?.uri.toString().startsWith('package:thor_ui/') ??
            false)) {
      return;
    }
    for (final arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'style') {
        _check(arg.expression);
      }
    }
  }

  /// [style] is `StyleProps(...)`, or `StyleProps(...).when(...)`.
  void _check(Expression style) {
    final parts = <InstanceCreationExpression>[];
    var varies = false;
    void collect(Expression e) {
      if (e is InstanceCreationExpression &&
          e.constructorName.type.element?.name == 'StyleProps') {
        parts.add(e);
      } else if (e is MethodInvocation && e.methodName.name == 'when') {
        varies = true;
        if (e.target case final target?) collect(target);
        for (final a in e.argumentList.arguments) {
          if (a is NamedExpression) collect(a.expression);
        }
      } else if (e is NamedExpression) {
        collect(e.expression);
      }
    }

    collect(style);
    for (final props in parts) {
      for (final a in props.argumentList.arguments) {
        if (a is! NamedExpression) continue;
        final name = a.name.label.name;
        final widget =
            _widgetOwned[name] ?? (varies ? null : _staticNumbers[name]);
        if (widget != null) {
          rule.reportAtNode(a, arguments: [name, widget]);
        }
      }
    }
  }
}
