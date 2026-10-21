import 'package:thor_engine/thor_engine.dart' show ConfirmSpec;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../engine/watch.dart' show engineAttributes;
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/parent_data.dart' show ParentDataWrapper;
import '../foundation/request_scope.dart';
import '../foundation/style_registry.dart';
import '../foundation/theme_tokens.dart';
import '../foundation/transparent.dart';
import '../foundation/widget_state.dart';
import '../router/page_actions.dart'
    show PagePost, PageValidPost, submitAttributes;
import 'effects.dart' show SemanticsButton;
import 'feedback.dart' show confirmSubmitAttributes;
import 'flex.dart' show Flex, Flexible, Row, Spacer;
import 'form.dart' show InsideForm;
import 'text.dart' show Text;
import 'theme.dart' show ThemeData, Theme;

const _buttonBase = <String, String>{
  'appearance': 'none',
  'border': '0',
  'margin': '0',
  'font': 'inherit',
  'font-size': ThemeTokens.labelLargeSize,
  'font-weight': ThemeTokens.labelLargeWeight,
  'letter-spacing': 'var(--t-label-large-tracking, 0.1px)',
  'line-height': ThemeTokens.labelLargeLine,
  'display': 'inline-flex',
  'align-items': 'center',
  'justify-content': 'center',
  'gap': '8px',
  'box-sizing': 'border-box',
  'min-height': '40px',
  'padding': '10px 24px',
  'border-radius': '20px',
  'cursor': 'pointer',
  'transition-property': 'background-color, box-shadow',
  'transition-duration': '150ms',
};

/// Flutter's `ButtonStyle`: overrides the variant's colors, spacing, size,
/// shape and text. Each field is a [WidgetStateProperty], so a value can
/// depend on the button's state (`WidgetStateProperty.resolveWith`); for plain
/// values use `FilledButton.styleFrom(...)` and its siblings.
///
/// ```dart
/// ButtonStyle(
///   backgroundColor: WidgetStateProperty.resolveWith((states) =>
///       states.contains(WidgetState.hovered) ? Colors.teal : null),
/// )
/// ```
///
/// `// web:` the server asks the property for each state the browser can
/// tell (`hovered` → `:hover`, `focused` → `:focus-visible`, `pressed` →
/// `:active`, `selected` → `aria-pressed` / `aria-selected`, `disabled` →
/// `:disabled` or `aria-disabled="true"`) and writes the ones that differ
/// from the base value as conditions of the button's one class; the
/// browser computes nothing. A
/// value that depends on a *combination* of states (hovered and focused)
/// gets the single-state values; `backgroundColor`, `foregroundColor`,
/// `side` and `overlayColor` change by state, the rest are resolved without
/// states.
class ButtonStyle {
  /// A style; null fields keep the variant's default.
  const ButtonStyle({
    this.textStyle,
    this.backgroundColor,
    this.foregroundColor,
    this.overlayColor,
    this.padding,
    this.minimumSize,
    this.fixedSize,
    this.side,
    this.shape,
    this.alignment,
    this.animationDuration,
    this.iconSize,
    this.elevation,
    this.shadowColor,
    this.shadows,
  });

  /// Font of the label.
  final WidgetStateProperty<TextStyle?>? textStyle;

  /// Fill.
  final WidgetStateProperty<Color?>? backgroundColor;

  /// Text and icon color.
  final WidgetStateProperty<Color?>? foregroundColor;

  /// The state layer: the fill while hovered (`hovered`) and pressed
  /// (`pressed`).
  final WidgetStateProperty<Color?>? overlayColor;

  /// Inner spacing.
  final WidgetStateProperty<EdgeInsetsGeometry?>? padding;

  /// Smallest size (a dimension of 0 leaves it free).
  final WidgetStateProperty<Size?>? minimumSize;

  /// Exact size (Flutter's `ButtonStyle.fixedSize`): a dimension that is
  /// finite becomes the button's `width` or `height`; `double.infinity`
  /// leaves it free. Wins over [minimumSize].
  final WidgetStateProperty<Size?>? fixedSize;

  /// Outline (wins over the shape's side).
  final WidgetStateProperty<BorderSide?>? side;

  /// Corner shape (and its outline).
  final WidgetStateProperty<OutlinedBorder?>? shape;

  /// Where the label sits when the button is wider than it (Flutter's
  /// `ButtonStyle.alignment`), e.g. `Alignment.centerLeft` for a menu row.
  final Alignment? alignment;

  /// How long a change of the button's look takes (Flutter's
  /// `ButtonStyle.animationDuration`): its fill, text color, outline,
  /// shadow and opacity move to the new values instead of jumping, e.g.
  /// when a `Watch` swaps a `FilledButton` for an `OutlinedButton` or
  /// disables it. Instant under reduced motion. Null keeps the default
  /// (the fill and shadow only, 150ms).
  final Duration? animationDuration;

  /// Side of the icon inside the button (Flutter's `ButtonStyle.iconSize`).
  /// `IconButton` reads it when its own `iconSize` is null; so does the arrow
  /// of `CarouselView(arrowStyle:)`, whose glyph is an image of this size
  /// (default: half the arrow).
  final WidgetStateProperty<double?>? iconSize;

  /// How far the button is raised (Flutter's `ButtonStyle.elevation`), as
  /// its shadow: 0 is none. Like Flutter's Material 3, the dp maps to a
  /// level of two shadow layers (1, 3, 6, 8 and 12 dp are levels 1 to 5; the
  /// nearest, the higher on a tie). A state value (`hovered`, `pressed`,
  /// `disabled`) replaces it in that state.
  ///
  /// `// web:` Flutter's `ButtonStyle` has no `boxShadow`; for an exact
  /// custom shadow such as `0 1px 2px` use the web-only [shadows].
  final WidgetStateProperty<double?>? elevation;

  /// The color of the shadow [elevation] draws (Flutter's
  /// `ButtonStyle.shadowColor`) that tints both layers of [elevation]: each
  /// layer keeps its share of the color's alpha (an opaque color gives the
  /// level's own 0.3 and 0.15). Without an [elevation] it tints the
  /// variant's own raise in each state (an `ElevatedButton` keeps its hover
  /// lift); a variant that is flat (elevation 0, e.g. `TextButton`) stays
  /// without a shadow, as in Flutter.
  final WidgetStateProperty<Color?>? shadowColor;

