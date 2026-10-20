import 'package:server_query/app.dart';
import 'package:server_query/core/repositories/lab_repository.dart';
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';

// `query(fn, ssr: false)`: the page does not wait for the function, goes
// out waiting with the states the browser will switch to, and the
// browser's call still answers.
final _handler = appHandler();

void main() {
  test('the page goes out at once and the function never runs', () async {
    final before = Map.of(labRepository.lazyCalls);
    final clock = Stopwatch()..start();
    final r = await _handler.client().get('/lazy');
    clock.stop();
    expect(r.status, 200);
    // `lazyRows` takes 600 ms: a page that waited for it would not be here.
    expect(clock.elapsedMilliseconds, lessThan(450));
    expect(labRepository.lazyCalls, before);
    expect(r.text, contains('rows: cargando'));
    expect(r.text, contains('variante cargando'));
  });

  test('the done states are in the HTML with no initialData', () async {
    final r = await _handler.client().get('/lazy');
    // Patches or templates of the live state, drawn with a placeholder.
    expect(r.text, contains('rows: listo'));
    expect(r.text, contains('variante móvil'));
    expect(r.text, contains('variante escritorio'));
    expect(r.text, contains('eco:'));
    expect(r.text, contains('broken: listo'));
  });

  test('the page still names its queries, so the browser can ask', () async {
    final r = await _handler.client().get('/lazy');
    for (final id in ['LazyState.rows', 'LazyState.echo', 'LazyState.broken']) {
      expect(r.text, contains('"$id"'), reason: id);
    }
    final answer = await _handler.client().callQuery(
      'LazyState.rows',
      path: '/lazy',
      body: const <String, Object?>{},
      headers: {
        HttpHeader.origin: 'http://localhost',
        HttpHeader.contentType: 'application/json',
      },
    );
    expect(answer.status, 200);
    expect(labRepository.lazyCalls['lazyRows'], isNotNull);
  });
}
