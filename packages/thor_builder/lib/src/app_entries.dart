/// What `thor` generates for an app, in `.dart_tool/thor/` (never in the
/// app's own folders, never imported by its code):
///
/// - `states.dart`: `registerThorStates()`, the member list of every
///   `ThorState` class of `lib/` (names, tear-offs, how the browser calls
///   each one, the values of a finite state). Dart can't list a class's
///   members while it runs (no reflection in an AOT server or in dart2js),
///   so the build writes it.
/// - `server.dart`: the server entry: registers the states and runs the
///   app's `bin/server.dart` (or a static app's `lib/main.server.dart`).
/// - `actions.dart`: `registerThorActions()`, the action methods of every
///   `ThorPage` class of `lib/`: their names, how to tear them off a
///   page and the schema each one checks first. Kept out of `states.dart`
///   because the browser's entry imports that one.
/// - `engine.dart`: the dart2js engine entry of the internal oracle
///   (`thor_engine_oracle`; thor ships the lite engine): registers
///   the states and starts the engine with the app's top-level states and
///   the features its sources use. Its existence also says the app has
///   pages with browser state.
///
/// `thor dev`, `thor build`, `thor test` and `thor render` write and run
/// them; `dart run bin/server.dart` without thor meets THOR-S010 on the
/// first state it renders.
library;

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:thor_lints/lite.dart';
import 'package:thor_lints/silent_failures.dart';
import 'package:thor_lints/state_misuse.dart';

import 'errors.dart';

/// The file (in `.dart_tool/thor/`) that lists the state misuses the last
/// run found, one per line; absent when there are none. `thor dev` shows
/// them on the page, `thor build` fails with them.
const stateMisusesFile = 'state_misuses.txt';

/// The code in [unit] that works but shows stale data in the browser: a
/// state read while the server draws the page (THOR-S015) and a state
/// member called with the row's key in a list row's builder (THOR-S034), as
/// `lib/x.dart:12:5: Warning: …`. They go in the same file as the errors
/// (`state_misuses.txt`); only an `Error` line stops `thor build`.
List<String> stateWarnings(CompilationUnit unit, String path) => _describeAll(
  [...findFrozenReads(unit), ...findRowServerReads(unit)],
  unit,
  path,
);

/// The code in [unit] (resolved; [path] relative to the app) that the
/// browser can't run, one line each, as a compiler writes an error (`thor
/// dev` shows it with its code): `lib/x.dart:12:5: Error: … (THOR-S011 · …)
/// fix.` A closure where a state's member goes, a state that is not
/// top-level, `setState` (THOR-S014) and an `AnimatedSwitcher` with nothing to
/// switch (THOR-S016). The detection is thor_lints' (the
/// editor flags the same code).
List<String> stateMisuses(CompilationUnit unit, String path) => _describeAll(
  [
    ...findStateMisuses(unit),
    ...findSetStateCalls(unit),
    ...findSwitcherMisuses(unit),
    ...findDerivedWrites(unit),
  ],
  unit,
  path,
);

List<String> _describeAll(
  List<StateMisuse> found,
  CompilationUnit unit,
  String path,
) => [
  for (final m in [...found]..sort((a, b) => a.offset.compareTo(b.offset)))
    _describe(m, unit, path),
];

String _describe(StateMisuse m, CompilationUnit unit, String path) {
  final at = unit.lineInfo.getLocation(m.offset);
  // One line each: a message that quotes multi-line code would otherwise
  // become lines with no `Warning:` and fail the build.
  return '$path:${at.lineNumber}:${at.columnNumber}: '
          '${m.warning ? 'Warning' : 'Error'}: '
          '${thorError(m.code, m.message)} ${m.correction}'
      .replaceAll(RegExp(r'\s*\n\s*'), ' ');
}

/// Whether [source] may hold a silent failure that needs no state:
/// `setState` (THOR-S014) or an `AnimatedSwitcher` (THOR-S016).
bool mayFailSilently(String source) =>
    source.contains('setState') || source.contains('AnimatedSwitcher');

/// Whether [source] may misuse a state: it names a state class or one of
/// the app's top-level states ([names]), so it is worth resolving.
bool mayUseStates(String source, Set<String> names) =>
    names.isNotEmpty && statesPattern(names).hasMatch(source);

/// What [mayUseStates] looks for in a source: one of [names] as a word.
RegExp statesPattern(Set<String> names) =>
    RegExp('\\b(${names.map(RegExp.escape).join('|')})\\b');

// `Gesture(` and the Flutter names over it (`GestureDetector`, `InkWell`,
// `InkResponse`), not a name that only ends like them.
final _gestureWidget = RegExp(
  r'(?<![\w.])(Gesture|GestureDetector|InkWell|InkResponse)\(',
);