  /// The exact shadow of the button, per state: a design system's
  /// `0 1px 2px rgba(79, 70, 229, .35)` is
  /// `[BoxShadow(color: …, offset: Offset(0, 1), blurRadius: 2)]`. An empty
  /// list is no shadow. When it resolves to a list (in the base look or in a
  /// state) it wins over [elevation] and [shadowColor]; null falls back to
  /// them.
  ///
  /// `// web:` Flutter's `ButtonStyle` has no such field (Material draws
  /// elevation only; a custom shadow is a `DecoratedBox` around the button).
  /// Here it is a style value so that the shadow keeps the button's
  /// `:hover`/`:active`/`:disabled` states and its transition.
  final WidgetStateProperty<List<BoxShadow>?>? shadows;

  /// A copy with the given fields replaced (Flutter's
  /// `ButtonStyle.copyWith`), e.g. a design token's style with another
  /// text color: `Tokens.ghostButton.copyWith(foregroundColor: …)`.
  ButtonStyle copyWith({
    WidgetStateProperty<TextStyle?>? textStyle,
    WidgetStateProperty<Color?>? backgroundColor,
    WidgetStateProperty<Color?>? foregroundColor,
    WidgetStateProperty<Color?>? overlayColor,
    WidgetStateProperty<EdgeInsetsGeometry?>? padding,
    WidgetStateProperty<Size?>? minimumSize,
    WidgetStateProperty<Size?>? fixedSize,
    WidgetStateProperty<BorderSide?>? side,
    WidgetStateProperty<OutlinedBorder?>? shape,
    Alignment? alignment,
    Duration? animationDuration,
    WidgetStateProperty<double?>? iconSize,
    WidgetStateProperty<double?>? elevation,
    WidgetStateProperty<Color?>? shadowColor,
    WidgetStateProperty<List<BoxShadow>?>? shadows,
  }) => ButtonStyle(
    textStyle: textStyle ?? this.textStyle,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    foregroundColor: foregroundColor ?? this.foregroundColor,
    overlayColor: overlayColor ?? this.overlayColor,
    padding: padding ?? this.padding,
    minimumSize: minimumSize ?? this.minimumSize,
    fixedSize: fixedSize ?? this.fixedSize,
    side: side ?? this.side,
    shape: shape ?? this.shape,
    alignment: alignment ?? this.alignment,
    animationDuration: animationDuration ?? this.animationDuration,
    iconSize: iconSize ?? this.iconSize,
    elevation: elevation ?? this.elevation,
    shadowColor: shadowColor ?? this.shadowColor,
    shadows: shadows ?? this.shadows,
  );

  /// This style with [other]'s fields where this one's are null (Flutter's
  /// `ButtonStyle.merge`): this style's non-null fields win. Shallow, as in
  /// Flutter: a [textStyle] here replaces [other]'s whole. Null [other]:
  /// this style.
  ButtonStyle merge(ButtonStyle? other) {
    if (other == null) return this;
    return copyWith(
      textStyle: textStyle ?? other.textStyle,
      backgroundColor: backgroundColor ?? other.backgroundColor,
      foregroundColor: foregroundColor ?? other.foregroundColor,
      overlayColor: overlayColor ?? other.overlayColor,
      padding: padding ?? other.padding,
      minimumSize: minimumSize ?? other.minimumSize,
      fixedSize: fixedSize ?? other.fixedSize,
      side: side ?? other.side,
      shape: shape ?? other.shape,
      alignment: alignment ?? other.alignment,
      animationDuration: animationDuration ?? other.animationDuration,
      iconSize: iconSize ?? other.iconSize,
      elevation: elevation ?? other.elevation,
      shadowColor: shadowColor ?? other.shadowColor,
      shadows: shadows ?? other.shadows,
    );
  }

  /// The `box-shadow` in [states]: [shadows] when it says one, else that of
  /// [elevation] tinted by [shadowColor]; null when the style says none of
  /// them.
  String? _shadowAt(Set<WidgetState> states) {
    if (shadows?.resolve(states) case final list?) {
      return list.isEmpty ? 'none' : list.map((b) => b.css).join(', ');
    }
    final color = shadowColor?.resolve(states);
    final e = elevation?.resolve(states);
    if (e == null) return null;
    if (e <= 0) return 'none';
    return _elevationShadow(e, color);
  }

  CssDeclarations get _css {
    final shape = this.shape?.resolve(_none);
    final border = side?.resolve(_none) ?? shape?.side;
    final minimumSize = this.minimumSize?.resolve(_none);
    final fixedSize = this.fixedSize?.resolve(_none);
    return {
      'background-color': ?backgroundColor?.resolve(_none)?.css,
      'color': ?foregroundColor?.resolve(_none)?.css,
      ...?padding?.resolve(_none)?.toCss('padding'),
      // An explicit size wins over the button's default, zero included
      // (Flutter: `minimumSize: Size.zero` lets a button be as small as its
      // content).
      if (minimumSize case final s?) ...{
        if (s.width.isFinite) 'min-width': cssPx(s.width),
        if (s.height.isFinite) 'min-height': cssPx(s.height),
      },
      if (fixedSize case final s?) ...{
        if (s.width.isFinite) 'width': cssPx(s.width),
        if (s.height.isFinite) 'height': cssPx(s.height),
      },
      'border-radius': ?shape?.radiusCss,
      'box-shadow': ?_shadowAt(_none),
      // An explicit `side: BorderSide.none` removes the variant's outline.
      if (dropsSide)
        'border': '0'
      else if (border != null && border != BorderSide.none)
        'border': border.css,
      ...?textStyle?.resolve(_none)?.toCss(),
      if (animationDuration case final d?) ...{
        'transition-property':
            'background-color, color, border-color, box-shadow, opacity',
        'transition-duration': cssDuration(d),
      },
      if (alignment case final a?)
        'justify-content': a.x < 0
            ? 'flex-start'
            : a.x > 0
            ? 'flex-end'
            : 'center',
    };
  }
}

const Set<WidgetState> _none = <WidgetState>{};

/// What the server reads from a [ButtonStyle]: its values without a state,
/// and what changes in each state. Not exported.
extension ButtonStyleResolved on ButtonStyle {
  /// The fill without a state.
  Color? get plainBackground => backgroundColor?.resolve(_none);

