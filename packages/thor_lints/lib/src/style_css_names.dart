import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import 'errors.dart';

/// `style_css_names`: an argument of the web layer's `Style` that is not a
/// CSS property (a Flutter name, a typo) or that carries a Flutter value
/// where `Style` wants the CSS one (`padding: EdgeInsets.all(16)`).
///
/// `Style` speaks CSS: every parameter is a CSS property in camelCase and
/// takes one CSS value. The compiler only says "no named parameter" or
/// "can't be assigned"; this names the property or the value to write.
class StyleCssNames extends AnalysisRule {
  /// The diagnostic reported on the argument.
  static const DiagnosticCode code = LintCode(
    'style_css_names',
    "'{0}' is not how Style says it "
        '(THOR-R018 · ${errorsUrl}THOR-R018).',
    correctionMessage: '{1}',
    uniqueName: 'LintCode.style_css_names',
  );

  /// Creates the rule.
  StyleCssNames()
    : super(
        name: 'style_css_names',
        description:
            "Write Style's arguments with CSS names and CSS values, not "
            "Flutter's.",
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

/// Names a model brings from Flutter or other CSS-in-JS APIs, and what
/// `Style` calls them.
const _renamed = {
  'background': 'backgroundColor',
  'bgColor': 'backgroundColor',
  'textColor': 'color',
  'foregroundColor': 'color',
  'radius': 'borderRadius',
  'elevation': 'boxShadow',
  'shadow': 'boxShadow',
  'spacing': 'gap',
  'mainAxisAlignment': 'justifyContent',
  'crossAxisAlignment': 'alignItems',
  'direction': 'flexDirection',
  'wrap': 'flexWrap',
  'alignment': 'placeItems (or alignItems + justifyContent)',
  'decoration': 'backgroundColor, border, borderRadius and boxShadow',
  'textStyle': 'fontSize, fontWeight, lineHeight and color',
  'fontColor': 'color',
  'underline': 'textDecoration: TextDecoration.underline',
  'weight': 'fontWeight',
  'size': 'width and height',
  'constraints': 'minWidth, maxWidth, minHeight and maxHeight',
  'paddingHorizontal': 'paddingInline',
  'paddingVertical': 'paddingBlock',
  'marginHorizontal': 'marginInline',
  'marginVertical': 'marginBlock',
  'paddingX': 'paddingInline',
  'paddingY': 'paddingBlock',
  'marginX': 'marginInline',
  'marginY': 'marginBlock',
  'zindex': 'zIndex',
};

/// Flutter types a model passes where `Style` wants a CSS value.
const _flutterValues = {
  'EdgeInsets':
      'one Length (Length.px(16)); per side: paddingInline, '
      'paddingBlock, paddingTop… (or the Flutter Padding widget)',
  'EdgeInsetsDirectional': 'paddingInline/paddingBlock with a Length',
  'BorderRadius': 'one Length: borderRadius: Length.px(12)',
  'BoxPosition': 'position: Position.absolute with top:, left:…',
  'MainAxisAlignment': 'JustifyContent (flexStart, center, spaceBetween…)',
  'CrossAxisAlignment': 'AlignItems (flexStart, center, stretch…)',
  'Axis': 'flexDirection: FlexDirection.row or .column',
  'TextStyle': 'fontSize, fontWeight, lineHeight, color…',
  'BoxDecoration': 'backgroundColor, border, borderRadius, boxShadow',
  'double': 'a Length: Length.px(n) (or n.px outside a const)',
  'int': 'a Length: Length.px(n) (or n.px outside a const)',
};

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final type = node.constructorName.type.element;
    if (type is! ClassElement || type.name != 'Style') return;
    // Only the CSS constructor (`Style.declarations` takes compiled CSS).
    if (node.constructorName.name != null) return;
    if (!(type.library.uri.toString().startsWith('package:thor_ui/'))) {
      return;
    }
    final params = <String, FormalParameterElement>{
      for (final p
          in type.unnamedConstructor?.formalParameters ??
              const <FormalParameterElement>[])
        if (p.isNamed && p.name != null) p.name!: p,
    };
    for (final arg in node.argumentList.arguments) {
      if (arg is! NamedExpression) continue;
      final name = arg.name.label.name;
      final param = params[name];
      if (param == null) {
        final better = _renamed[name] ?? _closest(name, params.keys);
        rule.reportAtNode(
          arg.name.label,
          arguments: [
            name,
            better == null
                ? 'Style has the CSS properties in camelCase.'
                : 'Write $better.',
          ],
        );
        continue;
      }
      // A Length/enum parameter given a Flutter value (or a bare number).
      final given = arg.expression.staticType?.element?.name;
      final wanted = param.type.element?.name;
      if (given == null || wanted == null || given == wanted) continue;
      if (_flutterValues[given] case final hint?) {
        if (given == 'double' || given == 'int') {
          if (wanted != 'Length') continue;
        }
        rule.reportAtNode(
          arg.expression,
          arguments: ['$name: $given', '$name takes $hint.'],
        );
      }
    }
  }
}

/// The name in [names] at the smallest edit distance from [name], if it
/// is close enough to be the one meant.
String? _closest(String name, Iterable<String> names) {
  String? best;
  var bestDistance = 1 << 30;
  final lower = name.toLowerCase();
  for (final n in names) {
    final d = _distance(lower, n.toLowerCase());
    if (d < bestDistance) (best, bestDistance) = (n, d);
  }
  return bestDistance <= (name.length / 3).ceil() ? best : null;
}

int _distance(String a, String b) {
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = [i, ...List<int>.filled(b.length, 0)];
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      current[j] = [
        previous[j] + 1,
        current[j - 1] + 1,
        previous[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    previous = current;
  }
  return previous[b.length];
}
