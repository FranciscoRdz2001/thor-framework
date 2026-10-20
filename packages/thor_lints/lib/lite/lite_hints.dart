// ignore_for_file: prefer_const_constructors, the table mixes RegExp entries with plain ones

/// How to get out of each construct the lite translator rejects.
///
/// A rejected construct that says only "not in the lite subset" leaves the
/// author guessing. [liteHintFor] gives every error its "how to fix it":
/// the entry of [liteHints] that matches, or [liteGenericHint].
///
/// `thor_builder`'s `test/lite_hints_doc_test.dart` keeps this table and
/// docs/errores/THOR-B012.md (the list of what the subset leaves out) in
/// step: every [LiteHint.construct] must appear in that page.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:thor_style/errors.dart' show thorErrorsUrl;

/// One rejected construct and the way out.
class LiteHint {
  /// [construct] is what the doc names; an error is this entry's when its
  /// message matches [message] (or [node] says so).
  const LiteHint(this.construct, this.suggestion, {this.message, this.node});

  /// The construct as docs/errores/THOR-B012.md names it (a code span there).
  final String construct;

  /// What to do instead: concrete and short.
  final String suggestion;

  /// Matches the error's message.
  final Pattern? message;

  /// Or the node where it fails.
  final bool Function(AstNode node)? node;

  /// Whether this entry explains the error [text] at [at].
  bool matches(String text, AstNode at) =>
      (message != null && text.contains(message!)) ||
      (node != null && node!(at));
}

const _toServer = 'or move the work to a query()/command() on the server';

/// Whether [n] is (or uses) an extension type.
bool _extensionType(AstNode n) {
  final DartType? t = switch (n) {
    InstanceCreationExpression() => n.staticType,
    Expression() => n.staticType,
    _ => null,
  };
  return t?.element is ExtensionTypeElement;
}

