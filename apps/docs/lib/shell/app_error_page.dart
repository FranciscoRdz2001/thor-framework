import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../core/content/library.dart';
import '../core/content/page_meta.dart' show siteTitle;
import '../core/i18n/docs_locale.dart';
import '../modules/search/search_routes.dart';
import 'docs_scaffold.dart';

/// A missing page (or an error), in the frame, with ways back.
class AppErrorPage extends ErrorPage {
  /// The page.
  const AppErrorPage();

  /// Its tab title and description, in the reader's language (the
  /// framework's default would be just the status code).
  @override
  PageMeta meta(ErrorState state) {
    final t = messagesOf(state.request);
    final notFound = state.status == StatusCode.notFound;
    return PageMeta(
      // web: the server applies the layout's `titleTemplate` to pages, not to
      // an error page's own meta: the same template, by hand.
      title: siteTitle(
        t,
        notFound ? t.errorNotFoundTitle : t.errorGenericTitle,
      ),
      description: notFound ? t.errorNotFoundLead : t.errorGenericLead,
    );
  }

  @override
  Widget build(BuildContext context, ErrorState state) {
    final t = context.l10n;
    final notFound = state.status == StatusCode.notFound;
    return DocsScaffold(
      // A path that is no page of the site: nothing is marked as current.
      path: state.request.routePath,
      indexed: false,
      sidebar: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: StudioSpacing.xl,
        children: [
          StudioPageHeader(
            eyebrow: '${state.status}',
            title: notFound ? t.errorNotFoundTitle : t.errorGenericTitle,
            lead: notFound ? t.errorNotFoundLead : t.errorGenericLead,
          ),
          StudioCardGrid(
            children: [
              StudioLinkCard(
                icon: StudioIcons.bookOpen,
                title: t.pageWhatIsThor,
                description: t.errorStartSubtitle,
                href: context.localized(guideBySlug('que-es-thor')!.path),
              ),
              StudioLinkCard(
                icon: StudioIcons.search,
                title: t.searchTitle,
                description: t.searchDescription,
                href: context.localized(searchRoute.link()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
