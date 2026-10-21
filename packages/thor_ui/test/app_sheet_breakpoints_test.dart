// The app stylesheet's size-class rules follow the theme's breakpoints.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/html.dart' show css;
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(ThemeData theme, List<StyleRule> styles) async {
  final r = WidgetRenderer(
    app: (page) => ThorApp(theme: theme, child: page),
    styles: styles,
    shareStyles: false,
  );
  final handler = RouteHandler<Widget>(
    renderer: r,
    onError: (request, error, stack) {},
    routes: [
      routePage<void>(path: '', build: (c, s) => const Text('x')),
    ],
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
  const rule = StyleProps(opacity: .5);
  const site = Breakpoints(medium: 640, expanded: 768);

  test('WindowSizeClass.media takes the app breakpoints', () async {
    final html = await page(ThemeData(breakpoints: site), [
      WindowSizeClass.medium.media(breakpoints: site, [
        css('.a').props(rule),
      ]),
      WindowSizeClass.large.media([css('.b').props(rule)]),
    ]);
    expect(html, contains('(min-width: 640px)'));
    expect(html, contains('(min-width: 1200px)')); // the default
    expect(html, isNot(contains('(min-width: 600px)')));
  });

  test('css.minWidth and css.maxWidth take any width', () async {
    final html = await page(ThemeData(), [
      css.minWidth(920, [css('.a').props(rule)]),
      css.maxWidth(919.98, [css('.b').props(rule)]),
    ]);
    expect(html, contains('@media screen and (min-width: 920px)'));
    expect(html, contains('@media screen and (max-width: 919.98px)'));
  });
}
