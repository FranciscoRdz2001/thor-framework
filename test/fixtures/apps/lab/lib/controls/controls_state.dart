import 'package:thor_ui/thor_ui.dart';

/// What the controls page changes in the browser: one of each controller,
/// and Duration / DateTime / TimeOfDay math.
class ControlsState extends ThorState {
  final feed = ScrollController();
  final name = TextEditingController(text: 'Ana');
  final nameFocus = FocusNode();
  final sheet = DialogController();
  final elapsed = state(0); // seconds
  final shift = state(0); // days

  String scrollLabel() =>
      'Desplazado: ${feed.offset.round()} de '
      '${feed.position.maxScrollExtent.round()} px '
      '(ventana ${feed.position.viewportDimension.round()})';
  void toTop() => feed.jumpTo(0);
  void toEnd() => feed.jumpTo(feed.position.maxScrollExtent);

  String greeting() => name.text.isEmpty
      ? 'Sin nombre'
      : 'Hola, ${name.text} (${name.text.length})';
  String focusLabel() => nameFocus.hasFocus ? 'Con foco' : 'Sin foco';
  void clearName() => name.clear();
  void setBea() => name.text = 'Bea';
  void focusName() => nameFocus.requestFocus();
  void blurName() => nameFocus.unfocus();

  String sheetLabel() => sheet.isOpen ? 'Hoja abierta' : 'Hoja cerrada';
  void openSheet() => sheet.open();
  void closeSheet() => sheet.close();

  Duration get _elapsed => Duration(seconds: elapsed.value);
  String elapsedLabel() =>
      '$_elapsed · ${_elapsed.inMinutes} min · '
      '${(_elapsed * 1.5).inSeconds} s×1,5 · '
      '${_elapsed > const Duration(minutes: 2) ? 'largo' : 'corto'}';
  void addLap() => elapsed.value += 95;
  void addHour() => elapsed.value += Duration.secondsPerHour;
  void back() => elapsed.value -= 200;

  DateTime get _start => DateTime.utc(2026, 9, 25, 8, 30);
  DateTime get _at =>
      _start.add(Duration(days: shift.value, seconds: elapsed.value));
  String dateLabel() {
    final d = _at;
    final local = DateTime(2026, 1, 31).add(Duration(days: shift.value));
    return '${d.toIso8601String()} · $d · día ${d.weekday} · '
        '${d.difference(_start).inHours} h · '
        '${DateUtils.getDaysInMonth(d.year, d.month)} días en el mes · '
        '${local.year}-${local.month}-${local.day} · '
        '${TimeOfDay.fromDateTime(d)} · '
        '${d.isBefore(DateTime.utc(2026, 10)) ? 'antes' : 'después'} de octubre · '
        '${d.copyWith(day: 1).toIso8601String()} · '
        '${d == DateTime.utc(2026, 9, 25, 8, 30) ? 'inicio' : 'movido'}';
  }

  // A persisted field: the next page (and a reload) starts from it.
  final compact = state(false, cookie: 'compacto');
  bool isCompact() => compact.value;
  void toggleCompact() => compact.value = !compact.value;

  // PageNavigator: leaving the page from the state, only to a safe place.
  final navNote = state('Sin navegar');
  void goNext() => PageNavigator.go('?vista=2');
  void askBack() => navNote.value = 'Puede volver: ${PageNavigator.canPop()}';
  void goBack() => PageNavigator.pop(fallback: '?vista=3');
  void reloadPage() => PageNavigator.reload();
  void tryUnsafe() {
    try {
      PageNavigator.go('javascript:alert(1)');
      navNote.value = 'Navegó';
    } on ArgumentError catch (e) {
      navNote.value = e.toString().contains('THOR-S008')
          ? 'Bloqueado (THOR-S008)'
          : 'Otro error';
    }
  }

  void nextDay() => shift.value++;
  void nextMonth() => shift.value += 31;
  void prevWeek() => shift.value -= 7;
  bool afternoon() => _at.hour >= 12;
}

final controls = ControlsState();
