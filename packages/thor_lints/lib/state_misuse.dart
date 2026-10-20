/// Misuses of a `ThorState` that the browser can't run (THOR-S001,
/// THOR-S011, THOR-S012), found in a resolved unit.
///
/// A widget's code runs once, on the server; in the browser only a
/// `ThorState`'s own members exist. A closure handed to a widget is not
/// translated: a button whose `onPressed` is `() { counter.decrement(); }`
/// renders with no event and does nothing. The same detection feeds the
/// editor (the `state_misuse` rule of this plugin) and the code generation
/// of `thor dev` / `thor build` (thor_builder).
///
/// Pure analyzer: no `analysis_server_plugin` import, so other packages can
/// use it.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// One misuse: [code] at [offset]/[length] of the unit.
class StateMisuse {
  /// A misuse.
  StateMisuse(
    this.code,
    this.node, {
    required this.message,
    required this.correction,
    this.replacement,
    this.warning = false,
  });

  /// `THOR-S001`, `THOR-S011` or `THOR-S012`.
  final String code;

  /// The flagged node (the closure, or the instance creation).
  final AstNode node;

  /// Where it starts in the unit.
  int get offset => node.offset;

  /// Its length.
  int get length => node.length;

  /// What is wrong.
  final String message;

  /// How to fix it.
  final String correction;

  /// The code that replaces [node] when the fix is mechanical (a closure
  /// that is one call of a state method: `counter.increment`,
  /// `todos.remove.withArg(id)`), null otherwise.
  final String? replacement;

  /// Whether it is only a warning: the app still works, and shows stale
  /// data (`thor dev` lists it, `thor build` doesn't stop). An error is code
  /// that does nothing in the browser.
  final bool warning;

  @override
  String toString() => '$code: $message $correction';
}

/// The misuses of `ThorState` in [unit] (resolved). THOR-S012 is checked
/// only in the app's code (files under `lib/`): a test may create a state
/// wherever it needs one.
List<StateMisuse> findStateMisuses(CompilationUnit unit) {
  final visitor = _Finder(inLib: isAppLib(unit));
  unit.accept(visitor);
  return visitor.found;
}

/// Whether [unit] is the app's code (a file under `lib/`, not a test, a
/// script or an example): the checks that would be noise in a test skip the
/// rest.
bool isAppLib(CompilationUnit unit) {
  final path = unit.declaredFragment?.source.fullName ?? '';
  // The innermost of lib/, test/, bin/… decides (an app may live under a
  // folder named lib).
  final lib = path.lastIndexOf('/lib/');
  final other = [
    for (final folder in const ['/test/', '/bin/', '/tool/', '/example/'])
      path.lastIndexOf(folder),
  ].fold(-1, (a, b) => a > b ? a : b);
  return lib >= 0 && lib > other;
}

/// The mechanical replacement of the callback [closure], if it is one
/// call of a state method (see [StateMisuse.replacement]).
String? stateCallbackReplacement(FunctionExpression closure) =>
    _singleCall(closure)?.$2;

/// Whether [type] is a `ThorState` or a subtype.
bool isThorState(DartType? type) =>
    type is InterfaceType &&
    (type.element.name == 'ThorState' ||
        type.allSupertypes.any((t) => t.element.name == 'ThorState'));

bool _isWidget(DartType? type) =>
    type is InterfaceType &&
    type.allSupertypes.any((t) => t.element.name == 'Widget');

/// Whether [type] is `Widget` or a subtype.
bool isWidgetType(DartType? type) =>
    type is InterfaceType && (type.element.name == 'Widget' || _isWidget(type));

/// An event handler: a parameter of function type that returns nothing.
bool isCallbackType(DartType? type) => _isCallback(type);

/// An event handler: a parameter of function type that returns nothing.
bool _isCallback(DartType? type) {
  if (type is! FunctionType) return false;
  final r = type.returnType;
  if (r is VoidType) return true;
  // `Future<void> Function()` / `FutureOr<void> Function()`.
  return r is InterfaceType &&
      (r.isDartAsyncFuture || r.isDartAsyncFutureOr) &&
      r.typeArguments.length == 1 &&
      r.typeArguments.single is VoidType;
}

class _Finder extends RecursiveAstVisitor<void> {
  _Finder({required this.inLib});

  final bool inLib;
  final found = <StateMisuse>[];

