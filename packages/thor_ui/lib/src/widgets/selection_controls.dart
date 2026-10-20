import 'dart:math' as math;

import 'package:thor_engine/thor_engine.dart'
    show StateSignal, encodeArg, fieldAttr, untracked;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../engine/watch.dart'
    show Watch, WatchAttributes, engineAttributes, watchControlValue;
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/errors.dart';
import '../foundation/html_attributes.dart';
import '../foundation/layout_hint.dart';
import '../foundation/parent_data.dart';
import '../foundation/style_registry.dart';
import '../foundation/theme_tokens.dart';
import '../foundation/transparent.dart';
import '../foundation/widget_state.dart';
import 'basic.dart' show Container, boxCss;
import 'buttons.dart' show ButtonStyle, ButtonStyleResolved, buttonStyleCss;
import 'component_themes.dart' show ShowValueIndicator, SliderThemeData;
import 'effects.dart' show Semantics;
import 'form.dart' show InsideForm;
import 'form_scope.dart';
import 'icon.dart' show Icon, IconSizeGiven;
import 'icons.dart' show Icons;
import 'text.dart' show Text;
import 'text_field.dart'
    show
        InputDecoration,
        decoratedFieldId,
        inputDecorator,
        selectBorderCss,
        themedDecoration;
import 'theme.dart' show Theme;

// Material 3 selection controls on native <input>s.
//
// The element keeps its native semantics, keyboard and form behavior; only
// its look is drawn with CSS (`appearance: none`). The state (`:checked`,
// `:disabled`, `:focus-visible`) is a CSS condition of the same class, so
// toggling a control never generates a new class or rule.
//
// The native control keeps its own state (and submits it in a <form>,
// `name`); with a ThorState method as `onChanged`, the browser reports each
// change to it.

const _primary = ThemeTokens.primary;
const _onPrimary = ThemeTokens.onPrimary;
const _onSurface = ThemeTokens.onSurface;
const _outline = ThemeTokens.outline;
const _surfaceHighest = ThemeTokens.surfaceContainerHighest;

const _inputReset = <String, String>{
  'appearance': 'none',
  'margin': '0',
  'flex': '0 0 auto',
  'box-sizing': 'border-box',
  'cursor': 'pointer',
  'background-repeat': 'no-repeat',
  'background-position': 'center',
};

// The 40px state layer of Material: a ring drawn with box-shadow, so the
// control keeps its visual size and needs no wrapper element.
const _hoverRing = ConditionalCss(
  CssCondition.selector(':hover:not(:disabled)'),
  {
    'box-shadow':
        '0 0 0 11px color-mix(in srgb, ${ThemeTokens.onSurface} 8%, transparent)',
  },
);

/// Focus and disabled states (+ the hover ring when standalone), and what
/// the control shows under forced colors.
List<ConditionalCss> _states(bool stateLayer, {bool switchLook = false}) => [
  if (stateLayer) _hoverRing,
  ..._baseStates,
  ...(switchLook ? _forcedSwitch : _forcedNative),
];

const _baseStates = [
  ConditionalCss(CssCondition.focused, {
    'outline': '2px solid $_primary',
    'outline-offset': '2px',
  }),
  ConditionalCss(CssCondition.disabled, {
    'cursor': 'default',
    'opacity': '0.38',
  }),
];

// web: forced colors (Windows High Contrast) repaint backgrounds and keep an
// image as it is, so the check mark's white stroke, the radio's dot and the
// switch's thumb would vanish and the state with them. A checkbox and a
// radio get back the browser's own look, which draws them in the system
// colors. `!important` because the `:checked` rules are more specific.
const _forcedNative = [
  ConditionalCss(CssCondition.forcedColors, {
    'appearance': 'auto',
    'background-image': 'none !important',
    'background-color': 'revert !important',
    'border': 'revert !important',
    'border-radius': 'revert',
    'box-shadow': 'none',
  }),
];

// A switch keeps its shape (the native look of a checkbox would be a huge
// box): the track is an edge in the system's text color, the thumb a
// gradient (an image can't name a system color) that moves as usual, and
// the checked track is filled with `Highlight`.
final _forcedSwitch = [
  const ConditionalCss(CssCondition.forcedColors, {
    'forced-color-adjust': 'none',
    'border-color': 'CanvasText !important',
    'background-color': 'Canvas !important',
    'background-image':
        'radial-gradient(closest-side, CanvasText 94%, transparent 100%) !important',
    'box-shadow': 'none',
  }),
  ConditionalCss(
    CssCondition.both(
      CssCondition.forcedColors,
      const CssCondition.selector(':checked'),
    ),
    {
      'border-color': 'Highlight !important',
      'background-color': 'Highlight !important',
      'background-image':
          'radial-gradient(closest-side, HighlightText 94%, transparent 100%) !important',
    },
  ),
];

String _svg(String body) =>
    'url("data:image/svg+xml,${Uri.encodeComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 18 18">$body</svg>')}")';

const Set<WidgetState> _selected = {WidgetState.selected};
const Set<WidgetState> _unselected = <WidgetState>{};

// The check mark and the dash in a color of the theme. `// web:` they are
// pictures: a color that is a CSS variable cannot reach inside them, so only a
// literal color paints them (a variable keeps the default white).
// web: the step at full precision: `cssNum` rounds to 4 decimals, and a
// step of 0.3333 can never land on `max` (3 divisions of 1).
String _stepOf(double step) =>
    step == step.roundToDouble() ? cssNum(step) : '$step';

String? _colorMark(Color? color) {
  if (color == null) return null;
  final css = color.css;
  return css.startsWith('var(') ? null : css;
}

String _checkOf(String color) => _svg(
  '<path d="M4 9.4l3.2 3.2L14 5.8" fill="none" stroke="$color" stroke-width="2"/>',
);

String _dashOf(String color) =>
    _svg('<path d="M4 9h10" stroke="$color" stroke-width="2"/>');

final _checkMark = _svg(
  '<path d="M4 9.4l3.2 3.2L14 5.8" fill="none" stroke="white" stroke-width="2"/>',
);
final _dash = _svg('<path d="M4 9h10" stroke="white" stroke-width="2"/>');

/// What an `onChanged` that was left out holds (a constant, so it can be the
/// default of the parameter): Dart can't tell a parameter left out from one
/// passed as `null`, and the two mean different things here. It does nothing
/// when called, and the engine ignores it like any closure.
void _omittedChange(Object? value) {}

/// Whether a control is enabled: it has a handler, or it is a form field.
///
/// `// web:` Flutter disables a control whose `onChanged` is null. A page
/// without JS has no handler to give a checkbox in a `Form`, and disabling
/// it would leave it out of what the form sends, so a control with a [name]
/// inside a `Form` whose `onChanged` is left out is an enabled field (the
/// form is what listens to it). An `onChanged: null` written on purpose
/// (`locked ? null : handler`) disables it everywhere, as in Flutter; so does
/// leaving it out without a name or outside a form.
bool _fieldEnabled(BuildContext context, String? name, Function? onChanged) {
  if (onChanged == null) return false;
  if (!identical(onChanged, _omittedChange)) return true;
  return name != null && InsideForm.isIn(context);
}

/// What the enclosing `Form` says about the control [name]: a control that
/// belongs to a failed form is marked invalid (and the first one takes the
/// focus, like a text field does).
class _Fielded {
  _Fielded(BuildContext context, String? name, bool enabled)
    : scope = name == null ? null : FormScope.maybeOf(context),
      name = name {
    final s = scope;
    invalid = s != null && s.errorsOf(name!).isNotEmpty;
    focus =
        invalid &&
        enabled &&
        (ThorStyleRegistry.active(context)?.claimErrorFocus() ?? false);
  }

  final FormScope? scope;
  final String? name;
  late final bool invalid;
  late final bool focus;

  Map<String, String> get attributes => {
    if (invalid) 'aria-invalid': 'true',
    if (focus) 'autofocus': '',
  };
}

/// Flutter's `Checkbox`. `tristate` + `value: null` renders the
/// indeterminate state (`aria-checked="mixed"`).
class Checkbox extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a Material checkbox.
  const Checkbox({
    super.key,
    this.stateLayer = true,
    required this.value,
    this.onChanged = _omittedChange,
    this.tristate = false,
    this.activeColor,
    this.checkColor,
    this.name,
    this.semanticLabel,
  }) : assert(tristate || value != null);

  /// Checked state; `null` (with `tristate`) is indeterminate.
  final bool? value;

  /// Called with the new value when the checkbox is toggled.
  ///
  /// `// web:` optional (Flutter's is required). Left out, the checkbox is
  /// disabled like Flutter's, unless it has a [name] and is inside a `Form`:
  /// then it is a field the form sends, enabled. Written as `onChanged: null`
  /// (`locked ? null : save`) it is disabled everywhere, as in Flutter. Same
  /// for [Switch], [Slider], [DropdownButton], [DropdownButtonFormField], the
  /// list tiles and a named [RadioGroup].
  final ValueChanged<bool?>? onChanged;

  /// Whether `value` can be `null` (Flutter's default: false).
  final bool tristate;

  /// Color when checked or indeterminate (Flutter's default: the primary
  /// color).
  final Color? activeColor;

  /// web: [checkColor] colors the mark when it is a literal color (a `var()`
  /// token keeps the default white mark).
  final Color? checkColor;

  // web: not in Flutter.
  /// Form field name.
  final String? name;

  /// The hover ring of a standalone control. `false` inside a `*ListTile`,
  /// whose whole row shows the state instead (like Flutter).
  final bool stateLayer;

  /// Accessible label for the control.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // The parameter, else `ThemeData.checkboxTheme`, else Flutter's default.
    final theme = Theme.of(context).checkboxTheme;
    final active =
        activeColor?.css ??
        theme?.fillColor?.resolve(_selected)?.css ??
        _primary;
    final off = theme?.fillColor?.resolve(_unselected)?.css;
    final mark = _colorMark(
      checkColor ?? theme?.checkColor?.resolve(_selected),
    );
    final side = theme?.side;
    final shape = theme?.shape;
    final mixed = tristate && value == null;
    final enabled = _fieldEnabled(context, name, onChanged);
    final form = _Fielded(context, name, enabled);
    final checked = name == null ? null : form.scope?.checked(name!);
    return thorElement(
      'input',
      debugName: 'Checkbox',
      baseCss: _inputReset,
      css: {
        'width': '18px',
        'height': '18px',
        'border': side == null || side == BorderSide.none
            ? '2px solid ${ThemeTokens.onSurfaceVariant}'
            : side.css,
        'border-radius': shape?.radiusCss ?? '2px',
        'background-color': ?off,
        'transition-property': stateLayer
            ? 'background-color, border-color, box-shadow'
            : 'background-color, border-color',
        'transition-duration': '150ms',
      },
      // Every state is a condition of the same class: toggling (or a client
      // engine switching `aria-checked`) never needs another class. The dash
      // applies while unchecked, so a click that nothing rebuilds still wins.
      conditions: [
        ConditionalCss(const CssCondition.selector(':checked'), {
          'background-color': active,
          'border-color': active,
          'background-image': mark == null ? _checkMark : _checkOf(mark),
        }),
        // web: the server's `aria-checked="mixed"` stays in the DOM after a
        // click that no rebuild follows; once checked, the check wins.
        ConditionalCss(
          const CssCondition.selector('[aria-checked="mixed"]:not(:checked)'),
          {
            'background-color': active,
            'border-color': active,
            'background-image': mark == null ? _dash : _dashOf(mark),
          },
        ),
        ..._states(stateLayer),
      ],
      attributes: {
        'type': 'checkbox',
        if (checked ?? value ?? false) 'checked': '',
        if (!enabled) 'disabled': '',
        if (mixed && checked == null) 'aria-checked': 'mixed',
        ...form.attributes,
        'name': ?name,
        'aria-label': ?semanticLabel,
        ...engineAttributes({'change': onChanged}),
      },
    );
  }
}

