import '../../modules/api/api_routes.dart';
import '../../modules/changes/changes_routes.dart';
import '../../modules/errors/errors_routes.dart';
import '../../modules/search/search_routes.dart';
import '../content/library.dart';

/// The part of the site a page belongs to: what the top bar marks as
/// current and what the breadcrumbs start from.
enum DocsArea {
  /// The home page.
  home,

  /// A page of the guide (every section but the catalog and the examples).
  guide,

  /// The widget catalog (a tab of the top bar with its own sidebar).
  components,

  /// The examples (a tab of the top bar with its own sidebar).
  examples,

  /// The generated API reference.
  api,

  /// The error codes.
  errors,

  /// The changelogs.
  changes,

  /// The search page.
  search,

  /// Something else (a missing page).
  none,
}

/// Where the page at [path] (the route's own, without the language) sits in
/// the site: its [area] and, for a guide, its page and section.
class DocsPlace {
  /// The place of [path].
  factory DocsPlace.of(String path) {
    final guide = allGuides.where((g) => g.path == path).firstOrNull;
    final area = switch (path) {
      '/' => DocsArea.home,
      _ when guide != null && guide.section == componentsSection =>
        DocsArea.components,
      _ when guide != null && guide.section == examplesSection =>
        DocsArea.examples,
      _ when guide != null => DocsArea.guide,
      _ when path.startsWith(apiIndexRoute.link()) => DocsArea.api,
      _ when path.startsWith(errorsRoute.link()) => DocsArea.errors,
      _ when path.startsWith(changesRoute.link()) => DocsArea.changes,
      _ when path.startsWith(searchRoute.link()) => DocsArea.search,
      _ => DocsArea.none,
    };
    return DocsPlace._(path, area, guide);
  }

  const DocsPlace._(this.path, this.area, this.guide);

  /// The route's own path.
  final String path;

  /// The part of the site.
  final DocsArea area;

  /// The guide page, when the path is one.
  final Guide? guide;

  /// The section the guide is in, when it is one.
  GuideSection? get section => guide == null ? null : sectionOfGuide(guide!);

  /// The pages the pager walks through: the guide's six sections, or the
  /// catalog's or the examples' own pages (a tab never leads into another).
  List<Guide> get _reading => switch (area) {
    DocsArea.components || DocsArea.examples => section!.guides,
    _ => [
      for (final s in guideSections)
        if (s.slug != componentsSection && s.slug != examplesSection)
          ...s.guides,
    ],
  };

  /// The page before this one in reading order, or null.
  Guide? get previous {
    final pages = _reading;
    final i = guide == null ? -1 : pages.indexOf(guide!);
    return i > 0 ? pages[i - 1] : null;
  }

  /// The page after this one in reading order, or null.
  Guide? get next {
    final pages = _reading;
    final i = guide == null ? -1 : pages.indexOf(guide!);
    return i >= 0 && i < pages.length - 1 ? pages[i + 1] : null;
  }
}
