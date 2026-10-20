/// Code that compiles, looks right and does nothing in the browser
/// (THOR-S014 and the ones that follow), found in a resolved unit.
library;

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import 'state_misuse.dart';

/// A `derived(...)` that writes a field (THOR-B035): the function runs when
/// something reads the result, in the middle of a render or an update, so a
/// write there makes the page depend on who read first. Reported: an
/// assignment, `++`/`--`, `update`, `toggle` or a set's `add`/`remove`/
/// `clear` on a signal inside the function. Only the app's `lib/`.
List<StateMisuse> findDerivedWrites(CompilationUnit unit) {
  if (!isAppLib(unit)) return const [];
  final finder = _DerivedFinder();
  unit.accept(finder);
  return finder.found;
}

class _DerivedFinder extends RecursiveAstVisitor<void> {
  final found = <StateMisuse>[];
  int _inDerived = 0;

  static bool _isSignal(DartType? t) =>
      t is InterfaceType &&
      const {'StateSignal', 'Signal'}.contains(t.element.name) &&
      '${t.element.library.uri}'.startsWith('package:thor_engine/');

  static bool _isSignalValue(Expression? e) => switch (e) {
    PrefixedIdentifier(:final identifier, :final prefix) =>
      identifier.name == 'value' && _isSignal(prefix.staticType),
    PropertyAccess(:final propertyName, :final realTarget) =>
      propertyName.name == 'value' && _isSignal(realTarget.staticType),
    _ => false,
  };

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final isDerived =
        node.target == null &&
        node.methodName.name == 'derived' &&
        '${node.methodName.element?.library?.uri}'.startsWith(
          'package:thor_engine/',
        );
    if (isDerived) _inDerived++;
    if (_inDerived > 0 &&
        const {
          'update',
          'toggle',
          'add',
          'addAll',
          'remove',
          'clear',
        }.contains(node.methodName.name) &&
        _isSignal(node.realTarget?.staticType)) {
      _report(node);
    }
    super.visitMethodInvocation(node);
    if (isDerived) _inDerived--;
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    if (_inDerived > 0 && _isSignalValue(node.leftHandSide)) _report(node);
    super.visitAssignmentExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    final step =
        node.operator.type == TokenType.PLUS_PLUS ||
        node.operator.type == TokenType.MINUS_MINUS;
    if (_inDerived > 0 && step && _isSignalValue(node.operand)) _report(node);
    super.visitPostfixExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    final step =
        node.operator.type == TokenType.PLUS_PLUS ||
        node.operator.type == TokenType.MINUS_MINUS;
    if (_inDerived > 0 && step && _isSignalValue(node.operand)) _report(node);
    super.visitPrefixExpression(node);
  }

  void _report(AstNode at) => found.add(
    StateMisuse(
      'THOR-B035',
      at,
      message:
          'A derived(...) only reads: it runs when something reads its '
          'value, in the middle of a render or an update, so a write inside '
          'it makes the page depend on who read first.',
      correction:
          'Move the write to a method of the state (the event that '
          'changes it) and let derived(...) compute from the fields.',
    ),
  );
}

/// `setState` of a `StatefulWidget`'s `State` (THOR-S014).
///
/// The server draws a page once and a `State` never reaches the browser, so
/// a `setState` changes nothing anyone sees; thor's `State.setState` also
/// fails an assert in debug. There is no place where it is right (not even
/// `initState`: Flutter's own docs call it unnecessary there), so every use
/// in the app's code is reported: a call, a tear-off, through `this`, an
/// extension or a subclass. Only the app's `lib/` is checked: a test may
/// call it on purpose.
List<StateMisuse> findSetStateCalls(CompilationUnit unit) {
  if (!isAppLib(unit)) return const [];
  final finder = _SetStateFinder();
  unit.accept(finder);
  return finder.found;
}

class _SetStateFinder extends RecursiveAstVisitor<void> {
  final found = <StateMisuse>[];

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == 'setState' && _isStateSetState(node.element)) {
      final parent = node.parent;
      final AstNode at = switch (parent) {
        MethodInvocation() when parent.methodName == node => parent,
        PrefixedIdentifier() when parent.identifier == node => parent,
        PropertyAccess() when parent.propertyName == node => parent,
        _ => node,
      };
      found.add(
        StateMisuse(
          'THOR-S014',
          at,
          message:
              'setState does nothing in the browser: the page is drawn once '
              "on the server and a StatefulWidget's State never reaches the "
              'browser (in debug it fails an assert).',
          correction:
              'Move what changes into a ThorState (`state(...)` fields and '
              'methods) and show it with Watch; the button passes the '
              'method (`onPressed: counter.increment`).',
        ),
      );
    }
    super.visitSimpleIdentifier(node);
  }
}

