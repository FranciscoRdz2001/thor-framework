// These tests are about the themes' wiring, not the widgets' names.
// ignore_for_file: thor_lints/icon_button_without_name
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// The rest of Flutter's component themes (`ThemeData.dividerTheme`,
// `dialogTheme`, `appBarTheme`…). Same order of precedence as the first ones:
// the widget's own parameter, then the theme, then the widget's default.

Future<String> _under(ThemeData theme, Widget child) =>
    renderHtml(Theme.provide(data: theme, child: child));

const _teal = Color(0xff009688);
const _plum = Color(0xff8e24aa);

void main() {
  setUpAll(initializeThorTests);

  group('DividerThemeData', () {
    const theme = DividerThemeData(
      color: _teal,
      thickness: 3,
      space: 30,
      indent: 5,
      endIndent: 7,
    );

    test('without a theme the divider keeps its defaults', () async {
      final html = await renderHtml(const Divider());
      expect(html, contains('border-top: 1px solid'));
      expect(html, contains('margin-block: 7.5px; margin-inline: 0px'));
    });

    test('the theme overrides the defaults', () async {
      final html = await _under(
        ThemeData(dividerTheme: theme),
        const Divider(),
      );
      expect(html, contains('border-top: 3px solid #009688'));
      expect(
        html,
        contains(
          'margin-block: 13.5px; margin-inline-start: 5px; margin-inline-end: 7px',
        ),
      );
    });

    test('the widget overrides the theme', () async {
      final html = await _under(
        ThemeData(dividerTheme: theme),
        const Divider(color: _plum, thickness: 2, height: 10),
      );
      expect(html, contains('border-top: 2px solid #8e24aa'));
      expect(html, isNot(contains('#009688')));
      // The indents were not given: the theme's.
      expect(
        html,
        contains(
          'margin-block: 4px; margin-inline-start: 5px; margin-inline-end: 7px',
        ),
      );
    });

    test('VerticalDivider reads it too', () async {
      final html = await _under(
        ThemeData(dividerTheme: theme),
        const VerticalDivider(),
      );
      expect(html, contains('border-left: 3px solid #009688'));
      final own = await _under(
        ThemeData(dividerTheme: theme),
        const VerticalDivider(color: _plum),
      );
      expect(own, contains('#8e24aa'));
      expect(own, isNot(contains('#009688')));
    });
  });

  group('DialogThemeData', () {
    const theme = DialogThemeData(
      backgroundColor: _teal,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(5)),
      ),
      titleTextStyle: TextStyle(fontSize: 31),
      contentTextStyle: TextStyle(fontSize: 13),
      barrierColor: Color(0x80112233),
      elevation: 0,
    );

    test('the AlertDialog keeps its defaults without a theme', () async {
      final html = await renderHtml(const AlertDialog(title: Text('t')));
      expect(html, contains('border-radius: 28px'));
      expect(html, contains('box-shadow: 0 8px 24px'));
    });

    test('a heading level on the title keeps the title size', () async {
      final html = await renderHtml(
        const AlertDialog(title: Semantics(headingLevel: 2, child: Text('t'))),
      );
      expect(html, contains('font-size: var(--t-headline-small-size, 24px)'));
      expect(html, isNot(contains('font-size: inherit')));
    });

    test('the theme overrides the AlertDialog defaults', () async {
      final html = await _under(
        ThemeData(dialogTheme: theme),
        const AlertDialog(title: Text('t'), content: Text('c')),
      );
      expect(html, contains('background-color: #009688'));
      expect(html, contains('border-radius: 5px'));
      expect(html, contains('font-size: 31px'));
      expect(html, contains('font-size: 13px'));
      expect(html, contains('rgba(17, 34, 51'));
      expect(html, contains('box-shadow: none'));
    });

    test('the Dialog takes the theme and its own parameters win', () async {
      final themed = await _under(
        ThemeData(dialogTheme: theme),
        const Dialog(child: Text('x')),
      );
      expect(themed, contains('background-color: #009688'));
      expect(themed, contains('border-radius: 5px'));
      final own = await _under(
        ThemeData(dialogTheme: theme),
        const Dialog(
          backgroundColor: _plum,
          barrierColor: Color(0x80445566),
          child: Text('x'),
        ),
      );
      expect(own, contains('background-color: #8e24aa'));
      expect(own, isNot(contains('#009688')));
      expect(own, contains('rgba(68, 85, 102'));
    });
  });

  group('DialogThemeData.barrierFilter', () {
    String backdrop(String html) => RegExp(r'::backdrop\{[^}]*\}')
        .allMatches(html.replaceAll(RegExp(r'\s+(?=[:{])'), ''))
        .map((m) => m[0]!)
        .join();

    test('filters what is behind the dialog, in both dialogs', () async {
      final theme = ThemeData(
        dialogTheme: DialogThemeData(
          barrierFilter: ImageFilter.blur(sigmaX: 3),
        ),
      );
      final alert = await _under(theme, const AlertDialog(title: Text('t')));
      expect(backdrop(alert), contains('backdrop-filter: blur(3px)'));
      final dialog = await _under(theme, const Dialog(child: Text('x')));
      expect(backdrop(dialog), contains('backdrop-filter: blur(3px)'));
    });

    test(
      'Dialog(barrierFilter:) wins over the theme; none by default',
      () async {
        final own = await _under(
          ThemeData(
            dialogTheme: DialogThemeData(
              barrierFilter: ImageFilter.blur(sigmaX: 3),
            ),
          ),
          Dialog(
            barrierFilter: ImageFilter.blur(sigmaX: 8),
            child: const Text('x'),
          ),
        );
        expect(backdrop(own), contains('blur(8px)'));
        expect(backdrop(own), isNot(contains('blur(3px)')));
        final none = await _under(ThemeData(), const Dialog(child: Text('x')));
        expect(none, isNot(contains('backdrop-filter')));
      },
    );

    test('copyWith keeps and replaces it', () {
      final a = DialogThemeData(barrierFilter: ImageFilter.blur(sigmaX: 3));
      expect(a.copyWith().barrierFilter, a.barrierFilter);
      expect(
        a.copyWith(barrierFilter: ImageFilter.blur(sigmaX: 1)).barrierFilter,
        ImageFilter.blur(sigmaX: 1),
      );
    });
  });

  group('AppBarThemeData', () {
    const theme = AppBarThemeData(
      backgroundColor: _teal,
      foregroundColor: Color(0xffffffff),
      elevation: 4,
      centerTitle: true,
      toolbarHeight: 80,
      titleTextStyle: TextStyle(fontSize: 19),
    );

    test('the theme overrides the defaults', () async {
      final html = await _under(
        ThemeData(appBarTheme: theme),
        const AppBar(title: Text('t')),
      );
      expect(html, contains('background-color: #009688'));
      expect(html, contains('grid-template-rows: 80px'));
      expect(html, contains('box-shadow'));
      expect(html, contains('font-size: 19px'));
      expect(html, contains('text-align: center'));
    });

    test('the widget overrides the theme', () async {
      final html = await _under(
        ThemeData(appBarTheme: theme),
        const AppBar(
          title: Text('t'),
          backgroundColor: _plum,
          toolbarHeight: 50,
          centerTitle: false,
        ),
      );
      expect(html, contains('background-color: #8e24aa'));
      expect(html, isNot(contains('#009688')));
      expect(html, contains('grid-template-rows: 50px'));
      expect(html, isNot(contains('text-align: center')));
    });
  });

  group('ListTileThemeData', () {
    const theme = ListTileThemeData(
      tileColor: _teal,
      textColor: Color(0xff112233),
      contentPadding: EdgeInsets.all(3),
      horizontalTitleGap: 9,
      dense: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
    );

    test('the theme overrides the defaults', () async {
      final html = await _under(
        ThemeData(listTileTheme: theme),
        const ListTile(title: Text('t')),
      );
      expect(html, contains('background-color: #009688'));
      expect(html, contains('color: #112233'));
      expect(html, contains('padding: 3px'));
      expect(html, contains('gap: 9px'));
      expect(html, contains('min-height: 48px'));
      expect(html, contains('border-radius: 6px'));
    });

    test('the widget overrides the theme', () async {
      final html = await _under(
        ThemeData(listTileTheme: theme),
        const ListTile(
          title: Text('t'),
          tileColor: _plum,
          dense: false,
          contentPadding: EdgeInsets.all(1),
        ),
      );
      expect(html, contains('background-color: #8e24aa'));
      expect(html, isNot(contains('#009688')));
      expect(html, contains('min-height: 56px'));
      expect(html, contains('padding: 1px'));
    });

    test('the theme colors the selected tile', () async {
      final html = await _under(
        ThemeData(
          listTileTheme: const ListTileThemeData(
            selectedColor: _plum,
            selectedTileColor: _teal,
          ),
        ),
        const ListTile(title: Text('t'), selected: true),
      );
      expect(html, contains('color: #8e24aa'));
      expect(html, contains('background-color: #009688'));
    });
  });

  group('TooltipThemeData', () {
    const theme = TooltipThemeData(
      height: 40,
      verticalOffset: 11,
      preferBelow: false,
      textStyle: TextStyle(fontSize: 17),
      waitDuration: Duration(milliseconds: 500),
      padding: EdgeInsets.all(2),
    );

    test('the theme overrides the defaults', () async {
      final html = await _under(
        ThemeData(tooltipTheme: theme),
        const Tooltip(message: 'm', child: Text('x')),
      );
      expect(html, contains('min-height: 40px'));
      expect(html, contains('font-size: 17px'));
      expect(html, contains('transition-delay: 500ms'));
      expect(html, contains('position-area: top'));
      expect(html, contains('padding: 2px'));
    });

    test('the widget overrides the theme', () async {
      final html = await _under(
        ThemeData(tooltipTheme: theme),
        const Tooltip(
          message: 'm',
          height: 30,
          preferBelow: true,
          waitDuration: Duration(milliseconds: 100),
          child: Text('x'),
        ),
      );
      expect(html, contains('min-height: 30px'));
      expect(html, contains('position-area: bottom'));
      expect(html, contains('transition-delay: 100ms'));
      expect(html, isNot(contains('500ms')));
    });
  });

  group('SnackBarThemeData', () {
    const theme = SnackBarThemeData(
      backgroundColor: _teal,
      contentTextStyle: TextStyle(fontSize: 15),
      elevation: 0,
      behavior: SnackBarBehavior.floating,
    );

    test('the theme overrides the defaults', () async {
      final html = await _under(
        ThemeData(snackBarTheme: theme),
        const SnackBar(content: Text('hi')),
      );
      expect(html, contains('background-color: #009688'));
      expect(html, contains('font-size: 15px'));
      expect(html, contains('box-shadow: none'));
      expect(html, contains('left: 50%'));
    });

    test('the widget overrides the theme', () async {
      final html = await _under(
        ThemeData(snackBarTheme: theme),
        const SnackBar(
          content: Text('hi'),
          backgroundColor: _plum,
          behavior: SnackBarBehavior.fixed,
        ),
      );
      expect(html, contains('background-color: #8e24aa'));
      expect(html, isNot(contains('#009688')));
      expect(html, contains('left: 0'));
    });
  });

  group('theme text styles sit under the child Text', () {
    const own = TextStyle(color: Color(0xffaa0000));
    const base = TextStyle(color: Color(0xff333333));

    test('AlertDialog title and content', () async {
      final html = await _under(
        ThemeData(
          dialogTheme: const DialogThemeData(
            titleTextStyle: base,
            contentTextStyle: base,
          ),
        ),
        const AlertDialog(
          title: Text('t', style: own),
          content: Text('c', style: own),
        ),
      );
      expect(html, contains('color: #aa0000'));
      expect(html, isNot(contains('#333333')));
    });

    test('AppBar title', () async {
      final html = await _under(
        ThemeData(appBarTheme: const AppBarThemeData(titleTextStyle: base)),
        const AppBar(title: Text('t', style: own)),
      );
      expect(html, contains('color: #aa0000'));
      expect(html, isNot(contains('#333333')));
    });

    test('SnackBar content', () async {
      final html = await _under(
        ThemeData(
          snackBarTheme: const SnackBarThemeData(contentTextStyle: base),
        ),
        const SnackBar(content: Text('c', style: own)),
      );
      expect(html, contains('color: #aa0000'));
    });
  });

  group('ProgressIndicatorThemeData', () {
    const theme = ProgressIndicatorThemeData(
      color: _teal,
      linearMinHeight: 9,
      circularStrokeWidth: 7,
    );

    test('the linear bar takes the theme', () async {
      final html = await _under(
        ThemeData(progressIndicatorTheme: theme),
        const LinearProgressIndicator(value: 0.5),
      );
      expect(html, contains('height: 9px'));
      expect(html, contains('accent-color: #009688'));
    });

    test('the circular one takes the theme', () async {
      final html = await _under(
        ThemeData(progressIndicatorTheme: theme),
        const CircularProgressIndicator(value: 0.5),
      );
      expect(html, contains('stroke-width="7"'));
      expect(html, contains('color: #009688'));
    });

    test('the widget overrides the theme', () async {
      final linear = await _under(
        ThemeData(progressIndicatorTheme: theme),
        const LinearProgressIndicator(value: 0.5, minHeight: 2, color: _plum),
      );
      expect(linear, contains('height: 2px'));
      expect(linear, contains('accent-color: #8e24aa'));
      final circular = await _under(
        ThemeData(progressIndicatorTheme: theme),
        const CircularProgressIndicator(
          value: 0.5,
          strokeWidth: 2,
          color: _plum,
        ),
      );
      expect(circular, contains('stroke-width="2"'));
      expect(circular, contains('color: #8e24aa'));
    });
  });

  group('BottomSheetThemeData', () {
    const theme = BottomSheetThemeData(
      modalBackgroundColor: _teal,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
      modalBarrierColor: Color(0x80112233),
      modalElevation: 6,
    );

    test('the theme overrides the defaults', () async {
      final html = await _under(
        ThemeData(bottomSheetTheme: theme),
        const ModalBottomSheet(child: Text('x')),
      );
      expect(html, contains('background-color: #009688'));
      expect(html, contains('border-radius: 2px'));
      expect(html, contains('rgba(17, 34, 51'));
      expect(html, contains('box-shadow: 0 3px 9px'));
    });

    test('the widget overrides the theme', () async {
      final html = await _under(
        ThemeData(bottomSheetTheme: theme),
        const ModalBottomSheet(backgroundColor: _plum, child: Text('x')),
      );
      expect(html, contains('background-color: #8e24aa'));
      expect(html, isNot(contains('#009688')));
    });
  });

  group('DrawerThemeData', () {
    const theme = DrawerThemeData(
      backgroundColor: _teal,
      width: 250,
      scrimColor: Color(0x80112233),
    );

    test('the theme overrides the defaults', () async {
      final html = await _under(
        ThemeData(drawerTheme: theme),
        const Drawer(child: Text('x')),
      );
      expect(html, contains('background-color: #009688'));
      expect(html, contains('min(250px, 85vw)'));
      expect(html, contains('rgba(17, 34, 51'));
    });

    test('the widget overrides the theme', () async {
      final html = await _under(
        ThemeData(drawerTheme: theme),
        const Drawer(backgroundColor: _plum, width: 200, child: Text('x')),
      );
      expect(html, contains('background-color: #8e24aa'));
      expect(html, isNot(contains('#009688')));
      expect(html, contains('min(200px, 85vw)'));
    });
  });

  group('CheckboxThemeData', () {
    final theme = CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>(
        (states) => states.contains(WidgetState.selected) ? _teal : null,
      ),
      checkColor: const WidgetStatePropertyAll(Color(0xffff0000)),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(9)),
      ),
    );

    test('the theme paints the checked box', () async {
      final html = await _under(
        ThemeData(checkboxTheme: theme),
        Checkbox(value: true, onChanged: (_) {}),
      );
      expect(html, contains('background-color: #009688'));
      expect(html, contains('border-radius: 9px'));
      expect(html, contains(Uri.encodeComponent('stroke="#ff0000"')));
    });

    test('activeColor wins over the theme', () async {
      final html = await _under(
        ThemeData(checkboxTheme: theme),
        Checkbox(value: true, onChanged: (_) {}, activeColor: _plum),
      );
      expect(html, contains('#8e24aa'));
      expect(html, isNot(contains('#009688')));
    });
  });

  group('SwitchThemeData', () {
    final theme = SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith<Color?>(
        (states) => states.contains(WidgetState.selected) ? _teal : null,
      ),
      thumbColor: const WidgetStatePropertyAll(Color(0xffff0000)),
    );

    test('the theme paints the track and the thumb', () async {
      final html = await _under(
        ThemeData(switchTheme: theme),
        Switch(value: true, onChanged: (_) {}),
      );
      expect(html, contains('background-color: #009688'));
      expect(html, contains(Uri.encodeComponent('fill="#ff0000"')));
    });

    test('activeColor wins over the theme', () async {
      final html = await _under(
        ThemeData(switchTheme: theme),
        Switch(value: true, onChanged: (_) {}, activeColor: _plum),
      );
      expect(html, contains('#8e24aa'));
      expect(html, isNot(contains('#009688')));
    });
  });

  group('RadioThemeData', () {
    const theme = RadioThemeData(fillColor: WidgetStatePropertyAll(_teal));

    test('the theme paints the selected radio', () async {
      final html = await _under(
        ThemeData(radioTheme: theme),
        const RadioGroup<int>(groupValue: 1, child: Radio<int>(value: 1)),
      );
      expect(html, contains('border-color: #009688'));
    });

    test('activeColor wins over the theme', () async {
      final html = await _under(
        ThemeData(radioTheme: theme),
        const RadioGroup<int>(
          groupValue: 1,
          child: Radio<int>(value: 1, activeColor: _plum),
        ),
      );
      expect(html, contains('#8e24aa'));
      expect(html, isNot(contains('#009688')));
    });
  });

  group('SliderThemeData', () {
    const theme = SliderThemeData(activeTrackColor: _teal);

    test('the theme sets the accent and the widget wins', () async {
      final themed = await _under(
        ThemeData(sliderTheme: theme),
        Slider(value: 0.5, onChanged: (_) {}),
      );
      expect(themed, contains('accent-color: #009688'));
      final own = await _under(
        ThemeData(sliderTheme: theme),
        Slider(value: 0.5, onChanged: (_) {}, activeColor: _plum),
      );
      expect(own, contains('accent-color: #8e24aa'));
      expect(own, isNot(contains('#009688')));
    });
  });

  group('TabBarThemeData', () {
    const theme = TabBarThemeData(
      labelColor: _teal,
      unselectedLabelColor: Color(0xff112233),
      dividerColor: Color(0xff445566),
      labelStyle: TextStyle(fontSize: 21),
      labelPadding: EdgeInsets.symmetric(horizontal: 3),
    );

    Widget bar([Color? labelColor]) => DefaultTabController(
      length: 2,
      child: TabBar(
        labelColor: labelColor,
        tabs: const [
          Tab(text: 'a'),
          Tab(text: 'b'),
        ],
      ),
    );

    test('the theme overrides the defaults', () async {
      final html = await _under(ThemeData(tabBarTheme: theme), bar());
      expect(html, contains('#009688'));
      expect(html, contains('color: #112233'));
      expect(html, contains('#445566'));
      expect(html, contains('font-size: 21px'));
      expect(html, contains('padding: 0px 3px'));
    });

    test('the widget overrides the theme', () async {
      final html = await _under(ThemeData(tabBarTheme: theme), bar(_plum));
      expect(html, contains('#8e24aa'));
      expect(html, isNot(contains('#009688')));
    });
  });

  group('PopupMenuThemeData', () {
    const theme = PopupMenuThemeData(
      color: _teal,
      elevation: 0,
      textStyle: TextStyle(fontSize: 18),
    );

    Widget menu([Color? color]) => PopupMenuButton(
      color: color,
      items: const [PopupMenuItem(value: 'a', child: Text('a'))],
      child: const Text('open'),
    );

    test('the theme overrides the defaults', () async {
      final html = await _under(ThemeData(popupMenuTheme: theme), menu());
      expect(html, contains('background-color: #009688'));
      expect(html, contains('box-shadow: none'));
      expect(html, contains('font-size: 18px'));
    });

    test('the widget overrides the theme', () async {
      final html = await _under(ThemeData(popupMenuTheme: theme), menu(_plum));
      expect(html, contains('background-color: #8e24aa'));
      expect(html, isNot(contains('#009688')));
    });
  });

  group('NavigationBarThemeData', () {
    const theme = NavigationBarThemeData(
      backgroundColor: _teal,
      height: 60,
      indicatorColor: Color(0xff112233),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
    );

    NavigationBar bar({Color? backgroundColor}) => NavigationBar(
      backgroundColor: backgroundColor,
      selectedIndex: 0,
      destinations: const [
        NavigationDestination(icon: Text('i'), label: 'one'),
        NavigationDestination(icon: Text('j'), label: 'two'),
      ],
    );

    test('the theme overrides the defaults', () async {
      final html = await _under(ThemeData(navigationBarTheme: theme), bar());
      expect(html, contains('background-color: #009688'));
      expect(html, contains('min-height: 60px'));
      expect(html, contains('#112233'));
      expect(html, contains('clip'));
    });

    test('the widget overrides the theme', () async {
      final html = await _under(
        ThemeData(navigationBarTheme: theme),
        bar(backgroundColor: _plum),
      );
      expect(html, contains('background-color: #8e24aa'));
      expect(html, isNot(contains('#009688')));
    });
  });

  test('copyWith keeps and replaces the component themes', () {
    const dialog = DialogThemeData(backgroundColor: _teal);
    final base = ThemeData(
      dividerTheme: const DividerThemeData(thickness: 2),
      dialogTheme: dialog,
    );
    final copy = base.copyWith(
      dividerTheme: const DividerThemeData(thickness: 5),
    );
    expect(copy.dividerTheme!.thickness, 5);
    expect(copy.dialogTheme, same(dialog));
  });
}
