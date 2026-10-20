import 'package:thor_ui/thor_ui.dart';

import 'notes_state.dart';

const _row = BoxDecoration(
  color: Color(0xFFEEF2FF),
  borderRadius: BorderRadius.all(Radius.circular(10)),
);

/// A list of notes whose rows grow in and shrink out.
class NotesPage extends StatelessWidget implements ThorElementWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      role: SemanticsRole.main,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            const Semantics(
              headingLevel: 1,
              child: Text(
                'Notas',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
            ),
            Watch(notes.countLabel),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: notes.add,
                  child: const Text('Agregar'),
                ),
                OutlinedButton(
                  onPressed: notes.clear,
                  child: const Text('Vaciar'),
                ),
                OutlinedButton(
                  onPressed: notes.reset,
                  child: const Text('Restaurar'),
                ),
              ],
            ),
            AnimatedList<Note, int>(
              notes.notes.call,
              itemKey: notes.idOf,
              duration: const Duration(milliseconds: 300),
              container: (rows) => Semantics(
                role: SemanticsRole.list,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: rows,
                ),
              ),
              // The row grows from nothing and fades in; leaving, the same
              // backwards. `animation` is 1 at rest and 0 where it starts.
              itemBuilder: (context, row, animation) => Semantics(
                role: SemanticsRole.listItem,
                child: SizeTransition(
                  sizeFactor: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  ),
                  child: FadeTransition(
                    opacity: animation,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: _row,
                        child: Row(
                          children: [
                            Expanded(child: row.text(notes.titleOf)),
                            TextButton(
                              onPressed: notes.remove.withArg(row.key),
                              child: const Text('Quitar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