/// Engine feature class → does a source use it (the app's `lib/` sources,
/// by text: dart2js drops the features no page needs).
final engineFeatures = <String, bool Function(String source)>{
  'VariantsFeature': (s) => s.contains('Watch') && s.contains('builder:'),
  'ListsFeature': (s) => s.contains('each:') || s.contains('AnimatedList'),
  'FormsFeature': (s) => s.contains('Form('),
  'CommandsFeature': (s) =>
      s.contains('DialogTrigger(') || s.contains('DialogClose('),
  'TransitionsFeature': (s) => s.contains('onEnd:'),
  'KeyboardFeature': _gestureWidget.hasMatch,
  // Callbacks the delegated `data-t-on` cannot carry (`toggle` and `scroll`
  // do not bubble; enter/leave/focus need the related target).
  'ElementEventsFeature': (s) =>
      RegExp(
        r'\bon(Enter|Exit|FocusChange|ExpansionChanged|PageChanged):',
      ).hasMatch(s) ||
      RegExp(r'(?<![\w.])SplitPane\(').hasMatch(s),
  // The size follows the content: the browser is told after the fact.
  'SizeAnimationsFeature': (s) =>
      RegExp(r'\b(AnimatedSize|AnimatedCrossFade)\(').hasMatch(s),
  // A carousel's controls (browsers without `::scroll-button`) and the one
  // that moves by itself.
  'CarouselFeature': (s) => RegExp(r'\bCarouselView\(').hasMatch(s),
  // A `SplitPane`: its divider's pointer and keys (and `onChanged`, which
  // is an element event).
  'SplitPaneFeature': (s) => RegExp(r'(?<![\w.])SplitPane\(').hasMatch(s),
  'GesturesFeature': (s) =>
      _gestureWidget.hasMatch(s) &&
      RegExp(
        r'on(DoubleTap|LongPress|Swipe|DragUpdate|DragEnd|ScaleEnd|PanUpdate|'
        r'PanEnd|HorizontalDragEnd|VerticalDragEnd):',
      ).hasMatch(s),
  // A row dragged away (or keyed away): `Dismissible(`, not a name that only
  // ends like it.
  'DismissibleFeature': (s) => RegExp(r'(?<![\w.])Dismissible\(').hasMatch(s),
  // Draggables and the targets they drop on (the pointer ones and the
  // browser's own, `NativeDraggable`), with or without a type argument.
  'DragDropFeature': (s) => RegExp(
    r'(?<![\w.])(Draggable|LongPressDraggable|DragTarget|NativeDraggable|'
    r'NativeDragTarget)(<[^;{}()]*>)?\(',
  ).hasMatch(s),
  // A list whose items are dragged into another place.
  'ReorderableFeature': (s) => RegExp(
    r'(?<![\w.])ReorderableListView(\.builder)?(<[^;{}()]*>)?\(',
  ).hasMatch(s),
  // A controller in a ThorState (the class's own file): one that is not
  // is a CSS animation and needs no engine.
  'AnimationsFeature': (s) =>
      s.contains('AnimationController(') && _declaresState(s),
  // `Shortcuts`, `Actions` and `Focus(onKeyEvent:)` share its key walk.
  'ShortcutsFeature': (s) =>
      s.contains('Shortcuts(') ||
      s.contains('HardwareKeyboard.') ||
      RegExp(r'(?<![\w.])Actions\s*\(|\bonKeyEvent\s*:').hasMatch(s),
  'ControllersFeature': (s) =>
      s.contains('ScrollController(') ||
      s.contains('PageController(') ||
      s.contains('TextEditingController(') ||
      s.contains('FocusNode(') ||
      s.contains('DialogController(') ||
      s.contains('SystemNavigator.') ||
      s.contains('PageNavigator.'),
  // `BoundLength` (`card.radius.px`: a field or method followed by `.px`,
  // not a number's `16.px` or the `Length.px(…)` constructor) makes the
  // same bindings by itself.
  'VariablesFeature': (s) =>
      s.contains('WatchVariables(') ||
      s.contains('WatchAttributes(') ||
      s.contains('BoundLength(') ||
      RegExp(r'\b[A-Za-z_]\w*\.px\b(?!\()').hasMatch(s),
  'ClipboardFeature': (s) => s.contains('Clipboard.'),
  // `confirm(…)` / `toast(…)` of a state method (the page's own dialog and
  // snack bar do the rest; a member of the same name has a `.` before it).
  'FeedbackFeature': (s) =>
      RegExp(
        r'(?<![.\w])(confirm|toast|hideToast|clearToasts)\(',
      ).hasMatch(s) &&
      _declaresState(s),
  // `state(…, cookie: 'name')` / `state(…, local: 'name')`: a field
  // persisted in the browser.
  'PersistedStatesFeature': (s) =>
      s.contains('state(') && (s.contains('cookie:') || s.contains('local:')),
  // `events(url)` in a state: the browser opens an `EventSource` for it.
  'EventsFeature': (s) =>
      // A field initializer (`final feed = events<…>(`), not a method that
      // happens to be named `events`.
      RegExp(r'\bfinal\b[^;=]*=\s*events\s*[<(]').hasMatch(s) &&
      _declaresState(s),
  // A state that overrides `dispose()`: it ends when the page stops naming
  // it, not only with the page.
  'LifecycleFeature': (s) =>
      _declaresState(s) && RegExp(r'\bvoid\s+dispose\(\)').hasMatch(s),
  'DatePickerFeature': (s) =>
      s.contains('CalendarDatePicker(') ||
      s.contains('DatePickerDialog(') ||
      s.contains('DatePickerFormField(') ||
      s.contains('TimePickerDialog('),
  // `DropdownMenu(` or `DropdownMenu<T>(`, not `DropdownMenuEntry(`.
  'DropdownMenuFeature': (s) =>
      RegExp(r'\bDropdownMenu(<[^;{}()]*>)?\(').hasMatch(s),
  // The tabs' and the menus' keyboard (the lite engine's `tabs` and `menu`
  // parts).
  'TabsFeature': (s) => RegExp(r'(?<![\w.])TabBar\(').hasMatch(s),
  'MenuFeature': (s) => RegExp(
    r'(?<![\w.])(PopupMenuButton|MenuAnchor|SubmenuButton)\(',
  ).hasMatch(s),
  // `Autocomplete(`, `Autocomplete<T>(`, `RawAutocomplete(`.
  'AutocompleteFeature': (s) =>
      RegExp(r'\b(Raw)?Autocomplete(<[^;{}()]*>)?\(').hasMatch(s),
};

/// Features that work without any `ThorState` (a date picker in a form
/// that posts): the app still gets an engine.
const standaloneFeatures = {
  'AutocompleteFeature',
  'DatePickerFeature',
  'DropdownMenuFeature',
};

/// Whether [source] declares a state class.
bool _declaresState(String source) => source.contains('extends ThorState');

/// Whether [source] may hold a state class or a top-level state (worth
/// resolving).
bool mentionsStates(String source) => _declaresState(source);

/// Whether [c] is a state class this registry lists: it extends
/// `ThorState` itself.
bool isRegisteredState(ClassElement c) {
  if (c.name == null) return false;
  final superclass = c.supertype?.element;
  return superclass != null &&
      superclass.name == 'ThorState' &&
      (superclass.library.uri.toString().startsWith('package:thor_engine/'));
}

/// Whether [type] is a `ThorState` (for the engine's list of instances).
bool isThorStateType(DartType type) =>
    type is InterfaceType &&
    (type.element.name == 'ThorState' ||
        type.allSupertypes.any((t) => t.element.name == 'ThorState'));

/// A problem that stops the generation (a class the registry can't list).
class EntryProblem {
  /// [message] about [path].
  EntryProblem(this.path, this.message);

  /// The file, relative to the app.
  final String path;

  /// What is wrong and how to fix it (with its THOR code).
  final String message;

  @override
  String toString() => '$path: $message';
}

/// The page features the code of [units] asks markup for: `confirm` and
/// `toast` (also `hideToast` and `clearToasts`), when it calls thor's functions of those names (not a member of
/// the same name of its own). A page that uses a state whose file calls
/// them ships the shared dialog or snack bar; no other page does.
Set<String> featuresCalledIn(Iterable<CompilationUnit> units) {
  final found = <String>{};
  for (final unit in units) {
    unit.accept(_FeatureCalls(found));
  }
  return found;
}

/// [featuresCalledIn] and the same of every function or method of the app
/// that [units] call from another library (a helper `askDelete()` of
/// another file that calls `confirm(…)`), followed through [session]
/// transitively. [inApp] says whether a library is the app's (packages are
/// not followed). A call through a tear-off (`run(askDelete)`) counts too.
/// The libraries whose function bodies were read go to [reached].
Future<Set<String>> featuresReachedFrom(
  Iterable<CompilationUnit> units,
  AnalysisSession session, {
  required bool Function(Uri library) inApp,
  Set<LibraryElement>? reached,
}) async {
  final found = featuresCalledIn(units);
  final own = {for (final u in units) u.declaredFragment?.element};
  final seen = <ExecutableElement>{};
  final work = <ExecutableElement>[];
  void collect(AstNode node) {
    final callees = _Callees();
    node.accept(callees);
    for (final e in callees.elements) {
      final base = e.baseElement;
      if (!own.contains(base.library) &&
          inApp(base.library.uri) &&
          seen.add(base)) {
        work.add(base);
      }
    }
  }

  for (final u in units) {
    collect(u);
  }
  final libraries = <LibraryElement, ResolvedLibraryResult?>{};
  // A very large app never makes this loop long: each function once.
  while (work.isNotEmpty && seen.length < 5000) {
    final e = work.removeLast();
    final lib = e.library;
    reached?.add(lib);
    final result = libraries[lib] ??= await session
        .getResolvedLibraryByElement(lib)
        .then((r) => r is ResolvedLibraryResult ? r : null);
    final declaration = result?.getFragmentDeclaration(e.firstFragment)?.node;
    if (declaration == null) continue;
    declaration.accept(_FeatureCalls(found));
    collect(declaration);
  }
  return found;
}

