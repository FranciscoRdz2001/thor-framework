import 'package:thor_ui/thor_ui.dart';

/// The counter's state: what changes in the browser.
class CounterState extends ThorState {
  final count = state(0);

  String label() => '${count.value}';
  bool isZero() => count.value == 0;
  bool isHigh() => count.value >= 5;
  String highLabel() => '¡Ya van ${count.value}!';

  void inc() => count.value++;
  void dec() => count.value--;
  void reset() => count.value = 0;
}

final counter = CounterState();
