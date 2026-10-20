@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

const _ghost = ButtonStyle(
  backgroundColor: WidgetStatePropertyAll(Color(0x00000000)),
  foregroundColor: WidgetStatePropertyAll(Color(0xff111111)),
  overlayColor: WidgetStatePropertyAll(Color(0x11000000)),
  padding: WidgetStatePropertyAll(EdgeInsets.all(8)),
  minimumSize: WidgetStatePropertyAll(Size(0, 32)),
  shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
  side: WidgetStatePropertyAll(BorderSide.none),
  textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 14)),
  alignment: Alignment.centerLeft,
  animationDuration: Duration(milliseconds: 100),
);

List<Object?> _fields(ButtonStyle s) => [
  s.backgroundColor?.resolve({}),
  s.foregroundColor?.resolve({}),
  s.overlayColor?.resolve({}),
  s.padding?.resolve({}),
  s.minimumSize?.resolve({}),
  s.shape?.resolve({}),
  s.side?.resolve({}),
  s.textStyle?.resolve({}),
  s.alignment,
  s.animationDuration,
];

void main() {
  setUpAll(initializeThorTests);

  test('copyWith with nothing keeps every field', () {
    expect(_fields(_ghost.copyWith()), _fields(_ghost));
  });

  test('copyWith replaces each field it is given, and only that one', () {
    const red = Color(0xffff0000);
    final all = _ghost.copyWith(
      backgroundColor: const WidgetStatePropertyAll(red),
      foregroundColor: const WidgetStatePropertyAll(red),
      overlayColor: const WidgetStatePropertyAll(red),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      minimumSize: const WidgetStatePropertyAll(Size.zero),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      side: const WidgetStatePropertyAll(BorderSide(color: red)),
      textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 20)),
      alignment: Alignment.center,
      animationDuration: Duration.zero,
    );
    expect(_fields(all), [
      red,
      red,
      red,
      EdgeInsets.zero,
      Size.zero,
      const StadiumBorder(),
      const BorderSide(color: red),
      const TextStyle(fontSize: 20),
      Alignment.center,
      Duration.zero,
    ]);
    final one = _ghost.copyWith(
      foregroundColor: const WidgetStatePropertyAll(red),
    );
    expect(one.foregroundColor?.resolve({}), red);
    expect(_fields(one)..removeAt(1), _fields(_ghost)..removeAt(1));
  });

  test("merge: this style's fields win, the other fills the nulls", () {
    const red = Color(0xffff0000);
    const partial = ButtonStyle(foregroundColor: WidgetStatePropertyAll(red));
    expect(_fields(partial.merge(_ghost)), [
      _ghost.backgroundColor?.resolve({}),
      red,
      ..._fields(_ghost).skip(2),
    ]);
    // The other's fields don't override this one's.
    expect(_fields(_ghost.merge(partial)), _fields(_ghost));
    // Null: the same style.
    expect(identical(_ghost.merge(null), _ghost), isTrue);
  });

  test('a varied token style renders its override', () async {
    final style = _ghost.copyWith(
      foregroundColor: const WidgetStatePropertyAll(Color(0xffff0000)),
    );
    final html = await renderDocument(
      ThorApp(
        child: TextButton(
          onPressed: null,
          style: style,
          child: const Text('x'),
        ),
      ),
    );
    expect(html, contains('#ff0000'));
  });

  test('a background with its own hover replaces the default hover', () async {
    String hoverRules(String html) =>
        RegExp(r':hover\{[^}]*\}').allMatches(html).map((m) => m[0]!).join(' ');

    // Without its own hover: the default overlay (and its shadow).
    final plain = await renderDocument(
      const ThorApp(
        child: FilledButton(
          href: '/a',
          onPressed: null,
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(Color(0xFF030712)),
          ),
          child: Text('a'),
        ),
      ),
    );
    expect(hoverRules(plain), contains('box-shadow'));

    // With it: only that one, no shadow nor color-mix fighting it.
    final own = await renderDocument(
      ThorApp(
        child: FilledButton(
          href: '/a',
          onPressed: null,
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(
              const Color(0xFF030712).when(hover: const Color(0xFF926D0E)),
            ),
          ),
          child: const Text('a'),
        ),
      ),
    );
    final rules = hoverRules(own);
    expect(rules, contains('#926d0e'));
    expect(rules, isNot(contains('box-shadow')));
    expect(rules, isNot(contains('color-mix')));
  });
}
