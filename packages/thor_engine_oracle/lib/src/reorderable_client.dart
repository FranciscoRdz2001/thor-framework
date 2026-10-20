/// thor_ui's `ReorderableListView` (`data-t-ro`; the lite engine's
/// `parts/reorderable.js` is the same).
///
/// The dragged item follows the pointer through `--t-ro-x/y` (its class maps
/// them to `translate`) and the others slide to make room: the engine measures
/// the items' boxes each frame (from their layout, never their drawn box), finds
/// the place the dragged one would take and writes each item's offset; the CSS
/// transitions do the rest. On release the dragged item settles in its place,
/// then the engine moves it in the page, clears every offset and calls
/// `reorder` (the old index and the new one, as Flutter counts them: before the
/// item leaves). A `Watch.list` finds its rows already in order. The keyboard: a
/// handle's Space or Enter picks an item up, the arrows move it, Space or Enter
/// drops it, Escape puts it back; Alt+arrow moves the item the focus is in by
/// one place. A live region says each step.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:thor_engine/src/protocol.dart';
import 'package:thor_engine_oracle/client.dart' show EngineFeature, EngineRun;
import 'package:thor_engine_oracle/src/drag_kit.dart';
import 'package:web/web.dart' as web;

/// `ReorderableListView` widgets.
final class ReorderableFeature extends EngineFeature {
  /// The feature.
  const ReorderableFeature();

  @override
  void Function()? install(web.Element scope, EngineRun run) =>
      _Reorder(scope, run).dispose;
}

const _slop = 4.0, _slopTouch = 8.0, _hold = 500, _ms = 200;
const _editable = 'input,textarea,select,[contenteditable]';
const _pickedUp =
    'Picked up {item}, position {position} of {count}. Use the arrow keys to '
    'move it, Space to drop it, Escape to cancel.';
const _english = [
  _pickedUp,
  '{item}, position {position} of {count}.',
  'Dropped {item} at position {position} of {count}.',
  'Cancelled. {item} is back at position {position} of {count}.',
  'Reorder {item}',
];

/// The axis of a list: vertical, or horizontal (`rtl` runs toward the left).
class _Axis {
  _Axis(this.vertical, this.rtl);
  final bool vertical, rtl;

  double pointer(double x, double y) => vertical ? y : (rtl ? -x : x);
}

class _Press {
  _Press(
    this.host,
    this.item,
    this.id,
    this.x,
    this.y,
    this.touch,
    this.delayed,
  );
  final web.HTMLElement host, item;
  final int id;
  final double x, y;
  final bool touch, delayed;
  int? timer;
}

class _Drag {
  _Drag(
    this.host,
    this.item,
    this.list,
    this.from,
    this.axis,
    this.pointer,
    this.at,
    this.grab,
  ) : to = from,
      cur = List.filled(list.length, 0.0);
  final web.HTMLElement host, item;
  final List<web.HTMLElement> list;
  final int from;
  final _Axis axis;
  final int pointer;
  int to;
  (double, double) at;
  final double grab;
  final List<double> cur;
  double settle = 0;
  int? frame;
  void Function()? stop;
}

/// A picked-up item, moved with the keyboard.
class _Held {
  _Held(this.host, this.item, this.from, this.ref);
  final web.HTMLElement host, item;
  final int from;
  final web.Node? ref;
}

