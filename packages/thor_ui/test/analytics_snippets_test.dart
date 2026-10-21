@TestOn('vm')
library;

// Inline tag-manager and analytics snippets in the document head
// (`WidgetRenderer(head:)` with `html.script`): they carry the request's CSP
// nonce, so the policy needs no `'unsafe-inline'`, and the loader script
// they add is allowed by its host.
import 'package:test/test.dart';
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

const _tag =
    'window.dataLayer=window.dataLayer||[];'
    'function gtag(){dataLayer.push(arguments)}'
    "gtag('js',new Date());gtag('config','G-TEST');";

void main() {
  initializeThorTests();

  RouteHandler<Widget> handler() => RouteHandler<Widget>(
    renderer: WidgetRenderer(
      app: (page) => ThorApp(child: page),
      head: [
        const html.script(
          src: 'https://www.googletagmanager.com/gtag/js?id=G-TEST',
          async: true,
        ),
        const html.script(content: _tag),
      ],
    ),
    routes: [
      LayoutRoute<Widget, void>(
        build: (s, child) => child,
        error: (e) => const Text('error'),
        middleware: contentSecurityPolicy(
          ContentSecurityPolicy(
            scriptSrc: [CspSource.host('https://www.googletagmanager.com')],
            connectSrc: [CspSource.host('https://www.google-analytics.com')],
          ),
        ),
        children: [
          PageRoute<Widget, void>(
            path: 'page',
            load: (r) {},
            build: (s) => const Text('hi'),
          ),
        ],
      ),
    ],
  );

  test('inline and external tag scripts in the head carry the nonce', () async {
    final r = await handler().handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://site.test/page'),
        headers: {HttpHeader.host: 'site.test'},
      ),
    );
    final policy = r.headers.entries
        .firstWhere((e) => e.key.toLowerCase() == 'content-security-policy')
        .value;
    final nonce = RegExp(r"'nonce-([^']+)'").firstMatch(policy)![1]!;
    final head = r.text.substring(0, r.text.indexOf('</head>'));
    expect(head, contains('<script nonce="$nonce">$_tag</script>'));
    expect(
      head,
      contains(
        '<script nonce="$nonce" '
        'src="https://www.googletagmanager.com/gtag/js?id=G-TEST" async>',
      ),
    );
    expect(policy, contains('https://www.googletagmanager.com'));
    expect(policy, contains('https://www.google-analytics.com'));
    final scripts = policy
        .split('; ')
        .firstWhere((d) => d.startsWith('script-src '));
    expect(scripts, isNot(contains("'unsafe-inline'")));
  });
}
