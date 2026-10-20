/// thor_ui's `Autocomplete` / `RawAutocomplete` in the browser
/// ([AutocompleteFeature]).
library;

import 'dart:js_interop';
import 'dart:math' as math;

import 'package:thor_engine/src/protocol.dart';
import 'package:thor_engine_oracle/client.dart' show EngineFeature, EngineRun;
import 'package:web/web.dart' as web;

/// `Autocomplete`: an options panel on the Popover API anchored to a text
/// field.
///
/// The panel is a manual popover (top layer: no sibling covers it, no
/// `overflow` clips it); this opens it while the field has focus and there
/// is an option to show, moves a highlight with the arrows
/// (`aria-activedescendant` on the field), picks with Enter or a click (the
/// field takes the option's text and tells its controller with an `input`
/// event; the option's own handler runs from the click), hides the options
/// the typed text does not match when the root says `f`, and closes on Esc,
/// Tab or the focus leaving. Options the page changes (a state's list) are
/// followed with a `MutationObserver` while the field has focus. A few
/// page-wide listeners: markup costs nothing until it is used.
///
/// Accessibility (APG "editable combobox with list autocomplete"): a polite
/// live region says how many options there are when they change;
/// ArrowDown / ArrowUp wrap around the options (as the APG example does);
/// Home / End give the highlight back to the field and move its caret (the
/// text field's keys); and the panel opens above the field when the visual
/// viewport (the on-screen keyboard) leaves no room below.
///
/// Inline (`i` in the root's value, the panel has `data-t-inl`): the panel
/// is in the flow, not a popover: it is shown while there is an option and
/// `hidden` otherwise, and Esc is left to the page. `h`: the first usable
/// option is kept active whenever the list shows or changes. With the list
/// inline, PageDown / PageUp move the highlight a page and Ctrl or Cmd with
/// Home / End go to the first / last option. `w`: the filter wants every
/// typed word, in any order, ignoring accents.
final class AutocompleteFeature extends EngineFeature {
  /// The feature.
  const AutocompleteFeature();

  @override
  void Function()? install(web.Element scope, EngineRun run) {
    final onKey = _onKey.toJS;
    final onFocusIn = _onFocusIn.toJS;
    final onFocusOut = _onFocusOut.toJS;
    final onInput = _onInput.toJS;
    final onMouseDown = _onMouseDown.toJS;
    final onClick = _onClick.toJS;
    final onOver = _onOver.toJS;
    scope
      // Capture: before the field's own handlers and the page's shortcuts,
      // which must not see the keys the options use.
      ..addEventListener('keydown', onKey, true.toJS)
      ..addEventListener('focusin', onFocusIn)
      ..addEventListener('focusout', onFocusOut)
      ..addEventListener('input', onInput)
      ..addEventListener('compositionend', onInput)
      ..addEventListener('mousedown', onMouseDown)
      ..addEventListener('click', onClick)
      ..addEventListener('pointerover', onOver);
    return () {
      _unfollow();
      scope
        ..removeEventListener('keydown', onKey, true.toJS)
        ..removeEventListener('focusin', onFocusIn)
        ..removeEventListener('focusout', onFocusOut)
        ..removeEventListener('input', onInput)
        ..removeEventListener('compositionend', onInput)
        ..removeEventListener('mousedown', onMouseDown)
        ..removeEventListener('click', onClick)
        ..removeEventListener('pointerover', onOver);
    };
  }
}

/// The parts of one autocomplete, found from its root.
extension type _Auto._(web.Element root) {
  static _Auto? of(web.EventTarget? target) {
    if (target == null || !target.isA<web.Element>()) return null;
    final root = (target as web.Element).closest('[$autocompleteAttr]');
    return root == null ? null : _Auto._(root);
  }

  /// The one whose field is [target].
  static _Auto? ofField(web.EventTarget? target) {
    final a = of(target);
    return a != null && identical(a.field, target) ? a : null;
  }

  web.HTMLElement get panel =>
      root.querySelector('[popover],[$autocompleteInlineAttr]')!
          as web.HTMLElement;

  String get _flags => root.getAttribute(autocompleteAttr) ?? '';

  web.HTMLInputElement get field {
    final p = panel;
    final inputs = root.querySelectorAll('input,textarea');
    for (var i = 0; i < inputs.length; i++) {
      final f = inputs.item(i)!;
      if (!p.contains(f)) return f as web.HTMLInputElement;
    }
    throw StateError('an Autocomplete without a field');
  }

