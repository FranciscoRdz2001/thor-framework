@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/src/web/tw.dart' show twCacheSize;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/web.dart';

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

String bodyOf(String html) => html.substring(html.indexOf('<body'));

/// The class attribute of the element whose text is [text].
String classOf(String html, String text) {
  final body = bodyOf(html);
  final at = body.indexOf('>$text<');
  final open = body.lastIndexOf('class="', at);
  return body.substring(open + 7, body.indexOf('"', open + 7));
}

/// Every rule of class [cls].
String rulesOfClass(String html, String cls) => [
  for (final m in RegExp(
    '[^{}]*\\.$cls(?=[\\s{:,])[^{}]*\\{[^}]*\\}',
  ).allMatches(html))
    m[0],
].join('\n');

Matcher throwsCode(String code, [String? text]) => throwsA(
  isA<ArgumentError>().having(
    (e) => '${e.message}',
    'message',
    allOf(contains(code), contains(text ?? '')),
  ),
);

void main() {
  setUpAll(initializeThorTests);

  group('Style', () {
    test('each property is the CSS property of the same name', () {
      expect(
        Style(
          display: Display.flex,
          flexDirection: FlexDirection.column,
          gap: 8.px,
          paddingInline: 16.px,
          backgroundColor: const Color(0xFFFFFFFF),
          borderRadius: 12.px,
          fontWeight: FontWeight.w600,
          lineHeight: const LineHeight(1.5),
          gridTemplateColumns: const GridTracks.repeat(3),
          gridColumn: GridLine.full,
          containerType: ContainerType.inlineSize,
        ).toCss(),
        {
          'display': 'flex',
          'flex-direction': 'column',
          'gap': '8px',
          'padding-inline': '16px',
          'background-color': '#ffffff',
          'border-radius': '12px',
          'grid-template-columns': 'repeat(3, minmax(0, 1fr))',
          'grid-column': '1 / -1',
          'font-weight': '600',
          'line-height': '1.5',
          'container-type': 'inline-size',
        },
      );
    });

    test('a side wins over all four sides, in any order', () {
      final css = Style(paddingTop: 4.px, padding: 16.px).toCss();
      expect(css.keys.toList(), ['padding', 'padding-top']);
      final merged = Style(paddingTop: 4.px).merge(Style(padding: 16.px));
      expect(merged.toCss().keys.toList(), ['padding', 'padding-top']);
    });

    test('a border width comes with the style that shows it, on its '
        'sides only', () {
      expect(Style(borderTopWidth: 1.px).toCss(), {
        'border-top-width': '1px',
        'border-top-style': 'solid',
      });
      expect(Style(borderWidth: 2.px, borderStyle: LineStyle.dashed).toCss(), {
        'border-width': '2px',
        'border-style': 'dashed',
      });
      // A style alone draws nothing new: only the style is written.
      expect(const Style(borderStyle: LineStyle.dotted).toCss(), {
        'border-style': 'dotted',
      });
    });

    test('grid tracks by size', () {
      expect(
        GridTracks.sizes([
          GridTrack.length(200.px),
          GridTrack.fr(1),
          GridTrack.auto,
        ]).css,
        '200px 1fr auto',
      );
      expect(GridTracks.none.css, 'none');
    });
  });

  group('Style: the CSS names a model writes', () {
    test('shorthands are CSS shorthands, typed', () {
      expect(
        const Style(
          flex: 1,
          placeItems: AlignItems.center,
          justifySelf: AlignSelf.end,
          alignContent: JustifyContent.spaceBetween,
          border: BorderSide(color: Color(0xFF000000)),
          borderBottom: BorderSide(color: Color(0xFF000000), width: 2),
          textDecoration: TextDecoration.underline,
        ).toCss(),
        {
          'flex': '1',
          'place-items': 'center',
          'justify-self': 'end',
          'align-content': 'space-between',
          'border': '1px solid #000000',
          'border-bottom': '2px solid #000000',
          'text-decoration': 'underline',
        },
      );
    });

    test('a shorthand goes before its longhands, whatever the order', () {
      final keys = Style(
        flexGrow: 2,
        flex: 1,
        borderTopWidth: 3.px,
        border: const BorderSide(color: Color(0xFF000000)),
      ).toCss().keys.toList();
      expect(keys.indexOf('flex'), lessThan(keys.indexOf('flex-grow')));
      expect(
        keys.indexOf('border'),
        lessThan(keys.indexOf('border-top-width')),
      );
    });

    test('flex-start and start are different keywords, as in CSS', () {
      expect(AlignItems.flexStart.css, 'flex-start');
      expect(AlignItems.start.css, 'start');
      expect(AlignSelf.flexEnd.css, 'flex-end');
      expect(JustifyContent.end.css, 'end');
    });

    test('lengths can be const with Length.px', () {
      const style = Style(gap: Length.px(8), padding: Length.px(16));
      expect(style.toCss(), {'gap': '8px', 'padding': '16px'});
    });
  });

  group('tw()', () {
    test('its memo is bounded: values from data do not grow it forever', () {
      for (var i = 0; i < 10000; i++) {
        tw('bg-[#${i.toRadixString(16).padLeft(6, '0')}]');
      }
      expect(twCacheSize, lessThanOrEqualTo(4096));
      // Still the same answer for the same string.
      expect(tw('p-4').toString(), tw('p-4').toString());
    });

    test('is a Style with the same declarations', () {
      expect(
        tw('flex flex-col gap-2 px-4 rounded-xl font-semibold').toCss(),
        Style(
          display: Display.flex,
          flexDirection: FlexDirection.column,
          gap: 8.px,
          paddingInline: 16.px,
          borderRadius: 12.px,
          fontWeight: FontWeight.w600,
        ).toCss(),
      );
    });

    test('window size classes are variants too, as Style.when(medium:)', () {
      expect(
        tw('p-4 medium:p-8 expanded:p-12 extra-large:p-16').toCss(),
        Style(padding: 16.px)
            .when(
              medium: Style(padding: 32.px),
              expanded: Style(padding: 48.px),
              extraLarge: Style(padding: 64.px),
            )
            .toCss(),
      );
    });

    test('variants are the same .when() as Style', () {
      expect(
        tw('p-4 md:p-8 hover:bg-surface-container dark:text-white').toCss(),
        Style(padding: 16.px)
            .when(
              // tw()'s `md:` is the `expanded` window size class.
              expanded: Style(padding: 32.px),
              hover: const Style(backgroundColor: ThemeColor.surfaceContainer),
              dark: const Style(color: Color(0xFFFFFFFF)),
            )
            .toCss(),
      );
      // `group-open:` is the `<details>` around being open.
      expect(
        tw('p-4 group-open:p-8').toCss(),
        Style(padding: 16.px).when(open: Style(padding: 32.px)).toCss(),
      );
      // Container widths: named and arbitrary.
      final c = tw('grid-cols-1 @md:grid-cols-2 @min-[600px]:grid-cols-3');
      expect(
        c.toCss(),
        const Style(gridTemplateColumns: GridTracks.repeat(1))
            .when(
              container: {
                448: const Style(gridTemplateColumns: GridTracks.repeat(2)),
                600: const Style(gridTemplateColumns: GridTracks.repeat(3)),
              },
            )
            .toCss(),
      );
    });

    test('spacing, sizes, fractions, negatives and arbitrary lengths', () {
      expect(tw('p-0.5 m-px').toCss(), {'padding': '2px', 'margin': '1px'});
      expect(tw('w-1/2 h-full max-w-md min-h-dvh').toCss(), {
        'width': '50%',
        'height': '100%',
        'max-width': '448px',
        'min-height': '100dvh',
      });
      expect(tw('-mt-2 mx-auto').toCss(), {
        'margin-top': '-8px',
        'margin-inline': 'auto',
      });
      expect(tw('w-[13px] top-[50%] p-(--gutter)').toCss(), {
        'width': '13px',
        'top': '50%',
        'padding': 'var(--gutter)',
      });
      expect(tw('w-fit h-min').toCss(), {
        'width': 'fit-content',
        'height': 'min-content',
      });
    });

    test('colors are theme roles, with opacity, variables or hex', () {
      expect(tw('bg-primary text-on-primary').toCss(), {
        'background-color': 'var(--t-primary)',
        'color': 'var(--t-on-primary)',
      });
      expect(tw('bg-primary/10').toCss(), {
        'background-color':
            'color-mix(in srgb, var(--t-primary) 10%, transparent)',
      });
      expect(tw('text-(--brand) border-[#0f172a] border').toCss(), {
        'color': 'var(--brand)',
        'border-color': '#0f172a',
        'border-width': '1px',
        'border-style': 'solid',
      });
    });

    test('a theme color token by name, checked when it renders', () async {
      final muted = tw('text-muted bg-brand/20');
      expect(muted.toCss(), {
        'color': 'var(--t-muted)',
        'background-color':
            'color-mix(in srgb, var(--t-brand) 20%, transparent)',
      });
      expect(muted.themeTokens, {'muted', 'brand'});
      expect(tw('text-primary').themeTokens, isEmpty);
      expect(tw('p-4 hover:text-muted').themeTokens, {'muted'});

      final theme = ThemeData(
        colorTokens: const {
          'muted': Color(0xFF6B7280),
          'brand': Color(0xFF4F46E5),
        },
      );
      final ok = await renderDocument(
        ThorApp(
          theme: theme,
          child: P(text: 'x', style: muted),
        ),
      );
      expect(ok, contains('--t-muted'));
      // A name the theme doesn't have: an error that says how to add it,
      // not a color that silently disappears.
      expect(
        () => renderDocument(
          ThorApp(
            theme: theme,
            child: P(text: 'x', style: tw('bg-red-500')),
          ),
        ),
        throwsCode('THOR-R013', "colorTokens: {'red-500'"),
      );
    });

    test('text- is a size, an alignment or a color', () {
      expect(tw('text-sm text-center text-outline').toCss(), {
        'font-size': '14px',
        'line-height': '20px',
        'text-align': 'center',
        'color': 'var(--t-outline)',
      });
      expect(tw('text-[28px] text-[#111827]').toCss(), {
        'font-size': '28px',
        'color': '#111827',
      });
      expect(tw('text-sm/6').toCss(), {
        'font-size': '14px',
        'line-height': '24px',
      });
    });

    test('a default of another utility gives way, in any order', () {
      expect(tw('leading-6 text-sm').toCss()['line-height'], '24px');
      expect(tw('text-sm leading-6').toCss()['line-height'], '24px');
      expect(
        tw('duration-300 transition').toCss()['transition-duration'],
        '300ms',
      );
    });

    test('a side border draws only that side', () {
      expect(tw('border-t border-dashed').toCss(), {
        'border-top-width': '1px',
        'border-top-style': 'dashed',
      });
      expect(tw('border-x-2').toCss(), {
        'border-left-width': '2px',
        'border-right-width': '2px',
        'border-left-style': 'solid',
        'border-right-style': 'solid',
      });
      expect(tw('rounded-t-lg').toCss(), {
        'border-top-left-radius': '8px',
        'border-top-right-radius': '8px',
      });
    });

    test('an unknown utility names the closest one (THOR-R013)', () {
      expect(() => tw('pd-4'), throwsCode('THOR-R013', '`p-4`'));
      expect(() => tw('items-centre'), throwsCode('THOR-R013', 'items-center'));
      expect(() => tw('space-x-4'), throwsCode('THOR-R013', 'gap-x-N'));
      expect(() => tw('2xl:p-4'), throwsCode('THOR-R013', 'sm, md, lg, xl'));
      expect(() => tw('focus:p-4'), throwsCode('THOR-R013', 'focus-visible'));
      expect(
        () => tw('md:hover:p-4'),
        throwsCode('THOR-R013', 'one variant per utility'),
      );
      expect(() => tw('opacity-150'), throwsCode('THOR-R013'));
      expect(() => tw('-p-4'), throwsCode('THOR-R013'));
    });

    test('two utilities for the same property fail (THOR-R014)', () {
      expect(() => tw('p-4 p-8'), throwsCode('THOR-R014', '`p-4`'));
      expect(() => tw('flex hidden'), throwsCode('THOR-R014', 'display'));
      // In different variants they are no conflict.
      expect(tw('hidden md:flex').toCss()['display'], isNotEmpty);
    });

    test('nothing outside the grammar reaches the stylesheet', () {
      for (final bad in [
        'bg-[red;x]',
        'bg-[#12345]',
        'p-[1px;color:red]',
        'w-[calc(1px)]',
        'bg-(--x;y)',
        'text-(--X)',
        'p-[1px}</style>]',
      ]) {
        expect(() => tw(bad), throwsCode('THOR-R013'), reason: bad);
      }
    });
  });

  group('elements', () {
    test('one element, one class, text as a text node', () async {
      final html = await page(
        Article(
          style: tw('rounded-xl border p-4'),
          children: [
            H2(text: 'Title', style: tw('text-lg font-semibold')),
            const P(text: 'Body'),
          ],
        ),
      );
      final body = bodyOf(html);
      expect(body, contains('<article class="'));
      expect(
        RegExp(r'<h2 class="[^" ]+"[^>]*>Title</h2>').hasMatch(body),
        isTrue,
      );
      expect(RegExp(r'<p class="[^" ]+"[^>]*>Body</p>').hasMatch(body), isTrue);
      final h2 = rulesOfClass(html, classOf(html, 'Title'));
      expect(h2, contains('font-size: 18px'));
      expect(h2, contains('font-weight: 600'));
    });

    test('variants become rules of the same class', () async {
      final html = await page(
        Box(text: 'x', style: tw('p-4 md:p-8 hover:bg-surface')),
      );
      final cls = classOf(html, 'x');
      final rules = rulesOfClass(html, cls);
      expect(rules, contains('padding: 16px'));
      expect(rules, contains('padding: 32px'));
      expect(html, contains('(min-width: 840px){.$cls{padding: 32px}}'));
      expect(html, contains('.$cls:hover{background-color: var(--t-surface)}'));
      expect(cls, isNot(contains(' ')));
    });

    test('the preflight is below the style', () async {
      final html = await page(
        Box(
          children: [
            const H1(text: 'Plain'),
            H1(text: 'Big', style: tw('text-4xl mb-4')),
          ],
        ),
      );
      final plain = rulesOfClass(html, classOf(html, 'Plain'));
      expect(plain, contains('margin: 0'));
      expect(plain, contains('font-size: inherit'));
      final big = rulesOfClass(html, classOf(html, 'Big'));
      expect(big, contains('font-size: 36px'));
      expect(big, contains('margin-bottom: 16px'));
    });

    test('FlexBox is CSS flex: no stretch or sharing granted', () async {
      final html = await page(
        FlexBox(
          gap: 8.px,
          align: AlignItems.center,
          style: tw('md:flex-col'),
          children: [
            const Span(text: 'a'),
            const Span(text: 'b'),
          ],
        ),
      );
      // A child of a web flex gets nothing from it (a Row would grant
      // `flex-shrink: 0` and more): no class at all.
      expect(bodyOf(html), contains('<span data-thor="Span">a</span>'));
      final flex = rulesOfClass(html, classOf(html, 'a'));
      expect(flex, contains('display: flex; align-items: center; gap: 8px'));
      expect(flex, contains('flex-direction: column'));
    });

    test('links, buttons and images carry their attributes', () async {
      final html = bodyOf(
        await page(
          const Box(
            children: [
              A(href: '/x', text: 'Go'),
              Button(type: 'submit', disabled: true, text: 'Send'),
              Img(src: '/a.png', alt: 'A cat', width: 40, height: 30),
            ],
          ),
        ),
      );
      expect(html, contains('href="/x"'));
      expect(html, contains('type="submit"'));
      expect(html, contains('disabled'));
      expect(html, contains('alt="A cat"'));
      expect(html, contains('loading="lazy"'));
      expect(html, contains('width="40"'));
    });

    test('a ThorState method on a button is bound like onPressed', () async {
      final html = bodyOf(await page(Button(onClick: _state.inc, text: 'Add')));
      expect(html, contains('data-t-on="click:'));
    });
  });
}

final _state = _Counter();

// The member list thor generates for [_Counter], by hand.
abstract class _CounterMembers extends ThorState {
  @override
  String get $type => 'Counter';

  @override
  List<ThorMember> get $members {
    final s = this as _Counter;
    return [ThorMember('inc', s.inc, call: (_) => s.inc())];
  }
}

class _Counter extends _CounterMembers {
  int count = 0;

  void inc() => count++;
}
