@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

/// Renders [component] on the server (compact, like release) and returns
/// the HTML. Without ThorApp, so styles are inline.
Future<String> render(Widget component) async {
  return renderHtml(component);
}

class _MyButton extends StatelessWidget {
  const _MyButton();

  @override
  Widget build(BuildContext context) =>
      Gesture(onTap: () {}, child: const Text('tap'));
}

class _MarkedButton extends StatelessWidget implements ThorElementWidget {
  const _MarkedButton();

  @override
  Widget build(BuildContext context) =>
      Gesture(onTap: () {}, child: const Text('tap'));
}

const _row =
    'display: flex; flex-direction: row; box-sizing: border-box; '
    'min-width: 0; min-height: 0; align-items: center';
const _text = 'margin: 0; min-width: 0; overflow-wrap: break-word';

void main() {
  setUpAll(initializeThorTests);

  test('Row maps to a flexbox with Flutter defaults', () async {
    final html = await render(
      const Row(
        spacing: 8,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text('a'), Text('b')],
      ),
    );
    // No structural classes: the Row grants `flex: 0 0 auto` to its
    // children (Flutter never shrinks non-flex children).
    expect(
      html,
      '<div style="$_row; justify-content: space-between; gap: 8px">'
      '<span style="$_text; flex: 0 0 auto">a</span>'
      '<span style="$_text; flex: 0 0 auto">b</span></div>',
    );
  });

  test('Expanded decorates the child element (no wrapper node)', () async {
    final html = await render(
      const Row(children: [Expanded(flex: 2, child: Text('x'))]),
    );
    // Parent data wins over the flex item rule the Row grants.
    expect(html, contains('<span style="$_text; flex: 2 1 0%">x</span>'));
  });

  test('directly nested wrappers are flattened into one element', () async {
    final html = await render(
      const Row(
        children: [
          Expanded(
            child: Opacity(
              opacity: 0.5,
              child: Positioned(top: 4, child: Container(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
    expect('<div'.allMatches(html), hasLength(2));
    expect(
      html,
      contains(
        'flex: 1 1 0%; display: flex; flex-direction: column; '
        'box-sizing: border-box; min-width: 0; min-height: 0; '
        'background-color: #f44336; opacity: 0.5; position: absolute; top: 4px',
      ),
    );
  });

  test('Container compiles padding, decoration and alignment', () async {
    final html = await render(
      Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        alignment: Alignment.bottomRight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('hi'),
      ),
    );
    // Box: column flexbox; bottom via justify-content, right via a physical
    // auto margin that the Container grants its (loose) child.
    expect(
      html,
      contains(
        'width: 200px; padding: 16px; background-color: #ffffff; '
        'border-radius: 8px; justify-content: flex-end"',
      ),
    );
    expect(
      html,
      contains(
        'flex: 0 1 auto; max-width: 100%; margin-left: auto; margin-right: 0',
      ),
    );
  });

  test('Stack uses a single grid cell; Positioned goes absolute', () async {
    final html = await render(
      const Stack(
        children: [
          SizedBox(width: 100, height: 100),
          Positioned(right: 0, bottom: 0, child: Text('badge')),
        ],
      ),
    );
    expect(
      html,
      startsWith(
        '<div style="display: grid; position: relative; '
        'place-items: start left; overflow: hidden">',
      ),
    );
    expect(
      html,
      contains(
        '<span style="$_text; grid-area: 1 / 1; position: absolute; '
        'right: 0px; bottom: 0px">badge</span>',
      ),
    );
  });

  test('Stack and IndexedStack place children at a fractional alignment '
      'like Align does, and leave Positioned alone', () async {
    for (final w in [
      const Stack(
        alignment: Alignment(0.5, -0.5),
        children: [
          SizedBox(width: 40, height: 40),
          Positioned(right: 0, bottom: 0, child: Text('badge')),
        ],
      ),
      const IndexedStack(
        alignment: Alignment(0.5, -0.5),
        children: [
          SizedBox(width: 40, height: 40),
          Positioned(right: 0, bottom: 0, child: Text('badge')),
        ],
      ),
    ]) {
      final html = await render(w);
      expect(html, contains('place-items: start'), reason: '${w.runtimeType}');
      expect(html, contains('position: relative'));
      // (0.5 + 1) * 50 = 75%, (-0.5 + 1) * 50 = 25%, translated back.
      expect(
        html,
        contains('left: 75%; top: 25%; translate: -75% -25%'),
        reason: '${w.runtimeType}',
      );
      // Only the non-positioned child: the badge stays absolute.
      expect('left: 75%'.allMatches(html), hasLength(1));
      expect(html, contains('position: absolute; right: 0px; bottom: 0px'));
    }
    // A named alignment is still a plain place-items keyword.
    final named = await render(
      const Stack(
        alignment: Alignment.center,
        children: [SizedBox(width: 40, height: 40)],
      ),
    );
    expect(named, contains('place-items: center'));
    expect(named, isNot(contains('translate')));
  });

  test(
    'Semantics(headingLevel:) renders a semantic heading with ellipsis',
    () async {
      final html = await render(
        const Semantics(
          headingLevel: 1,
          child: Text(
            'Title',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ),
      );
      expect(
        html,
        '<h1 style="$_text; font-size: 32px; font-weight: 700; '
        'overflow: hidden; text-overflow: ellipsis; white-space: nowrap; '
        'max-width: 100%">Title</h1>',
      );
    },
  );

  test(
    'Semantics(headingLevel:) alone keeps the inherited size and weight',
    () async {
      // Semantics only, like Flutter: no browser heading look.
      final html = await render(
        const Semantics(headingLevel: 2, child: Text('Title')),
      );
      expect(
        html,
        '<h2 style="$_text; font-size: inherit; font-weight: inherit">Title</h2>',
      );
    },
  );

  test('Theme publishes color roles as CSS variables', () async {
    final html = await render(
      Theme(
        data: ThemeData.dark(),
        child: const Center(child: Text('x')),
      ),
    );
    // Merged into the Center's element: no extra node, no extra class.
    expect('<div'.allMatches(html), hasLength(1));
    expect(html, contains('--t-primary: #d0bcff'));
    expect(html, contains('color-scheme: dark'));
  });

  test('buttons are real <button>s, disabled when onPressed is null', () async {
    final html = await render(
      const Row(children: [FilledButton(onPressed: null, child: Text('Save'))]),
    );
    expect(
      html,
      matches(
        RegExp(r'<button class="tl\w+" style="[^"]*" type="button" disabled>'),
      ),
    );
  });

  test('GridView.extent is responsive through CSS only', () async {
    final html = await render(
      const GridView.extent(
        maxCrossAxisExtent: 240,
        crossAxisSpacing: 12,
        children: [Text('a')],
      ),
    );
    // Flutter's cap: ceil(width / (max + spacing)) columns, counted by
    // container-query steps (auto-fill would count floor).
    expect(html, isNot(contains('auto-fill')));
    expect(html, contains('container-type: inline-size'));
    expect(html, contains('@container (min-width: 252.02px)'));
    // The grid grants its cells the aspect ratio: no CSS variable needed.
    expect(html, contains('aspect-ratio: 1'));
  });

  test('max-width propagates up like Flutter constraints', () async {
    // Flutter: Center > Container(maxWidth) > Column(stretch) is maxWidth
    // wide. Without the hint, CSS would shrink the Container to content.
    final html = await render(
      const Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Text('a')],
          ),
        ),
      ),
    );
    // The Container merges into the Column: one element, same layout.
    expect('<div'.allMatches(html), hasLength(2));
    expect(html, contains('max-width: 1080px'));
    // As wide as it may be, and still centered (not stretched to the left).
    expect(html, contains('width: 100%'));
    expect(html, contains('align-self: center'));
    expect(html, isNot(contains('align-self: stretch')));
    // A content-sized child keeps Flutter's shrink-wrap behavior.
    final shrink = await render(
      const Center(child: Container(child: Text('a'))),
    );
    expect(shrink, isNot(contains('align-self: stretch')));
    expect(shrink, isNot(contains('; width: 100%')));
  });

  test('spacers fold into margins; boxes merge into flex children', () async {
    final html = await render(
      const Semantics(
        role: SemanticsRole.region,
        child: Container(
          padding: EdgeInsets.all(12),
          color: Colors.white,
          child: Column(
            children: [
              Text('a'),
              SizedBox(height: 8),
              Text('b'),
              SizedBox(height: 4),
              SizedBox(height: 4),
              Text('c'),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    // One <section> (Container + Column merged), no spacer divs between.
    expect(
      html,
      startsWith('<section style="display: flex; flex-direction: column'),
    );
    expect(html, contains('padding: 12px; background-color: #ffffff'));
    expect(
      '<div'.allMatches(html),
      hasLength(1),
      reason: 'only the trailing spacer stays',
    );
    // The folded margin beats Text's `margin: 0` reset.
    expect(
      html,
      contains(
        '<span style="$_text; flex: 0 0 auto; margin-top: 8px">b</span>',
      ),
    );
    expect(
      html,
      contains(
        '<span style="$_text; flex: 0 0 auto; margin-top: 8px">c</span>',
      ),
    );
  });

  test('generated buttons are type=button, without redundant roles', () async {
    final html = await render(
      Gesture(
        onTap: () {},
        child: const Semantics(
          button: true,
          child: Container(child: Text('tap')),
        ),
      ),
    );
    // type=button: a <button> inside a <form> must not submit it.
    expect(html, contains('type="button"'));
    expect(html, isNot(contains('role="button"')));
    expect(html, isNot(contains('tabindex')));
  });

  test('wrappers split by a custom component still merge', () async {
    // The core merges nested wrappers across components: the inner
    // Gesture no longer shadows the outer Expanded.
    final html = await render(
      const Row(children: [Expanded(child: _MyButton())]),
    );
    // An unmarked component is transparent: its element gets the
    // wrapper data in its own styles, exactly like a marked one.
    expect(
      html,
      await render(const Row(children: [Expanded(child: _MarkedButton())])),
    );
    expect(html, isNot(contains('!important')));
    // Gesture(onTap) on a non-interactive element: keyboard-operable.
    expect(html, contains('role="button"'));
    expect(html, contains('tabindex="0"'));
  });

  test('a ThorElementWidget receives wrapper data in its own styles', () async {
    final html = await render(
      const Row(children: [Expanded(child: _MarkedButton())]),
    );
    expect(html, isNot(contains('<style')));
    expect(
      html,
      contains(
        '<span style="$_text; flex: 1 1 0%" '
        'role="button" tabindex="0">tap</span>',
      ),
    );
  });

  test('wrapper data never leaks to grandchildren', () async {
    final html = await render(
      const Row(
        children: [Expanded(child: Container(child: Text('x')))],
      ),
    );
    expect('flex: 1 1 0%'.allMatches(html), hasLength(1));
  });

  test(
    'without ThorApp, properties changed by conditions live in the class',
    () async {
      final html = await render(
        Column(
          layout: const FlexLayout().when(
            medium: const FlexLayout(direction: Axis.horizontal),
          ),
          children: const [Text('a')],
        ),
      );
      // An inline `flex-direction` would beat the media query.
      expect(
        html,
        matches(
          RegExp(
            r'\.tl\w+\{flex-direction: column\}@media screen and '
            r'\(min-width: 600px\)\{\.tl\w+\{flex-direction: row\}\}',
          ),
        ),
      );
      expect(html, isNot(contains('style="display: flex; flex-direction')));
    },
  );

  group('node merging', () {
    test('a box around plain text is one element', () async {
      final html = await render(
        const Container(
          padding: EdgeInsets.all(8),
          alignment: Alignment.center,
          child: Text('chip'),
        ),
      );
      expect(html, startsWith('<div style="'));
      expect(html, isNot(contains('<span')));
      expect(html, contains('justify-content: center; align-items: center'));
      expect(html, contains('>chip</div>'));
      // Padding and Center too.
      // Padding goes on the text's own element.
      expect(
        await render(
          const Padding(padding: EdgeInsets.all(4), child: Text('p')),
        ),
        matches(RegExp(r'^<span style="[^"]*padding: 4px">p</span>$')),
      );
      expect(
        await render(const Center(child: Text('c'))),
        isNot(contains('<span')),
      );
    });

    test('text that needs its own element keeps the span', () async {
      for (final c in const [
        Container(alignment: Alignment.centerRight, child: Text('x')),
        Container(child: Text('x', maxLines: 1)),
        Container(child: Semantics(headingLevel: 2, child: Text('x'))),
        Container(child: Text('x', semanticsLabel: 'y')),
      ]) {
        expect(await render(c), anyOf(contains('<span'), contains('<h2')));
      }
    });

    test('an aligned box merges into a centered Row', () async {
      final html = await render(
        const Semantics(
          role: SemanticsRole.header,
          child: Container(
            height: 84,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text('a'),
                Expanded(child: Text('b')),
              ],
            ),
          ),
        ),
      );
      expect('<div'.allMatches(html), isEmpty);
      expect(html, startsWith('<header style="'));
      expect(html, contains('height: 84px'));
      // Not when the Row would place its children differently.
      final top = await render(
        const Container(
          height: 84,
          alignment: Alignment.topLeft,
          child: Row(children: [Text('a')]),
        ),
      );
      expect('<div'.allMatches(top), hasLength(2));
    });

    test('a scroll view around a same-axis flex is one element', () async {
      final html = await render(
        const SingleChildScrollView(
          child: Column(children: [Text('a'), Text('b')]),
        ),
      );
      expect('<div'.allMatches(html), hasLength(1));
      expect(html, contains('flex-direction: column'));
      expect(html, contains('overflow: auto'));
      // A centered Column would be centered in the viewport: kept apart.
      final centered = await render(
        const SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Text('a')],
          ),
        ),
      );
      expect('<div'.allMatches(centered), hasLength(2));
    });

    // Flutter gives the child of a horizontal scroll view an
    // unbounded width, so a Column of long Rows is as wide as its widest
    // Row (no overflow). The box's width is the viewport's here: its child
    // takes its content's width instead.
    test('a horizontal scroll view sizes its child to its content', () async {
      final html = await render(
        const SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(children: [Text('a'), Text('b')]),
        ),
      );
      final column = RegExp(
        r'<div style="([^"]*flex-direction: column[^"]*)"',
      ).firstMatch(html)!;
      expect(column[1], contains('width: max-content'));
      // A vertical one: the child takes the view's width, as in Flutter.
      final vertical = await render(
        const SingleChildScrollView(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Text('a')],
          ),
        ),
      );
      expect(vertical, isNot(contains('max-content')));
    });

    // A horizontal viewport is as tall as its content (Flutter): in a row
    // it isn't stretched to the row's height, so a menu that scrolls
    // sideways stays centered with its row. A vertical one fills it.
    test('a horizontal scroll view in a row keeps its own height', () async {
      Future<String> inRow(Axis axis) => render(
        Row(
          children: [
            const Text('brand'),
            SingleChildScrollView(
              scrollDirection: axis,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('a'), Text('b')],
              ),
            ),
          ],
        ),
      );
      String scrollView(String html) => RegExp(
        r'<div style="([^"]*overflow: auto[^"]*)"',
      ).firstMatch(html)![1]!;
      expect(
        scrollView(await inRow(Axis.horizontal)),
        isNot(contains('align-self: stretch')),
      );
      expect(
        scrollView(await inRow(Axis.vertical)),
        contains('align-self: stretch'),
      );
    });

    test('a layout body becomes the <main> landmark', () async {
      final html = await render(
        const Scaffold(body: Column(children: [Text('a')])),
      );
      expect(
        html,
        contains('<main style="display: flex; flex-direction: column'),
      );
      expect(html, contains('grid-row: 2'));
      // Any other body is wrapped.
      final text = await render(const Scaffold(body: Text('x')));
      expect(text, contains('<main id="main-content" style="display: flex'));
      expect(text, contains('<span'));
    });
  });

  group('implicit animations', () {
    const ms200 = Duration(milliseconds: 200);

    test('AnimatedOpacity is a transition on the child element', () async {
      final html = await render(
        const AnimatedOpacity(
          opacity: 0.4,
          duration: ms200,
          curve: Curves.easeOut,
          child: Text('x'),
        ),
      );
      // One element: the transition lives in the child's own class.
      expect('<span'.allMatches(html), hasLength(1));
      expect(html, contains('opacity: 0.4'));
      expect(html, contains('transition-property: opacity'));
      expect(html, contains('transition-duration: 200ms'));
      expect(
        html,
        contains('transition-timing-function: cubic-bezier(0, 0, 0.58, 1)'),
      );
      // Reduced motion: applied instantly.
      expect(html, contains('@media (prefers-reduced-motion: reduce){.tl'));
    });

    test('nested implicit animations combine their transitions', () async {
      final html = await render(
        const AnimatedScale(
          scale: 1.1,
          duration: ms200,
          child: AnimatedContainer(
            width: 100,
            color: Colors.red,
            duration: Duration(milliseconds: 300),
          ),
        ),
      );
      expect('<div'.allMatches(html), hasLength(1));
      expect(html, contains('scale: 1.1'));
      expect(
        html,
        matches(
          RegExp(
            r'transition-property: scale, width, [^;]*box-shadow, transform;',
          ),
        ),
      );
      expect(html, contains('transition-duration: 200ms, 300ms,'));
      expect(html, isNot(contains('transition-delay')));
      expect('(prefers-reduced-motion: reduce)'.allMatches(html), hasLength(1));
    });

    test('AnimatedContainer still merges into a Row child', () async {
      final html = await render(
        const AnimatedContainer(
          padding: EdgeInsets.all(8),
          duration: ms200,
          child: Row(children: [Text('a')]),
        ),
      );
      expect('<div'.allMatches(html), hasLength(1));
      expect(html, contains('flex-direction: row'));
    });

    test('AnimatedAlign uses interpolable fractional positioning', () async {
      final html = await render(
        const SizedBox(
          width: 200,
          height: 60,
          child: AnimatedAlign(
            alignment: Alignment.bottomRight,
            duration: ms200,
            child: Text('x'),
          ),
        ),
      );
      expect(html, contains('left: 100%; top: 100%; translate: -100% -100%'));
      expect(html, contains('transition-property: left, top, translate'));
    });
  });
}
