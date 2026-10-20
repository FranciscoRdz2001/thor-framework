@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thor_ui/src/foundation/debug_inspector.dart'
    show debugInspectorScript;
import 'package:web/web.dart' as web;

/// Adds [markup] to the page, runs the layout inspector on it and returns
/// the warning of the element with `id="flex"` (null: none).
Future<String?> inspect(String markup) async {
  final host = web.document.createElement('div')..innerHTML = markup.toJS;
  web.document.body!.append(host);
  // The page has loaded already: run at once instead of on `load`.
  final script = web.document.createElement('script')
    ..textContent = debugInspectorScript.replaceFirst(
      "addEventListener('load', () => document.fonts.ready.then(run));",
      'run();',
    );
  web.document.body!.append(script);
  try {
    return web.document
        .getElementById('flex')!
        .getAttribute('data-thor-warning');
  } finally {
    host.remove();
    script.remove();
  }
}

void main() {
  test('the replacement that runs the script at once still applies', () {
    expect(
      debugInspectorScript,
      contains(
        "addEventListener('load', () => document.fonts.ready.then(run));",
      ),
    );
  });

  // A heading with a tight line-height spills its glyphs out of
  // its line box; its Column scrolls by 2px but nothing is out of place.
  test('a tight line-height heading is no Column overflow', () async {
    final warning = await inspect(
      '<div id="flex" data-thor="Column" '
      'style="display:flex;flex-direction:column;overflow:visible">'
      '<h2 style="margin:0;font-size:44px;line-height:20px">'
      'Everything your pipeline needs, nothing to maintain</h2></div>',
    );
    expect(warning, isNull);
  });

  test('a child taller than its Column is THOR-L001', () async {
    final warning = await inspect(
      '<div id="flex" data-thor="Column" '
      'style="display:flex;flex-direction:column;height:40px">'
      '<div style="flex:none;height:100px"></div></div>',
    );
    expect(warning, contains('Column overflowed by 60px'));
    expect(warning, contains('THOR-L001'));
  });

  // A transform moves the paint, not the layout (a Flutter
  // Transform): a SlideTransition entering from below, a spinning
  // CircularProgressIndicator (its rotated box is ~56px for 40).
  test('a child moved, turned or scaled is no overflow', () async {
    for (final move in [
      'translate:0 8%',
      'translate:0 -12px',
      'transform:translateY(20px)',
      'rotate:45deg',
      'scale:1.5',
      'transform:rotate(30deg) scale(1.2)',
    ]) {
      final warning = await inspect(
        '<div id="flex" data-thor="Column" '
        'style="display:flex;flex-direction:column;height:100px">'
        '<div style="flex:none;height:100px;$move"></div></div>',
      );
      expect(warning, isNull, reason: move);
    }
  });

  test('a moved child that is also too tall still overflows', () async {
    final warning = await inspect(
      '<div id="flex" data-thor="Column" '
      'style="display:flex;flex-direction:column;height:40px">'
      '<div style="flex:none;height:100px;translate:0 30px"></div></div>',
    );
    expect(warning, contains('Column overflowed by 60px'));
  });

  test('an icon (an SVG, which has no offsets) still overflows', () async {
    final warning = await inspect(
      '<div id="flex" data-thor="Row" style="display:flex;width:20px">'
      '<svg style="flex:none" width="50" height="10"></svg></div>',
    );
    expect(warning, contains('Row overflowed by 30px'));
  });

  test('a Row overflows at the start when reversed', () async {
    final warning = await inspect(
      '<div id="flex" data-thor="Row" '
      'style="display:flex;flex-direction:row-reverse;width:50px">'
      '<div style="flex:none;width:80px;height:10px"></div></div>',
    );
    expect(warning, contains('Row overflowed by 30px'));
  });

  // A padded Row inside a closed <dialog> (a Drawer's
  // navigation, a command palette) has no layout; its zero boxes minus its
  // padding read as an overflow of the padding.
  test('a padded Row in a closed dialog is no overflow', () async {
    final warning = await inspect(
      '<dialog><div id="flex" data-thor="Row" '
      'style="display:flex;padding:0 10px">'
      '<span style="flex:none">Docs</span></div></dialog>',
    );
    expect(warning, isNull);
  });

  test('a padded Row hidden with display:none is no overflow', () async {
    final warning = await inspect(
      '<div style="display:none"><div id="flex" data-thor="Row" '
      'style="display:flex;padding:0 10px">'
      '<span style="flex:none">Docs</span></div></div>',
    );
    expect(warning, isNull);
  });

  // Log lines (a Row each) in a Column inside a horizontal
  // SingleChildScrollView, as thor renders it. The Column takes its
  // content's width (Flutter's unbounded width): the Rows fit in it.
  String logBox({required bool maxContent}) =>
      '<div style="width:300px;overflow-x:auto;overflow-y:hidden">'
      '<div data-thor="Column" style="display:flex;flex-direction:column;'
      'align-items:flex-start${maxContent ? ';width:max-content' : ''}">'
      '<div id="flex" data-thor="Row" style="flex:0 0 auto;'
      'align-self:stretch;display:flex;gap:16px;padding:0 16px">'
      '<span style="flex:none;width:24px">1</span>'
      '<span style="flex:0 0 auto;white-space:pre">${'a long log line ' * 20}'
      '</span></div></div></div>';

  test('a Row in a horizontal scroll view is no overflow', () async {
    expect(await inspect(logBox(maxContent: true)), isNull);
  });

  test('sized to the view instead, the same Row overflows', () async {
    expect(
      await inspect(logBox(maxContent: false)),
      contains('A Row overflowed by'),
    );
  });

  // A field's name: `aria-label` (labelText, hintText, Semantics), a
  // `<label for>` with text, or `aria-labelledby`/`title`. thor wraps the
  // input in an empty `<label>`, which names nothing.
  String field(String input, [String before = '']) =>
      '$before<label data-thor="TextField">$input</label>';

  test('a TextField with no label, hint or semantics is THOR-L004', () async {
    final warning = await inspect(
      field('<input id="flex" type="text" name="q"/>'),
    );
    expect(warning, contains('no accessible name'));
    expect(warning, contains('THOR-L004'));
  });

  test('a textarea (maxLines > 1) with no name is THOR-L004', () async {
    final warning = await inspect(
      field('<textarea id="flex" name="q"></textarea>'),
    );
    expect(warning, contains('THOR-L004'));
  });

  test('an empty aria-label names nothing', () async {
    final warning = await inspect(
      field('<input id="flex" type="text" aria-label="  "/>'),
    );
    expect(warning, contains('THOR-L004'));
  });

  test('aria-label, aria-labelledby and title name the field', () async {
    for (final attr in [
      'aria-label="Search"',
      'aria-labelledby="lbl"',
      'title="Search"',
    ]) {
      final warning = await inspect(
        field('<input id="flex" type="text" $attr/>', '<i id="lbl">x</i>'),
      );
      expect(warning, isNull, reason: attr);
    }
  });

  test('a <label for> with text names it (an outer label too)', () async {
    final linked = await inspect(
      field('<input id="flex" type="text"/>', '<label for="flex">Name</label>'),
    );
    expect(linked, isNull);
    final wrapped = await inspect(
      '<label>Name<label data-thor="TextField">'
      '<input id="flex" type="text"/></label></label>',
    );
    expect(wrapped, isNull);
  });

  test('a <label for> with no text does not name it', () async {
    final warning = await inspect(
      field('<input id="flex" type="text"/>', '<label for="flex"></label>'),
    );
    expect(warning, contains('THOR-L004'));
  });

  test('a labelled wrapper (Semantics) names its field', () async {
    final warning = await inspect(
      '<label data-thor="TextField" aria-label="Search">'
      '<input id="flex" type="text"/></label>',
    );
    expect(warning, isNull);
  });

  test('prefix and suffix text in the wrapper do not name the field', () async {
    final warning = await inspect(
      '<label data-thor="TextField"><span>\$ </span>'
      '<input id="flex" type="text"/><span>kg</span></label>',
    );
    expect(warning, contains('THOR-L004'));
  });

  test('inputs that are not text fields are left alone', () async {
    for (final input in [
      '<input id="flex" type="hidden" name="t"/>',
      '<input id="flex" type="submit"/>',
      '<input id="flex" type="checkbox"/>',
    ]) {
      expect(await inspect(input), isNull, reason: input);
    }
  });
}