  /// The text color without a state.
  Color? get plainForeground => foregroundColor?.resolve(_none);

  /// The outline without a state.
  BorderSide? get plainSide => side?.resolve(_none);

  /// Whether the style removes the outline on purpose (`side: BorderSide.none`).
  bool get dropsSide => plainSide == BorderSide.none;

  /// The corner shape without a state.
  OutlinedBorder? get plainShape => shape?.resolve(_none);

  /// The padding without a state.
  EdgeInsetsGeometry? get plainPadding => padding?.resolve(_none);

  /// The minimum size without a state.
  Size? get plainMinimumSize => minimumSize?.resolve(_none);

  /// The exact size without a state.
  Size? get plainFixedSize => fixedSize?.resolve(_none);

  /// The icon side without a state.
  double? get plainIconSize => iconSize?.resolve(_none);

  /// The state layer for [state] (`hovered` or `pressed`).
  Color? overlayAt(WidgetState state) => overlayColor?.resolve({state});

  /// The declarations that differ from the base look while the button is
  /// in [state]: fill, text color and outline.
  CssDeclarations stateCss(WidgetState state) {
    final one = {state};
    final fill = backgroundColor?.resolve(one);
    final text = foregroundColor?.resolve(one);
    final outline = side?.resolve(one);
    return {
      if (fill != null && fill.css != plainBackground?.css)
        'background-color': fill.css,
      if (text != null && text.css != plainForeground?.css) 'color': text.css,
      if (outline != null && outline != plainSide)
        'border': outline == BorderSide.none ? '0' : outline.css,
      if (_shadowAt(one) case final shadow? when shadow != _shadowAt(_none))
        'box-shadow': shadow,
    };
  }
}

/// A [ButtonStyle] from plain values: the shared body of the `styleFrom` of
/// each button. A null value leaves the field to the variant. Not exported.
ButtonStyle buttonStyleFrom({
  Color? backgroundColor,
  Color? foregroundColor,
  Color? disabledBackgroundColor,
  Color? disabledForegroundColor,
  Color? overlayColor,
  EdgeInsetsGeometry? padding,
  Size? minimumSize,
  Size? fixedSize,
  OutlinedBorder? shape,
  BorderSide? side,
  TextStyle? textStyle,
  Alignment? alignment,
  Duration? animationDuration,
  double? iconSize,
  double? elevation,
  Color? shadowColor,
  List<BoxShadow>? shadows,
}) {
  WidgetStateProperty<T?>? all<T>(T? value) =>
      value == null ? null : WidgetStatePropertyAll<T?>(value);
  WidgetStateProperty<Color?>? colors(Color? enabled, Color? disabled) {
    if (disabled == null) return all(enabled);
    return WidgetStateProperty.resolveWith<Color?>(
      (states) => states.contains(WidgetState.disabled) ? disabled : enabled,
    );
  }

  return ButtonStyle(
    textStyle: all(textStyle),
    backgroundColor: colors(backgroundColor, disabledBackgroundColor),
    foregroundColor: colors(foregroundColor, disabledForegroundColor),
    overlayColor: all(overlayColor),
    padding: all(padding),
    minimumSize: all(minimumSize),
    fixedSize: all(fixedSize),
    side: all(side),
    shape: all(shape),
    alignment: alignment,
    animationDuration: animationDuration,
    iconSize: all(iconSize),
    elevation: all(elevation),
    shadowColor: all(shadowColor),
    shadows: all(shadows),
  );
}

/// [style]'s declarations, for the widgets outside this library that take
/// a `ButtonStyle` (`Popover(style:)`). Not exported.
CssDeclarations buttonStyleCss(ButtonStyle style) => style._css;

/// The content of the `.icon` constructors: [icon] and [label] in a row.
/// The button folds it in its own content (`_ButtonRow`).
class _IconLabel extends StatelessWidget {
  const _IconLabel(this.icon, this.label);

  final Widget icon;
  final Widget label;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: [icon, label]);
}

/// What a button does inside a `<form>` (the `type` of the `<button>`).
// web: Flutter has no such type.
enum ButtonType {
  /// Does nothing to the form (`type="button"`): the default.
  button,

  /// Submits the form that contains it (`type="submit"`), also without an
  /// `onPressed`.
  submit,
}

/// Shared implementation of the Material button family: a real `<button>`
/// (keyboard, focus and disabled for free), styled by its element's class,
/// which reads the theme's CSS variables.
abstract class _ButtonBase extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn, SemanticsButton {
  const _ButtonBase({
    super.key,
    this.onPressed,
    required this.child,
    this.buttonType,
    this.style,
    this.href,
    this.formAction,
    this.formId,
    this.onPost,
    this.onValid,
    this.confirm,
    this.withIcon = false,
  });

  final void Function()? onPressed;
  final Widget child;

  /// The `.icon` constructors: [child] is an icon and a label in a `Row`,
  /// so the padding is Material's (less before the icon).
  final bool withIcon;

  /// Overrides of the variant's look (`FilledButton.styleFrom(...)`).
  final ButtonStyle? style;

  // web: not in Flutter.
  /// Makes the button a link (`<a href>`), e.g. a call to action
  /// that navigates. [onPressed] is not needed then. With a `ThorState`
  /// method as [onPressed] and JS, a plain click runs the method and does not
  /// navigate; without JS, or with a modifier or middle click, the link is
  /// followed.
  // web: an `<a href>` with a handler is the progressive "load more" /
  // "next page": the href is the path with no JS, the method the one with
  // the engine.
  final String? href;

  // web: Flutter's buttons have no type: there is no `<form>` to submit.
  /// What the button does inside a `<form>`: [ButtonType.submit] sends it
  /// (and is enabled with no [onPressed]), [ButtonType.button] (the default)
  /// does not. A button with [onPost] or [onValid] submits whatever this says.
  final ButtonType? buttonType;

  // The type in effect: [buttonType], else a plain button.
  ButtonType get _type =>
      buttonType ?? (formId != null ? ButtonType.submit : ButtonType.button);

  // web: not in Flutter.
  /// The `Form.id` of the form this button submits when it is not inside
  /// it (`form="id"`): the footer of a dialog or a drawer, outside the form
  /// it closes. It makes the button a submit button unless [buttonType] says
  /// otherwise.
  final String? formId;

