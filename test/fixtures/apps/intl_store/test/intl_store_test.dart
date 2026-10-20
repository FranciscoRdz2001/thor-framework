import 'dart:io';

import 'package:intl_store/cart_state.dart';
import 'package:intl_store/handler.dart';
import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart' show exportSite;
import 'package:thor_test/thor_test.dart';
import 'package:thor_ui/router.dart';

void main() {
  late RouteHandler<Object?> handler;
  late ThorTestClient shop;
  setUp(() {
    handler = storeHandler(baseUrl: 'https://shop.test');
    shop = handler.client(origin: 'http://shop.test');
  });

  test('/ sends each visitor to their language', () async {
    final es = await shop.get(
      '/',
      headers: {HttpHeader.acceptLanguage: 'es-MX'},
    );
    expect(es, hasStatus(302));
    expect(es, redirectsTo('/es'));
    final fr = await shop.get('/', headers: {HttpHeader.acceptLanguage: 'fr'});
    expect(fr, redirectsTo('/en'));
    // A visitor who chose Spanish once: the cookie wins over the browser.
    final chose = handler.client(origin: 'http://shop.test')
      ..setCookie('locale', 'es');
    final cookie = await chose.get(
      '/product/mug',
      headers: {HttpHeader.acceptLanguage: 'en'},
    );
    expect(cookie, redirectsTo('/es/product/mug'));
  });

  test('the Spanish home: messages, plurals, formats, lang', () async {
    final html = (await shop.get('/es')).text;
    expect(html, contains('<html lang="es" dir="ltr"'));
    expect(html, contains('<title>La tiendita</title>'));
    expect(html, contains('Taza de peltre'));
    expect(html, contains('12,50 € · Quedan 7'));
    expect(html, contains('1.234,50\u00a0€ · ¡Queda uno!'));
    expect(html, contains('Agotado'));
    expect(html, contains('14 mar 2024'));
    expect(html, contains('Tu carrito está vacío'));
    // The browser gets the page's locale for the cart label.
    expect(html, contains('"CartState.locale":"es"'));
    expect(
      html,
      contains(
        '<link hreflang="en" href="https://shop.test/en" rel="alternate"/>',
      ),
    );
  });

  test('the English home', () async {
    final html = (await shop.get('/en')).text;
    expect(html, contains('<html lang="en" dir="ltr"'));
    expect(html, contains('€12.50 · 7 in stock'));
    expect(html, contains('Sold out'));
    expect(html, contains('Mar 14, 2024'));
    expect(html, contains('Your cart is empty'));
    // English is the default: no locale for the browser to change.
    expect(html, isNot(contains('"CartState.locale":"es"')));
  });

  test('a name in the URL is text, not markup', () async {
    final html = (await shop.get(
      '/es?name=${Uri.encodeQueryComponent('<script>alert(1)</script>')}',
    )).text;
    expect(html, isNot(contains('<script>alert')));
    expect(html, contains('¡Hola, &lt;script&gt;'));
  });

  test('a missing product is a 404 in the page language', () async {
    final r = await shop.get('/es/product/nope');
    expect(r.status, 404);
    expect(r.text, contains('Esta página no existe.'));
    expect(r.text, contains('<html lang="es"'));
  });

  test('the language switcher links this page in the other language', () async {
    final html = (await shop.get('/es/product/mug')).text;
    expect(
      html,
      contains('href="/es/product/mug?set-locale=en" hreflang="en" lang="en"'),
    );
    expect(html, contains('aria-current="true"'));
    expect(html, contains('En la tienda desde el 14 mar 2024'));
    // Following it: the page in English, the choice in the cookie.
    final r = await shop.get('/es/product/mug?set-locale=en');
    expect(r.status, 303);
    expect(r.headers['location'], '/en/product/mug');
    expect(r.cookies.single, startsWith('locale=en;'));
  });

  test('the home is cached once per language', () async {
    await shop.get('/es');
    await shop.get('/en');
    final again = (await shop.get('/es')).text;
    expect(again, contains('La tiendita'));
    expect(handler.cachedPaths, hasLength(2));
  });

  test('the cart label is computed in the page language (browser code)', () {
    cart.locale.value = 'es';
    cart.count.value = 0;
    expect(cart.label(), 'Tu carrito está vacío');
    cart.add();
    expect(cart.label(), '1 artículo en tu carrito');
    cart.add();
    expect(cart.label(), '2 artículos en tu carrito');
    cart.locale.value = 'en';
    expect(cart.label(), '2 items in your cart');
    // A locale the app lacks (a tampered state) falls back to English.
    cart.locale.value = 'xx';
    expect(cart.label, throwsUnsupportedError);
  });

  test('the export writes both languages and a chooser at /', () async {
    final out = await Directory.systemTemp.createTemp('intl_store');
    addTearDown(() => out.delete(recursive: true));
    final report = await exportSite(
      handler,
      paths: sitePaths(),
      outDir: out.path,
    );
    expect(report.failed, isEmpty);
    expect(report.brokenLinks, isEmpty);
    for (final file in [
      'index.html',
      'en.html',
      'es.html',
      'es/product/mug.html',
      'en/product/pencil.html',
    ]) {
      expect(File('${out.path}/$file').existsSync(), isTrue, reason: file);
    }
  });
}
