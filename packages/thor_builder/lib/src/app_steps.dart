/// The two analyzer steps `thor` runs on an app, as functions: the entries
/// (`.dart_tool/thor/`, `bin/entries.dart`) and the lite engine's states
/// (`bin/lite_state.dart`). The one-shot commands and the long-lived
/// worker of `thor dev` (`bin/worker.dart`, which keeps one analysis warm
/// across saves) run the same code and print the same lines.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:thor_engine/lite.dart' show writeFileIfChanged;
import 'package:thor_lints/lite.dart';

import 'app_entries.dart';
import 'entries_cache.dart';

/// The analysis of an app's `lib/` ([lib], absolute), as both steps want
/// it.
AnalysisContextCollection appAnalysis(String lib) =>
    AnalysisContextCollection(includedPaths: [lib]);

/// Writes `.dart_tool/thor/` of the app in [app] (absolute, symlinks
/// resolved; `lib/` and `pubspec.yaml` exist): what `thor_builder:entries`
/// does. Lines go to [out] and [err] as the command prints them; returns
/// its exit code (1 when a state class can't be listed, nothing written).
Future<int> writeAppEntries(
  String app, {
  required bool allFeatures,
  required StringSink out,
  required StringSink err,
  AnalysisContextCollection? analysis,
  EntriesCache? cache,
}) async {
  cache ??= EntriesCache();
  try {
    return await _writeAppEntries(
      app,
      allFeatures: allFeatures,
      out: out,
      err: err,
      analysis: analysis,
      cache: cache,
    );
  } finally {
    cache.finish();
  }
}

/// Every Dart file of the app's `lib/`, by path.
Map<String, String> _libSources(String lib) => {
  for (final f in Directory(lib).listSync(recursive: true))
    if (f is File && f.path.endsWith('.dart')) f.path: f.readAsStringSync(),
};

/// The name of the package in [app], or null without a pubspec.
String? _packageName(String app) {
  final pubspec = File('$app/pubspec.yaml');
  if (!pubspec.existsSync()) return null;
  return RegExp(
    r'^name:\s*(\S+)',
    multiLine: true,
  ).firstMatch(pubspec.readAsStringSync())?.group(1);
}

