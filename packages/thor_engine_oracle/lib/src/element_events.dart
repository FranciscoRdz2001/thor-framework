/// Element events of thor_ui's `MouseRegion.onEnter/onExit`,
/// `Focus.onFocusChange`, `ExpansionTile.onExpansionChanged` and
/// `PageView.onPageChanged` (`data-t-ev`): the ones `data-t-on` cannot carry, because `toggle` does
/// not bubble and enter/leave/focus need the related target to tell the
/// boundary between two children from the region's own edge (the same
/// `mouseover`/`mouseout` + `relatedTarget` test `mouseenter` does).
///
/// A finger never hovers, so only a mouse or pen counts. The handlers of
/// `focus` and `toggle` get `true`/`false`; the one of `page` the index of
/// the page a scroll-snap view settled on (`round(offset / size)`, read on
/// `scrollend`, or when the scroll has paused for 120 ms where there is no
/// `scrollend`: Safari before 26.2), only when it changed. Each element reports in
/// balanced pairs, and the state at hydration counts (the click that wakes
/// the engine may be inside a region). The lite engine has the same in
/// `lib/lite/parts/element_events.js`.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:thor_engine/src/protocol.dart';
import 'package:thor_engine_oracle/client.dart' show EngineFeature, EngineRun;
import 'package:web/web.dart' as web;

/// `MouseRegion`, `Focus` and `ExpansionTile` callbacks.
final class ElementEventsFeature extends EngineFeature {
  /// The feature.
  const ElementEventsFeature();

  @override
  void Function()? install(web.Element scope, EngineRun run) =>
      _ElementEvents(scope, run).dispose;

  // The listeners are on the scope and reach a late part; what it has
  // before the first event (the page a view shows, whether a tile is open)
  // is read here, once the controllers have taken the views to their start.
  @override
  void Function()? installLate(web.Element part, EngineRun run) {
    scheduleMicrotask(() {
      if (!part.isConnected) return;
      for (final el in [part, ..._ElementEvents._within(part)]) {
        final spec = _ElementEvents._spec(el);
        if (spec.containsKey('page')) {
          _ElementEvents._page[el] ??= _ElementEvents._pageOf(el);
        }
        if (spec.containsKey('toggle') && el.isA<web.HTMLDetailsElement>()) {
          _ElementEvents._open[el] ??= (el as web.HTMLDetailsElement).open;
        }
      }
    });
    return null;
  }
}

class _ElementEvents {
  _ElementEvents(this.scope, this.run) {
    _on('pointerover', (e) {
      if (_touch(e)) return;
      for (final el in _chain(e.target, 'enter')) {
        if (!_inside(el, e)) _enter(el);
      }
    });
    _on('pointerout', (e) {
      if (_touch(e)) return;
      for (final el in _chain(e.target, 'leave')) {
        if (!_inside(el, e)) _leave(el);
      }
    });
    _on('focusin', (e) {
      for (final el in _chain(e.target, 'focus')) {
        if (!_inside(el, e)) _gain(el);
      }
    });
    _on('focusout', (e) {
      for (final el in _chain(e.target, 'focus')) {
        if (!_inside(el, e)) _lose(el);
      }
    });
    _on('toggle', _toggle);
    // The state a tile has before the user changes it: the click (or Enter /
    // Space) on its summary comes before the toggle, so a tile that arrived
    // after the load is known by the time it reports.
    _on('click', (e) {
      final t = e.target;
      if (t == null || !t.isA<web.Element>()) return;
      final el = (t as web.Element).closest('summary')?.parentElement;
      if (el != null &&
          el.isA<web.HTMLDetailsElement>() &&
          el.hasAttribute(elementEventsAttr) &&
          _open[el] == null &&
          _spec(el).containsKey('toggle')) {
        _open[el] = (el as web.HTMLDetailsElement).open;
      }
    });
    // Scroll events don't bubble: captured, like `toggle`.
    _on('scroll', (e) {
      final el = _pageView(e.target);
      if (el == null) return;
      _timers.remove(el)?.cancel();
      _timers[el] = Timer(
        const Duration(milliseconds: 120),
        () => _settled(el),
      );
    });
    _on('scrollend', (e) {
      final el = _pageView(e.target);
      if (el == null) return;
      _timers.remove(el)?.cancel();
      _settled(el);
    });
    // A hidden view the controller took to its page when it was shown.
    _on(pageStartEvent, (e) {
      final el = _pageView(e.target);
      if (el != null) _page[el] = _pageOf(el);
    });
    _sync();
  }