/// Flutter's `Switch` (Material 3): `<input type=checkbox role=switch>`.
///
/// Like Flutter's, it is 52x32 and 16/24 thumb by default; a compact one is
/// `Transform.scale(scale: 40 / 52, child: Switch(...))`, which scales the
/// track, thumb and hover ring (it fuses into the `<input>`), or, without
/// scaling, a `SwitchThemeData(trackSize:, thumbSize:, trackOutlineWidth:)`:
///
/// ```dart
/// Theme(
///   data: ThemeData(
///     switchTheme: SwitchThemeData(
///       trackSize: Size(40, 24),
///       thumbSize: WidgetStatePropertyAll(18),
///       trackOutlineWidth: WidgetStatePropertyAll(1),
///     ),
///   ),
///   child: Switch(value: on, onChanged: state.toggle),
/// )
/// ```
///
/// `// web:` as in Flutter, the transform does not change the layout box, which
/// stays 52x32. `FittedBox` does not scale a `Switch` to a `SizedBox` yet.
class Switch extends StatelessWidget implements ThorElementWidget, ThorBuiltIn {
  /// Creates a Material 3 switch.
  const Switch({
    super.key,
    this.stateLayer = true,
    required this.value,
    this.onChanged = _omittedChange,
    this.activeColor,
    this.trackOutlineWidth,
    this.padding,
    this.materialTapTargetSize,
    this.name,
    this.semanticLabel,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the new value when toggled.
  final ValueChanged<bool>? onChanged;

  /// Color when on (Flutter's default: the primary color).
  final Color? activeColor;

  /// The track's outline width (default: the theme's, else 2).
  final WidgetStateProperty<double?>? trackOutlineWidth;

  /// The space around the track (default: the theme's, else Flutter's
  /// Material 3 `EdgeInsets.symmetric(horizontal: 4)`, a 60 px wide switch).
  /// `EdgeInsets.zero` removes it. `// web:` a margin: the clickable area
  /// stays the track.
  final EdgeInsetsGeometry? padding;

  /// The touch target (default: the theme's, else `padded`). `// web:` both
  /// values lay out the same box, the native control's own.
  final MaterialTapTargetSize? materialTapTargetSize;

  // web: not in Flutter.
  /// Form field name.
  final String? name;

  /// The hover ring of a standalone control. `false` inside a `*ListTile`,
  /// whose whole row shows the state instead (like Flutter).
  final bool stateLayer;

  /// Accessible label for the control.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // The parameter, else `ThemeData.switchTheme`, else Flutter's default.
    final theme = Theme.of(context).switchTheme;
    final active =
        activeColor?.css ??
        theme?.trackColor?.resolve(_selected)?.css ??
        _primary;
    final trackOff = theme?.trackColor?.resolve(_unselected)?.css;
    final thumbOn = theme?.thumbColor?.resolve(_selected)?.css;
    final thumbOff = theme?.thumbColor?.resolve(_unselected)?.css;
    final enabled = _fieldEnabled(context, name, onChanged);
    final form = _Fielded(context, name, enabled);
    final checked = name == null ? null : form.scope?.checked(name!);
    // The track is 52x32 unless the theme says (web-only); the thumb sits as
    // far from the ends as from the sides, so it is centered and its inset
    // follows its size. `edge` is that inset inside the outline.
    final track = theme?.trackSize ?? const Size(52, 32);
    final offSize = theme?.thumbSize?.resolve(_unselected) ?? 16.0;
    final onSize = theme?.thumbSize?.resolve(_selected) ?? 24.0;
    final offWidth =
        (trackOutlineWidth ?? theme?.trackOutlineWidth)?.resolve(_unselected) ??
        2.0;
    final onWidth =
        (trackOutlineWidth ?? theme?.trackOutlineWidth)?.resolve(_selected) ??
        2.0;
    double edge(double thumbSize, double outline) =>
        (track.height - thumbSize) / 2 - outline;
    final space =
        padding ?? theme?.padding ?? const EdgeInsets.symmetric(horizontal: 4);
    // web: the thumb is a background image, so a `box-shadow` cannot reach
    // it; `thumbShadow` draws blurred circles inside the same image, which
    // is enlarged by `pad` on every side to hold them.
    final shadows = theme?.thumbShadow ?? const <BoxShadow>[];
    final pad = shadows.isEmpty
        ? 0.0
        : shadows
              .map(
                (s) =>
                    math.max(s.offset.dx.abs(), s.offset.dy.abs()) +
                    s.blurRadius +
                    math.max(s.spreadRadius, 0),
              )
              .reduce(math.max)
              .ceilToDouble();
    String thumb(String color, double size) {
      final fill = color.startsWith('var(') ? '#fff' : color;
      if (shadows.isEmpty) {
        return _svg('<circle cx="9" cy="9" r="9" fill="$fill"/>');
      }
      final box = size + 2 * pad, c = box / 2, r = size / 2;
      final body = StringBuffer();
      for (final (i, s) in shadows.indexed) {
        body
          ..write('<filter id="b$i" x="-100%" y="-100%" width="300%" ')
          ..write('height="300%"><feGaussianBlur stdDeviation="')
          ..write(cssNum(s.blurRadius / 2))
          ..write('"/></filter><circle cx="')
          ..write(cssNum(c + s.offset.dx))
          ..write('" cy="')
          ..write(cssNum(c + s.offset.dy))
          ..write('" r="')
          ..write(cssNum(math.max(r + s.spreadRadius, 0)))
          ..write('" fill="${s.color.css}" filter="url(#b$i)"/>');
      }
      body.write(
        '<circle cx="${cssNum(c)}" cy="${cssNum(c)}" r="${cssNum(r)}" '
        'fill="$fill"/>',
      );
      final svg =
          '<svg xmlns="http://www.w3.org/2000/svg" '
          'viewBox="0 0 ${cssNum(box)} ${cssNum(box)}">$body</svg>';
      return 'url("data:image/svg+xml,${Uri.encodeComponent(svg)}")';
    }

    String grown(double size) => cssPx(size + 2 * pad);
    return thorElement(
      'input',
      debugName: 'Switch',
      baseCss: _inputReset,
      css: {
        'width': cssPx(track.width),
        'height': cssPx(track.height),
        'border': '${cssPx(offWidth)} solid $_outline',
        'border-radius': cssPx(track.height / 2),
        // web: Flutter's padding is part of the switch; here a margin.
        ...space.toCss('margin'),
        'background-color': trackOff ?? _surfaceHighest,
        // Thumb: one image whose size and position transition (16px off,
        // 24px on), so the change runs on CSS alone.
        'background-image': thumbOff == null && shadows.isEmpty
            ? _svg('<circle cx="9" cy="9" r="9" fill="#79747e"/>')
            : thumb(thumbOff ?? '#79747e', offSize),
        'background-size': '${grown(offSize)} ${grown(offSize)}',
        'background-position':
            'left ${cssPx(edge(offSize, offWidth) - pad)} center',
        'transition-property': stateLayer
            ? 'background-color, border-color, background-size, background-position, box-shadow'
            : 'background-color, border-color, background-size, background-position',
        'transition-duration': '200ms',
        'transition-timing-function': Curves.easeInOut.css,
      },
      conditions: [
        ConditionalCss(const CssCondition.selector(':checked'), {
          'background-color': active,
          'border-color': active,
          if (onWidth != offWidth) 'border-width': cssPx(onWidth),
          'background-image': thumb(thumbOn ?? _onPrimary, onSize),
          'background-size': '${grown(onSize)} ${grown(onSize)}',
          'background-position':
              'right ${cssPx(edge(onSize, onWidth) - pad)} center',
        }),
        ..._states(stateLayer, switchLook: true),
      ],
      attributes: {
        'type': 'checkbox',
        'role': 'switch',
        if (checked ?? value) 'checked': '',
        if (!enabled) 'disabled': '',
        ...form.attributes,
        'name': ?name,
        'aria-label': ?semanticLabel,
        ...engineAttributes({'change': onChanged}),
      },
    );
  }
}

/// Flutter's `RadioGroup<T>` (3.32+): the selection of the [Radio]s below it.
///
/// ```dart
/// RadioGroup<Plan>(
///   name: 'plan',
///   groupValue: Plan.free,
///   onChanged: signup.pick,
///   child: Column(children: [
///     RadioListTile<Plan>(value: Plan.free, title: Text('Free')),
///     RadioListTile<Plan>(value: Plan.pro, title: Text('Pro')),
///   ]),
/// )
/// ```
///
/// A `Radio<T>` (or `RadioListTile<T>`) below finds the nearest
/// `RadioGroup<T>` and takes its `name`, its checked state and its
/// [onChanged] from it. The value of an enum travels as its `name`.
///
/// web: no JavaScript is needed: the radios share a native `name`, so the
/// browser keeps one checked, moves with the arrow keys and submits the
/// value inside a `Form`. [name] is what the form sends the value under (and
/// how a failed form refills the group); without it the group gets a name of
/// its own that is unique in the page (the selection still works, the
/// form receives it under that name). Flutter has no `name`.
class RadioGroup<T> extends InheritedWidget {
  /// Creates a radio group around [child].
  const RadioGroup({
    super.key,
    this.groupValue,
    this.onChanged = _omittedChange,
    this.onSelectionChanged,
    this.name,
    required super.child,
  });

  /// The selected value: the radio below whose `value` equals it is checked.
  final T? groupValue;

  /// Called with the value of the radio the person selects; `null` disables
  /// every radio of the group (like a `Radio` without `onChanged`).
  final ValueChanged<T?>? onChanged;

  // web: not in Flutter. `SegmentedButton.onSelectionChanged` has this shape.
  /// Called, instead of [onChanged], with a set holding the one value the
  /// person selects (a `ThorState` method taking a `Set<T>`: the browser
  /// sends a single value and the page builds the set).
  final ValueChanged<Set<T>>? onSelectionChanged;

  // web: not in Flutter.
  /// The native group name (the form field name).
  final String? name;

  /// The nearest group of [T] above [context], or `null`.
  static RadioGroup<T>? maybeOf<T>(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RadioGroup<T>>();

  // The generated name of a group with no `name`: one per group in the
  // page, by the identity of its element (the page builds once).
  static final _generated = Expando<String>('RadioGroup name');

  String _nameFor(BuildContext context) {
    if (name case final n?) return n;
    final element = context
        .getElementForInheritedWidgetOfExactType<RadioGroup<T>>();
    if (element == null) return 't-rg${++_fallbackGroups}';
    // A loose page has no registry: a counter of its own, so two groups
    // never share a name (and so a checked radio).
    return _generated[element] ??=
        ThorStyleRegistry.active(context)?.uniqueId('t-rg') ??
        't-rg${++_fallbackGroups}';
  }

  static var _fallbackGroups = 0;

  @override
  bool updateShouldNotify(RadioGroup<T> oldWidget) =>
      groupValue != oldWidget.groupValue ||
      onChanged != oldWidget.onChanged ||
      onSelectionChanged != oldWidget.onSelectionChanged ||
      name != oldWidget.name;
}

/// Flutter's `Radio<T>`: selected when [value] equals the value of the
/// [RadioGroup] above it.
///
/// ```dart
/// RadioGroup<String>(
///   groupValue: 'a',
///   onChanged: state.pick,
///   child: Row(children: [Radio<String>(value: 'a'), Radio<String>(value: 'b')]),
/// )
/// ```
///
/// web: radios with the same name form a native group (arrow keys move
/// between them); the [RadioGroup] gives it, or pass a [name].
class Radio<T> extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a Material radio button.
  const Radio({
    super.key,
    this.stateLayer = true,
    required this.value,
    @Deprecated(
      'Use a RadioGroup ancestor to manage the group value instead, like '
      'Flutter (deprecated after v3.32).',
    )
    this.groupValue,
    @Deprecated(
      'Use RadioGroup(onChanged:) to handle the change instead, like '
      'Flutter (deprecated after v3.32).',
    )
    this.onChanged,
    this.activeColor,
    this.name,
    this.semanticLabel,
  }) : _overlay = false,
       _off = false;

