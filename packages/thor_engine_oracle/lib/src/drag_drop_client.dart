/// thor_ui's `Draggable`, `LongPressDraggable` and `DragTarget`
/// (`data-t-dg`, `data-t-dt`; the lite engine's `parts/drag_drop.js` is the
/// same).
///
/// Pointer events, not the HTML5 drag-and-drop (a finger cannot start that):
/// the draggable's feedback template is cloned as a fixed element (a manual
/// popover, so it is above a modal dialog) and moved with `--t-dg-x/y`, which
/// its own class maps to `translate`. The targets under the pointer are found
/// with `elementsFromPoint` each frame; the target's state method says whether
/// it accepts (`accept`, a `bool`) when the pointer enters it, `move` runs at
/// most once a frame, `drop` runs on release. Space or Enter picks a draggable
/// up from the keyboard, the arrows (and Tab) move between the targets that
/// fit it, Space or Enter drops it, Escape cancels; a live region says each
/// step.
library;

import 'dart:js_interop';
import 'dart:math' as math;

import 'package:thor_engine/src/bindings.dart' show Binding;
import 'package:thor_engine/src/protocol.dart';
import 'package:thor_engine/src/thor_state.dart' show ThorMember;
import 'package:thor_engine_oracle/client.dart' show EngineFeature, EngineRun;
import 'package:thor_engine_oracle/src/drag_kit.dart';
import 'package:thor_engine_oracle/src/member_ref.dart';
import 'package:web/web.dart' as web;

/// `Draggable` and `DragTarget` widgets.
final class DragDropFeature extends EngineFeature {
  /// The feature.
  const DragDropFeature();

  @override
  void collect(
    web.Element scope,
    ThorMember Function(String id) member,
    List<Binding> bindings,
    Set<String> seen, {
    bool late = false,
  }) {
    pageMember = member;
  }

  @override
  void Function()? install(web.Element scope, EngineRun run) =>
      _DragDrop(scope, run).dispose;
}

const _slop = 6.0, _slopTouch = 10.0;
const _editable = 'input,textarea,select,[contenteditable]';
const _pickedUp =
    'Picked up {item}. Use the arrow keys to choose where to drop it, Space to '
    'drop it, Escape to cancel.';
const _english = [
  _pickedUp,
  '{target}: it can be dropped here.',
  '{target}: it cannot be dropped here.',
  'Dropped {item} on {target}.',
  'Cancelled. {item} was not moved.',
];

class _Setup {
  _Setup(web.Element src) {
    final a = (src.getAttribute(dragSetupAttr) ?? '').split('|');
    axis = a.isNotEmpty ? a[0] : 'f';
    delay = a.length > 1 ? (parseNumber(a[1]) ?? 0).round() : 0;
    anchor = a.length > 2 ? a[2] : 'c';
    max = a.length > 3 ? (parseNumber(a[3]) ?? 1).round() : 1;
    ox = a.length > 4 ? parseNumber(a[4]) ?? 0 : 0;
    oy = a.length > 5 ? parseNumber(a[5]) ?? 0 : 0;
  }

  late final String axis, anchor;
  late final int delay, max;
  late final double ox, oy;
}

/// The target a drag is over, and whether it takes the drag.
class _Over {
  _Over(this.target, this.ok);
  final web.HTMLElement target;
  final bool ok;
}

class _Press {
  _Press(this.src, this.id, this.x, this.y, this.touch, this.setup);
  final web.HTMLElement src;
  final int id;
  final double x, y;
  final bool touch;
  final _Setup setup;
  int? timer;
  bool get ready => setup.delay == 0;
}

class _Drag {
  _Drag(
    this.src,
    this.setup,
    this.ids,
    this.pointer,
    this.mode,
    double x,
    double y,
  ) : rect = src.getBoundingClientRect(),
      x0 = x,
      y0 = y,
      at = (x, y);

