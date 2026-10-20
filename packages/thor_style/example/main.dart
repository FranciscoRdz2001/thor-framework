// Flutter's value types compile to CSS: pure Dart, no DOM.
import 'package:thor_style/thor_style.dart';

void main() {
  const decoration = BoxDecoration(
    color: Color(0xFFF7F8FA),
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );
  print(decoration.toCss()); // {background-color: #f7f8fa, border-radius: 16px}
  print(Curves.easeOutBack.css); // cubic-bezier(0.175, 0.885, 0.32, 1.275)
}
