/// Controllers of the page's `ThorState`s connected to their elements
/// ([ControllersFeature]) and CSS custom properties bound to state values
/// ([VariablesFeature]).
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:thor_engine/src/controllers.dart';
import 'package:thor_engine/src/navigation.dart';
import 'package:thor_engine/src/protocol.dart';
import 'package:thor_engine/src/reactive.dart';
import 'package:thor_engine/src/thor_state.dart';
import 'package:thor_engine_oracle/client.dart' show EngineFeature, EngineRun;
import 'package:web/web.dart' as web;

/// `ScrollController`, `TextEditingController`, `FocusNode`,
/// `DialogController`, `SystemNavigator` and `PageNavigator`.
///
/// Elements are looked up by the controller's id when needed, so a
/// controller follows its element when a `Watch` replaces it. Scroll
/// events don't bubble: one capturing listener on the page sees them all.
final class ControllersFeature extends EngineFeature {
  /// The feature.
  const ControllersFeature();

  @override
  void Function()? install(web.Element scope, EngineRun run) {
    final undo = <void Function()>[];
    final scrolls = <String, ScrollController>{};
    final texts = <String, TextEditingController>{};
    final focus = <String, FocusNode>{};
    final dialogs = <String, DialogController>{};
    for (final s in ThorState.all) {
      for (final m in s.members) {
        if (m.function != null) continue;
        final id = '${s.idPrefix}.${m.name}';
        switch (m.call?.call(null)) {
          case final ScrollController c:
            scrolls[id] = c;
          case final TextEditingController c:
            texts[id] = c;
          case final FocusNode c:
            focus[id] = c;
          case final DialogController c:
            dialogs[id] = c;
        }
      }
    }

    web.HTMLElement? find(String attr, String id) {
      final el = scope.querySelector('[$attr="$id"]');
      return el == null ? null : el as web.HTMLElement;
    }

    void measure(web.HTMLElement el, ScrollController c) {
      final horizontal = el.hasAttribute(horizontalScrollAttr);
      c.updatePosition(
        pixels:
            (horizontal ? el.scrollLeft : el.scrollTop).toDouble() * _sign(el),
        viewportDimension: (horizontal ? el.clientWidth : el.clientHeight)
            .toDouble(),
        maxScrollExtent: horizontal
            ? (el.scrollWidth - el.clientWidth).toDouble()
            : (el.scrollHeight - el.clientHeight).toDouble(),
      );
    }

    for (final e in scrolls.entries) {
      e.value.attachDriver(
        _ScrollDriver(
          () => find(scrollControllerAttr, e.key),
          (el) => measure(el, e.value),
        ),
      );
      final el = find(scrollControllerAttr, e.key);
      if (el != null) {
        _start(el, e.value, () => measure(el, e.value));
        measure(el, e.value);
      }
      undo.add(() => e.value.attachDriver(null));
    }
    if (scrolls.isNotEmpty) {
      final onScroll = ((web.Event e) {
        final t = e.target;
        if (t == null || !t.isA<web.HTMLElement>()) return;
        final el = t as web.HTMLElement;
        final c = scrolls[el.getAttribute(scrollControllerAttr)];
        if (c != null) measure(el, c);
      }).toJS;
      final onResize = ((web.Event _) {
        for (final e in scrolls.entries) {
          final el = find(scrollControllerAttr, e.key);
          if (el != null) measure(el, e.value);
        }
      }).toJS;
      final options = web.AddEventListenerOptions(capture: true, passive: true);
      // A part that arrived after hydration (or a copy that replaced a
      // subtree) with a view of a controller: it starts where the
      // controller says (an initial offset or page) and is measured, as the
      // views the first scan found were (`ScrollController.at` in lite).
      final onAdopted = ((web.Event e) {
        final t = e.target;
        if (t == null || !t.isA<web.Element>()) return;
        final root = t as web.Element;
        for (final el in [
          root,
          ..._elements(root, '[$scrollControllerAttr]'),
        ]) {
          final c = scrolls[el.getAttribute(scrollControllerAttr)];
          if (c == null || !el.isA<web.HTMLElement>()) continue;
          final box = el as web.HTMLElement;
          _start(box, c, () => measure(box, c));
          measure(box, c);
        }
      }).toJS;
      scope.addEventListener('scroll', onScroll, options);
      scope.addEventListener(adoptedEvent, onAdopted, true.toJS);
      web.window.addEventListener('resize', onResize);
      undo.add(() {
        scope.removeEventListener('scroll', onScroll, true.toJS);
        scope.removeEventListener(adoptedEvent, onAdopted, true.toJS);
        web.window.removeEventListener('resize', onResize);
      });
    }

    for (final e in texts.entries) {
      e.value.attachDriver(_TextDriver(scope, e.key, e.value));
      undo.add(() => e.value.attachDriver(null));
      // The server wrote the text it rendered into the field (a controller
      // is not part of the page's state JSON): start from it.
      final first = scope.querySelector('[$textControllerAttr="${e.key}"]');
      if (first != null) e.value.text = _valueOf(first);
      undo.add(
        effect(() {
          final text = e.value.text;
          final fields = scope.querySelectorAll(
            '[$textControllerAttr="${e.key}"]',
          );
          for (var i = 0; i < fields.length; i++) {
            _setValue(fields.item(i)! as web.Element, text);
          }
        }),
      );
    }
    if (texts.isNotEmpty) {
      final onInput = ((web.Event e) {
        final t = e.target;
        if (t == null || !t.isA<web.Element>()) return;
        final el = t as web.Element;
        final c = texts[el.getAttribute(textControllerAttr)];
        if (c == null) return;
        batch(() {
          c.text = _valueOf(el);
          _readSelection(el, c);
        });
      }).toJS;
      // The caret is the focused field's: a field another one's text was
      // put into moves its own caret, which is not the visitor's.
      final onCaret = ((web.Event e) {
        final t = e.target;
        if (t == null ||
            !t.isA<web.Element>() ||
            !identical(t, web.document.activeElement)) {
          return;
        }
        final el = t as web.Element;
        final c = texts[el.getAttribute(textControllerAttr)];
        if (c != null) _readSelection(el, c);
      }).toJS;
      const caretEvents = ['select', 'selectionchange', 'keyup'];
      for (final type in caretEvents) {
        scope.addEventListener(type, onCaret, true.toJS);
      }
      // Capture: the controller holds the new text before any `onChanged`.
      scope.addEventListener('input', onInput, true.toJS);
      // A copy of server markup replaced a subtree: its fields show what
      // the server rendered, not the controllers' text.
      final onAdopted = ((web.Event e) {
        final t = e.target;
        if (t == null || !t.isA<web.Element>()) return;
        final root = t as web.Element;
        for (final el in [root, ..._elements(root, '[$textControllerAttr]')]) {
          final c = texts[el.getAttribute(textControllerAttr)];
          if (c != null) _setValue(el, untracked(() => c.text));
        }
      }).toJS;
      scope.addEventListener(adoptedEvent, onAdopted, true.toJS);
      undo.add(() {
        scope.removeEventListener('input', onInput, true.toJS);
        scope.removeEventListener(adoptedEvent, onAdopted, true.toJS);
        for (final type in caretEvents) {
          scope.removeEventListener(type, onCaret, true.toJS);
        }
      });
    }

    for (final e in focus.entries) {
      e.value.attachDriver(_FocusDriver(() => find(focusNodeAttr, e.key)));
      undo.add(() => e.value.attachDriver(null));
    }
    if (focus.isNotEmpty) {
      void track(web.Event e, bool focused) {
        final t = e.target;
        if (t == null || !t.isA<web.Element>()) return;
        focus[(t as web.Element).getAttribute(focusNodeAttr)]?.updateFocus(
          focused,
        );
      }

      final onIn = ((web.Event e) => track(e, true)).toJS;
      final onOut = ((web.Event e) => track(e, false)).toJS;
      scope
        ..addEventListener('focusin', onIn)
        ..addEventListener('focusout', onOut);
      undo.add(
        () => scope
          ..removeEventListener('focusin', onIn)
          ..removeEventListener('focusout', onOut),
      );
    }

    for (final e in dialogs.entries) {
      e.value.attachDriver(
        _DialogDriver(() => find(dialogControllerAttr, e.key)),
      );
      undo.add(() => e.value.attachDriver(null));
    }
    if (dialogs.isNotEmpty) {
      // `close` and `toggle` don't bubble: capture them for every dialog.
      void track(web.Event e) {
        final t = e.target;
        if (t == null || !t.isA<web.HTMLDialogElement>()) return;
        final d = t as web.HTMLDialogElement;
        dialogs[d.getAttribute(dialogControllerAttr)]?.updateOpen(d.open);
      }

      final onChange = track.toJS;
      scope
        ..addEventListener('close', onChange, true.toJS)
        ..addEventListener('toggle', onChange, true.toJS);
      undo.add(
        () => scope
          ..removeEventListener('close', onChange, true.toJS)
          ..removeEventListener('toggle', onChange, true.toJS),
      );
    }

    // PageNavigator.go from a state method: the document's own navigation.
    PageNavigator.handler = (location, replace) => replace
        ? web.window.location.replace(location)
        : web.window.location.assign(location);
    // A hash entry (`hashchange` to another URL than the document's own)
    // is an entry of this site to go back to that neither the referrer nor
    // the state show: it is marked like a pushed one.
    final first = web.window.location.href;
    void onHash(web.Event _) {
      if (web.window.history.state.isNull &&
          web.window.location.href != first) {
        web.window.history.replaceState(_pushed, '');
      }
    }

    final onHashJs = onHash.toJS;
    web.window.addEventListener('hashchange', onHashJs);
    undo.add(() => web.window.removeEventListener('hashchange', onHashJs));
    PageNavigator.canPopHandler = _canPop;
    PageNavigator.popHandler = (fallback) {
      final can = _canPop();
      if (!can) return web.window.location.assign(fallback);
      // Without the Navigation API canPop is a guess (a first entry with a
      // forward entry looks like it has a back): when the back neither
      // leaves the document (`pagehide`) nor moves in it (`popstate`) in
      // time, the fallback loads.
      if (!_hasNavigationApi()) {
        late JSFunction done;
        late Timer timer;
        void finish(web.Event _) {
          timer.cancel();
          web.window
            ..removeEventListener('pagehide', done)
            ..removeEventListener('popstate', done);
        }

        done = finish.toJS;
        web.window
          ..addEventListener('pagehide', done)
          ..addEventListener('popstate', done);
        timer = Timer(const Duration(milliseconds: 600), () {
          finish(web.Event('timeout'));
          web.window.location.assign(fallback);
        });
      }
      web.window.history.back();
    };
    // ignore: unnecessary_lambdas, an interop member cannot be torn off.
    PageNavigator.reloadHandler = () => web.window.location.reload();
    undo.add(() {
      PageNavigator.handler = null;
      PageNavigator.canPopHandler = null;
      PageNavigator.popHandler = null;
      PageNavigator.reloadHandler = null;
    });

    SystemNavigator.handler = (uri, replace) {
      final url = uri.toString();
      if (url ==
          '${web.window.location.pathname}${web.window.location.search}') {
        return;
      }
      replace
          ? web.window.history.replaceState(web.window.history.state, '', url)
          : web.window.history.pushState(_pushed, '', url);
    };
    undo.add(() => SystemNavigator.handler = null);

    return () {
      for (final u in undo) {
        u();
      }
    };
  }
}