/// Whether [element] is the `setState` of a class named `State` or of a
/// subclass of one.
bool _isStateSetState(Element? element) {
  if (element is! MethodElement) return false;
  final owner = element.enclosingElement;
  return owner is InterfaceElement && _isStateClass(owner);
}

bool _isStateClass(InterfaceElement e) =>
    e.name == 'State' ||
    e.allSupertypes.any((InterfaceType t) => t.element.name == 'State');

/// An `AnimatedSwitcher` around something that isn't a `Watch` with states
/// (THOR-S016).
///
/// The switcher marks the element of the `Watch` it wraps and animates the
/// swap between that `Watch`'s states; around anything else it does nothing
/// and nothing says so. Only what is certainly wrong is reported: a built-in
/// widget that is not a `Watch` (through the wrappers that fuse into their
/// child), and a `Watch` whose source has no finite states (no `builder:`,
/// `each:`, a text or a list, an `int` without `count:`). The app's own
/// widgets, helpers and a nullable source (THOR-S003's) are left alone.
List<StateMisuse> findSwitcherMisuses(CompilationUnit unit) {
  if (!isAppLib(unit)) return const [];
  final finder = _SwitcherFinder();
  unit.accept(finder);
  return finder.found;
}

class _SwitcherFinder extends RecursiveAstVisitor<void> {
  final found = <StateMisuse>[];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.element?.name == 'AnimatedSwitcher' &&
        !_insideWatchBuilder(node)) {
      for (final arg in node.argumentList.arguments) {
        if (arg is! NamedExpression || arg.name.label.name != 'child') {
          continue;
        }
        final problem = _switcherChildProblem(arg.expression);
        if (problem == null) continue;
        found.add(
          StateMisuse(
            'THOR-S016',
            arg.expression,
            message:
                'AnimatedSwitcher does nothing here: it animates the swap '
                'between the states of the Watch it wraps, and its child '
                '$problem.',
            correction:
                'Wrap a Watch with a builder over a bool, an enum or an int '
                'with count: (`Watch(view.isGrid, builder: (grid) => …)`), '
                'or drop the AnimatedSwitcher.',
          ),
        );
      }
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// Whether [node] is the root of what the `builder:` of a `Watch` returns
/// (through the wrappers that fuse into their child, a conditional, a block
/// body): the Watch swaps that element between states, and the switcher
/// marks it, so it animates whatever its child is. Deeper in the builder's
/// tree the mark lands on an element the Watch does not swap, and nothing
/// animates.
bool _insideWatchBuilder(AstNode node) {
  var current = node;
  while (true) {
    final parent = current.parent;
    if (parent == null) return false;
    switch (parent) {
      case ParenthesizedExpression() ||
          ReturnStatement() ||
          ExpressionFunctionBody() ||
          BlockFunctionBody() ||
          Block() ||
          IfStatement():
        break;
      case ConditionalExpression(:final condition) when current == condition:
        return false;
      case ConditionalExpression():
        break;
      case NamedExpression(:final name) when name.label.name == 'child':
        // `Padding(child: <here>)`: only a wrapper that fuses into its child.
        final wrapper = parent.parent?.parent;
        final type = wrapper is InstanceCreationExpression
            ? wrapper.staticType
            : null;
        if (type is! InterfaceType || !_named(type, 'ParentDataWrapper')) {
          return false;
        }
        current = wrapper!;
        continue;
      case FunctionExpression():
        final named = parent.parent;
        final call = named?.parent?.parent;
        return named is NamedExpression &&
            named.name.label.name == 'builder' &&
            call is InstanceCreationExpression &&
            call.constructorName.type.element?.name == 'Watch';
      default:
        return false;
    }
    current = parent;
  }
}

/// Why [child] gives an `AnimatedSwitcher` nothing to animate, or null when
/// it does or the rule can't tell.
String? _switcherChildProblem(Expression child) {
  if (child is ParenthesizedExpression) {
    return _switcherChildProblem(child.expression);
  }
  // `Watch.list(…)` is a static method, not a constructor.
  if (child is MethodInvocation && child.methodName.name == 'list') {
    final target = child.realTarget;
    if (target is Identifier && target.element?.name == 'Watch') {
      return 'is a Watch of a list (Watch.list), not of states';
    }
  }
  if (child is! InstanceCreationExpression) return null;
  final type = child.staticType;
  if (type is! InterfaceType) return null;
  if (type.element.name == 'Watch') return _watchProblem(child, type);
  if (_named(type, 'ParentDataWrapper')) {
    // A wrapper fuses into its child's element: the child decides.
    for (final arg in child.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'child') {
        return _switcherChildProblem(arg.expression);
      }
    }
    return null;
  }
  if (_named(type, 'ThorBuiltIn')) {
    return 'is a ${type.element.name}, not a Watch';
  }
  return null;
}