  /// Inside a ThorState's own class: its closures run in the browser.
  int _inState = 0;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final inState = isThorState(node.declaredFragment?.element.thisType);
    if (inState) _inState++;
    super.visitClassDeclaration(node);
    if (inState) _inState--;
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final type = node.staticType;
    if (inLib && isThorState(type) && !_topLevelInitializer(node)) {
      final name = type!.element?.name ?? 'the state';
      found.add(
        StateMisuse(
          'THOR-S012',
          node,
          message:
              'A $name created here is not the one the browser runs: the '
              'page engine only finds the states declared at the top level '
              'of a file.',
          correction:
              'Declare it once at the top level of a file, next to its '
              'class (`final ${_lower(name)} = $name();`), and use that '
              'variable.',
        ),
      );
    }
    if (_inState == 0 && _isWidget(type)) _checkArguments(node);
    super.visitInstanceCreationExpression(node);
  }

  // `Watch.list(…)` and a list row's `row.text(…)` / `row.attribute(…)` are
  // method calls, not constructors: their source is a member of the state
  // too (the browser has no function to run for a closure).
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_inState == 0) {
      final target = node.realTarget;
      final name = node.methodName.name;
      final List<Expression> sources;
      final String what;
      if (name == 'list' &&
          target is Identifier &&
          target.element?.name == 'Watch') {
        // The source is the first argument; `each:` bodies are visited on
        // their own.
        final args = node.argumentList.arguments;
        sources = [
          if (args.isNotEmpty && args.first is! NamedExpression) args.first,
        ];
        what = 'Watch.list';
      } else if ((name == 'text' || name == 'attribute') &&
          const {
            'WatchRow',
            'WatchItem',
          }.contains(target?.staticType?.element?.name)) {
        sources = [
          for (final a in node.argumentList.arguments)
            if (a is! NamedExpression) a,
        ];
        what = 'row.$name';
      } else {
        sources = const [];
        what = '';
      }
      for (final value in sources) {
        if (value is! FunctionExpression || !_touchesState(value)) continue;
        found.add(
          StateMisuse(
            'THOR-S001',
            value,
            message:
                '$what needs a field or method of a ThorState as its '
                'source: the browser has no function to run for a closure.',
            correction:
                'Pass a method of the state '
                '(`$what(…, counterState.label)`).',
            replacement: _singleCall(value)?.$2,
          ),
        );
      }
    }
    super.visitMethodInvocation(node);
  }

  void _checkArguments(InstanceCreationExpression node) {
    final args = node.argumentList.arguments;
    final isWatch = node.constructorName.type.name.lexeme == 'Watch';
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      final value = arg is NamedExpression ? arg.expression : arg;
      if (value is! FunctionExpression) continue;
      if (isWatch && i == 0 && arg is! NamedExpression) {
        if (_touchesState(value)) {
          found.add(
            StateMisuse(
              'THOR-S001',
              value,
              message:
                  'Watch needs a field or method of a ThorState as its '
                  'source: the browser has no function to run for a '
                  'closure.',
              correction:
                  'Pass a field or method of the state '
                  '(`Watch(counterState.label)`).',
              replacement: _singleCall(value)?.$2,
            ),
          );
        }
        continue;
      }
      final parameter = arg.correspondingParameter;
      if (parameter == null || !_isCallback(parameter.type)) continue;
      if (!_touchesState(value)) continue;
      final single = _singleCall(value);
      final name = parameter.name ?? 'the callback';
      found.add(
        StateMisuse(
          'THOR-S011',
          value,
          message:
              "The closure passed to '$name' uses a ThorState, and the "
              "browser can't run a function: the element gets no event and "
              'does nothing.',
          correction: single != null
              ? 'Pass `${single.$2}`.'
              : 'Move this into a method of the state and pass it '
                    '(`onPressed: counter.reset`).',
          replacement: single?.$2,
        ),
      );
    }
  }
}

bool _topLevelInitializer(InstanceCreationExpression node) {
  final parent = node.parent;
  return parent is VariableDeclaration &&
      parent.initializer == node &&
      parent.parent?.parent is TopLevelVariableDeclaration;
}

String _lower(String name) {
  final base = name.endsWith('State') && name.length > 5
      ? name.substring(0, name.length - 5)
      : name;
  return base[0].toLowerCase() + base.substring(1);
}

/// Whether [closure] invokes or reads a member of a `ThorState`.
bool _touchesState(FunctionExpression closure) {
  final finder = _StateUse();
  closure.body.accept(finder);
  return finder.found;
}

class _StateUse extends RecursiveAstVisitor<void> {
  var found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (isThorState(node.realTarget?.staticType)) found = true;
    super.visitMethodInvocation(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (isThorState(node.realTarget.staticType)) found = true;
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (isThorState(node.prefix.staticType)) found = true;
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // A tear-off inside the closure (`() => run(counter.inc)`) is covered
    // by the prefixed forms; a bare state variable used as a value too.
    if (node.parent is! PrefixedIdentifier &&
        node.element is! InterfaceElement &&
        isThorState(node.staticType)) {
      found = true;
    }
    super.visitSimpleIdentifier(node);
  }
}

/// `(call, replacement)` when [closure]'s body is exactly one call of a
/// state method: `x.m()` → `x.m`, `x.m(a)` → `x.m.withArg(a)`, and a call
/// that passes the closure's parameters through (`(v) => x.m(v)`) → `x.m`.
(MethodInvocation, String)? _singleCall(FunctionExpression closure) {
  final body = closure.body;
  Expression? expression;
  if (body is ExpressionFunctionBody) {
    expression = body.expression;
  } else if (body is BlockFunctionBody) {
    final statements = body.block.statements;
    if (statements.length == 1 && statements.single is ExpressionStatement) {
      expression = (statements.single as ExpressionStatement).expression;
    }
  }
  if (expression is! MethodInvocation) return null;
  final target = expression.realTarget;
  if (target == null || !isThorState(target.staticType)) return null;
  if (expression.isNullAware || expression.typeArguments != null) return null;
  final member = '${target.toSource()}.${expression.methodName.name}';
  final args = expression.argumentList.arguments;
  if (args.any((a) => a is NamedExpression)) return null;
  final params = [
    for (final p in closure.parameters?.parameters ?? <FormalParameter>[])
      p.name?.lexeme,
  ];
  bool passes(int from) {
    for (var i = 0; i < params.length; i++) {
      final a = args[from + i];
      if (a is! SimpleIdentifier || a.name != params[i]) return false;
    }
    return true;
  }

  bool usesParams(Expression e) {
    final names = params.whereType<String>().toSet();
    var uses = false;
    e.accept(_Names((n) => uses = uses || names.contains(n)));
    return uses;
  }

  if (args.length == params.length && passes(0)) {
    return (expression, member);
  }
  if (args.length == params.length + 1 &&
      passes(1) &&
      !usesParams(args.first)) {
    return (expression, '$member.withArg(${args.first.toSource()})');
  }
  return null;
}

class _Names extends RecursiveAstVisitor<void> {
  _Names(this.onName);

  final void Function(String) onName;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) => onName(node.name);
}
