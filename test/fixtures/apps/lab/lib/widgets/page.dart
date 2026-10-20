// Test app: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
import 'package:thor_ui/thor_ui.dart';

import 'lab_state.dart';

const _card = BoxDecoration(
  color: Color(0xFFFFFFFF),
  borderRadius: BorderRadius.all(Radius.circular(16)),
  boxShadow: [
    BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2)),
  ],
);

const _h2 = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
const _muted = TextStyle(fontSize: 14, color: Color(0xFF5B6170));

/// One section per widget.
class LabPage extends StatelessWidget implements ThorElementWidget {
  const LabPage({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      role: SemanticsRole.main,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            const Semantics(
              headingLevel: 1,
              child: Text(
                'Widgets',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
            ),
            const Text('Pasa el mouse', style: _h2),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: lab.enter,
              onExit: lab.leave,
              child: Container(
                key: const ValueKey('hover'),
                padding: const EdgeInsets.all(24),
                decoration: _card,
                child: Watch(lab.hoverLabel, style: _muted),
              ),
            ),
            const Text('Foco', style: _h2),
            Focus(
              canRequestFocus: false,
              onFocusChange: lab.focusChanged,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: _card,
                child: Column(
                  spacing: 8,
                  children: [
                    const TextField(name: 'one', id: 'one'),
                    const TextField(name: 'two', id: 'two'),
                    Watch(lab.focusLabel, style: _muted),
                  ],
                ),
              ),
            ),
            const Text('Acordeón', style: _h2),
            ExpansionTile(
              title: const Text('Preguntas'),
              onExpansionChanged: lab.expansionChanged,
              children: const [Text('Respuesta.')],
            ),
            Watch(lab.expansionLabel, style: _muted),
            const Text('AnimatedSize', style: _h2),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: lab.toggleMore,
                    child: const Text('Ver más'),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    child: Watch(
                      lab.isMore,
                      builder: (more) => Container(
                        key: const ValueKey('size'),
                        height: more ? 160 : 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEEF2FF),
                        ),
                        child: Text(more ? 'Mucho más contenido' : 'Poco'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Text('AnimatedCrossFade', style: _h2),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: lab.toggleFade,
                    child: const Text('Cambiar'),
                  ),
                  Watch(
                    lab.isFaded,
                    builder: (faded) => AnimatedCrossFade(
                      firstChild: const Text('Primero', key: ValueKey('first')),
                      secondChild: const SizedBox(
                        key: ValueKey('second'),
                        height: 120,
                        child: Text('Segundo, más alto'),
                      ),
                      crossFadeState: faded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 300),
                    ),
                  ),
                ],
              ),
            ),
            const Text('SizeTransition', style: _h2),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: lab.togglePanel,
                    child: const Text('Abrir o cerrar'),
                  ),
                  SizeTransition(
                    sizeFactor: CurvedAnimation(
                      parent: lab.panel,
                      curve: Curves.easeOut,
                    ),
                    child: const SizedBox(
                      key: ValueKey('panel'),
                      height: 100,
                      child: Text('Panel que se pliega'),
                    ),
                  ),
                ],
              ),
            ),
            const Text('AnimatedSize: ancho y onEnd', style: _h2),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: lab.toggleWide,
                    child: const Text('Ensanchar'),
                  ),
                  AnimatedSize(
                    animateWidth: true,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    onEnd: lab.sizeEnded,
                    child: Watch(
                      lab.isWide,
                      builder: (wide) => Container(
                        key: const ValueKey('wide'),
                        width: wide ? 240 : 60,
                        height: wide ? 60 : 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEEF2FF),
                        ),
                      ),
                    ),
                  ),
                  Watch(lab.sizeEndLabel, style: _muted),
                ],
              ),
            ),
            const Text('Watch de un campo', style: _h2),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _card,
              child: Row(
                spacing: 12,
                children: [
                  FilledButton(
                    onPressed: lab.toggleFlag,
                    child: const Text('Alternar el campo'),
                  ),
                  // The field itself, its builder typed bool.
                  Watch.field(
                    lab.flag,
                    builder: (on) => Text(on ? 'Campo: sí' : 'Campo: no'),
                  ),
                ],
              ),
            ),
            const Text('Theme.of sigue al tema', style: _h2),
            Theme(
              data: ThemeData(),
              darkData: ThemeData.dark(),
              child: const _ThemeProbe(),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Colors taken from `Theme.of(context)`: they must follow the dark mode of
/// the page with no reload.
class _ThemeProbe extends StatelessWidget {
  const _ThemeProbe();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'theme-surface',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: scheme.surface),
        child: Row(
          spacing: 12,
          children: [
            Semantics(
              identifier: 'theme-primary',
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: scheme.primary),
              ),
            ),
            Semantics(
              identifier: 'theme-soft',
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
