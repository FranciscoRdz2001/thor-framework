@TestOn('vm')
library;

// A page with the web layer and nothing else: `web.dart` brings the
// widgets and the routes' types, so one import is enough.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/web.dart';

PageMeta meta(PageState<String> state) => PageMeta(title: state.data);

Widget build(BuildContext context, PageState<String> state) => Box(
  style: tw('flex flex-col gap-2 p-4'),
  children: [
    H1(text: state.data),
    const Text('made with one import'),
    FlexBox(gap: 8.px, children: const [Text('a'), Text('b')]),
  ],
);

final _request = PageRequest(
  method: HttpMethod.get,
  uri: Uri.parse('http://site.test/'),
);

void main() {
  setUpAll(initializeThorTests);

  test('widgets, routes and the web layer come from web.dart alone', () async {
    final html = await renderDocument(
      ThorApp(
        child: Builder(
          builder: (context) => build(
            context,
            PageState<String>(request: _request, data: 'Tarjeta'),
          ),
        ),
      ),
    );
    expect(html, contains('<h1'));
    expect(html, contains('made with one import'));
    expect(meta(PageState<String>(request: _request, data: 'x')).title, 'x');
  });
}
