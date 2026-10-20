import 'package:thor_engine/thor_engine.dart'
    show
        FocusNode,
        TextEditingController,
        dropdownActiveAttr,
        dropdownAttr,
        dropdownHintAttr,
        dropdownLabelAttr,
        encodeArg,
        focusNodeAttr;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../engine/watch.dart' show engineAttributes;
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/errors.dart';
import '../foundation/html_attributes.dart';
import '../foundation/layout_hint.dart';
import '../foundation/material_localizations.dart' show MaterialLocalizations;
import '../foundation/parent_data.dart';
import '../foundation/style_registry.dart';
import '../foundation/theme_tokens.dart';
import '../foundation/transparent.dart';
import '../foundation/widget_state.dart';
import 'buttons.dart' show ButtonStyle, ButtonStyleResolved, buttonStyleCss;
import 'form_scope.dart';
import 'icon.dart' show Icon;
import 'shortcuts.dart' show controllerIdOf;
import 'text.dart' show Text;
import 'text_field.dart';

const _outline = Color.variable(
  CssVariable('--t-outline'),
  fallback: Color(0xFF79747E),
);
const _primary = Color.variable(
  CssVariable('--t-primary'),
  fallback: Color(0xFF6750A4),
);
const _error = Color.variable(
  CssVariable('--t-error'),
  fallback: Color(0xFFB3261E),
);
const _onSurfaceVariant = ThemeTokens.onSurfaceVariant;
const _ring = 'var(--t-field-ring, 0 0 #0000)';
const _hint = 'color-mix(in srgb, currentColor 60%, transparent)';
const _highlight = 'color-mix(in srgb, currentColor 10%, transparent)';

// Material's arrow_drop_down / arrow_drop_up.
const _dropDown = IconData.svg(
  'thor-arrow-drop-down',
  '<path d="M7 10l5 5 5-5z"/>',
);
const _dropUp = IconData.svg(
  'thor-arrow-drop-up',
  '<path d="M7 14l5-5 5 5z"/>',
);

/// The anchor of a menu's panel: one name, scoped to each `DropdownMenu`
/// (`anchor-scope`), so every instance shares the same classes.
const _anchor = '--t-dd';

/// Flutter's `MenuStyle` (plain values, like `ButtonStyle` here): the look
/// of a menu's panel.
class MenuStyle {
  /// A style; null fields keep the menu's default.
  const MenuStyle({
    this.backgroundColor,
    this.shadowColor,
    this.elevation,
    this.padding,
    this.minimumSize,
    this.fixedSize,
    this.maximumSize,
    this.side,
    this.shape,
    this.shadows,
  });

  /// Fill of the panel.
  final Color? backgroundColor;

  /// Color of the [elevation] shadow.
  final Color? shadowColor;

  /// Shadow depth (Material 3 menus: 3).
  final double? elevation;

  /// Space inside the panel, around the entries (Material 3: 8 above and
  /// below).
  final EdgeInsetsGeometry? padding;

  /// Smallest size of the panel (a dimension of 0 leaves it free).
  final Size? minimumSize;

  /// Exact size of the panel (an infinite dimension leaves it free).
  final Size? fixedSize;

  /// Largest size of the panel (an infinite dimension leaves it free).
  final Size? maximumSize;

  /// Outline of the panel (wins over the shape's side).
  final BorderSide? side;

  /// Corners (and outline) of the panel.
  final OutlinedBorder? shape;

  /// `// web:` the exact shadow a design asks for (a shadcn popover's
  /// `shadow-md`), instead of Material's [elevation] steps; wins over them.
  final List<BoxShadow>? shadows;

