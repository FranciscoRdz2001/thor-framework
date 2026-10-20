/// thor_ui's `Dismissible` (`data-t-dm`; the lite engine's
/// `parts/dismissible.js` is the same).
///
/// The body (`data-t-dm-body`) follows the pointer through `--t-dm-x/y`,
/// which its own class maps to `translate`; the backgrounds under it are
/// shown by `data-t-dm-on`. Nothing runs in Dart while it moves. Past the
/// threshold (or a fling) the body slides out, `confirm` is asked (a state
/// method returning a `bool` or a `Future<bool>`), the root collapses (a CSS
/// transition of a grid track, `data-t-dm-gone`) and `dismissed` runs once
/// with the `DismissDirection`. Delete / Backspace and Shift+arrow do the
/// same from the keyboard.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:thor_engine/src/bindings.dart' show Binding;
import 'package:thor_engine/src/protocol.dart';
import 'package:thor_engine/src/thor_state.dart' show ThorMember;
import 'package:thor_engine_oracle/client.dart' show EngineFeature, EngineRun;
import 'package:thor_engine_oracle/src/member_ref.dart';
import 'package:web/web.dart' as web;

/// `Dismissible` widgets: drag or key them away.
final class DismissibleFeature extends EngineFeature {
  /// The feature.
  const DismissibleFeature();

  @override
  void collect(
    web.Element scope,
    ThorMember Function(String id) member,
    List<Binding> bindings,
    Set<String> seen, {
    bool late = false,
  }) {
    // `confirm` needs what the method returns, which an action doesn't give
    // back: the feature keeps the page's resolver (one per page).
    pageMember = member;
  }

  @override
  void Function()? install(web.Element scope, EngineRun run) {
    final d = _Dismissibles(scope, run);
    return d.dispose;
  }
}

const _slop = 8.0;
const _flingSpeed = 0.7;
const _directions = ['startToEnd', 'endToStart', 'up', 'down'];
const _editable = 'input,textarea,select,[contenteditable]';

class _Setup {
  _Setup(web.Element root) {
    final a = (root.getAttribute(dismissibleSetupAttr) ?? '').split('|');
    vertical = a.isNotEmpty && a[0] == 'v';
    for (var i = 0; i < 4; i++) {
      final s = i + 1 < a.length ? a[i + 1] : '-';
      thresholds.add(s == '-' ? null : _num(s));
    }
    move = a.length > 5 ? (_num(a[5]) ?? 0).round() : 0;
    resize = a.length > 6 ? (_num(a[6]) ?? 0).round() : 0;
  }

  late final bool vertical;
  final List<double?> thresholds = [];
  late final int move, resize;

  bool allows(String dir) => thresholds[_directions.indexOf(dir)] != null;
}

class _Press {
  _Press(this.root, this.body, this.setup, this.id, this.x, this.y);

  final web.HTMLElement root, body;
  final _Setup setup;
  final int id;
  final double x, y;
  bool on = false;
  double extent = 0;
  final List<(double, double)> last = [];
}

class _Dismissibles {
  _Dismissibles(this.scope, this.run) {
    _on('pointerdown', _down);
    _on('pointermove', _move);
    _on('pointerup', _up);
    _on('pointercancel', _cancel);
    _on('click', _click, capture: true);
    _on('dragstart', (e) {
      if (_press?.on ?? false) e.preventDefault();
    });
    _on('keydown', _key);
  }

  final web.Element scope;
  final EngineRun run;
  final _undo = <void Function()>[];
  _Press? _press;
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

  static web.HTMLElement? _rootOf(web.EventTarget? t) {
    if (t == null || !t.isA<web.Element>()) return null;
    return (t as web.Element).closest('[$dismissibleAttr]') as web.HTMLElement?;
  }

  static web.HTMLElement? _bodyOf(web.Element root) =>
      root.querySelector(':scope > [$dismissibleBodyAttr]') as web.HTMLElement?;

  static bool _rtl(web.Element el) =>
      web.window.getComputedStyle(el).direction == 'rtl';

  static bool _calm() =>
      web.window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /// Where a movement of sign [s] along the axis goes.
  static String _dirOf(web.Element root, _Setup c, double s) => c.vertical
      ? (s > 0 ? 'down' : 'up')
      : ((s > 0) != _rtl(root) ? 'startToEnd' : 'endToStart');

  static double _signOf(web.Element root, _Setup c, String dir) => c.vertical
      ? (dir == 'down' ? 1 : -1)
      : ((dir == 'startToEnd') != _rtl(root) ? 1 : -1);

