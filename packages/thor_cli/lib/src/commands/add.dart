import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../add_plan.dart';
import '../run.dart';
import '../templates.dart';
import '../workspace.dart';
import 'base.dart';

/// `thor add page|layout|error|not_found|middleware|styles|state|component
/// …`: the file in its place (a page also gets its route in
/// `lib/router.dart`; the rest say how to put them in the table).
class AddCommand extends Command<int> {
  /// The command and its kinds.
  AddCommand() {
    addSubcommand(
      _AddRouteFile(
        'page',
        'A page: lib/pages/<name>_page.dart, and its Route in lib/router.dart.',
      ),
    );
    addSubcommand(
      _AddRouteFile('layout', 'A layout: the frame a Group puts around pages.'),
    );
    addSubcommand(
      _AddRouteFile('error', 'The error page (404, 500) of a Group.'),
    );
    addSubcommand(
      _AddRouteFile(
        'not_found',
        'The 404 page of a Group (URLs with no route).',
      ),
    );
    addSubcommand(
      _AddRouteFile('middleware', 'Code around every request to a Group.'),
    );
    addSubcommand(
      _AddRouteFile('styles', "The stylesheet of a Group's pages."),
    );
    addSubcommand(_AddState());
    addSubcommand(_AddComponent());
  }

  @override
  String get name => 'add';

  @override
  String get description =>
      'Add a page, layout, error or 404 page, middleware, stylesheet, state '
      'or component.';
}

class _AddRouteFile extends Command<int> with ProjectCommand {
  _AddRouteFile(this.name, this.description) {
    argParser
      ..addOption(
        'project',
        help: 'The project (default: the one the current folder is in).',
      )
      ..addOption(
        'module',
        help:
            'In an app in modules (lib/modules/): the module it belongs to '
            '(default: core/ or shell/; a page, its URL\'s first segment).',
        valueHelp: 'name',
      );
  }

  /// Whether the project is an app in modules (`thor create` writes one):
  /// files go to `lib/modules/<module>/`, `lib/core/` and `lib/shell/`.
  bool _modular(Project project) =>
      Directory(project.path('lib/modules')).existsSync();