  final web.HTMLElement src;
  final _Setup setup;
  final Map<String, String> ids;
  final int? pointer;
  final String mode; // 'ptr' or 'kb'
  final web.DOMRect rect;
  final double x0, y0;
  (double, double) at;
  late final web.HTMLElement ghost;
  web.Element? placeholder;
  String type = 'Object', data = '';
  _Over? over;
  final asked = Expando<bool>('thor.drag.asked');
  int? frame;
  String sent = '';
  void Function()? stop;
  // The keyboard's: the targets that fit, the one chosen, and where the
  // feedback goes.
  List<web.HTMLElement> list = const [];
  int index = -1;
  (double, double) kb = (0, 0);
}

class _DragDrop {
  _DragDrop(this.scope, this.run) {
    _on('pointerdown', _down);
    _on('pointermove', _move);
    _on('pointerup', _up);
    _on('pointercancel', _cancel);
    _on('dragstart', (e) {
      if (_drag != null || _press != null) e.preventDefault();
    });
    _on('contextmenu', (e) {
      final p = _press;
      if (_drag != null || (p != null && !p.ready)) e.preventDefault();
    });
    _on('click', _click, capture: true);
    _on('keydown', _key, capture: true);
    _on('keyup', (e) {
      final k = (e as web.KeyboardEvent).key;
      if (_drag?.mode == 'kb' && (k == ' ' || k == 'Enter')) {
        e.preventDefault();
      }
    }, capture: true);
    // A pointer that goes down elsewhere ends a keyboard drag.
    _on('pointerdown', (e) {
      final d = _drag;
      if (d != null && d.mode == 'kb') _finish(d, false, d.at.$1, d.at.$2);
    }, capture: true);
    // A finger that is dragging must not scroll the page: the browser
    // decides that on `touchmove`, which only a non-passive listener can
    // cancel.
    final touch = ((web.Event e) {
      if (_drag?.mode == 'ptr' && e.cancelable) e.preventDefault();
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

  static web.HTMLElement? _closest(web.EventTarget? t, String selector) {
    if (t == null || !t.isA<web.Element>()) return null;
    return (t as web.Element).closest(selector) as web.HTMLElement?;
  }

  static bool _rtl(web.Element el) =>
      web.window.getComputedStyle(el).direction == 'rtl';

  static web.HTMLTemplateElement? _templateOf(web.Element src, String attr) {
    final inside = src.querySelectorAll(':scope > template');
    for (var i = 0; i < inside.length; i++) {
      final t = inside.item(i)! as web.HTMLTemplateElement;
      if (t.hasAttribute(attr)) return t;
    }
    // A wrapper (a `Tooltip`'s bubble) can sit between the element and the
    // templates the server put beside it: look at the next siblings, up to
    // the next draggable.
    for (
      var n = src.nextElementSibling;
      n != null && !n.hasAttribute(dragSourceAttr);
      n = n.nextElementSibling
    ) {
      if (n.tagName == 'TEMPLATE' && n.hasAttribute(attr)) {
        return n as web.HTMLTemplateElement;
      }
    }
    return null;
  }

  // A draggable fits a target when the type does: `Object` and `dynamic` take
  // all, `num` an int or a double.
  static bool _fits(String target, String drag) =>
      target == drag ||
      target == 'Object' ||
      target == 'Object?' ||
      target == 'dynamic' ||
      (target == 'num' && (drag == 'int' || drag == 'double'));

  Map<String, String> _ids(web.Element el, String attr) =>
      decodeOn(el.getAttribute(attr) ?? '');

  /// Whether a target takes this drag: the type, then its `accept` method.
  bool _accepts(_Drag d, web.Element t) {
    if (!_fits(t.getAttribute(dragTypeAttr) ?? 'Object', d.type)) return false;
    final id = _ids(t, dragTargetAttr)['accept'];
    if (id == null) return true;
    try {
      return callMember(id, t, d.data) == true;
    } catch (e) {
      web.console.error('$e'.toJS);
      return false;
    }
  }

  /// Marks [t] as the one under the drag ([ok]: it takes it), after the one
  /// before leaves.
  void _hover(_Drag d, web.HTMLElement? t, bool ok) {
    final was = d.over;
    if (was != null && identical(was.target, t) && was.ok == ok) return;
    if (was != null) {
      was.target
        ..removeAttribute(dragOverAttr)
        ..removeAttribute(dragRejectAttr);
      d.asked[was.target] = null;
      final leave = _ids(was.target, dragTargetAttr)['leave'];
      if (was.ok && leave != null) run(leave, was.target, d.data);
    }
    d.over = t == null ? null : _Over(t, ok);
    t?.toggleAttribute(ok ? dragOverAttr : dragRejectAttr, true);
  }

  /// The target under ([x], [y]): the first one that takes the drag, else the
  /// innermost one that does not.
  (web.HTMLElement?, bool) _targetAt(_Drag d, double x, double y) {
    web.HTMLElement? first;
    final seen = <web.Element>[];
    final els = web.document.elementsFromPoint(x, y).toDart;
    for (final el in els) {
      for (
        web.Element? t = el.closest('[$dragTargetAttr]');
        t != null;
        t = t.parentElement?.closest('[$dragTargetAttr]')
      ) {
        if (seen.any((s) => identical(s, t))) continue;
        seen.add(t);
        var ok = d.asked[t];
        if (ok == null) {
          ok = _accepts(d, t);
          d.asked[t] = ok;
        }
        if (ok) return (t as web.HTMLElement, true);
        first ??= t as web.HTMLElement;
      }
    }
    return (first, false);
  }

  void _place(_Drag d) {
    final (x, y) = d.at;
    final c = d.setup, r = d.rect;
    final double gx, gy;
    if (d.mode == 'kb') {
      (gx, gy) = d.kb;
    } else if (c.anchor == 'p') {
      // The feedback's corner is at the pointer (a locked axis keeps the
      // child's own).
      gx = (c.axis == 'v' ? r.left : x) + c.ox;
      gy = (c.axis == 'h' ? r.top : y) + c.oy;
    } else {
      // The feedback keeps the distance the child had from the pointer.
      gx = r.left + (c.axis == 'v' ? 0 : x - d.x0) + c.ox;
      gy = r.top + (c.axis == 'h' ? 0 : y - d.y0) + c.oy;
    }
    d.ghost.style
      ..setProperty(dragVarX, '${fmt(gx)}px')
      ..setProperty(dragVarY, '${fmt(gy)}px');
  }

  int _nextFrame(void Function() fn) =>
      web.window.requestAnimationFrame(((num _) => fn()).toJS);

  void _schedule(_Drag d) {
    d.frame ??= _nextFrame(() => _frame(d));
  }

  /// One frame of a pointer drag: the ghost, the target under it, `move`.
  void _frame(_Drag d) {
    d.frame = null;
    if (!identical(_drag, d)) return;
    _place(d);
    final (t, ok) = _targetAt(d, d.at.$1, d.at.$2);
    _hover(d, t, ok);
    if (t != null && ok) {
      final move = _ids(t, dragTargetAttr)['move'];
      final key = '${d.at.$1},${d.at.$2}';
      if (move != null && key != d.sent) {
        d.sent = key;
        final r = t.getBoundingClientRect();
        run(move, t, '${fmt(d.at.$1 - r.left)}~${fmt(d.at.$2 - r.top)}');
      }
    }
  }

  /// A clone of a template shows what the page showed when it was drawn: a
  /// text the row binds (`data-tf`) or the page binds (`data-tt`) is the live
  /// one's.
  web.Element _live(web.Element clone, web.Element src) {
    final fields = clone.querySelectorAll('[$fieldAttr],[$textAttr]');
    for (var i = 0; i < fields.length; i++) {
      final f = fields.item(i)! as web.Element;
      final a = f.hasAttribute(fieldAttr) ? fieldAttr : textAttr;
      final id = f.getAttribute(a);
      final pool = <web.Element>[];
      if (a == fieldAttr) {
        pool.add(src);
        final inside = src.querySelectorAll('[$a]');
        for (var j = 0; j < inside.length; j++) {
          pool.add(inside.item(j)! as web.Element);
        }
      } else {
        final page = web.document.querySelectorAll('[$a]');
        for (var j = 0; j < page.length; j++) {
          pool.add(page.item(j)! as web.Element);
        }
      }
      for (final o in pool) {
        if (o.getAttribute(a) == id) {
          f.textContent = o.textContent;
          break;
        }
      }
    }
    return clone;
  }

  /// The drag starts: the ghost from the feedback template, the source marked,
  /// `childWhenDragging` in its place.
  _Drag? _begin(
    web.HTMLElement src,
    String mode,
    double x,
    double y,
    int? pointer,
  ) {
    final fb = _templateOf(src, dragFeedbackAttr)?.content.firstElementChild;
    if (fb == null) return null;
    final d = _Drag(
      src,
      _Setup(src),
      _ids(src, dragSourceAttr),
      pointer,
      mode,
      x,
      y,
    );
    d.type = src.getAttribute(dragTypeAttr) ?? 'Object';
    d.data = src.getAttribute(dragDataAttr) ?? '';
    d.ghost = _live(fb.cloneNode(true) as web.Element, src) as web.HTMLElement
      ..setAttribute('popover', 'manual');
    _drag = d;
    web.document.body!.append(d.ghost);
    try {
      d.ghost.showPopover();
    } catch (_) {
      // No popovers: a fixed element with a high z-index.
    }
    src.setAttribute(dragActiveAttr, '');
    // The child is replaced by `childWhenDragging` while a pointer drags it.
    if (mode == 'ptr') {
      final ph = _templateOf(
        src,
        dragPlaceholderAttr,
      )?.content.firstElementChild;
      if (ph != null) {
        final copy = _live(ph.cloneNode(true) as web.Element, src);
        d.placeholder = copy;
        src.before(copy);
        src.setAttribute(dragGoneAttr, '');
      }
    }
    final start = d.ids['start'];
    if (start != null) run(start, src);
    // The page scrolls under a pointer near its edge (not under a keyboard's
    // drag).
    if (mode == 'ptr') d.stop = autoscroll(() => d.at);
    return d;
  }

  /// The drag ends: everything it put in the page goes, and the source's
  /// methods hear how it ended.
  void _finish(_Drag d, bool accepted, double x, double y) {
    if (!identical(_drag, d)) return;
    _drag = null;
    d.stop?.call();
    final f = d.frame;
    if (f != null) web.window.cancelAnimationFrame(f);
    final over = d.over;
    final dropped = accepted && over != null && over.ok;
    // Dropped on a target that took it: it hears the drop, not that it left.
    if (dropped) {
      over.target.removeAttribute(dragOverAttr);
      d.over = null;
    } else {
      _hover(d, null, false);
    }
    final drop = dropped ? _ids(over.target, dragTargetAttr)['drop'] : null;
    d.ghost.remove();
    d.placeholder?.remove();
    d.src
      ..removeAttribute(dragActiveAttr)
      ..removeAttribute(dragGoneAttr);
    final p = d.pointer;
    if (p != null) {
      try {
        d.src.releasePointerCapture(p);
      } catch (_) {
        // Already released.
      }
    }
    if (dropped) {
      if (drop != null) run(drop, over.target, d.data);
      if (d.ids['done'] case final done?) run(done, d.src);
      if (d.ids['end'] case final end?) run(end, d.src, 'true');
    } else {
      if (d.ids['cancel'] case final cancel?) {
        run(cancel, d.src, '${fmt(x)}~${fmt(y)}');
      }
      if (d.ids['end'] case final end?) run(end, d.src, 'false');
    }
  }

  // --- pointer ---------------------------------------------------------------

  void _stopPress() {
    final t = _press?.timer;
    if (t != null) web.window.clearTimeout(t);
    _press = null;
  }

  void _down(web.Event event) {
    final e = event as web.PointerEvent;
    if (_drag != null) return;
    if (e.button != 0 && e.pointerType == 'mouse') return;
    final src = _closest(e.target, '[$dragSourceAttr]');
    if (src == null || _closest(e.target, _editable) != null) return;
    final setup = _Setup(src);
    if (setup.max == 0) return;
    _stopPress();
    final p = _press = _Press(
      src,
      e.pointerId,
      e.clientX.toDouble(),
      e.clientY.toDouble(),
      e.pointerType != 'mouse',
      setup,
    );
    // A hold first: moving before it ends is a scroll, not a drag.
    if (setup.delay > 0) {
      p.timer = web.window.setTimeout(
        (() {
          if (!identical(_press, p)) return;
          _press = null;
          if (_begin(src, 'ptr', p.x, p.y, p.id) != null) {
            _suppress = src;
            try {
              src.setPointerCapture(p.id);
            } catch (_) {
              // A pointer the browser no longer tracks.
            }
            _schedule(_drag!);
          }
        }).toJS,
        setup.delay.toJS,
      );
    }
  }

  void _move(web.Event event) {
    final e = event as web.PointerEvent;
    final d = _drag;
    if (d != null && d.mode == 'ptr' && e.pointerId == d.pointer) {
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
    // Past the slop: a drag at once, or (waiting for a hold) a scroll.
    if (!p.ready) return _stopPress();
    _stopPress();
    final started = _begin(p.src, 'ptr', p.x, p.y, p.id);
    if (started != null) {
      _suppress = p.src;
      started.at = (e.clientX.toDouble(), e.clientY.toDouble());
      _schedule(started);
      try {
        p.src.setPointerCapture(p.id);
      } catch (_) {
        // A pointer the browser no longer tracks.
      }
    }
  }

  void _up(web.Event event) {
    final e = event as web.PointerEvent;
    final d = _drag;
    if (d != null && d.mode == 'ptr' && e.pointerId == d.pointer) {
      // The last position counts: the pointer may have moved since the frame.
      final x = e.clientX.toDouble(), y = e.clientY.toDouble();
      d.at = (x, y);
      final (t, ok) = _targetAt(d, x, y);
      _hover(d, t, ok);
      _finish(d, true, x, y);
      final el = d.src;
      web.window.setTimeout(
        (() {
          if (identical(_suppress, el)) _suppress = null;
        }).toJS,
        60.toJS,
      );
      return;
    }
    final p = _press;
    if (p != null && e.pointerId == p.id) _stopPress();
  }

  void _cancel(web.Event event) {
    final e = event as web.PointerEvent;
    final d = _drag;
    if (d != null && d.mode == 'ptr' && e.pointerId == d.pointer) {
      _finish(d, false, d.at.$1, d.at.$2);
      _suppress = null;
    }
    final p = _press;
    if (p != null && e.pointerId == p.id) _stopPress();
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

  /// The targets that fit the draggable, in the page's order.
  List<web.HTMLElement> _targetsFor(_Drag d) {
    final all = web.document.querySelectorAll('[$dragTargetAttr]');
    return [
      for (var i = 0; i < all.length; i++)
        if (_fits(
              (all.item(i)! as web.Element).getAttribute(dragTypeAttr) ??
                  'Object',
              d.type,
            ) &&
            (all.item(i)! as web.Element).getClientRects().length > 0)
          all.item(i)! as web.HTMLElement,
    ];
  }

  void _pick(_Drag d, int i) {
    final list = d.list;
    if (list.isEmpty) return;
    d.index = i.clamp(0, list.length - 1);
    final t = list[d.index];
    var ok = d.asked[t];
    if (ok == null) {
      ok = _accepts(d, t);
      d.asked[t] = ok;
    }
    _hover(d, t, ok);
    t.scrollIntoView(
      web.ScrollIntoViewOptions(block: 'nearest', inline: 'nearest'),
    );
    final r = t.getBoundingClientRect(), g = d.ghost.getBoundingClientRect();
    d.kb = (
      r.left + r.width / 2 - g.width / 2,
      r.top + r.height / 2 - g.height / 2,
    );
    _place(d);
    final w = words(d.src, dragLabelsAttr, _english);
    say(fill(ok ? w[1] : w[2], nameOf(d.src), nameOf(t)));
  }

  void _lift(web.HTMLElement src) {
    final d = _begin(src, 'kb', 0, 0, null);
    if (d == null) return;
    d.list = _targetsFor(d);
    d.kb = (d.rect.left, d.rect.top);
    d.at = (d.rect.left + d.rect.width / 2, d.rect.top + d.rect.height / 2);
    _place(d);
    say(fill(words(src, dragLabelsAttr, _english)[0], nameOf(src)));
  }

  void _key(web.Event event) {
    final e = event as web.KeyboardEvent;
    final d = _drag;
    // A pointer drag: Escape gives it up.
    if (d != null && d.mode == 'ptr') {
      if (e.key == 'Escape') {
        _finish(d, false, d.at.$1, d.at.$2);
        e.preventDefault();
      }
      return;
    }
    if (d != null && d.mode == 'kb') {
      final k = e.key;
      final w = words(d.src, dragLabelsAttr, _english);
      // Every key belongs to the drag while it lasts (a page that scrolls
      // under the arrows would lose the target).
      if (k == 'Escape') {
        _finish(d, false, d.at.$1, d.at.$2);
        say(fill(w[4], nameOf(d.src)));
      } else if (k == ' ' || k == 'Enter') {
        final over = d.over;
        if (over != null && over.ok) {
          say(fill(w[3], nameOf(d.src), nameOf(over.target)));
          _finish(d, true, d.at.$1, d.at.$2);
        } else if (over != null) {
          say(fill(w[2], nameOf(d.src), nameOf(over.target)));
        } else {
          say(fill(w[0], nameOf(d.src)));
        }
      } else if (k == 'Tab' ||
          k.startsWith('Arrow') ||
          k == 'Home' ||
          k == 'End') {
        final rtl = _rtl(d.src);
        final forward = k == 'Tab'
            ? !e.shiftKey
            : k == 'ArrowDown' || k == (rtl ? 'ArrowLeft' : 'ArrowRight');
        final back = k == 'Tab'
            ? e.shiftKey
            : k == 'ArrowUp' || k == (rtl ? 'ArrowRight' : 'ArrowLeft');
        if (k == 'Home') {
          _pick(d, 0);
        } else if (k == 'End') {
          _pick(d, d.list.length - 1);
        } else if (forward) {
          _pick(d, d.index + 1);
        } else if (back) {
          _pick(d, d.index - 1);
        }
      } else {
        return;
      }
      e
        ..preventDefault()
        ..stopImmediatePropagation();
      if (!identical(_drag, d) && d.src.isConnected) {
        d.src.focus(web.FocusOptions(preventScroll: true));
      }
      return;
    }
    if (d != null ||
        e.defaultPrevented ||
        e.altKey ||
        e.ctrlKey ||
        e.metaKey ||
        e.shiftKey) {
      return;
    }
    final src = _closest(e.target, '[$dragSourceAttr]');
    // Space or Enter on the draggable itself (not on a field or a control
    // inside it).
    if (src == null ||
        !identical(e.target, src) ||
        (e.key != ' ' && e.key != 'Enter') ||
        _Setup(src).max == 0) {
      return;
    }
    e.preventDefault();
    _lift(src);
  }
}
