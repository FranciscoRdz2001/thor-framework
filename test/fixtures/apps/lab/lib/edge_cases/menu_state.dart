import 'package:thor_ui/thor_ui.dart';

/// What the `DropdownMenu` case picks: the value and how many picks
/// reached the state (a pick of the same entry counts too).
class MenuState extends ThorState {
  final fruit = state('banana');
  final picks = state(0);

  void setFruit(String? value) => batch(() {
    fruit.value = value ?? fruit.value;
    picks.value++;
  });

  String fruitLabel() => 'Picked: ${fruit.value} (${picks.value})';
}

final menu = MenuState();