  bool get filter => _flags.contains('f');

  /// The panel is meant above: the engine never flips it.
  bool get up => _flags.contains('u');

  /// The panel is in the flow, not a popover.
  bool get inline => _flags.contains('i');

  /// The first usable option is kept active.
  bool get first => _flags.contains('h');

  /// The filter matches every typed word.
  bool get words => _flags.contains('w');

  List<web.HTMLElement> get options {
    final list = panel.querySelectorAll('[role="option"]');
    return [
      for (var i = 0; i < list.length; i++) list.item(i)! as web.HTMLElement,
    ];
  }

  bool get isOpen =>
      inline ? !panel.hasAttribute('hidden') : panel.matches(':popover-open');
}

bool _usable(web.HTMLElement o) =>
    !o.hasAttribute('hidden') && o.getAttribute('aria-disabled') != 'true';

String _textOf(web.HTMLElement o) => (o.textContent ?? '').trim();

// The highlighted option: a row the app took out of the list (its role or
// `hidden` changed by a Watch) is no option, whatever mark it kept.
web.HTMLElement? _active(_Auto a) {
  final e = a.panel.querySelector('[role="option"][$dropdownActiveAttr]');
  return e == null ? null : e as web.HTMLElement;
}

// Per root: the observer while the field has focus, and whether Esc or a
// pick closed the panel (it stays closed until the visitor types again).
final _armed = <web.Element, web.MutationObserver>{};
final _dismissed = <web.Element>{};
bool _picking = false;
int _optionIds = 0;

/// The field is the combobox (set when it first gets the focus: without JS
/// it is a plain text field).
void _ready(_Auto a) {
  final f = a.field;
  if (f.getAttribute('role') == 'combobox') return;
  f
    ..setAttribute('role', 'combobox')
    ..setAttribute('aria-autocomplete', 'list')
    ..setAttribute('aria-haspopup', 'listbox')
    ..setAttribute('aria-expanded', 'false')
    ..setAttribute('autocomplete', 'off');
  final id = a.panel.id;
  if (id.isNotEmpty) f.setAttribute('aria-controls', id);
}

void _setActive(_Auto a, web.HTMLElement? option, {bool scroll = true}) {
  // Every mark goes, not only the option's: a row that stopped being an
  // option keeps its attribute otherwise, and stays highlighted.
  final marks = a.panel.querySelectorAll('[$dropdownActiveAttr]');
  for (var i = 0; i < marks.length; i++) {
    final m = marks.item(i)! as web.Element;
    if (!identical(m, option)) m.removeAttribute(dropdownActiveAttr);
  }
  if (option == null) {
    a.field.removeAttribute('aria-activedescendant');
    return;
  }
  option.setAttribute(dropdownActiveAttr, '');
  // Ids only once an option is highlighted: the server writes none.
  if (option.id.isEmpty) {
    final base = a.panel.id.isEmpty ? 't-ac' : a.panel.id;
    // A counter, not the position: rows move, and an id must stay unique.
    option.id = '$base-${++_optionIds}';
  }
  a.field.setAttribute('aria-activedescendant', option.id);
  if (scroll) {
    option.scrollIntoView(web.ScrollIntoViewOptions(block: 'nearest'));
  }
}

/// Whether the browser positions the panel from its anchor (CSS anchor
/// positioning).
bool get _anchored => web.CSS.supports('position-area', 'block-end');

/// Which side of the field has the room, measured on the visual viewport:
/// the on-screen keyboard shrinks it without touching the layout viewport
/// (which is all CSS anchoring knows). The client only flips an attribute and
/// writes the room as a value: the rules are the server's.
({bool up, double? room}) _fit(_Auto a) {
  final p = a.panel;
  p.removeAttribute(autocompleteUpAttr);
  p.style.removeProperty(autocompleteRoomVar);
  final vv = web.window.visualViewport;
  if (vv == null || a.up) return (up: false, room: null);
  final r = a.root.getBoundingClientRect();
  final below = vv.offsetTop + vv.height - r.bottom - 8;
  final above = r.top - vv.offsetTop - 8;
  // The panel's own height (its cap included), whichever side it is on.
  final cap =
      double.tryParse(
        web.window.getComputedStyle(p).maxHeight.replaceAll('px', ''),
      ) ??
      double.infinity;
  final need = math.min(
    (p.scrollHeight + (p.offsetHeight - p.clientHeight)).toDouble(),
    cap,
  );
  if (below >= need) return (up: false, room: null);
  final up = above > below;
  return (up: up, room: math.max(up ? above : below, 0));
}

