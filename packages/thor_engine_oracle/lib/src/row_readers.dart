/// The readers behind `row.text((o) => o.customer)` (and `row.bind`,
/// `row.attribute`, `row.field` over a lambda, and `row.watch` over a `bool`
/// or enum property) for the dart2js engine.
///
/// The server draws a row by running the lambda and writes the field's id as
/// `$Rows.customer`; the browser cannot run the lambda, so the build finds the
/// ones that only read one `String` property and passes the engine a reader
/// per property name (the lite bundle defines the same, `thor.def('$Rows')`).
library;

import 'package:thor_engine/src/protocol.dart' show rowFieldsState;
import 'package:thor_engine/src/thor_state.dart';

/// The state whose members read one property of a list item each.
///
/// Not an app's state: `thor_builder`'s engine entry makes one with the
/// properties the app's row lambdas read.
final class RowReaders extends ThorState {
  /// Reads each property of [readers] with its function (`(it) =>
  /// (it as dynamic).customer`).
  RowReaders(this.readers, {this.states = const {}});

  /// Property name → how to read it from an item.
  final Map<String, Object? Function(Object? item)> readers;

  /// The properties that are finite states (`row.watch((o) => o.isOffer)`):
  /// name → how many states (2 for a `bool`, one per value of an enum). The
  /// reader gives the `bool` or the enum value; the member answers its index.
  final Map<String, int> states;

  @override
  String get $type => rowFieldsState;

  @override
  List<ThorMember> get $members => [
    for (final MapEntry(key: name, value: read) in readers.entries)
      if (states[name] case final count?)
        ThorMember(
          name,
          read,
          arity: 1,
          callWithItem: (item) => _index(read(item)),
          variants: List<Object?>.generate(count, (i) => i),
        )
      else
        ThorMember(name, read, arity: 1, callWithItem: read),
  ];

  static int _index(Object? value) =>
      value is bool ? (value ? 1 : 0) : (value! as Enum).index;
}
