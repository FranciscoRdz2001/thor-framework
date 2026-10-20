import 'dart:math' show Random;

import 'package:thor_engine/thor_engine.dart'
    show
        decodeOn,
        encodeOn,
        isBindableAttribute,
        rowAttributesAttr,
        safeAttributeValue;

import 'errors.dart';

// web: Flutter has no per-row attributes. `row.bind(state.titleOf)` returns
// a `String` so it fits the widget parameters Flutter types as `String`
// (`semanticLabel:`, `tooltip:`, `Semantics(label:)`, `alt`…): the String
// carries the binding, and the element that finally writes that parameter
// as an attribute (`thorElement`) turns it into the row's bound attribute
// (`data-tfa`) with the row's value, the same markup as `row.attribute`.
//
// The marker: U+E000 (a private-use character no text has), a per-process
// random tag (so text that comes from a user and holds U+E000 can never pass
// for a marker), the binding id, U+E001, the row's value (empty in the row
// template) and U+E002 at the end (so a `'${row.bind(…)}!'` is noticed). Only
// a value that holds U+E000 is looked at, so an element with no bound
// attribute pays one scan per attribute.
const _open = '\uE000';
const _sep = '\uE001';
const _end = '\uE002';
final String _prefix = '${_open}rb${_tag()}';
final String _lowerPrefix = _prefix.toLowerCase();

String _tag() {
  final random = Random.secure();
  return [
    for (var i = 0; i < 8; i++)
      random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

/// The String `row.bind` returns: [value] (the row's, empty in the row
/// template) tagged with the binding [id].
String rowBindMarker(String id, String value) => '$_prefix$id$_sep$value$_end';

/// Whether [value] is a [rowBindMarker], whole.
bool isRowBindMarker(String value) =>
    value.startsWith(_prefix) &&
    value.endsWith(_end) &&
    value.indexOf(_sep, _prefix.length) > _prefix.length;

bool _anyOpen(Iterable<String> values) {
  for (final v in values) {
    if (v.contains(_open)) return true;
  }
  return false;
}

/// THOR-S036 if [text] holds a [rowBindMarker] (whole, cut or changed by
/// `toUpperCase`, `'x' + …`, an interpolation): `row.bind` gives a `String`
/// for an attribute, not one to show or compute on. [where] says where it
/// ended up. Text with U+E000 that is not one (user data) passes.
void checkNoRowBindMarker(String text, String where) {
  if (!text.contains(_open)) return;
  if (!text.toLowerCase().contains(_lowerPrefix)) return;
  throw StateError(
    thorError(
      'THOR-S036',
      'row.bind(…) ended up $where, where the browser cannot keep it '
          'current: it is a String for a widget parameter that becomes an '
          'attribute (`semanticLabel:`, `tooltip:`, `Semantics(label:)`), '
          'not one to show or to compute on (`Text(row.bind(…))`, '
          '`\'x \${row.bind(…)}\'`, `.toUpperCase()`). Fix: for a visible '
          'text `row.text(…)`; for a computed label a method of the state '
          'that returns it (`row.bind(todos.labelOf)`).',
    ),
  );
}

/// [attributes] with every [rowBindMarker] value turned into its row
/// binding: the attribute gets the row's value (sanitized like
/// `row.attribute`'s) and `data-tfa` names the field that keeps it current.
/// The same map when none has one (the usual case).
///
/// A marker on an attribute a binding may not write (`on*`, `style`,
/// `class`, the engine's own) is THOR-S035: the browser would never fill it.
Map<String, String> bindRowMarkers(Map<String, String> attributes) {
  // Every element of every page comes through here, almost never with a
  // marker: without U+E000 there is none, whole or cut, to bind or report.
  if (!_anyOpen(attributes.values)) return attributes;
  Map<String, String>? out;
  Map<String, String>? bound;
  for (final MapEntry(:key, :value) in attributes.entries) {
    if (!isRowBindMarker(value)) {
      checkNoRowBindMarker(value, 'in the attribute `$key`');
      continue;
    }
    if (!isBindableAttribute(key)) {
      throw ArgumentError(
        thorError(
          'THOR-S035',
          'row.bind(…) ended up in the attribute `$key`, which a row '
              'binding may not write (aria-*, data-*, and plain attributes '
              'like alt, title, href, value; never on*, style or class). '
              'Use it for a widget parameter that becomes one of those '
              '(`semanticLabel:`, `tooltip:`, `Semantics(label:)`); for a '
              'text, `row.text(…)`.',
        ),
      );
    }
    final at = value.indexOf(_sep, _prefix.length);
    final id = value.substring(_prefix.length, at);
    final shown = safeAttributeValue(
      key,
      value.substring(at + 1, value.length - 1),
    );
    out ??= {...attributes};
    shown == null ? out.remove(key) : out[key] = shown;
    (bound ??= {})[key] = id;
  }
  if (out == null) return attributes;
  final previous = out[rowAttributesAttr];
  out[rowAttributesAttr] = encodeOn({
    ...?previous == null ? null : decodeOn(previous),
    ...bound!,
  });
  return out;
}
