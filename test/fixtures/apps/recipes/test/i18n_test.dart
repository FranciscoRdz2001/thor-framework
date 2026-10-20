// The recipes in two languages: Spanish at the URLs it always had, English
// under /en, the root asking the visitor, the switcher remembering.
import 'package:recipes/app.dart';
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';

void main() {
  final handler = recipesHandler();

  // A new visitor for each test: the language switcher sets a cookie.
  late ThorTestClient app;
  setUp(() => app = handler.client(origin: 'http://recipes.test'));

  Future<ThorTestResponse> get(
    String path, {
    Map<HttpHeader, String>? headers,
  }) => app.get(path, headers: headers ?? const {});

  String text(ThorTestResponse r) => r.text;

  test('Spanish keeps its URLs, English lives under /en', () async {
    final es = await get('/card');
    expect(es.status, 200);
    expect(text(es), contains('<html lang="es"'));
    expect(text(es), contains('hreflang="en" href="/en/card"'));

    final en = await get('/en');
    expect(en.status, 200);
    final html = text(en);
    expect(html, contains('<html lang="en"'));
    expect(html, contains('<title>Home · Recipes</title>'));
    expect(html, contains('thor recipes'));
    // The navigation stays in English.
    expect(html, contains('href="/en/card"'));
  });

  test('the root sends an English browser to /en, once', () async {
    final r = await get(
      '/',
      headers: {HttpHeader.acceptLanguage: 'en-GB,en;q=0.8'},
    );
    expect(r, hasStatus(302));
    expect(r, redirectsTo('/en'));

    // Chosen Spanish on the switcher: the root stays Spanish.
    final chose = await get('/en?set-locale=es');
    expect(chose, hasStatus(303));
    expect(chose, redirectsTo('/'));
    final back = await get('/', headers: {HttpHeader.acceptLanguage: 'en'});
    expect(back.status, 200);
    expect(text(back), contains('Recetas de thor'));
  });

  test('the Spanish prefix is not a second URL', () async {
    final r = await get('/es/card');
    expect(r, hasStatus(308));
    expect(r, redirectsTo('/card'));
  });

  test('a language the app lacks is a page of its own: 404', () async {
    expect((await get('/fr/card')).status, 404);
  });
}
