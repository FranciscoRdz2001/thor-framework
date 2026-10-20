// These tests are about the button's wiring, not its name.
// ignore_for_file: thor_lints/icon_button_without_name
@TestOn('vm')
library;

// `Watch.list` gives each row a key typed by `itemKey`'s return type
// (`row.key` is an `int` for `int idOf(Order o)`), so `withArg(row.key)` and
// `bind(row.key)` type-check; the row template still carries the key token
// the browser fills.
import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart' show templateIntKey;
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class Order {
  const Order(this.id, this.customer, [this.slug = '']);
  final int id;
  final String customer;
  final String slug;
}

abstract class _OrdersMembers extends ThorState {
  @override
  String get $type => 'OrdersState';

  @override
  List<ThorMember> get $members {
    final s = this as OrdersState;
    return [
      ThorMember.state('rows', s.rows),
      ThorMember(
        'idOf',
        s.idOf,
        arity: 1,
        callWithItem: (i) => s.idOf(i as Order),
      ),
      ThorMember(
        'slugOf',
        s.slugOf,
        arity: 1,
        callWithItem: (i) => s.slugOf(i as Order),
      ),
      ThorMember(
        'flagOf',
        s.flagOf,
        arity: 1,
        callWithItem: (i) => s.flagOf(i as Order),
      ),
      ThorMember(
        'customerOf',
        s.customerOf,
        arity: 1,
        callWithItem: (i) => s.customerOf(i as Order),
      ),
      ThorMember(
        'remove',
        s.remove,
        arity: 1,
        call: (a) => s.remove(int.parse(a!)),
      ),
      ThorMember('open', s.open, arity: 1, call: (a) => s.open(a!)),
    ];
  }
}

class OrdersState extends _OrdersMembers {
  final rows = state<List<Order>>(const [
    Order(3, 'Ana', 'a~1'),
    Order(4, 'Luis', 'l-2'),
  ]);

  int idOf(Order o) => o.id;
  String slugOf(Order o) => o.slug;
  bool flagOf(Order o) => o.id == 3;
  String customerOf(Order o) => o.customer;
  void remove(int id) {}
  void open(String slug) {}
}

final orders = OrdersState();

class OrdersPage extends ThorPage<void> {
  const OrdersPage();

  Future<ActionResult?> archive(PageRequest request, int id) async => null;

  @override
  Widget build(BuildContext context, PageState<void> state) => Watch.list(
    orders.rows.call,
    itemKey: orders.idOf,
    each: (row) => Row(
      children: [
        row.text(orders.customerOf),
        // `row.key` is an int here: this would not compile as a String.
        IconButton(
          onPressed: orders.remove.withArg(row.key),
          icon: const Icon(IconData.svg('x', '<path d="M0 0"/>')),
        ),
        FilledButton(onPost: archive.withArg(row.key), child: const Text('a')),
      ],
    ),
  );
}

void registerActions() => registerPageActions({
  OrdersPage: [
    PageActionMethod.args(
      'archive',
      (p) => (p as OrdersPage).archive,
      1,
      (x) => [int.parse(x[0])],
    ),
  ],
});

