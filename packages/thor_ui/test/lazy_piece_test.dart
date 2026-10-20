@TestOn('vm')
library;

// `LazyPiece`, a part of the page the server draws only
// when the browser asks for it (a GET to the same page with `?thor-piece=id`):
// the page carries the placeholder and a link, the answer is that piece's
// HTML with the classes it needs.
import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/src/engine/lazy_script.dart' show lazyScript;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class LazyCounter extends ThorState {
  LazyCounter();
  final count = state(0);
  String label() => '${count.value}';
}

final lazyCounter = LazyCounter();

void main() {
  initializeThorTests();
  setUpAll(
    () => ThorState.register({
      LazyCounter: ThorStateType('LazyCounter', (state) {
        final s = state as LazyCounter;
        return [
          ThorMember.state('count', s.count),
          ThorMember('label', s.label, call: (_) => s.label()),
        ];
      }),
    }),
  );

  var loads = 0;
  var pageLoads = 0;
  late List<Object> errors;

  Widget lazy(String id, {LazyTrigger? trigger, bool fail = false}) =>
      LazyPiece<List<String>>(
        id: id,
        trigger: trigger ?? LazyTrigger.open,
        load: (request) async {
          loads++;
          if (fail) throw const NotFound();
          return ['$id one', '$id two'];
        },
        builder: (context, rows) => Container(
          color: const Color(0xFF123ABC),
          child: Column(children: [for (final r in rows) Text(r)]),
        ),
        fallback: Link(
          href: RouteUrl('/all/$id'),
          child: const Text('See all'),
        ),
      );

  RouteHandler<Widget> handler() => RouteHandler<Widget>(
    renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
    onError: (request, error, stack) => errors.add(error),
    routes: [
      PageRoute<Widget, void>(
        path: 'shop',
        load: (r) => pageLoads++,
        meta: (s) => const PageMeta(title: 'Shop'),
        build: (s) => Column(
          children: [
            const Text('header'),
            ExpansionTile(title: const Text('Food'), children: [lazy('food')]),
            ExpansionTile(
              title: const Text('Home'),
              children: [lazy('home', trigger: LazyTrigger.visible)],
            ),
          ],
        ),
      ),
      PageRoute<Widget, void>(
        path: 'plain',
        load: (r) {},
        build: (s) => const Text('plain page'),
      ),
      PageRoute<Widget, void>(
        path: 'broken',
        load: (r) {},
        build: (s) => lazy('broken', fail: true),
      ),
      PageRoute<Widget, void>(
        path: 'state',
        load: (r) {
          lazyCounter.count.value = 5;
        },
        build: (s) => LazyPiece<void>(
          id: 'counter',
          load: (request) async {},
          builder: (context, _) => Watch(lazyCounter.label),
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
    pageLoads = 0;
    errors = [];
  });

  test('the page has the placeholder and the link, not the content', () async {
    final r = await handler().handle(get('/shop'));
    expect(r.status, 200);
    final html = r.text;
    expect(html, contains('data-thor-lazy="/shop?thor-piece=food"'));
    expect(html, contains('data-thor-lazy="/shop?thor-piece=home"'));
    expect(html, contains('data-thor-lazy-on="open"'));
    expect(html, contains('data-thor-lazy-on="visible"'));
    // The link is what shows without JavaScript.
    expect(html, contains('href="/all/food"'));
    expect(html, contains('See all'));
    // The content is not drawn, nor loaded.
    expect(html, isNot(contains('food one')));
    expect(loads, 0);
    // The loader, once, inline and constant (its hash is in the deploy guide).
    expect(RegExp(RegExp.escape(lazyScript)).allMatches(html), hasLength(1));
  });

  test('a page with no LazyPiece ships no loader', () async {
    final r = await handler().handle(get('/plain'));
    expect(r.text, isNot(contains('data-thor-lazy')));
    expect(r.text, isNot(contains(lazyScript)));
  });

  test('the query of the page stays in the fragment URL', () async {
    final r = await handler().handle(get('/shop?sort=price&x=1'));
    expect(
      r.text,
      contains('data-thor-lazy="/shop?sort=price&amp;x=1&amp;thor-piece=food"'),
    );
  });

  test('a repeated query key keeps every value in the fragment URL', () async {
    final r = await handler().handle(get('/shop?f=red&f=size-9'));
    expect(
      r.text,
      contains('data-thor-lazy="/shop?f=red&amp;f=size-9&amp;thor-piece=food"'),
    );
  });

  test('the fragment is that piece alone, with its classes', () async {
    final r = await handler().handle(get('/shop?thor-piece=food'));
    expect(r.status, 200);
    final html = r.text;
    expect(html, contains('food one'));
    expect(html, contains('food two'));
    expect(html, isNot(contains('home one')));
    // Not a document, and not the rest of the page.
    expect(html, isNot(contains('<html')));
    expect(html, isNot(contains('header')));
    expect(html, isNot(contains('See all')));
    // The class only the piece has comes as a rule.
    expect(html.toLowerCase(), contains('123abc'));
    expect(html, contains('<style>'));
    expect(r.headers['content-type'], startsWith('text/html'));
    // A fragment is no page: robots keep out.
    expect(r.headers['x-robots-tag'], contains('noindex'));
    expect(loads, 1);
    expect(errors, isEmpty);
  });

  test('the second piece is its own answer', () async {
    final r = await handler().handle(get('/shop?thor-piece=home'));
    expect(r.text, contains('home one'));
    expect(r.text, isNot(contains('food one')));
  });

  test('an unknown piece is a 404, and so is a failed load', () async {
    final missing = await handler().handle(get('/shop?thor-piece=nope'));
    expect(missing.status, 404);
    final broken = await handler().handle(get('/broken?thor-piece=broken'));
    expect(broken.status, 404);
  });

  test('the values of the states the piece uses travel with it', () async {
    final r = await handler().handle(get('/state?thor-piece=counter'));
    expect(r.status, 200);
    expect(r.text, contains('LazyCounter'));
    expect(r.text, contains('data-thor-lazy-json'));
    expect(r.text, contains('5'));
  });

  test('the page is drawn for the fragment too: its load runs', () async {
    await handler().handle(get('/shop?thor-piece=food'));
    expect(pageLoads, 1);
  });

  test('a query that does not decode is just the page', () async {
    final r = await handler().handle(get('/shop?x=%ff&thor-piece=food'));
    expect(r.status, 200);
    expect(r.text, contains('<html'));
    expect(r.text, contains('header'));
  });

  test('the loader refuses an answer that is a whole document', () {
    expect(lazyScript, contains('<(!doctype|html)'));
  });

  test('a piece outside a routed page is its fallback alone', () async {
    final html = await renderHtml(ThorApp(child: lazy('x')));
    expect(html, contains('See all'));
    expect(html, isNot(contains('data-thor-lazy=')));
  });
}