  CssDeclarations get _css {
    final border = side ?? shape?.side;
    final e = elevation;
    final shadowList =
        shadows ??
        (e == null
            ? null
            : e <= 0
            ? const <BoxShadow>[]
            : [
                BoxShadow(
                  color:
                      shadowColor?.withValues(alpha: 0.3) ??
                      const Color(0x4D000000),
                  offset: Offset(0, e / 3),
                  blurRadius: e,
                ),
                BoxShadow(
                  color:
                      shadowColor?.withValues(alpha: 0.15) ??
                      const Color(0x26000000),
                  offset: Offset(0, e),
                  blurRadius: e * 3,
                  spreadRadius: e / 3,
                ),
              ]);
    String? size(double v) => v.isFinite && v > 0 ? cssPx(v) : null;
    return {
      'background-color': ?backgroundColor?.css,
      ...?padding?.toCss('padding'),
      if (minimumSize case final s?) ...{
        'min-width': ?size(s.width),
        'min-height': ?size(s.height),
      },
      if (maximumSize case final s?) ...{
        'max-width': ?(s.width.isFinite
            ? 'min(${cssPx(s.width)}, 100vw - 16px)'
            : null),
        'max-height': ?size(s.height),
      },
      if (fixedSize case final s?) ...{
        'width': ?size(s.width),
        'height': ?size(s.height),
      },
      'border-radius': ?shape?.radiusCss,
      if (border != null && border != BorderSide.none) 'border': border.css,
      if (shadowList != null)
        'box-shadow': shadowList.isEmpty
            ? 'none'
            : shadowList.map((s) => s.css).join(', '),
    };
  }
}

/// The CSS of [style] (the panel of `MenuAnchor`, the same as a
/// `DropdownMenu`'s). Not exported.
CssDeclarations menuStyleCss(MenuStyle style) => style._css;

/// Flutter's `DropdownMenuEntry<T>`: one entry of a [DropdownMenu].
class DropdownMenuEntry<T> {
  /// Creates an entry.
  const DropdownMenuEntry({
    required this.value,
    required this.label,
    this.leadingIcon,
    this.trailingIcon,
    this.enabled = true,
    this.style,
    this.labelWidget,
  });

  /// The value the entry stands for (what `onSelected` gets and a form
  /// posts, encoded like any `ThorState` argument).
  final T value;

  /// The text of the entry, shown in the menu's button once picked, and
  /// what filtering and type-ahead match.
  final String label;

  /// Shown before the label.
  final Widget? leadingIcon;

  /// Shown after the label, at the end of the row.
  final Widget? trailingIcon;

  /// Whether the entry can be picked (Flutter's default: true).
  final bool enabled;

  /// The look of the entry's row (`MenuItemButton`'s style): padding,
  /// minimum size, text, colors, and `overlayColor` for the highlighted
  /// row.
  final ButtonStyle? style;

  /// Shown instead of [label] in the menu (the button still shows
  /// [label]).
  final Widget? labelWidget;
}

/// `// web:` shows [child] only on the picked entry of a [DropdownMenu],
/// keeping its space on the others (like the checkmark of a select menu). Put it
/// in a [DropdownMenuEntry]'s `leadingIcon` or `trailingIcon`.
class DropdownMenuSelectedIcon extends ParentDataWrapper {
  /// Wraps [child] (usually a check `Icon`).
  const DropdownMenuSelectedIcon({super.key, required super.child});

  @override
  WrapData get wrapData => const WrapData(
    css: {'visibility': 'hidden'},
    conditions: [
      ConditionalCss(CssCondition.within('[aria-selected="true"]'), {
        'visibility': 'visible',
      }),
    ],
  );
}

int _fallbackIds = 0;