void main() {
  initializeThorTests();
  registerActions();
  final app = ThorApp.router(
    routerConfig: ThorRouter([ThorRoute('/orders', const OrdersPage())]),
  );
  final handler = RouteHandler<Widget>(
    routes: app.routes,
    renderer: WidgetRenderer.router(app),
  );

  Future<String> get() async => (await handler.handle(
    PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://s.test/orders'),
      headers: const {HttpHeader.host: 's.test'},
    ),
  )).text;

  test('an int key: rows carry it, the template carries the token', () async {
    final html = await get();
    final template = html.substring(html.indexOf('<template'));
    final rows = html.substring(0, html.indexOf('<template'));
    expect(rows, contains('data-tk="3"'));
    expect(rows, contains('data-tx="3"'));
    expect(rows, contains('data-tx="4"'));
    expect(rows, contains('value="3"'));
    expect(template, contains('data-tx="{{key}}"'));
    expect(template, contains('value="{{key}}"'));
    expect(template, isNot(contains('$templateIntKey')));
  });

  test('a String key still works, and the legacy Watch keeps String', () async {
    final html = await renderHtml(
      Watch.list(
        orders.rows.call,
        itemKey: orders.slugOf,
        each: (row) => TextButton(
          onPressed: orders.open.withArg(row.key),
          child: Text(row.key.toUpperCase()),
        ),
      ),
    );
    expect(html, contains('data-tx="a~1"'));
    expect(html, contains('data-tx="{{key}}"'));
  });

  test('lazyLayout and itemExtent: CSS on the rows and the template', () async {
    Future<String> list({double? itemExtent, bool lazyLayout = false}) =>
        renderHtml(
          Watch.list(
            orders.rows.call,
            itemKey: orders.idOf,
            itemExtent: itemExtent,
            lazyLayout: lazyLayout,
            each: (row) => Text(row.key.toString()),
          ),
        );
    // Off by default: Chrome drops skipped rows from the accessibility tree.
    expect(await list(), isNot(contains('content-visibility')));
    final lazy = await list(lazyLayout: true, itemExtent: 34);
    expect(lazy, contains('content-visibility: auto'));
    expect(lazy, contains('contain-intrinsic-size: auto 34px'));
    expect(lazy, contains('height: 34px'));
    // Rows and template share the class, so the rows the browser adds get it.
    // Both rows and the template (the rows the browser adds) carry it.
    expect('content-visibility: auto'.allMatches(lazy), hasLength(3));
    expect(
      'content-visibility: auto'.allMatches(
        lazy.substring(lazy.indexOf('<template')),
      ),
      hasLength(1),
    );
    // An itemExtent alone fixes the height and nothing else.
    final fixed = await list(itemExtent: 34);
    expect(fixed, contains('height: 34px'));
    expect(fixed, isNot(contains('content-visibility')));
  });

  test(
    'virtual: the container says the extent; no extent is THOR-S040',
    () async {
      final html = await renderHtml(
        Watch.list(
          orders.rows.call,
          itemKey: orders.idOf,
          itemExtent: 34,
          virtual: true,
          each: (row) => Text(row.key.toString()),
        ),
      );
      expect(html, contains('data-tlv="34"'));
      expect(html, contains('height: 34px'));
      expect(
        await renderHtml(
          Watch.list(
            orders.rows.call,
            itemKey: orders.idOf,
            each: (row) => Text(row.key.toString()),
          ),
        ),
        isNot(contains('data-tlv')),
      );
      expect(
        () => Watch.list(
          orders.rows.call,
          itemKey: orders.idOf,
          virtual: true,
          each: (row) => const Text('x'),
        ),
        throwsA(
          isA<Object>().having((e) => '$e', 'message', contains('THOR-S040')),
        ),
      );
    },
  );

  test('a key that is not a String or an int says how to fix it', () async {
    expect(
      () => renderHtml(
        Watch.list(
          orders.rows.call,
          itemKey: orders.flagOf,
          each: (row) => const Text('x'),
        ),
      ),
      throwsA(
        isA<Object>()
            .having((e) => '$e', 'message', contains('THOR-S030'))
            .having((e) => '$e', 'message', contains('String')),
      ),
    );
  });

  test('a real key equal to the template placeholder is refused', () async {
    final saved = orders.rows.value;
    orders.rows.value = [const Order(templateIntKey, 'x')];
    addTearDown(() => orders.rows.value = saved);
    expect(
      () => renderHtml(
        Watch.list(
          orders.rows.call,
          itemKey: orders.idOf,
          each: (row) => row.text(orders.customerOf),
        ),
      ),
      throwsA(
        isA<Object>().having((e) => '$e', 'message', contains('THOR-S030')),
      ),
    );
  });
}