/// The state of a history entry the page pushed itself (the lite engine's
/// `$nav` writes the same marker).
final _pushed = 'thor'.toJS;

/// Whether the browser has the Navigation API's `canGoBack`.
bool _hasNavigationApi() {
  // (`hasProperty` first: the `isA` of an undefined `window.navigation`, a
  // browser without the API, throws.)
  final w = web.window as JSObject;
  if (!w.hasProperty('navigation'.toJS).toDart) return false;
  final nav = w['navigation'];
  return nav.isA<JSObject>() &&
      (nav! as JSObject)['canGoBack'].typeofEquals('boolean');
}

/// Whether the page can go back to an entry of its own site. The
/// Navigation API's `canGoBack` where there is one (it only knows entries of
/// this origin); else this entry was pushed by the page (or is a hash
/// entry, marked the same), or the document was reached from this origin with more
/// than one entry in the tab (a new tab opened from a link has the referrer
/// but nothing before it). The lite engine's `$canPop` does the same.
bool _canPop() {
  if (_hasNavigationApi()) {
    final nav = web.window['navigation'];
    return (nav['canGoBack']! as JSBoolean).toDart;
  }
  if (!web.window.history.state.isNull) return true;
  if (web.window.history.length <= 1) return false;
  final ref = web.document.referrer;
  final origin = web.window.location.origin;
  return ref == origin || ref.startsWith('$origin/');
}