class _Reorder {
  _Reorder(this.scope, this.run) {
    _on('pointerdown', _down);
    _on('pointermove', _move);
    _on('pointerup', _up);
    _on('pointercancel', _cancel);
    _on('dragstart', (e) {
      if (_drag != null || _press != null) e.preventDefault();
    });
    _on('contextmenu', (e) {
      if (_drag != null || (_press?.delayed ?? false)) e.preventDefault();
    });
    _on('click', _click, capture: true);
    _on('focusin', _focusin);
    _on('keydown', _key, capture: true);
    _on('keyup', (e) {
      final k = (e as web.KeyboardEvent).key;
      if (_held != null && (k == ' ' || k == 'Enter')) e.preventDefault();
    }, capture: true);
    _on('focusout', _focusout);
    // A finger that drags must not scroll the page: only a non-passive
    // listener can cancel the browser's decision on `touchmove`.
    final touch = ((web.Event e) {
      if (_drag != null && e.cancelable) e.preventDefault();
    }).toJS;
    final doc = web.document;
    doc.addEventListener(
      'touchmove',
      touch,
      web.AddEventListenerOptions(passive: false),
    );
    _undo.add(() => doc.removeEventListener('touchmove', touch));
  }

  final web.Element scope;
  final EngineRun run;
  final _undo = <void Function()>[];
  _Press? _press;
  _Drag? _drag;
  _Held? _held;
  web.Element? _suppress;

  void _on(
    String type,
    void Function(web.Event e) handler, {
    bool capture = false,
  }) {
    final js = handler.toJS;
    scope.addEventListener(type, js, capture.toJS);
    _undo.add(() => scope.removeEventListener(type, js, capture.toJS));
  }

  void dispose() {
    for (final u in _undo) {
      u();
    }
  }

  // --- helpers ---------------------------------------------------------------

  static web.HTMLElement? _closest(web.EventTarget? t, String selector) {
    if (t == null || !t.isA<web.Element>()) return null;
    return (t as web.Element).closest(selector) as web.HTMLElement?;
  }

  static List<web.HTMLElement> _itemsOf(web.Element host) {
    final out = <web.HTMLElement>[];
    final kids = host.children;
    for (var i = 0; i < kids.length; i++) {
      final c = kids.item(i)! as web.HTMLElement;
      if (c.hasAttribute(reorderItemAttr)) out.add(c);
    }
    return out;
  }

  /// The item of [host] that holds [el].
  static web.HTMLElement? _itemOf(web.Element host, web.Element el) {
    for (
      web.Element? n = el;
      n != null && !identical(n, host);
      n = n.parentElement
    ) {
      if (identical(n.parentElement, host)) {
        return n.hasAttribute(reorderItemAttr) ? n as web.HTMLElement : null;
      }
    }
    return null;
  }

  static (bool vertical, bool touch) _setup(web.Element host) {
    final a = (host.getAttribute(reorderSetupAttr) ?? 'v|1').split('|');
    return (a[0] != 'h', a.length > 1 && a[1] == '1');
  }

  static _Axis _axisOf(web.Element host) {
    final vertical = _setup(host).$1;
    return _Axis(
      vertical,
      !vertical && web.window.getComputedStyle(host).direction == 'rtl',
    );
  }

  /// An item's start and size along the axis, in the viewport's coordinates,
  /// from its layout (its offsets and the box they are measured from): never
  /// from its drawn box, which has its own `translate` in it (and a transition
  /// running).
  static (double, double) _box(_Axis a, web.HTMLElement el) {
    final op = (el.offsetParent ?? web.document.documentElement) as web.Element;
    final r = op.getBoundingClientRect();
    if (a.vertical) {
      return (
        r.top + op.clientTop - op.scrollTop + el.offsetTop,
        el.offsetHeight.toDouble(),
      );
    }
    final x = r.left + op.clientLeft - op.scrollLeft + el.offsetLeft;
    return (a.rtl ? -(x + el.offsetWidth) : x, el.offsetWidth.toDouble());
  }

  static void _put(web.HTMLElement el, _Axis a, double v) =>
      el.style.setProperty(
        a.vertical ? reorderVarY : reorderVarX,
        '${fmt(a.rtl ? -v : v)}px',
      );

  static void _clear(Iterable<web.HTMLElement> items) {
    for (final el in items) {
      el
        ..removeAttribute(reorderDragAttr)
        ..removeAttribute(reorderShiftAttr)
        ..removeAttribute(reorderSettleAttr);
      el.style
        ..removeProperty(reorderVarX)
        ..removeProperty(reorderVarY);
    }
  }