String? _watchProblem(InstanceCreationExpression watch, InterfaceType type) {
  bool has(String name) => watch.argumentList.arguments.any(
    (a) => a is NamedExpression && a.name.label.name == name,
  );
  if (has('each')) return 'is a Watch of a list (each:), not of states';
  if (!has('builder')) return 'is a Watch with no builder: it shows a text';
  if (type.typeArguments.length != 1) return null;
  final source = type.typeArguments.single;
  if (source.nullabilitySuffix != NullabilitySuffix.none) return null;
  if (source is! InterfaceType) return null;
  if (source.isDartCoreBool || source.element is EnumElement) return null;
  if (source.isDartCoreInt) {
    return has('count')
        ? null
        : 'is a Watch of an int with no count:, so it has no fixed states';
  }
  return 'is a Watch of a ${source.getDisplayString()}, not of states '
      '(a bool, an enum or an int with count:)';
}

/// Whether [type] is [name] or a subtype of a class with that name.
bool _named(InterfaceType type, String name) =>
    type.element.name == name ||
    type.allSupertypes.any((t) => t.element.name == name);

/// A state member called with the row, or a state signal read in a list
/// row's builder (THOR-S034).
///
/// `Watch.list`'s `each:` runs on the server once per row the page draws,
/// and once more for the row *template* with a placeholder key: rows the
/// browser adds are clones of that template, filled through `row.text`,
/// `row.attribute`, `row.bind` and `row.watch`. So `todos.titleById(row.key)`
/// written straight into a widget (`semanticLabel:`, a `Text`) holds the
/// right value for the rows the server drew and an empty or wrong one for
/// every row added later: no error, and the page looks right. The
/// rows are not rebuilt per item, so the value has to go through a binding.
///
/// Reported: a call of a `ThorState` member (not `withArg`, which builds the
/// handler) with an argument that mentions the row, and a read of a state
/// signal whose member chain (`selected.value.contains(row.key)`) mentions
/// it. Not reported: callbacks (`onPressed: () => …`, their own rule is
/// THOR-S011), `untracked(...)`, builders bound to another state (`Watch`),
/// and anything without the row. Only the app's `lib/` is checked.
List<StateMisuse> findRowServerReads(CompilationUnit unit) {
  if (!isAppLib(unit)) return const [];
  final finder = _RowFinder();
  unit.accept(finder);
  return finder.found;
}

bool _isRowType(DartType? type) =>
    type is InterfaceType &&
    (type.element.name == 'WatchRow' || type.element.name == 'WatchItem');

class _RowFinder extends RecursiveAstVisitor<void> {
  final found = <StateMisuse>[];
  final _seen = <int>{};

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _scan(node.functionExpression.parameters, node.functionExpression.body);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _scan(node.parameters, node.body);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (node.parent is! FunctionDeclaration) _scan(node.parameters, node.body);
    super.visitFunctionExpression(node);
  }

  void _scan(FormalParameterList? parameters, FunctionBody body) {
    final row = parameters?.parameters.any(
      (p) => _isRowType(p.declaredFragment?.element.type),
    );
    if (row != true) return;
    body.accept(_RowScan(this));
  }

  void report(AstNode node) {
    if (!_seen.add(node.offset)) return;
    found.add(
      StateMisuse(
        'THOR-S034',
        node,
        message:
            "'${node.toSource()}' runs once on the server with the row "
            "template's key: the rows the server drew show the right value "
            'and the rows the browser adds show an empty or wrong one.',
        correction:
            'Give the state a method that takes the item '
            '(`String titleOf(Todo t) => t.title`) and bind it: '
            '`row.bind(state.titleOf)` for an attribute (`semanticLabel:`, '
            '`tooltip:`), `row.text(state.titleOf)` for a text, '
            '`row.watch(state.isDone, builder: …)` for a look.',
        warning: true,
      ),
    );
  }
}

