/// The `<head>` of a page of the site: title, description and Open Graph.
library;

import 'package:thor_ui/router.dart' show OpenGraph, PageMeta, PageRequest;

import '../i18n/docs_locale.dart';

/// The card every page shares (`web/og.png`, 1200×630).
const defaultCard = '/og.png';

/// How the root layout shows the title of every page below it
/// (`PageMeta.titleTemplate`: `%s` is the page's own title), in [t]'s language.
String siteTitleTemplate(AppLocalizations t) =>
    t.siteTitleTemplate('%s', t.siteName);

/// [title] as the tab shows it. The server applies the layouts' template to
/// a page's title, but not to an error page's and not to `og:title`: those
/// go through here.
String siteTitle(AppLocalizations t, String title) =>
    t.siteTitleTemplate(title, t.siteName);

/// The meta of the page at [path] (its URL, with the language): `<title>`
/// (the root layout's template adds the site's name, unless [bare]: then the
/// layout's own title stays), description and its Open Graph tags. `og:url`
/// and `og:image` are paths: the renderer makes them absolute against the
/// site's origin (the base URL in an export). The shared bits (site name,
/// card, `twitter:card`) come from the root layout.
PageMeta docsMeta(
  PageRequest request, {
  required String title,
  required String path,
  String? description,
  String type = 'article',
  bool bare = false,
}) {
  final t = messagesOf(request);
  final full = bare ? title : siteTitle(t, title);
  return PageMeta(
    // web: a page cannot opt out of its layout's `titleTemplate`; the bare
    // page (the home) leaves its title to the layout.
    title: bare ? null : title,
    description: description,
    openGraph: OpenGraph(
      title: full,
      description: description,
      url: path,
      type: type,
    ),
  );
}