  // web: not in Flutter.
  /// Where this submit button posts, instead of its form's
  /// action (`formaction`, e.g. `?/removeTag`). With a `ThorState` method as
  /// [onPressed] and JS, the method runs and nothing is posted.
  final String? formAction;

  // web: not in Flutter.
  /// The page's action method this button submits its form to
  /// (`FilledButton(onPost: delete)` → `formaction="?/delete"`), instead of
  /// the form's own. The button is a submit button.
  final PagePost? onPost;

  // web: not in Flutter.
  /// Like [onPost], a method that receives the form's checked
  /// values (`FormValues` of the method's schema, checked on the server).
  final PageValidPost<Never>? onValid;

  // web: not in Flutter.
  /// Ask before this submit goes (`onPost`, `onValid` or
  /// `formAction`): the page's one native `<dialog>` shows the question and
  /// the submit goes only on a yes. Without JavaScript it goes straight
  /// (Rails' `data-confirm` and Phoenix's do the same). Flutter asks in
  /// code (`showDialog`); a state method does it with `confirm(…)`.
  final ConfirmSpec? confirm;

  /// The variant's default style in [theme] (`ThemeData.filledButtonTheme`
  /// and the like); null: the variant has no theme.
  ButtonStyle? themeStyle(ThemeData theme) => null;

  /// Colors / padding of the variant.
  CssDeclarations get variantCss;

  /// The variant's padding with an icon before the label, for a left-to-right
  /// and a right-to-left text (`null`: the variant's own).
  (String, String)? get iconPadding => null;

  /// The padding of a variant whose outline is dropped by the style (the
  /// border no longer takes a pixel of it), with and without an icon; null:
  /// the variant's own.
  String? get unborderedPadding => null;

  /// [iconPadding] when the style drops the outline.
  (String, String)? get unborderedIconPadding => null;

  /// The variant's own elevation in [states] (Flutter's default
  /// `ButtonStyle.elevation` of the variant): what a lone
  /// `ButtonStyle.shadowColor` tints. 0: flat.
  double variantElevation(Set<WidgetState> states) => 0;

  /// Background while pressed.
  CssDeclarations get pressedCss => const {
    'background-color':
        'color-mix(in srgb, ${ThemeTokens.primary} 10%, transparent)',
  };

  /// Accessible name (`aria-label`) and hint (`title`); null: none.
  String? get tooltip => null;

  /// Whether [tooltip] is the button's accessible name (its content is an
  /// icon) or only a hint (a label names it).
  bool get tooltipNames => true;

  /// Declarations that win over the label's own (a variant that lets its
  /// label wrap where a `Row` label would not).
  CssDeclarations get contentCss => const {};

  /// Conditions of the variant besides the shared states.
  List<ConditionalCss> get extraConditions => const [];

  /// Hover background of the variant.
  CssDeclarations get hoverCss => const {
    'background-color':
        'color-mix(in srgb, ${ThemeTokens.primary} 8%, transparent)',
  };

  Map<String, String> _tooltipAttributes() => {
    if (tooltip != null) ...{
      if (tooltipNames) 'aria-label': tooltip!,
      'title': tooltip!,
    },
  };

