/// Pointer gestures for thor_ui's `Gesture`: double tap, long press, swipe
/// (to dismiss), drag and pinch, with mouse, touch and pen.
///
/// While a gesture runs no Dart state changes: the element follows the
/// pointer through CSS variables (`--tg-x`, `--tg-y`, `--tg-s`) that its own
/// class maps to `translate` / `scale`, so the browser moves it on the
/// compositor. On release the engine calls the state's method once, with
/// the result (a direction, the displacement or the scale).
///
/// A drag with `onDragUpdate` is the exception: the state follows the
/// pointer instead (a column edge, a splitter). The engine hands it the
/// movement at most once per animation frame (moves in between add up),
/// and the element itself stays put.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:thor_engine/src/protocol.dart';
import 'package:thor_engine_oracle/client.dart' show EngineFeature, EngineRun;
import 'package:web/web.dart' as web;

/// `Gesture` widgets: double tap, long press, swipe, drag and pinch.
final class GesturesFeature extends EngineFeature {
  /// The feature.
  const GesturesFeature();

  @override
  void Function()? install(web.Element scope, EngineRun run) {
    final g = _Gestures(scope, run);
    return g.dispose;
  }
}

/// Movement (px) before a press becomes a swipe or a drag.
const _slop = 8.0;

/// A press held this long (ms) without moving is a long press.
const _longPressMs = 500;

/// Two taps closer than this (ms) are a double tap.
const _doubleTapMs = 300;

/// Native controls with their own tap (see `_Press.inControl`).
const _controls = 'input,button,select,textarea,a[href],label,summary';

/// A release faster than this (px/ms) swipes even below the threshold.
const _flingSpeed = 0.6;

enum _Mode { none, swipe, drag, pinch }

/// One element being pressed.
class _Press {
  _Press(this.el, this.spec, this.x, this.y, this.t);

  final web.HTMLElement el;
  final Map<String, String> spec;
  final double x, y;
  final double t;
  final Map<int, (double, double)> pointers = {};
  _Mode mode = _Mode.none;
  double dx = 0, dy = 0;

  /// The pointer's samples `(time, x, y)`, for the release velocity of a
  /// `GestureDetector.onPanEnd`.
  final trail = <(double, double, double)>[];
  double startDistance = 0, scale = 1;

  /// `onDragUpdate`: the movement from the press already handed to the
  /// state, the latest movement, and the pending frame.
  double sentX = 0, sentY = 0, lastX = 0, lastY = 0;
  int? frame;
  int? longTimer;
  bool longFired = false;

  /// The press began on a native control inside the element (a checkbox,
  /// a button): its own tap wins, like Flutter's gesture arena, so it
  /// doesn't count toward the element's double tap.
  bool inControl = false;
}

class _Gestures {
  _Gestures(this.scope, this.run) {
    _on('pointerdown', _down);
    _on('pointermove', _move);
    _on('pointerup', _up);
    _on('pointercancel', _cancel);
    _on('contextmenu', _contextMenu);
    _on('keydown', _key);
    // Capture: a gesture that moved (or a long press) must not also click.
    _on('click', _click, capture: true);
  }

  final web.Element scope;
  final EngineRun run;
  final _undo = <void Function()>[];
  _Press? _press;
  web.Element? _suppressClick;
  web.Element? _lastTapEl;
  double _lastTapAt = 0;
  web.Element? _lastLongEl;
  double _lastLongAt = 0;

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

  static web.HTMLElement? _target(web.Event e) {
    final t = e.target;
    if (t == null || !t.isA<web.Element>()) return null;
    final el = (t as web.Element).closest('[$gestureAttr]');
    return el == null ? null : el as web.HTMLElement;
  }

  static Map<String, String> _spec(web.Element el) =>
      decodeOn(el.getAttribute(gestureAttr) ?? '');

  static List<String> _setup(web.Element el, String attr) =>
      (el.getAttribute(attr) ?? '').split('|');

  static double _var(web.HTMLElement el, String name, double fallback) {
    final v = el.style.getPropertyValue(name);
    return v.isEmpty ? fallback : _num(v) ?? fallback;
  }

  static void _set(web.HTMLElement el, String name, double v, [String? unit]) =>
      el.style.setProperty(
        name,
        '${_round(v, unit == null ? 2 : 1)}${unit ?? ''}',
      );

