@TestOn('vm')
library;

// A `HiddenField` and a bound button in the rows of a `Watch.list` inside a
// `Form`: the rows and the template the browser clones for a new row carry
// the row's own value, never the sentinel of the template key.
import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart' show templateIntKey;
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class Item {
  const Item(this.id, this.name);
  final int id;
  final String name;
}

abstract class _Members extends ThorState {
  @override
  String get $type => 'ItemsState';

  @override
  List<ThorMember> get $members {
    final s = this as ItemsState;
    return [
      ThorMember.state('rows', s.rows),
      ThorMember(
        'idOf',
        s.idOf,
        arity: 1,
        callWithItem: (i) => s.idOf(i as Item),
      ),
      ThorMember('bump', s.bump, arity: 0, call: (_) => s.bump()),
      ThorMember(
        'nameOf',
        s.nameOf,
        arity: 1,
        callWithItem: (i) => s.nameOf(i as Item),
      ),
    ];
  }
}

class ItemsState extends _Members {
  final rows = state<List<Item>>(const [Item(3, 'a'), Item(4, 'b')]);
  int idOf(Item o) => o.id;
  String nameOf(Item o) => o.name;
  void bump() {}
}

final items = ItemsState();

class ItemsPage extends ThorPage<void> {
  const ItemsPage();

  Future<ActionResult?> archive(PageRequest request, int id) async => null;

  @override
  Widget build(BuildContext context, PageState<void> state) => Form(
    child: Column(
      children: [
        FilledButton(
          onPressed: items.bump,
          onPost: archive.withArg(1),
          child: const Text('both'),
        ),
        Watch.list(
          items.rows.call,
          itemKey: items.idOf,
          each: (row) => Row(
            children: [
              HiddenField(name: 'id', value: '${row.key}'),
              FilledButton(
                onPost: archive.withArg(row.key),
                child: const Text('a'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void main() {
  initializeThorTests();
  registerPageActions({
    ItemsPage: [
      PageActionMethod.args(
        'archive',
        (p) => (p as ItemsPage).archive,
        1,
        (x) => [int.parse(x[0])],
      ),
    ],
  });
  final app = ThorApp.router(
    routerConfig: ThorRouter([ThorRoute('/items', const ItemsPage())]),
  );
  final handler = RouteHandler<Widget>(
    routes: app.routes,
    renderer: WidgetRenderer.router(app),
  );
  Future<String> get() async => (await handler.handle(
    PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://s.test/items'),
      headers: const {HttpHeader.host: 's.test'},
    ),
  )).text;

  test('the template never carries the sentinel of the key', () async {
    final html = await get();
    final i = html.indexOf('<template');
    expect(i, greaterThan(0));
    final template = html.substring(i);
    expect(template, isNot(contains('$templateIntKey')));
    expect(html.substring(0, i), contains('name="id" value="3"'));
  });

  test('onPressed and onPost on one button keep both', () async {
    final html = await get();
    final b = RegExp('<button[^>]*>both').firstMatch(html)!.group(0)!;
    // The page's only action: its path, no key.
    expect(b, contains('formaction="/items"'));
    expect(b, contains('data-t'));
    expect(b, isNot(contains('disabled')));
  });

  test('a bound button in a Form inside a row stays in its Form', () async {
    final html = await get();
    expect(html, isNot(contains('form="thor-post"')));
    expect(html, contains('name="thor-arg"'));
  });
}
