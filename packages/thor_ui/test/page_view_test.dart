@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

String bodyOf(String html) => html.substring(html.indexOf('<body'));

String stylesOf(String html) =>
    html.substring(html.indexOf('@layer thor.props'), html.indexOf('</style>'));

String ruleOf(String html, String name) {
  final cls = RegExp(
    'class="(t\\w+)"[^>]*data-thor="$name"',
  ).firstMatch(bodyOf(html))![1]!;
  final css = stylesOf(html);
  final start = css.indexOf('.$cls{');
  return css.substring(start, css.indexOf('}', start) + 1);
}

class _Deck extends ThorState {
  final scroll = ScrollController();
  final pages = PageController(initialPage: 1);
  int seen = 0;
  void changed(int page) => seen = page;
  void mark(String who, int page) => seen = page;
}

final _deck = _Deck();

void main() {
  initializeThorTests();
  setUpAll(
    () => ThorState.register({
      _Deck: ThorStateType('_Deck', (state) {
        final s = state as _Deck;
        return [
          ThorMember.controller('scroll', s.scroll),
          ThorMember.controller('pages', s.pages),
          ThorMember(
            'changed',
            s.changed,
            arity: 1,
            call: (a) => s.changed(int.parse(a!)),
          ),
          ThorMember(
            'mark',
            s.mark,
            arity: 2,
            call: (a) {
              final x = splitArgs(a, 2);
              return s.mark(x[0], int.parse(x[1]));
            },
          ),
        ];
      }),
    }),
  );
  group('PageView', () {
    test(
      'a horizontal snapping scroller; each page is one full slot',
      () async {
        final html = await page(
          const PageView(children: [Text('one'), Text('two'), Text('three')]),
        );
        final rule = ruleOf(html, 'PageView');
        expect(rule, contains('display: flex'));
        expect(rule, contains('overflow-x: auto'));
        expect(rule, contains('scroll-snap-type: x mandatory'));
        expect(rule, contains('scrollbar-width: none'));
        // The page is the child's own element (one node per concept).
        final css = stylesOf(html);
        expect(css, contains('flex: 0 0 100%'));
        expect(css, contains('scroll-snap-align: start'));
        final body = bodyOf(html);
        expect('data-thor="PageView"'.allMatches(body), hasLength(1));
        expect(body, contains('one'));
        expect(body, contains('three'));
        for (final m in RegExp('class="([^"]*)"').allMatches(body)) {
          expect(m[1]!.split(' '), hasLength(1));
        }
      },
    );

    test('vertical: snaps on y and stacks the pages', () async {
      final html = await page(
        const PageView(
          scrollDirection: Axis.vertical,
          children: [Text('a'), Text('b')],
        ),
      );
      final rule = ruleOf(html, 'PageView');
      expect(rule, contains('flex-direction: column'));
      expect(rule, contains('overflow-y: auto'));
      expect(rule, contains('scroll-snap-type: y mandatory'));
    });

    test('pageSnapping false: free scroll', () async {
      final html = await page(
        const PageView(pageSnapping: false, children: [Text('a')]),
      );
      expect(ruleOf(html, 'PageView'), isNot(contains('scroll-snap-type')));
    });

    test('reverse flips the order', () async {
      final html = await page(
        const PageView(reverse: true, children: [Text('a'), Text('b')]),
      );
      expect(ruleOf(html, 'PageView'), contains('flex-direction: row-reverse'));
    });

    test('PageView.builder builds itemCount pages', () async {
      final html = await page(
        PageView.builder(
          itemCount: 4,
          itemBuilder: (context, i) => Text('page $i'),
        ),
      );
      final body = bodyOf(html);
      for (var i = 0; i < 4; i++) {
        expect(body, contains('page $i'));
      }
      expect(body, isNot(contains('page 4')));
    });

    test('no pages is an empty scroller', () async {
      final html = await page(const PageView(children: []));
      expect(bodyOf(html), contains('data-thor="PageView"'));
    });

    test('a ScrollController of a state follows and moves it', () async {
      final html = bodyOf(
        await page(
          PageView(controller: _deck.scroll, children: const [Text('a')]),
        ),
      );
      expect(html, contains('data-tsc="_Deck.scroll"'));
      expect(html, contains('data-tsc-h'));
    });

    test('a PageController of a state follows and moves it', () async {
      final html = bodyOf(
        await page(
          PageView(controller: _deck.pages, children: const [Text('a')]),
        ),
      );
      expect(html, contains('data-tsc="_Deck.pages"'));
      expect(html, contains('data-tsc-h'));
    });

    test('onPageChanged is a data-t-ev the engine reports to, with the '
        'row marked', () async {
      final html = bodyOf(
        await page(
          PageView(onPageChanged: _deck.changed, children: const [Text('a')]),
        ),
      );
      expect(html, contains('data-t-ev="page:_Deck.changed"'));
      expect(html, contains('data-tsc-h'), reason: 'the engine needs the axis');
      expect(html, isNot(contains('data-tsc=')), reason: 'no controller');
    });

    test('a vertical PageView reports pages without the row marker', () async {
      final html = bodyOf(
        await page(
          PageView(
            scrollDirection: Axis.vertical,
            onPageChanged: _deck.changed,
            children: const [Text('a')],
          ),
        ),
      );
      expect(html, contains('data-t-ev="page:_Deck.changed"'));
      expect(html, isNot(contains('data-tsc-h')));
    });

    test(
      'a method with an argument of its own gets the page after it',
      () async {
        final html = bodyOf(
          await page(
            PageView(
              onPageChanged: _deck.mark.withArg('deck'),
              children: const [Text('a')],
            ),
          ),
        );
        expect(html, contains('data-t-ev="page:_Deck.mark"'));
        expect(html, contains('data-tx='));
      },
    );

    test('PageView.builder takes it too', () async {
      final html = bodyOf(
        await page(
          PageView.builder(
            itemCount: 2,
            onPageChanged: _deck.changed,
            itemBuilder: (context, i) => Text('p$i'),
          ),
        ),
      );
      expect(html, contains('data-t-ev="page:_Deck.changed"'));
    });

    test('without it, a PageView is what it was: no engine markers', () async {
      final html = bodyOf(await page(const PageView(children: [Text('a')])));
      expect(html, isNot(contains('data-t-ev')));
      expect(html, isNot(contains('data-tsc')));
    });

    test('fills its slot like Flutter\'s: width and height', () async {
      final html = await page(
        const Column(
          children: [
            Expanded(child: PageView(children: [Text('a')])),
          ],
        ),
      );
      final rule = ruleOf(html, 'PageView');
      expect(rule, contains('min-height: 0'));
    });

    test('accepts physics, allowImplicitScrolling like Flutter code', () async {
      final html = await page(
        const PageView(
          physics: NeverScrollableScrollPhysics(),
          allowImplicitScrolling: true,
          children: [Text('a')],
        ),
      );
      expect(bodyOf(html), contains('PageView'));
    });

    test(
      'NeverScrollableScrollPhysics: the visitor cannot scroll it',
      () async {
        final html = await page(
          const PageView(
            physics: NeverScrollableScrollPhysics(),
            children: [Text('a'), Text('b')],
          ),
        );
        // `hidden` still lets a ScrollController move it (a tab bar drives it).
        final rule = ruleOf(html, 'PageView');
        expect(rule, contains('overflow-x: hidden'));
        expect(rule, isNot(contains('overflow-x: auto')));
      },
    );

    test('keyboard: the scroller itself takes focus, with a ring', () async {
      final html = await page(const PageView(children: [Text('a'), Text('b')]));
      expect(bodyOf(html), contains('tabindex="0"'));
      expect(stylesOf(html), contains(':focus-visible'));
      // Not when the visitor cannot scroll it: nothing to do with a key.
      final fixed = await page(
        const PageView(
          physics: NeverScrollableScrollPhysics(),
          children: [Text('a')],
        ),
      );
      expect(bodyOf(fixed), isNot(contains('tabindex')));
    });

    test('padEnds is accepted (one full page: nothing to pad)', () async {
      final html = await page(
        const PageView(padEnds: false, children: [Text('a')]),
      );
      expect(bodyOf(html), contains('PageView'));
    });

    test(
      'nested PageViews: one scroller each, vertical in horizontal',
      () async {
        final html = await page(
          const PageView(
            children: [
              PageView(
                scrollDirection: Axis.vertical,
                children: [Text('a'), Text('b')],
              ),
              Text('c'),
            ],
          ),
        );
        expect('data-thor="PageView"'.allMatches(bodyOf(html)), hasLength(2));
        expect(stylesOf(html), contains('scroll-snap-type: y mandatory'));
        expect(stylesOf(html), contains('scroll-snap-type: x mandatory'));
      },
    );

    test('pages of different heights share the view\'s height', () async {
      final html = await page(
        const PageView(
          children: [
            SizedBox(height: 40, child: Text('short')),
            SizedBox(height: 400, child: Text('tall')),
          ],
        ),
      );
      // The slot is the view's (flex stretch), not the page's content.
      expect(ruleOf(html, 'PageView'), isNot(contains('align-items')));
    });
  });
}
