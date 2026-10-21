/// What `thor dev`'s worker keeps between two runs of the entries and the
/// lite-state steps, so a save re-resolves only the libraries it touched.
///
/// Resolving a library (function bodies included) is most of the cost of
/// those steps, and the analyzer does not keep the result between
/// sessions. What the steps need from the bodies is small and plain data:
/// the misuses found in a file, the row lambdas, the engine features a
/// state's file reaches. That data is kept per library, valid while
///
/// - the library's own files are the same text, and
/// - the *public API* of every app library it depends on, transitively
///   through imports and exports, is the same: the declarations of those
///   files without the bodies that cannot change what other code sees
///   (see [apiSignature]).
///
/// Anything that is not a plain fact (the elements the generated code is
/// written from) is not kept: the steps ask the analysis for it again,
/// which is cheap because it needs no function body.
library;

import 'dart:async';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:path/path.dart' as p;

/// The misuses and warnings found in one file (see `stateMisuses`).
class UnitFacts {
  /// The findings of a file.
  UnitFacts(this.misuses, this.warnings);

  /// `stateMisuses` of the file.
  final List<String> misuses;

  /// `stateWarnings` of the file.
  final List<String> warnings;
}

/// What the row lambdas of one file said, in the order they were found.
class RowFacts {
  /// The lambdas of a file.
  RowFacts(this.events);

  /// One entry per lambda.
  final List<RowEvent> events;
}

/// A row lambda: a problem (its message), or a property of an item class.
class RowEvent {
  /// A lambda that does more than read a property.
  RowEvent.problem(String this.message)
    : itemLibrary = null,
      itemName = null,
      property = null,
      states = null;

  /// A lambda that reads [property] of the class [itemName] of
  /// [itemLibrary] (a library URI); [states] for a `bool` or enum.
  RowEvent.property(
    String this.itemLibrary,
    String this.itemName,
    String this.property,
    this.states,
  ) : message = null;

  /// The THOR-B030 message, or null.
  final String? message;

  /// The URI of the library of the row's class.
  final String? itemLibrary;

  /// The row's class.
  final String? itemName;

  /// The property read.
  final String? property;

  /// How many states the property has, for a `bool` or an enum.
  final int? states;
}

/// The engine features a library's code reaches, and what that depended on.
class CalledFacts {
  /// The features of a library, computed with the bodies of [reached].
  CalledFacts(this.features, this.reached);

  /// `confirm`, `toast`.
  final Set<String> features;

  /// The libraries (root path → the text key of their files) whose function
  /// bodies were read to find them.
  final Map<String, String> reached;
}

/// The libraries one analysis session resolved, so the steps of a run ask
/// for each only once (the entries, then the lite states).
class ResolveMemo {
  ResolveMemo._(this.session, this._count);

  final void Function() _count;

  /// The session everything here was resolved in.
  final AnalysisSession session;
  final _libraries = <String, Future<SomeResolvedLibraryResult>>{};
  final _units = <String, Future<SomeResolvedUnitResult>>{};

  /// [path] resolved as a library (function bodies included).
  Future<SomeResolvedLibraryResult> resolvedLibrary(String path) {
    return _libraries[path] ??= () {
      _count();
      return session.getResolvedLibrary(path);
    }();
  }

  /// The resolved unit of [path], a file of the library at [root] (null:
  /// itself).
  Future<SomeResolvedUnitResult> resolvedUnit(String path, [String? root]) =>
      _units[path] ??= () async {
        final library = await resolvedLibrary(root ?? path);
        if (library is ResolvedLibraryResult) {
          for (final unit in library.units) {
            if (unit.path == path) return unit;
          }
        }
        return session.getResolvedUnit(path);
      }();

  /// The element model of the library at [path] (no function bodies), or
  /// null when it is not a library.
  Future<LibraryElement?> library(String path) async {
    final uri = session.uriConverter.pathToUri(path);
    return uri == null ? null : libraryByUri('$uri');
  }

  /// The element model of the library named [uri], or null.
  Future<LibraryElement?> libraryByUri(String uri) async {
    final result = await session.getLibraryByUri(uri);
    return result is LibraryElementResult ? result.element : null;
  }
}

/// The caches of one app, kept by the long-lived worker.
class EntriesCache {
  /// A cache. With [retainResolved] the libraries a step resolved stay for
  /// a moment ([finish]) so the next step of the same update finds them;
  /// the worker sets it, a one-shot command has no use for it.
  EntriesCache({this.retainResolved = false});

  /// How many libraries were resolved (function bodies included) since this
  /// cache was made.
  var resolutions = 0;

  /// Whether [finish] keeps what was resolved for a moment.
  final bool retainResolved;
  ResolveMemo? _memo;
  Timer? _release;

