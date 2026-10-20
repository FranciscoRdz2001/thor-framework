// ignore_for_file: public_member_api_docs
// (each example is named by its region; a doc comment would sit outside
// the code the site shows)
// The live examples of the "State" guide. Each one sits between
// `// region: <id>` and `// endregion`: the site shows that code (with its
// thor_ui import) and renders the same widget on the page. Unlike
// gallery.dart these carry state, so the page that shows them loads the
// engine.
import 'dart:async';

import 'package:thor_ui/thor_ui.dart';

// region: state-bool
class FavoriteViewModel extends ThorState {
  final saved = state(false);

  bool isSaved() => saved.value;
  void toggle() => saved.value = !saved.value;
}

final favorite = FavoriteViewModel();

class FavoriteExample extends StatelessWidget {
  const FavoriteExample({super.key});

  @override
  Widget build(BuildContext context) => Watch(
    favorite.isSaved,
    builder: (saved) => saved
        ? FilledButton(onPressed: favorite.toggle, child: const Text('★ Saved'))
        : OutlinedButton(
            onPressed: favorite.toggle,
            child: const Text('☆ Save'),
          ),
  );
}
// endregion

// region: state-enum
enum Billing { monthly, yearly }

class PlanViewModel extends ThorState {
  final billing = state(Billing.monthly);

  Billing current() => billing.value;
  void select(Billing value) => billing.value = value;
}

final plan = PlanViewModel();

class PlanExample extends StatelessWidget {
  const PlanExample({super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 12,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          OutlinedButton(
            onPressed: plan.select.withArg(Billing.monthly),
            child: const Text('Monthly'),
          ),
          OutlinedButton(
            onPressed: plan.select.withArg(Billing.yearly),
            child: const Text('Yearly'),
          ),
        ],
      ),
      Watch(
        plan.current,
        builder: (billing) => Text(switch (billing) {
          Billing.monthly => r'$12 a month',
          Billing.yearly => r'$120 a year (2 months free)',
        }, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
    ],
  );
}
// endregion

// region: state-todo
class Todo {
  const Todo(this.id, this.title, {this.done = false});

  final int id;
  final String title;
  final bool done;

  factory Todo.fromJson(Map<String, Object?> json) => Todo(
    json['id']! as int,
    json['title']! as String,
    done: json['done']! as bool,
  );

  Map<String, Object?> toJson() => {'id': id, 'title': title, 'done': done};

  Todo toggled() => Todo(id, title, done: !done);
}

class TodoViewModel extends ThorState {
  final todos = state(const [
    Todo(1, 'Buy coffee'),
    Todo(2, 'Call Ana', done: true),
  ]);
  final draft = TextEditingController();

  // The rows the list draws, and what each one shows from its item.
  List<Todo> rows() => todos.value;
  String idOf(Todo t) => '${t.id}';
  String title(Todo t) => t.title;
  bool isDone(Todo t) => t.done;

  String summary() {
    final done = todos.value.where((t) => t.done).length;
    return '$done of ${todos.value.length} done';
  }

  void add() {
    final title = draft.text.trim();
    if (title.isEmpty) return;
    final id = todos.value.isEmpty ? 1 : todos.value.last.id + 1;
    todos.value = [...todos.value, Todo(id, title)];
    draft.clear();
  }

  void toggle(String id) => todos.value = [
    for (final t in todos.value)
      if (idOf(t) == id) t.toggled() else t,
  ];

  void remove(String id) => todos.value = [
    for (final t in todos.value)
      if (idOf(t) != id) t,
  ];
}

final todoList = TodoViewModel();

class TodoExample extends StatelessWidget {
  const TodoExample({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: TextField(
                controller: todoList.draft,
                decoration: const InputDecoration(hintText: 'New task'),
              ),
            ),
            FilledButton(onPressed: todoList.add, child: const Text('Add')),
          ],
        ),
        Watch.list(
          todoList.rows,
          itemKey: todoList.idOf,
          each: (row) => Row(
            spacing: 8,
            children: [
              row.watch(
                todoList.isDone,
                builder: (done) => TextButton(
                  onPressed: todoList.toggle.withArg(row.key),
                  child: Text(done ? '☑' : '☐'),
                ),
              ),
              Expanded(child: row.text(todoList.title)),
              TextButton(
                onPressed: todoList.remove.withArg(row.key),
                child: const Text('Remove'),
              ),
            ],
          ),
        ),
        Watch(
          todoList.summary,
          style: const TextStyle(color: ThemeColor.onSurfaceVariant),
        ),
      ],
    ),
  );
}
// endregion