class _RowScan extends RecursiveAstVisitor<void> {
  _RowScan(this.owner);

  final _RowFinder owner;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // A callback runs later (THOR-S011 is its rule); a builder bound to a
    // state is that state's business. `row.watch`'s builder is the row.
    if (_skipsClosure(node)) return;
    super.visitFunctionExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.realTarget;
    final name = node.methodName.name;
    if (target != null &&
        isThorState(target.staticType) &&
        name != 'withArg' &&
        name != 'withArgs' &&
        _mentionsRow(node.argumentList, _derived)) {
      owner.report(node);
      return;
    }
    // `state.selected()`: a signal read by calling it.
    if (target != null &&
        isThorState(target.staticType) &&
        _isStateSignal(node.methodName.staticType)) {
      _signalRead(node);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    if (_isStateSignal(node.function.staticType)) _signalRead(node);
    super.visitFunctionExpressionInvocation(node);
  }

  // The locals made from the row (`final id = row.key;`): a use of one is a
  // use of the row.
  final _derived = <Element>{};

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final init = node.initializer;
    final element = node.declaredFragment?.element;
    if (init != null && element != null && _mentionsRow(init, _derived)) {
      _derived.add(element);
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.propertyName.name == 'value' &&
        _isStateSignal(node.realTarget.staticType)) {
      _signalRead(node);
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.identifier.name == 'value' &&
        _isStateSignal(node.prefix.staticType)) {
      _signalRead(node);
    }
    super.visitPrefixedIdentifier(node);
  }

  /// `signal.value` read as data: the member chain it heads
  /// (`signal.value.contains(row.key)`) mentions the row.
  void _signalRead(Expression read) {
    var chain = read;
    while (true) {
      final parent = chain.parent;
      final next = switch (parent) {
        MethodInvocation() when parent.target == chain => parent,
        PropertyAccess() when parent.target == chain => parent,
        PrefixedIdentifier() when parent.prefix == chain => parent,
        IndexExpression() when parent.target == chain => parent,
        ParenthesizedExpression() => parent,
        _ => null,
      };
      if (next == null) break;
      chain = next;
    }
    if (_mentionsRow(chain, _derived)) owner.report(chain);
  }
}

/// Whether [node] names a list row (a `WatchRow` or `WatchItem`).
bool _mentionsRow(AstNode node, Set<Element> derived) {
  final finder = _RowUse(derived);
  node.accept(finder);
  return finder.found;
}

class _RowUse extends RecursiveAstVisitor<void> {
  _RowUse(this.derived);

  final Set<Element> derived;
  var found = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final element = node.element;
    if (element is! InterfaceElement && _isRowType(node.staticType) ||
        element != null && derived.contains(element)) {
      found = true;
    }
    super.visitSimpleIdentifier(node);
  }
}

/// Whether [closure] runs later or is bound to a state, unlike a list
/// row's own builders (`row.watch`).
bool _skipsClosure(FunctionExpression closure) {
  final parent = closure.parent;
  if (parent is! NamedExpression && parent is! ArgumentList) return false;
  final Expression arg = parent is NamedExpression ? parent : closure;
  if (isCallbackType(arg.correspondingParameter?.type)) return true;
  final name = arg.correspondingParameter?.name;
  if (name != null && (name == 'validator' || _isHandlerName(name))) {
    return true;
  }
  final call = arg.parent?.parent;
  if (call is InstanceCreationExpression) {
    return _bindingBuilders.contains(call.constructorName.type.element?.name);
  }
  if (call is MethodInvocation) {
    return call.realTarget == null && call.methodName.name == 'untracked';
  }
  return false;
}

