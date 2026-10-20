/// Keyboard shortcuts in the page: thor_ui's `CallbackShortcuts` (the
/// `data-tks` marker), `Shortcuts` + `Actions` (`data-tsi`, `data-tai`),
/// `Focus(onKeyEvent:)` (`data-tke`) and [HardwareKeyboard]'s modifiers.
library;

import 'dart:js_interop';

import 'package:thor_engine/src/clipboard.dart';
import 'package:thor_engine/src/keyboard.dart';
import 'package:thor_engine/src/protocol.dart';
import 'package:thor_engine_oracle/client.dart' show EngineFeature, EngineRun;
import 'package:web/web.dart' as web;

/// `CallbackShortcuts` and `HardwareKeyboard`.
///
/// One `keydown` listener on the page: from the event's target outward,
/// the first element whose shortcuts match the key runs its method and
/// stops the key there (like Flutter, where the innermost `Shortcuts`
/// wins). An element's `onCharacter` comes after its own bindings and
/// gets the typed character. A text field keeps the keys it edits with (letters, arrows,
/// Backspace…): shortcuts only see those when the field doesn't use them.
final class ShortcutsFeature extends EngineFeature {
  /// The feature.
  const ShortcutsFeature();

  @override
  void Function()? install(web.Element scope, EngineRun run) {
    void sync(web.Event e) {
      if (e.isA<web.KeyboardEvent>()) {
        final k = e as web.KeyboardEvent;
        HardwareKeyboard.instance.syncModifiers(
          shift: k.shiftKey,
          control: k.ctrlKey,
          alt: k.altKey,
          meta: k.metaKey,
        );
      } else if (e.isA<web.MouseEvent>()) {
        final m = e as web.MouseEvent;
        HardwareKeyboard.instance.syncModifiers(
          shift: m.shiftKey,
          control: m.ctrlKey,
          alt: m.altKey,
          meta: m.metaKey,
        );
      }
    }

    // The shortcuts of [el] that match [e]: runs the first and stops the
    // key there (true).
    bool fire(web.Element el, web.KeyboardEvent e) {
      for (final (spec, id) in decodeShortcuts(
        el.getAttribute(shortcutsAttr)!,
      )) {
        if (spec == anyCharacterSpec) {
          if (!isPrintableKey(
            e.key,
            control: e.ctrlKey,
            alt: e.altKey,
            meta: e.metaKey,
          )) {
            continue;
          }
          e.preventDefault();
          e.stopPropagation();
          final (member, arg) = parseBindingId(id);
          run(member, null, arg == null ? e.key : bindingId(arg, e.key));
          return true;
        }
        if (!shortcutMatches(
          spec,
          e.key,
          control: e.ctrlKey,
          shift: e.shiftKey,
          alt: e.altKey,
          meta: e.metaKey,
          repeat: e.repeat,
          code: e.code,
          textSelected: web.window.getSelection()?.isCollapsed == false,
        )) {
          continue;
        }
        e.stopPropagation();
        final (member, arg) = parseBindingId(id);
        run(member, null, arg);
        // A method that copies or pastes waits for this key's own
        // clipboard event (no permission prompt): let the key through.
        if (!(Clipboard.driver?.waitsForEvent ?? false)) e.preventDefault();
        return true;
      }
      return false;
    }

    // Actions: the one nearest [from] (Flutter looks from the focus) with an
    // action for [intent] runs it and stops the key (true); none, or a
    // `DoNothingAction(consumesKey: false)`, lets the key go on.
    bool act(web.Element from, String intent, web.KeyboardEvent e) {
      for (
        var a = from.closest('[$actionsAttr]');
        a != null;
        a = a.parentElement?.closest('[$actionsAttr]')
      ) {
        final id = actionFor(a.getAttribute(actionsAttr)!, intent);
        if (id == null) continue;
        if (id == ignoreKeyAction) return false;
        e
          ..preventDefault()
          ..stopPropagation();
        if (id.isNotEmpty) run(id, null);
        return true;
      }
      return false;
    }

    // Shortcuts: the first activator that matches names the intent.
    bool intents(web.Element el, web.KeyboardEvent e, {required bool root}) {
      for (final (spec, intent) in decodeShortcuts(
        el.getAttribute(intentShortcutsAttr)!,
      )) {
        if (shortcutMatches(
          spec,
          e.key,
          control: e.ctrlKey,
          shift: e.shiftKey,
          alt: e.altKey,
          meta: e.metaKey,
          repeat: e.repeat,
          code: e.code,
          textSelected: web.window.getSelection()?.isCollapsed == false,
        )) {
          final target = e.target;
          final from = root || target == null || !target.isA<web.Element>()
              ? el
              : target as web.Element;
          return act(from, intent, e);
        }
      }
      return false;
    }

    // Focus(onKeyEvent:): the method gets the KeyEvent and says what it did.
    bool onKeyEvent(web.Element el, web.KeyboardEvent e) {
      final result = run(
        el.getAttribute(keyEventAttr)!,
        null,
        encodeKeyEvent(e.key, e.code, repeat: e.repeat),
      );
      if (result == KeyEventResult.handled) {
        e
          ..preventDefault()
          ..stopPropagation();
      }
      return result == KeyEventResult.handled ||
          result == KeyEventResult.skipRemainingHandlers;
    }

    // An element's handlers, like the lite part's walk: onKeyEvent, then
    // Shortcuts, then CallbackShortcuts. With nothing focused ([root]) only
    // the shortcuts answer.
    bool handle(web.Element el, web.KeyboardEvent e, {bool root = false}) =>
        (!root && el.hasAttribute(keyEventAttr) && onKeyEvent(el, e)) ||
        (el.hasAttribute(intentShortcutsAttr) && intents(el, e, root: root)) ||
        (el.hasAttribute(shortcutsAttr) && fire(el, e));

    const walk = '[$keyEventAttr],[$intentShortcutsAttr],[$shortcutsAttr]';
    const rootWalk = '[$intentShortcutsAttr],[$shortcutsAttr]';

    // web: nothing focused (the key's target is <body>) is Flutter's root
    // focus: the shortcuts declared highest in the tree (an app's or a
    // layout's) answer, the outermost shortcut elements on view.
    void fireOutermost(web.KeyboardEvent e) {
      final all = scope.querySelectorAll(rootWalk);
      for (var i = 0; i < all.length; i++) {
        final el = all.item(i)! as web.Element;
        if (el.parentElement?.closest(rootWalk) != null) continue;
        if (!el.checkVisibility()) continue;
        if (handle(el, e, root: true)) return;
      }
    }

    bool unfocused(web.Element origin) =>
        origin == web.document.body || origin == web.document.documentElement;

    final onKey = ((web.KeyboardEvent e) {
      sync(e);
      if (e.isComposing || e.defaultPrevented) return;
      final target = e.target;
      if (target == null || !target.isA<web.Element>()) return;
      final origin = target as web.Element;
      if (consumesKey(
        origin,
        physicalKeyName(e.key, e.code) ?? e.key,
        modified: e.ctrlKey || e.metaKey || e.altKey,
      )) {
        return;
      }
      for (
        var el = origin.closest(walk);
        el != null;
        el = el.parentElement?.closest(walk)
      ) {
        if (handle(el, e)) return;
      }
      if (unfocused(origin)) fireOutermost(e);
    }).toJS;
    // A scope inside the page (not the whole document) never sees a key
    // whose target is <body>: listen for those on the document.
    final onRootKey = ((web.KeyboardEvent e) {
      final target = e.target;
      if (e.isComposing || e.defaultPrevented) return;
      if (target == null || !target.isA<web.Element>()) return;
      if (unfocused(target as web.Element)) fireOutermost(e);
    }).toJS;
    final coversBody = scope.contains(web.document.body);
    final onSync = sync.toJS;
    final onBlur = ((web.Event _) => HardwareKeyboard.instance.syncModifiers(
      shift: false,
      control: false,
      alt: false,
      meta: false,
    )).toJS;
    scope.addEventListener('keydown', onKey);
    if (!coversBody) web.document.addEventListener('keydown', onRootKey);
    scope.addEventListener('keyup', onSync, true.toJS);
    scope.addEventListener('pointerdown', onSync, true.toJS);
    web.window.addEventListener('blur', onBlur);
    return () {
      scope.removeEventListener('keydown', onKey);
      if (!coversBody) web.document.removeEventListener('keydown', onRootKey);
      scope.removeEventListener('keyup', onSync, true.toJS);
      scope.removeEventListener('pointerdown', onSync, true.toJS);
      web.window.removeEventListener('blur', onBlur);
    };
  }
}

