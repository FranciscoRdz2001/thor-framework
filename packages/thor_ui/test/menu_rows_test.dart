// These tests are about the button's wiring, not its name.
// ignore_for_file: thor_lints/icon_button_without_name
@TestOn('vm')
library;

// A MenuAnchor in a `Watch.list` row: the panel id keeps the row key, so the
// rows the browser adds don't share one panel.
import 'package:test/test.dart';
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

void main() {
  setUpAll(initializeThorTests);

  test(
    'a ValueKey(row.key) panel id keeps the key placeholder in the template',
    () async {
      final html = await renderHtml(
        Watch.list(
          orders.rows.call,
          itemKey: orders.idOf,
          each: (row) => MenuAnchor(
            key: ValueKey(row.key),
            builder: (c, ctl, ch) =>
                TextButton(onPressed: null, child: row.text(orders.customerOf)),
            menuChildren: [
              MenuItemButton(
                onPressed: orders.remove.withArg(row.key),
                child: const Text('Del'),
              ),
            ],
          ),
        ),
      );
      final rows = html.substring(0, html.indexOf('<template'));
      final template = html.substring(html.indexOf('<template'));
      expect(rows, contains('id="menu-3"'));
      expect(rows, contains('id="menu-4"'));
      // The browser fills the token in id, popovertarget and the anchor name,
      // so a row it adds is not a copy of the same panel.
      expect(template, contains('id="menu-{{key}}"'));
      expect(template, contains('popovertarget="menu-{{key}}"'));
      // CSS can't carry the token (it is escaped), so a template panel
      // anchors to its invoker; the rows the server drew keep a named one.
      expect(template, isNot(contains('anchor-name')));
      expect(template, isNot(contains('position-anchor')));
      expect(template, isNot(contains('7b')));
      expect(rows, contains('anchor-name: --menu-3'));
      expect(rows, contains('position-anchor: --menu-3'));
    },
  );
}
