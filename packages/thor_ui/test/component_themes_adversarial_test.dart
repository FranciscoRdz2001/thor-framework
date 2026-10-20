// Fixtures: the wiring of themes, not the buttons' names.
// ignore_for_file: thor_lints/icon_button_without_name
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// Precedence and nesting of the component themes, the dark switch, and the
// states of a chip.

void _noop() {}

Future<String> _under(ThemeData theme, Widget child) =>
    renderHtml(Theme.provide(data: theme, child: child));

void main() {
  setUpAll(initializeThorTests);

  group('ButtonStyle over the button theme', () {
    const theme = TextButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(Color(0xff010203)),
        foregroundColor: WidgetStatePropertyAll(Color(0xff0a0b0c)),
        padding: WidgetStatePropertyAll(EdgeInsets.all(13)),
        side: WidgetStatePropertyAll(
          BorderSide(color: Color(0xff777777), width: 3),
        ),
      ),
    );

    test('a null field of the widget style falls to the theme', () async {
      final html = await _under(
        ThemeData(textButtonTheme: theme),
        const TextButton(
          onPressed: _noop,
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(Color(0xff999999)),
          ),
          child: Text('a'),
        ),
      );
      expect(html, contains('color: #999999'));
      expect(html, isNot(contains('#0a0b0c')));
      expect(html, contains('background-color: #010203'));
      expect(html, contains('padding: 13px'));
    });

    test('an explicit BorderSide.none wins over the theme side', () async {
      final html = await _under(
        ThemeData(textButtonTheme: theme),
        const TextButton(
          onPressed: _noop,
          style: ButtonStyle(side: WidgetStatePropertyAll(BorderSide.none)),
          child: Text('a'),
        ),
      );
      expect(html, isNot(contains('#777777')));
    });

    test(
      'a zero minimumSize and a 0 icon size are values, not nulls',
      () async {
        final html = await _under(
          ThemeData(
            textButtonTheme: const TextButtonThemeData(
              style: ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size(80, 60)),
              ),
            ),
          ),
          const TextButton(
            onPressed: _noop,
            style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size.zero)),
            child: Text('a'),
          ),
        );
        expect(html, contains('min-width: 0px'));
        expect(html, isNot(contains('min-width: 80px')));
      },
    );

    test('a disabled button still takes the theme', () async {
      final html = await _under(
        ThemeData(textButtonTheme: theme),
        const TextButton(onPressed: null, child: Text('a')),
      );
      expect(html, contains('background-color: #010203'));
    });

    test('a link button takes the theme too', () async {
      final html = await _under(
        ThemeData(textButtonTheme: theme),
        const TextButton(href: '/x', child: Text('a')),
      );
      expect(html, contains('padding: 13px'));
    });

    test('the button style is not changed by a render (no mutation)', () async {
      const own = ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(Color(0xff999999)),
      );
      final t = ThemeData(textButtonTheme: theme);
      await _under(
        t,
        const TextButton(onPressed: _noop, style: own, child: Text('a')),
      );
      expect(own.backgroundColor, isNull);
      expect(
        theme.style!.foregroundColor?.resolve({}),
        const Color(0xff0a0b0c),
      );
    });
  });

  group('Theme.provide nesting', () {
    test('the inner theme replaces the outer one, it does not merge', () async {
      final outer = ThemeData(
        cardTheme: const CardThemeData(color: Color(0xff112233)),
        chipTheme: const ChipThemeData(backgroundColor: Color(0xff445566)),
      );
      final inner = ThemeData(
        cardTheme: const CardThemeData(color: Color(0xff778899)),
      );
      final html = await _under(
        outer,
        Column(
          children: [
            const Card(child: Text('outer')),
            const Chip(label: Text('outer chip')),
            Theme.provide(
              data: inner,
              child: const Column(
                children: [
                  Card(child: Text('inner')),
                  Chip(label: Text('inner chip')),
                ],
              ),
            ),
          ],
        ),
      );
      expect('#112233'.allMatches(html), hasLength(1));
      expect('#778899'.allMatches(html), hasLength(1));
      // Flutter: Theme(data:) is the whole theme, so the chip inside has none.
      expect('#445566'.allMatches(html), hasLength(1));
    });

    test('copyWith extends the outer theme, as in Flutter', () async {
      final outer = ThemeData(
        cardTheme: const CardThemeData(color: Color(0xff112233)),
        chipTheme: const ChipThemeData(backgroundColor: Color(0xff445566)),
      );
      final html = await _under(
        outer,
        Builder(
          builder: (context) => Theme.provide(
            data: Theme.of(context).copyWith(
              cardTheme: const CardThemeData(color: Color(0xff778899)),
            ),
            child: const Column(
              children: [
                Card(child: Text('i')),
                Chip(label: Text('c')),
              ],
            ),
          ),
        ),
      );
      expect(html, contains('#778899'));
      expect(html, isNot(contains('#112233')));
      expect(html, contains('#445566'), reason: 'the chip theme is kept');
    });
  });

  group('dark mode', () {
    test('ThemeColor values stay variables in the folded class', () async {
      final html = await _under(
        ThemeData(
          cardTheme: const CardThemeData(color: ThemeColor.primaryContainer),
          chipTheme: const ChipThemeData(
            backgroundColor: ThemeColor.surfaceContainer,
            selectedColor: ThemeColor.primary,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(
                ThemeColor.token('brand'),
              ),
            ),
          ),
        ),
        Column(
          children: [
            const Card(child: Text('a')),
            FilterChip(
              label: const Text('c'),
              selected: true,
              onSelected: (_) {},
            ),
            const FilledButton(onPressed: _noop, child: Text('b')),
          ],
        ),
      );
      expect(html, contains('var(--t-primary-container'));
      expect(html, contains('var(--t-surface-container'));
      expect(html, contains('var(--t-primary'));
      expect(html, contains('var(--t-brand'));
    });

    test('only the active theme is read: darkTheme component themes are not '
        'folded (documented: use ThemeColor)', () async {
      final html = await renderDocument(
        ThorApp(
          theme: ThemeData(
            cardTheme: const CardThemeData(color: Color(0xff112233)),
          ),
          darkTheme: ThemeData.dark().copyWith(
            cardTheme: const CardThemeData(color: Color(0xff998877)),
          ),
          child: const Card(child: Text('a')),
        ),
      );
      expect(html, contains('#112233'));
      expect(html, isNot(contains('#998877')));
    });

    test('a fixed ThemeMode.dark reads the dark theme', () async {
      final html = await renderDocument(
        ThorApp(
          theme: ThemeData(
            cardTheme: const CardThemeData(color: Color(0xff112233)),
          ),
          darkTheme: ThemeData.dark().copyWith(
            cardTheme: const CardThemeData(color: Color(0xff998877)),
          ),
          themeMode: ThemeMode.dark,
          child: const Card(child: Text('a')),
        ),
      );
      expect(html, contains('#998877'));
      expect(html, isNot(contains('#112233')));
    });
  });

  group('chips: selected and disabled', () {
    const theme = ChipThemeData(
      backgroundColor: Color(0xff102030),
      selectedColor: Color(0xff405060),
      disabledColor: Color(0xff708090),
    );

    test('a disabled chip takes the theme disabledColor', () async {
      final html = await _under(
        ThemeData(chipTheme: theme),
        const ActionChip(label: Text('a'), onPressed: null),
      );
      expect(
        html,
        matches(
          RegExp(r'aria-disabled="true"\]\)\{[^}]*background-color: #708090'),
        ),
      );
    });

    test('a disabled chip with a delete control takes it too', () async {
      final html = await _under(
        ThemeData(chipTheme: theme),
        const InputChip(
          label: Text('a'),
          isEnabled: false,
          onPressed: null,
          onDeleted: _noop,
        ),
      );
      expect(html, contains('aria-disabled="true"'));
      expect(
        html,
        matches(
          RegExp(r'aria-disabled="true"\]\{[^}]*background-color: #708090'),
        ),
      );
    });

    test('no disabledColor in the theme, no disabled background', () async {
      final html = await _under(
        ThemeData(
          chipTheme: const ChipThemeData(backgroundColor: Color(0xff102030)),
        ),
        const ActionChip(label: Text('a'), onPressed: null),
      );
      expect(html, isNot(matches(RegExp(r':disabled\{[^}]*background-color'))));
    });

    test('a selected chip is its selectedColor, enabled or not', () async {
      for (final enabled in [true, false]) {
        final html = await _under(
          ThemeData(chipTheme: theme),
          FilterChip(
            label: const Text('a'),
            selected: true,
            onSelected: enabled ? (_) {} : null,
          ),
        );
        expect(html, contains('#405060'), reason: 'enabled: $enabled');
      }
    });

    test('an unselected chip does not leak the selected color', () async {
      final html = await _under(
        ThemeData(chipTheme: theme),
        FilterChip(label: const Text('a'), selected: false, onSelected: (_) {}),
      );
      expect(html, contains('aria-pressed="false"'));
      // The selected color is only under [aria-pressed="true"].
      expect(
        html,
        isNot(matches(RegExp(r'\.\w+\{[^}]*background-color: #405060'))),
      );
    });
  });
}
