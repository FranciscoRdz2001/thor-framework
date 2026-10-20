import 'run.dart';
import 'templates.dart';

/// A message `thor add` gives besides the files: where to put what it
/// wrote ([warning] false), or what it left as it was ([warning] true).
class AddNote {
  /// A note.
  const AddNote(this.message, {this.warning = false});

  /// The text.
  final String message;

  /// Whether something was left undone.
  final bool warning;

  @override
  String toString() => message;
}

/// What `thor add page` or `thor add layout` would do, as data: nothing is
/// written. A tool that edits the project in memory (an editor with its own
/// undo and reload) applies it; `thor add` writes it.
class AddPlan {
  /// An empty plan.
  AddPlan();

  /// Files that do not exist yet, project-relative path (`/` separators) →
  /// content.
  final Map<String, String> created = {};

  /// Files that exist, project-relative path → the whole new source.
  final Map<String, String> changed = {};

  /// What to tell the developer.
  final List<AddNote> notes = [];
}

/// The plan of `thor add page <url>`: the page file and its route.
///
/// [read] gives the source of a project-relative path (`lib/router.dart`)
/// or null when there is no such file; [modular] says the project is an app
/// in modules (it has `lib/modules/`), where [module] (default: the first
/// segment of [url]) owns the page. [className] names the page class
/// (default: [pageClassName] of [url]).
///
/// Throws a [ThorException] for a [url], [module] or [className] that is not
/// valid, for a module that cannot be taken from the URL, and when the page
/// file already exists.
AddPlan planAddPage(
  String url, {
  required String? Function(String path) read,
  bool modular = false,
  String? module,
  String? className,
}) {
  if (!routePathPattern.hasMatch(url)) {
    throw ThorException(
      '"$url" is not a route path (`/about`, `/product/:id`, '
      '`/item/:id:int`, `/docs/*rest`).',
    );
  }
  if (className != null && !RegExp(r'^[A-Z]\w*$').hasMatch(className)) {
    throw ThorException(
      '"$className" is not a class name (UpperCamelCase: `AboutUsPage`).',
    );
  }
  _checkModule(module, modular);
  final plan = AddPlan();
  final files = PlanFiles(read, plan);
  final cls = className ?? pageClassName(url);
  if (!modular) {
    final file = 'lib/pages/${snakeCase(cls)}.dart';
    files.create(file, pageFile(url, className: cls));
    _addRoute(files, plan, url, cls, file);
    return plan;
  }
  final owner = module ?? _moduleOf(url);
  final file = 'lib/modules/$owner/pages/${snakeCase(cls)}.dart';
  files.create(file, pageFile(url, className: cls));
  _addModuleRoute(files, plan, owner, url, cls, file);
  return plan;
}

/// The plan of `thor add layout <name>`: the layout file (`Shop` →
/// `ShopLayout`), and a note on how to use it. See [planAddPage] for
/// [read], [modular] and [module].
AddPlan planAddLayout(
  String name, {
  required String? Function(String path) read,
  bool modular = false,
  String? module,
}) {
  if (!RegExp(r'^[A-Z]\w*$').hasMatch(name)) {
    throw ThorException('Name it in UpperCamelCase: `thor add layout Shop`.');
  }
  _checkModule(module, modular);
  final cls = name.endsWith('Layout') ? name : '${name}Layout';
  final plan = AddPlan();
  PlanFiles(read, plan).create(
    !modular
        ? 'lib/pages/${snakeCase(cls)}.dart'
        : module == null
        ? 'lib/shell/${snakeCase(cls)}.dart'
        : 'lib/modules/$module/${snakeCase(cls)}.dart',
    layoutFile(className: cls),
  );
  plan.notes.add(
    AddNote(
      'use it in ${module == null ? 'lib/router.dart' : 'lib/modules/$module/${module}_routes.dart'}: '
      'Group(layout: const $cls(), children: […])',
    ),
  );
  return plan;
}

/// The URLs `thor add page` takes: `/`, `/about`, `/item/:id:int`,
/// `/docs/*rest`.
final routePathPattern = RegExp(r'^/$|^(/([\w.\-]+|:\w+(:int)?|\*\w+))+$');

void _checkModule(String? module, bool modular) {
  if (module == null) return;
  if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(module)) {
    throw ThorException('Name the module in snake_case: `--module sales`.');
  }
  if (!modular) {
    throw ThorException(
      '--module needs an app in modules (lib/modules/), like the one '
      '`thor create` writes.',
    );
  }
}

/// The files of the project as the plan sees them: what the reader gives,
/// with the plan's own creations and edits on top. (Not exported: `thor
/// add` itself uses it.)
class PlanFiles {
  /// Files read through [_read], planned into [_plan].
  PlanFiles(this._read, this._plan);

  final String? Function(String path) _read;
  final AddPlan _plan;

  /// The source of [path] as the plan leaves it, or null.
  String? read(String path) =>
      _plan.changed[path] ?? _plan.created[path] ?? _read(path);

  /// Plans a new file; one that exists is a [ThorException].
  void create(String path, String content) {
    if (read(path) != null) throw ThorException('$path already exists.');
    _plan.created[path] = content;
  }

  /// Replaces [path]'s source (a file the plan created stays created).
  void write(String path, String source) {
    if (_plan.created.containsKey(path)) {
      _plan.created[path] = source;
    } else {
      _plan.changed[path] = source;
    }
  }
}