  void _later(void Function() fn) =>
      web.window.setTimeout(fn.toJS, (calm() ? 20 : _ms + 30).toJS);

  /// The item's name: its text, without the handles' (they are buttons, not
  /// words).
  static String _label(web.Element item) {
    final c = item.cloneNode(true) as web.Element;
    final handles = c.querySelectorAll('[$reorderHandleAttr]');
    for (var i = handles.length - 1; i >= 0; i--) {
      (handles.item(i)! as web.Element).remove();
    }
    return nameOf(c);
  }

  void _say(web.Element host, int k, web.Element item, int pos, int count) =>
      say(
        fill(
          words(host, reorderLabelsAttr, _english)[k],
          _label(item),
        ).replaceAll('{position}', '$pos').replaceAll('{count}', '$count'),
      );

  /// The method of the list by key (`reorder`, `start`, `end`) with [value].
  void _fire(web.Element host, String k, String value) {
    final id = decodeOn(host.getAttribute(reorderAttr) ?? '')[k];
    if (id != null) run(id, host, value);
  }

  /// A move that keeps the focus where it is (the state-preserving move where
  /// the browser has one).
  void _move2(web.HTMLElement host, web.HTMLElement item, web.Node? ref) {
    final focus = web.document.activeElement;
    var done = false;
    if ((host as JSObject).has('moveBefore')) {
      try {
        host.callMethodVarArgs<JSAny?>('moveBefore'.toJS, [item, ref]);
        done = true;
      } catch (_) {
        // Falls back to a plain move.
      }
    }
    if (!done) host.insertBefore(item, ref);
    final now = web.document.activeElement;
    if (focus != null && !identical(now, focus) && focus.isConnected) {
      (focus as web.HTMLElement).focus(web.FocusOptions(preventScroll: true));
    }
  }

  int _nextFrame(void Function() fn) =>
      web.window.requestAnimationFrame(((num _) => fn()).toJS);

  // --- pointer ---------------------------------------------------------------

  /// One frame: the boxes, where the dragged item would go, and each item's
  /// offset.
  void _frame(_Drag d) {
    d.frame = null;
    if (!identical(_drag, d)) return;
    final list = d.list, from = d.from, a = d.axis, n = list.length;
    final base = <double>[], size = <double>[];
    for (final e in list) {
      final (s, z) = _box(a, e);
      base.add(s);
      size.add(z);
    }
    // Where the dragged item's start is wanted, kept inside the list.
    final want = (a.pointer(d.at.$1, d.at.$2) - d.grab).clamp(
      base[0],
      math.max(base[0], base[n - 1] + size[n - 1] - size[from]),
    );
    final center = want + size[from] / 2;
    var t = from;
    // (A tie is the item at the end of the list, where the box is held in.)
    while (t < n - 1 && center >= base[t + 1] + size[t + 1] / 2) {
      t++;
    }
    while (t > 0 && center <= base[t - 1] + size[t - 1] / 2) {
      t--;
    }
    // The places once the item is there, the gap between items kept.
    var total = 0.0;
    for (final z in size) {
      total += z;
    }
    final gap = n > 1
        ? (base[n - 1] + size[n - 1] - base[0] - total) / (n - 1)
        : 0.0;
    final order = [
      for (var i = 0; i < n; i++)
        if (i != from) i,
    ]..insert(t, from);
    var pos = base[0];
    final next = List.filled(n, 0.0);
    for (final i in order) {
      next[i] = pos;
      pos += size[i] + gap;
    }
    for (var i = 0; i < n; i++) {
      final v = i == from ? want - base[i] : next[i] - base[i];
      if ((v - d.cur[i]).abs() < 0.1) continue;
      d.cur[i] = v;
      _put(list[i], a, v);
      if (i != from) list[i].setAttribute(reorderShiftAttr, '');
    }
    d.to = t;
    d.settle = next[from] - base[from];
  }

