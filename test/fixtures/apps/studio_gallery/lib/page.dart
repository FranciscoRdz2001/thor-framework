// The docs guide page, built with
// thor_studio's StudioScaffold: the design system tested on a real page.
// The skip link, the menu button, the drawer's names and the code blocks'
// buttons come from `StudioLocalizations` (the app says `es`): no strings
// for them here, and no ids: the scaffold names its own drawer.
import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/thor_ui.dart';

import 'sections/bench_section.dart';
import 'sections/content_section.dart';
import 'sections/layout_section.dart';
import 'sections/material_section.dart';

const _counter = '''
class CounterViewModel extends ThorState {
  final count = state(0);
  String label() => '\${count.value}';
  void inc() => count.value++;
}
final counter = CounterViewModel();''';

/// The whole page.
class GuidePage extends StatelessWidget implements ThorElementWidget {
  /// The page.
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context) => const StudioScaffold(
    appBar: StudioTopBar(
      brand: StudioBrand(name: 'Thor'),
      links: [
        StudioNavDestination('Guía', href: '#'),
        StudioNavDestination('Widgets', href: '#widgets'),
        StudioNavDestination('API', href: '#api'),
        StudioNavDestination('Ejemplos', href: '#ejemplos'),
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
    drawer: StudioSideNav(
      // The current page: "Estado reactivo", the first of "Interactividad".
      selectedIndex: 7,
      sections: [
        StudioNavSection(
          title: 'Empezar',
          items: [
            StudioNavDestination('Introducción', href: '#introduccion'),
            StudioNavDestination('Instalación', href: '#instalacion'),
            StudioNavDestination('Tu primera página', href: '#primera-pagina'),
          ],
        ),
        StudioNavSection(
          title: 'Widgets y estilos',
          items: [
            StudioNavDestination('Layout como en Flutter', href: '#layout'),
            StudioNavDestination('Estilos y tema', href: '#estilos'),
            StudioNavDestination('Variantes con .when()', href: '#variantes'),
            StudioNavDestination('Animaciones', href: '#animaciones'),
          ],
        ),
        StudioNavSection(
          title: 'Interactividad',
          items: [
            StudioNavDestination('Estado reactivo', href: '#estado-reactivo'),
            StudioNavDestination('Listas y filas', href: '#listas-y-filas'),
            StudioNavDestination('Formularios sin JS', href: '#formularios'),
            StudioNavDestination('Gestos', href: '#gestos'),
          ],
        ),
        StudioNavSection(
          title: 'Servidor',
          items: [
            StudioNavDestination('Rutas por archivos', href: '#rutas'),
            StudioNavDestination('Datos y acciones', href: '#datos'),
            StudioNavDestination('Caché de página', href: '#cache'),
            StudioNavDestination('Deploy', href: '#deploy'),
          ],
        ),
      ],
    ),
    tableOfContents: StudioTableOfContents(
      scrollSpy: true,
      entries: [
        StudioTocEntry('Cómo funciona', href: '#como-funciona'),
        StudioTocEntry('Watch y acciones', href: '#watch', depth: 1),
        StudioTocEntry('Qué llega al navegador', href: '#navegador'),
      ],
    ),
    body: _Content(),
    footer: StudioFooter(
      brand: StudioBrand(name: 'Thor'),
      sections: [
        StudioNavSection(
          title: 'Aprender',
          items: [
            StudioNavDestination('Widgets', href: '#widgets'),
            StudioNavDestination('Interactividad', href: '#estado-reactivo'),
          ],
        ),
        StudioNavSection(
          title: 'Proyecto',
          items: [StudioNavDestination('GitHub', href: 'https://github.com')],
        ),
      ],
      legal: 'Licencia MIT. HTML estático: esta página no necesita JavaScript.',
    ),
  );
}

class _Content extends StatelessWidget implements ThorElementWidget {
  const _Content();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 40,
    children: [
      _Article(),
      BenchSection(),
      LayoutSection(),
      _States(),
      ContentSection(),
      MaterialSection(),
      StudioPagerLinks(
        previous: StudioNavDestination('Gestos', href: '#gestos'),
        next: StudioNavDestination('Listas y filas', href: '#listas-y-filas'),
      ),
    ],
  );
}