  // A segment of a `SegmentedButton`: the native radio laid invisibly over
  // the whole segment, so the segment is the click target.
  const Radio._overlay({
    super.key,
    required this.value,
    this.semanticLabel,
    required bool disabled,
  }) : stateLayer = false,
       _off = disabled,
       // ignore: deprecated_member_use_from_same_package
       groupValue = null,
       // ignore: deprecated_member_use_from_same_package
       onChanged = null,
       activeColor = null,
       name = null,
       _overlay = true;

  final bool _overlay;
  final bool _off;

  /// The value this radio represents.
  final T value;

  /// The currently selected value of the group.
  @Deprecated(
    'Use a RadioGroup ancestor to manage the group value instead, like '
    'Flutter (deprecated after v3.32).',
  )
  final T? groupValue;

  /// Called with `value` when this radio is selected.
  @Deprecated(
    'Use RadioGroup(onChanged:) to handle the change instead, like '
    'Flutter (deprecated after v3.32).',
  )
  final ValueChanged<T?>? onChanged;

  /// Color when selected (Flutter's default: the primary color).
  final Color? activeColor;

  // web: not in Flutter.
  /// Native group name (radios sharing it move with arrow keys).
  /// Over the name of the [RadioGroup] above.
  final String? name;

  /// The hover ring of a standalone control. `false` inside a `*ListTile`,
  /// whose whole row shows the state instead (like Flutter).
  final bool stateLayer;

  /// Accessible label for the control.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // The parameter, else `ThemeData.radioTheme`, else Flutter's default.
    final theme = Theme.of(context).radioTheme;
    final active =
        activeColor?.css ??
        theme?.fillColor?.resolve(_selected)?.css ??
        _primary;
    final group = RadioGroup.maybeOf<T>(context);
    // The radio's own values win over the group's (the old API).
    // ignore: deprecated_member_use_from_same_package
    final ownChanged = onChanged;
    // ignore: deprecated_member_use_from_same_package
    final ownValue = groupValue;
    final Function? change =
        ownChanged ?? group?.onSelectionChanged ?? group?.onChanged;
    final selectedValue = ownChanged != null || group == null
        ? ownValue
        : group.groupValue;
    final fieldName = name ?? group?._nameFor(context);
    // A group named by the app is a form field; the generated name is not.
    final enabled = _fieldEnabled(context, name ?? group?.name, change);
    final form = _Fielded(context, fieldName, enabled);
    final scope = form.scope;
    // A form that decides the group (a failed submit, saved defaults)
    // says which radio is on; otherwise the group value does.
    final selected =
        fieldName != null && scope != null && scope.decides(fieldName)
        ? scope.valueOf(fieldName) == encodeArg(value)
        : value == selectedValue;
    return thorElement(
      'input',
      debugName: 'Radio',
      baseCss: _inputReset,
      css: _overlay
          ? _segmentInputCss
          : {
              'width': '20px',
              'height': '20px',
              'border': '2px solid ${ThemeTokens.onSurfaceVariant}',
              'border-radius': '50%',
              'transition-property': stateLayer
                  ? 'border-color, box-shadow'
                  : 'border-color',
              'transition-duration': '150ms',
            },
      conditions: _overlay
          ? const []
          : [
              ConditionalCss(const CssCondition.selector(':checked'), {
                'border-color': active,
                'background-image':
                    'radial-gradient(circle, $active 0 5px, transparent 5.5px)',
              }),
              ..._states(stateLayer),
            ],
      attributes: {
        'type': 'radio',
        if (selected) 'checked': '',
        if (!enabled || _off) 'disabled': '',
        ...form.attributes,
        'name': ?fieldName,
        // Native value: the form submits it (and an engine action gets it).
        'value': encodeArg(value),
        'aria-label': ?semanticLabel,
        ...engineAttributes({'change': change}),
      },
    );
  }
}

/// The `oninput` of a slider with a value bubble: moves `--f` (the thumb's
/// place) and writes the value into the bubble's template (`data-t-f`).
const _bubbleHandler =
    'var v=+this.value,a=+this.min,b=+this.max,p=this.parentNode,'
    'o=p.lastChild;p.style.setProperty("--f",b>a?(v-a)/(b-a):0);'
    'o.textContent=o.getAttribute("data-t-f").split("{}").join(+v.toFixed(4))';

/// Flutter's `Slider` on `<input type=range>`.
///
/// web: the active track is the browser's own fill (`accent-color`), so a
/// drag never produces a new class per value.
class Slider extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a Material slider.
  const Slider({
    super.key,
    required this.value,
    this.onChanged = _omittedChange,
    this.onChangeEnd,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.label,
    this.activeColor,
    this.name,
    this.semanticLabel,
  }) : assert(value >= min && value <= max),
       _source = null;

  /// A slider whose value is the number [source] returns (a `ThorState`
  /// method returning `double`, or a field's `call`), kept current in the
  /// browser: the page is not rebuilt.
  ///
  /// ```dart
  /// Slider.watch(circles.sliderValue, min: 5, max: 100, onChanged: circles.setPreview)
  /// ```
  ///
  /// `// web:` no Flutter counterpart: Flutter rebuilds with a new `value`.
  /// It replaces `WatchAttributes({AttributeName.value: …}, child: Slider(…))`.
  Slider.watch(
    double Function() source, {
    super.key,
    this.onChanged = _omittedChange,
    this.onChangeEnd,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.label,
    this.activeColor,
    this.name,
    this.semanticLabel,
  }) : value = untracked(source).clamp(min, max),
       _source = source;

  /// Current value, between `min` and `max`.
  final double value;

  final double Function()? _source;

  /// Called with the new value while dragging.
  final ValueChanged<double>? onChanged;

  /// Called with the final value when the drag ends.
  final ValueChanged<double>? onChangeEnd;

  /// Minimum value (Flutter's default: 0).
  final double min;

  /// Maximum value (Flutter's default: 1).
  final double max;

  /// Number of discrete steps; `null` for a continuous slider.
  final int? divisions;

  /// web: shown as the element's tooltip (`title`).
  final String? label;

  /// Color of the filled track (Flutter's default: the primary color).
  final Color? activeColor;

  // web: not in Flutter.
  /// Form field name.
  final String? name;

  /// Accessible label for the control.
  final String? semanticLabel;

  @override
  bool get fillsWidth => true;

  @override
  Widget build(BuildContext context) {
    // The parameter, else `ThemeData.sliderTheme`, else Flutter's default.
    final theme = Theme.of(context).sliderTheme;
    final enabled = _fieldEnabled(context, name, onChanged);
    final form = _Fielded(context, name, enabled);
    // What was sent (a hostile or out-of-range value is clamped).
    final sent = name == null ? null : form.scope?.valueOf(name!);
    final shown = (sent == null ? null : double.tryParse(sent))?.clamp(
      min,
      max,
    );
    final indicator = theme?.showValueIndicator;
    final bubble =
        enabled &&
        switch (indicator) {
          null || ShowValueIndicator.never => false,
          ShowValueIndicator.onlyForDiscrete => divisions != null,
          ShowValueIndicator.onlyForContinuous => divisions == null,
          ShowValueIndicator.onDrag || ShowValueIndicator.alwaysVisible => true,
        };
    final input = thorElement(
      'input',
      debugName: 'Slider',
      fillsWidth: true,
      baseCss: const {'margin': '0', 'box-sizing': 'border-box'},
      css: {
        'min-width': '0',
        'height': '44px',
        'accent-color':
            (activeColor ?? theme?.activeTrackColor ?? theme?.thumbColor)
                ?.css ??
            _primary,
        'cursor': 'pointer',
      },
      conditions: const [
        ConditionalCss(CssCondition.disabled, {
          'cursor': 'default',
          'opacity': '0.38',
        }),
      ],
      attributes: {
        'type': 'range',
        'min': cssNum(min),
        'max': cssNum(max),
        'step': divisions == null ? 'any' : _stepOf((max - min) / divisions!),
        'value': cssNum(shown ?? value),
        if (!enabled) 'disabled': '',
        ...form.attributes,
        if (!bubble) 'title': ?label,
        'name': ?name,
        'aria-label': ?semanticLabel,
        ...engineAttributes({'input': onChanged, 'change': onChangeEnd}),
        if (bubble) 'oninput': _bubbleHandler,
      },
    );
    final element = bubble ? _withBubble(input, theme!, shown ?? value) : input;
    final source = _source;
    return source == null
        ? element
        : WatchAttributes({AttributeName.value: source}, child: element);
  }

  /// The input in a box with the bubble over the thumb.
  // web: the thumb's place is `--f`, the value's share of the range (the
  // server writes it; the `oninput` moves it): the bubble is positioned by
  // CSS from it, the thumb being about 20 px wide. `onDrag` shows it while
  // the slider is pressed or has the keyboard's focus.
  Widget _withBubble(Widget input, SliderThemeData theme, double current) {
    final always = theme.showValueIndicator == ShowValueIndicator.alwaysVisible;
    final text = label ?? '{}';
    final fraction = max > min ? (current - min) / (max - min) : 0.0;
    final fill = theme.valueIndicatorColor?.css ?? _primary;
    return thorElement(
      'div',
      debugName: 'SliderIndicator',
      fillsWidth: true,
      css: {
        'position': 'relative',
        'box-sizing': 'border-box',
        'padding-top': '32px',
        '--f': cssNum(fraction),
      },
      children: [
        input,
        thorElement(
          'span',
          debugName: 'SliderBubble',
          css: {
            'position': 'absolute',
            'bottom': '40px',
            'left': 'calc(10px + (100% - 20px) * var(--f))',
            'transform': 'translateX(-50%)',
            'box-sizing': 'border-box',
            'min-width': '32px',
            'padding': '4px 8px',
            'border-radius': '16px',
            'background-color': fill,
            'color': _onPrimary,
            'font-size': '12px',
            'line-height': '16px',
            'text-align': 'center',
            'white-space': 'nowrap',
            'pointer-events': 'none',
            'opacity': always ? '1' : '0',
            'transition': 'opacity 120ms',
            ...?theme.valueIndicatorTextStyle?.toCss(),
          },
          conditions: [
            if (!always)
              const ConditionalCss(
                CssCondition.selector(
                  ':has(input:active, input:focus-visible)',
                ),
                {'opacity': '1'},
              ),
          ],
          attributes: {'aria-hidden': 'true', 'data-t-f': text},
          children: [Text(text.replaceAll('{}', cssNum(current)))],
        ),
      ],
    );
  }
}

/// Flutter's `DropdownMenuItem<T>`.
class DropdownMenuItem<T> {
  /// Creates a dropdown menu entry.
  const DropdownMenuItem({
    required this.value,
    required this.child,
    this.enabled = true,
  });

  /// Value the item represents.
  final T value;

  /// Content of the item, normally a `Text`. In a `Watch.list` row,
  /// `row.text(…)` fills the `<option>`'s text with the row's value
  /// (`// web:` the `<option>` carries the binding, with no `<span>`).
  final Widget child;

