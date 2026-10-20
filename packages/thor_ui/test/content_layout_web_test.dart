@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thor_ui/thor_ui.dart';
import 'package:web/web.dart' as web;

/// [markup] inside `.x`, with [rules] (selector → values) as the
/// descendant rules of `.x`, written as thor writes them; [measure] runs
/// while it is in the page.
T laidOut<T>(
  String markup,
  Map<String, StyleProps> rules,
  T Function(web.Element host) measure,
) {
  final rule = ThorStyleRegistry.renderRule(
    'x',
    const {'display': 'block', 'width': '500px'},
    conditions: [
      for (final MapEntry(:key, :value) in rules.entries)
        ConditionalCss(CssCondition.descendant(key), value.toCss()),
    ],
  );
  final style = web.document.createElement('style')
    ..textContent = '$thorLayerOrder$rule';
  final host = web.document.createElement('div')
    ..innerHTML = '<div class="x">$markup</div>'.toJS;
  web.document.head!.append(style);
  web.document.body!.append(host);
  try {
    return measure(host);
  } finally {
    style.remove();
    host.remove();
  }
}

web.DOMRect box(web.Element host, String id) =>
    host.querySelector('#$id')!.getBoundingClientRect();

void main() {
  test('an auto-fit grid shares the row, spacing between columns', () {
    final (a, b, c) = laidOut(
      '<div class="cards"><p id="a">a</p><p id="b">b</p><p id="c">c</p></div>',
      {
        '.cards': StyleProps(
          display: Display.grid,
          gridTemplateColumns: GridTracks.autoFit(
            GridTrack.minmax(GridTrack.length(200.px), GridTrack.fr(1)),
          ),
          spacing: 20.px,
          runSpacing: 10.px,
        ),
        '.cards > p': const StyleProps(margin: EdgeInsets.zero, height: 30),
      },
      (h) => (box(h, 'a'), box(h, 'b'), box(h, 'c')),
    );
    // Two 200px+ columns fit in 500px: (500 - 20) / 2 each.
    expect(a.width, 240);
    expect(b.left - a.right, 20);
    // The third runs onto the next row, 10px below.
    expect(c.top - a.bottom, 10);
    expect(c.left, a.left);
  });

  test('a column with Flutter names centers its children', () {
    final (a, b) = laidOut(
      '<div class="col"><span id="a">aa</span><span id="b">bbbb</span></div>',
      {
        '.col': StyleProps(
          display: Display.flex,
          direction: Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 12.px,
        ),
      },
      (h) => (box(h, 'a'), box(h, 'b')),
    );
    expect(b.top - a.bottom, 12);
    expect((a.left + a.right) / 2, closeTo((b.left + b.right) / 2, 0.01));
  });

  test('sides changes one margin and keeps the browser\'s others', () {
    final margins = laidOut(
      '<p id="a">a</p>',
      {
        '> :first-child': const StyleProps(
          margin: EdgeInsetsGeometry.sides(top: Length.zero),
        ),
      },
      (h) {
        final s = web.window.getComputedStyle(h.querySelector('#a')!);
        return (s.marginTop, s.marginBottom);
      },
    );
    expect(margins, ('0px', '16px'));
  });

  test('em font sizes follow the text around, px line heights are exact', () {
    final (inP, inH, lines) = laidOut(
      '<p id="p"><code id="a">x</code></p><h3><code id="b">x</code></h3>'
      '<div id="lines">1<br>2<br>3<br>4<br>5<br>6<br>7<br>8<br>9<br>10</div>',
      {
        'p': const StyleProps(textStyle: TextStyle(fontSize: 16)),
        'h3': const StyleProps(textStyle: TextStyle(fontSize: 24)),
        ':not(pre) > code': const StyleProps(
          textStyle: TextStyle(fontSizeLength: Length.em(0.9)),
        ),
        '#lines': const StyleProps(
          textStyle: TextStyle(fontSize: 14.8, heightLength: Length.px(20)),
        ),
      },
      (h) => (
        web.window.getComputedStyle(h.querySelector('#a')!).fontSize,
        web.window.getComputedStyle(h.querySelector('#b')!).fontSize,
        box(h, 'lines').height,
      ),
    );
    expect(inP, '14.4px');
    expect(inH, '21.6px');
    expect(lines, 200, reason: 'ten lines of exactly 20px');
  });

  test('a floated box sits at the right, the text beside it', () {
    final (host, fig, text) = laidOut(
      '<div id="fig" class="fig"></div><p id="text">words</p>',
      {
        '.fig': const StyleProps(
          float: BoxFloat.right,
          width: 100,
          height: 100,
        ),
        'p': const StyleProps(margin: EdgeInsets.zero),
      },
      (h) => (
        h.querySelector('.x')!.getBoundingClientRect(),
        box(h, 'fig'),
        box(h, 'text'),
      ),
    );
    expect(fig.right, host.right);
    expect(text.top, fig.top, reason: 'the paragraph runs beside it');
  });
}