  /// [v] with at most [decimals] decimals, without trailing zeros.
  static String _round(double v, [int decimals = 1]) {
    final f = math.pow(10, decimals);
    final r = (v * f).round() / f;
    return r == r.roundToDouble() ? '${r.round()}' : '$r';
  }

  // --- pointer events -----------------------------------------------------

  void _down(web.Event event) {
    final e = event as web.PointerEvent;
    if (e.button != 0 && e.pointerType == 'mouse') return;
    final el = _target(e);
    if (el == null) return;
    final press = _press;
    if (press != null && identical(press.el, el)) {
      // A second finger on the same element: pinch.
      press.pointers[e.pointerId] = (
        e.clientX.toDouble(),
        e.clientY.toDouble(),
      );
      if (press.pointers.length == 2 && press.spec.containsKey('scale')) {
        press
          ..mode = _Mode.pinch
          ..startDistance = _distance(press)
          ..scale = _var(el, '--tg-s', 1);
        _cancelTimer(press.longTimer);
        _begin(press);
      }
      return;
    }
    final spec = _spec(el);
    final p = _Press(
      el,
      spec,
      e.clientX.toDouble(),
      e.clientY.toDouble(),
      web.window.performance.now(),
    );
    p.pointers[e.pointerId] = (p.x, p.y);
    p.trail.add((p.t, p.x, p.y));
    final control = (e.target! as web.Element).closest(_controls);
    p.inControl =
        control != null && !identical(control, el) && el.contains(control);
    _press = p;
    // `onTapDown`: where the pointer went down (a tap on a native control
    // inside is that control's).
    if (spec['tapd'] case final id? when !p.inControl) {
      run(id, el, _local(el, p.x, p.y));
    }
    if (spec['long'] case final id?) {
      p.longTimer = _after(_longPressMs, () {
        if (_press != p || p.mode != _Mode.none) return;
        p.longFired = true;
        _fireLong(el, id);
      });
    }
  }

  /// A long press once: the timer, the browser's own `contextmenu` (Android
  /// sends it around the same time, sometimes after a `pointercancel`) and a
  /// right click are one request, however they interleave.
  void _fireLong(web.Element el, String id) {
    final now = web.window.performance.now();
    if (identical(_lastLongEl, el) && now - _lastLongAt < 300) return;
    _lastLongEl = el;
    _lastLongAt = now;
    _suppressClick = el;
    run(id, el);
  }

  void _move(web.Event event) {
    final e = event as web.PointerEvent;
    final p = _press;
    if (p == null || !p.pointers.containsKey(e.pointerId)) return;
    p.pointers[e.pointerId] = (e.clientX.toDouble(), e.clientY.toDouble());
    p.trail.add((
      web.window.performance.now(),
      e.clientX.toDouble(),
      e.clientY.toDouble(),
    ));
    if (p.trail.length > 24) p.trail.removeAt(0);
    if (p.mode == _Mode.pinch) {
      // One finger left: the scale rests where it was.
      if (p.pointers.length < 2) return;
      final setup = _setup(p.el, scaleAttr);
      final min = _num(setup[0]) ?? 1;
      final max = _num(setup.length > 1 ? setup[1] : '') ?? 4;
      final s = (p.scale * _distance(p) / math.max(p.startDistance, 1)).clamp(
        min,
        max,
      );
      _set(p.el, '--tg-s', s.toDouble());
      return;
    }
    final dx = e.clientX - p.x, dy = e.clientY - p.y;
    if (p.mode == _Mode.none) {
      if (math.sqrt(dx * dx + dy * dy) < _slop) return;
      _cancelTimer(p.longTimer);
      final horizontal = dx.abs() >= dy.abs();
      final swipe = p.spec.containsKey('swipe')
          ? _setup(p.el, swipeAttr)[0]
          : null;
      final drag = p.spec.containsKey('drag') || p.spec.containsKey('dragu')
          ? _setup(p.el, dragAttr)[0]
          : null;
      if (swipe != null && (swipe == 'h') == horizontal) {
        p.mode = _Mode.swipe;
      } else if (drag != null && (drag == 'f' || (drag == 'h') == horizontal)) {
        p.mode = _Mode.drag;
        p
          ..dx = _var(p.el, '--tg-x', 0)
          ..dy = _var(p.el, '--tg-y', 0);
      } else {
        // Movement this element doesn't handle (e.g. a vertical scroll).
        _press = null;
        return;
      }
      _begin(p, pointerId: e.pointerId);
    }
    if (p.mode == _Mode.swipe) {
      final h = _setup(p.el, swipeAttr)[0] == 'h';
      _set(p.el, h ? '--tg-x' : '--tg-y', h ? dx : dy, 'px');
    } else if (p.mode == _Mode.drag) {
      final axis = _setup(p.el, dragAttr)[0];
      if (p.spec.containsKey('dragu')) {
        p
          ..lastX = axis == 'v' ? 0 : dx
          ..lastY = axis == 'h' ? 0 : dy;
        p.frame ??= _nextFrame(() {
          p.frame = null;
          _flushUpdate(p);
        });
        return;
      }
      if (axis != 'v') _set(p.el, '--tg-x', p.dx + dx, 'px');
      if (axis != 'h') _set(p.el, '--tg-y', p.dy + dy, 'px');
    }
  }