Future<int> _writeAppEntries(
  String app, {
  required bool allFeatures,
  required StringSink out,
  required StringSink err,
  required AnalysisContextCollection? analysis,
  required EntriesCache cache,
}) async {
  final lib = Directory('$app/lib');
  final package = _packageName(app)!;

  final files = _libSources(lib.path);
  final sources = {
    for (final e in files.entries)
      if (!e.key.endsWith('.thor.dart')) e.key: e.value,
  };
  final graph = cache.graph(app: app, package: package, files: files);
  // What the engine needs, from the text of each file (kept while it is the
  // same).
  final features = <String>{};
  var rowAttributes = false;
  for (final e in sources.entries) {
    final (found, attributes) = cache.perFile(
      'features',
      e.key,
      () => featuresOf([e.value]),
    );
    features.addAll(found);
    rowAttributes |= attributes;
  }

  // Resolve only what may hold states: files that declare one, then files
  // that create one (a top-level `final cart = CartState();`).
  final declaring = [
    for (final e in sources.entries)
      if (mentionsStates(e.value)) e.key,
  ]..sort();
  final collection = analysis ?? appAnalysis(lib.path);
  final context = collection.contextFor(lib.path);
  // Each library resolves once per update (the lite states ask for the same
  // files again), and only when the facts kept from the last one no longer
  // hold: resolving the bodies is most of the cost.
  final memo = cache.memoFor(context.currentSession);
  String rel(String path) =>
      path.startsWith('$app/') ? path.substring(app.length + 1) : path;

  // What the library at [path] calls, and what the functions of other files
  // it calls do (a helper `askDelete()` that calls `confirm(…)`).
  Future<Set<String>> calledBy(String path) async {
    final root = graph.rootOf(path) ?? path;
    final key = graph.keyOf(path);
    if (cache.calledFacts(root, key, graph) case final known?) return known;
    final result = await memo.resolvedLibrary(path);
    if (result is! ResolvedLibraryResult) return const {};
    final reached = <LibraryElement>{};
    final called = await featuresReachedFrom(
      [for (final u in result.units) u.unit],
      context.currentSession,
      inApp: (uri) =>
          uri.scheme == 'package' && uri.pathSegments.first == package,
      reached: reached,
    );
    cache.putCalledFacts(
      root,
      key,
      CalledFacts(called, {
        for (final r in reached)
          if (r.firstFragment.source.fullName case final reachedPath)
            reachedPath: graph.contentKey(reachedPath),
      }),
    );
    return called;
  }

  final classes = <(ClassElement, String)>[];
  // What each state's library asks the page for (`confirm`, `toast`).
  final uses = <ClassElement, Set<String>>{};
  final names = <String>{};
  for (final path in declaring) {
    final library = await memo.library(path);
    if (library == null) continue;
    Set<String>? called;
    for (final c in library.classes) {
      if (isRegisteredState(c)) {
        classes.add((c, rel(path)));
        called ??= await calledBy(path);
        if (called.isNotEmpty) uses[c] = called;
      }
      if (isThorStateType(c.thisType) && c.name != null) names.add(c.name!);
    }
  }
  // A helper in another file may be what calls `confirm(…)`: the engine
  // gets the feedback feature when any state reaches it.
  if (uses.isNotEmpty) features.add('FeedbackFeature');
  final instances = <(String, String)>[];
  // A file that makes a state: one of the names followed by `(`.
  final makes = names.isEmpty
      ? null
      : RegExp('(${names.map(RegExp.escape).join('|')})\\(');
  final creating = [
    for (final e in sources.entries)
      if ((makes != null && makes.hasMatch(e.value)) ||
          declaring.contains(e.key))
        e.key,
  ]..sort();
  for (final path in creating) {
    final key = graph.keyOf(path);
    var found = cache.instanceFacts(path, key);
    if (found == null) {
      final library = await memo.library(path);
      if (library == null) continue;
      found = [
        for (final v in library.topLevelVariables)
          if (v.name case final name?)
            if (!name.startsWith('_') && isThorStateType(v.type)) name,
      ];
      cache.putInstanceFacts(path, key, found);
    }
    for (final name in found) {
      instances.add(('package:$package/${rel(path).substring(4)}', name));
    }
  }

  // The misuses the browser can't run (a closure as a callback, a state
  // that is not top-level): files that name a state class or a top-level
  // state.
  final used = {...names, for (final (_, name) in instances) name};
  final misuses = <String>[];
  final warnings = <String>[];
  final usedPattern = used.isEmpty ? null : statesPattern(used);
  for (final path in sources.keys.toList()..sort()) {
    final source = sources[path]!;
    if (!(usedPattern?.hasMatch(source) ?? false) &&
        !cache.perFile('silent', path, () => mayFailSilently(source))) {
      continue;
    }
    final key = graph.keyOf(path);
    var facts = cache.unitFacts(path, key);
    if (facts == null) {
      final result = await memo.resolvedUnit(path, graph.rootOf(path));
      if (result is! ResolvedUnitResult) continue;
      facts = UnitFacts(
        stateMisuses(result.unit, rel(path)),
        stateWarnings(result.unit, rel(path)),
      );
      cache.putUnitFacts(path, key, facts);
    }
    misuses.addAll(facts.misuses);
    warnings.addAll(facts.warnings);
  }

  // The pages' action methods: files that may declare a page.
  final pages = <(ClassElement, String)>[];
  for (final path in sources.keys.toList()..sort()) {
    if (!cache.perFile(
      'actions',
      path,
      () => mayDeclareActions(sources[path]!),
    )) {
      continue;
    }
    final library = await memo.library(path);
    if (library == null) continue;
    for (final c in library.classes) {
      if (isPageClass(c)) pages.add((c, rel(path)));
    }
  }

  final problems = <EntryProblem>[];
  // `row.text((o) => o.customer)`: the row classes that need a probe, and the
  // lambdas that do more than read a property.
  final rowItems = <InterfaceElement>{};
  final rowProperties = <String>{};
  final rowStates = <String, int>{};
  for (final path in sources.keys.toList()..sort()) {
    final source = sources[path]!;
    if (!source.contains('WatchRow') && !source.contains('Watch.list')) {
      continue;
    }
    final facts = await _rowFacts(path, rel(path), cache, graph, memo);
    if (facts == null) continue;
    for (final event in facts.events) {
      if (event.message case final message?) {
        problems.add(EntryProblem(rel(path), message));
        continue;
      }
      final item = await _rowItem(event, memo);
      if (item != null) rowItems.add(item);
      rowProperties.add(event.property!);
      if (event.states case final n?) rowStates[event.property!] = n;
    }
  }
  final states = statesLibrary(
    classes,
    warn: err.writeln,
    problems: problems,
    uses: uses,
    rowItems: rowItems,
  );
  final actions = actionsLibrary(pages, problems: problems);
  if (problems.isNotEmpty) {
    problems.forEach(err.writeln);
    return 1;
  }
  final dir = Directory('$app/.dart_tool/thor')..createSync(recursive: true);
  final written = <String>[];
  void write(String name, String? content) {
    final file = File('${dir.path}/$name');
    if (content == null) {
      if (file.existsSync()) file.deleteSync();
      return;
    }
    // Whole or not at all: `thor dev` reads these while another run may be
    // writing them (a half-written finding would show as an error).
    if (writeFileIfChanged(file, content)) written.add(name);
  }

  write('states.dart', states);
  write('actions.dart', actions);
  // Errors and warnings share the file, one line each; only `Error` fails.
  misuses.addAll(warnings);
  write(stateMisusesFile, misuses.isEmpty ? null : '${misuses.join('\n')}\n');
  misuses.forEach(out.writeln);
  final entry = File('$app/bin/server.dart').existsSync()
      ? '../../bin/server.dart'
      : File('$app/lib/main.server.dart').existsSync()
      ? 'package:$package/main.server.dart'
      : null;
  write(
    'server.dart',
    entry == null ? null : serverEntry(entry, actions: actions != null),
  );
  // `thor export` pre-renders with the app's bin/export.dart: same registry.
  write(
    'export.dart',
    File('$app/bin/export.dart').existsSync()
        ? serverEntry('../../bin/export.dart', actions: actions != null)
        : null,
  );
  final engine =
      instances.isNotEmpty || features.any(standaloneFeatures.contains);
  write(
    'engine.dart',
    engine
        ? engineEntry(
            instances,
            features: features,
            rowAttributes: rowAttributes,
            animatedRows: animatedRowsIn(sources.values),
            virtualLists: usesVirtualLists(sources.values),
            allFeatures: allFeatures,
            rowProperties: rowProperties,
            rowStates: rowStates,
          )
        : null,
  );
  // Every function passed to `query(...)` answers the browser: listed, so
  // nothing becomes an endpoint silently.
  final endpoints = queryEndpoints([for (final (c, _) in classes) c]);
  if (endpoints.isNotEmpty) {
    out.writeln(
      'query endpoints (POST to the page that uses the state, through its '
      'middleware): ${endpoints.join(', ')}',
    );
  }
  // And every function passed to `command(...)`.
  final commands = commandEndpoints([for (final (c, _) in classes) c]);
  if (commands.isNotEmpty) {
    out.writeln(
      'command endpoints (POST to the page that uses the state, through its '
      'middleware): ${commands.join(', ')}',
    );
  }
  out.writeln(
    '.dart_tool/thor: ${classes.length} state class(es), '
    '${instances.length} on pages'
    '${actions == null ? '' : ', ${pages.length} page class(es)'}'
    '${written.isEmpty ? '' : ', wrote ${written.join(', ')}'}',
  );
  return 0;
}