/// The article itself: header, code, callout and prose.
class _Article extends StatelessWidget implements ThorElementWidget {
  const _Article();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 18,
    children: [
      StudioBreadcrumbs(
        trail: [
          StudioNavDestination('Interactividad', href: '#interactividad'),
          StudioNavDestination('Estado reactivo', href: '#estado-reactivo'),
        ],
        selectedIndex: 1,
      ),
      StudioPageHeader(
        eyebrow: 'Interactividad',
        title: 'Estado reactivo con ThorState',
        lead:
            'La página llega renderizada desde el servidor. Solo lo que '
            'cambia con un toque se declara en un ThorState, y el motor '
            'conecta esos puntos sin volver a construir el árbol.',
      ),
      StudioCodeBlock(_counter, title: 'counter_view_model.dart'),
      StudioCallout(
        title: 'El motor solo viaja si hace falta.',
        body:
            'Una página sin ThorState no carga JavaScript; el build '
            'incluye solo las funciones del motor que tu app usa.',
      ),
      StudioProse(
        '<h2 id="como-funciona">Cómo funciona</h2>'
        '<p>Thor lista los miembros del estado y sus nombres estables '
        'fuera de tu código. En un widget, '
        '<code>Watch(counter.label)</code> marca el texto y '
        '<code>onPressed: counter.inc</code> la acción.</p>'
        '<h3 id="watch">Watch y acciones</h3>'
        '<ul><li>Un <code>Watch</code> es un texto o una variante que '
        'sigue a un miembro del estado.</li><li>Un callback que es un '
        'método del estado se conecta solo.</li></ul>'
        '<h2 id="navegador">Qué llega al navegador</h2>'
        '<table><thead><tr><th>Página</th><th>JS gz</th></tr></thead>'
        '<tbody><tr><td>Sin ThorState</td><td>0 KB</td></tr>'
        '<tr><td>Contador</td><td>24.8 KB</td></tr>'
        '<tr><td>Lista</td><td>30.7 KB</td></tr></tbody></table>'
        '<blockquote>Medido con <a href="#ejemplos">tool/thor '
        'build</a>.</blockquote>',
      ),
      StudioCodeBlock(
        'tool/thor build counter',
        language: StudioCodeLanguage.bash,
      ),
      StudioCardGrid(
        children: [
          StudioLinkCard(
            title: 'Listas y filas',
            description: 'Watch.list(…, each:)',
            href: '#listas-y-filas',
            icon: StudioIcons.layoutGrid,
          ),
          StudioLinkCard(
            title: 'Formularios sin JS',
            description: 'Form, validación nativa',
            href: '#formularios-sin-js',
            icon: StudioIcons.circleCheck,
          ),
        ],
      ),
    ],
  );
}

/// The states of a field, the status labels, an overlay of each kind and a
/// scroll box.
class _States extends StatelessWidget implements ThorElementWidget {
  const _States();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 14,
    children: [
      const _Field(label: 'Nombre', initialValue: 'counter_view_model'),
      const _Field(label: 'Vacío', hintText: 'Escribe un nombre'),
      const _Field(
        label: 'Deshabilitado',
        initialValue: 'Deshabilitado',
        enabled: false,
      ),
      const _Field(
        label: 'Con error',
        initialValue: 'no válido',
        errorText: 'El nombre no es válido',
      ),
      const Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          StudioStatusLabel(label: Text('neutral')),
          StudioStatusLabel(label: Text('info'), tone: StudioTone.info),
          StudioStatusLabel(label: Text('ok'), tone: StudioTone.ok),
          StudioStatusLabel(label: Text('warn'), tone: StudioTone.warn),
          StudioStatusLabel(label: Text('danger'), tone: StudioTone.danger),
          StudioFilterChip(label: Text('filtro'), selected: true, href: '#'),
          StudioKbd('⌘K', semanticLabel: 'Comando K'),
        ],
      ),
      const StudioCallout(
        tone: StudioTone.danger,
        title: 'Rompe la API.',
        body: 'Quitar un nombre público pide un aviso.',
      ),
      const Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Tooltip(message: 'Una pista', child: Text('Con pista (hover)')),
          Popover(
            label: 'Popover',
            trigger: Text('Popover'),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('Contenido del popover'),
            ),
          ),
          // The trigger names the dialog (a page of the gallery has no
          // state to hold a `DialogController`); `DialogClose()` needs none.
          DialogTrigger(id: 'studio-dialog', child: Text('Abrir diálogo')),
          Checkbox(value: true, semanticLabel: 'Casilla'),
          Switch(value: true, semanticLabel: 'Interruptor'),
          Image.network(
            'img/mark.svg',
            width: 32,
            height: 32,
            semanticLabel: 'Marca sin variante oscura',
          ),
          Image.network(
            'img/mark.svg',
            dark: 'img/mark-dark.svg',
            width: 32,
            height: 32,
            semanticLabel: 'Marca con variante oscura',
          ),
        ],
      ),
      const AlertDialog(
        id: 'studio-dialog',
        title: Text('Un diálogo'),
        content: Text('Sobre la página, en los dos temas.'),
        actions: [DialogClose(child: Text('Cerrar'))],
      ),
      SizedBox(
        height: 72,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 12; i++) Text('Fila desplazable $i'),
            ],
          ),
        ),
      ),
    ],
  );
}

/// A text field in the states a form has (the studio has no themed field
/// yet: a `TextField` with its decoration).
class _Field extends StatelessWidget implements ThorElementWidget {
  const _Field({
    required this.label,
    this.initialValue,
    this.hintText,
    this.errorText,
    this.enabled = true,
  });

  final String label;
  final String? initialValue;
  final String? hintText;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextField(
    initialValue: initialValue,
    enabled: enabled,
    decoration: InputDecoration(
      labelText: label,
      hintText: hintText,
      errorText: errorText,
    ),
  );
}
