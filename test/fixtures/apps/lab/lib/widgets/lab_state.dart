import 'package:thor_ui/thor_ui.dart';

/// What the lab page changes in the browser.
class LabState extends ThorState {
  final hovered = state(false);
  final hoverEvents = state(0);
  final focused = state(false);
  final focusEvents = state(0);
  final expansion = state('Sin tocar');
  final more = state(false);
  final faded = state(false);
  final flag = state(false);
  final wide = state(false);
  final sizeEnds = state(0);

  /// The panel that opens and closes (SizeTransition).
  final panel = AnimationController(
    duration: const Duration(milliseconds: 300),
    reverseDuration: const Duration(milliseconds: 300),
  );

  String hoverLabel() =>
      '${hovered.value ? 'Encima' : 'Fuera'} · ${hoverEvents.value}';
  void enter() => batch(() {
    hovered.value = true;
    hoverEvents.value++;
  });
  void leave() => batch(() {
    hovered.value = false;
    hoverEvents.value++;
  });

  String focusLabel() =>
      '${focused.value ? 'Con foco' : 'Sin foco'} · ${focusEvents.value}';
  void focusChanged(bool hasFocus) => batch(() {
    focused.value = hasFocus;
    focusEvents.value++;
  });

  String expansionLabel() => expansion.value;
  void expansionChanged(bool open) =>
      expansion.value = open ? 'Abierto' : 'Cerrado';

  bool isMore() => more.value;
  void toggleMore() => more.value = !more.value;

  bool isFaded() => faded.value;
  void toggleFade() => faded.value = !faded.value;

  bool isWide() => wide.value;
  void toggleWide() => wide.value = !wide.value;
  void sizeEnded() => sizeEnds.value++;
  String sizeEndLabel() => 'Fin: ${sizeEnds.value}';

  void toggleFlag() => flag.value = !flag.value;

  void togglePanel() => panel.toggle();
}

final lab = LabState();
