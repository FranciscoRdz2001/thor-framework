import 'package:thor_ui/thor_ui.dart';

import 'cycler_state.dart';

const _colors = [Color(0xFF2563EB), Color(0xFF16A34A), Color(0xFFDC2626)];

/// Every state is rendered by the server (so every class exists before the
/// first click); implicit animations interpolate between them.
class ColorCycler extends StatelessWidget implements ThorElementWidget {
  const ColorCycler({super.key});

  @override
  Widget build(BuildContext context) => Row(
    spacing: 12,
    children: [
      FilledButton(onPressed: cycler.cycle, child: Watch(cycler.cycleLabel)),
      Watch(
        cycler.current,
        count: 3,
        builder: (i) => Row(
          spacing: 12,
          children: [
            Styled(
              classes: const ['case-island-box'],
              child: Styled(
                style: const StyleProps().when(
                  medium: StyleProps(width: 160.0 + i * 10),
                  hover: StyleProps(opacity: 0.5 + i / 10),
                ),
                child: Container(width: 80, height: 40, color: _colors[i]),
              ),
            ),
            AnimatedScale(
              scale: i.isEven ? 1 : 1.25,
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              child: AnimatedContainer(
                width: i.isEven ? 40 : 80,
                height: 40,
                decoration: BoxDecoration(
                  color: _colors[i],
                  borderRadius: BorderRadius.circular(i.isEven ? 4 : 20),
                ),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                onEnd: cycler.animationEnded,
              ),
            ),
            SizedBox(
              width: 160,
              height: 60,
              child: ColoredBox(
                color: const Color(0xFFE5E7EB),
                child: AnimatedAlign(
                  alignment: i.isEven
                      ? Alignment.topLeft
                      : Alignment.bottomRight,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: const Text('●'),
                ),
              ),
            ),
          ],
        ),
      ),
      Watch(cycler.endsLabel),
    ],
  );
}
