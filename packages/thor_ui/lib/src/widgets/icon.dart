import 'package:thor_engine/thor_engine.dart' show ConfirmSpec;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../engine/watch.dart' show WatchAttributes, engineAttributes;
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/html_attributes.dart';
import '../foundation/request_scope.dart';
import '../foundation/style_registry.dart';
import '../foundation/theme_tokens.dart';
import '../foundation/widget_state.dart';
import '../router/page_actions.dart'
    show PagePost, PageValidPost, submitAttributes;
import 'buttons.dart'
    show
        ButtonStyle,
        ButtonStyleResolved,
        ButtonType,
        buttonStyleCss,
        buttonStyleFrom;
import 'effects.dart' show SemanticsButton;
import 'feedback.dart' show confirmSubmitAttributes;
import 'form.dart' show InsideForm;
import 'text.dart' show Text;
import 'theme.dart' show Theme;

/// Flutter's `Icon`: a glyph from an icon font, sized as a square box.
///
/// Color defaults to `currentColor`, which is the web equivalent of
/// inheriting `IconTheme`.
class Icon extends StatelessWidget implements ThorElementWidget, ThorBuiltIn {
  /// Creates an icon glyph.
  const Icon(
    this.icon, {
    super.key,
    double? size,
    this.color,
    this.semanticLabel,
  }) : _size = size;

  /// The glyph to draw.
  final IconData icon;

  /// Side of the square box, in logical pixels (null in the constructor:
  /// 24, the default size).
  // web: Flutter's `Icon.size` is nullable and falls back to the
  // `IconTheme`; thor has no `IconTheme`, so the getter answers the default
  // (24) and a widget that sizes its icon (a `DropdownButton(iconSize:)`)
  // tells an explicit size from it with [IconSizeGiven.hasOwnSize].
  double get size => _size ?? 24;

  final double? _size;

  /// Glyph color (defaults to `currentColor`).
  final Color? color;

  /// Without a label the icon is decorative (`aria-hidden`).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // A label from a wrapper that lands on this element
    // (`Semantics(label:)`, no tag of its own) names the icon like its own
    // semanticLabel: it must not stay hidden with aria-hidden. A wrapper
    // that is its own element (a `Link`'s `<a>`) keeps the label there.
    final pending = ChildRulesScope.maybeOf(context)?.pending;
    final wrapperLabel = pending?.tag == null
        ? pending?.attributes['aria-label']
        : null;
    // An empty label names nothing: the icon stays decorative.
    final a11y = semanticLabel != null && semanticLabel!.isNotEmpty
        ? {'role': 'img', 'aria-label': semanticLabel!}
        : wrapperLabel != null
        ? const {'role': 'img'}
        : const {'aria-hidden': 'true'};
    // web: Flutter's `matchTextDirection` flips the icon in right-to-left
    // text; here the browser knows the direction (`:dir(rtl)`).
    final mirror = icon.matchTextDirection
        ? const [
            ConditionalCss(CssCondition.selector(':dir(rtl)'), {
              'transform': 'scaleX(-1)',
            }),
          ]
        : const <ConditionalCss>[];
    if (!icon.isSvg) {
      return thorElement(
        'span',
        debugName: 'Icon',
        css: {
          'display': 'inline-block',
          'width': '1em',
          'height': '1em',
          'line-height': '1',
          'text-align': 'center',
          'font-style': 'normal',
          'font-weight': 'normal',
          'flex': 'none',
          '-webkit-font-smoothing': 'antialiased',
          'user-select': 'none',
          'font-family': icon.fontFamily!,
          'font-size': cssPx(size),
          if (color != null) 'color': color!.css,
        },
        conditions: mirror,
        attributes: a11y,
        children: [Widget.text(icon.character)],
      );
    }
    final stroke = icon.strokeWidth;
    final attrs = {
      ...a11y,
      'viewBox': icon.viewBox,
      'width': cssNum(size),
      'height': cssNum(size),
    };
    final registry = ThorStyleRegistry.active(context);
    final useSprite = registry != null;
    registry?.addSymbol(icon.svgId!, icon.viewBox, icon.svgBody!);
    return thorElement(
      'svg',
      debugName: 'Icon',
      css: {
        'display': 'block',
        'flex': 'none',
        'overflow': 'visible',
        if (stroke != null) ...{
          'fill': 'none',
          'stroke': 'currentColor',
          'stroke-width': cssNum(stroke),
          'stroke-linecap': 'round',
          'stroke-linejoin': 'round',
        } else
          'fill': 'currentColor',
        if (color != null) 'color': color!.css,
      },
      conditions: mirror,
      attributes: attrs,
      children: [
        if (useSprite)
          Widget.element(tag: 'use', attributes: {'href': '#${icon.svgId}'})
        else
          RawText(icon.svgBody!),
      ],
    );
  }
}