/// The row lambdas of [path] (shown as [shown]), kept for the library's
/// key. Null when the file does not resolve.
Future<RowFacts?> _rowFacts(
  String path,
  String shown,
  EntriesCache cache,
  AppGraph graph,
  ResolveMemo memo,
) async {
  final key = graph.keyOf(path);
  if (cache.rowFacts(path, key) case final known?) return known;
  final result = await memo.resolvedUnit(path, graph.rootOf(path));
  if (result is! ResolvedUnitResult) return null;
  final events = <RowEvent>[];
  for (final lambda in rowLambdasIn(result.unit, shown)) {
    if (lambda.message case final message?) {
      events.add(RowEvent.problem(message));
    } else {
      final item = lambda.item!;
      events.add(
        RowEvent.property(
          '${item.library.uri}',
          item.name!,
          lambda.property!,
          lambda.states,
        ),
      );
    }
  }
  final facts = RowFacts(events);
  cache.putRowFacts(path, key, facts);
  return facts;
}

/// The row class a kept row lambda reads a property of, from the analysis.
Future<InterfaceElement?> _rowItem(RowEvent event, ResolveMemo memo) async {
  final library = await memo.libraryByUri(event.itemLibrary!);
  final name = event.itemName!;
  return library?.getClass(name) ??
      library?.getEnum(name) ??
      library?.getMixin(name) ??
      library?.getExtensionType(name);
}

