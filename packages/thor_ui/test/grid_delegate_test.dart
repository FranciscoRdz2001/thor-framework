@TestOn('vm')
library;

// GridView(gridDelegate:) and GridView.builder, Flutter's spelling of
// GridView.count / .extent (same CSS), and IndexedStack.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Widget body) => renderDocument(ThorApp(child: body));

List<Widget> _items(int n) => [for (var i = 0; i < n; i++) Text('item $i')];

int _count(String html, String needle) =>
    RegExp(RegExp.escape(needle)).allMatches(html).length;

void main() {
  setUpAll(initializeThorTests);
  _fixedTracks();

  group('GridView with a delegate', () {
    test('FixedCrossAxisCount is GridView.count, byte for byte', () async {
      expect(
        await _page(
          GridView(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
            ),
            padding: const EdgeInsets.all(4),
            children: _items(5),
          ),
        ),
        await _page(
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            padding: const EdgeInsets.all(4),
            children: _items(5),
          ),
        ),
      );
    });

    test('MaxCrossAxisExtent is GridView.extent, byte for byte', () async {
      expect(
        await _page(
          GridView(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 6,
              crossAxisSpacing: 10,
              childAspectRatio: 0.8,
            ),
            children: _items(4),
          ),
        ),
        await _page(
          GridView.extent(
            maxCrossAxisExtent: 200,
            mainAxisSpacing: 6,
            crossAxisSpacing: 10,
            childAspectRatio: 0.8,
            children: _items(4),
          ),
        ),
      );
    });

    test('GridView.builder builds itemCount items with the index', () async {
      final html = await _page(
        GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
          ),
          itemCount: 5,
          itemBuilder: (context, i) => Text('cell $i'),
        ),
      );
      for (var i = 0; i < 5; i++) {
        expect(html, contains('>cell $i<'));
      }
      expect(html, isNot(contains('cell 5')));
      expect(
        html,
        await _page(
          GridView.count(
            crossAxisCount: 2,
            children: [for (var i = 0; i < 5; i++) Text('cell $i')],
          ),
        ),
      );
    });

    test('itemCount 0 is an empty grid, not an error', () async {
      final html = await _page(
        GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 120,
          ),
          itemCount: 0,
          itemBuilder: (context, i) => throw StateError('never called'),
        ),
      );
      expect(html, contains('grid-template-columns'));
    });

    test('10 000 items build, and lazyLayout keeps them cheap', () async {
      final html = await _page(
        GridView.builder(
          lazyLayout: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
          ),
          itemCount: 10000,
          itemBuilder: (context, i) => Text('n$i'),
        ),
      );
      expect(_count(html, '>n'), 10000);
      expect(html, contains('content-visibility'));
    });

    test('mainAxisExtent fixes the rows instead of the aspect ratio', () async {
      final html = await _page(
        GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 96,
          ),
          itemCount: 2,
          itemBuilder: (context, i) => Text('x$i'),
        ),
      );
      expect(html, contains('grid-auto-rows: 96px'));
      expect(html, isNot(contains('aspect-ratio')));
    });

    test('a null itemCount says why it cannot render', () {
      expect(
        () => GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
          ),
          itemBuilder: (context, i) => const Text('x'),
        ),
        returnsNormally,
      );
      expect(
        _page(
          GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
            ),
            itemBuilder: (context, i) => const Text('x'),
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('itemCount'),
          ),
        ),
      );
    });

    test('a negative itemCount and a bad delegate are errors', () {
      expect(
        () => GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
          ),
          itemCount: -1,
          itemBuilder: (context, i) => const Text('x'),
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('layout: still layers breakpoints over a delegate', () async {
      final html = await _page(
        GridView(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
          ),
          layout: const GridLayout().when(medium: const GridLayout(columns: 3)),
          children: _items(3),
        ),
      );
      expect(html, contains('@media'));
    });
  });

  group('IndexedStack', () {
    test('keeps every child in the DOM and shows only the index one', () async {
      final html = await _page(
        const IndexedStack(
          index: 1,
          children: [Text('zero'), Text('one'), Text('two')],
        ),
      );
      for (final t in ['zero', 'one', 'two']) {
        expect(html, contains('>$t<'));
      }
      expect(html, contains('data-stack-index="1"'));
      // The rule that shows the current one, and the default that hides.
      expect(html, contains('[data-stack-index="1"] > :nth-child(2)'));
      expect(html, contains('visibility: hidden'));
      expect(html, isNot(contains('[data-stack-index="1"] > :nth-child(1)')));
    });

    test('sizes to the largest child like Stack (one grid cell)', () async {
      final html = await _page(
        const IndexedStack(children: [Text('a'), Text('b')]),
      );
      expect(html, contains('display: grid'));
      expect(html, contains('grid-area: 1 / 1'));
    });

    test('index: null shows nothing; no children is fine', () async {
      var html = await _page(
        const IndexedStack(index: null, children: [Text('a'), Text('b')]),
      );
      // No value matches a rule: every child stays hidden.
      expect(bodyOfPage(html), isNot(contains('data-stack-index="')));
      expect(html, contains('>a<'));
      html = await _page(const IndexedStack(children: []));
      expect(html, contains('display: grid'));
    });

    test('an index out of range fails like Flutter\'s assert', () async {
      for (final i in [2, 5, -1]) {
        await expectLater(
          _page(IndexedStack(index: i, children: const [Text('a'), Text('b')])),
          throwsA(
            isA<RangeError>().having(
              (e) => e.message,
              'message',
              contains('IndexedStack'),
            ),
          ),
          reason: '$i',
        );
      }
    });

    test(
      'a state index: the attribute is bound, the first frame is right',
      () async {
        final html = await _page(
          IndexedStack.watch(
            _tabs.current,
            children: const [Text('a'), Text('b'), Text('c')],
          ),
        );
        expect(html, contains('data-stack-index="2"'));
        expect(html, contains('[data-stack-index="2"] > :nth-child(3)'));
        expect(
          html,
          contains('data-tca="data-stack-index:TabsState.current"'),
          reason: 'bound to the state',
        );
      },
    );

    test('through Watch with a finite state also works', () async {
      final html = await _page(
        Watch.field(
          _tabs.tab,
          count: 3,
          builder: (i) => IndexedStack(
            index: i,
            children: const [Text('a'), Text('b'), Text('c')],
          ),
        ),
      );
      expect(html, contains('data-stack-index="0"'));
      expect(html, contains('data-stack-index="2"'));
    });
  });
}