  /// Whether the item responds to input (Flutter's default: true).
  final bool enabled;
}

/// Flutter's `DropdownButton<T>` on a native `<select>`: the OS picker on
/// mobile, full keyboard and type-ahead for free.
///
/// web: item content should be text (a `Text`); richer content renders only
/// where the customizable select (`appearance: base-select`) is supported.
class DropdownButton<T> extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a Material dropdown button.
  const DropdownButton({
    super.key,
    required this.items,
    required this.value,
    this.onChanged = _omittedChange,
    this.hint,
    this.isExpanded = false,
    this.name,
    this.id,
    this.semanticLabel,
    this.style,
    this.underline,
    this.borderRadius,
    this.isDense = false,
    this.itemHeight,
    this.valueWatch,
    this.boxShadow,
    this.iconSize = 24,
    this.iconEnabledColor,
    this.icon,
    this.iconDisabledColor,
  });

  /// The trailing arrow, in place of the default `arrow_drop_down` (Flutter's
  /// `icon`): normally an [Icon]. [iconSize] and [iconEnabledColor] (or
  /// [iconDisabledColor] while the button is disabled) apply to it, as the
  /// `IconTheme` Flutter wraps it in does; an [Icon] with its own `size` or
  /// `color` keeps them.
  // web: the `<select>` drops the system arrow (`appearance: none`) and the
  // icon is a sibling over it, 8 px from the right edge, with
  // `pointer-events: none`: the select keeps its picker and keyboard. Leave
  // room for it in the padding (36 px by default).
  final Widget? icon;

  /// The color of [icon] while the button is disabled (default: the icon's
  /// enabled color at 38 % opacity).
  final Color? iconDisabledColor;

  /// `// web:` not in Flutter: the shadows under the button.
  final List<BoxShadow>? boxShadow;

  /// The size of the arrow when [iconEnabledColor] draws its own, or of
  /// [icon].
  final double iconSize;

  /// The arrow's color. Given, the `<select>` drops the system arrow
  /// (`appearance: none`) and draws an arrow of this color and [iconSize]
  /// on its right side (8 px from the edge); leave room for it in the
  /// padding. Null keeps the browser's arrow.
  // web: Flutter's `iconEnabledColor` colors its `icon`; a `<select>` has
  // no child to draw an icon in, so the arrow is a background image.
  final Color? iconEnabledColor;

  /// Whether the button is shorter: 36 px instead of 48 (the height a dense
  /// editor's controls have).
  // web: Flutter shrinks the button to its text; a `<select>` keeps a
  // minimum height, so the dense one is a 36 px minimum.
  final bool isDense;

  /// The button's minimum height (default 48, or 36 with [isDense]). A
  /// number sets the `<select>` height exactly: it is its `min-height`.
  final double? itemHeight;

  /// The text of the chosen value, kept current in the browser: a method of
  /// the state returning what the chosen option's value is (an enum's name,
  /// a number as text), torn off or with `withArg`. The control follows it
  /// when the value changes without a rebuild, and at load when the field is
  /// `local:` (the browser moves it after the server drew the page).
  /// [value] stays the value the server draws.
  ///
  /// ```dart
  /// DropdownButton<String>(
  ///   value: editor.device.value,
  ///   valueWatch: editor.deviceId,       // String deviceId() => device.value
  ///   items: devices,
  ///   onChanged: editor.setDevice,
  /// )
  /// ```
  ///
  /// `// web:` no Flutter counterpart (Flutter rebuilds with a new
  /// [value]). It replaces `WatchAttributes({AttributeName.value: …},
  /// child: DropdownButton(…))`.
  final String? Function()? valueWatch;

  /// Font and color of the selected item's text.
  final TextStyle? style;

  /// The line under the button.
  // web: the default look is an outlined box, not Flutter's underline. Any
  // underline replaces the outline: a `Container(height:, color:)` draws
  // that line under the button; anything else (`SizedBox.shrink()`)
  // leaves no line.
  final Widget? underline;

  /// Corner radius of the button.
  final BorderRadius? borderRadius;

  /// Entries of the dropdown.
  final List<DropdownMenuItem<T>> items;

  /// Currently selected value.
  final T? value;

  /// Called with the newly picked value.
  final ValueChanged<T?>? onChanged;

  /// Shown while [value] is null (a disabled placeholder option). Without
  /// [semanticLabel] or [id] it is also the control's accessible name, as
  /// Flutter's semantics reads the hint.
  final String? hint;

  /// Whether the control fills the available width (Flutter's default:
  /// false).
  final bool isExpanded;

  // web: not in Flutter.
  /// Form field name.
  final String? name;

  // web: not in Flutter.
  /// DOM id of the `<select>`, so a `<label for>` names it
  /// (like `TextField.id`); without it or [semanticLabel] the control has
  /// no accessible name.
  final String? id;

  /// Accessible label for the control.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => _buildSelect(context);

  /// The `<select>` (inside the box of [icon] when there is one). [extraCss]
  /// and [extraAttributes] land on the select itself: the form field's
  /// decoration.
  Widget _buildSelect(
    BuildContext context, {
    CssDeclarations extraCss = const {},
    Map<String, String> extraAttributes = const {},
  }) {
    final enabled = _fieldEnabled(context, name, onChanged);
    final form = _Fielded(context, name, enabled);
    final scope = form.scope;
    final hasIcon = icon != null;
    // A form that decides the field says which option is chosen (none: the
    // hint), else the widget's own value does.
    final index = name != null && scope != null && scope.decides(name!)
        ? items.indexWhere((i) => encodeArg(i.value) == scope.valueOf(name!))
        : items.indexWhere((i) => i.value == value);
    final select = thorElement(
      'select',
      debugName: 'DropdownButton',
      fillsWidth: isExpanded,
      baseCss: const {'margin': '0', 'font': 'inherit', 'color': 'inherit'},
      css: {
        'box-sizing': 'border-box',
        'min-height': cssPx(itemHeight ?? (isDense ? 36 : 48)),
        'padding': '0 36px 0 16px',
        'border': '1px solid $_outline',
        'border-radius': borderRadius?.css ?? '4px',
        'background-color': 'transparent',
        'min-width': '0',
        'cursor': 'pointer',
        'accent-color': _primary,
        if (boxShadow != null && boxShadow!.isNotEmpty)
          'box-shadow': boxShadow!.map((b) => b.css).join(', '),
        if (hasIcon)
          ..._iconSelectCss(iconSize)
        else if (iconEnabledColor case final c?)
          ..._ownArrowCss(c, iconSize),
        if (underline != null) ..._underlineCss(underline!),
        ...?style?.toCss(),
        ...extraCss,
      },
      conditions: const [
        ConditionalCss(CssCondition.focused, {
          'outline': '2px solid $_primary',
          'outline-offset': '-1px',
        }),
        ConditionalCss(CssCondition.disabled, {
          'cursor': 'default',
          'opacity': '0.38',
        }),
      ],
      attributes: {
        if (!enabled) 'disabled': '',
        ...form.attributes,
        'id': ?id,
        'name': ?name,
        'aria-label': ?(semanticLabel ?? (id == null ? hint : null)),
        ...engineAttributes({'change': onChanged}),
        ...extraAttributes,
      },
      children: [
        if (index < 0)
          Widget.element(
            tag: 'option',
            attributes: const {'value': '', 'disabled': '', 'selected': ''},
            children: [Widget.text(hint ?? '')],
          ),
        for (var i = 0; i < items.length; i++)
          _option({
            'value': encodeArg(items[i].value),
            if (i == index) 'selected': '',
            if (!items[i].enabled) 'disabled': '',
          }, items[i].child),
      ],
    );
    final watch = valueWatch;
    final control = watch == null
        ? select
        : watchControlValue(watch, child: select);
    if (!hasIcon) return control;
    return thorElement(
      'span',
      debugName: 'DropdownButtonBox',
      fillsWidth: isExpanded,
      css: {
        'position': 'relative',
        'display': isExpanded ? 'flex' : 'inline-flex',
        'min-width': '0',
        'vertical-align': 'top',
      },
      children: [
        control,
        _dropdownIcon(
          icon!,
          size: iconSize,
          color: enabled ? iconEnabledColor : iconDisabledColor,
          dimmed: !enabled && iconDisabledColor == null,
        ),
      ],
    );
  }
}

/// The `<select>` of a `DropdownButton` whose arrow is an `icon`: no system
/// arrow, and room on the right for the icon.
CssDeclarations _iconSelectCss(double size) => {
  'appearance': 'none',
  'flex': '1 1 auto',
  if (size > 24) 'padding-right': cssPx(size + 12),
};

/// The box of a `DropdownButton`'s `icon`: [size] square, 8 px from the right
/// edge, centered, never taking the pointer from the select under it.
// web: Flutter wraps the icon in an `IconTheme` (size, color); thor has
// none, so an `Icon` without its own size is drawn again at [size] (one
// with `size:`, 24 included, keeps it).
Widget _dropdownIcon(
  Widget icon, {
  required double size,
  required Color? color,
  required bool dimmed,
}) {
  var child = icon;
  final resolved = resolveComponent(icon);
  if (resolved is Icon && !resolved.hasOwnSize && size != 24) {
    child = Icon(
      resolved.icon,
      key: resolved.key,
      size: size,
      color: resolved.color,
      semanticLabel: resolved.semanticLabel,
    );
  }
  return thorElement(
    'span',
    debugName: 'DropdownButtonIcon',
    css: {
      'position': 'absolute',
      'right': '8px',
      'top': '50%',
      'margin-top': cssPx(-size / 2),
      'width': cssPx(size),
      'height': cssPx(size),
      'display': 'flex',
      'align-items': 'center',
      'justify-content': 'center',
      'pointer-events': 'none',
      if (color != null) 'color': color.css,
      if (dimmed) 'opacity': '0.38',
    },
    children: [child],
  );
}

/// A `<select>` without the system arrow and a triangle of [color] and
/// [size] in its place (Flutter's `arrow_drop_down`).
// web: two gradients, not an SVG image: a custom property (a theme token, the
// dark mode) cannot resolve inside a `data:` image, and a `<select>` cannot
// carry a pseudo-element or a mask of its own.
CssDeclarations _ownArrowCss(Color color, double size) {
  final c = color.css;
  // arrow_drop_down is a 10x5 triangle centered in its 24-unit icon box;
  // the box sits 8 px from the right edge.
  final half = size * 5 / 24;
  final center = 8 + size / 2;
  return {
    'appearance': 'none',
    'background-image':
        'linear-gradient(to top right, transparent 50%, $c 50%), '
        'linear-gradient(to top left, transparent 50%, $c 50%)',
    'background-repeat': 'no-repeat',
    'background-position':
        'right ${cssPx(center)} center, right ${cssPx(center - half)} center',
    'background-size': '${cssPx(half)} ${cssPx(half)}',
  };
}

/// The border of a `DropdownButton` with an [underline]: a line
/// `Container` draws it at the bottom, anything else draws nothing.
CssDeclarations _underlineCss(Widget underline) {
  final u = resolveComponent(underline);
  if (u is Container && u.height != null && u.height! > 0) {
    return {
      'border': '0',
      'border-bottom':
          '${cssPx(u.height!)} solid ${(u.color ?? const Color(0xFFBDBDBD)).css}',
    };
  }
  return const {'border': '0'};
}