/// Flutter's `DropdownMenu<T>` (Material 3): a button that opens a list
/// of entries to pick one from, with type-ahead and an optional filter
/// field. A styled select: every part takes the app's look, unlike a
/// native `<select>` (`DropdownButton`).
///
/// The list is a popover anchored under the button (light dismiss and
/// Esc are native); the engine's `DropdownMenuFeature` (added by the build
/// when an app uses `DropdownMenu(`) highlights and picks entries with the
/// keyboard and the pointer, filters as the user types, and updates the
/// button. The page ships the engine for it even without a `ThorState`.
///
/// Forms: with [name], a hidden `<select>` carries the picked value (the
/// [initialSelection] at first), so a plain POST works. Without JS that
/// same `<select>` is the control (`@media (scripting: none)`): the page
/// stays usable.
///
/// Accessibility: the button is a `combobox` with `aria-expanded` and
/// `aria-controls`; entries are `option`s with `aria-selected`; the
/// highlighted one is announced through `aria-activedescendant`, on the
/// button or on the filter field, where focus stays.
///
/// ```dart
/// DropdownMenu<String>(
///   name: 'fruit',
///   initialSelection: 'apple',
///   onSelected: order.setFruit,       // void setFruit(String? fruit)
///   enableFilter: true,
///   dropdownMenuEntries: const [
///     DropdownMenuEntry(value: 'apple', label: 'Apple'),
///     DropdownMenuEntry(value: 'banana', label: 'Banana'),
///   ],
/// )
/// ```
class DropdownMenu<T> extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn, LayoutHint {
  /// Creates a dropdown menu.
  const DropdownMenu({
    super.key,
    required this.dropdownMenuEntries,
    this.initialSelection,
    this.onSelected,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.leadingIcon,
    this.trailingIcon,
    this.selectedTrailingIcon,
    this.enableFilter = false,
    this.enableSearch = true,
    this.width,
    this.menuHeight,
    this.inputDecorationTheme,
    this.menuStyle,
    this.textStyle,
    this.enabled = true,
    this.requestFocusOnTap,
    this.controller,
    this.focusNode,
    this.expandedInsets,
    this.alignmentOffset,
    this.name,
    this.id,
    this.searchDecoration,
  });

  /// The entries of the menu.
  final List<DropdownMenuEntry<T>> dropdownMenuEntries;

  /// The value picked at first (none: the button shows [hintText]).
  final T? initialSelection;

  /// Called with the picked value on every pick. A method of a
  /// `ThorState` runs in the browser.
  final ValueChanged<T?>? onSelected;

  /// Shown above the button, and the button's accessible name when it is
  /// a `Text`.
  ///
  /// `// web:` above the field, not floating inside its border.
  final Widget? label;

  /// Shown in the button while nothing is picked.
  final String? hintText;

  /// Shown below the button when there is no [errorText].
  final String? helperText;

  /// An error (e.g. from the server after a submit), shown below the
  /// button, which takes the error border.
  final String? errorText;

  /// Shown before the button's text.
  final Widget? leadingIcon;

  /// Shown at the end of the button while the menu is closed (Flutter's
  /// default: `arrow_drop_down`).
  final Widget? trailingIcon;

  /// Shown at the end of the button while the menu is open (Flutter's
  /// default: `arrow_drop_up`).
  final Widget? selectedTrailingIcon;

  /// Whether a field at the top of the menu filters the entries as the
  /// user types (Flutter's default: false).
  ///
  /// `// web:` the filter field sits at the top of the open menu (like a
  /// shadcn select `withSearch`), not in the button: the button stays a
  /// button, so it keeps its keyboard and screen-reader behavior.
  final bool enableFilter;

  /// Whether typing on the button highlights the first entry that starts
  /// with the typed text (Flutter's default: true), like a native select.
  final bool enableSearch;

  /// Width of the button (and the least width of the menu). Default: the
  /// widest entry, like Flutter.
  final double? width;

  /// Largest height of the menu before it scrolls (default: the room on
  /// screen).
  final double? menuHeight;

  /// The button's look: border, padding, fill, hover, size limits, and
  /// the styles of the label, hint, helper and error texts.
  final InputDecorationTheme? inputDecorationTheme;

  /// The menu's look: fill, padding, border, corners, shadow, sizes.
  final MenuStyle? menuStyle;

  /// Style of the button's text.
  final TextStyle? textStyle;

  /// Whether the menu can be opened (Flutter's default: true).
  final bool enabled;

  /// Whether opening the menu focuses its filter field ([enableFilter]).
  /// Flutter's default (null): yes on desktop, no on phones (no keyboard
  /// popping up); here, no when the pointer is coarse.
  final bool? requestFocusOnTap;

