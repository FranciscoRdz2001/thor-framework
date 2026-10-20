@TestOn('vm')
library;

// `SwitchThemeData.thumbShadow` (web-only): the thumb is a background image,
// so the shadow is drawn inside it. And `Breakpoints.of` / `sizeClassFor`:
// the theme's size class widths, readable from code.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _head(Widget w, {ThemeData? theme}) async {
  final html = await renderDocument(ThorApp(theme: theme, child: w));
  return html.substring(0, html.indexOf('</head>'));
}

void main() {
  setUpAll(initializeThorTests);

  test('without thumbShadow the thumb image is the plain circle', () async {
    final head = await _head(const Switch(value: true));
    expect(head, isNot(contains('feGaussianBlur')));
    expect(head, contains('background-size: 16px 16px'));
  });

  test('thumbShadow draws a blurred circle and grows the image', () async {
    final head = await _head(
      const Switch(value: true),
      theme: ThemeData(
        switchTheme: const SwitchThemeData(
          thumbShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              offset: Offset(0, 1),
              blurRadius: 3,
            ),
          ],
        ),
      ),
    );
    expect(head, contains('feGaussianBlur'));
    // pad = 1 + 3 = 4 on every side: 16 -> 24 and 24 -> 32.
    expect(head, contains('background-size: 24px 24px'));
    expect(head, contains('background-size: 32px 32px'));
    expect(head, contains('background-position: left 2px center'));
    expect(head, contains('background-position: right -2px center'));
  });

  test(
    'Breakpoints.of follows the theme and sizeClassFor the widths',
    () async {
      late Breakpoints seen;
      await renderDocument(
        ThorApp(
          theme: ThemeData(breakpoints: const Breakpoints(medium: 640)),
          child: Builder(
            builder: (context) {
              seen = Breakpoints.of(context);
              return const Text('x');
            },
          ),
        ),
      );
      expect(seen, const Breakpoints(medium: 640));
      expect(seen.sizeClassFor(639), WindowSizeClass.compact);
      expect(seen.sizeClassFor(640), WindowSizeClass.medium);
      expect(
        const Breakpoints().sizeClassFor(1600),
        WindowSizeClass.extraLarge,
      );
      expect(const Breakpoints().sizeClassFor(900), WindowSizeClass.expanded);
    },
  );
}