  /// What [session] resolved in this run.
  ResolveMemo memoFor(AnalysisSession session) {
    _release?.cancel();
    final memo = _memo;
    if (memo != null && identical(memo.session, session)) return memo;
    return _memo = ResolveMemo._(session, () => resolutions++);
  }

  /// A step is done: what it resolved goes after a moment (it is the whole
  /// app's syntax trees), or now.
  void finish() {
    _release?.cancel();
    if (!retainResolved) {
      _memo = null;
      return;
    }
    _release = Timer(const Duration(seconds: 3), () => _memo = null);
  }

  final _infos = <String, _FileInfo>{};
  var _counter = 0;

  final _units = <String, (String, UnitFacts)>{};
  final _rows = <String, (String, RowFacts)>{};
  final _instances = <String, (String, List<String>)>{};
  final _called = <String, (String, CalledFacts)>{};

  /// Forgets everything: a package the app depends on changed, or the
  /// analysis started over.
  void clear() {
    _memo = null;
    _infos.clear();
    _units.clear();
    _rows.clear();
    _instances.clear();
    _perFile.clear();
    _called.clear();
  }

  final _perFile = <String, (int, Object?)>{};

  /// What [compute] finds in the text of [path], kept while the text is the
  /// same ([kind] tells the things kept apart).
  T perFile<T>(String kind, String path, T Function() compute) {
    final id = _infos[path]?.contentId;
    final known = _perFile['$kind $path'];
    if (id != null && known != null && known.$1 == id) return known.$2 as T;
    final value = compute();
    if (id != null) _perFile['$kind $path'] = (id, value);
    return value;
  }

  /// The graph of [files] (path → source, every Dart file of the app's
  /// `lib/`): only the files whose text changed are parsed again.
  AppGraph graph({
    required String app,
    required String package,
    required Map<String, String> files,
  }) {
    for (final path in _infos.keys.toList()) {
      if (!files.containsKey(path)) _infos.remove(path);
    }
    for (final MapEntry(key: path, value: source) in files.entries) {
      final known = _infos[path];
      if (known != null && known.source == source) continue;
      final parsed = _parse(path, source);
      _infos[path] = _FileInfo(
        source,
        ++_counter,
        parsed.api,
        // The same API keeps its id: dependents stay valid.
        known != null && known.api == parsed.api ? known.apiId : ++_counter,
        parsed.directives,
      );
    }
    return AppGraph._(app, package, _infos);
  }

  /// The misuse facts of [path] if they were made for [key].
  UnitFacts? unitFacts(String path, String key) {
    final known = _units[path];
    return known != null && known.$1 == key ? known.$2 : null;
  }

  /// Keeps the misuse facts of [path] made for [key].
  void putUnitFacts(String path, String key, UnitFacts facts) =>
      _units[path] = (key, facts);

  /// The names of the top-level states of [path] if they were found for
  /// [key].
  List<String>? instanceFacts(String path, String key) {
    final known = _instances[path];
    return known != null && known.$1 == key ? known.$2 : null;
  }

  /// Keeps the names of the top-level states of [path], found for [key].
  void putInstanceFacts(String path, String key, List<String> names) =>
      _instances[path] = (key, names);

  /// The row facts of [path] if they were made for [key].
  RowFacts? rowFacts(String path, String key) {
    final known = _rows[path];
    return known != null && known.$1 == key ? known.$2 : null;
  }

  /// Keeps the row facts of [path] made for [key].
  void putRowFacts(String path, String key, RowFacts facts) =>
      _rows[path] = (key, facts);

  /// The features reached from the library at [root] if they were made for
  /// [key] and the libraries they read have not changed.
  Set<String>? calledFacts(String root, String key, AppGraph graph) {
    final known = _called[root];
    if (known == null || known.$1 != key) return null;
    for (final MapEntry(key: path, value: text) in known.$2.reached.entries) {
      if (graph.contentKey(path) != text) return null;
    }
    return known.$2.features;
  }

  /// Keeps the features reached from the library at [root], made for [key].
  void putCalledFacts(String root, String key, CalledFacts facts) =>
      _called[root] = (key, facts);

  static ({String api, _Directives directives}) _parse(
    String path,
    String source,
  ) {
    final unit = parseString(
      content: source,
      path: path,
      throwIfDiagnostics: false,
    ).unit;
    final directives = _Directives();
    for (final d in unit.directives) {
      switch (d) {
        case ImportDirective():
          directives.depends.addAll(_uris(d.uri, d.configurations));
        case ExportDirective():
          directives.depends.addAll(_uris(d.uri, d.configurations));
        case PartDirective():
          directives.parts.addAll([?d.uri.stringValue]);
        case PartOfDirective():
          directives.partOf = d.uri?.stringValue ?? '${d.libraryName}';
          directives.partOfUri = d.uri != null;
        default:
      }
      final configurations = switch (d) {
        ImportDirective() => d.configurations.isNotEmpty,
        ExportDirective() => d.configurations.isNotEmpty,
        _ => false,
      };
      if (configurations) directives.conditional = true;
    }
    return (api: apiSignature(unit), directives: directives);
  }

