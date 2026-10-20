@TestOn('vm')
library;

// A compact `Switch` without `Transform.scale`: Flutter's `trackOutlineWidth`,
// `padding` and `materialTapTargetSize`, plus the web-only track and thumb
// size of `SwitchThemeData`. The defaults stay the Material 3 switch.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _head(Widget w, {ThemeData? theme}) async {
  final html = await renderDocument(ThorApp(theme: theme, child: w));
  return html.substring(0, html.indexOf('</head>'));
}

void main() {
  setUpAll(initializeThorTests);

  test('the default switch is the 52x32 Material 3 one', () async {
    final head = await _head(const Switch(value: true));
    expect(head, contains('width: 52px'));
    expect(head, contains('height: 32px'));
    expect(head, contains('border: 2px solid'));
    expect(head, contains('border-radius: 16px'));
    expect(head, contains('background-size: 16px 16px'));
    expect(head, contains('background-position: left 6px center'));
    expect(head, contains('background-size: 24px 24px'));
    expect(head, contains('background-position: right 2px center'));
  });

  test('trackOutlineWidth sets the border and keeps the thumb inset', () async {
    final head = await _head(
      const Switch(value: true, trackOutlineWidth: WidgetStatePropertyAll(1)),
    );
    expect(head, contains('border: 1px solid'));
    expect(head, contains('background-position: left 7px center'));
    expect(head, contains('background-position: right 3px center'));
  });

  test('a selected outline width differs from the unselected one', () async {
    final head = await _head(
      Switch(
        value: false,
        trackOutlineWidth: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? 0 : 2,
        ),
      ),
    );
    expect(head, contains('border: 2px solid'));
    // The checked rule narrows the border to 0 and moves the thumb out.
    expect(head, contains('border-width: 0px'));
    expect(head, contains('background-position: right 4px center'));
  });

  test('the theme draws a 40x24 switch with an 18px thumb', () async {
    final head = await _head(
      const Switch(value: true),
      theme: ThemeData(
        switchTheme: const SwitchThemeData(
          trackSize: Size(40, 24),
          thumbSize: WidgetStatePropertyAll(18),
          trackOutlineWidth: WidgetStatePropertyAll(1),
        ),
      ),
    );
    expect(head, contains('width: 40px'));
    expect(head, contains('height: 24px'));
    expect(head, contains('border-radius: 12px'));
    expect(head, contains('background-size: 18px 18px'));
    // Centered: (24 - 18) / 2 = 3 from the edge, 2 inside the 1px border.
    expect(head, contains('background-position: left 2px center'));
    expect(head, contains('background-position: right 2px center'));
  });

  test('padding is space around the track', () async {
    final head = await _head(
      const Switch(value: false, padding: EdgeInsets.symmetric(horizontal: 4)),
    );
    expect(head, contains('margin: 0px 4px'));
  });

  test('the default padding is Flutter\'s 4 px on each side', () async {
    // Material 3's Switch is 60 px wide: the 52 px track plus 4 + 4.
    expect(
      await _head(const Switch(value: false)),
      contains('margin: 0px 4px'),
    );
    final none = await _head(
      const Switch(value: false, padding: EdgeInsets.zero),
    );
    expect(none, isNot(contains('margin: 0px 4px')));
  });

  test('materialTapTargetSize.shrinkWrap keeps the track box', () async {
    final padded = await _head(const Switch(value: false));
    final wrapped = await _head(
      const Switch(
        value: false,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
    expect(wrapped, padded);
  });

  test('the theme supplies padding and the tap target size', () async {
    final head = await _head(
      const Switch(value: false),
      theme: ThemeData(
        switchTheme: const SwitchThemeData(
          padding: EdgeInsets.all(2),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
    expect(head, contains('margin: 2px'));
  });
}
