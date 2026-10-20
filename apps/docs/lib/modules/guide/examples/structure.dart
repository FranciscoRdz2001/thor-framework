// ignore_for_file: public_member_api_docs
// (each visual is named by its use in the guide)
// The illustrations and the explorer of "Project structure".
import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../core/content/code.dart' show DocsCode;
import '../../../core/content/library.dart' show MessageOf;
import '../../../core/i18n/docs_locale.dart';

/// The code face of the diagrams.
const _mono = TextStyle(
  fontFamily: StudioFontFamilies.mono,
  fontSize: 12,
  height: 1.5,
);

const _sectionLabel = TextStyle(
  fontSize: 12,
  height: 1.4,
  fontWeight: FontWeight.w600,
  color: StudioContentColors.muted,
);

const _folder = IconData.svg(
  'lucide-folder',
  '<path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 '
      '3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/>',
  strokeWidth: 2,
);
const _file = IconData.svg(
  'lucide-file',
  '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/>'
      '<path d="M14 2v4a2 2 0 0 0 2 2h4"/>',
  strokeWidth: 2,
);

/// One file of the new project: its path, what it is and its code (what
/// `thor create` writes, trimmed).
typedef _File = ({String path, MessageOf about, String code});

final _files = <_File>[
  (
    path: 'lib/router.dart',
    about: (t) => t.structAbout01,
    code: '''
final ThorRouter router = ThorRouter([
  Group(
    layout: const AppShell(),
    error: const AppErrorPage(),
    children: [homeModule],
  ),
]);''',
  ),
  (
    path: 'lib/app.dart',
    about: (t) => t.structAbout02,
    code: '''
const appLocale = Locale('en');

final app = ThorApp.router(
  routerConfig: router,
  theme: appTheme,
  darkTheme: appDarkTheme,
  supportedLocales: const [appLocale],
  styles: thorResetStyles,
);

WidgetRenderer appRenderer() => WidgetRenderer.router(
  app,
  locale: appLocale,
  head: const [html.link(rel: 'icon', href: '/favicon.svg')],
);''',
  ),
  (
    path: 'lib/modules/home/pages/home_page.dart',
    about: (t) => t.structAbout03,
    code: '''
class HomePage extends ThorPage<void> {
  const HomePage();

  @override
  PageMeta meta(PageState<void> state) =>
      const PageMeta(title: 'My app', description: 'My first Thor app.');

  @override
  Widget build(BuildContext context, PageState<void> state) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 16,
    children: [
      PageTitle('My app'),
      Text('Edit lib/modules/home/pages/home_page.dart and save.'),
      CounterCard(),
    ],
  );
}''',
  ),
  (
    path: 'lib/shell/app_shell.dart',
    about: (t) => t.structAbout04,
    code: '''
class AppShell extends ThorLayout<void> {
  const AppShell({this.title = 'My app', this.footer = 'Made with Thor'});

  final String title;
  final String footer;

  @override
  PageMeta meta(PageState<void> state) => PageMeta(title: title);

  @override
  Widget build(BuildContext context, PageState<void> state, Widget child) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            role: SemanticsRole.header,
            child: Link(href: homeRoute.link(), child: Text(title)),
          ),
          Semantics(role: SemanticsRole.main, child: child),
          Semantics(role: SemanticsRole.contentInfo, child: Text(footer)),
        ],
      );
}''',
  ),
  (
    path: 'lib/shell/app_error_page.dart',
    about: (t) => t.structAbout05,
    code: '''
class AppErrorPage extends ErrorPage {
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
}''',
  ),
  (
    path: 'lib/env.dart',
    about: (t) => t.structAbout06,
    code: '''
abstract final class AppEnv {
  static const port = EnvInt('PORT', fallback: 4300);
  static const secureCookies = EnvOptional(EnvBool('SECURE_COOKIES'));

  static const schema = EnvSchema([port, secureCookies]);
}

final env = AppEnv.schema.load();''',
  ),
  (
    path: 'bin/server.dart',
    about: (t) => t.structAbout07,
    code: '''
Future<void> main() => ThorServer.serve(
  () => ThorServer(
    handler: RouteHandler(
      routes: app.routes,
      renderer: appRenderer(),
      secureCookies: env.of(AppEnv.secureCookies),
    ),
    publicDir: ThorServer.appPublicDir(),
  ),
  port: env.of(AppEnv.port),
);''',
  ),
  (
    path: 'test/app_test.dart',
    about: (t) => t.structAbout08,
    code: '''
void main() {
  final handler = RouteHandler(routes: app.routes, renderer: appRenderer());

  Future<ThorTestResponse> get(String path) => handler.client().get(path);

  test('the home page renders, with the counter at zero', () async {
    final response = await get('/');
    expect(response.status, 200);
    expect(response.text, contains('>0<'));
  });

  test('an unknown page is a 404', () async {
    expect((await get('/missing')).status, 404);
  });
}''',
  ),
  (
    path: 'lib/modules/home/home_routes.dart',
    about: (t) => t.structAboutHomeRoutes,
    code: '''
final homeRoute = ThorRoute('/', const HomePage());

final homeModule = Group(children: [homeRoute]);''',
  ),
  (
    path: 'lib/modules/home/widgets/counter_card.dart',
    about: (t) => t.structAboutCounterCard,
    code: '''
class CounterCard extends StatelessWidget implements ThorElementWidget {
  const CounterCard({super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Watch(counter.label),
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
  );
}''',
  ),
  (
    path: 'lib/modules/home/state/counter_view_model.dart',
    about: (t) => t.structAboutCounterViewModel,
    code: '''
class CounterViewModel extends ThorState {
  final count = state(0);

  String label() => '\${count.value}';

  void increment() => count.value++;

  void reset() => count.value = 0;
}

final counter = CounterViewModel();''',
  ),
  (
    path: 'lib/core/theme/app_theme.dart',
    about: (t) => t.structAboutTheme,
    code: '''
final appTheme = ThemeData();

final appDarkTheme = ThemeData.dark();''',
  ),
  (
    path: 'lib/core/widgets/page_title.dart',
    about: (t) => t.structAboutPageTitle,
    code: '''
class PageTitle extends StatelessWidget {
  const PageTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    headingLevel: 1,
    child: Text(
      text,
      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
    ),
  );
}''',
  ),
  (
    path: 'test/modules/home/counter_view_model_test.dart',
    about: (t) => t.structAboutCounterTest,
    code: '''
void main() {
  test('the counter adds one and goes back to zero', () {
    final counter = CounterViewModel();
    counter
      ..increment()
      ..increment();
    expect(counter.label(), '2');
    counter.reset();
    expect(counter.label(), '0');
  });
}''',
  ),
  // ── The same app grown into modules (indices from _newCount) ──
  (
    path: 'lib/router.dart',
    about: (t) => t.structAbout09,
    code: '''
final ThorRouter router = ThorRouter([
  Group(
    layout: const AppShell(),
    middleware: [session, signInOn401('/login')],
    error: const AppErrorPage(),
    children: [homeRoute, salesModule, catalogModule],
  ),
  // Outside the shell: full screen, no session.
  Group(children: [loginRoute]),
]);''',
  ),
  (
    path: 'lib/shell/app_shell.dart',
    about: (t) => t.structAbout10,
    code: '''
class AppShell extends ThorLayout<void> {
  const AppShell();

  @override
  Widget build(BuildContext context, PageState<void> state, Widget child) =>
      Column(
        children: [
          AppHeader(links: [
            (label: 'Sales', href: ordersRoute.link()),
            (label: 'Catalog', href: productsRoute.link()),
          ]),
          child,
          const AppFooter(),
        ],
      );
}''',
  ),
  (
    path: 'lib/core/api/api.dart',
    about: (t) => t.structAbout11,
    code: '''
final _http = ThorHttpClient(headers: {HttpHeader.accept: 'application/json'});

final class Api {
  Api(this._base, this._token);

  final Uri _base;
  final String? _token;

  Future<Object?> get(String path, [Map<String, String>? query]) async {
    final r = await _http.get(
      _base.resolve(path).replace(queryParameters: query),
      headers: {if (_token != null) 'authorization': 'Bearer \$_token'},
    );
    return switch (r.statusCode) {
      404 => throw const NotFound(),
      401 => throw const HttpError(StatusCode.unauthorized),
      _ => r.ensureOk().json(),
    };
  }
}

/// Each request gets its own client, with its session token.
const apiKey = ContextKey<Api>('api');''',
  ),
  (
    path: 'lib/core/session/session.dart',
    about: (t) => t.structAbout12,
    code: '''
const userKey = ContextKey<User>('user');

Future<ThorResponse> session(PageRequest request, Next next) async {
  final token = request.cookies['session'];
  final api = Api(env.of(AppEnv.api), token);
  request.context.set(apiKey, api);
  if (token != null) {
    request.context.set(userKey, await UsersRepo(api).current());
  }
  return next();
}''',
  ),
  (
    path: 'lib/core/auth/permissions.dart',
    about: (t) => t.structAbout13,
    code: '''
enum Role { sales, catalog, admin }

/// For a module Group: requires a role.
Middleware requireRole(Role role) => (request, next) {
  final user = request.context.get(userKey);
  if (user == null) throw Redirect(loginRoute.link());
  if (!user.roles.contains(role)) throw const HttpError(StatusCode.forbidden);
  return next();
};''',
  ),
  (
    path: 'lib/core/widgets/page_header.dart',
    about: (t) => t.structAbout14,
    code: '''
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Semantics(headingLevel: 1, child: Text(title)),
      ),
      ...actions,
    ],
  );
}''',
  ),
  (
    path: 'lib/modules/sales/sales_routes.dart',
    about: (t) => t.structAbout15,
    code: '''
final salesModule = Group(
  prefix: '/sales',
  layout: const SalesLayout(),
  middleware: [requireRole(Role.sales)],
  error: const SalesErrorPage(),
  styles: salesStyles,
  children: [ordersSubmodule, customersSubmodule],
);''',
  ),
  (
    path: 'lib/modules/sales/middleware/open_register.dart',
    about: (t) => t.structAbout16,
    code: '''
Future<ThorResponse> requireOpenRegister(PageRequest request, Next next) async {
  final register = await RegisterRepo(request.context.get(apiKey)!).current();
  if (!register.isOpen) throw Redirect(openRegisterRoute.link());
  return next();
}''',
  ),
  (
    path: 'lib/modules/sales/data/orders_repository.dart',
    about: (t) => t.structAbout17,
    code: '''
final class OrdersRepository {
  const OrdersRepository(this._api);
  final Api _api;

  Future<List<Order>> list({OrderStatus? status}) async {
    final json = await _api.get('orders', {
      if (status != null) 'status': status.name,
    });
    return [
      for (final o in json! as List) Order.fromJson(o as Map<String, Object?>),
    ];
  }

  /// Throws [NotFound] when there is no such order.
  Future<Order> find(String id) async =>
      Order.fromJson(await _api.get('orders/\$id') as Map<String, Object?>);
}''',
  ),
  (
    path: 'lib/modules/sales/widgets/status_chip.dart',
    about: (t) => t.structAbout18,
    code: '''
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(status.label),
    backgroundColor: switch (status) {
      OrderStatus.pending => Tokens.warningBg,
      OrderStatus.delivered => Tokens.okBg,
      OrderStatus.cancelled => Tokens.errorBg,
    },
  );
}''',
  ),
  (
    path: 'lib/modules/sales/orders/orders_routes.dart',
    about: (t) => t.structAbout19,
    code: '''
final ordersRoute = ThorRoute('/sales/orders', const OrdersPage());
final orderRoute = ThorRoute('/sales/orders/:id', const OrderPage());

final ordersSubmodule = Group(children: [ordersRoute, orderRoute]);''',
  ),
  (
    path: 'lib/modules/sales/orders/pages/orders_page.dart',
    about: (t) => t.structAbout20,
    code: '''
class OrdersPage extends ThorPage<List<Order>> {
  const OrdersPage();

  @override
  Future<List<Order>> load(PageRequest request) {
    final status = request.queryParameters['status'];
    return OrdersRepository(request.context.get(apiKey)!).list(
      status: status == null ? null : OrderStatus.values.byName(status),
    );
  }

  @override
  Widget build(BuildContext context, PageState<List<Order>> state) =>
      Column(children: [
        const PageHeader(title: 'Orders'),
        OrdersTable(orders: state.data),
      ]);
}''',
  ),
  (
    path: 'lib/modules/sales/orders/forms/order_form.dart',
    about: (t) => t.structAbout21,
    code: '''
final class OrderForm extends FormSchema {
  const OrderForm._() : super(const [customer, total]);
  static const schema = OrderForm._();

  static const customer = TextSchemaField('customer',
      validators: [Validator.required('Pick a customer')]);
  static const total = TextSchemaField('total',
      validators: [Validator.required('Enter the total')]);
}''',
  ),
  (
    path: 'lib/modules/sales/orders/widgets/orders_table.dart',
    about: (t) => t.structAbout22,
    code: '''
class OrdersTable extends StatelessWidget {
  const OrdersTable({super.key, required this.orders});
  final List<Order> orders;

  @override
  Widget build(BuildContext context) => DataTable(
    columns: const [
      DataColumn(label: Text('Order')),
      DataColumn(label: Text('Status')),
    ],
    rows: [
      for (final o in orders)
        DataRow(cells: [
          DataCell(Link(href: orderRoute.link({'id': o.id}), child: Text(o.number))),
          DataCell(StatusChip(o.status)),
        ]),
    ],
  );
}''',
  ),
  (
    path: 'lib/modules/sales/orders/state/selection_view_model.dart',
    about: (t) => t.structAbout23,
    code: '''
class SelectionViewModel extends ThorState {
  final ids = state(<int>{});

  String label() => 'Selected: \${ids.value.length}';

  void toggle(int id) => ids.value = ids.value.contains(id)
      ? ({...ids.value}..remove(id))
      : {...ids.value, id};
}

final selection = SelectionViewModel();''',
  ),
  (
    path: 'lib/modules/sales/pages/sales_error_page.dart',
    about: (t) => t.structAbout24,
    code: '''
class SalesErrorPage extends ErrorPage {
  const SalesErrorPage();

  @override
  Widget build(BuildContext context, ErrorState state) => Text(
    state.status == StatusCode.notFound
        ? 'We could not find that order'
        : 'Sales is not available',
  );
}''',
  ),
];

