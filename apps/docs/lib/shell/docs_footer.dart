import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/router.dart' show RequestScope;
import 'package:thor_ui/thor_ui.dart';

import '../core/content/library.dart';
import '../core/i18n/docs_locale.dart';
import '../modules/api/api_routes.dart';
import '../modules/changes/changes_routes.dart';
import '../modules/errors/errors_routes.dart';
import '../modules/search/search_routes.dart';
import 'docs_scaffold.dart';
import 'docs_search_dialog.dart';

/// The footer of every page: the brand, the site's sections and the
/// project's links.
class DocsFooter extends StatelessWidget {
  /// The footer, its content [maxWidth] wide at most (the page's).
  const DocsFooter({super.key, this.maxWidth = docsPageWidth});

  /// The page's width, so the footer lines up with its columns.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    String page(String slug) => context.localized(guideBySlug(slug)!.path);
    final prefix = RequestScope.maybeOf(context)?.publicPathPrefix ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StudioFooter(
          // Lined up with the page's columns.
          maxWidth: maxWidth,
          // The columns start at their titles: the brand starts at the top of
          // its cell too, not in the middle of the row.
          brand: Styled(
            style: const StyleProps(alignSelf: CrossAxisAlignment.start),
            child: StudioBrand(name: 'Thor', href: context.localized('/')),
          ),
          sections: [
            StudioNavSection(
              title: t.footerStart,
              items: [
                for (final slug in const [
                  'que-es-thor',
                  'instalacion',
                  'primera-app',
                  'desde-flutter',
                ])
                  StudioNavDestination(
                    guideBySlug(slug)!.title(t),
                    href: page(slug),
                  ),
              ],
            ),
            StudioNavSection(
              title: t.footerReference,
              items: [
                StudioNavDestination(
                  t.navComponents,
                  href: page(componentsSection),
                ),
                StudioNavDestination(
                  t.navExamples,
                  href: page(examplesSection),
                ),
                StudioNavDestination(
                  t.navApi,
                  href: context.localized(apiHomePath),
                ),
                StudioNavDestination(
                  t.footerErrors,
                  href: context.localized(errorsRoute.link()),
                ),
                StudioNavDestination(t.pageCli, href: page('cli')),
              ],
            ),
            StudioNavSection(
              title: t.footerResources,
              items: [
                StudioNavDestination(t.footerGithub, href: repositoryUrl),
                StudioNavDestination(
                  t.navChanges,
                  href: context.localized(changesRoute.link()),
                ),
              ],
            ),
          ],
          legal: t.footerLegal,
        ),
        const DocsSearchDialog(),
        // The search pill promises ⌘K: this script keeps it, and goes to the
        // search page it is told about here.
        html.script(
          src: '$prefix/search-shortcut.js',
          defer: true,
          attributes: {
            'data-search-href':
                '$prefix${context.localized(searchRoute.link())}',
          },
        ),
      ],
    );
  }
}