  static Iterable<String> _uris(
    StringLiteral uri,
    List<Configuration> configurations,
  ) => [?uri.stringValue, for (final c in configurations) ?c.uri.stringValue];
}

class _Directives {
  /// The URIs this file imports or exports (every configuration).
  final depends = <String>[];

  /// The URIs of its `part` directives.
  final parts = <String>[];

  /// What `part of` names (a URI or a library name), or null.
  String? partOf;
  var partOfUri = false;

  /// Whether an import or export has an `if (dart.library…)`.
  var conditional = false;
}

class _FileInfo {
  _FileInfo(this.source, this.contentId, this.api, this.apiId, this.directives);

  final String source;
  final int contentId;
  final String api;
  final int apiId;
  final _Directives directives;
}

/// The libraries of an app's `lib/` (a library and its parts) and what they
/// import and export, as of one run.
class AppGraph {
  AppGraph._(this._app, this._package, Map<String, _FileInfo> infos)
    : _infos = Map.of(infos) {
    // Which library each part belongs to, and the parts of each library.
    for (final MapEntry(key: path, value: info) in _infos.entries) {
      if (info.directives.partOf == null) continue;
      final root = info.directives.partOfUri
          ? _resolve(path, info.directives.partOf!)
          : null;
      if (root != null &&
          _infos.containsKey(root) &&
          _infos[root]!.directives.partOf == null &&
          _infos[root]!.directives.parts.any(
            (u) => _resolve(root, u) == path,
          )) {
        _rootOf[path] = root;
      } else {
        // A part whose library can't be told: keys that name it depend on
        // every file.
        _orphans.add(path);
      }
    }
    for (final MapEntry(key: path, value: info) in _infos.entries) {
      if (info.directives.partOf != null) continue;
      _partsOf[path] = [
        for (final u in info.directives.parts)
          if (_resolve(path, u) case final part?)
            if (_rootOf[part] == path) part,
      ];
    }
  }

  final String _app;
  final String _package;
  final Map<String, _FileInfo> _infos;
  final _rootOf = <String, String>{};
  final _partsOf = <String, List<String>>{};
  final _orphans = <String>{};
  final _keys = <String, String>{};
  final _contentKeys = <String, String>{};

  /// The library [path] belongs to: itself unless it is a part. Null for a
  /// part whose library can't be told, or a file that is not in the graph.
  String? rootOf(String path) {
    final info = _infos[path];
    if (info == null) return null;
    if (info.directives.partOf == null) return path;
    return _rootOf[path];
  }

  /// Whether [path] is a library whose imports or exports pick a file by
  /// platform (`if (dart.library…)`), or has parts that do.
  bool isConditional(String path) =>
      _infos[path]?.directives.conditional ?? false;

  /// The libraries of the graph.
  Iterable<String> get roots => _partsOf.keys;

  /// A library and its parts.
  List<String> filesOf(String root) => [root, ...?_partsOf[root]];

  /// The text identity of the files of the library at [root]: equal while
  /// they are the same text. `-` for a path that is not there.
  String contentKey(String root) => _contentKeys[root] ??= [
    for (final f in filesOf(root)) '${_infos[f]?.contentId ?? '-'}',
  ].join('.');

  String _apiKey(String root) =>
      [for (final f in filesOf(root)) '${_infos[f]?.apiId ?? '-'}'].join('.');

  /// What the facts of [path] depend on: the text of its library and the
  /// public API of what that library depends on. Equal keys, same facts.
  String keyOf(String path) {
    final root = rootOf(path);
    if (root == null) return _everything();
    return _keys[root] ??= '${contentKey(root)}|${_closure(root).join(',')}';
  }

  String? _all;
  String _everything() => _all ??=
      '*${[for (final path in (_infos.keys.toList()..sort())) _infos[path]!.contentId].join('.')}';

  /// The tokens of the API of every app library [root] depends on,
  /// transitively, sorted; `!path` for one it names that is not there.
  List<String> _closure(String root) {
    final seen = <String>{root};
    final tokens = <String>{};
    final work = [root];
    while (work.isNotEmpty) {
      final current = work.removeLast();
      for (final file in filesOf(current)) {
        final info = _infos[file];
        if (info == null) continue;
        for (final uri in info.directives.depends) {
          final target = _resolve(file, uri);
          if (target == null) continue;
          final targetRoot = rootOf(target);
          if (targetRoot == null) {
            if (_infos.containsKey(target)) {
              // A part imported as a library: depends on everything.
              tokens.add('*${_everything()}');
            } else if (p.isWithin('$_app/lib', target)) {
              tokens.add('!$target');
            }
            continue;
          }
          if (seen.add(targetRoot)) {
            tokens.add(_apiKey(targetRoot));
            work.add(targetRoot);
          }
        }
      }
    }
    return tokens.toList()..sort();
  }

