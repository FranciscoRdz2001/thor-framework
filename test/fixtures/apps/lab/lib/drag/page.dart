import 'package:thor_ui/thor_ui.dart';

import 'board_state.dart';
import 'inbox_state.dart';
import 'reorder_state.dart';

const _card = BoxDecoration(
  color: Color(0xFFFFFFFF),
  borderRadius: BorderRadius.all(Radius.circular(12)),
  boxShadow: [
    BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 1)),
  ],
);
const _h2 = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);

/// The page: one section per widget.
class DragPage extends StatelessWidget implements ThorElementWidget {
  const DragPage({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Semantics(
      role: SemanticsRole.main,
      child: Container(
        constraints: BoxConstraints(maxWidth: 480),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Semantics(
              headingLevel: 1,
              child: Text(
                'Arrastrar',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
            ),
            DismissSection(),
            DropSection(),
            ReorderSection(),
          ],
        ),
      ),
    ),
  );
}

/// `Dismissible`: a list that leaves by dragging a row, and a vertical one.
class DismissSection extends StatelessWidget implements ThorElementWidget {
  const DismissSection({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 8,
    children: [
      const Text('Bandeja: desliza para descartar', style: _h2),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Color(0xFFEEF2FF),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Watch(inbox.status),
      ),
      Watch.list(
        inbox.messages,
        itemKey: inbox.rowKey,
        container: (rows) => Semantics(
          role: SemanticsRole.list,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: rows,
          ),
        ),
        each: (row) => Semantics(
          role: SemanticsRole.listItem,
          child: Dismissible(
            key: ValueKey(row.key),
            onDismissed: inbox.dismissed.withArg(row.key),
            confirmDismiss: inbox.confirm.withArg(row.key),
            background: const Container(
              color: Color(0xFF16A34A),
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Archivar',
                style: TextStyle(color: Color(0xFFFFFFFF)),
              ),
            ),
            secondaryBackground: const Container(
              color: Color(0xFFDC2626),
              alignment: Alignment.centerRight,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Borrar', style: TextStyle(color: Color(0xFFFFFFFF))),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: _card,
              child: row.text(inbox.subject),
            ),
          ),
        ),
      ),
      Row(
        children: [
          TextButton(
            onPressed: inbox.restore,
            child: const Text('Restaurar bandeja'),
          ),
        ],
      ),
      const Text('Cartas: hacia arriba (vertical)', style: _h2),
      Watch(cards.status),
      Watch.list(
        cards.cards,
        itemKey: cards.rowKey,
        container: (rows) => Semantics(
          role: SemanticsRole.list,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: rows,
          ),
        ),
        each: (row) => Semantics(
          role: SemanticsRole.listItem,
          child: Dismissible(
            key: ValueKey(row.key),
            direction: DismissDirection.up,
            resizeDuration: null,
            onDismissed: cards.dismissed.withArg(row.key),
            child: Container(
              height: 64,
              padding: const EdgeInsets.all(16),
              decoration: _card,
              child: row.text(cards.label),
            ),
          ),
        ),
      ),
    ],
  );
}

const _ghost = BoxDecoration(
  color: Color(0xFFFFFFFF),
  borderRadius: BorderRadius.all(Radius.circular(12)),
  boxShadow: [
    BoxShadow(color: Color(0x55000000), blurRadius: 14, offset: Offset(0, 6)),
  ],
);

/// One column of the board: the target is the list's own container.
class _Column extends StatelessWidget implements ThorElementWidget {
  const _Column({
    required this.id,
    required this.title,
    required this.items,
    this.hold = false,
  });

  final String id;
  final String title;
  final StateSignal<List<Task>> items;
  final bool hold;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 4,
    children: [
      Semantics(headingLevel: 3, child: Text(title, style: _h2)),
      Watch.list(
        items,
        itemKey: board.taskKey,
        container: (rows) => Semantics(
          label: title,
          child: DragTarget<String>(
            onWillAcceptWithDetails: board.canDrop.withArg(id),
            onAcceptWithDetails: board.moveTo.withArg(id),
            onLeave: board.left.withArg(id),
            onMove: board.moved.withArg(id),
            overStyle: const StyleProps(
              decoration: BoxDecoration(
                color: Color(0xFFDBEAFE),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            rejectStyle: const StyleProps(
              decoration: BoxDecoration(
                color: Color(0xFFFEE2E2),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            builder: (context, candidates, rejected) => Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: rows,
              ),
            ),
          ),
        ),
        each: (row) => hold
            ? LongPressDraggable<String>(
                data: row.key,
                delay: const Duration(milliseconds: 200),
                feedback: Container(
                  width: 180,
                  padding: const EdgeInsets.all(12),
                  decoration: _ghost,
                  child: row.text(board.taskTitle),
                ),
                child: _card(row),
              )
            : Draggable<String>(
                data: row.key,
                onDragStarted: board.started,
                onDragCompleted: board.completed,
                onDraggableCanceled: board.canceled,
                onDragEnd: board.ended,
                feedback: Container(
                  width: 180,
                  padding: const EdgeInsets.all(12),
                  decoration: _ghost,
                  child: row.text(board.taskTitle),
                ),
                childWhenDragging: const Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Text('…'),
                ),
                child: _card(row),
              ),
      ),
    ],
  );