  @override
  Widget build(BuildContext context) {
    // A plain Text label is the button's own text (no inner span).
    // Also one an app component builds.
    final c = resolveComponent(child)!;
    final text = c is Text ? c.boxContentCss : null;
    // An icon + label Row is the button's own content (no inner div).
    final row = text == null ? _ButtonRow.of(c) : null;
    // The button's own style wins, field by field, over the theme's.
    final merged = style == null
        ? themeStyle(Theme.of(context))
        : style!.merge(themeStyle(Theme.of(context)));
    // A lone shadowColor tints the variant's own raise, state by state (a
    // flat variant stays flat).
    final s =
        merged != null &&
            merged.shadowColor != null &&
            merged.elevation == null &&
            merged.shadows == null &&
            const [
              <WidgetState>{},
              {WidgetState.hovered},
              {WidgetState.pressed},
            ].any((st) => variantElevation(st) > 0)
        ? merged.copyWith(
            elevation: WidgetStateProperty.resolveWith<double?>(
              variantElevation,
            ),
          )
        : merged;
    final link = href != null;
    // A background that brings its own hover (`color.when(hover: …)`) is
    // the button's hover: the default overlay, and its shadow, would fight it.
    final background = s?.plainBackground;
    final ownHover =
        background != null &&
        splitAdaptive({
          'background-color': background.css,
        }).byBreakpoint.containsKey('hover');
    // The hover / pressed fills: the style's state layer, else the variant's
    // default (not when the fill brings its own hover), then what the
    // style's properties change in that state.
    final hoverLayer = s?.overlayAt(WidgetState.hovered);
    final pressedLayer = s?.overlayAt(WidgetState.pressed);
    final hoverState = s?.stateCss(WidgetState.hovered) ?? const {};
    final pressedState = s?.stateCss(WidgetState.pressed) ?? const {};
    // An elevation of the style replaces the variant's own raise in every
    // state; only the states where it differs (stateCss) draw another.
    final ownShadow = s?.elevation != null || s?.shadows != null;
    final hoverRules = <String, String>{
      if (!ownHover)
        ...(hoverLayer == null
            ? hoverCss
            : {'background-color': hoverLayer.css}),
      if (ownShadow) 'box-shadow': ?s?._shadowAt(_none),
      ...hoverState,
    };
    final pressedRules = <String, String>{
      if (!ownHover)
        ...(pressedLayer == null
            ? pressedCss
            : {'background-color': pressedLayer.css}),
      if (ownShadow) 'box-shadow': ?s?._shadowAt(_none),
      ...pressedState,
    };
    final selectedCss = s?.stateCss(WidgetState.selected) ?? const {};
    final disabledState = s?.stateCss(WidgetState.disabled) ?? const {};
    // web: only a disabled background replaces the faded look; a lone
    // disabled color keeps the opacity (Flutter falls back to a faded fill).
    final ownDisabled = disabledState.containsKey('background-color');
    final submits =
        onPost != null || onValid != null || _type == ButtonType.submit;
    final submit = link
        ? const <String, String>{}
        : submitAttributes(
            ThorStyleRegistry.active(context),
            formAction,
            onPost,
            onValid,
            query: RequestScope.maybeOf(context)?.uri.query,
            requestPath: RequestScope.maybeOf(context)?.routePath,
            localize: RequestScope.maybeOf(context)?.localizedPath,
            inForm: InsideForm.isIn(context),
          );
    return thorElement(
      link ? 'a' : 'button',
      debugName: kDebugMode ? runtimeType.toString() : null,
      // Static rules + theme variables; hover / focus / disabled are
      // conditions of the same class.
      baseCss: _buttonBase,
      css: {
        ...variantCss,
        if (withIcon && iconPadding != null) 'padding': iconPadding!.$1,
        if (s?.dropsSide ?? false)
          'padding': ?(withIcon && unborderedIconPadding != null
              ? unborderedIconPadding!.$1
              : unborderedPadding),
        if (link) 'text-decoration': 'none',
        ...?text,
        ...?row?.css,
        ...contentCss,
        ...?s?._css,
      },
      conditions: [
        if (hoverRules.isNotEmpty)
          ConditionalCss(
            // An `<a>` is never `:disabled`: plain `:hover` is enough.
            link ? CssCondition.hover : CssCondition.hoverEnabled,
            hoverRules,
          ),
        if (pressedRules.isNotEmpty)
          ConditionalCss(
            // An `<a>` is never `:disabled`.
            link ? CssCondition.pressed : CssCondition.pressedEnabled,
            pressedRules,
          ),
        // web: Material 3 lays the icon's side out with directional
        // padding; the browser knows the direction (`:dir(rtl)`).
        if (withIcon && iconPadding != null && s?.padding == null)
          ConditionalCss(const CssCondition.selector(':dir(rtl)'), {
            'padding': (s?.dropsSide ?? false) && unborderedIconPadding != null
                ? unborderedIconPadding!.$2
                : iconPadding!.$2,
          }),
        if (selectedCss.isNotEmpty)
          ConditionalCss(
            const CssCondition.selector(
              ':is([aria-pressed="true"], [aria-selected="true"])',
            ),
            selectedCss,
          ),
        if (!link)
          ConditionalCss(CssCondition.disabled, {
            'cursor': 'default',
            // A style with its own disabled background replaces the faded look.
            if (!ownDisabled) 'opacity': '0.38',
            ...disabledState,
          }),
        ConditionalCss(CssCondition.focused, {
          'outline': '2px solid ${ThemeTokens.primary}',
          'outline-offset': '2px',
          ...?s?.stateCss(WidgetState.focused),
        }),
        const ConditionalCss(CssCondition.reducedMotion, {
          'transition-duration': '1ms',
        }),
        ...extraConditions,
      ],
      attributes: link
          ? {
              'href': href!,
              ..._tooltipAttributes(),
              ...engineAttributes({'click': onPressed}),
            }
          : {
              ..._tooltipAttributes(),
              'type': onPost != null || onValid != null ? 'submit' : _type.name,
              ...submit,
              'form': ?formId,
              // A submit button in a `Form` submits it: it needs no handler.
              if (onPressed == null &&
                  onPost == null &&
                  onValid == null &&
                  formId == null &&
                  !(_type == ButtonType.submit && InsideForm.isIn(context)))
                'disabled': '',
              // web: without JS the page's dialog never asks, so a submit
              // with `confirm:` also carries its question for the server to
              // ask (a page that says it, confirm_page.dart in thor_server).
              ...confirmSubmitAttributes(
                ThorStyleRegistry.active(context),
                confirm,
                submit,
                submits: submits,
              ),
              ...engineAttributes({'click': onPressed}),
            },
      childRules: row == null ? ChildRules.none : ChildRules.row,
      children: text != null
          ? [Widget.text((c as Text).data!)]
          : row?.children ?? [child],
    );
  }
}

/// Row folding: a `Row(mainAxisSize: MainAxisSize.min)` that is a button's
/// child (Flutter's way to put an icon next to the label) lays out the same
/// as the button's own children: the button is already an inline flex row
/// that centers them. Its `spacing` becomes the button's `gap` and its
/// children get a row's rules; a plain `Text` among them is the button's
/// text (no span), kept on one line as the Row kept it.
class _ButtonRow {
  const _ButtonRow(this.css, this.children);

  final CssDeclarations css;
  final List<Widget> children;

  /// The fold of [child], or null when the Row lays out differently than
  /// the button would (it fills the width, aligns its children otherwise,
  /// has a flexible child, a key or a layout of its own).
  static _ButtonRow? of(Widget child) {
    if (child is! Flex ||
        child.direction != Axis.horizontal ||
        child.mainAxisSize != MainAxisSize.min ||
        child.crossAxisAlignment != CrossAxisAlignment.center ||
        child.textDirection == TextDirection.rtl ||
        child.layout != null ||
        child.key != null ||
        child.children.any(_flexible)) {
      return null;
    }
    final plain = [
      for (final c in child.children)
        if (c is Text &&
            c.runtimeType == Text &&
            c.style == null &&
            c.textAlign == null &&
            c.boxContentCss != null)
          c,
    ];
    final label = plain.length == 1 ? plain.single : null;
    return _ButtonRow(
      {'gap': cssPx(child.spacing), if (label != null) 'white-space': 'nowrap'},
      [
        for (final c in child.children)
          identical(c, label) ? Widget.text(label!.data!) : c,
      ],
    );
  }

  /// A child that takes the Row's free space (or folds into a margin),
  /// through app components too.
  static bool _flexible(Widget w) {
    Widget? c = resolveComponent(w);
    while (c is ParentDataWrapper) {
      if (c is Flexible) return true;
      c = resolveComponent(c.child);
    }
    return c is Spacer;
  }
}

/// Flutter's `FilledButton`.
class FilledButton extends _ButtonBase {
  /// Creates a filled button.
  const FilledButton({
    super.key,
    super.onPressed,
    required super.child,
    super.buttonType,
    super.style,
    super.href,
    super.formAction,
    super.formId,
    super.onPost,
    super.onValid,
    super.confirm,
  }) : _tonal = false;

  /// Flutter's `FilledButton.icon`: an [icon] before the [label].
  // web: the icon and the label are the button's own content (one `<button>`
  // and no inner element; Flutter builds a wider widget).
  FilledButton.icon({
    super.key,
    super.onPressed,
    required Widget icon,
    required Widget label,
    super.buttonType,
    super.style,
    super.href,
    super.formAction,
    super.formId,
    super.onPost,
    super.onValid,
    super.confirm,
  }) : _tonal = false,
       super(child: _IconLabel(icon, label), withIcon: true);

