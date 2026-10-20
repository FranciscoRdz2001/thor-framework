import 'dart:async';

import 'package:thor_ui/thor_ui.dart';

const categories = ['Café', 'Postres', 'Snacks', 'Bebidas'];

const _names = {'edit': 'Editar', 'copy': 'Duplicar', 'delete': 'Eliminar'};

/// Everything the content gallery changes in the browser.
class ContentState extends ThorState {
  final chips = state<List<bool>>([
    for (var i = 0; i < categories.length; i++) i == 0,
  ]);
  final email = state('');
  final welcome = state('');
  final picked = state('');
  final snack = state(false);
  Timer? _hide;

  bool chipSelected(int i) => chips.value[i];
  void setChip(int i, bool selected) =>
      chips.value = [...chips.value]..[i] = selected;

  void setEmail(String value) => email.value = value;
  void login() => welcome.value = 'Hola, ${email.value}';
  String welcomeText() => welcome.value;

  /// Menu choice: shows a snackbar for 3 s (like ScaffoldMessenger).
  void pick(String value) {
    picked.value = _names[value] ?? '';
    snack.value = true;
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () => snack.value = false);
  }

  bool snackVisible() => snack.value;
  String snackText() => 'Elegiste: ${picked.value}';
}

final content = ContentState();