  static double _room(web.HTMLElement b, _Setup c) =>
      (c.vertical ? b.offsetHeight : b.offsetWidth).toDouble();

  static void _px(web.HTMLElement b, _Setup c, double v) => b.style.setProperty(
    c.vertical ? dismissibleVarY : dismissibleVarX,
    '${(v * 10).round() / 10}px',
  );

  static void _reveal(web.Element root, String? dir) {
    final bgs = root.querySelectorAll(':scope > [$dismissibleBackgroundAttr]');
    for (var i = 0; i < bgs.length; i++) {
      final bg = bgs.item(i)! as web.Element;
      bg.toggleAttribute(
        dismissibleOnAttr,
        dir != null &&
            bg
                .getAttribute(dismissibleBackgroundAttr)!
                .split(' ')
                .contains(dir),
      );
    }
  }

  void _after(int ms, void Function() fn) {
    web.window.setTimeout(fn.toJS, (_calm() ? 20 : ms + 20).toJS);
  }

  void _back(web.HTMLElement root, web.HTMLElement b, _Setup c) {
    b.setAttribute(dismissibleOutAttr, '');
    b.style
      ..setProperty(dismissibleVarX, '0px')
      ..setProperty(dismissibleVarY, '0px');
    _after(c.move, () {
      b.removeAttribute(dismissibleOutAttr);
      if (!b.hasAttribute(dismissibleDragAttr)) _reveal(root, null);
    });
  }

  /// After a dismissal the focus goes to the next row (or the one before).
  void _refocus(web.HTMLElement root) {
    final active = web.document.activeElement;
    if (active != root && !root.contains(active)) return;
    for (final next in const [true, false]) {
      for (
        var s = next ? root.nextElementSibling : root.previousElementSibling;
        s != null;
        s = next ? s.nextElementSibling : s.previousElementSibling
      ) {
        if (s.hasAttribute(dismissibleAttr) &&
            !s.hasAttribute(dismissibleGoneAttr)) {
          (s as web.HTMLElement).focus(web.FocusOptions(preventScroll: true));
          return;
        }
      }
    }
  }

  void _leave(web.HTMLElement root, web.HTMLElement b, _Setup c, String dir) {
    if (b.hasAttribute(dismissibleOutAttr) ||
        root.hasAttribute(dismissibleGoneAttr)) {
      return;
    }
    final ids = decodeOn(root.getAttribute(dismissibleAttr) ?? '');
    _reveal(root, dir);
    b
      ..removeAttribute(dismissibleDragAttr)
      ..setAttribute(dismissibleOutAttr, '');
    b.style.setProperty(
      c.vertical ? dismissibleVarY : dismissibleVarX,
      '${_signOf(root, c, dir) * _room(b, c)}px',
    );
    void dismiss() {
      if (!root.isConnected) return;
      _refocus(root);
      void done() => run(ids['dismissed']!, root, dir);
      if (c.resize > 0) {
        root.setAttribute(dismissibleGoneAttr, '');
        _after(c.resize, done);
      } else {
        done();
      }
    }

    void decide(Object? ok) {
      if (ok == true) {
        dismiss();
      } else if (root.isConnected) {
        _back(root, b, c);
      }
    }

    _after(c.move, () {
      if (!root.isConnected) return;
      final confirm = ids['confirm'];
      if (confirm == null) return dismiss();
      Object? r;
      try {
        r = callMember(confirm, root, dir);
      } catch (e) {
        web.console.error('$e'.toJS);
      }
      if (r is Future) {
        r.then<void>(
          decide,
          onError: (Object e) {
            web.console.error('$e'.toJS);
            decide(false);
          },
        );
      } else {
        decide(r);
      }
    });
  }

  void _down(web.Event event) {
    final e = event as web.PointerEvent;
    if (e.button != 0 && e.pointerType == 'mouse') return;
    final root = _rootOf(e.target);
    final b = root == null ? null : _bodyOf(root);
    if (root == null ||
        b == null ||
        !b.contains(e.target as web.Node?) ||
        _press != null ||
        b.hasAttribute(dismissibleOutAttr) ||
        root.hasAttribute(dismissibleGoneAttr)) {
      return;
    }
    // The text of a field is the field's.
    if ((e.target! as web.Element).closest(_editable) != null) return;
    _press = _Press(
      root,
      b,
      _Setup(root),
      e.pointerId,
      e.clientX.toDouble(),
      e.clientY.toDouble(),
    );
  }

