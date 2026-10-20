import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

/// Style values compare by value, like Flutter's (web-only fields included).
void main() {
  void same(Object a, Object b) {
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  }

  test('BorderSide, Border, BoxShadow, Shadow', () {
    same(
      const BorderSide(color: Color(0xFF112233), width: 2),
      const BorderSide(color: Color(0xFF112233), width: 2),
    );
    expect(const BorderSide(width: 2), isNot(const BorderSide(width: 3)));
    same(Border.all(width: 2), Border.all(width: 2));
    expect(Border.all(width: 2), isNot(Border.all(width: 1)));
    same(
      const BoxShadow(blurRadius: 4, offset: Offset(0, 2)),
      const BoxShadow(blurRadius: 4, offset: Offset(0, 2)),
    );
    expect(
      const BoxShadow(blurRadius: 4),
      isNot(const BoxShadow(blurRadius: 4, inset: true)),
    );
    same(const Shadow(blurRadius: 2), const Shadow(blurRadius: 2));
  });

  test('gradients', () {
    // Built at run time (not `const`), so equal ones are not identical.
    LinearGradient linear({Color last = Colors.blue, Size? tile}) =>
        LinearGradient(colors: [Colors.red, last], stops: [0, 1], tile: tile);
    RadialGradient radial({double radius = 0.5}) =>
        RadialGradient(colors: [Colors.red, Colors.blue], radius: radius);
    expect(identical(linear(), linear()), isFalse);
    same(linear(), linear());
    expect(linear(), isNot(linear(last: Colors.green)));
    same(
      linear(tile: const Size.square(4)),
      linear(tile: const Size.square(4)),
    );
    expect(linear(), isNot(linear(tile: const Size.square(4))));
    same(radial(radius: 0.3), radial(radius: 0.3));
    expect(radial(), isNot(linear()));
    expect(radial(radius: 0.3), isNot(radial()));
  });

  test('BoxDecoration compares every field', () {
    BoxDecoration make({double blur = 4}) => BoxDecoration(
      color: Colors.white,
      border: Border.all(),
      borderRadius: BorderRadius.circular(8),
      boxShadow: [BoxShadow(blurRadius: blur)],
      gradient: const LinearGradient(colors: [Colors.red, Colors.blue]),
    );
    same(make(), make());
    expect(make(), isNot(make(blur: 5)));
    expect(
      const BoxDecoration(image: DecorationImage(url: 'a.png')),
      const BoxDecoration(image: DecorationImage(url: 'a.png')),
    );
    expect(
      const BoxDecoration(shape: BoxShape.circle),
      isNot(const BoxDecoration()),
    );
  });

  test('TextStyle compares every field, web-only ones too', () {
    TextStyle make({Length? size}) => TextStyle(
      color: Colors.black,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      fontFamilyFallback: const ['serif'],
      decoration: TextDecoration.combine([
        TextDecoration.underline,
        TextDecoration.lineThrough,
      ]),
      shadows: const [Shadow(blurRadius: 1)],
      fontFeatures: const [FontFeature.tabularFigures()],
      fontSizeLength: size,
    );
    same(make(), make());
    expect(make(), isNot(make(size: 1.2.em)));
    same(make(size: 1.2.em), make(size: 1.2.em));
    expect(
      const TextStyle(role: TextThemeRole.bodyLarge),
      isNot(const TextStyle()),
    );
    same(
      TextDecoration.combine([
        TextDecoration.underline,
        TextDecoration.overline,
      ]),
      TextDecoration.combine([
        TextDecoration.overline,
        TextDecoration.underline,
      ]),
    );
  });

  test('values built with .when() compare by base and variants', () {
    TextStyle make(double medium) =>
        const TextStyle(fontSize: 14).when(medium: TextStyle(fontSize: medium));
    same(make(18), make(18));
    expect(make(18), isNot(make(20)));
    expect(make(18), isNot(const TextStyle(fontSize: 14)));
    expect(const TextStyle(fontSize: 14), isNot(make(18)));

    BoxDecoration deco(Color hover) => const BoxDecoration(
      color: Colors.white,
    ).when(hover: BoxDecoration(color: hover));
    same(deco(Colors.red), deco(Colors.red));
    expect(deco(Colors.red), isNot(deco(Colors.blue)));
  });

  test('equal styles render the same CSS', () {
    // Built at run time (not `const`), so they are not identical.
    TextStyle make(double size) => TextStyle(
      fontSize: size,
      color: Colors.black,
      shadows: [Shadow(blurRadius: size)],
    );
    final a = make(14), b = make(14);
    expect(identical(a, b), isFalse);
    same(a, b);
    expect(a.toCss(), b.toCss());
  });
}