// region: state-form
class OrderViewModel extends ThorState {
  final name = state('');
  final quantity = state(1);
  final gift = state(false);

  // Computed values: plain getters, used by the methods.
  int get total => quantity.value * 45 + (gift.value ? 20 : 0);

  String summary() {
    final who = name.value.isEmpty ? 'someone' : name.value;
    final wrap = gift.value ? ', gift wrapped' : '';
    return '${quantity.value} × coffee for $who$wrap: \$$total';
  }

  void setName(String value) => name.value = value;
  void setQuantity(double value) => quantity.value = value.round();
  void setGift(bool value) => gift.value = value;
}

final order = OrderViewModel();

class OrderExample extends StatelessWidget {
  const OrderExample({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        TextField(
          onChanged: order.setName,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        Slider(
          value: 1,
          min: 1,
          max: 6,
          divisions: 5,
          onChanged: order.setQuantity,
          semanticLabel: 'Quantity',
        ),
        SwitchListTile(
          value: false,
          onChanged: order.setGift,
          title: const Text('Gift wrap'),
        ),
        Watch(
          order.summary,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
// endregion

// region: state-keyed
class ScoreViewModel extends ThorState {
  ScoreViewModel({super.key});

  final points = state(0);

  String label() => '${points.value}';
  void score() => points.value++;
}

final home = ScoreViewModel(key: 'home');
final away = ScoreViewModel(key: 'away');

class ScoreExample extends StatelessWidget {
  const ScoreExample({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    spacing: 32,
    children: [TeamScore('Home', home), TeamScore('Away', away)],
  );
}

class TeamScore extends StatelessWidget {
  const TeamScore(this.name, this.team);

  final String name;
  final ScoreViewModel team;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 8,
    children: [
      Text(name),
      Watch(
        team.label,
        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
      ),
      OutlinedButton(onPressed: team.score, child: const Text('+1')),
    ],
  );
}
// endregion

// region: state-controllers
class ProfileViewModel extends ThorState {
  final name = TextEditingController(text: 'Ana');
  final nameFocus = FocusNode();
  final confirm = DialogController();
  final saved = state(false);

  String greeting() => name.text.isEmpty ? 'No name' : 'Hello, ${name.text}';
  bool wasSaved() => saved.value;

  void edit() => nameFocus.requestFocus();
  void askToSave() => confirm.open();
  void cancel() => confirm.close();

  void save() {
    confirm.close();
    saved.value = true;
    Timer(const Duration(seconds: 2), () => saved.value = false);
  }
}

final profile = ProfileViewModel();

class ProfileExample extends StatelessWidget {
  const ProfileExample({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        TextField(
          controller: profile.name,
          focusNode: profile.nameFocus,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        Watch(profile.greeting),
        Row(
          spacing: 8,
          children: [
            OutlinedButton(onPressed: profile.edit, child: const Text('Edit')),
            FilledButton(
              onPressed: profile.askToSave,
              child: const Text('Save'),
            ),
          ],
        ),
        Watch(
          profile.wasSaved,
          builder: (saved) => Text(
            saved ? 'Changes saved' : '',
            style: TextStyle(
              color: const Color(
                0xFF047857,
              ).when(dark: const Color(0xFF34D399)),
            ),
          ),
        ),
        AlertDialog(
          controller: profile.confirm,
          title: const Text('Save the changes?'),
          content: Watch(profile.greeting),
          actions: [
            TextButton(onPressed: profile.cancel, child: const Text('Cancel')),
            FilledButton(onPressed: profile.save, child: const Text('Save')),
          ],
        ),
      ],
    ),
  );
}

// endregion

// region: state-pages
class DeckViewModel extends ThorState {
  final pages = PageController();
  final shown = state(0);

  String label() => 'Page ${shown.value + 1} of 3';
  bool isShown(int i) => shown.value == i;

  // The browser tells which page the swipe settled on.
  void changed(int page) => shown.value = page;

  void previous() => pages.animateToPage(
    (pages.page!.round() - 1).clamp(0, 2),
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
  );
  void next() => pages.animateToPage(
    (pages.page!.round() + 1).clamp(0, 2),
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
  );
  void first() => pages.jumpToPage(0);
}

final deck = DeckViewModel();

class DeckExample extends StatelessWidget {
  const DeckExample({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        SizedBox(
          height: 96,
          child: PageView(
            controller: deck.pages,
            onPageChanged: deck.changed,
            children: const [
              Center(child: Text('One')),
              Center(child: Text('Two')),
              Center(child: Text('Three')),
            ],
          ),
        ),
        Watch(deck.label),
        Row(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: deck.previous,
              child: const Text('Previous'),
            ),
            OutlinedButton(onPressed: deck.next, child: const Text('Next')),
            TextButton(onPressed: deck.first, child: const Text('First')),
          ],
        ),
      ],
    ),
  );
}
// endregion

// region: state-lifecycle
class ClockViewModel extends ThorState {
  final seconds = state(0);
  Timer? timer;

  String label() => '${seconds.value} s on this page';

  @override
  void onHydrated() {
    timer = Timer.periodic(
      const Duration(seconds: 1),
      (t) => seconds.value = t.tick,
    );
  }

  @override
  void dispose() => timer?.cancel();
}

final clock = ClockViewModel();

class ClockExample extends StatelessWidget {
  const ClockExample({super.key});

  @override
  Widget build(BuildContext context) =>
      Watch(clock.label, style: const TextStyle(fontSize: 24));
}
// endregion

// region: state-notifier
class PanelViewModel extends ThorState {
  final open = state(false);

  void toggle() => open.value = !open.value;
}

final panel = PanelViewModel();

class PanelExample extends StatelessWidget {
  const PanelExample({super.key});

  @override
  Widget build(BuildContext context) => Row(
    spacing: 16,
    children: [
      OutlinedButton(onPressed: panel.toggle, child: const Text('Toggle')),
      ValueListenableBuilder<bool>(
        valueListenable: panel.open,
        builder: (context, open, child) => Text(open ? 'Open' : 'Closed'),
      ),
    ],
  );
}

// endregion

// region: state-feedback
class TasksViewModel extends ThorState {
  final tasks = state(<String>['Buy coffee', 'Call Ana', 'Send the invoice']);

  String summary() => 'Tasks: ${tasks.value.length}';

  Future<void> remove(String title) async {
    // One native <dialog> for the page: the answer is a Future<bool>.
    if (!await confirm(
      'Remove "$title"?',
      message: 'This cannot be undone',
      confirmLabel: 'Remove',
    )) {
      return;
    }
    tasks.value = [
      for (final t in tasks.value)
        if (t != title) t,
    ];
    // One snack bar for the page, with a live region for screen readers.
    toast('Task removed', kind: ToastKind.success);
  }

  void restore() {
    tasks.value = ['Buy coffee', 'Call Ana', 'Send the invoice'];
    toast('Tasks restored');
  }

  // The message on screen goes; clearToasts() also drops the ones waiting.
  void quiet() => hideToast();
}

final tasks = TasksViewModel();

class TasksExample extends StatelessWidget {
  const TasksExample({super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 8,
    children: [
      for (final title in const ['Buy coffee', 'Call Ana', 'Send the invoice'])
        OutlinedButton(
          onPressed: tasks.remove.withArg(title),
          child: Text('Remove "$title"'),
        ),
      Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          TextButton(onPressed: tasks.restore, child: const Text('Restore')),
          TextButton(onPressed: tasks.quiet, child: const Text('Hide notice')),
          Watch(tasks.summary),
        ],
      ),
    ],
  );
}
// endregion

// region: state-set
class ChipsViewModel extends ThorState {
  final picked = state(<String>{});
  final expanded = state(false);

  bool isPicked(String name) => picked.contains(name);
  String summary() => picked.isEmpty
      ? 'Nothing picked'
      : 'Picked: ${picked.value.toList().join(', ')}';

  void pick(String name) => picked.toggle(name);
  void toggleMore() => expanded.toggle();
  bool isExpanded() => expanded.value;
}

final chips = ChipsViewModel();

class ChipsExample extends StatelessWidget {
  const ChipsExample({super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 8,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          for (final name in const ['Ana', 'Luis', 'Marta'])
            Watch(
              chips.isPicked.withArg(name),
              builder: (on) => on
                  ? FilledButton(
                      onPressed: chips.pick.withArg(name),
                      child: Text(name),
                    )
                  : OutlinedButton(
                      onPressed: chips.pick.withArg(name),
                      child: Text(name),
                    ),
            ),
        ],
      ),
      Watch(chips.summary),
      TextButton(onPressed: chips.toggleMore, child: const Text('More')),
      Watch(
        chips.isExpanded,
        builder: (open) => Text(open ? 'Showing the detail' : 'Detail hidden'),
      ),
    ],
  );
}

// endregion
