@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

/// The start tag of the first `<tag …>` of [html].
String tag(String html, String name) =>
    RegExp('<$name[ >][^>]*>').firstMatch(html)![0]!;

/// Every CSS rule of the first `<[name]>`'s classes, joined: what that
/// element looks like in every state.
String css(String html, String name) {
  final classes = RegExp(
    r'class="([^"]*)"',
  ).firstMatch(tag(html, name))![1]!.split(' ');
  final rules = <String>[];
  for (final c in classes) {
    rules.addAll(
      RegExp(
        '[^{}]*\\.${RegExp.escape(c)}[^{]*\\{[^}]*\\}',
      ).allMatches(html).map((m) => m[0]!),
    );
  }
  return rules.join('\n');
}

const _plus = Icon(Icons.add);

void main() {
  setUpAll(initializeThorTests);

  group('OutlinedButton side: none', () {
    test('drops the outline and keeps the label 24px from the edge', () async {
      final html = await page(
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(side: BorderSide.none),
          child: const Text('Go'),
        ),
      );
      final rules = css(html, 'button');
      expect(rules, contains('border: 0'));
      expect(rules, isNot(contains('1px solid')));
      expect(rules, contains('padding: 10px 24px'));
      expect(rules, isNot(contains('9px 23px')));
    });

    test('a style without a side keeps the outline', () async {
      final html = await page(
        OutlinedButton(onPressed: () {}, child: const Text('Go')),
      );
      expect(css(html, 'button'), contains('border: 1px solid'));
    });
  });

  group('ElevatedButton', () {
    test('is a real button, raised, with every state', () async {
      final html = await page(
        ElevatedButton(onPressed: () {}, child: const Text('Save')),
      );
      expect(tag(html, 'button'), contains('type="button"'));
      expect(tag(html, 'button'), isNot(contains('disabled')));
      // The label is the button's own text, no inner span.
      expect(html, contains('>Save</button>'));
      final rules = css(html, 'button');
      expect(rules, contains('--t-surface-container-low'));
      expect(rules, contains('var(--t-primary'));
      expect(rules, contains('box-shadow'));
      expect(rules, contains(':hover'));
      expect(rules, contains(':active'));
      expect(rules, contains(':focus-visible'));
      expect(rules, contains('transition-duration: 1ms'));
    });

    test('without onPressed it is disabled', () async {
      final html = await page(
        const ElevatedButton(onPressed: null, child: Text('Save')),
      );
      expect(tag(html, 'button'), contains('disabled'));
      final rules = css(html, 'button');
      expect(rules, contains(':disabled'));
      expect(rules, contains('opacity: 0.38'));
      // No hover nor pressed feedback on a disabled button.
      expect(
        rules,
        contains(':hover:not(:is(:disabled,[aria-disabled="true"]))'),
      );
      expect(
        rules,
        contains(':active:not(:is(:disabled,[aria-disabled="true"]))'),
      );
    });

    test('.icon folds the icon and the label in one button', () async {
      final html = await page(
        ElevatedButton.icon(
          onPressed: () {},
          icon: _plus,
          label: const Text('Add'),
        ),
      );
      expect(html, contains('<button'));
      expect('<button'.allMatches(html), hasLength(1));
      expect(html, contains('<use href="#material-add">'));
      expect(html, contains('>Add</button>'));
      final rules = css(html, 'button');
      expect(rules, contains('gap: 8px'));
      // Material 3: 16 before the icon, 24 after the label.
      expect(rules, contains('padding: 10px 24px 10px 16px'));
      // ...and the other way round in right-to-left text.
      expect(rules, contains(':dir(rtl)'));
      expect(rules, contains('padding: 10px 16px 10px 24px'));
    });

    test('.icon with a style padding keeps the style\'s', () async {
      final html = await page(
        ElevatedButton.icon(
          onPressed: () {},
          icon: _plus,
          label: const Text('Add'),
          style: const ButtonStyle(
            padding: WidgetStatePropertyAll(EdgeInsets.all(4)),
          ),
        ),
      );
      expect(css(html, 'button'), isNot(contains(':dir(rtl)')));
    });

    test('href makes it a link', () async {
      final html = await page(
        const ElevatedButton(href: '/go', child: Text('Go')),
      );
      expect(tag(html, 'a'), contains('href="/go"'));
      expect(html, isNot(contains('<button')));
    });

    test('styleFrom is Flutter\'s', () {
      final s = ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF112233),
      );
      expect(s.backgroundColor?.resolve({}), const Color(0xFF112233));
    });
  });

  group('the .icon and tonal constructors', () {
    for (final (name, make) in <(String, Widget Function())>[
      (
        'FilledButton.icon',
        () => FilledButton.icon(
          onPressed: () {},
          icon: _plus,
          label: const Text('Add'),
        ),
      ),
      (
        'FilledButton.tonalIcon',
        () => FilledButton.tonalIcon(
          onPressed: () {},
          icon: _plus,
          label: const Text('Add'),
        ),
      ),
      (
        'OutlinedButton.icon',
        () => OutlinedButton.icon(
          onPressed: () {},
          icon: _plus,
          label: const Text('Add'),
        ),
      ),
      (
        'TextButton.icon',
        () => TextButton.icon(
          onPressed: () {},
          icon: _plus,
          label: const Text('Add'),
        ),
      ),
    ]) {
      test('$name is one button with the icon before the label', () async {
        final html = await page(make());
        expect('<button'.allMatches(html), hasLength(1));
        expect(
          html.indexOf('material-add'),
          lessThan(html.indexOf('>Add</button>')),
        );
        expect(css(html, 'button'), contains('gap: 8px'));
      });
    }

    test('TextButton.icon has the smaller Material padding', () async {
      final html = await page(
        TextButton.icon(
          onPressed: () {},
          icon: _plus,
          label: const Text('Add'),
        ),
      );
      expect(css(html, 'button'), contains('padding: 10px 16px 10px 12px'));
    });

    test('OutlinedButton.icon keeps the border inside the padding', () async {
      final html = await page(
        OutlinedButton.icon(
          onPressed: () {},
          icon: _plus,
          label: const Text('Add'),
        ),
      );
      expect(css(html, 'button'), contains('padding: 9px 23px 9px 15px'));
    });

    test('FilledButton.tonal is filled with the secondary container', () async {
      final html = await page(
        FilledButton.tonal(onPressed: () {}, child: const Text('Tonal')),
      );
      final rules = css(html, 'button');
      expect(rules, contains('--t-secondary-container'));
      expect(rules, contains('--t-on-secondary-container'));
      expect(rules, isNot(contains('background-color: var(--t-primary')));
      expect(rules, contains(':active'));
    });

    test('plain Filled, Outlined and Text are pressed and calm too', () async {
      for (final w in <Widget>[
        FilledButton(onPressed: () {}, child: const Text('x')),
        OutlinedButton(onPressed: () {}, child: const Text('x')),
        TextButton(onPressed: () {}, child: const Text('x')),
      ]) {
        final rules = css(await page(w), 'button');
        expect(rules, contains(':active'), reason: '${w.runtimeType}');
        expect(rules, contains('10%'), reason: '${w.runtimeType}');
        expect(
          rules,
          contains('transition-duration: 1ms'),
          reason: '${w.runtimeType}',
        );
      }
    });

    test('.tonalIcon is tonal with an icon', () async {
      final html = await page(
        FilledButton.tonalIcon(
          onPressed: () {},
          icon: _plus,
          label: const Text('Add'),
        ),
      );
      expect(css(html, 'button'), contains('--t-secondary-container'));
    });
  });

  group('FloatingActionButton', () {
    test('a 56 px button named by its tooltip', () async {
      final html = await page(
        FloatingActionButton(
          onPressed: () {},
          tooltip: 'New note',
          child: _plus,
        ),
      );
      final start = tag(html, 'button');
      expect(start, contains('aria-label="New note"'));
      expect(start, contains('title="New note"'));
      expect(start, contains('type="button"'));
      final rules = css(html, 'button');
      expect(rules, contains('--t-primary-container'));
      expect(rules, contains('--t-on-primary-container'));
      expect(rules, contains('min-width: 56px'));
      expect(rules, contains('min-height: 56px'));
      expect(rules, contains('border-radius: 16px'));
      expect(rules, contains('box-shadow'));
      expect(rules, contains(':hover'));
      expect(rules, contains(':active'));
      expect(rules, contains(':focus-visible'));
      expect(rules, contains('transition-duration: 1ms'));
    });

    test('.small is 40 px and .large 96 px with a 36 px icon', () async {
      final small = await page(
        FloatingActionButton.small(onPressed: () {}, child: _plus),
      );
      expect(css(small, 'button'), contains('min-width: 40px'));
      expect(css(small, 'button'), contains('border-radius: 12px'));
      final large = await page(
        FloatingActionButton.large(onPressed: () {}, child: _plus),
      );
      final rules = css(large, 'button');
      expect(rules, contains('min-width: 96px'));
      expect(rules, contains('border-radius: 28px'));
      expect(rules, contains('width: 36px'));
    });

    test('disabled without onPressed', () async {
      final html = await page(
        const FloatingActionButton(onPressed: null, child: _plus),
      );
      expect(tag(html, 'button'), contains('disabled'));
      expect(css(html, 'button'), contains('opacity: 0.38'));
    });

    test('.extended is an icon and a label in one button', () async {
      final html = await page(
        FloatingActionButton.extended(
          onPressed: () {},
          icon: _plus,
          label: const Text('Compose'),
        ),
      );
      expect('<button'.allMatches(html), hasLength(1));
      expect(html, contains('>Compose</button>'));
      // The label names it: no aria-label to override it.
      expect(tag(html, 'button'), isNot(contains('aria-label')));
      final rules = css(html, 'button');
      expect(rules, contains('min-height: 56px'));
      expect(rules, contains('gap: 8px'));
    });

    test(
      '.extended with a long label wraps, never leaves the screen',
      () async {
        final html = await page(
          FloatingActionButton.extended(
            onPressed: () {},
            label: const Text(
              'A very long label that does not fit a phone next to the corner '
              'the button floats in',
            ),
          ),
        );
        final rules = css(html, 'button');
        expect(rules, contains('max-width: calc(100vw - 32px)'));
        expect(rules, contains('overflow-wrap: anywhere'));
        expect(rules, isNot(contains('white-space: nowrap')));
        expect(rules, contains('min-height: 56px'));
      },
    );

    test('.extended with a tooltip only titles it', () async {
      final html = await page(
        FloatingActionButton.extended(
          onPressed: () {},
          tooltip: 'Write a note',
          label: const Text('Compose'),
        ),
      );
      expect(tag(html, 'button'), contains('title="Write a note"'));
      expect(tag(html, 'button'), isNot(contains('aria-label')));
    });

    test('colors override the tokens', () async {
      final html = await page(
        FloatingActionButton(
          onPressed: () {},
          backgroundColor: const Color(0xFF112233),
          foregroundColor: const Color(0xFFffffff),
          tooltip: 'x',
          child: _plus,
        ),
      );
      expect(css(html, 'button'), contains('#112233'));
    });

    test(
      'goes in Scaffold(floatingActionButton:), fixed in the corner',
      () async {
        final html = await page(
          Scaffold(
            body: const Text('body'),
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              tooltip: 'New',
              child: _plus,
            ),
          ),
        );
        expect(html, contains('aria-label="New"'));
        expect(html, contains('position: fixed'));
      },
    );

    test('href makes it a link that still needs a name', () async {
      final html = await page(
        const FloatingActionButton(
          href: '/new',
          tooltip: 'New',
          onPressed: null,
          child: _plus,
        ),
      );
      final start = tag(html, 'a');
      expect(start, contains('href="/new"'));
      expect(start, contains('aria-label="New"'));
      expect(start, isNot(contains('disabled')));
    });
  });

  group('IconButton', () {
    test('href is a link with the tooltip as its name', () async {
      final html = await page(
        const IconButton(href: '/settings', tooltip: 'Settings', icon: _plus),
      );
      final start = tag(html, 'a');
      expect(start, contains('href="/settings"'));
      expect(start, contains('aria-label="Settings"'));
      expect(start, contains('title="Settings"'));
      expect(start, isNot(contains('type=')));
      expect(start, isNot(contains('disabled')));
      expect(html, isNot(contains('<button')));
      final rules = css(html, 'a');
      expect(rules, contains('text-decoration: none'));
      expect(rules, contains('width: 48px'));
      expect(rules, contains(':hover'));
      expect(rules, contains(':focus-visible'));
    });

    test('href with onPressed is still a link, never disabled', () async {
      final html = await page(
        IconButton(href: '/a', tooltip: 'A', onPressed: () {}, icon: _plus),
      );
      expect(tag(html, 'a'), contains('href="/a"'));
      expect(tag(html, 'a'), isNot(contains('disabled')));
    });

    test('href without a tooltip is refused: a link needs a name', () {
      expect(
        () => IconButton(href: '/a', icon: _plus),
        throwsA(isA<AssertionError>()),
      );
    });

    test('an empty tooltip names nothing: refused too', () {
      expect(
        () => IconButton(href: '/a', tooltip: '', icon: _plus),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => IconButton.filled(href: '/a', tooltip: '', icon: _plus),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => FloatingActionButton(
          onPressed: null,
          href: '/a',
          tooltip: '',
          child: _plus,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a Semantics label around the icon names the link too', () async {
      // Flutter's way to name an IconButton is `tooltip`; a label from the
      // icon still counts for a plain button.
      final html = await page(
        const IconButton(
          onPressed: null,
          icon: Icon(Icons.add, semanticLabel: 'Add'),
        ),
      );
      expect(html, contains('aria-label="Add"'));
    });

    test(
      '.filled, .filledTonal and .outlined are 40 px Material 3 variants',
      () async {
        final filled = css(
          await page(
            IconButton.filled(onPressed: () {}, tooltip: 'F', icon: _plus),
          ),
          'button',
        );
        expect(filled, contains('background: var(--t-primary'));
        expect(filled, contains('var(--t-on-primary'));
        expect(filled, contains('width: 40px'));
        expect(filled, contains(':active'));
        expect(filled, contains(':disabled'));
        expect(filled, contains('transition-duration: 1ms'));

        final tonal = css(
          await page(
            IconButton.filledTonal(onPressed: () {}, tooltip: 'T', icon: _plus),
          ),
          'button',
        );
        expect(tonal, contains('--t-secondary-container'));

        final outlined = css(
          await page(
            IconButton.outlined(onPressed: () {}, tooltip: 'O', icon: _plus),
          ),
          'button',
        );
        expect(outlined, contains('1px solid'));
        expect(outlined, contains('--t-outline'));
      },
    );

    test('variants are links with href too', () async {
      final html = await page(
        const IconButton.filled(href: '/x', tooltip: 'X', icon: _plus),
      );
      expect(tag(html, 'a'), contains('href="/x"'));
      expect(css(html, 'a'), contains('var(--t-primary'));
    });

    test('a disabled variant looks disabled', () async {
      final html = await page(
        const IconButton.filled(onPressed: null, tooltip: 'D', icon: _plus),
      );
      expect(tag(html, 'button'), contains('disabled'));
      expect(css(html, 'button'), contains('opacity: 0.38'));
    });

    test(
      'the plain IconButton is pressed and disabled like Material 3',
      () async {
        final html = await page(
          IconButton(onPressed: () {}, tooltip: 'P', icon: _plus),
        );
        final rules = css(html, 'button');
        expect(rules, contains(':active'));
        expect(rules, contains('width: 48px'));
        expect(rules, contains('border-radius: 50%'));
        expect(rules, contains('transition-duration: 1ms'));
        final off = await page(
          const IconButton(onPressed: null, tooltip: 'P', icon: _plus),
        );
        expect(tag(off, 'button'), contains('disabled'));
        expect(css(off, 'button'), contains('opacity: 0.38'));
        expect(css(off, 'button'), contains('cursor: default'));
      },
    );

    test('an icon link is pressed too, and is never disabled', () async {
      final html = await page(
        const IconButton(href: '/x', tooltip: 'X', icon: _plus),
      );
      expect(css(html, 'a'), contains(':active'));
      expect(css(html, 'a'), isNot(contains('opacity: 0.38')));
    });

    test(
      'the tonal button stops its transition under reduced motion',
      () async {
        final html = await page(
          FilledButton.tonal(onPressed: () {}, child: const Text('T')),
        );
        expect(css(html, 'button'), contains('transition-duration: 1ms'));
      },
    );
  });

  group('the container roles follow the theme (dark mode, custom colors)', () {
    Future<String> themed(Widget body) => renderDocument(
      ThorApp(
        theme: ThemeData(colorScheme: const ColorScheme.light()),
        darkTheme: ThemeData(colorScheme: const ColorScheme.dark()),
        child: body,
      ),
    );

    test('--t-primary-container is published, light and dark', () async {
      final html = await themed(
        FloatingActionButton(onPressed: () {}, tooltip: 'F', child: _plus),
      );
      expect(
        html,
        contains('--t-primary-container:light-dark(#eaddff, #4f378b)'),
      );
      expect(
        html,
        contains('--t-on-primary-container:light-dark(#21005d, #eaddff)'),
      );
    });

    test('a custom scheme without them publishes its primary', () async {
      final html = await renderDocument(
        ThorApp(
          theme: ThemeData(
            colorScheme: const ColorScheme(
              brightness: Brightness.light,
              primary: Color(0xFF00695C),
              onPrimary: Color(0xFFFFFFFF),
              secondary: Color(0xFF4A635F),
              onSecondary: Color(0xFFFFFFFF),
              error: Color(0xFFB3261E),
              onError: Color(0xFFFFFFFF),
              surface: Color(0xFFFFFFFF),
              onSurface: Color(0xFF000000),
              surfaceContainer: Color(0xFFEEEEEE),
              outline: Color(0xFF777777),
              outlineVariant: Color(0xFFCCCCCC),
            ),
          ),
          child: FloatingActionButton(
            onPressed: () {},
            tooltip: 'F',
            child: _plus,
          ),
        ),
      );
      expect(html, contains('--t-primary-container:#00695c'));
    });
  });
}
