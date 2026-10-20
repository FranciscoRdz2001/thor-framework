@TestOn('vm')
library;

// `controller:` in ListView and GridView marks the scroll container
// the way SingleChildScrollView already did.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class ListState extends ThorState {
  final scroll = ScrollController(initialScrollOffset: 40);
  final side = ScrollController();
}

final list = ListState();

void main() {
  initializeThorTests();
  setUpAll(
    () => ThorState.register({
      ListState: ThorStateType('ListState', (state) {
        final s = state as ListState;
        return [
          ThorMember.controller('scroll', s.scroll),
          ThorMember.controller('side', s.side),
        ];
      }),
    }),
  );

  test('ListView marks its element with the controller', () async {
    final html = await renderHtml(
      ListView(controller: list.scroll, children: const [Text('a')]),
    );
    expect(html, contains('data-tsc="ListState.scroll"'));
    expect(html, isNot(contains('data-tsc-h')));
  });

  test('ListView.builder and .separated take it too', () async {
    for (final view in [
      ListView.builder(
        controller: list.scroll,
        itemCount: 2,
        itemBuilder: (c, i) => Text('$i'),
      ),
      ListView.separated(
        controller: list.scroll,
        itemCount: 2,
        itemBuilder: (c, i) => Text('$i'),
        separatorBuilder: (c, i) => const Divider(),
      ),
    ]) {
      expect(await renderHtml(view), contains('data-tsc="ListState.scroll"'));
    }
  });

  test(
    'a horizontal list says so: the controller follows scrollLeft',
    () async {
      final html = await renderHtml(
        ListView(
          scrollDirection: Axis.horizontal,
          controller: list.side,
          children: const [Text('a')],
        ),
      );
      expect(html, contains('data-tsc="ListState.side"'));
      expect(html, contains('data-tsc-h'));
    },
  );

  test('GridView.count and .extent take it', () async {
    for (final view in [
      GridView.count(
        crossAxisCount: 2,
        controller: list.scroll,
        children: const [Text('a')],
      ),
      GridView.extent(
        maxCrossAxisExtent: 100,
        controller: list.scroll,
        children: const [Text('a')],
      ),
    ]) {
      expect(await renderHtml(view), contains('data-tsc="ListState.scroll"'));
    }
  });

  test('without a controller nothing is marked', () async {
    expect(
      await renderHtml(const ListView(children: [Text('a')])),
      isNot(contains('data-tsc')),
    );
  });

  test('a controller no state holds only exists on the server', () async {
    expect(
      await renderHtml(
        ListView(controller: ScrollController(), children: const [Text('a')]),
      ),
      isNot(contains('data-tsc')),
    );
  });
}