enum _IconButtonKind { standard, filled, tonal, outlined }

/// Flutter's `IconButton`: a real `<button>`, 48×48 touch target with a
/// circular hover/press highlight. With [href] a link that looks the same.
class IconButton extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn, SemanticsButton {
  /// Creates an icon button.
  const IconButton({
    super.key,
    this.iconSize,
    this.visualDensity,
    this.padding,
    this.constraints,
    this.style,
    this.isSelected,
    this.selectedIcon,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.tooltipWatch,
    this.color,
    this.buttonType,
    this.href,
    this.formAction,
    this.onPost,
    this.onValid,
    this.confirm,
  }) : assert(
         href == null ||
             tooltipWatch != null ||
             (tooltip != null && tooltip != ''),
         'IconButton(href:) needs a tooltip: it is the link\'s accessible name',
       ),
       assert(
         tooltip == null || tooltipWatch == null,
         'IconButton: give tooltip or tooltipWatch, not both',
       ),
       _kind = _IconButtonKind.standard;

  /// Flutter's `IconButton.filled`: on a primary fill, for a high emphasis.
  // web: 40 px, like Material 3's (the plain one keeps its 48 px box).
  const IconButton.filled({
    super.key,
    this.iconSize,
    this.visualDensity,
    this.padding,
    this.constraints,
    this.style,
    this.isSelected,
    this.selectedIcon,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.tooltipWatch,
    this.color,
    this.buttonType,
    this.href,
    this.formAction,
    this.onPost,
    this.onValid,
    this.confirm,
  }) : assert(
         href == null ||
             tooltipWatch != null ||
             (tooltip != null && tooltip != ''),
         'IconButton(href:) needs a tooltip: it is the link\'s accessible name',
       ),
       assert(
         tooltip == null || tooltipWatch == null,
         'IconButton: give tooltip or tooltipWatch, not both',
       ),
       _kind = _IconButtonKind.filled;

  /// Flutter's `IconButton.filledTonal`: on a secondary container fill.
  // web: 40 px, like Material 3's.
  const IconButton.filledTonal({
    super.key,
    this.iconSize,
    this.visualDensity,
    this.padding,
    this.constraints,
    this.style,
    this.isSelected,
    this.selectedIcon,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.tooltipWatch,
    this.color,
    this.buttonType,
    this.href,
    this.formAction,
    this.onPost,
    this.onValid,
    this.confirm,
  }) : assert(
         href == null ||
             tooltipWatch != null ||
             (tooltip != null && tooltip != ''),
         'IconButton(href:) needs a tooltip: it is the link\'s accessible name',
       ),
       assert(
         tooltip == null || tooltipWatch == null,
         'IconButton: give tooltip or tooltipWatch, not both',
       ),
       _kind = _IconButtonKind.tonal;

  /// Flutter's `IconButton.outlined`: with a 1 px outline.
  // web: 40 px, like Material 3's.
  const IconButton.outlined({
    super.key,
    this.iconSize,
    this.visualDensity,
    this.padding,
    this.constraints,
    this.style,
    this.isSelected,
    this.selectedIcon,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.tooltipWatch,
    this.color,
    this.buttonType,
    this.href,
    this.formAction,
    this.onPost,
    this.onValid,
    this.confirm,
  }) : assert(
         href == null ||
             tooltipWatch != null ||
             (tooltip != null && tooltip != ''),
         'IconButton(href:) needs a tooltip: it is the link\'s accessible name',
       ),
       assert(
         tooltip == null || tooltipWatch == null,
         'IconButton: give tooltip or tooltipWatch, not both',
       ),
       _kind = _IconButtonKind.outlined;

