import 'package:thor_ui/thor_ui.dart';

import 'rows_state.dart';

const _muted = TextStyle(color: Color(0xFF666666), fontSize: 13);

/// A task list: every row has states (done, priority, stars) and bound
/// attributes, plus a quick field and a validated form to add tasks.
class RowsPage extends StatelessWidget implements ThorElementWidget {
  const RowsPage({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      role: SemanticsRole.main,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            const Text(
              'Tareas',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            Watch(rows.summary),
            // ⌘K or Ctrl+K anywhere on the page, and a tap target the
            // keyboard reaches: both must work before the engine loads.
            CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                    rows.ping,
                const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                    rows.ping,
              },
              child: Row(
                spacing: 8,
                children: [
                  Watch(rows.pingsLabel),
                  Gesture(
                    onTap: rows.tap,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Watch(rows.tapsLabel),
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _button('Invertir', rows.reverse),
                _button('Todas hechas', rows.allDone),
                _button('Vaciar', rows.clear),
                _button('Restaurar', rows.reset),
              ],
            ),
            Form(
              action: '/tareas',
              child: Watch.list(
                rows.tasks,
                itemKey: rows.taskKey,
                container: (children) => Semantics(
                  role: SemanticsRole.list,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
                each: _row,
              ),
            ),
            TextField(
              name: 'quick',
              onSubmitted: rows.add,
              clearOnSubmitted: true,
              decoration: const InputDecoration(
                labelText: 'Agregar rápido (Enter)',
              ),
            ),
            Form(
              action: '/nueva',
              onSubmit: rows.submit,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  TextFormField(
                    name: 'title',
                    onChanged: rows.setDraft,
                    decoration: const InputDecoration(
                      labelText: 'Nueva tarea',
                      helperText: 'Al menos 3 letras',
                    ),
                    validators: [
                      const Validator.required('Escribe la tarea'),
                      const Validator.minLength(3, 'Mínimo 3 letras'),
                    ],
                  ),
                  Row(
                    children: [
                      FilledButton(
                        buttonType: ButtonType.submit,
                        onPressed: () {},
                        child: const Text('Guardar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  static Widget _button(String label, void Function() onPressed) =>
      OutlinedButton(onPressed: onPressed, child: Text(label));
}

/// A row: the row itself is a state (done or not), with states inside it
/// (priority, stars), a link and labels bound to the task, and a hidden
/// field that posts with the form.
///
/// Wrappers around a `row.watch` (the `<li>` role, a bound attribute)
/// decorate each of its states the same.
Widget _row(WatchRow<Task, String> row) => Semantics(
  role: SemanticsRole.listItem,
  child: row.watch(
    // Lambdas over a bool and an enum property: the browser reads them
    // ($Rows) in both engines, like row.text((t) => t.title).
    (Task t) => t.done,
    builder: (bool done) => Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      color: done ? const Color(0xFFEFF7EE) : const Color(0xFFFFFFFF),
      child: Row(
        spacing: 8,
        children: [
          Checkbox(value: done, onChanged: rows.setDone.withArg(row.key)),
          Expanded(
            child: row.attribute(
              AttributeName.href,
              rows.urlOf,
              child: Link(
                href: const RouteUrl('#'),
                // A lambda over a property: the browser reads it (`$Rows`)
                // in both engines.
                child: row.text(
                  (Task t) => t.title,
                  style: TextStyle(
                    decoration: done
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
          row.attribute(
            AttributeName.data('prio'),
            rows.prioName,
            child: row.watch(
              (Task t) => t.prio,
              builder: (Prio p) => TextButton(
                onPressed: rows.cycle.withArg(row.key),
                child: Text(switch (p) {
                  Prio.low => 'baja',
                  Prio.mid => 'media',
                  Prio.high => 'alta',
                }),
              ),
            ),
          ),
          row.watch(
            rows.starCount,
            count: 4,
            builder: (int n) => TextButton(
              onPressed: rows.star.withArg(row.key),
              child: Text('$n/3'),
            ),
          ),
          row.text(rows.starsOf, style: _muted),
          TextButton(
            onPressed: rows.rename.withArg(row.key),
            child: const Text('!'),
          ),
          TextButton(
            onPressed: rows.unsafe.withArg(row.key),
            child: const Text('js'),
          ),
          row.attribute(
            AttributeName.ariaOf(AriaAttribute.label),
            rows.labelOf,
            child: TextButton(
              onPressed: rows.remove.withArg(row.key),
              child: const Text('×'),
            ),
          ),
          row.field('tarea', rows.titleOf),
        ],
      ),
    ),
  ),
);