/// A state read while the server draws the page (THOR-S015).
///
/// A widget's `build` runs once, on the server: what it reads out of a
/// `StateSignal` (`counter.count.value`, `orders.data.value`) is the value
/// the state had then, and the browser never updates it. The same goes for a
/// list a state method or getter returns and the build iterates (`for`,
/// `.map`, `ListView.builder(itemCount: …length)`): the rows are the ones
/// the server drew.
///
/// What is server code: a widget's `build`, any function that returns a
/// `Widget`, and what those call in the same file (helpers, getters,
/// extension members). What is not: a `ThorState`'s own members (they run in
/// the browser), a closure passed as a callback (it runs later), and the
/// builders bound to a state (`Watch`, `ValueListenableBuilder`,
/// `QueryBuilder`, `row.watch`). A plain (non-signal) field of a state is
/// treated as data that never changes. A read is deliberate, and left
/// alone, in `untracked(() => …)` and in `peek()` (their names say it is a
/// snapshot), and as the initial value of a control (`value:`, `groupValue:`,
/// `initialValue:` or `selected:` of a widget that takes `onChanged:`: the
/// browser's control keeps its own value from then on). Only the app's
/// `lib/` is checked.
List<StateMisuse> findFrozenReads(CompilationUnit unit) {
  if (!isAppLib(unit)) return const [];
  return _FrozenReads(unit).find();
}

/// The classes whose builder closure is bound to a state.
const _bindingBuilders = {'Watch', 'ValueListenableBuilder', 'QueryBuilder'};

class _FrozenReads {
  _FrozenReads(this.unit);

  final CompilationUnit unit;

  /// The executable declarations of the unit outside a ThorState, by element.
  final _declarations = <Element, AstNode>{};
  final _pending = <AstNode>[];
  final _scanned = <AstNode>{};
  final _reported = <int>{};
  final _reads = <Element, bool>{};
  final found = <StateMisuse>[];

  List<StateMisuse> find() {
    for (final declaration in unit.declarations) {
      switch (declaration) {
        case FunctionDeclaration():
          _declare(declaration, declaration.declaredFragment?.element);
        case ClassDeclaration():
          final type = declaration.declaredFragment?.element.thisType;
          if (isThorState(type)) continue;
          _members(declaration.body, widget: isWidgetType(type));
        case MixinDeclaration():
          _members(declaration.body);
        case ExtensionDeclaration():
          _members(declaration.body);
        default:
      }
    }
    while (_pending.isNotEmpty) {
      final body = _pending.removeLast();
      if (_scanned.add(body)) body.accept(_Scan(this));
    }
    found.sort((a, b) => a.offset.compareTo(b.offset));
    return found;
  }

  void _members(ClassBody body, {bool widget = false}) {
    if (body is! BlockClassBody) return;
    for (final member in body.members) {
      if (member is MethodDeclaration) {
        _declare(member, member.declaredFragment?.element);
      } else if (widget) {
        // A widget is constructed while the page is drawn: its field
        // initializers and constructors run on the server too.
        if (member is FieldDeclaration && !member.isStatic) {
          for (final variable in member.fields.variables) {
            final init = variable.initializer;
            if (init != null) _pending.add(init);
          }
        } else if (member is ConstructorDeclaration) {
          _pending.add(member);
        }
      }
    }
  }

  /// Records [node] as reachable code when it is a `build` or returns a
  /// widget; other functions wait until something calls them.
  void _declare(AstNode node, ExecutableElement? element) {
    if (element == null) return;
    _declarations[element.baseElement] = node;
    if (element.name == 'build' || isWidgetType(element.returnType)) {
      _pending.add(node);
    }
  }

  void call(Element? element) {
    if (element is! ExecutableElement) return;
    final node = _declarations[element.baseElement];
    if (node != null) _pending.add(node);
  }

