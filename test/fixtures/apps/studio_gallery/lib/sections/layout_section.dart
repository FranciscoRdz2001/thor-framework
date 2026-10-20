// The layout and navigation widgets of thor_studio, each stage in the light
// theme and in the dark one (a scoped `Theme`, so both show at once).
import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/thor_ui.dart';

import 'section_frame.dart';

final _light = StudioTheme.light(fontsPath: 'fonts');
final _dark = StudioTheme.dark(fontsPath: 'fonts');

const _sections = [
  StudioNavSection(
    title: 'Empezar',
    items: [
      StudioNavDestination('Qué es Thor', href: '#que-es'),
      StudioNavDestination('Instalación', href: '#instalacion'),
      StudioNavDestination('Tu primera app', href: '#primera-app'),
    ],
  ),
  StudioNavSection(
    title: 'Aprender',
    items: [
      StudioNavDestination('Widgets', href: '#widgets'),
      StudioNavDestination('Layout', href: '#layout'),
    ],
  ),
  StudioNavSection(
    title: 'Referencia',
    items: [
      StudioNavDestination('API', href: '#api'),
      StudioNavDestination('Errores', href: '#errores'),
    ],
  ),
];

/// The section: one stage per theme.
class LayoutSection extends StatelessWidget implements ThorElementWidget {
  /// The section.
  const LayoutSection({super.key});

  @override
  Widget build(BuildContext context) => SectionFrame(
    label: 'layout y navegación',
    meta: 'StudioScaffold y compañía',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        _Stage(theme: _light, name: 'Claro'),
        _Stage(theme: _dark, name: 'Oscuro'),
      ],
    ),
  );
}

/// One theme's stage: a card with every widget on the page's own surface.
class _Stage extends StatelessWidget implements ThorElementWidget {
  const _Stage({required this.theme, required this.name});

  final ThemeData theme;
  final String name;

  @override
  Widget build(BuildContext context) => Theme(
    data: theme,
    child: Builder(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final text = Theme.of(context).textTheme;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(StudioRadii.inner),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 24,
            children: [
              Text(
                'Tema $name',
                style: text.titleSmall.copyWith(
                  color: scheme.onSurfaceVariant!,
                ),
              ),
              const StudioTopBar(
                brand: StudioBrand(name: 'thor'),
                links: [
                  StudioNavDestination('Guía', href: '#guia'),
                  StudioNavDestination('API', href: '#api'),
                ],
                selectedIndex: 0,
                // A parameter wins over the locale's "Buscar".
                search: StudioSearchPill(
                  href: '#buscar',
                  placeholder: 'Buscar en la guía',
                  shortcut: '⌘K',
                ),
                actions: [StudioThemeToggle()],
              ),
              const StudioBreadcrumbs(
                trail: [
                  StudioNavDestination('Empezar', href: '#empezar'),
                  StudioNavDestination('Instalación', href: '#instalacion'),
                ],
                selectedIndex: 1,
              ),
              const StudioPageHeader(
                eyebrow: 'Empezar',
                title: 'Instalación',
                lead:
                    'Instala el comando thor y crea tu primera app en un '
                    'minuto.',
              ),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 24,
                children: [
                  Expanded(
                    child: StudioSideNav(
                      label: 'Navegación de ejemplo',
                      selectedIndex: 1,
                      sections: _sections,
                    ),
                  ),
                  Expanded(
                    child: StudioTableOfContents(
                      current: '#requisitos',
                      entries: [
                        StudioTocEntry('Requisitos', href: '#requisitos'),
                        StudioTocEntry('Con pub', href: '#pub', depth: 1),
                        StudioTocEntry('Primer arranque', href: '#arranque'),
                      ],
                    ),
                  ),
                ],
              ),
              const StudioPagerLinks(
                previous: StudioNavDestination('Qué es Thor', href: '#que-es'),
                next: StudioNavDestination(
                  'Tu primera app',
                  href: '#primera-app',
                ),
              ),
              const Row(
                spacing: 12,
                children: [
                  StudioLocaleSwitcher(
                    selectedIndex: 0,
                    locales: [
                      StudioLocaleOption(
                        locale: Locale('es'),
                        label: 'Español',
                        href: '#es',
                      ),
                      StudioLocaleOption(
                        locale: Locale('en'),
                        label: 'English',
                        href: '#en',
                      ),
                    ],
                  ),
                ],
              ),
              const StudioFooter(
                brand: StudioBrand(name: 'thor'),
                sections: [
                  StudioNavSection(
                    title: 'Aprender',
                    items: [
                      StudioNavDestination('Widgets', href: '#widgets'),
                      StudioNavDestination('Layout', href: '#layout'),
                    ],
                  ),
                  StudioNavSection(
                    title: 'Comunidad',
                    items: [StudioNavDestination('GitHub', href: '#github')],
                  ),
                ],
                legal: 'Licencia MIT',
              ),
            ],
          ),
        );
      },
    ),
  );
}