/// The functions and methods a piece of code calls or tears off.
class _Callees extends RecursiveAstVisitor<void> {
  final elements = <ExecutableElement>{};

  void _add(Element? e) {
    if (e is TopLevelFunctionElement || e is MethodElement) {
      elements.add(e! as ExecutableElement);
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _add(node.methodName.element);
    super.visitMethodInvocation(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // A tear-off: `run(askDelete)`, `onPressed: dialogs.sure`.
    if (!node.inDeclarationContext()) _add(node.element);
    super.visitSimpleIdentifier(node);
  }
}

class _FeatureCalls extends RecursiveAstVisitor<void> {
  _FeatureCalls(this.found);

  final Set<String> found;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    final element = node.methodName.element;
    if ((name == 'confirm' || name == 'toast') &&
        element is TopLevelFunctionElement &&
        '${element.library.uri}'.startsWith('package:thor_engine/')) {
      found.add(name);
    }
    // Hiding needs the snack bar's markup and script as much as showing.
    if ((name == 'hideToast' || name == 'clearToasts') &&
        element is TopLevelFunctionElement &&
        '${element.library.uri}'.startsWith('package:thor_engine/')) {
      found.add('toast');
    }
    super.visitMethodInvocation(node);
  }
}

/// `states.dart`: the registry of [classes] (each with the app-relative
/// path of its file, for messages). Members the registry can't call are
/// reported to [warn]; classes it can't list at all go to [problems].
String statesLibrary(
  List<(ClassElement, String)> classes, {
  required void Function(String) warn,
  required List<EntryProblem> problems,
  Map<ClassElement, Set<String>> uses = const {},
  Set<InterfaceElement> rowItems = const {},
}) {
  final imports = _Imports();
  final entries = <String>[];
  final models = <InterfaceElement>{};
  // The page, the protocol and the browser name a state by its class name
  // alone: two classes with one name would answer for each other.
  final firstOf = <String, String>{};
  for (final (c, path) in classes) {
    firstOf.putIfAbsent(c.name ?? '', () => path);
  }
  final seen = <String>{};
  for (final (c, path) in classes) {
    final name = c.name ?? '';
    if (!seen.add(name)) {
      problems.add(
        EntryProblem(
          path,
          thorError(
            'THOR-B036',
            'the state class $name is also declared in ${firstOf[name]}. In '
                'Flutter two classes with one name in different files are '
                'legal, but a Thor state travels to the browser, and the page, '
                'the protocol and the browser name it by its class name alone: '
                'two with one name would answer for each other. Rename one of '
                'them, prefixing it with its page or feature (for example '
                '${_prefixed(name, path)}).',
          ),
        ),
      );
      continue;
    }
    if (name.startsWith('_') || c.typeParameters.isNotEmpty || c.isAbstract) {
      problems.add(
        EntryProblem(
          path,
          thorError(
            'THOR-B018',
            'the state class $name must be public, concrete and without type '
                'parameters: the generated registry names it from outside '
                'its file.',
          ),
        ),
      );
      continue;
    }
    final calls = <String>[];
    final members = _members(c, path, imports, warn, problems, calls, models);
    if (members == null) continue;
    final type = imports.ref(c);
    // The query and command fields: the only ids the server answers
    // (a build manifest).
    // Collected where the members are built, never re-parsed from their
    // text: a record or class argument adds codecs after the id.
    entries.add(
      "$type: ThorStateType('${_esc(name)}', (state) {\n"
      '  final s = state as $type;\n'
      '  return [\n${members.map((m) => '    $m,').join('\n')}\n  ];\n'
      '}, calls: const {${calls.map((id) => "'${_esc(id)}'").join(', ')}}'
      '${uses[c]?.isNotEmpty ?? false ? ", uses: const {${(uses[c]!.toList()..sort()).map((u) => "'${_esc(u)}'").join(', ')}}" : ''}'
      // Only a class that overrides `dispose` lives as long as the page
      // names it (the browser engine's `LifecycleFeature`).
      '${stateMethods(c).any((m) => m.name == 'dispose') ? ', disposes: true' : ''}),',
    );
  }
  // The probes of the row classes a `row.text((o) => o.customer)` reads: the
  // server learns which property the lambda reads from them.
  final probes = <String>[];
  final probeClasses = <String>[];
  final sortedItems = rowItems.toList()
    ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
  for (var i = 0; i < sortedItems.length; i++) {
    final item = sortedItems[i];
    final type = imports.ref(item);
    probes.add('    $type: (log) => _RowProbe$i(log),');
    probeClasses.add(_probeClass(i, type, item, imports));
  }
  // The classes the `state(...)` fields hold: the engine reads and writes
  // them as JSON with their own `toJson()` and `fromJson`.
  final modelLines = [
    for (final m in models.toList()..sort((a, b) => a.name!.compareTo(b.name!)))
      _registerModel(imports.ref(m)),
  ];
  final out = StringBuffer()
    ..writeln('// GENERATED BY thor - DO NOT MODIFY OR IMPORT FROM THE APP.')
    ..writeln(
      "// The members of the app's ThorState classes (see "
      'ThorState.register).',
    )
    ..writeln('// ignore_for_file: type=lint')
    ..writeln()
    ..writeln(
      "import 'package:thor_ui/thor_ui.dart' "
      'show ThorMember, ThorState, ThorStateType, splitArgs'
      '${models.isEmpty ? '' : ', registerJsonModel'}'
      '${probes.isEmpty ? '' : ', RowProbeLog, registerRowProbes'};',
    );
  imports.writeTo(out);
  out
    ..writeln()
    ..writeln("/// Registers the app's state classes.")
    ..writeln('void registerThorStates() {')
    ..writeAll(modelLines.map((l) => '$l\n'))
    ..writeln('  ThorState.register({')
    ..writeAll(entries.map((e) => '$e\n'))
    ..writeln('  });');
  if (probes.isNotEmpty) {
    out
      ..writeln('  registerRowProbes({')
      ..writeAll(probes.map((p) => '$p\n'))
      ..writeln('  });');
  }
  out.writeln('}');
  for (final c in probeClasses) {
    out
      ..writeln()
      ..write(c);
  }
  return '$out';
}

/// The probe class of row class [item] (named [type] in the generated
/// library): it answers each `String` property with a marker and counts the
/// reads, so the server can tell a lambda that only reads one property.
String _probeClass(
  int index,
  String type,
  InterfaceElement item,
  _Imports imports,
) {
  final b = StringBuffer()
    ..writeln('class _RowProbe$index implements $type {')
    ..writeln('  _RowProbe$index(this.log);')
    ..writeln()
    ..writeln('  final RowProbeLog log;');
  for (final (name, nullable) in stringGetters(item)) {
    b
      ..writeln()
      ..writeln('  @override')
      ..writeln("  String${nullable ? '?' : ''} get $name {")
      ..writeln("    log.read('${_esc(name)}');")
      ..writeln("    return RowProbeLog.marker('${_esc(name)}');")
      ..writeln('  }');
  }
  for (final (name, type) in numberGetters(item)) {
    b
      ..writeln()
      ..writeln('  @override')
      ..writeln(
        type == 'double'
            ? "  double get $name => log.decimal('${_esc(name)}');"
            : "  $type get $name => log.integer('${_esc(name)}');",
      );
  }
  for (final (name, e) in stateGetters(item)) {
    final ref = e == null ? null : imports.ref(e);
    b
      ..writeln()
      ..writeln('  @override')
      ..writeln(
        ref == null
            ? "  bool get $name => log.choose('${_esc(name)}', const [false, true]) as bool;"
            : "  $ref get $name => log.choose('${_esc(name)}', $ref.values) as $ref;",
      );
  }
  b
    ..writeln()
    ..writeln('  @override')
    ..writeln('  dynamic noSuchMethod(Invocation invocation) {')
    ..writeln("    log.read('');")
    ..writeln('    return super.noSuchMethod(invocation);')
    ..writeln('  }')
    ..writeln('}');
  return '$b';
}

/// `server.dart`: registers the states and, with [actions], the pages'
/// action methods (`actions.dart`), in every isolate the server starts
/// (`ThorServer.setUpIsolates`), then runs the app's entry ([entry]: a
/// `package:` URI or a path relative to `.dart_tool/thor/`).
String serverEntry(String entry, {bool actions = false}) =>
    '''
// GENERATED BY thor - DO NOT MODIFY OR IMPORT FROM THE APP.
// The server entry `thor` runs: the states' registry, then the app.
// ignore_for_file: type=lint

import 'package:thor_server/thor_server.dart' show ThorServer;

import '$entry' as app;
${actions ? "import 'actions.dart';\n" : ''}import 'states.dart';

Future<void> main(List<String> args) async {
  // In this isolate and in every one ThorServer.serve starts.
  ThorServer.setUpIsolates(registerThorStates);
${actions ? '  ThorServer.setUpIsolates(registerThorActions);\n' : ''}  final Function run = app.main;
  await (run is Function(List<String>) ? run(args) : (run as dynamic)());
}
''';

/// `engine.dart`: the dart2js entry: registers the states and starts the
/// engine with [instances] (`package:` URI and top-level name) and the
/// [features] the app uses (all of them when [allFeatures]). The
/// [rowProperties] are the `String` properties its row lambdas read
/// (`row.text((o) => o.customer)`): the engine gets a reader for each
/// (`RowReaders`), as the lite bundle's `$Rows` has; [rowStates] counts the
/// states of the ones that are a `bool` or an enum (`row.watch`).
String engineEntry(
  List<(String uri, String name)> instances, {
  required Set<String> features,
  bool rowAttributes = false,
  bool animatedRows = false,
  bool virtualLists = false,
  bool allFeatures = false,
  Iterable<String> rowProperties = const [],
  Map<String, int> rowStates = const {},
}) {
  final uris = {for (final s in instances) s.$1}.toList()..sort();
  final prefix = {for (var i = 0; i < uris.length; i++) uris[i]: 's$i'};
  final list = [
    for (final f in engineFeatures.keys)
      if (features.contains(f))
        f == 'ListsFeature' && (rowAttributes || animatedRows || virtualLists)
            ? 'ListsFeature(${[if (rowAttributes) 'rowAttributes: RowAttributes()', if (animatedRows) 'animatedRows: true', if (virtualLists) 'virtualLists: VirtualLists()'].join(', ')})'
            : '$f()',
  ];
  final out = StringBuffer()
    ..writeln('// GENERATED BY thor - DO NOT MODIFY OR IMPORT FROM THE APP.')
    ..writeln("// Browser entry: starts the engine with the app's ThorStates.")
    ..writeln('// ignore_for_file: type=lint')
    ..writeln()
    ..writeln("import 'package:thor_engine_oracle/client.dart';")
    ..writeln()
    ..writeln("import 'states.dart';");
  for (final uri in uris) {
    out.writeln("import '$uri' as ${prefix[uri]};");
  }
  out
    ..writeln()
    ..writeln('void main() {')
    ..writeln('  registerThorStates();')
    ..writeln('  startThor([')
    ..writeAll([for (final s in instances) '    ${prefix[s.$1]}.${s.$2},\n']);
  final properties = rowProperties.toSet().toList()..sort();
  if (properties.isNotEmpty) {
    out.writeln('    RowReaders({');
    for (final p in properties) {
      // `$` is legal in a Dart identifier and means interpolation in the
      // quoted key.
      out.writeln(
        "      '${p.replaceAll(r'$', r'\$')}': (it) => (it as dynamic).$p,",
      );
    }
    final states = rowStates.keys.toList()..sort();
    out.writeln(
      states.isEmpty
          ? '    }),'
          : '    }, states: {${[for (final p in states) "'${p.replaceAll(r'$', r'\$')}': ${rowStates[p]}"].join(', ')}}),',
    );
  }
  out
    ..writeln(
      '  ]${allFeatures ? '' : ', features: const [${list.join(', ')}]'});',
    )
    ..writeln('}');
  return '$out';
}

/// The engine features [sources] use, and whether a list has per-row
/// attributes.
(Set<String>, bool) featuresOf(Iterable<String> sources) {
  final used = <String>{};
  var rowAttributes = false;
  for (final source in sources) {
    for (final f in engineFeatures.entries) {
      if (f.value(source)) used.add(f.key);
    }
    // `row.attribute(…)`, `row.length(…)` and `row.bind(…)`: the list's
    // per-row attributes part (a `.bind(` that is not a row's only adds that
    // small part).
    if (source.contains('.attribute(') ||
        source.contains('.length(') ||
        source.contains('.bind(')) {
      rowAttributes = true;
    }
  }
  return (used, rowAttributes);
}

/// Whether [sources] have an `AnimatedList`: its lists keep a removed row
/// until its exit transition ends (`ListsFeature(animatedRows: true)`).
bool animatedRowsIn(Iterable<String> sources) =>
    sources.any((s) => RegExp(r'\bAnimatedList\s*[<(]').hasMatch(s));

/// Whether a list in [sources] windows its rows (`Watch.list(virtual: true)`):
/// the engine then gets the windowing part.
bool usesVirtualLists(Iterable<String> sources) {
  final virtual = RegExp(r'\bvirtual\s*:\s*true\b');
  return sources.any(virtual.hasMatch);
}

/// The imports of a generated library: each library once, with a prefix.
class _Imports {
  final _prefixes = <String, String>{};

