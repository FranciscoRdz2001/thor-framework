import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../core/content/library.dart';
import '../../../core/i18n/docs_locale.dart';
import '../../../core/widgets/docs_side_nav.dart';
import '../../api/api_routes.dart';

/// A section of the home: a heading over its content.
class _HomeSection extends StatelessWidget {
  const _HomeSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: StudioSpacing.lg,
      children: [
        Semantics(
          headingLevel: 2,
          child: Text(
            title,
            style: text.headlineMedium.copyWith(
              fontSize: 24,
              color: scheme.onSurface,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// "Start here": installation, the first app, and the map from Flutter.
class HomeStart extends StatelessWidget {
  /// The three cards.
  const HomeStart({super.key});

  static final _pages = <(String, IconData, MessageOf)>[
    ('instalacion', StudioIcons.download, (t) => t.homeStartInstall),
    ('primera-app', StudioIcons.rocket, (t) => t.homeStartFirstApp),
    (
      'desde-flutter',
      StudioContentIcons.arrowLeftRight,
      (t) => t.homeStartFlutter,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return _HomeSection(
      title: t.homeStartHeading,
      child: StudioCardGrid(
        columns: 3,
        children: [
          for (final (slug, icon, description) in _pages)
            StudioLinkCard(
              title: guideBySlug(slug)!.title(t),
              href: context.localized(guideBySlug(slug)!.path),
              icon: icon,
              description: description(t),
            ),
        ],
      ),
    );
  }
}

/// "The guide": each of the six sections with its icon, its summary and its
/// first three pages, in three columns.
class HomeGuide extends StatelessWidget {
  /// The index.
  const HomeGuide({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final sections = [
      for (final s in guideSections)
        if (s.slug != componentsSection && s.slug != examplesSection) s,
    ];
    final link = scheme.accent;
    return _HomeSection(
      title: t.homeGuideHeading,
      child: Grid(
        layout: const GridLayout(columns: 1, gap: StudioSpacing.xl).when(
          medium: const GridLayout(columns: 2, gap: StudioSpacing.xl),
          expanded: const GridLayout(columns: 3, gap: StudioSpacing.xl),
        ),
        children: [
          for (final s in sections)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: StudioSpacing.xs,
              children: [
                Link(
                  href: RouteUrl(context.localized(s.guides.first.path)),
                  child: Row(
                    spacing: StudioSpacing.xs,
                    children: [
                      // The section's icon in the accent on its tint, as in
                      // the sidebar.
                      ExcludeSemantics(
                        child: Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scheme.accentContainer,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(
                            docsSectionIcons[s.slug]!,
                            size: 14,
                            color: scheme.accent,
                          ),
                        ),
                      ),
                      Text(
                        s.title(t),
                        style: text.titleMedium.copyWith(
                          fontSize: 15,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  s.summary(t),
                  style: text.bodyMedium.copyWith(
                    color: scheme.onSurfaceVariant!,
                  ),
                ),
                Semantics(
                  role: SemanticsRole.list,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: StudioSpacing.xxs,
                    children: [
                      for (final guide in s.guides.take(3))
                        Semantics(
                          role: SemanticsRole.listItem,
                          child: Link(
                            href: RouteUrl(context.localized(guide.path)),
                            child: Text(
                              guide.title(t),
                              style: text.bodyMedium.copyWith(
                                color: link.when(hover: scheme.onSurface),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// "Reference": the catalog, the examples and the API.
class HomeReference extends StatelessWidget {
  /// The three cards.
  const HomeReference({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return _HomeSection(
      title: t.homeReferenceHeading,
      child: StudioCardGrid(
        columns: 3,
        children: [
          StudioLinkCard(
            title: t.navComponents,
            description: t.homeComponentsSummary,
            icon: StudioIcons.layoutGrid,
            href: context.localized(guideBySlug(componentsSection)!.path),
          ),
          StudioLinkCard(
            title: t.navExamples,
            description: t.homeExamplesSummary,
            icon: StudioIcons.appWindow,
            href: context.localized(guideBySlug(examplesSection)!.path),
          ),
          StudioLinkCard(
            title: t.navApi,
            description: t.apiSummary,
            icon: StudioIcons.code,
            href: context.localized(apiHomePath),
          ),
        ],
      ),
    );
  }
}
