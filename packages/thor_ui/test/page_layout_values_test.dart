import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

// What a page hands its layouts: a typed value the layout reads while it
// builds (the page is built first), so one route can drop the footer.
class _HideFooter {
  const _HideFooter();
}

class _Banner {
  const _Banner(this.text);
  final String text;
}

class _ShopLayout extends ThorLayout<void> {
  const _ShopLayout();

  @override
  Widget build(BuildContext context, PageState<void> state, Widget child) {
    final banner = state.fromPage<_Banner>();
    return Column(
      children: [
        if (banner != null) Text('banner ${banner.text}'),
        child,
        if (state.fromPage<_HideFooter>() == null) const Text('footer'),
      ],
    );
  }
}

class _OuterLayout extends ThorLayout<void> {
  const _OuterLayout();

  @override
  Widget build(BuildContext context, PageState<void> state, Widget child) =>
      Column(
        children: [
          child,
          Text(
            state.fromPage<_HideFooter>() == null ? 'outer-on' : 'outer-off',
          ),
        ],
      );
}

class _HomePage extends ThorPage<void> {
  const _HomePage();

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      const Text('home');
}

class _CheckoutPage extends ThorPage<String> {
  const _CheckoutPage();

  @override
  String load(PageRequest request) => request.param('step');

  @override
  List<Object> forLayouts(PageState<String> state) => [
    const _HideFooter(),
    if (state.data == 'pay') const _Banner('secure'),
  ];

  @override
  Widget build(BuildContext context, PageState<String> state) =>
      Text('checkout ${state.data}');
}

class _Lost extends ErrorPage {
  const _Lost();

  @override
  Widget build(BuildContext context, ErrorState state) => const Text('lost');
}

void main() {
  final router = ThorRouter([
    Group(
      layout: const _OuterLayout(),
      notFound: const _Lost(),
      children: [
        Group(
          layout: const _ShopLayout(),
          children: [
            ThorRoute('/', const _HomePage()),
            ThorRoute('/checkout/:step', const _CheckoutPage()),
          ],
        ),
      ],
    ),
  ]);
  final handler = RouteHandler<Widget>(
    renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
    onError: (request, error, stack) {},
    routes: router.routes,
  );

  PageRequest get(String path) => PageRequest(
    method: HttpMethod.get,
    uri: Uri.parse('http://site.test$path'),
    headers: {HttpHeader.host: 'site.test'},
  );

  test('a page that gives nothing leaves the layout as it was', () async {
    final r = await handler.handle(get('/'));
    expect(r.text, contains('footer'));
    expect(r.text, contains('outer-on'));
    expect(r.text, isNot(contains('banner')));
  });

  test(
    'a page hides the footer of its layout, and of every one above',
    () async {
      final r = await handler.handle(get('/checkout/cart'));
      expect(r.text, contains('checkout cart'));
      expect(r.text, isNot(contains('footer')));
      expect(r.text, contains('outer-off'));
      expect(r.text, isNot(contains('banner')));
    },
  );

  test('the values can depend on the page data', () async {
    final r = await handler.handle(get('/checkout/pay'));
    expect(r.text, contains('banner secure'));
    expect(r.text, isNot(contains('footer')));
  });

  test('an error page has no page, so the layout sees nothing', () async {
    final r = await handler.handle(get('/nowhere'));
    expect(r.status, 404);
    expect(r.text, contains('lost'));
    expect(r.text, contains('outer-on'));
  });
}
