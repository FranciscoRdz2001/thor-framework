// The page reset draws a bare `<button>` like its surroundings, in the
// lowest layer, so no widget's own class has to fight it.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Widget body) async {
  final handler = RouteHandler<Widget>(
    renderer: WidgetRenderer(
      app: (page) => ThorApp(child: page),
      styles: thorResetStyles,
      shareStyles: false,
    ),
    onError: (request, error, stack) {},
    routes: [routePage<void>(path: '', build: (c, s) => body)],
  );
  final res = await handler.handle(
    PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://site.test/'),
      headers: {HttpHeader.host: 'site.test'},
    ),
  );
  return res.text;
}

void main() {
  test('thorResetStyles resets the browser button in thor.reset', () async {
    final out = await _page(const html.button([Widget.text('Share')]));
    final start = out.indexOf('@layer thor.reset {');
    expect(start, isNonNegative);
    final reset = out.substring(start, out.indexOf('</style>', start));
    final rule = RegExp(
      r'(?:^|[,}\s])button\s*\{([^}]*)\}',
    ).firstMatch(reset)?[1];
    expect(rule, isNotNull);
    final flat = rule!.replaceAll(RegExp(r'\s+'), ' ');
    for (final d in [
      'font: inherit',
      'color: inherit',
      'background: none',
      'border: 0',
      'padding: 0',
    ]) {
      expect(flat, contains(d));
    }
  });

  test('a Material button keeps its own look over the reset', () async {
    final out = await _page(
      FilledButton(onPressed: () {}, child: const Text('Buy')),
    );
    final start = out.indexOf('@layer thor.props');
    expect(start, isNonNegative);
    expect(
      out.substring(start, out.indexOf('</style>', start)),
      contains('background-color'),
    );
  });
}
