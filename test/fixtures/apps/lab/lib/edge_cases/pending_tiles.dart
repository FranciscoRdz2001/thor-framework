import 'package:thor_ui/thor_ui.dart';

import 'pending_state.dart';

/// A `CheckboxListTile` list with a delete `IconButton` as its `secondary`,
/// rows added in the browser (tile-secondary check).
class PendingTiles extends StatelessWidget {
  const PendingTiles({super.key});

  @override
  Widget build(BuildContext context) =>
      Column(children: [_lab(), const SizedBox(height: 16), _static()]);

  Widget _lab() => Styled(
    classes: const ['tile-lab'],
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  name: 'pendiente',
                  decoration: const InputDecoration(
                    labelText: 'Nueva pendiente',
                  ),
                  onChanged: pending.setNewText,
                  onSubmitted: pending.addPendingOnSubmit,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: pending.addPending,
                child: const Text('Agregar pendiente'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          Watch(pending.completionLabel),
          Watch.list(
            pending.todos,
            itemKey: pending.idOf,
            each: (row) => row.watch(
              pending.isDone,
              builder: (done) => CheckboxListTile(
                value: done,
                onChanged: pending.toggleDone.withArg(row.key),
                title: DefaultTextStyle(
                  style: TextStyle(
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                  child: row.text(pending.titleOf),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                secondary: IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Eliminar',
                  onPressed: pending.removePending.withArg(row.key),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _static() => Styled(
    classes: const ['tile-static'],
    child: Column(
      children: [
        CheckboxListTile(
          value: false,
          onChanged: (_) {},
          title: const Text('Icono'),
          secondary: const Icon(Icons.delete),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          value: false,
          onChanged: (_) {},
          title: const Text('Icono final'),
          secondary: const Icon(Icons.delete),
        ),
        CheckboxListTile(
          value: false,
          onChanged: (_) {},
          title: const Text('Con interruptor'),
          secondary: Switch(value: false, onChanged: (_) {}),
        ),
        const CheckboxListTile(
          value: false,
          onChanged: null,
          title: Text('Apagado'),
          secondary: Icon(Icons.delete),
        ),
      ],
    ),
  );
}
