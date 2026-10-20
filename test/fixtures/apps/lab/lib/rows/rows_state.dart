import 'package:thor_ui/thor_ui.dart';

enum Prio { low, mid, high }

class Task {
  const Task(this.id, this.title, this.done, this.prio, this.stars, this.url);

  final int id;
  final String title;
  final bool done;
  final Prio prio;
  final int stars;
  final String url;

  Task copyWith({
    String? title,
    bool? done,
    Prio? prio,
    int? stars,
    String? url,
  }) => Task(
    id,
    title ?? this.title,
    done ?? this.done,
    prio ?? this.prio,
    stars ?? this.stars,
    url ?? this.url,
  );
}

const _first = [
  Task(1, 'Comprar pan', false, Prio.low, 0, '/tareas/1'),
  Task(2, 'Llamar a Ana', true, Prio.high, 2, 'https://example.com/ana'),
  Task(3, 'Pagar la luz', false, Prio.mid, 1, 'mailto:luz@example.com'),
  Task(4, 'Leer', false, Prio.low, 3, ''),
];

/// Tasks whose rows change state (done, priority, stars) and attributes
/// (link, labels) in place.
class RowsState extends ThorState {
  final tasks = state<List<Task>>(_first);
  final draft = state('');

  /// Runs of the ⌘K / Ctrl+K shortcut and of the focusable tap target: the
  /// early-keys check counts them to prove a key pressed before the engine
  /// loaded runs exactly once.
  final pings = state(0);
  final taps = state(0);
  var _next = 5;

  String taskKey(Task t) => 't${t.id}';
  String titleOf(Task t) => t.title;
  String urlOf(Task t) => t.url;
  String labelOf(Task t) => 'Quitar «${t.title}»';
  String prioName(Task t) => t.prio.name;
  String starsOf(Task t) => '${'★' * t.stars}${'☆' * (3 - t.stars)}';
  int starCount(Task t) => t.stars;

  String summary() {
    final all = tasks.value;
    final done = all.where((t) => t.done).length;
    return '$done de ${all.length} hechas';
  }

  void _edit(String key, Task Function(Task t) change) => tasks.value = [
    for (final t in tasks.value)
      if (taskKey(t) == key) change(t) else t,
  ];

  void setDone(String key, bool? done) =>
      _edit(key, (t) => t.copyWith(done: done ?? false));
  void cycle(String key) =>
      _edit(key, (t) => t.copyWith(prio: Prio.values[(t.prio.index + 1) % 3]));
  void star(String key) =>
      _edit(key, (t) => t.copyWith(stars: (t.stars + 1) % 4));
  void rename(String key) =>
      _edit(key, (t) => t.copyWith(title: '${t.title}!'));
  void unsafe(String key) =>
      _edit(key, (t) => t.copyWith(url: 'javascript:alert(1)'));
  void remove(String key) => tasks.value = [
    for (final t in tasks.value)
      if (taskKey(t) != key) t,
  ];

  /// Enter in the quick field.
  void add(String title) {
    final t = title.trim();
    if (t.isEmpty) return;
    tasks.value = [
      ...tasks.value,
      Task(_next++, t, false, Prio.mid, 0, '/tareas/$_next'),
    ];
  }

  String pingsLabel() => 'atajos: ${pings.value}';
  String tapsLabel() => 'toques: ${taps.value}';
  void ping() => pings.value++;
  void tap() => taps.value++;

  void setDraft(String value) => draft.value = value;

  /// The validated form (the browser only submits a valid one).
  void submit() {
    add(draft.value);
    draft.value = '';
  }

  void reverse() => tasks.value = [...tasks.value.reversed];
  void allDone() =>
      tasks.value = [for (final t in tasks.value) t.copyWith(done: true)];
  void clear() => tasks.value = const [];
  void reset() => tasks.value = _first;
}

final rows = RowsState();