/// Flutter's `DropdownButtonFormField<T>`: a [DropdownButton] inside the
/// field's decoration, like `TextFormField`: [decoration]'s `labelText` is
/// a visible `<label for>` the `<select>`, and its helper or error line
/// sits below (the select's `aria-describedby`).
///
/// `// web:` the label sits above the border instead of floating inside
/// it. The select's id is [id], else `f-<name>`, else one unique in the
/// page.
class DropdownButtonFormField<T> extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a dropdown inside a decorated form field.
  const DropdownButtonFormField({
    super.key,
    required this.items,
    this.initialValue,
    this.hint,
    this.onChanged = _omittedChange,
    this.decoration,
    this.style,
    this.isExpanded = false,
    this.borderRadius,
    this.isDense,
    this.itemHeight,
    this.name,
    this.id,
    this.valueWatch,
    this.semanticLabel,
    this.boxShadow,
    this.iconSize = 24,
    this.iconEnabledColor,
    this.icon,
    this.iconDisabledColor,
  });

  /// See [DropdownButton.icon].
  final Widget? icon;

  /// See [DropdownButton.iconDisabledColor].
  final Color? iconDisabledColor;

  /// The select's accessible name (`aria-label`) when [decoration] has no
  /// `labelText`; else its hint.
  // web: not in Flutter.
  final String? semanticLabel;

  /// See [DropdownButton.boxShadow].
  final List<BoxShadow>? boxShadow;

  /// See [DropdownButton.iconSize].
  final double iconSize;

  /// See [DropdownButton.iconEnabledColor]. Given, the select's right
  /// padding is not raised to leave room for the system arrow.
  final Color? iconEnabledColor;

  /// Whether the dropdown is shorter (36 px). Null follows
  /// `decoration.isDense` (a 40 px dropdown).
  final bool? isDense;

  /// The dropdown's minimum height (default 48); see
  /// `DropdownButton.itemHeight`.
  ///
  /// `// web:` when the [decoration]'s `contentPadding` has vertical space,
  /// that padding sets the height instead and the minimum is dropped (as in
  /// Flutter), unless an `itemHeight` is given.
  final double? itemHeight;

  /// See [DropdownButton.valueWatch]: the control follows it, also at load
  /// when the field is `local:`.
  final String? Function()? valueWatch;

  /// Entries of the dropdown.
  final List<DropdownMenuItem<T>>? items;

  /// The value selected when the field is first shown.
  final T? initialValue;

  /// Shown while no value is selected.
  final String? hint;

  /// Called with the newly picked value; null disables the field.
  final ValueChanged<T?>? onChanged;

  /// Label, helper and error text around the dropdown.
  final InputDecoration? decoration;

  /// Font and color of the selected item's text.
  final TextStyle? style;

  /// Whether the dropdown fills the field's width (the field itself always
  /// does, as in Flutter).
  final bool isExpanded;

  /// Corner radius of the dropdown.
  final BorderRadius? borderRadius;

  // web: not in Flutter.
  /// Form field name.
  final String? name;

  // web: not in Flutter.
  /// DOM id of the `<select>`.
  final String? id;

  @override
  bool get fillsWidth => true;

  @override
  Widget build(BuildContext context) {
    var d = themedDecoration(context, decoration ?? const InputDecoration());
    if (d.errorText == null && name != null) {
      final error = FormScope.maybeOf(context)?.errorTextOf(name!);
      if (error != null) d = d.copyWith(errorText: error);
    }
    final inputId = decoratedFieldId(context, id, name);
    final hasMessage = d.helperText != null || d.errorText != null;
    final padding = d.contentPadding == null
        ? null
        : _selectPadding(
            numericInsets(d.contentPadding!, 'InputDecoration.contentPadding'),
            ownArrow: iconEnabledColor != null || icon != null,
          );
    final height =
        itemHeight ??
        (padding != null && padding.top + padding.bottom > 0
            ? 0.0
            : isDense == null
            ? (d.isDense ?? false ? 40.0 : 48.0)
            : (isDense! ? 36.0 : 48.0));
    final decorationCss = <String, String>{
      if (padding != null) 'padding': padding.css,
      ...?selectBorderCss(d),
      ...?d.constraints?.toCss(),
      if (d.filled)
        'background-color': (d.fillColor ?? const Color(0x0A000000)).css,
      if ((d.enabledBorder ?? d.border)?.borderRadius case final r?)
        'border-radius': r.css,
    };
    final button = DropdownButton<T>(
      items: items ?? const [],
      value: initialValue,
      onChanged: onChanged,
      hint: hint ?? d.hintText,
      isExpanded: true,
      itemHeight: height,
      name: name,
      id: inputId,
      semanticLabel: d.labelText == null && d.label == null
          ? (semanticLabel ?? hint ?? d.hintText)
          : null,
      style: style,
      boxShadow: boxShadow,
      iconSize: iconSize,
      iconEnabledColor: iconEnabledColor,
      icon: icon,
      iconDisabledColor: iconDisabledColor,
      borderRadius: borderRadius,
      valueWatch: valueWatch,
    );
    final describedBy = hasMessage ? '$inputId-msg' : null;
    return inputDecorator(
      debugName: 'DropdownButtonFormField',
      decoration: d,
      inputId: inputId,
      message: hasMessage,
      field: icon == null
          ? _DescribedSelect<T>(
              describedBy: describedBy,
              invalid: d.errorText != null,
              css: decorationCss,
              child: button,
            )
          : _IconSelect<T>(
              button: button,
              describedBy: describedBy,
              invalid: d.errorText != null,
              css: decorationCss,
            ),
    );
  }
}

/// A [DropdownButton] with an `icon` inside a form field: the decoration's
/// box and `aria-describedby` go on its `<select>`, not on the box around the
/// icon.
class _IconSelect<T> extends StatelessWidget implements ThorBuiltIn {
  const _IconSelect({
    required this.button,
    required this.describedBy,
    required this.invalid,
    required this.css,
  });

  final DropdownButton<T> button;
  final String? describedBy;
  final bool invalid;
  final CssDeclarations css;

  @override
  Widget build(BuildContext context) => button._buildSelect(
    context,
    extraCss: css,
    extraAttributes: {
      'aria-describedby': ?describedBy,
      if (invalid) 'aria-invalid': 'true',
    },
  );
}

/// Puts the message line's `aria-describedby` (and `aria-invalid`) and
/// the decoration's box on the `<select>` itself.
class _DescribedSelect<T> extends ParentDataWrapper {
  const _DescribedSelect({
    required this.describedBy,
    required this.invalid,
    required this.css,
    required super.child,
  });

  final String? describedBy;
  final bool invalid;

  /// The decoration's padding, size, fill and corners on the select.
  final CssDeclarations css;

  @override
  WrapData get wrapData => WrapData(
    css: css,
    attributes: {
      'aria-describedby': ?describedBy,
      if (invalid) 'aria-invalid': 'true',
    },
  );
}

// A plain Text becomes the option's text: the classic <select> parser drops
// any element inside <option> anyway.
Widget _optionContent(Widget child) => switch (resolveComponent(child)) {
  Text(:final data?) => Widget.text(data),
  _ => child,
};

// An `<option>` with [child] as its content. A row's `row.text(…)` (a
// `Watch.list` row text) as the child is bound on the `<option>` itself: the
// browser fills the option's text, and the `<span>` it would draw is gone
// (the select's parser drops any element inside an option).
Widget _option(Map<String, String> attributes, Widget child) {
  var content = child;
  var bound = const <String, String>{};
  if (child is WrapWith) {
    final a = child.wrapData.attributes;
    final only = a.length == 1 && a.containsKey(fieldAttr);
    if (only && resolveComponent(child.child) is Text) {
      bound = a;
      content = child.child;
    }
  }
  return Widget.element(
    tag: 'option',
    attributes: {...attributes, ...bound},
    children: [_optionContent(content)],
  );
}

/// An entry of a [ListBox]: like Flutter's `DropdownMenuItem`, a [value]
/// and what shows it.
///
/// `// web:` no Flutter counterpart, as [ListBox] has none.
class ListBoxItem<T> {
  /// Creates a list box entry.
  const ListBoxItem({
    required this.value,
    required this.child,
    this.enabled = true,
  });

  /// Value the entry represents.
  final T value;

  /// Content of the entry: a `Text` (an `<option>` holds text only).
  final Widget child;

  /// Whether the entry can be chosen (default: true).
  final bool enabled;
}

