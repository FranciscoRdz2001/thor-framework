import 'package:thor_engine/thor_engine.dart' show tabsAttr;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../engine/watch.dart' show engineAttributes;
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/errors.dart';
import '../foundation/layout_hint.dart';
import '../foundation/native_id.dart';
import '../foundation/parent_data.dart';
import '../foundation/style_registry.dart';
import '../foundation/theme_tokens.dart';
import '../foundation/transparent.dart';
import 'basic.dart' show boxCss;
import 'component_themes.dart' show TabBarThemeData;
import 'theme.dart' show Theme;

const _primary = ThemeTokens.primary;
const _onSurfaceVariant = ThemeTokens.onSurfaceVariant;
const _hover = 'color-mix(in srgb, ${ThemeTokens.onSurface} 8%, transparent)';

final _validId = RegExp(r'^[A-Za-z][A-Za-z0-9_-]*$');

// Tabs with no JS: the selection is a native radio group, one radio
// inside each tab's <label>. The browser gives the keyboard model of
// automatic-activation tabs (one Tab stop, arrows move and select, Home/End
// in some browsers), restores the choice on back/forward, and `:has()` shows
// the panel of the checked radio. Semantics are the radios' own
// (`radiogroup` / `radio`, "2 of 3, selected"): `role=tab` is not allowed on
// an <input>, and `aria-selected` would go stale without JS.
//
// With the lite engine the `tabs` part promotes the bar to the WAI-ARIA
// tabs pattern: `tablist` / `tab` / `tabpanel`, `aria-selected`, a roving
// tabindex and Left/Right/Home/End on the focused tab.

/// Flutter's `DefaultTabController`: the shared selection of the `TabBar`
/// and `TabBarView` below it.
///
/// `// web:` [id] names the native radio group and the panels' ids (like
/// `Drawer(id:)`); it must be unique in the page and a plain identifier
/// (letters, digits, `-`, `_`), or the build throws an [ArgumentError].
/// There is no `TabController` object: the browser holds the selection;
/// `TabBar.onTap` tells a `ThorState` when it changes.
class DefaultTabController extends StatelessWidget implements ThorBuiltIn {
  /// Creates the selection scope for [length] tabs.
  const DefaultTabController({
    super.key,
    this.id,
    required this.length,
    this.initialIndex = 0,
    required this.child,
  }) : assert(length >= 0),
       assert(length == 0 || (initialIndex >= 0 && initialIndex < length));

  /// `// web:` name of the radio group; prefix of the tab and panel ids.
  /// Optional: without one it is named by its `ValueKey` or its place in
  /// the page (the same on every render).
  final String? id;

  /// Number of tabs (the `TabBar.tabs` and `TabBarView.children` count).
  final int length;

  /// The tab selected when the page loads (Flutter's default: 0).
  final int initialIndex;

  /// The subtree with the `TabBar` and the `TabBarView`.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final id = nativeId(context, prefix: 'tabs', id: this.id, key: key);
    if (!_validId.hasMatch(id)) {
      throw ArgumentError.value(
        id,
        'id',
        'DefaultTabController.id must be letters, digits, - or _ '
            '(it is a DOM id and a CSS attribute value)',
      );
    }
    return _TabScope(controller: this, id: id, child: child);
  }
}

class _TabScope extends InheritedWidget {
  const _TabScope({
    required this.controller,
    required this.id,
    required super.child,
  });

  final DefaultTabController controller;

  /// The DOM id in use (the given one or the automatic one).
  final String id;

  int get length => controller.length;

  int get initialIndex => controller.initialIndex;

  static _TabScope of(BuildContext context, String widget) {
    final scope = context.dependOnInheritedWidgetOfExactType<_TabScope>();
    if (scope == null) {
      throw StateError(
        thorError(
          'THOR-R008',
          'No DefaultTabController for $widget: put the $widget below a '
              'DefaultTabController (Flutter throws too).',
        ),
      );
    }
    return scope;
  }

  @override
  bool updateShouldNotify(_TabScope oldWidget) =>
      oldWidget.controller != controller || oldWidget.id != id;
}

/// Flutter's `Tab`: a [text], an [icon] (above the text when both), or a
/// custom [child].
class Tab extends StatelessWidget implements ThorElementWidget, ThorBuiltIn {
  /// Creates a tab's content.
  const Tab({
    super.key,
    this.text,
    this.icon,
    this.iconMargin,
    this.height,
    this.child,
  }) : assert(text != null || child != null || icon != null),
       assert(text == null || child == null);

  /// Label of the tab (one line, ellipsis when it doesn't fit).
  final String? text;

  /// Icon of the tab.
  final Widget? icon;

  /// Space between [icon] and the text (Flutter's default: 2 px below the
  /// icon).
  final EdgeInsetsGeometry? iconMargin;

  /// Height of the tab (Flutter's default: 48, or 72 with icon and text).
  final double? height;

  /// Custom content (instead of [text]).
  final Widget? child;

  double get _height =>
      height ?? (icon != null && (text != null || child != null) ? 72 : 48);