  /// The `--module` asked for, checked.
  String? _module(Project project) {
    final module = argResults!['module'] as String?;
    if (module == null) return null;
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(module)) {
      usageException('Name the module in snake_case: `--module sales`.');
    }
    if (!_modular(project)) {
      throw ThorException(
        '--module needs an app in modules (lib/modules/), like the one '
        '`thor create` writes.',
      );
    }
    return module;
  }

  @override
  final String name;

  @override
  final String description;

  @override
  String get invocation => switch (name) {
    'page' => 'thor add page </url/:param>',
    'layout' => 'thor add layout <Name>',
    'middleware' || 'styles' => 'thor add $name <name>',
    _ => 'thor add $name',
  };

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length > 1) usageException('One at a time.');
    final arg = rest.firstOrNull;
    final project = _project();
    // `homeRoute.link()` when the app has one: in its table, or in the
    // home module of an app in modules (`thor create`).
    final homeLibrary = ['lib/router.dart', 'lib/modules/home/home_routes.dart']
        .where((f) {
          final file = File(project.path(f));
          return file.existsSync() &&
              file.readAsStringSync().contains('final homeRoute =');
        })
        .firstOrNull;
    final home = homeLibrary == null ? null : project.name;
    final homeImport = homeLibrary?.substring('lib/'.length) ?? 'router.dart';
    switch (name) {
      case 'page':
        final url =
            arg ?? usageException('Which URL? (`/about`, `/product/:id`)');
        await _apply(
          project,
          planAddPage(
            url,
            read: (f) => _read(project, f),
            modular: _modular(project),
            module: _module(project),
          ),
        );
      case 'layout':
        if (arg == null || !RegExp(r'^[A-Z]\w*$').hasMatch(arg)) {
          usageException('Name it in UpperCamelCase: `thor add layout Shop`.');
        }
        await _apply(
          project,
          planAddLayout(
            arg,
            read: (f) => _read(project, f),
            modular: _modular(project),
            module: _module(project),
          ),
        );
      case 'error' || 'not_found':
        final module = _module(project);
        final kind = name == 'error' ? 'ErrorPage' : 'NotFoundPage';
        // The app's pages are `AppErrorPage` / `NotFoundPage`; a module's
        // take its name (`SalesErrorPage`).
        final cls = module != null
            ? '${upperCamel(module)}$kind'
            : kind == 'ErrorPage'
            ? 'AppErrorPage'
            : 'NotFoundPage';
        final file = !_modular(project)
            ? 'lib/pages/${snakeCase(kind)}.dart'
            : module == null
            ? 'lib/shell/${snakeCase(cls)}.dart'
            : 'lib/modules/$module/pages/${snakeCase(cls)}.dart';
        await _write(
          project,
          file,
          name == 'error'
              ? errorFile(app: home, homeLibrary: homeImport, className: cls)
              : notFoundFile(
                  app: home,
                  homeLibrary: homeImport,
                  className: cls,
                ),
        );
        final key = name == 'error' ? 'error' : 'notFound';
        if (module == null) {
          Say.info(
            'use it in ${_table(project, module)}: '
            'Group($key: const $cls(), …)',
          );
        } else {
          await _wireIntoModule(project, module, file, key, 'const $cls()');
        }
      default:
        if (arg == null || !RegExp(r'^[a-z]\w*$').hasMatch(arg)) {
          usageException(
            'Name it in lowerCamelCase: `thor add $name session`.',
          );
        }
        final dir = name == 'styles' ? 'styles' : 'middleware';
        final module = _module(project);
        final snake = snakeCase(arg);
        final file = !_modular(project)
            ? 'lib/$dir/$snake.dart'
            : module != null
            ? (name == 'styles'
                  ? 'lib/modules/$module/${snake}_styles.dart'
                  : 'lib/modules/$module/middleware/$snake.dart')
            : (name == 'styles'
                  ? 'lib/core/theme/${snake}_styles.dart'
                  : 'lib/core/middleware/$snake.dart');
        await _write(
          project,
          file,
          name == 'styles' ? stylesFile(arg) : middlewareFile(arg),
        );
        if (module == null) {
          Say.info(
            'use it in ${_table(project, module)}: Group('
            '${name == 'styles' ? 'styles: ${arg}Styles' : 'middleware: [$arg]'}, …)',
          );
        } else if (name == 'styles') {
          await _wireIntoModule(
            project,
            module,
            file,
            'styles',
            '${arg}Styles',
          );
        } else {
          await _wireIntoModule(project, module, file, 'middleware', arg);
        }
    }
    return 0;
  }

  /// Where a Group of [module] is declared, for a hint.
  String _table(Project project, String? module) => module == null
      ? 'lib/router.dart'
      : 'lib/modules/$module/${module}_routes.dart';

  /// Puts what [file] declares in its module's group: its import, and
  /// `key: value` among the group's arguments (`error: const
  /// SalesErrorPage()`), or [value] appended to its `middleware: […]`. An
  /// `error:`, `notFound:` or `styles:` already there stays; it says which
  /// line to change instead.
  Future<void> _wireIntoModule(
    Project project,
    String module,
    String file,
    String key,
    String value,
  ) async {
    final plan = AddPlan();
    final files = PlanFiles((f) => _read(project, f), plan);
    final routesPath = ensureModuleRoutes(files, plan, module);
    final group = '${lowerCamel(module)}Module';
    final source = files.read(routesPath)!;
    final local = file.substring('lib/modules/$module/'.length);
    switch (wireGroupArgument(source, group, key, value)) {
      case GroupArgumentAdded(:final source):
        files.write(routesPath, addImport(source, "import '$local';"));
        plan.notes.add(AddNote('$routesPath: $key added to $group'));
      case GroupArgumentTaken(:final current):
        plan.notes.add(
          AddNote(
            '$routesPath: $group already has `$current`; left as is. To use '
            'the new one, change that line to `$key: $value,` and import '
            "'$local'",
            warning: true,
          ),
        );
      case GroupNotFound():
        plan.notes.add(
          AddNote(
            'use it in $routesPath: '
            'Group(${key == 'middleware' ? '$key: [$value]' : '$key: $value'}, …)',
          ),
        );
    }
    await _apply(project, plan);
  }

  /// The source of [relative] in [project], or null when it is not there.
  String? _read(Project project, String relative) {
    final file = File(project.path(relative));
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  /// Writes [plan]: the files it creates, the ones it changes (the route
  /// files formatted), and its notes.
  Future<void> _apply(Project project, AddPlan plan) async {
    for (final MapEntry(:key, :value) in plan.created.entries) {
      await _write(project, key, value);
    }
    for (final MapEntry(:key, :value) in plan.changed.entries) {
      File(project.path(key)).writeAsStringSync(value);
    }
    for (final path in [...plan.created.keys, ...plan.changed.keys]) {
      if (path.startsWith('lib/modules/') && path.endsWith('_routes.dart')) {
        await _format(project, path);
      }
    }
    for (final note in plan.notes) {
      note.warning ? Say.warn(note.message) : Say.info(note.message);
    }
  }

  Future<void> _format(Project project, String relative) async {
    try {
      await exec('dart', ['format', relative], dir: project.dir, quiet: true);
    } on ThorException {
      // Unformatted is still valid code.
    }
  }

  Project _project() {
    final named = argResults!['project'] as String?;
    final project = Project.find(named);
    if (project == null) {
      throw ThorException(
        'Run it inside a thor project, or pass --project <path>.',
      );
    }
    return project;
  }
}