void _apply(_Auto a, ({bool up, double? room}) f) {
  a.panel.toggleAttribute(autocompleteUpAttr, f.up);
  if (f.room == null) {
    a.panel.style.removeProperty(autocompleteRoomVar);
  } else {
    a.panel.style.setProperty(autocompleteRoomVar, '${f.room}px');
  }
}

/// Where the panel goes: above or below (see [_fit]), and in a browser
/// without CSS anchor positioning, under or over the field with a fixed
/// position.
void _place(_Auto a) {
  final f = _fit(a);
  if (_anchored) return _apply(a, f);
  final r = a.root.getBoundingClientRect();
  final edge = f.up
      ? 'bottom:${web.document.documentElement!.clientHeight - r.top}px'
      : 'top:${r.bottom}px';
  a.panel.style.cssText =
      'position:fixed;inset:auto;margin:0;left:${r.left}px;$edge;'
      'min-width:${r.width}px';
  _apply(a, f);
}

// Opening listens to the page's scroll and resize, and the visual
// viewport's (the keyboard): the panel follows its field and the room.
void Function()? _unfollowAll;
void _unfollow() {
  _unfollowAll?.call();
  _unfollowAll = null;
}

void _follow() {
  if (_unfollowAll != null) return;
  var frame = 0;
  final go = ((web.Event _) {
    if (frame != 0) return;
    frame = web.window.requestAnimationFrame(
      ((double _) {
        frame = 0;
        final roots = web.document.querySelectorAll('[$autocompleteAttr]');
        for (var i = 0; i < roots.length; i++) {
          final a = _Auto._(roots.item(i)! as web.Element);
          if (a.isOpen) _place(a);
        }
      }).toJS,
    );
  }).toJS;
  final vv = web.window.visualViewport;
  web.window
    ..addEventListener('scroll', go, true.toJS)
    ..addEventListener('resize', go);
  vv
    ?..addEventListener('resize', go)
    ..addEventListener('scroll', go);
  _unfollowAll = () {
    web.window
      ..removeEventListener('scroll', go, true.toJS)
      ..removeEventListener('resize', go);
    vv
      ?..removeEventListener('resize', go)
      ..removeEventListener('scroll', go);
  };
}

/// The polite live region says how many options the field has now. It waits
/// for the typing to pause (a screen reader would read every step of
/// "apple"); closing empties it at once and cancels what was pending.
const _sayAfter = 200;
final _saying = Expando<int>('autocomplete status timer');

String _say(_Auto a, web.Element el) {
  if (_dismissed.contains(a.root) || !_armed.containsKey(a.root)) return '';
  final n = a.options.where(_usable).length;
  if (n == 1) return el.getAttribute(autocompleteOneAttr) ?? '';
  if (n > 1) {
    return (el.getAttribute(autocompleteStatusAttr) ?? '').replaceAll(
      '{count}',
      '$n',
    );
  }
  // Nothing typed and nothing to show is not news.
  return a.field.value.trim().isEmpty
      ? ''
      : el.getAttribute(autocompleteNoneAttr) ?? '';
}

void _announce(_Auto a, {bool clear = false}) {
  final el = a.root.querySelector('[$autocompleteStatusAttr]');
  if (el == null) return;
  final pending = _saying[el];
  if (pending != null) web.window.clearTimeout(pending);
  _saying[el] = null;
  if (clear) {
    if (el.textContent != '') el.textContent = '';
    return;
  }
  if (el.textContent == _say(a, el)) return;
  _saying[el] = web.window.setTimeout(
    (() {
      _saying[el] = null;
      final text = _say(a, el);
      if (el.textContent != text) el.textContent = text;
    }).toJS,
    _sayAfter.toJS,
  );
}

void _show(_Auto a) {
  _follow();
  if (!a.isOpen) {
    if (a.inline) {
      a.panel.removeAttribute('hidden');
    } else {
      a.panel.showPopover();
    }
  }
  a.field.setAttribute('aria-expanded', 'true');
  if (a.inline) return;
  // Open, so its height can be measured; before the next paint.
  _place(a);
}

