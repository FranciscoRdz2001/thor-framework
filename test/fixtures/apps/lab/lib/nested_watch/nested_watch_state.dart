import 'package:thor_ui/thor_ui.dart';

/// What the Watch nestedWatch page changes in the browser.
class NestedWatchState extends ThorState {
  // Flags; the inner Watches live in a variant of the outer one.
  final outer = state(false);
  final inner = state(false);
  final second = state(false);

  // The list behind every container shape.
  final items = state(const <String>['uno', 'dos']);

  // The day the dialog handed over.
  final picked = state('');

  bool isOuter() => outer.value;
  bool isInner() => inner.value;
  bool isSecond() => second.value;
  void toggleOuter() => outer.value = !outer.value;
  void toggleInner() => inner.value = !inner.value;
  void toggleSecond() => second.value = !second.value;

  String itemKey(String item) => item;
  String itemName(String item) => item;
  void clearItems() => items.value = const [];
  void addItem() => items.value = [...items.value, 'n${items.value.length}'];

  void setPicked(DateTime d) => picked.value = '${d.year}-${d.month}-${d.day}';
  String pickedLabel() => 'Elegido: ${picked.value}';
}

final nestedWatch = NestedWatchState();
