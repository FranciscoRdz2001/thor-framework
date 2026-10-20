// The pages of the slide part of the `transitions` browser check: three
// documents (`/a`, `/b`, `/c`), each linking to the next, all with
// `PageTransition.slide()`; `/a` also has a form that posts to `/post` (the
// check answers it with a redirect) and a link to `/plain`, a document that
// opts into a cross-fade only (one side of the pair slides).
//
//   dart run packages/thor_ui/tool/slide_pages.dart <out dir>
import 'dart:io';

import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main(List<String> args) async {
  initializeThorTests();
  const pages = ['a', 'b', 'c'];
  for (var i = 0; i < pages.length; i++) {
    final next = pages[(i + 1) % pages.length];
    final html = await renderDocument(
      ThorApp(
        navigation: const PageNavigation(
          transition: PageTransition.slide(),
          prefetch: null,
        ),
        child: Column(
          children: [
            Text('Page ${pages[i]}'),
            Link(href: RouteUrl('/$next'), child: Text('To $next')),
            if (pages[i] == 'a') ...[
              const Link(href: RouteUrl('/plain'), child: Text('To plain')),
              Form(
                // A raw post the check redirects: the action API needs a
                // page route, and these pages are static documents.
                // ignore: thor_lints/untyped_form_action
                action: '/post',
                child: FilledButton(
                  onPressed: () {},
                  buttonType: ButtonType.submit,
                  child: const Text('Send'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    File('${args.single}/${pages[i]}.html').writeAsStringSync(html);
  }
  // A page that fades: only one side of a pair slides.
  File('${args.single}/plain.html').writeAsStringSync(
    await renderDocument(
      const ThorApp(
        navigation: PageNavigation(
          transition: PageTransition.fade(),
          prefetch: null,
        ),
        child: Column(
          children: [
            Text('Page plain'),
            Link(href: RouteUrl('/a'), child: Text('To a')),
          ],
        ),
      ),
    ),
  );
}
