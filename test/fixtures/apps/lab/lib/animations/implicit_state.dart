import 'package:thor_ui/thor_ui.dart';

/// The implicit animations of the page: each flag is a state the elements
/// transition between in CSS.
class ImplicitState extends ThorState {
  final tilted = state(false);
  final lifted = state(false);
  final bold = state(false);

  bool isTilted() => tilted.value;
  bool isLifted() => lifted.value;
  bool isBold() => bold.value;

  void toggleTilt() => tilted.value = !tilted.value;
  void toggleLift() => lifted.value = !lifted.value;
  void toggleBold() => bold.value = !bold.value;
}

final implicit = ImplicitState();