void _hide(_Auto a) {
  if (a.isOpen) {
    if (a.inline) {
      a.panel.setAttribute('hidden', '');
    } else {
      a.panel.hidePopover();
    }
  }
  a.field.setAttribute('aria-expanded', 'false');
  _setActive(a, null);
  _announce(a, clear: true);
}

/// Open while there is something to show; closed otherwise.
void _refresh(_Auto a) {
  if (!_armed.containsKey(a.root)) return;
  final current = _active(a);
  if (current != null && (!a.panel.contains(current) || !_usable(current))) {
    _setActive(a, null);
  } else if (current == null &&
      a.panel.querySelector('[$dropdownActiveAttr]') != null) {
    _setActive(a, null);
  }
  final want = !_dismissed.contains(a.root) && a.options.any(_usable);
  if (want) {
    _show(a);
    // Nothing active: the first option is (Enter picks it).
    if (a.first && _active(a) == null) {
      _setActive(a, a.options.firstWhere(_usable));
    }
  } else if (a.isOpen) {
    _hide(a);
  }
  _announce(a);
}

final _marks = RegExp('[\u0300-\u036f]');

extension on JSString {
  @JS('normalize')
  external JSString normalizeForm(String form);
}

/// Lower case without accents (NFD, the combining marks stripped).
String _fold(String t) =>
    t.toJS.normalizeForm('NFD').toDart.replaceAll(_marks, '').toLowerCase();

/// Whether the option's text matches what was typed. Default: the whole
/// phrase appears in the text, any case. With `w`: every whitespace-separated
/// word appears, in any order, ignoring case and accents.
bool _matches(_Auto a, String text, String q) {
  if (!a.words) return text.toLowerCase().contains(q.toLowerCase());
  final t = _fold(text);
  return _fold(q).split(RegExp(r'\s+')).every(t.contains);
}

/// The options the typed text does not match go (a view the app builds is
/// already the matching one).
void _narrow(_Auto a) {
  if (!a.filter) return;
  final q = a.field.value.trim();
  for (final o in a.options) {
    o.toggleAttribute('hidden', q.isNotEmpty && !_matches(a, _textOf(o), q));
  }
}

void _arm(_Auto a) {
  if (_armed.containsKey(a.root)) return;
  _ready(a);
  final watcher = web.MutationObserver(
    ((JSArray<web.MutationRecord> _, web.MutationObserver _) => _refresh(
      a,
    )).toJS,
  );
  watcher.observe(
    a.panel,
    web.MutationObserverInit(
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['hidden'.toJS, 'role'.toJS, 'aria-disabled'.toJS].toJS,
    ),
  );
  _armed[a.root] = watcher;
  // A panel the page kept can carry marks from an earlier focus.
  _setActive(a, null, scroll: false);
  _narrow(a);
  _refresh(a);
}

void _disarm(_Auto a) {
  _armed.remove(a.root)?.disconnect();
  _dismissed.remove(a.root);
  // An inline list stays where it is: it is not a popup that leaves.
  if (a.inline) {
    _announce(a, clear: true);
  } else {
    _hide(a);
  }
}

void _pick(_Auto a, web.HTMLElement option) {
  if (!_usable(option)) return;
  for (final o in a.options) {
    o.setAttribute('aria-selected', '${identical(o, option)}');
  }
  _picking = true;
  a.field.value = _textOf(option);
  // The field's controller (if any) hears it.
  a.field.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
  _picking = false;
  _dismissed.add(a.root);
  _hide(a);
  a.field.focus(web.FocusOptions(preventScroll: true));
}

// To the first / last usable option (inline: Ctrl or Cmd with Home / End).
void _edge(_Auto a, {required bool last}) {
  final usable = a.options.where(_usable).toList();
  if (usable.isNotEmpty) _setActive(a, last ? usable.last : usable.first);
}

// A page of options (inline): as many as the panel shows, at least one;
// clamped at the ends (APG: PageUp / PageDown do not wrap).
void _page(_Auto a, int by) {
  final usable = a.options.where(_usable).toList();
  if (usable.isEmpty) return;
  final current = _active(a);
  final at = current == null ? -1 : usable.indexOf(current);
  final row = usable.first.offsetHeight == 0 ? 1 : usable.first.offsetHeight;
  final n = math.max(1, (a.panel.clientHeight / row).floor() - 1);
  final to = at < 0 ? (by > 0 ? n - 1 : usable.length - n) : at + by * n;
  _setActive(a, usable[to.clamp(0, usable.length - 1)]);
}