/// How many files the new project has: the modular ones follow.
const _newCount = 14;

/// The file the modular view opens on (its module's Group).
const _firstModular = _newCount + 6;

// The trees as they're drawn: folders (no file) and files (their index).
const _newTree = <(int depth, String name, int? file)>[
  (0, 'my_app/', null),
  (1, 'bin/', null),
  (2, 'server.dart', 6),
  (1, 'lib/', null),
  (2, 'app.dart', 1),
  (2, 'env.dart', 5),
  (2, 'router.dart', 0),
  (2, 'shell/', null),
  (3, 'app_error_page.dart', 4),
  (3, 'app_shell.dart', 3),
  (2, 'core/', null),
  (3, 'theme/', null),
  (4, 'app_theme.dart', 11),
  (3, 'widgets/', null),
  (4, 'page_title.dart', 12),
  (2, 'modules/', null),
  (3, 'home/', null),
  (4, 'home_routes.dart', 8),
  (4, 'pages/', null),
  (5, 'home_page.dart', 2),
  (4, 'state/', null),
  (5, 'counter_view_model.dart', 10),
  (4, 'widgets/', null),
  (5, 'counter_card.dart', 9),
  (1, 'test/', null),
  (2, 'app_test.dart', 7),
  (2, 'modules/', null),
  (3, 'home/', null),
  (4, 'counter_view_model_test.dart', 13),
  (1, 'web/', null),
  (1, 'pubspec.yaml', null),
];

