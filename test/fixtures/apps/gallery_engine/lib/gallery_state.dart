import 'package:thor_ui/thor_ui.dart';

const branches = ['Centro', 'Norte', 'Sur'];

/// The tristate "Todos" (all) checkbox: mixed → checked → unchecked → mixed.
enum AllState { mixed, all, none }

/// Everything the controls gallery changes in the browser.
class GalleryState extends ThorState {
  final ticket = state(true);
  final email = state(false);
  final all = state(
    AllState.mixed,
    encode: (t) => t.name,
    decode: (j) => AllState.values.byName(j! as String),
  );
  final dark = state(false);
  final sound = state(true);
  final payment = state('Efectivo');
  final tip = state(10);
  final branch = state<String?>(null);

  void setTicket(bool? v) => ticket.value = v ?? false;
  void setEmail(bool? v) => email.value = v ?? false;
  void setDark(bool v) => dark.value = v;
  void setSound(bool v) => sound.value = v;
  void setPayment(String? v) => payment.value = v ?? payment.value;
  void setTip(double v) => tip.value = v.round();
  void setBranch(String? v) => branch.value = v;

  // The native checkbox only knows checked/unchecked: the cycle is ours.
  void cycleAll(bool? _) => all.value = switch (all.value) {
    AllState.mixed => AllState.all,
    AllState.all => AllState.none,
    AllState.none => AllState.mixed,
  };
  AllState allState() => all.value;

  String tipLabel() => 'Propina: ${tip.value}%';

  String summary() =>
      'Ticket: ${_yesNo(ticket.value)} · Correo: ${_yesNo(email.value)} · '
      'Oscuro: ${_yesNo(dark.value)} · Sonido: ${_yesNo(sound.value)} · '
      'Pago: ${payment.value} · Propina: ${tip.value}% · '
      'Sucursal: ${branch.value ?? '—'}';

  static String _yesNo(bool v) => v ? 'sí' : 'no';
}

final gallery = GalleryState();