  /// Hands `onDragUpdate` the movement since its last call (rounded to a
  /// tenth of a pixel; what rounding leaves out goes with the next one).
  void _flushUpdate(_Press p) {
    final id = p.spec['dragu'];
    if (id == null) return;
    final dx = _roundTo(p.lastX - p.sentX), dy = _roundTo(p.lastY - p.sentY);
    if (dx == 0 && dy == 0) return;
    p
      ..sentX += dx
      ..sentY += dy;
    run(id, p.el, '${_round(dx)}~${_round(dy)}');
  }

  void _begin(_Press p, {int? pointerId}) {
    p.el
      ..setAttribute(gestureActiveAttr, '')
      ..removeAttribute(gestureReleaseAttr);
    if (pointerId != null) {
      try {
        p.el.setPointerCapture(pointerId);
      } catch (_) {
        // A pointer the browser no longer tracks (released, synthetic).
      }
    }
    _suppressClick = p.el;
  }

  void _up(web.Event event) {
    final e = event as web.PointerEvent;
    final p = _press;
    if (p == null || !p.pointers.containsKey(e.pointerId)) return;
    p.pointers.remove(e.pointerId);
    if (p.mode == _Mode.pinch && p.pointers.isNotEmpty) return;
    _press = null;
    _cancelTimer(p.longTimer);
    p.el.removeAttribute(gestureActiveAttr);
    // The click of this gesture (if the browser sends one) comes right after
    // the pointerup; a touch that moved never gets one, and the flag must not
    // wait for the next tap to swallow it.
    if (identical(_suppressClick, p.el)) {
      final el = p.el;
      _after(60, () {
        if (identical(_suppressClick, el)) _suppressClick = null;
      });
    }
    final dx = e.clientX - p.x, dy = e.clientY - p.y;
    final dt = math.max(web.window.performance.now() - p.t, 1.0);
    switch (p.mode) {
      case _Mode.none:
        if (p.longFired) return;
        if (p.inControl) {
          _lastTapEl = null;
          return;
        }
        _tap(p.el, p.spec, e.clientX.toDouble(), e.clientY.toDouble());
      case _Mode.swipe:
        _endSwipe(p, dx, dy, dt);
      case _Mode.drag:
        _endDrag(p, dx, dy, e);
      case _Mode.pinch:
        _endPinch(p);
    }
  }

  void _cancel(web.Event event) {
    final p = _press;
    // Another finger's cancel is not this press's.
    if (p == null ||
        !p.pointers.containsKey((event as web.PointerEvent).pointerId)) {
      return;
    }
    _press = null;
    // No result, so no click to swallow either.
    _suppressClick = null;
    _cancelTimer(p.longTimer);
    _cancelFrame(p);
    p.el.removeAttribute(gestureActiveAttr);
    if (p.mode != _Mode.none) {
      _release(p.el, x: 0, y: 0, scale: p.mode == _Mode.pinch ? p.scale : null);
    }
  }

