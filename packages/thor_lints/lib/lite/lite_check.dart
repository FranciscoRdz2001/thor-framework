import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import 'lite_state_js.dart';

/// The data classes of [units] that travel to the browser, by name, and the
/// members they declare: every class with a `fromJson` constructor.
///
/// A package that only declares the data of other packages' states (a
/// protocol package) has no `ThorState` here to say which classes the
/// browser decodes, so all of them count. The names are what
/// [translateLiteStates] takes as `dataClasses` and `dataMembers`.
({Set<String> classes, Set<String> members}) wireClassesOf(
  Iterable<LiteUnit> units,
) {
  final classes = <String>{}, members = <String>{};
  for (final u in units) {
    for (final d in u.unit.declarations.whereType<ClassDeclaration>()) {
      final element = d.declaredFragment?.element;
      if (element == null || element.getNamedConstructor('fromJson') == null) {
        continue;
      }
      classes.add(element.name ?? '');
      d.accept(_MemberNames(members));
    }
  }
  classes.remove('');
  return (classes: classes, members: members);
}

class _MemberNames extends RecursiveAstVisitor<void> {
  _MemberNames(this.names);

  final Set<String> names;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    names.add(node.name.lexeme);
    // Not the bodies: a local function is not a member.
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    for (final v in node.fields.variables) {
      names.add(v.name.lexeme);
    }
  }
}

/// What [checkLiteSubset] found.
class LiteCheck {
  /// A result.
  const LiteCheck({
    required this.states,
    required this.dataClasses,
    required this.errors,
  });

  /// How many `ThorState` classes were checked.
  final int states;

  /// How many data classes (with a `fromJson`) were checked.
  final int dataClasses;

  /// Every construct outside the subset.
  final List<LiteError> errors;

  /// Whether nothing is outside the subset.
  bool get ok => errors.isEmpty;

  /// Nothing to check: no state and no data class.
  bool get empty => states == 0 && dataClasses == 0;
}

/// Whether the code of [units] fits the thor-lite subset, as the build
/// would find out, without a build: the `ThorState` classes and what they
/// reach. A package **without** states takes **every** data class (a class
/// with a `fromJson`) instead, as nothing says which ones the browser
/// decodes.
///
/// For a package that declares the data classes of `events<T>`, `query`
/// and `state<T>` fields of another package (`thor analyze --lite`, the
/// `thor_lite_subset` rule with `thor: lite_data: true`). A construct a
/// data class uses outside the subset (`Uri.parse` in a `fromJson`) is a
/// [LiteError], as it would be in the build of the app that uses the class.
LiteCheck checkLiteSubset(List<LiteUnit> units) {
  var states = 0;
  for (final u in units) {
    for (final d in u.unit.declarations.whereType<ClassDeclaration>()) {
      final c = d.declaredFragment?.element;
      if (c != null && _isState(c)) states++;
    }
  }
  final wire = wireClassesOf(units);
  if (states == 0 && wire.classes.isEmpty) {
    return const LiteCheck(states: 0, dataClasses: 0, errors: []);
  }
  // With states the build translates what they reach, and so does the
  // check: a data class no state names is not in the browser's code (a
  // `fromJson` of a model another page uses with `query`, say). Only a
  // package without states (a protocol package) takes every data class.
  final named = states == 0;
  try {
    translateLiteStates(
      units,
      dataClasses: named ? wire.classes : const {},
      dataMembers: named ? wire.members : const {},
    );
    return LiteCheck(
      states: states,
      dataClasses: named ? wire.classes.length : 0,
      errors: const [],
    );
  } on LiteTranslationException catch (e) {
    return LiteCheck(
      states: states,
      dataClasses: named ? wire.classes.length : 0,
      errors: e.errors,
    );
  }
}

bool _isState(ClassElement c) => c.allSupertypes.any(
  (t) =>
      t.element.name == 'ThorState' &&
      '${t.element.library.uri}'.startsWith('package:thor_engine/'),
);
