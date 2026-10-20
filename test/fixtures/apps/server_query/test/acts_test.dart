// The `/acts` lab through the test client: a typed action
// argument from a button, and the flash that follows the redirect.
import 'package:server_query/app.dart';
import 'package:server_query/core/repositories/acts_repository.dart';
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';

/// Whether the page's snack bar is showing a message (the inline script also
/// names the attribute).
bool _flashing(String html) =>
    RegExp('<[^>]*id="thor-toast"[^>]*data-t-on').hasMatch(html);

void main() {
  setUp(actsRepository.reset);

  test(
    'a button posts its int argument, the page shows the flash once',
    () async {
      final app = appHandler().client();
      final page = await app.get('/acts');
      expect(page.text, contains('name="thor-arg"'));

      final answer = await app.post('/acts?/delete', form: {'thor-arg': '4'});
      expect(answer, redirectsTo('/acts'));
      expect(actsRepository.orders.map((o) => o.id), [3, 5]);
      expect(app.cookie('thor-flash'), isNotNull);

      final after = await app.follow(answer);
      expect(after.text, contains('Pedido eliminado'));
      expect(_flashing(after.text), isTrue);
      // Shown once: the cookie went with the page that drew it.
      expect(app.cookie('thor-flash'), isNull);
      expect(_flashing((await app.get('/acts')).text), isFalse);
    },
  );

  test('an int and an enum in one value, typed', () async {
    final app = appHandler().client();
    await app.post('/acts?/assign', form: {'thor-arg': '5~luis'});
    expect(actsRepository.orders.last.owner, 'luis');
  });

  test('what a button could not send is a 400, and changes nothing', () async {
    final app = appHandler().client();
    for (final form in <Map<String, Object?>>[
      {},
      {'thor-arg': 'abc'},
      {'thor-arg': '3~root'},
    ]) {
      final path = form['thor-arg'] == '3~root'
          ? '/acts?/assign'
          : '/acts?/delete';
      expect(await app.post(path, form: form), hasStatus(400), reason: '$form');
    }
    expect(actsRepository.orders, hasLength(3));
  });

  test('a cross-origin post never runs an action', () async {
    final app = appHandler().client();
    final r = await app.post(
      '/acts?/delete',
      form: {'thor-arg': '3'},
      headers: {HttpHeader.origin: 'http://evil.test'},
    );
    expect(r, hasStatus(403));
    expect(actsRepository.orders, hasLength(3));
  });

  test('a flash survives a guard redirect and is text, not markup', () async {
    final app = appHandler().client();
    final first = await app.post('/acts?/hostile');
    expect(first, redirectsTo('/acts/next'));
    final page = await app.follow(first);
    expect(page.text, contains('&lt;img src=x onerror=alert(1)&gt;'));
    expect(page.text, isNot(contains('<img src=x')));
  });
}
