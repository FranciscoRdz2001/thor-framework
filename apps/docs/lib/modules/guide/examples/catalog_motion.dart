// ignore_for_file: public_member_api_docs
// (each example is named by its region; a doc comment would sit outside
// the code the site shows)
// Motion and pointer events: docs/guia/es/animaciones.md, gestos.md and
// componentes-contenido.md. Each example sits between `// region: <id>` and
// `// endregion`: the site shows that code and renders the same widget.
import 'package:thor_ui/thor_ui.dart';

// region: motion-animated-size
class MoreViewModel extends ThorState {
  final open = state(false);

  bool isOpen() => open.value;
  void toggle() => open.value = !open.value;
}

final more = MoreViewModel();

class AnimatedSizeDemo extends StatelessWidget {
  const AnimatedSizeDemo({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        OutlinedButton(
          onPressed: more.toggle,
          child: Watch(
            more.isOpen,
            builder: (open) => Text(open ? 'Show less' : 'Show more'),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: Watch(
            more.isOpen,
            builder: (open) => Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: ThemeColor.secondaryContainer,
              ),
              child: Text(
                open
                    ? 'Spiced coffee with cinnamon and cane sugar, served in '
                          'a clay mug. It is brewed in a clay pot over low heat '
                          'and sweetened while it simmers.'
                    : 'Spiced coffee with cinnamon.',
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
// endregion

// region: events-hover-focus
class PointerViewModel extends ThorState {
  final hovering = state(false);
  final hasFocus = state(false);

  String hoverLabel() => hovering.value ? 'Mouse is over' : 'Mouse is outside';
  String focusLabel() => hasFocus.value ? 'Focused' : 'Not focused';

  void enter() => hovering.value = true;
  void leave() => hovering.value = false;
  void focusChanged(bool has) => hasFocus.value = has;
}

final pointer = PointerViewModel();

class PointerEventsDemo extends StatelessWidget {
  const PointerEventsDemo({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        MouseRegion(
          onEnter: pointer.enter,
          onExit: pointer.leave,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: ThemeColor.secondaryContainer,
            ),
            child: Watch(pointer.hoverLabel),
          ),
        ),
        Focus(
          canRequestFocus: false,
          onFocusChange: pointer.focusChanged,
          child: Column(
            spacing: 8,
            children: [
              const TextField(
                name: 'name',
                decoration: InputDecoration(labelText: 'Name'),
              ),
              const TextField(
                name: 'email',
                decoration: InputDecoration(labelText: 'Email'),
              ),
              Watch(pointer.focusLabel),
            ],
          ),
        ),
      ],
    ),
  );
}
// endregion

// region: events-expansion
class FaqViewModel extends ThorState {
  final status = state('Tap the question');

  String label() => status.value;
  void changed(bool open) => status.value = open ? 'Open' : 'Closed';
}

final faq = FaqViewModel();

class ExpansionEventsDemo extends StatelessWidget {
  const ExpansionEventsDemo({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExpansionTile(
          title: const Text('Do you ship?'),
          onExpansionChanged: faq.changed,
          children: const [Text('Yes, across the whole city.')],
        ),
        Watch(faq.label),
      ],
    ),
  );
}
// endregion

// region: gesture-swipe-keys
class InboxViewModel extends ThorState {
  final last = state('Swipe the row or use Shift + arrows');

  String label() => last.value;

  void swiped(SwipeDirection direction) => last.value = switch (direction) {
    SwipeDirection.start => 'Archived',
    SwipeDirection.end => 'Flagged',
    _ => 'Other',
  };
}

final inbox = InboxViewModel();

class SwipeKeysDemo extends StatelessWidget {
  const SwipeKeysDemo({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Gesture(
          onSwipe: inbox.swiped,
          swipe: const Swipe(),
          feedback: const Press(),
          child: const Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: ThemeColor.secondaryContainer),
            child: Text('Order #1042 ready'),
          ),
        ),
        Watch(inbox.label),
      ],
    ),
  );
}

// endregion

// region: gesture-inkwell
class TileViewModel extends ThorState {
  final opened = state(0);

  String label() => 'Times opened: ${opened.value}';
  void open() => opened.value++;
}

final tile = TileViewModel();

class InkWellDemo extends StatelessWidget {
  const InkWellDemo({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        InkWell(
          onTap: tile.open,
          borderRadius: BorderRadius.circular(12),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Order #1042'),
          ),
        ),
        Watch(tile.label),
      ],
    ),
  );
}