  /// How the generated library names [element].
  String ref(Element element) {
    final library = element.library;
    if (library == null || library.isDartCore) return element.name ?? '';
    final uri = library.uri.toString();
    final prefix = _prefixes.putIfAbsent(uri, () => 't${_prefixes.length}');
    return '$prefix.${element.name}';
  }

  void writeTo(StringBuffer out) {
    for (final MapEntry(key: uri, value: prefix) in _prefixes.entries) {
      out.writeln("import '$uri' as $prefix;");
    }
  }
}

String _registerModel(String ref) =>
    '  registerJsonModel<$ref>($ref.fromJson, (m) => m.toJson());';

/// The classes of the app with `toJson()`/`fromJson` that a `state(...)`
/// field of value type [t] holds: the class itself, or the element of a
/// `List` or the value of a String-keyed `Map` (nullable or not).
Set<InterfaceElement> _stateModels(DartType t) {
  final model = jsonStateModel(t);
  return model != null && !model.element.name!.startsWith('_')
      ? {model.element}
      : const {};
}

/// A Flutter listenable that is not a `StateSignal` (which is one too).
bool _isLooseNotifier(InterfaceType t) =>
    t.element.name != 'StateSignal' &&
    [t, ...t.allSupertypes].any(
      (s) =>
          (s.element.name == 'ChangeNotifier' ||
              s.element.name == 'Listenable') &&
          '${s.element.library.uri}'.startsWith('package:thor_'),
    );

List<String>? _members(
  ClassElement c,
  String path,
  _Imports imports,
  void Function(String) warn,
  List<EntryProblem> problems,
  List<String> calls,
  Set<InterfaceElement> models,
) {
  final name = c.name!;
  final members = <String>[];
  for (final f in stateFields(c)) {
    if (f.isStatic || !f.isOriginDeclaration || f.name == null) continue;
    if (f.name!.startsWith('_')) continue;
    final t = f.type;
    if (t is InterfaceType && _isServerEventStream(t)) {
      final data = t.typeArguments.single;
      final problem = _resultProblem(data);
      if (problem != null) {
        problems.add(
          EntryProblem(
            path,
            thorError('THOR-B021', 'the stream $name.${f.name} $problem'),
          ),
        );
        return null;
      }
      // The query's members and `connection`; how the JSON of an event
      // becomes the value (a class, a list of them) when it isn't plain.
      // The marker keeps `thor build` from listing it as a query endpoint.
      members.add(
        "...s.${f.name}.members('${_esc(f.name)}'${_eventsCodec(data, imports)})"
        ' /* events */',
      );
    } else if (t is InterfaceType && _isServerQuery(t)) {
      final problem = _queryProblem(t);
      if (problem != null) {
        problems.add(
          EntryProblem(
            path,
            thorError('THOR-B021', 'the query $name.${f.name} $problem'),
          ),
        );
        return null;
      }
      // The query and its signals (`info$data`…) and `info$refresh`: the
      // only way a function becomes something the browser can call. An
      // argument that is a class or a record says how it becomes JSON.
      final codec = _argCodec(t.typeArguments.first, imports);
      members.add("...s.${f.name}.members('${_esc(f.name)}'$codec)");
      calls.add(f.name!);
    } else if (t is InterfaceType && isServerCommandType(t)) {
      final problem = _commandProblem(t);
      if (problem != null) {
        problems.add(
          EntryProblem(
            path,
            thorError('THOR-B021', 'the command $name.${f.name} $problem'),
          ),
        );
        return null;
      }
      // The command and its signals (`add$pending`…) and `add$run`. The
      // marker tells `thor build` it from a query when it lists endpoints.
      final codec = _argCodec(commandTypes(t).$1, imports);
      members.add(
        "...s.${f.name}.members('${_esc(f.name)}'$codec) /* command */",
      );
      calls.add(f.name!);
    } else if (t is InterfaceType && t.element.name == 'StateSignal') {
      // A bool or enum field is a finite state for `Watch(…, builder:)` and
      // `ValueListenableBuilder`: its values, in order.
      // A nullable one has a value (null) with no copy to show: not finite.
      final single = t.typeArguments.single;
      // A class of the app (or a list or map of them) in the field travels
      // as JSON with its `toJson()`/`fromJson`: the engine learns them.
      models.addAll(_stateModels(single));
      final variants = single.nullabilitySuffix == NullabilitySuffix.question
          ? null
          : _variants(single, imports);
      final extra = variants == null || variants == _private
          ? ''
          : ', variants: $variants';
      members.add("ThorMember.state('${_esc(f.name)}', s.${f.name}$extra)");
    } else if (t is InterfaceType && _isDerived(t)) {
      // A `derived(...)` field is read like a method that returns a value
      // (`Watch(visible.call)`): the tear-off of its `call`, no state of its
      // own to send to the page.
      final single = t.typeArguments.single;
      final variants = single.nullabilitySuffix == NullabilitySuffix.question
          ? null
          : _variants(single, imports);
      final extra = variants == null || variants == _private
          ? ''
          : ', variants: $variants';
      members.add(
        "ThorMember('${_esc(f.name)}', s.${f.name}.call, "
        'call: (_) => s.${f.name}.value$extra)',
      );
    } else if (t is InterfaceType && _isController(t)) {
      // Found by id in the page: the engine connects the elements that
      // use it (transitions, a scroller, a field, a focus target).
      members.add("ThorMember.controller('${_esc(f.name)}', s.${f.name})");
    } else if (t is InterfaceType && _isLooseNotifier(t)) {
      // The lite build refuses it; the dart2js one would take it silently.
      warn(
        thorError(
          'THOR-B033',
          '$path: $name.${f.name} is a ${t.getDisplayString()}: a plain '
              'ValueNotifier or ChangeNotifier does not react in the browser '
              '(nothing listens to it there). Make it a `state(...)` field: '
              'a StateSignal is a ValueNotifier.',
        ),
      );
    }
  }
  for (final m in stateMethods(c)) {
    final n = m.name;
    if (n == null || m.isStatic || n.startsWith('_') || m.isOperator) {
      continue;
    }
    // The state's life, not something the page calls.
    if (_lifecycle.contains(n)) continue;
    final params = m.formalParameters;
    if (params.length > 3 || params.any((p) => !p.isRequiredPositional)) {
      warn(
        thorError(
          'THOR-B002',
          '$path: $name.$n is skipped: a ThorState method can take at most '
              'three required positional parameters.',
        ),
      );
      continue;
    }
    final variants = _variants(m.returnType, imports);
    if (variants == _private) {
      problems.add(
        EntryProblem(
          path,
          thorError(
            'THOR-B018',
            '$name.$n returns a private enum: the generated registry lists '
                'its values from outside the file. Make the enum public.',
          ),
        ),
      );
      return null;
    }
    final extra = variants == null ? '' : ', variants: $variants';
    final node = params.length == 2 ? focusNodeType(params[0].type) : null;
    final keyEvent = params.length == 2 ? keyEventType(params[1].type) : null;
    if (node != null && keyEvent != null) {
      // `Focus(onKeyEvent:)`'s `KeyEventResult onKey(FocusNode node,
      // KeyEvent event)`: the page sends the event; `node` is not the
      // page's (a fresh one, see `Focus.onKeyEvent`).
      final event = imports.ref(keyEvent);
      members.add(
        "ThorMember('${_esc(n)}', s.$n, call: (a) => "
        's.$n(${imports.ref(node)}(), $event.decode(a!))$extra)',
      );
      continue;
    }
    if (params.length == 2) {
      // `String cellLabel(int column, Row row)`: a simple first parameter
      // fixed with `withArg`, a list item second (row texts, attributes
      // and states per column).
      final first = _parse(params[0].type, 'a', imports);
      if (first != null &&
          first != _private &&
          _parse(params[1].type, 'a', imports) == null) {
        members.add(
          "ThorMember('${_esc(n)}', s.$n, arity: 2, callWithArgAndItem: "
          '(String? a, i) => s.$n($first, i as dynamic)$extra)',
        );
        continue;
      }
    }
    if (params.length >= 2) {
      final parsed = [
        for (var i = 0; i < params.length; i++)
          _parse(params[i].type, 'x[$i]', imports),
      ];
      if (parsed.contains(null) || parsed.contains(_private)) {
        warn(
          thorError(
            'THOR-B002',
            '$path: $name.$n is skipped: every parameter of a '
                'multi-parameter method must be a simple public value (int, '
                'double, String, bool, enum, DateTime, TimeOfDay).',
          ),
        );
        continue;
      }
      members.add(
        "ThorMember('${_esc(n)}', s.$n, arity: ${params.length}, call: (a) { "
        'final x = splitArgs(a, ${params.length}); '
        'return s.$n(${parsed.join(', ')}); })',
      );
      continue;
    }
    if (params.isEmpty) {
      members.add("ThorMember('${_esc(n)}', s.$n, call: (_) => s.$n()$extra)");
      continue;
    }
    if (intentType(params.single.type) case final intent?) {
      // A `CallbackAction`'s `void save(SaveIntent intent)`: the intent made
      // again (the page only knows its class).
      if (!intentRebuildable(intent)) {
        warn(
          thorError(
            'THOR-B002',
            '$path: $name.$n is skipped: its intent ${intent.name} needs a '
                'public constructor without arguments (the page makes it '
                'again: an intent carries no fields to the browser).',
          ),
        );
        continue;
      }
      members.add(
        "ThorMember('${_esc(n)}', s.$n, arity: 1, call: (_) => "
        's.$n(${imports.ref(intent)}())$extra)',
      );
      continue;
    }
    final parse = _parse(params.single.type, 'a', imports);
    if (parse == _private) {
      warn(
        thorError(
          'THOR-B002',
          '$path: $name.$n is skipped: its parameter is a private enum.',
        ),
      );
      continue;
    }
    if (parse != null) {
      // A simple parameter: an action with an argument, and also a row
      // field or key when the list holds simple values (`List<String>`).
      members.add(
        "ThorMember('${_esc(n)}', s.$n, arity: 1, call: (a) => s.$n($parse), "
        'callWithItem: (i) => s.$n(i as dynamic)$extra)',
      );
    } else {
      // A list item (row fields and keys): the item's type is checked when
      // the method runs, so a private item class works too.
      members.add(
        "ThorMember('${_esc(n)}', s.$n, arity: 1, callWithItem: (i) => "
        's.$n(i as dynamic)$extra)',
      );
    }
  }
  return members;
}

/// The type of a `derived(...)` field.
bool _isDerived(InterfaceType t) =>
    t.element.name == 'ReadSignal' &&
    '${t.element.library.uri}'.startsWith('package:thor_engine/');

bool _isServerEventStream(InterfaceType t) =>
    t.element.name == 'ServerEventStream' &&
    '${t.element.library.uri}'.startsWith('package:thor_engine/');

/// The `decode:`, `item:` and `list:` an events field's `members` call gets
/// when its value [t] is a class of the app or a list of them or of
/// maps/simple values: how an event's JSON becomes the field's type (nothing
/// for what `StateSignal` already decodes).
String _eventsCodec(DartType t, _Imports imports) {
  String? item(DartType x) {
    if (x is InterfaceType && _dataClass(x)) {
      return '(j) => ${imports.ref(x.element)}.fromJson('
          'Map<String, Object?>.from(j! as Map))';
    }
    if (x is InterfaceType &&
        x.isDartCoreMap &&
        x.typeArguments.first.isDartCoreString &&
        (_simpleJson(x.typeArguments.last) ||
            x.typeArguments.last.isDartCoreObject)) {
      return '(j) => ${x.getDisplayString()}.from(j! as Map)';
    }
    if (_simpleJson(x)) return '(j) => ${_jsonRead('j', x)}';
    return null;
  }

  String name(DartType x) => x is InterfaceType && _dataClass(x)
      ? imports.ref(x.element)
      : x.getDisplayString();

  if (t is InterfaceType && t.isDartCoreList) {
    final element = t.typeArguments.single;
    final read = item(element);
    if (read == null) return '';
    return ', item: $read, list: (xs) => <${name(element)}>'
        '[for (final e in xs) e as ${name(element)}]';
  }
  if (t is InterfaceType && _dataClass(t)) {
    return ', decode: ${item(t)}';
  }
  return '';
}

bool _isServerQuery(InterfaceType t) =>
    t.element.name == 'ServerQuery' &&
    '${t.element.library.uri}'.startsWith('package:thor_engine/');

/// The queries of [classes] as the page ids the browser calls
/// (`ProfileState.info`): what `thor build` lists as endpoints.
List<String> queryEndpoints(Iterable<ClassElement> classes) => [
  for (final c in classes)
    for (final f in stateFields(c))
      if (!f.isStatic &&
          f.type is InterfaceType &&
          _isServerQuery(f.type as InterfaceType))
        '${c.name}.${f.name}',
];

/// The commands of [classes] as the page ids the browser calls
/// (`CartState.add`): what `thor build` lists as endpoints.
List<String> commandEndpoints(Iterable<ClassElement> classes) => [
  for (final c in classes)
    for (final f in stateFields(c))
      if (!f.isStatic && isServerCommandType(f.type)) '${c.name}.${f.name}',
];

/// Why a command's types can't travel as JSON, or null when they can: the
/// argument like a query's (a simple value, a record or a class), the result like a query's or nothing (`void`,
/// `Null`).
String? _commandProblem(InterfaceType t) {
  final (arg, result) = commandTypes(t);
  if (!arg.isDartCoreNull && !_simpleJson(arg) && !_argShape(arg)) {
    return 'takes an argument of type ${arg.getDisplayString()}: an '
        'argument is an int, double, num, String or bool (or nullable), a '
        'record of them, or a class of the app with toJson() and '
        'factory fromJson(Map<String, Object?>).';
  }
  if (result is VoidType || result.isDartCoreNull) return null;
  return _resultProblem(result);
}

/// Why a query's types can't travel as JSON, or null when they can: the
/// argument ([t]'s first type) is a simple value; the result (its second) a
/// simple value, a `List` or `Map<String, …>` of them, or a class of the
/// app with `toJson()` and `factory fromJson(Map<String, Object?>)` (or a
/// list of those).
String? _queryProblem(InterfaceType t) {
  final [arg, data] = t.typeArguments;
  if (!arg.isDartCoreNull && !_simpleJson(arg) && !_argShape(arg)) {
    return 'takes an argument of type ${arg.getDisplayString()}: an '
        'argument is an int, double, num, String or bool (or nullable), a '
        'record of them, or a class of the app with toJson() and '
        'factory fromJson(Map<String, Object?>).';
  }
  return _resultProblem(data);
}

/// Whether [t] is a query argument that is not a simple value but travels as
/// JSON: a record of simple values, or a class of the app with `toJson()`
/// and a `fromJson` factory. Neither is nullable: `null` has no shape.
bool _argShape(DartType t) {
  if (t.nullabilitySuffix == NullabilitySuffix.question) return false;
  if (t is RecordType) {
    return [
      ...t.positionalFields,
      ...t.namedFields,
    ].every((f) => _simpleJson(f.type));
  }
  return t is InterfaceType && _dataClass(t);
}

/// The `argToJson:`/`argFromJson:` a query's `members` call gets when its
/// argument [t] is a class or a record (nothing for a simple value).
String _argCodec(DartType t, _Imports imports) {
  if (t is RecordType && _argShape(t)) {
    // Positional fields are `$1`, `$2`… (the lite engine's JS records name
    // them the same), named ones by their name.
    final keys = [
      for (var i = 1; i <= t.positionalFields.length; i++)
        (
          r'$'
              '$i',
          r'$'
              '$i',
        ),
      for (final f in t.namedFields) (f.name, f.name),
    ];
    final types = [
      for (final f in t.positionalFields) f.type,
      for (final f in t.namedFields) f.type,
    ];
    final toJson = [for (final (k, a) in keys) "'${_esc(k)}': a.$a"].join(', ');
    final positional = <String>[];
    final named = <String>[];
    for (var i = 0; i < keys.length; i++) {
      final (key, _) = keys[i];
      final read = _jsonRead("j['${_esc(key)}']", types[i]);
      if (i < t.positionalFields.length) {
        positional.add(read);
      } else {
        named.add('$key: $read');
      }
    }
    return ', argToJson: (a) => {$toJson}, '
        'argFromJson: (j) => (${[...positional, ...named].join(', ')})';
  }
  if (t is InterfaceType && _argShape(t)) {
    return ', argToJson: (a) => a.toJson(), '
        'argFromJson: ${imports.ref(t.element)}.fromJson';
  }
  return '';
}

/// `$` in a Dart string literal.
// `PanelState` declared in `lib/shop/cart_page.dart` → `CartPagePanelState`:
// the suggestion THOR-B036 gives.
String _prefixed(String name, String path) {
  final file = path.split('/').last.replaceAll(RegExp(r'\.dart$'), '');
  final words = file
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1));
  return '${words.join()}$name';
}

