import 'package:test/test.dart';
import 'package:thor_ui/html.dart' show css;
import 'package:thor_ui/thor_ui.dart';
import 'package:thor_ui/web.dart'
    show
        Display,
        UserSelect,
        GridTrack,
        GridTracks,
        ListStyleType,
        ObjectFit,
        WhiteSpace;

void main() {
  test('StyleProps writes the web-only typed values', () {
    final out = StyleProps(
      widthLength: Length.maxContent,
      aspectRatio: 1.5,
      display: Display.block,
      cursor: SystemMouseCursors.click,
      textAlign: TextAlign.center,
      whiteSpace: WhiteSpace.nowrap,
      textWrap: TextWrap.balance,
      overflowWrap: OverflowWrap.anywhere,
      verticalAlign: VerticalAlign.middle,
      listStyleType: ListStyleType.none,
      objectFit: ObjectFit.cover,
      filter: ImageFilter.saturate(0),
      mixBlendMode: BlendMode.multiply,
      appearance: Appearance.none,
      resize: Resize.horizontal,
      boxSizing: BoxSizing.borderBox,
      accentColor: const Color(0xFF16A34A),
      contentVisibility: ContentVisibility.auto,
      colorScheme: CssColorScheme.lightDark,
      scrollSnapType: const ScrollSnapType(Axis.horizontal),
      scrollSnapAlign: ScrollSnapAlign.start,
      scrollTargetGroup: ScrollTargetGroup.auto,
      borderCollapse: BorderCollapse.collapse,
      borderSpacing: 0,
    ).toCss();
    expect(out, {
      'width': 'max-content',
      'aspect-ratio': '1.5',
      'display': 'block',
      'cursor': 'pointer',
      'text-align': 'center',
      'white-space': 'nowrap',
      'text-wrap': 'balance',
      'overflow-wrap': 'anywhere',
      'vertical-align': 'middle',
      'list-style-type': 'none',
      'object-fit': 'cover',
      'filter': 'saturate(0)',
      'mix-blend-mode': 'multiply',
      'appearance': 'none',
      'resize': 'horizontal',
      'box-sizing': 'border-box',
      'accent-color': const Color(0xFF16A34A).css,
      'content-visibility': 'auto',
      'color-scheme': 'light dark',
      'scroll-snap-type': 'x mandatory',
      'scroll-snap-align': 'start',
      'scroll-target-group': 'auto',
      'border-collapse': 'collapse',
      'border-spacing': '0px',
    });
  });

  test('filter wins over blur and transition: [] writes none', () {
    expect(
      StyleProps(blur: 4, filter: ImageFilter.grayscale(1)).toCss()['filter'],
      'grayscale(1)',
    );
    expect(const StyleProps(transition: []).toCss(), {'transition': 'none'});
  });

  test(
    'a stylesheet takes the typed values and registers color properties',
    () {
      final sheet = [
        css('.a').props(
          const StyleProps(
            animation: [CssAnimation('fade', Duration(milliseconds: 90))],
          ),
        ),
        css.colorProperty('--t-ink', initialValue: const Color(0xFF000000)),
      ].map((r) => r.toCss()).join('\n');
      expect(sheet, contains('animation: fade 90ms ease 0ms 1 normal none;'));
      expect(sheet, contains('@property --t-ink'));
      expect(sheet, contains(r'syntax: "\3c color>";'));
      expect(sheet, contains('inherits: true;'));
    },
  );

  group('flex and grid container values', () {
    test('a column with Flutter names', () {
      expect(
        StyleProps(
          display: Display.flex,
          direction: Axis.vertical,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          wrap: true,
          spacing: 1.rem,
          runSpacing: 4.px,
        ).toCss(),
        {
          'display': 'flex',
          'flex-direction': 'column',
          'justify-content': 'center',
          'align-items': 'flex-start',
          'flex-wrap': 'wrap',
          'row-gap': '1rem',
          'column-gap': '4px',
        },
      );
    });

    test('spacing is the main axis: column-gap in a row, one gap if equal', () {
      expect(StyleProps(spacing: 8.px).toCss(), {'column-gap': '8px'});
      expect(StyleProps(runSpacing: 8.px).toCss(), {'row-gap': '8px'});
      expect(StyleProps(spacing: 8.px, runSpacing: 8.px).toCss(), {
        'gap': '8px',
      });
      expect(const StyleProps(wrap: false).toCss(), {'flex-wrap': 'nowrap'});
    });

    test('grid tracks: auto-fit, minmax, fr and auto rows', () {
      expect(
        StyleProps(
          display: Display.grid,
          gridTemplateColumns: GridTracks.autoFit(
            GridTrack.minmax(
              GridTrack.length(Length.min([100.percent, 24.rem])),
              GridTrack.fr(1),
            ),
          ),
          gridAutoRows: GridTrack.fr(1),
          spacing: 1.5.rem,
          runSpacing: 1.rem,
        ).toCss(),
        {
          'display': 'grid',
          'column-gap': '1.5rem',
          'row-gap': '1rem',
          'grid-template-columns':
              'repeat(auto-fit, minmax(min(100%, 24rem), 1fr))',
          'grid-auto-rows': '1fr',
        },
      );
      expect(
        GridTracks.sizes([
          GridTrack.minmax(GridTrack.length(60.percent), GridTrack.fr(1)),
          GridTrack.auto,
        ]).css,
        'minmax(60%, 1fr) auto',
      );
      expect(
        GridTracks.autoFill(GridTrack.length(10.rem)).css,
        'repeat(auto-fill, 10rem)',
      );
    });
  });

  test('fontSmoothing writes both engines\' declarations', () {
    expect(const StyleProps(fontSmoothing: FontSmoothing.antialiased).toCss(), {
      '-webkit-font-smoothing': 'antialiased',
      '-moz-osx-font-smoothing': 'grayscale',
    });
    expect(
      const StyleProps(
        textStyle: TextStyle(fontVariations: [FontVariation.opticalSize(24)]),
      ).toCss(),
      {'font-variation-settings': '"opsz" 24'},
    );
  });

  test('float, user-select, invert and a fractional translation', () {
    expect(
      StyleProps(
        float: BoxFloat.right,
        userSelect: UserSelect.none,
        filter: ImageFilter.compose(
          outer: ImageFilter.brightness(0.8),
          inner: ImageFilter.invert(1),
        ),
        fractionalTranslation: const Offset(-0.5, 0),
      ).toCss(),
      {
        'float': 'right',
        'user-select': 'none',
        'filter': 'invert(1) brightness(0.8)',
        'translate': '-50% 0%',
      },
    );
    expect(
      const StyleProps(
        offset: Offset(4, 0),
        fractionalTranslation: Offset(-0.5, 0),
      ).toCss()['translate'],
      'calc(-50% + 4px) calc(0% + 0px)',
    );
    expect(const StyleProps(float: BoxFloat.start).toCss(), {
      'float': 'inline-start',
    });
  });
}