  /// Inside a `TabBar` the tab's `<label>` holds this content directly;
  /// alone it is a `<span>` with the same content.
  @override
  Widget build(BuildContext context) => thorElement(
    'span',
    debugName: 'Tab',
    css: {
      'display': 'inline-flex',
      'flex-direction': 'column',
      'align-items': 'center',
      'justify-content': 'center',
      'min-height': cssPx(_height),
    },
    children: _content,
  );

  List<Widget> get _content => [
    if (icon != null)
      if (text != null || child != null)
        WrapWith(
          WrapData(css: (iconMargin ?? _iconMargin).toCss('margin')),
          child: icon!,
        )
      else
        icon!,
    if (text != null)
      thorElement('span', css: _ellipsis, children: [Widget.text(text!)])
    else
      ?child,
  ];

  static const _iconMargin = EdgeInsets.only(bottom: 2);
}

const _ellipsis = {
  'max-width': '100%',
  'overflow': 'hidden',
  'text-overflow': 'ellipsis',
  'white-space': 'nowrap',
};

/// Flutter's `TabBar` (Material 3 primary tabs), with no JS: each tab is a
/// `<label>` around a visually hidden radio of the `DefaultTabController`'s
/// group. Arrow keys move the selection natively; the checked tab shows
/// the indicator and its `TabBarView` panel (`:has()`).
///
/// ```dart
/// DefaultTabController(
///   id: 'order',
///   length: 2,
///   child: Column(children: [
///     const TabBar(tabs: [Tab(text: 'Details'), Tab(text: 'Payments')]),
///     const TabBarView(children: [Text('…'), Text('…')]),
///   ]),
/// )
/// ```
///
/// `// web:` the indicator spans the whole tab (`TabBarIndicatorSize.tab`)
/// and doesn't slide between tabs; the selection is exposed as a radio
/// group until the engine loads, then as tabs.
/// In forced-colors mode (Windows High Contrast) the selected tab is
/// underlined with the text, since the indicator is a shadow the browser
/// drops.
class TabBar extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a Material 3 tab bar.
  const TabBar({
    super.key,
    required this.tabs,
    this.isScrollable = false,
    this.onTap,
    this.indicatorColor,
    this.labelColor,
    this.unselectedLabelColor,
    this.dividerColor,
    this.labelStyle,
    this.labelPadding,
  });

  /// The tabs, usually [Tab]s; as many as the controller's `length`.
  final List<Widget> tabs;

  /// Tabs as wide as their content, scrolling horizontally when they
  /// don't fit (default: equal shares of the bar, labels cut with an
  /// ellipsis).
  final bool isScrollable;

  /// Called with the index of the newly selected tab (a `ThorState`
  /// method, e.g. `order.setTab`).
  final ValueChanged<int>? onTap;

  /// Color of the selected tab's underline (default: `primary`).
  final Color? indicatorColor;

  /// Color of the selected tab's label (default: `primary`).
  final Color? labelColor;

  /// Color of the other labels (default: `onSurfaceVariant`).
  final Color? unselectedLabelColor;

  /// Color of the 1 px line under the bar (default: `outlineVariant`).
  final Color? dividerColor;

  /// Font of the labels (default: the theme's, else the title-small role).
  final TextStyle? labelStyle;

  /// Space inside each tab on the inline axis (default: the theme's, else
  /// 16).
  final EdgeInsetsGeometry? labelPadding;

  @override
  bool get fillsWidth => true;

  @override
  Widget build(BuildContext context) {
    final c = _TabScope.of(context, 'TabBar');
    if (c.length != tabs.length) {
      throw StateError(
        thorError(
          'THOR-R009',
          "DefaultTabController's length (${c.length}) does not match the "
              'number of tabs (${tabs.length}) in the TabBar.',
        ),
      );
    }
    // The parameter, else `ThemeData.tabBarTheme`, else Flutter's default.
    final theme = Theme.of(context).tabBarTheme;
    final divider =
        (dividerColor ?? theme?.dividerColor)?.css ??
        ThemeTokens.outlineVariant;
    return thorElement(
      'div',
      debugName: 'TabBar',
      fillsWidth: true,
      css: {
        'display': 'flex',
        'box-sizing': 'border-box',
        'min-width': '0',
        'box-shadow': 'inset 0 -1px 0 $divider',
        if (isScrollable) ...{
          'overflow-x': 'auto',
          'scrollbar-width': 'none',
          'overscroll-behavior-x': 'contain',
        },
      },
      attributes: const {'role': 'radiogroup', tabsAttr: ''},
      children: [for (final (i, t) in tabs.indexed) _tab(c, t, i, theme)],
    );
  }

  Widget _tab(_TabScope c, Widget tab, int index, TabBarThemeData? theme) {
    final labelColor = this.labelColor ?? theme?.labelColor;
    final unselectedLabelColor =
        this.unselectedLabelColor ?? theme?.unselectedLabelColor;
    final indicatorColor = this.indicatorColor ?? theme?.indicatorColor;
    final padding = labelPadding ?? theme?.labelPadding;
    // Also a Tab an app component builds.
    final t = switch (resolveComponent(tab)) {
      final Tab t => t,
      _ => null,
    };
    // A text-only tab is one block line: the label itself cuts the text.
    final textOnly = t != null && t.icon == null && t.text != null;
    final height = t?._height ?? 48;
    final selected = labelColor?.css ?? _primary;
    return thorElement(
      'label',
      id: '${c.id}-tab-$index',
      debugName: 'Tab',
      css: {
        'position': 'relative',
        'box-sizing': 'border-box',
        'min-height': cssPx(height),
        ...(padding?.toCss('padding') ?? const {'padding-inline': '16px'}),
        if (isScrollable)
          'flex': 'none'
        else ...{
          'flex': '1 1 0',
          'min-width': '0',
        },
        if (textOnly) ...{
          'display': 'block',
          'line-height': cssPx(height),
          'text-align': 'center',
          ..._ellipsis,
        } else ...{
          'display': 'flex',
          'flex-direction': 'column',
          'align-items': 'center',
          'justify-content': 'center',
        },
        'font-size': 'var(--t-title-small-size, 14px)',
        'letter-spacing': 'var(--t-title-small-tracking, normal)',
        'font-weight': 'var(--t-title-small-weight, 500)',
        'color': unselectedLabelColor?.css ?? _onSurfaceVariant,
        'cursor': 'pointer',
        'user-select': 'none',
        '-webkit-tap-highlight-color': 'transparent',
        ...?(labelStyle ?? theme?.labelStyle)?.toCss(),
      },
      conditions: [
        ConditionalCss(const CssCondition.selector(':has(:checked)'), {
          'color': selected,
          'box-shadow':
              'inset 0 -3px 0 ${indicatorColor?.css ?? labelColor?.css ?? _primary}',
        }),
        const ConditionalCss(CssCondition.hover, {'background-color': _hover}),
        // The radio has the focus (no engine), or the tab itself (the `tabs`
        // part makes the label the tab).
        const ConditionalCss(CssCondition.selector(':has(:focus-visible)'), {
          'outline': '2px solid $_primary',
          'outline-offset': '-2px',
        }),
        const ConditionalCss(CssCondition.focused, {
          'outline': '2px solid $_primary',
          'outline-offset': '-2px',
        }),
        // web: forced colors drop the box-shadow that marks the selection.
        ConditionalCss(
          CssCondition.both(
            CssCondition.forcedColors,
            const CssCondition.selector(':has(:checked)'),
          ),
          const {
            'box-shadow': 'none',
            'text-decoration': 'underline',
            'text-decoration-thickness': '3px',
            'text-underline-offset': '6px',
          },
        ),
      ],
      children: [
        thorElement(
          'input',
          css: const {
            'position': 'absolute',
            'inset-inline-start': '0',
            'top': '0',
            'width': '1px',
            'height': '1px',
            'margin': '0',
            'opacity': '0',
            'pointer-events': 'none',
          },
          attributes: {
            'type': 'radio',
            'name': c.id,
            'value': '$index',
            if (index == c.initialIndex) 'checked': '',
            'aria-controls': '${c.id}-panel-$index',
            ...engineAttributes({'change': onTap}, arg: index),
          },
        ),
        if (t == null)
          tab
        else if (textOnly)
          Widget.text(t.text!)
        else
          ...t._content,
      ],
    );
  }
}

