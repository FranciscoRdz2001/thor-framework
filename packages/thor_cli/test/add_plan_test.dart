import 'package:test/test.dart';
import 'package:thor_cli/thor_cli.dart';

const _router = '''
import 'package:thor_ui/router.dart';
import 'modules/home/home_routes.dart';

final ThorRouter router = ThorRouter([
  Group(children: [homeModule]),
]);
''';

const _flatRouter = '''
import 'package:thor_ui/router.dart';

final ThorRouter router = ThorRouter([]);
''';

void main() {
  group('planAddPage', () {
    test('a flat app: the file, and the route in lib/router.dart', () {
      final files = {'lib/router.dart': _flatRouter};
      final plan = planAddPage('/about', read: files.get);
      expect(plan.created.keys, ['lib/pages/about_page.dart']);
      expect(plan.created.values.single, contains('class AboutPage'));
      expect(
        plan.changed['lib/router.dart'],
        allOf(
          contains("import 'pages/about_page.dart';"),
          contains(
            "final aboutRoute = ThorRoute('/about', const AboutPage());",
          ),
        ),
      );
      // Planning writes nothing.
      expect(files['lib/router.dart'], _flatRouter);
    });

    test('className names the class, its file and its route', () {
      final files = {'lib/router.dart': _flatRouter};
      final plan = planAddPage(
        '/about',
        read: files.get,
        className: 'AboutUsPage',
      );
      expect(plan.created.keys, ['lib/pages/about_us_page.dart']);
      expect(plan.created.values.single, contains('class AboutUsPage '));
      expect(plan.changed['lib/router.dart'], contains('final aboutUsRoute ='));
    });

    test('a bad class name or URL is a ThorException', () {
      expect(
        () => planAddPage('/a', read: (_) => null, className: 'lower'),
        throwsA(isA<ThorException>()),
      );
      expect(
        () => planAddPage('about', read: (_) => null),
        throwsA(isA<ThorException>()),
      );
    });

    test('a file that exists is refused', () {
      final files = {
        'lib/router.dart': _flatRouter,
        'lib/pages/about_page.dart': '// mine',
      };
      expect(
        () => planAddPage('/about', read: files.get),
        throwsA(isA<ThorException>()),
      );
    });

    test('an app in modules: a new module joins the table', () {
      final files = {
        'lib/router.dart': _router,
        'lib/modules/home/home_routes.dart':
            'final homeModule = Group(children: []);',
      };
      final plan = planAddPage('/sales/orders', read: files.get, modular: true);
      expect(
        plan.created.keys,
        unorderedEquals([
          'lib/modules/sales/pages/sales_orders_page.dart',
          'lib/modules/sales/sales_routes.dart',
        ]),
      );
      expect(
        plan.created['lib/modules/sales/sales_routes.dart'],
        contains('children: [salesOrdersRoute]'),
      );
      expect(
        plan.changed['lib/router.dart'],
        allOf(
          contains("import 'modules/sales/sales_routes.dart';"),
          contains('children: [homeModule, salesModule]'),
        ),
      );
    });

    test('a second page of a module joins its group', () {
      final files = {
        'lib/router.dart': _router,
        'lib/modules/sales/sales_routes.dart':
            'final salesModule = Group(children: [a]);\n',
      };
      final plan = planAddPage('/sales/items', read: files.get, modular: true);
      expect(plan.created.keys, [
        'lib/modules/sales/pages/sales_items_page.dart',
      ]);
      expect(plan.changed.keys, ['lib/modules/sales/sales_routes.dart']);
      expect(
        plan.changed.values.single,
        contains('children: [a, salesItemsRoute]'),
      );
    });

    test('a URL with no module name asks for one', () {
      expect(
        () => planAddPage('/2fa/setup', read: (_) => null, modular: true),
        throwsA(
          isA<ThorException>().having(
            (e) => e.message,
            'message',
            contains('--module'),
          ),
        ),
      );
      expect(
        planAddPage(
          '/2fa/setup',
          read: (_) => null,
          modular: true,
          module: 'security',
        ).created.keys,
        contains('lib/modules/security/pages/route2fa_setup_page.dart'),
      );
    });
  });

  group('planAddLayout', () {
    test('Shop becomes ShopLayout in lib/pages', () {
      final plan = planAddLayout('Shop', read: (_) => null);
      expect(plan.created.keys, ['lib/pages/shop_layout.dart']);
      expect(plan.created.values.single, contains('class ShopLayout '));
      expect(plan.changed, isEmpty);
      expect(
        plan.notes.single.message,
        contains('Group(layout: const ShopLayout()'),
      );
    });

    test('modules: shell/ or the module', () {
      expect(
        planAddLayout('Shop', read: (_) => null, modular: true).created.keys,
        ['lib/shell/shop_layout.dart'],
      );
      expect(
        planAddLayout(
          'Shop',
          read: (_) => null,
          modular: true,
          module: 'sales',
        ).created.keys,
        ['lib/modules/sales/shop_layout.dart'],
      );
    });

    test('a name that is not UpperCamelCase is refused', () {
      expect(
        () => planAddLayout('shop', read: (_) => null),
        throwsA(isA<ThorException>()),
      );
    });
  });
}

extension on Map<String, String> {
  String? get(String path) => this[path];
}