// endregion

// region: gesture-dismissible
class ArchiveViewModel extends ThorState {
  final rows = state(const [1, 2, 3]);
  final last = state('Swipe a row to either side');

  String label() => last.value;
  String rowKey(int n) => 'r$n';
  String title(int n) => 'Order #${1040 + n}';

  Future<bool> sure(String key, DismissDirection direction) async =>
      direction == DismissDirection.endToStart || key != 'r1';

  void archived(String key, DismissDirection direction) => batch(() {
    rows.value = [
      for (final n in rows.value)
        if (rowKey(n) != key) n,
    ];
    last.value = '$key: ${direction.name}';
  });
}

final archive = ArchiveViewModel();

class DismissibleDemo extends StatelessWidget {
  const DismissibleDemo({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Watch.list(
          archive.rows,
          itemKey: archive.rowKey,
          container: (rows) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: rows,
          ),
          each: (row) => Dismissible(
            key: ValueKey(row.key),
            onDismissed: archive.archived.withArg(row.key),
            confirmDismiss: archive.sure.withArg(row.key),
            background: const Container(
              color: Color(0xFF16A34A),
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Archive',
                style: TextStyle(color: Color(0xFFFFFFFF)),
              ),
            ),
            secondaryBackground: const Container(
              color: Color(0xFFDC2626),
              alignment: Alignment.centerRight,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Delete', style: TextStyle(color: Color(0xFFFFFFFF))),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: ThemeColor.secondaryContainer,
              ),
              child: row.text(archive.title),
            ),
          ),
        ),
        Watch(archive.label),
      ],
    ),
  );
}
// endregion

// region: gesture-draggable
class FruitViewModel extends ThorState {
  final basket = state(0);
  final last = state('Drag a fruit to the basket');

  String label() => last.value;
  String count() => 'In the basket: ${basket.value}';
  bool fits(String name) => name != 'stone';
  void dropped(String name) => batch(() {
    basket.value++;
    last.value = 'Dropped $name';
  });
}

final fruit = FruitViewModel();

class DraggableDemo extends StatelessWidget {
  const DraggableDemo({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Row(
          spacing: 8,
          children: [
            for (final name in const ['apple', 'pear', 'stone'])
              Draggable<String>(
                data: name,
                feedback: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: ThemeColor.surfaceContainer,
                  ),
                  child: Text(name),
                ),
                childWhenDragging: const Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(color: ThemeColor.outlineVariant),
                  child: Text('…'),
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: ThemeColor.secondaryContainer,
                  ),
                  child: Text(name),
                ),
              ),
          ],
        ),
        DragTarget<String>(
          onWillAcceptWithDetails: fruit.fits,
          onAcceptWithDetails: fruit.dropped,
          overStyle: StyleProps(
            decoration: BoxDecoration(
              color: ThemeColor.primary.withValues(alpha: 0.15),
            ),
          ),
          rejectStyle: StyleProps(
            decoration: BoxDecoration(
              color: ThemeColor.error.withValues(alpha: 0.15),
            ),
          ),
          builder: (context, candidates, rejected) => Container(
            height: 72,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: ThemeColor.surfaceContainerHighest,
            ),
            child: Watch(fruit.count),
          ),
        ),
        Watch(fruit.label),
      ],
    ),
  );
}
// endregion

// region: gesture-reorderable
class MotionPlanViewModel extends ThorState {
  final steps = state(const ['Grind', 'Strain', 'Serve', 'Wash']);

  String order() => steps.value.join(' → ');
  String stepKey(String s) => s;
  String stepTitle(String s) => s;

  void reorder(int oldIndex, int newIndex) => batch(() {
    final list = [...steps.value];
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, moved);
    steps.value = list;
  });
}

final plan = MotionPlanViewModel();

class ReorderableDemo extends StatelessWidget {
  const ReorderableDemo({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Watch.list(
          plan.steps,
          itemKey: plan.stepKey,
          container: (rows) =>
              ReorderableListView(onReorder: plan.reorder, children: rows),
          each: (row) => Container(
            key: ValueKey(row.key),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(16, 16, 56, 16),
            decoration: const BoxDecoration(
              color: ThemeColor.secondaryContainer,
            ),
            child: row.text(plan.stepTitle),
          ),
        ),
        Watch(plan.order),
      ],
    ),
  );
}

// endregion