String _esc(Object? s) => '$s'.replaceAll(r'$', r'\$');

/// Dart reading the JSON value [expr] as a [t] (a simple value): a `double`
/// arrives as an `int` when it has no fraction.
String _jsonRead(String expr, DartType t) {
  final nullable = t.nullabilitySuffix == NullabilitySuffix.question;
  final type = t.getDisplayString();
  if (t.isDartCoreDouble) {
    return nullable
        ? '($expr as num?)?.toDouble()'
        : '($expr! as num).toDouble()';
  }
  return nullable ? '$expr as $type' : '$expr! as $type';
}

/// Why a query's or a command's result [data] can't travel as JSON, or
/// null.
String? _resultProblem(DartType data) {
  if (_json(data)) return null;
  var item = data;
  if (data is InterfaceType && data.isDartCoreList) {
    item = data.typeArguments.single;
  }
  if (item is InterfaceType && _dataClass(item)) return null;
  return 'returns ${data.getDisplayString()}, which does not travel as JSON: '
      'return a simple value, a List or Map<String, …> of them, or a class '
      'of the app with toJson() and factory fromJson(Map<String, Object?>) '
      '(or a List of them).';
}

bool _simpleJson(DartType t) =>
    t.isDartCoreInt ||
    t.isDartCoreDouble ||
    t.isDartCoreNum ||
    t.isDartCoreString ||
    t.isDartCoreBool;

