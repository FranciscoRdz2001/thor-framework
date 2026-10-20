/// `row.text((o) => o.customer)`, `row.bindText((o) => o.customer)`,
/// `row.bind((o) => o.customer)`,
/// `row.attribute('title', (o) => o.customer, child: …)`,
/// `row.field('who', (o) => o.customer)` and
/// `row.watch((o) => o.isOffer, builder: …)` (a `bool` or enum): finding the lambdas a list row
/// binds without a method of the state per property.
///
/// The server runs the lambda to draw the row; the browser can't, so the
/// build finds the ones that only read one `String` property of the row,
/// gives the server a probe of the row's class (`registerRowProbes`) to
/// learn which, and gives the lite bundle a reader for it (`$Rows`). A
/// lambda that does more is THOR-B030. An `int`, `num`, `double` or `bool`
/// property as text (`'${o.id}'`, `o.id.toString()`) is a property path too. `row.watch` reads a `bool` or an enum
/// instead of a `String`: the probe answers it with a choice of its values.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import 'package:thor_style/errors.dart' show thorError;

/// One `row.text(lambda)`, `row.bind(lambda)`, `row.attribute(name, lambda)`
/// or `row.field(name, lambda)` of the app.
class RowLambda {
  RowLambda._(
    this.path,
    this.line,
    this.item,
    this.property,
    this.problem, [
    this.method = 'text',
    this.states,
  ]);

  /// `text`, `bindText`, `bind`, `attribute`, `field` or `watch`.
  final String method;

  /// The file, relative to the app.
  final String path;

  /// The line of the call.
  final int line;

  /// The row's class, or null when the lambda is not over a class.
  final InterfaceElement? item;

  /// The property the lambda reads, when it is a property path.
  final String? property;

  /// What is wrong with it (without the code), or null.
  final String? problem;

  /// For `watch`: how many states the property has (2 for a `bool`, the
  /// number of values of an enum); null for the `String` ones.
  final int? states;

  /// The THOR-B030 message, or null when the lambda is fine.
  String? get message => problem == null
      ? null
      : method == 'watch'
      ? thorError(
          'THOR-B030',
          '$path:$line: row.watch((o) => …) $problem. The browser can read a '
              'property of each item, it can not run a lambda. Fix: a method '
              'of the state (`bool isOfferOf(Order o) => …`) passed as '
              '`row.watch(state.isOfferOf, builder: …)`, or a lambda that only '
              'reads a bool or enum property (`(o) => o.isOffer`).',
        )
      : thorError(
          'THOR-B030',
          '$path:$line: row.$method(${_nameHint(method)}(o) => …) $problem. The browser can read a '
              'property of each item, it can not run a lambda. Fix: a method '
              'of the state (`String customerOf(Order o) => o.customer.trim()`) '
              'passed as `row.$method(${_nameHint(method)}state.customerOf)`, or a lambda that only '
              'reads a String property (`(o) => o.customer`), or an int, num, '
              'double or bool one as text (`(o) => \'\${o.id}\'` or '
              '`(o) => o.id.toString()`).',
        );
}

/// The methods whose first argument is a name, the lambda the second.
const _named = {'attribute', 'field'};

// The leading name argument of a row call: an `AttributeName` for
// `row.attribute`, a String for `row.field`.
String _nameHint(String method) => switch (method) {
  'attribute' => 'AttributeName.title, ',
  'field' => "'name', ",
  _ => '',
};

/// The `row.text`, `row.bind`, `row.attribute`, `row.field` and `row.watch`
/// calls with a
/// lambda in [unit] (shown as [path]) over a `WatchRow` (a `Watch.list` row).
List<RowLambda> rowLambdasIn(CompilationUnit unit, String path) {
  final found = <RowLambda>[];
  unit.accept(_Finder(unit, path, found));
  return found;
}

class _Finder extends RecursiveAstVisitor<void> {
  _Finder(this.unit, this.path, this.found);