const _editingKeys = {
  'ArrowLeft',
  'ArrowRight',
  'ArrowUp',
  'ArrowDown',
  'Home',
  'End',
  'PageUp',
  'PageDown',
  'Backspace',
  'Delete',
};

const _textInputTypes = {
  'text',
  'search',
  'url',
  'email',
  'tel',
  'password',
  'number',
  'date',
  'datetime-local',
  'time',
  'month',
  'week',
};

/// Whether [el] uses [key] itself (a text field moving its caret, a
/// checkbox toggling on Space, a button pressing on Enter), so no
/// shortcut sees it. [modified]: Control, Meta or Alt is held (then a
/// field only keeps its own editing commands: select all, copy, cut,
/// paste, undo, redo).
bool consumesKey(web.Element el, String key, {required bool modified}) {
  final printable = key.length == 1;
  if (el.isA<web.HTMLTextAreaElement>() ||
      (el.isA<web.HTMLElement>() &&
          (el as web.HTMLElement).isContentEditable)) {
    if (modified) return 'acvxyz'.contains(key.toLowerCase()) && printable;
    return printable || _editingKeys.contains(key) || key == 'Enter';
  }
  if (el.isA<web.HTMLInputElement>()) {
    final type = (el as web.HTMLInputElement).type;
    if (_textInputTypes.contains(type)) {
      if (modified) return 'acvxyz'.contains(key.toLowerCase()) && printable;
      return printable || _editingKeys.contains(key);
    }
    if (type == 'checkbox' || type == 'radio') {
      return key == ' ' || (type == 'radio' && key.startsWith('Arrow'));
    }
    if (type == 'range') return key.startsWith('Arrow') || key == 'Home';
    return false;
  }
  if (el.isA<web.HTMLSelectElement>()) {
    return key == ' ' || key == 'Enter' || key.startsWith('Arrow');
  }
  if (el.isA<web.HTMLButtonElement>() || el.isA<web.HTMLAnchorElement>()) {
    return key == 'Enter' || (key == ' ' && el.isA<web.HTMLButtonElement>());
  }
  return false;
}