/// A list of entries always shown, of which one, or several with
/// [multiSelectionEnabled], are chosen: a native `<select size>` (with
/// `multiple`). No JS: the browser gives the keyboard (arrows, Home/End,
/// type-ahead; Shift and Ctrl/Cmd to choose several), and the form sends
/// the chosen values under [name].
///
/// ```dart
/// ListBox<String>(
///   items: const [
///     ListBoxItem(value: 'es', child: Text('Español')),
///     ListBoxItem(value: 'en', child: Text('English')),
///   ],
///   value: settings.language.value,
///   onChanged: settings.setLanguage,        // void setLanguage(String? code)
///   semanticLabel: 'Idioma',
/// )
/// ```
///
/// A list that changes (filtered, added to) and a selection that the state
/// changes too are [ListBox.list].
///
/// `// web:` Flutter has no list box: a list with a selection is a
/// `ListView` of `ListTile(selected:)` rows, each with its own tap. Here it
/// is the browser's control (ARIA's `listbox`, which names it), with the
/// API of `DropdownButton` ([value], [onChanged]) for one value and of
/// `SegmentedButton` ([selected], [onSelectionChanged],
/// [multiSelectionEnabled]) for several. Its entries are text only, like a
/// `DropdownButton`'s.
class ListBox<T> extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a list box over [items].
  const ListBox({
    super.key,
    required List<ListBoxItem<T>> this.items,
    this.value,
    this.onChanged = _omittedChange,
    this.multiSelectionEnabled = false,
    this.selected = const {},
    this.onSelectionChanged = _omittedChange,
    this.visibleItemCount = 4,
    this.name,
    this.id,
    this.semanticLabel,
    this.style,
    this.borderRadius,
  }) : assert(visibleItemCount > 1),
       _rows = null;

  const ListBox._list({
    super.key,
    required this.onChanged,
    required this.multiSelectionEnabled,
    required this.onSelectionChanged,
    required this.visibleItemCount,
    required this.name,
    required this.id,
    required this.semanticLabel,
    required this.style,
    required this.borderRadius,
    required Widget Function(
      Widget Function(List<Widget>) select,
      Set<String>? sent,
    )
    rows,
  }) : items = null,
       value = null,
       selected = const {},
       _rows = rows;

  /// A list box over the items [source] returns (a `ThorState` field's
  /// `call` or a method returning a `List`), kept current in the browser
  /// like a `Watch.list`: an entry per item, its value the item's
  /// [itemKey] and its text [itemLabel] (methods of the state taking the
  /// item).
  ///
  /// The chosen entry is the item whose key is the value of [selected] (a
  /// `state(...)` field of the key's type): the browser marks it when the
  /// state changes, and [onChanged] gets the key the user chose (null when
  /// none is). With [multiSelectionEnabled], an item is chosen while
  /// [isSelected] (a method of the state taking the item) says so, and
  /// [onSelectionChanged] gets every chosen key.
  ///
  /// ```dart
  /// ListBox.list(
  ///   crud.visible.call,
  ///   itemKey: crud.idOf,         // int idOf(Person p)
  ///   itemLabel: crud.label,      // String label(Person p)
  ///   selected: crud.selected,    // final selected = state(0);
  ///   onChanged: crud.select,     // void select(int? id)
  ///   semanticLabel: 'People',
  /// )
  /// ```
  ///
  /// `// web:` no Flutter counterpart (see [ListBox]).
  static ListBox<K> list<I, K extends Object>(
    List<I> Function() source, {
    Key? key,
    required K Function(I item) itemKey,
    required String Function(I item) itemLabel,
    StateSignal<K>? selected,
    bool Function(I item)? isSelected,
    ValueChanged<K?>? onChanged = _omittedChange,
    bool multiSelectionEnabled = false,
    ValueChanged<Set<K>>? onSelectionChanged = _omittedChange,
    int visibleItemCount = 4,
    String? name,
    String? id,
    String? semanticLabel,
    TextStyle? style,
    BorderRadius? borderRadius,
  }) {
    assert(visibleItemCount > 1);
    assert(
      selected == null || isSelected == null,
      'ListBox.list: give the selection as `selected:` (a field) or '
      '`isSelected:` (a method), not both',
    );
    assert(
      !multiSelectionEnabled || selected == null,
      'ListBox.list(multiSelectionEnabled: true) takes `isSelected:` (a '
      'field holds one key)',
    );
    return ListBox<K>._list(
      key: key,
      onChanged: onChanged,
      multiSelectionEnabled: multiSelectionEnabled,
      onSelectionChanged: onSelectionChanged,
      visibleItemCount: visibleItemCount,
      name: name,
      id: id,
      semanticLabel: semanticLabel,
      style: style,
      borderRadius: borderRadius,
      rows: (select, sent) => Watch.list<I, K>(
        source,
        itemKey: itemKey,
        container: select,
        each: (row) {
          final text = row.bindText(itemLabel);
          // A failed form's values choose the rows the server draws (the
          // state's binding stays: its next change patches them); the
          // template keeps every state of the binding.
          final fromForm = row.isTemplate
              ? null
              : sent?.contains(encodeArg(row.key));
          Widget option(bool on) => thorElement(
            'option',
            attributes: {
              'value': encodeArg(row.key),
              if (fromForm ?? on) 'selected': '',
              ...text.attributes,
            },
            children: text.children,
          );
          if (selected != null) {
            return row.selected(selected, builder: option);
          }
          if (isSelected != null) {
            return row.watch<bool>(isSelected, builder: option);
          }
          return option(false);
        },
      ),
    );
  }

  /// Entries of the list (null for [ListBox.list]).
  final List<ListBoxItem<T>>? items;

  /// The chosen value (one selection).
  final T? value;

  /// Called with the value the user chose, or null when none is chosen
  /// (one selection).
  ///
  /// `// web:` optional, like [DropdownButton.onChanged]: left out, the
  /// list is disabled unless it is a named field of a `Form`; `null` on
  /// purpose disables it.
  final ValueChanged<T?>? onChanged;

  /// Whether several entries can be chosen (`multiple`), like
  /// `SegmentedButton.multiSelectionEnabled` (default: false).
  final bool multiSelectionEnabled;

  /// The chosen values (with [multiSelectionEnabled]).
  final Set<T> selected;

  /// Called with every chosen value when the user changes the selection
  /// (with [multiSelectionEnabled]). Optional like [onChanged].
  final ValueChanged<Set<T>>? onSelectionChanged;

  /// How many entries show at once; the rest scroll (default: 4, at least
  /// 2).
  ///
  /// `// web:` the `<select>`'s `size`. A height from the parent (an
  /// `Expanded`, a `SizedBox`) wins over it.
  final int visibleItemCount;

  // web: not in Flutter.
  /// Form field name (repeated once per chosen value with
  /// [multiSelectionEnabled]).
  final String? name;

  // web: not in Flutter.
  /// DOM id of the `<select>`, so a `<label for>` names it; without it or
  /// [semanticLabel] the list has no accessible name.
  final String? id;

  /// Accessible label for the list.
  final String? semanticLabel;

  /// Font and color of the entries.
  final TextStyle? style;

  /// Corner radius of the list.
  final BorderRadius? borderRadius;

  final Widget Function(
    Widget Function(List<Widget>) select,
    Set<String>? sent,
  )?
  _rows;

  @override
  Widget build(BuildContext context) {
    final handler = multiSelectionEnabled ? onSelectionChanged : onChanged;
    final enabled = _fieldEnabled(context, name, handler);
    final form = _Fielded(context, name, enabled);
    final scope = form.scope;
    // A form that decides the field says which entries are chosen, else
    // the widget's own value does.
    final sent = name != null && scope != null && scope.decides(name!)
        ? scope.valuesOf(name!).toSet()
        : null;
    bool chosen(T v) => sent != null
        ? sent.contains(encodeArg(v))
        : multiSelectionEnabled
        ? selected.contains(v)
        : v == value;
    // The ListTile's colors of a selected row, from the theme.
    final tile = Theme.of(context).listTileTheme;
    Widget select(List<Widget> options) => thorElement(
      'select',
      debugName: 'ListBox',
      baseCss: const {'margin': '0', 'font': 'inherit', 'color': 'inherit'},
      css: {
        'box-sizing': 'border-box',
        'min-width': '0',
        'padding': '4px 0',
        'border': '1px solid $_outline',
        'border-radius': borderRadius?.css ?? '4px',
        'background-color': 'transparent',
        'overflow-y': 'auto',
        'accent-color': _primary,
        ...?style?.toCss(),
      },
      conditions: [
        const ConditionalCss(CssCondition.focused, {
          'outline': '2px solid $_primary',
          'outline-offset': '-1px',
        }),
        const ConditionalCss(CssCondition.disabled, {
          'cursor': 'default',
          'opacity': '0.38',
        }),
        const ConditionalCss(CssCondition.selector(' > option'), {
          'padding': '4px 16px',
          'cursor': 'pointer',
        }),
        ConditionalCss(const CssCondition.selector(' > option:checked'), {
          'background-color':
              tile?.selectedTileColor?.css ?? ThemeTokens.secondaryContainer,
          'color': tile?.selectedColor?.css ?? ThemeTokens.onSecondaryContainer,
        }),
        // web: under forced colors the chosen entries keep the system's
        // selection colors (an author fill would be repainted as Canvas).
        ConditionalCss(
          CssCondition.both(
            CssCondition.forcedColors,
            const CssCondition.selector(' > option:checked'),
          ),
          const {
            'forced-color-adjust': 'none',
            'background-color': 'Highlight',
            'color': 'HighlightText',
          },
        ),
      ],
      attributes: {
        'size': '$visibleItemCount',
        if (multiSelectionEnabled) 'multiple': '',
        if (!enabled) 'disabled': '',
        ...form.attributes,
        'id': ?id,
        'name': ?name,
        'aria-label': ?semanticLabel,
        ...engineAttributes({'change': handler}),
      },
      children: options,
    );
    final rows = _rows;
    if (rows != null) return rows(select, sent);
    return select([
      for (final item in items!)
        _option({
          'value': encodeArg(item.value),
          if (chosen(item.value)) 'selected': '',
          if (!item.enabled) 'disabled': '',
        }, item.child),
    ]);
  }
}

/// Where the control sits in a `*ListTile` (Flutter's
/// `ListTileControlAffinity`).
enum ListTileControlAffinity {
  /// The control before the title.
  leading,

  /// The control after the title.
  trailing,

  /// The platform default; web: as Material, the control after the title
  /// (same as `trailing`).
  platform,
}

/// Shared row of the `*ListTile` controls: a `<label>` wrapping the input,
/// so the whole row toggles it natively (no JS, no extra handlers).
Widget _controlTile({
  required String debugName,
  required Widget control,
  required Widget? title,
  required Widget? subtitle,
  required ListTileControlAffinity affinity,
  required bool enabled,
  Widget? secondary,
  Color? hoverColor,
}) {
  final leading = affinity == ListTileControlAffinity.leading;
  const titleCss = {'font-size': '16px', 'line-height': '24px'};
  const subtitleCss = {
    'font-size': '14px',
    'line-height': '20px',
    'color': ThemeTokens.onSurfaceVariant,
  };
  // A plain Text title alone is the label's own text (an anonymous flex
  // item: no element at all), like `<label><input> Sonido</label>`.
  final titleText = resolveComponent(title);
  final plain = subtitle == null && secondary == null && titleText is Text
      ? titleText.boxContentCss
      : null;
  if (plain != null) {
    return thorElement(
      'label',
      debugName: debugName,
      fillsWidth: true,
      css: {
        ..._tileCss(enabled),
        if (!leading) 'justify-content': 'space-between',
        ...titleCss,
        ...plain,
      },
      conditions: enabled ? _tileHover(hoverColor) : const [],
      children: leading
          ? [control, Widget.text((titleText! as Text).data!)]
          : [Widget.text((titleText! as Text).data!), control],
    );
  }
  // Otherwise the texts style their own elements (no wrapper spans): a
  // title alone is one flex item; with a subtitle, one column holding both.
  final Widget text = subtitle == null
      ? WrapWith(
          const WrapData(css: {...titleCss, 'flex': '1 1 0'}),
          child: title ?? const Widget.fragment([]),
        )
      : thorElement(
          'span',
          css: const {...boxCss, 'flex': '1 1 0', 'gap': '2px'},
          children: [
            if (title != null)
              WrapWith(const WrapData(css: titleCss), child: title),
            WrapWith(const WrapData(css: subtitleCss), child: subtitle),
          ],
        );
  final extra = secondary == null
      ? null
      : WrapWith(
          // A default, under the secondary's own color (Flutter: an icon's
          // `color` beats the tile's icon theme).
          const WrapData(
            baseCss: {'color': ThemeTokens.onSurfaceVariant},
            // web: outside the <label>, a press on a secondary that does
            // nothing by itself must still toggle the tile (Flutter: the
            // whole ListTile is the target). The label's overlay covers
            // the row; the secondary lets presses through to it, except
            // what is interactive (a button, a switch, a link).
            css: {
              'position': 'relative',
              'z-index': '1',
              'pointer-events': 'none',
            },
            conditions: [
              ConditionalCss(CssCondition.selector(_interactive), _pressable),
              ConditionalCss(
                CssCondition.selector(' $_interactive'),
                _pressable,
              ),
            ],
          ),
          child: secondary,
        );
  if (extra == null) {
    return thorElement(
      'label',
      debugName: debugName,
      fillsWidth: true,
      css: _tileCss(enabled),
      conditions: enabled ? _tileHover(hoverColor) : const [],
      children: leading ? [control, text] : [text, control],
    );
  }
  // web: the secondary sits outside the <label>, as its sibling in the row
  // (MUI's `secondaryAction` lives outside its `ListItemButton` too). HTML's
  // label content model forbids labelable descendants other than the
  // labeled control (an IconButton inside would rename the checkbox and
  // a click on it could toggle it). The row holds the tile's box and the
  // label keeps the control and the texts; the secondary sits opposite the
  // control (Flutter's ListTile `leading`/`trailing` colors:
  // on-surface-variant).
  final label = thorElement(
    'label',
    css: {
      'display': 'flex',
      'align-items': 'center',
      'gap': '16px',
      'flex': '1 1 0',
      'min-width': '0',
      'cursor': enabled ? 'pointer' : 'default',
    },
    conditions: [
      // The label's press area is the whole row (its padding, the gaps and
      // the secondary included), like the single <label> tile.
      ConditionalCss(const CssCondition.selector('::after'), {
        'content': '""',
        'position': 'absolute',
        'inset': '0',
        'cursor': enabled ? 'pointer' : 'default',
      }),
      // The control and the texts paint above the overlay, so a press on
      // them (or a test's `check()`) lands on them, not on the overlay.
      const ConditionalCss(CssCondition.children, {
        'position': 'relative',
        'z-index': '1',
      }),
    ],
    children: leading ? [control, text] : [text, control],
  );
  return thorElement(
    'div',
    debugName: debugName,
    fillsWidth: true,
    css: {..._tileCss(enabled), 'cursor': 'default', 'position': 'relative'},
    conditions: enabled ? _tileHover(hoverColor) : const [],
    children: leading ? [label, extra] : [extra, label],
  );
}

