/// The files `thor create` and `thor add` write. Each template is the
/// smallest code that compiles and shows something, in the style of the
/// guides.
library;

/// Where a new project takes thor's packages from (they are not on
/// pub.dev yet).
sealed class ThorSource {
  const ThorSource();

  /// The `dependencies`/`dev_dependencies` entry of [package].
  String entry(String package);

  /// Whether the project resolves with the enclosing workspace.
  bool get workspace => false;
}

/// An app of the thor monorepo (`apps/<name>`): the packages next door,
/// resolved with the workspace.
class MonorepoSource extends ThorSource {
  /// The monorepo's own apps.
  const MonorepoSource();

  @override
  String entry(String package) => '    path: ../../packages/$package';

  @override
  bool get workspace => true;
}

/// A project of its own, using a thor checkout on this machine.
class LocalSource extends ThorSource {
  /// The checkout at [root].
  const LocalSource(this.root);

  /// The checkout's folder.
  final String root;

  @override
  String entry(String package) => '    path: $root/packages/$package';
}

/// A project of its own, taking thor from its git repository.
class GitSource extends ThorSource {
  /// The repository at [url], at [ref].
  const GitSource(this.url, {this.ref = 'master'});

  /// The repository.
  final String url;

  /// The branch, tag or commit.
  final String ref;

  String _git(String path) =>
      '    git:\n      url: $url\n      ref: $ref\n      path: $path';

  @override
  String entry(String package) => _git('packages/$package');
}

/// The app's `analysis_options.yaml`: the editor and `dart analyze` run
/// thor's own rules (thor_lints: a closure where the browser needs a
/// state's member, THOR-S011…), taken from [source] like the packages. An
/// app of the monorepo includes the workspace's options, which enable them.
String analysisOptions(ThorSource source) => source.workspace
    ? '''
include: ../../analysis_options.yaml

analyzer:
  errors:
    # Apps are not libraries: their members need no API docs.
    public_member_api_docs: ignore
'''
    : '''
include: package:lints/recommended.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  exclude:
    - "**/build/**"
    - "**/.dart_tool/**"

# thor's own rules in the editor and in `dart analyze` (thor_lints): code
# the browser can't run, flagged where it is written. They run from the
# project's root: `thor analyze` does that.
plugins:
  thor_lints:
${source.entry('thor_lints')}
''';

/// `.github/workflows/ci.yml` of a project outside the monorepo: the checks
/// `thor create` leaves green (format, `dart analyze --fatal-infos` with
/// thor_lints, `thor test`). The `thor` command comes from [source]'s git
/// repository (or the public one, when [source] is a local checkout).
String ciWorkflow(ThorSource source) {
  final (url, ref) = switch (source) {
    GitSource(:final url, :final ref) => (url, ref),
    _ => (_publicRepository, 'master'),
  };
  final local = source is LocalSource
      ? '''
      # This project takes thor from a checkout on your machine (path:
      # dependencies in pubspec.yaml), which CI can't see: create it with
      # `thor create --git <url>` or point pubspec.yaml at the repository.
'''
      : '';
  return '''
name: CI

on:
  push:
    branches: [main, master]
  pull_request:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable
$local      - name: Install thor
        run: >
          dart pub global activate --source git $url
          --git-ref $ref --git-path packages/thor_cli
      - name: Dependencies
        run: dart pub get
      - name: Format
        run: dart format --output=none --set-exit-if-changed .
      - name: Analyze (infos are fatal)
        run: dart analyze --fatal-infos
      - name: Tests
        run: thor test
''';
}

const _publicRepository =
    'https://github.com/FranciscoRdz2001/thor-framework.git';