List<web.Element> _elements(web.Element root, String selector) {
  final list = root.querySelectorAll(selector);
  return [for (var i = 0; i < list.length; i++) list.item(i)! as web.Element];
}

String _valueOf(web.Element el) => el.isA<web.HTMLTextAreaElement>()
    ? (el as web.HTMLTextAreaElement).value
    : el.isA<web.HTMLInputElement>()
    ? (el as web.HTMLInputElement).value
    : '';

void _setValue(web.Element el, String text) {
  if (el.isA<web.HTMLTextAreaElement>()) {
    final area = el as web.HTMLTextAreaElement;
    if (area.value != text) area.value = text;
  } else if (el.isA<web.HTMLInputElement>()) {
    final input = el as web.HTMLInputElement;
    if (input.value != text) input.value = text;
  }
}

/// What the field has selected, or null for a type with no selection
/// (`email`, `number`).
TextSelection? _selectionOf(web.Element el) {
  int? start, end;
  String? direction;
  if (el.isA<web.HTMLTextAreaElement>()) {
    final area = el as web.HTMLTextAreaElement;
    (start, end, direction) = (
      area.selectionStart,
      area.selectionEnd,
      area.selectionDirection,
    );
  } else if (el.isA<web.HTMLInputElement>()) {
    final input = el as web.HTMLInputElement;
    (start, end, direction) = (
      input.selectionStart,
      input.selectionEnd,
      input.selectionDirection,
    );
  }
  if (start == null || end == null) return null;
  return direction == 'backward'
      ? TextSelection(baseOffset: end, extentOffset: start)
      : TextSelection(baseOffset: start, extentOffset: end);
}

