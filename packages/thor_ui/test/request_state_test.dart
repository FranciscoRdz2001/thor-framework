// A page's state written in its `load` belongs to that request only:
// concurrent requests that write the
// same signal and await never see each other's value.
import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

final _probe = Signal(0);

void main() {
  final handler = RouteHandler<Widget>(
    renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
    onError: (request, error, stack) {},
    routes: [
      PageRoute<Widget, int>(
        path: 'scope',
        load: (r) async {
          final v = int.parse(r.queryParameters['v']!);
          _probe.value = v;
          // Later requests write while this one waits.
          await Future<void>.delayed(Duration(milliseconds: 40 - v * 4));
          return v;
        },
        build: (s) => Text('asked ${s.data} saw ${_probe.value}'),
      ),
    ],
  );

  Future<String> get(int v) async => (await handler.handle(
    PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://site.test/scope?v=$v'),
      headers: const {HttpHeader.host: 'site.test'},
    ),
  )).text;

  test('a value written in load stays in its request', () async {
    final pages = await Future.wait([for (var v = 1; v <= 8; v++) get(v)]);
    for (var v = 1; v <= 8; v++) {
      expect(pages[v - 1], contains('asked $v saw $v'));
    }
    // Nothing reached the value every request starts from.
    expect(_probe.value, 0);
  });
}
