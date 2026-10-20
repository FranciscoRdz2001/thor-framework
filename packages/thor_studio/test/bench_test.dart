// The bench widgets: structure, roles, native controls, keyboard semantics,
// strings from parameters and color contrast.
import 'dart:math';

import 'package:test/test.dart';
import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

final _theme = StudioTheme.light();

// The member list thor generates for [_RadiusState], by hand.
abstract class _RadiusMembers extends ThorState {
  @override
  String get $type => 'RadiusState';

  @override
  List<ThorMember> get $members {
    final s = this as _RadiusState;
    return [
      ThorMember.state('radius', s.radius),
      ThorMember('radiusText', s.radiusText, call: (_) => s.radiusText()),
    ];
  }
}

class _RadiusState extends _RadiusMembers {
  final radius = state(20.0);
  String radiusText() => '${radius.value.round()} px';
}

final _radius = _RadiusState();

Future<String> _page(Widget child) async =>
    bodyOfPage(await renderDocument(ThorApp(theme: _theme, child: child)));

Future<String> _head(Widget child) async =>
    headOfPage(await renderDocument(ThorApp(theme: _theme, child: child)));

enum _Fill { soft, solid }

Widget _bench({String id = 'demo-1', String? replayLabel}) => StudioBench(
  id: id,
  title: 'Rounded card',
  description: 'Pull the radius.',
  demoLabel: 'Live',
  codeLabel: 'Source',
  viewLabel: 'View',
  replayLabel: replayLabel,
  stage: const Text('THE-STAGE'),
  code: const Text('THE-CODE'),
  panel: const StudioBenchPanel(
    groups: [
      StudioBenchGroup(
        label: 'Switches',
        children: [
          StudioBenchRow(
            label: 'Fill',
            child: StudioSegmentedControl<_Fill>(
              semanticLabel: 'Fill',
              selected: {_Fill.soft},
              segments: [
                StudioButtonSegment(value: _Fill.soft, label: Text('Soft')),
                StudioButtonSegment(value: _Fill.solid, label: Text('Solid')),
              ],
            ),
          ),
        ],
      ),
      StudioBenchGroup(
        label: 'Levels',
        children: [
          StudioLevelSlider(
            title: 'Radius',
            value: 16,
            max: 48,
            divisions: 12,
            onChanged: _noop,
          ),
        ],
      ),
    ],
    footer: [
      OutlinedButton(href: '/share', child: Text('Share')),
      FilledButton(child: Text('Open')),
    ],
  ),
);

void _noop(double _) {}

void _noopSet(Set<_Fill> _) {}