void _readSelection(web.Element el, TextEditingController c) {
  final s = _selectionOf(el);
  if (s != null) c.updateSelection(s);
}

class _TextDriver implements TextDriver {
  _TextDriver(this.scope, this.id, this.controller);

  final web.Element scope;
  final String id;
  final TextEditingController controller;

  @override
  void select() {
    final s = controller.selectionNow;
    if (!s.isValid) return;
    final fields = scope.querySelectorAll('[$textControllerAttr="$id"]');
    for (var i = 0; i < fields.length; i++) {
      final el = fields.item(i)! as web.Element;
      final direction = s.baseOffset > s.extentOffset ? 'backward' : 'none';
      try {
        if (el.isA<web.HTMLTextAreaElement>()) {
          (el as web.HTMLTextAreaElement).setSelectionRange(
            s.start,
            s.end,
            direction,
          );
        } else if (el.isA<web.HTMLInputElement>()) {
          (el as web.HTMLInputElement).setSelectionRange(
            s.start,
            s.end,
            direction,
          );
        } else {
          continue;
        }
        _readSelection(el, controller);
      } on Object {
        // A type with no selection (email, number): the value stays.
      }
    }
  }
}

/// Which way the browser counts a view's `scrollLeft`/`scrollTop`: -1 when
/// the start is at the right (a right-to-left row, or `row-reverse`, not
/// both) or at the bottom (`column-reverse`), where they go negative. Offsets
/// of a controller count from the start, like Flutter's.
int _sign(web.HTMLElement el) {
  final style = web.window.getComputedStyle(el);
  final horizontal = el.hasAttribute(horizontalScrollAttr);
  final reverse =
      style.display.endsWith('flex') &&
      style.flexDirection == (horizontal ? 'row-reverse' : 'column-reverse');
  final rtl = horizontal && style.direction == 'rtl';
  return rtl != reverse ? -1 : 1;
}

