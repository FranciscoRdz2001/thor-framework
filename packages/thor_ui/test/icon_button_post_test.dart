// IconButton(onPost:) is the same submit as FilledButton(onPost:): it asks
// with `confirm:` when JavaScript is off and it keeps the locale prefix.
import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

class _ItemPage extends ThorPage<void> {
  const _ItemPage();

  Future<ActionResult?> remove(PageRequest request, int id) async => null;

  Future<ActionResult?> wipe(PageRequest request) async => null;

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    children: [
      IconButton(
        onPost: remove.withArg(3),
        confirm: const ConfirmSpec('Delete?'),
        icon: const Text('x'),
      ),
      IconButton(
        onPost: wipe,
        confirm: const ConfirmSpec('Wipe?'),
        icon: const Text('w'),
      ),
    ],
  );
}

class _CartPage extends ThorPage<void> {
  const _CartPage();

  Future<ActionResult?> clear(PageRequest request) async => null;

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      IconButton(onPost: clear, icon: const Text('c'));
}

void main() {
  registerPageActions({
    _CartPage: [
      PageActionMethod.request('clear', (p) => (p as _CartPage).clear),
    ],
    _ItemPage: [
      PageActionMethod.args(
        'remove',
        (p) => (p as _ItemPage).remove,
        1,
        (x) => [int.parse(x[0])],
      ),
      PageActionMethod.request('wipe', (p) => (p as _ItemPage).wipe),
    ],
  });
  final app = ThorApp.router(
    routerConfig: ThorRouter([
      ThorRoute('/item/:id', const _ItemPage()),
      ThorRoute('/cart', const _CartPage()),
    ]),
    supportedLocales: const [Locale('es'), Locale('en')],
    localeStrategy: LocaleStrategy.prefix,
  );
  final handler = RouteHandler<Widget>(
    routes: app.routes,
    locales: app.localeRouting,
    renderer: WidgetRenderer.router(app),
  );

  late String html;
  setUpAll(() async {
    final r = await handler.handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://s.test/en/item/3'),
        headers: const {HttpHeader.host: 's.test'},
      ),
    );
    expect(r.status, 200);
    html = r.text;
  });

  test('IconButton(confirm:) carries the question without JS', () {
    final buttons = RegExp(
      '<button[^>]*thor-ask[^>]*>',
    ).allMatches(html).toList();
    expect(buttons, hasLength(2));
    // The one with an argument keeps its `name`, so the question rides in
    // the formaction; the other one carries it in its own name/value.
    expect(buttons[0][0], contains('/thor-ask='));
    expect(buttons[1][0], contains('name="thor-ask"'));
  });

  test('IconButton(onPost:) posts to its own localized page', () async {
    // The action is the page's own, so it stays relative to '/en/item/3'
    // (a route path with the prefix would not match: THOR-P020 or '/item').
    expect(html, contains('formaction="?/wipe"'));
    final r = await handler.handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://s.test/en/cart'),
        headers: const {HttpHeader.host: 's.test'},
      ),
    );
    expect(r.status, 200);
    // The page's only action posts to the page itself, with its prefix.
    expect(r.text, contains('formaction="/en/cart"'));
  });
}