const _interactive =
    ':is(button,a[href],input,select,textarea,summary,label,[tabindex],'
    '[role=button],[popovertarget],[contenteditable])';
const _pressable = {'pointer-events': 'auto'};

CssDeclarations _tileCss(bool enabled) => {
  'display': 'flex',
  'align-items': 'center',
  'gap': '16px',
  'min-height': '56px',
  'padding': '8px 24px 8px 16px',
  'box-sizing': 'border-box',
  'color': _onSurface,
  'cursor': enabled ? 'pointer' : 'default',
  if (!enabled) 'opacity': '0.38',
};

List<ConditionalCss> _tileHover(Color? color) => [
  ConditionalCss(CssCondition.hover, {
    'background-color':
        color?.css ??
        'color-mix(in srgb, ${ThemeTokens.onSurface} 8%, transparent)',
  }),
];

/// Flutter's `CheckboxListTile`.
class CheckboxListTile extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a list tile with a checkbox.
  const CheckboxListTile({
    super.key,
    required this.value,
    this.onChanged = _omittedChange,
    this.title,
    this.subtitle,
    this.secondary,
    this.tristate = false,
    this.controlAffinity = ListTileControlAffinity.platform,
    this.name,
    this.hoverColor,
  });

  /// Checked state; `null` (with `tristate`) is indeterminate.
  final bool? value;

  /// Called with the new value when toggled.
  final ValueChanged<bool?>? onChanged;

  /// Primary content of the tile.
  final Widget? title;

  /// Secondary content shown below the title.
  final Widget? subtitle;

  /// A widget on the opposite side of the tile from the control (Flutter's
  /// `secondary`, e.g. an icon or avatar). `// web:` colored on-surface-variant.
  final Widget? secondary;

  /// Whether `value` can be `null` (Flutter's default: false).
  final bool tristate;

  /// Where the checkbox sits relative to the title.
  final ListTileControlAffinity controlAffinity;

  // web: not in Flutter.
  /// Form field name.
  final String? name;

  /// The row's fill under the pointer (default: on-surface at 8 %).
  /// `Colors.transparent` removes the layer.
  final Color? hoverColor;

  @override
  bool get fillsWidth => true;

  @override
  Widget build(BuildContext context) => _controlTile(
    debugName: 'CheckboxListTile',
    control: Checkbox(
      stateLayer: false,
      value: value,
      onChanged: onChanged,
      tristate: tristate,
      name: name,
    ),
    title: title,
    secondary: secondary,
    subtitle: subtitle,
    affinity: controlAffinity,
    hoverColor: hoverColor,
    enabled: _fieldEnabled(context, name, onChanged),
  );
}

/// Flutter's `SwitchListTile`.
class SwitchListTile extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a list tile with a switch.
  const SwitchListTile({
    super.key,
    required this.value,
    this.onChanged = _omittedChange,
    this.title,
    this.subtitle,
    this.secondary,
    this.controlAffinity = ListTileControlAffinity.platform,
    this.name,
    this.hoverColor,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the new value when toggled.
  final ValueChanged<bool>? onChanged;

  /// Primary content of the tile.
  final Widget? title;

  /// Secondary content shown below the title.
  final Widget? subtitle;

  /// A widget on the opposite side of the tile from the control (Flutter's
  /// `secondary`, e.g. an icon or avatar). `// web:` colored on-surface-variant.
  final Widget? secondary;

  /// Where the switch sits relative to the title.
  final ListTileControlAffinity controlAffinity;

  // web: not in Flutter.
  /// Form field name.
  final String? name;

  /// The row's fill under the pointer (default: on-surface at 8 %).
  /// `Colors.transparent` removes the layer.
  final Color? hoverColor;

  @override
  bool get fillsWidth => true;

  @override
  Widget build(BuildContext context) => _controlTile(
    debugName: 'SwitchListTile',
    control: Switch(
      stateLayer: false,
      value: value,
      onChanged: onChanged,
      name: name,
    ),
    title: title,
    secondary: secondary,
    subtitle: subtitle,
    affinity: controlAffinity,
    hoverColor: hoverColor,
    enabled: _fieldEnabled(context, name, onChanged),
  );
}

/// Flutter's `RadioListTile<T>`.
class RadioListTile<T> extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a list tile with a radio button.
  const RadioListTile({
    super.key,
    required this.value,
    @Deprecated(
      'Use a RadioGroup ancestor to manage the group value instead, like '
      'Flutter (deprecated after v3.32).',
    )
    this.groupValue,
    @Deprecated(
      'Use RadioGroup(onChanged:) to handle the change instead, like '
      'Flutter (deprecated after v3.32).',
    )
    this.onChanged,
    this.title,
    this.subtitle,
    this.secondary,
    this.controlAffinity = ListTileControlAffinity.platform,
    this.name,
    this.hoverColor,
  });

  /// The value this radio represents.
  final T value;

  /// The currently selected value of the group.
  @Deprecated(
    'Use a RadioGroup ancestor to manage the group value instead, like '
    'Flutter (deprecated after v3.32).',
  )
  final T? groupValue;

  /// Called with `value` when this radio is selected.
  @Deprecated(
    'Use RadioGroup(onChanged:) to handle the change instead, like '
    'Flutter (deprecated after v3.32).',
  )
  final ValueChanged<T?>? onChanged;

  /// Primary content of the tile.
  final Widget? title;

  /// Secondary content shown below the title.
  final Widget? subtitle;

  /// A widget on the opposite side of the tile from the control (Flutter's
  /// `secondary`, e.g. an icon or avatar). `// web:` colored on-surface-variant.
  final Widget? secondary;

  /// Where the radio sits relative to the title.
  final ListTileControlAffinity controlAffinity;

  // web: not in Flutter.
  /// Form field name.
  final String? name;

  /// The row's fill under the pointer (default: on-surface at 8 %).
  /// `Colors.transparent` removes the layer.
  final Color? hoverColor;

  @override
  bool get fillsWidth => true;

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use_from_same_package
    final own = onChanged;
    final group = RadioGroup.maybeOf<T>(context);
    final enabled = _fieldEnabled(
      context,
      name ?? group?.name,
      own ?? group?.onChanged,
    );
    return _controlTile(
      debugName: 'RadioListTile',
      control: Radio<T>(
        stateLayer: false,
        value: value,
        // ignore: deprecated_member_use_from_same_package
        groupValue: groupValue,
        // ignore: deprecated_member_use_from_same_package
        onChanged: own,
        name: name,
      ),
      title: title,
      secondary: secondary,
      subtitle: subtitle,
      affinity: controlAffinity,
      hoverColor: hoverColor,
      enabled: enabled,
    );
  }
}

// A select keeps room on the right for the browser's arrow.
// (unless the select draws its own arrow, which takes what the app gives).
EdgeInsets _selectPadding(EdgeInsets p, {bool ownArrow = false}) =>
    EdgeInsets.fromLTRB(
      p.left,
      p.top,
      !ownArrow && p.right < 36 ? 36 : p.right,
      p.bottom,
    );

// ---------------------------------------------------------------------------
// SegmentedButton.

/// What a `SegmentedButton` with no `onSelectionChanged` holds.
///
/// web: Flutter disables the control when the callback is null; here an
/// omitted one keeps it enabled (the native inputs keep the choice and the
/// page's CSS reads it, with no JS), and only an explicit `null` disables.
void _omittedSelection(Set<Object?> _) {}

void _ignoreChange(Object? _) {}

const _secondaryContainer = 'var(--t-secondary-container, #e8def8)';
const _onSecondaryContainer = 'var(--t-on-secondary-container, #1d192b)';

/// The invisible native input laid over a whole segment.
const _segmentInputCss = <String, String>{
  'appearance': 'none',
  'position': 'absolute',
  'inset': '0',
  'width': '100%',
  'height': '100%',
  'margin': '0',
  'opacity': '0',
  'cursor': 'pointer',
};

/// Flutter's `ButtonSegment<T>`: one choice of a [SegmentedButton].
///
/// ```dart
/// ButtonSegment(value: View.list, icon: Icon(Icons.list), label: Text('List'))
/// ```
class ButtonSegment<T> {
  /// A segment that stands for [value]. It needs an [icon], a [label] or
  /// both; give an icon-only segment a [tooltip], its accessible name.
  const ButtonSegment({
    required this.value,
    this.icon,
    this.label,
    this.tooltip,
    this.enabled = true,
  }) : assert(
         icon != null || label != null,
         'A segment needs an icon or a label.',
       );

  /// What the selection holds when this segment is chosen.
  final T value;

  /// The icon, before the [label].
  final Widget? icon;

  /// The visible text (usually a `Text`).
  final Widget? label;

  /// The segment's `title` and, for an icon-only segment, its accessible
  /// name.
  final String? tooltip;

  /// Whether the segment can be chosen.
  final bool enabled;
}