/// Takes the view to where its controller starts (its `initialScrollOffset`,
/// or `initialPage`), unless it is already scrolled (a restored position
/// wins). A view with no size yet (hidden: a closed tab, `display: none`)
/// starts when it gets one; the page it starts on is then the one it reports
/// from ([pageStartEvent]), not a change.
void _start(
  web.HTMLElement el,
  ScrollController c, [
  void Function()? measure,
]) {
  final horizontal = el.hasAttribute(horizontalScrollAttr);
  final viewport = (horizontal ? el.clientWidth : el.clientHeight).toDouble();
  if (viewport == 0) {
    _whenSized(el, () {
      final moved = _startNow(el, c);
      measure?.call();
      if (moved) el.dispatchEvent(web.CustomEvent(pageStartEvent, _bubbles));
    });
    return;
  }
  _startNow(el, c);
}

final _bubbles = web.CustomEventInit(bubbles: true);

/// Whether the view was taken to its start.
bool _startNow(web.HTMLElement el, ScrollController c) {
  final horizontal = el.hasAttribute(horizontalScrollAttr);
  final viewport = (horizontal ? el.clientWidth : el.clientHeight).toDouble();
  final at = c.takeStart(viewport);
  if (at == null || at <= 0) return false;
  if ((horizontal ? el.scrollLeft : el.scrollTop) != 0) return false;
  final px = at * _sign(el);
  horizontal ? el.scrollLeft = px : el.scrollTop = px;
  return true;
}

/// Runs [fn] the first time [el] has a size (and measures it): a hidden view
/// is not scrolled. Nothing if it leaves the page first.
void _whenSized(web.HTMLElement el, void Function() fn) {
  late final web.ResizeObserver observer;
  observer = web.ResizeObserver(
    ((JSArray<web.ResizeObserverEntry> _, web.ResizeObserver _) {
      if (!el.isConnected) return observer.disconnect();
      if (el.clientWidth == 0 && el.clientHeight == 0) return;
      observer.disconnect();
      fn();
    }).toJS,
  );
  observer.observe(el);
}

class _ScrollDriver implements ScrollDriver {
  _ScrollDriver(this.element, this.measure);

  final web.HTMLElement? Function() element;
  final void Function(web.HTMLElement el) measure;

  @override
  bool get hasView => element() != null;

  @override
  void jumpTo(double offset) {
    _stop?.call(false);
    final el = element();
    if (el == null) return;
    final px = offset * _sign(el);
    el.hasAttribute(horizontalScrollAttr)
        ? el.scrollLeft = px
        : el.scrollTop = px;
    // Where it really is (the browser clamps, a hidden view had no size),
    // without waiting for the scroll event.
    measure(el);
  }

  // Ends the scroll that is running (the future completes), if any.
  void Function(bool finish)? _stop;

  static const _inputs = ['wheel', 'touchstart', 'pointerdown', 'keydown'];

  /// An instant scroll of [el] to [v] (px along its axis from its start).
  static void _put(web.HTMLElement el, double v) {
    final px = v * _sign(el);
    el.scrollTo(
      el.hasAttribute(horizontalScrollAttr)
          ? web.ScrollToOptions(left: px, behavior: 'instant')
          : web.ScrollToOptions(top: px, behavior: 'instant'),
    );
  }

  static double _at(web.HTMLElement el) =>
      (el.hasAttribute(horizontalScrollAttr) ? el.scrollLeft : el.scrollTop) *
      _sign(el);

  static double _room(web.HTMLElement el) =>
      (el.hasAttribute(horizontalScrollAttr)
              ? el.scrollWidth - el.clientWidth
              : el.scrollHeight - el.clientHeight)
          .toDouble();