  final web.Element scope;
  final EngineRun run;
  final _over = Expando<bool>('thor.over');
  final _focus = Expando<bool>('thor.focus');

  // What the feature knows of a tile and of a view; static for
  // [ElementEventsFeature.installLate].
  static final _open = Expando<bool>('thor.open');
  static final _page = Expando<int>('thor.page');

  /// The elements under [part] that report events.
  static List<web.Element> _within(web.Element part) {
    final all = part.querySelectorAll('[$elementEventsAttr]');
    return [for (var i = 0; i < all.length; i++) all.item(i)! as web.Element];
  }

  final _timers = <web.Element, Timer>{};
  final _undo = <void Function()>[];

  void _on(String type, void Function(web.Event e) handler) {
    final js = handler.toJS;
    // Capture: `toggle` does not bubble, and the others must not depend on
    // what the page does with the event.
    scope.addEventListener(type, js, true.toJS);
    _undo.add(() => scope.removeEventListener(type, js, true.toJS));
  }

  void dispose() {
    for (final u in _undo) {
      u();
    }
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
  }

  /// [target] if it is a view that reports its page.
  static web.Element? _pageView(web.EventTarget? target) {
    if (target == null || !target.isA<web.Element>()) return null;
    final el = target as web.Element;
    return el.hasAttribute(elementEventsAttr) && _spec(el).containsKey('page')
        ? el
        : null;
  }

  /// The page a view shows: the offset in sizes, from the start (negative
  /// offsets of a right-to-left or reversed view count the same).
  static int _pageOf(web.Element el) {
    final horizontal = el.hasAttribute(horizontalScrollAttr);
    final box = el as web.HTMLElement;
    final size = horizontal ? box.clientWidth : box.clientHeight;
    if (size == 0) return 0;
    final offset = (horizontal ? box.scrollLeft : box.scrollTop).abs();
    return (offset / size).round();
  }

  void _settled(web.Element el) {
    _timers.remove(el);
    // A controller's own run (animateToPage) is still going: its end reports.
    if ((el as JSObject)['thorMoving'].isTruthy.toDart) return;
    final page = _pageOf(el);
    if (page == (_page[el] ?? 0)) return;
    _page[el] = page;
    _fire(el, 'page', '$page');
  }

  static bool _touch(web.Event e) =>
      (e as JSObject).getProperty<JSString?>('pointerType'.toJS)?.toDart ==
      'touch';

  static bool _inside(web.Element el, web.Event e) {
    final r = (e as JSObject).getProperty<JSObject?>('relatedTarget'.toJS);
    return r != null && r.isA<web.Node>() && el.contains(r as web.Node);
  }

  static Map<String, String> _spec(web.Element el) =>
      decodeOn(el.getAttribute(elementEventsAttr) ?? '');

  /// The elements from [target] up that handle [key].
  static List<web.Element> _chain(web.EventTarget? target, String key) {
    final out = <web.Element>[];
    if (target == null || !target.isA<web.Element>()) return out;
    const sel = '[$elementEventsAttr]';
    for (
      web.Element? el = (target as web.Element).closest(sel);
      el != null;
      el = el.parentElement?.closest(sel)
    ) {
      if (_spec(el).containsKey(key)) out.add(el);
    }
    return out;
  }

  void _fire(web.Element el, String key, [String? value]) {
    final id = _spec(el)[key];
    if (id != null) run(id, el, value);
  }

  void _enter(web.Element el) {
    if (_over[el] ?? false) return;
    _over[el] = true;
    _fire(el, 'enter');
  }

  void _leave(web.Element el) {
    if (!(_over[el] ?? false)) return;
    _over[el] = null;
    _fire(el, 'leave');
  }

