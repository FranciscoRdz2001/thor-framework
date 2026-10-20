import 'package:thor_ui/thor_ui.dart';

import 'focus_swap_state.dart';

/// A form section inside a `Watch` whose variant changes while typing: the
/// browser replaces the subtree, so the focused field must be found again
/// (focus-swap check). The first field has an `id`, the second only a `name`.
class FocusSwap extends StatelessWidget {
  const FocusSwap({super.key});

  @override
  Widget build(BuildContext context) => Watch(
    focusSwap.hints,
    count: 4,
    builder: (hints) => Column(
      children: [
        TextField(
          id: 'swap-first',
          name: 'swapFirst',
          decoration: const InputDecoration(labelText: 'First'),
          onChanged: focusSwap.setFirst,
        ),
        if (hints & 1 != 0) const Text('First: at least 3 characters'),
        TextField(
          name: 'swapSecond',
          decoration: const InputDecoration(labelText: 'Second'),
          onChanged: focusSwap.setSecond,
        ),
        if (hints & 2 != 0) const Text('Second: at least 3 characters'),
      ],
    ),
  );
}