  // The scroll is a frame loop (the browser has no animation of an offset):
  // the easing is evaluated by the browser, from an animation paused at
  // each frame's time; the snap points are off while it runs; the visitor's
  // wheel, touch, pointer or key (or anything else that moves the view, or
  // takes it out of the page) ends it where it is.
  @override
  Future<void> animateTo(double offset, Duration duration, String? easing) {
    _stop?.call(false);
    final el = element();
    final ms = duration.inMicroseconds / 1000;
    final to = el == null ? offset : offset.clamp(0.0, _room(el)).toDouble();
    final from = el == null ? 0.0 : _at(el);
    final reduced = web.window
        .matchMedia('(prefers-reduced-motion: reduce)')
        .matches;
    // (`!(… >= 1)`: NaN jumps too.)
    if (el == null || reduced || ms <= 0 || !((from - to).abs() >= 1)) {
      jumpTo(to);
      return Future.value();
    }
    final done = Completer<void>();
    final snap = el.style.scrollSnapType;
    el.style.scrollSnapType = 'none';
    final clock = web.Animation(
      web.KeyframeEffect(
        null,
        null,
        web.KeyframeAnimationOptions(
          duration: ms.toJS,
          easing: easing ?? 'linear',
          fill: 'both',
        ),
      ),
    )..pause();
    var last = from;
    int? frameId;
    Timer? fallback;
    late final JSFunction onInput;
    void end(bool finish) {
      if (done.isCompleted) return;
      if (frameId != null) web.window.cancelAnimationFrame(frameId!);
      fallback?.cancel();
      for (final t in _inputs) {
        el.removeEventListener(t, onInput);
      }
      clock.cancel();
      el.style.scrollSnapType = snap;
      (el as JSObject)['thorMoving'] = false.toJS;
      _stop = null;
      if (finish) _put(el, to);
      measure(el);
      // The jumps' own `scrollend`s were not reported (a PageView waits for
      // the end of the run): this one is.
      el.dispatchEvent(web.Event('scrollend'));
      done.complete();
    }

    onInput = ((web.Event _) => end(false)).toJS;
    final options = web.AddEventListenerOptions(passive: true);
    for (final t in _inputs) {
      el.addEventListener(t, onInput, options);
    }
    _stop = end;
    // Every frame's jump ends its own scroll (`scrollend`): the PageView
    // reports the page when the whole run is over.
    (el as JSObject)['thorMoving'] = true.toJS;
    // A hidden tab runs no frames: the scroll still ends.
    fallback = Timer(
      Duration(milliseconds: (ms + 1000).round()),
      () => end(true),
    );
    final t0 = web.window.performance.now();
    void frame(double now) {
      if (done.isCompleted) return;
      if (!el.isConnected || (_at(el) - last).abs() > 2) return end(false);
      clock.currentTime = math.min(now - t0, ms).toJS;
      final p = clock.effect!.getComputedTiming().progress ?? 1;
      last = (from + (to - from) * p).clamp(0.0, _room(el)).toDouble();
      _put(el, last);
      if (now - t0 >= ms) return end(true);
      frameId = web.window.requestAnimationFrame(frame.toJS);
    }

    frameId = web.window.requestAnimationFrame(frame.toJS);
    return done.future;
  }
}

class _FocusDriver implements FocusDriver {
  _FocusDriver(this.element);

  final web.HTMLElement? Function() element;

  @override
  void requestFocus() {
    final el = element();
    if (el == null) return;
    el.focus(web.FocusOptions(preventScroll: true));
    el.scrollIntoView(
      web.ScrollIntoViewOptions(block: 'nearest', inline: 'nearest'),
    );
  }

  @override
  void unfocus() {
    final el = element();
    if (el != null && identical(web.document.activeElement, el)) el.blur();
  }
}

class _DialogDriver implements DialogDriver {
  _DialogDriver(this.element);

  final web.HTMLElement? Function() element;

  web.HTMLDialogElement? get _dialog {
    final el = element();
    return el != null && el.isA<web.HTMLDialogElement>()
        ? el as web.HTMLDialogElement
        : null;
  }

  @override
  void open() {
    final d = _dialog;
    if (d != null && !d.open) d.showModal();
  }

  @override
  void close() {
    final d = _dialog;
    if (d != null && d.open) d.close();
  }
}