  /// [clientX]/[clientY] relative to [el]'s top-left corner, as the
  /// `x~y` argument of a state method (Flutter's `localPosition`, in CSS
  /// pixels).
  static String _local(web.Element el, double clientX, double clientY) {
    final r = el.getBoundingClientRect();
    return '${_round(clientX - r.left)}~${_round(clientY - r.top)}';
  }

  void _tap(
    web.HTMLElement el,
    Map<String, String> spec,
    double clientX,
    double clientY,
  ) {
    if (spec['tapu'] case final up?) run(up, el, _local(el, clientX, clientY));
    final id = spec['dtap'];
    if (id == null) return;
    final now = web.window.performance.now();
    if (identical(_lastTapEl, el) && now - _lastTapAt < _doubleTapMs) {
      _lastTapEl = null;
      run(id, el);
    } else {
      _lastTapEl = el;
      _lastTapAt = now;
    }
  }

  void _endSwipe(_Press p, double dx, double dy, double dt) {
    final setup = _setup(p.el, swipeAttr);
    final h = setup[0] == 'h';
    final dismiss = setup.length > 1 && setup[1] == '1';
    final threshold = _num(setup.length > 2 ? setup[2] : '') ?? 0.4;
    final d = h ? dx : dy;
    final size = h ? p.el.offsetWidth : p.el.offsetHeight;
    final far = d.abs() >= threshold * size || d.abs() / dt >= _flingSpeed;
    if (!far) {
      _release(p.el, x: 0, y: 0);
      return;
    }
    _swiped(p.el, p.spec['swipe']!, _dirOf(p.el, h, d), dismiss, h, d.sign);
  }

  /// Where a swipe went ([d] > 0: toward the physical right/bottom): `up`
  /// or `down`, or `start`/`end` by the element's direction (RTL flips them).
  String _dirOf(web.Element el, bool h, double d) {
    if (!h) return d > 0 ? 'down' : 'up';
    final rtl = web.window.getComputedStyle(el).direction == 'rtl';
    return (d > 0) != rtl ? 'end' : 'start';
  }

  void _swiped(
    web.HTMLElement el,
    String id,
    String direction,
    bool dismiss,
    bool horizontal,
    double sign,
  ) {
    // Already on its way out (a held key repeats): dismissed once.
    if (dismiss && el.hasAttribute(gestureOutAttr)) return;
    if (!dismiss) {
      _release(el, x: 0, y: 0);
      run(id, el, direction);
      return;
    }
    // Away and faded; the state then removes the item.
    final size = horizontal ? el.offsetWidth : el.offsetHeight;
    el.setAttribute(gestureOutAttr, '');
    _release(
      el,
      x: horizontal ? sign * size * 1.2 : null,
      y: horizontal ? null : sign * size * 1.2,
    );
    _after(200, () => run(id, el, direction));
  }

  void _endDrag(_Press p, double dx, double dy, web.PointerEvent e) {
    final setup = _setup(p.el, dragAttr);
    final axis = setup[0];
    final snap = setup.length > 1 && setup[1] == '1';
    final mx = axis == 'v' ? 0.0 : dx, my = axis == 'h' ? 0.0 : dy;
    // Measured before the snap back moves the element.
    final details = setup.length > 3 && setup[3] == '1'
        ? _ended(p, e)
        : '${_round(mx)}~${_round(my)}';
    if (p.spec.containsKey('dragu')) {
      // The last moves reach the state before the release does.
      _cancelFrame(p);
      p
        ..lastX = mx
        ..lastY = my;
      _flushUpdate(p);
    } else if (snap) {
      _release(p.el, x: 0, y: 0);
    }
    final end = p.spec['drag'];
    if (end != null) run(end, p.el, details);
  }

  /// Where [el] rests in the viewport, `(left, top, width, height)`: its box
  /// without the translate of a drag that follows the finger (Flutter's
  /// widget never moved).
  static (double, double, double, double) _rest(web.HTMLElement el) {
    final r = el.getBoundingClientRect();
    return (
      r.left - _var(el, '--tg-x', 0),
      r.top - _var(el, '--tg-y', 0),
      r.width,
      r.height,
    );
  }

