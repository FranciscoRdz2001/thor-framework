import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/file_system/file_system.dart';

import '../lite.dart';
import 'errors.dart';

/// `thor_lite_subset`: a `ThorState` (or the code it reaches) that the lite
/// translator can't write as JS (THOR-B012), in the editor with the message
/// and the fix `thor dev`/`thor build` print.
///
/// The rule runs the build's translator ([translateLiteStates]) on the
/// library being analyzed when it declares a state. An analysis rule only
/// has that library resolved, so the app's other libraries are opaque: a
/// construct that names a declaration of another library of the app is not
/// reported here (the build, which translates the whole app, still is),
/// and neither are the errors inside those libraries.
///
/// The data classes that travel to the browser (the type arguments of the
/// `events`, `query` and `state` fields: their `fromJson`/`toJson` and the
/// members the state calls) are translated by the build too, and live in
/// their own libraries. A library with a class that has a `fromJson` is
/// translated as if the states of the app that name it held it (found in
/// the app's other files by name, without resolving them), and its errors
/// show in its own file.
class LiteSubsetRule extends AnalysisRule {
  /// The diagnostic: the build's message (with its code) and its fix.
  static const DiagnosticCode code = LintCode(
    'thor_lite_subset',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.ERROR,
    uniqueName: 'LintCode.thor_lite_subset',
  );

  /// Creates the rule.
  LiteSubsetRule()
    : super(
        name: 'thor_lite_subset',
        description:
            "A ThorState runs in the browser as JS: what the lite "
            'translator does not write stops the build (THOR-B012).',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    // The build translates the app's `lib/`: a state in a test or a script
    // never reaches the browser's bundle.
    if (!context.isInLibDir) return;
    // The framework's own states (the oracle's row readers) are not an
    // app's: no bundle translates them.
    final uri = context.libraryElement?.uri.toString() ?? '';
    if (_framework.any((p) => uri.startsWith('package:$p/'))) return;
    registry.addCompilationUnit(this, _Visitor(this, context));
  }
}

const _framework = {
  'thor_builder',
  'thor_cli',
  'thor_engine',
  'thor_engine_oracle',
  'thor_lints',
  'thor_server',
  'thor_studio',
  'thor_style',
  'thor_test',
  'thor_ui',
};

/// What the build says of each library (by its defining unit): the server
/// visits every unit of a library with the same context.
final _byLibrary = Expando<List<LiteError>>();

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitCompilationUnit(CompilationUnit node) {
    final unit = context.currentUnit;
    if (unit == null) return;
    final path = unit.file.path;
    for (final e in _errors()) {
      if (e.path != path) continue;
      final lines = node.lineInfo;
      if (e.line > lines.lineCount) continue;
      final offset = lines.getOffsetOfLine(e.line - 1) + e.column - 1;
      final end = e.node?.end ?? offset + 1;
      final message = e.message.contains('THOR-')
          ? e.message
          : thorError('THOR-B012', e.message);
      rule.reportAtOffset(
        offset,
        end > offset ? end - offset : 1,
        arguments: [message, e.hint.isEmpty ? liteWayOut : e.hint],
      );
    }
  }

  List<LiteError> _errors() {
    final key = context.definingUnit.unit;
    return _byLibrary[key] ??= _translate();
  }

  List<LiteError> _translate() {
    final units = [
      for (final u in context.allUnits) LiteUnit(u.file.path, u.unit),
    ];
    final library = context.libraryElement;
    final wire = _wireClasses(library);
    if (!units.any((u) => _declaresState(u.unit)) && wire.classes.isEmpty) {
      return const [];
    }
    try {
      translateLiteStates(
        units,
        dataClasses: wire.classes,
        dataMembers: wire.members,
      );
      return const [];
    } on LiteTranslationException catch (e) {
      return [
        for (final error in e.errors)
          // The editor resolves one library: a data class of another
          // library or package is the build's to find.
          if (!error.message.startsWith(dataClassSourceMissing) &&
              (library == null || !_namesOtherLibrary(error.node, library)))
            error,
      ];
    } catch (_) {
      // The translator only ever saw a whole app: a crash on a library
      // without the rest is the build's to report, not the editor's.
      return const [];
    }
  }

  /// The classes of [library] with a `fromJson` that a `ThorState` of the
  /// app names, and the identifiers those states use (the members they
  /// might call). The states are not resolved (the rule has one library):
  /// they are read from the app's files by name, which may over-ask a class
  /// that shares a name, never under-ask one the state names.
  ({Set<String> classes, Set<String> members}) _wireClasses(
    LibraryElement? library,
  ) {
    const none = (classes: <String>{}, members: <String>{});
    if (library == null) return none;
    final own = {
      for (final c in library.classes)
        if (c.getNamedConstructor('fromJson') != null) c.name!,
    };
    if (own.isEmpty) return none;
    final root = context.package?.root;
    if (root == null) return none;
    // A protocol package: its states are in the apps that use it, so every
    // data class here goes to the browser.
    if (_declaresLiteData(root)) {
      final all = wireClassesOf([
        for (final u in context.allUnits) LiteUnit(u.file.path, u.unit),
      ]);
      return (classes: all.classes, members: all.members);
    }
    final mine = {for (final u in context.allUnits) u.file.path};
    final names = <String>{}, members = <String>{};
    for (final s in _stateNames(root.getChildAssumingFolder('lib'), mine)) {
      names.addAll(s.types);
      members.addAll(s.members);
    }
    final classes = own.intersection(names);
    return classes.isEmpty ? none : (classes: classes, members: members);
  }

  /// Whether [node] names a declaration of another library of the app (the
  /// same package): the rule doesn't have it resolved, so the translator
  /// took it for code outside the app.
  bool _namesOtherLibrary(AstNode? node, LibraryElement library) {
    if (node == null) return false;
    final root = context.package?.root.path;
    String? packageOf(Uri uri) =>
        uri.isScheme('package') ? uri.pathSegments.first : null;
    final own = packageOf(library.uri);
    final finder = _OtherLibrary(library, (e) {
      final lib = e.library;
      if (lib == null) return false;
      if (own != null && packageOf(lib.uri) == own) return true;
      final source = lib.firstFragment.source.fullName;
      return root != null && source.startsWith('$root/');
    });
    node.accept(finder);
    return finder.found;
  }
}