bool _json(DartType t) {
  if (_simpleJson(t)) return true;
  if (t is! InterfaceType) return false;
  if (t.isDartCoreList) return _json(t.typeArguments.single);
  if (t.isDartCoreMap) {
    return t.typeArguments.first.isDartCoreString &&
        _json(t.typeArguments.last);
  }
  return false;
}

/// Whether [t] is a data class (see [isJsonDataClass]): `toJson()` and a
/// `fromJson` factory taking the decoded map.
bool _dataClass(InterfaceType t) => isJsonDataClass(t.element);

/// Marks a value of a private type (the registry can't name it).
const _private = '\u0000private';

const _controllers = {
  'ThorController',
  'AnimationController',
  'ScrollController',
  'TextEditingController',
  'FocusNode',
  'DialogController',
};

/// `ThorState`'s own life: never a member the page can name.
const _lifecycle = {'onHydrated', 'dispose'};

/// Whether [t] is a `ThorController`.
bool _isController(InterfaceType t) =>
    _controllers.contains(t.element.name) ||
    t.allSupertypes.any((s) => s.element.name == 'ThorController');

/// The finite values of a variant source, in order.
String? _variants(DartType t, _Imports imports) {
  if (t.isDartCoreBool) return 'const [false, true]';
  final e = t.element;
  if (e is EnumElement) {
    if (e.name?.startsWith('_') ?? true) return _private;
    return '${imports.ref(e)}.values';
  }
  return null;
}

