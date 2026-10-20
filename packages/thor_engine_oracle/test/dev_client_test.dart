@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:test/test.dart';
import 'package:thor_engine_oracle/client.dart';
import 'package:thor_engine_oracle/src/dev_client.dart';
import 'package:web/web.dart' as web;

web.HTMLElement mount(String html) {
  final root = web.document.createElement('div') as web.HTMLElement;
  root.innerHTML = html.toJS;
  web.document.body!.append(root);
  // ignore: unnecessary_lambdas
  addTearDown(() => root.remove());
  return root;
}

// The member list thor generates for [_Todo], by hand.
abstract class _TodoMembers extends ThorState {
  @override
  String get $type => 'Todo';

  @override
  List<ThorMember> get $members {
    final s = this as _Todo;
    return [
      ThorMember.state('count', s.count),
      ThorMember.state('items', s.items),
      ThorMember('label', s.label, call: (_) => s.label()),
      ThorMember(
        'isZero',
        s.isZero,
        call: (_) => s.isZero(),
        variants: const [false, true],
      ),
      ThorMember(
        'itemKey',
        s.itemKey,
        arity: 1,
        callWithItem: (i) => s.itemKey(i! as String),
      ),
      ThorMember(
        'itemName',
        s.itemName,
        arity: 1,
        callWithItem: (i) => s.itemName(i! as String),
      ),
    ];
  }
}

class _Todo extends _TodoMembers {
  final count = state(0);
  final items = state(const ['a', 'b']);

  String label() => 'n=${count.value}';
  bool isZero() => count.value == 0;
  String itemKey(String i) => 'k$i';
  String itemName(String i) => i.toUpperCase();
}

web.Storage get storage => web.window.sessionStorage;

void save(String path, String json) {
  storage.setItem('$devStateKey$path', json);
  addTearDown(() => storage.removeItem('$devStateKey$path'));
}

String? snapshotText() =>
    globalContext.callMethod<JSString?>(devStateGlobal.toJS)?.toDart;

List<String?> texts(web.Element root, String selector) {
  final list = root.querySelectorAll(selector);
  return [for (var i = 0; i < list.length; i++) list.item(i)!.textContent];
}

void main() {
  test('after hydration the saved values win over the server, once', () {
    final todo = _Todo();
    final root = mount(
      '<script type="application/json" id="thor-state">{"Todo.count":2}</script>'
      '<span data-tt="Todo.label">n=2</span>'
      '<p class="off" data-tv="Todo.isZero" data-tp-1="|class|=on">x</p>'
      '<ul data-tl="Todo.items" data-tlk="Todo.itemKey">'
      '<li data-tk="ka"><b data-tf="Todo.itemName">A</b></li>'
      '<li data-tk="kb"><b data-tf="Todo.itemName">B</b></li>'
      '<template data-tlt="Todo.items"><li><b data-tf="Todo.itemName"></b></li></template>'
      '</ul>',
    );
    save('/t1', '{"v":1,"s":{"Todo.count":0,"Todo.items":["b","c","a"]}}');
    final rowA = root.querySelector('[data-tk="ka"]');
    // startThor's order: hydrate the server's values, then restore.
    addTearDown(startThor([todo], root: root, features: allEngineFeatures));
    expect(todo.count.value, 2, reason: "the server's JSON first");
    final r = installDevState([todo], path: '/t1')!;
    expect(r.restored, ['Todo.count', 'Todo.items']);
    expect(todo.count.value, 0);
    expect(root.querySelector('[data-tt]')!.textContent, 'n=0');
    // The variant moves from the server's markup (index 0) to the restored
    // one: it knew the markup before the restore.
    expect(root.querySelector('p')!.className, 'on');
    // Keyed list: reordered, a new row, and the old rows are the same nodes.
    expect(texts(root, 'li [data-tf]'), ['B', 'C', 'A']);
    expect(identical(root.querySelector('[data-tk="ka"]'), rowA), isTrue);
    // Once: the saved values are gone, a manual reload starts over.
    expect(storage.getItem('$devStateKey/t1'), isNull);
    expect(installDevState([todo], path: '/t1'), isNull);
  });

  test('the page exposes its snapshot to the live-reload script', () {
    final todo = _Todo();
    todo.count.value = 4;
    installDevState([todo], path: '/t2');
    expect(
      snapshotText(),
      allOf(contains('"v":1'), contains('"Todo.count":4')),
    );
    // Taken now, not at install.
    todo.count.value = 5;
    expect(snapshotText(), contains('"Todo.count":5'));
  });

  test('a huge field is left out of the snapshot, the rest stays', () {
    final todo = _Todo();
    todo.items.value = List.filled(200, 'x' * 50);
    installDevState([todo], path: '/t3', limit: 1000);
    final text = snapshotText()!;
    expect(text, contains('"Todo.count":0'));
    expect(text, isNot(contains('Todo.items')));
  });

  test('a corrupt or foreign value is ignored and removed', () {
    final todo = _Todo()..count.value = 3;
    save('/t4', '{not json');
    expect(installDevState([todo], path: '/t4'), isNull);
    expect(storage.getItem('$devStateKey/t4'), isNull);
    save('/t4', '{"v":99,"s":{"Todo.count":8}}');
    final r = installDevState([todo], path: '/t4')!;
    expect(r.restored, isEmpty);
    expect(todo.count.value, 3);
  });

  test('another path, or a changed shape, does not break the page', () {
    final todo = _Todo();
    final root = mount('<span data-tt="Todo.label">n=0</span>');
    addTearDown(startThor([todo], root: root, features: allEngineFeatures));
    save('/other', '{"v":1,"s":{"Todo.count":9}}');
    expect(installDevState([todo], path: '/t5'), isNull);
    save('/t5', '{"v":1,"s":{"Todo.count":"nine","Gone.x":1}}');
    final r = installDevState([todo], path: '/t5')!;
    expect(r.dropped.keys, {'Todo.count', 'Gone.x'});
    expect(root.querySelector('[data-tt]')!.textContent, 'n=0');
    todo.count.value = 1;
    expect(root.querySelector('[data-tt]')!.textContent, 'n=1');
  });
}
