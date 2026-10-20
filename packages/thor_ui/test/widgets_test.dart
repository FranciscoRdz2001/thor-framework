import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

const _x = IconData.svg('x', '<path d="M0 0"/>');
const _box = SizedBox(width: 10, height: 10);
const _ms200 = Duration(milliseconds: 200);

void _noop() {}

int _count(String html, String tag) =>
    RegExp('<$tag[ >]').allMatches(html).length;

void main() {
  initializeThorTests();

  group('boxes', () {
    test('Align positions its child with auto margins', () async {
      final html = await renderHtml(
        const Align(alignment: Alignment.bottomRight, child: _box),
      );
      expect(html, contains('justify-content: flex-end'));
      expect(html, contains('margin-left: auto'));
    });

    test('ConstrainedBox fuses its constraints into the child', () async {
      final html = await renderHtml(
        const ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 300),
          child: _box,
        ),
      );
      expect(_count(html, 'div'), 1);
      expect(html, contains('max-width: 300px'));
    });

    test('AspectRatio uses aspect-ratio', () async {
      final html = await renderHtml(
        const AspectRatio(aspectRatio: 16 / 9, child: _box),
      );
      expect(html, contains('aspect-ratio: 1.7778'));
    });

    test('ColoredBox paints a background', () async {
      final html = await renderHtml(
        const ColoredBox(color: Color(0xFFFF0000), child: _box),
      );
      expect(html, contains('background-color: #ff0000'));
    });

    test('SafeArea pads with the safe-area insets', () async {
      final html = await renderHtml(const SafeArea(child: _box));
      expect(html, contains('env(safe-area-inset-top)'));
      expect(html, contains('env(safe-area-inset-left)'));
    });
  });

  group('effects (fused into the child, 0 extra nodes)', () {
    Future<String> one(Widget w) async {
      final html = await renderHtml(w);
      expect(_count(html, 'div'), 1, reason: html);
      return html;
    }

    test('Transform.rotate', () async {
      expect(
        await one(Transform.rotate(angle: 0.5, child: _box)),
        contains('transform: rotate(0.5rad)'),
      );
    });

    test('ClipRRect and ClipOval', () async {
      final r = await one(
        ClipRRect(borderRadius: BorderRadius.circular(8), child: _box),
      );
      expect(r, contains('border-radius: 8px'));
      expect(r, contains('overflow: hidden'));
      expect(
        await one(const ClipOval(child: _box)),
        contains('border-radius: 50%'),
      );
    });

    test('Visibility hides, or keeps the space with maintainSize', () async {
      final gone = await one(const Visibility(visible: false, child: _box));
      expect(gone, contains('display: none'));
      expect(gone, contains('aria-hidden="true"'));
      final kept = await one(
        const Visibility(visible: false, maintainSize: true, child: _box),
      );
      expect(kept, contains('visibility: hidden'));
    });

    test('Offstage removes the child from layout', () async {
      expect(await one(const Offstage(child: _box)), contains('display: none'));
    });

    test('MouseRegion sets the cursor', () async {
      expect(
        await one(
          const MouseRegion(cursor: SystemMouseCursors.click, child: _box),
        ),
        contains('cursor: pointer'),
      );
    });

    test('Tooltip describes its child with a bubble, not a title', () async {
      final html = await one(const Tooltip(message: 'Help', child: _box));
      expect(html, isNot(contains('title=')));
      expect(html, contains('role="tooltip"'));
      expect(html, contains('>Help<'));
    });
  });

  group('flex children', () {
    test('Flexible (loose) shrinks by its flex factor', () async {
      final html = await renderHtml(
        const Row(children: [Flexible(flex: 2, child: _box)]),
      );
      expect(html, contains('flex: 0 2 auto'));
      expect(_count(html, 'div'), 2);
    });

    test('Spacer takes the free space and is hidden from a11y', () async {
      final html = await renderHtml(
        const Row(children: [_box, Spacer(), _box]),
      );
      expect(html, contains('flex: 1 1 0'));
      expect(html, contains('aria-hidden="true"'));
    });
  });

  group('implicit animations', () {
    Future<String> animated(Widget w, String property) async {
      final html = await renderHtml(w);
      expect(html, contains('transition-property: $property'));
      expect(html, contains('transition-duration: 200ms'));
      expect(html, contains('prefers-reduced-motion: reduce'));
      return html;
    }

    test('AnimatedRotation animates rotate in turns', () async {
      final html = await animated(
        const AnimatedRotation(turns: 0.25, duration: _ms200, child: _box),
        'rotate',
      );
      expect(html, contains('rotate: 0.25turn'));
    });

    test('AnimatedSlide translates by a fraction of the child', () async {
      final html = await animated(
        const AnimatedSlide(
          offset: Offset(0.5, 0),
          duration: _ms200,
          child: _box,
        ),
        'translate',
      );
      expect(html, contains('translate: 50% 0%'));
    });

    test('AnimatedPositioned animates the offsets inside a Stack', () async {
      final html = await animated(
        const Stack(
          children: [
            AnimatedPositioned(
              left: 10,
              top: 20,
              duration: _ms200,
              child: _box,
            ),
          ],
        ),
        'left, top, right, bottom, width, height',
      );
      expect(html, contains('position: absolute'));
      expect(html, contains('left: 10px'));
      expect(html, contains('top: 20px'));
    });

    test('AnimatedPadding animates padding', () async {
      final html = await animated(
        const AnimatedPadding(
          padding: EdgeInsets.all(8),
          duration: _ms200,
          child: _box,
        ),
        'padding, margin',
      );
      expect(html, contains('padding: 8px'));
    });

    test(
      'AnimatedDefaultTextStyle applies and animates the text style',
      () async {
        final html = await animated(
          const AnimatedDefaultTextStyle(
            style: TextStyle(fontSize: 20),
            duration: _ms200,
            child: Text('t'),
          ),
          'color, font-size, font-weight, line-height, letter-spacing, word-spacing',
        );
        expect(html, contains('font-size: 20px'));
        expect(_count(html, 'span'), 1);
      },
    );
  });

  group('text', () {
    test('Text.rich renders spans and inline widgets', () async {
      final html = await renderHtml(
        const Text.rich(
          TextSpan(
            text: 'Hello ',
            children: [
              TextSpan(
                text: 'world',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              WidgetSpan(child: Icon(_x)),
            ],
          ),
        ),
      );
      expect(
        html,
        contains('Hello <span style="font-weight: 700">world</span>'),
      );
      expect(html, contains('display: inline-block'));
      expect(html, contains('<svg'));
    });

    test('a TextSpan with href is an inline link', () async {
      final html = await renderHtml(
        const Text.rich(
          TextSpan(
            text: 'Read ',
            children: [
              TextSpan(text: 'the docs', href: '/docs'),
              TextSpan(text: ' or ', children: []),
              TextSpan(
                text: 'HN',
                href: 'https://news.ycombinator.com',
                newTab: true,
              ),
            ],
          ),
        ),
      );
      expect(html, matches(RegExp(r'<a [^>]*href="/docs"')));
      expect(html, contains('>the docs</a>'));
      expect(html, contains('target="_blank" rel="noopener noreferrer"'));
      // No inline-block: it wraps with the sentence.
      expect(html, isNot(contains('inline-block')));
    });

    test('DefaultTextStyle merges into its Text', () async {
      final html = await renderHtml(
        const DefaultTextStyle(
          style: TextStyle(fontSize: 18),
          child: Text('t'),
        ),
      );
      expect(_count(html, 'span'), 1);
      expect(html, contains('font-size: 18px'));
    });
  });

  group('controls', () {
    test('OutlinedButton is a native button with an outline', () async {
      final html = await renderHtml(
        const OutlinedButton(onPressed: _noop, child: Text('Ok')),
      );
      expect(html, contains('<button'));
      expect(html, contains('type="button"'));
      expect(html, contains('border: 1px solid var(--t-outline'));
    });

    test('IconButton gets an accessible name from its tooltip', () async {
      final html = await renderHtml(
        const IconButton(icon: Icon(_x), onPressed: _noop, tooltip: 'Close'),
      );
      expect(html, contains('aria-label="Close"'));
      expect(html, contains('aria-hidden="true"'));
      expect(html, contains('width: 48px'));
    });

    test('Chip, ChoiceChip and ActionChip', () async {
      expect(
        await renderHtml(const Chip(label: Text('Café'))),
        startsWith('<span'),
      );
      final choice = await renderHtml(
        ChoiceChip(label: const Text('A'), selected: true, onSelected: (_) {}),
      );
      expect(choice, contains('aria-pressed="true"'));
      final action = await renderHtml(
        const ActionChip(label: Text('Go'), onPressed: _noop),
      );
      expect(action, contains('<button'));
      expect(action, isNot(matches(RegExp('<button[^>]*aria-pressed'))));
    });

    test(
      'CheckboxListTile and RadioListTile wrap the control in a label',
      () async {
        final check = await renderHtml(
          CheckboxListTile(
            value: true,
            onChanged: (_) {},
            title: const Text('Sound'),
          ),
        );
        expect(check, startsWith('<style>'));
        expect(check, contains('<label'));
        expect(check, contains('type="checkbox" checked'));
        final radio = await renderHtml(
          RadioListTile<int>(
            value: 1,
            groupValue: 1,
            onChanged: (_) {},
            title: const Text('One'),
            name: 'g',
          ),
        );
        expect(radio, contains('type="radio" checked name="g" value="1"'));
      },
    );

    test('Divider indent and endIndent follow the text direction', () async {
      final html = await renderHtml(const Divider(indent: 40, endIndent: 8));
      expect(
        html,
        contains('margin-inline-start: 40px; margin-inline-end: 8px'),
      );
      expect(html, isNot(contains('margin: 7.5px 8px 7.5px 40px')));
    });

    test('VerticalDivider is a vertical separator', () async {
      final html = await renderHtml(const VerticalDivider());
      expect(html, contains('role="separator"'));
      expect(html, contains('aria-orientation="vertical"'));
    });
  });

  test('Image.network: lazy, async decoding, intrinsic size, alt', () async {
    final html = await renderHtml(
      const Image.network(
        'a.png',
        width: 40,
        height: 30,
        fit: BoxFit.cover,
        semanticLabel: 'Photo',
      ),
    );
    expect(html, contains('alt="Photo"'));
    expect(html, contains('loading="lazy"'));
    expect(html, contains('decoding="async"'));
    expect(html, contains('width="40" height="30"'));
    expect(html, contains('object-fit: cover'));
  });

  test('a TextSpan with nothing of its own is just text', () async {
    final html = await renderHtml(
      const Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'plain '),
            TextSpan(
              text: 'bold',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: ' and '),
            TextSpan(text: 'a link', href: '/x'),
            TextSpan(text: ' named', semanticsLabel: 'named'),
          ],
        ),
      ),
    );
    // One span for the text itself; no root span, no span per plain run.
    expect(html, contains('>plain <span'));
    expect(html, contains('>bold</span> and <a'));
    expect(RegExp('<span').allMatches(html), hasLength(3)); // Text, bold, named
    expect(html, contains('href="/x"'));
    expect(html, contains('aria-label="named"'));
  });

  group('Spacer folding', () {
    Future<String> row(List<Widget> children, {double spacing = 0}) =>
        renderHtml(Row(spacing: spacing, children: children));
    int spacers(String html) =>
        RegExp('aria-hidden="true"').allMatches(html).length;

    test(
      'a Spacer between two children is an auto margin on the next',
      () async {
        final html = await row(const [Text('a'), Spacer(), Text('b')]);
        expect(spacers(html), 0);
        expect(html, contains('margin-inline-start: auto'));
        final col = await renderHtml(
          const Column(children: [Text('a'), Spacer(), Text('b')]),
        );
        expect(spacers(col), 0);
        expect(col, contains('margin-top: auto'));
      },
    );

    test('several spacers share the space like auto margins', () async {
      final html = await row(const [
        Text('a'),
        Spacer(),
        Text('b'),
        Spacer(),
        Text('c'),
      ], spacing: 8);
      expect(spacers(html), 0);
      expect(
        RegExp('margin-inline-start: auto').allMatches(html),
        hasLength(2),
      );
    });

    test('not folded where the space would go elsewhere', () async {
      for (final (why, children) in [
        (
          'an Expanded sibling',
          const [Text('a'), Spacer(), Expanded(child: Text('b'))],
        ),
        (
          'an Expanded inside a wrapper',
          const [
            Text('a'),
            Spacer(),
            Opacity(opacity: 1, child: Expanded(child: Text('b'))),
          ],
        ),
        ('flex 2', const [Text('a'), Spacer(flex: 2), Text('b')]),
        ('leading', const [Spacer(), Text('b')]),
        ('trailing', const [Text('a'), Spacer()]),
        ('two in a row', const [Text('a'), Spacer(), Spacer(), Text('b')]),
        // Found in the browser: the margin went to a nav hidden on phones,
        // and the actions after it lost their push to the right.
        (
          'next child may be hidden',
          const [
            Text('a'),
            Spacer(),
            ResponsiveVisibility(
              visibleFrom: WindowSizeClass.expanded,
              child: Text('nav'),
            ),
            Text('b'),
          ],
        ),
        (
          'next child hidden by Visibility',
          const [
            Text('a'),
            Spacer(),
            Visibility(visible: false, child: Text('x')),
          ],
        ),
      ]) {
        final html = await row(children);
        expect(html, isNot(contains('margin-inline-start: auto')), reason: why);
        expect(spacers(html), greaterThan(0), reason: why);
      }
    });
  });

  test('softWrap: false keeps line breaks and spaces, like Flutter', () async {
    final html = await renderHtml(const Text('a  b\nc', softWrap: false));
    expect(html, contains('white-space: pre'));
    expect(html, isNot(contains('nowrap')));
  });

  test('a line break in the text breaks the line, like Flutter', () async {
    final html = await renderHtml(const Text('one\n\ntwo'));
    expect(html, contains('white-space: pre-wrap'));
    // No break, no rule; and an ellipsis keeps its own nowrap.
    expect(
      await renderHtml(const Text('one two')),
      isNot(contains('pre-wrap')),
    );
    final clipped = await renderHtml(
      const Text('one\ntwo', maxLines: 1, overflow: TextOverflow.ellipsis),
    );
    expect(clipped, isNot(contains('pre-wrap')));
    expect(clipped, contains('nowrap'));
  });
}