class _AddState extends _AddRouteFile {
  _AddState() : super('state', 'Browser state: lib/<name>_view_model.dart.');

  @override
  String get invocation => 'thor add state <Name>';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1 || !RegExp(r'^[A-Z]\w*$').hasMatch(rest.single)) {
      usageException('Name it in UpperCamelCase: `thor add state Cart`.');
    }
    // `Cart` is `CartViewModel` (Flutter's name); an explicit `CartState`
    // or `CartViewModel` is kept.
    final type = stateClassName(rest.single);
    final project = _project();
    final module = _module(project);
    await _write(
      project,
      !_modular(project)
          ? p.join('lib', '${snakeCase(type)}.dart')
          : module == null
          ? p.join('lib', 'core', 'state', '${snakeCase(type)}.dart')
          : p.join(
              'lib',
              'modules',
              module,
              'state',
              '${snakeCase(type)}.dart',
            ),
      stateFile(type),
    );
    Say.info(
      'thor lists its members in .dart_tool/thor/ (thor dev does it on save)',
    );
    return 0;
  }
}

class _AddComponent extends _AddRouteFile {
  _AddComponent()
    : super('component', 'A widget with its stylesheet class, and its test.');

  @override
  String get invocation => 'thor add component <Name>';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1 || !RegExp(r'^[A-Z]\w*$').hasMatch(rest.single)) {
      usageException('Name it in UpperCamelCase: `thor add component Card`.');
    }
    final name = rest.single;
    final project = _project();
    final snake = snakeCase(name);
    final module = _module(project);
    // Its folder under lib/ (and test/): widgets/ in a flat app, core/widgets/
    // or modules/<module>/widgets/ in an app in modules.
    final folder = !_modular(project)
        ? 'widgets'
        : module == null
        ? 'core/widgets'
        : 'modules/$module/widgets';
    await _write(project, 'lib/$folder/$snake.dart', componentFile(name));
    await _write(
      project,
      'test/$folder/${snake}_test.dart',
      componentTestFile(project.name, name, library: '$folder/$snake.dart'),
    );
    Say.info('list $name.styles in the app stylesheet (WidgetRenderer)');
    return 0;
  }
}

Future<void> _write(Project project, String relative, String content) async {
  final file = File(project.path(relative));
  if (file.existsSync()) {
    throw ThorException('${p.relative(file.path)} already exists.');
  }
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
  Say.ok(p.relative(file.path));
}

/// What [wireGroupArgument] did.
sealed class GroupArgumentResult {
  const GroupArgumentResult();
}

/// The argument is in: the new [source].
final class GroupArgumentAdded extends GroupArgumentResult {
  /// The new source.
  const GroupArgumentAdded(this.source);

  /// The file with the argument.
  final String source;
}

/// The group already has that argument ([current], as written); the source
/// is left as is.
final class GroupArgumentTaken extends GroupArgumentResult {
  /// The argument already there.
  const GroupArgumentTaken(this.current);