const _modularTree = <(int depth, String name, int? file)>[
  (0, 'lib/', null),
  (1, 'router.dart', _newCount),
  (1, 'shell/', null),
  (2, 'app_shell.dart', _newCount + 1),
  (1, 'core/', null),
  (2, 'api/', null),
  (3, 'api.dart', _newCount + 2),
  (2, 'session/', null),
  (3, 'session.dart', _newCount + 3),
  (2, 'auth/', null),
  (3, 'permissions.dart', _newCount + 4),
  (2, 'widgets/', null),
  (3, 'page_header.dart', _newCount + 5),
  (1, 'modules/', null),
  (2, 'sales/', null),
  (3, 'sales_routes.dart', _newCount + 6),
  (3, 'middleware/', null),
  (4, 'open_register.dart', _newCount + 7),
  (3, 'pages/', null),
  (4, 'sales_error_page.dart', _newCount + 15),
  (3, 'data/', null),
  (4, 'orders_repository.dart', _newCount + 8),
  (3, 'widgets/', null),
  (4, 'status_chip.dart', _newCount + 9),
  (3, 'orders/', null),
  (4, 'orders_routes.dart', _newCount + 10),
  (4, 'pages/', null),
  (5, 'orders_page.dart', _newCount + 11),
  (4, 'forms/', null),
  (5, 'order_form.dart', _newCount + 12),
  (4, 'widgets/', null),
  (5, 'orders_table.dart', _newCount + 13),
  (4, 'state/', null),
  (5, 'selection_view_model.dart', _newCount + 14),
  (3, 'customers/', null),
  (2, 'catalog/', null),
];

