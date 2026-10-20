import 'package:thor_ui/thor_ui.dart';

import 'implicit_state.dart';
import 'motion_state.dart';

const _card = BoxDecoration(
  color: Color(0xFFFFFFFF),
  borderRadius: BorderRadius.all(Radius.circular(16)),
  boxShadow: [
    BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2)),
  ],
);

final _panel = DecorationTween(
  begin: const BoxDecoration(
    color: Color(0xFFEEF2FF),
    borderRadius: BorderRadius.all(Radius.circular(12)),
  ),
  end: const BoxDecoration(
    color: Color(0xFFC7D2FE),
    borderRadius: BorderRadius.all(Radius.circular(24)),
  ),
);

const _h2 = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
const _muted = TextStyle(fontSize: 14, color: Color(0xFF5B6170));

/// One section per kind of explicit animation.
class AnimationsPage extends StatelessWidget implements ThorElementWidget {
  const AnimationsPage({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      role: SemanticsRole.main,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 20,
          children: [
            // Entrance: a controller outside any state, already playing
            // when the page renders → a CSS animation, no JavaScript.
            SlideTransition(
              position: Tween(begin: const Offset(0, 0.3), end: Offset.zero)
                  .animate(
                    CurvedAnimation(
                      parent: AnimationController(
                        duration: const Duration(milliseconds: 500),
                      )..forward(),
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: const Semantics(
                headingLevel: 1,
                child: Text(
                  'Animaciones',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const _Section(
              title: 'Un bucle sin JavaScript',
              note: 'repeat(reverse: true) al pintar: una animación de CSS.',
              child: _Pulse(),
            ),
            _Section(
              title: 'Un panel que aparece',
              note:
                  'AnimationController en un ThorState: forward, reverse, '
                  'toggle.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: motion.show,
                        child: const Text('Mostrar'),
                      ),
                      OutlinedButton(
                        onPressed: motion.hide,
                        child: const Text('Ocultar'),
                      ),
                      TextButton(
                        onPressed: motion.toggle,
                        child: const Text('Alternar'),
                      ),
                      OutlinedButton(
                        onPressed: motion.half,
                        child: const Text('A la mitad'),
                      ),
                      OutlinedButton(
                        onPressed: motion.quarter,
                        child: const Text('Bajar a un cuarto'),
                      ),
                      OutlinedButton(
                        onPressed: motion.flingUp,
                        child: const Text('Lanzar'),
                      ),
                    ],
                  ),
                  Watch(motion.revealLabel, style: _muted),
                  FadeTransition(
                    opacity: motion.reveal,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.92, end: 1.0).animate(
                        CurvedAnimation(
                          parent: motion.reveal,
                          curve: Curves.easeOutBack,
                          reverseCurve: Curves.easeIn,
                        ),
                      ),
                      alignment: Alignment.topLeft,
                      // The panel's colour and corners move with it.
                      child: DecoratedBoxTransition(
                        decoration: _panel.animate(motion.reveal),
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Hola: sé aparecer y ocultarme.'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Girar hasta que lo detengas',
              note: 'repeat() y stop() desde métodos del estado.',
              child: Row(
                spacing: 16,
                children: [
                  RotationTransition(
                    turns: motion.spin,
                    child: const Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(0xFF4361EE),
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: motion.rock,
                    child: const Text('Mecer'),
                  ),
                  Watch(
                    motion.isSpinning,
                    builder: (on) => FilledButton(
                      onPressed: on ? motion.stopSpin : motion.startSpin,
                      child: Text(on ? 'Detener' : 'Girar'),
                    ),
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Un latido',
              note: 'TweenSequence: sube rápido y baja con curva.',
              child: Row(
                spacing: 16,
                children: [
                  ScaleTransition(
                    scale: TweenSequence<double>([
                      TweenSequenceItem(
                        tween: Tween(begin: 1, end: 1.3),
                        weight: 1,
                      ),
                      TweenSequenceItem(
                        tween: Tween<double>(
                          begin: 1.3,
                          end: 1,
                        ).chain(CurveTween(curve: Curves.elasticOut)),
                        weight: 3,
                      ),
                    ]).animate(motion.beat),
                    child: const Text('❤', style: TextStyle(fontSize: 32)),
                  ),
                  OutlinedButton(
                    onPressed: motion.pulse,
                    child: const Text('Latir'),
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Una transformación',
              note: 'AnimatedContainer(transform:) transiciona la matriz.',
              child: Row(
                spacing: 16,
                children: [
                  Watch(
                    implicit.isTilted,
                    builder: (tilted) => AnimatedContainer(
                      key: const ValueKey('tilt'),
                      width: 40,
                      height: 40,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutQuart,
                      transformAlignment: Alignment.center,
                      transform: tilted
                          ? Matrix4.rotationZ(0.6) *
                                Matrix4.translationValues(24, 0, 0)
                          : Matrix4.identity(),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: implicit.toggleTilt,
                    child: const Text('Inclinar'),
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Un valor interpolado',
              note:
                  'TweenAnimationBuilder: el elemento transiciona entre '
                  'los valores del objetivo.',
              child: Row(
                spacing: 16,
                children: [
                  Watch(
                    implicit.isLifted,
                    builder: (lifted) => TweenAnimationBuilder<double>(
                      tween: Tween(end: lifted ? 1.0 : 0.0),
                      duration: const Duration(milliseconds: 400),
                      builder: (context, v, child) => Opacity(
                        opacity: 1 - 0.7 * v,
                        child: Transform.translate(
                          offset: Offset(0, -12 * v),
                          child: child!,
                        ),
                      ),
                      child: const Container(
                        key: ValueKey('lift'),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(0xFF4361EE),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: implicit.toggleLift,
                    child: const Text('Subir'),
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Un estilo de texto',
              note: 'AnimatedDefaultTextStyle: peso, interlineado y espaciado.',
              child: Row(
                spacing: 16,
                children: [
                  Watch(
                    implicit.isBold,
                    builder: (bold) => AnimatedDefaultTextStyle(
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: bold ? FontWeight.w800 : FontWeight.w300,
                        height: bold ? 2 : 1,
                        letterSpacing: bold ? 4 : 0,
                      ),
                      duration: const Duration(milliseconds: 400),
                      child: const Text('Texto', key: ValueKey('type')),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: implicit.toggleBold,
                    child: const Text('Resaltar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Pulse extends StatelessWidget implements ThorElementWidget {
  const _Pulse();

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.35, end: 1.0).animate(
      AnimationController(duration: const Duration(milliseconds: 900))
        ..repeat(reverse: true),
    ),
    child: const Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: Color(0xFF22C55E),
        shape: BoxShape.circle,
      ),
    ),
  );
}

class _Section extends StatelessWidget implements ThorElementWidget {
  const _Section({
    required this.title,
    required this.note,
    required this.child,
  });

  final String title;
  final String note;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _card,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(title, style: _h2),
        Text(note, style: _muted),
        const SizedBox(height: 4),
        child,
      ],
    ),
  );
}