  void _schedule(_Drag d) {
    d.frame ??= _nextFrame(() => _frame(d));
  }

  _Drag? _begin(
    web.HTMLElement host,
    web.HTMLElement item,
    int pid,
    double x,
    double y,
  ) {
    final list = _itemsOf(host),
        from = list.indexWhere((e) => identical(e, item));
    if (from < 0) return null;
    final a = _axisOf(host);
    final d = _Drag(host, item, list, from, a, pid, (
      x,
      y,
    ), a.pointer(x, y) - _box(a, item).$1);
    _drag = d;
    item.setAttribute(reorderDragAttr, '');
    _fire(host, 'start', '$from');
    d.stop = autoscroll(() => d.at);
    return d;
  }

  /// The drag ends: the item settles in its place ([drop]), or everything goes
  /// back; then the page changes and the state hears it.
  void _end(_Drag d, bool drop) {
    if (!identical(_drag, d)) return;
    d.stop?.call();
    // The last position counts: the pointer may have moved since the frame.
    final f = d.frame;
    if (f != null) web.window.cancelAnimationFrame(f);
    d.frame = null;
    if (drop) _frame(d);
    _drag = null;
    final host = d.host,
        item = d.item,
        list = d.list,
        from = d.from,
        a = d.axis;
    final to = drop ? d.to : from;
    item
      ..removeAttribute(reorderDragAttr)
      ..setAttribute(reorderSettleAttr, '');
    for (var i = 0; i < list.length; i++) {
      if (i != from) list[i].setAttribute(reorderShiftAttr, '');
      _put(list[i], a, drop && i == from ? d.settle : (drop ? d.cur[i] : 0));
    }
    _later(() {
      if (!item.isConnected) return _clear(list);
      if (to != from) {
        _move2(host, item, to > from ? list[to].nextSibling : list[to]);
      }
      _clear(list);
      if (to != from) {
        _fire(host, 'reorder', '$from~${to > from ? to + 1 : to}');
      }
      _fire(host, 'end', '$to');
    });
  }

  void _stopPress() {
    final t = _press?.timer;
    if (t != null) web.window.clearTimeout(t);
    _press = null;
  }

  void _down(web.Event event) {
    final e = event as web.PointerEvent;
    if (_drag != null || _held != null) return;
    if (e.button != 0 && e.pointerType == 'mouse') return;
    final h = _closest(e.target, '[$reorderHandleAttr]');
    final host = _closest(h ?? e.target, '[$reorderAttr]');
    if (host == null) return;
    final item = _itemOf(host, (h ?? e.target)! as web.Element);
    if (item == null) return;
    final bool delayed;
    if (h != null && identical(_closest(h, '[$reorderAttr]'), host)) {
      delayed = h.getAttribute(reorderHandleAttr) == 'delayed';
    } else if (e.pointerType != 'mouse' &&
        _setup(host).$2 &&
        _closest(e.target, _editable) == null) {
      // A held finger anywhere on the item drags it (not under a field).
      delayed = true;
    } else {
      return;
    }
    _stopPress();
    final p = _press = _Press(
      host,
      item,
      e.pointerId,
      e.clientX.toDouble(),
      e.clientY.toDouble(),
      e.pointerType != 'mouse',
      delayed,
    );
    if (delayed) {
      p.timer = web.window.setTimeout(
        (() {
          if (!identical(_press, p)) return;
          _press = null;
          final d = _begin(host, item, p.id, p.x, p.y);
          if (d != null) {
            _suppress = item;
            try {
              item.setPointerCapture(p.id);
            } catch (_) {
              // A pointer the browser no longer tracks.
            }
            _schedule(d);
          }
        }).toJS,
        _hold.toJS,
      );
    }
  }

