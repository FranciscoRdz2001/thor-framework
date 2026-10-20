import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_cli/src/commands/build.dart'
    show copyPublicFiles, exportBaseUrlWarning;
import 'package:thor_cli/src/commands/preview.dart' show previewPort;
import 'package:thor_cli/src/run.dart' show needsBuildRunner;
import 'package:thor_cli/thor_cli.dart';

void main() {
  late Directory tmp;
  late String cwd;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('thor_cli');
    cwd = Directory.current.path;
  });
  tearDown(() {
    Directory.current = cwd;
    tmp.deleteSync(recursive: true);
  });

  group('freePortPair', () {
    test('a base near the top keeps the derived port valid', () async {
      // Was: the app port was base + 1000 = 65843 (Invalid port).
      final (port, app) = await freePortPair(64843, isFree: (_) async => true);
      expect(port, 64843);
      expect(app, inInclusiveRange(1024, 65535));
      expect(app, 63843);
    });

    test('skips a base whose partner is busy, and probes both', () async {
      final busy = {4301, 5300};
      final probed = <int>[];
      final (port, app) = await freePortPair(
        4300,
        isFree: (n) async {
          probed.add(n);
          return !busy.contains(n);
        },
      );
      // 4300 is free but 5300 is not: the next pair.
      expect((port, app), (4302, 5302));
      expect(probed, containsAll([4300, 5300, 4301, 4302, 5302]));
    });

    test('every derived port is valid across the whole range', () async {
      for (final base in [1024, 30000, 64535, 64536, 65000, 65535]) {
        final (port, app) = await freePortPair(base, isFree: (_) async => true);
        expect(port, inInclusiveRange(1, 65535), reason: '$base');
        expect(app, inInclusiveRange(1024, 65535), reason: '$base');
        expect(app, isNot(port));
      }
    });

    test('freePort never goes past 65535', () async {
      expect(
        () => freePort(65535, isFree: (_) async => false),
        throwsA(isA<ThorException>()),
      );
    });
  });

  group('--port', () {
    for (final command in ['preview', 'dev']) {
      for (final bad in ['abc', '', '70000', '-1', '4.5']) {
        test('`thor $command --port "$bad"` is a ThorException', () async {
          await expectLater(
            thorRunner().run([command, '--port=$bad']),
            throwsA(
              isA<ThorException>().having(
                (e) => e.message,
                'message',
                allOf(contains('--port'), contains('0 to 65535')),
              ),
            ),
          );
        });
      }
    }

    test('a valid port is accepted by the parser', () {
      expect(
        () => thorRunner().run(['preview', '--port=4400', '--help']),
        returnsNormally,
      );
    });
  });

  group('workspace list', () {
    const pubspec =
        'name: w\n\nworkspace:\n  - packages/a\n  - apps/one\n'
        '  - apps/two\n\ndev_dependencies:\n  lints: ^6.0.0\n';

    test('a new app goes after the last app, the rest untouched', () {
      final updated = addWorkspaceMember(pubspec, 'apps/three');
      expect(updated, contains('  - apps/two\n  - apps/three\n\ndev_'));
      expect(updated, endsWith('lints: ^6.0.0\n'));
    });

    test('a listed member changes nothing', () {
      expect(addWorkspaceMember(pubspec, 'apps/one'), pubspec);
    });

    test('a member of a new folder goes at the end of the list', () {
      expect(
        addWorkspaceMember(pubspec, 'tools/x'),
        contains('  - apps/two\n  - tools/x\n'),
      );
    });

    test('no workspace list is an error', () {
      expect(
        () => addWorkspaceMember('name: x\n', 'apps/a'),
        throwsFormatException,
      );
    });
  });

  group('templates', () {
    test('an app of the monorepo resolves with the workspace', () {
      final pubspec = appFiles('shop')['pubspec.yaml']!;
      expect(pubspec, contains('resolution: workspace'));
      expect(pubspec, contains('path: ../../packages/thor_ui'));
      expect(pubspec, isNot(contains('dependency_overrides')));
    });

    test('a project of its own takes the checkout, with no overrides', () {
      final pubspec = appFiles(
        'shop',
        source: const LocalSource('/opt/thor'),
      )['pubspec.yaml']!;
      expect(pubspec, isNot(contains('resolution:')));
      expect(pubspec, contains('path: /opt/thor/packages/thor_ui'));
      expect(pubspec, isNot(contains('dependency_overrides')));
    });

    test('or git, with the ref', () {
      final pubspec = appFiles(
        'shop',
        source: const GitSource('https://x/thor.git', ref: 'v0.1'),
      )['pubspec.yaml']!;
      expect(
        pubspec,
        contains(
          'thor_ui:\n    git:\n      url: https://x/thor.git\n'
          '      ref: v0.1\n      path: packages/thor_ui',
        ),
      );
      expect(pubspec, isNot(contains('dependency_overrides')));
    });

    test('the analysis options enable thor_lints from the same source', () {
      expect(
        appFiles('shop')['analysis_options.yaml'],
        contains('include: ../../analysis_options.yaml'),
      );
      expect(
        appFiles(
          'shop',
          source: const LocalSource('/opt/thor'),
        )['analysis_options.yaml'],
        contains(
          'plugins:\n  thor_lints:\n    path: /opt/thor/packages/thor_lints',
        ),
      );
      expect(
        appFiles(
          'shop',
          source: const GitSource('https://x/thor.git', ref: 'v0.1'),
        )['analysis_options.yaml'],
        contains(
          'thor_lints:\n    git:\n      url: https://x/thor.git\n'
          '      ref: v0.1\n      path: packages/thor_lints',
        ),
      );
    });

    test('the server serves the route table of lib/router.dart', () {
      final files = appFiles('shop');
      expect(files['bin/server.dart'], contains('routes: app.routes'));
      expect(files['lib/app.dart'], contains('ThorApp.router('));
      expect(files['lib/app.dart'], contains('routerConfig: router'));
      expect(files['lib/router.dart'], contains('children: [homeModule]'));
      expect(
        files['lib/modules/home/home_routes.dart'],
        contains("final homeRoute = ThorRoute('/', const HomePage());"),
      );
      expect(files.keys.where((k) => k.startsWith('lib/routes/')), isEmpty);
    });

    test('the reset and the theme live in lib/app.dart, used by both', () {
      final files = appFiles('shop');
      final app = files['lib/app.dart']!;
      expect(app, contains('styles: thorResetStyles'));
      expect(app, contains('theme: appTheme'));
      expect(app, contains('darkTheme: appDarkTheme'));
      expect(files['bin/server.dart'], contains('appRenderer('));
      expect(files['test/app_test.dart'], contains('appRenderer()'));
    });

    test('the environment is a checked schema; .env stays out of git', () {
      final files = appFiles('shop');
      expect(
        files['lib/env.dart'],
        contains('EnvSchema([port, secureCookies])'),
      );
      expect(files['bin/server.dart'], contains('env.of(AppEnv.port)'));
      expect(files['bin/server.dart'], isNot(contains('Platform.environment')));
      expect(files['.gitignore'], contains('\n.env\n'));
    });

    test(
      'the server sets secureCookies itself: Secure over HTTPS by default',
      () {
        final files = appFiles('shop');
        expect(
          files['bin/server.dart'],
          contains('secureCookies: env.of(AppEnv.secureCookies)'),
        );
        expect(
          files['lib/env.dart'],
          contains("EnvOptional(EnvBool('SECURE_COOKIES'))"),
        );
      },
    );

    test('a page with parameters loads them; one without is plain', () {
      final product = pageFile('/product/:id');
      expect(product, contains("request.param('id')"));
      expect(
        product,
        contains(
          'class ProductByIdPage extends ThorPage<ProductByIdPageData> {',
        ),
      );
      expect(pageFile('/item/:id:int'), contains("request.paramInt('id')"));
      expect(pageFile('/docs/*rest'), contains("request.param('rest')"));
      expect(
        pageFile('/about'),
        contains('class AboutPage extends ThorPage<void> {'),
      );
      expect(
        pageFile('/'),
        contains('class HomePage extends ThorPage<void> {'),
      );
      expect(
        layoutFile(),
        contains('class RootLayout extends ThorLayout<void>'),
      );
      expect(
        layoutFile(className: 'AccountLayout'),
        contains('class AccountLayout extends ThorLayout<void>'),
      );
      expect(routeVariable('ProductByIdPage'), 'productByIdRoute');
      // The trailing parameters name the page: it doesn't take the list's.
      expect(pageClassName('/orders'), 'OrdersPage');
      expect(pageClassName('/orders/:id:int'), 'OrdersByIdPage');
      expect(pageClassName('/api/:package/:topic'), 'ApiByPackageAndTopicPage');
      expect(
        middlewareFile('session'),
        contains('Future<ThorResponse> session('),
      );
      expect(
        stylesFile('article'),
        contains('final articleStyles = <StyleRule>['),
      );
    });

    test('a state is its class, part and instance', () {
      final cart = stateFile('Cart');
      expect(cart, isNot(contains('part ')));
      expect(cart, contains('class CartViewModel extends ThorState'));
      expect(cart, contains('final cart = CartViewModel();'));
      expect(snakeCase('ProductListViewModel'), 'product_list_view_model');
      // The old names are still accepted, as typed.
      expect(stateClassName('CartState'), 'CartState');
      expect(stateClassName('CartViewModel'), 'CartViewModel');
      expect(stateClassName('State'), 'StateViewModel');
      final old = stateFile('CartState');
      expect(old, contains('class CartState extends ThorState'));
      expect(old, contains('final cart = CartState();'));
      expect(
        stateFile('CartViewModel'),
        contains('final cart = CartViewModel();'),
      );
    });

    test('names: packages only, never a thor package', () {
      expect(isPackageName('mi_tienda'), isTrue);
      expect(isPackageName('MiTienda'), isFalse);
      expect(isPackageName('1app'), isFalse);
      expect(isPackageName('thor_ui'), isFalse);
    });
  });

  group('projects', () {
    test('found from any folder inside, wherever it lives', () {
      final app = Directory(p.join(tmp.path, 'site'))..createSync();
      File(p.join(app.path, 'pubspec.yaml')).writeAsStringSync(
        'name: site\ndependencies:\n  thor_ui:\n    path: /x\n',
      );
      final deep = Directory(p.join(app.path, 'lib', 'routes'))
        ..createSync(recursive: true);
      Directory.current = deep.path;
      final project = Project.find()!;
      expect(project.dir, app.resolveSymbolicLinksSync());
      expect(project.name, 'site');
      expect(project.isServer, isFalse);
      expect(project.pubRoot, project.dir);
    });

    test('a Dart package without thor_ui is not one', () {
      File(
        p.join(tmp.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: other\ndependencies:\n  http: ^1.0.0\n');
      expect(Project.isProject(tmp.path), isFalse);
    });

    test('create: outside the thor repository, a project of its own', () async {
      Directory.current = tmp.path;
      final plan = await planCreate('shop');
      expect(plan.workspace, isNull);
      expect(plan.source, isA<LocalSource>());
      expect(p.basename(plan.dir), 'shop');
      final written = writeApp(plan.dir, 'shop', source: plan.source);
      expect(written, contains(p.join('shop', 'bin', 'server.dart')));
      expect(Project.isProject(plan.dir), isTrue);
    });

    test('create --git needs no checkout', () async {
      Directory.current = tmp.path;
      final plan = await planCreate('shop', gitUrl: 'https://x/thor.git');
      expect(plan.source, isA<GitSource>());
    });

    test(
      'create: the scaffold analyzes clean, deprecations included',
      () async {
        // This checkout: packages/thor_cli/lib/thor_cli.dart, three up.
        final library = await Isolate.resolvePackageUri(
          Uri.parse('package:thor_cli/thor_cli.dart'),
        );
        final checkout = p.normalize(
          p.join(p.dirname(library!.toFilePath()), '..', '..', '..'),
        );
        final dir = p.join(tmp.path, 'shop');
        writeApp(dir, 'shop', source: LocalSource(checkout));
        // What `thor add` writes in an app in modules, too.
        for (final (path, source) in [
          ('modules/about/pages/about_page.dart', pageFile('/about')),
          (
            'modules/account/pages/product_by_id_page.dart',
            pageFile('/product/:id'),
          ),
          (
            'modules/account/account_layout.dart',
            layoutFile(className: 'AccountLayout'),
          ),
          (
            'modules/account/pages/account_not_found_page.dart',
            notFoundFile(
              app: 'shop',
              homeLibrary: 'modules/home/home_routes.dart',
              className: 'AccountNotFoundPage',
            ),
          ),
          (
            'modules/account/middleware/session.dart',
            middlewareFile('session'),
          ),
          ('modules/account/account_styles.dart', stylesFile('account')),
          (
            'modules/account/widgets/product_card.dart',
            componentFile('ProductCard'),
          ),
          (
            '../test/modules/account/widgets/product_card_test.dart',
            componentTestFile(
              'shop',
              'ProductCard',
              library: 'modules/account/widgets/product_card.dart',
            ),
          ),
          ('modules/account/state/cart_view_model.dart', stateFile('Cart')),
        ]) {
          File(p.normalize(p.join(dir, 'lib', path)))
            ..createSync(recursive: true)
            ..writeAsStringSync(source);
        }
        // The modules' groups and the table that puts them in place.
        File(
          p.join(dir, 'lib', 'modules', 'about', 'about_routes.dart'),
        ).writeAsStringSync('''
import 'package:thor_ui/router.dart';

import 'pages/about_page.dart';

/// `/about`.
final aboutRoute = ThorRoute('/about', const AboutPage());

/// The about module.
final aboutModule = Group(children: [aboutRoute]);
''');
        File(
          p.join(dir, 'lib', 'modules', 'account', 'account_routes.dart'),
        ).writeAsStringSync('''
import 'package:thor_ui/router.dart';

import 'account_layout.dart';
import 'account_styles.dart';
import 'middleware/session.dart';
import 'pages/account_not_found_page.dart';
import 'pages/product_by_id_page.dart';

/// `/product/:id`.
final productByIdRoute = ThorRoute('/product/:id', const ProductByIdPage());

/// The account module.
final accountModule = Group(
  layout: const AccountLayout(),
  middleware: [session],
  notFound: const AccountNotFoundPage(),
  styles: accountStyles,
  children: [productByIdRoute],
);
''');
        File(p.join(dir, 'lib', 'router.dart')).writeAsStringSync('''
import 'package:thor_ui/router.dart';

import 'modules/about/about_routes.dart';
import 'modules/account/account_routes.dart';
import 'modules/home/home_routes.dart';
import 'shell/app_error_page.dart';
import 'shell/app_shell.dart';

/// Every route.
final ThorRouter router = ThorRouter([
  Group(
    layout: const AppShell(),
    error: const AppErrorPage(),
    children: [homeModule, aboutModule, accountModule],
  ),
]);
''');
        final pub = await Process.run('dart', [
          'pub',
          'get',
          '--offline',
        ], workingDirectory: dir);
        expect(pub.exitCode, 0, reason: '${pub.stdout}${pub.stderr}');
        // What `thor create` does next: the app's code generation (its
        // states and browser entry), then the whole app.
        final codegen = await Process.run('dart', [
          'run',
          'build_runner',
          'build',
          '--delete-conflicting-outputs',
        ], workingDirectory: dir);
        expect(codegen.exitCode, 0, reason: '${codegen.stdout}');
        final analyze = await Process.run('dart', [
          'analyze',
          '--fatal-infos',
          '--fatal-warnings',
        ], workingDirectory: dir);
        expect(analyze.exitCode, 0, reason: '${analyze.stdout}');
        // Its own tests, the way the app runs them (`thor test` registers
        // its states first): the page, its counter and the 404.
        final test = await Process.run('dart', [
          'run',
          '--packages=${p.join(checkout, '.dart_tool', 'package_config.json')}',
          p.join(checkout, 'packages', 'thor_cli', 'bin', 'thor.dart'),
          'test',
        ], workingDirectory: dir);
        expect(test.exitCode, 0, reason: '${test.stdout}${test.stderr}');
      },
      timeout: const Timeout(Duration(minutes: 6)),
    );
  });

  test(
    'a closure that uses a state: the editor flags it, thor build fails',
    () async {
      final library = await Isolate.resolvePackageUri(
        Uri.parse('package:thor_cli/thor_cli.dart'),
      );
      final checkout = p.normalize(
        p.join(p.dirname(library!.toFilePath()), '..', '..', '..'),
      );
      final dir = p.join(tmp.path, 'shop');
      writeApp(dir, 'shop', source: LocalSource(checkout));
      final card = File(
        p.join(dir, 'lib', 'modules', 'home', 'widgets', 'counter_card.dart'),
      );
      card.writeAsStringSync(
        card.readAsStringSync().replaceFirst(
          'onPressed: counter.increment,',
          'onPressed: () {\n                  counter.increment();\n'
              '                },',
        ),
      );
      final pub = await Process.run('dart', [
        'pub',
        'get',
        '--offline',
      ], workingDirectory: dir);
      expect(pub.exitCode, 0, reason: '${pub.stdout}${pub.stderr}');
      // The plugin, loaded from the app's own analysis_options.yaml.
      final analyze = await Process.run('dart', [
        'analyze',
      ], workingDirectory: dir);
      expect(analyze.exitCode, isNot(0));
      expect(
        '${analyze.stdout}',
        allOf(
          contains('counter_card.dart:'),
          contains('THOR-S011'),
          contains('Pass `counter.increment`.'),
        ),
      );
      // The build stops at the code generation, with the file and line.
      final build = await Process.run('dart', [
        'run',
        '--packages=${p.join(checkout, '.dart_tool', 'package_config.json')}',
        p.join(checkout, 'packages', 'thor_cli', 'bin', 'thor.dart'),
        'build',
      ], workingDirectory: dir);
      expect(build.exitCode, isNot(0));
      expect(
        '${build.stdout}${build.stderr}',
        allOf(
          contains('lib/modules/home/widgets/counter_card.dart:'),
          contains('THOR-S011'),
        ),
      );
      expect(File(p.join(dir, 'build', 'server')).existsSync(), isFalse);
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );

  group('thor add in an app in modules', () {
    test('each file lands in its module, core/ or shell/, and a new '
        "module's group joins the table", () async {
      final library = await Isolate.resolvePackageUri(
        Uri.parse('package:thor_cli/thor_cli.dart'),
      );
      final checkout = p.normalize(
        p.join(p.dirname(library!.toFilePath()), '..', '..', '..'),
      );
      final dir = p.join(tmp.path, 'shop');
      writeApp(dir, 'shop', source: LocalSource(checkout));
      Future<void> add(List<String> args) async {
        final r = await Process.run('dart', [
          'run',
          '--packages=${p.join(checkout, '.dart_tool', 'package_config.json')}',
          p.join(checkout, 'packages', 'thor_cli', 'bin', 'thor.dart'),
          'add',
          ...args,
        ], workingDirectory: dir);
        expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      }

      await add(['page', '/about']);
      await add(['page', '/sales/orders']);
      await add(['page', '/sales/orders/:id:int']);
      await add(['error', '--module', 'sales']);
      await add(['component', 'EmptyState']);
      await add(['component', 'StatusChip', '--module', 'sales']);
      await add(['state', 'Selection', '--module', 'sales']);
      await add(['middleware', 'requireLogin', '--module', 'sales']);

      bool exists(String f) => File(p.join(dir, f)).existsSync();
      for (final f in [
        'lib/modules/about/pages/about_page.dart',
        'lib/modules/about/about_routes.dart',
        'lib/modules/sales/pages/sales_orders_page.dart',
        'lib/modules/sales/pages/sales_orders_by_id_page.dart',
        'lib/modules/sales/pages/sales_error_page.dart',
        'lib/core/widgets/empty_state.dart',
        'test/core/widgets/empty_state_test.dart',
        'lib/modules/sales/widgets/status_chip.dart',
        'lib/modules/sales/state/selection_view_model.dart',
        'lib/modules/sales/middleware/require_login.dart',
      ]) {
        expect(exists(f), isTrue, reason: f);
      }
      expect(exists('lib/pages'), isFalse);
      final router = File(p.join(dir, 'lib', 'router.dart')).readAsStringSync();
      expect(
        router,
        contains('children: [homeModule, aboutModule, salesModule]'),
      );
      expect(router, contains("import 'modules/sales/sales_routes.dart';"));
      final sales = File(
        p.join(dir, 'lib', 'modules', 'sales', 'sales_routes.dart'),
      ).readAsStringSync();
      expect(
        sales,
        contains('children: [salesOrdersRoute, salesOrdersByIdRoute]'),
      );
      expect(
        File(
          p.join(
            dir,
            'lib',
            'modules',
            'sales',
            'pages',
            'sales_error_page.dart',
          ),
        ).readAsStringSync(),
        contains('class SalesErrorPage extends ErrorPage'),
      );
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('a URL whose first segment is no identifier asks for --module, '
        'and writes nothing', () async {
      final library = await Isolate.resolvePackageUri(
        Uri.parse('package:thor_cli/thor_cli.dart'),
      );
      final checkout = p.normalize(
        p.join(p.dirname(library!.toFilePath()), '..', '..', '..'),
      );
      final dir = p.join(tmp.path, 'shop');
      writeApp(dir, 'shop', source: LocalSource(checkout));
      Future<ProcessResult> add(List<String> args) => Process.run('dart', [
        'run',
        '--packages=${p.join(checkout, '.dart_tool', 'package_config.json')}',
        p.join(checkout, 'packages', 'thor_cli', 'bin', 'thor.dart'),
        'add',
        ...args,
      ], workingDirectory: dir);

      final router = File(p.join(dir, 'lib', 'router.dart'));
      final before = router.readAsStringSync();
      final bad = await add(['page', '/2fa/setup']);
      expect(bad.exitCode, isNot(0));
      expect('${bad.stdout}${bad.stderr}', contains('--module'));
      expect(router.readAsStringSync(), before);
      expect(
        Directory(p.join(dir, 'lib', 'modules', '2fa')).existsSync(),
        isFalse,
      );
      // With a module said, the same URL works.
      final ok = await add(['page', '/2fa/setup', '--module', 'security']);
      expect(ok.exitCode, 0, reason: '${ok.stdout}${ok.stderr}');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('--module wires error, notFound, styles and middleware into the '
        "module's group; an error: already set stays", () async {
      final library = await Isolate.resolvePackageUri(
        Uri.parse('package:thor_cli/thor_cli.dart'),
      );
      final checkout = p.normalize(
        p.join(p.dirname(library!.toFilePath()), '..', '..', '..'),
      );
      final dir = p.join(tmp.path, 'shop');
      writeApp(dir, 'shop', source: LocalSource(checkout));
      Future<String> add(List<String> args) async {
        final r = await Process.run('dart', [
          'run',
          '--packages=${p.join(checkout, '.dart_tool', 'package_config.json')}',
          p.join(checkout, 'packages', 'thor_cli', 'bin', 'thor.dart'),
          'add',
          ...args,
        ], workingDirectory: dir);
        expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
        return '${r.stdout}${r.stderr}';
      }

      String read(String f) => File(p.join(dir, f)).readAsStringSync();

      await add(['page', '/sales/orders']);
      await add(['error', '--module', 'sales']);
      await add(['not_found', '--module', 'sales']);
      await add(['styles', 'sales', '--module', 'sales']);
      await add(['middleware', 'requireLogin', '--module', 'sales']);
      await add(['middleware', 'audit', '--module', 'sales']);
      final sales = read('lib/modules/sales/sales_routes.dart');
      for (final line in [
        "import 'middleware/audit.dart';",
        "import 'middleware/require_login.dart';",
        "import 'pages/sales_error_page.dart';",
        "import 'pages/sales_not_found_page.dart';",
        "import 'sales_styles.dart';",
        'error: const SalesErrorPage(),',
        'notFound: const SalesNotFoundPage(),',
        'styles: salesStyles,',
        'middleware: [requireLogin, audit],',
        'children: [salesOrdersRoute],',
      ]) {
        expect(sales, contains(line), reason: sales);
      }
      // `children:` stays last.
      expect(
        sales.indexOf('children:'),
        greaterThan(sales.indexOf('middleware:')),
      );

      // A module with no routes file yet: it gets one, in the table.
      await add(['error', '--module', 'reports']);
      expect(
        read('lib/modules/reports/reports_routes.dart'),
        allOf(
          contains("import 'pages/reports_error_page.dart';"),
          contains('error: const ReportsErrorPage()'),
        ),
      );
      expect(
        read('lib/router.dart'),
        allOf(
          contains("import 'modules/reports/reports_routes.dart';"),
          contains('reportsModule]'),
        ),
      );

      // An error page already set: left alone, with the line to change.
      File(p.join(dir, 'lib', 'modules', 'billing', 'billing_routes.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync('''
import 'package:thor_ui/router.dart';

import '../../shell/app_error_page.dart';

/// The billing module.
final billingModule = Group(
  error: const AppErrorPage(),
  children: [],
);
''');
      final before = read('lib/modules/billing/billing_routes.dart');
      final out = await add(['error', '--module', 'billing']);
      expect(read('lib/modules/billing/billing_routes.dart'), before);
      expect(
        out,
        allOf(
          contains('billingModule already has `error: const AppErrorPage()`'),
          contains('`error: const BillingErrorPage(),`'),
        ),
      );

      final pub = await Process.run('dart', [
        'pub',
        'get',
        '--offline',
      ], workingDirectory: dir);
      expect(pub.exitCode, 0, reason: '${pub.stdout}${pub.stderr}');
      final codegen = await Process.run('dart', [
        'run',
        'build_runner',
        'build',
        '--delete-conflicting-outputs',
      ], workingDirectory: dir);
      expect(codegen.exitCode, 0, reason: '${codegen.stdout}');
      final analyze = await Process.run('dart', [
        'analyze',
        '--fatal-infos',
        '--fatal-warnings',
      ], workingDirectory: dir);
      expect(analyze.exitCode, 0, reason: '${analyze.stdout}');
    }, timeout: const Timeout(Duration(minutes: 6)));
  });

  group('wireGroupArgument', () {
    test('goes before children:, on one line or many', () {
      final one = wireGroupArgument(
        'final salesModule = Group(children: [a]);',
        'salesModule',
        'error',
        'const E()',
      );
      expect(
        (one as GroupArgumentAdded).source,
        'final salesModule = Group(error: const E(), children: [a]);',
      );
      final many = wireGroupArgument(
        'final salesModule = Group(\n'
            '  layout: const L(),\n'
            "  children: [ThorRoute('/x', const P()), b],\n"
            ');',
        'salesModule',
        'styles',
        'salesStyles',
      );
      expect(
        (many as GroupArgumentAdded).source,
        'final salesModule = Group(\n'
        '  layout: const L(),\n'
        "  styles: salesStyles, children: [ThorRoute('/x', const P()), b],\n"
        ');',
      );
    });

    test('middleware appends to the list there, empty or not', () {
      String wire(String source) =>
          (wireGroupArgument(source, 'm', 'middleware', 'b')
                  as GroupArgumentAdded)
              .source;
      expect(
        wire('final m = Group(middleware: [a,\n], children: []);'),
        'final m = Group(middleware: [a, b], children: []);',
      );
      expect(
        wire('final m = Group(middleware: const [], children: []);'),
        'final m = Group(middleware: const [b], children: []);',
      );
      expect(
        wire('final m = Group(children: []);'),
        'final m = Group(middleware: [b], children: []);',
      );
    });

    test('an argument already set is not overwritten', () {
      final r = wireGroupArgument(
        'final m = Group(\n  notFound: const Old(), // keep\n  children: [],\n);',
        'm',
        'notFound',
        'const New()',
      );
      expect((r as GroupArgumentTaken).current, 'notFound: const Old()');
    });

    test('another group, or none: not found', () {
      expect(
        wireGroupArgument(
          'final other = Group(children: []);',
          'm',
          'error',
          'const E()',
        ),
        isA<GroupNotFound>(),
      );
      // Only the named group changes.
      final r = wireGroupArgument(
        'final a = Group(children: []);\nfinal m = Group(children: []);',
        'm',
        'error',
        'const E()',
      );
      expect(
        (r as GroupArgumentAdded).source,
        'final a = Group(children: []);\n'
        'final m = Group(error: const E(), children: []);',
      );
    });

    test('a group with no children: keeps its trailing comma', () {
      final r = wireGroupArgument(
        'final m = Group(\n  layout: const L(),\n);',
        'm',
        'error',
        'const E()',
      );
      expect(
        (r as GroupArgumentAdded).source,
        'final m = Group(\n  layout: const L(), error: const E(),);',
      );
    });
  });

  group('public files of packages', () {
    test('copied into web/ when missing or changed, else left alone', () {
      final pkg = Directory(p.join(tmp.path, 'studio', 'fonts'))
        ..createSync(recursive: true);
      File(
        p.join(pkg.parent.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: studio\nthor:\n  public:\n    fonts: fonts\n');
      File(p.join(pkg.path, 'a.woff2')).writeAsBytesSync([1, 2, 3]);
      final app = Directory(p.join(tmp.path, 'app'))..createSync();
      File(p.join(app.path, 'pubspec.yaml')).writeAsStringSync(
        'name: app\ndependencies:\n  thor_ui:\n    path: /x\n'
        '  studio:\n    path: ../studio\n',
      );
      Directory(p.join(app.path, '.dart_tool')).createSync();
      File(
        p.join(app.path, '.dart_tool', 'package_config.json'),
      ).writeAsStringSync(
        '{"configVersion":2,"packages":[{"name":"studio",'
        '"rootUri":"../../studio","packageUri":"lib/"}]}',
      );
      final assets = PublicAssets(Project(app.path));
      expect(assets.sync(), [p.join('web', 'fonts', 'a.woff2')]);
      expect(assets.sync(), isEmpty);
      File(p.join(pkg.path, 'a.woff2')).writeAsBytesSync([9, 9, 9]);
      expect(assets.sync(), hasLength(1));
      expect(
        File(p.join(app.path, 'web', 'fonts', 'a.woff2')).readAsBytesSync(),
        [9, 9, 9],
      );
    });
  });

  group('public files an app leaves out', () {
    Project appWith(String appPubspecExtra) {
      for (final folder in ['fonts', 'scripts']) {
        Directory(
          p.join(tmp.path, 'studio', folder),
        ).createSync(recursive: true);
        File(
          p.join(tmp.path, 'studio', folder, 'a.txt'),
        ).writeAsStringSync(folder);
      }
      File(p.join(tmp.path, 'studio', 'pubspec.yaml')).writeAsStringSync(
        'name: studio\nthor:\n  public:\n    fonts: fonts\n    scripts: scripts\n',
      );
      final app = Directory(p.join(tmp.path, 'app'))..createSync();
      File(p.join(app.path, 'pubspec.yaml')).writeAsStringSync(
        'name: app\ndependencies:\n  studio:\n    path: ../studio\n'
        '$appPubspecExtra',
      );
      Directory(p.join(app.path, '.dart_tool')).createSync();
      File(
        p.join(app.path, '.dart_tool', 'package_config.json'),
      ).writeAsStringSync(
        '{"configVersion":2,"packages":[{"name":"studio",'
        '"rootUri":"../../studio","packageUri":"lib/"}]}',
      );
      return Project(app.path);
    }

    test('without a setting every folder a package declares is copied', () {
      final assets = PublicAssets(appWith(''));
      expect(assets.declared().keys, unorderedEquals(['fonts', 'scripts']));
      expect(assets.sync(), hasLength(2));
    });

    test('thor: public: exclude skips those folders', () {
      final project = appWith('thor:\n  public:\n    exclude: [scripts]\n');
      final assets = PublicAssets(project);
      expect(assets.excluded(), {'scripts'});
      expect(assets.declared().keys, ['fonts']);
      expect(assets.sync(), [p.join('web', 'fonts', 'a.txt')]);
      expect(
        Directory(p.join(project.dir, 'web', 'scripts')).existsSync(),
        isFalse,
      );
    });

    test('exclude that is not a list is an error that says where', () {
      final assets = PublicAssets(
        appWith('thor:\n  public:\n    exclude: scripts\n'),
      );
      expect(assets.sync, throwsA(isA<FormatException>()));
    });
  });

  test(
    'every command that serves or renders an app publishes package files',
    () {
      // A command that forgets it serves the app without a design system's
      // fonts: a 404 that only shows in the page's console.
      for (final file in [
        'lib/src/commands/dev.dart',
        'lib/src/commands/build.dart',
        'lib/src/commands/doctor.dart',
        'lib/src/commands/test.dart',
        'lib/src/render/render.dart',
      ]) {
        expect(
          File(file).readAsStringSync(),
          contains('PublicAssets('),
          reason: file,
        );
      }
    },
  );

  test('export warns when there is no --base-url', () {
    final warning = exportBaseUrlWarning(null)!;
    expect(warning, contains('--base-url'));
    expect(warning, contains('http://localhost'));
    expect(warning, contains('sitemap.xml'));
    expect(exportBaseUrlWarning(' '), isNotNull);
    expect(exportBaseUrlWarning('https://example.com'), isNull);
  });

  group('preview', () {
    test(
      '--port is the port served, or an error; the default searches',
      () async {
        Future<bool> busy4400(int port) async => port != 4400;
        expect(
          await previewPort(4400, explicit: false, isFree: busy4400),
          4401,
        );
        expect(
          await previewPort(4650, explicit: true, isFree: (_) async => true),
          4650,
        );
        await expectLater(
          previewPort(4400, explicit: true, isFree: busy4400),
          throwsA(
            isA<ThorException>().having(
              (e) => e.message,
              'message',
              allOf(contains('4400'), contains('in use')),
            ),
          ),
        );
      },
    );

    test('clean URLs like a static host, and never outside the site', () {
      final site = Directory(p.join(tmp.path, 'site'))..createSync();
      File(p.join(site.path, 'index.html')).writeAsStringSync('home');
      File(p.join(site.path, 'about.html')).writeAsStringSync('about');
      Directory(p.join(site.path, 'docs')).createSync();
      File(p.join(site.path, 'docs', 'index.html')).writeAsStringSync('docs');
      File(p.join(tmp.path, 'secret.txt')).writeAsStringSync('x');
      String? read(String path) =>
          resolveStatic(site.path, path)?.readAsStringSync();
      expect(read('/'), 'home');
      expect(read('/about'), 'about');
      expect(read('/about.html'), 'about');
      expect(read('/docs'), 'docs');
      expect(read('/nope'), isNull);
      expect(read('/../secret.txt'), isNull);
    });
  });

  test('thor preview answers 400 to a path with invalid UTF-8', () async {
    final site = Directory(p.join(tmp.path, 'site'))..createSync();
    File(p.join(site.path, 'index.html')).writeAsStringSync('home');
    final server = await serveStatic(site.path, 0);
    addTearDown(() => server.close(force: true));
    // A raw socket: HttpClient would refuse to send the bad path.
    Future<int> status(String path) async {
      final socket = await Socket.connect('127.0.0.1', server.port);
      socket.write(
        'GET $path HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n',
      );
      final reply = await utf8.decoder.bind(socket).join();
      return int.parse(reply.split(' ')[1]);
    }

    expect(await status('/%C3'), 400);
    expect(await status('/%FF'), 400);
    expect(await status('/'), 200); // still alive
  });

  test('release copies web/ without sources, the dev engine or .gitkeep', () {
    final app = Directory(p.join(tmp.path, 'copy'))..createSync();
    void put(String f) => File(p.join(app.path, 'web', f))
      ..createSync(recursive: true)
      ..writeAsStringSync('x');
    for (final f in [
      'favicon.ico',
      'img/a.png',
      'main.dart',
      'engine.dart.js',
      'engine.dart.js.map',
      'img/.gitkeep',
    ]) {
      put(f);
    }
    final out = p.join(app.path, 'out');
    copyPublicFiles(Project(app.path), out);
    final copied = [
      for (final f in Directory(
        out,
      ).listSync(recursive: true).whereType<File>())
        p.relative(f.path, from: out),
    ]..sort();
    expect(copied, ['favicon.ico', p.join('img', 'a.png')]);
  });

  test('SDK versions compare by number, not text', () {
    expect(olderThan('3.7.9', '3.8.0'), isTrue);
    expect(olderThan('3.10.0', '3.8.0'), isFalse);
    expect(olderThan('3.8.0-1.0.dev', '3.8.0'), isFalse);
  });

  test('a static app without its page entry fails before building', () async {
    final app = Directory(p.join(tmp.path, 'site'))..createSync();
    File(p.join(app.path, 'pubspec.yaml')).writeAsStringSync(
      'name: site\ndependencies:\n  thor_ui:\n    path: /x\n',
    );
    await expectLater(
      buildStatic(Project(app.path)),
      throwsA(
        isA<ThorException>().having(
          (e) => e.message,
          'message',
          contains('lib/main.server.dart'),
        ),
      ),
    );
    expect(Directory(p.join(app.path, 'build')).existsSync(), isFalse);
  });

  group('needsBuildRunner', () {
    late Directory app;
    void write(String name, String code) {
      File(p.join(app.path, 'lib', name))
        ..createSync(recursive: true)
        ..writeAsStringSync(code);
    }

    setUp(() => app = Directory(p.join(tmp.path, 'app'))..createSync());

    test('a new app skips it', () {
      write('main.dart', "import 'package:thor_ui/thor_ui.dart';\n");
      expect(needsBuildRunner(app.path), isFalse);
    });

    test('messages and old-form states need it', () {
      write('x_state.dart', "part 'x_state.thor.dart';\n");
      expect(needsBuildRunner(app.path), isTrue);
    });

    test('a part another builder generates needs it (json_serializable, '
        'freezed)', () {
      write('product.dart', "part 'product.g.dart';\n");
      expect(needsBuildRunner(app.path), isTrue);
      File(p.join(app.path, 'lib', 'product.dart')).deleteSync();
      write('order.dart', 'part "order.freezed.dart";\n');
      expect(needsBuildRunner(app.path), isTrue);
    });

    test('a hand-written part does not', () {
      write('big.dart', "part 'big_helpers.dart';\n");
      expect(needsBuildRunner(app.path), isFalse);
    });
  });

  group('staticLocales', () {
    late Directory app;
    void arb(String name, String json) {
      final l10n = Directory(p.join(app.path, 'lib', 'l10n'))
        ..createSync(recursive: true);
      File(p.join(l10n.path, name)).writeAsStringSync(json);
    }

    setUp(() => app = Directory(p.join(tmp.path, 'site'))..createSync());

    test('none without lib/l10n; one ARB is one locale', () {
      expect(staticLocales(Project(app.path)), isEmpty);
      arb('app_en.arb', '{"a": "x"}');
      expect(staticLocales(Project(app.path)), ['en']);
    });

    test('the template first, tags with hyphens, @@locale wins', () {
      arb('app_en.arb', '{"a": "x"}');
      arb('app_ar.arb', '{"a": "x"}');
      arb('app_pt_BR.arb', '{"a": "x"}');
      arb('messages.arb', '{"@@locale": "es", "a": "x"}');
      expect(staticLocales(Project(app.path)), ['en', 'ar', 'es', 'pt-BR']);
    });

    test('the template of build.yaml', () {
      arb('app_en.arb', '{"a": "x"}');
      arb('app_es.arb', '{"a": "x"}');
      File(p.join(app.path, 'build.yaml')).writeAsStringSync('''
targets:
  \$default:
    builders:
      thor_builder:thor_l10n:
        options:
          template_arb_file: app_es.arb
''');
      expect(staticLocales(Project(app.path)), ['es', 'en']);
    });

    test('a broken ARB or a file without a locale fails the build', () {
      arb('app_en.arb', '{not json');
      expect(
        () => staticLocales(Project(app.path)),
        throwsA(isA<ThorException>()),
      );
      File(p.join(app.path, 'lib', 'l10n', 'app_en.arb')).deleteSync();
      arb('strings.arb', '{"a": "x"}');
      expect(
        () => staticLocales(Project(app.path)),
        throwsA(
          isA<ThorException>().having(
            (e) => e.message,
            'message',
            contains('no locale'),
          ),
        ),
      );
    });
  });

  test('a static app runs its page, a server app its server', () {
    final app = Directory(p.join(tmp.path, 'site'))..createSync();
    expect(Project(app.path).entry, 'lib/main.server.dart');
    Directory(p.join(app.path, 'bin')).createSync();
    File(p.join(app.path, 'bin', 'server.dart')).writeAsStringSync('');
    expect(Project(app.path).entry, 'bin/server.dart');
  });

  group('shared stylesheet', () {
    Project app(String yaml) {
      final dir = Directory(p.join(tmp.path, 'share'))..createSync();
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync(
        'name: share\ndependencies:\n  thor_ui:\n    path: /x\n$yaml',
      );
      return Project(dir.path);
    }

    test('off without thor.share_styles, or with a thor: of other keys', () {
      expect(app('').shareStyles, isFalse);
      expect(app('thor:\n  flutter:\n    project: w\n').shareStyles, isFalse);
      expect(app('thor:\n  share_styles: false\n').shareStyles, isFalse);
    });

    test('on when the pubspec says so', () {
      expect(app('thor:\n  share_styles: true\n').shareStyles, isTrue);
    });

    for (final value in ['yes', '1', '"true"', '[true]']) {
      test('$value is an error, not a guess', () {
        expect(
          () => app('thor:\n  share_styles: $value\n').shareStyles,
          throwsA(isA<ThorException>()),
        );
      });
    }
  });

  group('release engine', () {
    Project app(String yaml) {
      final dir = Directory(p.join(tmp.path, 'engine'))..createSync();
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync(
        'name: engine\ndependencies:\n  thor_ui:\n    path: /x\n$yaml',
      );
      return Project(dir.path);
    }

    test('lite, whatever the pubspec says', () {
      expect(app('').engine, EngineKind.lite);
      expect(app('thor:\n  share_styles: true\n').engine, EngineKind.lite);
      expect(app('thor:\n  engine: dart\n').engine, EngineKind.lite);
    });

    test('only the internal variable selects the dart2js oracle', () {
      expect(internalEngine({}), EngineKind.lite);
      expect(internalEngine({internalEngineVariable: 'lite'}), EngineKind.lite);
      expect(internalEngine({internalEngineVariable: 'wasm'}), EngineKind.lite);
      expect(internalEngine({internalEngineVariable: 'dart'}), EngineKind.dart);
    });

    test('no command offers --engine', () {
      for (final command in ['build', 'dev', 'export']) {
        final parser = thorRunner().commands[command]!.argParser;
        expect(parser.options.containsKey('engine'), isFalse, reason: command);
      }
    });
  });

  group('flutter embed', () {
    Project app(String thor) {
      final dir = Directory(p.join(tmp.path, 'app'))..createSync();
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync(
        'name: app\ndependencies:\n  thor_ui:\n    path: /x\n$thor',
      );
      return Project(dir.path);
    }

    void flutterProject(String dir) =>
        (Directory(dir)..createSync(recursive: true)).path;

    test('no thor.flutter: nothing to build', () {
      expect(FlutterEmbed.of(app('')), isNull);
    });

    test('the declaration, with its defaults', () {
      final embed = FlutterEmbed.of(
        app('thor:\n  flutter:\n    project: widgets\n'),
      )!;
      expect(embed.project, p.join(tmp.path, 'app', 'widgets'));
      expect(embed.public, 'flutter');
      expect(embed.publicDir, p.join(tmp.path, 'app', 'web', 'flutter'));
      expect(embed.cdn, isFalse);
    });

    for (final (label, yaml) in [
      ('no project', 'thor:\n  flutter:\n    public: x\n'),
      ('a scalar', 'thor:\n  flutter: widgets\n'),
      (
        'public outside web/',
        'thor:\n  flutter:\n    project: w\n    public: ../x\n',
      ),
      (
        'public absolute',
        'thor:\n  flutter:\n    project: w\n    public: /x\n',
      ),
    ]) {
      test('$label is an error', () {
        expect(() => FlutterEmbed.of(app(yaml)), throwsA(isA<ThorException>()));
      });
    }

    test('writes thor\'s bootstrap when the project has none', () {
      final embed = FlutterEmbed.of(
        app('thor:\n  flutter:\n    project: widgets\n'),
      )!;
      flutterProject(embed.project);
      File(p.join(embed.project, 'pubspec.yaml')).writeAsStringSync('name: w');
      embed.ensureBootstrap();
      final file = File(p.join(embed.project, 'web', 'flutter_bootstrap.js'));
      expect(file.readAsStringSync(), flutterBootstrapTemplate);
      // Twice: unchanged, no error.
      embed.ensureBootstrap();
      expect(file.readAsStringSync(), flutterBootstrapTemplate);
    });

    test('a bootstrap of its own is never overwritten (error)', () {
      final embed = FlutterEmbed.of(
        app('thor:\n  flutter:\n    project: widgets\n'),
      )!;
      flutterProject(p.join(embed.project, 'web'));
      File(p.join(embed.project, 'pubspec.yaml')).writeAsStringSync('name: w');
      final own = File(p.join(embed.project, 'web', 'flutter_bootstrap.js'))
        ..writeAsStringSync('{{flutter_js}}\n_flutter.loader.load();\n');
      expect(embed.ensureBootstrap, throwsA(isA<ThorException>()));
      expect(own.readAsStringSync(), contains('_flutter.loader.load();'));
    });

    test('a missing Flutter project is an error', () {
      final embed = FlutterEmbed.of(
        app('thor:\n  flutter:\n    project: nowhere\n'),
      )!;
      expect(embed.ensureBootstrap, throwsA(isA<ThorException>()));
    });

    test('publish keeps what the page loads and replaces the old build', () {
      final embed = FlutterEmbed.of(
        app('thor:\n  flutter:\n    project: widgets\n'),
      )!;
      final out = p.join(tmp.path, 'out');
      for (final f in [
        'flutter_bootstrap.js',
        'main.dart.js',
        'canvaskit/canvaskit.wasm',
        'canvaskit/canvaskit.js.symbols',
        'assets/FontManifest.json',
        'index.html',
        'flutter_service_worker.js',
        'version.json',
        '.last_build_id',
      ]) {
        File(p.join(out, f))
          ..createSync(recursive: true)
          ..writeAsStringSync(f);
      }
      final stale = File(p.join(embed.publicDir, 'old.js'))
        ..createSync(recursive: true);
      embed.publish(out);
      final published = [
        for (final f in Directory(embed.publicDir).listSync(recursive: true))
          if (f is File) p.relative(f.path, from: embed.publicDir),
      ]..sort();
      expect(published, [
        'assets/FontManifest.json',
        'canvaskit/canvaskit.wasm',
        'flutter_bootstrap.js',
        'main.dart.js',
      ]);
      expect(stale.existsSync(), isFalse);
    });

    test('the Flutter SDK: FLUTTER_ROOT first, then PATH, else none', () {
      final exe = Platform.isWindows ? 'flutter.bat' : 'flutter';
      final root = p.join(tmp.path, 'sdk');
      final onPath = p.join(tmp.path, 'bin');
      File(p.join(root, 'bin', exe)).createSync(recursive: true);
      File(p.join(onPath, exe)).createSync(recursive: true);
      final sep = Platform.isWindows ? ';' : ':';
      expect(
        FlutterEmbed.flutterExecutable(
          environment: {'FLUTTER_ROOT': root, 'PATH': onPath},
        ),
        p.join(root, 'bin', exe),
      );
      expect(
        FlutterEmbed.flutterExecutable(
          environment: {
            'FLUTTER_ROOT': p.join(tmp.path, 'x'),
            'PATH': '$sep$onPath',
          },
        ),
        p.join(onPath, exe),
      );
      expect(FlutterEmbed.flutterExecutable(environment: {'PATH': ''}), isNull);
    });

    test('the example app ships the same bootstrap thor writes', () {
      final example = File(
        p.join(
          '..',
          '..',
          'test',
          'fixtures',
          'apps',
          'hybrid',
          'flutter_widgets',
          'web',
          'flutter_bootstrap.js',
        ),
      );
      expect(example.readAsStringSync(), flutterBootstrapTemplate);
    });
  });
}
