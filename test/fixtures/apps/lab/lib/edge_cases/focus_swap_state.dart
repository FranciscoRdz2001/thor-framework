import 'package:thor_ui/thor_ui.dart';

/// Two fields whose section swaps its variant while the user types: a hint
/// shows under them until each has three characters (focus-swap check).
class FocusSwapState extends ThorState {
  final first = state('');
  final second = state('');

  void setFirst(String value) => first.value = value;
  void setSecond(String value) => second.value = value;

  bool firstShort() => first.value.length < 3;
  bool secondShort() => second.value.length < 3;

  /// 0..3: which hints show. One `Watch` for both fields so a swap replaces
  /// the subtree that holds the focused one.
  int hints() => (firstShort() ? 1 : 0) + (secondShort() ? 2 : 0);
}

final focusSwap = FocusSwapState();