  void _move(web.Event event) {
    final e = event as web.PointerEvent;
    final d = _drag;
    if (d != null && e.pointerId == d.pointer) {
      d.at = (e.clientX.toDouble(), e.clientY.toDouble());
      _schedule(d);
      return;
    }
    final p = _press;
    if (p == null || e.pointerId != p.id || d != null) return;
    final moved = math.sqrt(
      math.pow(e.clientX - p.x, 2) + math.pow(e.clientY - p.y, 2),
    );
    if (moved < (p.touch ? _slopTouch : _slop)) return;
    _stopPress();
    // Moving before the hold is a scroll; a handle starts at once.
    if (p.delayed) return;
    final started = _begin(p.host, p.item, p.id, p.x, p.y);
    if (started != null) {
      _suppress = p.item;
      started.at = (e.clientX.toDouble(), e.clientY.toDouble());
      _schedule(started);
      try {
        p.item.setPointerCapture(p.id);
      } catch (_) {
        // A pointer the browser no longer tracks.
      }
    }
  }

  void _up(web.Event event) {
    final e = event as web.PointerEvent;
    final d = _drag;
    if (d != null && e.pointerId == d.pointer) {
      d.at = (e.clientX.toDouble(), e.clientY.toDouble());
      _end(d, true);
      final el = d.item;
      web.window.setTimeout(
        (() {
          if (identical(_suppress, el)) _suppress = null;
        }).toJS,
        60.toJS,
      );
    } else if (_press != null && e.pointerId == _press!.id) {
      _stopPress();
    }
  }

  void _cancel(web.Event event) {
    final e = event as web.PointerEvent;
    final d = _drag;
    if (d != null && e.pointerId == d.pointer) {
      _end(d, false);
      _suppress = null;
    } else if (_press != null && e.pointerId == _press!.id) {
      _stopPress();
    }
  }

  void _click(web.Event e) {
    final el = _suppress;
    if (el == null) return;
    _suppress = null;
    final t = e.target;
    if (t != null && t.isA<web.Node>() && el.contains(t as web.Node)) {
      e
        ..stopImmediatePropagation()
        ..preventDefault();
    }
  }

  // --- keyboard --------------------------------------------------------------

  /// The handle's name says which item it moves (the server cannot: a cloned
  /// row has no text yet).
  void _focusin(web.Event e) {
    final h = _closest(e.target, '[$reorderHandleAttr]');
    if (h == null) return;
    final host = _closest(h, '[$reorderAttr]');
    final item = host == null ? null : _itemOf(host, h);
    if (host == null || item == null) return;
    final label = words(host, reorderLabelsAttr, _english)[4];
    if (label.contains('{item}')) {
      h.setAttribute('aria-label', fill(label, _label(item)));
    }
  }

  /// Moves [item] [delta] places along the list; says where it is now.
  /// Returns whether it moved. The two items that swap slide into their new
  /// places.
  bool _step(web.HTMLElement host, web.HTMLElement item, int delta, int k) {
    final list = _itemsOf(host);
    final i = list.indexWhere((e) => identical(e, item)), j = i + delta;
    if (j < 0 || j >= list.length) {
      _say(host, 1, item, i + 1, list.length);
      return false;
    }
    final other = list[j], a = _axisOf(host);
    final before = _box(a, item).$1, otherBefore = _box(a, other).$1;
    _move2(host, item, delta > 0 ? other.nextSibling : other);
    final after = _box(a, item).$1, otherAfter = _box(a, other).$1;
    if (!calm()) {
      _put(item, a, before - after);
      _put(other, a, otherBefore - otherAfter);
      item.getBoundingClientRect();
      item.setAttribute(reorderShiftAttr, '');
      other.setAttribute(reorderShiftAttr, '');
      _put(item, a, 0);
      _put(other, a, 0);
      _later(() => _clear([item, other]));
    }
    item.scrollIntoView(
      web.ScrollIntoViewOptions(block: 'nearest', inline: 'nearest'),
    );
    _say(host, k, item, j + 1, list.length);
    return true;
  }