  void _gain(web.Element el) {
    if (_focus[el] ?? false) return;
    _focus[el] = true;
    _fire(el, 'focus', 'true');
  }

  void _lose(web.Element el) {
    if (!(_focus[el] ?? false)) return;
    _focus[el] = null;
    _fire(el, 'focus', 'false');
  }

  /// A tile's toggle, from the event. A tile of an exclusive group (`name`)
  /// is not reported at once: opening one closes another, and the browsers
  /// send those two `toggle`s in either order, so the group is settled in a
  /// microtask (the attributes are all final by then) and reported closes
  /// first, then opens.
  void _toggle(web.Event e) {
    final t = e.target;
    if (t == null || !t.isA<web.HTMLDetailsElement>()) return;
    final el = t as web.HTMLDetailsElement;
    if (!_spec(el).containsKey('toggle')) return;
    final old = (e as JSObject).getProperty<JSString?>('oldState'.toJS)?.toDart;
    if ((el.getAttribute('name') ?? '').isEmpty) {
      final now = _change(el, old);
      if (now != null) _fire(el, 'toggle', '$now');
      return;
    }
    _queued.add((el, old));
    if (_queued.length > 1) return;
    scheduleMicrotask(_settleGroups);
  }

  final _queued = <(web.HTMLDetailsElement, String?)>[];

  /// The new state of [el] if it changed since this feature last saw it
  /// (`oldState` is what its `toggle` event said it was before), else null.
  bool? _change(web.HTMLDetailsElement el, String? oldState) {
    final now = el.open;
    // A tile this feature never saw that is open now arrived open (a row
    // the server inserted): its first toggle is its first state, not a
    // change. A user's open is seen first, by the click on its summary.
    final before =
        _open[el] ?? (now || (oldState == null ? !now : oldState == 'open'));
    _open[el] = now;
    // The parser sets `open` on a tile the server rendered open.
    if (web.document.readyState == 'loading' || before == now) return null;
    return now;
  }

  void _settleGroups() {
    final events = [..._queued];
    _queued.clear();
    final names = {for (final (el, _) in events) el.getAttribute('name')!};
    final seen = <web.HTMLDetailsElement>{};
    final changes = <(web.HTMLDetailsElement, bool)>[];
    void visit(web.HTMLDetailsElement el, String? old, {required bool known}) {
      if (!seen.add(el)) return;
      // A sibling this feature never saw has no state to compare with.
      if (!known && _open[el] == null) return;
      final now = _change(el, old);
      if (now != null) changes.add((el, now));
    }

    for (final (el, old) in events) {
      visit(el, old, known: true);
    }
    final all = scope.querySelectorAll('details[name]');
    for (var i = 0; i < all.length; i++) {
      final el = all.item(i)! as web.HTMLDetailsElement;
      if (names.contains(el.getAttribute('name')) &&
          _spec(el).containsKey('toggle')) {
        visit(el, null, known: false);
      }
    }
    for (final close in [false, true]) {
      for (final (el, now) in changes) {
        if (now == close) _fire(el, 'toggle', '$now');
      }
    }
  }

  /// What is already true when the engine wakes up.
  void _sync() {
    // After the other features are installed: the controller of a view has
    // taken it to its initial page by then, which is not a change.
    scheduleMicrotask(() {
      final views = scope.querySelectorAll('[$elementEventsAttr]');
      for (var i = 0; i < views.length; i++) {
        final el = views.item(i)! as web.Element;
        if (_spec(el).containsKey('page')) _page[el] ??= _pageOf(el);
      }
    });
    final hover = web.window.matchMedia('(hover: hover)').matches;
    final active = web.document.activeElement;
    final all = scope.querySelectorAll('[$elementEventsAttr]');
    for (var i = 0; i < all.length; i++) {
      final el = all.item(i)! as web.Element;
      final s = _spec(el);
      if (s.containsKey('toggle') && el.isA<web.HTMLDetailsElement>()) {
        _open[el] = (el as web.HTMLDetailsElement).open;
      }
      if (hover && s.containsKey('enter') && el.matches(':hover')) _enter(el);
      if (s.containsKey('focus') && active != null && el.contains(active)) {
        _gain(el);
      }
    }
  }
}