/// Every resolved unit of the package in [app] (absolute), shown relative
/// to it. [cache] shares what was resolved with the other steps of the
/// update.
Future<List<LiteUnit>> _appUnits(
  String app,
  AnalysisContextCollection collection, {
  EntriesCache? cache,
}) async {
  final units = <LiteUnit>[];
  final prefix = '$app/';
  for (final context in collection.contexts) {
    final files = context.contextRoot.analyzedFiles().toList()..sort();
    final memo = cache?.memoFor(context.currentSession);
    for (final path in files) {
      // Parts come with their library; generated libraries (the app's
      // messages) are the app's code.
      if (!path.endsWith('.dart')) continue;
      // The file `thor analyze` drops in lib/ to prove its lints run
      // (`Completer.sync` on purpose) is not the app's code.
      if (path == '${prefix}lib/zz_thor_canary.dart') continue;
      final result = memo == null
          ? await context.currentSession.getResolvedLibrary(path)
          : await memo.resolvedLibrary(path);
      if (result is! ResolvedLibraryResult) continue;
      for (final unit in result.units) {
        final p = unit.path;
        units.add(
          LiteUnit(
            p.startsWith(prefix) ? p.substring(prefix.length) : p,
            unit.unit,
          ),
        );
      }
    }
  }
  return units;
}

/// Checks the package in [app] (absolute) against the lite subset without
/// writing anything: `dart run thor_builder:lite_state <dir> --check`, and
/// `thor analyze`. Its `ThorState` classes and what they reach count, as in
/// the build; a package with no state counts **every** data class (a
/// `fromJson`), so one that only declares the classes other packages'
/// `events<T>`, `query` and `state<T>` send to the browser is checked
/// before an app uses it. Returns 0 when it fits (or has nothing to
/// check), 1 with the constructs printed to [err] otherwise.
Future<int> checkLitePackage(
  String app, {
  required StringSink out,
  required StringSink err,
  AnalysisContextCollection? analysis,
}) async {
  final collection = analysis ?? appAnalysis('$app/lib');
  final check = checkLiteSubset(await _appUnits(app, collection));
  if (!check.ok) {
    err.writeln(LiteTranslationException(check.errors).report);
    return 1;
  }
  if (check.empty) {
    out.writeln('Nothing to check: no ThorState and no data class (fromJson).');
  } else {
    out.writeln(
      'Inside the lite subset: ${check.states} state(s), '
      '${check.dataClasses} data class(es).',
    );
  }
  return 0;
}

/// Writes the app's ThorState classes (the app in [app], absolute) as JS
/// for the lite engine into [outPath]: what `thor_builder:lite_state`
/// does. [readable] keeps the Dart names. Lines go to [out] and [err] as
/// the command prints them; returns its exit code (1 when something is
/// outside the lite subset, nothing written).
Future<int> writeLiteStates(
  String app, {
  required String outPath,
  required bool readable,
  required StringSink out,
  required StringSink err,
  AnalysisContextCollection? analysis,
  EntriesCache? cache,
}) async {
  cache ??= EntriesCache();
  try {
    return await _writeLiteStates(
      app,
      outPath: outPath,
      readable: readable,
      out: out,
      err: err,
      analysis: analysis,
      cache: cache,
    );
  } finally {
    cache.finish();
  }
}