// region: demo-explorer
// A project by modules (or a new one), as an editor shows it: pick a file in
// the tree and see its code and what it's for.
class ExplorerViewModel extends ThorState {
  final file = state(_firstModular);

  int current() => file.value;
  int view() => file.value < _newCount ? 0 : 1;
  void open(int index) => file.value = index;
  void setView(String? index) => file.value = index == '1' ? _firstModular : 0;
}

final explorerDemo = ExplorerViewModel();

class _TreeRow extends StatelessWidget {
  const _TreeRow(this.depth, this.name, this.file, this.selected);

  final int depth;
  final String name;
  final int? file;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final file = this.file;
    final isFile = file != null;
    final on = file == selected;
    final label = Row(
      spacing: 8,
      children: [
        SizedBox(width: depth * 12.0),
        Icon(
          name.endsWith('/') ? _folder : _file,
          size: 14,
          color: on ? StudioAccentColors.accent : StudioContentColors.faint,
        ),
        Text(
          name,
          style: _mono.copyWith(
            fontSize: 12.5,
            color: on
                ? StudioAccentColors.accent
                : isFile
                ? StudioContentColors.ink
                : StudioContentColors.muted,
            fontWeight: on ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
    if (!isFile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: label,
      );
    }
    return TextButton(
      onPressed: explorerDemo.open.withArg(file),
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(
          on ? StudioAccentColors.accentTint : null,
        ),
        overlayColor: WidgetStatePropertyAll(
          on ? StudioAccentColors.accentTint : StudioSurfaceColors.hover,
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        ),
        minimumSize: const WidgetStatePropertyAll(Size.zero),
        alignment: Alignment.centerLeft,
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(StudioRadii.small)),
          ),
        ),
      ),
      child: label,
    );
  }
}

