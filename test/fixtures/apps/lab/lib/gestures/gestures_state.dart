import 'package:thor_ui/thor_ui.dart';

/// A message of the inbox.
class Message {
  const Message(this.id, this.subject);
  final int id;
  final String subject;
}

const _inbox = [
  Message(1, 'Pedido #1042 listo'),
  Message(2, 'Corte de caja del turno'),
  Message(3, 'Nuevo proveedor: Café Altura'),
  Message(4, 'Recordatorio: inventario'),
];

/// Everything the gestures page changes in the browser.
class GesturesState extends ThorState {
  final messages = state(
    _inbox,
    encode: (v) => [
      for (final m in v) [m.id, m.subject],
    ],
    decode: (j) => [
      for (final m in j! as List)
        Message(((m as List)[0] as num).toInt(), m[1] as String),
    ],
  );
  final lastAction = state('Desliza, arrastra o pellizca');
  final likes = state(0);
  final x = state(0.0);
  final y = state(0.0);
  final zoom = state(1.0);

  String status() => lastAction.value;
  String likesLabel() => '♥ ${likes.value}';
  String positionLabel() => 'Posición: ${x.value.round()}, ${y.value.round()}';
  String zoomLabel() => 'Zoom: ${zoom.value.toStringAsFixed(2)}×';

  String messageKey(Message m) => 'm${m.id}';
  String messageSubject(Message m) => m.subject;

  void swiped(String key, SwipeDirection direction) {
    final m = messages.value.firstWhere((m) => messageKey(m) == key);
    batch(() {
      messages.value = [
        for (final other in messages.value)
          if (other.id != m.id) other,
      ];
      lastAction.value = direction == SwipeDirection.start
          ? 'Archivado: ${m.subject}'
          : 'Marcado: ${m.subject}';
    });
  }

  void opened(String key) => lastAction.value = 'Abriste $key';
  void menu(String key) => lastAction.value = 'Menú de $key';

  void like() => likes.value++;
  void moved(double dx, double dy) => batch(() {
    x.value += dx;
    y.value += dy;
    lastAction.value = 'Movido ${dx.round()}, ${dy.round()}';
  });
  void zoomed(double scale) => zoom.value = scale;
  void restore() => batch(() {
    messages.value = _inbox;
    lastAction.value = 'Bandeja restaurada';
  });
}

final gestures = GesturesState();
