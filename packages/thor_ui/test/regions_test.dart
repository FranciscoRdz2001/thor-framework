@TestOn('vm')
library;

// `Region`, `LoadMore`, `Form(live:)` and `Link(fetch:)`: parts of a page the
// server draws alone (a GET to the same page with `?thor-piece=id`). A
// listing paged by a cursor, a search that updates its results and a dialog
// that shows any item: the page's own `load` reads the query, the page draws
// the pieces, and the answer to a fragment request is just that piece.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/src/engine/lazy_script.dart' show lazyScript;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

const _all = [
  'ana',
  'beto',
  'carla',
  'diego',
  'elena',
  'fede',
  'gus',
  'hugo',
  'ines',
];

class WeekState extends ThorState {
  WeekState();
  final week = state('0');
  String text() => 'week ${week.value}';
}

final weekState = WeekState();

class _Rows {
  const _Rows(this.items, this.next);
  final List<String> items;
  final String? next;
}

void main() {
  initializeThorTests();
  setUpAll(
    () => ThorState.register({
      WeekState: ThorStateType('WeekState', (state) {
        final s = state as WeekState;
        return [
          ThorMember.state('week', s.week),
          ThorMember('text', s.text, call: (_) => s.text()),
        ];
      }),
    }),
  );
  var loads = 0;
  late List<Object> errors;

  // Pages of 4 names, by `?cursor=<offset>`, filtered by `?q=`.
  _Rows rows(PageRequest request) {
    loads++;
    final q = request.uri.queryParameters['q'] ?? '';
    final start =
        int.tryParse(request.uri.queryParameters['cursor'] ?? '') ?? 0;
    final all = [
      for (final n in _all)
        if (n.contains(q)) n,
    ];
    final end = start + 4;
    return _Rows(
      all.sublist(start.clamp(0, all.length), end.clamp(0, all.length)),
      end < all.length ? '$end' : null,
    );
  }

  RouteHandler<Widget> handler() => RouteHandler<Widget>(
    renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
    onError: (request, error, stack) => errors.add(error),
    routes: [
      PageRoute<Widget, _Rows>(
        path: 'people',
        load: rows,
        build: (s) => Column(
          children: [
            const Text('header'),
            const Form(
              formMethod: FormMethod.get,
              live: 'results',
              // ignore: thor_lints/text_field_without_label
              child: TextFormField(name: 'q'),
            ),
            Region(
              id: 'results',
              child: Column(
                children: [
                  LoadMore(
                    id: 'people',
                    next: s.data.next,
                    items: [for (final n in s.data.items) Text('person $n')],
                    child: const Text('More people'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      PageRoute<Widget, void>(
        path: 'shop',
        build: (s) => const Column(
          children: [
            Text('catalog'),
            Dialog(
              id: 'product',
              child: Region(id: 'product-body', child: Text('empty')),
            ),
            Link(
              href: RouteUrl('/shop/mug'),
              fetch: FragmentFetch(
                piece: 'detail',
                into: 'product-body',
                open: 'product',
              ),
              child: Text('Mug'),
            ),
          ],
        ),
      ),
      // The same state is read outside the region and inside it.
      for (final sync in [true, false])
        PageRoute<Widget, void>(
          path: sync ? 'week' : 'plainweek',
          load: (r) => weekState.week.value = r.uri.queryParameters['w'] ?? '1',
          build: (s) => Column(
            children: [
              Watch(weekState.text),
              Link(
                href: RouteUrl(sync ? '/week?w=2' : '/plainweek?w=2'),
                fetch: const FragmentFetch(piece: 'grid', into: 'grid'),
                child: const Text('next'),
              ),
              Region(
                id: 'grid',
                syncState: sync,
                child: Column(children: [Watch(weekState.text)]),
              ),
            ],
          ),
        ),
      // Filter chips that fill the results in place and write the address.
      PageRoute<Widget, String>(
        path: 'filter',
        load: (r) => r.uri.queryParameters['cat'] ?? 'none',
        build: (s) => Column(
          children: [
            for (final (mode, cat) in [
              (FragmentHistory.push, 'a'),
              (FragmentHistory.replace, 'b'),
              (FragmentHistory.none, 'c'),
            ])
              Link(
                href: RouteUrl('/filter?cat=$cat'),
                fetch: FragmentFetch(
                  piece: 'list',
                  into: 'list',
                  history: mode,
                ),
                child: Text('chip $cat'),
              ),
            Region(id: 'list', child: Text('cat ${s.data}')),
          ],
        ),
      ),
      PageRoute<Widget, void>(
        path: 'shop/lamp',
        build: (s) => const Region(
          id: 'detail',
          child: Dialog(id: 'lamp', initiallyOpen: true, child: Text('Lamp')),
        ),
      ),
      PageRoute<Widget, void>(
        path: 'shop/mug',
        build: (s) => const Column(
          children: [
            Text('page chrome'),
            Region(id: 'detail', child: Text('Mug in detail')),
          ],
        ),
      ),
    ],
  );

  PageRequest get(String path) => PageRequest(
    method: HttpMethod.get,
    uri: Uri.parse('http://site.test$path'),
    headers: {HttpHeader.host: 'site.test'},
  );

  setUp(() {
    loads = 0;
    errors = [];
  });

  group('LoadMore', () {
    test('the page has the first rows and a real link to the next', () async {
      final html = (await handler().handle(get('/people'))).text;
      for (final n in ['ana', 'beto', 'carla', 'diego']) {
        expect(html, contains('person $n'));
      }
      expect(html, isNot(contains('person elena')));
      expect(html, contains('href="/people?cursor=4"'));
      expect(html, contains('rel="next"'));
      expect(
        html,
        contains(
          'data-thor-lazy="/people?cursor=4&amp;thor-piece=results%3Apeople"',
        ),
      );
      expect(html, contains('data-thor-lazy-as="replace"'));
      expect(html, contains('data-thor-lazy-on="click"'));
      expect(html, contains('More people'));
      expect(RegExp(RegExp.escape(lazyScript)).allMatches(html), hasLength(1));
    });

    test('the fragment is the next rows and the next control', () async {
      // (the list is in the `results` region: its piece is `results:people`)
      final r = await handler().handle(
        get('/people?cursor=4&thor-piece=results:people'),
      );
      expect(r.status, 200);
      final html = r.text;
      for (final n in ['elena', 'fede', 'gus', 'hugo']) {
        expect(html, contains('person $n'));
      }
      expect(html, isNot(contains('person ana')));
      expect(html, isNot(contains('header')));
      expect(html, isNot(contains('<html')));
      expect(
        html,
        contains(
          'data-thor-lazy="/people?cursor=8&amp;thor-piece=results%3Apeople"',
        ),
      );
      expect(html, contains('href="/people?cursor=8"'));
      expect(r.headers['x-robots-tag'], contains('noindex'));
      expect(loads, 1, reason: 'one backend read for the fragment');
      expect(errors, isEmpty);
    });

    test('the last page has no control', () async {
      final r = await handler().handle(
        get('/people?cursor=8&thor-piece=results:people'),
      );
      expect(r.text, contains('person ines'));
      expect(r.text, isNot(contains('More people')));
      expect(r.text, isNot(contains('data-thor-lazy')));
    });

    test('the rest of the query is kept in the next page', () async {
      final r = await handler().handle(
        get('/people?q=e&thor-piece=results:people'),
      );
      expect(r.status, 200);
      expect(r.text, contains('person beto'));
      // `e` matches beto, diego, elena, fede, hugo, ines: five rows.
      expect(r.text, contains('person beto'));
      expect(r.text, contains('href="/people?q=e&amp;cursor=4"'));
    });

    test('a visible trigger asks by itself', () async {
      Widget list(LoadMoreTrigger t) => LoadMore(
        id: 'v',
        items: const [Text('row')],
        next: '2',
        trigger: t,
        child: const Text('More'),
      );
      final h = RouteHandler<Widget>(
        renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
        onError: (request, error, stack) {},
        routes: [
          PageRoute<Widget, void>(
            path: 'scroll',
            build: (s) => list(LoadMoreTrigger.visible),
          ),
        ],
      );
      final html = (await h.handle(get('/scroll'))).text;
      expect(html, contains('data-thor-lazy-on="visible"'));
    });

    test('a bad id or param is refused', () async {
      final h = RouteHandler<Widget>(
        renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
        onError: (request, error, stack) => errors.add(error),
        routes: [
          PageRoute<Widget, void>(
            path: 'bad',
            build: (s) => const LoadMore(
              id: 'a b',
              items: [],
              next: '1',
              child: Text('More'),
            ),
          ),
        ],
      );
      final r = await h.handle(get('/bad'));
      expect(r.status, 500);
      expect('${errors.single}', contains('THOR-R035'));
    });

    test('outside a routed page it is just the rows', () async {
      final html = await renderHtml(
        const ThorApp(
          child: LoadMore(
            id: 'x',
            items: [Text('one'), Text('two')],
            next: '3',
            child: Text('More'),
          ),
        ),
      );
      expect(html, contains('one'));
      expect(html, contains('two'));
      expect(html, isNot(contains('data-thor-lazy')));
    });
  });

  group('Region and Form(live:)', () {
    test('the form asks for the region, and the page carries both', () async {
      final html = (await handler().handle(get('/people?q=a'))).text;
      expect(html, contains('data-thor-live="results"'));
      expect(html, contains('data-thor-live-ms="350"'));
      expect(html, contains('method="get"'));
      expect(html, contains('data-thor-region="results"'));
      // The region holds what the page drew for this query.
      expect(html, contains('person ana'));
    });

    test('the fragment is the region alone, drawn for the query', () async {
      final r = await handler().handle(get('/people?q=gus&thor-piece=results'));
      expect(r.status, 200);
      expect(r.text, contains('person gus'));
      expect(r.text, isNot(contains('person ana')));
      expect(r.text, isNot(contains('header')));
      expect(r.text, isNot(contains('<form')));
      expect(r.text, isNot(contains('data-thor-region')));
      expect(loads, 1);
    });

    test('a new search keeps its query in the control it brings', () async {
      final r = await handler().handle(get('/people?q=e&thor-piece=results'));
      expect(
        r.text,
        contains(
          'data-thor-lazy="/people?q=e&amp;cursor=4'
          '&amp;thor-piece=results%3Apeople"',
        ),
      );
    });

    test('the region asked for is not drawn twice', () async {
      var builds = 0;
      final h = RouteHandler<Widget>(
        renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
        onError: (request, error, stack) {},
        routes: [
          PageRoute<Widget, void>(
            path: 'once',
            build: (s) => Region(
              id: 'r',
              child: Builder(
                builder: (context) {
                  builds++;
                  return const Text('inside');
                },
              ),
            ),
          ),
        ],
      );
      await h.handle(get('/once?thor-piece=r'));
      expect(builds, 1);
    });

    test('an unknown region is a 404', () async {
      final r = await handler().handle(get('/people?thor-piece=nope'));
      expect(r.status, 404);
    });

    test('live needs a GET form', () {
      expect(
        () => Form(live: 'results', child: const Text('x')),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a region outside a routed page is just its content', () async {
      final html = await renderHtml(
        const ThorApp(
          child: Region(id: 'x', child: Text('plain')),
        ),
      );
      expect(html, contains('plain'));
      expect(html, isNot(contains('data-thor-region')));
    });
  });

  group('Link(fetch:)', () {
    test(
      'the link names the region of the other page and where it goes',
      () async {
        final html = (await handler().handle(get('/shop'))).text;
        expect(html, contains('href="/shop/mug"'));
        expect(html, contains('data-thor-lazy="/shop/mug?thor-piece=detail"'));
        expect(html, contains('data-thor-lazy-as="into"'));
        expect(html, contains('data-thor-lazy-into="product-body"'));
        expect(html, contains('data-thor-lazy-open="product"'));
        expect(html, contains('data-thor-lazy-on="click"'));
        expect(html, contains('data-thor-region="product-body"'));
        expect(
          RegExp(RegExp.escape(lazyScript)).allMatches(html),
          hasLength(1),
        );
      },
    );

    test('the other page answers its region alone', () async {
      final r = await handler().handle(get('/shop/mug?thor-piece=detail'));
      expect(r.status, 200);
      expect(r.text, contains('Mug in detail'));
      expect(r.text, isNot(contains('page chrome')));
    });

    test('history is an attribute only when asked for', () async {
      final html = (await handler().handle(get('/filter'))).text;
      expect(html, contains('data-thor-lazy-history="push"'));
      expect(html, contains('data-thor-lazy-history="replace"'));
      expect(
        RegExp('data-thor-lazy-history').allMatches(html),
        hasLength(2),
        reason: 'FragmentHistory.none writes nothing',
      );
      expect(html, contains('href="/filter?cat=a"'));
    });

    test('a query in the href is kept', () {
      const link = Link(
        href: RouteUrl('/shop/mug?color=red#top'),
        fetch: FragmentFetch(piece: 'detail', into: 'b'),
        child: Text('x'),
      );
      final attrs = link.wrapData.attributes;
      expect(attrs['data-thor-lazy'], '/shop/mug?color=red&thor-piece=detail');
      expect(attrs.containsKey('data-thor-lazy-open'), isFalse);
    });
  });

  group('Region(syncState:)', () {
    test('the answer carries the states the page already has', () async {
      final r = await handler().handle(get('/week?w=3&thor-piece=grid'));
      expect(r.status, 200);
      expect(r.text, contains('week 3'));
      expect(r.text, contains('data-thor-lazy-json data-thor-lazy-sync'));
      expect(r.text, contains('"WeekState.week":"3"'));
    });

    test('by default a state the page has is not sent again', () async {
      final r = await handler().handle(get('/plainweek?w=3&thor-piece=grid'));
      expect(r.text, contains('week 3'));
      expect(r.text, isNot(contains('data-thor-lazy-json')));
      expect(r.text, isNot(contains('data-thor-lazy-sync')));
    });

    test('a region that reads no state sends none', () async {
      final r = await handler().handle(get('/people?q=gus&thor-piece=results'));
      expect(r.text, isNot(contains('data-thor-lazy-sync')));
    });
  });

  group('the loader script, in node over the server\'s own HTML', () {
    final hasNode = () {
      try {
        return Process.runSync('node', ['--version']).exitCode == 0;
      } on ProcessException {
        return false;
      }
    }();

    // The body of a page, up to its scripts, as the browser would parse it.
    String bodyOf(String html) =>
        RegExp(r'<body[^>]*>([\s\S]*?)<script').firstMatch(html)![1]!;

    /// Runs [steps] (JS, with `$` = the harness) against [page]'s body, the
    /// loader and the fragments the server answers for [urls].
    Future<Map<String, Object?>> run(
      String path,
      List<String> urls,
      String steps, {
      Map<String, Object> extra = const {},
    }) async {
      final h = handler();
      final page = bodyOf((await h.handle(get(path))).text);
      final fragments = <String, Object>{
        for (final u in urls) u: (await h.handle(get(u))).text,
        ...extra,
      };
      final program =
          '''
require('fs');
eval(require('fs').readFileSync('test/support/mini_dom.js', 'utf8'));
const input = JSON.parse(process.argv[1]);
const D = document, calls = [], listeners = {};
D.addEventListener = (t, f) => (listeners[t] ||= []).push(f);
globalThis.MutationObserver = class { observe() {} };
const streams = [];
D.documentElement.dispatchEvent = (e) => streams.push(e);
globalThis.navigator = {};
globalThis.location = { href: 'http://site.test$path', reload() { calls.push(['reload']); } };
globalThis.history = {
  state: null,
  replaceState: (s, t, u) => calls.push(['replaceState', u]),
  pushState: (s, t, u) => { history.state = s; calls.push(['pushState', u]); },
};
const winListeners = {};
globalThis.addEventListener = (t, f) => (winListeners[t] ||= []).push(f);
globalThis.FormData = class {
  constructor(f) { this.p = f.querySelectorAll('input').map((i) => [i.getAttribute('name'), i.value ?? '']); }
  [Symbol.iterator]() { return this.p[Symbol.iterator](); }
};
let fail = false;
const delays = [];
globalThis.fetch = (u, o) => {
  calls.push(['fetch', u]);
  if (fail) return Promise.reject(new Error('offline'));
  const v = input.fragments[u], body = Array.isArray(v) ? v.shift() : v;
  const ms = delays.shift() || 0;
  return new Promise((res) => setTimeout(() => res({ ok: true, headers: { get: () => null }, text: () => Promise.resolve(body) }), ms));
};
const root = miniDom.parseHtml(input.page);
D.body.append(...root.childNodes);
const tick = (ms = 20) => new Promise((r) => setTimeout(r, ms));
const click = (el, extra = {}) => {
  const ev = { target: el, defaultPrevented: false, button: 0, preventDefault() { this.defaultPrevented = true; }, ...extra };
  listeners.click.forEach((f) => f(ev));
  return ev;
};
const words = (n) => n.nodeType === 3 ? [n.data] : n.localName === 'style' ? [] : n.childNodes.flatMap(words);
const text = (el) => words(el).join(' ').replace(/\\s+/g, ' ').trim();
const out = {};
eval(input.script);
(async () => { $steps; console.log(JSON.stringify(out)); })();
''';
      final result = Process.runSync('node', [
        '-e',
        program,
        jsonEncode({
          'page': page,
          'fragments': fragments,
          'script': lazyScript,
        }),
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      return jsonDecode((result.stdout as String).trim().split('\n').last)
          as Map<String, Object?>;
    }

    test(
      'a synced region swap hands the engine the states\' JSON',
      () async {
        final out = await run(
          '/week?w=1',
          ['/week?w=2&thor-piece=grid'],
          r'''
          const region = D.querySelector('[data-thor-region="grid"]');
          const mine = D.createElement('script');
          mine.setAttribute('id', 'thor-state');
          mine.textContent = '{"WeekState.week":"1","Other.x":2}';
          D.body.append(mine);
          out.before = text(region);
          click(D.querySelector('a'));
          await tick();
          out.after = text(region);
          out.events = streams.length;
          out.sync = streams[0].detail.sync;
          out.merged = JSON.parse(mine.textContent);
        ''',
        );
        expect(out['before'], 'week 1');
        expect(out['after'], 'week 2');
        expect(out['events'], 1);
        expect(jsonDecode(out['sync']! as String), {'WeekState.week': '2'});
        expect(out['merged'], {'WeekState.week': '2', 'Other.x': 2});
      },
      skip: hasNode ? false : 'node is not installed',
    );

    test(
      'a plain region swap sends no sync',
      () async {
        final out = await run(
          '/plainweek?w=1',
          ['/plainweek?w=2&thor-piece=grid'],
          r'''
          click(D.querySelector('a'));
          await tick();
          out.events = streams.length;
          out.sync = streams[0].detail.sync;
        ''',
        );
        expect(out['events'], 1);
        expect(out['sync'], isIn([0, null]));
      },
      skip: hasNode ? false : 'node is not installed',
    );

    test(
      'a refresh event asks the region again from the page\'s URL',
      () async {
        final out = await run(
          '/people?q=gus',
          ['/people?q=gus&thor-piece=results'],
          r'''
          const region = D.querySelector('[data-thor-region="results"]');
          out.before = text(region);
          listeners['thor:region'].forEach((f) => f({ detail: 'results' }));
          out.busy = region.getAttribute('aria-busy');
          await tick();
          out.after = text(region);
          out.busyAfter = region.getAttribute('aria-busy');
          out.calls = calls.map((c) => c.join(' '));
          // not a region, or not an id: nothing is asked
          listeners['thor:region'].forEach((f) => f({ detail: 'nope' }));
          listeners['thor:region'].forEach((f) => f({ detail: 'a"]b' }));
          listeners['thor:region'].forEach((f) => f({ detail: null }));
          await tick();
          out.callsAfter = calls.length;
        ''',
          extra: {'/people?q=gus&thor-piece=results': 'fresh rows'},
        );
        expect(out['before'], 'person gus');
        expect(out['busy'], 'true');
        expect(out['after'], 'fresh rows');
        expect(out['busyAfter'], isNull);
        expect(out['calls'], ['fetch /people?q=gus&thor-piece=results']);
        expect(out['callsAfter'], 1);
      },
      skip: hasNode ? false : 'node is not installed',
    );

    test(
      'a refresh drops the answer of an earlier one still on its way',
      () async {
        final out = await run(
          '/people?q=gus',
          [],
          r'''
          const region = D.querySelector('[data-thor-region="results"]');
          delays.push(120, 0);
          const ask = () => listeners['thor:region'].forEach((f) => f({ detail: 'results' }));
          ask(); // slow: the stale one
          ask(); // fast: the newer one
          await tick(250);
          out.after = text(region);
          out.calls = calls.length;
        ''',
          extra: {
            '/people?q=gus&thor-piece=results': ['old answer', 'new answer'],
          },
        );
        expect(out['after'], 'new answer');
        expect(out['calls'], 2);
      },
      skip: hasNode ? false : 'node is not installed',
    );

    test(
      'a failed refresh keeps the content and clears the busy mark',
      () async {
        final out = await run('/people?q=gus', [], r'''
          const region = D.querySelector('[data-thor-region="results"]');
          const before = text(region);
          fail = true;
          listeners['thor:region'].forEach((f) => f({ detail: 'results' }));
          await tick();
          out.same = text(region) == before;
          out.busy = region.getAttribute('aria-busy');
        ''');
        expect(out['same'], isTrue);
        expect(out['busy'], isNull);
      },
      skip: hasNode ? false : 'node is not installed',
    );

    test(
      'a region a link filled is refreshed from the link\'s fragment',
      () async {
        final out = await run(
          '/shop',
          ['/shop/mug?thor-piece=detail'],
          r'''
          const link = D.querySelector('[data-thor-lazy-as="into"]');
          const dialog = D.getElementById('product');
          dialog.matches = () => false;
          dialog.showModal = () => { dialog.open = true; };
          const region = D.querySelector('[data-thor-region="product-body"]');
          click(link);
          await tick();
          calls.length = 0;
          listeners['thor:region'].forEach((f) => f({ detail: 'product-body' }));
          await tick();
          out.calls = calls.map((c) => c.join(' '));
          out.text = text(region);
        ''',
        );
        expect(out['calls'], ['fetch /shop/mug?thor-piece=detail']);
        expect(out['text'], 'Mug in detail');
      },
      skip: hasNode ? false : 'node is not installed',
    );

    test(
      'Link(fetch: history: push) writes the address once the region is in',
      () async {
        final out = await run(
          '/filter',
          ['/filter?cat=a&thor-piece=list'],
          r'''
          const region = D.querySelector('[data-thor-region="list"]');
          const chip = (t) => D.querySelectorAll('a').find((a) => text(a) == t);
          out.before = text(region);
          click(chip('chip a'));
          out.early = calls.map((c) => c[0]);
          await tick();
          out.after = text(region);
          click(chip('chip a'));
          await tick();
          out.calls = calls.map((c) => c.join(' '));
        ''',
        );
        expect(out['before'], 'cat none');
        expect(out['early'], ['fetch'], reason: 'the URL waits for the swap');
        expect(out['after'], 'cat a');
        expect(out['calls'], [
          'fetch /filter?cat=a&thor-piece=list',
          'pushState /filter?cat=a',
        ], reason: 'a second click on the same link adds no entry');
      },
      skip: hasNode ? false : 'node is not installed',
    );

    test(
      'Link(fetch: history: replace) replaces; none leaves the address alone',
      () async {
        final out = await run(
          '/filter',
          ['/filter?cat=b&thor-piece=list', '/filter?cat=c&thor-piece=list'],
          r'''
          const chip = (t) => D.querySelectorAll('a').find((a) => text(a) == t);
          click(chip('chip b'));
          await tick();
          click(chip('chip c'));
          await tick();
          out.calls = calls.map((c) => c.join(' '));
          out.region = text(D.querySelector('[data-thor-region="list"]'));
        ''',
        );
        expect(out['calls'], [
          'fetch /filter?cat=b&thor-piece=list',
          'replaceState /filter?cat=b',
          'fetch /filter?cat=c&thor-piece=list',
        ]);
        expect(out['region'], 'cat c');
      },
      skip: hasNode ? false : 'node is not installed',
    );

    test(
      'back and forward ask the region again for the URL they land on',
      () async {
        final out = await run(
          '/filter',
          ['/filter?cat=a&thor-piece=list', '/filter?thor-piece=list'],
          r'''
          const region = D.querySelector('[data-thor-region="list"]');
          const chip = (t) => D.querySelectorAll('a').find((a) => text(a) == t);
          click(chip('chip a'));
          await tick();
          calls.length = 0;
          // Back: the browser puts the first URL back and fires popstate.
          location.href = 'http://site.test/filter';
          winListeners.popstate.forEach((f) => f({}));
          await tick();
          out.back = text(region);
          // Forward: the second URL again.
          location.href = 'http://site.test/filter?cat=a';
          winListeners.popstate.forEach((f) => f({}));
          await tick();
          out.forward = text(region);
          // Same URL as shown: nothing to ask.
          calls.length = 0;
          winListeners.popstate.forEach((f) => f({}));
          await tick();
          out.quiet = calls.length;
          out.history = calls.map((c) => c[0]);
        ''',
          extra: {'/filter?thor-piece=list': 'cat none'},
        );
        expect(out['back'], 'cat none');
        expect(out['forward'], 'cat a');
        expect(out['quiet'], 0);
      },
      skip: hasNode ? false : 'node is not installed',
    );

    test(
      'a popstate whose request fails reloads the page',
      () async {
        final out = await run(
          '/filter',
          ['/filter?cat=a&thor-piece=list'],
          r'''
          const chip = (t) => D.querySelectorAll('a').find((a) => text(a) == t);
          click(chip('chip a'));
          await tick();
          calls.length = 0;
          fail = true;
          location.href = 'http://site.test/filter';
          winListeners.popstate.forEach((f) => f({}));
          await tick();
          out.calls = calls.map((c) => c[0]);
        ''',
        );
        expect(out['calls'], ['fetch', 'reload']);
      },
      skip: hasNode ? false : 'node is not installed',
    );

    test(
      'no popstate work when no link used history',
      () async {
        final out = await run('/filter', [], r'''
          winListeners.popstate.forEach((f) => f({}));
          await tick();
          out.calls = calls.length;
        ''');
        expect(out['calls'], 0);
      },
      skip: hasNode ? false : 'node is not installed',
    );

    test(
      'a modal dialog drawn open inside a fragment is upgraded on arrival',
      () async {
        final h = handler();
        final lamp = (await h.handle(get('/shop/lamp?thor-piece=detail'))).text;
        final out = await run(
          '/shop',
          [],
          r'''
          Object.getPrototypeOf(D.createElement('dialog')).showModal = function () {
            calls.push(['showModal', this.id, this.hasAttribute('open')]);
          };
          D.getElementById('product').matches = () => false;
          click(D.querySelector('[data-thor-lazy-as="into"]'));
          await tick();
          out.calls = calls.filter((c) => c[1] == 'lamp');
          out.mark = D.getElementById('lamp').hasAttribute('data-thor-open');
        ''',
          extra: {'/shop/mug?thor-piece=detail': lamp},
        );
        expect(out['calls'], [
          ['showModal', 'lamp', false],
        ]);
        expect(out['mark'], isFalse);
      },
      skip: hasNode ? false : 'node is not installed',
    );

    test(
      'Load more: the next rows and control replace the link',
      () async {
        final out = await run(
          '/people',
          [
            '/people?cursor=4&thor-piece=results%3Apeople',
            '/people?cursor=8&thor-piece=results%3Apeople',
          ],
          r'''
          const region = D.querySelector('[data-thor-region="results"]');
          const more = () => region.querySelector('[data-thor-lazy]');
          out.before = text(region);
          const first = more();
          const ev = click(first);
          out.prevented = ev.defaultPrevented;
          await tick();
          out.after = text(region);
          out.href = more().getAttribute('href');
          out.old = first.parentNode == null;
          out.focused = D.activeElement.textContent;
          click(more());
          await tick();
          out.last = text(region);
          out.controls = region.querySelectorAll('[data-thor-lazy]').length;
          out.calls = calls.filter((c) => c[0] == 'fetch').map((c) => c[1]);
        ''',
        );
        expect(out['before'], contains('person diego More people'));
        expect(out['prevented'], isTrue);
        expect(out['after'], contains('person diego person elena'));
        expect(out['after'], contains('person hugo More people'));
        expect(out['href'], '/people?cursor=8');
        expect(out['old'], isTrue);
        expect(out['focused'], 'person elena');
        expect(out['last'], contains('person ines'));
        expect(out['controls'], 0, reason: 'the last page has no control');
        expect(out['calls'], [
          '/people?cursor=4&thor-piece=results%3Apeople',
          '/people?cursor=8&thor-piece=results%3Apeople',
        ]);
      },
      skip: hasNode ? false : 'node is not installed',
    );

    test(
      'a modified click, or a failed request, goes to the link',
      () async {
        final out = await run('/people', [], r'''
        const a = D.querySelector('[data-thor-lazy]');
        a.href = '/people?cursor=4';
        out.ctrl = click(a, { ctrlKey: true }).defaultPrevented;
        out.middle = click(a, { button: 1 }).defaultPrevented;
        out.fetched = calls.length;
        fail = true;
        click(a);
        await tick();
        out.went = location.href;
        out.state = a.getAttribute('data-thor-lazy-state');
      ''');
        expect(out['ctrl'], isFalse);
        expect(out['middle'], isFalse);
        expect(out['fetched'], 0);
        expect(out['went'], '/people?cursor=4');
        expect(out['state'], 'error');
      },
      skip: hasNode ? false : 'node is not installed',
    );

    test(
      'a live form: debounced, one answer, same URL, same field',
      () async {
        final out = await run(
          '/people',
          ['/people?q=gus&thor-piece=results'],
          r'''
          const form = D.querySelector('form');
          const input = form.querySelector('input');
          input.form = form;
          const region = D.querySelector('[data-thor-region="results"]');
          const type = (v) => {
            input.value = v;
            listeners.input.forEach((f) => f({ target: input }));
          };
          type('g'); type('gu'); type('gus');
          out.beforeWait = calls.length;
          await tick(450);
          out.after = text(region);
          out.calls = calls.map((c) => c.join(' '));
          out.sameInput = form.querySelector('input') === input;
          const ev = { target: form, defaultPrevented: false, preventDefault() { this.defaultPrevented = true; } };
          listeners.submit.forEach((f) => f(ev));
          out.enterPrevented = ev.defaultPrevented;
        ''',
        );
        expect(out['beforeWait'], 0, reason: 'nothing asked while typing');
        expect(out['after'], 'person gus');
        expect(out['calls'], [
          'fetch /people?q=gus&thor-piece=results',
          'replaceState /people?q=gus',
        ]);
        expect(out['sameInput'], isTrue);
        expect(out['enterPrevented'], isTrue);
      },
      skip: hasNode ? false : 'node is not installed',
    );

    test(
      'a link with fetch: fills the region once and opens the dialog',
      () async {
        final out = await run(
          '/shop',
          ['/shop/mug?thor-piece=detail'],
          r'''
          const link = D.querySelector('[data-thor-lazy-as="into"]');
          const dialog = D.getElementById('product');
          dialog.matches = (s) => s != ':popover-open' && false;
          dialog.showModal = () => { dialog.open = true; calls.push(['showModal']); };
          const region = D.querySelector('[data-thor-region="product-body"]');
          out.before = text(region);
          click(link);
          await tick();
          out.after = text(region);
          dialog.open = false;
          click(link);
          await tick();
          out.calls = calls.map((c) => c.join(' '));
        ''',
        );
        expect(out['before'], 'empty');
        expect(out['after'], 'Mug in detail');
        expect(out['calls'], [
          'fetch /shop/mug?thor-piece=detail',
          'showModal',
          'showModal',
        ]);
      },
      skip: hasNode ? false : 'node is not installed',
    );
  });
}
