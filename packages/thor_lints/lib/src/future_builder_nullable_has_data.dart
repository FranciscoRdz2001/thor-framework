import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

/// `future_builder_nullable_has_data`: a `FutureBuilder<T?>` whose builder
/// tells "waiting" from "done" only with `snapshot.hasData` (THOR-R033).
///
/// `hasData` is `false` when the future completes with `null` (Flutter's
/// own meaning), so a builder like `snapshot.hasData ? Card(...) :
/// Skeleton()` keeps the skeleton forever when the future answers `null`
/// ("no such product"). With a nullable `T` the builder has to look at
/// `snapshot.connectionState == ConnectionState.done`.
///
/// Not reported when the builder reads `connectionState`, when it never
/// reads `hasData`, or when it hands the snapshot to another function
/// (nothing is known about what that does).
class FutureBuilderNullableHasData extends AnalysisRule {
  /// The diagnostic reported on the `hasData` read.
  static const DiagnosticCode code = LintCode(
    'future_builder_nullable_has_data',
    "This FutureBuilder's future can complete with null, and 'hasData' is "
        'false then: the builder draws the waiting branch forever '
        '(THOR-R033).',
    correctionMessage:
        "Tell done from waiting with 'snapshot.connectionState == "
        "ConnectionState.done' and read 'hasData' inside it.",
    uniqueName: 'LintCode.future_builder_nullable_has_data',
  );

  /// Creates the rule.
  FutureBuilderNullableHasData()
    : super(
        name: 'future_builder_nullable_has_data',
        description:
            'A FutureBuilder<T?> needs connectionState, not only hasData, to '
            'tell a done null from a future still waiting.',
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
    final type = node.staticType;
    if (type is! InterfaceType ||
        type.element.name != 'FutureBuilder' ||
        type.typeArguments.length != 1 ||
        type.typeArguments.single.nullabilitySuffix !=
            NullabilitySuffix.question) {
      return;
    }
    for (final arg in node.argumentList.arguments) {
      if (arg is! NamedExpression || arg.name.label.name != 'builder') {
        continue;
      }
      final fn = arg.expression;
      if (fn is! FunctionExpression) continue;
      final params = fn.parameters?.parameters ?? const <FormalParameter>[];
      if (params.length < 2) continue;
      final name = params[1].name?.lexeme;
      if (name == null || name == '_') continue;
      final reads = _Reads(name);
      fn.body.accept(reads);
      if (reads.escapes || reads.connectionState) continue;
      final first = reads.hasData.firstOrNull;
      if (first != null) rule.reportAtNode(first);
    }
  }
}

/// How a builder uses its snapshot: the `hasData` reads, whether it reads
/// `connectionState`, and whether the snapshot goes anywhere else (as an
/// argument, assigned): then it is not judged.
class _Reads extends RecursiveAstVisitor<void> {
  _Reads(this.snapshot);

  final String snapshot;
  final hasData = <AstNode>[];
  var connectionState = false;
  var escapes = false;

  void _property(AstNode node, String property) {
    if (property == 'hasData') hasData.add(node);
    if (property == 'connectionState') connectionState = true;
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.name == snapshot) {
      _property(node, node.identifier.name);
      // The prefix is a use that is not an escape: skip it.
      return;
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final target = node.target;
    if (target is SimpleIdentifier && target.name == snapshot) {
      _property(node, node.propertyName.name);
      return;
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // Any other mention of the snapshot (an argument, a method call, `==`)
    // may do what the rule looks for, out of sight.
    if (node.name == snapshot && !node.inDeclarationContext()) escapes = true;
  }
}