void main() {
  setUpAll(initializeThorTests);

  group('StudioSegmentedControl', () {
    Widget control({bool enabled = true}) => StudioSegmentedControl<_Fill>(
      semanticLabel: 'Fill',
      selected: const {_Fill.solid},
      onSelectionChanged: enabled ? _noopSet : null,
      segments: const [
        StudioButtonSegment(value: _Fill.soft, label: Text('Light')),
        StudioButtonSegment(value: _Fill.solid, label: Text('Dark')),
      ],
    );

    test('is a native radio group named by its label', () async {
      final html = await renderHtml(control());
      expect(html, contains('role="radiogroup"'));
      expect(html, contains('aria-label="Fill"'));
      expect(RegExp('type="radio"').allMatches(html), hasLength(2));
      // The browser moves the choice with the arrow keys: one name.
      final names = RegExp(r'name="([^"]+)"').allMatches(html);
      expect({for (final m in names) m[1]}, hasLength(1));
      expect(html, contains('aria-label="Light"'));
      expect(html, contains('aria-label="Dark"'));
      expect(html, contains('>Light<'));
    });

    test('a Text.rich label still names its radio', () async {
      final html = await renderHtml(
        const StudioSegmentedControl<_Fill>(
          semanticLabel: 'Fill',
          selected: {_Fill.solid},
          onSelectionChanged: _noopSet,
          segments: [
            StudioButtonSegment(
              value: _Fill.soft,
              label: Text.rich(
                TextSpan(
                  text: 'Light ',
                  children: [TextSpan(text: 'mode')],
                ),
              ),
            ),
            StudioButtonSegment(value: _Fill.solid, label: Text('Dark')),
          ],
        ),
      );
      expect(html, contains('aria-label="Light mode"'));
    });

    test('never clips: a wrapping row of cells, CSS only', () async {
      final head = await _head(
        StudioSegmentedControl<int>(
          semanticLabel: 'Long',
          selected: {0},
          segments: [
            for (var i = 0; i < 5; i++)
              StudioButtonSegment(
                value: i,
                label: Text('A rather long label $i'),
              ),
          ],
        ),
      );
      // No estimate of the text width: the cells share the line by content
      // and wrap onto the next row when it is narrower.
      expect(head, contains('flex-wrap: wrap'));
      expect(
        head,
        contains('flex-grow: 1; flex-shrink: 1; flex-basis: max-content'),
      );
      expect(head, isNot(contains('grid-template-columns')));
      expect(head, isNot(contains('@container (max-width')));
      expect(head, contains('max-width: 100%'));
      expect(head, contains('width: fit-content'));
      // Each segment may shrink to 0 and has a least (not a fixed) height,
      // so a label that wraps grows its cell.
      expect(head, contains('min-height: 32px'));
      expect(head, isNot(contains(' height: 32px')));
    });

    test(
      'a long label wraps in its cell: never clipped, no ellipsis',
      () async {
        final head = await _head(
          StudioSegmentedControl<int>(
            semanticLabel: 'Fields',
            selected: const {0},
            segments: [
              for (final label in ['Requerido', 'Correo electrónico', 'Mín. 8'])
                StudioButtonSegment(value: label.length, label: Text(label)),
            ],
          ),
        );
        // The label breaks at spaces (balanced) and, only when a word alone is
        // wider than the cell, inside the word.
        expect(head, contains('overflow-wrap: anywhere'));
        expect(head, contains('text-wrap: balance'));
        expect(head, contains('min-width: 0'));
        // The old reading: one line with an ellipsis.
        expect(head, isNot(contains('text-overflow')));
        expect(head, isNot(contains('white-space: nowrap')));
      },
    );

    test('the thumb follows the checked cell by anchor positioning', () async {
      final head = await _head(
        const StudioSegmentedControl<int>(
          semanticLabel: 'Variant',
          selected: {1},
          segments: [
            StudioButtonSegment(value: 0, label: Text('Estándar')),
            StudioButtonSegment(value: 1, label: Text('Relleno')),
            StudioButtonSegment(value: 2, label: Text('Tonal')),
            StudioButtonSegment(value: 3, label: Text('Borde')),
          ],
        ),
      );
      final css = head.replaceAll(RegExp(r'\s+'), ' ');
      // The checked cell is the anchor, the thumb takes its box.
      expect(css, contains('@supports (anchor-name: --t-seg)'));
      expect(css, contains('anchor-name: --t-seg'));
      expect(css, contains('anchor-scope: --t-seg'));
      expect(css, contains('position-anchor: --t-seg'));
      expect(css, contains('left: anchor(left)'));
      expect(css, contains('top: anchor(top)'));
      expect(css, contains('width: anchor-size(width)'));
      expect(css, contains('height: anchor-size(height)'));
      // No per-position rules, no column math, no stacked mode.
      expect(css, isNot(contains(':nth-child')));
      expect(css, isNot(contains('calc((100% -')));
      expect(css, isNot(contains('@container (max-width')));
      // Without anchor positioning: the checked cell is the background.
      expect(css, contains('@supports not (anchor-name: --t-seg)'));
      final fallback = RegExp(
        r'@supports not \(anchor-name: --t-seg\)\{[^{]*:has\(:checked\)\{[^}]*background-color',
      );
      expect(
        css.replaceAll(' {', '{').replaceAll('{ ', '{'),
        contains(fallback),
      );
    });

    test('keeps the radio group order when it wraps', () async {
      final html = await renderHtml(
        StudioSegmentedControl<int>(
          semanticLabel: 'Long',
          selected: {2},
          segments: [
            for (var i = 0; i < 5; i++)
              StudioButtonSegment(
                value: i,
                label: Text('A rather long label $i'),
              ),
          ],
        ),
      );
      expect(RegExp('type="radio"').allMatches(html), hasLength(5));
      expect(html, contains('role="radiogroup"'));
      expect(RegExp(r'\schecked[\s>=/]').allMatches(html), hasLength(1));
    });

    test('a bench row wraps its control under the name', () async {
      final head = await _head(
        const StudioBenchRow(label: 'Fill', child: Text('x')),
      );
      expect(head, contains('flex-wrap: wrap'));
    });

    test(
      'more than two segments take their own full-width line under the name',
      () async {
        Widget row(int n) => StudioBenchRow(
          label: 'Mode',
          child: StudioSegmentedControl<int>(
            semanticLabel: 'Mode',
            selected: {0},
            segments: [
              for (var i = 0; i < n; i++)
                StudioButtonSegment(value: i, label: Text('S$i')),
            ],
          ),
        );
        // Three: a column (name, then the control as wide as the row).
        final three = await _head(row(3));
        expect(three, contains('flex-direction: column'));
        expect(three, contains('width: 100%'));
        // Two: still beside the name (no own line for the control).
        final two = await _head(row(2));
        expect(two, isNot(equals(three)));
      },
    );

    test('four short labels stay one row', () async {
      final head = await _head(
        const StudioSegmentedControl<int>(
          semanticLabel: 'Curve',
          selected: {0},
          segments: [
            StudioButtonSegment(value: 0, label: Text('Out')),
            StudioButtonSegment(value: 1, label: Text('In-out')),
            StudioButtonSegment(value: 2, label: Text('Lineal')),
            StudioButtonSegment(value: 3, label: Text('Back')),
          ],
        ),
      );
      expect(head, contains('flex-wrap: wrap'));
      expect(head, contains('anchor-size(width)'));
    });

    test('checks the segment of the value only', () async {
      final html = await renderHtml(control());
      final radios = RegExp('<input[^>]*type="radio"[^>]*>').allMatches(html);
      final checked = [
        for (final m in radios)
          if (m[0]!.contains('checked')) m[0]!,
      ];
      expect(checked, hasLength(1));
      expect(checked.single, contains('value="solid"'));
    });

    test(
      'the chosen look is a :has(:checked) rule, not a class swap',
      () async {
        final head = await _head(control());
        expect(head, contains(':has(:checked)'));
        expect(head, contains(':has(:focus-visible)'));
        expect(head, contains(':has(:active)'));
        expect(head, contains('scale: 0.97'));
      },
    );

    test('a disabled control disables every radio', () async {
      final html = await renderHtml(control(enabled: false));
      final radios = RegExp('<input[^>]*type="radio"[^>]*>').allMatches(html);
      expect(radios, hasLength(2));
      for (final radio in radios) {
        expect(radio[0], contains(' disabled'));
      }
    });

    test('needs two segments and a name for an icon-only one', () {
      expect(
        () => StudioButtonSegment<int>(value: 1),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('StudioLevelSlider', () {
    Widget level({ValueChanged<double>? onChanged = _noop}) =>
        StudioLevelSlider(
          title: 'Radius',
          value: 20,
          max: 48,
          divisions: 24,
          onChanged: onChanged,
          formatValue: (v) => '${v.round()} px',
        );

    test(
      'is a native range input with the name, the value and the step',
      () async {
        final html = await renderHtml(level());
        expect(html, contains('type="range"'));
        expect(html, contains('aria-label="Radius"'));
        expect(html, contains('min="0"'));
        expect(html, contains('max="48"'));
        expect(html, contains('step="2"'));
        expect(html, contains('value="20"'));
      },
    );

    test('the screen reader hears the formatted value, kept current', () async {
      final html = await _page(
        StudioLevelSlider(
          title: 'Radius',
          value: 20,
          max: 48,
          onChanged: _noop,
          valueText: _radius.radiusText,
        ),
      );
      expect(html, contains('aria-valuetext="20 px"'));
      expect(
        html,
        contains('data-tca="aria-valuetext:RadiusState.radiusText"'),
      );
    });

    test(
      'the bar sits between the name and the value, never under them',
      () async {
        final html = await renderHtml(level());
        // Name, then the range input, then the value: the grip travels only
        // the input, so at the lowest value it stays after the name.
        final (name, input, value) = (
          html.indexOf('>Radius<'),
          html.indexOf('type="range"'),
          html.indexOf('>20 px<'),
        );
        expect(name, lessThan(input));
        expect(input, lessThan(value));
        final doc = await renderDocument(
          ThorApp(theme: _theme, child: level()),
        );
        final head = headOfPage(doc).replaceAll(' ', '');
        // The name keeps its own room (88 px) and the value its 64 px.
        expect(head, contains('min-width:88px'));
        expect(head, contains('width:64px'));
        // No overlay: the bar is no longer an absolutely placed layer.
        expect(head, isNot(contains('right:80px')));
      },
    );

    test('draws the name left and the formatted value right', () async {
      final html = await renderHtml(level());
      expect(html.indexOf('>Radius<'), lessThan(html.indexOf('>20 px<')));
    });

    test(
      'the fill is the browser\'s own: no script, no class per value',
      () async {
        final head = await _head(level());
        expect(head, contains('::-webkit-slider-thumb'));
        expect(head, contains('::-moz-range-progress'));
        expect(head, contains('appearance: none'));
      },
    );

    test('the name and the value sit beside the bar, not over it', () async {
      final head = await _head(level());
      expect(head, isNot(contains('pointer-events: none')));
      expect(head, isNot(contains('position: absolute')));
    });

    test('without onChanged the bar is disabled', () async {
      final html = await renderHtml(level(onChanged: null));
      expect(html, contains('disabled'));
    });
  });

  group('StudioBench', () {
    test('has no JavaScript: Demo and Code are a radio group', () async {
      final body = await _page(_bench());
      expect(body, isNot(contains('<script')));
      expect(
        RegExp('<input[^>]*name="demo-1-view"').allMatches(body),
        hasLength(2),
      );
      expect(body, contains('value="demo"'));
      expect(body, contains('value="code"'));
      expect(body, contains('aria-label="Live"'));
      expect(body, contains('aria-label="Source"'));
      expect(body, contains('aria-label="View"'));
    });

    test('draws the stage, the code and the panel', () async {
      final body = await _page(_bench());
      expect(body, contains('THE-STAGE'));
      expect(body, contains('THE-CODE'));
      // The bench names itself once: the panel takes its title and text.
      expect(body, contains('<h3'));
      expect(body, contains('Rounded card'));
      expect(body, contains('Pull the radius.'));
      expect(body, contains('aria-label="Rounded card"'));
      expect(body, contains('role="group"'));
      expect(body, contains('Switches'));
      expect(body, contains('Levels'));
      expect(body, contains('Share'));
    });

    test('the page switches panes with :has() on the checked radio', () async {
      final head = await _head(_bench());
      expect(
        head,
        contains(
          ':where(:root:has(input[name="demo-1-view"]'
          '[value="code"]:checked))',
        ),
      );
      expect(
        head,
        contains(
          ':where(:root:has(input[name="demo-1-view"]'
          '[value="demo"]:checked))',
        ),
      );
    });

    test('the panel sits beside the stage in a row', () async {
      final head = await _head(_bench());
      expect(head, contains('flex-direction: row'));
    });

    test('the panel goes beside the stage by the bench\'s own width', () async {
      final doc = await renderDocument(ThorApp(theme: _theme, child: _bench()));
      final head = headOfPage(doc);
      final body = bodyOfPage(doc);
      expect(head, contains('@container (min-width: 640px)'));
      // The flex row is under the container query, not under a viewport one.
      final row = RegExp(r'@media[^{]*\{[^{}]*\{[^}]*flex-direction: row');
      expect(row.hasMatch(head), isFalse);
      // The scope is a size container and wraps the group.
      expect(head, contains('container-type: inline-size'));
      expect(
        body,
        startsWith('<body><div class="t-studio-bench" data-thor="LayoutScope"'),
      );
    });

    test(
      'the stage sizes to its demo and scrolls with a stacked panel',
      () async {
        final head = await _head(_bench());
        // Stacked (a phone): compact least height, in the page's flow.
        expect(head, contains('min-height: 148px'));
        expect(head, isNot(contains('position: sticky')));
        expect(head, isNot(contains('max-height: 520px')));
        // Side by side: the roomy least height, no cap, a fixed 288px panel.
        final wide = RegExp(
          r'@container \(min-width: 640px\)\{.*\}',
          dotAll: true,
        ).firstMatch(head)![0]!;
        expect(wide, contains('min-height: 240px'));
        expect(wide, contains('max-height: 100%'));
        expect(wide, contains('width: 288px'));
        // The pane no longer forces a height: the card's least height does.
        expect(head, isNot(contains('min-height: 360px')));
      },
    );

    test('a wide bench bleeds past its column from xl up', () async {
      final narrow = await _head(_bench());
      expect(narrow, isNot(contains('margin: 0px -96px')));
      final wide = await _head(
        const StudioBench(
          id: 'w',
          wide: true,
          stage: Text('s'),
          code: Text('c'),
        ),
      );
      expect(wide, contains('-96px'));
      final custom = await _head(
        const StudioBench(
          id: 'w',
          wide: true,
          theme: StudioBenchThemeData(wideBleed: 40, sideBySideFrom: 600),
          stage: Text('s'),
          code: Text('c'),
          panel: Text('p'),
        ),
      );
      expect(custom, contains('-40px'));
      expect(custom, contains('@container (min-width: 600px)'));
    });

    test('replay is a checkbox and draws the stage twice', () async {
      final without = await _page(_bench());
      final withReplay = await _page(_bench(replayLabel: 'Replay'));
      expect(without, isNot(contains('type="checkbox"')));
      expect(RegExp('THE-STAGE').allMatches(without), hasLength(1));
      expect(withReplay, contains('aria-label="Replay"'));
      expect(
        RegExp(
          '<input[^>]*name="demo-1-replay"[^>]*type="checkbox"|'
          '<input[^>]*type="checkbox"[^>]*name="demo-1-replay"',
        ).allMatches(withReplay),
        hasLength(1),
      );
      expect(RegExp('THE-STAGE').allMatches(withReplay), hasLength(2));
    });

    test(
      'a replayed stage enters with a starting style and stays under 200 ms',
      () async {
        final head = await _head(_bench(replayLabel: 'Replay'));
        expect(head, contains('@starting-style'));
        expect(head, contains('transition-duration: 200ms'));
      },
    );

    test('the id must be a plain identifier (asserted when built)', () async {
      await expectLater(_page(_bench(id: 'bad id"]')), throwsA(anything));
    });

    test(
      'without an id the page names each bench, the same every time',
      () async {
        Widget two() => const Column(
          children: [
            StudioBench(stage: Text('S1'), code: Text('C1')),
            StudioBench(stage: Text('S2'), code: Text('C2')),
          ],
        );
        final first = await _page(two());
        expect(first, contains('name="t-bench1-view"'));
        expect(first, contains('name="t-bench2-view"'));
        expect(first, isNot(contains('name="t-bench3-view"')));
        expect(await _page(two()), first);
        expect(await _head(two()), contains('input[name="t-bench1-view"]'));
      },
    );

    test('a stage alone has no panel and no replay', () async {
      final body = await _page(
        const StudioBench(id: 'solo', stage: Text('S'), code: Text('C')),
      );
      expect(body, isNot(contains('<h3')));
      expect(body, isNot(contains('type="checkbox"')));
    });
  });

  group('contrast of the bench colors, light and dark', () {
    double luminance(Color c) {
      double lin(int v) {
        final s = v / 255;
        return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4) * 1.0;
      }

      final argb = c.value;
      return 0.2126 * lin((argb >> 16) & 0xFF) +
          0.7152 * lin((argb >> 8) & 0xFF) +
          0.0722 * lin(argb & 0xFF);
    }

    double ratio(Color a, Color b) {
      final (l1, l2) = (luminance(a), luminance(b));
      return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05);
    }

    final bench = StudioBenchThemeData.resolve(StudioTheme.light());
    final seg = StudioSegmentedButtonThemeData.resolve(StudioTheme.light());
    final level = StudioSliderThemeData.resolve(StudioTheme.light());
    final chip = StudioChipThemeData.resolve(StudioTheme.light());
    final cs = StudioTheme.colorScheme(Brightness.light);

    final text = <(String, Color, Color)>[
      ('idle segment', seg.labelColor, seg.trackColor),
      ('chosen segment', seg.selectedLabelColor, seg.selectedColor),
      ('hovered segment on the groove', cs.onSurface, seg.trackColor),
      ('level name on the track', level.nameColor, level.trackColor),
      ('level name on the fill', level.nameColor, level.fillColor),
      ('level value on the track', level.valueColor, level.trackColor),
      ('level value on the fill', level.valueColor, level.fillColor),
      ('row label on the panel', cs.onSurfaceVariant!, bench.panelColor),
      ('selected chip', chip.selectedLabelColor, chip.selectedColor),
      ('chip', chip.labelColor, chip.color),
      for (final (name, tone) in [
        ('info', chip.info),
        ('ok', chip.ok),
        ('warn', chip.warn),
        ('danger', chip.danger),
      ])
        ('$name badge', tone.foreground, tone.background),
    ];

    final graphics = <(String, Color, Color)>[
      ('level grip on the fill', level.handleColor, level.fillColor),
      ('level grip on the track', level.handleColor, level.trackColor),
      // The accent thumb stands out of its groove.
      ('chosen segment on the groove', seg.selectedColor, seg.trackColor),
      for (final (name, bg) in [
        ('stage', bench.stageColor),
        ('panel', bench.panelColor),
        ('groove', seg.trackColor),
        ('level track', level.trackColor),
        ('level fill', level.fillColor),
      ])
        ('focus ring on the $name', seg.focusColor, bg),
    ];

    for (final dark in [false, true]) {
      Color side(Color c) =>
          dark ? (c as ColorToken).dark : (c as ColorToken).light;
      final mode = dark ? 'dark' : 'light';

      test('every text pair meets 4.5:1 in the $mode theme', () {
        for (final (name, fg, bg) in text) {
          expect(
            ratio(side(fg), side(bg)),
            greaterThanOrEqualTo(4.5),
            reason: name,
          );
        }
      });

      test(
        'the grip, the focus ring and the chosen segment meet 3:1 in $mode',
        () {
          for (final (name, fg, bg) in graphics) {
            expect(
              ratio(side(fg), side(bg)),
              greaterThanOrEqualTo(3),
              reason: name,
            );
          }
        },
      );
    }
  });
}
