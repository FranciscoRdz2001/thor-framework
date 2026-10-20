// These tests are about the button's box, not its name.
// ignore_for_file: thor_lints/icon_button_without_name
// An IconButton keeps its own box (padding + icon) in a real browser, also
// inside parents that stretch their children: with `iconSize:` it used to
// have only a min-width, so a stretching flex column widened it into a
// flat ellipse (the docs' IconButton demo).
@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thor_ui/server.dart' show Document;
import 'package:thor_ui/src/core/render.dart' as render;
import 'package:thor_ui/thor_ui.dart';
import 'package:web/web.dart' as web;

const _x = IconData.svg('x', '<path d="M0 0"/>');

void _noop() {}

/// Renders [body] like a page, puts it in the document and returns the
/// size of its `<button>`.
Future<(double, double)> buttonSize(Widget body) async {
  final r = await buttonRect(body);
  return (r.width, r.height);
}

/// The box of the `<button>` of [body], relative to the page's first box.
Future<({double left, double top, double width, double height})> buttonRect(
  Widget body,
) async {
  render.compactHtml = true;
  final result = await render.renderPage(Document(body: body));
  final page = utf8.decode(result.body);
  final style = RegExp(
    r'<style[^>]*>([\s\S]*?)</style>',
  ).allMatches(page).map((m) => m[1]).join('\n');
  final markup = page.substring(page.indexOf('<body') + 6);
  final sheet = web.document.createElement('style')..textContent = style;
  final host = web.document.createElement('div')
    ..innerHTML = markup.substring(0, markup.indexOf('</body>')).toJS;
  web.document.head!.append(sheet);
  web.document.body!.append(host);
  try {
    final r = host.querySelector('button')!.getBoundingClientRect();
    final o = host.firstElementChild!.getBoundingClientRect();
    return (
      left: r.left - o.left,
      top: r.top - o.top,
      width: r.width,
      height: r.height,
    );
  } finally {
    sheet.remove();
    host.remove();
  }
}

/// A box that stretches its children both ways: a flex column whose
/// cross axis stretches, inside a row that stretches too.
Widget stretching(Widget child) => SizedBox(
  width: 600,
  height: 200,
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [child],
        ),
      ),
    ],
  ),
);

void main() {
  const sized = IconButton(icon: Icon(_x), iconSize: 40, onPressed: _noop);

  test('with iconSize it is padding + icon, alone', () async {
    expect(await buttonSize(sized), (56, 56));
  });

  test('a stretching Column does not widen it', () async {
    final size = await buttonSize(
      const SizedBox(
        width: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [sized],
        ),
      ),
    );
    expect(size, (56, 56));
  });

  test('a stretching Row does not make it taller', () async {
    final size = await buttonSize(
      const SizedBox(
        height: 200,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [sized],
        ),
      ),
    );
    expect(size, (56, 56));
  });

  test('nor a Center, nor a box that stretches both ways', () async {
    expect(
      await buttonSize(
        const SizedBox(width: 600, height: 200, child: Center(child: sized)),
      ),
      (56, 56),
    );
    expect(await buttonSize(stretching(sized)), (56, 56));
  });

  test('the minimum still wins over a small icon', () async {
    expect(
      await buttonSize(
        stretching(
          const IconButton(icon: Icon(_x), iconSize: 16, onPressed: _noop),
        ),
      ),
      (48, 48),
    );
  });

  test('the default 48 and the filled 40 hold too', () async {
    expect(
      await buttonSize(
        stretching(const IconButton(icon: Icon(_x), onPressed: _noop)),
      ),
      (48, 48),
    );
    expect(
      await buttonSize(
        stretching(const IconButton.filled(icon: Icon(_x), onPressed: _noop)),
      ),
      (40, 40),
    );
  });

  test(
    'an aligned Container centers it (its margin reset is a base)',
    () async {
      // The parent's auto margins used to lose to the button's `margin: 0`:
      // the docs' demo sat at the stage's left edge.
      for (final button in const [
        sized,
        IconButton(icon: Icon(_x), onPressed: _noop),
      ]) {
        final r = await buttonRect(
          Container(
            width: 600,
            height: 200,
            alignment: Alignment.center,
            child: button,
          ),
        );
        expect(r.left + r.width / 2, 300, reason: '$button');
        expect(r.top + r.height / 2, 100, reason: '$button');
      }
    },
  );
}
