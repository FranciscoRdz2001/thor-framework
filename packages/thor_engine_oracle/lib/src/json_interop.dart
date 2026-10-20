/// JSON data between JS and Dart for the dart2js engine, hand-written:
/// `dartify()` / `jsify()` pull in far more code than a page's JSON needs.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// JSON value (from `JSON.parse`) → Dart maps, lists, strings, numbers and
/// bools.
Object? jsonToDart(JSAny? v) {
  if (v == null) return null;
  if (v.typeofEquals('string')) return (v as JSString).toDart;
  if (v.typeofEquals('number')) return (v as JSNumber).toDartDouble;
  if (v.typeofEquals('boolean')) return (v as JSBoolean).toDart;
  if (v.isA<JSArray>()) {
    return [for (final e in (v as JSArray<JSAny?>).toDart) jsonToDart(e)];
  }
  final o = v as JSObject;
  final keys = (globalContext['Object']! as JSObject)
      .callMethod<JSArray<JSString>>('keys'.toJS, o)
      .toDart;
  return {for (final k in keys) k.toDart: jsonToDart(o[k.toDart])};
}

/// JSON data (maps with String keys, lists, strings, numbers, bools, null)
/// → the JS value `JSON.stringify` takes.
JSAny? dartToJson(Object? v) => switch (v) {
  null => null,
  final String s => s.toJS,
  final num n => n.toJS,
  final bool b => b.toJS,
  final List<Object?> l => [for (final e in l) dartToJson(e)].toJS,
  final Map<Object?, Object?> m => () {
    final o = JSObject();
    for (final MapEntry(:key, :value) in m.entries) {
      o['$key'] = dartToJson(value);
    }
    return o;
  }(),
  _ => throw ArgumentError.value(v, 'value', 'not JSON data'),
};
