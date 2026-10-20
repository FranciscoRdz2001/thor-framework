import 'package:thor_ui/thor_ui.dart';

/// The `/defer` page's state: a counter inside content that arrives late.
class DeferState extends ThorState {
  final count = state(0);

  void increment() => count.value++;

  String label() => 'clicks=${count.value}';
}

/// The `/defer` page's state.
final deferState = DeferState();