void _move(_Auto a, int by) {
  final usable = a.options.where(_usable).toList();
  if (usable.isEmpty) return;
  final current = _active(a);
  final at = current == null ? -1 : usable.indexOf(current);
  final next = at < 0
      ? (by > 0 ? 0 : usable.length - 1)
      // APG: past either end it wraps (none highlighted: Down is the first,
      // Up the last).
      : (at + by + usable.length) % usable.length;
  _setActive(a, usable[next]);
}

void _onKey(web.KeyboardEvent e) {
  if (e.isComposing || e.defaultPrevented) return;
  final a = _Auto.ofField(e.target);
  if (a == null) return;
  switch (e.key) {
    case 'ArrowDown' || 'ArrowUp':
      _arm(a);
      _dismissed.remove(a.root);
      _refresh(a);
      if (!a.isOpen) return;
      _move(a, e.key == 'ArrowDown' ? 1 : -1);
    case 'Enter':
      // Nothing highlighted: Enter is the field's (a form submits).
      final highlighted = a.isOpen ? _active(a) : null;
      if (highlighted == null) return;
      highlighted.click();
    case 'Escape':
      // Inline: the list is not a popup to dismiss; a dialog around it
      // closes with this one press.
      if (a.inline || !a.isOpen) return;
      _dismissed.add(a.root);
      _hide(a);
    case 'Tab':
      if (a.isOpen) _hide(a);
      return; // focus moves on as usual
    case 'PageDown' || 'PageUp' when a.inline && a.isOpen:
      _page(a, e.key == 'PageDown' ? 1 : -1);
    case 'Home' || 'End' when a.inline && a.isOpen && (e.ctrlKey || e.metaKey):
      _edge(a, last: e.key == 'End');
    case 'Home' || 'End':
      // The field's own keys (the caret): the highlight returns to it
      // (unless the first option is kept active).
      if (a.isOpen && _active(a) != null && !a.first) _setActive(a, null);
      return;
    default:
      return;
  }
  e.preventDefault();
  e.stopPropagation();
}

void _onFocusIn(web.FocusEvent e) {
  final a = _Auto.ofField(e.target);
  if (a != null) _arm(a);
}

void _onFocusOut(web.FocusEvent e) {
  final a = _Auto.ofField(e.target);
  if (a == null) return;
  final to = e.relatedTarget;
  if (to == null || !to.isA<web.Node>() || !a.root.contains(to as web.Node)) {
    _disarm(a);
  }
}

/// Composing text (IME) is not yet the query: it is acted on when the
/// composition ends (`compositionend` lands here too).
void _onInput(web.Event e) {
  final a = _Auto.ofField(e.target);
  if (a == null || _picking) return;
  if (e.isA<web.InputEvent>() && (e as web.InputEvent).isComposing) return;
  _arm(a);
  // Typing opens it again after Esc or a pick.
  _dismissed.remove(a.root);
  _setActive(a, null);
  _narrow(a);
  _refresh(a);
}

web.Element? _optionOf(web.EventTarget? t) {
  if (t == null || !t.isA<web.Element>()) return null;
  final option = (t as web.Element).closest('[role="option"]');
  if (option == null) return null;
  final a = _Auto.of(option);
  return a != null && a.panel.contains(option) ? option : null;
}

/// The pointer takes no focus from the field: it would close the panel
/// before the click lands.
void _onMouseDown(web.MouseEvent e) {
  final t = e.target;
  if (t == null || !t.isA<web.Element>()) return;
  final a = _Auto.of(t);
  if (a != null && a.panel.contains(t as web.Node)) e.preventDefault();
}

void _onClick(web.MouseEvent e) {
  final option = _optionOf(e.target);
  if (option == null) return;
  _pick(_Auto.of(option)!, option as web.HTMLElement);
}

void _onOver(web.PointerEvent e) {
  final option = _optionOf(e.target);
  if (option == null || option.hasAttribute(dropdownActiveAttr)) return;
  final a = _Auto.of(option)!;
  if (_usable(option as web.HTMLElement)) _setActive(a, option, scroll: false);
}