/// Flutter's `SegmentedButton<T>`: a row of [segments] to choose one value
/// (or several) from.
///
/// ```dart
/// SegmentedButton<View>(
///   segments: const [
///     ButtonSegment(value: View.list, label: Text('List')),
///     ButtonSegment(value: View.grid, label: Text('Grid')),
///   ],
///   selected: const {View.list},
///   onSelectionChanged: browse.setView, // a ThorState method taking Set<View>
/// )
/// ```
///
/// Like Flutter: [selected] is the chosen values, [onSelectionChanged]
/// receives the set the person picks, and `onSelectionChanged: null`
/// disables the control.
///
/// `// web:` the segments are native inputs (no JavaScript needed to choose):
/// a radio group, or checkboxes with [multiSelectionEnabled]. The keys
/// (arrow keys in a radio group, Space in checkboxes), focus, form value and
/// screen reader names are the browser's. A radio cannot be unchecked, so
/// [emptySelectionAllowed] only means that [selected] may start empty, and
/// with [multiSelectionEnabled] the last checked segment can still be
/// unchecked. Because the browser holds the choice, [selected] is the value
/// the page is drawn with; the state's handler receives the new set when
/// the person picks (for a radio group the browser sends one value, for
/// checkboxes all the checked ones). A control with no `onSelectionChanged`
/// argument at all is not disabled: the browser keeps the choice and the
/// page's CSS reads it.
///
/// `// web:` Flutter's `ButtonStyle` holds `WidgetStateProperty`s; here
/// [style] is the look of every segment and [selectedStyle] the look of a
/// chosen one.
class SegmentedButton<T> extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// A control over [segments] whose chosen ones are in [selected].
  const SegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    this.onSelectionChanged = _omittedSelection,
    this.multiSelectionEnabled = false,
    this.emptySelectionAllowed = false,
    this.showSelectedIcon = true,
    this.selectedIcon,
    this.style,
    this.selectedStyle,
    this.direction = Axis.horizontal,
    this.expandedInsets,
    this.groupPadding,
    this.groupColor,
    this.name,
    this.semanticLabel,
    this.selectedWatch,
  }) : assert(
         selectedWatch == null || !multiSelectionEnabled,
         'selectedWatch follows a single choice (a radio group).',
       );

  /// The text of the chosen segment's value, kept current in the browser: a
  /// method of the state returning it (an enum's name, a number as text),
  /// torn off or with `withArg`. The segments follow it when it changes
  /// without a rebuild, and at load when the field is `local:`. [selected]
  /// stays what the server draws. Single choice only.
  ///
  /// `// web:` no Flutter counterpart (Flutter rebuilds with a new
  /// [selected]).
  final String? Function()? selectedWatch;

  /// The choices, in order.
  final List<ButtonSegment<T>> segments;

  /// The chosen values when the page is drawn.
  final Set<T> selected;

  /// Called with the set the person picks (a `ThorState` method taking a
  /// `Set<T>`); `null` disables the control; left out, the browser just
  /// keeps the choice.
  final ValueChanged<Set<T>>? onSelectionChanged;

  /// Whether several segments can be chosen at once (checkboxes).
  final bool multiSelectionEnabled;

  /// Whether [selected] may be empty.
  final bool emptySelectionAllowed;

  /// Whether a chosen segment shows a check mark before its content.
  final bool showSelectedIcon;

  /// The check mark of a chosen segment (default: a check icon).
  final Widget? selectedIcon;

  /// The look of the control: colors, padding and minimum size of every
  /// segment, and, as in Flutter, [ButtonStyle.side] and
  /// [ButtonStyle.shape] for the group as a whole (its outline, the
  /// dividers between segments and its corners).
  final ButtonStyle? style;

  /// `// web:` not in Flutter: what changes in a chosen segment (all of
  /// [ButtonStyle], also its `shape`, the corners of that segment).
  final ButtonStyle? selectedStyle;

  /// `// web:` not in Flutter: space between the group's outline and its
  /// segments (a rail the chosen segment sits in).
  final EdgeInsetsGeometry? groupPadding;

  /// `// web:` not in Flutter: the fill behind the segments.
  final Color? groupColor;

  /// The axis the segments line up in.
  final Axis direction;

  /// Fills the width it is given, with these insets around it.
  final EdgeInsets? expandedInsets;

  /// The native group name: the form field name, and what CSS elsewhere
  /// reads (`:root:has(input[name="..."]:checked)`).
  ///
  /// `// web:` not in Flutter.
  final String? name;

  /// The group's accessible name (`aria-label`): what the segments choose.
  ///
  /// `// web:` not in Flutter.
  final String? semanticLabel;

  static var _generated = 0;

  @override
  Widget build(BuildContext context) {
    assert(segments.length > 1, 'A segmented button needs two or more.');
    assert(
      multiSelectionEnabled || selected.length <= 1,
      'Several selected values need multiSelectionEnabled.',
    );
    assert(
      emptySelectionAllowed || selected.isNotEmpty,
      'An empty selection needs emptySelectionAllowed.',
    );
    final omitted = identical(onSelectionChanged, _omittedSelection);
    final disabled = !omitted && onSelectionChanged == null;
    final setHandler = !omitted && !disabled ? onSelectionChanged : null;
    final vertical = direction == Axis.vertical;
    final expanded = expandedInsets != null;
    final groupName =
        name ??
        (multiSelectionEnabled
            ? ThorStyleRegistry.active(context)?.uniqueId('t-sb') ??
                  't-sb${++_generated}'
            : null);
    final side = style?.plainSide ?? style?.plainShape?.side;
    final noSide = style?.dropsSide ?? false;
    final group = thorElement(
      'div',
      debugName: 'SegmentedButton',
      css: {
        'display': expanded ? 'flex' : 'inline-flex',
        'flex-direction': vertical ? 'column' : 'row',
        'max-width': '100%',
        'box-sizing': 'border-box',
        'overflow': 'hidden',
        // The group's outline and corners are the style's `side` and `shape`.
        'border': noSide
            ? '0'
            : side == null || side == BorderSide.none
            ? '1px solid $_outline'
            : side.css,
        'border-radius': style?.plainShape?.radiusCss ?? '20px',
        ...?groupPadding?.resolve(TextDirection.ltr).toCss('padding'),
        'background-color': ?groupColor?.css,
        if (expanded) 'width': '100%',
        if (expandedInsets case final i?) ...i.toCss('margin'),
        if (disabled) 'cursor': 'default',
      },
      attributes: {
        'role': multiSelectionEnabled ? 'group' : 'radiogroup',
        'aria-label': ?semanticLabel,
        if (disabled) 'aria-disabled': 'true',
      },
      children: [
        for (var i = 0; i < segments.length; i++)
          _Segment<T>(
            segment: segments[i],
            first: i == 0,
            checked: selected.contains(segments[i].value),
            multi: multiSelectionEnabled,
            groupName: groupName,
            handler: setHandler,
            disabled: disabled,
            owner: this,
            divider: noSide
                ? null
                : side == null || side == BorderSide.none
                ? '1px solid $_outline'
                : side.css,
          ),
      ],
    );
    if (multiSelectionEnabled) return group;
    final watch = selectedWatch;
    return RadioGroup<T>(
      groupValue: selected.isEmpty ? null : selected.first,
      name: name,
      onChanged: disabled ? null : _ignoreChange,
      onSelectionChanged: setHandler,
      // web: the group's `value` is not an attribute of a `<div>`; the engine
      // checks the radio with that value.
      child: watch == null ? group : watchControlValue(watch, child: group),
    );
  }
}

class _Segment<T> extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  const _Segment({
    required this.segment,
    required this.first,
    required this.checked,
    required this.multi,
    required this.groupName,
    required this.handler,
    required this.disabled,
    required this.owner,
    required this.divider,
  });

  /// The line between this segment and the one before (`null`: none).
  final String? divider;

  final ButtonSegment<T> segment;
  final bool first;
  final bool checked;
  final bool multi;
  final String? groupName;
  final ValueChanged<Set<T>>? handler;
  final bool disabled;
  final SegmentedButton<T> owner;

  @override
  Widget build(BuildContext context) {
    final style = owner.style;
    final selectedStyle = owner.selectedStyle;
    final vertical = owner.direction == Axis.vertical;
    final label = segment.label;
    final off = disabled || !segment.enabled;
    final named = _namesItself(label);
    assert(() {
      if (!named && segment.tooltip == null) {
        throw StateError(
          thorError(
            'THOR-R038',
            'a segment of `SegmentedButton` has no accessible name: its '
                'label is not a `Text` (nor a `Semantics(label:)` or an '
                '`Icon(semanticLabel:)`) and it has no `tooltip`, so the '
                'radio would be announced without a name. Give the segment '
                'a `tooltip: \'Name\'` (or a `Text` label).',
          ),
        );
      }
      return true;
    }());
    // A segment whose label names it is named by it (the input is inside
    // the `<label>`); any other one (icon only, an unnamed widget) by its
    // tooltip.
    final name = named ? null : segment.tooltip;
    final input = multi
        ? _SegmentCheckbox<T>(
            value: segment.value,
            checked: checked,
            name: groupName,
            handler: handler,
            disabled: off,
            semanticLabel: name,
          )
        : Radio<T>._overlay(
            value: segment.value,
            semanticLabel: name,
            disabled: off,
          );
    final showCheck = owner.showSelectedIcon;
    return thorElement(
      'label',
      debugName: 'ButtonSegment',
      css: {
        'position': 'relative',
        'display': 'inline-flex',
        // web: Flutter gives every segment the same width; a basis of 0 makes
        // the free space the only thing that sizes them (a long label does not
        // widen its own). A `Text(overflow: TextOverflow.ellipsis)` label
        // is cut with dots when the group is narrower than the labels.
        'flex': '1 1 0',
        'align-items': 'center',
        'justify-content': 'center',
        'gap': '8px',
        'box-sizing': 'border-box',
        'min-width': '0',
        'min-height': '40px',
        'padding': '0 12px',
        'cursor': 'pointer',
        'user-select': 'none',
        'color': _onSurface,
        'background-color': 'transparent',
        'font-size': '14px',
        'font-weight': '500',
        'line-height': '20px',
        'letter-spacing': '0.1px',
        'transition-property': 'background-color, color',
        'transition-duration': '150ms',
        if (!first && divider != null)
          if (vertical)
            'border-top': divider!
          else
            'border-inline-start': divider!,
        // web: `side` and `shape` of `style` belong to the group, not to each
        // segment.
        ...?style == null ? null : _withoutBox(buttonStyleCss(style)),
      },
      conditions: [
        if (!off)
          const ConditionalCss(CssCondition.selector(':hover'), {
            'background-color':
                'color-mix(in srgb, $_onSurface 8%, transparent)',
          }),
        ConditionalCss(const CssCondition.selector(':has(:checked)'), {
          'background-color': _secondaryContainer,
          'color': _onSecondaryContainer,
          ...?selectedStyle == null ? null : buttonStyleCss(selectedStyle),
        }),
        const ConditionalCss(CssCondition.selector(':has(:focus-visible)'), {
          'outline': '2px solid $_primary',
          'outline-offset': '-2px',
        }),
        const ConditionalCss(CssCondition.selector(':has(:disabled)'), {
          'cursor': 'default',
          'opacity': '0.38',
        }),
        if (showCheck)
          const ConditionalCss(
            CssCondition.selector(':has(:checked) > [data-t-seg-check]'),
            {'display': 'inline-flex'},
          ),
        if (showCheck && segment.icon != null)
          const ConditionalCss(
            CssCondition.selector(':has(:checked) > [data-t-seg-icon]'),
            {'display': 'none'},
          ),
      ],
      attributes: {'title': ?segment.tooltip},
      children: [
        input,
        if (showCheck)
          thorElement(
            'span',
            debugName: 'ButtonSegment check',
            css: const {'display': 'none', 'align-items': 'center'},
            attributes: const {'data-t-seg-check': '', 'aria-hidden': 'true'},
            children: [owner.selectedIcon ?? const Icon(Icons.check, size: 18)],
          ),
        if (segment.icon case final icon?)
          thorElement(
            'span',
            debugName: 'ButtonSegment icon',
            css: const {'display': 'inline-flex', 'align-items': 'center'},
            attributes: const {'data-t-seg-icon': '', 'aria-hidden': 'true'},
            children: [icon],
          ),
        ?label,
      ],
    );
  }
}

/// [css] without the outline and corners, which belong to the whole group.
CssDeclarations _withoutBox(CssDeclarations css) => {
  for (final e in css.entries)
    if (e.key != 'border' && e.key != 'border-radius') e.key: e.value,
};

/// Whether a segment's [label] gives the `<label>` around its input a
/// name: a `Text` (also built by an app component), a `Semantics(label:)`
/// or an `Icon(semanticLabel:)`, also under `Styled`/`Padding`-like wrappers
/// and app components. The segment's own icon is `aria-hidden`.
bool _namesItself(Widget? label) => switch (resolveComponent(label)) {
  Text() => true,
  Semantics(:final label?) when label.isNotEmpty => true,
  Icon(:final semanticLabel?) => semanticLabel.isNotEmpty,
  ParentDataWrapper(:final child) => _namesItself(child),
  _ => false,
};

/// A checkbox laid invisibly over a segment of a multi-selection
/// `SegmentedButton`. Its change reports all the checked segments of the
/// group (`data-t-set`), joined with U+001F, which the page parses into a
/// `Set`.
class _SegmentCheckbox<T> extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  const _SegmentCheckbox({
    required this.value,
    required this.checked,
    required this.name,
    required this.handler,
    required this.disabled,
    this.semanticLabel,
  });

  final T value;
  final bool checked;
  final String? name;
  final ValueChanged<Set<T>>? handler;
  final bool disabled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => thorElement(
    'input',
    debugName: 'SegmentCheckbox',
    css: _segmentInputCss,
    attributes: {
      'type': 'checkbox',
      if (checked) 'checked': '',
      if (disabled) 'disabled': '',
      'name': ?name,
      'value': encodeArg(value),
      'aria-label': ?semanticLabel,
      if (handler != null) 'data-t-set': name ?? '',
      ...engineAttributes({'change': handler}),
    },
  );
}