  /// The arrow of the list's axis as a step of -1 or 1 (`ArrowRight` goes
  /// backward in a right-to-left row).
  int _delta(web.Element host, String key) {
    final a = _axisOf(host);
    if (a.vertical) return key == 'ArrowDown' ? 1 : (key == 'ArrowUp' ? -1 : 0);
    final right = key == 'ArrowRight' ? 1 : (key == 'ArrowLeft' ? -1 : 0);
    return a.rtl ? -right : right;
  }

  void _key(web.Event event) {
    final e = event as web.KeyboardEvent;
    final held = _held;
    // A picked-up item: every key is the reorder's while it lasts.
    if (held != null) {
      final host = held.host, item = held.item, k = e.key;
      final list = _itemsOf(host);
      final here = list.indexWhere((x) => identical(x, item));
      final dl = _delta(host, k);
      if (dl != 0) {
        _step(host, item, dl, 1);
      } else if (k == 'Home' || k == 'End') {
        _step(host, item, k == 'Home' ? -here : list.length - 1 - here, 1);
      } else if (k == ' ' || k == 'Enter') {
        final to = here, from = held.from;
        _held = null;
        if (to != from) {
          _fire(host, 'reorder', '$from~${to > from ? to + 1 : to}');
        }
        _fire(host, 'end', '$to');
        _say(host, 2, item, to + 1, list.length);
      } else if (k == 'Escape') {
        _held = null;
        final ref = held.ref;
        _move2(
          host,
          item,
          ref != null && identical(ref.parentNode, host) ? ref : null,
        );
        _fire(host, 'end', '${held.from}');
        _say(host, 3, item, held.from + 1, list.length);
      } else {
        return;
      }
      e
        ..preventDefault()
        ..stopImmediatePropagation();
      return;
    }
    final d = _drag;
    if (d != null) {
      if (e.key == 'Escape') {
        _end(d, false);
        e.preventDefault();
      }
      return;
    }
    if (e.defaultPrevented) return;
    final h = _closest(e.target, '[$reorderHandleAttr]');
    final host = _closest(e.target, '[$reorderAttr]');
    final item = host == null ? null : _itemOf(host, e.target! as web.Element);
    if (host == null || item == null) return;
    // Space or Enter on a handle picks the item up.
    if (h != null &&
        identical(e.target, h) &&
        !e.altKey &&
        !e.ctrlKey &&
        !e.metaKey &&
        !e.shiftKey &&
        (e.key == ' ' || e.key == 'Enter')) {
      final list = _itemsOf(host);
      final from = list.indexWhere((x) => identical(x, item));
      _held = _Held(host, item, from, item.nextSibling);
      _fire(host, 'start', '$from');
      _say(host, 0, item, from + 1, list.length);
      e.preventDefault();
      return;
    }
    // Alt+arrow anywhere in an item (not in a field): one place, at once.
    final dl =
        e.altKey &&
            !e.ctrlKey &&
            !e.metaKey &&
            !e.shiftKey &&
            _closest(e.target, _editable) == null
        ? _delta(host, e.key)
        : 0;
    if (dl == 0) return;
    e.preventDefault();
    final list = _itemsOf(host);
    final from = list.indexWhere((x) => identical(x, item));
    if (_step(host, item, dl, 2)) {
      final to = from + dl;
      _fire(host, 'reorder', '$from~${to > from ? to + 1 : to}');
    }
  }

  /// The focus leaving the list drops a keyboard drag back where it was.
  void _focusout(web.Event event) {
    final held = _held;
    if (held == null) return;
    final to = (event as web.FocusEvent).relatedTarget;
    if (to != null &&
        to.isA<web.Node>() &&
        held.host.contains(to as web.Node)) {
      return;
    }
    _held = null;
    final ref = held.ref;
    _move2(
      held.host,
      held.item,
      ref != null && identical(ref.parentNode, held.host) ? ref : null,
    );
    _fire(held.host, 'end', '${held.from}');
  }
}