/// Whether the pubspec of the package at [root] says its data classes all
/// travel to the browser:
///
/// ```yaml
/// thor:
///   lite_data: true
/// ```
bool _declaresLiteData(Folder root) {
  final file = root.getChildAssumingFile('pubspec.yaml');
  String text;
  try {
    text = file.readAsStringSync();
  } catch (_) {
    return false;
  }
  return pubspecLiteData(text);
}

/// Whether [pubspec] has `thor:` with `lite_data: true` under it.
bool pubspecLiteData(String pubspec) {
  var inThor = false;
  for (final line in pubspec.split('\n')) {
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    if (!line.startsWith(' ') && !line.startsWith('\t')) {
      inThor = RegExp(r'^thor:\s*(#.*)?$').hasMatch(line);
      continue;
    }
    if (inThor && RegExp(r'^\s+lite_data:\s*true\s*(#.*)?$').hasMatch(line)) {
      return true;
    }
  }
  return false;
}

bool _declaresState(CompilationUnit unit) {
  for (final d in unit.declarations) {
    if (d is! ClassDeclaration) continue;
    final c = d.declaredFragment?.element;
    if (c == null) continue;
    if (c.allSupertypes.any(
      (t) =>
          t.element.name == 'ThorState' &&
          '${t.element.library.uri}'.startsWith('package:thor_engine/'),
    )) {
      return true;
    }
  }
  return false;
}

/// Finds an identifier or a type of another library of the app.
class _OtherLibrary extends GeneralizingAstVisitor<void> {
  _OtherLibrary(this.library, this.inApp);

  final LibraryElement library;
  final bool Function(Element) inApp;
  bool found = false;

  void _check(Element? e) {
    if (found || e == null) return;
    final lib = e.library;
    if (lib != null && lib != library && inApp(e)) found = true;
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    _check(node.element);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitPatternField(PatternField node) {
    _check(node.element);
    super.visitPatternField(node);
  }

  @override
  void visitDartPattern(DartPattern node) {
    _check(node.matchedValueType?.element);
    super.visitDartPattern(node);
  }

  @override
  void visitNamedType(NamedType node) {
    _check(node.element);
    super.visitNamedType(node);
  }

  @override
  void visitExpression(Expression node) {
    _check(node.staticType?.element);
    super.visitExpression(node);
  }
}

/// What a state class mentions: its type names and its identifiers.
typedef _Mentions = ({Set<String> types, Set<String> members});

/// The states of a package, by the files of its `lib/` that name
/// `ThorState`: refreshed when older than [_scanTtl], so a pass over many
/// libraries reads the files once.
final _scans =
    Expando<Map<String, (DateTime, Map<String, (int, List<_Mentions>)>)>>();
const _scanTtl = Duration(seconds: 2);

List<_Mentions> _stateNames(Folder lib, Set<String> except) {
  final now = DateTime.now();
  final byLib = _scans[lib.provider] ??= {};
  final scan = byLib[lib.path];
  final known = scan?.$2 ?? <String, (int, List<_Mentions>)>{};
  if (scan == null || now.difference(scan.$1) > _scanTtl) {
    final fresh = <String, (int, List<_Mentions>)>{};
    void walk(Folder dir) {
      List<Resource> children;
      try {
        children = dir.getChildren();
      } catch (_) {
        return;
      }
      for (final c in children) {
        if (c is Folder) {
          walk(c);
        } else if (c is File && c.path.endsWith('.dart')) {
          String text;
          try {
            text = c.readAsStringSync();
          } catch (_) {
            continue;
          }
          if (!text.contains('ThorState')) continue;
          final before = known[c.path];
          fresh[c.path] = before != null && before.$1 == text.hashCode
              ? before
              : (text.hashCode, _mentions(text));
        }
      }
    }

    walk(lib);
    byLib[lib.path] = (now, fresh);
    return [
      for (final e in fresh.entries)
        if (!except.contains(e.key)) ...e.value.$2,
    ];
  }
  return [
    for (final e in known.entries)
      if (!except.contains(e.key)) ...e.value.$2,
  ];
}

/// The type names and identifiers of each class of [text] that extends
/// something (the file names `ThorState`; a state may extend a base state
/// of the app, so this over-asks rather than miss one).
List<_Mentions> _mentions(String text) {
  final unit = parseString(content: text, throwIfDiagnostics: false).unit;
  final out = <_Mentions>[];
  for (final d in unit.declarations) {
    if (d is! ClassDeclaration) continue;
    final extended = d.extendsClause?.superclass.name.lexeme;
    if (extended == null) continue;
    final finder = _Mentioned();
    d.accept(finder);
    out.add((types: finder.types, members: finder.members));
  }
  return out;
}

class _Mentioned extends RecursiveAstVisitor<void> {
  final types = <String>{};
  final members = <String>{};

  @override
  void visitNamedType(NamedType node) {
    types.add(node.name.lexeme);
    super.visitNamedType(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    members.add(node.name);
    types.add(node.name);
    super.visitSimpleIdentifier(node);
  }
}
