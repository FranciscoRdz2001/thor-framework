import 'package:thor_engine/thor_engine.dart'
    show cssPxValue, untracked, variablesAttr;
import 'package:thor_style/thor_style.dart';

import 'style_registry.dart' show ConditionalCss;

// Internal (hidden from `thor_ui.dart`): the variables behind `BoundLength`.
//
// A bound value is a `Length` whose CSS is `var(--tb-<state>-<member>)`: the
// name is a function of the binding, so the class an element gets is the
// same in every session and the client generates nothing. The element that
// reads the variable gets the binding (`data-tcv`) and its first value
// (`style`) here, wherever the `Length` came from (padding, radius, a font
// size, a position): the app never names the variable.

/// The prefix of the variables a `BoundLength` writes.
const boundLengthPrefix = '--tb-';

/// The prefix of the variables a row's `RowLength` writes (not in the
/// bound-length registry: its first value depends on the row).
const rowLengthPrefix = '--tr-';

/// Whether any `BoundLength` was made in this process: until one is, no
/// element looks for variables.
bool boundLengthsUsed = false;

typedef _Source = ({String bindingId, num Function() read});

// Name → what it is bound to. Insertion ordered and bounded: a bound value
// with an argument per item (`cell.px.withArg(i)`) must not grow it forever,
// and the entries are only read while the element that uses them is built.
final _sources = <String, _Source>{};
const _sourcesLimit = 4096;

/// The variable name of [bindingId]: `--tb-` and the id with whatever a
/// custom property can't hold escaped (`Card.radius` → `--tb-Card-radius`).
String boundLengthName(String bindingId) {
  final out = StringBuffer(boundLengthPrefix);
  for (final unit in bindingId.codeUnits) {
    final c = String.fromCharCode(unit);
    if (c == '.') {
      out.write('-');
    } else if (_plain.hasMatch(c)) {
      out.write(c);
    } else {
      out.write('_${unit.toRadixString(16)}_');
    }
  }
  return out.toString();
}

final _plain = RegExp(r'[A-Za-z0-9]');

/// Binds [bindingId] to [read] and returns the variable's name.
String registerBoundLength(String bindingId, num Function() read) {
  boundLengthsUsed = true;
  final name = boundLengthName(bindingId);
  _sources.remove(name);
  _sources[name] = (bindingId: bindingId, read: read);
  if (_sources.length > _sourcesLimit) {
    _sources.remove(_sources.keys.first);
  }
  return name;
}

final _rowReference = RegExp('$rowLengthPrefix[A-Za-z0-9_-]+');

/// The `--tr-` names (a row's `RowLength`) [css] and [conditions] read.
List<String> rowLengthsIn(
  CssDeclarations css,
  List<ConditionalCss> conditions,
) {
  Set<String>? found;
  void scan(CssDeclarations declarations) {
    for (final value in declarations.values) {
      if (!value.contains(rowLengthPrefix)) continue;
      for (final m in _rowReference.allMatches(value)) {
        (found ??= {}).add(m[0]!);
      }
    }
  }

  scan(css);
  for (final c in conditions) {
    scan(c.css);
  }
  return found?.toList() ?? const [];
}

final _reference = RegExp('$boundLengthPrefix[A-Za-z0-9_-]+');

/// The names of the bound variables [css] and [conditions] read, sorted.
List<String> boundLengthsIn(
  CssDeclarations css,
  List<ConditionalCss> conditions,
) {
  if (!boundLengthsUsed) return const [];
  Set<String>? found;
  void scan(CssDeclarations declarations) {
    for (final value in declarations.values) {
      if (!value.contains(boundLengthPrefix)) continue;
      for (final m in _reference.allMatches(value)) {
        (found ??= {}).add(m[0]!);
      }
    }
  }

  scan(css);
  for (final c in conditions) {
    scan(c.css);
  }
  return found == null ? const [] : (found!.toList()..sort());
}

/// The attributes of an element that reads the bound variables [names]: the
/// bindings the browser keeps current, and their first values (so the page
/// is right without JS).
Map<String, String> boundLengthAttributes(List<String> names) {
  final ids = <String>[];
  final first = <String>[];
  for (final name in names) {
    final source = _sources[name];
    // Not bound by this process (a copied class, a stale name): the
    // variable keeps whatever the CSS falls back to.
    if (source == null) continue;
    ids.add('$name:${source.bindingId}');
    first.add('$name:${cssPxValue(untracked(source.read))}');
  }
  return ids.isEmpty
      ? const {}
      : {variablesAttr: ids.join(';'), 'style': first.join(';')};
}
