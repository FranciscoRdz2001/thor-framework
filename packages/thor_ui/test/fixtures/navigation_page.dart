// The link matrix of test/e2e/checks/navigation_check.mjs: renders
// `THOR_RENDER_TO` once, with speculation rules at `immediate` eagerness so
// Chrome fetches every matching link at load. Each path says whether it
// may be prefetched (`/yes-*`) or not (`/no-*`); `__CROSS__` is replaced
// by the check with a URL of another origin on the same server.
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/server.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  initializeThor(styles: const []);
  runApp(
    Document(
      title: 'Navigation matrix',
      body: ThorApp(
        navigation: const PageNavigation(
          prefetch: SpeculationEagerness.immediate,
          exclude: ['/no-logout', '/no-admin/*'],
        ),
        child: Column(
          children: [
            const Link(href: RouteUrl('/yes-plain'), child: Text('plain')),
            const Link(
              href: RouteUrl('/yes-query?page=2&q=a'),
              child: Text('query'),
            ),
            const Link(href: RouteUrl('/yes-hash#top'), child: Text('hash')),
            const Link(
              href: RouteUrl('#same-document'),
              child: Text('same doc'),
            ),
            const Link(
              href: RouteUrl('__CROSS__/no-cross'),
              child: Text('cross'),
            ),
            const Link(
              href: RouteUrl('/no-blank'),
              newTab: true,
              child: Text('blank'),
            ),
            const Link(
              href: RouteUrl('/no-optout'),
              prefetch: false,
              child: Text('off'),
            ),
            const Link(href: RouteUrl('/no-logout'), child: Text('logout')),
            const Link(href: RouteUrl('/no-admin/users'), child: Text('admin')),
            const html.a([Text('download')], href: '/no-file', download: ''),
            const html.a(
              [Text('nofollow')],
              href: '/no-nofollow',
              attributes: {'rel': 'nofollow'},
            ),
            const Text.rich(
              TextSpan(
                children: [TextSpan(text: 'span', href: '/yes-span')],
              ),
            ),
            NavigationBar(
              selectedIndex: null,
              destinations: const [
                NavigationDestination(
                  icon: Text('a'),
                  label: 'destination',
                  href: '/yes-destination',
                ),
                NavigationDestination(
                  icon: Text('b'),
                  label: 'home',
                  href: '/',
                ),
              ],
            ),
            Form(
              action: '/no-post',
              child: FilledButton(
                onPressed: () {},
                buttonType: ButtonType.submit,
                child: const Text('post'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
