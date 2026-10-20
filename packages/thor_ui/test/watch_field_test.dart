@TestOn('vm')
library;

// `Watch` on a `state(...)` field, with and without `builder:`. Dart has
// no overloading and infers `Object?` for a field passed where a
// `T Function()` is expected, so a builder gets its type from
// `Watch.field`; the plain `Watch(field)` and every `Watch(method)` stay.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

enum Mood { calm, busy }

abstract class _Members extends ThorState {
  @override
  String get $type => 'Orders';

  @override
  List<ThorMember> get $members {
    final s = this as Orders;
    return [
      ThorMember.state('toast', s.toast, variants: const [false, true]),
      ThorMember.state('mood', s.mood, variants: Mood.values),
      ThorMember.state('step', s.step),
      ThorMember.state('name', s.name),
      ThorMember.state('maybe', s.maybe),
      ThorMember.state('maybeMood', s.maybeMood),
      ThorMember('label', s.label, call: (_) => s.label()),
      ThorMember(
        'lineName',
        s.lineName,
        callWithItem: (i) => s.lineName(i as String),
      ),
    ];
  }
}

class Orders extends _Members {
  final toast = state(false);
  final mood = state(Mood.calm);
  final step = state(1);
  final name = state('Ana');
  final maybe = state<bool?>(null);
  final maybeMood = state<Mood?>(null);
  final lines = state(const <String>['a', 'b']);
  String label() => 'L${step.value}';
  String lineName(String line) => line.toUpperCase();
}

abstract class _OtherMembers extends ThorState {
  @override
  String get $type => 'Cart';

  @override
  List<ThorMember> get $members {
    final s = this as Cart;
    return [
      ThorMember.state('open', s.open, variants: const [false, true]),
      ThorMember.state('lines', s.lines),
      ThorMember(
        'lineKey',
        s.lineKey,
        callWithItem: (i) => s.lineKey(i as String),
      ),
      ThorMember(
        'lineName',
        s.lineName,
        callWithItem: (i) => s.lineName(i as String),
      ),
    ];
  }
}

// A second state that reads the first one's field (`uses` another state).
class Cart extends _OtherMembers {
  final open = state(false);
  final lines = state(const <String>['a', 'b']);
  final Orders orders = orders_;
  String lineKey(String line) => line;
  String lineName(String line) => line;
}

final orders_ = Orders();
final cart = Cart();
// A field that is not in any ThorState: the browser can't find it.
final orphan = state(false);

Future<String> failure(Widget w) async {
  try {
    await renderHtml(w);
  } on ArgumentError catch (e) {
    return '${e.message}';
  }
  fail('expected an ArgumentError');
}