class _TreeView extends StatelessWidget {
  const _TreeView(this.selected);

  final int selected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 1,
    children: [
      for (final (depth, name, file)
          in selected < _newCount ? _newTree : _modularTree)
        _TreeRow(depth, name, file, selected),
    ],
  );
}

class _FileView extends StatelessWidget {
  const _FileView(this.index);

  final int index;

  @override
  Widget build(BuildContext context) {
    final f = _files[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Text(f.about(context.l10n), style: const TextStyle(fontSize: 14)),
        DocsCode(f.code, title: f.path),
      ],
    );
  }
}

class ExplorerView extends StatelessWidget {
  const ExplorerView({super.key});

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: const BoxDecoration(
      color: StudioSurfaceColors.panel,
      border: Border.fromBorderSide(BorderSide(color: StudioBorderColors.line)),
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: StudioSurfaceColors.raised,
            border: Border(bottom: BorderSide(color: StudioBorderColors.line)),
          ),
          child: Row(
            spacing: 12,
            children: [
              const Text('View', style: _sectionLabel),
              Watch(
                explorerDemo.view,
                count: 2,
                builder: (v) => DropdownButton<String>(
                  id: 'docs-structure-view',
                  semanticLabel: 'Project view',
                  value: '$v',
                  items: const [
                    DropdownMenuItem(value: '0', child: Text('New project')),
                    DropdownMenuItem(value: '1', child: Text('With modules')),
                  ],
                  onChanged: explorerDemo.setView,
                ),
              ),
            ],
          ),
        ),
        LayoutScope(
          child: Grid(
            layout: const GridLayout(areas: ['tree', 'code']).when(
              container: {
                640: const GridLayout(
                  columns: 5,
                  areas: ['tree tree code code code'],
                ),
              },
            ),
            children: [
              GridItem(
                placement: const GridPlacement(area: 'tree'),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: StudioSurfaceColors.raised,
                    border: Border(
                      right: BorderSide(color: StudioBorderColors.line),
                    ),
                  ),
                  child: Watch(
                    explorerDemo.current,
                    count: _files.length,
                    builder: _TreeView.new,
                  ),
                ),
              ),
              GridItem(
                placement: const GridPlacement(area: 'code'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Watch(
                    explorerDemo.current,
                    count: _files.length,
                    builder: _FileView.new,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// endregion
