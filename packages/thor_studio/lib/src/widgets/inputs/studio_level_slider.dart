import 'package:thor_ui/thor_ui.dart';

import '../../theme/component_themes/studio_slider_theme.dart';
import 'state_styles.dart';

/// A bar you drag to set a number: the name on the left, the value on the
/// right and a fill that follows the value.
///
/// ```dart
/// StudioLevelSlider(
///   title: 'Radius',
///   value: 16,
///   min: 0,
///   max: 48,
///   divisions: 12,
///   label: '16 px',
///   onChanged: demo.setRadius, // a ThorState method: void (double)
///   valueText: demo.radiusText, // a ThorState method: String Function()
/// )
/// ```
///
/// Like Flutter's `Slider`: [value] between [min] and [max], [divisions]
/// steps (null for continuous), [onChanged] with the new value while the bar
/// moves, [onChangeEnd] with the final one when it is released (both can be
/// methods of a `ThorState`), and [label] as the text of the value indicator
/// (here the number on the right, as first drawn). With [onChanged] null the
/// bar is disabled. The visible name is the [title]; [semanticLabel] is the
/// accessible name when it should say more than the title. The theme is a
/// [StudioSliderThemeData].
///
/// `// web:` the bar is one native `<input type=range>` drawn as a track
/// whose fill is the browser's own (the range input's progress, or a thumb
/// shadow in Chromium and WebKit), so dragging, the arrow keys, Home, End
/// and Page Up/Down work, and the fill follows the value, with no JavaScript
/// and no new class per value. What needs the engine is the number on the
/// right: [label] (or [formatValue]) draws the value of the first paint, and
/// [valueText] (a `ThorState` method returning the text) keeps it current
/// while the person drags. Without [valueText] the number stays at its first
/// value. Flutter's `onChangeStart` has no counterpart: the range input
/// tells the engine about movement (`input`) and release (`change`), not
/// about the first touch.
class StudioLevelSlider extends StatelessWidget implements ThorElementWidget {
  /// A bar at [value].
  const StudioLevelSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.title,
    this.label,
    this.semanticLabel,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.formatValue,
    this.valueText,
    this.name,
    this.theme,
  }) : assert(value >= min && value <= max),
       assert(max > min),
       assert(
         title != null || semanticLabel != null,
         'A level needs a title (or a semanticLabel): its accessible name.',
       );

  /// The visible name, on the left (and the input's accessible name unless
  /// [semanticLabel] says otherwise).
  final String? title;

  /// The text of the value indicator: the number on the right, as first
  /// drawn.
  final String? label;

  /// The accessible name (`aria-label`); defaults to the [title].
  final String? semanticLabel;

  /// The value when the page is drawn.
  final double value;

  /// Called with the value while the bar is dragged (a `ThorState` method);
  /// null disables the bar.
  final ValueChanged<double>? onChanged;

  /// Called with the value when the bar is released (a `ThorState` method).
  final ValueChanged<double>? onChangeEnd;

  /// The least value.
  final double min;

  /// The greatest value.
  final double max;

  /// The number of steps between [min] and [max]; null is continuous.
  final int? divisions;

  /// Writes a value as the text on the right (the first paint) when there is
  /// no [label]. Defaults to the number, rounded to the step.
  final String Function(double value)? formatValue;

  /// A `ThorState` method returning the text on the right, kept current in
  /// the browser (`String radiusText() => '${radius.value.round()} px'`).
  final String Function()? valueText;

  /// The native field name, for a form.
  final String? name;

  /// Overrides the slider theme (otherwise the nearest, or the default).
  final StudioSliderThemeData? theme;

  String _format(double v) {
    if (formatValue != null) return formatValue!(v);
    final step = divisions == null ? null : (max - min) / divisions!;
    final whole = v == v.roundToDouble();
    return whole || (step != null && step >= 1)
        ? '${v.round()}'
        : v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final t = StudioSliderThemeData.of(context, theme);
    final radius = BorderRadius.circular(t.radius);
    final grip = (t.height - t.handleHeight) / 2;
    final disabled = onChanged == null;
    // web: `Border()` writes `border: none`: the browser's own thumb has one.
    final handle = BoxDecoration(
      color: t.handleColor,
      border: const Border(),
      borderRadius: BorderRadius.circular(2),
      // The fill is a shadow cast to the left of the grip, clipped by the
      // bar: it always ends where the grip is, whatever the value.
      boxShadow: [
        BoxShadow(
          color: t.fillColor,
          offset: const Offset(-2000, 0),
          spreadRadius: 2000,
        ),
      ],
    );
    final text = Theme.of(context).textTheme.labelLarge.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    // The bar sits between the name and the value: the grip travels only
    // that width, so it never covers the name (lowest value) or the number
    // (greatest value), and the fill starts where the name ends.
    final grow = Transition(CssProperty.scale, t.gripDuration, curve: t.curve);
    final slider = Slider(
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      onChanged: onChanged,
      onChangeEnd: onChangeEnd,
      label: label,
      name: name,
      semanticLabel: semanticLabel ?? title,
    );
    return StateStyles(
      style: StyleProps(
        height: t.height,
        opacity: disabled ? t.disabledOpacity : null,
        decoration: BoxDecoration(color: t.trackColor, borderRadius: radius),
        overflowX: Overflow.hidden,
        overflowY: Overflow.hidden,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: t.padding.left),
          // The name: its own room, in front of the bar.
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: t.nameWidth),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title ?? '',
                softWrap: false,
                style: text.copyWith(color: t.nameColor),
              ),
            ),
          ),
          SizedBox(width: t.nameGap),
          Expanded(
            child: StateStyles(
              style: StyleProps(
                height: t.height,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: radius,
                ),
                overflowX: Overflow.hidden,
                overflowY: Overflow.hidden,
                // The browser draws a range input; the bar draws its own.
                appearance: Appearance.none,
                margin: EdgeInsets.zero,
              ),
              states: [
                // Chromium and WebKit: the track is transparent and the grip
                // paints the fill (its shadow).
                StateStyle.selector(
                  '::-webkit-slider-runnable-track',
                  const StyleProps(
                    heightFactor: 1,
                    appearance: Appearance.none,
                    color: Colors.transparent,
                  ),
                ),
                StateStyle.selector(
                  '::-webkit-slider-thumb',
                  StyleProps(
                    width: t.handleWidth,
                    height: t.handleHeight,
                    margin: EdgeInsets.only(top: grip),
                    decoration: handle,
                    // The grip's own transition (a pseudo-element, which a
                    // `Styled` duration never reaches).
                    appearance: Appearance.none,
                    transition: [grow],
                  ),
                ),
                // The grip grows while it is held or has the keyboard, so
                // the person sees what they are moving; a hover only hints.
                StateStyle.selector(
                  ':hover::-webkit-slider-thumb',
                  StyleProps(scale: t.gripHoverScale),
                ),
                StateStyle.selector(
                  ':is(:active, :focus-visible)::-webkit-slider-thumb',
                  StyleProps(scale: t.gripScale),
                ),
                // Firefox draws the fill itself (`progress`).
                StateStyle.selector(
                  '::-moz-range-track',
                  const StyleProps(heightFactor: 1, color: Colors.transparent),
                ),
                StateStyle.selector(
                  '::-moz-range-progress',
                  StyleProps(
                    heightFactor: 1,
                    decoration: BoxDecoration(color: t.fillColor),
                  ),
                ),
                StateStyle.selector(
                  '::-moz-range-thumb',
                  StyleProps(
                    width: t.handleWidth,
                    height: t.handleHeight,
                    decoration: BoxDecoration(
                      color: t.handleColor,
                      border: const Border(),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    transition: [grow],
                  ),
                ),
                StateStyle.selector(
                  ':hover::-moz-range-thumb',
                  StyleProps(scale: t.gripHoverScale),
                ),
                StateStyle.selector(
                  ':is(:active, :focus-visible)::-moz-range-thumb',
                  StyleProps(scale: t.gripScale),
                ),
                // Under `prefers-reduced-motion` the grip does not grow.
                StateStyle(
                  CssCondition.both(
                    CssCondition.reducedMotion,
                    const CssCondition.selector('::-webkit-slider-thumb'),
                  ),
                  const StyleProps(transition: []),
                ),
                StateStyle(
                  CssCondition.both(
                    CssCondition.reducedMotion,
                    const CssCondition.selector('::-moz-range-thumb'),
                  ),
                  const StyleProps(transition: []),
                ),
              ],
              // The screen reader hears the formatted value ("20 px"), kept
              // current like the text on the right.
              child: valueText == null
                  ? slider
                  : WatchAttributes({
                      AttributeName.ariaOf(AriaAttribute.valuetext): valueText!,
                    }, child: slider),
            ),
          ),
          // The value: a fixed room, the number against the right edge.
          Padding(
            padding: EdgeInsets.only(right: t.padding.right),
            child: SizedBox(
              width: t.valueWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: valueText != null
                    ? Watch(
                        valueText!,
                        style: text.copyWith(color: t.valueColor),
                      )
                    : Text(
                        label ?? _format(value),
                        style: text.copyWith(color: t.valueColor),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
