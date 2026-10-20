// The v2 content widgets of thor_studio: what a documentation page is made
// of. The labels ("Copiar", "En Flutter"…) are not passed: they come from
// `StudioLocalizations`, as in the docs site.
import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/thor_ui.dart';

import 'orders_example.dart';
import 'section_frame.dart';

const _counter = '''
class CounterViewModel extends ThorState {
  final count = state(0);

  String label() => '\${count.value}';

  void inc() => count.value++;
}

final counter = CounterViewModel();''';

const _flutterCounter = '''
class CounterViewModel extends ChangeNotifier {
  int count = 0;

  void inc() {
    count++;
    notifyListeners();
  }
}''';

const _stepOne = '''
class CounterViewModel extends ThorState {
  final count = state(0);
}''';

const _stepTwo = '''
class CounterViewModel extends ThorState {
  final count = state(0);

  void inc() => count.value++;
}''';

const _stepThree = '''
class CounterViewModel extends ThorState {
  final count = state(0);

  String label() => '\${count.value}';

  void inc() => count.value++;
}

final counter = CounterViewModel();''';

/// The whole section: registered in `page.dart` with one line.
class ContentSection extends StatelessWidget implements ThorElementWidget {
  /// The section.
  const ContentSection({super.key});

  @override
  Widget build(BuildContext context) => const SectionFrame(
    label: 'widgets de contenido',
    meta: 'StudioProse, código, capas, pasos',
    maxWidth: 920,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 40,
      children: [
        _Group(
          title: 'Resumen Flutter / Thor',
          child: StudioCompareSummary(
            flutter: 'setState(() => count++)',
            thor: 'count.value++',
          ),
        ),
        _Group(
          title: 'Capas de la arquitectura',
          child: StudioLayerDiagram(id: 'gallery-layers', layers: ordersLayers),
        ),
        _Group(
          title: 'Flutter / Thor',
          child: StudioFlutterCompare(
            id: 'gallery-compare',
            flutterCode: _flutterCounter,
            thorCode: _counter,
          ),
        ),
        _Group(
          title: 'Bloque de código',
          child: StudioCodeBlock(
            _counter,
            title: 'counter_view_model.dart',
            highlight: [StudioLineRange(2)],
            changed: [StudioLineRange(6)],
          ),
        ),
        _Group(
          title: 'Código en pestañas',
          child: StudioCodeTabs(
            id: 'gallery-tabs',
            tabs: [
              StudioCodeTab(label: 'counter_view_model.dart', code: _counter),
              StudioCodeTab(
                label: 'pubspec.yaml',
                language: StudioCodeLanguage.yaml,
                code:
                    'name: counter\n'
                    'dependencies:\n'
                    '  thor_ui: ^0.1.0 # la API de widgets\n'
                    'environment:\n'
                    '  sdk: ^3.8.0',
              ),
              StudioCodeTab(
                label: 'terminal',
                language: StudioCodeLanguage.bash,
                code: 'thor create counter\ncd counter\nthor dev',
              ),
            ],
          ),
        ),
        _Group(
          title: 'Notas',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              StudioCallout(
                title: 'Nota',
                body: 'Una página sin ThorState no carga JavaScript.',
              ),
              StudioCallout(
                tone: StudioTone.ok,
                title: 'Consejo',
                body: 'Declara el estado en una clase por pantalla.',
              ),
              StudioCallout(
                tone: StudioTone.warn,
                title: 'Ojo',
                body: 'El builder de un QueryBuilder corre en el servidor.',
              ),
              StudioCallout(
                tone: StudioTone.danger,
                title: 'Cuidado',
                body: 'Quitar un widget exportado rompe a quien lo usa.',
              ),
              StudioCallout(
                tone: StudioTone.flutter,
                title: 'Diferencia con Flutter',
                body: 'No hay setState: el estado vive en un ThorState.',
              ),
            ],
          ),
        ),
        _Group(
          title: 'Pasos',
          child: StudioSteps(
            steps: [
              StudioStep(
                title: 'Crea la app',
                code: 'thor create counter',
                language: StudioCodeLanguage.bash,
              ),
              StudioStep(
                title: 'Declara el estado',
                body: 'Una clase, un campo.',
                code: _stepOne,
                codeTitle: 'counter_view_model.dart',
              ),
              StudioStep(
                title: 'Muéstralo',
                body: 'Un Watch sigue al campo.',
                code: _stepThree,
                codeTitle: 'counter_view_model.dart',
              ),
            ],
          ),
        ),
        _Group(
          title: 'Pasos con diff',
          child: StudioSteps.diff(
            steps: [
              StudioStep(
                title: 'El campo',
                code: _stepOne,
                codeTitle: 'counter_view_model.dart',
              ),
              StudioStep(
                title: 'La acción',
                code: _stepTwo,
                codeTitle: 'counter_view_model.dart',
              ),
              StudioStep(
                title: 'El texto y la instancia',
                code: _stepThree,
                codeTitle: 'counter_view_model.dart',
              ),
            ],
          ),
        ),
        _Group(
          title: 'Tarjetas',
          child: StudioCardGrid(
            children: [
              StudioLinkCard(
                title: 'Arquitectura',
                description: 'View, ViewModel, Repository y Service.',
                href: '#arquitectura',
                icon: StudioIcons.layoutGrid,
              ),
              StudioLinkCard(
                title: 'Estado',
                description: 'Un ThorState por pantalla.',
                href: '#estado',
                icon: StudioIcons.zap,
              ),
              StudioLinkCard(
                title: 'Repositorio',
                description: 'El código fuente en GitHub.',
                href: 'https://github.com',
                icon: StudioIcons.github,
                external: true,
              ),
            ],
          ),
        ),
        _Group(
          title: 'Árbol de archivos',
          child: StudioFileTree(
            label: 'Estructura del proyecto',
            entries: [
              StudioFileEntry(
                'lib/',
                children: [
                  StudioFileEntry('main.server.dart', note: 'Arranca la app'),
                  StudioFileEntry(
                    'orders/',
                    children: [
                      StudioFileEntry('orders_state.dart', note: 'ViewModel'),
                      StudioFileEntry('orders_view.dart', note: 'View'),
                    ],
                  ),
                ],
              ),
              StudioFileEntry('pubspec.yaml'),
            ],
          ),
        ),
        _Group(
          title: 'Tabla y teclas',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              StudioDataTable(
                columns: [
                  DataColumn(label: Text('Página')),
                  DataColumn(label: Text('JS (gzip)'), numeric: true),
                  DataColumn(label: Text('Atajo')),
                ],
                rows: [
                  DataRow(
                    cells: [
                      DataCell(Text('Sin ThorState')),
                      DataCell(Text('0 KB')),
                      DataCell(StudioKbd('Esc')),
                    ],
                  ),
                  DataRow(
                    cells: [
                      DataCell(Text('Contador')),
                      DataCell(Text('24.8 KB')),
                      DataCell(StudioKbd('⌘', semanticLabel: 'Command')),
                    ],
                  ),
                ],
              ),
              Row(
                spacing: 8,
                children: [Text('Buscar:'), StudioKbd('Ctrl'), StudioKbd('K')],
              ),
            ],
          ),
        ),
        _Group(
          title: 'Prosa',
          child: StudioProse(_prose, anchorLabel: 'Enlace a esta sección'),
        ),
      ],
    ),
  );
}