/// Adds the page's route to `lib/router.dart`: its import and its
/// `final …Route`; placing it in the table is the app's call.
void _addRoute(
  PlanFiles files,
  AddPlan plan,
  String url,
  String cls,
  String file,
) {
  final variable = routeVariable(cls);
  var source = files.read('lib/router.dart');
  if (source == null) {
    plan.notes.add(
      AddNote(
        "no lib/router.dart: add `final $variable = ThorRoute('$url', "
        'const $cls());` to your route table',
      ),
    );
    return;
  }
  source = addImport(source, "import '${file.substring('lib/'.length)}';");
  final table = RegExp(
    r'^(/// [^\n]*\n)*final ThorRouter ',
    multiLine: true,
  ).firstMatch(source);
  final declaration =
      '/// `$url`: link to it with `$variable.link(…)`.\n'
      "final $variable = ThorRoute('$url', const $cls());\n\n";
  source = table == null
      ? '$source\n$declaration'
      : source.replaceRange(table.start, table.start, declaration);
  files.write('lib/router.dart', source);
  plan.notes.add(
    AddNote(
      'lib/router.dart: $variable added; put it in the table where it belongs',
    ),
  );
}

/// The module of a page at [url]: its first fixed segment, `home` for `/`.
String _moduleOf(String url) {
  if (url == '/') return 'home';
  final first = url.split('/')[1];
  if (first.startsWith(':') || first.startsWith('*')) {
    throw ThorException(
      '"$url" starts with a parameter: say its module, `--module sales`.',
    );
  }
  // A module is a Dart identifier (`<module>Module`): a leading digit
  // (`/2fa`) has none to take, so it asks for --module.
  final module = snakeCase(
    first.replaceAll(RegExp('[^A-Za-z0-9]+'), '_'),
  ).replaceFirst(RegExp(r'^_+'), '');
  if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(module)) {
    throw ThorException(
      '"$url" has no module name to take from "$first": say it, '
      '`--module sales`.',
    );
  }
  return module;
}

/// Adds the page's route to its module's group, creating the module and
/// putting it in `lib/router.dart` when it is new.
void _addModuleRoute(
  PlanFiles files,
  AddPlan plan,
  String module,
  String url,
  String cls,
  String file,
) {
  final routesPath = ensureModuleRoutes(files, plan, module);
  final group = '${lowerCamel(module)}Module';
  final variable = routeVariable(cls);
  var source = files.read(routesPath)!;
  source = addImport(
    source,
    "import '${file.substring('lib/modules/$module/'.length)}';",
  );
  final declaration = RegExp(
    '^(/// [^\n]*\n)*final $group = Group',
    multiLine: true,
  ).firstMatch(source);
  final route =
      '/// `$url`: link to it with `$variable.link(…)`.\n'
      "final $variable = ThorRoute('$url', const $cls());\n\n";
  source = declaration == null
      ? '$source\n$route'
      : source.replaceRange(declaration.start, declaration.start, route);
  // Into the module's group.
  final added = _addChild(source, group, variable);
  files.write(routesPath, added ?? source);
  plan.notes.add(
    AddNote(
      added == null
          ? '$routesPath: $variable added; put it in $group'
          : '$routesPath: $variable added to $group',
    ),
  );
}

/// The routes file of [module] (`lib/modules/<module>/<module>_routes.dart`),
/// created and its group put in `lib/router.dart` when the module is new.
String ensureModuleRoutes(PlanFiles files, AddPlan plan, String module) {
  final routesPath = 'lib/modules/$module/${module}_routes.dart';
  if (files.read(routesPath) == null) {
    files.create(routesPath, moduleRoutesFile(module));
    _registerModule(files, plan, module, '${lowerCamel(module)}Module');
  }
  return routesPath;
}

/// Puts a new module's group in the app's table, next to the others.
void _registerModule(
  PlanFiles files,
  AddPlan plan,
  String module,
  String group,
) {
  final router = files.read('lib/router.dart');
  if (router == null) return;
  var source = addImport(
    router,
    "import 'modules/$module/${module}_routes.dart';",
  );
  // The children list that holds the other modules.
  final list = RegExp(r'children: \[([^\]]*Module[^\]]*)\]').firstMatch(source);
  if (list == null) {
    files.write('lib/router.dart', source);
    plan.notes.add(AddNote('lib/router.dart: put $group in the table'));
    return;
  }
  source = source.replaceRange(
    list.start,
    list.end,
    'children: [${list[1]!.trim().replaceAll(RegExp(r',\s*$'), '')}, $group]',
  );
  files.write('lib/router.dart', source);
  plan.notes.add(AddNote('lib/router.dart: $group added to the table'));
}

/// [source] with [child] appended to the `children: […]` of the group
/// declared as [group], or null when it can't find it.
String? _addChild(String source, String group, String child) {
  final m = RegExp(
    'final $group = Group\\([\\s\\S]*?children: \\[([^\\]]*)\\]',
  ).firstMatch(source);
  if (m == null) return null;
  final items = m[1]!.trim().replaceAll(RegExp(r',\s*$'), '');
  final start = m.start + m[0]!.lastIndexOf('[');
  return source.replaceRange(
    start,
    m.end,
    '[${items.isEmpty ? child : '$items, $child'}]',
  );
}

/// [source] with [import] among its imports (a relative one after the
/// package ones, in its own block).
String addImport(String source, String import) {
  if (source.contains(import)) return source;
  final imports = RegExp(
    r"^import '[^']*'[^;]*;\n",
    multiLine: true,
  ).allMatches(source).toList();
  if (imports.isEmpty) return '$import\n$source';
  // A relative import after the package ones goes in its own block.
  final gap =
      !import.contains("'package:") &&
          imports.last.group(0)!.contains("'package:")
      ? '\n'
      : '';
  return source.replaceRange(
    imports.last.end,
    imports.last.end,
    '$gap$import\n',
  );
}