  Widget _card(WatchRow<Task, String> row) => Container(
    padding: const EdgeInsets.all(12),
    decoration: _card0,
    child: row.text(board.taskTitle),
  );
}

const _card0 = BoxDecoration(
  color: Color(0xFFFFFFFF),
  borderRadius: BorderRadius.all(Radius.circular(12)),
  boxShadow: [
    BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 1)),
  ],
);

/// `Draggable`, `LongPressDraggable` and `DragTarget`: a board of cards, and
/// chips that carry a number to a target that takes only numbers.
class DropSection extends StatelessWidget implements ThorElementWidget {
  const DropSection({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 8,
    children: [
      const Text('Tablero: arrastra tarjetas', style: _h2),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Color(0xFFEEF2FF),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Watch(board.status),
            Watch(board.whereLabel),
            Watch(board.startsLabel),
          ],
        ),
      ),
      _Column(id: 'todo', title: 'Por hacer', items: board.todo),
      _Column(
        id: 'doing',
        title: 'En curso (mantén pulsado)',
        items: board.doing,
        hold: true,
      ),
      _Column(
        id: 'done',
        title: 'Hecho (solo lo que está en curso)',
        items: board.done,
      ),
      Row(
        children: [
          TextButton(onPressed: board.add, child: const Text('Añadir tarjeta')),
        ],
      ),
      const Text('Números: el objetivo solo suma números', style: _h2),
      Row(
        spacing: 8,
        children: [
          for (final n in const [3, 5])
            Draggable<int>(
              data: n,
              feedback: Container(
                padding: const EdgeInsets.all(12),
                decoration: _ghost,
                child: Text('$n'),
              ),
              child: Semantics(
                label: 'Número $n',
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: _card0,
                  child: Text('$n'),
                ),
              ),
            ),
          DragTarget<int>(
            onAcceptWithDetails: board.addNumber,
            overStyle: const StyleProps(opacity: 0.6),
            builder: (context, c, r) => Semantics(
              label: 'Sumador',
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Watch(board.totalLabel),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

/// `ReorderableListView`: a live list (rows cloned from a template), and a row
/// of chips with handles of its own.
class ReorderSection extends StatelessWidget implements ThorElementWidget {
  const ReorderSection({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 8,
    children: [
      const Text('Pendientes: reordena arrastrando', style: _h2),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Color(0xFFEEF2FF),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Watch(reorders.status),
            Watch(reorders.order),
            Watch(reorders.eventsLabel),
          ],
        ),
      ),
      Watch.list(
        reorders.todos,
        itemKey: reorders.todoKey,
        container: (rows) => ReorderableListView(
          onReorder: reorders.reorder,
          onReorderStart: reorders.started,
          onReorderEnd: reorders.ended,
          header: const Text('Lista'),
          footer: const Text('Fin de la lista'),
          children: rows,
        ),
        each: (row) => Container(
          key: ValueKey(row.key),
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.fromLTRB(12, 12, 52, 12),
          decoration: _card0,
          child: row.text(reorders.todoTitle),
        ),
      ),
      Row(
        children: [
          TextButton(
            onPressed: reorders.add,
            child: const Text('Añadir pendiente'),
          ),
        ],
      ),
      const Text('Fichas: con tu propio asa', style: _h2),
      Watch(reorders.chipOrder),
      ReorderableListView(
        onReorder: reorders.reorderChips,
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              key: ValueKey('chip$i'),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(8),
              decoration: _card0,
              child: Row(
                spacing: 8,
                children: [
                  Text(const ['uno', 'dos', 'tres'][i]),
                  ReorderableDragStartListener(
                    index: i,
                    child: const Icon(Icons.drag_handle),
                  ),
                ],
              ),
            ),
        ],
      ),
    ],
  );
}