const _prose =
    '<h2 id="como-funciona">Cómo funciona</h2>'
    '<p>Thor pinta la página en el servidor. Solo lo que cambia con un toque '
    'se declara en un <code>ThorState</code>, y el navegador conecta esos '
    'puntos sin volver a construir el árbol. Lee <a href="#estado">la guía '
    'del estado</a> para el detalle.</p>'
    '<h3 id="watch">Watch y acciones</h3>'
    '<ul><li>Un <code>Watch</code> sigue a un campo del estado.</li>'
    '<li>Un callback que es un método del estado se conecta solo.</li></ul>'
    '<pre><code><span class="studio-tok-keyword">final</span> label = '
    '<span class="studio-tok-type">Watch</span>(counter.label);</code></pre>'
    '<h2 id="que-llega">Qué llega al navegador</h2>'
    '<table><thead><tr><th>Página</th><th>JS gz</th></tr></thead><tbody>'
    '<tr><td>Sin ThorState</td><td>0 KB</td></tr>'
    '<tr><td>Contador</td><td>24.8 KB</td></tr></tbody></table>'
    '<blockquote>Medido contra la misma página en otros frameworks.</blockquote>'
    '<p>Pulsa <kbd>Ctrl</kbd> + <kbd>K</kbd> para buscar.</p>';

class _Group extends StatelessWidget implements ThorElementWidget {
  const _Group({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 16,
    children: [
      Semantics(
        headingLevel: 2,
        child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ),
      child,
    ],
  );
}