/// Flutter's `TabBarView`: one panel per tab; only the selected tab's panel
/// is shown, by CSS (`:has()` on the checked radio), with no JS.
///
/// `// web:` no swipe between panels (the tabs are the only way to switch)
/// and no slide animation. If the browser lacks `:has()`, every panel is
/// shown: the content stays reachable.
class TabBarView extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates the panels of a `DefaultTabController`.
  const TabBarView({super.key, required this.children});

  /// One widget per tab, in the same order.
  final List<Widget> children;

  @override
  bool get fillsWidth => true;

  @override
  Widget build(BuildContext context) {
    final c = _TabScope.of(context, 'TabBarView');
    if (c.length != children.length) {
      throw StateError(
        thorError(
          'THOR-R009',
          "DefaultTabController's length (${c.length}) does not match the "
              'number of children (${children.length}) in the TabBarView.',
        ),
      );
    }
    return thorElement(
      'div',
      debugName: 'TabBarView',
      fillsWidth: true,
      css: boxCss,
      childRules: ChildRules.column,
      children: [
        for (final (i, child) in children.indexed)
          thorElement(
            'div',
            id: '${c.id}-panel-$i',
            css: const {...boxCss, 'flex': '1 1 auto'},
            conditions: [
              // Hidden while *another* radio of the group is checked: with
              // no `:has()` support every panel stays visible (fail open).
              ConditionalCss(
                CssCondition.within(
                  ':root:has(input[name="${c.id}"]:checked:not([value="$i"]))',
                ),
                const {'display': 'none'},
              ),
            ],
            attributes: {
              'role': 'group',
              'aria-labelledby': '${c.id}-tab-$i',
              'tabindex': '0',
            },
            childRules: ChildRules.column,
            children: [child],
          ),
      ],
    );
  }
}
