@TestOn('vm')
library;

// GridView, ListView(shrinkWrap:, physics:) compile as in Flutter and change nothing;
// GridView(autoRowHeight: true) sizes rows by content (web extra).
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Widget body) => renderDocument(ThorApp(child: body));

/// A view that never scrolls is not a tab stop and clips instead of
/// scrolling: the default page without that stop and with `overflow:
/// hidden` is what `NeverScrollableScrollPhysics` draws (class names are
/// hashes of the rules, so they are compared by shape).
Future<String> _unfocusable(Widget body) async => _shape(
  (await _page(body))
      .replaceAll(' tabindex="0"', '')
      .replaceAll('overflow: auto', 'overflow: hidden'),
);

String _shape(String html) =>
    html.replaceAll(RegExp(r'\bt[0-9a-z]{6,8}\b'), 'c');

List<Widget> _items(int n) => [for (var i = 0; i < n; i++) Text('item $i')];

void main() {
  setUpAll(initializeThorTests);

  test('the default stays square tiles', () async {
    final html = await _page(
      GridView.count(crossAxisCount: 2, children: _items(2)),
    );
    expect(html, contains('aspect-ratio: 1'));
  });

  test('shrinkWrap and physics are accepted and change nothing', () async {
    for (final physics in <ScrollPhysics?>[
      null,
      const NeverScrollableScrollPhysics(),
      const AlwaysScrollableScrollPhysics(),
      const BouncingScrollPhysics(),
      const ClampingScrollPhysics(),
    ]) {
      expect(
        _shape(
          await _page(
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: physics,
              children: _items(2),
            ),
          ),
        ),
        physics is NeverScrollableScrollPhysics
            ? await _unfocusable(
                GridView.count(crossAxisCount: 2, children: _items(2)),
              )
            : _shape(
                await _page(
                  GridView.count(crossAxisCount: 2, children: _items(2)),
                ),
              ),
      );
    }
  });

  test(
    'ListView and SingleChildScrollView take shrinkWrap and physics',
    () async {
      const physics = NeverScrollableScrollPhysics();
      final items = _items(2);
      expect(
        _shape(
          await _page(
            ListView(shrinkWrap: true, physics: physics, children: items),
          ),
        ),
        await _unfocusable(ListView(children: items)),
      );
      expect(
        _shape(
          await _page(
            ListView.builder(
              shrinkWrap: true,
              physics: physics,
              itemCount: 2,
              itemBuilder: (_, i) => Text('item $i'),
            ),
          ),
        ),
        await _unfocusable(
          ListView.builder(
            itemCount: 2,
            itemBuilder: (_, i) => Text('item $i'),
          ),
        ),
      );
      expect(
        _shape(
          await _page(
            ListView.separated(
              shrinkWrap: true,
              physics: physics,
              itemCount: 2,
              itemBuilder: (_, i) => Text('item $i'),
              separatorBuilder: (_, _) => const Divider(),
            ),
          ),
        ),
        await _unfocusable(
          ListView.separated(
            itemCount: 2,
            itemBuilder: (_, i) => Text('item $i'),
            separatorBuilder: (_, _) => const Divider(),
          ),
        ),
      );
      expect(
        _shape(
          await _page(
            SingleChildScrollView(physics: physics, child: items.first),
          ),
        ),
        await _unfocusable(SingleChildScrollView(child: items.first)),
      );
    },
  );

  group('autoRowHeight', () {
    final delegates = <String, Widget>{
      'count': GridView.count(
        crossAxisCount: 2,
        autoRowHeight: true,
        children: _items(2),
      ),
      'extent': GridView.extent(
        maxCrossAxisExtent: 200,
        autoRowHeight: true,
        children: _items(2),
      ),
      'delegate': GridView(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
        ),
        autoRowHeight: true,
        children: _items(2),
      ),
      'builder': GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.7,
        ),
        autoRowHeight: true,
        itemCount: 2,
        itemBuilder: (_, i) => Text('item $i'),
      ),
    };
    for (final MapEntry(:key, :value) in delegates.entries) {
      test('$key: rows follow their content', () async {
        final html = await _page(value);
        expect(html, isNot(contains('aspect-ratio')));
        expect(html, isNot(contains('grid-auto-rows')));
        expect(html, contains('item 1'));
      });
    }

    test('mainAxisExtent still wins', () async {
      final html = await _page(
        GridView(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 120,
          ),
          autoRowHeight: true,
          children: _items(2),
        ),
      );
      expect(html, contains('grid-auto-rows: 120px'));
      expect(html, isNot(contains('aspect-ratio')));
    });
  });
}