  /// `error: const OtherErrorPage()`.
  final String current;
}

/// No `final <group> = Group(…)` in the source (or a middleware list that
/// isn't a literal).
final class GroupNotFound extends GroupArgumentResult {
  /// Nothing found.
  const GroupNotFound();
}

/// [source] with `key: value` among the arguments of the `final [group] =
/// Group(…)` it declares, before `children:`. A `middleware:` already
/// there gets [value] appended to its list; any other [key] already there
/// is [GroupArgumentTaken]. Robust to how the call is formatted.
GroupArgumentResult wireGroupArgument(
  String source,
  String group,
  String key,
  String value,
) {
  final call = RegExp(
    'final\\s+$group\\s*=\\s*(?:const\\s+)?Group\\(',
  ).firstMatch(source);
  if (call == null) return const GroupNotFound();
  final open = call.end - 1;
  final close = _closing(source, open);
  if (close == null) return const GroupNotFound();
  final args = _topLevelArguments(source, open + 1, close);
  String? nameOf((int, int) a) =>
      RegExp(r'^(\w+)\s*:').firstMatch(source.substring(a.$1, a.$2))?[1];
  final existing = args.where((a) => nameOf(a) == key).firstOrNull;
  if (existing != null) {
    final text = source.substring(existing.$1, existing.$2);
    if (key != 'middleware') return GroupArgumentTaken(text);
    final bracket = source.indexOf('[', existing.$1);
    final end = bracket < 0 || bracket >= existing.$2
        ? null
        : _closing(source, bracket);
    if (end == null || end >= existing.$2) return const GroupNotFound();
    final items = source
        .substring(bracket + 1, end)
        .trim()
        .replaceAll(RegExp(r',$'), '')
        .trim();
    return GroupArgumentAdded(
      source.replaceRange(
        bracket,
        end + 1,
        '[${items.isEmpty ? value : '$items, $value'}]',
      ),
    );
  }
  final argument = key == 'middleware' ? '$key: [$value]' : '$key: $value';
  final children = args.where((a) => nameOf(a) == 'children').firstOrNull;
  if (children != null) {
    return GroupArgumentAdded(
      source.replaceRange(children.$1, children.$1, '$argument, '),
    );
  }
  if (args.isEmpty) {
    return GroupArgumentAdded(source.replaceRange(close, close, argument));
  }
  final last = args.last.$2;
  final comma = source.substring(last, close).contains(',');
  return GroupArgumentAdded(
    source.replaceRange(last, close, comma ? ', $argument,' : ', $argument'),
  );
}

/// The offset of the bracket that closes the one at [open], skipping
/// strings and `//` comments, or null.
int? _closing(String s, int open) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    final c = s[i];
    if (c == "'" || c == '"') {
      final end = s.indexOf(c, i + 1);
      if (end < 0) return null;
      i = end;
    } else if (c == '/' && i + 1 < s.length && s[i + 1] == '/') {
      final end = s.indexOf('\n', i);
      if (end < 0) return null;
      i = end;
    } else if ('([{'.contains(c)) {
      depth++;
    } else if (')]}'.contains(c) && --depth == 0) {
      return i;
    }
  }
  return null;
}

/// The arguments between [start] and [end] (the inside of a call), as
/// offsets without the surrounding blanks and commas.
List<(int, int)> _topLevelArguments(String s, int start, int end) {
  final args = <(int, int)>[];
  var from = start;
  void add(int to) {
    final text = s.substring(from, to);
    if (text.trim().isEmpty) return;
    final lead = text.length - text.trimLeft().length;
    args.add((from + lead, from + text.trimRight().length));
  }

  for (var i = start; i < end; i++) {
    final c = s[i];
    if ('([{\'"'.contains(c) || (c == '/' && s[i + 1] == '/')) {
      final skip = c == '/'
          ? s.indexOf('\n', i)
          : '\'"'.contains(c)
          ? s.indexOf(c, i + 1)
          : _closing(s, i);
      if (skip == null || skip < 0) break;
      i = skip;
    } else if (c == ',') {
      add(i);
      from = i + 1;
    }
  }
  add(end);
  return args;
}
