import 'package:thor_ui/thor_ui.dart';

import 'gestures_state.dart';

const _card = BoxDecoration(
  color: Color(0xFFFFFFFF),
  borderRadius: BorderRadius.all(Radius.circular(16)),
  boxShadow: [
    BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2)),
  ],
);

const _h2 = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);

/// One section per gesture.
class GesturesPage extends StatelessWidget implements ThorElementWidget {
  const GesturesPage({super.key});

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
                'Gestos',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Watch(gestures.status),
            ),
            const Text('Bandeja: desliza para archivar', style: _h2),
            Watch.list(
              gestures.messages,
              itemKey: gestures.messageKey,
              container: (rows) => Semantics(
                role: SemanticsRole.list,
                child: Column(spacing: 8, children: rows),
              ),
              each: (row) => Gesture(
                onTap: gestures.opened.withArg(row.key),
                onLongPress: gestures.menu.withArg(row.key),
                onSwipe: gestures.swiped.withArg(row.key),
                swipe: const Swipe(dismiss: true),
                child: Semantics(
                  role: SemanticsRole.listItem,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _card,
                    child: row.text(gestures.messageSubject),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: gestures.restore,
                  child: const Text('Restaurar bandeja'),
                ),
              ],
            ),
            const Text('Doble tap para dar like', style: _h2),
            Gesture(
              onDoubleTap: gestures.like,
              feedback: const Press(),
              child: Container(
                height: 120,
                alignment: Alignment.center,
                decoration: _card,
                child: Watch(
                  gestures.likesLabel,
                  style: const TextStyle(
                    fontSize: 28,
                    color: Color(0xFFE11D48),
                  ),
                ),
              ),
            ),
            const Text('Arrastra la ficha', style: _h2),
            Container(
              height: 180,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 16,
                    top: 16,
                    child: Gesture(
                      onDragEnd: gestures.moved,
                      drag: const Drag(snapBack: false),
                      child: const Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Color(0xFF16A34A),
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        child: Text(
                          'Ficha',
                          style: TextStyle(color: Color(0xFFFFFFFF)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Watch(gestures.positionLabel),
            const Text('Pellizca para hacer zoom', style: _h2),
            Container(
              height: 160,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: Gesture(
                onScaleEnd: gestures.zoomed,
                child: const Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Watch(gestures.zoomLabel),
          ],
        ),
      ),
    ),
  );
}
