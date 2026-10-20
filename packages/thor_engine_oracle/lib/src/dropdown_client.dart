/// thor_ui's `DropdownMenu` in the browser ([DropdownMenuFeature]).
library;

import 'dart:js_interop';

import 'package:thor_engine/src/protocol.dart';
import 'package:thor_engine_oracle/client.dart' show EngineFeature, EngineRun;
import 'package:web/web.dart' as web;

/// `DropdownMenu`: a listbox select on the Popover API.
///
/// The popover opens and closes natively (its button's `popovertarget`,
/// Esc and light dismiss); this feature adds what a native `<select>`
/// would: the highlighted entry (arrows, Home/End, the pointer) announced
/// through `aria-activedescendant`, Enter/Space/click to pick, type-ahead
/// on the button, filtering as the user types in the menu's field, and on
/// a pick the button's text, `aria-selected`, the value of the hidden
/// `<select>` (what a form posts) and a `change` event on it (what reaches
/// `onSelected`). A handful of page-wide listeners: markup costs nothing
/// until it is used.
final class DropdownMenuFeature extends EngineFeature {
  /// The feature.
  const DropdownMenuFeature();

  @override
  void Function()? install(web.Element scope, EngineRun run) {
    final onKey = _onKey.toJS;
    final onClick = _onClick.toJS;
    final onOver = _onOver.toJS;
    final onInput = _onInput.toJS;
    final onToggle = _onToggle.toJS;
    scope
      // Capture: before the field's own handlers and the page's shortcuts,
      // which must not see the keys the menu uses.
      ..addEventListener('keydown', onKey, true.toJS)
      ..addEventListener('click', onClick)
      ..addEventListener('pointerover', onOver)
      ..addEventListener('input', onInput)
      // `toggle` doesn't bubble.
      ..addEventListener('toggle', onToggle, true.toJS);
    return () => scope
      ..removeEventListener('keydown', onKey, true.toJS)
      ..removeEventListener('click', onClick)
      ..removeEventListener('pointerover', onOver)
      ..removeEventListener('input', onInput)
      ..removeEventListener('toggle', onToggle, true.toJS);
  }
}

/// The parts of one `DropdownMenu`, found from its root.
extension type _Menu._(web.Element root) {
  static _Menu? of(web.EventTarget? target) {
    if (target == null || !target.isA<web.Element>()) return null;
    final root = (target as web.Element).closest('[$dropdownAttr]');
    return root == null ? null : _Menu._(root);
  }

  web.HTMLElement get button =>
      root.querySelector('button[aria-haspopup]')! as web.HTMLElement;

  web.HTMLElement get panel =>
      root.querySelector('[popover]')! as web.HTMLElement;

  web.Element get listbox {
    final p = panel;
    return p.getAttribute('role') == 'listbox'
        ? p
        : p.querySelector('[role="listbox"]')!;
  }

  web.HTMLInputElement? get field {
    final f = panel.querySelector('input');
    return f == null ? null : f as web.HTMLInputElement;
  }

  web.HTMLSelectElement get select =>
      root.querySelector('select')! as web.HTMLSelectElement;

  List<web.HTMLElement> get options {
    final list = listbox.querySelectorAll('[role="option"]');
    return [
      for (var i = 0; i < list.length; i++) list.item(i)! as web.HTMLElement,
    ];
  }

  bool get isOpen => panel.matches(':popover-open');

  String get flags => root.getAttribute(dropdownAttr) ?? '';

  /// The `<option>` of the hidden select behind entry [i] (a leading hint
  /// option shifts them).
  web.HTMLOptionElement optionOf(int i, int count) {
    final s = select;
    return s.options.item(s.options.length - count + i)!
        as web.HTMLOptionElement;
  }

  /// The label of each entry (the hidden select's option texts).
  List<String> labels(int count) => [
    for (var i = 0; i < count; i++) optionOf(i, count).text,
  ];
}

bool _usable(web.HTMLElement o) =>
    !o.hasAttribute('hidden') && o.getAttribute('aria-disabled') != 'true';