  void _move(web.Event event) {
    final e = event as web.PointerEvent;
    final p = _press;
    if (p == null || e.pointerId != p.id) return;
    final dx = e.clientX - p.x, dy = e.clientY - p.y;
    if (!p.on) {
      if (math.sqrt(dx * dx + dy * dy) < _slop) return;
      // Movement along the other axis is the page's (a scroll).
      if ((dx.abs() >= dy.abs()) == p.setup.vertical) {
        _press = null;
        return;
      }
      p.on = true;
      p.body
        ..setAttribute(dismissibleDragAttr, '')
        ..removeAttribute(dismissibleOutAttr);
      try {
        p.body.setPointerCapture(e.pointerId);
      } catch (_) {
        // A pointer the browser no longer tracks.
      }
      _suppress = p.root;
    }
    var d = p.setup.vertical ? dy : dx;
    // A direction that is not allowed does not move.
    if (d != 0 && !p.setup.allows(_dirOf(p.root, p.setup, d))) d = 0;
    p.extent = d.toDouble();
    _px(p.body, p.setup, p.extent);
    _reveal(p.root, d == 0 ? null : _dirOf(p.root, p.setup, d));
    final now = web.window.performance.now();
    p.last.add((now, p.extent));
    while (p.last.length > 1 && now - p.last.first.$1 > 100) {
      p.last.removeAt(0);
    }
  }

  void _up(web.Event event) {
    final e = event as web.PointerEvent;
    final p = _press;
    if (p == null || e.pointerId != p.id) return;
    _press = null;
    if (!p.on) return;
    final el = p.root;
    web.window.setTimeout(
      (() {
        if (identical(_suppress, el)) _suppress = null;
      }).toJS,
      60.toJS,
    );
    final d = p.extent;
    p.body.removeAttribute(dismissibleDragAttr);
    if (d == 0) return _back(p.root, p.body, p.setup);
    final dir = _dirOf(p.root, p.setup, d);
    final size = math.max(_room(p.body, p.setup), 1);
    final first = p.last.first;
    // At least a frame: a burst of events is not a fling.
    final dt = math.max(web.window.performance.now() - first.$1, 16);
    final speed = (d - first.$2) / dt;
    final far =
        d.abs() >= p.setup.thresholds[_directions.indexOf(dir)]! * size ||
        (speed.abs() >= _flingSpeed && speed.sign == d.sign);
    if (far) {
      _leave(p.root, p.body, p.setup, dir);
    } else {
      _back(p.root, p.body, p.setup);
    }
  }

  void _cancel(web.Event event) {
    final p = _press;
    if (p == null || (event as web.PointerEvent).pointerId != p.id) return;
    _press = null;
    _suppress = null;
    if (!p.on) return;
    p.body.removeAttribute(dismissibleDragAttr);
    _back(p.root, p.body, p.setup);
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

  void _key(web.Event event) {
    final e = event as web.KeyboardEvent;
    final root = _rootOf(e.target);
    if (root == null ||
        e.defaultPrevented ||
        e.altKey ||
        e.ctrlKey ||
        e.metaKey) {
      return;
    }
    final target = e.target! as web.HTMLElement;
    if (target.closest(_editable) != null || target.isContentEditable) return;
    final b = _bodyOf(root);
    if (b == null) return;
    final c = _Setup(root);
    final k = e.key;
    String? dir;
    if ((k == 'Delete' || k == 'Backspace') && !e.shiftKey) {
      for (final d in const ['endToStart', 'startToEnd', 'up', 'down']) {
        if (c.allows(d)) {
          dir = d;
          break;
        }
      }
    } else if (e.shiftKey &&
        k.startsWith('Arrow') &&
        (k == 'ArrowUp' || k == 'ArrowDown') == c.vertical) {
      dir = _dirOf(root, c, k == 'ArrowRight' || k == 'ArrowDown' ? 1 : -1);
      if (!c.allows(dir)) dir = null;
    }
    if (dir == null) return;
    e.preventDefault();
    _leave(root, b, c, dir);
  }
}

/// The browser's `parseFloat`: Dart's `double.tryParse` would pull a regular
/// expression engine into the bundle.
double? _num(String s) {
  final n = globalContext.callMethod<JSNumber>('parseFloat'.toJS, s.toJS);
  final v = n.toDartDouble;
  return v.isNaN ? null : v;
}