/// Construct → suggestion, most common first. The first match wins.
final liteHints = <LiteHint>[
  LiteHint(
    'Future.wait(cleanUp:)',
    'drop `cleanUp:` and release what each future made in a try/finally '
        'after the await, $_toServer',
    message: RegExp(r'^Future\.wait\(cleanUp:\)'),
  ),
  LiteHint(
    '.wait',
    'use `await Future.wait([a, b])` and read the list: a failure is then '
        'the first error itself, not a ParallelWaitError',
    message: '`.wait`',
  ),
  LiteHint(
    '.timeout',
    'race it on the server in a query()/command(), or keep a deadline with '
        'Timer',
    message: '`.timeout()`',
  ),
  LiteHint(
    'Timer.run',
    'use `Timer(Duration.zero, callback)` (or `unawaited(Future.delayed('
        'Duration.zero, callback))`)',
    message: RegExp(r'^Timer\.run\b'),
  ),
  LiteHint(
    'Completer.sync',
    'use `Completer()`: its listeners run in a microtask, not inside '
        'complete()',
    message: RegExp(r'^Completer\.sync\b'),
  ),
  LiteHint(
    'StreamController',
    'lite has no streams: keep the values in a state() and change it '
        'directly',
    message: RegExp(r'\bStreamController\b'),
  ),
  LiteHint(
    '.listen',
    'lite has no streams: use Timer.periodic to poll, or read the data with '
        'a query() on the server',
    message: '`.listen()`',
  ),
  LiteHint(
    'await for',
    'lite has no streams: loop over a List, or use Timer.periodic, or read '
        'the data with a query() on the server',
    message: '`await for`',
  ),
  LiteHint(
    'Stream',
    'lite has no streams: use Timer.periodic to poll, or read the data with '
        'a query() on the server',
    message: RegExp(r'^Stream(\.\w+)?\(\.\.\.\)|\bStream<'),
  ),
  LiteHint(
    'sync*',
    'return a List built with a loop or a collection `for` (async*: a '
        'Future<List<T>> from an async method); a long or endless sequence '
        'belongs in a query() on the server',
    message: 'Generators',
  ),
  LiteHint(
    'mixin',
    'mix in a `mixin` declared in the app (not a `mixin class`, not one of a '
        'package), without static members: or use composition (a field of '
        'the helper class or a top-level function)',
    message: RegExp('mixes in|`mixin class`|in a mixin|interfaces are not'),
  ),
  LiteHint(
    'operator +',
    'write a method instead (`a.plus(b)`, `a.at(i)`): of the operators on '
        'your classes only `==` is translated',
    message: RegExp(r'^Operators? '),
  ),
  LiteHint(
    'is Map<String, dynamic>',
    'JS carries no type arguments: test `is Map` (or `is List`) without '
        'them, then read with `as Map<String, dynamic>`; or build the objects '
        'in a `fromJson` factory',
    message: RegExp(r'`is (Map|List|Set)<|Matching the type (Map|List|Set)<'),
  ),
  LiteHint(
    '.whereType',
    'a type with arguments (`whereType<List<int>>()`) can not be tested in '
        'JS: `l.where((x) => x is List).map((x) => x as List<int>)`',
    message: '`.whereType()`',
  ),
  LiteHint(
    'lastIndexOf(RegExp)',
    'walk `RegExp.allMatches` and keep the last match, or use a String '
        'pattern',
    message: RegExp(r'with a RegExp'),
  ),
  LiteHint(
    'extension type',
    'use a small class with one `final` field, or the underlying type',
    node: _extensionType,
  ),
  LiteHint(
    'late',
    '`late final x = …` (with its initializer) is supported in a state and '
        'a class; for another `late`, give it a value where it is declared '
        '(`final x = …`), or make it nullable (`int? x;`) and check it with `!`',
    message: RegExp('^`late`'),
  ),
  LiteHint(
    'super',
    'drop the `super.…` call (only `super.dispose()` and '
        '`super.onHydrated()` are accepted: a ThorState has nothing in them); '
        'cancel your Timers in `dispose()`',
    message: '`super`',
  ),
  LiteHint(
    'ValueNotifier',
    'make it a `state(...)` field: a StateSignal is a ValueNotifier '
        '(`final count = state(0);`, `ValueListenableBuilder` and '
        '`addListener` work on it) and it reacts in the browser',
    // Also where a helper class of the state holds one (`ValueNotifier(...)`,
    // `.value` on a `ValueNotifier<int>`).
    message: RegExp(r'ValueNotifier|ChangeNotifier'),
  ),
  LiteHint(
    'interpolate a Map',
    'print the entries: `m.entries.map((e) => "\${e.key}: \${e.value}")'
        '.join(", ")`',
    message: RegExp(r'^Interpolating a (Map|LinkedHashMap)<'),
  ),
  LiteHint(
    'interpolate a record',
    'interpolate each field: `"\${r.\$1}, \${r.\$2}"`',
    message: RegExp(r'^Interpolating a \('),
  ),
  LiteHint(
    'interpolate a List<Object>',
    'its elements have no known type: type the collection (`List<String>`) '
        'or join a field of each (`items.map((i) => i.name).join(", ")`)',
    message: RegExp(
      r'^Interpolating a (Iterable|List|Set)<(Object\??|dynamic)>',
    ),
  ),
  LiteHint(
    'interpolate a list of objects',
    'join a field of each (`items.map((i) => i.name).join(", ")`), or give '
        'the element class a toString()',
    message: RegExp(r'^Interpolating a (Iterable|List|Set)<'),
  ),
  LiteHint(
    'interpolate a class',
    'give the class a `String toString() => …`, or interpolate its fields',
    message: RegExp(r'^Interpolating a '),
  ),
  LiteHint('getRange', 'use `sublist(start, end)`', message: '`.getRange()`'),
  LiteHint(
    'removeRange',
    'rebuild the list: `l = [...l.sublist(0, a), ...l.sublist(b)]`',
    message: '`.removeRange()`',
  ),
  LiteHint(
    'runtimeType',
    'test with `is`, or give your classes a `kind` enum',
    message: '`.runtimeType`',
  ),
  LiteHint(
    'index on dynamic',
    'cast before indexing: `(d as Map)["key"]` or `(d as List)[0]`',
    message: 'Index on dynamic',
  ),
  LiteHint(
    'compare by value',
    'key by a String or an int (`item.id`, `date.millisecondsSinceEpoch`): '
        'a Set or Map of DateTime, Duration or TimeOfDay compares by value in '
        'Dart',
    message: 'compare by value in Dart',
  ),
  LiteHint(
    'extends',
    'extend a class of the app, or keep the framework class as a field '
        '(composition)',
    message: RegExp(r'only classes of the app can be extended'),
  ),
  LiteHint(
    'integer above 2^53',
    'keep integers under 2^53 (JS numbers are doubles): send it as a '
        'String, or compute it in a query() on the server',
    message: 'Integer literal outside the exact JS range',
  ),
];

/// The fallback for an error no entry knows: where the supported subset is
/// and the server way out (THOR-B012).
const liteGenericHint =
    'rewrite it with what the lite subset supports (${thorErrorsUrl}THOR-B012), '
    '$_toServer';

/// Words that show the message already says what to do instead.
final _saysHow = RegExp(
  r'\b(use|write|move|cast|create|iterate|catch|assign|interpolate|compare'
  r'|only)\b',
  caseSensitive: false,
);

/// The construct name of an error inside generated code (`*.g.dart`).
const liteGeneratedConstruct = '*.g.dart';

/// Whether [node] is in a generated file (`*.g.dart`, `*.freezed.dart`).
bool _inGenerated(AstNode node) {
  final root = node.root;
  final path = root is CompilationUnit
      ? root.declaredFragment?.source.fullName
      : null;
  return path != null && RegExp(r'\.(g|freezed|gr)\.dart$').hasMatch(path);
}

/// The way out of the error [message] at [node]: an explicit [given] hint,
/// else the first [liteHints] entry that matches, else null when the message
/// already says how, else [liteGenericHint].
String liteHintFor(String message, AstNode node, {String? given}) {
  final hint = given ?? _hintFor(message, node);
  if (!_inGenerated(node)) return hint;
  return 'this file is generated, do not edit it: keep that builder\'s '
      'output out of a ThorState (a hand-written class, or move the work to '
      'a query()/command() on the server)${hint.isEmpty ? '' : '; $hint'}';
}

String _hintFor(String message, AstNode node) {
  for (final h in liteHints) {
    if (h.matches(message, node)) return h.suggestion;
  }
  return _saysHow.hasMatch(message) ? '' : liteGenericHint;
}