  /// The libraries [roots] depend on, transitively, and themselves.
  Set<String> closureOf(Iterable<String> roots) {
    final seen = <String>{};
    final work = [...roots];
    while (work.isNotEmpty) {
      final root = work.removeLast();
      if (!seen.add(root)) continue;
      for (final file in filesOf(root)) {
        final info = _infos[file];
        if (info == null) continue;
        for (final uri in info.directives.depends) {
          final target = _resolve(file, uri);
          if (target == null) continue;
          if (rootOf(target) case final targetRoot?) work.add(targetRoot);
        }
      }
    }
    return seen;
  }

  /// The file a `uri` written in [from] names, if it is in the app's
  /// `lib/`.
  String? _resolve(String from, String uri) {
    final Uri parsed;
    try {
      parsed = Uri.parse(uri);
    } on FormatException {
      return null;
    }
    if (parsed.scheme == 'package') {
      final segments = parsed.pathSegments;
      if (segments.isEmpty || segments.first != _package) return null;
      return p.joinAll([_app, 'lib', ...segments.skip(1)]);
    }
    if (parsed.hasScheme) return null;
    return p.normalize(p.join(p.dirname(from), p.joinAll(parsed.pathSegments)));
  }
}

/// The public shape of a Dart file: its tokens without the comments and
/// without the bodies and initializers that cannot change what code in
/// another library sees (the body of a function whose return type is
/// written, the value of a variable whose type is written). What stays is
/// exactly what could: written types, signatures, annotations, constants,
/// and the bodies of anything whose type is inferred from them.
String apiSignature(CompilationUnit unit) {
  final skipped = <(int, int)>[];
  unit.accept(_Bodies(skipped));
  skipped.sort((a, b) => a.$1.compareTo(b.$1));
  final out = StringBuffer();
  var next = 0;
  var t = unit.beginToken;
  while (!t.isEof) {
    while (next < skipped.length && skipped[next].$2 <= t.offset) {
      next++;
    }
    final inside =
        next < skipped.length &&
        t.offset >= skipped[next].$1 &&
        t.offset < skipped[next].$2;
    if (!inside) {
      out
        ..write(t.lexeme)
        ..write(' ');
    }
    t = t.next!;
  }
  return '$out';
}

class _Bodies extends RecursiveAstVisitor<void> {
  _Bodies(this.skipped);

  final List<(int, int)> skipped;

  /// Whether the classes being visited keep every initializer (a class with
  /// a const constructor: its fields' values are part of its constants).
  final _constClass = <bool>[];

  void _skip(AstNode node) => skipped.add((node.offset, node.end));

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final body = node.body;
    _constClass.add(
      body is BlockClassBody &&
          body.members.any(
            (m) => m is ConstructorDeclaration && m.constKeyword != null,
          ),
    );
    super.visitClassDeclaration(node);
    _constClass.removeLast();
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    _constClass.add(true);
    super.visitEnumDeclaration(node);
    _constClass.removeLast();
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    _constClass.add(false);
    super.visitMixinDeclaration(node);
    _constClass.removeLast();
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    _constClass.add(false);
    super.visitExtensionDeclaration(node);
    _constClass.removeLast();
  }

  @override
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) {
    // The representation's constructor is const-like.
    _constClass.add(true);
    super.visitExtensionTypeDeclaration(node);
    _constClass.removeLast();
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    // A top-level function (a local one is inside a body that is skipped, or
    // kept whole). A return type that is written does not depend on the body.
    if (node.parent is CompilationUnit &&
        (node.returnType != null || node.isSetter)) {
      _skip(node.functionExpression.body);
      node.functionExpression.parameters?.accept(this);
      return;
    }
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.returnType != null || node.isSetter) {
      _skip(node.body);
      node.parameters?.accept(this);
      return;
    }
    super.visitMethodDeclaration(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    // Initializers stay (a const constructor's are part of its constants).
    _skip(node.body);
    node.parameters.accept(this);
    for (final i in node.initializers) {
      i.accept(this);
    }
    node.redirectedConstructor?.accept(this);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    _variables(node.fields, keepAll: _constClass.lastOrNull ?? false);
    super.visitFieldDeclaration(node);
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    _variables(node.variables, keepAll: false);
    super.visitTopLevelVariableDeclaration(node);
  }

  void _variables(VariableDeclarationList list, {required bool keepAll}) {
    // `var x = …` and `final x = …` have the type of the value; a constant's
    // value is its identity.
    if (list.type == null || list.isConst || keepAll) return;
    for (final v in list.variables) {
      if (v.initializer case final init?) _skip(init);
    }
  }
}
