import 'dart:async';

// The Flutter-shaped inputs: StudioSegmentedControl (SegmentedButton),
// StudioLevelSlider (Slider), their themes, and the old shapes still working.
import 'package:test/test.dart';
import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

enum _Fill { soft, solid, ghost }

// The member list thor generates for [_FillState], by hand.
abstract class _FillMembers extends ThorState {
  @override
  String get $type => 'FillState';

  @override
  List<ThorMember> get $members {
    final s = this as _FillState;
    return [
      ThorMember(
        'setFill',
        s.setFill,
        arity: 1,
        call: (a) => s.setFill(
          a == null || a.isEmpty ? <_Fill>{} : {_Fill.values.byName(a)},
        ),
      ),
      ThorMember(
        'setRadius',
        s.setRadius,
        arity: 1,
        call: (a) => s.setRadius(double.parse(a!)),
      ),
      ThorMember(
        'setEnd',
        s.setEnd,
        arity: 1,
        call: (a) => s.setEnd(double.parse(a!)),
      ),
    ];
  }
}

class _FillState extends _FillMembers {
  final fill = state(_Fill.soft);
  void setFill(Set<_Fill> v) => fill.value = v.first;
  void setRadius(double v) {}
  void setEnd(double v) {}
}

final _state = _FillState();

Future<String> _html(Widget child) async => bodyOfPage(
  await renderDocument(ThorApp(theme: StudioTheme.light(), child: child)),
);

Future<String> _head(Widget child) async => headOfPage(
  await renderDocument(ThorApp(theme: StudioTheme.light(), child: child)),
);

Widget _segments({
  Set<_Fill> selected = const {_Fill.solid},
  ValueChanged<Set<_Fill>>? onSelectionChanged,
  bool pass = true,
  EdgeInsets? expandedInsets,
  bool emptyAllowed = false,
}) => pass
    ? StudioSegmentedControl<_Fill>(
        semanticLabel: 'Fill',
        selected: selected,
        onSelectionChanged: onSelectionChanged,
        emptySelectionAllowed: emptyAllowed,
        expandedInsets: expandedInsets,
        segments: const [
          StudioButtonSegment(value: _Fill.soft, label: Text('Soft')),
          StudioButtonSegment(value: _Fill.solid, label: Text('Solid')),
          StudioButtonSegment(value: _Fill.ghost, label: Text('Ghost')),
        ],
      )
    : StudioSegmentedControl<_Fill>(
        semanticLabel: 'Fill',
        selected: selected,
        emptySelectionAllowed: emptyAllowed,
        segments: const [
          StudioButtonSegment(value: _Fill.soft, label: Text('Soft')),
          StudioButtonSegment(value: _Fill.solid, label: Text('Solid')),
        ],
      );

