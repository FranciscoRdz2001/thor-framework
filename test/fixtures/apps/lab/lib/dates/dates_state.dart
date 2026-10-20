import 'package:thor_ui/thor_ui.dart';

/// What the dates page changes in the browser.
class DatesState extends ThorState {
  final day = state('2026-09-25');
  final due = state('');
  final at = state('09:30');
  final shown = state('2026-09');

  final dueDialog = DialogController();

  void setDay(DateTime d) => day.value = _iso(d);
  void setShown(DateTime month) => shown.value = _iso(month).substring(0, 7);
  void setDue(DateTime d) => due.value = _iso(d);
  void setAt(TimeOfDay t) => at.value =
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
  void openDue() => dueDialog.open();

  String dayLabel() => 'Elegiste: ${day.value}';
  String shownLabel() => 'Mes a la vista: ${shown.value}';
  String dueLabel() =>
      due.value.isEmpty ? 'Sin fecha de entrega' : 'Entrega: ${due.value}';
  String atLabel() => 'Hora: ${at.value}';
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

final dates = DatesState();
