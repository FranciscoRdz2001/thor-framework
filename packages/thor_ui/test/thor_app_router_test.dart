import 'package:test/test.dart';
import 'package:thor_ui/html.dart' show css;
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

class _Card extends ThorPage<void> {
  const _Card();

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      Text('card ${state.request.locale ?? '-'} ${state.request.routePath}');
}

final _cardRoute = ThorRoute('/tarjeta', const _Card());
final _router = ThorRouter([ThorRoute('/', const _Card()), _cardRoute]);

final _bilingual = ThorApp.router(
  routerConfig: _router,
  supportedLocales: const [Locale('es'), Locale('en')],
  localeStrategy: LocaleStrategy.prefixExceptDefault,
  theme: ThemeData(),
  styles: [css('body').props(const StyleProps(margin: EdgeInsets.all(3)))],
);

final _single = ThorApp.router(routerConfig: _router);

RouteHandler<Widget> _handler(ThorApp app) => RouteHandler<Widget>(
  routes: app.routes,
  locales: app.localeRouting,
  renderer: WidgetRenderer.router(app),
);

PageRequest _get(String path, {Map<HttpHeader, String> headers = const {}}) =>
    PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://s.test$path'),
      headers: {HttpHeader.host: 's.test', ...headers},
    );

void main() {
  test('the locale is resolved before the route is matched', () async {
    final h = _handler(_bilingual);
    final en = await h.handle(_get('/en/tarjeta'));
    expect(en.status, 200);
    expect(en.text, contains('card en /tarjeta'));
    expect(en.text, contains('<html lang="en"'));
    final es = await h.handle(_get('/tarjeta'));
    expect(es.text, contains('card es /tarjeta'));
    // The default has no prefix: /es/… goes back to it.
    final prefixed = await h.handle(_get('/es/tarjeta'));
    expect(prefixed.status, 308);
    expect(prefixed.headers['location'], '/tarjeta');
  });

  test('the root asks the cookie, then Accept-Language', () async {
    final h = _handler(_bilingual);
    final byCookie = await h.handle(
      _get('/', headers: {HttpHeader.cookie: 'locale=en'}),
    );
    expect(byCookie.status, 302);
    expect(byCookie.headers['location'], '/en');
    final byHeader = await h.handle(
      _get('/', headers: {HttpHeader.acceptLanguage: 'en-US,en;q=0.9'}),
    );
    expect(byHeader.headers['location'], '/en');
  });

  test(
    'every page is drawn in the one app: its theme and its styles',
    () async {
      final page = (await _handler(_bilingual).handle(_get('/tarjeta'))).text;
      expect(page, contains('--t-primary'));
      expect(page, contains('margin: 3px'));
      expect(_bilingual.page(const Text('x')).styles, same(_bilingual.styles));
      expect(_bilingual.page(const Text('x')).theme, same(_bilingual.theme));
    },
  );

  test('an app in one language has no locale routing', () async {
    expect(_single.localeRouting, isNull);
    final r = await _handler(_single).handle(_get('/tarjeta'));
    expect(r.text, contains('card - /tarjeta'));
    expect((await _handler(_single).handle(_get('/en/tarjeta'))).status, 404);
  });

  test('only the router form has routes', () {
    expect(_single.routerConfig, same(_router));
    expect(const ThorApp(child: Text('x')).routerConfig, isNull);
    expect(() => const ThorApp(child: Text('x')).routes, throwsStateError);
  });
}
