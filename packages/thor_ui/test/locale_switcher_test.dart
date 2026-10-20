import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  RouteHandler<Widget> handler(LocaleStrategy strategy) => RouteHandler(
    renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
    onError: (request, error, stack) {},
    locales: LocaleRouting(
      supportedLocales: [
        const Locale('es'),
        const Locale('en'),
        const Locale('pt', 'BR'),
      ],
      strategy: strategy,
    ),
    routes: [
      PageRoute<Widget, void>(
        path: 'about',
        build: (s) => LocaleSwitcher(labels: {const Locale('pt', 'BR'): 'PT'}),
      ),
    ],
  );

  PageRequest get(String path) => PageRequest(
    method: HttpMethod.get,
    uri: Uri.parse('http://site.test$path'),
    headers: {HttpHeader.host: 'site.test'},
  );

  test('a link per locale that sets it, the current one marked', () async {
    final r = await handler(
      LocaleStrategy.prefixExceptDefault,
    ).handle(get('/en/about?q=a%26b'));
    final html = utf8.decode(r.body);
    expect(html, contains('<nav'));
    expect(html, contains('aria-label="Language"'));
    expect(
      html,
      contains(
        'href="/en/about?q=a%26b&amp;set-locale=es" hreflang="es" lang="es"',
      ),
    );
    expect(
      html,
      contains(
        'href="/en/about?q=a%26b&amp;set-locale=en" hreflang="en" lang="en" '
        'aria-current="true"',
      ),
    );
    expect(html, contains('>Español<'));
    expect(html, contains('>PT<'), reason: 'labels win over endonyms');
  });

  test('the link lands on the chosen locale and remembers it', () async {
    final h = handler(LocaleStrategy.prefixExceptDefault);
    final r = await h.handle(get('/en/about?set-locale=es'));
    expect(r.status, 303);
    expect(r.headers['location'], '/about');
    expect(r.cookies.single, startsWith('locale=es;'));
  });

  test('outside a routed page with locales it draws nothing', () async {
    final plain = RouteHandler<Widget>(
      renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
      onError: (request, error, stack) {},
      routes: [
        PageRoute<Widget, void>(
          path: 'about',
          build: (s) => const LocaleSwitcher(),
        ),
      ],
    );
    final html = utf8.decode((await plain.handle(get('/about'))).body);
    expect(html, isNot(contains('<nav')));
  });

  test('endonyms: the language itself, then its base, then the tag', () {
    expect(LocaleSwitcher.endonym(const Locale('es', 'MX')), 'Español');
    expect(
      LocaleSwitcher.endonym(const Locale('pt', 'BR')),
      'Português (Brasil)',
    );
    expect(LocaleSwitcher.endonym(const Locale('xx')), 'xx');
  });
}