  final _IconButtonKind _kind;

  /// A [ButtonStyle] from plain values, like Flutter's `IconButton.styleFrom`:
  /// for [style] and for `CarouselView(arrowStyle:)`.
  static ButtonStyle styleFrom({
    Color? backgroundColor,
    Color? foregroundColor,
    Color? overlayColor,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    Size? fixedSize,
    OutlinedBorder? shape,
    BorderSide? side,
    double? iconSize,

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
    iconSize: iconSize,
    disabledBackgroundColor: disabledBackgroundColor,
    disabledForegroundColor: disabledForegroundColor,
    alignment: alignment,
    animationDuration: animationDuration,
    elevation: elevation,
    shadowColor: shadowColor,
    shadows: shadows,
  );

  /// Whether the button is on (Flutter's `IconButton.isSelected`): it shows
  /// [selectedIcon] and sets `aria-pressed`, which the `selected` state of
  /// the [style] styles. Null: not a toggle.
  final bool? isSelected;

  /// The icon while [isSelected] (default: [icon]).
  final Widget? selectedIcon;

  /// The icon to show.
  final Widget icon;

  /// Called on tap; `null` disables the button.
  final void Function()? onPressed;

  /// Also used as the accessible name (`aria-label`): an icon alone has none,
  /// so give every icon button one (`thor_lints` reports the ones without).
  final String? tooltip;

  // web: not in Flutter.
  /// [tooltip] bound to a `ThorState` method that returns it
  /// (`IconButton(tooltipWatch: editor.undoTip)`): the accessible name and
  /// the `title` follow the state in the browser, with no reload. Instead of
  /// [tooltip], not with it.
  final String Function()? tooltipWatch;

  // web: not in Flutter.
  /// Like `FilledButton(href: )`: makes the button a link
  /// (`<a href>`) that looks like an icon button, e.g. a settings icon that
  /// navigates. [tooltip] is required: it is the link's accessible name.
  /// [onPressed] does not disable a link.
  final String? href;

  /// Icon color (defaults to `inherit`).
  final Color? color;

  /// Side of the icon inside, in logical pixels (Flutter's default is 24).
  // web: it wins over the icon's own `Icon(size:)` too (Flutter's explicit
  // icon size would win over the button's `IconTheme`).
  final double? iconSize;

  /// How compact the button is: each step moves its minimum size by 4 px.
  final VisualDensity? visualDensity;

  /// Space around the icon.
  // web: null keeps 12 px around a 24 px icon (the 48×48 box); with any of
  // the sizing parameters set it is Flutter's 8 px.
  final EdgeInsetsGeometry? padding;

  /// Size limits of the button (default: at least 48×48, adjusted by
  /// [visualDensity]).
  final BoxConstraints? constraints;

  /// Overrides of the button's look; its fields win over [color] and
  /// [padding], as in Flutter.
  final ButtonStyle? style;

  // web: not in Flutter.
  /// Like `FilledButton(buttonType: )`: [ButtonType.submit] sends the
  /// `<form>` that contains it (e.g. a sign-out icon that posts).
  final ButtonType? buttonType;

  ButtonType get _type => buttonType ?? ButtonType.button;

  // web: not in Flutter.
  /// Like `FilledButton(formAction: )`: where this submit button
  /// posts instead of its form's action.
  final String? formAction;

  // web: not in Flutter.
  /// Like `FilledButton(onPost: )`: the page's action method
  /// this button submits its form to.
  final PagePost? onPost;

  // web: not in Flutter.
  /// Like `FilledButton(onValid: )`.
  final PageValidPost<Never>? onValid;

  // web: not in Flutter.
  /// Like `FilledButton(confirm: )`: ask before the submit goes.
  final ConfirmSpec? confirm;

  @override
  Widget build(BuildContext context) {
    // The button's own style wins, field by field, over
    // `ThemeData.iconButtonTheme`.
    final themed = Theme.of(context).iconButtonTheme?.style;
    final s = style == null ? themed : style!.merge(themed);
    final size = iconSize ?? s?.plainIconSize;
    final hoverLayer = s?.overlayAt(WidgetState.hovered);
    final pressedLayer = s?.overlayAt(WidgetState.pressed);
    final disabledState = s?.stateCss(WidgetState.disabled) ?? const {};
    final ownDisabled =
        disabledState.containsKey('background-color') ||
        disabledState.containsKey('color');
    final sized =
        size != null ||
        visualDensity != null ||
        padding != null ||
        constraints != null;
    final CssDeclarations box;
    if (!sized) {
      box = _kind == _IconButtonKind.standard
          ? const {'padding': '12px', 'width': '48px', 'height': '48px'}
          : const {'padding': '8px', 'width': '40px', 'height': '40px'};
    } else {
      final adjust =
          (visualDensity ?? VisualDensity.standard).baseSizeAdjustment;
      final c =
          constraints ?? const BoxConstraints(minWidth: 48, minHeight: 48);
      final minW = c.minWidth + adjust.dx;
      final minH = c.minHeight + adjust.dy;
      box = {
        ...(padding?.toCss('padding') ?? const {'padding': '8px'}),
        'box-sizing': 'border-box',
        // Its own size (padding + icon, at least the minimum), like
        // Flutter's under the loose constraints of a Column or a Center: a
        // stretching flex or grid parent must not widen it into an ellipse.
        'width': 'fit-content',
        'height': 'fit-content',
        if (minW > 0) 'min-width': cssPx(minW),
        if (minH > 0) 'min-height': cssPx(minH),
        if (c.maxWidth.isFinite) 'max-width': cssPx(c.maxWidth),
        if (c.maxHeight.isFinite) 'max-height': cssPx(c.maxHeight),
      };
    }
    final link = href != null;
    // A bound tooltip: the server writes the first value, the engine keeps
    // the accessible name and the title current.
    final watch = tooltipWatch;
    final tipAttributes = watch != null
        ? WatchAttributes({
            AttributeName.ariaOf(AriaAttribute.label): watch,
            AttributeName.title: watch,
          }, child: const Text('')).wrapData.attributes
        : <String, String>{
            if (tooltip != null) ...{'aria-label': tooltip!, 'title': tooltip!},
          };
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
    // The fill's colors of the Material 3 variants: (fill, icon, hover
    // fill, pressed fill); null for the plain and the outlined one.
    final (String, String, String, String)? fill = switch (_kind) {
      _IconButtonKind.filled => (
        ThemeTokens.primary,
        ThemeTokens.onPrimary,
        'color-mix(in srgb, ${ThemeTokens.onPrimary} 8%, ${ThemeTokens.primary})',
        'color-mix(in srgb, ${ThemeTokens.onPrimary} 10%, ${ThemeTokens.primary})',
      ),
      _IconButtonKind.tonal => (
        ThemeTokens.secondaryContainer,
        ThemeTokens.onSecondaryContainer,
        'color-mix(in srgb, ${ThemeTokens.onSecondaryContainer} 8%, ${ThemeTokens.secondaryContainer})',
        'color-mix(in srgb, ${ThemeTokens.onSecondaryContainer} 10%, ${ThemeTokens.secondaryContainer})',
      ),
      _ => null,
    };
    return thorElement(
      link ? 'a' : 'button',
      debugName: 'IconButton',
      // The resets go under the parent's rules, as in the other buttons: the
      // auto margins of an aligned parent (`Center`, `Container(alignment:)`)
      // center it.
      baseCss: const {'appearance': 'none', 'border': '0', 'margin': '0'},
      css: {
        ...box,
        'display': 'inline-grid',
        'place-items': 'center',
        'border-radius': '50%',
        'background': fill?.$1 ?? 'transparent',
        'color':
            color?.css ??
            fill?.$2 ??
            (_kind == _IconButtonKind.outlined
                ? ThemeTokens.onSurfaceVariant
                : 'inherit'),
        'cursor': 'pointer',
        'transition-property': 'background-color',
        'transition-duration': '150ms',
        if (_kind == _IconButtonKind.outlined)
          'border': '1px solid ${ThemeTokens.outline}',
        if (link) 'text-decoration': 'none',
        if (s != null) ...buttonStyleCss(s),
      },
      conditions: [
        ConditionalCss(CssCondition.hoverEnabled, {
          ...(hoverLayer == null
              ? {
                  'background-color':
                      fill?.$3 ??
                      'color-mix(in srgb, currentColor 8%, transparent)',
                }
              : {'background-color': hoverLayer.css}),
          ...?s?.stateCss(WidgetState.hovered),
        }),
        // Material 3's pressed (10 % state layer), disabled (38 %) and
        // reduced motion, in every kind.
        ConditionalCss(CssCondition.pressedEnabled, {
          ...(pressedLayer == null
              ? {
                  'background-color':
                      fill?.$4 ??
                      'color-mix(in srgb, currentColor 10%, transparent)',
                }
              : {'background-color': pressedLayer.css}),
          ...?s?.stateCss(WidgetState.pressed),
        }),
        if (s?.stateCss(WidgetState.selected) case final on? when on.isNotEmpty)
          ConditionalCss(
            const CssCondition.selector(
              ':is([aria-pressed="true"], [aria-selected="true"])',
            ),
            on,
          ),
        if (!link)
          ConditionalCss(CssCondition.disabled, {
            'cursor': 'default',
            if (!ownDisabled) 'opacity': '0.38',
            ...disabledState,
          }),
        const ConditionalCss(CssCondition.reducedMotion, {
          'transition-duration': '1ms',
        }),
        ConditionalCss(CssCondition.focused, {
          'outline': '2px solid ${ThemeTokens.primary}',
          'outline-offset': '2px',
          ...?s?.stateCss(WidgetState.focused),
        }),
        if (size != null) ...[
          ConditionalCss(const CssCondition.selector(' > svg'), {
            'width': cssPx(size),
            'height': cssPx(size),
          }),
          ConditionalCss(const CssCondition.selector(' > span'), {
            'font-size': cssPx(size),
          }),
        ],
      ],
      attributes: link
          // web: a link is never disabled; `onPressed` is one more click
          // handler (`FilledButton(href:)` works the same).
          ? {
              'href': href!,
              // web: `aria-pressed` is not allowed on the link role; a toggle
              // link is a `role="button"` (WAI-ARIA APG toggle button).
              if (isSelected != null) ...{
                'role': 'button',
                'aria-pressed': '$isSelected',
              },
              ...tipAttributes,
              ...engineAttributes({'click': onPressed}),
            }
          : {
              'type': onPost != null || onValid != null ? 'submit' : _type.name,
              if (isSelected != null) 'aria-pressed': '$isSelected',
              ...submit,
              ...tipAttributes,
              // A submit button in a `Form` submits it: it needs no handler.
              if (onPressed == null &&
                  onPost == null &&
                  onValid == null &&
                  !(_type == ButtonType.submit && InsideForm.isIn(context)))
                'disabled': '',
              // web: without JS the page's dialog never asks, so a submit
              // with `confirm:` also carries its question (as FilledButton).
              ...confirmSubmitAttributes(
                ThorStyleRegistry.active(context),
                confirm,
                submit,
                submits:
                    onPost != null ||
                    onValid != null ||
                    _type == ButtonType.submit,
              ),
              ...engineAttributes({'click': onPressed}),
            },
      children: [isSelected == true ? selectedIcon ?? icon : icon],
    );
  }
}

/// Whether an [Icon] was given its own size (`Icon(size:)`, even 24), so a
/// parent that sizes its icon leaves it alone, as Flutter's explicit size
/// wins over the `IconTheme`. Not exported.
extension IconSizeGiven on Icon {
  /// Whether `Icon(size:)` was given.
  bool get hasOwnSize => _size != null;
}
