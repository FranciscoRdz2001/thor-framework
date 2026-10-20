@TestOn('vm')
library;

// `row.bindText(...)` (a row's text on an element of your own, no `<span>`)
// and `row.text((o) => '${o.id}')` (an int, double or bool property as text).
import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart'
    show RowProbeLog, propertyOfRowLambda, registerRowProbes;
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/web.dart';

class Item {
  const Item(this.id, this.label, this.price, {this.done = false});
  final int id;
  final String label;
  final double price;
  final bool done;
}

/// What thor generates for `Item` (by hand: tests don't run the build).
class _ItemProbe implements Item {
  _ItemProbe(this.log);
  final RowProbeLog log;

  @override
  int get id => log.integer('id');

  @override
  String get label {
    log.read('label');
    return RowProbeLog.marker('label');
  }

  @override
  double get price => log.decimal('price');

  @override
  bool get done => log.choose('done', const [false, true]) as bool;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    log.read('');
    return super.noSuchMethod(invocation);
  }
}

abstract class _Members extends ThorState {
  @override
  String get $type => 'ItemsState';

  @override
  List<ThorMember> get $members {
    final s = this as ItemsState;
    return [
      ThorMember.state('items', s.items),
      ThorMember(
        'idOf',
        s.idOf,
        arity: 1,
        callWithItem: (i) => s.idOf(i as Item),
      ),
      ThorMember(
        'labelOf',
        s.labelOf,
        arity: 1,
        callWithItem: (i) => s.labelOf(i as Item),
      ),
    ];
  }
}

class ItemsState extends _Members {
  final items = state<List<Item>>(const [
    Item(7, 'Ana', 1.5, done: true),
    Item(8, '<b>Luis</b>', 2.25),
  ]);

  int idOf(Item i) => i.id;
  String labelOf(Item i) => i.label;
}

final items = ItemsState();

Future<String> rows(Widget Function(WatchRow<Item, int> row) each) =>
    renderHtml(Watch.list(items.items.call, itemKey: items.idOf, each: each));

void main() {
  initializeThorTests();
  setUpAll(() => registerRowProbes({Item: _ItemProbe.new}));

  group('a number or bool property as text', () {
    test('an int by interpolation or toString', () async {
      for (final build in <Widget Function(WatchRow<Item, int>)>[
        (row) => row.text((o) => '${o.id}'),
        (row) => row.text((o) => o.id.toString()),
      ]) {
        final out = await rows(build);
        expect(out, contains(r'data-tf="$Rows.id"'));
        expect(out, contains('>7<'));
        expect(out, contains('>8<'));
      }
    });

    test('a double and a bool', () async {
      final d = await rows((row) => row.text((o) => '${o.price}'));
      expect(d, contains(r'data-tf="$Rows.price"'));
      expect(d, contains('>1.5<'));
      final b = await rows((row) => row.text((o) => o.done.toString()));
      expect(b, contains(r'data-tf="$Rows.done"'));
      expect(b, contains('>true<'));
      expect(b, contains('>false<'));
    });

    test('a lambda that computes still fails', () {
      expect(propertyOfRowLambda(Item, (Item o) => '${o.id + 1}'), isNull);
      expect(propertyOfRowLambda(Item, (Item o) => '#${o.id}'), isNull);
      expect(propertyOfRowLambda(Item, (Item o) => o.done ? 'y' : 'n'), isNull);
      expect(propertyOfRowLambda(Item, (Item o) => '${o.id}'), 'id');
      expect(propertyOfRowLambda(Item, (Item o) => '${o.done}'), 'done');
    });
  });

  group('row.bindText', () {
    test('a td carries the binding with no span', () async {
      final out = await rows((row) {
        final id = row.bindText((o) => '${o.id}');
        return html.td(id.children, attributes: id.attributes);
      });
      expect(out, contains(r'data-tf="$Rows.id">7</td>'));
      expect(out, isNot(contains('<span')));
      final template = out.substring(out.indexOf('<template'));
      expect(template, contains(r'<td data-tf="$Rows.id"></td>'));
    });

    test('a method of the state and an a without href', () async {
      final out = await rows((row) {
        final label = row.bindText(items.labelOf);
        return html.a(label.children, attributes: label.attributes);
      });
      expect(out, contains('data-tf="ItemsState.labelOf">Ana</a>'));
      expect(out, contains('&lt;b&gt;Luis&lt;/b&gt;'));
      expect(out, isNot(contains('href')));
    });

    test('a web Td takes it as text:', () async {
      final out = await rows((row) {
        final label = row.bindText((o) => o.label);
        return Td(
          classes: 'cell',
          text: label.text,
          attributes: label.attributes,
        );
      });
      expect(out, contains(r'data-tf="$Rows.label"'));
      expect(out, contains('>Ana</td>'));
    });
  });
}
