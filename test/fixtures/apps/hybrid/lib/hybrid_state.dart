import 'dart:convert';

import 'package:thor_ui/thor_ui.dart';

/// What the page shows about its Flutter views: the last message each one
/// sent (a JSON string, `FlutterView(onMessage:)`).
class HybridState extends ThorState {
  final bar = state('');
  final count = state('');

  String barLabel() => switch (_decode(bar.value)) {
    {'bar': final String name, 'value': final num value} =>
      'Tocaste $name: $value ventas.',
    _ => 'Toca una barra de la gráfica.',
  };

  String countLabel() => switch (_decode(count.value)) {
    {'count': final int n} => 'El contador de Flutter va en $n.',
    _ => 'El contador de Flutter aún no cambia.',
  };

  // A message is data from another program: anything unexpected is ignored.
  static Object? _decode(String message) {
    try {
      return jsonDecode(message);
    } on FormatException {
      return null;
    }
  }

  void onBar(String message) => bar.value = message;
  void onCount(String message) => count.value = message;
}

final hybrid = HybridState();
