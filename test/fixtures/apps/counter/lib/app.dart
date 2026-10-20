import 'package:thor_ui/thor_ui.dart';

import 'counter_state.dart';

/// A counter: − / value / + and a reset that is disabled at zero.
class Counter extends StatelessWidget implements ThorElementWidget {
  const Counter({super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 16,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          OutlinedButton(onPressed: counter.dec, child: const Text('−')),
          Watch(counter.label, style: const TextStyle(fontSize: 24)),
          OutlinedButton(onPressed: counter.inc, child: const Text('+')),
          Watch(
            counter.isZero,
            builder: (zero) => TextButton(
              onPressed: zero ? null : counter.reset,
              child: const Text('Reiniciar'),
            ),
          ),
        ],
      ),
      // Appears from 5 on: a state with another structure (nothing / a text).
      Watch(
        counter.isHigh,
        builder: (high) => high
            ? Watch(
                counter.highLabel,
                style: const TextStyle(color: Color(0xFFB45309)),
              )
            : const SizedBox.shrink(),
      ),
    ],
  );
}
