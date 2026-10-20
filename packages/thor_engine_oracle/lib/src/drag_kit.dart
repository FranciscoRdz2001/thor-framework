/// What thor_ui's `Draggable` / `DragTarget` and `ReorderableListView` share
/// (the lite engine's `parts/drag_kit.js` is the same): the live region that
/// says what a keyboard drag does, the page scrolling while the pointer is
/// near an edge, and the escaping of a part of a multi-argument value.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

web.HTMLElement? _live;
int? _said;

/// Says [text] to assistive technology: a visually hidden assertive live
/// region the first call creates (each step of a keyboard drag replaces the
/// one before). The same words twice are read twice.
void say(String text) {
  var live = _live;
  if (live == null || !live.isConnected) {
    live = web.document.createElement('div') as web.HTMLElement
      ..setAttribute('aria-live', 'assertive')
      ..setAttribute('aria-atomic', 'true');
    live.style.cssText =
        'position:fixed;width:1px;height:1px;margin:-1px;padding:0;'
        'overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap;border:0';
    web.document.body!.append(live);
    _live = live;
  }
  live.textContent = '';
  final pending = _said;
  if (pending != null) web.window.clearTimeout(pending);
  _said = web.window.setTimeout((() => live!.textContent = text).toJS, 30.toJS);
}

/// The name of [el] for a screen reader: its label, or its text.
String nameOf(web.Element el) {
  final label = el.getAttribute('aria-label');
  final text = label != null && label.isNotEmpty
      ? label
      : _collapse(el.textContent ?? '');
  return text.length > 80 ? text.substring(0, 80) : text;
}

// Runs of white space as one space, trimmed (by hand: a RegExp would bring
// the regular-expression support into every engine with a drag).
String _collapse(String s) {
  final out = StringBuffer();
  var gap = false;
  for (final c in s.codeUnits) {
    if (c == 0x20 || c == 0x0A || c == 0x09 || c == 0x0D || c == 0xA0) {
      gap = out.isNotEmpty;
    } else {
      if (gap) out.write(' ');
      gap = false;
      out.writeCharCode(c);
    }
  }
  return '$out';
}

/// [text] with `{item}` and `{target}` replaced.
String fill(String text, [String item = '', String target = '']) =>
    text.replaceAll('{item}', item).replaceAll('{target}', target);

/// The words of [el]: its `data-t-dg-say` (a line each) over [fallback].
List<String> words(web.Element el, String attribute, List<String> fallback) {
  final mine = el.getAttribute(attribute);
  return mine == null ? fallback : mine.split('\n');
}

/// A part of a multi-argument value (`<fixed>~<part>~…`) with `%` and `~`
/// escaped.
String esc(String s) => s.replaceAll('%', '%25').replaceAll('~', '%7E');

/// "Reduce motion" is on.
bool calm() =>
    web.window.matchMedia('(prefers-reduced-motion: reduce)').matches;

/// [v] to a tenth of a pixel, without trailing zeros.
String fmt(double v) {
  final r = (v * 10).round() / 10;
  return r == r.roundToDouble() ? '${r.round()}' : '$r';
}

const _edge = 56.0, _max = 18.0;

bool _scrolls(web.Element el, bool horizontal) {
  final cs = web.window.getComputedStyle(el);
  final overflow = horizontal ? cs.overflowX : cs.overflowY;
  if (!overflow.contains('auto') && !overflow.contains('scroll')) return false;
  return horizontal
      ? el.scrollWidth > el.clientWidth
      : el.scrollHeight > el.clientHeight;
}

// How far to go along one axis for a pointer at [p] in [lo]..[hi].
int _speed(double p, double lo, double hi) => p < lo + _edge
    ? -(_max * (lo + _edge - p) / _edge).ceil()
    : p > hi - _edge
    ? (_max * (p - (hi - _edge)) / _edge).ceil()
    : 0;

/// Scrolls the container under the pointer (the nearest one that can scroll
/// that way) or the page while the pointer is within a few pixels of its
/// edge. [where] gives the pointer's `(x, y)`; the result stops it.
void Function() autoscroll((double, double) Function() where) {
  var on = true;
  int? frame;
  void step() {
    if (!on) return;
    final (x, y) = where();
    var moved = false;
    for (
      var el = web.document.elementFromPoint(x, y);
      el != null &&
          !moved &&
          el != web.document.body &&
          el != web.document.documentElement;
      el = el.parentElement
    ) {
      final r = el.getBoundingClientRect();
      for (final h in const [false, true]) {
        if (!_scrolls(el, h)) continue;
        final v = h ? _speed(x, r.left, r.right) : _speed(y, r.top, r.bottom);
        if (v == 0) continue;
        final before = h ? el.scrollLeft : el.scrollTop;
        if (h) {
          el.scrollLeft = before + v;
        } else {
          el.scrollTop = before + v;
        }
        if ((h ? el.scrollLeft : el.scrollTop) != before) moved = true;
      }
    }
    if (!moved) {
      final root = web.document.documentElement!;
      final v = _speed(y, 0, root.clientHeight.toDouble());
      final h = _speed(x, 0, root.clientWidth.toDouble());
      if (v != 0 || h != 0) web.window.scrollBy(h.toJS, v);
    }
    frame = web.window.requestAnimationFrame(((num _) => step()).toJS);
  }

  frame = web.window.requestAnimationFrame(((num _) => step()).toJS);
  return () {
    on = false;
    final f = frame;
    if (f != null) web.window.cancelAnimationFrame(f);
  };
}

/// The browser's `parseFloat`: Dart's `double.tryParse` would pull a regular
/// expression engine into the bundle.
double? parseNumber(String s) {
  final n = globalContext.callMethod<JSNumber>('parseFloat'.toJS, s.toJS);
  final v = n.toDartDouble;
  return v.isNaN ? null : v;
}
