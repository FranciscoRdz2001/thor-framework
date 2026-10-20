/// Reading a property of a row without a method per property:
/// `row.text((o) => o.customer)`.
///
/// The server calls the lambda with a probe of the row's class: an object
/// that answers each `String` property with a marker naming it and counts
/// the reads. A lambda that read exactly one property and returned it as it
/// came is a property path, and the page binds it (`data-tf="$Rows.customer"`)
/// so the browser reads the same property of each item. Anything else is
/// a method's work (THOR-S033). The build (`thor_builder`) writes the probes
/// into `.dart_tool/thor/states.dart`; an app never does.
library;

/// What a probe saw while a lambda ran over it.
final class RowProbeLog {
  /// The last property read (`customer`), or null.
  String? property;

  /// How many reads the lambda made.
  int reads = 0;

  /// Which value of a finite property (a `bool`, an enum) the probe answers:
  /// the [pick]th of its values (the last one when it has fewer).
  int pick = 0;

  /// The values of the finite property last read through [choose].
  List<Object?>? values;

  /// Notes that [name] was read.
  void read(String name) {
    property = name;
    reads++;
  }

  /// What a probe answers for the `bool` or enum property [name], whose
  /// possible [all] values are in order: the [pick]th one. A lambda that
  /// returns it unchanged for two picks is a property path too
  /// ([statesOfRowLambda]).
  Object? choose(String name, List<Object?> all) {
    read(name);
    values = all;
    return all[pick < all.length ? pick : all.length - 1];
  }

  /// What a probe answers for `String` property [name].
  static String marker(String name) => '\u0000thor:$name';

  /// What a probe answers for an `int` (or `num`) property: a number no row
  /// has, whose text (`'${o.id}'`, `o.id.toString()`) the lambda returns.
  static const int intMarker = 4503599627370495;

  /// What a probe answers for a `double` property.
  static const double doubleMarker = 4503599627370495.5;

  /// Whether the property last read is a number ([integer], [decimal]).
  bool numeric = false;

  /// What a probe answers for the `int` property [name] ([intMarker]); the
  /// lambda must turn it into text, so `row.text((o) => '${o.id}')` reads
  /// `id`.
  int integer(String name) {
    read(name);
    numeric = true;
    return intMarker;
  }

  /// What a probe answers for the `double` property [name]
  /// ([doubleMarker]).
  double decimal(String name) {
    read(name);
    numeric = true;
    return doubleMarker;
  }
}

/// Makes a probe of a row class that reports into [log].
typedef RowProbeFactory = Object Function(RowProbeLog log);

var _probes = <Type, RowProbeFactory>{};

/// Installs the probes of the app's row classes: what the generated
/// `registerThorStates()` calls.
void registerRowProbes(Map<Type, RowProbeFactory> probes) {
  _probes = {..._probes, ...probes};
}

/// Whether a probe of [item] is registered.
bool hasRowProbe(Type item) => _probes.containsKey(item);

/// The property [lambda] reads over a row of class [item] and returns
/// unchanged, or null when it is anything else (a call, a second read, a
/// property that is not a `String`) or [item] has no probe.
String? propertyOfRowLambda(Type item, Function lambda) {
  final make = _probes[item];
  if (make == null) return null;
  final log = RowProbeLog();
  try {
    final result = Function.apply(lambda, [make(log)]);
    final name = log.property;
    if (name != null && log.reads == 1 && result == RowProbeLog.marker(name)) {
      return name;
    }
    // `'${o.id}'` / `o.id.toString()` over an `int` or `double` property:
    // the lambda returned the text of the number the probe gave.
    if (name != null &&
        log.reads == 1 &&
        log.numeric &&
        (result == '${RowProbeLog.intMarker}' ||
            result == '${RowProbeLog.doubleMarker}')) {
      return name;
    }
    // The same over a `bool` property: the text of each of its two values.
    final all = log.values;
    if (name != null && log.reads == 1 && all != null && _isBoolPair(all)) {
      if (result != '${all[0]}') return null;
      final second = RowProbeLog()..pick = 1;
      final other = Function.apply(lambda, [make(second)]);
      if (second.reads == 1 &&
          second.property == name &&
          other == '${all[1]}') {
        return name;
      }
    }
    // A lambda that threw is not a property path either (the probe answers
    // only `String` properties): everything else falls to the caller's error.
    // ignore: avoid_catches_without_on_clauses
  } catch (_) {}
  return null;
}

/// The `bool` or enum property [lambda] reads over a row of class [item] and
/// returns unchanged (`(o) => o.isOffer`), with its values in order, or null
/// when it is anything else (a comparison, a negation, a `String`) or [item]
/// has no probe. Two probes answer different values: a lambda that only
/// returns what it read follows them both.
({String property, List<Object?> values})? statesOfRowLambda(
  Type item,
  Function lambda,
) {
  final make = _probes[item];
  if (make == null) return null;
  String? property;
  List<Object?>? values;
  for (var pick = 0; pick < 2; pick++) {
    final log = RowProbeLog()..pick = pick;
    try {
      final result = Function.apply(lambda, [make(log)]);
      final all = log.values;
      final name = log.property;
      if (name == null ||
          all == null ||
          all.length < 2 ||
          log.reads != 1 ||
          (property != null && property != name) ||
          result != all[pick]) {
        return null;
      }
      property = name;
      values = all;
      // A lambda that threw is not a property path either.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return null;
    }
  }
  return (property: property!, values: values!);
}

bool _isBoolPair(List<Object?> values) =>
    values.length == 2 && values[0] == false && values[1] == true;
