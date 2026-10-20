import 'package:thor_ui/thor_ui.dart';

/// A message of the inbox.
class Message {
  const Message(this.id, this.subject);
  final int id;
  final String subject;
}

const _seed = [
  Message(1, 'Pedido #1042 listo'),
  Message(2, 'Corte de caja (pide confirmar)'),
  Message(3, 'Nuevo proveedor: Café Altura'),
  Message(4, 'Recordatorio: inventario'),
];

/// The rows that leave by dragging them away.
class InboxState extends ThorState {
  final messages = state(
    _seed,
    encode: (v) => [
      for (final m in v) [m.id, m.subject],
    ],
    decode: (j) => [
      for (final m in j! as List)
        Message(((m as List)[0] as num).toInt(), m[1] as String),
    ],
  );
  final last = state('Desliza una fila');

  String status() => last.value;
  String rowKey(Message m) => 'm${m.id}';
  String subject(Message m) => m.subject;

  /// Every row asks first; the second one says no (it comes back).
  Future<bool> confirm(String key, DismissDirection direction) async {
    last.value = 'Confirmando $key';
    await Future<void>.delayed(const Duration(milliseconds: 30));
    return key != 'm2';
  }

  void dismissed(String key, DismissDirection direction) => batch(() {
    messages.value = [
      for (final m in messages.value)
        if (rowKey(m) != key) m,
    ];
    last.value = 'Descartado $key (${direction.name})';
  });

  void restore() => batch(() {
    messages.value = _seed;
    last.value = 'Bandeja restaurada';
  });
}

final inbox = InboxState();

/// A second list whose rows only go up (a vertical dismissal), with no
/// confirmation and no collapse.
class CardsState extends ThorState {
  final cards = state(
    const [1, 2, 3],
    encode: (v) => v,
    decode: (j) => [for (final n in j! as List) (n as num).toInt()],
  );
  final last = state('Sin cartas descartadas');

  String status() => last.value;
  String rowKey(int n) => 'c$n';
  String label(int n) => 'Carta $n';

  void dismissed(String key, DismissDirection direction) => batch(() {
    cards.value = [
      for (final c in cards.value)
        if (rowKey(c) != key) c,
    ];
    last.value = '$key: ${direction.name}';
  });
}

final cards = CardsState();
