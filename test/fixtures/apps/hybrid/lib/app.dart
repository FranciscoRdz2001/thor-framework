import 'package:thor_ui/thor_ui.dart';

import 'hybrid_state.dart';

const _muted = TextStyle(color: Color(0xFF52525B));

/// A thor page with two Flutter views: a chart above the fold and a
/// counter below it. Everything else is thor HTML.
class HybridPage extends StatelessWidget implements ThorElementWidget {
  const HybridPage({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            const Semantics(
              headingLevel: 1,
              child: Text(
                'Modo híbrido',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
              ),
            ),
            const Text(
              'Esta página es HTML de thor. La gráfica y el contador son '
              'vistas de una app de Flutter web que se cargan solas cuando '
              'llegan a la pantalla; mientras tanto (o sin JavaScript) se ve '
              'su versión en HTML.',
              style: _muted,
            ),
            FlutterView(
              initialData: const {
                'view': 'chart',
                'labels': ['ene', 'feb', 'mar', 'abr', 'may'],
                'values': [12, 19, 7, 24, 16],
              },
              aspectRatio: 16 / 9,
              semanticLabel: 'Ventas por mes',
              onMessage: hybrid.onBar,
              placeholder: const _Placeholder(
                'Ventas por mes: ene 12 · feb 19 · mar 7 · abr 24 · may 16',
              ),
            ),
            Watch(hybrid.barLabel),
            // Pushes the counter below the fold: it loads when scrolled to.
            const SizedBox(height: 900),
            FlutterView(
              initialData: const {'view': 'counter', 'start': 3},
              height: 160,
              semanticLabel: 'Contador de Flutter',
              onMessage: hybrid.onCount,
              placeholder: const _Placeholder('Contador: 3'),
            ),
            Watch(hybrid.countLabel),
          ],
        ),
      ),
    ),
  );
}

/// The HTML version of a view: what the page shows before Flutter paints.
class _Placeholder extends StatelessWidget implements ThorElementWidget {
  const _Placeholder(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFFF4F4F5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Center(child: Text(text, style: _muted)),
  );
}
