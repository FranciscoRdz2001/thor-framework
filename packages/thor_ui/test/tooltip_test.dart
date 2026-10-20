@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

const _button = SizedBox(width: 48, height: 48, child: Text('b'));

void main() {
  setUpAll(initializeThorTests);

  Future<String> page(Widget child) => renderDocument(ThorApp(child: child));

  String body(String html) =>
      html.substring(html.indexOf('<body'), html.indexOf('</body>'));

  test('the child points at the bubble; the bubble follows it', () async {
    final html = body(
      await page(const Tooltip(message: 'Save', child: _button)),
    );
    final id = RegExp(r'aria-describedby="([^"]+)"').firstMatch(html)![1]!;
    final bubble = RegExp('<span[^>]*id="$id"[^>]*>').firstMatch(html)![0]!;
    expect(bubble, contains('role="tooltip"'));
    // Child, then bubble, inside the box: the bubble is its next sibling.
    expect(
      html,
      matches(RegExp('aria-describedby="$id"[^>]*>b</span><span id="$id"')),
    );
  });

  test('every tooltip shares the same classes (one anchor name)', () async {
    final html = await page(
      const Row(
        children: [
          Tooltip(message: 'One', child: _button),
          Tooltip(message: 'Two', child: _button),
        ],
      ),
    );
    final ids = RegExp(
      r'aria-describedby="([^"]+)"',
    ).allMatches(html).map((m) => m[1]).toSet();
    expect(ids, hasLength(2), reason: 'unique ids per page');
    final bubbles = RegExp(
      r'<span id="t-tip\d+" class="([^"]+)"',
    ).allMatches(html).map((m) => m[1]).toSet();
    expect(bubbles, hasLength(1));
    expect(html, contains('anchor-scope: --t-tip'));
    expect(html, contains('anchor-name: --t-tip'));
    expect(html, contains('position-anchor: --t-tip'));
  });

  test('shows on hover and on focus of the child, after the wait', () async {
    final html = await page(
      const Tooltip(
        message: 'Save',
        waitDuration: Duration(milliseconds: 500),
        child: _button,
      ),
    );
    // Hover only where there is a pointer that hovers.
    expect(
      html,
      contains(
        RegExp(r'@media \(hover: hover\)\{:where\(:hover\) \+ \.[\w-]+\{'),
      ),
    );
    expect(
      html,
      contains(':where(:is(:focus-visible, :has(:focus-visible))) +'),
    );
    expect(html, contains('transition-delay: 500ms'));
  });

  test('fades in from where display: none left it', () async {
    final html = await page(const Tooltip(message: 'a', child: _button));
    // Nothing transitions from display: none: the fade (and its wait)
    // starts from a starting style.
    expect(
      html,
      contains(RegExp(r'@starting-style\{\.[\w-]+\{opacity: 0\}\}')),
    );
    expect(html, contains('display 150ms allow-discrete'));
  });

  test('preferBelow and verticalOffset place the bubble', () async {
    final below = await page(const Tooltip(message: 'a', child: _button));
    expect(below, contains('position-area: bottom'));
    expect(
      below,
      contains('margin-top: max(0px, calc(24px - anchor-size(height) / 2))'),
    );
    final above = await page(
      const Tooltip(
        message: 'a',
        preferBelow: false,
        verticalOffset: 40,
        child: _button,
      ),
    );
    expect(above, contains('position-area: top'));
    expect(
      above,
      contains('margin-bottom: max(0px, calc(40px - anchor-size(height) / 2))'),
    );
    expect(above, contains('position-try-fallbacks: flip-block'));
  });

  test(
    'stays inside the viewport: fallbacks line it up with the child',
    () async {
      final below = await page(const Tooltip(message: 'a', child: _button));
      // Centered first; near an edge, the bubble starts or ends where the
      // child does, on the preferred side first.
      expect(below, contains('position-area: bottom;'));
      expect(
        below,
        contains(
          'position-try-fallbacks: flip-block, bottom span-right, '
          'bottom span-left, --t-tip-bottom-r flip-block, '
          '--t-tip-bottom-l flip-block',
        ),
      );
      expect(below, contains('margin: 0;'));
      final above = await page(
        const Tooltip(message: 'a', preferBelow: false, child: _button),
      );
      expect(
        above,
        contains(
          'position-try-fallbacks: flip-block, top span-right, '
          'top span-left, --t-tip-top-r flip-block, --t-tip-top-l flip-block',
        ),
      );
    },
  );

  test(
    'the other side keeps the gap toward the child (named tries, flipped)',
    () async {
      final html = await page(const Tooltip(message: 'a', child: _button));
      // The cross-side fallbacks are named rules flipped by `flip-block`:
      // the tactic swaps the margins too, so the gap on `margin-top` ends
      // up on `margin-bottom` when the bubble moves above the child.
      final css = html.replaceAll(' ', '');
      for (final (name, area) in [
        ('--t-tip-bottom-r', 'bottomspan-right'),
        ('--t-tip-bottom-l', 'bottomspan-left'),
        ('--t-tip-top-r', 'topspan-right'),
        ('--t-tip-top-l', 'topspan-left'),
      ]) {
        expect(css, contains('@position-try$name{position-area:$area}'));
      }
      // Outside the layers and only once per page.
      final two = await page(
        const Column(
          children: [
            Tooltip(message: 'a', child: _button),
            Tooltip(message: 'b', child: _button),
          ],
        ),
      );
      expect('@position-try --t-tip-top-r{'.allMatches(two), hasLength(1));
      // Without a ThorApp the rules travel with the tooltip.
      final bare = await renderHtml(
        const Tooltip(message: 'a', child: _button),
      );
      expect(bare, contains('@position-try --t-tip-bottom-r{'));
    },
  );

  test('margin surrounds the bubble and adds to the offset', () async {
    final below = await page(
      const Tooltip(
        message: 'a',
        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: _button,
      ),
    );
    expect(below, contains('margin: 4px 10px;'));
    expect(
      below,
      contains(
        'margin-top: calc(max(0px, calc(24px - anchor-size(height) / 2)) '
        '+ 4px)',
      ),
    );
    final above = await page(
      ThorApp(
        theme: ThemeData(
          tooltipTheme: const TooltipThemeData(
            margin: EdgeInsets.only(left: 12, bottom: 6),
          ),
        ),
        child: const Tooltip(message: 'a', preferBelow: false, child: _button),
      ),
    );
    expect(above, contains('margin: 0px 0px 6px 12px;'));
    expect(
      above,
      contains(
        'margin-bottom: calc(max(0px, calc(24px - anchor-size(height) / 2)) '
        '+ 6px)',
      ),
    );
    // A zero side keeps the plain offset (`calc(x + 0)` is invalid CSS).
    final flat = await page(
      const Tooltip(
        message: 'a',
        margin: EdgeInsets.symmetric(horizontal: 8),
        child: _button,
      ),
    );
    expect(
      flat,
      contains('margin-top: max(0px, calc(24px - anchor-size(height) / 2))'),
    );
  });

  test('excludeFromSemantics leaves the child undescribed', () async {
    final html = body(
      await page(
        const Tooltip(message: 'a', excludeFromSemantics: true, child: _button),
      ),
    );
    expect(html, isNot(contains('aria-describedby')));
    expect(html, contains('aria-hidden="true"'));
  });

  test('richMessage renders its spans', () async {
    final html = await page(
      const Tooltip(
        richMessage: TextSpan(
          text: 'Pulsa ',
          children: [
            TextSpan(
              text: 'Ctrl+S',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        child: _button,
      ),
    );
    expect(html, contains('Ctrl+S'));
  });

  test('message and richMessage are exclusive', () {
    expect(
      () => Tooltip(child: _button, message: null, richMessage: null),
      throwsA(isA<AssertionError>()),
    );
  });

  test(
    'a margin folded onto a Tooltip reaches the child, not the box',
    () async {
      final html = await renderHtml(
        const Column(
          children: [
            Text('a'),
            SizedBox(height: 12),
            Tooltip(message: 'b', child: _button),
          ],
        ),
      );
      final box = RegExp(
        r'<span style="[^"]*display: contents[^"]*"',
      ).firstMatch(html)![0]!;
      expect(box, isNot(contains('margin')));
      expect(html, contains('margin-top: 12px'));
    },
  );
}
