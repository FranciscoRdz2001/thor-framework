import 'dart:math' as math;

import 'package:thor_style/errors.dart' show thorError;
import 'package:thor_ui/thor_ui.dart';

import '../../theme/component_themes/studio_segmented_button_theme.dart';
import 'state_styles.dart';

/// What a [StudioSegmentedControl] with no `onSelectionChanged` holds: the
/// native radios keep the choice and the page's CSS reads it, so it is not
/// disabled (an explicit `null` is).
void _omittedSelection(Set<Object?> _) {}

void _ignore(Object? _) {}

/// One choice of a [StudioSegmentedControl] (Flutter's `ButtonSegment`): a
/// [value], shown as a [label], an [icon] or both.
///
/// ```dart
/// StudioButtonSegment(value: Fill.soft, label: Text('Soft'))
/// StudioButtonSegment(value: View.code, icon: Icon(StudioIcons.code), tooltip: 'Code')
/// ```
///
/// `// web:` Flutter's `ButtonSegment.enabled` has no counterpart: the
/// segments are native radios that the control disables as a group. Give an
/// `Icon` its own `size` (16 fits the groove): thor's `Icon` has no
/// `IconTheme` to size it from. [tooltip] is the segment's accessible name
/// (`aria-label`); a segment with a `Text` label (or a `Semantics(label:)`,
/// an `Icon(semanticLabel:)`) is named by it. A segment with neither (an
/// unlabeled `Icon`, no [tooltip]) fails with THOR-R038 in debug.
class StudioButtonSegment<T> {
  /// A segment that stands for [value]. Without a [label] (icon only) give a
  /// [tooltip]: it is the segment's accessible name.
  const StudioButtonSegment({
    required this.value,
    Widget? icon,
    Widget? label,
    this.tooltip,
  }) : _icon = icon,
       _label = label,
       assert(
         label != null || icon != null,
         'A segment needs a label or an icon.',
       ),
       assert(
         label != null || tooltip != null,
         'An icon-only segment needs a tooltip.',
       );

  /// What the control's selection holds when this segment is chosen.
  final T value;

  /// The accessible name; defaults to the text of a `Text` [label].
  final String? tooltip;

  final Widget? _icon;
  final Widget? _label;

  /// The icon, before the label (alone, an icon-only segment).
  Widget? get icon => _icon;

  /// The visible text (usually a `Text`).
  Widget? get label => _label;
}

