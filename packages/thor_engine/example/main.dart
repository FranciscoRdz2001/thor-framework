// Signals: the reactive core thor's browser engine is built on.
import 'package:thor_engine/thor_engine.dart';

void main() {
  final count = Signal(0);
  final label = Computed(() => 'count: ${count.value}');

  final stop = effect(() => print(label.value)); // count: 0
  count.value++; // count: 1
  batch(() {
    count.value++;
    count.value++;
  }); // count: 3, printed once
  stop();
}