Future<int> _writeLiteStates(
  String app, {
  required String outPath,
  required bool readable,
  required StringSink out,
  required StringSink err,
  required AnalysisContextCollection? analysis,
  required EntriesCache cache,
}) async {
  final lib = '$app/lib';
  final collection = analysis ?? appAnalysis(lib);
  // Every library: the translator reads the whole app (what a state reaches
  // is found while it translates, and some of its choices depend on every
  // class of the app).
  final units = await _appUnits(app, collection, cache: cache);
  // A data class that crosses the wire to a state (a `state(...)` field,
  // a `query`, `events<T>` or `command` type) that another package declares
  // (a workspace package's model): the registry lists it
  // (`registerJsonModel`), so the browser needs its `fromJson` and `toJson`
  // too, and so the libraries it is written with.
  final known = {
    for (final u in units)
      if (u.unit.declaredFragment?.element case final LibraryElement l) l,
  };
  for (final u in [...units]) {
    for (final d in u.unit.declarations.whereType<ClassDeclaration>()) {
      final element = d.declaredFragment?.element;
      if (element == null) continue;
      for (final f in element.fields) {
        for (final model in wireModels(f.type)) {
          for (final library in modelLibraries(model.library)) {
            if (!known.add(library)) continue;
            final result = await library.session.getResolvedLibraryByElement(
              library,
            );
            if (result is! ResolvedLibraryResult) continue;
            for (final unit in result.units) {
              units.add(LiteUnit(unit.uri.toString(), unit.unit));
            }
          }
        }
      }
    }
  }
  final String js;
  try {
    js = translateLiteStates(
      units,
      shortNames: !readable,
      header:
          '// GENERATED CODE - DO NOT MODIFY BY HAND (thor_builder, '
          'bin/lite_state.dart).\n'
          "// The app's ThorState classes for the thor-lite runtime.\n",
    );
  } on LiteTranslationException catch (e) {
    err.writeln(e.report);
    return 1;
  }
  final file = File(outPath);
  writeFileIfChanged(file, js);
  out.writeln('${file.path} (${js.length} bytes)');
  return 0;
}

/// The data classes (`fromJson` and `toJson`, see `jsonStateModel`) that a
/// state field of type [t] sends to the browser or gets back from it: the
/// value of a `state(...)`, a query's argument and result, the data of an
/// `events<T>`, a command's argument and result.
Iterable<InterfaceElement> wireModels(DartType t) sync* {
  if (t is! InterfaceType) return;
  for (final s in [t, ...t.allSupertypes]) {
    if (!'${s.element.library.uri}'.startsWith('package:thor_engine/')) {
      continue;
    }
    if (!const {
      'StateSignal',
      'ServerQuery',
      'ServerCommandBase',
    }.contains(s.element.name)) {
      continue;
    }
    for (final a in s.typeArguments) {
      if (jsonStateModel(a) case final model?) yield model.element;
    }
    return;
  }
}

/// [start] and what a data class written in it needs to be translated: the
/// libraries of its package that it imports or exports (a model split in
/// files), and the libraries (of any package) of the data classes its fields
/// hold.
Set<LibraryElement> modelLibraries(LibraryElement start) {
  String? package(LibraryElement l) {
    final uri = l.uri;
    return uri.scheme == 'package' ? uri.pathSegments.first : null;
  }

  final seen = <LibraryElement>{};
  final queue = [start];
  while (queue.isNotEmpty) {
    final library = queue.removeLast();
    if (library.uri.scheme == 'dart' || !seen.add(library)) continue;
    final mine = package(library);
    for (final fragment in library.fragments) {
      for (final target in [
        for (final i in fragment.libraryImports) i.importedLibrary,
        for (final e in fragment.libraryExports) e.exportedLibrary,
      ]) {
        if (target != null && mine != null && package(target) == mine) {
          queue.add(target);
        }
      }
    }
    for (final c in library.classes) {
      if (!isJsonDataClass(c)) continue;
      for (final f in c.fields) {
        if (jsonStateModel(f.type) case final model?) {
          queue.add(model.element.library);
        }
      }
    }
  }
  return seen;
}
