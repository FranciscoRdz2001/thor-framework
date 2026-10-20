// Test app: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
import 'package:thor_ui/thor_ui.dart';

import 'focus_edge_state.dart';

/// Adversarial focus-swap scenarios: each block is a `Watch` that swaps its
/// subtree while the focus is inside it (focus-edge check).
class FocusEdge extends StatelessWidget {
  const FocusEdge({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      // The swap sets a different value on purpose (a reset / server value).
      Styled(
        classes: const ['edge-reset'],
        child: Watch(
          focusEdge.resetV,
          count: 2,
          builder: (v) => Column(
            children: [
              if (v == 1) const Text('reset by the server'),
              TextField(
                id: 'reset-f',
                name: 'resetF',
                initialValue: v == 1 ? 'server' : '',
                onChanged: focusEdge.onReset,
              ),
            ],
          ),
        ),
      ),
      // The focused field has no counterpart in the new variant.
      Styled(
        classes: const ['edge-vanish'],
        child: Watch(
          focusEdge.vanishV,
          count: 2,
          builder: (v) => v == 0
              ? Column(
                  children: [
                    const TextField(name: 'va'),
                    TextField(name: 'vb', onChanged: focusEdge.goVanish),
                  ],
                )
              : const Column(
                  children: [
                    Text('gone'),
                    TextField(name: 'vz0'),
                    TextField(name: 'vz1'),
                  ],
                ),
        ),
      ),
      // Fields without id or name; the new variant inserts one before.
      Styled(
        classes: const ['edge-insert'],
        child: Watch(
          focusEdge.insertV,
          count: 2,
          builder: (v) => v == 0
              ? Column(
                  children: [
                    TextField(
                      inputAttributes: HtmlAttributes(data: {'k': 'u0'}),
                    ),
                    TextField(
                      inputAttributes: HtmlAttributes(data: {'k': 'u1'}),
                      onChanged: focusEdge.goInsert,
                    ),
                  ],
                )
              : Column(
                  children: [
                    TextField(
                      inputAttributes: HtmlAttributes(data: {'k': 'x'}),
                    ),
                    TextField(
                      inputAttributes: HtmlAttributes(data: {'k': 'u0'}),
                    ),
                    TextField(
                      inputAttributes: HtmlAttributes(data: {'k': 'u1'}),
                    ),
                  ],
                ),
        ),
      ),
      // Input types without (or with odd) selection API, and a textarea.
      Styled(
        classes: const ['edge-types'],
        child: Watch(
          focusEdge.typesV,
          count: 2,
          builder: (v) => Column(
            children: [
              TextField(
                name: 'tEmail',
                keyboardType: TextInputType.emailAddress,
                onChanged: focusEdge.bumpTypes,
              ),
              TextField(
                name: 'tNum',
                keyboardType: TextInputType.number,
                onChanged: focusEdge.bumpTypes,
              ),
              TextField(
                name: 'tDate',
                inputAttributes: HtmlAttributes.custom({'type': 'date'}),
                onChanged: focusEdge.bumpTypes,
              ),
              TextField(
                name: 'tArea',
                maxLines: 3,
                onChanged: focusEdge.bumpTypes,
              ),
              if (v == 1) const Text('odd'),
            ],
          ),
        ),
      ),
      // Every typed character swaps.
      Styled(
        classes: const ['edge-fast'],
        child: Watch(
          focusEdge.fastV,
          count: 2,
          builder: (v) => Column(
            children: [
              TextField(name: 'fast', onChanged: focusEdge.bumpFast),
              if (v == 1) const Text('odd'),
            ],
          ),
        ),
      ),
      // Checkbox and button keep the focus.
      Styled(
        classes: const ['edge-controls'],
        child: Watch(
          focusEdge.fcV,
          count: 4,
          builder: (v) => Column(
            children: [
              Checkbox(
                name: 'fcCheck',
                value: v & 1 != 0,
                onChanged: focusEdge.toggleChk,
              ),
              ElevatedButton(
                onPressed: focusEdge.pressBtn,
                child: Text(v & 2 != 0 ? 'Press!' : 'Press'),
              ),
            ],
          ),
        ),
      ),
      // Nested Watches that swap at once.
      Styled(
        classes: const ['edge-nested'],
        child: Watch(
          focusEdge.outerV,
          count: 2,
          builder: (o) => Column(
            children: [
              Text(o == 1 ? 'outer odd' : 'outer even'),
              Watch(
                focusEdge.innerV,
                count: 2,
                builder: (i) => Column(
                  children: [
                    TextField(name: 'nest', onChanged: focusEdge.bumpNest),
                    Text(i == 1 ? 'inner odd' : 'inner even'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // A swap inside a Watch.list row.
      Styled(
        classes: const ['edge-list'],
        child: Watch.list(
          focusEdge.rows,
          itemKey: focusEdge.idOf,
          each: (row) => row.watch(
            focusEdge.nOf,
            count: 2,
            builder: (n) => Column(
              children: [
                TextField(
                  name: 'rowF',
                  onChanged: focusEdge.bumpRow.withArg(row.key),
                ),
                if (n == 1) const Text('odd'),
              ],
            ),
          ),
        ),
      ),
      // Ids with CSS-special characters and a duplicated id.
      Styled(
        classes: const ['edge-ids'],
        child: Watch(
          focusEdge.spV,
          count: 2,
          builder: (v) => Column(
            children: [
              TextField(
                id: 'sp:e.c[1]',
                inputAttributes: HtmlAttributes(data: {'k': 'special'}),
                onChanged: focusEdge.bumpSp,
              ),
              TextField(
                id: 'dupid',
                inputAttributes: HtmlAttributes(data: {'k': 'dup1'}),
                onChanged: focusEdge.bumpSp,
              ),
              TextField(
                id: 'dupid',
                inputAttributes: HtmlAttributes(data: {'k': 'dup2'}),
                onChanged: focusEdge.bumpSp,
              ),
              if (v == 1) const Text('odd'),
            ],
          ),
        ),
      ),
    ],
  );
}