  /// Flutter's `DragEndDetails` for `onPanEnd` (the drag's 4th setup field is
  /// `1`): the release velocity in px/s from the last 100 ms (the release is
  /// the last sample), clamped to Flutter's 8000, then the pointer's local
  /// and viewport positions, `vx~vy~lx~ly~gx~gy` (the local one from where
  /// the element rests).
  String _ended(_Press p, web.PointerEvent e) {
    final now = web.window.performance.now();
    final x = e.clientX.toDouble(), y = e.clientY.toDouble();
    double v(double to, double from, double dt) =>
        dt > 0 ? ((to - from) / dt * 1000).clamp(-8000.0, 8000.0) : 0.0;
    var vx = 0.0, vy = 0.0;
    for (final (t, sx, sy) in p.trail) {
      if (now - t <= 100) {
        vx = v(x, sx, now - t);
        vy = v(y, sy, now - t);
        break;
      }
    }
    final (left, top, _, _) = _rest(p.el);
    return [vx, vy, x - left, y - top, x, y].map(_round).join('~');
  }

  void _cancelFrame(_Press p) {
    final f = p.frame;
    if (f == null) return;
    web.window.cancelAnimationFrame(f);
    p.frame = null;
  }

  void _endPinch(_Press p) {
    final setup = _setup(p.el, scaleAttr);
    final snap = setup.length > 2 && setup[2] == '1';
    final s = _var(p.el, '--tg-s', 1);
    if (snap) _release(p.el, scale: 1);
    run(p.spec['scale']!, p.el, _round(s, 2));
  }

  /// Animates the element to [x]/[y]/[scale] (null: leave as is).
  void _release(web.HTMLElement el, {double? x, double? y, double? scale}) {
    el.setAttribute(gestureReleaseAttr, '');
    if (x != null) _set(el, '--tg-x', x, 'px');
    if (y != null) _set(el, '--tg-y', y, 'px');
    if (scale != null) _set(el, '--tg-s', scale);
    _after(260, () => el.removeAttribute(gestureReleaseAttr));
  }

  static double _distance(_Press p) {
    final pts = p.pointers.values.toList();
    if (pts.length < 2) return 0;
    final dx = pts[0].$1 - pts[1].$1, dy = pts[0].$2 - pts[1].$2;
    return math.sqrt(dx * dx + dy * dy);
  }

  // --- mouse, keyboard ------------------------------------------------------

  /// Right click or the keyboard's context-menu key: a long press.
  void _contextMenu(web.Event e) {
    final el = _target(e);
    if (el == null) return;
    final id = _spec(el)['long'];
    if (id == null) return;
    e.preventDefault();
    final p = _press;
    if (p != null && identical(p.el, el)) {
      // The hold is now the browser's: the timer must not fire it again.
      _cancelTimer(p.longTimer);
      p.longFired = true;
    }
    _fireLong(el, id);
  }

  void _click(web.Event e) {
    final el = _suppressClick;
    if (el == null) return;
    _suppressClick = null;
    final t = e.target;
    if (t != null && t.isA<web.Node>() && el.contains(t as web.Node)) {
      e
        ..stopImmediatePropagation()
        ..preventDefault();
    }
  }

