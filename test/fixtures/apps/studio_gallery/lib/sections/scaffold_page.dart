// A whole docs page on StudioScaffold: run it with
// `GALLERY_PAGE=scaffold thor dev` to try the sticky bar, the sidebar that
// becomes a drawer on a phone, the table of contents and the skip link.
import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/router.dart' show LocaleSwitcher;
import 'package:thor_ui/thor_ui.dart';

/// The page.
class ScaffoldPage extends StatelessWidget implements ThorElementWidget {
  /// The page.
  const ScaffoldPage({super.key});

  @override
  Widget build(BuildContext context) => StudioScaffold(
    // The skip link, the menu button and the drawer's names come from
    // `StudioLocalizations` (the app says `es`): no strings here.
    appBar: const StudioTopBar(
      brand: StudioBrand(name: 'Thor'),
      links: [
        StudioNavDestination('Guía', href: '#guia'),
        StudioNavDestination('API', href: '#api'),
        StudioNavDestination('Cambios', href: '#cambios'),
      ],
      selectedIndex: 0,
      search: StudioSearchPill(href: '#buscar', shortcut: '⌘K'),
      actions: [
        StudioIconButton(
          icon: Icon(StudioIcons.github, size: 18),
          tooltip: 'Repositorio en GitHub',
          href: 'https://github.com',
          newTab: true,
        ),
        StudioThemeToggle(),
      ],
    ),
    drawer: const StudioSideNav(
      // The current page: the second item of the first section.
      selectedIndex: 1,
      sections: [
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
            StudioNavDestination('Interactividad', href: '#interactividad'),
          ],
        ),
        StudioNavSection(
          title: 'Desplegar',
          items: [
            StudioNavDestination('Estático o servidor', href: '#estatico'),
            StudioNavDestination('Desplegar', href: '#desplegar'),
          ],
        ),
      ],
    ),
    tableOfContents: const StudioTableOfContents(
      scrollSpy: true,
      entries: [
        StudioTocEntry('Requisitos', href: '#requisitos'),
        StudioTocEntry('Con pub', href: '#pub', depth: 1),
        StudioTocEntry('Primer arranque', href: '#arranque'),
        StudioTocEntry('Siguientes pasos', href: '#siguientes'),
      ],
    ),
    body: const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 32,
      children: [
        StudioBreadcrumbs(
          trail: [
            StudioNavDestination('Empezar', href: '#empezar'),
            StudioNavDestination('Instalación', href: '#instalacion'),
          ],
          selectedIndex: 1,
        ),
        StudioPageHeader(
          eyebrow: 'Empezar',
          title: 'Instalación',
          lead:
              'Instala el comando thor y crea tu primera app en un '
              'minuto.',
        ),
        _Section(id: 'requisitos', title: 'Requisitos'),
        _Section(id: 'pub', title: 'Con pub'),
        _Section(id: 'arranque', title: 'Primer arranque'),
        _Section(id: 'siguientes', title: 'Siguientes pasos'),
        StudioPagerLinks(
          previous: StudioNavDestination('Qué es Thor', href: '#que-es'),
          next: StudioNavDestination('Tu primera app', href: '#primera-app'),
        ),
      ],
    ),
    footer: StudioFooter(
      brand: const StudioBrand(name: 'Thor'),
      sections: [
        const StudioNavSection(
          title: 'Aprender',
          items: [
            StudioNavDestination('Widgets', href: '#widgets'),
            StudioNavDestination('Layout', href: '#layout'),
          ],
        ),
        const StudioNavSection(
          title: 'Comunidad',
          items: [StudioNavDestination('GitHub', href: '#github')],
        ),
      ],
      legal: 'Licencia MIT',
      actions: [
        StudioLocaleSwitcher(
          selectedIndex: 0,
          locales: [
            // The language's own name, from the framework's table.
            StudioLocaleOption(
              locale: const Locale('es'),
              label: LocaleSwitcher.endonym(const Locale('es')),
              href: '#es',
            ),
            StudioLocaleOption(
              locale: const Locale('en'),
              label: LocaleSwitcher.endonym(const Locale('en')),
              href: '#en',
            ),
          ],
        ),
      ],
    ),
  );
}

/// A heading and enough text to make the page scroll.
class _Section extends StatelessWidget implements ThorElementWidget {
  const _Section({required this.id, required this.title});

  final String id;
  final String title;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: [
      Semantics(
        headingLevel: 2,
        identifier: id,
        child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ),
      for (var i = 0; i < 4; i++)
        Text(
          'Thor convierte la API de widgets de Flutter en HTML semántico y '
          'CSS generado en el servidor. Cada widget termina en un solo '
          'elemento, y lo interactivo se engancha con un motor de signals '
          'que solo viaja cuando la página lo necesita.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
    ],
  );
}
