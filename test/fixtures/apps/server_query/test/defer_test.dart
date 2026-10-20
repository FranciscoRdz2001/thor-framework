// The `/defer` lab through the test client: it gets the page a visitor ends
// up with, every deferred value in place.
import 'package:server_query/app.dart';
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';
import 'package:thor_ui/router.dart' show HttpMethod, PageRequest;

void main() {
  test('the test client gets the complete page, no skeletons', () async {
    final page = await appHandler().client().get('/defer?ms=20');
    expect(page.status, 200);
    expect(page.text, contains('Loaded: slow value'));
    expect(page.text, contains('Loaded: slower value'));
    expect(page.text, contains('Failed: Something went wrong'));
    expect(page.text, isNot(contains('secret backend detail')));
    expect(page.text, isNot(contains('data-thor-skeleton')));
    expect(page.text, isNot(contains('<!--thor:')));
    // The state of the late content is in the page's engine setup.
    expect(page.text, contains('DeferState.increment'));
  });

  test('the same page answers in pieces to a browser', () async {
    final response = await appHandler().handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://site.test/defer?ms=20'),
        headers: const {HttpHeader.host: 'site.test'},
      ),
    );
    expect(response.stream, isNotNull);
    final chunks = await response.stream!.toList();
    expect(chunks.length, greaterThan(2));
  });
}
