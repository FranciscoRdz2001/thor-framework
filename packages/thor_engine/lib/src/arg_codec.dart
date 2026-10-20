import 'dart:convert';

/// How a query's or a command's argument becomes JSON and back, when it is
/// not a simple value (see `ServerQuery.members`,
/// `ServerCommandBase.members`). Internal: not exported.
final class ArgCodec<A> {
  /// A class's or record's JSON writer (the builder's `argToJson`).
  Object? Function(A arg)? toJson;

  /// A class's or record's JSON reader (the builder's `argFromJson`).
  A Function(Map<String, Object?> json)? fromJson;

  /// The JSON of [arg]: what the builder says, else the value itself for a
  /// simple one, else its own `toJson()`.
  Object? encode(A arg) {
    if (toJson case final f?) return f(arg);
    return switch (arg) {
      null || num() || String() || bool() || List() || Map() => arg,
      // A unit test's class with `toJson()`, with no builder around.
      // ignore: avoid_dynamic_calls
      _ => (arg as dynamic).toJson(),
    };
  }

  /// [json] as an [A] (the signal's restore from the page's state).
  A decode(Object? json) {
    if (json is A) return json;
    if (json is Map && fromJson != null) {
      return fromJson!(Map<String, Object?>.from(json));
    }
    throw ArgumentError.value(json, 'arg', 'not a $A');
  }

  /// The argument a call from the page brings as JSON, as an [A]: throws
  /// [ArgumentError] when [json] is not one (a class is decoded with the
  /// app's `fromJson`; a bad shape is a bad request, whatever it throws).
  A argFrom(Object? json, {required bool hasArg}) {
    if (!hasArg) return null as A;
    if (json is int && <double>[] is List<A>) return json.toDouble() as A;
    if (json is A) return json;
    if (json is Map) {
      final decode = fromJson;
      if (decode != null) {
        try {
          final value = decode(Map<String, Object?>.from(json));
          // A `cast<T>()` in the app's `fromJson` is lazy: writing the value
          // back forces it, so a wrong element type fails here, as a bad
          // request, and not later inside the function.
          jsonEncode(encode(value));
          return value;
          // The app's `fromJson` on a shape the browser (or anyone) made up:
          // whatever it throws, the call is a bad request.
          // ignore: avoid_catches_without_on_clauses
        } catch (_) {
          throw ArgumentError.value(json, 'arg', 'not a $A');
        }
      }
    }
    throw ArgumentError.value(json, 'arg', 'not a $A');
  }
}