void _setActive(_Menu m, web.HTMLElement? option, {bool scroll = true}) {
  final list = m.listbox;
  list
      .querySelector('[$dropdownActiveAttr]')
      ?.removeAttribute(dropdownActiveAttr);
  final field = m.field;
  if (option == null) {
    m.button.removeAttribute('aria-activedescendant');
    field?.removeAttribute('aria-activedescendant');
    return;
  }
  option.setAttribute(dropdownActiveAttr, '');
  // Ids only when an entry is highlighted: the server doesn't write one
  // per entry.
  if (option.id.isEmpty) {
    option.id = '${list.id}-${m.options.indexOf(option)}';
  }
  m.button.setAttribute('aria-activedescendant', option.id);
  field?.setAttribute('aria-activedescendant', option.id);
  if (scroll) {
    option.scrollIntoView(web.ScrollIntoViewOptions(block: 'nearest'));
  }
}

web.HTMLElement? _active(_Menu m) {
  final a = m.listbox.querySelector('[$dropdownActiveAttr]');
  return a == null ? null : a as web.HTMLElement;
}

/// Moves the highlight [by] usable entries (no wrap, like a `<select>`);
/// `null` [by] with [last]: to the first or last one.
void _move(_Menu m, {int by = 0, bool? last}) {
  final usable = m.options.where(_usable).toList();
  if (usable.isEmpty) return;
  final current = _active(m);
  final at = current == null ? -1 : usable.indexOf(current);
  final int next;
  if (last != null) {
    next = last ? usable.length - 1 : 0;
  } else if (at < 0) {
    next = by > 0 ? 0 : usable.length - 1;
  } else {
    next = (at + by).clamp(0, usable.length - 1);
  }
  _setActive(m, usable[next]);
}

void _opened(_Menu m) {
  m.button.setAttribute('aria-expanded', 'true');
  final field = m.field;
  if (field != null && field.value.isNotEmpty) {
    field.value = '';
    // The controller of the field (if any) hears it; so does the filter.
    field.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
  }
  final options = m.options;
  for (final o in options) {
    o.removeAttribute('hidden');
  }
  final selected = options
      .where((o) => o.getAttribute('aria-selected') == 'true' && _usable(o))
      .firstOrNull;
  _setActive(m, selected ?? options.where(_usable).firstOrNull);
  if (field != null) {
    final flags = m.flags;
    final focus = flags.contains('f')
        ? true
        : flags.contains('n')
        ? false
        : !web.window.matchMedia('(pointer: coarse)').matches;
    if (focus) field.focus(web.FocusOptions(preventScroll: true));
  }
}

void _closed(_Menu m) {
  m.button.setAttribute('aria-expanded', 'false');
  _setActive(m, null);
  _typed = '';
}

void _pick(_Menu m, web.HTMLElement option) {
  if (!_usable(option)) return;
  final options = m.options;
  final i = options.indexOf(option);
  final select = m.select;
  final native = m.optionOf(i, options.length);
  native.selected = true;
  for (final o in options) {
    o.setAttribute('aria-selected', '${identical(o, option)}');
  }
  final label = m.root.querySelector('[$dropdownLabelAttr]');
  if (label != null) {
    label
      ..textContent = native.text
      ..removeAttribute(dropdownHintAttr);
  }
  if (m.isOpen) m.panel.hidePopover();
  // Now, not on the (queued) `toggle` event.
  _closed(m);
  m.button.focus(web.FocusOptions(preventScroll: true));
  // Like Flutter's onSelected: every pick, the same entry again included.
  select.dispatchEvent(web.Event('change', web.EventInit(bubbles: true)));
}

// Type-ahead: the characters typed within 700ms of each other.
String _typed = '';
double _typedAt = 0;

bool get _typing =>
    _typed.isNotEmpty && web.window.performance.now() - _typedAt <= 700;

void _typeAhead(_Menu m, String key) {
  final now = web.window.performance.now();
  _typed = now - _typedAt > 700 ? key : _typed + key;
  _typedAt = now;
  final options = m.options;
  final labels = m.labels(options.length);
  var query = _typed.toLowerCase();
  // The same letter again cycles through the entries that start with it.
  final repeated = query.split('').every((c) => c == query[0]);
  if (repeated) query = query[0];
  final current = _active(m);
  final from = current == null ? 0 : options.indexOf(current);
  final skip = repeated && current != null ? 1 : 0;
  for (var n = 0; n < options.length; n++) {
    final i = (from + skip + n) % options.length;
    if (_usable(options[i]) && labels[i].toLowerCase().startsWith(query)) {
      _setActive(m, options[i]);
      return;
    }
  }
}

