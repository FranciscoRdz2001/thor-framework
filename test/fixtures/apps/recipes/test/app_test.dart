// Every recipe renders, and each one's flow works end to end on the
// server (the handler, no network): filters, validation, the dialog's
// action, the protected module, sign in and out, the state's markers.
import 'package:recipes/app.dart';
import 'package:recipes/router.dart';
import 'package:recipes/session.dart';
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';
import 'package:thor_ui/router.dart';

void main() {
  final handler = RouteHandler(
    routes: router.routes,
    renderer: recipesRenderer(),
  );

  // A new visitor (empty cookie jar) for each test.
  late ThorTestClient app;
  setUp(() => app = handler.client());

  test('every recipe renders inside the shell', () async {
    for (final path in [
      homeRoute.link(),
      cardRoute.link(),
      listRoute.link(),
      tableRoute.link(),
      formRoute.link(),
      dialogRoute.link(),
      panelRoute.link(),
      counterRoute.link(),
      loginRoute.link(),
    ]) {
      final r = await app.get(path);
      expect(r.status, 200, reason: path);
      expect(r.text, contains('<h1'), reason: path);
      // The sidebar, and the drawer for narrow screens.
      expect(r.text, contains('<nav'), reason: path);
      expect(r.text, contains('<dialog'), reason: path);
      expect(r.text, contains('· Recetas</title>'), reason: path);
    }
  });

  test('the list filters on the server, from the URL', () async {
    final all = await app.get('/list');
    expect(all.text, contains('6 de 6 productos'));
    final tea = await app.get('/list?cat=tea');
    expect(tea.text, contains('2 de 6 productos'));
    expect(tea.text, contains('Matcha ceremonial'));
    expect(tea.text, isNot(contains('Molino manual')));
    final none = await app.get('/list?q=zzz');
    expect(none.text, contains('Nada coincide'));
    // An unknown category is no filter, not an error.
    expect((await app.get('/list?cat=pizza')).text, contains('6 de 6'));
  });

  test('the table sorts and filters on the server, from the URL', () async {
    int at(String html, String text) => html.indexOf(text);
    final byName = (await app.get('/table')).text;
    expect(byName, contains('aria-sort="ascending"'));
    expect(at(byName, 'Chiapas lavado'), lessThan(at(byName, 'Veracruz')));
    final cheapLast = (await app.get('/table?sort=price&dir=desc')).text;
    expect(cheapLast, contains('aria-sort="descending"'));
    expect(
      at(cheapLast, 'Molino manual'),
      lessThan(at(cheapLast, 'Oolong de montaña')),
    );
    // The sorted header flips; the others start ascending, keeping the search.
    final search = (await app.get('/table?q=chiapas&sort=price')).text;
    expect(search, contains('1 de 6 productos'));
    expect(
      search,
      contains('href="/table?q=chiapas&amp;sort=price&amp;dir=desc"'),
    );
    expect(search, contains('href="/table?q=chiapas&amp;sort=product"'));
    // An unknown order is the default, not an error.
    expect((await app.get('/table?sort=pizza')).status, 200);
  });

  test('the form: native checks in the HTML, the server re-checks', () async {
    final page = await app.get('/form');
    expect(page.text, contains('required'));
    expect(page.text, contains('type="email"'));
    expect(page.text, contains('minlength="10"'));
    final bad = await app.post(
      '/form?/send',
      form: {'name': '', 'email': 'ana', 'message': 'hola'},
    );
    expect(bad.status, 422);
    expect(bad.text, contains('Escribe tu nombre.'));
    expect(bad.text, contains('Ese correo no parece válido.'));
    expect(bad.text, contains('Cuéntanos un poco más'));
    // A rule the browser can't run: only the server catches it.
    final link = await app.post(
      '/form?/send',
      form: {
        'name': 'Ana',
        'email': 'ana@example.com',
        'message': 'mira http://spam.example',
      },
    );
    expect(link.status, 422);
    expect(link.text, contains('Sin enlaces, por favor.'));
    // A tampered form (no fields at all) never reaches the action's code.
    expect((await app.post('/form?/send')).status, 422);
    // What the visitor typed stays.
    expect(bad.text, contains('value="ana"'));
    final ok = await app.post(
      '/form?/send',
      form: {
        'name': 'Ana',
        'email': 'ana@example.com',
        'message': 'Quiero un molino.',
      },
    );
    expect(ok.status, 303);
    expect(ok.headers['location'], '/form?sent=1');
    expect((await app.get('/form?sent=1')).text, contains('¡Gracias!'));
  });

  test('the dialog opens natively and posts its action', () async {
    final page = await app.get('/dialog');
    expect(page.text, contains('commandfor="confirm"'));
    expect(page.text, contains('command="show-modal"'));
    final deleted = await app.post('/dialog?/delete');
    expect(deleted.status, 303);
    expect(deleted.headers['location'], '/dialog?deleted=1');
  });

  test('the dashboard computes on the server', () async {
    final r = await app.get('/panel');
    expect(r.text, contains('Agotados'));
    expect(r.text, contains('<progress'));
    // The chart card spans every column of the same grid.
    expect(r.text, contains('grid-column: 1 / -1'));
  });

  test('the private module: guests go to sign in, with the way back', () async {
    final guest = await app.get('/account');
    expect(guest.status, anyOf(302, 303, 307));
    expect(guest.headers['location'], '/login?back=%2Faccount');
    // A forged cookie is a guest.
    app.setCookie(sessionCookie, 'Ana.x');
    final forged = await app.get('/account');
    expect(forged.headers['location'], startsWith('/login'));
  });

  test('sign in, see the account, sign out', () async {
    // The form keeps the page's query (the way back) in its action.
    final form = await app.get('/login?back=/account');
    expect(form.text, contains('action="?back=/account"'));
    expect((await app.get('/login')).text, contains('action="/login"'));

    final wrong = await app.post(
      '/login?/signIn',
      form: {'email': 'ana@example.com', 'password': 'nope'},
    );
    expect(wrong, hasStatus(401));
    expect(wrong.text, contains('no coinciden'));
    expect(wrong.text, contains('value="ana@example.com"'));

    final ok = await app.post(
      '/login?back=/account&/signIn',
      form: {'email': 'ana@example.com', 'password': 'recipes123'},
    );
    expect(ok, hasStatus(303));
    expect(ok, redirectsTo('/account'));
    final account = await app.follow(ok);
    expect(account.status, 200);
    expect(account.text, contains('Hola, Ana.'));

    final out = await app.post('/account?/signOut');
    expect(out, hasStatus(303));
    expect(app.cookies, isEmpty);

    // Never an open redirect.
    final away = await app.post(
      '/login?back=//evil.example&/signIn',
      form: {'email': 'ana@example.com', 'password': 'recipes123'},
    );
    expect(away.headers['location'], '/account');
  });

  test('the state: engine markers, first paint from the server', () async {
    final r = await app.get('/counter');
    expect(r.text, contains('12 me gusta'));
    expect(r.text, contains('data-t-on'));
    expect(r.text, contains('Me gusta'));
  });

  test('an unknown page is a 404', () async {
    expect((await app.get('/no-existe')).status, 404);
  });
}
