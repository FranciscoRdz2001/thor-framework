@TestOn('vm')
library;

// A page whose only engine markers sit on raw elements (`Widget.element`)
// still ships the engine: the markers come from wrappers (`Gesture`,
// `Watch.list`) fused into an element thorElement never builds.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class Item {
  const Item(this.id);
  final int id;
}

abstract class _PanelMembers extends ThorState {
  @override
  String get $type => 'RawPanel';

  @override
  List<ThorMember> get $members {
    final s = this as RawPanel;
    return [
      ThorMember('open', s.open, call: (_) => s.open()),
      ThorMember.state('items', s.items),
      ThorMember(
        'idOf',
        s.idOf,
        arity: 1,
        callWithItem: (i) => s.idOf(i as Item),
      ),
    ];
  }
}

class RawPanel extends _PanelMembers {
  final items = state<List<Item>>(const [Item(1)]);
  void open() {}
  int idOf(Item i) => i.id;
}

final panel = RawPanel();

Future<String> _doc(Widget child) => renderDocument(ThorApp(child: child));

void main() {
  setUpAll(initializeThorTests);

  test('a Gesture fused into a raw element ships the engine', () async {
    final doc = await _doc(
      Gesture(
        onTap: panel.open,
        semanticButton: false,
        child: const Widget.element(tag: 'button', classes: 'btn'),
      ),
    );
    expect(doc, contains('data-t-on="click:RawPanel.open"'));
    expect(doc, contains('data-thor-engine'));
  });

  test('a Watch.list with a raw container ships the engine', () async {
    final doc = await _doc(
      Watch.list(
        panel.items.call,
        itemKey: panel.idOf,
        container: (rows) => Widget.element(tag: 'ul', children: rows),
        each: (row) => const Widget.element(tag: 'li', classes: 'row'),
      ),
    );
    expect(doc, contains('data-tl='));
    expect(doc, contains('data-thor-engine'));
  });

  test('a page without engine markers does not ship it', () async {
    final doc = await _doc(const Widget.element(tag: 'div', classes: 'x'));
    expect(doc, isNot(contains('data-thor-engine')));
  });
}