/// `WatchVariables` and `WatchAttributes`: CSS custom properties (pixels)
/// and HTML attributes whose values come from state methods. The server
/// wrote the first values into each element; an effect per binding (name and
/// id) keeps them current, however many elements carry it.
///
/// What the page gains afterwards (a late part, a copy put in place of a
/// subtree, a row cloned from a template) is found by one observer of the
/// scope and joins the same effects; a binding with no element left in the
/// page is released (when its signal changes, or in a sweep once there are
/// many), so a list that swaps rows keeps no binding of the ones that left.
final class VariablesFeature extends EngineFeature {
  /// The feature.
  const VariablesFeature();

  @override
  void Function()? install(web.Element scope, EngineRun run) {
    final members = <String, ThorMember>{
      for (final s in ThorState.all)
        for (final m in s.members) '${s.idPrefix}.${m.name}': m,
    };
    // (is an attribute, name, binding id) → what keeps it current.
    final bound = <(bool, String, String), _VariableBinding>{};
    var cap = 256;

    // The bindings of rows that left while their signal did not change again.
    void sweep() {
      for (final key in bound.keys.toList()) {
        final b = bound[key]!;
        b.els.removeWhere((el) => !el.isConnected);
        if (b.els.isEmpty) bound.remove(key)?.stop();
      }
      cap = math.max(256, 2 * bound.length);
    }

    void add(web.HTMLElement el, bool attribute, String name, String id) {
      final key = (attribute, name, id);
      final found = bound[key];
      if (found != null) {
        if (!found.els.contains(el)) {
          found.els.add(el);
          if (found.hasValue) found.write(el, found.value);
        }
        return;
      }
      final (memberName, arg) = parseBindingId(id);
      final member = members[memberName];
      if (member?.call == null) return;
      if (!attribute && !isCssVariableName(name)) return;
      final b = _VariableBinding(attribute, name, [el]);
      bound[key] = b;
      b.stop = effect(() {
        b.els.removeWhere((x) => !x.isConnected);
        if (b.els.isEmpty) {
          // Nothing to write to: it reads nothing, so nothing wakes it again.
          if (identical(bound[key], b)) bound.remove(key);
          return;
        }
        try {
          b.value = member!.call!(arg);
          b.hasValue = true;
        } catch (error, stack) {
          // Reported, and the pair stays: it keeps what the server wrote and
          // is not made again each time its element is put in the page.
          Zone.current.handleUncaughtError(error, stack);
          return;
        }
        for (final x in b.els) {
          b.write(x, b.value);
        }
      });
      if (bound.length > cap) sweep();
    }

    void bind(web.Element root) {
      const selector = '[$variablesAttr],[$attributesAttr]';
      final marked = [
        if (root.matches(selector)) root,
        ..._nodeElements(root.querySelectorAll(selector)),
      ];
      for (final el in marked) {
        try {
          if (el.getAttribute(variablesAttr) case final vars?) {
            for (final (property, id) in decodeVariables(vars)) {
              add(el as web.HTMLElement, false, property, id);
            }
          }
          if (el.getAttribute(attributesAttr) case final attrs?) {
            for (final e in decodeOn(attrs).entries) {
              add(el as web.HTMLElement, true, e.key, e.value);
            }
          }
        } catch (error, stack) {
          // One binding's failure must not stop the others.
          Zone.current.handleUncaughtError(error, stack);
        }
      }
    }

    bind(scope);
    final observer = web.MutationObserver(
      ((JSArray<web.MutationRecord> records, web.MutationObserver _) {
        for (final record in records.toDart) {
          for (final n in _nodeElements(record.addedNodes)) {
            if (n.isConnected) bind(n);
          }
        }
      }).toJS,
    );
    observer.observe(
      scope,
      web.MutationObserverInit(childList: true, subtree: true),
    );
    return () {
      observer.disconnect();
      for (final b in bound.values) {
        b.stop();
      }
      bound.clear();
    };
  }
}

// The elements in [list].
Iterable<web.Element> _nodeElements(web.NodeList list) sync* {
  for (var i = 0; i < list.length; i++) {
    final n = list.item(i)!;
    if (n.isA<web.Element>()) yield n as web.Element;
  }
}