/// A pill-shaped control that picks one of a few values (Flutter's
/// `SegmentedButton`): a groove with the chosen segment raised in it.
///
/// ```dart
/// StudioSegmentedControl<Brightness>(
///   semanticLabel: 'Theme',
///   segments: const [
///     StudioButtonSegment(value: Brightness.light, label: Text('Light')),
///     StudioButtonSegment(value: Brightness.dark, label: Text('Dark')),
///   ],
///   selected: const {Brightness.light},
///   onSelectionChanged: demo.setBrightness, // a ThorState method: void (Set<Brightness>)
/// )
/// ```
///
/// Like Flutter's `SegmentedButton`: [selected] is the set of chosen values
/// (one), [onSelectionChanged] receives the set the person picks, and with
/// `onSelectionChanged: null` the control is disabled. The handler is a
/// method of a `ThorState`; its parameter is a `Set` of the enum, `String`,
/// `int` or `bool` the segment stands for.
///
/// The chosen segment is a thumb that slides to the new one (200 ms, the
/// studio's move curve; none under `prefers-reduced-motion`). The theme is a
/// [StudioSegmentedButtonThemeData].
///
/// `// web:` the segments are a native radio group, no JavaScript needed:
/// every segment holds a real `<input type=radio>` laid over its label, so
/// the arrow keys move the choice, Tab enters and leaves the group once, and
/// screen readers say "Light, radio button, 1 of 2". Because radios keep one
/// choice, [multiSelectionEnabled] is not supported and [emptySelectionAllowed]
/// only means that [selected] may start empty (a radio cannot be unchecked).
/// A control with no `onSelectionChanged` argument at all is not disabled:
/// the browser keeps the choice and the page's CSS reads it (the bench's
/// Demo/Code toggle). The browser sends one value, so the engine hands the
/// handler a set holding it.
///
/// `// web:` the layout is CSS only: a wrapping row (`flex-wrap`) whose cells
/// share the line by their content (`flex: 1 1 max-content`; the whole line
/// when [expandedInsets] is set). When the line is narrower than the labels
/// the cells wrap onto a second row and a label wraps inside its cell (a word
/// breaks only when it alone is wider than the cell), so nothing is ever
/// clipped. The thumb is the groove's `::before`, put over the checked cell
/// with CSS anchor positioning (`anchor-name` on `:has(:checked)`, `anchor()`
/// and `anchor-size()`), so it follows the cell through any wrapping and
/// nothing is measured in Dart. Without anchor positioning (`@supports not
/// (anchor-name: --x)`) there is no thumb: the checked cell paints the
/// selected background.
class StudioSegmentedControl<T> extends StatelessWidget
    implements ThorElementWidget {
  /// A control over [segments] whose chosen one is in [selected].
  const StudioSegmentedControl({
    super.key,
    required this.segments,
    this.selected,
    this.onSelectionChanged = _omittedSelection,
    this.multiSelectionEnabled = false,
    this.emptySelectionAllowed = false,
    this.expandedInsets,
    this.semanticLabel,
    this.name,
    this.theme,
  }) : assert(
         !multiSelectionEnabled,
         'Radios keep one choice: multiSelectionEnabled is not supported.',
       );

  /// The choices, left to right.
  final List<StudioButtonSegment<T>> segments;

  /// The chosen values when the page is drawn: one, or none with
  /// [emptySelectionAllowed].
  final Set<T>? selected;

  /// Called with the set the person picks (a `ThorState` method taking a
  /// `Set<T>`); `null` disables the control; left out, the browser just
  /// keeps the choice.
  final ValueChanged<Set<T>>? onSelectionChanged;

  /// Not supported (see the class): always false.
  final bool multiSelectionEnabled;

  /// Whether [selected] may be empty.
  final bool emptySelectionAllowed;

  /// Fills the width it is given, the cells sharing it equally, with these
  /// insets around the control, instead of being as wide as its cells need.
  /// `StudioBenchRow` sets it for a control that sits on its own line.
  final EdgeInsets? expandedInsets;

  /// The group's accessible name (`aria-label`): what the segments choose.
  final String? semanticLabel;

  /// The native group name; set it when CSS elsewhere on the page reads the
  /// choice (`:root:has(input[name="…"]:checked)`) or a form submits it.
  final String? name;

  /// Overrides the segmented button theme (otherwise the nearest, or the
  /// default).
  final StudioSegmentedButtonThemeData? theme;

  /// The same control filling its line, with [insets] around it (what a
  /// `StudioBenchRow` does for a control that sits on its own line).
  StudioSegmentedControl<T> withExpandedInsets(EdgeInsets insets) =>
      StudioSegmentedControl<T>(
        key: key,
        segments: segments,
        selected: selected,
        onSelectionChanged: onSelectionChanged,
        multiSelectionEnabled: multiSelectionEnabled,
        emptySelectionAllowed: emptySelectionAllowed,
        expandedInsets: insets,
        semanticLabel: semanticLabel,
        name: name,
        theme: theme,
      );

  @override
  Widget build(BuildContext context) {
    assert(segments.length > 1, 'A segmented control needs two or more.');
    final t = StudioSegmentedButtonThemeData.of(context, theme);
    final chosen = selected ?? <T>{};
    assert(
      chosen.isNotEmpty || emptySelectionAllowed || selected == null,
      'An empty selection needs emptySelectionAllowed.',
    );
    // The handler the radios run: the set handler, or a no-op when it was
    // left out (the browser keeps the choice).
    final omitted = identical(onSelectionChanged, _omittedSelection);
    final disabled = !omitted && onSelectionChanged == null;
    final setHandler = !omitted && !disabled ? onSelectionChanged : null;
    final expanded = expandedInsets != null;
    return RadioGroup<T>(
      groupValue: chosen.isEmpty ? null : chosen.first,
      name: name,
      onChanged: disabled ? null : _ignore,
      onSelectionChanged: setHandler,
      child: StateStyles(
        attributes: {
          'role': 'radiogroup',
          'aria-label': ?semanticLabel,
          if (disabled) 'aria-disabled': 'true',
        },
        style: StyleProps(
          padding: t.padding,
          margin: expandedInsets,
          // Never wider than the space it is given: the cells share it.
          maxWidth: expanded ? null : 100.percent,
          widthFactor: expanded ? 1 : null,
          opacity: disabled ? t.disabledOpacity : null,
          decoration: BoxDecoration(
            color: t.trackColor,
            borderRadius: BorderRadius.circular(_grooveRadius(t)),
          ),
        ),
        // web: the thumb is the cells' `::before` (see [_thumbStates]).
        child: StateStyles(
          style: StyleProps(
            position: const BoxPosition.relative(),
            // web: as wide as its widest cell, not the stage it sits in; or
            // the whole line, the cells sharing it (`expandedInsets`).
            widthLength: expanded ? 100.percent : Length.fitContent,
          ),
          states: _thumbStates(t),
          child: Wrap(
            children: [
              for (final segment in segments)
                _SegmentedControlSegment<T>(
                  segment: segment,
                  theme: t,
                  enabled: !disabled,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// web: a pill is `radius: 999`, which on a groove that wraps onto several
// rows (a narrow line) is a blob: the corners stop at half the one-row
// height, so a single row is still a pill and a taller groove is a rounded
// box. No breakpoint: the cap is the height the theme declares.
double _grooveRadius(StudioSegmentedButtonThemeResolved t) =>
    math.min(t.radius, t.height / 2);

double _cellRadius(StudioSegmentedButtonThemeResolved t) =>
    math.min(t.radius, (t.height - t.padding.vertical) / 2);

/// The thumb: the groove's `::before`, put over the checked cell by CSS anchor
/// positioning (the checked cell is the `anchor-name`, the thumb takes its
/// edges and size with `anchor()` / `anchor-size()`), so it follows the cell
/// wherever the row wraps it and measures nothing in Dart.
///
/// Where anchor positioning is not supported there is no thumb: the checked
/// cell paints the selected background itself (see [_fallbackStates]).
List<StateStyle> _thumbStates(StudioSegmentedButtonThemeResolved t) {
  final thumb = BoxDecoration(
    color: t.selectedColor,
    borderRadius: BorderRadius.circular(_cellRadius(t)),
    boxShadow: t.shadows,
  );
  Transition move(String property) =>
      Transition(property, t.thumbDuration, curve: t.curve);
  const supported = '(anchor-name: --t-seg)';
  CssCondition ifAnchors(String selector) =>
      CssCondition.supports(supported, CssCondition.selector(selector));
  return [
    // The anchor's name is scoped to this control: two controls on a page
    // never borrow each other's checked cell.
    StateStyle(
      ifAnchors(''),
      // ignore: thor_lints/avoid_raw_css
      const StyleProps(raw: {'anchor-scope': '--t-seg'}),
    ),
    StateStyle(
      ifAnchors(' > :has(:checked)'),
      // ignore: thor_lints/avoid_raw_css
      const StyleProps(raw: {'anchor-name': '--t-seg'}),
    ),
    StateStyle(
      ifAnchors('::before'),
      StyleProps(
        position: const BoxPosition.absolute(),
        decoration: thumb,
        ignorePointer: true,
        // The transition lives on the pseudo-element, which a `Styled`
        // duration never reaches.
        transition: [
          move(CssProperty.left),
          move(CssProperty.top),
          move(CssProperty.width),
          move(CssProperty.height),
          move(CssProperty.opacity),
        ],
        // web: `content` and the anchor properties have no typed form yet.
        // ignore: thor_lints/avoid_raw_css
        raw: {
          'content': '""',
          'position-anchor': '--t-seg',
          'left': 'anchor(left)',
          'top': 'anchor(top)',
          'width': 'anchor-size(width)',
          'height': 'anchor-size(height)',
        },
      ),
    ),
    // No choice (an empty selection): no thumb.
    StateStyle(
      ifAnchors(':not(:has(:checked))::before'),
      const StyleProps(opacity: 0),
    ),
    // Under `prefers-reduced-motion` the thumb jumps (the label's color
    // still eases: that is not movement).
    StateStyle(
      CssCondition.both(
        CssCondition.reducedMotion,
        const CssCondition.selector('::before'),
      ),
      const StyleProps(transition: []),
    ),
  ];
}

/// Without anchor positioning there is no sliding thumb: the checked cell is
/// the selected background (no movement, nothing to measure). The labels
/// still wrap inside their cells.
List<StateStyle> _fallbackStates(StudioSegmentedButtonThemeResolved t) {
  return [
    StateStyle(
      CssCondition.supports(
        'not (anchor-name: --t-seg)',
        const CssCondition.selector(':has(:checked)'),
      ),
      StyleProps(
        decoration: BoxDecoration(
          color: t.selectedColor,
          borderRadius: BorderRadius.circular(_cellRadius(t)),
          boxShadow: t.shadows,
        ),
      ),
    ),
  ];
}

/// The chosen look is a rule on the segment itself (`:has(:checked)`); the
/// radio lies over it, invisible, so the whole segment is the target.
class _SegmentedControlSegment<T> extends StatelessWidget
    implements ThorElementWidget {
  /// A segment of [segment] drawn with [theme].
  const _SegmentedControlSegment({
    required this.segment,
    required this.theme,
    required this.enabled,
  });

  /// What the segment shows and stands for.
  final StudioButtonSegment<T> segment;

  /// The segmented button theme.
  final StudioSegmentedButtonThemeResolved theme;

  /// Whether the segments take clicks.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_cellRadius(theme));
    final idle = Theme.of(
      context,
    ).textTheme.labelLarge.copyWith(color: theme.labelColor);
    // Under a state only the color moves: size and weight stay put.
    final chosen = TextStyle(color: theme.selectedLabelColor);
    // A segment under the pointer brightens to the ink, not to the chosen
    // label: that one is drawn on the accent thumb.
    final hovered = TextStyle(color: Theme.of(context).colorScheme.onSurface);
    final label = segment.label;
    // web: the radio lies over the cell, outside any `<label>`, so its
    // name is a string: the tooltip, else what the label says.
    final name = segment.tooltip ?? _nameOf(label);
    assert(() {
      if (name == null) {
        throw StateError(
          thorError(
            'THOR-R038',
            'a segment of `StudioSegmentedControl` has no accessible name: '
                'its label is not a `Text` (nor a `Semantics(label:)` or an '
                '`Icon(semanticLabel:)`) and it has no `tooltip`, so the '
                'radio would be announced without a name. Give the segment a '
                '`tooltip: \'Name\'` (or a `Text` label).',
          ),
        );
      }
      return true;
    }());
    return StateStyles(
      duration: theme.duration,
      curve: theme.curve,
      style: StyleProps(
        padding: theme.segmentPadding,
        // A least height, not a height: a label that wraps grows its cell.
        minHeight: Length.px(theme.height - theme.padding.vertical),
        minWidth: const Length.px(0),
        // Above the thumb, which is the groove's first child.
        zIndex: 1,
        // web: the cells share the row by their content and wrap onto the
        // next row when the line is narrower: `flex: 1 1 max-content`.
        flex: 1,
        flexShrink: 1,
        flexBasis: Length.maxContent,
        overflowX: Overflow.hidden,
        textStyle: idle,
        decoration: BoxDecoration(borderRadius: radius),
      ),
      states: [
        // The pointer says "this one" without changing the choice.
        if (enabled)
          StateStyle.selector(
            ':hover:not(:has(:checked))',
            StyleProps(textStyle: hovered),
          ),
        // The thumb is behind it: only the label changes.
        StateStyle.selector(':has(:checked)', StyleProps(textStyle: chosen)),
        ..._fallbackStates(theme),
        if (enabled)
          StateStyle.selector(
            ':has(:active)',
            StyleProps(scale: theme.pressScale),
          ),
        StateStyle.selector(
          ':has(:focus-visible)',
          StyleProps(
            outline: BorderSide(color: theme.focusColor, width: 2),
            outlineOffset: 2,
          ),
        ),
      ],
      child: Stack(
        alignment: Alignment.center,
        children: [
          // A label longer than its cell wraps inside it (the cell grows, and
          // the thumb with it: they are one row of equal cells). Never clipped
          // and never drawn over its neighbors.
          Styled(
            style: StyleProps(maxWidth: 100.percent),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: theme.iconGap,
              children: [
                ?segment.icon,
                if (label != null)
                  Flexible(
                    child: Styled(
                      // web: `overflow-wrap` and `text-wrap` have no typed
                      // form yet. `anywhere` breaks a word only when it alone
                      // is wider than the cell, so nothing is ever cut.
                      style: const StyleProps(
                        minWidth: Length.zero,
                        overflowWrap: OverflowWrap.anywhere,
                        textAlign: TextAlign.center,
                        textWrap: TextWrap.balance,
                      ),
                      child: label,
                    ),
                  ),
              ],
            ),
          ),
          Positioned.fill(
            child: MouseRegion(
              cursor: enabled
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.forbidden,
              child: StateStyles(
                style: const StyleProps(
                  widthFactor: 1,
                  heightFactor: 1,
                  opacity: 0,
                ),
                child: Radio<T>(
                  value: segment.value,
                  stateLayer: false,
                  semanticLabel: name,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What [label] says to a screen reader: a `Text`'s text, a
/// `Semantics(label:)` or an `Icon(semanticLabel:)`; null for anything
/// else.
String? _nameOf(Widget? label) => switch (label) {
  Text(:final data?) => data,
  Text(:final textSpan) => _plainText(textSpan),
  Semantics(label: final String label) when label.isNotEmpty => label,
  Icon(semanticLabel: final String label) when label.isNotEmpty => label,
  _ => null,
};

/// The text of a `Text.rich` span tree (Flutter's `toPlainText()`, without
/// the `WidgetSpan`s), or null when it has none.
String? _plainText(InlineSpan? span) {
  if (span is! TextSpan) return null;
  final text = StringBuffer(span.text ?? '');
  for (final child in span.children ?? const <InlineSpan>[]) {
    text.write(_plainText(child) ?? '');
  }
  return text.isEmpty ? null : text.toString();
}