void _filter(_Menu m, String text) {
  final query = text.trim().toLowerCase();
  final options = m.options;
  final labels = m.labels(options.length);
  web.HTMLElement? first;
  for (var i = 0; i < options.length; i++) {
    final shown = query.isEmpty || labels[i].toLowerCase().contains(query);
    options[i].toggleAttribute('hidden', !shown);
    if (shown && first == null && _usable(options[i])) first = options[i];
  }
  _setActive(m, first);
}

bool _printable(web.KeyboardEvent e) =>
    e.key.length == 1 && !e.ctrlKey && !e.metaKey && !e.altKey;

void _onKey(web.KeyboardEvent e) {
  if (e.isComposing || e.defaultPrevented) return;
  final m = _Menu.of(e.target);
  if (m == null) return;
  final target = e.target! as web.Element;
  final onButton = target.matches('button[aria-haspopup]');
  final inField = !onButton && target.matches('[popover] input');
  if (!onButton && !inField) return;
  final key = e.key;
  final typeAhead = onButton && m.flags.contains('s') && _printable(e);
  var handled = true;
  // Opened by the pointer a moment ago: `toggle` is queued, set up now.
  if (m.isOpen && m.button.getAttribute('aria-expanded') != 'true') _opened(m);
  if (!m.isOpen) {
    if (!onButton) return;
    if (key == 'ArrowDown' || key == 'ArrowUp' || typeAhead) {
      m.button.click();
      if (m.isOpen) _opened(m);
      if (typeAhead) _typeAhead(m, key);
    } else {
      handled = false;
    }
  } else {
    switch (key) {
      case 'ArrowDown':
        _move(m, by: 1);
      case 'ArrowUp':
        _move(m, by: -1);
      case 'Home' || 'End' when onButton:
        _move(m, last: key == 'End');
      case 'Enter':
        final a = _active(m);
        if (a != null) _pick(m, a);
      case ' ' when onButton && !_typing:
        final a = _active(m);
        if (a != null) _pick(m, a);
      case 'Tab':
        m.panel.hidePopover();
        return; // focus moves on as usual
      case _ when typeAhead:
        _typeAhead(m, key);
      default:
        handled = false;
    }
  }
  if (!handled) return;
  e.preventDefault();
  e.stopPropagation();
}

void _onClick(web.MouseEvent e) {
  final t = e.target;
  if (t == null || !t.isA<web.Element>()) return;
  final option = (t as web.Element).closest('[role="option"]');
  if (option == null) return;
  final m = _Menu.of(option);
  if (m != null) _pick(m, option as web.HTMLElement);
}

void _onOver(web.PointerEvent e) {
  final t = e.target;
  if (t == null || !t.isA<web.Element>()) return;
  final option = (t as web.Element).closest('[role="option"]');
  if (option == null || option.hasAttribute(dropdownActiveAttr)) return;
  final m = _Menu.of(option);
  if (m != null && _usable(option as web.HTMLElement)) {
    _setActive(m, option, scroll: false);
  }
}

void _onInput(web.Event e) {
  final t = e.target;
  if (t == null || !t.isA<web.HTMLInputElement>()) return;
  final input = t as web.HTMLInputElement;
  if (input.closest('[popover]') == null) return;
  final m = _Menu.of(input);
  if (m == null) return;
  // Opened by the pointer a moment ago: its (queued) `toggle` would set the
  // menu up after this input and wipe the filter; mark it set up now.
  if (m.isOpen && m.button.getAttribute('aria-expanded') != 'true') {
    m.button.setAttribute('aria-expanded', 'true');
  }
  _filter(m, input.value);
}

void _onToggle(web.ToggleEvent e) {
  final t = e.target;
  if (t == null || !t.isA<web.Element>()) return;
  final panel = t as web.Element;
  if (!panel.hasAttribute('popover')) return;
  final m = _Menu.of(panel);
  if (m == null || !identical(m.panel, panel)) return;
  final open = e.newState == 'open';
  // Opened by the keyboard: already set up (synchronously, so a typed
  // character could highlight its entry).
  if (open == (m.button.getAttribute('aria-expanded') == 'true')) return;
  open ? _opened(m) : _closed(m);
}
