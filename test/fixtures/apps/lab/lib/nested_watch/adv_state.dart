import 'package:thor_ui/thor_ui.dart';

enum Five { a, b, c, d, e }

/// State for the harder cases of the Watch nestedWatch page.
class AdvState extends ThorState {
  // Three levels of nested variants.
  final l1 = state(false);
  final l2 = state(false);
  final l3 = state(false);

  // An enum with five values inside a variant, two of them drawing the same.
  final o2 = state(false);
  final five = state(Five.a);

  // Two states that draw the very same markup, inside a variant.
  final o3 = state(false);
  final same = state(false);
  final other = state(false);

  // A keyed list (with row states) inside a variant.
  final o4 = state(false);
  final xs = state(const <String>['p', 'q']);

  // A thousand Watches inside a variant.
  final o5 = state(false);
  final flag = state(false);

  bool isL1() => l1.value;
  bool isL2() => l2.value;
  bool isL3() => l3.value;
  void toggleL1() => l1.value = !l1.value;
  void toggleL2() => l2.value = !l2.value;
  void toggleL3() => l3.value = !l3.value;

  bool isO2() => o2.value;
  void toggleO2() => o2.value = !o2.value;
  Five fiveOf() => five.value;
  void nextFive() => five.value = Five.values[(five.value.index + 1) % 5];

  bool isO3() => o3.value;
  bool isSame() => same.value;
  bool isOther() => other.value;
  void toggleO3() => o3.value = !o3.value;
  void toggleSame() => same.value = !same.value;
  void toggleOther() => other.value = !other.value;

  bool isO4() => o4.value;
  void toggleO4() => o4.value = !o4.value;
  String xsKey(String s) => s;
  String xsName(String s) => s;
  bool xsMarked(String s) => s.startsWith('q');
  void addX() => xs.value = [...xs.value, 'n${xs.value.length}'];
  void reverseX() => xs.value = xs.value.reversed.toList();
  void dropFirstX() => xs.value = xs.value.skip(1).toList();
  void resetX() => xs.value = const ['p', 'q'];
  void clearX() => xs.value = const [];
  void markLast() => xs.value = [for (final s in xs.value) s == 'p' ? 'q9' : s];

  bool isO5() => o5.value;
  bool isFlag() => flag.value;
  void toggleO5() => o5.value = !o5.value;
  void toggleFlag() => flag.value = !flag.value;
}

final adv = AdvState();

/// Another state, watched from inside the rows of a list and from a list
/// that lives in a variant in a row.
class OtherState extends ThorState {
  final label = state('L0');
  final mode = state(false);
  final items = state(const <String>['n1', 'n2']);

  String labelOf() => label.value;
  bool isMode() => mode.value;
  String itemKey(String s) => s;
  String itemName(String s) => s;
  void nextLabel() =>
      label.value = 'L${int.parse(label.value.substring(1)) + 1}';
  void toggleMode() => mode.value = !mode.value;
  void addItem() =>
      items.value = [...items.value, 'n${items.value.length + 1}'];
}

final other = OtherState();