/// [value] escaped to sit inside a single-quoted Dart string literal
/// (backslash, quote, `$`, line breaks): user text (`--title`) never ends
/// the literal or starts an interpolation.
String dartString(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll("'", r"\'")
    .replaceAll(r'$', r'\$')
    .replaceAll('\n', r'\n')
    .replaceAll('\r', r'\r');

/// A new server app named [name] (`thor create`), in modules: the app
/// (`lib/app.dart`, `lib/router.dart`), its frame (`lib/shell/`), what the
/// modules share (`lib/core/`) and the home module with a counter that
/// runs in the browser (`lib/modules/home/`), its server and its tests,
/// taking thor from [source].
Map<String, String> appFiles(
  String name, {
  ThorSource source = const MonorepoSource(),
  String title = 'Hello, Thor',
}) => {
  'pubspec.yaml':
      '''
name: $name
description: A thor app.
publish_to: none
${source.workspace ? 'resolution: workspace\n' : ''}
environment:
  sdk: ^3.10.0

dependencies:
  thor_engine:
${source.entry('thor_engine')}
  thor_server:
${source.entry('thor_server')}
  thor_ui:
${source.entry('thor_ui')}

dev_dependencies:
  build_runner: ^2.4.0
${source.workspace ? '' : '  lints: ^6.0.0\n'}  test: ^1.25.0
  thor_builder:
${source.entry('thor_builder')}
  thor_test:
${source.entry('thor_test')}
''',
  'analysis_options.yaml': analysisOptions(source),
  // An app of the monorepo is checked by the repository's own CI.
  if (!source.workspace) '.github/workflows/ci.yml': ciWorkflow(source),
  '.gitignore': '''
.dart_tool/
build/
# The engine compiled by `thor dev` (thor build writes the release one).
web/engine.dart.js*
# Local environment (secrets): thor dev and thor preview read it.
.env
''',
  'bin/server.dart':
      '''
import 'package:$name/app.dart';
import 'package:$name/env.dart';
import 'package:thor_ui/router.dart';

/// The app's server: `thor dev` runs it and reloads it on every change;
/// `thor build` compiles it.
Future<void> main() => ThorServer.serve(
  () => ThorServer(
    handler: RouteHandler(
      routes: app.routes, // the table of lib/router.dart
      renderer: appRenderer(),
      // `Secure` on cookies: unset, whenever the request came over HTTPS
      // (or a proxy says so), so `thor dev` on http://localhost keeps its
      // session; SECURE_COOKIES=true forces it, =false turns it off.
      secureCookies: env.of(AppEnv.secureCookies),
    ),
    // build/public after `thor build`; web/ under `thor dev`.
    publicDir: ThorServer.appPublicDir(),
  ),
  // Read first: a missing or invalid variable stops the start (THOR-P011).
  port: env.of(AppEnv.port),
);
''',
  'lib/env.dart': '''
/// What the app reads from the environment, typed and checked at startup:
/// every missing or invalid variable is listed at once (THOR-P011). Put
/// local values in `.env` (git-ignored); `thor dev` passes them in.
library;

import 'package:thor_ui/router.dart';

/// The app's variables.
abstract final class AppEnv {
  /// The port the server listens on.
  static const port = EnvInt('PORT', fallback: 4300);

  /// `Secure` on cookies (`null`: when the request came over HTTPS).
  static const secureCookies = EnvOptional(EnvBool('SECURE_COOKIES'));

  // More, for example:
  //   static const api = EnvUrl('API_URL');
  //   static const session = EnvSecret('SESSION_SECRET', minLength: 32);
  // and sign the session with it, always with a lifetime (`thor dev` warns
  // about a session without `maxAge`, THOR-P033):
  //   SignedCookies(env.of(AppEnv.session).reveal(),
  //       purpose: 'session', maxAge: const Duration(days: 30))

  /// Every variable.
  static const schema = EnvSchema([port, secureCookies]);
}

/// The loaded environment.
final env = AppEnv.schema.load();
''',
  'lib/app.dart': '''
/// The app around every page: routes, theme, page reset and language, in
/// one place for the server (`bin/server.dart`) and the tests.
library;

import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import 'core/theme/app_theme.dart';
import 'router.dart';

/// The app's language (`<html lang>`). For several languages list them in
/// `supportedLocales` and add `localizationsDelegates` (docs:
/// https://thor-docs.vercel.app/en/interface/localization).
const appLocale = Locale('en');

/// The app, declared once (like `MaterialApp.router`): its routes
/// (`lib/router.dart`), the page reset (no body margin, `border-box`) and
/// its theme (`lib/core/theme/app_theme.dart`).
final app = ThorApp.router(
  routerConfig: router,
  theme: appTheme,
  darkTheme: appDarkTheme,
  supportedLocales: const [appLocale],
  styles: thorResetStyles,
);

/// Renders every page in [app], in [appLocale]'s language, with the app's
/// icon.
WidgetRenderer appRenderer() => WidgetRenderer.router(
  app,
  locale: appLocale,
  head: const [html.link(rel: 'icon', href: '/favicon.svg')],
);
''',
  'lib/router.dart': routerFile(name),
  'lib/shell/app_shell.dart':
      '''
import 'package:$name/modules/home/home_routes.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

/// The frame of every page: header, the page and footer. It belongs to
/// the app, not to `core/`: it may link to the modules' routes.
class AppShell extends ThorLayout<void> {
  /// The one instance the table holds and every request shares.
  const AppShell({this.title = '${dartString(title)}', this.footer = 'Made with Thor'});

  /// The site's name: the header link and the default `<title>`. With
  /// several languages, read it from `AppLocalizations` instead.
  final String title;

  /// The text of the footer.
  final String footer;

  /// Default meta of the pages below (a page's own meta wins).
  @override
  PageMeta meta(PageState<void> state) => PageMeta(title: title);

  @override
  Widget build(BuildContext context, PageState<void> state, Widget child) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            role: SemanticsRole.header,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0x1F000000))),
              ),
              child: Link(
                href: homeRoute.link(),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Semantics(
              role: SemanticsRole.main,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 960),
                child: child,
              ),
            ),
          ),
          Semantics(
            role: SemanticsRole.contentInfo,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                footer,
                style: const TextStyle(fontSize: 13, color: Color(0x99000000)),
              ),
            ),
          ),
        ],
      );
}
''',
  'lib/shell/app_error_page.dart':
      '''
import 'package:$name/core/widgets/page_title.dart';
import 'package:$name/modules/home/home_routes.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

/// A missing page (or an error), with a way back.
class AppErrorPage extends ErrorPage {
  /// The one instance the table holds.
  const AppErrorPage();

  @override
  Widget build(BuildContext context, ErrorState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: [
      PageTitle(
        state.status == 404
            ? 'We could not find that page'
            : 'Something went wrong',
      ),
      Link(href: homeRoute.link(), child: const Text('Back to home')),
    ],
  );
}
''',
  'lib/core/theme/app_theme.dart': '''
import 'package:thor_ui/thor_ui.dart';

/// The light theme: Material 3 colors and the system font. Change the
/// colors here (`ColorScheme.light(primary: …)`); widgets read them.
final appTheme = ThemeData();

/// The dark theme: the page follows the system's preference.
final appDarkTheme = ThemeData.dark();
''',
  'lib/core/widgets/page_title.dart': '''
import 'package:thor_ui/thor_ui.dart';

/// The title of a page: its `<h1>`. A general component: it knows no
/// module, so any page can use it.
class PageTitle extends StatelessWidget {
  /// The title [text].
  const PageTitle(this.text, {super.key});

  /// What it says.
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    headingLevel: 1,
    child: Text(
      text,
      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
    ),
  );
}
''',
  'lib/modules/home/home_routes.dart': '''
import 'package:thor_ui/router.dart';

import 'pages/home_page.dart';

/// `/`: link to it with `homeRoute.link()`.
final homeRoute = ThorRoute('/', const HomePage());

/// The home module: its routes and what they share (a layout, middleware,
/// a stylesheet). The app's table puts it in place.
final homeModule = Group(children: [homeRoute]);
''',
  'lib/modules/home/pages/home_page.dart':
      '''
import 'package:$name/core/widgets/page_title.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../widgets/counter_card.dart';

/// The page `/`.
class HomePage extends ThorPage<void> {
  /// The one instance the table holds and every request shares.
  const HomePage();

  /// Title and description.
  @override
  PageMeta meta(PageState<void> state) =>
      const PageMeta(title: '${dartString(title)}', description: 'My first Thor app.');

  @override
  Widget build(BuildContext context, PageState<void> state) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 16,
    children: [
      PageTitle('${dartString(title)}'),
      Text(
        'Edit lib/modules/home/pages/home_page.dart and save: '
        'the page updates itself.',
      ),
      CounterCard(),
    ],
  );
}
''',
  'lib/modules/home/widgets/counter_card.dart': '''
import 'package:thor_ui/thor_ui.dart';

import '../state/counter_view_model.dart';

/// The counter: the number and the buttons that change it, in the
/// browser, without reloading the page. It builds one element (a `Card`):
/// a wrapper around it (`Padding`, `Expanded`) fuses into that element.
class CounterCard extends StatelessWidget implements ThorElementWidget {
  /// The card.
  const CounterCard({super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          const Text('You have pushed the button this many times:'),
          DefaultTextStyle(
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700),
            child: Watch(counter.label),
          ),
          Row(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: counter.increment,
                child: const Text('Add'),
              ),
              TextButton(onPressed: counter.reset, child: const Text('Reset')),
            ],
          ),
        ],
      ),
    ),
  );
}
''',
  'lib/modules/home/state/counter_view_model.dart': '''
import 'package:thor_ui/thor_ui.dart';

/// The counter's view model. It runs in the browser: its fields change there,
/// and the widgets that read them (`Watch(counter.label)`) follow.
class CounterViewModel extends ThorState {
  /// How many times the button was pressed.
  final count = state(0);

  /// The count, as the page shows it.
  String label() => '\${count.value}';

  /// One more.
  void increment() => count.value++;

  /// Back to zero.
  void reset() => count.value = 0;
}

/// The counter every page shares.
final counter = CounterViewModel();
''',
  'web/favicon.svg':
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">'
      '<rect width="32" height="32" rx="8" fill="#4f46e5"/>'
      '<text x="16" y="22" font-family="system-ui,sans-serif" font-size="18" '
      'font-weight="700" fill="#fff" text-anchor="middle">t</text></svg>\n',
  'test/app_test.dart':
      '''
import 'package:$name/app.dart';
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';
import 'package:thor_ui/router.dart';

void main() {
  final handler = RouteHandler(routes: app.routes, renderer: appRenderer());

  // A visitor: keeps cookies, follows redirects when asked (docs:
  // https://thor-docs.vercel.app/en/test-and-deploy/testing).
  Future<ThorTestResponse> get(String path) => handler.client().get(path);

  test('the home page renders, with the counter at zero', () async {
    final response = await get('/');
    expect(response.status, 200);
    expect(response.text, contains('<h1'));
    expect(response.text, contains('>0<'));
    // Its buttons call the state's methods in the browser.
    expect(response.text, contains('CounterViewModel.increment'));
    expect(response.text, contains('CounterViewModel.reset'));
  });

  test('every page has the reset and the theme', () async {
    final page = (await get('/')).text;
    expect(page, contains('@layer thor.reset'));
    expect(page, contains('--t-primary'));
  });

  test('an unknown page is a 404', () async {
    expect((await get('/missing')).status, 404);
  });
}
''',
  'test/modules/home/counter_view_model_test.dart':
      '''
import 'package:$name/modules/home/state/counter_view_model.dart';
import 'package:test/test.dart';

void main() {
  test('the counter adds one and goes back to zero', () {
    final counter = CounterViewModel();
    expect(counter.label(), '0');
    counter
      ..increment()
      ..increment();
    expect(counter.label(), '2');
    counter.reset();
    expect(counter.label(), '0');
  });
}
''',
};

/// `lib/router.dart` of a new app: it composes the modules' groups inside
/// the app's frame.
String routerFile(String app) => '''
// The app's routes: the table the server serves and every link uses. Each
// module brings its group (`lib/modules/<name>/<name>_routes.dart`); the
// table puts them inside the app's frame.
import 'package:thor_ui/router.dart';

import 'modules/home/home_routes.dart';
import 'shell/app_error_page.dart';
import 'shell/app_shell.dart';

/// Every route of the app.
final ThorRouter router = ThorRouter([
  Group(
    layout: const AppShell(),
    error: const AppErrorPage(),
    children: [homeModule],
  ),
]);
''';

/// `lib/pages/<name>_layout.dart`: the frame a `Group` puts around its
/// pages ([className], `RootLayout` for the whole app).
String layoutFile({String title = 'My app', String className = 'RootLayout'}) =>
    '''
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

/// The frame around every page of its group
/// (`Group(layout: const $className(), children: […])`).
class $className extends ThorLayout<void> {
  /// The one instance the table holds and every request shares.
  const $className();

  /// Default meta of the pages below (a page's own meta wins).
  @override
  PageMeta meta(PageState<void> state) => const PageMeta(title: '${dartString(title)}');

  @override
  Widget build(BuildContext context, PageState<void> state, Widget child) =>
      Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          role: SemanticsRole.main,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 960),
            child: child,
          ),
        ),
      );
}
''';

/// `lib/pages/error_page.dart`: `AppErrorPage`, what a `Group` shows for
/// an error or a URL with no route (`Group(error: const AppErrorPage(),
/// …)`). With [app]
/// (its package, when it has a `homeRoute`, declared in [homeLibrary])
/// the way back is that route.
String errorFile({
  String? app,
  String homeLibrary = 'router.dart',
  String className = 'AppErrorPage',
}) =>
    '''
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';
${_routerImport(app, homeLibrary)}
/// A missing page (or an error), with a way back.
class $className extends ErrorPage {
  /// The one instance the table holds.
  const $className();

  @override
  Widget build(BuildContext context, ErrorState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: [
      Semantics(
        headingLevel: 1,
        child: Text(
          state.status == 404
              ? 'We could not find that page'
              : 'Something went wrong',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
      ),
      ${_homeLink(app)},
    ],
  );
}
''';

/// `lib/pages/not_found_page.dart`: `NotFoundPage`, the 404 of a group's
/// URLs, inside its layouts (`Group(notFound: const NotFoundPage(), …)`).
/// [app] as
/// in [errorFile].
String notFoundFile({
  String? app,
  String homeLibrary = 'router.dart',
  String className = 'NotFoundPage',
}) =>
    '''
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';
${_routerImport(app, homeLibrary)}
/// A URL of this group with no page.
class $className extends ErrorPage {
  /// The one instance the table holds.
  const $className();

  @override
  Widget build(BuildContext context, ErrorState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: [
      const Semantics(
        headingLevel: 1,
        child: Text(
          'We could not find that page',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
      ),
      ${_homeLink(app)},
    ],
  );
}
''';

String _routerImport(String? app, String homeLibrary) =>
    app == null ? '' : "\nimport 'package:$app/$homeLibrary';\n";

// A literal '/' when the app may have no `homeRoute` (`thor add` in any
// app); the route's link otherwise.
String _homeLink(String? app) => app == null
    ? "const Link(href: RouteUrl('/'), child: Text('Back to home'))"
    : "Link(href: homeRoute.link(), child: const Text('Back to home'))";

/// `lib/middleware/<name>.dart`: [name] runs around every request to the
/// pages of a group (`Group(middleware: [$name], …)`), outer groups first.
String middlewareFile(String name) =>
    '''
import 'package:thor_ui/router.dart';

/// Every request to the pages of its group passes here: read the session
/// (a `SignedCookies(purpose: 'session', maxAge: …)`, see `lib/env.dart`)
/// into `request.context`, end early (`throw Redirect('/login')`, or return
/// a response without calling [next]) or change the response.
Future<ThorResponse> $name(PageRequest request, Next next) async {
  final response = await next();
  return response;
}
''';

/// The parameters of a route [url] (`/product/:id:int` → `id` as an
/// int), in order.
List<(String, bool)> routeParams(String url) => [
  for (final m in RegExp(r'[:*](\w+)(:int)?').allMatches(url))
    (m[1]!, m[2] != null),
];

/// `lib/pages/<name>_page.dart` for the route [url] (`/product/:id`): a
/// `load` reading each parameter when the route has some. The class is
/// [className], or the one [pageClassName] derives from the URL.
String pageFile(String url, {String? className}) {
  final params = routeParams(url);
  final words = [
    for (final s in url.split('/'))
      if (s.isNotEmpty && !s.startsWith(':') && !s.startsWith('*')) s,
  ];
  final title = words.isEmpty ? 'Home' : words.last;
  final cls = className ?? pageClassName(url);
  if (params.isEmpty) {
    return '''
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

/// The page `$url`.
class $cls extends ThorPage<void> {
  /// The one instance the table holds and every request shares.
  const $cls();

  /// Title and description.
  @override
  PageMeta meta(PageState<void> state) => const PageMeta(title: '$title');

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      const Semantics(headingLevel: 1, child: Text('$title'));
}
''';
  }
  final fields = [
    for (final (name, isInt) in params)
      '  /// `:$name` of the URL.\n  final ${isInt ? 'int' : 'String'} $name;',
  ].join('\n\n');
  final ctor = params.map((p) => 'this.${p.$1}').join(', ');
  final reads = [
    for (final (name, isInt) in params)
      isInt ? "request.paramInt('$name')" : "request.param('$name')",
  ].join(', ');
  final first = params.first.$1;
  return '''
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

/// What `$url` shows, loaded before it renders.
class ${cls}Data {
  /// The data of one page.
  const ${cls}Data($ctor);

$fields
}

/// The page `$url`.
class $cls extends ThorPage<${cls}Data> {
  /// The one instance the table holds and every request shares.
  const $cls();

  /// Reads the URL (and, later, your data source). Throw `NotFound()` for a
  /// missing item: the error page answers 404.
  @override
  ${cls}Data load(PageRequest request) => ${cls}Data($reads);

  /// Title and description.
  @override
  PageMeta meta(PageState<${cls}Data> state) =>
      PageMeta(title: '$title \${state.data.$first}');

  @override
  Widget build(BuildContext context, PageState<${cls}Data> state) =>
      Semantics(
        headingLevel: 1,
        child: Text('$title \${state.data.$first}'),
      );
}
''';
}

/// The class a `thor add state <name>` makes: Flutter's name, `CartViewModel`
/// for `Cart`. A [name] that already ends in `ViewModel` or `State`
/// (`CartState`) is kept as typed.
String stateClassName(String name) =>
    _stateSuffix(name) == null ? '${name}ViewModel' : name;

// The suffix [name] already has (`ViewModel` or `State`) when
// something comes before it.
String? _stateSuffix(String name) {
  for (final suffix in const ['ViewModel', 'State']) {
    if (name.endsWith(suffix) && name.length > suffix.length) return suffix;
  }
  return null;
}

/// `lib/<snake>_view_model.dart`: a browser state class ([name] like `Cart`
/// → `CartViewModel`, `cart` instance; `CartState` stays `CartState`).
String stateFile(String name) {
  final type = stateClassName(name);
  final base = type.substring(0, type.length - _stateSuffix(type)!.length);
  final instance = base[0].toLowerCase() + base.substring(1);
  return '''
import 'package:thor_ui/thor_ui.dart';

/// State that runs in the browser: its fields change there, and the
/// widgets that read them (`Watch($instance.label)`) follow. thor lists
/// its members (the names the page uses) out of the app, in
/// `.dart_tool/thor/`.
class $type extends ThorState {
  final count = state(0);

  String label() => '\${count.value}';

  void increment() => count.value++;
}

final $instance = $type();
''';
}

/// `lib/widgets/<snake>.dart`: a component ([name] like `ProductCard`)
/// whose look lives in one stylesheet class under `thor.components`
/// (`styles`, listed once in the app stylesheet), not per instance.
String componentFile(String name) {
  final cls = snakeCase(name).replaceAll('_', '-');
  return '''
import 'package:thor_ui/html.dart' show css;
import 'package:thor_ui/thor_ui.dart';

/// $name. Its look (states, breakpoints) is one class in [styles]; values
/// of one instance go in widget props (they win over the class).
class $name extends StatelessWidget {
  /// $name with [title].
  const $name({super.key, required this.title});

  /// What it shows.
  final String title;

  /// Its rules, in the `thor.components` layer. List them once in the app
  /// stylesheet (`WidgetRenderer(styles: [...$name.styles])`): with
  /// `shareStyles` they travel in the cached sheet.
  static final styles = <StyleRule>[
    css.components([
      css('.$cls', [
        css('&').props(
          StyleProps(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        css('&:hover').props(const StyleProps(offset: Offset(0, -2))),
      ]),
    ]),
  ];

  @override
  Widget build(BuildContext context) =>
      Styled(classes: const ['$cls'], child: Text(title));
}
''';
}

/// `test/widgets/<snake>_test.dart` for [componentFile].
String componentTestFile(String app, String name, {String? library}) {
  final snake = snakeCase(name);
  return '''
import 'package:$app/${library ?? 'widgets/$snake.dart'}';
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';

void main() {
  setUpAll(initializeThorTests);

  test('$name shows its title with its class', () async {
    final html = await renderHtml(const $name(title: 'Hello'));
    expect(html, contains('Hello'));
    expect(html, contains('${snakeCase(name).replaceAll('_', '-')}'));
  });
}
''';
}

/// `lib/styles/<name>.dart`: the stylesheet of a group's pages
/// (`Group(styles: <name>Styles, …)`), after the groups' above.
String stylesFile(String name) =>
    '''
import 'package:thor_ui/html.dart' show css;
import 'package:thor_ui/thor_ui.dart';

/// The stylesheet of the pages of its group, after the groups' above: a
/// cached file with `shareStyles`, else a `<style>` in their pages. For
/// what the page's own markup can't say (HTML from markdown, a third-party
/// widget's inner elements); a widget's look goes in the widget.
final ${name}Styles = <StyleRule>[
  css('.prose p').props(const StyleProps(margin: EdgeInsets.only(bottom: 16))),
];
''';

/// The route file of a new module [module] (`thor add page` in an app in
/// modules): its Group, empty until a page joins it.
String moduleRoutesFile(String module) =>
    '''
import 'package:thor_ui/router.dart';

/// The $module module: its routes and what they share (a layout,
/// middleware, a stylesheet). The app's table puts it in place.
final ${lowerCamel(module)}Module = Group(children: []);
''';

/// `sales_orders` → `salesOrders`.
String lowerCamel(String snake) {
  final parts = snake.split('_');
  return parts.first +
      [
        for (final w in parts.skip(1))
          if (w.isNotEmpty) w[0].toUpperCase() + w.substring(1),
      ].join();
}

/// `sales_orders` → `SalesOrders`.
String upperCamel(String snake) {
  final c = lowerCamel(snake);
  return c[0].toUpperCase() + c.substring(1);
}

/// `CartViewModel` → `cart_view_model`.
String snakeCase(String name) => name
    .replaceAllMapped(RegExp('(?<=[a-z0-9])([A-Z])'), (m) => '_${m[1]}')
    .toLowerCase();

/// Whether [name] is a valid package name (`shop`, `my_app`).
bool isPackageName(String name) =>
    RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name) && !_reserved.contains(name);