  /// Whether the state member [member] reads a signal (its body names a
  /// signal of its class, a `.value`, or calls a member that does), so that
  /// calling it while the server draws returns a snapshot. Read from the
  /// parsed library of the member, so a state in another file counts too.
  bool readsState(ExecutableElement member) {
    final base = member.baseElement;
    final known = _reads[base];
    if (known != null) return known;
    _reads[base] = false; // Recursion guard: a cycle reads nothing new.
    final owner = base.enclosingElement;
    if (owner is! InterfaceElement) return false;
    final parsed = base.session?.getParsedLibraryByElement(base.library);
    if (parsed is! ParsedLibraryResult) return false;
    final node = parsed.getFragmentDeclaration(base.firstFragment)?.node;
    if (node == null) return false;
    final signals = <String>{
      for (final type in [owner.thisType, ...owner.allSupertypes])
        for (final field in type.element.fields)
          if (!field.isStatic &&
              (_isStateSignal(field.type) ||
                  (field.type is InterfaceType &&
                      _named(field.type as InterfaceType, 'ServerQuery'))))
            ?field.name,
    };
    final calls = <ExecutableElement>[];
    final finder = _StateNames(signals, (name) {
      final method =
          owner.getMethod(name) ??
          owner.getGetter(name) ??
          _inherited(owner, name);
      if (method != null) calls.add(method);
    });
    node.accept(finder);
    var reads = finder.reads;
    for (final call in calls) {
      if (reads) break;
      reads = readsState(call);
    }
    return _reads[base] = reads;
  }

  void report(AstNode node, {required String message, required String fix}) {
    if (!_reported.add(node.offset)) return;
    found.add(
      StateMisuse(
        'THOR-S015',
        node,
        message: message,
        correction: fix,
        warning: true,
      ),
    );
  }
}

ExecutableElement? _inherited(InterfaceElement owner, String name) {
  for (final type in owner.allSupertypes) {
    final found = type.element.getMethod(name) ?? type.element.getGetter(name);
    if (found != null) return found;
  }
  return null;
}

/// Whether a member's parsed body reads a signal of its class, by name: the
/// body is not resolved, so a name that is a signal field of the class, or
/// any `.value`, counts.
class _StateNames extends RecursiveAstVisitor<void> {
  _StateNames(this.signals, this.onName);

  final Set<String> signals;
  final void Function(String) onName;
  var reads = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (signals.contains(node.name)) reads = true;
    onName(node.name);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.identifier.name == 'value') reads = true;
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.propertyName.name == 'value') reads = true;
    super.visitPropertyAccess(node);
  }
}

class _Scan extends RecursiveAstVisitor<void> {
  _Scan(this.owner);