bool _isDartCore(DartType t, String name) =>
    t.element?.name == name && (t.element?.library?.isDartCore ?? false);

/// Dart that parses the page's text argument [a] to [t], null if [t] is
/// not a simple value (then it is a list item), [_private] for a private
/// enum.
String? _parse(DartType t, String a, _Imports imports) {
  final nullable = t.nullabilitySuffix == NullabilitySuffix.question;
  String? core;
  if (t.isDartCoreInt) {
    core = 'int.parse($a!)';
  } else if (t.isDartCoreDouble) {
    core = 'double.parse($a!)';
  } else if (t.isDartCoreNum) {
    core = 'num.parse($a!)';
  } else if (t.isDartCoreString) {
    core = '$a!';
  } else if (t.isDartCoreBool) {
    core = "$a == 'true'";
  } else if (_isDartCore(t, 'DateTime')) {
    // `yyyy-mm-dd` from a date picker (or a full ISO 8601 date-time).
    core = 'DateTime.parse($a!)';
  } else if (gestureDetails(t) case final e?) {
    // `x~y` from a GestureDetector (`TapDownDetails.localPosition`).
    core = '${imports.ref(e)}.fromArg($a)';
  } else if (t.element case final e? when e.name == 'TimeOfDay') {
    // `hh:mm` from a time picker.
    core =
        '${imports.ref(e)}(hour: int.parse($a!.substring(0, 2)), '
        'minute: int.parse($a.substring(3, 5)))';
  } else if (t.element case final EnumElement e) {
    if (e.name?.startsWith('_') ?? true) return _private;
    core = '${imports.ref(e)}.values.byName($a!)';
  } else if (t is InterfaceType &&
      t.isDartCoreSet &&
      !nullable &&
      t.typeArguments.length == 1 &&
      t.typeArguments.single.nullabilitySuffix != NullabilitySuffix.question) {
    // A `Set<E>` of a simple value (a segmented button's selection): the
    // browser sends one value, so the set holds it, or nothing when the text
    // is empty.
    final inner = _parse(t.typeArguments.single, a, imports);
    if (inner == null || inner == _private) return inner;
    final element = t.typeArguments.single;
    final name = element.element is EnumElement
        ? imports.ref(element.element!)
        : element.getDisplayString();
    // Checkboxes send all the checked values, U+001F apart.
    final each = _parse(t.typeArguments.single, r'$v', imports);
    return '($a == null || $a.isEmpty ? <$name>{} : '
        '{for (final String? \$v in $a.split(\'\\u001f\')) $each})';
  }
  if (core == null) return null;
  if (!nullable) return core;
  // `x[i]` (a part of a multi-argument value) is a String, never null.
  return a.startsWith('x[')
      ? '($a.isEmpty ? null : $core)'
      : '($a == null || $a.isEmpty ? null : $core)';
}

/// Whether [source] may hold a page with action methods (worth resolving):
/// it names `ActionResult` or declares a subclass. Any subclass, not only
/// `extends …Page`: a page can extend the app's own base (`class Clients
/// extends Screen`) and inherit its actions without naming either.
bool mayDeclareActions(String source) =>
    source.contains('ActionResult') ||
    RegExp(r'\bclass\s+\w+[^{;]*\bextends\b').hasMatch(source);

/// Whether [c] is a concrete `ThorPage` of `package:thor_ui` (directly or
/// through the app's own base pages).
bool isPageClass(ClassElement c) =>
    !c.isAbstract &&
    c.allSupertypes.any(
      (t) =>
          t.element.name == 'ThorPage' &&
          '${t.element.library.uri}'.startsWith('package:thor_ui/'),
    );

/// An action method of a page: its name, when it takes the form's values
/// the schema type `S` of its `FormValues<S>` (null otherwise), and the
/// types of the arguments a button binds (`delete(PageRequest request, int
/// id)`: `[int]`; empty otherwise).
typedef ActionMethod = ({
  String name,
  InterfaceType? schema,
  List<DartType> args,
});

