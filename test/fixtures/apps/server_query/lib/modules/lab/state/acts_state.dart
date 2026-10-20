import 'package:thor_ui/thor_ui.dart';

/// One row the browser's list shows.
class ActsRow {
  const ActsRow(this.id, this.customer);

  factory ActsRow.fromJson(Map<String, Object?> json) =>
      ActsRow(json['id']! as int, json['customer']! as String);

  final int id;
  final String customer;

  Map<String, Object?> toJson() => {'id': id, 'customer': customer};
}

Object? _encodeRows(List<ActsRow> rows) => [for (final r in rows) r.toJson()];

List<ActsRow> _decodeRows(Object? json) => [
  for (final m in json! as List) ActsRow.fromJson(m as Map<String, Object?>),
];

/// The `/acts` page's state: what a state method does with `confirm`,
/// `toast`, `toggle()`, a set field and `withArgs`, next to the server's
/// page actions (`delete.withArg(id)`, `Redirect.flash`).
class ActsState extends ThorState {
  final rows = state<List<ActsRow>>(
    const [ActsRow(3, 'Ana'), ActsRow(4, 'Luis'), ActsRow(5, 'Marta')],
    encode: _encodeRows,
    decode: _decodeRows,
  );
  final open = state(false);
  final picked = state(<String>{});
  final log = state('');
  // Keys that hold the argument separator and the escape: `~` and `%`.
  final tags = state<List<String>>(const ['a~b', '50%']);

  int idOf(ActsRow r) => r.id;

  /// A row the browser adds (its text comes from `row.text((o) => o.customer)`).
  void addRow() => rows.value = [
    ...rows.value,
    ActsRow(10 + rows.value.length, 'Nueva ${rows.value.length}'),
  ];

  /// The first row changes its customer.
  void renameFirst() => rows.value = [
    for (final r in rows.value)
      if (r == rows.value.first) ActsRow(r.id, '${r.customer}*') else r,
  ];

  /// Asks first, then removes the row in the browser and says so.
  Future<void> removeAsk(int id) async {
    if (!await confirm(
      '¿Eliminar el pedido $id?',
      message: 'Esto no se puede deshacer',
      confirmLabel: 'Eliminar',
    )) {
      log.value = 'cancelado $id';
      return;
    }
    rows.value = [
      for (final r in rows.value)
        if (r.id != id) r,
    ];
    log.value = 'eliminado $id';
    toast('Pedido $id eliminado', kind: ToastKind.success);
  }

  /// Two asks at once: the page queues them, one after the other.
  Future<void> askTwice() async {
    final a = confirm('Primera');
    final b = confirm('Segunda');
    log.value = 'dobles ${await a} ${await b}';
  }

  /// A flood of toasts, each one short.
  void flood(int n) {
    for (var i = 0; i < n; i++) {
      toast('Aviso $i', duration: const Duration(milliseconds: 300));
    }
  }

  /// `ScaffoldMessenger.hideCurrentSnackBar` / `clearSnackBars`.
  void hideNotice() => hideToast();
  void clearNotices() => clearToasts();

  void say(String message) => toast(message);
  void fail() => toast('Falló', kind: ToastKind.error);

  void toggleOpen() => open.toggle();
  bool isOpen() => open.value;

  void pick(String who) => picked.toggle(who);
  bool isPicked(String who) => picked.contains(who);
  String logText() => log.value;
  String pickedText() => 'elegidos: ${picked.value.toList().join(',')}';

  String tagKey(String t) => t;

  /// A row the browser adds, whose key holds `~` and `%`.
  void addTag() => tags.value = [...tags.value, 'x~y%7E'];

  /// The row's key first, then a text: two arguments in one value.
  void mark(String key, String note) => log.value = 'marca $key|$note';

  /// Two arguments bound at once: `acts.tag.withArgs(4, 'a~b')`.
  void tag(int id, String label) => log.value = 'etiqueta $id $label';
}

/// The `/acts` page's state.
final acts = ActsState();
