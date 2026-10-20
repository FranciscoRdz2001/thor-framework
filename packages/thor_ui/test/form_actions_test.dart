// Fixture: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
// Buttons and forms that post page actions: the arguments travel WITH the
// enclosing Form's fields, an action of another page posts to that page's URL,
// a submit button in a Form is enabled, and `HiddenField` is a public form
// widget.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

final _calls = <String>[];

class CartPage extends ThorPage<void> {
  const CartPage();

  Future<ActionResult?> add(PageRequest request, String sku) async {
    final form = await request.form();
    _calls.add('add $sku qty=${form['quantity']}');
    return null;
  }

  Future<ActionResult?> addTwo(
    PageRequest request,
    String sku,
    String seller,
  ) async {
    final form = await request.form();
    _calls.add('addTwo $sku $seller qty=${form['quantity']}');
    return null;
  }

  Future<ActionResult?> clear(PageRequest request) async {
    _calls.add('clear');
    return null;
  }

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    children: [
      // Its own page: the relative `?/…`.
      FilledButton(
        onPost: const CartPage().add.withArg('own'),
        child: const Text('own'),
      ),
      // In a Form: the Form's fields and the arguments both go.
      Form(
        child: Column(
          children: [
            const TextField(name: 'quantity'),
            const HiddenField(name: 'note', value: 'n'),
            FilledButton(
              onPost: const CartPage().addTwo.withArgs('sku1', 'seller1'),
              child: const Text('in form'),
            ),
          ],
        ),
      ),
    ],
  );
}

class ProductPage extends ThorPage<void> {
  const ProductPage();

  Future<ActionResult?> buy(PageRequest request) async => null;

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    children: [
      // The route has a parameter, and this IS the page: relative.
      FilledButton(onPost: const ProductPage().buy, child: const Text('buy')),
    ],
  );
}

class HomePage extends ThorPage<void> {
  const HomePage();

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    children: [
      FilledButton(
        onPost: const CartPage().add.withArg('x'),
        child: const Text('other page'),
      ),
      Form(
        onPost: const CartPage().clear,
        child: const FilledButton(
          buttonType: ButtonType.submit,
          onPressed: null,
          child: Text('go'),
        ),
      ),
      Form(
        action: '/elsewhere',
        onPost: const CartPage().clear,
        child: const Text('explicit'),
      ),
    ],
  );
}

class NeedsParamsPage extends ThorPage<void> {
  const NeedsParamsPage();

  @override
  Widget build(BuildContext context, PageState<void> state) => FilledButton(
    onPost: const ProductPage().buy,
    child: const Text('needs a param'),
  );
}

void main() {
  registerPageActions({
    CartPage: [
      PageActionMethod.args(
        'add',
        (p) => (p as CartPage).add,
        1,
        (x) => [x[0]],
      ),
      PageActionMethod.args(
        'addTwo',
        (p) => (p as CartPage).addTwo,
        2,
        (x) => [x[0], x[1]],
      ),
      PageActionMethod.request('clear', (p) => (p as CartPage).clear),
    ],
    ProductPage: [
      PageActionMethod.request('buy', (p) => (p as ProductPage).buy),
    ],
  });
  final app = ThorApp.router(
    routerConfig: ThorRouter([
      ThorRoute('/', const HomePage()),
      ThorRoute('/cart', const CartPage()),
      ThorRoute('/p/:id', const ProductPage()),
      ThorRoute('/needs', const NeedsParamsPage()),
    ]),
  );
  final handler = RouteHandler<Widget>(
    routes: app.routes,
    renderer: WidgetRenderer.router(app),
  );
  Future<ThorResponse> get(String url) => handler.handle(
    PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://s.test$url'),
      headers: const {HttpHeader.host: 's.test'},
    ),
  );
  Future<ThorResponse> post(String url, String body) => handler.handle(
    PageRequest(
      method: HttpMethod.post,
      uri: Uri.parse('http://s.test$url'),
      headers: const {
        HttpHeader.host: 's.test',
        HttpHeader.origin: 'http://s.test',
        HttpHeader.contentType: 'application/x-www-form-urlencoded',
      },
      body: Stream.value(utf8.encode(body)),
    ),
  );
  String button(String html, String label) =>
      RegExp('<button[^>]*>$label').firstMatch(html)!.group(0)!;

  setUp(_calls.clear);

  group('arguments inside a Form (#14)', () {
    test('the button submits its Form, not the shared one', () async {
      final b = button((await get('/cart')).text, 'in form');
      expect(b, isNot(contains('form="')));
      expect(b, contains('name="thor-arg"'));
      expect(b, contains('formaction="?/addTwo"'));
    });

    test('outside a Form it still takes the shared one', () async {
      final b = button((await get('/cart')).text, 'own');
      expect(b, contains('form="thor-post"'));
      expect(b, contains('formaction="?/add"'));
    });

    test('the Form fields and the arguments arrive together', () async {
      final r = await post(
        '/cart?/addTwo',
        'quantity=3&note=n&thor-arg=sku1~seller1',
      );
      expect(r.status, 303);
      expect(_calls, ['addTwo sku1 seller1 qty=3']);
    });
  });

  group('an action of another page (#3)', () {
    test('a button posts to that page', () async {
      final b = button((await get('/')).text, 'other page');
      expect(b, contains('formaction="/cart?/add"'));
    });

    test('a Form with onPost posts to that page', () async {
      expect((await get('/')).text, contains('action="/cart?/clear"'));
    });

    test('an explicit action wins', () async {
      expect((await get('/')).text, contains('action="/elsewhere?/clear"'));
    });

    test('a button in a Form with type submit is enabled', () async {
      final b = button((await get('/')).text, 'go');
      expect(b, isNot(contains('disabled')));
      expect(b, contains('type="submit"'));
    });

    test('the only action of a route with params posts to its path', () async {
      final b = button((await get('/p/7')).text, 'buy');
      expect(b, contains('formaction="/p/7"'));
    });

    test('a path that is not UTF-8 still matches its route', () async {
      // The server routes `/p/%FF` to `/p/:id` (matched as written); the
      // page must not fail while it asks whether the request is its own.
      final r = await get('/p/%FF');
      expect(r.status, 200);
      expect(button(r.text, 'buy'), contains('formaction="'));
    });

    test('a page whose route needs params is a clear THOR-P020', () async {
      final r = await get('/needs');
      expect(r.status, 500);
    });
  });

  group('HiddenField (#15)', () {
    test('renders a hidden input from thor_ui.dart', () async {
      expect(
        (await get('/cart')).text,
        contains('<input type="hidden" name="note" value="n"'),
      );
    });
  });
}