void main() {
  setUpAll(initializeThorTests);

  group('StudioSegmentedControl (SegmentedButton)', () {
    test(
      'selected is the checked radio; the group is named by semanticLabel',
      () async {
        final html = await _html(_segments(onSelectionChanged: _state.setFill));
        expect(html, contains('role="radiogroup"'));
        expect(html, contains('aria-label="Fill"'));
        final radios = RegExp('<input[^>]*type="radio"[^>]*>').allMatches(html);
        expect(radios, hasLength(3));
        final checked = [
          for (final m in radios)
            if (m[0]!.contains(' checked')) m[0]!,
        ];
        expect(checked.single, contains('value="solid"'));
        // A segment with a Text label is named by it.
        expect(html, contains('aria-label="Ghost"'));
      },
    );

    test('onSelectionChanged is a ThorState method taking a Set', () async {
      final html = await _html(_segments(onSelectionChanged: _state.setFill));
      expect(html, contains('FillState.setFill'));
      // Enabled.
      expect(html, isNot(contains(' disabled')));
    });

    test('onSelectionChanged: null disables every radio', () async {
      final html = await _html(_segments(onSelectionChanged: null));
      final radios = RegExp('<input[^>]*type="radio"[^>]*>').allMatches(html);
      expect(radios, hasLength(3));
      for (final radio in radios) {
        expect(radio[0], contains(' disabled'));
      }
      expect(html, contains('aria-disabled="true"'));
    });

    test('left out, the control is native: not disabled, no handler', () async {
      final html = await _html(_segments(pass: false));
      expect(html, isNot(contains(' disabled')));
      expect(html, isNot(contains('data-t-on')));
    });

    test('an empty selection draws no thumb (emptySelectionAllowed)', () async {
      final html = await _html(
        _segments(selected: const {}, emptyAllowed: true),
      );
      expect(RegExp(r'\schecked[\s>=/]').allMatches(html), isEmpty);
      final head = await _head(
        _segments(selected: const {}, emptyAllowed: true),
      );
      expect(head, contains(':not(:has(:checked))::before'));
    });

    test(
      'the layout is CSS only: a wrapping row, no text-width estimate',
      () async {
        final head = await _head(_segments());
        expect(head, contains('flex-wrap: wrap'));
        expect(
          head,
          contains('flex-grow: 1; flex-shrink: 1; flex-basis: max-content'),
        );
        expect(head, contains('width: fit-content'));
        // The thumb is anchored to the checked cell.
        expect(head, contains('anchor-size(width)'));
        expect(head, isNot(contains('repeat(3, minmax(0, 1fr))')));
        expect(head, isNot(contains('@container (max-width')));
      },
    );

    test('a theme parameter overrides the installed one', () async {
      final head = await _head(
        const StudioSegmentedControl<int>(
          semanticLabel: 'x',
          selected: {0},
          theme: StudioSegmentedButtonThemeData(height: 57),
          segments: [
            StudioButtonSegment(value: 0, label: Text('a')),
            StudioButtonSegment(value: 1, label: Text('b')),
          ],
        ),
      );
      expect(head, contains('min-height: 53px'));
    });

    test('expandedInsets fills the line, with the insets around it', () async {
      final head = await _head(
        _segments(expandedInsets: const EdgeInsets.symmetric(horizontal: 8)),
      );
      expect(head, contains('width: 100%'));
      expect(head, contains('margin: 0px 8px'));
    });

    test('a segment with no Text label and no tooltip fails (THOR-R038)', () {
      expect(
        () => _head(
          const StudioSegmentedControl<int>(
            semanticLabel: 'x',
            selected: {0},
            segments: [
              StudioButtonSegment(value: 0, label: Icon(Icons.list)),
              StudioButtonSegment(value: 1, label: Text('b')),
            ],
          ),
        ),
        throwsA(predicate((e) => e.toString().contains('THOR-R038'))),
      );
    });

    test('each segment names its radio: tooltip, Text, Semantics', () async {
      final html = await _html(
        const StudioSegmentedControl<int>(
          semanticLabel: 'x',
          selected: {0},
          segments: [
            StudioButtonSegment(value: 0, label: Text('Plain')),
            StudioButtonSegment(
              value: 1,
              label: Semantics(label: 'Grid', child: Icon(Icons.list)),
            ),
            StudioButtonSegment(
              value: 2,
              label: Icon(Icons.list),
              tooltip: 'List',
            ),
          ],
        ),
      );
      final radios = RegExp(
        r'<input[^>]*type="radio"[^>]*>',
      ).allMatches(html).map((m) => m[0]!).toList();
      expect(radios, hasLength(3));
      expect(radios[0], contains('aria-label="Plain"'));
      expect(radios[1], contains('aria-label="Grid"'));
      expect(radios[2], contains('aria-label="List"'));
    });

    test('more than one selected value needs multiSelectionEnabled', () {
      expect(
        () => StudioSegmentedControl<_Fill>(
          segments: const [
            StudioButtonSegment(value: _Fill.soft, label: Text('a')),
            StudioButtonSegment(value: _Fill.solid, label: Text('b')),
          ],
          multiSelectionEnabled: true,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test(
      'a segment needs a label or an icon, and a tooltip without a label',
      () {
        expect(
          () => StudioButtonSegment<int>(value: 1),
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => StudioButtonSegment<int>(
            value: 1,
            icon: const Icon(StudioIcons.x),
          ),
          throwsA(isA<AssertionError>()),
        );
      },
    );

    test('an icon-only segment is named by its tooltip', () async {
      final html = await _html(
        const StudioSegmentedControl<int>(
          selected: {0},
          segments: [
            StudioButtonSegment(
              value: 0,
              icon: Icon(StudioIcons.x, size: 16),
              tooltip: 'Close',
            ),
            StudioButtonSegment(
              value: 1,
              icon: Icon(StudioIcons.menu, size: 16),
              tooltip: 'Menu',
            ),
          ],
        ),
      );
      expect(html, contains('aria-label="Close"'));
      expect(html, contains('aria-label="Menu"'));
    });

    test('the theme is a StudioSegmentedButtonThemeData', () async {
      final base = StudioTheme.light();
      final theme = base.copyWith(
        extensions: [
          ...base.extensions,
          const StudioSegmentedButtonThemeData(height: 48),
        ],
      );
      final head = headOfPage(
        await renderDocument(ThorApp(theme: theme, child: _segments())),
      );
      expect(head, contains('min-height: 44px'));
    });
  });

  group('StudioSegmentedButtonThemeData', () {
    test('resolves override, installed, then defaults', () {
      final base = StudioTheme.light();
      expect(StudioSegmentedButtonThemeData.resolve(base).height, 36);
      final installed = base.copyWith(
        extensions: [
          ...base.extensions,
          const StudioSegmentedButtonThemeData(height: 40),
        ],
      );
      expect(StudioSegmentedButtonThemeData.resolve(installed).height, 40);
      expect(
        StudioSegmentedButtonThemeData.resolve(
          installed,
          const StudioSegmentedButtonThemeData(height: 44),
        ).height,
        44,
      );
    });

    test('has copyWith, == and hashCode', () {
      const a = StudioSegmentedButtonThemeData(height: 1);
      expect(a.copyWith(radius: 3).radius, 3);
      expect(a.copyWith(radius: 3).height, 1);
      expect(a, const StudioSegmentedButtonThemeData(height: 1));
      expect(
        a.hashCode,
        const StudioSegmentedButtonThemeData(height: 1).hashCode,
      );
      expect(a == const StudioSegmentedButtonThemeData(height: 2), isFalse);
    });
  });

  group('StudioLevelSlider (Slider)', () {
    test(
      'title is the visible name, label the value text, semanticLabel the name',
      () async {
        final html = await _html(
          StudioLevelSlider(
            title: 'Radius',
            label: '16 px',
            semanticLabel: 'Corner radius',
            value: 16,
            max: 48,
            onChanged: _state.setRadius,
          ),
        );
        expect(
          html.indexOf('>Radius<'),
          lessThan(html.indexOf('type="range"')),
        );
        expect(html, contains('>16 px<'));
        expect(html, contains('aria-label="Corner radius"'));
        expect(html, contains('title="16 px"'));
      },
    );

    test(
      'onChanged and onChangeEnd are forwarded to the range input',
      () async {
        final html = await _html(
          StudioLevelSlider(
            title: 'Radius',
            value: 16,
            max: 48,
            divisions: 12,
            onChanged: _state.setRadius,
            onChangeEnd: _state.setEnd,
          ),
        );
        expect(html, contains('FillState.setRadius'));
        expect(html, contains('FillState.setEnd'));
        expect(html, contains('step="4"'));
      },
    );

    test('without onChanged the bar is disabled and dimmed', () async {
      final html = await _html(
        const StudioLevelSlider(title: 'Radius', value: 1, onChanged: null),
      );
      expect(html, contains('disabled'));
      final head = await _head(
        const StudioLevelSlider(title: 'Radius', value: 1, onChanged: null),
      );
      expect(head, contains('opacity: 0.38'));
    });

    test('the title is the name and the label the value text', () async {
      final html = await _html(
        const StudioLevelSlider(
          title: 'Radius',
          label: '1 px',
          value: 1,
          onChanged: _noop,
        ),
      );
      expect(html.indexOf('>Radius<'), lessThan(html.indexOf('type="range"')));
      expect(html.indexOf('>1 px<'), greaterThan(html.indexOf('type="range"')));
      expect(html, contains('aria-label="Radius"'));
    });

    test('a theme parameter overrides the installed one', () async {
      final head = await _head(
        const StudioLevelSlider(
          title: 'R',
          value: 0,
          onChanged: _noop,
          theme: StudioSliderThemeData(height: 61),
        ),
      );
      expect(head, contains('height: 61px'));
    });

    test('needs a name', () {
      expect(
        () => StudioLevelSlider(value: 0, onChanged: _noop),
        throwsA(isA<AssertionError>()),
      );
    });

    test('the theme is a StudioSliderThemeData', () async {
      final base = StudioTheme.light();
      final theme = base.copyWith(
        extensions: [
          ...base.extensions,
          const StudioSliderThemeData(height: 52),
        ],
      );
      final head = headOfPage(
        await renderDocument(
          ThorApp(
            theme: theme,
            child: const StudioLevelSlider(
              title: 'R',
              value: 0,
              onChanged: _noop,
            ),
          ),
        ),
      );
      expect(head, contains('height: 52px'));
    });

    test('StudioSliderThemeData resolves and compares', () {
      final base = StudioTheme.light();
      expect(StudioSliderThemeData.resolve(base).height, 44);
      expect(
        StudioSliderThemeData.resolve(
          base,
          const StudioSliderThemeData(nameWidth: 100),
        ).nameWidth,
        100,
      );
      const a = StudioSliderThemeData(height: 1);
      expect(a, const StudioSliderThemeData(height: 1));
      expect(a.copyWith(height: 2).height, 2);
    });
  });
}

void _noop(double _) {}