/// The effect of one (name, binding id) of [VariablesFeature] and the
/// elements it writes to.
final class _VariableBinding {
  _VariableBinding(this.attribute, this.name, this.els);

  final bool attribute;
  final String name;
  final List<web.HTMLElement> els;

  /// The last value the method returned (when [hasValue]).
  Object? value;

  /// Whether the method has returned: until then there is nothing to write.
  bool hasValue = false;

  /// Ends the effect.
  void Function() stop = () {};

  void write(web.HTMLElement el, Object? v) {
    if (attribute) return writeBoundAttribute(el, name, '${v ?? ''}');
    final px = cssPxValue(v is num ? v : 0);
    if (el.style.getPropertyValue(name) != px) el.style.setProperty(name, px);
  }
}

/// Writes a bound attribute (`row.attribute`, `WatchAttributes`) through
/// [safeAttributeValue]: an unsafe URL, or a name a binding may not write,
/// removes it. A custom property name (`--x`, a row's `row.length`) writes
/// a number of pixels into the element's `style` (a `row.color` one,
/// `--tr-color-…`, a color: [safeCssColor]).
///
/// `// web:` an `<input>`, `<textarea>` or `<select>` the user already touched
/// ignores its `value` attribute (and a checkbox its `checked` one), so the
/// property is written too, when it differs: a bound value moves a control the
/// user edited.
void writeBoundAttribute(web.Element el, String name, String value) {
  if (name.startsWith('--')) {
    if (!isCssVariableName(name)) return;
    final style = (el as web.HTMLElement).style;
    if (name.startsWith(rowColorPrefix)) {
      final color = safeCssColor(value);
      if (color == null) {
        style.removeProperty(name);
      } else if (style.getPropertyValue(name) != color) {
        style.setProperty(name, color);
      }
      return;
    }
    final px = cssPxValue(num.tryParse(value) ?? 0);
    if (style.getPropertyValue(name) != px) style.setProperty(name, px);
    return;
  }
  final safe = safeAttributeValue(name, value);
  // A <textarea> keeps its text as content, a <select> and a radio group (a
  // SegmentedButton) their chosen option or radio: `value` is only the
  // property, never an attribute of theirs.
  if (name == 'value' &&
      (el.isA<web.HTMLTextAreaElement>() ||
          el.isA<web.HTMLSelectElement>() ||
          el.getAttribute('role') == 'radiogroup')) {
    _syncProperty(el, name, safe);
    return;
  }
  if (safe == null) {
    if (el.hasAttribute(name)) el.removeAttribute(name);
  } else if (el.getAttribute(name) != safe) {
    el.setAttribute(name, safe);
  }
  _syncProperty(el, name, safe);
}

// The property behind a written attribute [name] ([safe]: its value, or null
// when it was removed), when the element keeps one of its own once touched.
void _syncProperty(web.Element el, String name, String? safe) {
  if (name == 'value') {
    final v = safe ?? '';
    if (el.isA<web.HTMLInputElement>()) {
      final input = el as web.HTMLInputElement;
      if (input.type != 'file' && input.value != v) input.value = v;
    } else if (el.isA<web.HTMLTextAreaElement>()) {
      final area = el as web.HTMLTextAreaElement;
      if (area.value != v) area.value = v;
    } else if (el.isA<web.HTMLSelectElement>()) {
      final select = el as web.HTMLSelectElement;
      if (select.value != v) select.value = v;
    } else if (el.getAttribute('role') == 'radiogroup') {
      // A group of radios (a SegmentedButton) takes the value of the one
      // that is on.
      final radios = el.querySelectorAll('input[type=radio]');
      for (var i = 0; i < radios.length; i++) {
        final radio = radios.item(i) as web.HTMLInputElement;
        final on = radio.value == v;
        if (radio.checked != on) radio.checked = on;
      }
    }
  } else if (name == 'checked' && el.isA<web.HTMLInputElement>()) {
    final input = el as web.HTMLInputElement;
    if (input.checked != (safe != null)) input.checked = safe != null;
  }
}