  /// A `TextEditingController` field of a `ThorState`.
  ///
  /// `// web:` it holds the filter field's text ([enableFilter]), cleared
  /// each time the menu opens; the picked entry reaches [onSelected].
  final TextEditingController? controller;

  /// A `FocusNode` field of a `ThorState` that focuses the button from a
  /// method.
  final FocusNode? focusNode;

  /// When set, the menu takes its parent's full width, minus these insets
  /// (Flutter's `expandedInsets`).
  final EdgeInsetsGeometry? expandedInsets;

  /// Moves the menu from its place under the button (Flutter's
  /// `alignmentOffset`): `Offset(0, 4)` leaves a 4px gap.
  final Offset? alignmentOffset;

  /// `// web:` form field name: the picked value (`encodeArg`, like a
  /// `ThorState` argument) is posted under it.
  final String? name;

  /// `// web:` DOM id prefix of the parts (default: unique on the page).
  final String? id;

  /// `// web:` the look of the filter field ([enableFilter]): hint, icons,
  /// padding, border (default: an underlined `Search` field).
  final InputDecoration? searchDecoration;

  @override
  bool get fillsWidth => expandedInsets != null;

  @override
  Widget build(BuildContext context) {
    final registry = ThorStyleRegistry.active(context);
    registry?.useEngine();
    final id =
        this.id ?? registry?.uniqueId('t-dd') ?? 't-dd-${++_fallbackIds}';
    final listId = enableFilter ? '$id-list' : '$id-menu';
    final helpId = '$id-help';
    final entries = dropdownMenuEntries;
    final scope = name == null ? null : FormScope.maybeOf(context);
    // A form that decides the field (a failed submit, saved defaults) says
    // which entry is picked (none: the hint).
    final selected = scope != null && scope.decides(name!)
        ? entries.indexWhere((e) => encodeArg(e.value) == scope.valueOf(name!))
        : initialSelection == null
        ? -1
        : entries.indexWhere((e) => e.value == initialSelection);
    final errorText = this.errorText ?? scope?.errorTextOf(name!);
    final theme = inputDecorationTheme ?? const InputDecorationTheme();
    final padding = numericInsets(
      theme.contentPadding ?? const EdgeInsets.fromLTRB(16, 0, 12, 0),
      'DropdownMenu(inputDecorationTheme: contentPadding)',
    );
    final message = errorText ?? helperText;
    final error = errorText != null;
    final base =
        theme.enabledBorder ??
        theme.border ??
        const OutlineInputBorder(borderSide: BorderSide(color: _outline));
    final shown = error
        ? theme.errorBorder ??
              const OutlineInputBorder(
                borderSide: BorderSide(color: _error, width: 2),
              )
        : base;
    final focused = error
        ? shown
        : theme.focusedBorder ??
              OutlineInputBorder(
                borderRadius:
                    base.borderRadius ??
                    const BorderRadius.all(Radius.circular(4)),
                borderSide: const BorderSide(color: _primary, width: 2),
              );
    final radius = (shown.borderRadius ?? focused.borderRadius)?.css;
    final fieldRow = label == null ? '1' : '2';
    final labelText = switch (resolveComponent(label)) {
      final Text t => t.data,
      _ => null,
    };
    // The box the button draws; the no-JS select draws it too.
    final box = <String, String>{
      'box-sizing': 'border-box',
      'min-height': '56px',
      'padding': padding.css,
      'box-shadow': '${shown.shadow ?? '0 0 #0000'}, $_ring',
      'border-radius': ?radius,
      if (theme.filled)
        'background-color': (theme.fillColor ?? const Color(0x0A000000)).css,
      ...?theme.constraints?.toCss(),
      'font-size': ThemeTokens.bodyLargeSize,
      ...?textStyle?.toCss(),
    };

    final Widget closedIcon;
    final Widget? openIcon;
    if (trailingIcon == null && selectedTrailingIcon == null) {
      // One arrow, turned while open: the same pixels as Material's pair.
      closedIcon = const WrapWith(
        WrapData(
          css: {'transition': 'rotate 150ms'},
          conditions: [
            ConditionalCss(CssCondition.within('[aria-expanded="true"]'), {
              'rotate': '180deg',
            }),
            ConditionalCss(CssCondition.reducedMotion, {'transition': 'none'}),
          ],
        ),
        child: Icon(_dropDown),
      );
      openIcon = null;
    } else {
      closedIcon = WrapWith(
        const WrapData(
          conditions: [
            ConditionalCss(CssCondition.within('[aria-expanded="true"]'), {
              'display': 'none',
            }),
          ],
        ),
        child: trailingIcon ?? const Icon(_dropDown),
      );
      openIcon = WrapWith(
        const WrapData(
          css: {'display': 'none'},
          conditions: [
            ConditionalCss(CssCondition.within('[aria-expanded="true"]'), {
              'display': 'block',
            }),
          ],
        ),
        child: selectedTrailingIcon ?? const Icon(_dropUp),
      );
    }

    final button = thorElement(
      'button',
      debugName: 'DropdownMenuButton',
      baseCss: const {
        'appearance': 'none',
        'border': '0',
        'margin': '0',
        'font': 'inherit',
        'color': 'inherit',
        'background': 'none',
        'text-align': 'start',
        'outline': '0',
      },
      css: {
        'grid-row': fieldRow,
        'grid-column': '1',
        'display': 'flex',
        'align-items': 'center',
        'gap': '8px',
        'min-width': '0',
        'cursor': 'pointer',
        'anchor-name': _anchor,
        'transition-property': 'box-shadow, background-color',
        'transition-duration': '150ms',
        ...box,
      },
      conditions: [
        if (theme.hoverColor case final hover?)
          ConditionalCss(CssCondition.hoverEnabled, {
            'background-color': hover.css,
          }),
        if (focused.shadow case final ring?) ...[
          ConditionalCss(CssCondition.focused, {'box-shadow': '$ring, $_ring'}),
          ConditionalCss(
            const CssCondition.selector('[aria-expanded="true"]'),
            {'box-shadow': '$ring, $_ring'},
          ),
        ],
        const ConditionalCss(CssCondition.disabled, {
          'cursor': 'default',
          'opacity': '0.38',
        }),
        // No JS: the native select below is the control.
        const ConditionalCss(CssCondition.media('(scripting: none)'), {
          'display': 'none',
        }),
      ],
      attributes: {
        'type': 'button',
        'role': 'combobox',
        'aria-haspopup': 'listbox',
        'aria-expanded': 'false',
        'aria-controls': listId,
        'popovertarget': '$id-menu',
        'aria-label': ?labelText,
        if (message != null) 'aria-describedby': helpId,
        if (error) 'aria-invalid': 'true',
        if (!enabled) 'disabled': '',
        focusNodeAttr: ?controllerIdOf(focusNode),
      },
      children: [
        ?leadingIcon,
        thorElement(
          'span',
          css: const {
            'flex': '1 1 auto',
            'min-width': '0',
            'overflow': 'hidden',
            'text-overflow': 'ellipsis',
            'white-space': 'nowrap',
          },
          conditions: [
            ConditionalCss(const CssCondition.selector('[$dropdownHintAttr]'), {
              'color': _hint,
              ...?theme.hintStyle?.toCss(),
            }),
          ],
          attributes: {
            dropdownLabelAttr: '',
            if (selected < 0) dropdownHintAttr: '',
          },
          children: [
            Widget.text(
              selected < 0 ? hintText ?? '' : entries[selected].label,
            ),
          ],
        ),
        closedIcon,
        ?openIcon,
      ],
    );

    // The form's value, and the control without JS. Hidden with JS, it
    // still sizes the column to the widest entry (Flutter's default width).
    final lead = leadingIcon == null ? 0.0 : 32.0;
    final select = thorElement(
      'select',
      baseCss: const {'margin': '0', 'font': 'inherit', 'color': 'inherit'},
      css: {
        'grid-row': fieldRow,
        'grid-column': '1',
        'align-self': 'start',
        'box-sizing': 'border-box',
        'min-width': '0',
        'visibility': 'hidden',
        'height': '0',
        'border': '0',
        'appearance': 'none',
        'pointer-events': 'none',
        'font-size': ?box['font-size'],
        ...?textStyle?.toCss(),
        'padding':
            '0 ${cssPx(padding.right + 32)} 0 ${cssPx(padding.left + lead)}',
      },
      conditions: [
        ConditionalCss(const CssCondition.media('(scripting: none)'), {
          ...box,
          'visibility': 'visible',
          'height': 'auto',
          'appearance': 'auto',
          'pointer-events': 'auto',
          'background-color': ?box['background-color'],
          'cursor': 'pointer',
        }),
      ],
      attributes: {
        'name': ?name,
        'aria-label': ?(labelText ?? hintText),
        if (!enabled) 'disabled': '',
        ...engineAttributes({'change': onSelected}),
      },
      children: [
        if (selected < 0)
          Widget.element(
            tag: 'option',
            attributes: const {
              'value': '',
              'disabled': '',
              'selected': '',
              'hidden': '',
            },
            children: [Widget.text(hintText ?? '')],
          ),
        for (var i = 0; i < entries.length; i++)
          Widget.element(
            tag: 'option',
            attributes: {
              'value': encodeArg(entries[i].value),
              if (i == selected) 'selected': '',
              if (!entries[i].enabled) 'disabled': '',
            },
            children: [Widget.text(entries[i].label)],
          ),
      ],
    );

    final options = [
      for (var i = 0; i < entries.length; i++)
        _entry(entries[i], selected: i == selected),
    ];
    final style = menuStyle?._css ?? const {};
    final dy = alignmentOffset?.dy ?? 0;
    final dx = alignmentOffset?.dx ?? 0;
    final panel = thorElement(
      'div',
      id: '$id-menu',
      debugName: 'DropdownMenuPanel',
      css: {
        'position-anchor': _anchor,
        // The UA centers popovers (`inset: 0`); anchoring needs auto.
        'inset': 'auto',
        // Under the button, from its start edge; above it when it doesn't
        // fit below.
        'position-area': 'block-end span-inline-end',
        'position-try-fallbacks': 'flip-block',
        'margin': '${cssPx(dy)} 0 ${cssPx(dy)} ${cssPx(dx)}',
        'box-sizing': 'border-box',
        'min-width': 'anchor-size(width)',
        'max-width': 'calc(100vw - 16px)',
        'max-height': menuHeight == null
            ? 'calc(100dvh - 16px)'
            : 'min(${cssPx(menuHeight!)}, calc(100dvh - 16px))',
        'padding': '8px 0',
        'border': '0',
        'border-radius': '4px',
        'background-color': ThemeTokens.surfaceContainer,
        'color': 'inherit',
        'box-shadow':
            '0 1px 3px rgba(0, 0, 0, 0.3), 0 4px 8px 3px rgba(0, 0, 0, 0.15)',
        if (!enableFilter) ...{
          'overflow-y': 'auto',
          'overscroll-behavior': 'contain',
        },
        ...style,
      },
      conditions: [
        if (enableFilter)
          const ConditionalCss(CssCondition.selector(':popover-open'), {
            'display': 'flex',
            'flex-direction': 'column',
          }),
      ],
      attributes: {
        'popover': 'auto',
        if (!enableFilter) ...{'role': 'listbox', 'aria-label': ?labelText},
      },
      children: enableFilter
          ? [
              // Never widens the menu: it takes the width the entries give.
              WrapWith(
                const WrapData(
                  css: {'width': '0', 'min-width': '100%', 'flex': 'none'},
                ),
                child: TextField(
                  decoration:
                      searchDecoration ??
                      InputDecoration(
                        hintText: MaterialLocalizations.of(
                          context,
                        ).searchFieldLabel,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: const UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Color.variable(
                              CssVariable('--t-outline-variant'),
                              fallback: Color(0xFFCAC4D0),
                            ),
                          ),
                        ),
                      ),
                  controller: controller,
                  inputAttributes: trustedAttributes({
                    'role': 'combobox',
                    'aria-autocomplete': 'list',
                    'aria-expanded': 'true',
                    'aria-controls': listId,
                    'autocomplete': 'off',
                    'spellcheck': 'false',
                  }),
                ),
              ),
              thorElement(
                'div',
                id: listId,
                css: const {
                  'flex': '1 1 auto',
                  'min-height': '0',
                  'overflow-y': 'auto',
                  'overscroll-behavior': 'contain',
                },
                attributes: {'role': 'listbox', 'aria-label': ?labelText},
                children: options,
              ),
            ]
          : options,
    );

    const messageCss = {
      // Never widens the column: it wraps under the button.
      'width': '0',
      'min-width': '100%',
      'font-size': '12px',
      'line-height': '16px',
      'padding': '0 16px',
      'box-sizing': 'border-box',
    };
    return thorElement(
      'div',
      debugName: 'DropdownMenu',
      fillsWidth: expandedInsets != null,
      css: {
        'display': expandedInsets == null ? 'inline-grid' : 'grid',
        'row-gap': '4px',
        'vertical-align': 'top',
        'min-width': '0',
        'anchor-scope': _anchor,
        if (width != null) 'width': cssPx(width!),
        if (expandedInsets case final m?) ...m.toCss('margin'),
      },
      attributes: {
        dropdownAttr: [
          if (enableSearch) 's',
          if (requestFocusOnTap == true) 'f',
          if (requestFocusOnTap == false) 'n',
        ].join(),
      },
      children: [
        if (label != null)
          WrapWith(
            WrapData(
              css: {
                'width': '0',
                'min-width': '100%',
                'font-size': '14px',
                'line-height': '20px',
                'font-weight': '500',
                ...?theme.labelStyle?.toCss(),
              },
            ),
            child: label!,
          ),
        button,
        select,
        if (message != null)
          thorElement(
            'span',
            id: helpId,
            css: {
              ...messageCss,
              'color': error ? _error.css : _onSurfaceVariant,
              ...?(error ? theme.errorStyle : theme.helperStyle)?.toCss(),
            },
            children: [Widget.text(message)],
          ),
        panel,
      ],
    );
  }

  Widget _entry(DropdownMenuEntry<T> e, {required bool selected}) {
    final s = e.style;
    return thorElement(
      'div',
      css: {
        'display': 'flex',
        'align-items': 'center',
        'gap': '12px',
        'box-sizing': 'border-box',
        'min-height': '48px',
        'padding': '0 12px',
        'cursor': 'pointer',
        'user-select': 'none',
        'font-size': ThemeTokens.labelLargeSize,
        'letter-spacing': ThemeTokens.labelLargeTracking,
        if (s != null) ...buttonStyleCss(s),
      },
      conditions: [
        ConditionalCss(const CssCondition.selector('[$dropdownActiveAttr]'), {
          'background-color':
              s?.overlayAt(WidgetState.hovered)?.css ?? _highlight,
        }),
        const ConditionalCss(CssCondition.selector('[aria-disabled="true"]'), {
          'opacity': '0.38',
          'cursor': 'default',
        }),
        // Filtered out (`hidden`): the row's display must not win.
        const ConditionalCss(CssCondition.selector('[hidden]'), {
          'display': 'none',
        }),
      ],
      attributes: {
        'role': 'option',
        'aria-selected': '$selected',
        if (!e.enabled) 'aria-disabled': 'true',
      },
      children: [
        ?e.leadingIcon,
        e.labelWidget ?? Widget.text(e.label),
        if (e.trailingIcon case final t?)
          WrapWith(
            const WrapData(css: {'margin-inline-start': 'auto'}),
            child: t,
          ),
      ],
    );
  }
}