const _reserved = {
  'thor',
  'thor_ui',
  'thor_style',
  'thor_engine',
  'thor_server',
  'thor_builder',
  'thor_studio',
  'thor_test',
  'thor_cli',
  'test',
  'build_runner',
};

/// The class name of the page at [url] (`/product/:id` → `ProductPage`,
/// `/` → `HomePage`).
String pageClassName(String url) {
  final segments = url.split('/').where((s) => s.isNotEmpty).toList();
  var words = [
    for (final s in segments)
      if (!s.startsWith(':') && !s.startsWith('*'))
        ...s.split(RegExp('[^A-Za-z0-9]+')).where((w) => w.isNotEmpty),
  ];
  if (words.isEmpty) {
    words = [for (final (name, _) in routeParams(url)) name];
  } else if (segments.last.startsWith(':') || segments.last.startsWith('*')) {
    // The parameters after the last fixed segment name the page too, so
    // `/orders/:id` (OrdersByIdPage) doesn't take `/orders`' name.
    final trailing = segments.reversed
        .takeWhile((s) => s.startsWith(':') || s.startsWith('*'))
        .toList()
        .reversed
        .map((s) => s.substring(1).split(':').first);
    words = [
      ...words,
      'By',
      ...trailing.expand((t) => [t, 'And']).toList()..removeLast(),
    ];
  }
  if (words.isEmpty) return 'HomePage';
  final name = words
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join();
  return RegExp('^[0-9]').hasMatch(name) ? 'Route${name}Page' : '${name}Page';
}

/// The camelCase route variable of a page class (`ProductPage` →
/// `productRoute`).
String routeVariable(String pageClass) {
  final base = pageClass.endsWith('Page')
      ? pageClass.substring(0, pageClass.length - 4)
      : pageClass;
  return '${base[0].toLowerCase()}${base.substring(1)}Route';
}
