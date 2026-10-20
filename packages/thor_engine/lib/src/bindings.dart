/// What a page declares as dynamic. Everything else is static HTML that the
/// client never builds.
///
/// A binding has an explicit, stable `id`: the server writes it into the
/// markup and the client finds the node by it. That is the whole contract
/// between them — see `protocol.dart`.
library;

import 'reactive.dart';

/// A dynamic piece of a page, identified by [id].
sealed class Binding {
  const Binding(this.id);

  /// Unique on the page. Letters, digits, `-` and `_`.
  final String id;
}

/// A text computed from signals (`Text('Total: ${cart.value.total}')`).
final class TextBinding extends Binding {
  /// Binds the element's text to [text].
  const TextBinding(super.id, this.text);

  /// The current text, tracked.
  final String Function() text;
}

/// One of [count] precompiled variants of a subtree (selected / unselected,
/// pressed / idle…). The server renders every variant; the client only
/// copies classes, attributes and texts from the chosen one — zero style
/// work at runtime.
final class VariantBinding extends Binding {
  /// Binds the element to one of [count] precompiled variants, selected by
  /// [index].
  const VariantBinding(super.id, {required this.count, required this.index});

  /// Total number of precompiled variants.
  final int count;

  /// Index of the current variant (0 ≤ index < count), tracked.
  final int Function() index;
}

/// A named reaction to a DOM event. `arg` comes from the element's
/// `data-tx` attribute (e.g. the product index of a card).
final class Action extends Binding {
  /// Binds the element's event(s) to [run].
  const Action(super.id, this.run);

  /// Called with the event's `arg` (from `data-tx`) when the action fires;
  /// returns the method's result (a `Focus.onKeyEvent`'s `KeyEventResult`).
  final Object? Function(String? arg) run;
}

/// A keyed list of rows (Flutter's `ListView.builder` / `Column` of items).
///
/// The server renders the current rows plus one row template; the client
/// reconciles by [key]: existing rows are kept (and moved), new ones are
/// cloned from the template, missing ones removed. Each row's dynamic
/// content is a set of named text [fields].
final class ListBinding<T> extends Binding {
  /// Binds the element to a reconciled list of rows keyed by [key].
  const ListBinding(
    super.id, {
    required this.items,
    required this.key,
    this.fields = const {},
    this.states = const {},
    this.selections = const {},
  });

  /// The current items, tracked.
  final List<T> Function() items;

  /// Stable identity of an item (letters, digits, `-`, `_`).
  final String Function(T item) key;

  /// Row texts by field name.
  final Map<String, String Function(T item)> fields;

  /// Row elements with finite states: name → the item's state index.
  final Map<String, int Function(T item)> states;

  /// Row elements whose state is whether the row's key is the value of a field
  /// (`row.selected`): name → that value as text, tracked. Not read per row:
  /// when it changes only the row that was and the one that is now selected
  /// change state.
  final Map<String, String Function()> selections;

  /// `(key, item)` in order (reads [items], so tracked).
  List<(String, Object?)> entries() => [
    for (final item in items()) (key(item), item),
  ];

  /// The texts of one item (from [entries]). A field that throws is left
  /// out and handed to [onError] (the row keeps its template text there and
  /// the other fields still show), like the lite engine's rows.
  Map<String, String> fieldsOf(
    Object? item, [
    void Function(Object error, StackTrace trace)? onError,
  ]) {
    final out = <String, String>{};
    for (final f in fields.entries) {
      try {
        out[f.key] = f.value(item as T);
        // ignore: avoid_catches_without_on_clauses
      } catch (e, st) {
        if (onError == null) rethrow;
        onError(e, st);
      }
    }
    return out;
  }

  /// The state indices of one item's row elements; one that throws is left
  /// out and handed to [onError].
  Map<String, int> statesOf(
    Object? item, [
    void Function(Object error, StackTrace trace)? onError,
  ]) {
    final out = <String, int>{};
    for (final s in states.entries) {
      try {
        out[s.key] = s.value(item as T);
        // ignore: avoid_catches_without_on_clauses
      } catch (e, st) {
        if (onError == null) rethrow;
        onError(e, st);
      }
    }
    return out;
  }
}

/// Server data for a [signal]: the server writes the value it rendered with
/// into the page (`<script type="application/json" id="thor-state">`) and
/// the client restores it before any effect runs, so the page starts from
/// the real data instead of the defaults in the code.
final class StateBinding<T> extends Binding {
  /// Binds [signal] to server-rendered state, restored via [decode].
  const StateBinding(
    super.id,
    this.signal, {
    required this.encode,
    required this.decode,
  });

  /// The signal whose value is persisted and restored.
  final Signal<T> signal;

  /// To JSON-compatible values (maps, lists, strings, numbers, bools).
  final Object? Function(T value) encode;

  /// From the JSON-compatible value back to [T].
  final T Function(Object? json) decode;

  /// Encodes [signal]'s current value with [encode].
  Object? encodeCurrent() => encode(signal.peek());

  /// Decodes [json] with [decode] and writes it into [signal].
  void restore(Object? json) => signal.value = decode(json);
}
