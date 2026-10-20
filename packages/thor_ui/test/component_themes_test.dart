// These tests are about the theme's wiring, not the buttons' names.
// ignore_for_file: thor_lints/icon_button_without_name
// ignore_for_file: thor_lints/text_field_without_label
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// Flutter's component themes (`ThemeData.cardTheme`, `chipTheme`,
// `expansionTileTheme`, `*ButtonTheme`): the page's look of a widget kind in
// one place. Order of precedence, as in Flutter: the widget's own parameter,
// then the theme, then the widget's default.

const _x = IconData.svg('x', '<path d="M0 0"/>');

void _noop() {}

Future<String> _under(ThemeData theme, Widget child) =>
    renderHtml(Theme.provide(data: theme, child: child));

void main() {
  setUpAll(initializeThorTests);

  group('CardThemeData', () {
    const theme = CardThemeData(
      color: Color(0xff112233),
      elevation: 0,
      margin: EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(3)),
      ),
    );

    test('without a theme the card keeps its defaults', () async {
      final html = await renderHtml(const Card(child: Text('x')));
      expect(html, contains('margin: 4px'));
      expect(html, contains('border-radius: 12px'));
      expect(html, contains('box-shadow'));
    });

    test('the theme overrides the defaults', () async {
      final html = await _under(
        ThemeData(cardTheme: theme),
        const Card(child: Text('x')),
      );
      expect(html, contains('background-color: #112233'));
      expect(html, contains('margin: 20px'));
      expect(html, contains('border-radius: 3px'));
      expect(html, isNot(contains('box-shadow')), reason: 'elevation 0');
    });

    test('the widget overrides the theme', () async {
      final html = await _under(
        ThemeData(cardTheme: theme),
        const Card(
          color: Color(0xff445566),
          elevation: 2,
          margin: EdgeInsets.all(1),
          child: Text('x'),
        ),
      );
      expect(html, contains('background-color: #445566'));
      expect(html, contains('margin: 1px'));
      expect(html, contains('box-shadow'));
      expect(html, isNot(contains('#112233')));
      expect(html, isNot(contains('margin: 20px')));
      // The shape was not given: the theme's.
      expect(html, contains('border-radius: 3px'));
    });

    test('the theme reaches every card of the page with one class', () async {
      final html = await renderDocument(
        ThorApp(
          theme: ThemeData(cardTheme: theme),
          child: const Column(
            children: [
              Card(child: Text('a')),
              Card(child: Text('b')),
            ],
          ),
        ),
      );
      expect('background-color: #112233'.allMatches(html), hasLength(1));
      expect('class="'.allMatches(html).length, greaterThan(1));
    });
  });

  group('ChipThemeData', () {
    const theme = ChipThemeData(
      backgroundColor: Color(0xff102030),
      selectedColor: Color(0xff405060),
      shape: StadiumBorder(),
      labelStyle: TextStyle(fontSize: 11),
      padding: EdgeInsets.all(7),
      showCheckmark: true,
      deleteIconColor: Color(0xffaa0000),
    );

    test('Chip reads the theme and the widget wins', () async {
      final themed = await _under(
        ThemeData(chipTheme: theme),
        const Chip(label: Text('a')),
      );
      expect(themed, contains('background-color: #102030'));
      expect(themed, contains('border-radius: 9999px'));
      expect(themed, contains('font-size: 11px'));
      expect(themed, contains('padding: 7px'));
      final own = await _under(
        ThemeData(chipTheme: theme),
        const Chip(label: Text('a'), backgroundColor: Color(0xff0000ff)),
      );
      expect(own, contains('background-color: #0000ff'));
      expect(own, isNot(contains('#102030')));
    });

    test('the selected chips read selectedColor and showCheckmark', () async {
      final html = await _under(
        ThemeData(chipTheme: theme),
        FilterChip(label: const Text('a'), selected: true, onSelected: (_) {}),
      );
      expect(html, contains('#405060'));
      expect(html, contains(r'content: "\2713"'));
      final own = await _under(
        ThemeData(chipTheme: theme),
        FilterChip(
          label: const Text('a'),
          selected: true,
          selectedColor: const Color(0xff00ff00),
          showCheckmark: false,
          onSelected: (_) {},
        ),
      );
      expect(own, contains('#00ff00'));
      expect(own, isNot(contains('#405060')));
      expect(own, isNot(contains(r'\2713')));
    });

    test('every chip kind reads it', () async {
      for (final chip in <Widget>[
        const InputChip(label: Text('a'), onPressed: _noop),
        ChoiceChip(label: const Text('a'), selected: false, onSelected: (_) {}),
        const ActionChip(label: Text('a'), onPressed: _noop),
      ]) {
        final html = await _under(ThemeData(chipTheme: theme), chip);
        expect(html, contains('background-color: #102030'), reason: '$chip');
      }
    });

    test('a theme with nothing set changes nothing', () async {
      final plain = await renderHtml(const Chip(label: Text('a')));
      final empty = await _under(
        ThemeData(chipTheme: const ChipThemeData()),
        const Chip(label: Text('a')),
      );
      expect(empty, plain);
    });
  });

  group('ExpansionTileThemeData', () {
    const theme = ExpansionTileThemeData(
      backgroundColor: Color(0xff0a0b0c),
      collapsedBackgroundColor: Color(0xff0d0e0f),
      iconColor: Color(0xffaa1111),
      collapsedIconColor: Color(0xff11aa11),
      textColor: Color(0xff2222bb),
      collapsedTextColor: Color(0xff333333),
      tilePadding: EdgeInsets.symmetric(horizontal: 6),
      childrenPadding: EdgeInsets.all(9),
      shape: RoundedRectangleBorder(),
    );
    const tile = ExpansionTile(title: Text('t'), children: [Text('c')]);

    test('the theme overrides the defaults', () async {
      final html = await _under(ThemeData(expansionTileTheme: theme), tile);
      for (final v in [
        '#0a0b0c',
        '#0d0e0f',
        '#aa1111',
        '#11aa11',
        '#2222bb',
        '#333333',
        'padding: 9px',
      ]) {
        expect(html, contains(v), reason: v);
      }
    });

    test('the widget overrides the theme', () async {
      final html = await _under(
        ThemeData(expansionTileTheme: theme),
        const ExpansionTile(
          title: Text('t'),
          iconColor: Color(0xff777777),
          childrenPadding: EdgeInsets.all(1),
          children: [Text('c')],
        ),
      );
      expect(html, contains('#777777'));
      expect(html, isNot(contains('#aa1111')));
      expect(html, contains('padding: 1px'));
      expect(html, isNot(contains('padding: 9px')));
      expect(html, contains('#11aa11'), reason: 'the rest is the theme\'s');
    });

    test('without a theme the defaults stay', () async {
      final html = await renderHtml(tile);
      expect(html, contains('padding: 0px 16px 16px'));
    });
  });

  group('button themes', () {
    const filled = ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(Color(0xff010203)),
      foregroundColor: WidgetStatePropertyAll(Color(0xfffefdfc)),
      padding: WidgetStatePropertyAll(EdgeInsets.all(11)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
    );

    test('each variant reads its own theme only', () async {
      final theme = ThemeData(
        filledButtonTheme: const FilledButtonThemeData(style: filled),
        elevatedButtonTheme: const ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(Color(0xff040506)),
          ),
        ),
        outlinedButtonTheme: const OutlinedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(Color(0xff070809)),
          ),
        ),
        textButtonTheme: const TextButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(Color(0xff0a0b0d)),
          ),
        ),
      );
      final cases = <(Widget, String)>[
        (const FilledButton(onPressed: _noop, child: Text('a')), '#010203'),
        (const ElevatedButton(onPressed: _noop, child: Text('a')), '#040506'),
        (const OutlinedButton(onPressed: _noop, child: Text('a')), '#070809'),
        (const TextButton(onPressed: _noop, child: Text('a')), '#0a0b0d'),
      ];
      for (final (button, color) in cases) {
        final html = await _under(theme, button);
        expect(html, contains('background-color: $color'), reason: '$button');
        for (final (_, other) in cases) {
          if (other != color) expect(html, isNot(contains(other)));
        }
      }
    });

    test(
      'the button\'s style wins field by field, the theme fills the rest',
      () async {
        final html = await _under(
          ThemeData(
            filledButtonTheme: const FilledButtonThemeData(style: filled),
          ),
          const FilledButton(
            onPressed: _noop,
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(Color(0xff999999)),
            ),
            child: Text('a'),
          ),
        );
        expect(html, contains('background-color: #999999'));
        expect(html, isNot(contains('#010203')));
        expect(html, contains('padding: 11px'), reason: 'from the theme');
        expect(html, contains('color: #fefdfc'), reason: 'from the theme');
      },
    );

    test('the theme overrides the variant\'s default', () async {
      final plain = await renderHtml(
        const FilledButton(onPressed: _noop, child: Text('a')),
      );
      expect(plain, isNot(contains('padding: 11px')));
      expect(plain, contains('padding: 10px 24px'));
      final themed = await _under(
        ThemeData(
          filledButtonTheme: const FilledButtonThemeData(style: filled),
        ),
        const FilledButton(onPressed: _noop, child: Text('a')),
      );
      expect(themed, isNot(contains('padding: 10px 24px')));
    });

    test('a theme with no style changes nothing', () async {
      final plain = await renderHtml(
        const FilledButton(onPressed: _noop, child: Text('a')),
      );
      final empty = await _under(
        ThemeData(filledButtonTheme: const FilledButtonThemeData()),
        const FilledButton(onPressed: _noop, child: Text('a')),
      );
      expect(empty, plain);
    });

    test('a theme overlayColor is the hover fill', () async {
      final html = await _under(
        ThemeData(
          textButtonTheme: const TextButtonThemeData(
            style: ButtonStyle(
              overlayColor: WidgetStatePropertyAll(Color(0xff123456)),
            ),
          ),
        ),
        const TextButton(onPressed: _noop, child: Text('a')),
      );
      expect(html, contains('background-color: #123456'));
    });

    test('IconButton (every kind) reads IconButtonThemeData', () async {
      final theme = ThemeData(
        iconButtonTheme: const IconButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(Color(0xff0f0e0d)),
            iconSize: WidgetStatePropertyAll(30),
          ),
        ),
      );
      for (final b in <Widget>[
        const IconButton(icon: Icon(_x), onPressed: _noop),
        const IconButton.filled(icon: Icon(_x), onPressed: _noop),
        const IconButton.outlined(icon: Icon(_x), onPressed: _noop),
      ]) {
        final html = await _under(theme, b);
        expect(html, contains('color: #0f0e0d'), reason: '$b');
      }
      final own = await _under(
        theme,
        const IconButton(
          icon: Icon(_x),
          onPressed: _noop,
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(Color(0xff111111)),
          ),
        ),
      );
      expect(own, contains('color: #111111'));
      expect(own, isNot(contains('#0f0e0d')));
    });

    test(
      'the buttons inside a Theme(data:) subtree follow that subtree',
      () async {
        final html = await _under(
          ThemeData(
            filledButtonTheme: const FilledButtonThemeData(style: filled),
          ),
          Column(
            children: [
              const FilledButton(onPressed: _noop, child: Text('a')),
              Theme.provide(
                data: ThemeData(),
                child: const FilledButton(onPressed: _noop, child: Text('b')),
              ),
            ],
          ),
        );
        expect('background-color: #010203'.allMatches(html), hasLength(1));
      },
    );
  });

  group('InputDecorationTheme', () {
    test('fills what the field leaves null; the field wins', () async {
      final theme = ThemeData(
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xff101010),
          contentPadding: EdgeInsets.all(5),
        ),
      );
      final html = await _under(
        theme,
        const TextField(
          decoration: InputDecoration(contentPadding: EdgeInsets.all(2)),
        ),
      );
      expect(html, contains('background-color: #101010'));
      expect(html, contains('padding: 2px'));
      expect(html, isNot(contains('padding: 5px')));
    });
  });

  test(
    'the themes follow the dark switch through ThemeColor variables',
    () async {
      final theme = ThemeData(
        cardTheme: const CardThemeData(color: ThemeColor.primary),
      );
      final html = await _under(theme, const Card(child: Text('x')));
      expect(html, contains('background-color: var(--t-primary'));
    },
  );
}