void main() {
  initializeThorTests();

  test('the dx_probe case: a bool field, its builder typed bool, with no '
      'annotation and no .call', () async {
    final html = await renderHtml(
      Watch.field(
        orders_.toast,
        builder: (visible) {
          // The parameter is a `bool`, not `Object?`.
          final bool shown = visible;
          return SnackBar(visible: shown, content: const Text('Saved'));
        },
      ),
    );
    expect(html, contains('data-tv="Orders.toast"'));
    expect(html, contains('Saved'));
  });

  test('it is the same markup as the .call form', () async {
    Widget builder(bool v) => Text(v ? 'yes' : 'no');
    expect(
      await renderHtml(Watch.field(orders_.toast, builder: builder)),
      await renderHtml(Watch(orders_.toast.call, builder: builder)),
    );
  });

  test('the plain Watch(field, builder: (bool v) => …) works annotated, and '
      'a method is unchanged', () async {
    final field = await renderHtml(
      // The annotation gives T = bool, so the field compiles as is (the
      // lint lets a typed builder through).
      Watch(orders_.toast, builder: (bool v) => Text(v ? 'yes' : 'no')),
    );
    expect(field, contains('data-tv="Orders.toast"'));
    final method = await renderHtml(Watch(orders_.label));
    expect(method, contains('data-tt="Orders.label"'));
    expect(method, contains('L1'));
  });

  test(
    'an enum field: one state per case, the builder typed as the enum',
    () async {
      final html = await renderHtml(
        Watch.field(
          orders_.mood,
          builder: (mood) {
            final Mood m = mood;
            return Text(switch (m) {
              Mood.calm => 'tranquilo',
              Mood.busy => 'ocupado',
            });
          },
        ),
      );
      expect(html, contains('data-tv="Orders.mood"'));
      expect(html, contains('tranquilo'));
      expect(html, contains('ocupado'));
    },
  );

  test('an int field with count: values 0 … count-1, typed int', () async {
    final html = await renderHtml(
      Watch.field(
        orders_.step,
        count: 3,
        builder: (n) {
          final int i = n;
          return Text('paso $i');
        },
      ),
    );
    expect(html, contains('paso 0'));
    expect(html, contains('paso 1'));
    expect(html, contains('paso 2'));
    expect(html, isNot(contains('paso 3')));
  });

  test('a String field is text: with and without builder', () async {
    final plain = await renderHtml(Watch.field(orders_.name));
    expect(plain, contains('data-tt="Orders.name"'));
    expect(plain, contains('Ana'));
    expect(await renderHtml(Watch(orders_.name)), plain);
    final built = await renderHtml(
      Watch.field(orders_.name, builder: (n) => Text('Hello, $n')),
    );
    expect(built, contains('data-tt="Orders.name"'));
    expect(built, contains('Hello, Ana'));
  });

  test('without a builder any field shows its value as text', () async {
    final html = await renderHtml(Watch.field(orders_.step));
    expect(html, contains('data-tt="Orders.step"'));
    expect(html, contains('>1<'));
  });

  test('a nullable field without a builder shows nothing for null', () async {
    final html = await renderHtml(Watch.field(orders_.maybe));
    expect(html, contains('data-tt="Orders.maybe"'));
  });

  test('a field of another state, read from a state that uses it', () async {
    final html = await renderHtml(
      Watch.field(cart.orders.toast, builder: (v) => Text(v ? 'on' : 'off')),
    );
    expect(html, contains('data-tv="Orders.toast"'));
    final own = await renderHtml(
      Watch.field(cart.open, builder: (v) => Text(v ? 'on' : 'off')),
    );
    expect(own, contains('data-tv="Cart.open"'));
  });

  test('inside a list row: the field is a state of the row and of its '
      'template', () async {
    final html = await renderHtml(
      Watch.list(
        cart.lines,
        itemKey: cart.lineKey,
        each: (row) => Row(
          children: [
            row.text(cart.lineName),
            Watch.field(
              cart.open,
              builder: (v) => Text(v ? 'panel open' : 'panel closed'),
            ),
          ],
        ),
      ),
    );
    expect(html, contains('data-tl="Cart.lines"'));
    // Two rows and the template: three bindings to the same field.
    expect('data-tv="Cart.open"'.allMatches(html), hasLength(3));
    expect(html, contains('panel open'));
  });

  test('a states builder inside another one, both fields', () async {
    final html = await renderHtml(
      Watch.field(
        orders_.toast,
        builder: (v) => Watch.field(
          orders_.mood,
          builder: (m) => Text('${v ? 1 : 0}${m.name}'),
        ),
      ),
    );
    expect(html, contains('data-tv="Orders.toast"'));
    expect(html, contains('data-tv="Orders.mood"'));
  });

  group('errors say the fix', () {
    test('an int field with a builder and no count', () async {
      final message = await failure(
        Watch.field(orders_.step, builder: (n) => Text('$n')),
      );
      expect(message, contains('THOR-S003'));
      expect(message, contains('Orders.step'));
      expect(message, contains('count: n'));
      expect(message, isNot(contains('needs a bool or enum source')));
    });

    test('a nullable bool or enum field', () async {
      final bool_ = await failure(
        Watch.field(orders_.maybe, builder: (v) => Text('v=$v')),
      );
      expect(bool_, contains('THOR-S003'));
      expect(bool_, contains('can be null'));
      expect(bool_, contains('non-null'));
      final enum_ = await failure(
        Watch.field(orders_.maybeMood, builder: (v) => Text('v=$v')),
      );
      expect(enum_, contains('can be null'));
    });

    test('a field that is in no ThorState says so (THOR-S001)', () async {
      final message = await failure(
        Watch.field(orphan, builder: (v) => Text('$v')),
      );
      expect(message, contains('THOR-S001'));
      expect(message, contains('field'));
    });
  });
}