  final CompilationUnit unit;
  final String path;
  final List<RowLambda> found;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);
    final method = node.methodName.name;
    if (method != 'text' &&
        method != 'bindText' &&
        method != 'bind' &&
        method != 'watch' &&
        !_named.contains(method)) {
      return;
    }
    final target = node.realTarget?.staticType;
    if (target is! InterfaceType ||
        target.element.name != 'WatchRow' ||
        !'${target.element.library.uri}'.startsWith('package:thor_ui/')) {
      return;
    }
    final args = node.argumentList.arguments;
    // `attribute('title', lambda, child: …)`, `field('who', lambda)`.
    final at = _named.contains(method) ? 1 : 0;
    if (args.length <= at || args[at] is NamedExpression) return;
    final lambda = args[at];
    // A tear-off or any other expression is a method of a state.
    if (lambda is! FunctionExpression) return;
    final line = unit.lineInfo.getLocation(node.methodName.offset).lineNumber;
    final itemType = target.typeArguments.first;
    RowLambda fail(String problem) =>
        RowLambda._(path, line, null, null, problem, method);
    if (itemType is! InterfaceType) {
      found.add(fail('is over a row that is not a class'));
      return;
    }
    final e = itemType.element;
    final reason = _notImplementable(e, itemType);
    if (reason != null) {
      found.add(fail(reason));
      return;
    }
    final List<FormalParameter> params =
        lambda.parameters?.parameters ?? const <FormalParameter>[];
    final body = lambda.body;
    if (params.length != 1 || body is! ExpressionFunctionBody) {
      found.add(fail('must be `(o) => o.property`'));
      return;
    }
    final param = params.single.declaredFragment?.element;
    Expression expression = _unparen(body.expression);
    // `(o) => '${o.id}'` and `(o) => o.id.toString()`: a number or a bool
    // property as text, still one read of one property (not for `watch`).
    var converted = false;
    if (method != 'watch') {
      final inner = _conversionOperand(expression);
      if (inner != null) {
        expression = inner;
        converted = true;
      }
    }
    final (Expression? on, SimpleIdentifier? name) = switch (expression) {
      PrefixedIdentifier(:final prefix, :final identifier) => (
        prefix,
        identifier,
      ),
      PropertyAccess(:final target, :final propertyName) => (
        target,
        propertyName,
      ),
      _ => (null, null),
    };
    if (on is! SimpleIdentifier || on.element != param || name == null) {
      found.add(
        fail(
          'does more than read one property of the row (${expression.toSource()})',
        ),
      );
      return;
    }
    final getter = name.element;
    final type = getter is PropertyAccessorElement
        ? getter.returnType
        : (getter is FieldElement ? getter.type : null);
    if (method == 'watch') {
      final states = type == null ? null : statesOf(type);
      if (states == null) {
        found.add(
          fail(
            'reads `${name.name}`, which is not a bool or a public enum '
            '(and not nullable)',
          ),
        );
        return;
      }
      found.add(RowLambda._(path, line, e, name.name, null, method, states));
      return;
    }
    if (type == null ||
        !(type.isDartCoreString &&
                !(converted &&
                    type.nullabilitySuffix == NullabilitySuffix.question) ||
            (converted && _isTextConvertible(type)))) {
      found.add(
        fail(
          converted
              ? 'reads `${name.name}`, which is not a String, an int, a num, '
                    'a double or a bool (and not nullable)'
              : 'reads `${name.name}`, which is not a String',
        ),
      );
      return;
    }
    found.add(RowLambda._(path, line, e, name.name, null, method));
  }
}

Expression _unparen(Expression e) {
  while (e is ParenthesizedExpression) {
    e = e.expression;
  }
  return e;
}

/// The `o.id` of `'${o.id}'` (no other text) or `o.id.toString()`, or null.
Expression? _conversionOperand(Expression e) {
  if (e is StringInterpolation) {
    final parts = e.elements;
    final expressions = parts.whereType<InterpolationExpression>().toList();
    final onlyThat = parts.whereType<InterpolationString>().every(
      (s) => s.value.isEmpty,
    );
    if (expressions.length == 1 && onlyThat) {
      return _unparen(expressions.single.expression);
    }
    return null;
  }
  if (e is MethodInvocation &&
      e.methodName.name == 'toString' &&
      e.argumentList.arguments.isEmpty &&
      e.target != null &&
      !e.isNullAware) {
    return _unparen(e.target!);
  }
  return null;
}