  final _FrozenReads owner;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // A callback runs later, in the browser; a builder bound to a state is
    // the state's business.
    if (_runsLater(node)) return;
    super.visitFunctionExpression(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    owner.call(node.element);
    if (node.name == 'value' && node.inGetterContext()) _checkValue(node);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.realTarget;
    if (target != null && isThorState(target.staticType)) {
      _root(node);
      _member(node, node.methodName);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (isThorState(node.realTarget.staticType) &&
        !_isField(node.propertyName)) {
      _root(node);
      _member(node, node.propertyName);
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (isThorState(node.prefix.staticType) && !_isField(node.identifier)) {
      _root(node);
      _member(node, node.identifier);
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    // `counter.count()`: a signal is callable, and calling it reads it.
    if (_isStateSignal(node.function.staticType)) _read(node, null);
    super.visitFunctionExpressionInvocation(node);
  }

  /// A method or computed getter of a state that reads state, called or read
  /// while the server draws: what it returns is the snapshot of that moment
  /// (`Text(counter.label())`). A field is not one (its signal goes to
  /// `Watch`), nor is a call that returns nothing, a widget, a collection
  /// (see [_root]) or a member that reads no state. A tear-off is not a call.
  void _member(Expression node, SimpleIdentifier name) {
    final element = name.element;
    if (element is! ExecutableElement) return;
    // `counter.count()` parses as a call of the field `count`.
    if (element is GetterElement &&
        element.variable.isOriginDeclaration &&
        node is MethodInvocation) {
      if (_isStateSignal(element.returnType)) _read(node, null);
      return;
    }
    final type = node.staticType;
    if (type == null || type is VoidType || type is FunctionType) return;
    if (type is InterfaceType &&
        (type.isDartAsyncFuture ||
            type.isDartAsyncFutureOr ||
            isWidgetType(type) ||
            _isCollection(type) ||
            _isStateSignal(type))) {
      return;
    }
    if (element is GetterElement && element.variable.isOriginDeclaration) {
      return;
    }
    if (_isControlValue(node)) return;
    if (!owner.readsState(element)) return;
    final call = node is MethodInvocation;
    final args = call && node.argumentList.arguments.isNotEmpty;
    owner.report(
      node,
      message:
          "'${node.toSource()}' reads state while the server draws the page: "
          'it returns the value the state had then, and the browser never '
          'updates it (frozen).',
      fix: args
          ? 'Show it in a list row with `row.text(…)`, or make a method '
                'with no arguments and pass it to Watch '
                '(`Watch(counter.label)`).'
          : 'Pass the member to Watch without calling it '
                '(`Watch(${_watchable(node)})`).',
    );
  }

  /// `<signal>.value` (the identifier [value] of a property access), or a
  /// bare `value` inside an extension on a signal.
  void _checkValue(SimpleIdentifier value) {
    // A label (`value: 1`) or a variable named `value` is not the getter.
    if (value.element is! GetterElement) return;
    final parent = value.parent;
    AstNode read = value;
    DartType? signal;
    if (parent is PrefixedIdentifier && parent.identifier == value) {
      read = parent;
      signal = parent.prefix.staticType;
    } else if (parent is PropertyAccess && parent.propertyName == value) {
      read = parent;
      signal = parent.realTarget.staticType;
    } else if (parent is! MethodInvocation) {
      // Implicit `this`: only an extension on a signal has one that matters.
      final extension = value.thisOrAncestorOfType<ExtensionDeclaration>();
      signal = extension?.declaredFragment?.element.extendedType;
    }
    if (_isStateSignal(signal)) _read(read, signal);
  }

  void _read(AstNode read, DartType? signal) {
    if (_isControlValue(read)) return;
    final value = signal is InterfaceType ? _signalValue(signal) : null;
    final list = value != null && _isCollection(value);
    owner.report(
      read,
      message:
          "'${read.toSource()}' is read while the server draws the page: "
          'the browser keeps the value the state had then and never updates '
          'it (frozen).',
      fix: list
          ? 'Draw the list with Watch, so its rows follow the state '
                '(`Watch.list(state.rows.call, itemKey: …, each: (row) => …)`).'
          : 'Show it with Watch (`Watch(counter.count)`, or a method of the '
                'state that returns it: `Watch(counter.label)`); in a list '
                'row, with `row.text(…)`.',
    );
  }

  /// A member of a state read as data ([node] is a call or a getter),
  /// reported when a `for`, a spread or a member access consumes the
  /// collection it returns.
  void _root(Expression node) {
    final type = node.staticType;
    if (type == null || !_isCollection(type) || _isStateSignal(type)) return;
    if (!_consumed(node)) return;
    owner.report(
      node,
      message:
          "'${node.toSource()}' is a snapshot: the list is drawn once on the "
          'server, so rows the state adds or removes in the browser never '
          'show up (frozen).',
      fix:
          'Draw the rows with Watch and the state field '
          "(`Watch.list(${_watchable(node)}, itemKey: …, each: (row) => …)`).",
    );
  }
}

/// Whether [member] is a plain field (its getter is the implicit one): data
/// the state holds, not something computed from its signals.
bool _isField(SimpleIdentifier member) {
  final element = member.element;
  return element is GetterElement && element.variable.isOriginDeclaration;
}

/// The member [node] reads, torn off for a `Watch`.
String _watchable(Expression node) {
  final source = node.toSource();
  return node is MethodInvocation
      ? source.substring(0, source.length - node.argumentList.length)
      : source;
}

/// Whether the collection [node] evaluates to is iterated or indexed.
bool _consumed(Expression node) {
  var current = node;
  while (true) {
    final parent = current.parent;
    if (parent is ParenthesizedExpression ||
        parent is AsExpression ||
        (parent is PostfixExpression && parent.operator.lexeme == '!') ||
        (parent is BinaryExpression && parent.operator.lexeme == '??') ||
        parent is ConditionalExpression) {
      current = parent as Expression;
      continue;
    }
    break;
  }
  final parent = current.parent;
  return switch (parent) {
    ForEachParts() => parent.iterable == current,
    SpreadElement() => true,
    MethodInvocation() => parent.target == current,
    PropertyAccess() => parent.target == current,
    PrefixedIdentifier() => parent.prefix == current,
    IndexExpression() => parent.target == current,
    VariableDeclaration() => _consumedThroughLocal(parent),
    _ => false,
  };
}

/// `final rows = state.rows();` and a later `for (… in rows)` / `rows[i]`.
bool _consumedThroughLocal(VariableDeclaration declaration) {
  final element = declaration.declaredFragment?.element;
  final scope = declaration.thisOrAncestorOfType<FunctionBody>();
  if (element == null || scope == null) return false;
  final finder = _LocalUses(element);
  scope.accept(finder);
  return finder.consumed;
}

class _LocalUses extends RecursiveAstVisitor<void> {
  _LocalUses(this.local);

  final Element local;
  var consumed = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.element == local && node.parent is! VariableDeclaration) {
      // Reuse the member-access logic on the reference itself.
      if (_consumed(node)) consumed = true;
    }
    super.visitSimpleIdentifier(node);
  }
}

/// Whether [read] is (part of) the initial value of a control.
bool _isControlValue(AstNode read) {
  for (var node = read.parent; node != null; node = node.parent) {
    if (node is FunctionBody || node is Statement) return false;
    if (node is! NamedExpression) continue;
    if (!_controlValues.contains(node.name.label.name)) return false;
    final call = node.parent?.parent;
    final constructor = call is InstanceCreationExpression
        ? call.constructorName.element
        : null;
    return constructor != null &&
        constructor.formalParameters.any((p) => _isChangeCallback(p.name));
  }
  return false;
}

/// `onSomething`: an event handler by name, whatever it returns.
bool _isHandlerName(String name) =>
    name.length > 2 &&
    name.startsWith('on') &&
    name.codeUnitAt(2) >= 0x41 &&
    name.codeUnitAt(2) <= 0x5a;

const _controlValues = {
  'value',
  'values',
  'groupValue',
  'initialValue',
  'initialSelection',
  'selected',
  'isSelected',
};

/// `onChanged`, `onSelected`, `onSelectionChanged`…: the callback that tells
/// a control owns its value.
bool _isChangeCallback(String? name) =>
    name != null &&
    name.startsWith('on') &&
    (name.endsWith('Changed') || name.endsWith('Selected'));

/// Whether [closure] runs later or is bound to a state: an event callback
/// (a parameter of a function type that returns nothing) or the closure
/// of a `Watch` / `ValueListenableBuilder` / `QueryBuilder` / `row.watch`,
/// or of `untracked(...)`.
bool _runsLater(FunctionExpression closure) {
  final parent = closure.parent;
  if (parent is! NamedExpression && parent is! ArgumentList) return false;
  final Expression arg = parent is NamedExpression ? parent : closure;
  if (isCallbackType(arg.correspondingParameter?.type)) return true;
  // A handler that answers with a value (`validator:`, `onWillPop:`) runs
  // when the browser or a request asks, not while the page is drawn.
  final name = arg.correspondingParameter?.name;
  if (name != null && (name == 'validator' || _isHandlerName(name))) {
    return true;
  }
  final call = arg.parent?.parent;
  if (call is InstanceCreationExpression) {
    return _bindingBuilders.contains(call.constructorName.type.element?.name);
  }
  if (call is MethodInvocation) {
    // `untracked(() => …)` says in its name that it reads a snapshot.
    if (call.realTarget == null && call.methodName.name == 'untracked') {
      return true;
    }
    // `Watch.list(…)`: a static call, its target is the class itself.
    final target = call.realTarget;
    if (target is Identifier &&
        target.element?.name == 'Watch' &&
        call.methodName.name == 'list') {
      return true;
    }
    final row = target?.staticType?.element?.name;
    return row == 'WatchItem' || row == 'WatchRow';
  }
  return false;
}

bool _isStateSignal(DartType? type) =>
    type is InterfaceType &&
    (type.element.name == 'StateSignal' ||
        type.allSupertypes.any((t) => t.element.name == 'StateSignal'));

/// The `T` of a `StateSignal<T>` (or a subtype).
DartType? _signalValue(InterfaceType type) {
  for (final t in [type, ...type.allSupertypes]) {
    if (t.element.name == 'StateSignal' && t.typeArguments.length == 1) {
      return t.typeArguments.single;
    }
  }
  return null;
}

bool _isCollection(DartType type) =>
    type is InterfaceType &&
    (type.isDartCoreIterable ||
        type.isDartCoreList ||
        type.isDartCoreSet ||
        type.isDartCoreMap ||
        type.allSupertypes.any((t) => t.isDartCoreIterable || t.isDartCoreMap));
