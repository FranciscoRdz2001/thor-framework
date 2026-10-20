// `Redirect.back(request)`: the page the action was posted from, query
// included, so the visitor lands on the very URL the form script keeps the
// scroll for (a hand-written `Redirect(request.uri.path)` drops the query).
import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

PageRequest _post(String url) => PageRequest(
  method: HttpMethod.post,
  uri: Uri.parse('http://site.test$url'),
);

void main() {
  test('keeps the query and drops the action key', () {
    final r = Redirect.back(_post('/orders?status=paid&page=2&/delete=1'));
    expect(r.location, '/orders?status=paid&page=2');
    expect(r.status, 303);
  });

  test('a page with no query is its path', () {
    expect(Redirect.back(_post('/orders?/delete')).location, '/orders');
  });

  test('keeps the locale prefix and the encoding of the query', () {
    expect(
      Redirect.back(_post('/es/orders?q=a%20b&%2Fdelete=1')).location,
      '/es/orders?q=a%20b',
    );
  });

  test('is a plain redirect: flash and a status still apply', () {
    final r = Redirect.back(_post('/x?/a'), status: 302).flash('Hecho');
    expect(r.status, 302);
    expect(r.flashMessage?.message, 'Hecho');
    expect(r.location, '/x');
  });

  test('a path that looks like another site stays on this one', () {
    expect(
      Redirect.back(_post('//evil.test/x?/a')).location,
      isNot(startsWith('//')),
    );
  });
}