  /// Flutter's `FilledButton.tonal`: a filled button in the secondary
  /// container's colors, for a lower emphasis than the primary fill.
  const FilledButton.tonal({
    super.key,
    super.onPressed,
    required super.child,
    super.buttonType,
    super.style,
    super.href,
    super.formAction,
    super.formId,
    super.onPost,
    super.onValid,
    super.confirm,
  }) : _tonal = true;

  /// Flutter's `FilledButton.tonalIcon`: an [icon] before the [label].
  // web: the icon and the label are the button's own content (one `<button>`
  // and no inner element; Flutter builds a wider widget).
  FilledButton.tonalIcon({
    super.key,
    super.onPressed,
    required Widget icon,
    required Widget label,
    super.buttonType,
    super.style,
    super.href,
    super.formAction,
    super.formId,
    super.onPost,
    super.onValid,
    super.confirm,
  }) : _tonal = true,
       super(child: _IconLabel(icon, label), withIcon: true);

  final bool _tonal;

  /// A [ButtonStyle] from plain values, like Flutter's `FilledButton.styleFrom`.
  static ButtonStyle styleFrom({
    Color? backgroundColor,
    Color? foregroundColor,
    Color? overlayColor,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    Size? fixedSize,
    OutlinedBorder? shape,
    BorderSide? side,
    TextStyle? textStyle,
    Color? disabledBackgroundColor,
    Color? disabledForegroundColor,
    Alignment? alignment,
    Duration? animationDuration,
    double? elevation,
    Color? shadowColor,
    List<BoxShadow>? shadows,
  }) => buttonStyleFrom(
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
    overlayColor: overlayColor,
    padding: padding,
    minimumSize: minimumSize,
    fixedSize: fixedSize,
    shape: shape,
    side: side,
    textStyle: textStyle,
    disabledBackgroundColor: disabledBackgroundColor,
    disabledForegroundColor: disabledForegroundColor,
    alignment: alignment,
    animationDuration: animationDuration,
    elevation: elevation,
    shadowColor: shadowColor,
    shadows: shadows,
  );

  @override
  ButtonStyle? themeStyle(ThemeData theme) => theme.filledButtonTheme?.style;

  @override
  CssDeclarations get variantCss => _tonal
      ? const {
          'background-color': _tonalFill,
          'color': ThemeTokens.onSecondaryContainer,
        }
      : const {
          'background-color': ThemeTokens.primary,
          'color': ThemeTokens.onPrimary,
        };

  @override
  CssDeclarations get hoverCss => _tonal
      ? {
          'background-color':
              'color-mix(in srgb, ${ThemeTokens.onSecondaryContainer} 8%, $_tonalFill)',
          'box-shadow': _elevation1,
        }
      : const {
          'background-color':
              'color-mix(in srgb, ${ThemeTokens.primary} 92%, ${ThemeTokens.onPrimary})',
          'box-shadow': '0 1px 3px rgba(0, 0, 0, 0.3)',
        };

  @override
  CssDeclarations get pressedCss => _tonal
      ? const {
          'background-color':
              'color-mix(in srgb, ${ThemeTokens.onSecondaryContainer} 10%, $_tonalFill)',
        }
      : const {
          'background-color':
              'color-mix(in srgb, ${ThemeTokens.onPrimary} 10%, ${ThemeTokens.primary})',
        };

  // Flutter's FilledButton: 1 while hovered, 0 otherwise.
  @override
  double variantElevation(Set<WidgetState> states) =>
      states.contains(WidgetState.hovered) &&
          !states.contains(WidgetState.disabled) &&
          !states.contains(WidgetState.pressed)
      ? 1
      : 0;

  @override
  (String, String)? get iconPadding =>
      ('10px 24px 10px 16px', '10px 16px 10px 24px');
}

const _tonalFill = ThemeTokens.secondaryContainer;

// The variants' own Material 3 raises (levels 1 to 4), from the same table
// as `styleFrom(elevation:)`: one source for both.
final _elevation1 = _elevationShadow(1, null);
final _elevation2 = _elevationShadow(3, null);
final _elevation3 = _elevationShadow(6, null);
final _elevation4 = _elevationShadow(8, null);

// The two layers of each Material 3 level: key (offset, blur) and ambient
// (offset, blur, spread).
const _levels = [
  ('1px 2px', '1px 3px 1px'),
  ('1px 2px', '2px 6px 2px'),
  ('1px 3px', '4px 8px 3px'),
  ('2px 3px', '6px 10px 4px'),
  ('4px 4px', '8px 12px 6px'),
];

// The `box-shadow` of [elevation] dp (Flutter's Material 3 mapping: 1, 3, 6,
// 8 and 12 dp are levels 1 to 5, the nearest, the higher on a tie), tinted by
// [color] (its alpha scales each layer; black by default).
String _elevationShadow(double elevation, Color? color) {
  if (elevation <= 0) return 'none';
  const dp = [1.0, 3.0, 6.0, 8.0, 12.0];
  var level = 0;
  for (var i = 1; i < dp.length; i++) {
    if (elevation >= (dp[i - 1] + dp[i]) / 2) level = i;
  }
  final (key, ambient) = _levels[level];
  final tint = color ?? const Color(0xFF000000);
  String layer(double share) => tint.hasChannels
      ? 'rgba(${tint.red}, ${tint.green}, ${tint.blue}, '
            '${cssNum(double.parse((tint.opacity * share).toStringAsFixed(4)))})'
      : tint.withOpacity(share).css;
  return '0 $key ${layer(0.3)}, 0 $ambient ${layer(0.15)}';
}

/// Flutter's `ElevatedButton`: a raised button on the surface, for the
/// emphasis between [FilledButton] and [OutlinedButton].
class ElevatedButton extends _ButtonBase {
  /// Creates an elevated button.
  const ElevatedButton({
    super.key,
    super.onPressed,
    required super.child,
    super.buttonType,
    super.style,
    super.href,
    super.formAction,
    super.formId,
    super.onPost,
    super.onValid,
    super.confirm,
  });