abstract class _TabsMembers extends ThorState {
  @override
  String get $type => 'TabsState';

  @override
  List<ThorMember> get $members {
    final s = this as TabsState;
    return [
      ThorMember.state('tab', s.tab),
      ThorMember('current', s.current, call: (_) => s.current()),
    ];
  }
}

class TabsState extends _TabsMembers {
  final tab = state(0);

  int current() => 2;
}

final _tabs = TabsState();

// `stretch: false`: fixed tracks, as in "3 columns of 260 with exactly 73
// between them".
void _fixedTracks() {
  group('GridView.extent(stretch: false)', () {
    String css(String html, String name) =>
        RegExp('$name: ([^;}]*)').firstMatch(html)![1]!.trim();

    test('tiles keep exactly the extent and the gap, as many as fit', () async {
      final html = await _page(
        GridView.extent(
          maxCrossAxisExtent: 260,
          crossAxisSpacing: 73,
          mainAxisSpacing: 20,
          stretch: false,
          children: _items(4),
        ),
      );
      expect(
        css(html, 'grid-template-columns'),
        'repeat(auto-fill, minmax(min(260px, 100%), 260px))',
      );
      expect(css(html, 'column-gap'), '73px');
      expect(css(html, 'row-gap'), '20px');
      expect(css(html, 'justify-content'), 'flex-start');
      // The browser counts the columns: no query steps, no extra wrapper.
      expect(html, isNot(contains('@container')));
      expect(html, isNot(contains('container-type')));
    });

    test('alignment places the space left over', () async {
      final html = await _page(
        GridView.extent(
          maxCrossAxisExtent: 260,
          stretch: false,
          alignment: WrapAlignment.center,
          children: _items(2),
        ),
      );
      expect(css(html, 'justify-content'), 'center');
    });

    test('the delegate is GridView.extent, byte for byte', () async {
      expect(
        await _page(
          GridView(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 260,
              crossAxisSpacing: 73,
              childAspectRatio: 0.8,
              stretch: false,
              alignment: WrapAlignment.spaceBetween,
            ),
            children: _items(3),
          ),
        ),
        await _page(
          GridView.extent(
            maxCrossAxisExtent: 260,
            crossAxisSpacing: 73,
            childAspectRatio: 0.8,
            stretch: false,
            alignment: WrapAlignment.spaceBetween,
            children: _items(3),
          ),
        ),
      );
    });

    test('stretching (the default) is unchanged', () async {
      final html = await _page(
        GridView.extent(maxCrossAxisExtent: 260, children: _items(2)),
      );
      expect(css(html, 'grid-template-columns'), 'repeat(1, minmax(0, 1fr))');
      expect(html, contains('@container'));
      expect(html, isNot(contains('justify-content')));
    });
  });
}
