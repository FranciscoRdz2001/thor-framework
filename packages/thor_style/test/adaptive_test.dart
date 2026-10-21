import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

void main() {
  test('EdgeInsets.from marks only the sides that change', () {
    final p = const EdgeInsets.symmetric(
      horizontal: 32,
      vertical: 96,
    ).when(medium: const EdgeInsets.symmetric(horizontal: 32, vertical: 128));
    final split = splitAdaptive({'padding': p.css});
    expect(split.base, {'padding': '96px 32px'});
    expect(split.byBreakpoint, {
      'medium': {'padding': '128px 32px'},
    });
  });

  test('a breakpoint without its own value keeps the smaller one', () {
    final c = const Color(
      0xFF000000,
    ).when(medium: const Color(0xFFFF0000), expanded: const Color(0xFF00FF00));
    final split = splitAdaptive({'border': '1px solid ${c.css}'});
    expect(split.base['border'], '1px solid #000000');
    expect(split.byBreakpoint['medium']!['border'], '1px solid #ff0000');
    expect(split.byBreakpoint['expanded']!['border'], '1px solid #00ff00');
    expect(split.byBreakpoint.containsKey('large'), isFalse);
  });

  test('TextStyle.from changes only the properties that differ', () {
    final t = const TextStyle(
      fontSize: 48,
      fontWeight: FontWeight.w700,
    ).when(medium: const TextStyle(fontSize: 60, fontWeight: FontWeight.w700));
    final split = splitAdaptive(t.toCss());
    expect(split.base['font-size'], '48px');
    expect(split.byBreakpoint, {
      'medium': {'font-size': '60px'},
    });
  });

  test('no variants → plain value, no markers', () {
    final p = const EdgeInsets.all(8).when(medium: const EdgeInsets.all(8));
    expect(isAdaptive(p.css), isFalse);
    expect(p.css, '8px');
  });

  test('states change only what they set, with no breakpoint cascade', () {
    final c = const Color(
      0xFF000000,
    ).when(medium: const Color(0xFF111111), hover: const Color(0xFFFFFFFF));
    final split = splitAdaptive({'background-color': c.css});
    expect(split.base['background-color'], '#000000');
    expect(split.byBreakpoint['medium']!['background-color'], '#111111');
    expect(split.byBreakpoint['hover']!['background-color'], '#ffffff');
  });

  test('container variants cascade by width, apart from breakpoints', () {
    final p = const EdgeInsets.all(8).when(
      medium: const EdgeInsets.all(12),
      container: {400: const EdgeInsets.all(16), 700: const EdgeInsets.all(24)},
    );
    final split = splitAdaptive({'padding': p.css});
    expect(split.base['padding'], '8px');
    expect(split.byBreakpoint['medium']!['padding'], '12px');
    expect(split.byBreakpoint['c400']!['padding'], '16px');
    expect(split.byBreakpoint['c700']!['padding'], '24px');
  });

  test('container widths may be fractional; whole ones read the same', () {
    final p = const EdgeInsets.all(8).when(
      container: {
        925.5: const EdgeInsets.all(24),
        592.02: const EdgeInsets.all(16),
        400.0: const EdgeInsets.all(12),
      },
    );
    final split = splitAdaptive({'padding': p.css});
    expect(split.byBreakpoint['c400']!['padding'], '12px');
    expect(split.byBreakpoint['c592.02']!['padding'], '16px');
    expect(split.byBreakpoint['c925.5']!['padding'], '24px');
    expect(containerWidthOf('c592.02'), 592.02);
    expect(containerKeyOf(400.0), 'c400');
  });

  test('a breakpoint that goes back to the base after another changed it', () {
    final p = const EdgeInsets.all(
      8,
    ).when(medium: const EdgeInsets.all(16), expanded: const EdgeInsets.all(8));
    final split = splitAdaptive({'padding': p.css});
    expect(split.base, {'padding': '8px'});
    expect(split.byBreakpoint, {
      'medium': {'padding': '16px'},
      'expanded': {'padding': '8px'},
    });
  });

  test('declarations: a later breakpoint back to the base keeps its rule', () {
    final css = const Adaptive<String>(
      'a',
      medium: 'b',
      expanded: 'a',
    ).declarations((v) => {'x': v});
    final split = splitAdaptive(css);
    expect(split.byBreakpoint['expanded'], {'x': 'a'});
  });

  test('a state equal to the base still applies over a changed breakpoint', () {
    final css = const Adaptive<String>(
      'a',
      medium: 'b',
      hover: 'a',
    ).declarations((v) => {'x': v});
    expect(splitAdaptive(css).byBreakpoint['hover'], {'x': 'a'});
  });

  test('an equal-to-previous breakpoint is not repeated', () {
    final css = const Adaptive<String>(
      'a',
      medium: 'b',
      expanded: 'b',
    ).declarations((v) => {'x': v});
    expect(splitAdaptive(css).byBreakpoint.containsKey('expanded'), isFalse);
  });

  group('variants inside a state', () {
    const black = Color(0xFF000000);
    const white = Color(0xFFFFFFFF);
    const gray = Color(0xFF888888);

    test(
      'a hover that changes from medium up is the compound medium+hover',
      () {
        final c = black.when(hover: white.when(medium: gray));
        final split = splitAdaptive({'color': c.css});
        expect(split.base['color'], '#000000');
        expect(split.byBreakpoint['hover'], {'color': '#ffffff'});
        expect(split.byBreakpoint['medium+hover'], {'color': '#888888'});
      },
    );

    test('a breakpoint that has its own hover is the same compound', () {
      final c = black.when(medium: white.when(hover: gray));
      final split = splitAdaptive({'color': c.css});
      expect(split.byBreakpoint['medium'], {'color': '#ffffff'});
      expect(split.byBreakpoint['medium+hover'], {'color': '#888888'});
    });

    test('container widths compound too, and states may be named groups', () {
      final c = black.when(
        container: {400: white.when(hover: gray)},
        groupHovers: {'card': white.when(medium: gray)},
      );
      final split = splitAdaptive({'color': c.css});
      expect(split.byBreakpoint['c400+hover'], {'color': '#888888'});
      expect(split.byBreakpoint['group-hover/card'], {'color': '#ffffff'});
      expect(split.byBreakpoint['medium+group-hover/card'], {
        'color': '#888888',
      });
    });

    test('the inner cascade is mobile-first', () {
      final c = black.when(
        hover: white.when(medium: gray, expanded: const Color(0xFF999999)),
      );
      final split = splitAdaptive({'color': c.css});
      expect(split.byBreakpoint['medium+hover'], {'color': '#888888'});
      expect(split.byBreakpoint['expanded+hover'], {'color': '#999999'});
    });

    test(
      'a state in a state or a breakpoint in a breakpoint keeps its base',
      () {
        final c = black.when(
          hover: white.when(focused: gray),
          expanded: white.when(large: gray),
        );
        final split = splitAdaptive({'color': c.css});
        expect(split.byBreakpoint.keys.where((k) => k.contains('+')), isEmpty);
        expect(split.byBreakpoint['hover'], {'color': '#ffffff'});
        expect(split.byBreakpoint['expanded'], {'color': '#ffffff'});
      },
    );

    test('a named group is a variant of its own, listed with the others', () {
      const a = Adaptive<String>('a', groupHovers: {'card': 'b'});
      expect(a.variants, {'group-hover/card': 'b'});
    });
  });

  group('window size classes', () {
    test('medium..extraLarge cascade mobile-first', () {
      final p = const EdgeInsets.all(
        8,
      ).when(medium: const EdgeInsets.all(16), large: const EdgeInsets.all(32));
      final split = splitAdaptive(p.toCss('padding'));
      expect(split.base, {'padding': '8px'});
      expect(split.byBreakpoint, {
        'medium': {'padding': '16px'},
        'large': {'padding': '32px'},
      });
    });

    test('the cascade is ordered by width: expanded after medium', () {
      final css = const Adaptive<String>(
        'a',
        extraLarge: 'd',
        medium: 'b',
        expanded: 'c',
      ).css((v) => v);
      expect(resolveAdaptive(css, 'medium'), 'b');
      expect(resolveAdaptive(css, 'expanded'), 'c');
      // extraLarge also carries what expanded set before it.
      expect(resolveAdaptive(css, 'extraLarge'), 'd');
      expect(resolveAdaptive(css, 'large'), 'c');
    });
  });

  test('a variant can undo a bound or a shape the base sets', () {
    final c = const BoxConstraints(
      maxWidth: 600,
    ).when(expanded: const BoxConstraints());
    final split = splitAdaptive(c.toCss());
    expect(split.base, {'max-width': '600px'});
    expect(split.byBreakpoint['expanded'], {'max-width': 'none'});

    final d = const BoxDecoration(
      shape: BoxShape.circle,
    ).when(expanded: const BoxDecoration());
    final ds = splitAdaptive(d.toCss());
    expect(ds.base, {'border-radius': '50%'});
    expect(ds.byBreakpoint['expanded'], {'border-radius': '0'});
  });

  test('a state does not reset what a breakpoint set', () {
    final c = const BoxConstraints(maxWidth: 600).when(
      expanded: const BoxConstraints(maxWidth: 900),
      hover: const BoxConstraints(minWidth: 10),
    );
    final split = splitAdaptive(c.toCss());
    expect(split.byBreakpoint['hover'], {'min-width': '10px'});
  });

  test('a state resets what only the base sets', () {
    final d = const BoxDecoration(
      shape: BoxShape.circle,
    ).when(hover: const BoxDecoration());
    expect(splitAdaptive(d.toCss()).byBreakpoint['hover'], {
      'border-radius': '0',
    });
  });

  test('a variant without a border removes the base border', () {
    final d = BoxDecoration(
      border: Border.all(),
    ).when(expanded: const BoxDecoration());
    expect(splitAdaptive(d.toCss()).byBreakpoint['expanded'], {
      'border': 'none',
    });
  });

  group('mergeAdaptive', () {
    test('a marker over a marker is one marker, the upper one wins', () {
      final merged = mergeAdaptive(
        {
          'align-self': markAdaptive('stretch', {
            'c640': 'auto',
            'c900': 'auto',
          }),
        },
        {
          'align-self': markAdaptive('', {'c640': 'stretch'}),
        },
      );
      final value = merged['align-self']!;
      // Markers never nest: a nested one would leak into the CSS.
      expect('\u27e6'.allMatches(value), hasLength(1));
      final split = splitAdaptive(merged);
      expect(split.base, {'align-self': 'stretch'});
      expect(split.byBreakpoint['c640'], {'align-self': 'stretch'});
      expect(split.byBreakpoint['c900'], {'align-self': 'auto'});
    });

    test('a marker over a plain value takes it as its base', () {
      final merged = mergeAdaptive(
        {'align-self': 'stretch'},
        {
          'align-self': markAdaptive('', {'c640': 'auto'}),
        },
      );
      final split = splitAdaptive(merged);
      expect(split.base, {'align-self': 'stretch'});
      expect(split.byBreakpoint['c640'], {'align-self': 'auto'});
    });

    test('several markers in the lower value keep only its base', () {
      final under = {
        'padding': '${markAdaptive('1px', {'c640': '2px'})} 3px',
      };
      final merged = mergeAdaptive(under, {
        'padding': markAdaptive('', {'c640': '9px'}),
      });
      expect(isAdaptive(merged['padding']!), isTrue);
      final split = splitAdaptive(merged);
      expect(split.base['padding'], '1px 3px');
      expect(split.byBreakpoint['c640'], {'padding': '9px'});
    });
  });
}