  /// Flutter's `ElevatedButton.icon`: an [icon] before the [label].
  // web: the icon and the label are the button's own content (one `<button>`
  // and no inner element; Flutter builds a wider widget).
  ElevatedButton.icon({
    super.key,
    super.onPressed,
    required Widget icon,
    required Widget label,
    super.buttonType,
    super.style,
    super.href,
    super.formAction,
    super.formId,
    super.onPost,
    super.onValid,
    super.confirm,
  }) : super(child: _IconLabel(icon, label), withIcon: true);

  /// A [ButtonStyle] from plain values, like Flutter's `ElevatedButton.styleFrom`.
  static ButtonStyle styleFrom({
    Color? backgroundColor,
    Color? foregroundColor,
    Color? overlayColor,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    Size? fixedSize,
    OutlinedBorder? shape,
    BorderSide? side,
    TextStyle? textStyle,
    Color? disabledBackgroundColor,
    Color? disabledForegroundColor,
    Alignment? alignment,
    Duration? animationDuration,
    double? elevation,
    Color? shadowColor,
    List<BoxShadow>? shadows,
  }) => buttonStyleFrom(
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
    overlayColor: overlayColor,
    padding: padding,
    minimumSize: minimumSize,
    fixedSize: fixedSize,
    shape: shape,
    side: side,
    textStyle: textStyle,
    disabledBackgroundColor: disabledBackgroundColor,
    disabledForegroundColor: disabledForegroundColor,
    alignment: alignment,
    animationDuration: animationDuration,
    elevation: elevation,
    shadowColor: shadowColor,
    shadows: shadows,
  );

  static const _fill = ThemeTokens.surfaceContainerLow;

  @override
  ButtonStyle? themeStyle(ThemeData theme) => theme.elevatedButtonTheme?.style;

  @override
  CssDeclarations get variantCss => {
    'background-color': _fill,
    'color': ThemeTokens.primary,
    'box-shadow': _elevation1,
  };

  @override
  CssDeclarations get hoverCss => {
    'background-color': 'color-mix(in srgb, ${ThemeTokens.primary} 8%, $_fill)',
    'box-shadow': _elevation2,
  };

  @override
  CssDeclarations get pressedCss => {
    'background-color':
        'color-mix(in srgb, ${ThemeTokens.primary} 10%, $_fill)',
    'box-shadow': _elevation1,
  };

  // Flutter's ElevatedButton: 1, 3 while hovered, 0 disabled.
  @override
  double variantElevation(Set<WidgetState> states) =>
      states.contains(WidgetState.disabled)
      ? 0
      : states.contains(WidgetState.hovered) &&
            !states.contains(WidgetState.pressed)
      ? 3
      : 1;

  @override
  (String, String)? get iconPadding =>
      ('10px 24px 10px 16px', '10px 16px 10px 24px');
}

/// Flutter's `TextButton`.
class TextButton extends _ButtonBase {
  /// Creates a text button.
  const TextButton({
    super.key,
    super.onPressed,
    required super.child,
    super.buttonType,
    super.style,
    super.href,
    super.formAction,
    super.formId,
    super.onPost,
    super.onValid,
    super.confirm,
  });

  /// Flutter's `TextButton.icon`: an [icon] before the [label].
  // web: the icon and the label are the button's own content (one `<button>`
  // and no inner element; Flutter builds a wider widget).
  TextButton.icon({
    super.key,
    super.onPressed,
    required Widget icon,
    required Widget label,
    super.buttonType,
    super.style,
    super.href,
    super.formAction,
    super.formId,
    super.onPost,
    super.onValid,
    super.confirm,
  }) : super(child: _IconLabel(icon, label), withIcon: true);

  /// A [ButtonStyle] from plain values, like Flutter's `TextButton.styleFrom`.
  static ButtonStyle styleFrom({
    Color? backgroundColor,
    Color? foregroundColor,
    Color? overlayColor,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    Size? fixedSize,
    OutlinedBorder? shape,
    BorderSide? side,
    TextStyle? textStyle,
    Color? disabledBackgroundColor,
    Color? disabledForegroundColor,
    Alignment? alignment,
    Duration? animationDuration,
    double? elevation,
    Color? shadowColor,
    List<BoxShadow>? shadows,
  }) => buttonStyleFrom(
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
    overlayColor: overlayColor,
    padding: padding,
    minimumSize: minimumSize,
    fixedSize: fixedSize,
    shape: shape,
    side: side,
    textStyle: textStyle,
    disabledBackgroundColor: disabledBackgroundColor,
    disabledForegroundColor: disabledForegroundColor,
    alignment: alignment,
    animationDuration: animationDuration,
    elevation: elevation,
    shadowColor: shadowColor,
    shadows: shadows,
  );

  @override
  ButtonStyle? themeStyle(ThemeData theme) => theme.textButtonTheme?.style;

  @override
  CssDeclarations get variantCss => const {
    'background-color': 'transparent',
    'color': ThemeTokens.primary,
    'padding': '10px 12px',
  };

  @override
  (String, String)? get iconPadding =>
      ('10px 16px 10px 12px', '10px 12px 10px 16px');
}

/// Flutter's `OutlinedButton`.
class OutlinedButton extends _ButtonBase {
  /// Creates an outlined button.
  const OutlinedButton({
    super.key,
    super.onPressed,
    required super.child,
    super.buttonType,
    super.style,
    super.href,
    super.formAction,
    super.formId,
    super.onPost,
    super.onValid,
    super.confirm,
  });

  /// Flutter's `OutlinedButton.icon`: an [icon] before the [label].
  // web: the icon and the label are the button's own content (one `<button>`
  // and no inner element; Flutter builds a wider widget).
  OutlinedButton.icon({
    super.key,
    super.onPressed,
    required Widget icon,
    required Widget label,
    super.buttonType,
    super.style,
    super.href,
    super.formAction,
    super.formId,
    super.onPost,
    super.onValid,
    super.confirm,
  }) : super(child: _IconLabel(icon, label), withIcon: true);