  /// Keyboard alternatives: Delete dismisses, arrows drag, +/- zoom.
  void _key(web.Event event) {
    final e = event as web.KeyboardEvent;
    final t = e.target;
    if (t == null || !t.isA<web.Element>()) return;
    final el = t as web.Element;
    if (!el.hasAttribute(gestureAttr)) return;
    final html = el as web.HTMLElement;
    // A text field (or an editable element) that is the gesture keeps its
    // keys: Shift+arrow selects, Delete and Backspace erase.
    if (html.isContentEditable ||
        const {'INPUT', 'TEXTAREA', 'SELECT'}.contains(html.tagName)) {
      return;
    }
    final spec = _spec(el);
    final key = e.key;
    // Enter/Space on the focused element is a tap in its middle.
    if ((key == 'Enter' || key == ' ') &&
        identical(el, e.target) &&
        spec['tapu'] != null) {
      e.preventDefault();
      run(
        spec['tapu']!,
        el,
        '${_round(html.offsetWidth / 2)}~${_round(html.offsetHeight / 2)}',
      );
      return;
    }
    if ((key == 'Delete' || key == 'Backspace') && spec['swipe'] != null) {
      final setup = _setup(el, swipeAttr);
      if (setup.length > 1 && setup[1] == '1') {
        e.preventDefault();
        final h = setup[0] == 'h';
        final rtl = h && web.window.getComputedStyle(el).direction == 'rtl';
        final sign = rtl ? 1.0 : -1.0;
        _swiped(html, spec['swipe']!, _dirOf(el, h, sign), true, h, sign);
      }
      return;
    }
    // Shift+arrow along the axis is the swipe from the keyboard.
    if (e.shiftKey &&
        !e.altKey &&
        !e.ctrlKey &&
        !e.metaKey &&
        key.startsWith('Arrow') &&
        spec['swipe'] != null) {
      final setup = _setup(el, swipeAttr);
      final h = setup[0] == 'h';
      final d = h
          ? (key == 'ArrowRight' ? 1.0 : (key == 'ArrowLeft' ? -1.0 : 0.0))
          : (key == 'ArrowDown' ? 1.0 : (key == 'ArrowUp' ? -1.0 : 0.0));
      if (d != 0) {
        e.preventDefault();
        _swiped(
          html,
          spec['swipe']!,
          _dirOf(el, h, d),
          setup.length > 1 && setup[1] == '1',
          h,
          d,
        );
        return;
      }
    }
    if (key.startsWith('Arrow') &&
        (spec['drag'] != null || spec['dragu'] != null)) {
      final setup = _setup(el, dragAttr);
      final axis = setup[0];
      final step = _num(setup.length > 2 ? setup[2] : '') ?? 10;
      final (dx, dy) = switch (key) {
        'ArrowLeft' when axis != 'v' => (-step, 0.0),
        'ArrowRight' when axis != 'v' => (step, 0.0),
        'ArrowUp' when axis != 'h' => (0.0, -step),
        'ArrowDown' when axis != 'h' => (0.0, step),
        _ => (0.0, 0.0),
      };
      if (dx == 0 && dy == 0) return;
      e.preventDefault();
      final snap = setup.length > 1 && setup[1] == '1';
      final moved = '${_round(dx)}~${_round(dy)}';
      if (spec['dragu'] case final update?) {
        // The state moves it: one update, then the end.
        run(update, el, moved);
      } else if (!snap) {
        _set(html, '--tg-x', _var(html, '--tg-x', 0) + dx, 'px');
        _set(html, '--tg-y', _var(html, '--tg-y', 0) + dy, 'px');
      }
      if (spec['drag'] case final end?) {
        // A key has no velocity: the details are at the element's center.
        final (left, top, w, h) = _rest(html);
        run(
          end,
          el,
          setup.length > 3 && setup[3] == '1'
              ? '0~0~${_round(w / 2)}~${_round(h / 2)}~'
                    '${_round(left + w / 2)}~${_round(top + h / 2)}'
              : moved,
        );
      }
      return;
    }
    if ((key == '+' || key == '=' || key == '-') && spec['scale'] != null) {
      final setup = _setup(el, scaleAttr);
      final min = _num(setup[0]) ?? 1;
      final max = _num(setup.length > 1 ? setup[1] : '') ?? 4;
      final step = _num(setup.length > 3 ? setup[3] : '') ?? 0.25;
      final s = (_var(html, '--tg-s', 1) + (key == '-' ? -step : step))
          .clamp(min, max)
          .toDouble();
      e.preventDefault();
      _set(html, '--tg-s', s);
      run(spec['scale']!, el, _round(s, 2));
    }
  }
}

/// `setTimeout` straight from the browser (no Dart `Timer`/zone machinery
/// in the bundle).
int _after(int ms, void Function() fn) =>
    web.window.setTimeout(fn.toJS, ms.toJS);

void _cancelTimer(int? id) {
  if (id != null) web.window.clearTimeout(id);
}

/// `requestAnimationFrame` straight from the browser.
int _nextFrame(void Function() fn) =>
    web.window.requestAnimationFrame(((num _) => fn()).toJS);

/// [v] rounded to a tenth.
double _roundTo(double v) => (v * 10).round() / 10;

/// The browser's `parseFloat` (`'12px'` → 12), or null for no number. Dart's
/// `double.tryParse` would pull a regular-expression engine into the bundle.
double? _num(String s) {
  final n = globalContext.callMethod<JSNumber>('parseFloat'.toJS, s.toJS);
  final v = n.toDartDouble;
  return v.isNaN ? null : v;
}
