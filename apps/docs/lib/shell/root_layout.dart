import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../core/content/page_meta.dart';
import '../core/i18n/docs_locale.dart';
import 'docs_locale_routing.dart';

/// The layout of `/` and the pages below it.
class RootLayout extends ThorLayout<void> {
  /// The one instance the build shares between requests.
  const RootLayout();

  /// Default meta for every page, in the page's language.
  @override
  PageMeta meta(PageState<void> state) {
    final t = messagesOf(state.request);
    return PageMeta(
      // The home's title (a page that sets none shows this one); the pages
      // below show theirs through the template.
      title: t.homeMetaTitle,
      titleTemplate: siteTitleTemplate(t),
      canonical: _canonical(state.request),
      description: t.siteDescription,
      openGraph: OpenGraph(
        siteName: t.siteName,
        type: 'website',
        locale: Locale.tryParse(t.siteOpenGraphLocale),
        image: defaultCard,
        imageAlt: t.siteImageAlt,
        twitterCard: 'summary_large_image',
      ),
      jsonLd: [
        {
          '@context': 'https://schema.org',
          '@type': 'WebSite',
          'name': t.siteName,
          'inLanguage': t.localeName,
        },
      ],
    );
  }

  /// The page: it builds its own frame (`DocsScaffold`), because the table
  /// of contents and the title are the page's.
  @override
  Widget build(BuildContext context, PageState<void> state, Widget child) =>
      child;
}

/// The page's own address, absolute when the request knows the site's
/// origin. A guide page shown from the default language because its own
/// language has no file is a copy: it points to the default's page.
RouteUrl _canonical(PageRequest request) {
  final routing = request.localeRouting;
  final path = request.routePath;
  final locale = localeTagOf(request);
  final own = DocsLocaleRouting.hasPage(locale, path);
  final target = routing == null
      ? request.uri.path
      : routing.pathFor(Locale.tryParse(own ? locale : defaultLocale)!, path);
  final uri = request.uri;
  return RouteUrl(
    uri.hasAuthority
        ? '${uri.origin}${request.publicPathPrefix}$target'
        : '${request.publicPathPrefix}$target',
  );
}