  /// A [ButtonStyle] from plain values, like Flutter's `OutlinedButton.styleFrom`.
  static ButtonStyle styleFrom({
    Color? backgroundColor,
    Color? foregroundColor,
    Color? overlayColor,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    Size? fixedSize,
    OutlinedBorder? shape,
    BorderSide? side,
    TextStyle? textStyle,
    Color? disabledBackgroundColor,
    Color? disabledForegroundColor,
    Alignment? alignment,
    Duration? animationDuration,
    double? elevation,
    Color? shadowColor,
    List<BoxShadow>? shadows,
  }) => buttonStyleFrom(
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
    overlayColor: overlayColor,
    padding: padding,
    minimumSize: minimumSize,
    fixedSize: fixedSize,
    shape: shape,
    side: side,
    textStyle: textStyle,
    disabledBackgroundColor: disabledBackgroundColor,
    disabledForegroundColor: disabledForegroundColor,
    alignment: alignment,
    animationDuration: animationDuration,
    elevation: elevation,
    shadowColor: shadowColor,
    shadows: shadows,
  );

  @override
  ButtonStyle? themeStyle(ThemeData theme) => theme.outlinedButtonTheme?.style;

  @override
  CssDeclarations get variantCss => const {
    'background-color': 'transparent',
    'color': ThemeTokens.primary,
    'border': '1px solid ${ThemeTokens.outline}',
    // Flutter paints the side inside the shape: the button stays 40 px tall
    // and its label 24 px from the outer edge (CSS adds the border outside
    // the padding).
    'padding': '9px 23px',
  };

  @override
  (String, String)? get iconPadding =>
      ('9px 23px 9px 15px', '9px 15px 9px 23px');

  @override
  String? get unborderedPadding => '10px 24px';

  @override
  (String, String)? get unborderedIconPadding =>
      ('10px 24px 10px 16px', '10px 16px 10px 24px');
}

enum _FabSize { regular, small, large, extended }

/// Flutter's `FloatingActionButton`: the screen's main action, a raised
/// button in the primary container's colors. Inside
/// `Scaffold(floatingActionButton:)` it floats in the bottom corner.
///
/// [tooltip] is its accessible name (`aria-label`) when it holds only an
/// icon, so give it one.
class FloatingActionButton extends _ButtonBase {
  /// A 56 px round-cornered button around [child] (usually an `Icon`).
  const FloatingActionButton({
    super.key,
    required super.onPressed,
    required super.child,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    super.href,
  }) : assert(
         href == null || (tooltip != null && tooltip != ''),
         'FloatingActionButton(href:) needs a tooltip: it is the link\'s name',
       ),
       _size = _FabSize.regular;

  /// A 40 px button.
  const FloatingActionButton.small({
    super.key,
    required super.onPressed,
    required super.child,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    super.href,
  }) : assert(
         href == null || (tooltip != null && tooltip != ''),
         'FloatingActionButton(href:) needs a tooltip: it is the link\'s name',
       ),
       _size = _FabSize.small;

  /// A 96 px button with a 36 px icon.
  const FloatingActionButton.large({
    super.key,
    required super.onPressed,
    required super.child,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    super.href,
  }) : assert(
         href == null || (tooltip != null && tooltip != ''),
         'FloatingActionButton(href:) needs a tooltip: it is the link\'s name',
       ),
       _size = _FabSize.large;

  /// A button with a [label] and, before it, an optional [icon].
  // web: a label longer than the screen wraps to more lines (Flutter's
  // overflows), so the button never leaves the viewport.
  FloatingActionButton.extended({
    super.key,
    required super.onPressed,
    required Widget label,
    Widget? icon,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    super.href,
  }) : _size = _FabSize.extended,
       super(
         child: icon == null ? label : _IconLabel(icon, label),
         withIcon: icon != null,
       );

  final _FabSize _size;

  /// The accessible name of an icon-only button (`aria-label`), also shown
  /// as the browser's hint (`title`); an extended button's label already
  /// names it, so there it is only the hint.
  @override
  final String? tooltip;

  /// Fill (default: the theme's primary container).
  final Color? backgroundColor;

  /// Icon and label color (default: the theme's on-primary-container).
  final Color? foregroundColor;

  @override
  bool get tooltipNames => _size != _FabSize.extended;

  static const _fill = ThemeTokens.primaryContainer;

  String get _bg => backgroundColor?.css ?? _fill;

  @override
  CssDeclarations get variantCss => {
    'background-color': _bg,
    'color': foregroundColor?.css ?? ThemeTokens.onPrimaryContainer,
    'box-shadow': _elevation3,
    ...switch (_size) {
      // web: Flutter's sizes: 56 (regular), 40 (small), 96 (large).
      _FabSize.regular => const {
        'min-width': '56px',
        'min-height': '56px',
        'padding': '16px',
        'border-radius': '16px',
      },
      _FabSize.small => const {
        'min-width': '40px',
        'min-height': '40px',
        'padding': '8px',
        'border-radius': '12px',
      },
      _FabSize.large => const {
        'min-width': '96px',
        'min-height': '96px',
        'padding': '30px',
        'border-radius': '28px',
      },
      _FabSize.extended => const {
        'min-height': '56px',
        'padding': '16px 20px',
        'border-radius': '16px',
        'max-width': 'calc(100vw - 32px)',
        'text-align': 'center',
        'overflow-wrap': 'anywhere',
      },
    },
  };

  @override
  CssDeclarations get contentCss =>
      _size == _FabSize.extended ? const {'white-space': 'normal'} : const {};

  @override
  (String, String)? get iconPadding =>
      ('16px 20px 16px 16px', '16px 16px 16px 20px');

  // Flutter's FloatingActionButton: 6, 8 while hovered.
  @override
  double variantElevation(Set<WidgetState> states) =>
      states.contains(WidgetState.hovered) &&
          !states.contains(WidgetState.pressed)
      ? 8
      : 6;

  @override
  CssDeclarations get hoverCss => {
    'background-color': 'color-mix(in srgb, currentColor 8%, $_bg)',
    'box-shadow': _elevation4,
  };

  @override
  CssDeclarations get pressedCss => {
    'background-color': 'color-mix(in srgb, currentColor 10%, $_bg)',
    'box-shadow': _elevation3,
  };

  @override
  List<ConditionalCss> get extraConditions => _size == _FabSize.large
      ? const [
          ConditionalCss(CssCondition.selector(' > svg'), {
            'width': '36px',
            'height': '36px',
          }),
          ConditionalCss(CssCondition.selector(' > span'), {
            'font-size': '36px',
          }),
        ]
      : const [];
}
