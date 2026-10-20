/// The tabs' and the menus' keyboard ([TabsFeature], [MenuFeature]).
library;

import 'dart:js_interop';

import 'package:thor_engine/src/protocol.dart';
import 'package:thor_engine_oracle/client.dart' show EngineFeature, EngineRun;
import 'package:web/web.dart' as web;

/// The WAI-ARIA tabs pattern over a `TabBar`'s radios.
///
/// The lite engine's `tabs` part does the work (roles, roving tabindex,
/// arrow keys). This comparison engine is never shipped, so it leaves the
/// bar as the server wrote it: native radios with their own arrow keys.
final class TabsFeature extends EngineFeature {
  /// The feature.
  const TabsFeature();
}

/// The divider of a `SplitPane`.
///
/// The lite engine's `split_pane` part does the work (pointer drag, arrows,
/// Home/End, `aria-valuenow`). This comparison engine is never shipped, so it
/// leaves the divider as the server wrote it.
final class SplitPaneFeature extends EngineFeature {
  /// The feature.
  const SplitPaneFeature();
}

/// The menu keyboard of `PopupMenuButton`, `MenuAnchor` and `SubmenuButton`.
///
/// The lite engine's `menu` part does the work (arrows, Home/End,
/// type-ahead, submenus). This comparison engine is never shipped, so the
/// popover keeps its native keys (Tab, Esc, light dismiss), but its markup
/// follows the part's, since the conformance compares the DOM: a panel
/// becomes a `menu` (its buttons and links `menuitem`s) as it first opens,
/// its items leave the Tab order while it is open, and a menu the keyboard
/// opened focuses its first item.
final class MenuFeature extends EngineFeature {
  /// The feature.
  const MenuFeature();

  @override
  void Function()? install(web.Element scope, EngineRun run) {
    final root = web.document.documentElement!;
    // How the last input came: the focus goes into a menu the keyboard
    // opened, not into one the pointer did.
    var byKey = false;
    final onKey = ((web.Event _) => byKey = true).toJS;
    final onPointer = ((web.Event _) => byKey = false).toJS;
    final onBefore = ((web.ToggleEvent e) {
      final panel = _panel(e);
      if (panel != null && e.newState == 'open') _promote(panel);
    }).toJS;
    final onToggle = ((web.ToggleEvent e) {
      final panel = _panel(e);
      if (panel == null) return;
      final open = e.newState == 'open';
      // A menu that opened before this feature was installed.
      if (open) _promote(panel);
      final items = _itemsOf(panel);
      if (!open) {
        // Back in the Tab order (the menu is a plain list again).
        for (final x in items) {
          x.removeAttribute('tabindex');
        }
        return;
      }
      final active = web.document.activeElement;
      for (final x in items) {
        x.tabIndex = identical(x, active) ? 0 : -1;
      }
      if (byKey &&
          items.isNotEmpty &&
          !items.any((x) => identical(x, active)) &&
          !panel.contains(active)) {
        items.first
          ..tabIndex = 0
          ..focus();
      }
    }).toJS;
    root
      ..addEventListener('keydown', onKey, true.toJS)
      ..addEventListener('pointerdown', onPointer, true.toJS)
      // `beforetoggle` and `toggle` don't bubble.
      ..addEventListener('beforetoggle', onBefore, true.toJS)
      ..addEventListener('toggle', onToggle, true.toJS);
    return () => root
      ..removeEventListener('keydown', onKey, true.toJS)
      ..removeEventListener('pointerdown', onPointer, true.toJS)
      ..removeEventListener('beforetoggle', onBefore, true.toJS)
      ..removeEventListener('toggle', onToggle, true.toJS);
  }
}

const _panelSelector = '[$menuAttr]';

/// The menu panel an event is about, if it is one.
web.Element? _panel(web.Event e) {
  final t = e.target;
  if (t == null || !t.isA<web.Element>()) return null;
  final panel = t as web.Element;
  return panel.matches(_panelSelector) ? panel : null;
}

/// The usable items of [panel], not those of a submenu inside it.
List<web.HTMLElement> _itemsOf(web.Element panel) {
  final found = panel.querySelectorAll('[role^="menuitem"]');
  return [
    for (var i = 0; i < found.length; i++)
      if (found.item(i)! as web.HTMLElement case final x
          when identical(x.closest(_panelSelector), panel) && _usable(x))
        x,
  ];
}

bool _usable(web.HTMLElement x) =>
    !x.hasAttribute('disabled') &&
    x.getAttribute('aria-disabled') != 'true' &&
    !x.hasAttribute('hidden');

/// A panel is a menu from its first opening on (a closed popover is not in
/// the accessibility tree, so nothing is announced before).
void _promote(web.Element panel) {
  if (panel.hasAttribute('role')) return;
  panel.setAttribute('role', 'menu');
  final raw = panel.querySelectorAll('button,a[href],[role^="menuitem"]');
  for (var i = 0; i < raw.length; i++) {
    final x = raw.item(i)! as web.Element;
    if (identical(x.closest(_panelSelector), panel) &&
        !x.hasAttribute('role')) {
      x.setAttribute('role', 'menuitem');
    }
  }
}