/// A non-nullable `int`, `num`, `double` or `bool`: what a probe answers
/// with a number (or the two values of a bool) whose text the lambda returns.
bool _isTextConvertible(DartType type) =>
    type.nullabilitySuffix != NullabilitySuffix.question &&
    (type.isDartCoreInt ||
        type.isDartCoreNum ||
        type.isDartCoreDouble ||
        type.isDartCoreBool);

/// How many states a row property of [type] has when it is a finite state a
/// probe can answer (a `bool`, or a public enum, never nullable), or null.
int? statesOf(DartType type) {
  if (type.nullabilitySuffix == NullabilitySuffix.question) return null;
  if (type.isDartCoreBool) return 2;
  final e = type.element;
  if (e is EnumElement && !(e.name ?? '_').startsWith('_')) {
    return e.constants.length;
  }
  return null;
}

/// Why a probe of [e] can not be written (an `implements` of it from another
/// library), or null when it can.
String? _notImplementable(InterfaceElement e, InterfaceType type) {
  if (e is! ClassElement) return 'is over a row that is not a class';
  final name = e.name ?? '';
  if (name.startsWith('_')) {
    return 'is over the private class $name (the generated probe names it from another file)';
  }
  if (e.typeParameters.isNotEmpty) {
    return 'is over the generic class $name';
  }
  if (e.isFinal || e.isSealed || e.isBase || e.isMixinClass) {
    return 'is over $name, a class the generated probe cannot implement '
        '(final, sealed or base)';
  }
  return null;
}

/// The public `String` getters of [item] (its own and inherited), which a
/// probe answers with their markers.
List<(String, bool)> stringGetters(InterfaceElement item) {
  final seen = <String>{};
  final out = <(String, bool)>[];
  for (final type in [item.thisType, ...item.allSupertypes]) {
    if (type.element.name == 'Object') continue;
    for (final getter in type.element.getters) {
      final n = getter.name;
      if (n == null || n.startsWith('_') || getter.isStatic || !seen.add(n)) {
        continue;
      }
      final rt = getter.returnType;
      if (rt.isDartCoreString) {
        out.add((n, rt.nullabilitySuffix == NullabilitySuffix.question));
      }
    }
  }
  return out;
}

/// The public non-nullable `int`, `num` and `double` getters of [item] (its
/// own and inherited), which a probe answers with a number
/// (`row.text((o) => '${o.id}')`): the name and the type's name.
List<(String, String)> numberGetters(InterfaceElement item) {
  final seen = <String>{};
  final out = <(String, String)>[];
  for (final type in [item.thisType, ...item.allSupertypes]) {
    if (type.element.name == 'Object') continue;
    for (final getter in type.element.getters) {
      final n = getter.name;
      if (n == null || n.startsWith('_') || getter.isStatic || !seen.add(n)) {
        continue;
      }
      final rt = getter.returnType;
      if (rt.nullabilitySuffix == NullabilitySuffix.question) continue;
      if (rt.isDartCoreInt) out.add((n, 'int'));
      if (rt.isDartCoreNum) out.add((n, 'num'));
      if (rt.isDartCoreDouble) out.add((n, 'double'));
    }
  }
  return out;
}

/// The public `bool` and enum getters of [item] (its own and inherited) a
/// probe answers with a choice of their values: the name, and the enum (null
/// for a `bool`).
List<(String, EnumElement?)> stateGetters(InterfaceElement item) {
  final seen = <String>{};
  final out = <(String, EnumElement?)>[];
  for (final type in [item.thisType, ...item.allSupertypes]) {
    if (type.element.name == 'Object') continue;
    for (final getter in type.element.getters) {
      final n = getter.name;
      if (n == null || n.startsWith('_') || getter.isStatic || !seen.add(n)) {
        continue;
      }
      final rt = getter.returnType;
      if (statesOf(rt) == null) continue;
      out.add((n, rt.isDartCoreBool ? null : rt.element as EnumElement));
    }
  }
  return out;
}
