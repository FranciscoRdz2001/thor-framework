@TestOn('vm')
library;

// Adversarial: `Watch.field` on a `state(...)` field, with and without `builder:`. Dart has
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

  test(
    'a list field with a builder and no each: says each: (THOR-S003)',
    () async {
      final message = await failure(
        Watch.field(cart.lines, builder: (lines) => Text('${lines.length}')),
      );
      expect(message, contains('THOR-S003'));
      expect(message, contains('Cart.lines'));
      expect(message, contains('each:'));
    },
  );

  test(
    'a nullable field: THOR-S003, not the builder\'s own null error',
    () async {
      // The builder dereferences its value, as a bool? builder written by
      // someone who filled the field before rendering would.
      final message = await failure(
        Row(
          children: [
            Watch.field(orders_.maybe, builder: (v) => Text(v! ? 'a' : 'b')),
          ],
        ),
      );
      expect(message, contains('THOR-S003'));
    },
  );

  test('the same field nested in itself: every pair is a state', () async {
    final html = await renderHtml(
      Watch.field(
        orders_.toast,
        builder: (a) => Watch.field(
          orders_.toast,
          builder: (b) => Text('${a ? 1 : 0}${b ? 1 : 0}'),
        ),
      ),
    );
    for (final pair in ['00', '01', '10', '11']) {
      expect(html, contains(pair));
    }
  });

  test('nested variants of two fields reach every pair: the inner ones ship as '
      'patches of one element, the outer ones as templates', () async {
    final html = await renderHtml(
      Watch.field(
        orders_.toast,
        builder: (a) => Watch.field(
          orders_.mood,
          builder: (m) => SizedBox(
            width: (a ? 10.0 : 20.0) + (m == Mood.busy ? 1.0 : 2.0),
            height: 4,
          ),
        ),
      ),
    );
    // web: one box per outer state (2), the inner states are patches of it
    // (a pair is one element with a patch), so 4 pairs are not 4 copies.
    expect(
      RegExp('<template data-tvt="Orders.toast"').allMatches(html),
      hasLength(1),
    );
    expect(RegExp(r'data-tv="Orders.mood"').allMatches(html), hasLength(2));
    expect(RegExp(r'data-tp-\d').allMatches(html), hasLength(2));
  });

  test('the live copy is the current value, whatever it is', () async {
    orders_.toast.value = true;
    addTearDown(() => orders_.toast.value = false);
    final html = await renderHtml(
      Watch.field(orders_.toast, builder: (v) => Text(v ? 'yes' : 'no')),
    );
    expect(html, contains('>yes</span>'));
    expect(html, contains('=no"'));
    orders_.mood.value = Mood.busy;
    addTearDown(() => orders_.mood.value = Mood.calm);
    final e = await renderHtml(
      Watch.field(orders_.mood, builder: (m) => Text(m.name)),
    );
    expect(e, contains('>busy</span>'));
  });

  test('inside a ValueListenableBuilder on another field', () async {
    final html = await renderHtml(
      ValueListenableBuilder<bool>(
        valueListenable: orders_.toast,
        builder: (context, open, _) => Watch.field(
          cart.open,
          builder: (v) => Text('${open ? 'T' : 'F'}${v ? 'o' : 'c'}'),
        ),
      ),
    );
    expect(html, contains('data-tv="Cart.open"'));
    expect(html, contains('data-tv="Orders.toast"'));
  });

  test(
    'each: over a list field with itemKey of a method of another state',
    () async {
      final html = await renderHtml(
        Watch.list(
          cart.lines.call,
          itemKey: cart.lineKey,
          container: (rows) => Column(children: rows),
          each: (row) => row.text(cart.lineName),
        ),
      );
      expect(html, contains('data-tl="Cart.lines"'));
      expect(html, contains('data-tk="a"'));
      expect(html, contains('data-tk="b"'));
    },
  );

  test('an empty list field renders the template and no rows', () async {
    cart.lines.value = const [];
    addTearDown(() => cart.lines.value = const ['a', 'b']);
    final html = await renderHtml(
      Watch.list(
        cart.lines.call,
        itemKey: cart.lineKey,
        each: (row) => row.text(cart.lineName),
      ),
    );
    expect(html, contains('data-tl="Cart.lines"'));
    expect(html, isNot(contains('data-tk="a"')));
    expect(html, contains('<template'));
  });

  test('a 10k-row list field renders every row', () async {
    cart.lines.value = [for (var i = 0; i < 10000; i++) 'r$i'];
    addTearDown(() => cart.lines.value = const ['a', 'b']);
    final html = await renderHtml(
      Watch.list(
        cart.lines.call,
        itemKey: cart.lineKey,
        each: (row) => row.text(cart.lineName),
      ),
    );
    expect(
      RegExp('data-tk="r').allMatches(html).length,
      greaterThanOrEqualTo(10000),
    );
  });

  test('a key and a container are passed through', () async {
    final html = await renderHtml(
      Watch.list(
        cart.lines.call,
        key: const ValueKey('k'),
        itemKey: cart.lineKey,
        container: (rows) => Row(children: rows),
        each: (row) => row.text(cart.lineName),
      ),
    );
    expect(html, contains('data-tl="Cart.lines"'));
  });

  // Containers ask their child whether it fills the width (layout hints),
  // which runs the builder once with the current value before the build:
  // for a null field that is the builder's own null error, not THOR-S003.
  for (final (name, wrap) in <(String, Widget Function(Widget))>[
    ('Container', (w) => Container(child: w)),
    ('Padding', (w) => Padding(padding: const EdgeInsets.all(4), child: w)),
    ('SizedBox', (w) => SizedBox(child: w)),
    (
      'DecoratedBox',
      (w) => DecoratedBox(decoration: const BoxDecoration(), child: w),
    ),
  ]) {
    test('a nullable field under a $name says THOR-S003', () async {
      final message = await failure(
        wrap(Watch.field(orders_.maybe, builder: (v) => Text(v! ? 'a' : 'b'))),
      );
      expect(message, contains('THOR-S003'));
    });
  }

  for (final (name, wrap) in <(String, Widget Function(Widget))>[
    ('Container', (w) => Container(child: w)),
    ('Padding', (w) => Padding(padding: const EdgeInsets.all(4), child: w)),
  ]) {
    test(
      'an int or bool field with no builder under a $name is its text',
      () async {
        final n = await renderHtml(wrap(Watch.field(orders_.step)));
        expect(n, contains('data-tt="Orders.step"'));
        final b = await renderHtml(wrap(Watch.field(orders_.toast)));
        expect(b, contains('data-tt="Orders.toast"'));
        final e = await renderHtml(wrap(Watch.field(orders_.mood)));
        expect(e, contains('data-tt="Orders.mood"'));
      },
    );
  }
}