/// The action methods of the page class [c]: its public instance
/// methods (its own, its mixins' and those of the app's base pages above
/// it) that return
/// an `ActionResult?` (`Future`/`FutureOr` too) and take `(PageRequest)`,
/// `(PageRequest, FormValues<S>)` or the request and up to three simple
/// arguments (`int`, `double`, `num`, `String`, `bool`, `DateTime`, an enum;
/// `onPost: delete.withArg(id)`).
List<ActionMethod> actionMethodsOf(ClassElement c) {
  final found = <String, ActionMethod>{};
  // The instantiated types, not the declarations: `ClientPage extends
  // CrudPage<ClientForm>` makes `save(PageRequest, FormValues<S>)` take
  // `FormValues<ClientForm>` (the same for a generic mixin).
  for (InterfaceType? t = c.thisType; t != null; t = t.superclass) {
    final e = t.element;
    if (e.name == 'ThorPage' &&
        '${e.library.uri}'.startsWith('package:thor_ui/')) {
      break;
    }
    // Its own methods, then its mixins' (`mixin EditorActions on ThorPage`).
    for (final m in [
      ...t.methods,
      for (final mixin in t.mixins.reversed) ...mixin.methods,
    ]) {
      final n = m.name;
      if (n == null || m.isStatic || n.startsWith('_') || m.isOperator) {
        continue;
      }
      if (found.containsKey(n) || !_returnsActionResult(m.returnType)) {
        continue;
      }
      final params = m.formalParameters;
      if (params.isEmpty ||
          params.length > 4 ||
          params.any((p) => !p.isRequiredPositional) ||
          params.first.type.element?.name != 'PageRequest') {
        continue;
      }
      if (params.length == 1) {
        found[n] = (name: n, schema: null, args: const []);
        continue;
      }
      final values = params[1].type;
      if (params.length == 2 &&
          values is InterfaceType &&
          values.element.name == 'FormValues') {
        final s = values.typeArguments.single;
        found[n] = (
          name: n,
          schema: s is InterfaceType ? s : null,
          args: const [],
        );
        continue;
      }
      // The request and the arguments a button binds.
      final args = [for (final p in params.skip(1)) p.type];
      if (args.every(_postable)) found[n] = (name: n, schema: null, args: args);
    }
  }
  return found.values.toList();
}

/// Whether a button can post a value of type [t] (what `_parse` reads back).
bool _postable(DartType t) =>
    t.isDartCoreInt ||
    t.isDartCoreDouble ||
    t.isDartCoreNum ||
    t.isDartCoreString ||
    t.isDartCoreBool ||
    _isDartCore(t, 'DateTime') ||
    t.element is EnumElement;

bool _returnsActionResult(DartType t) {
  var inner = t;
  if (inner is InterfaceType &&
      (inner.isDartAsyncFuture || inner.isDartAsyncFutureOr)) {
    inner = inner.typeArguments.single;
  }
  return inner is InterfaceType &&
      (inner.element.name == 'ActionResult' ||
          inner.allSupertypes.any((s) => s.element.name == 'ActionResult'));
}

/// `actions.dart`: the registry of the action methods of [pages] (each with
/// the app-relative path of its file, for messages), or null when no page
/// has one. Pages the registry can't name go to [problems].
String? actionsLibrary(
  List<(ClassElement, String)> pages, {
  required List<EntryProblem> problems,
}) {
  final imports = _Imports();
  final entries = <String>[];
  for (final (c, path) in pages) {
    final methods = actionMethodsOf(c);
    if (methods.isEmpty) continue;
    final name = c.name ?? '';
    if (name.startsWith('_') || c.typeParameters.isNotEmpty) {
      problems.add(
        EntryProblem(
          path,
          thorError(
            'THOR-B023',
            'the page class $name has action methods '
                '(${methods.map((m) => m.name).join(', ')}) and must be '
                'public and without type parameters: the generated registry '
                'names it from outside its file.',
          ),
        ),
      );
      continue;
    }
    final type = imports.ref(c);
    final lines = <String>[];
    for (final m in methods) {
      final tearOff = '(p) => (p as $type).${m.name}';
      final s = m.schema;
      if (m.args.isNotEmpty) {
        final parsed = [
          for (var i = 0; i < m.args.length; i++)
            _parse(m.args[i], 'x[$i]', imports),
        ];
        if (parsed.contains(_private)) {
          problems.add(
            EntryProblem(
              path,
              thorError(
                'THOR-B023',
                '$name.${m.name} takes an argument of a private enum: the '
                    'generated registry names it from outside its file. Make '
                    'the enum public.',
              ),
            ),
          );
          continue;
        }
        lines.add(
          "PageActionMethod.args('${m.name}', $tearOff, ${m.args.length}, "
          '(x) => [${parsed.join(', ')}])',
        );
        continue;
      }
      if (s == null) {
        lines.add("PageActionMethod.request('${m.name}', $tearOff)");
        continue;
      }
      final schema = _schemaOf(s, imports);
      if (schema == null) {
        problems.add(
          EntryProblem(
            path,
            thorError(
              'THOR-B024',
              '$name.${m.name} takes FormValues<${s.getDisplayString()}>: '
                  'thor checks the form with that schema before running the '
                  'method, so the type must be a public class that extends '
                  'FormSchema and has a `static const schema` of its own type '
                  '(or a const constructor without arguments).',
            ),
          ),
        );
        continue;
      }
      lines.add("PageActionMethod.valid('${m.name}', $tearOff, $schema)");
    }
    entries.add(
      '    $type: [\n${lines.map((l) => '      $l,').join('\n')}\n    ],',
    );
  }
  if (entries.isEmpty) return null;
  final out = StringBuffer()
    ..writeln('// GENERATED BY thor - DO NOT MODIFY OR IMPORT FROM THE APP.')
    ..writeln(
      "// The action methods of the app's pages (see registerPageActions).",
    )
    ..writeln('// ignore_for_file: type=lint')
    ..writeln()
    ..writeln(
      "import 'package:thor_ui/router.dart' "
      'show PageActionMethod, registerPageActions;',
    );
  imports.writeTo(out);
  out
    ..writeln()
    ..writeln("/// Registers the action methods of the app's pages.")
    ..writeln('void registerThorActions() {')
    ..writeln('  registerPageActions({')
    ..writeAll(entries.map((e) => '$e\n'))
    ..writeln('  });')
    ..writeln('}');
  return '$out';
}

/// How the registry gets the schema instance of type [s]: its
/// `static const schema` of type [s], else `const S()`; null when neither
/// exists (or [s] is `FormSchema` itself, or private).
String? _schemaOf(InterfaceType s, _Imports imports) {
  final e = s.element;
  final name = e.name;
  if (e is! ClassElement || name == null || name.startsWith('_')) return null;
  if (name == 'FormSchema' || s.typeArguments.isNotEmpty) return null;
  if (!s.allSupertypes.any((t) => t.element.name == 'FormSchema')) {
    return null;
  }
  final field = e.getField('schema');
  if (field != null && field.isStatic && field.type == s) {
    return '${imports.ref(e)}.schema';
  }
  final constructor = e.unnamedConstructor;
  if (constructor != null &&
      constructor.isConst &&
      constructor.formalParameters.every((p) => !p.isRequired)) {
    return 'const ${imports.ref(e)}()';
  }
  return null;
}
