/// Translates an app's `ThorState` classes (and the library code they use)
/// to JS for the thor-lite runtime (`packages/thor_engine/lib/lite/runtime.js`).
///
/// Works on the resolved AST: the static types decide how an operation is
/// written in JS (`~/`, `%`, `==`, list and string methods…). The numeric
/// semantics are those of Dart on the web (what the dart2js engine runs):
/// an `int` is a JS number, bitwise operators work on 32 bits.
///
/// Only a subset of Dart is translated (see [liteSubset]); everything else
/// is a [LiteError] with its file and line, never a silent approximation.
///
/// DateTime, Duration, TimeOfDay, DateUtils and the controllers are classes
/// of optional runtime parts (`packages/thor_engine/lib/lite/parts/`), with Dart's
/// member names; the output's first line after the header names the parts
/// it needs (`// thor-lite parts: …`), and the build loads only those.
library;

import 'dart:math' show min;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:thor_style/thor_style.dart' as st;

import 'package:thor_style/errors.dart' show thorError;
import 'data_class.dart';
import 'lite_hints.dart';
import 'row_lambdas.dart' show rowLambdasIn;
import 'state_members.dart'
    show focusNodeType, intentRebuildable, intentType, keyEventType;

/// Whether a node names [element] (a parameter that must go unused).
class _ReadsElement extends RecursiveAstVisitor<void> {
  _ReadsElement(this.element);

  final Element element;
  bool found = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.element == element) found = true;
  }
}

/// What the translator accepts, for error messages and docs.
const liteSubset =
    'ThorState fields `state(...)` and plain fields; methods, getters and '
    'private helpers; top-level functions, variables and constants of the '
    "app's own libraries; simple enums; data classes (fields, one unnamed "
    'constructor, factory constructors, getters, methods, toString); '
    "thor's `batch` and `untracked`; dart:async's Timer (one-shot and "
    'periodic: `cancel`, `isActive`, `tick`); '
    'int, double, num, bool, String, List, Map<String, V> and records; '
    'FrameMessages (postToParent, postToFrame, listen; part `frame_messages`); '
    'DateTime, Duration, TimeOfDay and DateUtils (runtime part `dates`); '
    'DialogController, FocusNode, TextEditingController, ScrollController '
    'and AnimationController fields (part `controllers`); '
    'static methods and constants of a state (`static const`, or '
    '`static final` of a constant value); '
    'try/catch/finally (`on` FormatException, StateError, ArgumentError, '
    'RangeError, UnsupportedError, Exception, Error, String or a class of '
    'the app; a FormatException\'s `message`), throw and rethrow; '
    'jsonDecode and jsonEncode; '
    'Future.delayed (awaited or not, with or without a callback), '
    'unawaited and Future.value; package:collection\'s '
    'firstWhereOrNull, lastWhereOrNull, sortedBy, sorted, groupListsBy, '
    'groupBy, mapIndexed, whereIndexed, forEachIndexed, sum, max and min; '
    'patterns (objects, records, maps, lists, `MapEntry(:key, :value)`); '
    '`late final x = …` fields (computed on first read); '
    '`late final x = derived(() => …)` fields (a cached computed signal); '
    'closures, collection if/for/spread, cascades, switch on constants.';

/// One resolved compilation unit of the app, with the path shown in errors.
class LiteUnit {
  /// [unit] (resolved), displayed as [path].
  LiteUnit(this.path, this.unit);

  /// The path shown in errors (relative to the app).
  final String path;

  /// The resolved unit.
  final CompilationUnit unit;
}

/// The start of the message for a `state(...)` field that holds a data class
/// (see [isJsonDataClass]) whose source is not among the translated units.
const dataClassSourceMissing = 'Data class without source';

/// A construct outside the subset, with where it is.
class LiteError {
  /// [message] at [path]:[line]:[column], with the source line ([frame])
  /// and the way out ([hint]).
  LiteError(
    this.path,
    this.line,
    this.column,
    this.message, {
    this.hint = '',
    this.frame = '',
    this.node,
  });

  /// File, 1-based line and column.
  final String path;

  /// 1-based line.
  final int line;

  /// 1-based column.
  final int column;

  /// What is not supported.
  final String message;

  /// How to fix it (empty when the message already says).
  final String hint;

  /// The source line with a caret under the column (see [liteCodeFrame]);
  /// empty when the source is not at hand.
  final String frame;

  /// The construct, where the translator has it: the editor's rule
  /// (`thor_lite_subset`) underlines it.
  final AstNode? node;

  @override
  String toString() =>
      '$path:$line:$column: $message'
      '${frame.isEmpty ? '' : '\n$frame'}'
      '${hint.isEmpty ? '' : '\n  fix: $hint'}';
}

/// [errors] sorted by place and without repeats: the same construct is
/// translated once per state that reaches it, so one place can report the
/// same message twice.
List<LiteError> _sortedUnique(List<LiteError> errors) {
  final seen = <String>{};
  final out = [
    for (final e in errors)
      if (seen.add(
        '${e.path}\u0000${e.line}\u0000${e.column}\u0000${e.message}',
      ))
        e,
  ];
  out.sort(
    (a, b) => a.path != b.path
        ? a.path.compareTo(b.path)
        : a.line != b.line
        ? a.line.compareTo(b.line)
        : a.column.compareTo(b.column),
  );
  return out;
}

/// The line [line] (1-based) of [source] with a caret under [column]
/// (1-based, UTF-16 units as the analyzer counts them), like
/// `  12 | code` over `     |   ^`. A CRLF line loses its `\r`, a tab before
/// the caret stays a tab (so the caret lines up in any tab width), and a
/// long line is cut around the column with `…`.
///
/// Known limit: the caret is aligned by rune (a tab stays a tab, every other
/// code point is one column), not by display cell, so wide glyphs (CJK) and
/// ZWJ emoji before the column shift it in a terminal.
String liteCodeFrame(String source, int line, int column) {
  var start = 0;
  for (var i = 1; i < line; i++) {
    final nl = source.indexOf('\n', start);
    if (nl < 0) return '';
    start = nl + 1;
  }
  var end = source.indexOf('\n', start);
  if (end < 0) end = source.length;
  var text = source.substring(start, end);
  if (text.endsWith('\r')) text = text.substring(0, text.length - 1);
  final col = (column - 1).clamp(0, text.length);
  const width = 100, before = 40;
  var from = 0;
  while (from < col && (text[from] == ' ' || text[from] == '\t')) {
    from++;
  }
  if (col - from > before && text.length - from > width) from = col - before;
  // Never cut a surrogate pair in two.
  bool low(int i) => i < text.length && (text.codeUnitAt(i) & 0xFC00) == 0xDC00;
  if (low(from)) from++;
  var to = text.length;
  if (to - from > width) {
    to = from + width;
    if (low(to)) to--;
  }
  final shown =
      '${from > 0 && text.substring(0, from).trim().isNotEmpty ? '…' : ''}'
      '${text.substring(from, to)}'
      '${to < text.length ? '…' : ''}';
  final lead = shown.startsWith('…') ? 1 : 0;
  final pad = StringBuffer();
  for (final r in text.substring(from, col.clamp(from, to)).runes) {
    pad.write(r == 0x09 ? '\t' : ' ');
  }
  final gutter = '$line'.length;
  return '  $line | $shown\n'
      '  ${' ' * gutter} | ${' ' * lead}$pad^';
}

/// Thrown by [translateLiteStates] with every error found.
class LiteTranslationException implements Exception {
  /// The [errors], in source order and without repeats.
  LiteTranslationException(List<LiteError> errors)
    : errors = _sortedUnique(errors);

  /// Everything outside the subset.
  final List<LiteError> errors;

  @override
  String toString() => errors.join('\n');

  /// What the build prints: every construct, then the ways out, lightest
  /// first (lite is the only engine): the work to the server
  /// (`query`/`command`, where any package runs and the page stays lite),
  /// or the subset.
  String get report =>
      '${errors.length} construct(s) outside the thor-lite subset:\n$this\n'
      '${thorError('THOR-B012', liteWayOut)}';
}

/// The way out of THOR-B012 the build prints after the list (and the
/// editor's rule gives an error without its own fix).
const liteWayOut =
    'Move that work to the server: a `query(fn)` computes a value and a '
    '`command(fn)` changes one, and `fn` may use any package (intl, uuid…) '
    'while the page keeps the lite engine. Or rewrite it within the subset';

/// The thor-lite JS for the `ThorState` classes in [units] (every library of
/// the app: states, and the code they use). Throws a
/// [LiteTranslationException] listing every construct outside the subset.
///
/// With [shortNames] (the build's), locals, parameters, the states' own
/// members and the top-level declarations get short JS names (`a`, `b`…,
/// unique in the file, so no name shadows another); the page's protocol
/// names (a state's members as the page calls them, `$s`) stay Dart's.
///
/// [checks] (default: the opposite of [shortNames], so `thor dev` has them
/// and the release build not) emits what Dart checks and JS would let pass:
/// `x!` on null, `as` casts, list and string indexes, `single`, `sublist`,
/// `reduce` and `removeAt`/`removeLast` out of range. Like dart2js, which
/// keeps them at -O1 and drops them with `--omit-implicit-checks` (-O3).
///
/// [dataClasses] and [dataMembers] are for a library that has the data
/// classes but not the state (the editor's rule only has one library
/// resolved): the classes named in [dataClasses] travel to the browser as
/// if a state held them (events/query/state type arguments: their
/// `fromJson`, `toJson` and fields), and the members named in [dataMembers]
/// are the ones the states call.
String translateLiteStates(
  List<LiteUnit> units, {
  String header = '',
  bool shortNames = false,
  bool? checks,
  Set<String> dataClasses = const {},
  Set<String> dataMembers = const {},
}) => _Translator(
  units,
  shortNames: shortNames,
  checks: checks,
  dataClasses: dataClasses,
  dataMembers: dataMembers,
).run(header);

// ---------------------------------------------------------------------------

/// A declaration of the app, by element.
class _Decl {
  _Decl(this.node, this.unit, this.order);
  final AstNode node;
  final LiteUnit unit;
  final int order;
}

/// Where an expression is being translated.
class _Ctx {
  _Ctx({this.state, this.cls, this.ext, this.hoist = true});

  /// The ThorState class whose factory is being written.
  final _StateInfo? state;

  /// The data class whose method is being written (`this` is the object).
  final InterfaceElement? cls;

  /// The extension whose member is being written (`this` is `$this`, the
  /// function's first parameter).
  final ExtensionElement? ext;

  /// Whether const collections are hoisted (inside functions).
  final bool hoist;
}

/// What a pattern needs of a value: tests (all must hold, in order) and
/// the variables it binds (name, JS value, declared with `var`).
class _Match {
  final conds = <String>[];
  final binds = <(String, String, bool)>[];
}

class _StateInfo {
  _StateInfo(this.element, [Iterable<InterfaceElement> mixins = const []])
    : owners = {element, ...mixins};
  final ClassElement element;

  /// The state and the mixins it uses: their members are the state's.
  final Set<InterfaceElement> owners;
  bool owns(Element? e) => e != null && owners.contains(e);

  /// For the member being written: `super.name` → the JS name of the
  /// definition it overrides (a mixin's, or the base state's).
  var supers = const <String, String>{};
  final signals = <FieldElement>{};
  final getters = <Element>{};
}

/// A JS literal a class `static` can keep as is (a number, a string
/// without interpolation, a bool, null): it reads nothing that may not
/// exist yet when the class is evaluated.
final _jsLiteral = RegExp(
  r"""^(-?[\d.]+(e[+-]?\d+)?|"([^"\\]|\\.)*"|'([^'\\]|\\.)*'|true|false|null)$""",
);

const _jsReserved = {
  'arguments', 'await', 'break', 'case', 'catch', 'class', 'const', //
  'continue', 'debugger', 'default', 'delete', 'do', 'else', 'enum', 'eval',
  'export', 'extends', 'false', 'finally', 'for', 'function', 'if',
  'implements', 'import', 'in', 'instanceof', 'interface', 'let', 'new',
  'null', 'package', 'private', 'protected', 'public', 'return', 'static',
  'super', 'switch', 'this', 'throw', 'true', 'try', 'typeof', 'var', 'void',
  'while', 'with', 'yield', 'undefined', 'NaN', 'Infinity', 'Math', 'Number',
  'Object', 'Array', 'String', 'Error', 'JSON', 'console', 'window',
  'document', 'thor', 'globalThis', 'Symbol', 'Boolean', 'Map', 'Set',
};

/// Helpers emitted once, only when used.
const _helpers = {
  // A Dart exception of dart:core (`$t`: its type): `on StateError` tests
  // `$t`; toString is Dart's ([s]: the whole text, when Dart's differs).
  r'$X':
      r"class $X extends Error { constructor(t, m, s) { super(m ?? ''); this.$t = t; this.m = m; this.s = s; } toString() { const m = this.m; if (this.s != null) return this.s; switch (this.$t) { case 'StateError': return `Bad state: ${m}`; case 'ArgumentError': return m == null ? 'Invalid argument(s)' : `Invalid argument(s): ${m}`; case 'UnsupportedError': return `Unsupported operation: ${m}`; default: return m == null || m === '' ? this.$t : `${this.$t}: ${m}`; } } }",
  // DateTime.parse: a FormatException (`on FormatException` catches it, its
  // `message` is Dart's), not the part's plain error.
  r'$dtp':
      r"const $dtp = (s) => { const d = $DT.p(s); if (d == null) { const m = d === null ? 'Invalid date format' : 'Time out of range'; throw new $X('FormatException', m, `FormatException: ${m}\n${s.length > 78 ? s.substring(0, 75) + '...' : s}`); } return d; };",
  // jsonDecode: JSON.parse, and dart2js's FormatException(String(error)).
  r'$json':
      r"const $json = (s) => { try { return thor.parse(s); } catch (e) { throw new $X('FormatException', String(e)); } };",
  // jsonEncode: Dart's rules (toJson of a class, String keys, finite
  // numbers; anything else is a JsonUnsupportedObjectError) and the maps'
  // insertion order; JSON.stringify writes each scalar (it escapes like
  // Dart).
  r'$jenc':
      r"const $jenc = (v) => { const w = (x) => { if (x == null || typeof x === 'boolean' || typeof x === 'string' || typeof x === 'number' && Number.isFinite(x)) return JSON.stringify(x ?? null); if (Array.isArray(x)) return `[${x.map(w).join(',')}]`; if (x instanceof Map) return `{${[...x].map(([k, y]) => { if (typeof k !== 'string') throw $jerr(x); return `${JSON.stringify(k)}:${w(y)}`; }).join(',')}}`; if (typeof x === 'object' && typeof x.toJson === 'function') return w(x.toJson()); throw $jerr(x); }; return w(v); };",
  r'$jerr':
      r"const $jerr = (x) => new $X('JsonUnsupportedObjectError', null, `Converting object to an encodable object failed: ${x}`);",
  // package:collection's groupListsBy / groupBy.
  r'$group':
      r'const $group = (l, f, m = new Map()) => { for (const x of l) { const k = f(x), g = m.get(k); if (g) g.push(x); else m.set(k, [x]); } return m; };',
  // package:collection's max / min of numbers (StateError when empty).
  r'$maxmin':
      r"const $maxmin = (l, f) => { if (l.length === 0) throw new $X('StateError', 'No element'); return l.reduce((a, b) => f(a, b) ? a : b); };",
  // A key comparison for sortedBy: compareTo when the key has one (a date
  // of the runtime's parts, a class of the app), else < and >.
  r'$kcmp':
      r"const $kcmp = (a, b) => (a != null && typeof a === 'object' && typeof a.compareTo === 'function' ? a.compareTo(b) : a < b ? -1 : a > b ? 1 : 0);",
  // A const map: set, delete and clear throw, like Dart's unmodifiable map.
  r'$ro':
      r"const $ro = (m) => { m.set = m.delete = m.clear = () => { throw new $X('UnsupportedError', 'Cannot modify unmodifiable map'); }; return m; };",
  // Iterating a map's keys, values or entries (for-in) or forEach: over a
  // copy, and a change in the map's size meanwhile is Dart's
  // ConcurrentModificationError (a remove plus an add goes unseen).
  r'$cme':
      r"const $cme = (m) => new $X('ConcurrentModificationError', null, `Concurrent modification during iteration: ${m}`);",
  r'$iter':
      r"function* $iter(m, p) { const n = m.size; for (const x of p === 'entries' ? [...m].map(([key, value]) => ({ key, value })) : [...m[p]()]) { yield x; if (m.size !== n) throw $cme(m); } }",
  r'$each':
      r'const $each = (m, f) => { const n = m.size; for (const [k, v] of [...m]) { f(k, v); if (m.size !== n) throw $cme(m); } };',
  // Future.wait: every future is awaited (and its error handled); the first
  // error to happen is the result's, once all are done (or at once with
  // eagerError), like dart:async.
  r'$wait':
      r'const $wait = (l, eager) => new Promise((res, rej) => { const a = [...l], out = new Array(a.length); let n = a.length, err, bad = false; if (!n) return res(out); a.forEach((p, i) => Promise.resolve(p).then((v) => { out[i] = v; if (!--n) bad ? rej(err) : res(out); }, (e) => { if (!bad) { bad = true; err = e; if (eager) return rej(e); } if (!--n) rej(err); })); });',
  // dart:async's Completer: a second complete is a StateError.
  r'$Completer':
      r"class $Completer { constructor() { this.isCompleted = false; this.future = new Promise((r, j) => { this.r = r; this.j = j; }); } complete(v) { if (this.isCompleted) throw new $X('StateError', 'Future already completed'); this.isCompleted = true; this.r(v === undefined ? null : v); } completeError(e) { if (this.isCompleted) throw new $X('StateError', 'Future already completed'); this.isCompleted = true; this.j(e); } }",
  // String.split(RegExp) as dart2js does it: without capture groups the
  // native `split` (a match at the end leaves a trailing ''); with them its
  // `_defaultSplit`: no captured groups in the parts, an empty match at the start or right after another
  // one cuts nothing, and a match at the end leaves no trailing ''.
  r'$resplit':
      r'const $resplit = (s, r) => { if (new RegExp(r.source + "|", r.flags).exec("").length === 1) return s.split(r); const out = []; let st = 0, len = 1; for (const m of s.matchAll($g(r))) { const ms = m.index, me = ms + m[0].length; len = me - ms; if (len === 0 && st === ms) continue; out.push(s.substring(st, ms)); st = me; } if (st < s.length || len > 0) out.push(s.substring(st)); return out; };',
  // indexOf(RegExp, start): the first match at or after start.
  r'$ixre':
      r'const $ixre = (s, r, i = 0) => { const g = $g(r); g.lastIndex = i; const m = g.exec(s); return m ? m.index : -1; };',
  // startsWith(RegExp, index): a match that begins exactly at index.
  r'$swre':
      r"const $swre = (s, r, i = 0) => { const y = new RegExp(r.source, r.flags.replace('g', '') + 'y'); y.lastIndex = i; return y.test(s); };",
  // Map.update: the value of an existing key through [f], else [absent],
  // else Dart's ArgumentError.
  r'$mupd':
      r"const $mupd = (m, k, f, absent) => { if (m.has(k)) { const v = f(m.get(k)); m.set(k, v); return v; } if (absent) { const v = absent(); m.set(k, v); return v; } throw new $X('ArgumentError', null, `Invalid argument (key): Key not in map.: ${typeof k === 'string' ? JSON.stringify(k) : k}`); };",
  // Map.fromIterables.
  r'$zipmap':
      r'const $zipmap = (ks, vs, mk) => { const k = [...ks], v = [...vs], m = mk(); k.forEach((x, i) => m.set(x, v[i])); return m; };',
  r'$isMap': r'const $isMap = (v) => v instanceof Map;',
  r'$mod':
      r'const $mod = (a, b) => { const r = a % b; return r < 0 ? r + Math.abs(b) : r; };',
  r'$shr':
      r'const $shr = (a, b) => (b > 31 ? (a < 0 ? 4294967295 : 0) : a > 0 ? a >>> b : (a >> b) >>> 0);',
  r'$shl': r'const $shl = (a, b) => (b > 31 ? 0 : (a << b) >>> 0);',
  // JS masks the count of `>>>` to 5 bits (`5 >>> 32 === 5`); Dart gives 0.
  r'$ushr': r'const $ushr = (a, b) => (b > 31 ? 0 : a >>> b);',
  r'$eq': r'const $eq = (a, b) => a === b || (a == null && b == null);',
  // int.parse / double.parse: Dart's grammar (JS's Number accepts `1e3` as
  // an int, `0x10` as a double, `0b1`…).
  r'$int':
      r"const $int = (s) => { const t = s.trim(); if (!/^([+-]?\d+|0x[\da-f]+)$/i.test(t)) throw new $X('FormatException', s); return Number(t); };",
  r'$tryInt':
      r"const $tryInt = (s) => { const t = s == null ? '' : s.trim(); return /^([+-]?\d+|0x[\da-f]+)$/i.test(t) ? Number(t) : null; };",
  r'$double':
      r"const $double = (s) => { const t = s.trim(); if (!/^[+-]?(NaN|Infinity|(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?)$/.test(t)) throw new $X('FormatException', 'Invalid double', `FormatException: Invalid double\n${s.length > 78 ? s.substring(0, 75) + '...' : s}`); return Number(t); };",
  r'$tryDouble':
      r"const $tryDouble = (s) => { const t = s == null ? '' : s.trim(); return /^[+-]?(NaN|Infinity|(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?)$/.test(t) ? Number(t) : null; };",
  r'$pad':
      r'const $pad = (s, w, p, e) => { const k = Math.max(0, w - s.length); return e ? s + p.repeat(k) : p.repeat(k) + s; };',
  // `a ~/ b` (dev): dart2js's UnsupportedError for a non-finite result.
  r'$idiv':
      r"const $idiv = (a, b) => { const r = a / b; if (!Number.isFinite(r)) throw new $X('UnsupportedError', `Result of truncating division is ${r}: ${a} ~/ ${b}`); return Math.trunc(r); };",
  r'$ins':
      r"const $ins = (l, i, x) => { if (!(i >= 0 && i <= l.length)) throw new $X('RangeError', `Value not in range: ${i}`); l.splice(i, 0, x); };",
  r'$cu': r'const $cu = (s, i) => s.charCodeAt($ix(s, i));',
  r'$tk':
      r"const $tk = (l, n, skip) => { if (!(n >= 0)) throw new $X('RangeError', null, `RangeError (${skip ? 'start' : 'end'}): Invalid value: Not greater than or equal to 0: ${n}`); return skip ? l.slice(n) : l.slice(0, n); };",
  // A multi-argument value from the page (`fixed~value`): every part but the
  // last comes back from its `%25` / `%7E` escapes (`splitArgs` of
  // thor_engine, the server's `encodeArgs`).
  r'$split':
      r"const $split = (a, n) => { let r = a ?? ''; const p = [], u = (x) => x.replace(/%(25|7E)/g, (_, c) => (c === '25' ? '%' : '~')); for (let i = 0; i < n - 1; i++) { const at = r.indexOf('~'); if (at < 0) { p.push(u(r)); r = ''; } else { p.push(u(r.slice(0, at))); r = r.slice(at + 1); } } p.push(r); return p; };",
  r'$round':
      r'const $round = (x) => (x < 0 ? -Math.round(-x) : Math.round(x));',
  r'$cmp': r'const $cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);',
  r'$removeWhere':
      r'const $removeWhere = (l, f) => { let j = 0; for (let i = 0; i < l.length; i++) if (!f(l[i])) l[j++] = l[i]; l.length = j; };',
  r'$first':
      r"const $first = (l) => { if (l.length === 0) throw new $X('StateError', 'No element'); return l[0]; };",
  r'$last':
      r"const $last = (l) => { if (l.length === 0) throw new $X('StateError', 'No element'); return l[l.length - 1]; };",
  // A list or string index, checked like dart2js's IndexError (returns the
  // index, so it also works as an assignment target).
  r'$ix':
      r'''const $ix = (l, i) => { if (!(i >= 0 && i < l.length)) throw new $X('RangeError', `Index out of range: ${i}`, `RangeError (index): Index out of range: ${i < 0 ? 'index must not be negative' : `index should be less than ${l.length}`}: ${i}`); return i; };''',
  r'$at': r'const $at = (l, i) => l[$ix(l, i)];',
  // The receiver of an indexed assignment, once (dev only).
  r'$r': r'let $r;',
  r'$atq': r'const $atq = (l, i) => (l == null ? null : $at(l, i));',
  // `x!`: dart2js's NullError text.
  r'$nn':
      r"const $nn = (x) => { if (x == null) { const m = 'Null check operator used on a null value'; throw new $X('TypeError', m, m); } return x; };",
  // `x as T`: [ok] is the type test; the text is the VM's.
  r'$cast':
      r"const $cast = (v, ok, t) => { if (ok(v)) return v; const k = v == null ? 'Null' : typeof v === 'string' ? 'String' : typeof v === 'boolean' ? 'bool' : typeof v === 'number' ? (Number.isInteger(v) ? 'int' : 'double') : Array.isArray(v) ? 'List<dynamic>' : v.constructor?.name ?? 'Object'; const m = `type '${k}' is not a subtype of type '${t}' in type cast`; throw new $X('TypeError', m, m); };",
  r'$single':
      r"const $single = (l) => { if (l.length !== 1) throw new $X('StateError', l.length ? 'Too many elements' : 'No element'); return l[0]; };",
  r'$reduce':
      r"const $reduce = (l, f) => { if (l.length === 0) throw new $X('StateError', 'No element'); return l.reduce(f); };",
  r'$rerr':
      r"const $rerr = (n, v, a, b) => new $X('RangeError', null, `RangeError (${n}): Invalid value: ${a === b ? `Only valid value is ${a}` : `Not in inclusive range ${a}..${b}`}: ${v}`);",
  r'$sub':
      r"const $sub = (l, s, e) => { const n = l.length; if (!(s >= 0 && s <= n)) throw $rerr('start', s, 0, n); if (e != null && !(e >= s && e <= n)) throw $rerr('end', e, s, n); return l.slice(s, e); };",
  r'$rem':
      r"const $rem = (l, i) => { if (!(i >= 0 && i < l.length)) throw new $X('RangeError', `Value not in range: ${i}`); return l.splice(i, 1)[0]; };",
  r'$pop': r'const $pop = (l) => { $ix(l, l.length - 1); return l.pop(); };',
  // Enum values are objects (index, name) of their enum's class; a simple
  // enum shares this one.
  r'$E':
      r'class $E { constructor(t, i, n) { this.$t = t; this.index = i; this.name = n; } toString() { return `${this.$t}.${this.name}`; } }',
  r'$enum':
      r'const $enum = (t, ns) => Object.freeze(ns.map((n, i) => new $E(t, i, n)));',
  r'$byName':
      r'''const $byName = (l, n) => { for (const v of l) if (v.name === n) return v; throw new $X('ArgumentError', 'No enum value with that name', `Invalid argument (name): No enum value with that name: "${n}"`); };''',
  r'$SB':
      r"class $SB { constructor(s = '') { this.s = s; } write(x) { this.s += x; } writeln(x = '') { this.s += x + '\n'; } writeCharCode(c) { this.s += String.fromCharCode(c); } get length() { return this.s.length; } get isEmpty() { return !this.s; } get isNotEmpty() { return !!this.s; } clear() { this.s = ''; } toString() { return this.s; } }",
  // A RegExp's global twin (replaceAll, allMatches).
  r'$g': r"const $g = (r) => new RegExp(r.source, r.flags + 'g');",
  // Uri.encodeQueryComponent: unreserved A-Za-z0-9-._~, space as +.
  r'$encQ':
      r"const $encQ = (s) => encodeURIComponent(s).replace(/[!'()*]/g, (c) => '%' + c.charCodeAt(0).toString(16).toUpperCase()).replace(/%20/g, '+');",
  r'$decQ': r"const $decQ = (s) => decodeURIComponent(s.replace(/\+/g, ' '));",
  r'$sadd': r'const $sadd = (s, x) => s.size !== s.add(x).size;',
  // A set field's add (0), remove (1), toggle (2) or clear (3): a new set
  // when something changes (what notifies), nothing otherwise.
  r'$sop':
      r'const $sop = (s, k, x) => { const v = s.value, h = k < 3 && v.has(x); if (k === 3 ? !v.size : k === 0 ? h : k === 1 ? !h : 0) return; const n = new Set(k === 3 ? [] : v); if (k === 0 || (k === 2 && !h)) n.add(x); else n.delete(x); s.value = n; };',
  // A value as Dart prints it: null as `null`, a list or set as `[1, null,
  // a]` (nested ones too). JS prints null as '' in a join and a list as
  // `1,5`.
  r'$str':
      r"const $str = (x) => (x == null ? 'null' : Array.isArray(x) ? `[${x.map($str).join(', ')}]` : x instanceof Set ? `{${[...x].map($str).join(', ')}}` : `${x}`);",
  // `join` of elements that JS would print differently (null, lists).
  r'$join': r"const $join = (l, s = '') => [...l].map($str).join(s);",
  // SystemNavigator.routeInformationUpdated: the address bar, no reload.
  r'$nav':
      r"const $nav = (u, r) => { if (u !== location.pathname + location.search) r ? history.replaceState(history.state, '', u) : history.pushState('thor', '', u); };",
  // PageNavigator.go: the next page as a new document (location.assign or
  // replace), only a relative or http(s) location (THOR-S008), checked
  // like the Dart side: control characters dropped, the scheme before the
  // first `:` that comes before any `/`, `?` or `#`. [f], [g]: the flash
  // (`PageNavigator.go(flash:)`) the next page shows, in the cookie a server
  // flash rides in (`kind:message`, 300 characters at most, two minutes).
  r'$go':
      r"const $go = (u, r, v, f, g) => { let s = '', k = null; for (const c of u) { if (c <= ' ') continue; if (c === '/' || c === '?' || c === '#') break; if (c === ':') { k = s.toLowerCase(); break; } s += c; } if (k != null && k !== 'http' && k !== 'https') { const m = 'Only a relative, http: or https: location can be navigated to (THOR-S008)'; throw new $X('ArgumentError', m, `Invalid argument (location): ${m}: ${JSON.stringify(u)}`); } if (!v) { if (f != null && f.trim()) { const t = f.length > 300 ? f.slice(0, (f.charCodeAt(299) & 0xFC00) === 0xD800 ? 299 : 300) : f; document.cookie = 'thor-flash=' + encodeURIComponent(g + ':' + t) + '; Path=/; Max-Age=120; SameSite=Lax' + (location.protocol === 'https:' ? '; Secure' : ''); } r ? location.replace(u) : location.assign(u); } };",
  // PageNavigator.canPop: an entry of this site to go back to — the
  // Navigation API's canGoBack (it only knows this origin's entries), else
  // an entry the page pushed ($nav) or a hash entry it saw (`hashchange` to
  // another URL than the document's own: the entry is marked like a pushed
  // one), or a same-origin referrer with more than one entry in the tab (a new tab
  // opened from a link has the referrer but no entry before it). The
  // dart2js engine does the same.
  r'$canPop':
      r"const $canPop = (() => { const u = location.href; addEventListener('hashchange', () => { if (history.state == null && location.href !== u) history.replaceState('thor', ''); }); return () => { const n = globalThis.navigation; if (n && typeof n.canGoBack === 'boolean') return n.canGoBack; if (history.state != null) return true; const r = document.referrer; return history.length > 1 && (r === location.origin || r.startsWith(location.origin + '/')); }; })();",
  // PageNavigator.pop: back one entry, or the fallback (checked like $go,
  // even when it is not needed). Without the Navigation API canPop is a
  // guess (a first entry with a forward entry looks like it has a back):
  // when the back neither leaves the document (`pagehide`) nor moves in it
  // (`popstate`) in time, the fallback loads.
  r'$goBack':
      r"const $goBack = (f) => { const c = $canPop(); $go(f, false, c); if (!c) return; const n = globalThis.navigation; const a = n && typeof n.canGoBack === 'boolean'; let t; const d = () => { clearTimeout(t); removeEventListener('pagehide', d); removeEventListener('popstate', d); }; if (!a) { addEventListener('pagehide', d); addEventListener('popstate', d); t = setTimeout(() => { d(); location.assign(f); }, 600); } history.back(); };",
  r'$reload': r'const $reload = () => location.reload();',
  // state(…, local: 'k'): the `local_storage` part keeps the field in
  // localStorage (`thor-s.k`), like `$persist` keeps one in a cookie.
  r'$local': r'const $local = thor.local;',
  // state(…, cookie: 'c'): move to the cookie `thor-s.c` when it holds a
  // value of the field's type ([t]; [d] decodes it) — in a microtask, once
  // the state's bindings took the server's markup — and write it back
  // (through [e]) when the value changes, like the dart2js engine. The
  // writes are coalesced: a field changed many times between two frames (a
  // Slider drag) is written once, with the value it has then; a hidden page
  // (`visibilitychange`) or `pagehide` writes at once, so the last value is
  // never lost (a hidden tab gets no frames), and a write that throws (cookies
  // blocked) is reported without losing the other fields' writes.
  r'$persist':
      r"const $persist = (() => { const q = new Map(); let h = 0, on = 0; const flush = () => { h = 0; const l = [...q.values()]; q.clear(); l.forEach((w) => { try { w(); } catch (x) { (globalThis.reportError || console.error)(x); } }); }; return (s, c, e, t, d) => { const k = 'thor-s.' + c, m = document.cookie.split(';').map((x) => x.trim()).find((x) => x.startsWith(k + '=')); if (m && m.length - k.length - 1 <= 2048) try { const y = thor.parse(decodeURIComponent(m.slice(k.length + 1))), z = d ? d(y) : y; if (!t || t(z)) queueMicrotask(() => (s.value = z)); } catch {} if (!on) { on = 1; globalThis.addEventListener?.('pagehide', flush); document.addEventListener?.('visibilitychange', () => document.visibilityState === 'hidden' && flush()); } const w = () => { const j = thor.str(e ? e(s.peek()) : s.peek()), v = encodeURIComponent(j); if (v.length <= 2048) document.cookie = `${k}=${v}; path=/; max-age=31536000; samesite=lax${location.protocol === 'https:' ? '; secure' : ''}`; }; let f = 1; thor.effect(() => { s.value; if (f) { f = 0; return; } q.set(k, w); if (document.visibilityState === 'hidden') return flush(); if (!h) { h = 1; globalThis.requestAnimationFrame ? globalThis.requestAnimationFrame(flush) : setTimeout(flush, 16); } }); return s; }; })();",
  // `confirm(...)` / `toast(...)`: the page's one dialog and snack bar (the
  // inline scripts the server ships next to them, `document.thorConfirm` and
  // `document.thorToast`). Without them (a page the server didn't give the
  // markup) a confirm says no and both say why in the console.
  r'$confirm':
      r"const $confirm = (t, m, o, n) => document.thorConfirm ? document.thorConfirm(t, m, o, n) : (console.error('thor: this page has no confirm dialog (THOR-S031)'), Promise.resolve(false));",
  r'$toast':
      r"const $toast = (m, k, d) => document.thorToast ? document.thorToast(m, k, d) : console.error('thor: this page has no snack bar (THOR-S031)');",
  // `hideToast()` / `clearToasts()`: the snack bar's handle (nothing to
  // hide without a bar, so no complaint).
  r'$toastHide': r'const $toastHide = (a) => document.thorToastHide?.(a);',
  // The page's clipboard (part `clipboard`).
  r'$clip': r'const $clip = thor.clip;',
  // FrameMessages (part `frame_messages`): postMessage, explicit origins.
  r'$frame': r'const $frame = thor.frame;',
  // HardwareKeyboard.instance (part `shortcuts` keeps it current).
  r'$keys': r'const $keys = thor.keys;',
  // LogicalKeyboardKey: one frozen object per key label (`==` is `===`).
  r'$LK':
      r'const $LK = (() => { const m = new Map(); return (l) => { let k = m.get(l); if (!k) m.set(l, (k = Object.freeze({ keyLabel: l }))); return k; }; })();',
  // A KeyEvent from the page's `[repeat, keyLabel, character]` (part
  // `key_actions`): `$r` 0 is a KeyDownEvent, 1 a KeyRepeatEvent.
  r'$KE':
      r'const $KE = (a) => { const [r, l, c] = JSON.parse(a); return { $r: r, logicalKey: $LK(l), character: c }; };',
  r'$mdel':
      r'const $mdel = (m, k) => { const v = m.get(k); return m.delete(k) ? v : null; };',
  // thor's Locale (Flutter's): tryParse, subtags, toString and `==` by
  // value (`eq`, like the date parts' values).
  r'$Loc':
      r"""class $Loc { constructor(l, s, c) { this.languageCode = l; this.scriptCode = s ?? null; this.countryCode = c ?? null; } static tryParse(tag) { const p = tag.split(/[-_]/); if (!/^[A-Za-z]{2,8}$/.test(p[0])) return null; let s = null, r = null; for (const x of p.slice(1)) { if (!/^[A-Za-z0-9]{1,8}$/.test(x)) return null; if (s == null && r == null && x.length === 4) s = x[0].toUpperCase() + x.substring(1).toLowerCase(); else if (r == null && (x.length === 2 || /^\d{3}$/.test(x))) r = x.toUpperCase(); } return new $Loc(p[0].toLowerCase(), s, r); } get $parts() { return [this.languageCode, this.scriptCode, this.countryCode].filter((x) => x != null); } toLanguageTag() { return this.$parts.join('-'); } toString() { return this.$parts.join('_'); } eq(o) { return o instanceof $Loc && o.languageCode === this.languageCode && o.scriptCode === this.scriptCode && o.countryCode === this.countryCode; } }""",
  // package:intl's Intl (part `intl`, generated from intl's own rules).
  r'$I': r'const $I = thor.intl;',
  // Optional runtime parts (packages/thor_engine/lib/lite/parts/<part>.js).
  r'$DT': r'const $DT = thor.dt.DT;',
  r'$Dur': r'const $Dur = thor.dt.Dur;',
  r'$TOD': r'const $TOD = thor.dt.TOD;',
  r'$DU': r'const $DU = thor.dt.DU;',
  // Dart's `==` by value, for what the static type doesn't pin down: null
  // only equals null; a class of the app with `operator ==` is asked (its
  // `$eq`, always, even against itself); the date parts' values and records
  // compare their fields; anything else is identity.
  r'$deq':
      r"const $deq = (a, b) => { if (a == null || b == null) return a == b; if (typeof a.$eq === 'function') return a.$eq(b); if (a === b) return true; if (typeof a.eq === 'function') return a.eq(b); return $req(a, b); };",
  // Records (`Object.freeze({ $1: …, name: … })`): same fields, each equal.
  r'$req':
      r"const $req = (a, b) => { if (typeof a !== 'object' || typeof b !== 'object' || Object.getPrototypeOf(a) !== Object.prototype || !Object.isFrozen(a) || Object.getPrototypeOf(b) !== Object.prototype || !Object.isFrozen(b)) return false; const k = Object.keys(a); return k.length === Object.keys(b).length && k.every((x) => x in b && $deq(a[x], b[x])); };",
  // hashCode: the app's own getter; records combine their fields (in key
  // order, so `(a: 1, b: 2)` and `(b: 2, a: 1)` agree); a number, string or
  // bool by value; any other object by an id of its own (what Dart's
  // identity hash is). The numbers are not Dart's.
  r'$hash':
      r"const $hash = (() => { const ids = new WeakMap(); let next = 0; const h = (x) => { if (x == null) return 0; switch (typeof x) { case 'number': return Number.isInteger(x) ? (x | 0) ^ ((x / 4294967296) | 0) : h(String(x)); case 'string': { let r = 7; for (let i = 0; i < x.length; i++) r = (Math.imul(r, 31) + x.charCodeAt(i)) | 0; return r; } case 'boolean': return x ? 1231 : 1237; case 'bigint': return h(String(x)); } if (typeof x.hashCode === 'number') return x.hashCode; if (Object.getPrototypeOf(x) === Object.prototype && Object.isFrozen(x)) return $hashAll(Object.keys(x).sort().map((k) => h(x[k]))); let i = ids.get(x); if (i === undefined) ids.set(x, (i = ++next)); return i; }; return h; })();",
  // Object.hash / hashAll / hashAllUnordered.
  r'$hashAll':
      r'const $hashAll = (l) => { let r = 17; for (const x of l) r = (Math.imul(r, 31) + $hash(x)) | 0; return r; };',
  r'$hashSum':
      r'const $hashSum = (l) => { let r = 0; for (const x of l) r = (r + $hash(x)) | 0; return r; };',
  // A Map and a Set whose keys compare with `==` (records, classes of the
  // app with `operator ==`): the first key equal to a new one stands for it
  // (found by hashCode, then `==`), and the JS collection holds that one,
  // so size, order and iteration are the plain ones. A key that no stored
  // one equals (a key changed after it went in: its hash moved) is not
  // found, as in Dart (`{}` stands for it: equal to nothing).
  r'$HM':
      r'class $HM extends Map { $c(k, add) { const b = (this.$b ??= new Map()), h = $hash(k), l = b.get(h); if (l) for (const e of l) if ($deq(e, k)) return e; if (add) l ? l.push(k) : b.set(h, [k]); return add ? k : {}; } get(k) { return super.get(this.$c(k)); } has(k) { return super.has(this.$c(k)); } set(k, v) { return super.set(this.$c(k, true), v); } delete(k) { const c = this.$c(k); if (!super.delete(c)) return false; const h = $hash(c), l = this.$b.get(h); l.splice(l.indexOf(c), 1); if (!l.length) this.$b.delete(h); return true; } clear() { this.$b?.clear(); super.clear(); } }',
  r'$HS':
      r'class $HS extends Set { $c(k, add) { const b = (this.$b ??= new Map()), h = $hash(k), l = b.get(h); if (l) for (const e of l) if ($deq(e, k)) return e; if (add) l ? l.push(k) : b.set(h, [k]); return add ? k : {}; } add(k) { return super.add(this.$c(k, true)); } has(k) { return super.has(this.$c(k)); } delete(k) { const c = this.$c(k); if (!super.delete(c)) return false; const h = $hash(c), l = this.$b.get(h); l.splice(l.indexOf(c), 1); if (!l.length) this.$b.delete(h); return true; } clear() { this.$b?.clear(); super.clear(); } }',
  // List.indexOf / lastIndexOf / remove / contains with `==` by value
  // (the element on the left, as Dart's).
  r'$ixeq':
      r'const $ixeq = (l, v, s = 0) => { for (let i = s; i < l.length; i++) if ($deq(l[i], v)) return i; return -1; };',
  r'$lixeq':
      r'const $lixeq = (l, v, s = l.length - 1) => { for (let i = Math.min(s, l.length - 1); i >= 0; i--) if ($deq(l[i], v)) return i; return -1; };',
  // A signal of a date type is set like Dart's (`==` by value: an equal
  // DateTime notifies nobody); the runtime's signals compare by identity.
  r'$sset':
      r'const $sset = (s, v) => { if (!$deq(s.peek(), v)) s.value = v; };',
  // StateSignal.addListener / removeListener: an effect that skips its first
  // run and calls the listener untracked. Made inside `onHydrated` it belongs
  // to the state and stops with it; a disposed state's signals refuse it.
  r'$addL':
      r"const $addL = (s, f) => { if (s.off) throw Error('thor: addListener on a disposed state'); let x = 1; (s.L ||= []).push([f, thor.effect(() => { s.value; x ? (x = 0) : thor.untracked(f); })]); };",
  r'$rmL':
      r'const $rmL = (s, f) => { const i = s.L ? s.L.findIndex((p) => p[0] === f) : -1; if (i >= 0) thor.stop(s.L.splice(i, 1)[0][1]); };',
  r'$C': r'const $C = thor.ctl;',
  // query(fn): the part `query` (fetch to the page, four signals).
  r'$Q': r'const $Q = thor.query;',
  // command(fn): the part `server_command` (fetch to the page, then the
  // page's queries get the new values from the same answer).
  r'$SC': r'const $SC = thor.command;',
  // events(url): the part `events` (a query an EventSource keeps current).
  r'$EV': r'const $EV = thor.events;',
  // dart:async's Timer on the browser's timers (Dart on the web does the
  // same): a negative duration is 0; `tick` counts the calls.
  r'$Timer':
      r'class $Timer { constructor(d, f, p) { const ms = Math.max(0, d.inMilliseconds); this.t = 0; this.p = p; this.h = p ? setInterval(() => { this.t++; f(this); }, ms) : setTimeout(() => { this.h = null; this.t = 1; f(); }, ms); } get tick() { return this.t; } get isActive() { return this.h != null; } cancel() { if (this.h == null) return; (this.p ? clearInterval : clearTimeout)(this.h); this.h = null; } }',
};

/// Helpers other helpers call.
const _helperDeps = {
  r'$KE': [r'$LK'],
  r'$Completer': [r'$X'],
  r'$resplit': [r'$g'],
  r'$ixre': [r'$g'],
  r'$mupd': [r'$X'],
  r'$deq': [r'$req'],
  r'$req': [r'$deq'],
  r'$hash': [r'$hashAll'],
  r'$hashAll': [r'$hash'],
  r'$HM': [r'$hash', r'$deq'],
  r'$HS': [r'$hash', r'$deq'],
  r'$ixeq': [r'$deq'],
  r'$lixeq': [r'$deq'],
  r'$int': [r'$X'],
  r'$double': [r'$X'],
  r'$idiv': [r'$X'],
  r'$ins': [r'$X'],
  r'$cu': [r'$ix'],
  r'$tk': [r'$X'],
  r'$first': [r'$X'],
  r'$last': [r'$X'],
  r'$join': [r'$str'],
  r'$ix': [r'$X'],
  r'$at': [r'$ix'],
  r'$atq': [r'$at'],
  r'$nn': [r'$X'],
  r'$cast': [r'$X'],
  r'$single': [r'$X'],
  r'$reduce': [r'$X'],
  r'$rerr': [r'$X'],
  r'$sub': [r'$rerr'],
  r'$rem': [r'$X'],
  r'$pop': [r'$ix'],
  r'$byName': [r'$X'],
  r'$json': [r'$X'],
  r'$dtp': [r'$X', r'$DT'],
  r'$cme': [r'$X'],
  r'$iter': [r'$cme'],
  r'$each': [r'$cme'],
  r'$ro': [r'$X'],
  r'$jenc': [r'$jerr'],
  r'$jerr': [r'$X'],
  r'$maxmin': [r'$X'],
  r'$go': [r'$X'],
};

/// The runtime parts each helper needs, in load order.
const _helperParts = {
  r'$DT': ['datetime'],
  r'$Dur': ['duration'],
  r'$TOD': ['time_of_day'],
  r'$DU': ['datetime', 'date_utils'],
  r'$life': ['lifecycle'],
  // `m.value[k]` of a map state (no item: the runtime's `key`).
  r'$mapKeys': ['map_keys'],
  r'$addL': ['lifecycle'],
  r'$rmL': ['lifecycle'],
  r'$C': ['controllers'],
  r'$Cdialog': ['dialog_controller'],
  r'$Cfocus': ['focus_node'],
  r'$Ctext': ['text_controller'],
  r'$Cscroll': ['scroll_controller'],
  r'$Cpage': ['scroll_controller', 'page_controller'],
  r'$Canim': ['animation_controller'],
  r'$clip': ['clipboard'],
  r'$frame': ['frame_messages'],
  r'$keys': ['shortcuts'],
  r'$I': ['intl'],
  r'$Q': ['query', 'server_call', 'json'],
  r'$EV': ['events', 'query', 'server_call', 'json', 'lifecycle'],
  r'$SC': ['server_command', 'server_call', 'json'],
  r'$json': ['json'],
  r'$jenc': ['json'],
  r'$persist': ['json'],
  r'$local': ['local_storage', 'json'],
};

/// Value types of the date parts: Dart's `==` compares them by value.
const _dateTypes = {
  'DateTime',
  'Duration',
  'TimeOfDay',
  'TextSelection',
  'TextEditingValue',
};

/// Controller field types → the `controllers` part's factory.
const _controllers = {
  'DialogController': 'dialog',
  'FocusNode': 'focus',
  'TextEditingController': 'text',
  'ScrollController': 'scroll',
  'PageController': 'page',
  'AnimationController': 'anim',
};

/// Members of the `dates` and `controllers` types the parts implement with
/// Dart's names: getters and methods.
const _valueGetters = {
  'DateTime': {
    'year', 'month', 'day', 'hour', 'minute', 'second', 'millisecond', //
    'microsecond', 'weekday', 'isUtc', 'millisecondsSinceEpoch',
    'microsecondsSinceEpoch', 'timeZoneOffset',
  },
  'Duration': {
    'inDays', 'inHours', 'inMinutes', 'inSeconds', 'inMilliseconds', //
    'inMicroseconds', 'isNegative',
  },
  'TimeOfDay': {'hour', 'minute', 'period', 'hourOfPeriod', 'periodOffset'},
  'DialogController': {'isOpen'},
  'FocusNode': {'hasFocus'},
  'TextEditingController': {'text', 'selection', 'value'},
  'TextEditingValue': {'text', 'selection'},
  'TextSelection': {
    'baseOffset', 'extentOffset', 'start', 'end', 'isCollapsed', 'isValid', //
  },
  'ScrollController': {'offset', 'position', 'hasClients'},
  // The details of a GestureDetector callback (plain objects of the page).
  'Offset': {'dx', 'dy'},
  'TapDownDetails': {'localPosition'},
  'TapUpDetails': {'localPosition'},
  'DragUpdateDetails': {'delta'},
  'DragEndDetails': {
    'velocity', 'primaryVelocity', 'localPosition', 'globalPosition', //
  },
  'Velocity': {'pixelsPerSecond'},
  'PageController': {
    'offset', 'position', 'hasClients', 'page', 'initialPage', //
  },
  'ScrollPosition': {'pixels', 'viewportDimension', 'maxScrollExtent'},
  'Locale': {'languageCode', 'scriptCode', 'countryCode'},
  'AnimationController': {
    'value', 'status', 'isAnimating', 'isCompleted', 'isDismissed', //
    'isForwardOrCompleted', 'lowerBound', 'upperBound', 'duration',
    'reverseDuration', 'debugLabel',
  },
  // Focus.onKeyEvent's event (`$KE`) and its key (`$LK`).
  'KeyEvent': {'logicalKey', 'character'},
  'KeyDownEvent': {'logicalKey', 'character'},
  'KeyRepeatEvent': {'logicalKey', 'character'},
  'KeyUpEvent': {'logicalKey', 'character'},
  'LogicalKeyboardKey': {'keyLabel'},
};

/// thor's `LogicalKeyboardKey` constants and their key labels.
final _logicalKeys = {
  for (final n in [
    'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Enter', 'Escape', //
    'Tab', 'Backspace', 'Delete', 'Home', 'End', 'PageUp', 'PageDown',
  ])
    '${n[0].toLowerCase()}${n.substring(1)}': n,
  'space': ' ',
  'f2': 'F2',
  for (var c = 0; c < 26; c++)
    'key${String.fromCharCode(65 + c)}': String.fromCharCode(97 + c),
  for (var d = 0; d < 10; d++) 'digit$d': '$d',
  'slash': '/',
  'period': '.',
  'comma': ',',
  'minus': '-',
};

const _valueMethods = {
  'DateTime': {
    'add', 'subtract', 'difference', 'isBefore', 'isAfter', //
    'isAtSameMomentAs', 'compareTo', 'toUtc', 'toLocal', 'toIso8601String',
    'copyWith',
  },
  'Duration': {'abs', 'compareTo'},
  'TimeOfDay': {
    'replacing', 'isBefore', 'isAfter', 'isAtSameTimeAs', 'compareTo', //
  },
  'DialogController': {'open', 'close'},
  'FocusNode': {
    'requestFocus', 'unfocus', 'addListener', 'removeListener', 'dispose', //
  },
  'TextEditingController': {'clear'},
  'TextEditingValue': {'copyWith'},
  'ScrollController': {'jumpTo', 'animateTo'},
  'PageController': {'jumpTo', 'animateTo', 'jumpToPage', 'animateToPage'},
  'Locale': {'toLanguageTag', 'toString'},
  'AnimationController': {
    'forward', 'reverse', 'toggle', 'repeat', 'stop', 'reset', 'dispose', //
  },
};

/// Static constants of those types.
const _valueStatics = {
  'DateTime': {
    'monday': '1', 'tuesday': '2', 'wednesday': '3', 'thursday': '4', //
    'friday': '5', 'saturday': '6', 'sunday': '7', 'daysPerWeek': '7',
    'january': '1', 'february': '2', 'march': '3', 'april': '4', 'may': '5',
    'june': '6', 'july': '7', 'august': '8', 'september': '9',
    'october': '10', 'november': '11', 'december': '12',
    'monthsPerYear': '12',
  },
  'Duration': {
    'zero': r'$Dur.zero', 'microsecondsPerMillisecond': '1000', //
    'microsecondsPerSecond': '1000000', 'microsecondsPerMinute': '60000000',
    'microsecondsPerHour': '3600000000', 'microsecondsPerDay': '86400000000',
    'millisecondsPerSecond': '1000', 'millisecondsPerMinute': '60000',
    'millisecondsPerHour': '3600000', 'millisecondsPerDay': '86400000',
    'secondsPerMinute': '60', 'secondsPerHour': '3600',
    'secondsPerDay': '86400', 'minutesPerHour': '60', 'minutesPerDay': '1440',
    'hoursPerDay': '24',
  },
  'TimeOfDay': {
    'hoursPerDay': '24',
    'hoursPerPeriod': '12',
    'minutesPerHour': '60',
  },
};

/// dart:math functions that are JS's `Math` ones with the same numbers (Dart
/// on the web calls them).
const _math = {
  'min', 'max', 'sqrt', 'pow', 'exp', 'log', 'sin', 'cos', 'tan', 'asin', //
  'acos', 'atan', 'atan2',
};

/// Globals the output may name (short names skip them).
const _globals = {
  'thor', 'document', 'window', 'location', 'history', 'navigator', //
  'console', 'setTimeout', 'setInterval', 'clearTimeout', 'clearInterval',
  'queueMicrotask', 'Promise', 'Math', 'Number', 'String', 'Object',
  'Array', 'JSON', 'Set', 'Map', 'RegExp', 'Error', 'RangeError',
  'TypeError', 'Infinity', 'NaN', 'undefined', 'encodeURIComponent',
  'decodeURIComponent', 'encodeURI', 'decodeURI', 'parseFloat', 'parseInt',
  'isNaN', 'isFinite', 'Symbol', 'Boolean', 'Date', 'Intl', 'globalThis',
  'self', 'performance', 'requestAnimationFrame', 'D', 'W', 'T',
};

/// More globals of JS and of the browser an app name must not shadow
/// (see `_Translator._ident`).
const _moreGlobals = {
  'Reflect', 'Proxy', 'WeakMap', 'WeakSet', 'WeakRef', 'BigInt', 'Function', //
  'Iterator', 'EvalError', 'SyntaxError', 'ReferenceError', 'URIError',
  'AggregateError', 'ArrayBuffer', 'DataView', 'Uint8Array', 'Int32Array',
  'Float64Array', 'Atomics', 'URL', 'URLSearchParams', 'fetch', 'Node',
  'Element', 'Event', 'EventTarget', 'HTMLElement', 'FormData', 'Blob', 'File',
  'Request', 'Response', 'Headers', 'AbortController', 'XMLHttpRequest',
  'localStorage', 'sessionStorage', 'crypto', 'structuredClone', //
  'TextEncoder', 'TextDecoder',
};

/// Enums of thor the translator knows (emitted like the app's, on use).
const _thorEnums = {
  'DayPeriod',
  'DatePickerMode',
  'AnimationStatus',
  'SwipeDirection',
  'DismissDirection',
  'ServerErrorKind',
  'ConnectionState',
  'ToastKind',
  'KeyEventResult',
};

class _Translator {
  _Translator(
    this.units, {
    this.shortNames = false,
    bool? checks,
    this.dataClasses = const {},
    this.dataMembers = const {},
  }) : checks = checks ?? !shortNames;

  /// Classes that travel to the browser without a state in [units] (see
  /// [translateLiteStates]).
  final Set<String> dataClasses;

  /// Members the states outside [units] call.
  final Set<String> dataMembers;

  final bool shortNames;

  /// Whether the Dart checks are emitted (`thor dev`) or dropped (release).
  final bool checks;

  /// Short names given to locals (by element) and to the members of the
  /// state being written (by name).
  final _locals = <Element, String>{};
  var _stateNames = <String, String>{};
  var _next = 0;

  /// The next short name, skipping keywords and the globals the output
  /// uses.
  String _shortName() {
    for (;;) {
      var n = _next++;
      const first = r'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_';
      const rest =
          r'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789';
      final b = StringBuffer(first[n % first.length]);
      n ~/= first.length;
      while (n > 0) {
        n--;
        b.write(rest[n % rest.length]);
        n ~/= rest.length;
      }
      final name = '$b';
      if (!_jsReserved.contains(name) && !_globals.contains(name)) return name;
    }
  }

  /// A local's (or parameter's) JS name.
  String _local(Element? e, String name) {
    if (!shortNames || e == null) return _ident(name);
    return _locals.putIfAbsent(e.baseElement, _shortName);
  }

  /// A member of the state being written, by its Dart name.
  String _stateName(String name) =>
      shortNames ? _stateNames.putIfAbsent(name, _shortName) : _mangle(name);

  final List<LiteUnit> units;
  final errors = <LiteError>[];
  final decls = <Element, _Decl>{};
  final states = <ClassDeclaration>[];
  final needed = <Element>{};
  final used = <String>{};
  final hoisted = <String, String>{}; // code → name
  final topNames = <Element, String>{};

  /// Names of the app's class members something reachable uses (a class
  /// keeps only those; toString and compareTo are called by JS itself).
  final _memberNames = <String>{'toString', 'compareTo'};

  /// Whether the code makes records (the equality helper compares them only
  /// then).
  var _recordsMade = false;

  /// The mixins the states use: their members are written inside each state,
  /// so a plain class can not mix them in.
  final _stateMixins = <Element>{};

  /// Factory constructors something reachable calls.
  final _ctors = <Element>{};

  /// Enums of thor used by the states (`DayPeriod`) → their JS name.
  final thorEnums = <EnumElement, String>{};
  late LiteUnit _unit;
  var _tmp = 0;
  String? _cascade;

  /// Where an unlabeled `break` goes: the label of a lowered switch, or
  /// null for the nearest JS loop/switch.
  final _breaks = <String?>[];

  String run(String header) {
    var order = 0;
    for (final u in units) {
      for (final d in u.unit.declarations) {
        switch (d) {
          case ClassDeclaration():
            final e = d.declaredFragment?.element;
            if (e == null) continue;
            decls[e] = _Decl(d, u, order++);
            final superclass = d.extendsClause?.superclass;
            final thorState = switch (superclass?.element) {
              final ClassElement c =>
                c.name == 'ThorState' &&
                    c.library.uri.toString().startsWith('package:thor_engine/'),
              _ => false,
            };
            if (thorState) states.add(d);
          case EnumDeclaration():
            final e = d.declaredFragment?.element;
            if (e != null) decls[e] = _Decl(d, u, order++);
          case MixinDeclaration():
            final e = d.declaredFragment?.element;
            if (e != null) decls[e] = _Decl(d, u, order++);
          case FunctionDeclaration():
            final e = d.declaredFragment?.element;
            if (e != null) decls[e] = _Decl(d, u, order++);
          case TopLevelVariableDeclaration():
            for (final v in d.variables.variables) {
              final e = v.declaredFragment?.element;
              if (e != null) decls[e] = _Decl(v, u, order++);
            }
          case ExtensionDeclaration():
            final e = d.declaredFragment?.element;
            if (e != null) decls[e] = _Decl(d, u, order++);
          default:
        }
      }
    }
    // What the states use, transitively (not their generated bases). A
    // class comes with its constructors and instance fields; its methods,
    // getters, static fields and factories only when something reachable
    // names them (by name: an override is kept with the member it
    // overrides), so a class's unused members may be outside the subset
    // (generated messages: only the ones a state calls).
    final bases = {for (final s in states) s.extendsClause?.superclass.element};
    // The mixins of the states are written inside each state.
    final stateMixins = _stateMixins
      ..addAll({
        for (final s in states)
          for (final t in s.declaredFragment!.element.mixins) t.element,
      });
    final work = <AstNode>[
      for (final s in states) s,
      for (final m in stateMixins)
        if (decls[m] case final d?) d.node,
    ];
    _memberNames.addAll(dataMembers);
    final byName = <String, List<AstNode>>{};
    final byCtor = <Element, AstNode>{};
    void queueMember(String name, AstNode node) {
      if (_memberNames.contains(name)) {
        work.add(node);
      } else {
        byName.putIfAbsent(name, () => []).add(node);
      }
    }

    void open(AstNode node) {
      final List<ClassMember> members;
      switch (node) {
        case ClassDeclaration():
          if (node.extendsClause case final x?) work.add(x);
          if (node.withClause case final x?) work.add(x);
          members = node.body.members;
        case MixinDeclaration():
          if (node.onClause case final x?) work.add(x);
          members = node.body.members;
        case EnumDeclaration():
          work.addAll(node.body.constants);
          members = node.body.members;
        default:
          work.add(node);
          return;
      }
      for (final m in members) {
        switch (m) {
          case ConstructorDeclaration(factoryKeyword: _?):
            final c = m.declaredFragment?.element;
            if (c == null || _ctors.contains(c)) {
              work.add(m);
            } else {
              byCtor[c] = m;
            }
          case FieldDeclaration(isStatic: true):
            for (final v in m.fields.variables) {
              if (_isCurveType(v.declaredFragment?.element.type)) continue;
              queueMember(v.name.lexeme, v);
            }
          case MethodDeclaration()
              when !m.isOperator && m.name.lexeme != 'hashCode':
            queueMember(m.name.lexeme, m);
          default:
            work.add(m);
        }
      }
    }

    // The classes a state of another library holds (see [dataClasses]):
    // as a `state(...)` field's, with `fromJson` and `toJson`.
    for (final e in decls.keys) {
      if (e is! ClassElement || !dataClasses.contains(e.name)) continue;
      if (e.getNamedConstructor('fromJson') case final ctor?) {
        _ctors.add(ctor);
        if (needed.add(e)) open(decls[e]!.node);
        if (_memberNames.add('toJson')) {
          work.addAll(byName.remove('toJson') ?? const []);
        }
      }
    }
    // A query's argument class goes to the server with its `toJson` and
    // comes back (the page's state) with its `fromJson`.
    for (final st in states) {
      for (final f in st.declaredFragment!.element.fields) {
        final t = f.type;
        if (!isServerQueryType(t)) continue;
        final arg = (t as InterfaceType).typeArguments.first;
        if (arg is! InterfaceType || !decls.containsKey(arg.element)) continue;
        if (arg.element.getNamedConstructor('fromJson') case final ctor?) {
          _ctors.add(ctor);
          if (needed.add(arg.element)) open(decls[arg.element]!.node);
          if (_memberNames.add('toJson')) {
            work.addAll(byName.remove('toJson') ?? const []);
          }
        }
      }
    }
    // The same for a `state(...)` field that holds a class of the app (or a
    // list or map of them): it comes back from the server's JSON with its
    // `fromJson` and goes out (a cookie, the dev reload) with its `toJson`.
    for (final st in states) {
      for (final f in st.declaredFragment!.element.fields) {
        final t = f.type;
        if (t is! InterfaceType || t.element.name != 'StateSignal') continue;
        final data = jsonStateModel(t.typeArguments.single);
        if (data == null) continue;
        if (!decls.containsKey(data.element)) {
          // The class the builder registers too: its source must be among
          // the units, or the field would reach the page undecoded.
          if (_fieldNode(st, f.name) case final at?) {
            _unit = decls[st.declaredFragment!.element]!.unit;
            _fail(
              at,
              '$dataClassSourceMissing: ${data.element.name} '
              '(${data.element.library.uri}) has toJson() and fromJson, so '
              'the field is read back with them, but its source is not part '
              'of the translated code.',
            );
          }
          continue;
        }
        if (data.element.getNamedConstructor('fromJson') case final ctor?) {
          _ctors.add(ctor);
          if (needed.add(data.element)) open(decls[data.element]!.node);
          if (_memberNames.add('toJson')) {
            work.addAll(byName.remove('toJson') ?? const []);
          }
        }
      }
    }
    // A query's (or a command's) result class comes back from JSON with
    // its `fromJson`.
    for (final st in states) {
      for (final f in st.declaredFragment!.element.fields) {
        final t = f.type;
        final DartType? result;
        if (isServerQueryType(t)) {
          result = (t as InterfaceType).typeArguments[1];
        } else if (isServerCommandType(t)) {
          result = commandTypes(t as InterfaceType).$2;
        } else if (isServerEventStreamType(t)) {
          result = (t as InterfaceType).typeArguments.single;
        } else {
          result = null;
        }
        if (result == null) continue;
        var data = result;
        if (data is InterfaceType && data.isDartCoreList) {
          data = data.typeArguments.single;
        }
        if (data is! InterfaceType || !decls.containsKey(data.element)) {
          continue;
        }
        final ctor = data.element.getNamedConstructor('fromJson');
        if (ctor == null) continue;
        _ctors.add(ctor);
        if (needed.add(data.element)) open(decls[data.element]!.node);
      }
    }
    // A conditional import or export (`if (dart.library.js_interop) …`)
    // picks its file at build time in Dart; the analyzer's pick is not what
    // the browser would run.
    final configured = <LibraryElement, (Directive, LiteUnit)>{};
    for (final u in units) {
      for (final d in u.unit.directives) {
        final target = switch (d) {
          ImportDirective(configurations: [_, ...]) =>
            d.libraryImport?.importedLibrary,
          ExportDirective(configurations: [_, ...]) =>
            d.libraryExport?.exportedLibrary,
          _ => null,
        };
        if (target != null) configured[target] = (d, u);
      }
    }
    final conditionalReported = <Directive>{};
    while (work.isNotEmpty) {
      final node = work.removeLast();
      final refs = _References();
      node.accept(refs);
      for (final e in refs.elements) {
        final base = e.baseElement;
        final cond = base.library == null ? null : configured[base.library];
        if (cond != null &&
            decls.containsKey(_topOf(base)) &&
            conditionalReported.add(cond.$1)) {
          final (d, u) = cond;
          _unit = u;
          _fail(
            d,
            'A conditional import or export (`if (dart.library…)`) is not in '
            'the lite subset: the browser would run another file than the '
            'one analyzed. Import the file for the web directly, or move the '
            'work to a query()/command() on the server.',
          );
        }
        // jsonEncode calls toJson on the app's objects.
        if (base is TopLevelFunctionElement &&
            base.name == 'jsonEncode' &&
            '${base.library.uri}' == 'dart:convert' &&
            _memberNames.add('toJson')) {
          work.addAll(byName.remove('toJson') ?? const []);
        }
        final owner = base.enclosingElement;
        if (owner is InterfaceElement && decls.containsKey(owner)) {
          if (base is ConstructorElement) {
            if (_ctors.add(base)) {
              if (byCtor.remove(base) case final n?) work.add(n);
            }
          } else if (base.name case final raw?) {
            final n = raw.endsWith('=')
                ? raw.substring(0, raw.length - 1)
                : raw;
            if (_memberNames.add(n)) work.addAll(byName.remove(n) ?? const []);
          }
        }
        final top = _topOf(e);
        if (top == null || !decls.containsKey(top)) continue;
        // A curve is compiled to CSS where an animation takes it.
        if (top is TopLevelVariableElement && _isCurveType(top.type)) continue;
        if (_isStateClass(top) ||
            _stateInstance(top) != null ||
            bases.contains(top) ||
            stateMixins.contains(top)) {
          continue;
        }
        if (needed.add(top)) open(decls[top]!.node);
      }
    }
    // JS names for top-level declarations (unique across libraries).
    final taken = <String>{};
    for (final e
        in needed.toList()
          ..sort((a, b) => decls[a]!.order.compareTo(decls[b]!.order))) {
      if (shortNames) {
        topNames[e] = _shortName();
        continue;
      }
      // An unnamed extension (`extension on X {}`) is named by its order.
      // An unnamed extension (`extension on X {}`) is named by its order.
      final n = _ident(e.name ?? 'ext${decls[e]!.order}');
      var candidate = n;
      for (var i = 2; taken.contains(candidate); i++) {
        candidate = '$n\$$i';
      }
      taken.add(candidate);
      topNames[e] = candidate;
    }

    final sorted = _bySuperclass(
      needed.toList()
        ..sort((a, b) => decls[a]!.order.compareTo(decls[b]!.order)),
    );
    final enums = <String>[], classes = <String>[], fns = <String>[];
    final vars = <String>[], consts = <String>[];
    for (final e in sorted) {
      final d = decls[e]!;
      _unit = d.unit;
      switch (d.node) {
        case final EnumDeclaration n:
          enums.add(_enum(n));
        case final ClassDeclaration n:
          classes.add(_class(n));
        case final MixinDeclaration n:
          classes.add(_mixin(n));
        case final FunctionDeclaration n:
          fns.add(_topFunction(n));
        case final ExtensionDeclaration n:
          fns.add(_extension(n));
        case final VariableDeclaration n:
          ((n.parent as VariableDeclarationList).isConst ? consts : vars).add(
            _topVariable(n),
          );
      }
    }
    final defs = <String>[];
    for (final s in states) {
      _unit = units.firstWhere((u) => u.unit == s.root);
      defs.add(_state(s));
    }
    // `row.text((o) => o.customer)`: one reader per property the app's
    // lambdas read (the server binds `$Rows.customer`; see row_lambdas.dart).
    final rowProperties = {
      for (final u in units)
        for (final l in rowLambdasIn(u.unit, u.path))
          if (l.property != null) l.property!,
    }.toList()..sort();
    if (rowProperties.isNotEmpty) {
      defs.add(
        "thor.def('\$Rows', (\$) => ({\n"
        '${[for (final p in rowProperties) "  $p: (it) => it.${_mangle(p)},"].join('\n')}\n'
        '  \$s: {},\n'
        '}));',
      );
    }
    if (errors.isNotEmpty) throw LiteTranslationException(errors);
    for (final e in thorEnums.entries) {
      enums.add(
        _enumArrays(e.value, e.key.name!, [
          for (final c in e.key.constants) c.name!,
        ]),
      );
      // The `query` and `command` parts set `errorKind` from these values.
      if (e.key.name == 'ServerErrorKind') {
        enums.add('thor.K = ${e.value}\$values;');
      }
      // ... and `snapshot` its `connectionState` from these.
      if (e.key.name == 'ConnectionState') {
        enums.add('thor.CS = ${e.value}\$values;');
      }
    }
    for (var grew = true; grew;) {
      grew = false;
      for (final h in [...used]) {
        for (final d in _helperDeps[h] ?? const <String>[]) {
          grew |= used.add(d);
        }
      }
    }
    final out = StringBuffer(header);
    // The optional runtime parts the states need (thor_engine's lite
    // bundle sews packages/thor_engine/lib/lite/parts/<part>.js into the
    // runtime before this file).
    final parts = {for (final h in used) ...?_helperParts[h]};
    out.writeln(_partsMark);
    out.writeln('{');
    for (final h in _helpers.keys) {
      if (!used.contains(h)) continue;
      // Without records, `$deq` has no `$req` to ask.
      if (h == r'$req' && !_recordsMade) continue;
      out.writeln('$_itemMark\n  ${h == r'$deq' ? _deq() : _helpers[h]}');
    }
    for (final part in [
      ...enums,
      ...classes,
      ..._constsInOrder([
        ...consts,
        for (final h in hoisted.entries) 'const ${h.value} = ${h.key};',
      ]),
      ...fns,
      ...vars,
      ...defs,
    ]) {
      out.writeln('$_itemMark\n${_indent(part, '  ')}');
    }
    out.writeln('}');
    final code = '$out';
    // The `json` part (parse/str of Maps in the order of the text) is for
    // code that has Maps: the states without one keep the runtime's
    // minimal `thor.parse`.
    if (RegExp(r'\bMap\b|\.get\(').hasMatch(code)) parts.add('json');
    final list = parts.toList()..sort();
    // The part(s) behind each helper that has one: a page of a static site
    // that keeps only some of the items (thor_engine's lite_site) ships
    // only the parts of the helpers it kept.
    final helperParts = [
      for (final h in used.toList()..sort())
        if (_helperParts[h] case final ps?) '$h=${ps.join(',')}',
    ];
    return code.replaceFirst(
      '$_partsMark\n',
      list.isEmpty
          ? ''
          : '// thor-lite parts: ${list.join(' ')}\n'
                '// thor-lite helper-parts: ${helperParts.join(' ')}\n',
    );
  }

  /// The helpers without an item the state being translated uses.
  final _statePseudo = <String>{};

  static const _partsMark = '\u0000P';

  /// Before each top-level item of the file (a helper, a class, a function,
  /// a state): where thor_engine's lite_site splits it.
  static const _itemMark = '  // @item';

  /// `$deq` with only the questions this app can ask: the `$eq` method of a
  /// class with `operator ==`, the `eq` of the date and locale values, and
  /// the fields of a record.
  String _deq() {
    final userEq = needed.whereType<InterfaceElement>().any(_declaresEq);
    // A date or locale value can only come from code that names its type.
    final values =
        const [r'$DT', r'$Dur', r'$TOD', r'$Loc'].any(used.contains) ||
        units.any(
          (u) => RegExp(
            r'\b(DateTime|Duration|TimeOfDay|Locale|TextSelection)\b',
          ).hasMatch(u.unit.declaredFragment?.source.contents.data ?? ''),
        );
    return 'const \$deq = (a, b) => { if (a == null || b == null) return a == b; '
        "${userEq ? "if (typeof a.\$eq === 'function') return a.\$eq(b); " : ''}"
        'if (a === b) return true; '
        "${values ? "if (typeof a.eq === 'function') return a.eq(b); " : ''}"
        'return ${_recordsMade ? r'$req(a, b)' : 'false'}; };';
  }

  String _indent(String s, String by) =>
      s.split('\n').map((l) => l.isEmpty ? l : '$by$l').join('\n');

  // -------------------------------------------------------------------------
  // Errors.

  /// Where [node] is reported: its start, except a call or member access on
  /// a chain that starts on an earlier line, which points at the member that
  /// fails (`.cast` in `l\n  .where(…)\n  .cast<int>()`).
  int _placeOf(AstNode node) {
    final SimpleIdentifier? name = switch (node) {
      MethodInvocation(target: != null) => node.methodName,
      PropertyAccess() => node.propertyName,
      PrefixedIdentifier() => node.identifier,
      _ => null,
    };
    if (name == null) return node.offset;
    final info = _unit.unit.lineInfo;
    return info.getLocation(name.offset).lineNumber ==
            info.getLocation(node.offset).lineNumber
        ? node.offset
        : name.offset;
  }

  /// The declaration of the field [name] in state [c], if it has one.
  AstNode? _fieldNode(ClassDeclaration c, String? name) {
    for (final m in c.body.members) {
      if (m is! FieldDeclaration) continue;
      for (final v in m.fields.variables) {
        if (v.name.lexeme == name) return v;
      }
    }
    return null;
  }

  String _fail(AstNode node, String message) {
    final loc = _unit.unit.lineInfo.getLocation(_placeOf(node));
    final source = _unit.unit.declaredFragment?.source.contents.data;
    errors.add(
      LiteError(
        _unit.path,
        loc.lineNumber,
        loc.columnNumber,
        message,
        hint: liteHintFor(message, node),
        frame: source == null
            ? ''
            : liteCodeFrame(source, loc.lineNumber, loc.columnNumber),
        node: node,
      ),
    );
    return '/*error*/';
  }

  String _src(AstNode node) {
    final s = node.toSource();
    return s.length > 60 ? '${s.substring(0, 57)}...' : s;
  }

  // -------------------------------------------------------------------------
  // Elements.

  String _mangle(String name) => _jsReserved.contains(name) ? '$name\$' : name;

  /// The JS name of an identifier of the app (a local, a parameter, a
  /// top-level declaration): one that is also a global the runtime or the
  /// translated code uses (`Promise`, `Date`, `document`…) would shadow it
  /// in the whole block, so it gets a `$` suffix. Members are properties
  /// (`this.name`): they can't shadow anything.
  String _ident(String name) =>
      _jsReserved.contains(name) ||
          _globals.contains(name) ||
          _moreGlobals.contains(name)
      ? '$name\$'
      : name;

  /// The top-level declaration [e] belongs to (itself, its class, the
  /// variable of a getter).
  Element? _topOf(Element? e) {
    if (e == null) return null;
    e = e.baseElement;
    if (e is PropertyAccessorElement) {
      final v = e.variable;
      if (v is TopLevelVariableElement) return v;
      final enclosing = v.enclosingElement;
      return enclosing is InterfaceElement || enclosing is ExtensionElement
          ? enclosing
          : null;
    }
    if (e is TopLevelVariableElement ||
        e is TopLevelFunctionElement ||
        e is ClassElement ||
        e is MixinElement ||
        e is EnumElement) {
      return e;
    }
    if (e is ConstructorElement || e is MethodElement || e is FieldElement) {
      final enclosing = e.enclosingElement;
      return enclosing is InterfaceElement || enclosing is ExtensionElement
          ? enclosing
          : null;
    }
    if (e is ExtensionElement) return e;
    return null;
  }

  /// Whether [c] is `X({super.key});` (or `X();`): an unnamed, generative
  /// constructor with no body, no initializers and at most the key.
  static bool _onlyForwardsKey(ConstructorDeclaration c) =>
      c.name == null &&
      c.factoryKeyword == null &&
      c.redirectedConstructor == null &&
      c.initializers.isEmpty &&
      c.body is EmptyFunctionBody &&
      c.parameters.parameters.every(
        (p) =>
            p is DefaultFormalParameter &&
            p.isNamed &&
            p.defaultValue == null &&
            p.parameter is SuperFormalParameter &&
            p.name?.lexeme == 'key',
      );

  bool _isStateClass(Element e) =>
      e is ClassElement && states.any((s) => s.declaredFragment?.element == e);

  /// The page id of the state held by top-level variable [e]
  /// (`final counter = CounterState();` → `CounterState`), or null.
  String? _stateInstance(Element e) {
    if (e is! TopLevelVariableElement) return null;
    final d = decls[e];
    final init = (d?.node as VariableDeclaration?)?.initializer;
    if (init is! InstanceCreationExpression) return null;
    final cls = init.constructorName.element?.enclosingElement;
    if (cls == null || !_isStateClass(cls)) return null;
    String? key;
    for (final a in init.argumentList.arguments) {
      if (a is NamedExpression && a.name.label.name == 'key') {
        final v = a.expression;
        if (v is SimpleStringLiteral) key = v.value;
      }
    }
    return key == null ? cls.name! : '${cls.name}#$key';
  }

  bool _inThor(Element? e) {
    final uri = '${e?.library?.uri}';
    // `Locale` lives in thor_server (the router routes by it).
    return uri.startsWith('package:thor_engine/') ||
        uri.startsWith('package:thor_server/') ||
        uri.startsWith('package:thor_ui/');
  }

  bool _isSignal(DartType? t) =>
      t is InterfaceType &&
      (t.element.name == 'StateSignal' ||
          t.element.name == 'Signal' ||
          t.element.name == 'ReadSignal') &&
      _inThor(t.element);

  /// `derived(() => …)` of thor_engine: the field that holds a memoized
  /// derivation (a `late final` or a plain `final`), else null.
  MethodInvocation? _derivedCall(VariableDeclaration v) {
    final init = v.initializer;
    return init is MethodInvocation &&
            init.target == null &&
            init.methodName.name == 'derived' &&
            _inThor(init.methodName.element)
        ? init
        : null;
  }

  /// The signal of `signal.value` when [e] is that read of a `StateSignal`
  /// (a `state(…)` field: a computed has no per-key read), else null.
  Expression? _stateValue(Expression e) {
    final (Expression? target, String? name) = switch (e) {
      PropertyAccess(:final realTarget, :final propertyName) => (
        realTarget,
        propertyName.name,
      ),
      PrefixedIdentifier(:final prefix, :final identifier) => (
        prefix,
        identifier.name,
      ),
      _ => (null, null),
    };
    final t = target?.staticType;
    return name == 'value' &&
            t is InterfaceType &&
            t.element.name == 'StateSignal' &&
            _inThor(t.element)
        ? target
        : null;
  }

  /// The value type of a signal type (`bool` of `StateSignal<bool>`).
  DartType? _signalValue(DartType? t) =>
      t is InterfaceType && t.typeArguments.length == 1
      ? t.typeArguments.single
      : null;

  /// The element type of a `StateSignal<Set<T>>` (a set field), else null.
  DartType? _setSignal(DartType? t) {
    final v = _signalValue(t);
    return v is InterfaceType &&
            v.element.name == 'Set' &&
            v.typeArguments.length == 1
        ? v.typeArguments.single
        : null;
  }

  /// `late final x = …;`: the one `late` field the subset translates (a
  /// getter that computes it on first read and keeps it). A `late` without
  /// an initializer is assigned somewhere else, after the class exists.
  bool _lazyField(FieldDeclaration m) =>
      m.fields.isLate &&
      m.fields.isFinal &&
      m.fields.variables.every((v) => v.initializer != null);

  /// Whether [t] is a thor_style `Curve`: compiled to CSS where an animation
  /// takes it, never written to the page.
  bool _isCurveType(DartType? t) =>
      t is InterfaceType &&
      [t, ...t.allSupertypes].any(
        (s) =>
            s.element.name == 'Curve' &&
            '${s.element.library.uri}'.startsWith('package:thor_style/'),
      );

  bool _isController(DartType? t) =>
      t is InterfaceType &&
      t.allSupertypes.any((s) => s.element.name == 'ThorController');

  /// A Flutter listenable that is not a `StateSignal` (which is one too).
  bool _isNotifier(DartType? t) =>
      t is InterfaceType &&
      !_isSignal(t) &&
      [t, ...t.allSupertypes].any(
        (s) =>
            (s.element.name == 'ChangeNotifier' ||
                s.element.name == 'Listenable') &&
            _inThor(s.element),
      );

  bool _isApp(Element? e) => e != null && decls.containsKey(_topOf(e));

  // -------------------------------------------------------------------------
  // Types.

  bool _num(DartType? t) =>
      t != null && (t.isDartCoreInt || t.isDartCoreDouble || t.isDartCoreNum);
  bool _str(DartType? t) => t != null && t.isDartCoreString;
  bool _bool(DartType? t) => t != null && t.isDartCoreBool;
  bool _list(DartType? t) =>
      t is InterfaceType &&
      (t.isDartCoreList ||
          t.isDartCoreIterable ||
          t.allSupertypes.any((s) => s.isDartCoreIterable) &&
              !t.isDartCoreSet &&
              t.element.library.isDartCore);
  bool _map(DartType? t) => t != null && t.isDartCoreMap;
  bool _nullable(DartType? t) =>
      t == null ||
      t is DynamicType ||
      t.nullabilitySuffix == NullabilitySuffix.question ||
      t.isDartCoreNull;
  bool _isEnum(DartType? t) =>
      t is InterfaceType &&
      t.element is EnumElement &&
      (_isApp(t.element) ||
          _thorEnums.contains(t.element.name) && _inThor(t.element));

  /// An enum, `Enum` or a type parameter bound by it (`T extends Enum`):
  /// `index` and `name` work on all.
  bool _enumLike(DartType? t) {
    if (_isEnum(t)) return true;
    if (t is TypeParameterType) return _enumLike(t.bound);
    return t is InterfaceType &&
        t.element.name == 'Enum' &&
        t.element.library.isDartCore;
  }

  /// The name of [t] when it is one of the types of the `dates` and
  /// `controllers` parts (DateTime and Duration of dart:core, the others of
  /// thor), else null.
  String? _valueType(DartType? t) {
    if (t is! InterfaceType) return null;
    final e = t.element;
    final n = e.name;
    if (n == 'DateTime' || n == 'Duration') {
      return e.library.isDartCore ? n : null;
    }
    if (n == 'Offset') {
      return '${e.library.uri}'.startsWith('package:thor_style/') ? n : null;
    }
    return _valueGetters.containsKey(n) && _inThor(e) ? n : null;
  }

  /// Whether [t] is dart:core's StringBuffer.
  bool _stringBuffer(DartType? t) =>
      t is InterfaceType &&
      t.element.name == 'StringBuffer' &&
      t.element.library.isDartCore;

  /// Whether [t] is dart:core's RegExp (or its Pattern, when it's one).
  bool _regExp(DartType? t) =>
      t is InterfaceType &&
      t.element.name == 'RegExp' &&
      t.element.library.isDartCore;

  bool _regExpMatch(DartType? t) =>
      t is InterfaceType &&
      (t.element.name == 'RegExpMatch' || t.element.name == 'Match') &&
      t.element.library.isDartCore;

  bool _set(DartType? t) => t is InterfaceType && t.isDartCoreSet;

  /// Whether class [e] (or a superclass of the app) defines toString.
  bool _hasToString(InterfaceElement e) {
    for (InterfaceElement? c = e; c != null && _isApp(c);) {
      if (c.methods.any((m) => m.name == 'toString')) return true;
      c = c.supertype?.element;
    }
    return false;
  }

  /// Whether the elements of the iterable [t] print in a JS `join` as
  /// Dart's do: not null, not a list or set, with a toString of their own.
  bool _joinsLikeJs(DartType? t) {
    if (t is! InterfaceType || t.typeArguments.length != 1) return false;
    final el = t.typeArguments.single;
    return el.nullabilitySuffix != NullabilitySuffix.question &&
        !_list(el) &&
        !_set(el) &&
        _printable(el);
  }

  /// Whether a value of type [t] prints the same in Dart and JS (in a
  /// string, a list's `toString`).
  bool _printable(DartType t) =>
      _str(t) ||
      _num(t) ||
      _bool(t) ||
      t.isDartCoreNull ||
      _enumLike(t) ||
      _dateValue(t) ||
      _locale(t) ||
      _coreException(t) ||
      _stringBuffer(t) ||
      t is InterfaceType && _isApp(t.element) && _hasToString(t.element) ||
      (_list(t) || _set(t)) &&
          t is InterfaceType &&
          t.typeArguments.length == 1 &&
          _printable(t.typeArguments.single);

  /// A state reads `errorKind`: the browser needs `ServerErrorKind`'s values
  /// (the part finds them by name in `thor.K`).
  void _serverErrorKind(Expression whole) {
    final t = whole.staticType;
    if (t is! InterfaceType) return;
    final e = t.typeArguments.singleOrNull?.element;
    if (e is EnumElement) _enumName(e);
  }

  /// A state reads a query's `snapshot`: the browser needs the values of
  /// `ConnectionState` (the part finds them in `thor.CS`) and of
  /// `ServerErrorKind`.
  void _snapshotEnums(Expression whole) {
    final t = whole.staticType;
    if (t is! InterfaceType) return;
    for (final g in const ['connectionState', 'errorKind']) {
      final e = t.getGetter(g)?.returnType.element;
      if (e is EnumElement) _enumName(e);
    }
  }

  /// The options of an `events(url, ...)` call as the JS object the `events`
  /// part takes (`{u, e, k, m, i}`), or null after reporting what the browser
  /// can't know: it needs the url, the event name and the key as literals,
  /// and an url that stays on the page's own origin (THOR-B012).
  String? _eventsSpec(MethodInvocation init, InterfaceType type) {
    String? url, event = 'message', key;
    Expression? eventAt, keyAt;
    var ok = true, hasInitial = false;
    int? ms;
    String? literal(Expression e, String what) {
      if (e is SimpleStringLiteral) return e.value;
      _fail(
        e,
        '`events()` takes $what as a string literal: the browser needs it '
        'when it builds.',
      );
      ok = false;
      return null;
    }

    final positional = init.argumentList.arguments
        .where((a) => a is! NamedExpression)
        .toList();
    if (positional.length != 1) {
      _fail(
        init,
        '`events()` takes the url of the stream as its one argument.',
      );
      return null;
    }
    url = literal(positional.single, 'the url');
    for (final a in init.argumentList.arguments.whereType<NamedExpression>()) {
      switch (a.name.label.name) {
        case 'initial':
          hasInitial = true;
        case 'event':
          event = literal(a.expression, '`event:`');
          eventAt = a.expression;
        case 'key':
          key = literal(a.expression, '`key:`');
          keyAt = a.expression;
        case 'timeout':
          ms = _timeoutMs(init);
        default:
          _fail(
            a,
            '`events()` has no `${a.name.label.name}:` in the lite subset '
            '(event, key, initial and timeout are).',
          );
          ok = false;
      }
    }
    if (url != null &&
        (!url.startsWith('/') ||
            url.startsWith('//') ||
            RegExp(r'[\s\\\x00-\x1f]').hasMatch(url))) {
      _fail(
        positional.single,
        '`events()` opens a stream of the app: its url is a path that starts '
        'with one `/` (`/quotes/stream`), never another origin.',
      );
      ok = false;
    }
    if (event != null &&
        (event.isEmpty || RegExp(r'[\r\n\x00]').hasMatch(event))) {
      _fail(
        eventAt ?? init,
        '`event:` is not an event name: it is not empty and has no line '
        'breaks.',
      );
      ok = false;
    }
    if (key != null) {
      final data = type.typeArguments.single;
      if (!RegExp(r'^[A-Za-z_$][\w$-]*$').hasMatch(key)) {
        _fail(
          keyAt ?? init,
          '`key:` is the name of a field of the items (letters, digits, `_`, '
          '`-`; not starting with a digit).',
        );
        ok = false;
      } else if (!(data is InterfaceType && data.isDartCoreList)) {
        _fail(
          keyAt ?? init,
          '`key:` merges the items of a list: the events field is a '
          '`List<…>` and the key a field name of its items.',
        );
        ok = false;
      }
    }
    if (!ok) return null;
    String q(String v) =>
        "'${v.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";
    return '{ u: ${q(url!)}, e: ${q(event!)}, '
        'k: ${key == null ? 'null' : q(key)}, '
        'm: ${ms ?? 'null'}, i: ${hasInitial ? 1 : 0} }';
  }

  /// Whether a `query` call has `ssr: false`: the browser runs it when the
  /// page hydrates (the server draws the waiting state and never calls it).
  /// Only a literal `true` or `false` is known here.
  bool _browserOnly(MethodInvocation init) {
    final named = init.argumentList.arguments
        .whereType<NamedExpression>()
        .where((a) => a.name.label.name == 'ssr')
        .firstOrNull;
    if (named == null) return false;
    final e = named.expression;
    if (e is BooleanLiteral) return !e.value;
    _fail(
      named,
      '`ssr:` takes a literal `true` or `false`: the browser needs its value '
      'when it builds.',
    );
    return false;
  }

  /// The `timeout:` of a `query` or a `command` call in milliseconds (the
  /// browser ends the call in an error after it), or null when it has
  /// none (the browser applies the page's default, 30 s). `Duration.zero`
  /// gives 0: no timeout. Only a `Duration` of integer literals is known
  /// here.
  int? _timeoutMs(MethodInvocation init) {
    final named = init.argumentList.arguments
        .whereType<NamedExpression>()
        .where((a) => a.name.label.name == 'timeout')
        .firstOrNull;
    if (named == null) return null;
    final e = named.expression;
    var micros = 0;
    // `Duration.zero`: no timeout.
    final zero =
        e is PrefixedIdentifier &&
        e.prefix.name == 'Duration' &&
        e.identifier.name == 'zero' &&
        e.element?.library?.uri.toString() == 'dart:core';
    var ok =
        zero ||
        e is InstanceCreationExpression &&
            e.constructorName.type.name.lexeme == 'Duration' &&
            e.constructorName.name == null;
    if (ok && e is InstanceCreationExpression) {
      const units = {
        'days': 86400000000,
        'hours': 3600000000,
        'minutes': 60000000,
        'seconds': 1000000,
        'milliseconds': 1000,
        'microseconds': 1,
      };
      for (final a in e.argumentList.arguments) {
        final unit = a is NamedExpression ? units[a.name.label.name] : null;
        final v = a is NamedExpression ? a.expression : null;
        if (unit == null || v is! IntegerLiteral || v.value == null) {
          ok = false;
          break;
        }
        // No term wraps an int around (a literal of 2^63 milliseconds).
        micros += min(v.value!, _maxTimeoutMs * 1000 ~/ unit + 1) * unit;
      }
    }
    if (!ok || (micros != 0 && micros < 1000)) {
      _fail(
        named,
        '`timeout:` takes a Duration of integer literals of at least a '
        'millisecond (`Duration(seconds: 5)`) or `Duration.zero` (no '
        'timeout): the browser needs its value when it builds.',
      );
      return null;
    }
    // setTimeout holds 2^31-1 ms (about 24.8 days): a longer delay is read
    // as 0 and the call would time out at once.
    return min(micros ~/ 1000, _maxTimeoutMs);
  }

  static const _maxTimeoutMs = 2147483647;

  /// Whether [t] is dart:async's Timer.
  bool _timer(DartType? t) =>
      t is InterfaceType &&
      t.element.name == 'Timer' &&
      '${t.element.library.uri}' == 'dart:async';

  /// Whether [t] is thor's FrameSubscription (the handle of `FrameMessages.listen`).
  bool _frameSub(DartType? t) =>
      t is InterfaceType &&
      t.element.name == 'FrameSubscription' &&
      _inThor(t.element);

  /// Whether [t] is DateTime, Duration or TimeOfDay (value `==`).
  bool _dateValue(DartType? t) => _dateTypes.contains(_valueType(t));

  /// Whether [t] is thor's Locale (`==` by value, `$Loc`).
  bool _locale(DartType? t) => _valueType(t) == 'Locale';

  /// [helper]'s name, marking it (and its runtime part) used.
  String _use(String helper) {
    used.add(helper);
    if (helper == r'$enum') used.add(r'$E');
    if (helper == r'$goBack') used.addAll([r'$go', r'$canPop']);
    return helper;
  }

  bool _declaresEq(InterfaceElement c) => c.methods.any((m) => m.name == '==');
  final _hasEq = <InterfaceElement, bool>{};

  /// Whether an instance of [e] can have an `operator ==` of the app: [e]
  /// or a supertype of it declares one, or a subclass does (a variable of
  /// the base type holds it).
  bool _hasUserEq(InterfaceElement e) => _hasEq.putIfAbsent(e, () {
    if (!_isApp(e)) return false;
    if (_declaresEq(e) ||
        e.allSupertypes.any(
          (t) => _isApp(t.element) && _declaresEq(t.element),
        )) {
      return true;
    }
    return decls.keys.whereType<InterfaceElement>().any(
      (x) => _declaresEq(x) && x.allSupertypes.any((t) => t.element == e),
    );
  });

  /// Whether `==` on [t] compares by value in Dart and so needs `$deq`: the
  /// date values, a record, a class of the app with `operator ==`.
  bool _valueEq(DartType? t) =>
      _dateValue(t) ||
      _locale(t) ||
      t is RecordType ||
      t is InterfaceType && _isApp(t.element) && _hasUserEq(t.element);

  /// Whether a class of the app has an `operator ==` somewhere.
  late final bool _anyUserEq = decls.keys.whereType<InterfaceElement>().any(
    _declaresEq,
  );

  /// Whether a Set of, or a Map keyed by, [k] needs `$HS`/`$HM`: its keys
  /// compare with `==` by value (a record, a class with `operator ==`), or
  /// are typed `Object?` in an app that has such classes (a literal passed
  /// as `Set<Object?>`).
  bool _needsHash(DartType? k) =>
      k is RecordType ||
      k is InterfaceType && _isApp(k.element) && _hasUserEq(k.element) ||
      _anyUserEq && _maybeValue(k) && k is! TypeParameterType;

  /// `new Map(init)` for a map of type [t]: a `$HM` when its keys need it,
  /// or when [keys] (a literal's) do: the static type may be wider than the
  /// keys (`{Point(1, 2)}` as an `Object?` argument).
  String _newMap(
    DartType? t, [
    String init = '',
    Iterable<DartType?> keys = const [],
  ]) {
    final key = t is InterfaceType && t.typeArguments.isNotEmpty
        ? t.typeArguments.first
        : null;
    final hash = _needsHash(key) || keys.any((k) => k != null && _needsHash(k));
    return 'new ${hash ? _use(r'$HM') : 'Map'}($init)';
  }

  /// `new Set(init)` for a set of type [t] (see [_newMap]).
  String _newSet(
    DartType? t, [
    String init = '',
    Iterable<DartType?> keys = const [],
  ]) {
    final key = t is InterfaceType && t.typeArguments.isNotEmpty
        ? t.typeArguments.first
        : null;
    final hash = _needsHash(key) || keys.any((k) => k != null && _needsHash(k));
    return 'new ${hash ? _use(r'$HS') : 'Set'}($init)';
  }

  // -------------------------------------------------------------------------
  // Declarations.

  // An enum value is an object with `index` and `name` (and toString);
  // `Tab.home` is `Tab$values[0]`. An enum with members is a class of its
  // own (extending the helper `$E`) whose constructor takes the type, the
  // index and the name first.
  String _enum(EnumDeclaration n) {
    final e = n.declaredFragment!.element;
    final name = topNames[e]!;
    final consts = n.body.constants;
    if (n.withClause != null) {
      _fail(n, 'Enum ${e.name} mixes in a class: not in the lite subset.');
    }
    if (n.body.members.isEmpty) {
      return _enumArrays(name, e.name!, [
        for (final c in consts) c.name.lexeme,
      ]);
    }
    final cls = _classJs(n, e, name, n.body.members);
    final ctx = _Ctx(hoist: false);
    final values = <String>[];
    for (var i = 0; i < consts.length; i++) {
      final c = consts[i];
      if (c.arguments?.constructorSelector != null) {
        _fail(c, 'Named enum constructors are not in the lite subset.');
      }
      final args = c.arguments == null
          ? ''
          : _args(c.arguments!.argumentList, c.constructorElement, ctx);
      values.add(
        "new $name('${e.name}', $i, '${c.name.lexeme}'${args.isEmpty ? '' : ', $args'})",
      );
    }
    return '$cls\nconst $name\$values = Object.freeze([${values.join(', ')}]);';
  }

  String _enumArrays(String name, String dartName, List<String> names) =>
      "const $name\$values = ${_use(r'$enum')}('$dartName', [${names.map((n) => "'$n'").join(', ')}]);";

  /// `values` or a value of enum [e] by [name] as JS, or null.
  String? _enumValue(InterfaceElement e, String name) {
    final n = _enumName(e);
    if (n == null || e is! EnumElement) return null;
    if (name == 'values') return '$n\$values';
    final i = e.constants.indexWhere((c) => c.name == name);
    return i < 0 ? null : '$n\$values[$i]';
  }

  /// The JS name of enum [e]: the app's, or one of thor's ([_thorEnums]).
  String? _enumName(InterfaceElement e) {
    if (topNames[e] case final n?) return n;
    if (e is EnumElement && _thorEnums.contains(e.name) && _inThor(e)) {
      return thorEnums.putIfAbsent(e, () => '\$${e.name}');
    }
    return null;
  }

  String _class(ClassDeclaration n) {
    final e = n.declaredFragment!.element;
    if (n.mixinKeyword != null) {
      _fail(
        n,
        'Class ${e.name} is a `mixin class`: declare a `mixin` or a `class`.',
      );
    }
    for (final w in n.withClause?.mixinTypes ?? const <NamedType>[]) {
      final m = w.element;
      if (m is! MixinElement || !_isApp(m)) {
        _fail(
          w,
          'Class ${e.name} mixes in ${w.name.lexeme}: only a `mixin` of the '
          'app can be mixed in the lite subset.',
        );
      } else if (_stateMixins.contains(m)) {
        _fail(
          w,
          'Class ${e.name} mixes in ${w.name.lexeme}, which is used by a '
          'ThorState (its members are written inside each state): mix in '
          'another `mixin` here.',
        );
      }
    }
    final sup = n.extendsClause?.superclass.element;
    // thor's `Intent` has nothing to inherit: the class stands alone.
    final intent = sup?.name == 'Intent' && _inThor(sup);
    if (sup != null && !_isApp(sup) && !intent) {
      _fail(
        n,
        'Class ${e.name} extends ${sup.name}: only classes of the app can be '
        'extended in the lite subset.',
      );
    }
    return _classJs(n, e, topNames[e]!, n.body.members);
  }

  /// `mixin M on B { … }` as a function from a base class to the class that
  /// adds its members (`class A extends B with M1, M2` is
  /// `class A extends M2(M1(B))`: the same order of resolution as Dart's, and
  /// `super` goes to the class below).
  String _mixin(MixinDeclaration n) {
    final e = n.declaredFragment!.element;
    return _classJs(n, e, topNames[e]!, n.body.members);
  }

  /// The classes in [list] (by declaration order) with each superclass and
  /// mixin before the class that uses it: a JS class is not hoisted.
  List<Element> _bySuperclass(List<Element> list) {
    final out = <Element>[], seen = <Element>{};
    void visit(Element e) {
      if (!seen.add(e)) return;
      if (e is InterfaceElement) {
        for (final d in [
          e.supertype?.element,
          for (final m in e.mixins) m.element,
        ]) {
          // A mixin application (`B with M`) is not a declaration: its
          // parts are.
          if (d is InterfaceElement && !needed.contains(d)) {
            for (final x in [
              d.supertype?.element,
              for (final m in d.mixins) m.element,
            ]) {
              if (x != null && needed.contains(x)) visit(x);
            }
          } else if (d != null && needed.contains(d)) {
            visit(d);
          }
        }
      }
      out.add(e);
    }

    list.forEach(visit);
    return out;
  }

  /// A JS class for class or enum [n] (element [e], JS [name]); for a mixin
  /// the function that makes it from its base.
  String _classJs(
    AstNode n,
    InterfaceElement e,
    String name,
    List<ClassMember> members,
  ) {
    final isEnum = e is EnumElement;
    final isMixin = e is MixinElement;
    final sup = e.supertype?.element;
    // `A extends B with M1, M2`: the mixins' functions applied in order on B
    // (or on Object).
    final mixins = [
      for (final m in e.mixins)
        if (m.element is MixinElement && _isApp(m.element)) m.element,
    ];
    String? base = isEnum
        ? _use(r'$E')
        : isMixin
        ? 'S'
        : sup != null && _isApp(sup)
        ? topNames[sup]
        : null;
    if (mixins.isNotEmpty) {
      var b = base ?? 'Object';
      for (final m in mixins) {
        b = '${topNames[m]}($b)';
      }
      base = b;
    }
    final ctx = _Ctx(cls: e);
    final fieldInits = <String, String>{};
    final statics = <String>[];
    final methods = <String>[];
    ConstructorDeclaration? ctor;
    final factories = <String>[];
    for (final m in members) {
      // Members nothing reachable uses stay out (see `run`).
      if (m is MethodDeclaration &&
          !m.isOperator &&
          m.name.lexeme != 'hashCode' &&
          !_memberNames.contains(m.name.lexeme)) {
        continue;
      }
      if (m is ConstructorDeclaration &&
          m.factoryKeyword != null &&
          !_ctors.contains(m.declaredFragment?.element)) {
        continue;
      }
      switch (m) {
        case FieldDeclaration():
          for (final v in m.fields.variables) {
            if (_isCurveType(v.declaredFragment?.element.type)) continue;
            final js = _mangle(v.name.lexeme);
            if (m.fields.isLate) {
              if (!_lazyField(m) || m.isStatic) {
                _fail(
                  v,
                  '`late` fields are not in the lite subset (only '
                  '`late final x = …`, with its initializer).',
                );
              } else if (_memberNames.contains(v.name.lexeme)) {
                // A getter that computes it the first time it is read.
                final store = '\$lz_${v.name.lexeme}';
                methods.add(
                  'get $js() { if (!(\'$store\' in this)) this.$store = ${_expr(v.initializer!, ctx)}; return this.$store; }',
                );
              }
              continue;
            }
            if (m.isStatic && !_memberNames.contains(v.name.lexeme)) continue;
            if (m.isStatic && isMixin) {
              _fail(
                v,
                'Static field ${e.name}.${v.name.lexeme} in a mixin: move it '
                'to the top level.',
              );
            } else if (m.isStatic) {
              final init = v.initializer == null
                  ? 'null'
                  : _expr(v.initializer!, _Ctx(cls: e, hoist: false));
              // A JS static runs when the class is evaluated, before the
              // hoisted constants (`$c0`) and the classes below it exist: an
              // instance (`static const none = Tree(file: '')`, whose
              // constructor reads `$c0` for its default) would fall in the
              // TDZ, and so would a static that reads a class declared
              // below it or a top-level const. Dart's statics are lazy;
              // anything but a literal is too here: a getter that keeps the
              // first value.
              if (!_jsLiteral.hasMatch(init)) {
                statics.add(
                  'static get $js() { return $name.\$s_${v.name.lexeme} ??= $init; }',
                );
              } else {
                statics.add('static $js = $init;');
              }
            } else {
              final init = v.initializer;
              fieldInits[js] =
                  'this.$js = ${init == null ? 'null' : _expr(init, ctx)};';
            }
          }
        case ConstructorDeclaration():
          if (m.factoryKeyword != null) {
            if (m.redirectedConstructor != null) {
              _fail(m, 'Redirecting factory constructors are not supported.');
              continue;
            }
            final fname = m.name == null ? r'$new' : _mangle(m.name!.lexeme);
            factories.add(
              'static $fname(${_params(m.parameters, _Ctx())}) ${_body(m.body, _Ctx(), returns: true)}',
            );
          } else if (m.name != null) {
            _fail(
              m,
              'Named generative constructor ${e.name}.${m.name!.lexeme}: '
              'write it as a factory constructor.',
            );
          } else {
            ctor = m;
          }
        case MethodDeclaration():
          final mn = m.name.lexeme;
          if (m.isOperator && mn == '==') {
            // `operator ==` is the method `$eq`: a Map, a Set, `contains`,
            // a signal and `==` itself ask it (the helper `$deq`).
            if (m.body is! EmptyFunctionBody) {
              methods.add(
                '\$eq(${_params(m.parameters!, ctx)}) ${_body(m.body, ctx, returns: true)}',
              );
            }
            continue;
          }
          if (m.isOperator) {
            _fail(
              m,
              'Operator ${e.name}.$mn: operators on your classes are not in '
              'the lite subset (only == is).',
            );
            continue;
          }
          // An abstract member (a sealed base's `String get key;`): the
          // subclasses have it.
          if (m.body is EmptyFunctionBody && !m.isStatic) continue;
          if (m.isStatic && isMixin) {
            _fail(
              m,
              'Static member ${e.name}.$mn in a mixin: move it to the top '
              'level.',
            );
            continue;
          }
          final prefix = m.isStatic ? 'static ' : '';
          final c = m.isStatic ? _Ctx(cls: e) : ctx;
          if (m.isGetter) {
            // JS has no `async get`: an async getter returns the promise of
            // an async arrow (it keeps `this`).
            methods.add(
              m.body.isAsynchronous
                  ? '${prefix}get ${_mangle(mn)}() { return (${_async(m.body)}() => ${_body(m.body, c, returns: true)})(); }'
                  : '${prefix}get ${_mangle(mn)}() ${_body(m.body, c, returns: true)}',
            );
          } else if (m.isSetter) {
            methods.add(
              '${prefix}set ${_mangle(mn)}(${_params(m.parameters!, c)}) ${_body(m.body, c, returns: false)}',
            );
          } else {
            methods.add(
              '$prefix${_async(m.body)}${_mangle(mn)}(${_params(m.parameters!, c)}) ${_body(m.body, c, returns: m.returnType?.type is! VoidType)}',
            );
          }
        default:
          _fail(m, 'Unsupported class member.');
      }
    }
    if (!isEnum) _completeAccessorPairs(e, members, methods);
    final ctorLines = <String>[];
    var ctorParams = '';
    // The superclass constructor's call: JS runs it first (Dart runs the
    // field initializers first, which can't read `this`: the same).
    String? superCall;
    if (ctor != null) {
      ctorParams = _params(ctor.parameters, ctx);
      final superParams = <FormalParameter>[];
      for (final p in ctor.parameters.parameters) {
        final inner = p is DefaultFormalParameter ? p.parameter : p;
        if (inner is FieldFormalParameter) {
          final js = _mangle(inner.name.lexeme);
          fieldInits[js] =
              'this.$js = ${_local(inner.declaredFragment?.element, inner.name.lexeme)};';
        } else if (inner is SuperFormalParameter) {
          superParams.add(p);
        }
      }
      SuperConstructorInvocation? invocation;
      for (final i in ctor.initializers) {
        if (i is ConstructorFieldInitializer) {
          final js = _mangle(i.fieldName.name);
          fieldInits[js] = 'this.$js = ${_expr(i.expression, ctx)};';
        } else if (i is AssertInitializer) {
          // Asserts are dropped (like a release build).
        } else if (i is SuperConstructorInvocation && base != null) {
          invocation = i;
        } else {
          _fail(i, 'Unsupported constructor initializer: ${_src(i)}.');
        }
      }
      if (base != null && !isEnum) {
        final target =
            invocation?.element ??
            ctor.declaredFragment?.element.superConstructor;
        superCall = _superArgs(superParams, invocation, target, ctx);
      }
    }
    if (isEnum) {
      ctorParams = ctorParams.isEmpty
          ? r'$t, $i, $n'
          : '\$t, \$i, \$n, $ctorParams';
      superCall = r'$t, $i, $n';
    }
    ctorLines.insertAll(0, fieldInits.values);
    if (isMixin && ctorLines.isNotEmpty) {
      // A mixin has no constructor of its own: its base's takes the
      // arguments, then the mixin's fields start.
      ctorParams = r'...$a';
      ctorLines.insert(0, r'super(...$a);');
    } else if (base != null &&
        (ctorLines.isNotEmpty || ctor != null || isEnum)) {
      ctorLines.insert(0, 'super(${superCall ?? ''});');
    }
    if (ctor != null) {
      final b = ctor.body;
      if (b is BlockFunctionBody) {
        ctorLines.add(_block(b.block.statements, ctx));
      }
    }
    final body = [
      if (ctorLines.isNotEmpty || ctorParams.isNotEmpty)
        'constructor($ctorParams) {\n${_indent(ctorLines.where((l) => l.isNotEmpty).join('\n'), '  ')}\n}',
      ...methods,
      ...factories,
      ...statics,
    ];
    if (isMixin) {
      // The parameter is `$`-prefixed: a short name (letters only) can't
      // shadow it.
      return 'const $name = (\$S) => class extends \$S {\n${_indent(body.join('\n'), '  ')}\n};';
    }
    final ext = base == null ? '' : ' extends $base';
    return 'class $name$ext {\n${_indent(body.join('\n'), '  ')}\n}';
  }

  /// JS accessors shadow as a pair: a class that declares only the getter (or
  /// only the setter) of a pair its superclass has would lose the other half
  /// (`undefined`, or a TypeError on write). The other half is delegated with
  /// `super`; a pair that the superclass keeps as a field can not be
  /// continued (a field is an own property in JS), which says so.
  void _completeAccessorPairs(
    InterfaceElement e,
    List<ClassMember> members,
    List<String> methods,
  ) {
    final getters = <String, MethodDeclaration>{};
    final setters = <String, MethodDeclaration>{};
    for (final m in members) {
      if (m is! MethodDeclaration || m.isStatic || m.isOperator) continue;
      if (m.body is EmptyFunctionBody) continue;
      final n = m.name.lexeme;
      if (!_memberNames.contains(n)) continue;
      if (m.isGetter) getters[n] = m;
      if (m.isSetter) setters[n] = m;
    }
    for (final n in {...getters.keys, ...setters.keys}) {
      final isGetter = getters.containsKey(n);
      if (isGetter == setters.containsKey(n)) continue; // both, or the field
      final node = isGetter ? getters[n]! : setters[n]!;
      final other = _inheritedAccessor(e, n, getter: !isGetter, {});
      if (other == null) continue;
      if (other) {
        _fail(
          node,
          '`$n` of ${e.name} overrides only one half of a field of its '
          'superclass: write both `get $n` and `set $n` (the field is an own '
          'property in JS, `super.$n` can not reach it).',
        );
        continue;
      }
      final js = _mangle(n);
      methods.add(
        isGetter
            ? 'set $js(v) { super.$js = v; }'
            : 'get $js() { return super.$js; }',
      );
    }
  }

  /// Whether the accessor [name] (a getter, or a setter) of the classes above
  /// [e] is the synthetic one of a field (`true`), a declared one (`false`),
  /// or there is none (`null`).
  bool? _inheritedAccessor(
    InterfaceElement e,
    String name,
    Set<InterfaceElement> seen, {
    required bool getter,
  }) {
    final above = <InterfaceElement>[
      for (final m in e.mixins.reversed) m.element,
      ?e.supertype?.element,
      if (e is MixinElement)
        for (final c in e.superclassConstraints) c.element,
    ];
    for (final t in above) {
      if (!_isApp(t) || !seen.add(t)) continue;
      final acc = getter ? t.getGetter(name) : t.getSetter(name);
      if (acc != null && !acc.isAbstract) {
        return !acc.variable.isOriginGetterSetter;
      }
      final up = _inheritedAccessor(t, name, seen, getter: getter);
      if (up != null) return up;
    }
    return null;
  }

  /// The arguments of a superclass constructor call: super parameters
  /// (`super.x`) and `super(...)`'s own, in [target]'s parameter order.
  String _superArgs(
    List<FormalParameter> superParams,
    SuperConstructorInvocation? invocation,
    ConstructorElement? target,
    _Ctx ctx,
  ) {
    if (target == null) return '';
    final positional = <String>[];
    final named = <String, String>{};
    for (final p in superParams) {
      final inner = p is DefaultFormalParameter ? p.parameter : p;
      final js = _local(inner.declaredFragment?.element, inner.name!.lexeme);
      if (p.isNamed) {
        named[inner.name!.lexeme] = js;
      } else {
        positional.add(js);
      }
    }
    for (final a
        in invocation?.argumentList.arguments ?? const <Expression>[]) {
      if (a is NamedExpression) {
        named[a.name.label.name] = _expr(a.expression, ctx);
      } else {
        positional.add(_expr(a, ctx));
      }
    }
    final out = <String>[];
    var i = 0;
    for (final p in target.formalParameters) {
      if (p.isNamed) {
        out.add(named[p.name] ?? 'undefined');
      } else {
        out.add(i < positional.length ? positional[i++] : 'undefined');
      }
    }
    while (out.isNotEmpty && out.last == 'undefined') {
      out.removeLast();
    }
    return out.join(', ');
  }

  /// An extension's members as functions taking the receiver first:
  /// `Ext$m($this, …)`, `Ext$get$g($this)`.
  String _extension(ExtensionDeclaration n) {
    final e = n.declaredFragment!.element;
    final ctx = _Ctx(ext: e);
    final out = <String>[];
    for (final m in n.body.members) {
      if (m is! MethodDeclaration || m.isOperator || m.isSetter) {
        out.add(
          _fail(
            m,
            'Only methods and getters of an extension are in the lite subset.',
          ),
        );
        continue;
      }
      if (m.isStatic) {
        out.add(
          _fail(m, 'Static extension members are not in the lite subset.'),
        );
        continue;
      }
      final name = _extName(e, m.name.lexeme, getter: m.isGetter);
      final params = m.isGetter ? '' : _params(m.parameters!, ctx);
      out.add(
        '${_async(m.body)}function $name(\$this${params.isEmpty ? '' : ', $params'}) '
        '${_body(m.body, ctx, returns: m.returnType?.type is! VoidType)}',
      );
    }
    return out.join('\n');
  }

  String _extName(ExtensionElement e, String member, {required bool getter}) =>
      '${topNames[e] ?? _ident(e.name ?? 'ext')}\$${getter ? r'get$' : ''}$member';

  String _topFunction(FunctionDeclaration n) {
    final name = topNames[n.declaredFragment!.element]!;
    if (n.isGetter || n.isSetter) {
      return _fail(n, 'Top-level getters and setters are not supported.');
    }
    final f = n.functionExpression;
    return '${_async(f.body)}function $name(${_params(f.parameters!, _Ctx())}) '
        '${_body(f.body, _Ctx(), returns: n.returnType?.type is! VoidType)}';
  }

  String _topVariable(VariableDeclaration v) {
    final e = v.declaredFragment!.element;
    final name = topNames[e]!;
    final list = v.parent as VariableDeclarationList;
    if (list.isLate) {
      return _fail(v, '`late` top-level variables are not supported.');
    }
    final init = v.initializer == null
        ? 'null'
        : _expr(v.initializer!, _Ctx(hoist: false));
    final kw = list.isConst || list.isFinal ? 'const' : 'let';
    return '$kw $name = $init;';
  }

  // -------------------------------------------------------------------------
  // A ThorState class → thor.def(...).

  /// A state's static constants as JS `const`s, each after the ones its
  /// value reads (a Dart constant may name a later one; a JS `const`
  /// can't be read before its line).
  List<String> _staticLines(List<VariableDeclaration> fields, _Ctx ctx) {
    final byField = {for (final v in fields) v.declaredFragment!.element: v};
    final out = <String>[];
    final done = <Element>{};
    final visiting = <Element>{};
    void emit(VariableDeclaration v) {
      final f = v.declaredFragment!.element;
      if (done.contains(f) || !visiting.add(f)) return;
      final refs = _References();
      v.initializer!.accept(refs);
      for (final r in refs.elements) {
        final dep = r is PropertyAccessorElement ? r.variable : r;
        if (byField[dep] case final d?) emit(d);
      }
      visiting.remove(f);
      done.add(f);
      out.add(
        'const ${_stateName(v.name.lexeme)} = ${_expr(v.initializer!, ctx)};',
      );
    }

    fields.forEach(emit);
    return out;
  }

  /// Whether [e] is a constant expression (a state's `static final` is
  /// then a constant too): literals, `const` creations and collections,
  /// constants by name, and operators on those.
  bool _constantValue(Expression e) => switch (e) {
    TypedLiteral() => e.isConst,
    StringInterpolation() => e.elements.every(
      (x) =>
          x is InterpolationString ||
          _constantValue((x as InterpolationExpression).expression),
    ),
    Literal() => true,
    InstanceCreationExpression() => e.isConst,
    ParenthesizedExpression() => _constantValue(e.expression),
    PrefixExpression() => _constantValue(e.operand),
    BinaryExpression() =>
      _constantValue(e.leftOperand) && _constantValue(e.rightOperand),
    ConditionalExpression() =>
      _constantValue(e.condition) &&
          _constantValue(e.thenExpression) &&
          _constantValue(e.elseExpression),
    Identifier() => switch (e.element?.baseElement) {
      PropertyAccessorElement(:final variable) => variable.isConst,
      _ => false,
    },
    PropertyAccess() => switch (e.propertyName.element?.baseElement) {
      PropertyAccessorElement(:final variable) => variable.isConst,
      _ => false,
    },
    _ => false,
  };

  String _state(ClassDeclaration n) {
    final e = n.declaredFragment!.element;
    // The mixins of the app a state uses: their members are the state's, in
    // the order of resolution (the state's own last).
    final mixinDecls = <MixinDeclaration>[
      for (final t in e.mixins)
        if (decls[t.element]?.node case final MixinDeclaration d) d,
    ];
    final info = _StateInfo(e, [
      for (final d in mixinDecls) d.declaredFragment!.element,
    ]);
    final ctx = _Ctx(state: info);
    final members = <ClassMember>[
      for (final d in mixinDecls) ...d.body.members,
      ...n.body.members,
    ];
    // Definitions of one name, by order of resolution: the last one is the
    // member; an earlier method stays reachable as `super.name()` of the next
    // (`name$s1`…), an earlier field is replaced.
    final chains = <String, List<AstNode>>{};
    for (final m in members) {
      if (m is FieldDeclaration && !m.isStatic) {
        for (final v in m.fields.variables) {
          chains.putIfAbsent(v.name.lexeme, () => []).add(v);
        }
      } else if (m is MethodDeclaration && !m.isStatic) {
        chains.putIfAbsent(m.name.lexeme, () => []).add(m);
      }
    }
    final shadowed = <VariableDeclaration>{};
    final jsNames = <MethodDeclaration, String>{};
    final belowNames = <MethodDeclaration, String>{};
    for (final c in chains.entries) {
      final k = c.value.length - 1;
      for (var i = 0; i < k; i++) {
        final d = c.value[i];
        if (d is VariableDeclaration) {
          shadowed.add(d);
        } else if (d is MethodDeclaration) {
          jsNames[d] = _stateName('${c.key}\$s${k - i}');
        }
      }
      for (var i = 1; i <= k; i++) {
        final d = c.value[i];
        final below = c.value[i - 1];
        if (d is MethodDeclaration && below is MethodDeclaration) {
          belowNames[d] = jsNames[below] ?? _stateName(c.key);
        }
      }
    }
    _stateNames = {};
    _statePseudo.clear();
    final name = e.name!;
    final lines = <String>[];
    final exposed = <String>[];
    final signals = <String>[];
    // Controllers name themselves by the state's page id; a ScrollController
    // measures its element at load, so its state starts at load.
    var controllers = false, eager = false;
    // `bool get global => true;`: the state wakes on every page, not only
    // where the page names it.
    var global = false;
    // `onHydrated()` / `dispose()`: the state's life, kept out of the members
    // the page can call (`$l`).
    String? hydrated, disposed;
    // Queries with `ssr: false`: started when the state wakes in the browser.
    final browserOnly = <String>[];
    // `events(…)` fields: opened when the state wakes, closed when it ends.
    final eventStreams = <String>[];
    // Persisted fields' cookies: the runtime starts the state at load when
    // one is set, so the page shows it before any event (as dart2js does).
    final cookies = <String>[];
    // Fields kept in localStorage: the same, when one is stored.
    final locals = <String>[];
    if (n.implementsClause != null) {
      _fail(n, 'State $name: interfaces are not in the lite subset.');
    }
    for (final w in n.withClause?.mixinTypes ?? const <NamedType>[]) {
      final m = w.element;
      if (m is! MixinElement || !_isApp(m)) {
        _fail(
          w,
          'State $name mixes in ${w.name.lexeme}: only a `mixin` of the app '
          'can be mixed in a ThorState.',
        );
      }
    }
    // Declarations first, so methods know which fields are signals.
    for (final m in members) {
      if (m is FieldDeclaration && !m.isStatic) {
        for (final v in m.fields.variables) {
          final f = v.declaredFragment?.element;
          if (f is FieldElement && _isSignal(f.type)) info.signals.add(f);
        }
      }
      if (m is MethodDeclaration && m.isGetter && !m.isStatic) {
        final g = m.declaredFragment?.element;
        if (g != null) info.getters.add(g);
      }
      // `late final x = …`: read as a call that computes it the first time.
      if (m is FieldDeclaration && !m.isStatic && _lazyField(m)) {
        for (final v in m.fields.variables) {
          // (a derived is read as a signal: `.value`)
          if (_derivedCall(v) != null) continue;
          final g = (v.declaredFragment?.element as FieldElement?)?.getter;
          if (g != null) info.getters.add(g);
        }
      }
    }
    // Lines that go first: a lazy field (a field declared before it may read
    // it) and the static methods.
    final lazyLines = <String>[];
    // `static const` (and `static final` of a constant value).
    final staticFields = <VariableDeclaration>[];
    for (final m in members) {
      switch (m) {
        case FieldDeclaration(isStatic: true)
            when m.fields.variables.every(
              (v) => _isCurveType(v.declaredFragment?.element.type),
            ):
          break; // a curve: compiled to CSS where an animation takes it
        case FieldDeclaration(isStatic: true):
          // A constant: a `const` of the state's scope, before the fields
          // that read it (ordered by [_staticLines]).
          for (final v in m.fields.variables) {
            final init = v.initializer;
            if (m.fields.isConst ||
                m.fields.isFinal && init != null && _constantValue(init)) {
              staticFields.add(v);
            } else {
              _fail(
                v,
                'Static field $name.${v.name.lexeme}: a ThorState keeps only '
                'constants (`static const`, or `static final` with a '
                'constant value). Move it to the top level, or make it a '
                'field of the state.',
              );
            }
          }
        case FieldDeclaration():
          for (final v in m.fields.variables) {
            if (shadowed.contains(v)) continue;
            if (_isCurveType(v.declaredFragment?.element.type)) continue;
            final f = v.declaredFragment!.element;
            final js = _stateName(v.name.lexeme);
            // `late final visible = derived(() => …)`: the runtime's lazy,
            // cached computed, registered on the state so its end stops it.
            if (_derivedCall(v) case final call?) {
              final args = call.argumentList.arguments;
              if (args.length != 1 ||
                  args.single is! FunctionExpression ||
                  !m.fields.isFinal) {
                _fail(
                  v,
                  'Field $name.${v.name.lexeme}: a derived is a `final` field '
                  'made with `derived(() => …)` (one closure).',
                );
                continue;
              }
              lines.add('const $js = \$.computed(${_expr(args.single, ctx)});');
              exposed.add('${v.name.lexeme}: () => $js.value');
              final key = _mangle(v.name.lexeme);
              signals.add(key == js ? js : '$key: $js');
              continue;
            }
            if (m.fields.isLate) {
              if (_lazyField(m) &&
                  !(isServerQueryType(f.type) ||
                      isServerEventStreamType(f.type) ||
                      isServerCommandType(f.type) ||
                      _isSignal(f.type) ||
                      _isNotifier(f.type) ||
                      _isController(f.type))) {
                final d = '\$lz${_tmp++}';
                lazyLines.add(
                  'let $d, ${d}d = false; '
                  'const $js = () => (${d}d || ($d = ${_expr(v.initializer!, ctx)}, ${d}d = true), $d);',
                );
                continue;
              }
              // (what follows reports the field's own error too)
              _fail(
                v,
                _lazyField(m)
                    ? '`late` fields are not in the lite subset for a '
                          '`state(...)`, `query`, `command` or controller: '
                          'declare it in a `final` field.'
                    : '`late` fields are not in the lite subset (only '
                          '`late final x = …`, with its initializer).',
              );
            }
            if (isServerEventStreamType(f.type)) {
              final init = v.initializer;
              if (init is! MethodInvocation ||
                  !isServerEventStreamCall(init) ||
                  !m.fields.isFinal) {
                _fail(
                  v,
                  'Field $name.${v.name.lexeme}: an event stream is made in a '
                  '`final` field with `events(url, ...)`.',
                );
                continue;
              }
              final n = v.name.lexeme;
              final spec = _eventsSpec(init, f.type as InterfaceType);
              if (spec == null) continue;
              final data = (f.type as InterfaceType).typeArguments.single;
              final decode = _queryDecode(data, v);
              // The browser needs ConnectionState's values (`thor.CS`).
              final cs = (f.type as InterfaceType)
                  .getGetter('connection')
                  ?.returnType;
              final csEnum = cs is InterfaceType
                  ? cs.typeArguments.singleOrNull?.element
                  : null;
              if (csEnum is EnumElement) _enumName(csEnum);
              lines.add(
                "const $js = ${_use(r'$EV')}(\$, '$name', '$n', "
                '${decode ?? 'null'}, $spec);',
              );
              eventStreams.add(js);
              for (final k in const [
                'data',
                'loading',
                'error',
                'connection',
              ]) {
                exposed.add("'$n\$$k': () => $js.$k.value");
                signals.add("'$n\$$k': $js.$k");
              }
              exposed.add("'$n\$phase': () => $js.phase()");
              exposed.add("'$n\$message': () => $js.error.value ?? ''");
              exposed.add("'$n\$refresh': () => $js.refresh()");
              continue;
            }
            if (isServerQueryType(f.type)) {
              final init = v.initializer;
              if (init is! MethodInvocation ||
                  !isServerQueryCall(init) ||
                  !m.fields.isFinal) {
                _fail(
                  v,
                  'Field $name.${v.name.lexeme}: a query is made in a `final` '
                  'field with `query(fn)` or `queryWith(fn, arg: …)`.',
                );
                continue;
              }
              final n = v.name.lexeme;
              final withArg = init.methodName.name == 'queryWith';
              final arg = init.argumentList.arguments
                  .whereType<NamedExpression>()
                  .where((a) => a.name.label.name == 'arg')
                  .firstOrNull;
              final data = (f.type as InterfaceType).typeArguments[1];
              final decode = _queryDecode(data, v);
              final ms = _timeoutMs(init);
              if (_browserOnly(init)) browserOnly.add(js);
              // An argument that is a class or a record: how it comes back
              // from JSON (and, for a class, how it is written).
              final (argDecode, argEncode) = withArg
                  ? _argCodec((f.type as InterfaceType).typeArguments.first)
                  : (null, null);
              lines.add(
                "const $js = ${_use(r'$Q')}(\$, '$name', '$n', "
                '${arg == null ? 'null' : _expr(arg.expression, ctx)}, '
                '${decode ?? 'null'}${argDecode != null
                    ? ', 1, ${ms ?? 'null'}, $argDecode${argEncode == null ? '' : ', $argEncode'}'
                    : ms != null
                    ? ', ${withArg ? 1 : 0}, $ms'
                    : withArg
                    ? ', 1'
                    : ''});',
              );
              // The server draws a `ssr: false` query waiting: the browser
              // starts there too (what the page's finite state switches from).
              if (_browserOnly(init)) lines.add('$js.ssrOff = 1;');
              for (final k in const ['data', 'loading', 'error', 'arg']) {
                exposed.add("'$n\$$k': () => $js.$k.value");
                signals.add("'$n\$$k': $js.$k");
              }
              exposed.add("'$n\$phase': () => $js.phase()");
              exposed.add("'$n\$message': () => $js.error.value ?? ''");
              exposed.add("'$n\$refresh': () => $js.refresh()");
              continue;
            }
            if (isServerCommandType(f.type)) {
              final init = v.initializer;
              if (init is! MethodInvocation ||
                  !isServerCommandCall(init) ||
                  !m.fields.isFinal) {
                _fail(
                  v,
                  'Field $name.${v.name.lexeme}: a command is made in a '
                  '`final` field with `command(fn)` or `commandWith(fn)`.',
                );
                continue;
              }
              final n = v.name.lexeme;
              final (argType, result) = commandTypes(f.type as InterfaceType);
              final withArg = init.methodName.name == 'commandWith';
              final decode = _queryDecode(result, v);
              final ms = _timeoutMs(init);
              // An argument that is a class travels as JSON: it says how it is
              // written (`toJson`); a record goes as it is.
              final argEncode = withArg ? _argCodec(argType).$2 : null;
              lines.add(
                "const $js = ${_use(r'$SC')}(\$, '$name', '$n', "
                '${decode ?? 'null'}${argEncode != null
                    ? ', 1, ${ms ?? 'null'}, $argEncode'
                    : ms != null
                    ? ', ${withArg ? 1 : 0}, $ms'
                    : withArg
                    ? ', 1'
                    : ''});',
              );
              for (final k in const ['pending', 'error', 'result']) {
                exposed.add("'$n\$$k': () => $js.$k.value");
                signals.add("'$n\$$k': $js.$k");
              }
              if (withArg) {
                // The page's text argument (`run.withArg(sku)`), parsed
                // like a method's.
                final parse = _parseArg(argType, 'a', v, fromItem: false);
                exposed.add("'$n\$run': (a) => $js.run(${parse ?? 'a'})");
              } else {
                exposed.add("'$n\$run': () => $js.run()");
              }
              continue;
            }
            if (_isNotifier(f.type)) {
              _fail(
                v,
                'Field $name.${v.name.lexeme} is a '
                '${f.type.getDisplayString()}: a plain ValueNotifier or '
                'ChangeNotifier does not react in the browser (nothing '
                'listens to it there).',
              );
              continue;
            }
            if (_isSignal(f.type)) {
              final init = v.initializer;
              if (init is! MethodInvocation ||
                  init.methodName.name != 'state' ||
                  !_inThor(init.methodName.element)) {
                _fail(
                  v,
                  'Field $name.${v.name.lexeme} is a signal not made with `state(...)`.',
                );
                continue;
              }
              final args = init.argumentList.arguments;
              final initial = args.firstWhere((a) => a is! NamedExpression);
              String? decode, encode;
              Expression? cookie, local;
              for (final a in args.whereType<NamedExpression>()) {
                switch (a.name.label.name) {
                  case 'decode':
                    decode = _expr(a.expression, ctx);
                  case 'encode':
                    encode = _expr(a.expression, ctx);
                  case 'cookie':
                    cookie = a.expression;
                  case 'local':
                    local = a.expression;
                }
              }
              // A class of the app with `toJson()`/`fromJson` (or a list or
              // a map of them) needs no decode: the same one a query uses.
              if (decode == null && encode == null) {
                decode = _stateDecode(
                  (f.type as InterfaceType).typeArguments.single,
                );
              }
              // A set field travels as a list: back to a set (of simple
              // values; another element type says how with decode:).
              if (_setSignal(f.type) case final element?) {
                if (decode == null) {
                  if (_num(element) || _str(element) || _bool(element)) {
                    decode = '(j) => new Set(j)';
                  } else {
                    _fail(
                      v,
                      'Field $name.${v.name.lexeme} is a set of '
                      '${element.getDisplayString()}: only sets of int, '
                      'double, String and bool travel from the server as '
                      'they are; give the others `encode:` and `decode:`.',
                    );
                  }
                }
              }
              var made =
                  "\$.state('${v.name.lexeme}', ${_expr(initial, ctx)}${decode == null ? '' : ', $decode'})";
              if (cookie != null && local != null) {
                _fail(
                  local,
                  'A field persists in a cookie or in localStorage, not both '
                  '(THOR-S009).',
                );
              } else if (cookie ?? local case final where?) {
                final option = cookie != null ? 'cookie' : 'local';
                final c = where is SimpleStringLiteral ? where.value : null;
                final valueType =
                    (f.type as InterfaceType).typeArguments.single;
                final check = _persistCheck(valueType);
                if (c == null || !_cookieName(c)) {
                  _fail(
                    where,
                    'state($option:) takes a string literal of 1–40 letters, '
                    'digits, _ or - (THOR-S009).',
                  );
                } else if (check == null && decode == null) {
                  _fail(
                    where,
                    'A persisted ${valueType.getDisplayString()} needs '
                    'encode/decode: lite checks a stored value against bool, '
                    'int, double, num, String and lists or String-keyed maps '
                    'of them.',
                  );
                } else {
                  (cookie != null ? cookies : locals).add(c);
                  made =
                      "${_use(cookie != null ? r'$persist' : r'$local')}($made, '$c', ${encode ?? 'null'}, ${check ?? 'null'}, ${decode ?? 'null'})";
                }
              }
              // `thor dev` keeps the page's values across a reload: a field
              // with a codec carries it on the signal (`enc`/`dec`) so the
              // dev_state part saves and restores it. Release drops it.
              if (checks && encode != null) {
                made =
                    'Object.assign($made, { enc: $encode'
                    '${decode == null ? '' : ', dec: $decode'} })';
              }
              lines.add('const $js = $made;');
              exposed.add('${v.name.lexeme}: () => $js.value');
              final key = _mangle(v.name.lexeme);
              signals.add(key == js ? js : '$key: $js');
            } else if (f.type is InterfaceType &&
                (f.type as InterfaceType).allSupertypes.any(
                  (s) => s.element.name == 'ThorController',
                )) {
              final kind = _controllers[_valueType(f.type)];
              final init = v.initializer;
              if (kind == null) {
                _fail(
                  v,
                  'Controller field $name.${v.name.lexeme}: '
                  '${f.type.getDisplayString()} is not in the lite subset '
                  '(DialogController, FocusNode, TextEditingController, '
                  'ScrollController and AnimationController are).',
                );
              } else if (init is! InstanceCreationExpression ||
                  !m.fields.isFinal) {
                _fail(
                  v,
                  'Controller field $name.${v.name.lexeme}: create it in a '
                  '`final` field (`final ${v.name.lexeme} = ${f.type.getDisplayString()}();`).',
                );
              } else {
                controllers = true;
                used.add('\$C$kind');
                _statePseudo.add('\$C$kind');
                // A ScrollController measures its element, an
                // AnimationController takes over its CSS animation: at load.
                if (kind == 'scroll' || kind == 'page' || kind == 'anim') {
                  eager = true;
                }
                if (kind == 'page') {
                  for (final a
                      in init.argumentList.arguments
                          .whereType<NamedExpression>()) {
                    final e = a.expression;
                    final one =
                        e is IntegerLiteral && e.value == 1 ||
                        e is DoubleLiteral && e.value == 1.0;
                    if (a.name.label.name == 'viewportFraction' && !one) {
                      _fail(
                        a,
                        'PageController(viewportFraction:) is not in the lite '
                        'subset: a PageView page fills the view (use a '
                        'smaller child inside each page).',
                      );
                    }
                  }
                }
                final args = _args(
                  init.argumentList,
                  init.constructorName.element,
                  ctx,
                );
                lines.add(
                  'const $js = ${_use(r'$C')}.$kind(`\${\$p}.${v.name.lexeme}`${args.isEmpty ? '' : ', $args'});',
                );
              }
            } else {
              final kw = m.fields.isFinal || m.fields.isConst ? 'const' : 'let';
              lines.add(
                '$kw $js = ${v.initializer == null ? 'null' : _expr(v.initializer!, ctx)};',
              );
            }
          }
        case MethodDeclaration():
          final mn = m.name.lexeme;
          // A method a later definition overrides keeps a name of its own.
          final overridden = jsNames[m];
          final js = overridden ?? _stateName(mn);
          info.supers = {mn: ?belowNames[m]};
          if (m.isOperator) {
            _fail(m, 'Operators in a ThorState are not supported.');
            continue;
          }
          // A static method is a function of the state's scope (never a
          // member the page calls).
          if (m.isStatic && (m.isSetter || m.isGetter)) {
            _fail(
              m,
              'Static getters and setters in a ThorState are not supported: '
              'use a static method or a top-level function.',
            );
            continue;
          }
          if (m.isGetter && mn == 'global' && !m.isStatic) {
            // A literal the builder reads (default false): never a member.
            final b = m.body;
            final e = b is ExpressionFunctionBody ? b.expression : null;
            if (e is BooleanLiteral) {
              global = e.value;
            } else {
              _fail(m, '$name.global must be a literal `true` or `false`.');
            }
            continue;
          }
          if (m.isGetter) {
            lines.add(
              'const $js = ${_async(m.body)}() => ${_arrowBody(m.body, ctx, returns: true)};',
            );
            continue;
          }
          if (m.isSetter) {
            _fail(
              m,
              'Setters in a ThorState are not in the lite subset: use a method.',
            );
            continue;
          }
          final isVoid =
              m.returnType?.type is VoidType ||
              m.declaredFragment?.element.returnType is VoidType;
          // A static method goes first: a field initializer may call it
          // (the only method an initializer can reach), declared before or
          // after the field.
          (m.isStatic ? lazyLines : lines).add(
            'const $js = ${_async(m.body)}(${_params(m.parameters!, ctx)}) => ${_arrowBody(m.body, ctx, returns: !isVoid)};',
          );
          if (overridden != null) continue;
          if ((mn == 'onHydrated' || mn == 'dispose') && !m.isStatic) {
            if (m.parameters!.parameters.isNotEmpty) {
              _fail(
                m,
                '$name.$mn takes no parameters: the engine calls it, the page '
                'never does.',
              );
              continue;
            }
            if (mn == 'onHydrated') {
              hydrated = js;
            } else {
              disposed = js;
            }
            continue;
          }
          if (!mn.startsWith('_') && !m.isStatic) {
            final entry = _entry(m, js);
            if (entry != null) {
              exposed.add(
                entry == js
                    ? js == mn
                          ? mn
                          : '$mn: $js'
                    : '$mn: $entry',
              );
            }
          }
        // `TileState({super.key});` only forwards the key, which the lite
        // engine gives each instance from the page (`$.key`).
        case ConstructorDeclaration() when _onlyForwardsKey(m):
          break;
        case ConstructorDeclaration():
          _fail(
            m,
            'Constructors in a ThorState are not in the lite subset (the key comes from the page).',
          );
        default:
          _fail(m, 'Unsupported member.');
      }
    }
    exposed.add('\$s: { ${signals.join(', ')} }');
    if (browserOnly.isNotEmpty) {
      // The page's own `onHydrated` first (it may set an argument, which asks
      // already); then every query nothing has asked yet, also when it threw.
      final start = browserOnly
          .map(
            (q) =>
                'if (!$q.loading.peek() && $q.data.peek() == null) $q.refresh();',
          )
          .join(' ');
      hydrated = hydrated == null
          ? '() => { $start }'
          : '() => { try { return $hydrated(); } finally { $start } }';
    }
    if (eventStreams.isNotEmpty) {
      final start = [for (final q in eventStreams) '$q.start();'].join(' ');
      final stop = [for (final q in eventStreams) '$q.stop();'].join(' ');
      hydrated = hydrated == null
          ? '() => { $start }'
          : '() => { try { return $hydrated(); } finally { $start } }';
      disposed = disposed == null
          ? '() => { $stop }'
          : '() => { try { return $disposed(); } finally { $stop } }';
    }
    if (hydrated != null || disposed != null) {
      used.add(r'$life');
      _statePseudo.add(r'$life');
      exposed.add(
        '\$l: { ${[if (hydrated != null) 'h: $hydrated', if (disposed != null) 'd: $disposed'].join(', ')} }',
      );
    }
    final uses = <String>{};
    final refs = _References();
    n.accept(refs);
    for (final d in mixinDecls) {
      d.accept(refs);
    }
    for (final r in refs.elements) {
      final top = _topOf(r);
      if (top == null) continue;
      final id = _stateInstance(top);
      if (id != null && top.name != null) {
        final cls = id.split('#').first;
        if (cls != name) uses.add(cls);
      }
    }
    lines.insertAll(0, [..._staticLines(staticFields, ctx), ...lazyLines]);
    if (controllers) {
      lines.insert(0, 'const \$p = \$.p;');
    }
    final options = [
      if (uses.isNotEmpty) 'uses: [${uses.map((u) => "'$u'").join(', ')}]',
      if (eager)
        'eager: true'
      else if (locals.isNotEmpty)
        "eager: \$local.has('$name', ${locals.map((c) => "'$c'").join(', ')})",
      if (hydrated != null) 'idle: true',
      // The idle wake (timers, queries) only on a page that names the state,
      // unless the state is `global`.
      if (hydrated != null && !global) 'named: true',
      if (cookies.isNotEmpty)
        'cookies: [${cookies.map((c) => "'$c'").join(', ')}]',
    ];
    final opts = options.isEmpty ? '' : ', { ${options.join(', ')} }';
    // The parts behind helpers that have no item of their own (`$life`, the
    // controllers): a page that keeps only some states needs these.
    final pseudo = {for (final h in _statePseudo) ...?_helperParts[h]}.toList()
      ..sort();
    return "thor.def('$name', (\$) => {\n"
        '${_indent(lines.join('\n'), '  ')}\n'
        '  return {\n${_indent(exposed.join(',\n'), '    ')},\n  };\n'
        '}$opts);'
        '${pseudo.isEmpty ? '' : '\n// @parts ${pseudo.join(' ')}'}';
  }

  /// JS turning a query's JSON result back into a [t] (its `fromJson`), or
  /// null when the JSON is the value (simple values, lists and maps of
  /// them). The registry reports other types (THOR-B021).
  /// JS for a query argument of type [t] that is not a simple value:
  /// `(decode, encode)`, or `(null, null)` for a simple one. A class comes
  /// back with its `fromJson` and goes out with its `toJson`; a record is
  /// its fields (`$1`… for the positional ones) and goes out as it is.
  (String?, String?) _argCodec(DartType t) {
    if (t is RecordType) {
      _recordsMade = true;
      final fields = [
        for (var i = 1; i <= t.positionalFields.length; i++) '\$$i',
        for (final f in t.namedFields) f.name,
      ];
      return (
        '(j) => Object.freeze({ '
            "${fields.map((k) => "$k: j.get('$k')").join(', ')} })",
        null,
      );
    }
    if (t is InterfaceType && _isApp(t.element)) {
      return ('(j) => ${topNames[t.element]}.fromJson(j)', '(a) => a.toJson()');
    }
    return (null, null);
  }

  /// JS turning a state field's JSON back into its [t] (a class with
  /// `fromJson`, a list or a map of them), or null when the JSON is the
  /// value.
  String? _stateDecode(DartType t) {
    final model = jsonStateModel(t);
    if (model == null) return null;
    final from = '${topNames[model.element]}.fromJson';
    final nullable = t.nullabilitySuffix == NullabilitySuffix.question;
    final String inner;
    if (t is InterfaceType && t.isDartCoreList) {
      inner = 'j.map((x) => $from(x))';
    } else if (t is InterfaceType && t.isDartCoreMap) {
      inner = 'new Map([...j].map(([k, x]) => [k, $from(x)]))';
    } else {
      inner = '$from(j)';
    }
    return nullable ? '(j) => j == null ? null : $inner' : '(j) => $inner';
  }

  String? _queryDecode(DartType t, AstNode at) {
    final nullable = t.nullabilitySuffix == NullabilitySuffix.question;
    String? inner;
    if (t is InterfaceType && _isApp(t.element)) {
      inner = '${topNames[t.element]}.fromJson(j)';
    } else if (t is InterfaceType && t.isDartCoreList) {
      if (t.typeArguments.single case final InterfaceType e
          when _isApp(e.element)) {
        inner = 'j.map((x) => ${topNames[e.element]}.fromJson(x))';
      }
    }
    if (inner == null) return null;
    return nullable ? '(j) => j == null ? null : $inner' : '(j) => $inner';
  }

  /// How the runtime calls method [m] (its JS function [js]): the function
  /// itself, or a wrapper parsing the page's string arguments like the
  /// generated Dart members do. Null when the Dart builder skips it too.
  String? _entry(MethodDeclaration m, String js) {
    final params = m.parameters!.parameters;
    if (params.isEmpty) return js;
    if (params.length > 3 || params.any((p) => !p.isRequiredPositional)) {
      return null;
    }
    DartType typeOf(FormalParameter p) => p.declaredFragment!.element.type;
    if (params.length == 2 &&
        focusNodeType(typeOf(params[0])) != null &&
        keyEventType(typeOf(params[1])) != null) {
      // `Focus(onKeyEvent:)`: the event from the page; the node is not the
      // page's (the Dart engine passes a fresh one), so it must go unused.
      final node = params[0].declaredFragment!.element;
      final reads = _ReadsElement(node);
      m.body.accept(reads);
      if (reads.found) {
        _fail(
          params[0],
          'The FocusNode of onKeyEvent (${node.name}) is not the page\'s: '
          'use a FocusNode field of the state to move or test the focus.',
        );
      }
      return '(a) => $js(null, ${_use(r'$KE')}(a))';
    }
    if (params.length == 1) {
      final t = typeOf(params.single);
      if (intentType(t) case final intent?) {
        // A CallbackAction's method: the intent made again (the page only
        // knows its class), like the Dart engine's member.
        if (!intentRebuildable(intent)) {
          _fail(
            params.single,
            'Intent ${intent.name} needs a public constructor without '
            'arguments: the page makes it again (an intent carries no fields '
            'to the browser; use one intent class per meaning).',
          );
          return js;
        }
        return '() => $js(new ${topNames[intent]}())';
      }
      final parse = _parseArg(t, 'a', m, fromItem: true);
      if (parse == null || parse == 'a') return js;
      return '(a) => $js($parse)';
    }
    if (params.length == 2) {
      final first = _parseArg(typeOf(params[0]), 'a', m, fromItem: false);
      final second = typeOf(params[1]);
      if (first != null && _parseArg(second, 'i', m, fromItem: false) == null) {
        return '(a, i) => $js($first, i)';
      }
    }
    final parsed = [
      for (var i = 0; i < params.length; i++)
        _parseArg(typeOf(params[i]), 'x[$i]', m, fromItem: false),
    ];
    if (parsed.contains(null)) return null;
    used.add(r'$split');
    return '(a) => { const x = \$split(a, ${params.length}); return $js(${parsed.join(', ')}); }';
  }

  /// JS parsing the page's string argument [a] as [t] (like the generated
  /// Dart members). With [fromItem], [a] may also be a list item already of
  /// type [t] (a row field over `List<int>`). Null for types that are not
  /// simple values.
  String? _parseArg(
    DartType t,
    String a,
    AstNode at, {
    required bool fromItem,
  }) {
    final nullable = t.nullabilitySuffix == NullabilitySuffix.question;
    String? core;
    var typed = '';
    if (t.isDartCoreInt) {
      used.add(r'$int');
      core = '\$int($a)';
      typed = "typeof $a === 'string'";
    } else if (t.isDartCoreDouble || t.isDartCoreNum) {
      used.add(r'$double');
      core = '\$double($a)';
      typed = "typeof $a === 'string'";
    } else if (t.isDartCoreString) {
      core = a;
    } else if (t.isDartCoreBool) {
      core = "$a === 'true'";
      typed = "typeof $a === 'string'";
    } else if (_isEnum(t)) {
      final e = (t as InterfaceType).element;
      final name = _enumName(e);
      if (name == null) {
        _fail(at, 'Enum ${e.name} is not declared in the app.');
        return a;
      }
      core = '${_use(r'$byName')}($name\$values, $a)';
      typed = "typeof $a === 'string'";
    } else if (_valueType(t) == 'DateTime') {
      // `yyyy-mm-dd` from a date picker (or a full ISO 8601 date-time).
      core = '${_use(r'$dtp')}($a)';
      typed = "typeof $a === 'string'";
    } else if (_valueType(t) == 'TimeOfDay') {
      // `hh:mm` from a time picker.
      used.add(r'$int');
      core =
          'new ${_use(r'$TOD')}(\$int($a.substring(0, 2)), \$int($a.substring(3, 5)))';
      typed = "typeof $a === 'string'";
    }
    if (core == null && _valueType(t) == 'DragEndDetails') {
      // `vx~vy~lx~ly~gx~gy` from a GestureDetector's `onPanEnd`.
      used.add(r'$double');
      core =
          '((p) => ({velocity: {pixelsPerSecond: {dx: \$double(p[0]), dy: \$double(p[1])}}, '
          'primaryVelocity: null, '
          'localPosition: {dx: \$double(p[2]), dy: \$double(p[3])}, '
          'globalPosition: {dx: \$double(p[4]), dy: \$double(p[5])}}))'
          "($a.split('~'))";
      typed = "typeof $a === 'string'";
    }
    if (core == null &&
        const {
          'TapDownDetails',
          'TapUpDetails',
          'DragUpdateDetails',
        }.contains(_valueType(t))) {
      // `x~y` from a GestureDetector: the details as a plain object.
      used.add(r'$double');
      final field = _valueType(t) == 'DragUpdateDetails'
          ? 'delta'
          : 'localPosition';
      core =
          '((p) => ({$field: {dx: \$double(p[0]), dy: \$double(p[1])}}))'
          "($a.split('~'))";
      typed = "typeof $a === 'string'";
    }
    if (core == null && !nullable && _set(t)) {
      // A `Set<E>` of a simple value (a segmented button's selection): the
      // browser sends the chosen values (one for a radio group), or nothing
      // when empty.
      final element = (t as InterfaceType).typeArguments.single;
      if (element.nullabilitySuffix != NullabilitySuffix.question) {
        // Checkboxes send all the checked values, U+001F apart.
        final inner = _parseArg(element, r'$v', at, fromItem: false);
        if (inner == null) return null;
        final built =
            "($a == null || $a === '' ? ${_newSet(t)} : "
            '${_newSet(t, '$a.split("\\u001f").map((\$v) => $inner)')})';
        // A list item of this type arrives already built.
        return fromItem ? "(typeof $a === 'string' ? $built : $a)" : built;
      }
    }
    if (core == null) return null;
    if (fromItem && typed.isNotEmpty) core = '($typed ? $core : $a)';
    if (!nullable) return core;
    return "($a == null || $a === '' ? null : $core)";
  }

  // -------------------------------------------------------------------------
  // Functions.

  String _params(FormalParameterList list, _Ctx ctx) {
    final out = <String>[];
    for (final p in list.parameters) {
      final inner = p is DefaultFormalParameter ? p.parameter : p;
      final name = _local(
        inner.declaredFragment?.element,
        inner.name?.lexeme ?? '_',
      );
      if (inner is FunctionTypedFormalParameter) {
        out.add(name);
        continue;
      }
      if (p is DefaultFormalParameter && p.isOptional) {
        final d = p.defaultValue;
        out.add('$name = ${d == null ? 'null' : _expr(d, ctx)}');
      } else {
        out.add(name);
      }
    }
    return out.join(', ');
  }

  /// `async ` for an async body (JS's async functions run like Dart's on
  /// the web: the body until the first await, then microtasks).
  String _async(FunctionBody b) => b.isAsynchronous ? 'async ' : '';

  /// A function body as a JS block.
  String _body(FunctionBody b, _Ctx ctx, {required bool returns}) {
    if (b.isGenerator) {
      return _fail(b, 'Generators (sync*, async*) are not in the lite subset.');
    }
    // A break inside refers to the function's own loops.
    _breaks.add(null);
    try {
      switch (b) {
        case BlockFunctionBody():
          return '{\n${_indent(_block(b.block.statements, ctx), '  ')}\n}';
        case ExpressionFunctionBody():
          final e = _expr(b.expression, ctx);
          return returns ? '{\n  return $e;\n}' : '{\n  $e;\n}';
        case EmptyFunctionBody():
          return _fail(b, 'Abstract/external members are not supported.');
        default:
          return _fail(b, 'Unsupported function body.');
      }
    } finally {
      _breaks.removeLast();
    }
  }

  /// A function body after `=>` in JS.
  String _arrowBody(FunctionBody b, _Ctx ctx, {required bool returns}) {
    if (b is ExpressionFunctionBody && !b.isGenerator) {
      final e = _expr(b.expression, ctx);
      if (!returns) return '{\n  $e;\n}';
      return e.startsWith('{') ? '($e)' : e;
    }
    return _body(b, ctx, returns: returns);
  }

  /// [body] translated where an unlabeled `break` leaves [label] (a lowered
  /// switch) or the nearest JS loop/switch (null).
  String _breakScope(String? label, String Function() body) {
    _breaks.add(label);
    try {
      return body();
    } finally {
      _breaks.removeLast();
    }
  }

  // -------------------------------------------------------------------------
  // Statements.

  String _block(List<Statement> statements, _Ctx ctx) => statements
      .map((s) => _stmt(s, ctx))
      .where((s) => s.isNotEmpty)
      .join('\n');

  String _stmt(Statement s, _Ctx ctx) {
    switch (s) {
      case Block():
        return '{\n${_indent(_block(s.statements, ctx), '  ')}\n}';
      case ExpressionStatement(expression: final ThrowExpression t):
        return _throwStmt(t.expression, ctx);
      case ExpressionStatement(expression: RethrowExpression()):
        if (_caught.isEmpty) return _fail(s, '`rethrow` outside a catch.');
        return 'throw ${_caught.last};';
      case ExpressionStatement():
        return '${_expr(s.expression, ctx)};';
      case VariableDeclarationStatement():
        return '${_vars(s.variables, ctx)};';
      case ReturnStatement():
        final e = s.expression;
        return e == null ? 'return;' : 'return ${_expr(e, ctx)};';
      case IfStatement():
        final elseS = s.elseStatement;
        if (s.caseClause case final c?) {
          return _ifCase(
            _expr(s.expression, ctx),
            c.guardedPattern,
            () => _stmt(s.thenStatement, ctx),
            elseS == null ? null : () => _stmt(elseS, ctx),
            ctx,
          );
        }
        return 'if (${_expr(s.expression, ctx)}) ${_stmt(s.thenStatement, ctx)}'
            '${elseS == null ? '' : ' else ${_stmt(elseS, ctx)}'}';
      case ForStatement():
        if (s.awaitKeyword != null) {
          return _fail(s, '`await for` is not supported.');
        }
        final parts = s.forLoopParts;
        if (parts is ForEachPartsWithPattern) {
          final (head, binds) = _forPattern(parts, ctx);
          final body = _breakScope(null, () => _stmt(s.body, ctx));
          return 'for ($head) {\n${_indent('$binds\n$body', '  ')}\n}';
        }
        return 'for (${_forParts(parts, ctx)}) ${_breakScope(null, () => _stmt(s.body, ctx))}';
      case WhileStatement():
        return 'while (${_expr(s.condition, ctx)}) ${_breakScope(null, () => _stmt(s.body, ctx))}';
      case DoStatement():
        return 'do ${_breakScope(null, () => _stmt(s.body, ctx))} while (${_expr(s.condition, ctx)});';
      case BreakStatement():
        if (s.label != null) return 'break ${s.label!.name};';
        final to = _breaks.isEmpty ? null : _breaks.last;
        return to == null ? 'break;' : 'break $to;';
      case PatternVariableDeclarationStatement():
        final d = s.declaration;
        final v = '\$p${_tmp++}';
        final m = _match(d.pattern, v, ctx);
        final binds = _binds(m, mutable: d.keyword.lexeme == 'var');
        return 'const $v = ${_expr(d.expression, ctx)};${binds.isEmpty ? '' : '\n$binds'}';
      case ContinueStatement():
        return s.label == null ? 'continue;' : 'continue ${s.label!.name};';
      case EmptyStatement():
        return ';';
      case AssertStatement():
        return '';
      case LabeledStatement():
        return '${s.labels.map((l) => '${l.label.name}:').join(' ')} ${_stmt(s.statement, ctx)}';
      case FunctionDeclarationStatement():
        final f = s.functionDeclaration;
        final fe = f.functionExpression;
        return 'const ${_local(f.declaredFragment?.element, f.name.lexeme)} = ${_async(fe.body)}(${_params(fe.parameters!, ctx)}) => '
            '${_arrowBody(fe.body, ctx, returns: f.returnType?.type is! VoidType)};';
      case SwitchStatement():
        return _switchStatement(s, ctx);
      case TryStatement():
        return _try(s, ctx);
      default:
        return _fail(
          s,
          'Statement not in the lite subset: ${_src(s)} (yield is not supported).',
        );
    }
  }

  String _vars(VariableDeclarationList l, _Ctx ctx) {
    if (l.isLate) _fail(l, '`late` variables are not in the lite subset.');
    final kw = l.isFinal || l.isConst ? 'const' : 'let';
    final parts = [
      for (final v in l.variables)
        v.initializer == null
            ? _unset(v)
            : '${_local(v.declaredFragment?.element, v.name.lexeme)} = ${_expr(v.initializer!, ctx)}',
    ];
    if (kw == 'const' && l.variables.any((v) => v.initializer == null)) {
      return 'let ${parts.join(', ')}';
    }
    return '$kw ${parts.join(', ')}';
  }

  /// A local without initializer: a nullable one is `null` (JS's unset
  /// `undefined` would print as such, and `x == null` needs no `== undefined`
  /// twin); a non-nullable one is assigned before it is read.
  String _unset(VariableDeclaration v) {
    final name = _local(v.declaredFragment?.element, v.name.lexeme);
    final t = v.declaredFragment?.element.type;
    return t == null || t.nullabilitySuffix == NullabilitySuffix.question
        ? '$name = null'
        : name;
  }

  String _forParts(ForLoopParts p, _Ctx ctx) {
    switch (p) {
      case ForPartsWithDeclarations():
        final vars = _vars(
          p.variables,
          ctx,
        ).replaceFirst(RegExp('^const '), 'let ');
        return '$vars; ${p.condition == null ? '' : _expr(p.condition!, ctx)}; '
            '${p.updaters.map((u) => _expr(u, ctx)).join(', ')}';
      case ForPartsWithExpression():
        return '${p.initialization == null ? '' : _expr(p.initialization!, ctx)}; '
            '${p.condition == null ? '' : _expr(p.condition!, ctx)}; '
            '${p.updaters.map((u) => _expr(u, ctx)).join(', ')}';
      case ForEachPartsWithDeclaration():
        final kw =
            p.loopVariable.keyword?.lexeme == 'var' ||
                p.loopVariable.keyword == null
            ? 'let'
            : 'const';
        return '$kw ${_local(p.loopVariable.declaredFragment?.element, p.loopVariable.name.lexeme)} of ${_iterable(p.iterable, ctx)}';
      case ForEachPartsWithIdentifier():
        return '${_expr(p.identifier, ctx)} of ${_iterable(p.iterable, ctx)}';
      default:
        return _fail(p, 'Pattern for-loops are not in the lite subset.');
    }
  }

  String _iterable(Expression e, _Ctx ctx) {
    final t = e.staticType;
    if (_map(t)) {
      return _fail(e, 'Iterate over a map with .keys, .values or .entries.');
    }
    // `for (final k in m.keys)`: a copy, and a change of the map while it
    // runs is a ConcurrentModificationError (`$iter`), like Dart's.
    final (Expression? target, String? prop) = switch (e) {
      PropertyAccess(isNullAware: false) => (e.target, e.propertyName.name),
      PrefixedIdentifier() => (e.prefix, e.identifier.name),
      _ => (null, null),
    };
    if (target != null &&
        _map(target.staticType) &&
        (prop == 'keys' || prop == 'values' || prop == 'entries')) {
      return "${_use(r'$iter')}(${_expr(target, ctx)}, '$prop')";
    }
    return _expr(e, ctx);
  }

  /// `for (final (a, b) in pairs)`: the loop's head (`const $e of pairs`)
  /// and the declarations that open its body.
  (String, String) _forPattern(ForEachPartsWithPattern p, _Ctx ctx) {
    final v = '\$e${_tmp++}';
    final m = _match(p.pattern, v, ctx);
    return (
      'const $v of ${_iterable(p.iterable, ctx)}',
      _binds(m, mutable: p.keyword.lexeme == 'var'),
    );
  }

  /// Whether every case of a switch is a constant (a JS `switch` does it).
  bool _constantCases(Iterable<GuardedPattern> cases) =>
      cases.every((g) => g.whenClause == null && _isConstantPattern(g.pattern));

  bool _isConstantPattern(DartPattern p) => switch (p) {
    ConstantPattern() => !_valueEq(p.expression.staticType),
    WildcardPattern(type: null) => true,
    LogicalOrPattern() =>
      _isConstantPattern(p.leftOperand) && _isConstantPattern(p.rightOperand),
    ParenthesizedPattern() => _isConstantPattern(p.pattern),
    _ => false,
  };

  String _switchStatement(SwitchStatement s, _Ctx ctx) {
    if (!_constantCases([
      for (final m in s.members)
        if (m is SwitchPatternCase) m.guardedPattern,
    ])) {
      return _patternSwitch(s, ctx);
    }
    final out = StringBuffer('switch (${_expr(s.expression, ctx)}) {\n');
    _breaks.add(null);
    for (final m in s.members) {
      final labels = <String>[];
      switch (m) {
        case SwitchCase():
          labels.add('case ${_expr(m.expression, ctx)}:');
        case SwitchPatternCase():
          if (m.guardedPattern.whenClause != null) {
            _fail(m, '`when` guards are not in the lite subset.');
          }
          final cases = _constantPatterns(m.guardedPattern.pattern, ctx);
          if (cases == null) {
            labels.add('default:');
          } else {
            labels.addAll(cases.map((c) => 'case $c:'));
          }
        case SwitchDefault():
          labels.add('default:');
      }
      out.writeln('  ${labels.join(' ')}');
      if (m.statements.isNotEmpty) {
        final body = _block(m.statements, ctx);
        final last = m.statements.last;
        final exits =
            last is ReturnStatement ||
            last is BreakStatement ||
            last is ContinueStatement ||
            (last is ExpressionStatement && last.expression is ThrowExpression);
        final js = exits ? body : '$body\nbreak;';
        // Dart gives each case its own scope; JS's cases share one.
        final declares = m.statements.any(
          (x) =>
              x is VariableDeclarationStatement ||
              x is PatternVariableDeclarationStatement ||
              x is FunctionDeclarationStatement,
        );
        out.writeln(
          _indent(declares ? '{\n${_indent(js, '  ')}\n}' : js, '    '),
        );
      }
    }
    _breaks.removeLast();
    out.write('}');
    return '$out';
  }

  bool _exits(List<Statement> statements) {
    if (statements.isEmpty) return false;
    final last = statements.last;
    return last is ReturnStatement ||
        last is BreakStatement ||
        last is ContinueStatement ||
        (last is ExpressionStatement && last.expression is ThrowExpression);
  }

  /// A switch with patterns that JS's `switch` can't match (types, fields,
  /// guards): a labeled block of ifs, cases in order; a `break` inside
  /// leaves the block.
  String _patternSwitch(SwitchStatement s, _Ctx ctx) {
    final label = '\$sw${_tmp++}';
    final v = '\$v${_tmp++}';
    final out = StringBuffer(
      '$label: {\n  const $v = ${_expr(s.expression, ctx)};\n',
    );
    // Empty cases share the next case's body (`case A: case B: body`).
    final pending = <GuardedPattern>[];
    var hasDefault = false;
    for (final m in s.members) {
      if (m is SwitchPatternCase) pending.add(m.guardedPattern);
      if (m is SwitchCase) {
        _fail(m, 'Mix of old-style and pattern cases: not in the lite subset.');
      }
      if (m is SwitchDefault) hasDefault = true;
      if (m.statements.isEmpty && m is! SwitchDefault) continue;
      final body = _breakScope(label, () {
        final b = _block(m.statements, ctx);
        return _exits(m.statements) ? b : '$b\nbreak $label;';
      });
      if (hasDefault) {
        out.writeln(_indent('{\n${_indent(body, '  ')}\n}', '  '));
        pending.clear();
        break;
      }
      final alternatives = [
        for (final g in pending) (g, _match(g.pattern, v, ctx)),
      ];
      pending.clear();
      if (alternatives.length > 1 &&
          alternatives.any(
            (a) => a.$2.binds.isNotEmpty || a.$1.whenClause != null,
          )) {
        _fail(
          m,
          'Cases sharing a body with variables or guards: not in the lite subset.',
        );
        continue;
      }
      if (alternatives.length == 1) {
        final (g, match) = alternatives.single;
        out.writeln(_indent(_caseIf(match, g.whenClause, body, ctx), '  '));
      } else {
        final cond = alternatives.map((a) => '(${_and(a.$2)})').join(' || ');
        out.writeln(_indent('if ($cond) {\n${_indent(body, '  ')}\n}', '  '));
      }
    }
    out.write('}');
    return '$out';
  }

  /// `if (conds) { binds; [if (guard)] body }`.
  String _caseIf(_Match m, WhenClause? when, String body, _Ctx ctx) {
    final binds = _binds(m);
    var inner = body;
    if (when != null) {
      inner =
          'if (${_expr(when.expression, ctx)}) {\n${_indent(body, '  ')}\n}';
    }
    inner = binds.isEmpty ? inner : '$binds\n$inner';
    final cond = _and(m);
    if (cond == 'true') return '{\n${_indent(inner, '  ')}\n}';
    return 'if ($cond) {\n${_indent(inner, '  ')}\n}';
  }

  /// `if (value case pattern when guard) then else otherwise`.
  String _ifCase(
    String value,
    GuardedPattern g,
    String Function() then,
    String Function()? otherwise,
    _Ctx ctx,
  ) {
    final v = '\$v${_tmp++}';
    final m = _match(g.pattern, v, ctx);
    final binds = _binds(m);
    final cond = _and(m);
    final guard = g.whenClause == null
        ? null
        : _expr(g.whenClause!.expression, ctx);
    final thenJs = then();
    final elseJs = otherwise?.call();
    if (guard == null) {
      final inner = binds.isEmpty ? thenJs : '$binds\n$thenJs';
      return '{\n  const $v = $value;\n  if ($cond) {\n${_indent(inner, '    ')}\n  }'
          '${elseJs == null ? '' : ' else {\n${_indent(elseJs, '    ')}\n  }'}\n}';
    }
    // A guard: the else branch runs when the pattern or the guard fails.
    final h = '\$h${_tmp++}';
    final hit = elseJs == null ? thenJs : '$h = true;\n$thenJs';
    final inner =
        '${binds.isEmpty ? '' : '$binds\n'}if ($guard) {\n${_indent(hit, '  ')}\n}';
    return '{\n  const $v = $value;\n${elseJs == null ? '' : '  let $h = false;\n'}'
        '  if ($cond) {\n${_indent(inner, '    ')}\n  }'
        '${elseJs == null ? '' : '\n  if (!$h) {\n${_indent(elseJs, '    ')}\n  }'}\n}';
  }

  // -------------------------------------------------------------------------
  // Patterns: what a pattern tests on a value and the variables it binds.

  _Match _match(DartPattern p, String v, _Ctx ctx) {
    final m = _Match();
    _matchInto(p, v, m, ctx);
    return m;
  }

  String _and(_Match m) => m.conds.isEmpty ? 'true' : m.conds.join(' && ');

  /// The variables of [m] as one declaration (`const a = $v.$1, b = …;`).
  String _binds(_Match m, {bool mutable = false}) {
    if (m.binds.isEmpty) return '';
    final kw = mutable || m.binds.any((b) => b.$3) ? 'let' : 'const';
    return '$kw ${m.binds.map((b) => '${b.$1} = ${b.$2}').join(', ')};';
  }

  TypeSystem get _types => _unit.unit.declaredFragment!.element.typeSystem;

  /// Adds a test that [v] (of static type [from]) is a [to], unless it
  /// statically is.
  void _typeCond(String v, DartType? from, DartType to, _Match m, AstNode at) {
    if (from != null && from is! DynamicType && _types.isSubtypeOf(from, to)) {
      return;
    }
    final test = _typeTest(v, to, at);
    if (test == null) {
      _fail(
        at,
        'Matching the type ${to.getDisplayString()} is not in the lite subset.',
      );
      return;
    }
    m.conds.add(test);
  }

  void _matchInto(DartPattern p, String v, _Match m, _Ctx ctx) {
    final mt = p.matchedValueType;
    switch (p) {
      case ParenthesizedPattern():
        _matchInto(p.pattern, v, m, ctx);
      case ConstantPattern():
        final c = p.expression;
        if (c is NullLiteral) {
          m.conds.add('$v == null');
        } else {
          m.conds.add(_eqJs(v, _operand(c, ctx), mt, c.staticType, p));
        }
      case WildcardPattern():
        if (p.type?.type case final t?) _typeCond(v, mt, t, m, p);
      case DeclaredVariablePattern():
        if (p.type?.type case final t?) _typeCond(v, mt, t, m, p);
        m.binds.add((
          _local(p.declaredFragment?.element, p.name.lexeme),
          v,
          p.keyword?.lexeme == 'var',
        ));
      case AssignedVariablePattern():
        _fail(p, 'Assigning in a pattern is only supported in `(a, b) = …`.');
      case ObjectPattern():
        final t = p.type.type;
        if (t == null) {
          _fail(p, 'Unresolved type.');
          return;
        }
        _typeCond(v, mt, t, m, p);
        for (final f in p.fields) {
          final name = f.effectiveName;
          if (name == null) {
            _fail(f, 'Unnamed field pattern.');
            continue;
          }
          final sub = _memberOf(v, t, name, f);
          if (sub == null) continue;
          _matchInto(f.pattern, sub, m, ctx);
        }
      case RecordPattern():
        if (mt is! RecordType) {
          // The shape of a record: its fields (`$1`…, then the named ones).
          var n = 0;
          final keys = [
            for (final f in p.fields)
              f.name == null ? '\$${++n}' : f.effectiveName!,
          ];
          m.conds.add(
            "($v != null && typeof $v === 'object' && Object.keys($v).length === ${keys.length}"
            "${keys.map((k) => " && '$k' in $v").join()})",
          );
        }
        var i = 1;
        for (final f in p.fields) {
          final key = f.name == null ? '\$${i++}' : f.effectiveName!;
          _matchInto(f.pattern, '$v.$key', m, ctx);
        }
      case NullCheckPattern():
        m.conds.add('$v != null');
        _matchInto(p.pattern, v, m, ctx);
      case CastPattern():
        // Like `as` elsewhere: no check (a wrong cast is a Dart error).
        _matchInto(p.pattern, v, m, ctx);
      case LogicalAndPattern():
        _matchInto(p.leftOperand, v, m, ctx);
        _matchInto(p.rightOperand, v, m, ctx);
      case LogicalOrPattern():
        final l = _match(p.leftOperand, v, ctx);
        final r = _match(p.rightOperand, v, ctx);
        if (l.binds.isNotEmpty || r.binds.isNotEmpty) {
          _fail(p, 'Variables in `||` patterns are not in the lite subset.');
        }
        m.conds.add('(${_and(l)} || ${_and(r)})');
      case MapPattern():
        _mapPattern(p, v, m, ctx);
      case ListPattern():
        _listPattern(p, v, m, ctx);
      case RelationalPattern():
        final op = p.operator.lexeme;
        final r = _operand(p.operand, ctx);
        final rt = p.operand.staticType;
        if (op == '==' || op == '!=') {
          final eq = _eqJs(v, r, mt, rt, p);
          m.conds.add(op == '==' ? eq : '!$eq');
        } else {
          m.conds.add('(${_binaryJs(op, v, r, mt, rt, p)})');
        }
      default:
        _fail(p, 'This pattern is not in the lite subset: ${_src(p)}.');
    }
  }

  /// Whether the static type `from` already is a `to`.
  bool _staticallyA(DartType? from, DartType to) =>
      from != null && from is! DynamicType && _types.isSubtypeOf(from, to);

  /// Whether the pattern's required collection type [t] has type arguments
  /// a run-time test would have to check (JS arrays and objects carry none).
  bool _reifiedArgs(DartType? t) =>
      t is InterfaceType &&
      t.typeArguments.any(
        (a) =>
            !(a is DynamicType ||
                a.isDartCoreObject &&
                    a.nullabilitySuffix == NullabilitySuffix.question),
      );

  bool _isa(DartType? t, bool Function(InterfaceType) test) =>
      t is InterfaceType && (test(t) || t.allSupertypes.any(test));

  /// `{'a': var x}`: a map (tested when the static type isn't one) that
  /// has each key, and each value matches. Extra keys don't matter.
  void _mapPattern(MapPattern p, String v, _Match m, _Ctx ctx) {
    final mt = p.matchedValueType;
    final static = _isa(mt, (t) => t.isDartCoreMap);
    if (!static) {
      if (_reifiedArgs(p.requiredType)) {
        _fail(
          p,
          'A map pattern with type arguments on a value that is not '
          'statically a Map: JS maps carry no types to test.',
        );
        return;
      }
      m.conds.add('${_use(r'$isMap')}($v)');
    }
    for (final e in p.elements) {
      if (e is! MapPatternEntry) {
        _fail(e, 'This map pattern element is not in the lite subset.');
        continue;
      }
      final k = _expr(e.key, ctx);
      final (has, get) = ('$v.has($k)', '$v.get($k)');
      m.conds.add(has);
      _matchInto(e.value, get, m, ctx);
    }
  }

  /// `[a, b, ...rest]`: a list (tested when the static type isn't one) of
  /// that length (at least, with a rest), and each element matches.
  void _listPattern(ListPattern p, String v, _Match m, _Ctx ctx) {
    final mt = p.matchedValueType;
    if (!_isa(mt, (t) => t.isDartCoreList)) {
      if (_reifiedArgs(p.requiredType)) {
        _fail(
          p,
          'A list pattern with an element type on a value that is not '
          'statically a List: JS arrays carry no types to test.',
        );
        return;
      }
      m.conds.add('Array.isArray($v)');
    }
    final rest = p.elements.indexWhere((e) => e is RestPatternElement);
    final before = rest < 0 ? p.elements.length : rest;
    final after = rest < 0 ? 0 : p.elements.length - rest - 1;
    m.conds.add(
      rest < 0
          ? '$v.length === ${p.elements.length}'
          : '$v.length >= ${before + after}',
    );
    for (var i = 0; i < p.elements.length; i++) {
      final e = p.elements[i];
      if (e is RestPatternElement) {
        if (e.pattern case final sub?) {
          _matchInto(
            sub,
            after == 0
                ? '$v.slice($before)'
                : '$v.slice($before, $v.length - $after)',
            m,
            ctx,
          );
        }
      } else if (e is DartPattern) {
        final at = rest < 0 || i < rest
            ? '$v[$i]'
            : '$v[$v.length - ${p.elements.length - i}]';
        _matchInto(e, at, m, ctx);
      }
    }
  }

  /// [v].[name] for a field pattern on type [t], or null (with an error).
  String? _memberOf(String v, DartType t, String name, AstNode at) {
    if (_enumLike(t) && (name == 'index' || name == 'name')) return '$v.$name';
    if (t is InterfaceType && _isApp(t.element)) return '$v.${_mangle(name)}';
    // `MapEntry(:key, :value)`: an entry is `{key, value}` (see `entries`).
    if (t is InterfaceType &&
        t.element.name == 'MapEntry' &&
        (name == 'key' || name == 'value')) {
      return '$v.$name';
    }
    if ((_str(t) || _list(t)) && name == 'length') return '$v.length';
    if ((_str(t) || _list(t)) && (name == 'isEmpty' || name == 'isNotEmpty')) {
      return '($v.length ${name == 'isEmpty' ? '===' : '!=='} 0)';
    }
    _fail(
      at,
      'Field `$name` of ${t.getDisplayString()} in a pattern is not in the lite subset.',
    );
    return null;
  }

  /// `(a, b) = (b, a)`: the value once, then each variable.
  String _patternAssignment(PatternAssignment e, _Ctx ctx) {
    final v = '\$a${_tmp++}';
    final writes = <String>[];
    void walk(DartPattern p, String at) {
      switch (p) {
        case ParenthesizedPattern():
          walk(p.pattern, at);
        case AssignedVariablePattern():
          final el = p.element;
          if (el is LocalVariableElement || el is FormalParameterElement) {
            writes.add('${_local(el, p.name.lexeme)} = $at;');
          } else {
            _fail(p, 'Only local variables can be assigned by a pattern.');
          }
        case WildcardPattern():
          break;
        case RecordPattern():
          var i = 1;
          for (final f in p.fields) {
            walk(
              f.pattern,
              '$at.${f.name == null ? '\$${i++}' : f.effectiveName!}',
            );
          }
        default:
          _fail(p, 'This pattern is not in the lite subset here: ${_src(p)}.');
      }
    }

    walk(e.pattern, v);
    return '(($v) => { ${writes.join(' ')} return $v; })(${_expr(e.expression, ctx)})';
  }

  /// The JS constants a case pattern matches, or null for `_`.
  List<String>? _constantPatterns(DartPattern p, _Ctx ctx) {
    switch (p) {
      case ConstantPattern():
        return [_expr(p.expression, ctx)];
      case WildcardPattern():
        return null;
      case LogicalOrPattern():
        final l = _constantPatterns(p.leftOperand, ctx);
        final r = _constantPatterns(p.rightOperand, ctx);
        if (l == null || r == null) return null;
        return [...l, ...r];
      default:
        _fail(
          p,
          'Only constant patterns (`case Tab.home:`, `_`) are in the lite subset.',
        );
        return ['undefined'];
    }
  }

  // -------------------------------------------------------------------------
  // Expressions.

  /// [e] parenthesized when it is not a primary expression in JS.
  String _operand(Expression e, _Ctx ctx) {
    final js = _expr(e, ctx);
    if (e is ParenthesizedExpression) return js;
    final bare = e.unParenthesized;
    // Operators written as calls in JS need no parentheses.
    if (bare is BinaryExpression &&
        const {
          '%',
          '>>',
          '>>>',
          '<<',
          '~/',
          '&',
          '|',
          '^',
        }.contains(bare.operator.lexeme) &&
        !_bool(bare.leftOperand.staticType)) {
      return js;
    }
    if (bare is BinaryExpression ||
        bare is ConditionalExpression ||
        bare is AssignmentExpression ||
        bare is FunctionExpression ||
        bare is ThrowExpression ||
        bare is PrefixExpression ||
        bare is AsExpression && _needsParens(bare.expression) ||
        bare is IsExpression ||
        bare is PostfixExpression &&
            bare.operator.type == TokenType.BANG &&
            _needsParens(bare.operand)) {
      return '($js)';
    }
    return js;
  }

  bool _needsParens(Expression e) {
    final b = e.unParenthesized;
    return b is BinaryExpression ||
        b is ConditionalExpression ||
        b is AssignmentExpression ||
        b is PrefixExpression ||
        b is IsExpression ||
        b is AsExpression && _needsParens(b.expression);
  }

  /// What the next element of a `?.`/`!` chain hangs from, or null when [n]
  /// is not a link of a chain.
  Expression? _chainTarget(Expression n) => switch (n) {
    PropertyAccess() => n.target,
    MethodInvocation() => n.target,
    IndexExpression() => n.target,
    PostfixExpression() when n.operator.type == TokenType.BANG => n.operand,
    _ => null,
  };

  bool _nullAwareLink(Expression n) => switch (n) {
    PropertyAccess() => n.isNullAware,
    MethodInvocation() => n.isNullAware && n.target != null,
    IndexExpression() => n.isNullAware,
    _ => false,
  };

  /// Whether [e], a link of a chain, is the last one (its parent does not
  /// go on from it).
  bool _chainEnd(Expression e) {
    final p = e.parent;
    return !(p is Expression &&
        p is! ParenthesizedExpression &&
        _chainTarget(p) == e);
  }

  /// The innermost `?.` link under a `!` of the chain that ends at [e]: in
  /// Dart the `!` (and everything after it) is skipped when the `?.` finds
  /// null, so a check can only apply where the receiver was not null.
  Expression? _shortedBang(Expression e) {
    if (_chainTarget(e) == null || !_chainEnd(e)) return null;
    Expression? found;
    var bang = false;
    for (Expression? n = e; n != null; n = _chainTarget(n)) {
      if (bang && _nullAwareLink(n)) found = n;
      if (n is PostfixExpression) bang = true;
    }
    return found;
  }

  /// JS for [e] (a chain with a `!` after a `?.`): the `?.`'s receiver once,
  /// then null or the chain on the non-null receiver (`$nn` inside).
  String? _shortedChain(Expression e, _Ctx ctx) {
    if (!checks || _wrapped.contains(e)) return null;
    final link = _shortedBang(e);
    if (link == null) return null;
    final target = _chainTarget(link)!;
    final recv = _expr(target, ctx);
    final q = '\$q${_tmp++}';
    _override[target] = q;
    _noShort.add(link);
    _wrapped.add(e);
    try {
      return '(($q) => $q == null ? null : ${_expr(e, ctx)})($recv)';
    } finally {
      _override.remove(target);
      _noShort.remove(link);
      _wrapped.remove(e);
    }
  }

  final _override = <Expression, String>{};
  final _noShort = <Expression>{};
  final _wrapped = <Expression>{};

  String _expr(Expression e, _Ctx ctx) {
    if (_override[e] case final o?) return o;
    if ((e is Identifier || e is PropertyAccess) &&
        _isCurveType(e.staticType)) {
      return _fail(
        e,
        'A Curve is only the `curve:` argument of an animation in a lite '
        'state (it is compiled to CSS there); it cannot be passed, stored or '
        'read.',
      );
    }
    if (checks) {
      if (_shortedChain(e, ctx) case final js?) return js;
    }
    switch (e) {
      case ParenthesizedExpression():
        return '(${_expr(e.expression, ctx)})';
      case IntegerLiteral():
        final v = e.value;
        if (v == null || v.abs() > 9007199254740991) {
          return _fail(e, 'Integer literal outside the exact JS range (2^53).');
        }
        return '$v';
      case DoubleLiteral():
        final v = e.value;
        // Integral and exact in JS: the integer's digits (`2`), and `1e20`
        // past 2^53 (toInt would saturate at 2^63).
        return v == v.truncateToDouble() && v.abs() < 9007199254740992
            ? '${v.toInt()}'
            : '$v';
      case BooleanLiteral():
        return '${e.value}';
      case NullLiteral():
        return 'null';
      case SimpleStringLiteral():
        return _quote(e.value);
      case AdjacentStrings():
        return e.strings.map((s) => _operand(s, ctx)).join(' + ');
      case StringInterpolation():
        return _interpolation(e, ctx);
      case SimpleIdentifier():
        return _identifier(e, ctx);
      case PrefixedIdentifier():
        return _property(e, e.prefix, e.identifier, ctx, nullAware: false);
      case DotShorthandPropertyAccess():
        final owner = _shorthandOwner(e.propertyName);
        if (owner == null) {
          return _fail(e, 'Expression not in the lite subset: ${_src(e)}.');
        }
        return _property(
          e,
          null,
          e.propertyName,
          ctx,
          nullAware: false,
          shorthand: owner,
        );
      case DotShorthandInvocation():
        return _shorthandInvocation(e, ctx);
      case DotShorthandConstructorInvocation():
        final ctor = e.element?.baseElement;
        final n = e.constructorName.name;
        return _construct(
          e,
          ctor,
          n == 'new' ? null : n,
          e.argumentList,
          e.isConst,
          ctx,
        );
      case PropertyAccess():
        return _property(
          e,
          e.target,
          e.propertyName,
          ctx,
          nullAware: e.isNullAware && !_noShort.contains(e),
        );
      case MethodInvocation():
        return _invocation(e, ctx);
      case FunctionExpressionInvocation():
        final f = e.function;
        final t = f.staticType;
        if (t is! FunctionType) {
          return _fail(e, 'Only calls of functions are supported (no call()).');
        }
        return '${_operand(f, ctx)}(${_args(e.argumentList, null, ctx)})';
      case InstanceCreationExpression():
        return _creation(e, ctx);
      case IndexExpression():
        return _index(e, ctx);
      case AssignmentExpression():
        return _assignment(e, ctx);
      case BinaryExpression():
        return _binary(e, ctx);
      case PrefixExpression():
        return _prefix(e, ctx);
      case PostfixExpression():
        if (e.operator.type == TokenType.BANG) {
          final v = _expr(e.operand, ctx);
          return checks ? '${_use(r'$nn')}($v)' : v;
        }
        return '${_lvalue(e.operand, ctx)}${e.operator.lexeme}';
      case ConditionalExpression():
        return '${_operand(e.condition, ctx)} ? ${_operand(e.thenExpression, ctx)} : ${_operand(e.elseExpression, ctx)}';
      case ListLiteral():
        return _listLiteral(e, ctx);
      case SetOrMapLiteral():
        return _mapLiteral(e, ctx);
      case RecordLiteral():
        return _record(e, ctx);
      case FunctionExpression():
        final isVoid = e.declaredFragment?.element.returnType is VoidType;
        return '${_async(e.body)}(${_params(e.parameters!, ctx)}) => ${_arrowBody(e.body, ctx, returns: !isVoid)}';
      case AsExpression():
        return _cast(e, ctx);
      case IsExpression():
        return _isTest(e, ctx);
      case CascadeExpression():
        return _cascadeExpr(e, ctx);
      case ThrowExpression():
        return _throw(e, ctx);
      case RethrowExpression():
        if (_caught.isEmpty) return _fail(e, '`rethrow` outside a catch.');
        return '(() => { throw ${_caught.last}; })()';
      case SwitchExpression():
        return _switchExpression(e, ctx);
      case AwaitExpression():
        return '(await ${_operand(e.expression, ctx)})';
      case ThisExpression():
        if (ctx.ext != null) return r'$this';
        if (ctx.cls != null) return 'this';
        return _fail(e, '`this` in a ThorState: use the members directly.');
      case NamedExpression():
        return _expr(e.expression, ctx);
      case TypeLiteral():
        final te = e.type.element;
        if (te is InterfaceElement && _isApp(te) && topNames[te] != null) {
          return topNames[te]!;
        }
        return _fail(
          e,
          'The type ${e.type} as a value is not in the lite subset.',
        );
      case FunctionReference():
        // A generic function's tear-off (`math.max` for `reduce`): types go.
        return _expr(e.function, ctx);
      case PatternAssignment():
        return _patternAssignment(e, ctx);
      case SuperExpression():
        if (ctx.cls != null) return 'super';
        return _fail(e, '`super` is not in the lite subset here.');
      default:
        return _fail(e, 'Expression not in the lite subset: ${_src(e)}.');
    }
  }

  // A `Curve` argument as the CSS easing it compiles to, at build time (the
  // browser plays it): `Curves.easeOut`, a constant of the app, or a
  // `Cubic(...)` / `Interval(...)` / `FlippedCurve(...)` ... written in place.
  String _curveCss(Expression e) {
    final curve = _curveOf(e);
    if (curve == null) {
      _fail(
        e,
        'The curve of an animation must be a constant a lite state can '
        'compile to CSS: `Curves.easeOut`, `const Cubic(...)`, '
        '`const Interval(...)`, `FlippedCurve(...)` or a const of the app '
        'that holds one.',
      );
      return "'linear'";
    }
    return _quote(curve.css);
  }

  st.Curve? _curveOf(Expression e) {
    e = e.unParenthesized;
    if (e is InstanceCreationExpression) {
      final name = e.constructorName.type.name.lexeme;
      final a = e.argumentList.arguments;
      final pos = a.where((x) => x is! NamedExpression).toList();
      double? num(int i) => i < pos.length ? _constNum(pos[i]) : null;
      switch (name) {
        case 'Cubic':
          final v = [for (var i = 0; i < 4; i++) num(i)];
          return v.contains(null) ? null : st.Cubic(v[0]!, v[1]!, v[2]!, v[3]!);
        case 'Threshold':
          final x = num(0);
          return x == null ? null : st.Threshold(x);
        case 'FlippedCurve':
          final c = pos.isEmpty ? null : _curveOf(pos[0]);
          return c == null ? null : st.FlippedCurve(c);
        case 'Interval':
          final begin = num(0), end = num(1);
          if (begin == null || end == null) return null;
          Expression? curve;
          for (final n in a.whereType<NamedExpression>()) {
            if (n.name.label.name == 'curve') curve = n.expression;
          }
          final c = curve == null ? st.Curves.linear : _curveOf(curve);
          return c == null ? null : st.Interval(begin, end, curve: c);
        case 'ElasticOutCurve' || 'ElasticInCurve' || 'ElasticInOutCurve':
          final period = pos.isEmpty ? 0.4 : num(0);
          if (period == null) return null;
          return switch (name) {
            'ElasticOutCurve' => st.ElasticOutCurve(period),
            'ElasticInCurve' => st.ElasticInCurve(period),
            _ => st.ElasticInOutCurve(period),
          };
      }
      return null;
    }
    // A name (`Curves.easeOut`, a const of the app): its constant value.
    final el = switch (e) {
      Identifier() => e.element,
      PropertyAccess() => e.propertyName.element,
      _ => null,
    };
    final variable = switch (el) {
      PropertyAccessorElement() => el.variable,
      VariableElement() => el,
      _ => null,
    };
    final value = variable?.computeConstantValue();
    if (value != null) return _curveOfValue(value);
    // A `final` initialized with a constant curve expression.
    if (variable != null && variable.isFinal && !variable.isLate) {
      final init = _initializers[variable.baseElement];
      if (init != null && _curveDepth < 8) {
        _curveDepth++;
        try {
          return _curveOf(init);
        } finally {
          _curveDepth--;
        }
      }
    }
    return null;
  }

  int _curveDepth = 0;

  /// The initializer of each variable the app declares (top level and fields).
  late final Map<Element, Expression> _initializers = () {
    final out = <Element, Expression>{};
    void add(VariableDeclaration v) {
      final el = v.declaredFragment?.element;
      final init = v.initializer;
      if (el != null && init != null) out[el.baseElement] = init;
    }

    for (final d in decls.values) {
      switch (d.node) {
        case final VariableDeclaration v:
          add(v);
        case final ClassDeclaration c:
          for (final m in c.body.members) {
            if (m is FieldDeclaration) m.fields.variables.forEach(add);
          }
        case final MixinDeclaration c:
          for (final m in c.body.members) {
            if (m is FieldDeclaration) m.fields.variables.forEach(add);
          }
        default:
      }
    }
    return out;
  }();

  st.Curve? _curveOfValue(DartObject o) {
    double? d(String f) {
      final v = o.getField(f);
      return v?.toDoubleValue() ?? v?.toIntValue()?.toDouble();
    }

    switch (o.type?.element?.name) {
      case '_Linear':
        return st.Curves.linear;
      case '_BounceOut':
        return st.Curves.bounceOut;
      case '_BounceIn':
        return st.Curves.bounceIn;
      case '_BounceInOut':
        return st.Curves.bounceInOut;
      case 'Cubic':
        final v = [d('a'), d('b'), d('c'), d('d')];
        return v.contains(null) ? null : st.Cubic(v[0]!, v[1]!, v[2]!, v[3]!);
      case 'Threshold':
        final x = d('threshold');
        return x == null ? null : st.Threshold(x);
      case 'FlippedCurve':
        final c = o.getField('curve');
        final inner = c == null ? null : _curveOfValue(c);
        return inner == null ? null : st.FlippedCurve(inner);
      case 'Interval':
        final begin = d('begin'), end = d('end');
        final c = o.getField('curve');
        final inner = c == null ? null : _curveOfValue(c);
        return begin == null || end == null || inner == null
            ? null
            : st.Interval(begin, end, curve: inner);
      case 'ElasticOutCurve':
        final p = d('period');
        return p == null ? null : st.ElasticOutCurve(p);
      case 'ElasticInCurve':
        final p = d('period');
        return p == null ? null : st.ElasticInCurve(p);
      case 'ElasticInOutCurve':
        final p = d('period');
        return p == null ? null : st.ElasticInOutCurve(p);
      case 'ThreePointCubic':
        st.Offset? off(String f) {
          final p = o.getField(f);
          final dx = p?.getField('dx')?.toDoubleValue();
          final dy = p?.getField('dy')?.toDoubleValue();
          return dx == null || dy == null ? null : st.Offset(dx, dy);
        }

        final a1 = off('a1'), b1 = off('b1'), mid = off('midpoint');
        final a2 = off('a2'), b2 = off('b2');
        return a1 == null ||
                b1 == null ||
                mid == null ||
                a2 == null ||
                b2 == null
            ? null
            : st.ThreePointCubic(a1, b1, mid, a2, b2);
    }
    return null;
  }

  /// A number written in place (`0.5`, `-1`, `1 / 3`), or null.
  double? _constNum(Expression e) {
    e = e.unParenthesized;
    if (e is IntegerLiteral) return e.value?.toDouble();
    if (e is DoubleLiteral) return e.value;
    if (e is PrefixExpression && e.operator.lexeme == '-') {
      final v = _constNum(e.operand);
      return v == null ? null : -v;
    }
    if (e is BinaryExpression) {
      final l = _constNum(e.leftOperand), r = _constNum(e.rightOperand);
      if (l == null || r == null) return null;
      return switch (e.operator.lexeme) {
        '+' => l + r,
        '-' => l - r,
        '*' => l * r,
        '/' => l / r,
        _ => null,
      };
    }
    return null;
  }

  String _quote(String s) {
    final b = StringBuffer("'");
    for (final r in s.runes) {
      switch (r) {
        case 0x27:
          b.write(r"\'");
        case 0x5C:
          b.write(r'\\');
        case 0x0A:
          b.write(r'\n');
        case 0x0D:
          b.write(r'\r');
        case 0x09:
          b.write(r'\t');
        case 0x2028:
          b.write(r'\u2028');
        case 0x2029:
          b.write(r'\u2029');
        default:
          b.writeCharCode(r);
      }
    }
    b.write("'");
    return '$b';
  }

  String _interpolation(StringInterpolation e, _Ctx ctx) {
    final b = StringBuffer('`');
    for (final el in e.elements) {
      switch (el) {
        case InterpolationString():
          b.write(
            el.value
                .replaceAll(r'\', r'\\')
                .replaceAll('`', r'\`')
                .replaceAll(r'${', r'\${')
                // A raw CR (or CRLF) in a template literal reads as LF, and
                // the output indents every raw line: escape the controls.
                .replaceAll('\r', r'\r')
                .replaceAll('\n', r'\n')
                .replaceAll('\t', r'\t')
                .replaceAll('\u2028', r'\u2028')
                .replaceAll('\u2029', r'\u2029'),
          );
        case InterpolationExpression():
          b.write('\${${_toStr(el.expression, ctx)}}');
      }
    }
    b.write('`');
    return '$b';
  }

  /// [e] as Dart's `'$e'` would print it.
  String _toStr(Expression e, _Ctx ctx) {
    final t = e.staticType;
    final js = _expr(e, ctx);
    if (t == null || t is DynamicType) {
      return _fail(
        e,
        'Interpolating a dynamic value: cast it to String, num or bool.',
      );
    }
    if (_str(t) || _num(t) || _bool(t) || t.isDartCoreNull) return js;
    if (_dateValue(t) || _locale(t)) return js; // their toString() is Dart's
    // Enum values, StringBuffers and dart:core's exceptions (`$X`) print
    // with their toString().
    if (_enumLike(t) || _stringBuffer(t) || _coreException(t)) return js;
    // A list or set of values that print the same: `[1, 2]`, `{a, b}`.
    if ((_list(t) || _set(t)) &&
        t is InterfaceType &&
        t.typeArguments.length == 1 &&
        _printable(t.typeArguments.single)) {
      return '${_use(r'$str')}($js)';
    }
    if (t is InterfaceType && _isApp(t.element) && _hasToString(t.element)) {
      return js;
    }
    if (t is InterfaceType &&
        t.element.name == 'Type' &&
        t.element.library.isDartCore) {
      return _fail(
        e,
        'Printing a `.runtimeType`: JS keeps no class names in the browser '
        '(only `a.runtimeType == b.runtimeType` is in the lite subset).',
      );
    }
    return _fail(
      e,
      'Interpolating a ${t.getDisplayString()}: Dart and JS print it '
      'differently.',
    );
  }

  String _identifier(SimpleIdentifier id, _Ctx ctx) {
    final raw = id.element;
    final e = raw?.baseElement;
    if (e == null) return _fail(id, 'Unresolved name ${id.name}.');
    switch (e) {
      case LocalVariableElement():
      case FormalParameterElement():
      case LocalFunctionElement():
        return _local(e, id.name);
      case PropertyAccessorElement():
        return _accessor(id, e, ctx);
      case MethodElement():
        final cls = e.enclosingElement;
        if (ctx.state != null && ctx.state!.owns(cls)) {
          return _stateName(e.name!);
        }
        if (cls is InterfaceElement && _isApp(cls)) {
          return e.isStatic
              ? '${topNames[cls]}.${_mangle(e.name!)}'
              : 'this.${_mangle(e.name!)}.bind(this)';
        }
        return _fail(id, 'Method ${e.name} is not in the lite subset.');
      case TopLevelFunctionElement():
        if (_isApp(e)) return topNames[e]!;
        return _core(id, e.name!, e);
      case ClassElement():
      case EnumElement():
        if (_isApp(e)) return topNames[e]!;
        return _fail(id, 'Type ${e.name} is not in the lite subset.');
      default:
        return _fail(id, '${id.name} is not in the lite subset.');
    }
  }

  /// A dart:core / dart:math top-level function used as a value.
  String _core(AstNode at, String name, Element e) {
    final lib = '${e.library?.uri}';
    if (lib == 'dart:math') {
      // JS passes callbacks extra arguments (reduce: index, array).
      if (name == 'min' || name == 'max') return '((a, b) => Math.$name(a, b))';
      if (_math.contains(name)) return '((x) => Math.$name(x))';
    }
    if (lib == 'dart:core' && name == 'identical') return r'Object.is';
    return _fail(at, '$name (${e.library?.uri}) is not in the lite subset.');
  }

  /// A getter/setter referenced by a bare name.
  String _accessor(SimpleIdentifier id, PropertyAccessorElement e, _Ctx ctx) {
    final v = e.variable;
    if (v.name == 'runtimeType' && ctx.cls != null) return 'this.constructor';
    if (v is TopLevelVariableElement) {
      final stateId = _stateInstance(v);
      if (stateId != null) return "\$.use('$stateId')";
      if (_isApp(v)) return topNames[v]!;
      final lib = '${v.library.uri}';
      if (lib == 'dart:math') {
        const math = {'pi': 'Math.PI', 'e': 'Math.E'};
        if (math[v.name] case final js?) return js;
      }
      return _fail(
        id,
        '${v.name} (${v.library.uri}) is not in the lite subset.',
      );
    }
    final cls = v.enclosingElement;
    if (cls is ExtensionElement && _isApp(cls)) {
      return '${_extName(cls, v.name!, getter: true)}(\$this)';
    }
    // Inside an extension, a getter of the extended type (`isNegative`).
    if (ctx.ext != null && cls is InterfaceElement && !_isApp(cls)) {
      return _propertyOn(id, id, ctx.ext!.extendedType, r'$this', ctx);
    }
    // Inside an enum: its values by bare name (`this == none`).
    if (cls is EnumElement && v is FieldElement && v.isStatic) {
      if (_enumValue(cls, v.name!) case final js?) return js;
    }
    final state = ctx.state;
    if (state != null && state.owns(cls)) {
      if (e is GetterElement && !v.isOriginDeclaration ||
          state.getters.contains(e)) {
        return '${_stateName(v.name!)}()';
      }
      return _stateName(v.name!);
    }
    if (_inThor(cls) && v.name == 'key' && state != null) return r'$.key';
    if (cls is InterfaceElement && _isApp(cls)) {
      if (v.isStatic) return '${topNames[cls]}.${_mangle(v.name!)}';
      // Its own, or inherited from a class of the app it extends.
      final self = ctx.cls;
      if (self == cls ||
          self != null && self.allSupertypes.any((t) => t.element == cls)) {
        return 'this.${_mangle(v.name!)}';
      }
    }
    return _fail(id, '${v.name} is not in the lite subset here.');
  }

  String _target(Expression? target, _Ctx ctx) {
    if (target == null) {
      if (_cascade != null) return _cascade!;
      throw StateError('no target');
    }
    return _operand(target, ctx);
  }

  String _property(
    Expression whole,
    Expression? target,
    SimpleIdentifier name,
    _Ctx ctx, {
    required bool nullAware,
    // The type a dot shorthand (`.loading`) resolves to: like `Type.loading`.
    InterfaceElement? shorthand,
  }) {
    final prop = name.name;
    // Static members, enum values, prefixed imports.
    final Element? te = target is Identifier ? target.element : shorthand;
    if (target is Identifier || shorthand != null) {
      if (te is EnumElement) {
        if (_enumValue(te, prop) case final js?) return js;
      }
      if (te is InterfaceElement && _isApp(te)) {
        // `State.x` inside the state: its constant.
        if (ctx.state != null && ctx.state!.owns(te)) return _stateName(prop);
        final top = topNames[te];
        if (top == null) {
          return _fail(
            whole,
            'Static field $prop of ${te.name} is not in the lite subset '
            'outside its state: move it to the top level.',
          );
        }
        return '$top.${_mangle(prop)}';
      }
      if (te is PrefixElement) return _identifier(name, ctx);
      if (te is InterfaceElement) {
        if (_valueStatics[_valueType(te.thisType)]?[prop] case final js?) {
          if (js.startsWith(r'$Dur')) used.add(r'$Dur');
          return js;
        }
        if (_inThor(te)) {
          if (te.name == 'HardwareKeyboard' && prop == 'instance') {
            return _use(r'$keys');
          }
          if (te.name == 'LogicalKeyboardKey') {
            if (_logicalKeys[prop] case final label?) {
              final quoted = label.replaceAll("'", r"\'");
              return "${_use(r'$LK')}('$quoted')";
            }
          }
          if (te.name == 'Clipboard' && prop == 'kTextPlain') {
            return "'text/plain'";
          }
        }
        if (te.name == 'TextEditingValue' && prop == 'empty' && _inThor(te)) {
          _use(r'$Ctext');
          return '${_use(r'$C')}.val()';
        }
        if (te.name == 'double' && prop == 'infinity') return 'Infinity';
        if (te.name == 'double' && prop == 'nan') return 'NaN';
        if (te.name == 'double' && prop == 'negativeInfinity') {
          return '-Infinity';
        }
        return _fail(whole, '${te.name}.$prop is not in the lite subset.');
      }
    }
    final t =
        target?.staticType ??
        (_cascade != null
            ? (whole as PropertyAccess).realTarget.staticType
            : null);
    final r = _target(target, ctx);
    // A `?.` before this link (`n?.keys.length`) gave the null-or-value
    // wrapper: Dart's `?.` skips the rest of the chain, so this link
    // checks it too.
    if (nullAware || _shortWrapped(r)) {
      return _nullAware(whole, r, (q) => _propertyOn(whole, name, t, q, ctx));
    }
    return _propertyOn(whole, name, t, r, ctx);
  }

  /// Whether [js] is `_nullAware`'s temporary form: null or a value.
  bool _shortWrapped(String js) => js.startsWith('((\$q');

  /// [recv]`?.`… as JS: the member access itself when the translation is a
  /// plain one (`recv?.x`, `recv?.f(…)`); otherwise the receiver once, then
  /// null or the translation ([on] of a temporary).
  String _nullAware(
    Expression whole,
    String recv,
    String Function(String q) on,
  ) {
    final q = '\$q${_tmp++}';
    final js = on(q);
    if (js.startsWith('$q.') && js.indexOf(q, 1) < 0) {
      final chain = '$recv?.${js.substring(q.length + 1)}';
      // JS's `?.` gives undefined; Dart's null prints and encodes as null.
      final parent = whole.parent;
      final nullish =
          parent is ExpressionStatement ||
          parent is BinaryExpression &&
              (parent.operator.type == TokenType.QUESTION_QUESTION &&
                      parent.leftOperand == whole ||
                  parent.leftOperand is NullLiteral ||
                  parent.rightOperand is NullLiteral) ||
          parent is PropertyAccess && parent.target == whole ||
          parent is MethodInvocation && parent.target == whole;
      return nullish ? chain : '($chain ?? null)';
    }
    return '(($q) => $q == null ? null : $js)($recv)';
  }

  String _propertyOn(
    Expression whole,
    SimpleIdentifier name,
    DartType? t,
    String recv,
    _Ctx ctx,
  ) {
    final prop = name.name;
    final el = name.element?.baseElement;
    const dot = '.';
    // `super.getter` of a class of the app.
    if (recv == 'super' &&
        el is PropertyAccessorElement &&
        _isApp(el.variable.enclosingElement)) {
      return 'super.${_mangle(prop)}';
    }
    // `(a, b).wait` / `futures.wait` (dart:async's extensions): they fail
    // with a ParallelWaitError, which lite has not.
    if (prop == 'wait' && el?.library?.isDartAsync == true) {
      return _fail(
        whole,
        '`.wait` of futures fails with a ParallelWaitError: not in the lite '
        'subset.',
      );
    }
    // `e.message` of a FormatException (`int.parse`, `jsonDecode`, the
    // app's own): the message dart2js gives it (`FormatException()`'s: '').
    if (prop == 'message' &&
        t is InterfaceType &&
        t.element.library.isDartCore &&
        t.element.name == 'FormatException') {
      return "($recv.m ?? '')";
    }
    // `x.hashCode`: the app's own getter, else the runtime's (`$hash`: the
    // numbers are not Dart's).
    if (prop == 'hashCode' && recv != 'super' && _valueType(t) == null) {
      return '${_use(r'$hash')}($recv)';
    }
    if (el is PropertyAccessorElement &&
        el.variable.enclosingElement is ExtensionElement &&
        _isApp(el.variable.enclosingElement)) {
      return '${_extName(el.variable.enclosingElement as ExtensionElement, prop, getter: true)}($recv)';
    }
    if (_list(t) && _fromCollection(el)) {
      switch (prop) {
        case 'sum':
          return '$recv.reduce((a, b) => a + b, 0)';
        case 'max':
          return '${_use(r'$maxmin')}($recv, (a, b) => a >= b)';
        case 'min':
          return '${_use(r'$maxmin')}($recv, (a, b) => a <= b)';
      }
    }
    if (isServerEventStreamType(t)) {
      if (const {
        'data',
        'loading',
        'error',
        'errorKind',
        'connection',
      }.contains(prop)) {
        if (prop == 'errorKind') _serverErrorKind(whole);
        return '$recv$dot$prop';
      }
      if (prop == 'snapshot') {
        _snapshotEnums(whole);
        return '$recv${dot}snapshot()';
      }
      return _fail(
        whole,
        'ServerEventStream.$prop is not in the lite subset (data, loading, error, '
        'errorKind, connection and snapshot are).',
      );
    }
    if (isServerQueryType(t)) {
      if (const {
        'data',
        'loading',
        'error',
        'errorKind',
        'arg',
      }.contains(prop)) {
        if (prop == 'errorKind') _serverErrorKind(whole);
        return '$recv$dot$prop';
      }
      if (prop == 'snapshot') {
        _snapshotEnums(whole);
        return '$recv${dot}snapshot()';
      }
      return _fail(whole, 'ServerQuery.$prop is not in the lite subset.');
    }
    if (isAsyncSnapshotType(t)) {
      if (const {
        'connectionState',
        'data',
        'hasData',
        'error',
        'errorKind',
        'hasError',
      }.contains(prop)) {
        return '$recv$dot$prop';
      }
      return _fail(
        whole,
        prop == 'requireData'
            ? '`requireData` of an AsyncSnapshot is not in the lite subset: '
                  'check `hasData` and use `data!`.'
            : 'AsyncSnapshot.$prop is not in the lite subset '
                  '(connectionState, data, hasData, error, errorKind and '
                  'hasError are).',
      );
    }
    if (isServerCommandType(t)) {
      if (const {'pending', 'error', 'errorKind', 'result'}.contains(prop)) {
        if (prop == 'errorKind') _serverErrorKind(whole);
        return '$recv$dot$prop';
      }
      return _fail(whole, 'A command\'s $prop is not in the lite subset.');
    }
    if (_isSignal(t)) {
      if (prop == 'value') return '$recv${dot}value';
      if (_setSignal(t) != null) {
        switch (prop) {
          case 'length':
            return '$recv${dot}value.size';
          case 'isEmpty':
            return '($recv${dot}value.size === 0)';
          case 'isNotEmpty':
            return '($recv${dot}value.size > 0)';
        }
      }
      return _fail(
        whole,
        'Signal.$prop is not in the lite subset (use .value).',
      );
    }
    // A member of another state (`counter.count`).
    if (t is InterfaceType && _isStateClass(t.element)) {
      final member = el is PropertyAccessorElement ? el.variable : el;
      if (member is FieldElement && _isSignal(member.type)) {
        return '$recv$dot\$s.${_mangle(prop)}';
      }
      if (el is MethodElement) return '$recv$dot$prop';
      return _fail(
        whole,
        'Only signals and methods of another state can be used.',
      );
    }
    if (t is RecordType) {
      return '$recv$dot$prop';
    }
    if (_completer(t) && (prop == 'future' || prop == 'isCompleted')) {
      return '$recv$dot$prop';
    }
    if (_timer(t)) {
      if (prop == 'isActive' || prop == 'tick') return '$recv$dot$prop';
      return _fail(whole, '`.$prop` of Timer is not in the lite subset.');
    }
    if (_valueType(t) case final vt?) {
      // A Duration made by the datetime part (timeZoneOffset) needs its part.
      if (_valueType(whole.staticType) == 'Duration') used.add(r'$Dur');
      if (_valueGetters[vt]!.contains(prop)) {
        // The parts give thor's enums (TimeOfDay.period) as their index.
        final wt = whole.staticType;
        if (_isEnum(wt)) {
          final n = _enumName((wt! as InterfaceType).element)!;
          return '$n\$values[$recv.$prop]';
        }
        return '$recv$dot$prop';
      }
      return _fail(whole, '`.$prop` of $vt is not in the lite subset.');
    }
    if (_enumLike(t) && (prop == 'index' || prop == 'name')) {
      return '$recv$dot$prop';
    }
    // Two `runtimeType`s compare by class (a Type can not be printed, see
    // `_toStr`): the constructor of the object.
    if (prop == 'runtimeType' &&
        (t is InterfaceType && _isApp(t.element) ||
            _maybeValue(t) ||
            _str(t) ||
            _num(t))) {
      return '$recv${dot}constructor';
    }
    if (t is InterfaceType && _isApp(t.element)) {
      return '$recv$dot${_mangle(prop)}';
    }
    if (_str(t) || _list(t)) {
      switch (prop) {
        case 'length':
          return '$recv${dot}length';
        case 'isEmpty':
          return '($recv${dot}length === 0)';
        case 'isNotEmpty':
          return '($recv${dot}length !== 0)';
      }
    }
    if (_list(t)) {
      switch (prop) {
        case 'first':
          used.add(r'$first');
          return '\$first($recv)';
        case 'last':
          used.add(r'$last');
          return '\$last($recv)';
        // Iterable<T?>.nonNulls, Iterable<T>.indexed (records `(i, x)`).
        case 'nonNulls':
          return '$recv${dot}filter((x) => x != null)';
        case 'indexed':
          _recordsMade = true;
          return '$recv${dot}map((x, i) => Object.freeze({ \$1: i, \$2: x }))';
        case 'firstOrNull':
          return '($recv[0] ?? null)';
        case 'lastOrNull':
          return _bound(recv, (l) => '($l[$l.length - 1] ?? null)');
        case 'reversed':
          return '[...$recv].reverse()';
        case 'single':
          return checks ? '${_use(r'$single')}($recv)' : '$recv[0]';
        case 'singleOrNull':
          return _bound(recv, (l) => '($l.length === 1 ? $l[0] : null)');
      }
    }
    if (_set(t)) {
      switch (prop) {
        case 'length':
          return '$recv${dot}size';
        case 'isEmpty':
          return '($recv${dot}size === 0)';
        case 'isNotEmpty':
          return '($recv${dot}size !== 0)';
        case 'first':
          return '${_use(r'$first')}([...$recv])';
        case 'last':
          return '${_use(r'$last')}([...$recv])';
        case 'firstOrNull':
          return '([...$recv][0] ?? null)';
        case 'nonNulls':
          return '[...$recv].filter((x) => x != null)';
        case 'indexed':
          _recordsMade = true;
          return '[...$recv].map((x, i) => Object.freeze({ \$1: i, \$2: x }))';
      }
    }
    if (t is InterfaceType &&
        t.element.name == 'HardwareKeyboard' &&
        _inThor(t.element) &&
        const {
          'isShiftPressed',
          'isControlPressed',
          'isAltPressed',
          'isMetaPressed',
        }.contains(prop)) {
      return '$recv$dot$prop';
    }
    if (t is InterfaceType &&
        t.element.name == 'ClipboardData' &&
        _inThor(t.element) &&
        prop == 'text') {
      return '$recv${dot}text';
    }
    if (_stringBuffer(t) &&
        const {'length', 'isEmpty', 'isNotEmpty'}.contains(prop)) {
      return '$recv$dot$prop';
    }
    if (_regExpMatch(t)) {
      switch (prop) {
        case 'start':
          return '$recv${dot}index';
        case 'end':
          return _bound(recv, (m) => '($m.index + $m[0].length)');
        case 'groupCount':
          return '($recv.length - 1)';
        case 'input':
          return '$recv${dot}input';
      }
    }
    if (_map(t)) {
      switch (prop) {
        case 'keys':
          return '[...$recv.keys()]';
        case 'values':
          return '[...$recv.values()]';
        case 'length':
          return '$recv${dot}size';
        case 'isEmpty':
          return '($recv${dot}size === 0)';
        case 'isNotEmpty':
          return '($recv${dot}size !== 0)';
        case 'entries':
          return '[...$recv].map(([key, value]) => ({ key, value }))';
      }
    }
    if (t is InterfaceType && t.element.name == 'MapEntry') {
      if (prop == 'key' || prop == 'value') return '$recv$dot$prop';
    }
    if (_num(t)) {
      switch (prop) {
        case 'isEven':
          return '($recv % 2 === 0)';
        case 'isOdd':
          return '(Math.abs($recv % 2) === 1)';
        case 'isNegative':
          return _bound(recv, (n) => '($n < 0 || Object.is($n, -0))');
        case 'isNaN':
          return 'Number.isNaN($recv)';
        case 'isFinite':
          return 'Number.isFinite($recv)';
        case 'sign':
          return 'Math.sign($recv)';
      }
    }
    return _fail(
      whole,
      '`.$prop` on ${t?.getDisplayString() ?? 'this'} is not in the lite subset.',
    );
  }

  String _args(ArgumentList list, ExecutableElement? callee, _Ctx ctx) {
    final args = list.arguments;
    if (callee == null) {
      if (args.any((a) => a is NamedExpression)) {
        _fail(list, 'Named arguments to a function value are not supported.');
      }
      return args.map((a) => _expr(a, ctx)).join(', ');
    }
    final positional = [
      for (final a in args)
        if (a is! NamedExpression) a,
    ];
    final named = {
      for (final a in args.whereType<NamedExpression>())
        a.name.label.name: a.expression,
    };
    final out = <String>[];
    var i = 0;
    for (final p in callee.formalParameters) {
      if (p.isNamed) {
        final a = named[p.name];
        out.add(a == null ? 'undefined' : _expr(a, ctx));
      } else {
        out.add(
          i < positional.length ? _expr(positional[i++], ctx) : 'undefined',
        );
      }
    }
    while (out.isNotEmpty && out.last == 'undefined') {
      out.removeLast();
    }
    return out.join(', ');
  }

  /// The class or enum a dot shorthand member belongs to (what `.x` stands
  /// for in `Type.x`), or null when it does not resolve.
  InterfaceElement? _shorthandOwner(SimpleIdentifier member) {
    final owner = member.element?.baseElement.enclosingElement;
    return owner is InterfaceElement ? owner : null;
  }

  /// `.name(args)`: the static method (or constructor) of the context type.
  String _shorthandInvocation(DotShorthandInvocation e, _Ctx ctx) {
    final el = e.memberName.element?.baseElement;
    final name = e.memberName.name;
    if (el is ConstructorElement) {
      return _construct(
        e,
        el,
        name == 'new' ? null : name,
        e.argumentList,
        false,
        ctx,
      );
    }
    final owner = _shorthandOwner(e.memberName);
    if (el is! MethodElement || !el.isStatic || owner == null) {
      return _fail(e, 'Expression not in the lite subset: ${_src(e)}.');
    }
    return _staticCall(e, owner, name, el, e.argumentList, ctx);
  }

  String _invocation(MethodInvocation m, _Ctx ctx) {
    final name = m.methodName.name;
    final el = m.methodName.element?.baseElement;
    final target = m.target;
    final args = m.argumentList.arguments;
    // Flutter's habit: `super.dispose()` / `super.onHydrated()`. ThorState's
    // own are empty.
    if (target is SuperExpression && ctx.state != null) {
      // A mixin's (or the base state's) definition of the same method.
      if (ctx.state!.supers[name] case final below?) {
        return '$below(${_args(m.argumentList, el is ExecutableElement ? el : null, ctx)})';
      }
      if (args.isEmpty &&
          (name == 'dispose' || name == 'onHydrated') &&
          el is MethodElement &&
          _inThor(el)) {
        return 'undefined';
      }
    }
    // `super.method(...)` of a class of the app (or of a mixin it uses).
    if (target is SuperExpression &&
        ctx.cls != null &&
        el is MethodElement &&
        !el.isStatic &&
        _isApp(el.enclosingElement)) {
      return 'super.${_mangle(name)}(${_args(m.argumentList, el, ctx)})';
    }
    // `math.max(...)`: a function of an import with a prefix.
    final prefixed =
        target is SimpleIdentifier && target.element is PrefixElement;
    // Bare calls: functions, methods of the state or class, local closures.
    if (target == null && !m.isCascaded || prefixed) {
      if (el is TopLevelFunctionElement && !_isApp(el)) {
        final lib = '${el.library.uri}';
        if (lib == 'dart:core' && name == 'identical') {
          return '(${_operand(args[0], ctx)} === ${_operand(args[1], ctx)})';
        }
        if (lib == 'dart:convert' && name == 'jsonDecode') {
          if (args.length != 1) {
            return _fail(
              m,
              'jsonDecode with a reviver is not in the lite subset.',
            );
          }
          return '${_use(r'$json')}(${_expr(args[0], ctx)})';
        }
        if (lib == 'dart:convert' && name == 'jsonEncode') {
          if (args.length != 1) {
            return _fail(
              m,
              'jsonEncode with toEncodable is not in the lite subset.',
            );
          }
          return '${_use(r'$jenc')}(${_expr(args[0], ctx)})';
        }
        if (lib.startsWith('package:collection/') && name == 'groupBy') {
          final type = m.staticType;
          if (type != null) _checkElements(m, type, 'Map keys');
          return '${_use(r'$group')}(${_expr(args[0], ctx)}, ${_expr(args[1], ctx)}, ${_newMap(type)})';
        }
        if (lib == 'dart:core' && name == 'print') {
          return 'console.log(${_toStr(args[0], ctx)})';
        }
        // dart:async's `unawaited(f)` only marks the future as not awaited
        // (the linter's `unawaited_futures`): JS already lets a promise run
        // on its own, so the argument is evaluated and dropped.
        if (lib == 'dart:async' && name == 'unawaited' && args.length == 1) {
          return 'void (${_expr(args[0], ctx)})';
        }
        if (lib == 'dart:math' && _math.contains(name)) {
          return 'Math.$name(${_args(m.argumentList, null, ctx)})';
        }
        if (_inThor(el) && name == 'state') {
          return _fail(m, '`state(...)` only in a ThorState field.');
        }
        if (_inThor(el) && (name == 'hideToast' || name == 'clearToasts')) {
          if (args.isNotEmpty) {
            return _fail(m, '$name() takes no arguments.');
          }
          return '${_use(r'$toastHide')}(${name == 'clearToasts'})';
        }
        if (_inThor(el) && (name == 'confirm' || name == 'toast')) {
          final positional = args.where((a) => a is! NamedExpression).toList();
          final named = {
            for (final n in args.whereType<NamedExpression>())
              n.name.label.name: n.expression,
          };
          String opt(String key, [String Function(String)? wrap]) {
            final e = named[key];
            if (e == null) return 'null';
            final js = _expr(e, ctx);
            return wrap == null ? js : wrap(js);
          }

          if (name == 'confirm') {
            return '${_use(r'$confirm')}(${_expr(positional.single, ctx)}, '
                "${opt('message')}, ${opt('confirmLabel')}, ${opt('cancelLabel')})";
          }
          final kind = named['kind'] == null
              ? "'info'"
              : '${_expr(named['kind']!, ctx)}.name';
          if (named['duration'] != null) used.add(r'$Dur');
          return '${_use(r'$toast')}(${_expr(positional.single, ctx)}, $kind, '
              "${opt('duration', (d) => '$d.inMilliseconds')})";
        }
        if (_inThor(el) && (name == 'batch' || name == 'untracked')) {
          // The runtime's own: one flush of effects at the end / no tracking.
          return 'thor.$name(${_args(m.argumentList, null, ctx)})';
        }
        return _fail(m, '$name (${el.library.uri}) is not in the lite subset.');
      }
      final callee = el is ExecutableElement ? el : null;
      if (el is LocalVariableElement ||
          el is FormalParameterElement ||
          el is PropertyAccessorElement) {
        // A function value.
        return '${_identifier(m.methodName, ctx)}(${_args(m.argumentList, null, ctx)})';
      }
      if (el is MethodElement) {
        final cls = el.enclosingElement;
        if (cls is ExtensionElement && _isApp(cls)) {
          final a = _args(m.argumentList, callee, ctx);
          return '${_extName(cls, name, getter: false)}(\$this${a.isEmpty ? '' : ', $a'})';
        }
        // Inside an extension, a member of the extended type (`toDouble()`).
        if (ctx.ext != null && !m.isCascaded) {
          return _invocationOn(m, ctx.ext!.extendedType, r'$this', ctx);
        }
        if (ctx.state != null && ctx.state!.owns(cls)) {
          return '${_stateName(name)}(${_args(m.argumentList, callee, ctx)})';
        }
        if (cls is InterfaceElement && _isApp(cls)) {
          final recv = el.isStatic ? topNames[cls]! : 'this';
          return '$recv.${_mangle(name)}(${_args(m.argumentList, callee, ctx)})';
        }
      }
      if (el is TopLevelFunctionElement) {
        return '${topNames[el]}(${_args(m.argumentList, callee, ctx)})';
      }
      if (el is LocalFunctionElement) {
        return '${_local(el, name)}(${_args(m.argumentList, callee, ctx)})';
      }
      return _fail(m, 'Call of $name is not in the lite subset.');
    }
    // Static calls: `int.parse`, `Item.fromJson` (factory = creation), enum.
    if (target is Identifier) {
      final te = target.element;
      if (te is InterfaceElement) {
        return _staticCall(m, te, name, el, m.argumentList, ctx);
      }
    }
    final t = m.realTarget?.staticType;
    final r = _target(target, ctx);
    if (m.isNullAware && !_noShort.contains(m) || _shortWrapped(r)) {
      return _nullAware(m, r, (q) => _invocationOn(m, t, q, ctx));
    }
    return _invocationOn(m, t, r, ctx);
  }

  String _invocationOn(MethodInvocation m, DartType? t, String recv, _Ctx ctx) {
    final name = m.methodName.name;
    final el = m.methodName.element?.baseElement;
    final args = m.argumentList.arguments;
    const dot = '.';
    if (el is MethodElement &&
        el.enclosingElement is ExtensionElement &&
        _isApp(el.enclosingElement)) {
      final ea = _args(m.argumentList, el, ctx);
      return '${_extName(el.enclosingElement as ExtensionElement, name, getter: false)}($recv${ea.isEmpty ? '' : ', $ea'})';
    }
    // `animateTo(offset, duration:, curve:)` and `animateToPage(page, ...)`:
    // the duration, and the curve as the CSS easing it compiles to.
    if ((name == 'animateTo' || name == 'animateToPage') &&
        const {'ScrollController', 'PageController'}.contains(_valueType(t))) {
      final offset = args.firstWhere((x) => x is! NamedExpression);
      final named = {
        for (final n in args.whereType<NamedExpression>())
          n.name.label.name: n.expression,
      };
      final duration = named['duration'];
      final curve = named['curve'];
      if (duration == null || curve == null) {
        return _fail(m, '$name needs its `duration:` and `curve:`.');
      }
      used.add(r'$Dur');
      return '$recv$dot$name(${_expr(offset, ctx)}, ${_expr(duration, ctx)}, '
          '${_curveCss(curve)})';
    }
    // `animateTo(target, duration:, curve:)`, `animateBack` and
    // `fling(velocity:)` of an AnimationController: the duration, and the
    // curve as the CSS easing it compiles to (a fling is a spring the part
    // samples itself).
    if (const {'animateTo', 'animateBack', 'fling'}.contains(name) &&
        _valueType(t) == 'AnimationController') {
      final named = {
        for (final n in args.whereType<NamedExpression>())
          n.name.label.name: n.expression,
      };
      final positional = args.where((x) => x is! NamedExpression).toList();
      if (name == 'fling') {
        final v = named['velocity'];
        return '$recv${dot}fling(${v == null ? '' : _expr(v, ctx)})';
      }
      final duration = named['duration'];
      final curve = named['curve'];
      if (duration != null) used.add(r'$Dur');
      final tail = [
        if (duration != null || curve != null)
          duration == null ? 'null' : _expr(duration, ctx),
        if (curve != null) _curveCss(curve),
      ];
      return '$recv$dot$name(${[_expr(positional.first, ctx), ...tail].join(', ')})';
    }
    final a = [for (final x in args) _expr(x, ctx)];
    if (isServerEventStreamType(t)) {
      if (name == 'refresh' || name == 'reconnect') {
        return '$recv$dot$name(${a.join(', ')})';
      }
      return _fail(
        m,
        'ServerEventStream.$name is not in the lite subset (refresh and '
        'reconnect are).',
      );
    }
    if (isServerQueryType(t)) {
      if (name == 'refresh' || name == 'setArg') {
        return '$recv$dot$name(${a.join(', ')})';
      }
      return _fail(m, 'ServerQuery.$name is not in the lite subset.');
    }
    if (isServerCommandType(t)) {
      if (name == 'run' || name == 'pendingFor') {
        return '$recv$dot$name(${a.join(', ')})';
      }
      return _fail(m, 'A command\'s $name is not in the lite subset.');
    }
    if (_isSignal(t)) {
      if (name == 'call') return '$recv${dot}value';
      if (name == 'peek') return '$recv${dot}peek()';
      // `flag.toggle()` of a `StateSignal<bool>`.
      if (name == 'toggle' && a.isEmpty && _bool(_signalValue(t))) {
        return '($recv${dot}value = !$recv${dot}value)';
      }
      if (_setSignal(t) != null) {
        if (name == 'contains' && a.length == 1) {
          return '$recv${dot}value.has(${a[0]})';
        }
        const kinds = {'add': 0, 'remove': 1, 'toggle': 2, 'clear': 3};
        if (kinds[name] case final k? when a.length == (k == 3 ? 0 : 1)) {
          return '${_use(r'$sop')}($recv, $k${a.isEmpty ? '' : ', ${a[0]}'})';
        }
      }
      if ((name == 'addListener' || name == 'removeListener') &&
          a.length == 1 &&
          (t as InterfaceType).element.name == 'StateSignal') {
        return '${_use(name == 'addListener' ? r'$addL' : r'$rmL')}($recv, ${a[0]})';
      }
      return _fail(m, 'Signal.$name is not in the lite subset.');
    }
    if (t is InterfaceType && _isStateClass(t.element)) {
      return '$recv$dot$name(${a.join(', ')})';
    }
    if (_valueType(t) case final vt?) {
      if (_valueType(m.staticType) == 'Duration') used.add(r'$Dur');
      if (name == 'toString' && args.isEmpty && _dateTypes.contains(vt) ||
          (_valueMethods[vt]?.contains(name) ?? false)) {
        return '$recv$dot$name(${_args(m.argumentList, el is ExecutableElement ? el : null, ctx)})';
      }
      return _fail(m, '`.$name()` of $vt is not in the lite subset.');
    }
    if (t is InterfaceType && _isApp(t.element) && el is MethodElement) {
      // `toString()` of a nullable prints `null` (String() calls toString).
      if (name == 'toString' &&
          args.isEmpty &&
          t.nullabilitySuffix == NullabilitySuffix.question) {
        return 'String($recv)';
      }
      return '$recv$dot${_mangle(name)}(${_args(m.argumentList, el, ctx)})';
    }
    if (_future(t)) {
      final js = _futureMethod(m, recv, name, ctx);
      if (js != null) return js;
    }
    if (_completer(t)) {
      switch (name) {
        case 'complete':
          return '$recv${dot}complete(${a.join(', ')})';
        case 'completeError':
          return '$recv${dot}completeError(${a.isEmpty ? '' : a[0]})';
      }
    }
    if (_frameSub(t)) {
      if (name == 'cancel' && args.isEmpty) return '$recv${dot}cancel()';
      return _fail(
        m,
        '`.$name()` of FrameSubscription is not in the lite subset.',
      );
    }
    if (_timer(t)) {
      if (name == 'cancel' && args.isEmpty) return '$recv${dot}cancel()';
      return _fail(m, '`.$name()` of Timer is not in the lite subset.');
    }
    if (t is FunctionType && name == 'call') return '$recv(${a.join(', ')})';
    if (name == 'toString' && args.isEmpty) {
      if (_num(t) || _bool(t) || _str(t)) return 'String($recv)';
      if (t is InterfaceType && _isApp(t.element) ||
          _enumLike(t) ||
          _stringBuffer(t)) {
        // A nullable receiver prints `null`: String() also calls toString.
        return t!.nullabilitySuffix == NullabilitySuffix.question
            ? 'String($recv)'
            : '$recv${dot}toString()';
      }
      // _toStr is for a template literal (which calls toString itself);
      // as a call its value must be the string, not the object.
      return 'String(${_toStr(m.realTarget!, ctx)})';
    }
    if (_str(t)) {
      final js = _stringMethod(m, recv, dot, name, a);
      if (js != null) return js;
    }
    if (_stringBuffer(t)) {
      switch (name) {
        case 'write':
          return '$recv${dot}write(${_toStr(args[0], ctx)})';
        case 'writeln':
          return args.isEmpty
              ? '$recv${dot}writeln()'
              : '$recv${dot}writeln(${_toStr(args[0], ctx)})';
        case 'writeCharCode':
        case 'clear':
          return '$recv$dot$name(${a.join(', ')})';
        case 'writeAll':
          final sep = a.length > 1 ? a[1] : "''";
          return _joinsLikeJs(args[0].staticType)
              ? '$recv${dot}write([...${a[0]}].join($sep))'
              : '$recv${dot}write(${_use(r'$join')}(${a[0]}, $sep))';
      }
    }
    if (_regExp(t)) {
      switch (name) {
        case 'hasMatch':
          return '$recv${dot}test(${a[0]})';
        case 'firstMatch':
          return '$recv${dot}exec(${a[0]})';
        case 'stringMatch':
          return '($recv.exec(${a[0]})?.[0] ?? null)';
        case 'allMatches':
          if (a.length > 1) break;
          return '[...${a[0]}.matchAll(${_use(r'$g')}($recv))]';
      }
    }
    if (_regExpMatch(t)) {
      if (name == 'group' && a.length == 1) return '($recv[${a[0]}] ?? null)';
      if (name == 'namedGroup') return '($recv.groups?.[${a[0]}] ?? null)';
    }
    if (_set(t)) {
      final js = _setMethod(m, recv, dot, name, a, ctx);
      if (js != null) return js;
    }
    if (_list(t) && _fromCollection(el)) {
      final js = _collectionMethod(m, recv, name, a);
      if (js != null) return js;
    }
    if (_list(t)) {
      final js = _listMethod(m, recv, dot, name, a, ctx);
      if (js != null) return js;
    }
    if (_map(t)) {
      switch (name) {
        case 'containsKey':
          return '$recv${dot}has(${a[0]})';
        case 'containsValue':
          final vt = t is InterfaceType && t.typeArguments.length == 2
              ? t.typeArguments[1]
              : null;
          if (_byValue(vt, args.first.staticType)) {
            return '[...$recv.values()].some((x) => ${_use(r'$deq')}(x, ${a[0]}))';
          }
          return '[...$recv.values()].includes(${a[0]})';
        case 'remove':
          return m.parent is ExpressionStatement
              ? '$recv${dot}delete(${a[0]})'
              : '${_use(r'$mdel')}($recv, ${a[0]})';
        case 'clear':
          return '$recv${dot}clear()';
        case 'forEach':
          return '${_use(r'$each')}($recv, ${a[0]})';
        case 'addAll':
          return _bound(
            recv,
            (m) => '(${a[0]}).forEach((v, k) => $m.set(k, v))',
          );
        case 'putIfAbsent':
          return '((m, k) => (m.has(k) ? m.get(k) : (m.set(k, (${a[1]})()), m.get(k))))($recv, ${a[0]})';
        case 'cast':
          return recv;
        case 'update':
          final absent = [
            for (final x in args.whereType<NamedExpression>())
              if (x.name.label.name == 'ifAbsent') _expr(x.expression, ctx),
          ];
          return '${_use(r'$mupd')}($recv, ${a[0]}, ${a[1]}${absent.isEmpty ? '' : ', ${absent.single}'})';
        case 'updateAll':
          return '((m, f) => { for (const [k, v] of [...m]) m.set(k, f(k, v)); })($recv, ${a[0]})';
        case 'removeWhere':
          return '((m, f) => { for (const [k, v] of [...m]) if (f(k, v)) m.delete(k); })($recv, ${a[0]})';
        case 'addEntries':
          return '((m, l) => { for (const e of [...l]) m.set(e.key, e.value); })($recv, ${a[0]})';
        case 'map':
          final type = m.staticType;
          if (type != null) _checkElements(m, type, 'Map keys');
          return '((m, f) => ${_newMap(type, '[...m].map(([k, v]) => { const e = f(k, v); return [e.key, e.value]; })')})($recv, ${a[0]})';
      }
    }
    if (_num(t)) {
      switch (name) {
        case 'abs':
          return 'Math.abs($recv)';
        case 'floor':
        case 'ceil':
          return 'Math.$name($recv)';
        case 'round':
          used.add(r'$round');
          return '\$round($recv)';
        case 'truncate':
        case 'toInt':
          return 'Math.trunc($recv)';
        case 'toDouble':
          return recv;
        case 'toStringAsFixed':
          // `4.toFixed(1)` is a syntax error in JS: a bare integer literal.
          return '${RegExp(r'^\d+$').hasMatch(recv) ? '($recv)' : recv}'
              '.toFixed(${a[0]})';
        case 'clamp':
          return 'Math.min(Math.max($recv, ${a[0]}), ${a[1]})';
        case 'compareTo':
          used.add(r'$cmp');
          return '\$cmp($recv, ${a[0]})';
        case 'remainder':
          return '($recv % ${a[0]})';
        case 'roundToDouble':
          return '${_use(r'$round')}($recv)';
        case 'floorToDouble':
          return 'Math.floor($recv)';
        case 'ceilToDouble':
          return 'Math.ceil($recv)';
        case 'truncateToDouble':
          return 'Math.trunc($recv)';
      }
    }
    return _fail(
      m,
      '`.$name()` on ${t?.getDisplayString() ?? '?'} is not in the lite subset.',
    );
  }

  bool _future(DartType? t) =>
      t is InterfaceType &&
      t.element.name == 'Future' &&
      t.element.library.isDartAsync;

  bool _completer(DartType? t) =>
      t is InterfaceType &&
      t.element.name == 'Completer' &&
      t.element.library.isDartAsync;

  /// `Future.wait(...)`, `Future.any`, `Future.error`, `Future.forEach` and
  /// `Future.doWhile`: promises, with Dart's order and error rules.
  /// `Type.name(args)`: a static method of [te] (the explicit form, or the
  /// context type of a dot shorthand `.name(args)`).
  String _staticCall(
    Expression m,
    InterfaceElement te,
    String name,
    Element? el,
    ArgumentList argList,
    _Ctx ctx,
  ) {
    final args = argList.arguments;
    if (_isApp(te) && el is MethodElement && el.isStatic) {
      // `State.helper(…)` inside the state: its local function.
      if (ctx.state != null && ctx.state!.owns(te)) {
        return '${_stateName(name)}(${_args(argList, el, ctx)})';
      }
      final top = topNames[te];
      if (top == null) {
        return _fail(
          m,
          'Static method $name of ${te.name} is not in the lite subset outside its state.',
        );
      }
      return '$top.${_mangle(name)}(${_args(argList, el, ctx)})';
    }
    final a0 =
        args.isEmpty ||
            te.name == 'SystemNavigator' ||
            te.name == 'PageNavigator' ||
            te.name == 'Clipboard' ||
            te.name == 'FrameMessages'
        ? ''
        : _expr(args[0], ctx);
    switch ('${te.name}.$name') {
      case 'Object.hash':
        if (!te.library.isDartCore) break;
        return '${_use(r'$hashAll')}([${[for (final x in args) _expr(x, ctx)].join(', ')}])';
      case 'Object.hashAll':
        if (!te.library.isDartCore) break;
        return '${_use(r'$hashAll')}($a0)';
      case 'Object.hashAllUnordered':
        if (!te.library.isDartCore) break;
        return '${_use(r'$hashSum')}($a0)';
      case 'int.parse':
        used.add(r'$int');
        return '\$int($a0)';
      case 'int.tryParse':
        used.add(r'$tryInt');
        return '\$tryInt($a0)';
      case 'double.parse':
      case 'num.parse':
        used.add(r'$double');
        return '\$double($a0)';
      case 'double.tryParse':
      case 'num.tryParse':
        used.add(r'$tryDouble');
        return '\$tryDouble($a0)';
      case 'Future.wait' ||
          'Future.any' ||
          'Future.error' ||
          'Future.forEach' ||
          'Future.doWhile':
        if (!te.library.isDartAsync) break;
        return _futureStatic(m, name, argList, ctx);
    }
    if (_valueType(te.thisType) == 'DateTime' && name == 'parse') {
      return '${_use(r'$dtp')}($a0)';
    }
    if (_valueType(te.thisType) == 'DateTime' && name == 'tryParse') {
      return '${_use(r'$DT')}.tryParse($a0)';
    }
    if (te.name == 'Locale' && _inThor(te) && name == 'tryParse') {
      return '${_use(r'$Loc')}.tryParse($a0)';
    }
    if (te.name == 'Intl' && '${te.library.uri}'.startsWith('package:intl/')) {
      switch (name) {
        case 'canonicalizedLocale':
          return '${_use(r'$I')}.canon($a0)';
        case 'pluralLogic':
          final named = {
            for (final n in args.whereType<NamedExpression>())
              n.name.label.name: _expr(n.expression, ctx),
          };
          if (named.containsKey('meaning')) {
            return _fail(
              m,
              'Intl.pluralLogic(meaning:) is not in the lite subset.',
            );
          }
          final order = [
            'zero', 'one', 'two', 'few', 'many', 'other', 'locale', //
            'precision', 'useExplicitNumberCases',
          ];
          final out = [a0, for (final k in order) named[k] ?? 'undefined'];
          while (out.last == 'undefined') {
            out.removeLast();
          }
          return '${_use(r'$I')}.plural(${out.join(', ')})';
      }
    }
    if (te.name == 'DateUtils' && _inThor(te)) {
      return '${_use(r'$DU')}.$name(${_args(argList, el is ExecutableElement ? el : null, ctx)})';
    }
    if (te.library.isDartCore && te.name == 'Uri') {
      switch (name) {
        case 'encodeQueryComponent':
          return '${_use(r'$encQ')}($a0)';
        case 'decodeQueryComponent':
          return '${_use(r'$decQ')}($a0)';
        // Dart's unreserved sets are JS's here.
        case 'encodeComponent':
          return 'encodeURIComponent($a0)';
        case 'decodeComponent':
          return 'decodeURIComponent($a0)';
        case 'encodeFull':
          return 'encodeURI($a0)';
        case 'decodeFull':
          return 'decodeURI($a0)';
      }
    }
    if (te.name == 'PageNavigator' && _inThor(te) && name == 'go') {
      final positional = args.where((a) => a is! NamedExpression).toList();
      NamedExpression? named(String key) => args
          .whereType<NamedExpression>()
          .where((n) => n.name.label.name == key)
          .firstOrNull;
      final replace = named('replace');
      final flash = named('flash');
      final kind = named('flashKind');
      return '${_use(r'$go')}(${_expr(positional.single, ctx)}, '
          '${replace == null ? 'false' : _expr(replace.expression, ctx)}'
          '${flash == null ? '' : ', false, ${_expr(flash.expression, ctx)}, '
                    '${kind == null ? "'info'" : '${_expr(kind.expression, ctx)}.name'}'})';
    }
    if (te.name == 'PageNavigator' && _inThor(te)) {
      switch (name) {
        case 'pop':
          final fallback = args
              .whereType<NamedExpression>()
              .where((n) => n.name.label.name == 'fallback')
              .firstOrNull;
          return '${_use(r'$goBack')}('
              '${fallback == null ? "'/'" : _expr(fallback.expression, ctx)})';
        case 'canPop':
          return '${_use(r'$canPop')}()';
        case 'reload':
          return '${_use(r'$reload')}()';
      }
    }
    if (te.name == 'Clipboard' && _inThor(te)) {
      // The part answers in the key's own copy/paste event (no prompt).
      if (name == 'setData') {
        final data = args.single;
        final text = data is InstanceCreationExpression
            ? data.argumentList.arguments
                  .whereType<NamedExpression>()
                  .where((n) => n.name.label.name == 'text')
                  .map((n) => _expr(n.expression, ctx))
                  .firstOrNull
            : null;
        if (text == null) {
          return _fail(m, 'Clipboard.setData(ClipboardData(text: ...)) only.');
        }
        return '${_use(r'$clip')}.write($text)';
      }
      if (name == 'getData') {
        return "(${_expr(args.single, ctx)} === 'text/plain' ? ${_use(r'$clip')}.read().then((t) => t == null ? null : { text: t }) : Promise.resolve(null))";
      }
    }
    if (te.name == 'FrameMessages' && _inThor(te)) {
      NamedExpression? named(String key) => args
          .whereType<NamedExpression>()
          .where((n) => n.name.label.name == key)
          .firstOrNull;
      final positional = args.where((a) => a is! NamedExpression).toList();
      final frame = _use(r'$frame');
      switch (name) {
        case 'postToParent':
          return '$frame.post(null, ${_expr(positional.single, ctx)}, '
              '${_expr(named('targetOrigin')!.expression, ctx)})';
        case 'postToFrame':
          return '$frame.post(${_expr(positional[0], ctx)}, '
              '${_expr(positional[1], ctx)}, '
              '${_expr(named('targetOrigin')!.expression, ctx)})';
        case 'listen':
          return '$frame.listen(${_expr(named('origins')!.expression, ctx)}, '
              '${_expr(named('onMessage')!.expression, ctx)})';
      }
    }
    if (te.name == 'SystemNavigator' && _inThor(te)) {
      if (name == 'routeInformationUpdated') {
        final named = {
          for (final n in args.whereType<NamedExpression>())
            n.name.label.name: n.expression,
        };
        final uri = named['uri'];
        final location = named['location'];
        String? href;
        if (uri is InstanceCreationExpression || uri is MethodInvocation) {
          final inner =
              uri is MethodInvocation &&
                  uri.methodName.name == 'parse' &&
                  uri.argumentList.arguments.length == 1
              ? uri.argumentList.arguments.single
              : null;
          if (inner != null) href = _expr(inner, ctx);
        } else if (uri == null && location != null) {
          href = _expr(location, ctx);
        }
        if (href == null) {
          return _fail(
            m,
            'SystemNavigator.routeInformationUpdated(uri: Uri.parse(...)) '
            'or (location: ...) only.',
          );
        }
        final replace = named['replace'];
        return '${_use(r'$nav')}($href, ${replace == null ? 'false' : _expr(replace, ctx)})';
      }
    }
    return _fail(m, '${te.name}.$name is not in the lite subset.');
  }

  String _futureStatic(
    Expression m,
    String name,
    ArgumentList argList,
    _Ctx ctx,
  ) {
    final args = argList.arguments;
    final positional = [
      for (final a in args)
        if (a is! NamedExpression) a,
    ];
    final named = {
      for (final a in args.whereType<NamedExpression>())
        a.name.label.name: a.expression,
    };
    String arg(int i) => _expr(positional[i], ctx);
    switch (name) {
      case 'wait':
        if (named.containsKey('cleanUp')) {
          return _fail(m, 'Future.wait(cleanUp:) is not in the lite subset.');
        }
        final eager = named['eagerError'];
        return '${_use(r'$wait')}(${arg(0)}${eager == null ? '' : ', ${_expr(eager, ctx)}'})';
      case 'any':
        return 'Promise.race(${arg(0)})';
      case 'error':
        return 'Promise.reject(${arg(0)})';
      case 'forEach':
        return '(async (l, f) => { for (const x of [...l]) await f(x); })(${arg(0)}, ${arg(1)})';
      default: // doWhile
        return '(async (f) => { while (await f()); })(${arg(0)})';
    }
  }

  /// `then`, `catchError` and `whenComplete` of a Future (a promise).
  String? _futureMethod(
    MethodInvocation m,
    String recv,
    String name,
    _Ctx ctx,
  ) {
    final args = m.argumentList.arguments;
    final positional = [
      for (final a in args)
        if (a is! NamedExpression) a,
    ];
    final named = {
      for (final a in args.whereType<NamedExpression>())
        a.name.label.name: a.expression,
    };
    // An error handler may take the stack trace too (a JS stack, as in
    // a catch clause). Its parameter is a fresh name: the handler's own
    // code can use any.
    String handler(Expression e) {
      final js = _expr(e, ctx);
      final t = e.staticType;
      final two = t is FunctionType && t.formalParameters.length > 1;
      final x = '\$e${_tmp++}';
      return two ? "($x) => ($js)($x, $x?.stack ?? '')" : '($x) => ($js)($x)';
    }

    switch (name) {
      case 'then':
        if (positional.length != 1) return null;
        final onError = named['onError'];
        return '$recv.then(${_expr(positional[0], ctx)}${onError == null ? '' : ', ${handler(onError)}'})';
      case 'catchError':
        if (positional.length != 1) return null;
        final test = named['test'];
        if (test == null) return '$recv.catch(${handler(positional[0])})';
        final x = '\$e${_tmp++}';
        return '$recv.catch(($x) => { if (!(${_expr(test, ctx)})($x)) throw $x; return (${handler(positional[0])})($x); })';
      case 'whenComplete':
        if (positional.length != 1) return null;
        return '$recv.finally(() => (${_expr(positional[0], ctx)})())';
    }
    return null;
  }

  String? _stringMethod(
    MethodInvocation m,
    String recv,
    String dot,
    String name,
    List<String> a,
  ) {
    final args = m.argumentList.arguments;
    final re = args.isNotEmpty && _regExp(args[0].staticType);
    switch (name) {
      // The replacement is a function: JS reads `$&`, `$1`… in a string.
      case 'replaceAll':
        return re
            ? '$recv${dot}replace(${_use(r'$g')}(${a[0]}), () => ${a[1]})'
            : '$recv${dot}replaceAll(${a[0]}, () => ${a[1]})';
      case 'replaceFirst':
        if (a.length > 2) return null;
        return '$recv${dot}replace(${a[0]}, () => ${a[1]})';
      case 'contains':
        if (re) {
          if (a.length > 1) return null;
          return '${a[0]}.test($recv)';
        }
        return '$recv${dot}includes(${a.join(', ')})';
      case 'toUpperCase':
      case 'toLowerCase':
      case 'trim':
      case 'startsWith':
      case 'endsWith':
      case 'indexOf':
      case 'lastIndexOf':
      case 'split':
      case 'trimLeft':
      case 'trimRight':
        if (re) {
          switch (name) {
            case 'split':
              return '${_use(r'$resplit')}($recv, ${a[0]})';
            case 'indexOf' when a.length <= 2:
              return '${_use(r'$ixre')}($recv, ${a.join(', ')})';
            case 'startsWith' when a.length <= 2:
              return '${_use(r'$swre')}($recv, ${a.join(', ')})';
          }
          _fail(args[0], '`.$name()` with a RegExp is not in the lite subset.');
        }
        final js =
            {'trimLeft': 'trimStart', 'trimRight': 'trimEnd'}[name] ?? name;
        return '$recv$dot$js(${a.join(', ')})';
      case 'substring':
        if (checks) return '${_use(r'$sub')}($recv, ${a.join(', ')})';
        return '$recv${dot}substring(${a.join(', ')})';
      // Dart repeats the whole pad; JS's padStart cuts it.
      case 'padLeft' || 'padRight':
        final pad = args.length > 1 ? args[1] : null;
        if (pad is SimpleStringLiteral && pad.value.length == 1 ||
            a.length < 2) {
          return '$recv$dot${name == 'padLeft' ? 'padStart' : 'padEnd'}(${a.join(', ')})';
        }
        return '${_use(r'$pad')}($recv, ${a[0]}, ${a[1]}, ${name == 'padRight' ? 1 : 0})';
      case 'codeUnitAt':
        if (checks) return '${_use(r'$cu')}($recv, ${a[0]})';
        return '$recv${dot}charCodeAt(${a[0]})';
      case 'compareTo':
        used.add(r'$cmp');
        return '\$cmp($recv, ${a[0]})';
    }
    return null;
  }

  /// A Set's own members; the rest (where, map, any…) run on a copy as an
  /// array, like Dart's Iterable methods.
  String? _setMethod(
    MethodInvocation m,
    String recv,
    String dot,
    String name,
    List<String> a,
    _Ctx ctx,
  ) {
    final used = m.parent is! ExpressionStatement;
    switch (name) {
      case 'cast':
        return recv;
      case 'add':
        return used
            ? '${_use(r'$sadd')}($recv, ${a[0]})'
            : '$recv${dot}add(${a[0]})';
      case 'remove':
        return '$recv${dot}delete(${a[0]})';
      case 'contains':
        return '$recv${dot}has(${a[0]})';
      case 'clear':
        return '$recv${dot}clear()';
      case 'addAll':
        final x = '\$x${_tmp++}';
        return '((s) => { for (const $x of ${a[0]}) s.add($x); })($recv)';
      case 'removeAll':
        final x = '\$x${_tmp++}';
        return '((s) => { for (const $x of ${a[0]}) s.delete($x); })($recv)';
      case 'toSet':
        return _newSet(m.staticType, recv);
      case 'toList':
        if (a.isNotEmpty) return null;
        return '[...$recv]';
      case 'removeWhere':
        return '((s, f) => { for (const x of [...s]) if (f(x)) s.delete(x); })($recv, ${a[0]})';
      case 'retainWhere':
        return '((s, f) => { for (const x of [...s]) if (!f(x)) s.delete(x); })($recv, ${a[0]})';
      case 'containsAll':
        return '[...${a[0]}].every((x) => $recv.has(x))';
      case 'union':
        return _newSet(m.staticType, '[...$recv, ...${a[0]}]');
      case 'intersection':
        return '((s, o) => ${_newSet(m.staticType, '[...s].filter((x) => o.has(x))')})($recv, ${a[0]})';
      case 'difference':
        return '((s, o) => ${_newSet(m.staticType, '[...s].filter((x) => !o.has(x))')})($recv, ${a[0]})';
    }
    return _listMethod(m, '[...$recv]', '.', name, a, ctx);
  }

  /// Whether [e] already makes a fresh JS array (no copy for `toList`).
  bool _fresh(Expression? e) {
    final b = e?.unParenthesized;
    if (b is ListLiteral) return true;
    if (b is MethodInvocation) {
      return const {
        'where',
        'map',
        'expand',
        'toList',
        'skip',
        'take',
        'whereType',
      }.contains(b.methodName.name);
    }
    return false;
  }

  /// Whether [e] is a member of an extension of package:collection.
  bool _fromCollection(Element? e) {
    final owner = e is PropertyAccessorElement
        ? e.variable.enclosingElement
        : e?.enclosingElement;
    return owner is ExtensionElement &&
        '${owner.library.uri}'.startsWith('package:collection/');
  }

  /// The iterable helpers of package:collection most apps use.
  String? _collectionMethod(
    MethodInvocation m,
    String recv,
    String name,
    List<String> a,
  ) {
    final args = m.argumentList.arguments;
    switch (name) {
      case 'firstWhereOrNull':
        return '($recv.find(${_oneArg(a[0], args[0])}) ?? null)';
      case 'lastWhereOrNull':
        return '($recv.findLast(${_oneArg(a[0], args[0])}) ?? null)';
      case 'sortedBy':
        // A stable sort, like the package's merge sort.
        return '[...$recv].sort(((k) => (x, y) => ${_use(r'$kcmp')}(k(x), k(y)))(${_oneArg(a[0], args[0])}))';
      case 'sorted':
        return '[...$recv].sort(${a[0]})';
      case 'groupListsBy':
        final type = m.staticType;
        if (type != null) _checkElements(m, type, 'Map keys');
        return '${_use(r'$group')}($recv, ${_oneArg(a[0], args[0])}, ${_newMap(type)})';
      case 'mapIndexed':
        return '$recv.map((x, i) => (${a[0]})(i, x))';
      case 'whereIndexed':
        return '$recv.filter((x, i) => (${a[0]})(i, x))';
      case 'forEachIndexed':
        return '$recv.forEach((x, i) => (${a[0]})(i, x))';
    }
    return null;
  }

  String? _listMethod(
    MethodInvocation m,
    String recv,
    String dot,
    String name,
    List<String> a,
    _Ctx ctx,
  ) {
    final args = m.argumentList.arguments;
    final item = m.realTarget?.staticType is InterfaceType
        ? (m.realTarget!.staticType! as InterfaceType).typeArguments.firstOrNull
        : null;
    // `contains`, `indexOf`, `lastIndexOf` and `remove` ask `==`: by value
    // for dates, records and classes with `operator ==` (or when the
    // element type does not say).
    if (const {'contains', 'indexOf', 'remove', 'lastIndexOf'}.contains(name) &&
        args.isNotEmpty &&
        _byValue(item, args.first.staticType)) {
      final eq = _use(r'$deq');
      switch (name) {
        case 'contains':
          return '((l, v) => l.some((x) => $eq(x, v)))($recv, ${a[0]})';
        case 'indexOf':
          return '${_use(r'$ixeq')}($recv, ${a.join(', ')})';
        case 'lastIndexOf':
          return '${_use(r'$lixeq')}($recv, ${a.join(', ')})';
        default:
          return '((l, v) => { const i = ${_use(r'$ixeq')}(l, v); if (i < 0) return false; l.splice(i, 1); return true; })($recv, ${a[0]})';
      }
    }
    // Enum values: `values.asNameMap()`, `values.byName(n)`.
    if (_enumLike(item)) {
      if (name == 'asNameMap') {
        return 'new Map($recv.map((v) => [v.name, v]))';
      }
      if (name == 'byName') return '${_use(r'$byName')}($recv, ${a[0]})';
    }
    switch (name) {
      // A view in Dart (changes pass through, the element type is checked
      // when read): here the same list, unchecked.
      case 'cast':
        return recv;
      case 'whereType':
        final t = m.typeArguments?.arguments.single.type;
        if (t == null) return null;
        final test = _typeTest('x', t, m);
        if (test == null) return null;
        return '$recv${dot}filter((x) => $test)';
      case 'toSet':
        if (_dateValue(item)) {
          return _fail(
            m,
            'Sets of ${item?.getDisplayString()} compare by value in Dart: '
            'not in the lite subset.',
          );
        }
        return _newSet(m.staticType, recv);
      case 'add':
        return '$recv${dot}push(${a[0]})';
      case 'addAll':
        return '$recv${dot}push(...${a[0]})';
      case 'insert':
        if (checks) return '${_use(r'$ins')}($recv, ${a[0]}, ${a[1]})';
        return '$recv${dot}splice(${a[0]}, 0, ${a[1]})';
      case 'removeAt':
        if (checks) return '${_use(r'$rem')}($recv, ${a[0]})';
        return '$recv${dot}splice(${a[0]}, 1)[0]';
      case 'removeLast':
        if (checks) return '${_use(r'$pop')}($recv)';
        return '$recv${dot}pop()';
      case 'remove':
        return '((l, x) => { const i = l.indexOf(x); if (i < 0) return false; l.splice(i, 1); return true; })($recv, ${a[0]})';
      case 'removeWhere':
        used.add(r'$removeWhere');
        return '\$removeWhere($recv, ${a[0]})';
      case 'retainWhere':
        used.add(r'$removeWhere');
        return '\$removeWhere($recv, (x) => !(${a[0]})(x))';
      case 'clear':
        return '($recv.length = 0)';
      case 'where':
        return '$recv${dot}filter(${_oneArg(a[0], args[0])})';
      case 'map':
        // Dart's map passes only the element.
        return args[0] is FunctionExpression ||
                args[0] is SimpleIdentifier &&
                    (args[0] as SimpleIdentifier).element
                        is! PropertyAccessorElement
            ? '$recv${dot}map(${_oneArg(a[0], args[0])})'
            : '$recv${dot}map((x) => (${a[0]})(x))';
      case 'expand':
        // flatMap only flattens arrays: a Set (a JS Set) or another iterable
        // result is spread first.
        final ft = args[0].staticType;
        if (ft is FunctionType && ft.returnType.isDartCoreList) {
          return '$recv${dot}flatMap(${_oneArg(a[0], args[0])})';
        }
        return '$recv${dot}flatMap((x) => [...(${a[0]})(x)])';
      case 'forEach':
        return '$recv${dot}forEach(${_oneArg(a[0], args[0])})';
      case 'any':
        return '$recv${dot}some(${_oneArg(a[0], args[0])})';
      case 'every':
        return '$recv${dot}every(${_oneArg(a[0], args[0])})';
      case 'contains':
        return '$recv${dot}includes(${a[0]})';
      case 'indexOf':
        return '$recv${dot}indexOf(${a.join(', ')})';
      case 'indexWhere':
        if (a.length > 1) return null;
        return '$recv${dot}findIndex(${_oneArg(a[0], args[0])})';
      case 'firstWhere':
        final orElse = [
          for (final x in args.whereType<NamedExpression>())
            if (x.name.label.name == 'orElse') _expr(x.expression, ctx),
        ];
        if (orElse.isEmpty) {
          return "((l, f) => { for (const x of l) if (f(x)) return x; throw new ${_use(r'$X')}('StateError', 'No element'); })($recv, ${a[0]})";
        }
        return '((l, f, o) => { for (const x of l) if (f(x)) return x; return o(); })($recv, ${a[0]}, ${orElse.single})';
      case 'join':
        // JS prints a null element as '' and a list as `1,5`: Dart's text
        // takes `$str`, unless the elements print the same (String, num,
        // bool, a non-null enum or class with toString).
        if (!_joinsLikeJs(m.realTarget?.staticType)) {
          return '${_use(r'$join')}($recv${a.isEmpty ? '' : ', ${a[0]}'})';
        }
        return '$recv${dot}join(${a.isEmpty ? "''" : a[0]})';
      case 'sublist':
        if (checks) return '${_use(r'$sub')}($recv, ${a.join(', ')})';
        return '$recv${dot}slice(${a.join(', ')})';
      case 'skip':
        if (checks) return '${_use(r'$tk')}($recv, ${a[0]}, 1)';
        return '$recv${dot}slice(${a[0]})';
      case 'take':
        if (checks) return '${_use(r'$tk')}($recv, ${a[0]}, 0)';
        return '$recv${dot}slice(0, ${a[0]})';
      case 'toList':
        if (args.isNotEmpty) return null;
        return _fresh(m.realTarget) ? recv : '[...$recv]';
      case 'fold':
        return '$recv${dot}reduce(${_twoArg(a[1], args[1])}, ${a[0]})';
      case 'reduce':
        final f = _twoArg(a[0], args[0]);
        if (checks) return '${_use(r'$reduce')}($recv, $f)';
        return '$recv${dot}reduce($f)';
      case 'sort':
        if (a.isEmpty) {
          final el = (m.realTarget!.staticType as InterfaceType)
              .typeArguments
              .firstOrNull;
          if (_num(el)) return '$recv${dot}sort((x, y) => x - y)';
          if (_dateValue(el)) {
            return '$recv${dot}sort((x, y) => x.compareTo(y))';
          }
          used.add(r'$cmp');
          return '$recv${dot}sort(\$cmp)';
        }
        return '$recv${dot}sort(${a[0]})';
      case 'elementAt':
        used.add(r'$at');
        return '\$at($recv, ${a[0]})';
    }
    return null;
  }

  /// [body] over [js] evaluated once: [js] itself when it is a plain name or
  /// a property path (no calls, so repeating it is free and effect-free),
  /// else bound to a parameter of an immediately called function.
  ///
  /// A [js] with `?.` may be a null-aware chain that stopped short
  /// (`undo.lastOrNull?.changes.singleOrNull`): in Dart the whole chain is
  /// null; in JS the function breaks the chain, so it gives null itself.
  String _bound(String js, String Function(String) body) {
    if (RegExp(r'^[\w$]+(\.[\w$]+)*$').hasMatch(js)) return body(js);
    if (js.contains('?.')) {
      return '((\$r) => \$r == null ? null : ${body(r'$r')})($js)';
    }
    return '((\$r) => ${body(r'$r')})($js)';
  }

  /// A callback JS calls with extra arguments (index, array): a tear-off of
  /// a function with optional parameters would receive them; wrap it.
  String _oneArg(String js, Expression dart) {
    final t = dart.staticType;
    if (dart is FunctionExpression) return js;
    if (t is FunctionType && t.formalParameters.length == 1) return js;
    return '(x) => ($js)(x)';
  }

  /// The same for `fold`/`reduce`, which JS calls with (acc, x, index, array).
  String _twoArg(String js, Expression dart) {
    final t = dart.staticType;
    if (t is FunctionType && t.formalParameters.length == 2) return js;
    return '(a, x) => ($js)(a, x)';
  }

  String _creation(InstanceCreationExpression e, _Ctx ctx) => _construct(
    e,
    e.constructorName.element?.baseElement,
    e.constructorName.name?.name,
    e.argumentList,
    e.isConst,
    ctx,
  );

  /// `Type(args)` / `Type.named(args)`: the explicit form, or the context
  /// type of a dot shorthand `.named(args)` ([c] is the resolved constructor).
  String _construct(
    Expression e,
    ConstructorElement? c,
    String? ctorName,
    ArgumentList argList,
    bool isConst,
    _Ctx ctx,
  ) {
    final cls = c?.enclosingElement;
    if (c == null || cls == null) return _fail(e, 'Unresolved constructor.');
    if (_isStateClass(cls)) {
      return _fail(e, 'Creating a ThorState at run time is not supported.');
    }
    if (_isApp(cls)) {
      final n = topNames[cls]!;
      final args = _args(argList, c, ctx);
      final js = c.isFactory
          ? '$n.${ctorName == null ? r'$new' : _mangle(ctorName)}($args)'
          : 'new $n($args)';
      if (isConst && ctx.hoist) return _hoist(js);
      return js;
    }
    final a = [for (final x in argList.arguments) _expr(x, ctx)];
    if (cls.library.isDartAsync && cls.name == 'Future') {
      switch (ctorName) {
        case 'delayed':
          // dart:async on the web: a timer (a negative duration is 0).
          final wait =
              'new Promise((r) => setTimeout(r, Math.max(0, ${a[0]}.inMilliseconds)))';
          return a.length > 1 ? '$wait.then(() => (${a[1]})())' : wait;
        case 'value':
          return 'Promise.resolve(${a.isEmpty ? 'null' : a[0]})';
        // An error thrown by the function rejects the promise, like Dart's.
        case 'sync':
          return 'new Promise((r) => r((${a[0]})()))';
        case 'microtask':
          return 'Promise.resolve().then(() => (${a[0]})())';
        case 'error':
          return 'Promise.reject(${a[0]})';
      }
    }
    if (cls.library.isDartAsync &&
        cls.name == 'Completer' &&
        ctorName == null) {
      return 'new ${_use(r'$Completer')}()';
    }
    switch ('${cls.name}.${ctorName ?? ''}') {
      case 'List.filled':
        return 'new Array(${a[0]}).fill(${a[1]})';
      case 'List.generate':
        return 'Array.from({ length: ${a[0]} }, (_, i) => (${a[1]})(i))';
      case 'List.of':
      case 'List.from':
        return '[...${a[0]}]';
      case 'List.empty':
        return '[]';
      case 'List.unmodifiable':
        return 'Object.freeze([...${a[0]}])';
      case 'Map.':
        return _newMap(e.staticType);
      case 'Map.of':
      case 'Map.from':
        return _newMap(e.staticType, a[0]);
      case 'Map.fromEntries':
        _checkElements(e, e.staticType!, 'Map keys');
        return _newMap(
          e.staticType,
          '[...${a[0]}].map((e) => [e.key, e.value])',
        );
      case 'Map.fromIterables':
        _checkElements(e, e.staticType!, 'Map keys');
        return '${_use(r'$zipmap')}(${a[0]}, ${a[1]}, () => ${_newMap(e.staticType)})';
      case 'Map.fromIterable':
        _checkElements(e, e.staticType!, 'Map keys');
        final named = {
          for (final n in argList.arguments.whereType<NamedExpression>())
            n.name.label.name: _expr(n.expression, ctx),
        };
        const id = '(x) => x';
        return '((l, k, v) => ${_newMap(e.staticType, '[...l].map((x) => [k(x), v(x)])')})(${a[0]}, ${named['key'] ?? id}, ${named['value'] ?? id})';
      case 'MapEntry.':
        return '{ key: ${a[0]}, value: ${a[1]} }';
      case 'Set.':
        return _newSet(e.staticType);
      case 'Set.of':
      case 'Set.from':
        final st = e.staticType;
        if (st != null) _checkElements(e, st, 'Sets');
        return _newSet(st, a[0]);
      case 'StringBuffer.':
        if (!_stringBuffer(cls.thisType)) break;
        final init = argList.arguments;
        return 'new ${_use(r'$SB')}(${init.isEmpty ? '' : _toStr(init.single, ctx)})';
      case 'RegExp.':
        if (!_regExp(cls.thisType)) break;
        final named = {
          for (final n in argList.arguments.whereType<NamedExpression>())
            n.name.label.name: n.expression,
        };
        var flags = '';
        for (final (arg, flag, on) in const [
          ('multiLine', 'm', true),
          ('caseSensitive', 'i', false),
          ('unicode', 'u', true),
          ('dotAll', 's', true),
        ]) {
          final v = named[arg];
          if (v == null) continue;
          if (v is! BooleanLiteral) {
            return _fail(v, 'RegExp flags must be true/false literals.');
          }
          if (v.value == on) flags += flag;
        }
        final source = argList.arguments.first;
        final js =
            'new RegExp(${_expr(source, ctx)}${flags.isEmpty ? '' : ", '$flags'"})';
        // One object per literal (its methods have no state without `g`).
        return source is StringLiteral && ctx.hoist ? _hoist(js) : js;
      case 'Locale.':
        if (!_inThor(cls)) break;
        final js =
            'new ${_use(r'$Loc')}(${a[0]}, null${a.length > 1 ? ', ${a[1]}' : ''})';
        return isConst && ctx.hoist ? _hoist(js) : js;
      case 'Locale.fromSubtags':
        if (!_inThor(cls)) break;
        final named = {
          for (final n in argList.arguments.whereType<NamedExpression>())
            n.name.label.name: _expr(n.expression, ctx),
        };
        final js =
            "new ${_use(r'$Loc')}(${named['languageCode'] ?? "'und'"}, ${named['scriptCode'] ?? 'null'}, ${named['countryCode'] ?? 'null'})";
        return isConst && ctx.hoist ? _hoist(js) : js;
      case 'ClipboardData.':
        if (!_inThor(cls)) break;
        return '{ text: ${_expr((argList.arguments.single as NamedExpression).expression, ctx)} }';
      case 'TextEditingValue.':
        if (_valueType(cls.thisType) != 'TextEditingValue') break;
        // `val(text, selection)` of the part `text_controller`.
        _use(r'$Ctext');
        final js = '${_use(r'$C')}.val(${_args(argList, c, ctx)})';
        return isConst && ctx.hoist ? _hoist(js) : js;
      case 'TextSelection.':
      case 'TextSelection.collapsed':
        if (_valueType(cls.thisType) != 'TextSelection') break;
        // The part `text_controller` makes them (its `sel`).
        _use(r'$Ctext');
        final named = {
          for (final n in argList.arguments.whereType<NamedExpression>())
            n.name.label.name: _expr(n.expression, ctx),
        };
        final js = ctorName == 'collapsed'
            ? '${_use(r'$C')}.sel(${named['offset']})'
            : '${_use(r'$C')}.sel(${named['baseOffset']}, ${named['extentOffset']})';
        return isConst && ctx.hoist ? _hoist(js) : js;
      case 'DateTime.':
      case 'DateTime.utc':
      case 'DateTime.now':
      case 'DateTime.timestamp':
      case 'DateTime.fromMillisecondsSinceEpoch':
      case 'DateTime.fromMicrosecondsSinceEpoch':
      case 'Duration.':
      case 'TimeOfDay.':
      case 'TimeOfDay.fromDateTime':
      case 'TimeOfDay.now':
        if (_valueType(cls.thisType) == null) {
          break;
        }
        final args = _args(argList, c, ctx);
        final js = switch ('${cls.name}.${ctorName ?? ''}') {
          'DateTime.' => '${_use(r'$DT')}.of(false, $args)',
          'DateTime.utc' => '${_use(r'$DT')}.of(true, $args)',
          'DateTime.now' => '${_use(r'$DT')}.now(false)',
          'DateTime.timestamp' => '${_use(r'$DT')}.now(true)',
          'DateTime.fromMillisecondsSinceEpoch' => '${_use(r'$DT')}.ms($args)',
          'DateTime.fromMicrosecondsSinceEpoch' =>
            '${_use(r'$DT')}.micro($args)',
          'Duration.' => '${_use(r'$Dur')}.of($args)',
          'TimeOfDay.' => 'new ${_use(r'$TOD')}($args)',
          'TimeOfDay.fromDateTime' => '${_use(r'$TOD')}.from($args)',
          _ => '${_use(r'$TOD')}.from(${_use(r'$DT')}.now(false))',
        };
        return isConst && ctx.hoist ? _hoist(js) : js;
      case 'Timer.':
      case 'Timer.periodic':
        if (!_timer(cls.thisType)) break;
        return 'new ${_use(r'$Timer')}(${a[0]}, ${a[1]}${ctorName == null ? '' : ', 1'})';
      case 'StateError.':
      case 'ArgumentError.':
      case 'Exception.':
      case 'UnsupportedError.':
      case 'RangeError.':
      case 'FormatException.':
        if (!cls.library.isDartCore) break;
        // One argument, the message: Dart prints the others its own way
        // (a FormatException's source and offset, an argument's name).
        if (a.length > 1) {
          return _fail(
            e,
            '${cls.name} with more than a message is not in the lite subset.',
          );
        }
        return "new ${_use(r'$X')}('${cls.name}'${a.isEmpty ? '' : ', ${a[0]}'})";
    }
    return _fail(
      e,
      '${cls.name}${ctorName == null ? '' : '.$ctorName'}(...) is not in the lite subset.',
    );
  }

  /// [items] (`const name = …;`) with each one after the constants it
  /// names, otherwise in the order given: a top-level `const emptyTree =
  /// Tree(file: '')` runs a constructor whose default is a hoisted `$c0`,
  /// which a plain "constants, then hoisted" order would not have made yet.
  static List<String> _constsInOrder(List<String> items) {
    final names = <String, int>{};
    for (var i = 0; i < items.length; i++) {
      final m = RegExp(r'^const ([\w$]+) =').firstMatch(items[i]);
      if (m != null) names[m[1]!] = i;
    }
    bool isHoisted(int i) => RegExp(r'^const \$c\d+ =').hasMatch(items[i]);
    // The constants each one names: those always come first.
    final deps = [
      for (var i = 0; i < items.length; i++)
        [
          for (final n in names.entries)
            if (n.value != i &&
                RegExp(
                  '(?<![\\w\$.])${RegExp.escape(n.key)}(?![\\w\$])',
                ).hasMatch(items[i]))
              n.value,
        ],
    ];
    final out = <String>[];
    final seen = <int>{};
    // The constants being placed (each waits for the next one down).
    final active = <int>{};
    // Whether [from] names one of [active], directly or through others.
    bool needsActive(int from) {
      final stack = [from];
      final seen = <int>{from};
      while (stack.isNotEmpty) {
        final k = stack.removeLast();
        if (active.contains(k)) return true;
        for (final d in deps[k]) {
          if (seen.add(d)) stack.add(d);
        }
      }
      return false;
    }

    void visit(int i) {
      if (!seen.add(i)) return;
      active.add(i);
      for (final d in deps[i]) {
        visit(d);
      }
      // A constructor can read a hoisted constant (a default `const []`):
      // a constant that builds an instance comes after them.
      // Among the hoisted ones, those that build none come first (a
      // hoisted `new Set()` builds a JS one, so a top-level constant waits
      // for every hoisted one). A guess, so it never overrides a real
      // use: a hoisted `Object.freeze([$c13])` that names this instance
      // (or one placed before it) stays after it.
      if (items[i].contains('new ')) {
        final hoistedSelf = isHoisted(i);
        for (var j = 0; j < items.length; j++) {
          if (j == i || !isHoisted(j) || needsActive(j)) continue;
          if (!hoistedSelf || !items[j].contains('new ')) visit(j);
        }
      }
      active.remove(i);
      out.add(items[i]);
    }

    for (var i = 0; i < items.length; i++) {
      visit(i);
    }
    return out;
  }

  String _hoist(String code) {
    return hoisted.putIfAbsent(code, () => '\$c${hoisted.length}');
  }

  String _index(IndexExpression e, _Ctx ctx) {
    final aware = e.isNullAware && !_noShort.contains(e);
    final t = e.realTarget.staticType;
    final recv = _target(e.target, ctx);
    final i = _expr(e.index, ctx);
    if (_map(t)) {
      if (e.inSetterContext()) {
        return _fail(e, 'Assign to a map entry with `m[k] = v` only.');
      }
      // `field.value[k]` of a map state: the runtime's per-key read, so the
      // reader re-runs when that entry changes, not on every write (see `parts/map_keys.js`).
      final signal = aware ? null : _stateValue(e.realTarget);
      if (signal != null) {
        used.add(r'$mapKeys');
        _statePseudo.add(r'$mapKeys');
        return '(${_operand(signal, ctx)}.key($i) ?? null)';
      }
      return aware ? '($recv?.get($i) ?? null)' : '($recv.get($i) ?? null)';
    }
    if (_regExpMatch(t)) return '($recv[$i] ?? null)';
    if (_list(t) || _str(t)) {
      if (checks && !e.inSetterContext()) {
        return aware
            ? '${_use(r'$atq')}($recv, $i)'
            : '${_use(r'$at')}($recv, $i)';
      }
      return aware ? '$recv?.[$i]' : '$recv[$i]';
    }
    return _fail(
      e,
      'Index on ${t?.getDisplayString()} is not in the lite subset.',
    );
  }

  /// An assignable expression.
  String _lvalue(Expression e, _Ctx ctx) {
    if (e is SimpleIdentifier) {
      final parent = e.parent;
      Element? w;
      if (parent is AssignmentExpression && parent.leftHandSide == e) {
        w = parent.writeElement;
      } else if (parent is PostfixExpression) {
        w = parent.writeElement;
      } else if (parent is PrefixExpression) {
        w = parent.writeElement;
      }
      w = w?.baseElement;
      if (w is SetterElement) {
        final v = w.variable;
        if (v is TopLevelVariableElement && _isApp(v)) return topNames[v]!;
        final cls = v.enclosingElement;
        if (ctx.state != null && ctx.state!.owns(cls)) {
          return _stateName(v.name!);
        }
        if (cls is InterfaceElement && _isApp(cls)) {
          return v.isStatic
              ? '${topNames[cls]}.${_mangle(v.name!)}'
              : 'this.${_mangle(v.name!)}';
        }
        return _fail(e, '${e.name} cannot be assigned in the lite subset.');
      }
      if (w is LocalVariableElement || w is FormalParameterElement) {
        return _local(w, e.name);
      }
      return _identifier(e, ctx);
    }
    if (e is PrefixedIdentifier || e is PropertyAccess) {
      final (target, prop) = e is PrefixedIdentifier
          ? (e.prefix as Expression, e.identifier)
          : ((e as PropertyAccess).target, e.propertyName);
      final t = e is PropertyAccess
          ? e.realTarget.staticType
          : target?.staticType;
      if (_isSignal(t) && prop.name == 'value') {
        return '${_target(target, ctx)}.value';
      }
      if (_valueType(t) == 'TextEditingController' &&
              const {'text', 'selection', 'value'}.contains(prop.name) ||
          _valueType(t) == 'AnimationController' &&
              const {
                'value',
                'duration',
                'reverseDuration',
              }.contains(prop.name)) {
        return '${_target(target, ctx)}.${prop.name}';
      }
      if (t is InterfaceType && _isApp(t.element)) {
        return '${_target(target, ctx)}.${_mangle(prop.name)}';
      }
      if (target is Identifier &&
          target.element is InterfaceElement &&
          _isApp(target.element)) {
        return '${topNames[target.element]}.${_mangle(prop.name)}';
      }
      return _fail(e, 'Assigning ${_src(e)} is not in the lite subset.');
    }
    if (e is IndexExpression) {
      final t = e.realTarget.staticType;
      if (_list(t)) {
        final r = _target(e.target, ctx);
        final i = _expr(e.index, ctx);
        if (!checks || !_list(t)) return '$r[$i]';
        // The receiver is written twice (the check and the access): a plain
        // name as is, anything else (a getter, a call, `!`, `as`) once in
        // the scratch `$r`, taken before the index runs.
        if (RegExp(r'^[\w$]+$').hasMatch(r)) {
          return '$r[${_use(r'$ix')}($r, $i)]';
        }
        _use(r'$ix');
        return '(${_use(r'$r')} = $r)[\$ix(\$r, $i)]';
      }
    }
    return _fail(e, 'Assigning ${_src(e)} is not in the lite subset.');
  }

  String _assignment(AssignmentExpression e, _Ctx ctx) {
    if (_dateSignalValue(e) case final target?) {
      return _setDateSignal(e, target, ctx);
    }
    // `m[k] = v` on a JS Map.
    final lhsNode = e.leftHandSide;
    if (lhsNode is IndexExpression && _map(lhsNode.realTarget.staticType)) {
      if (e.operator.type != TokenType.EQ) {
        return _fail(
          e,
          '`${e.operator.lexeme}` on a map entry: use `m[k] = v`.',
        );
      }
      final map = _target(lhsNode.target, ctx), key = _expr(lhsNode.index, ctx);
      if (e.parent is ExpressionStatement) {
        return '$map.set($key, ${_expr(e.rightHandSide, ctx)})';
      }
      final v = '\$w${_tmp++}';
      return '(($v) => ($map.set($key, $v), $v))(${_expr(e.rightHandSide, ctx)})';
    }
    final lhs = _lvalue(e.leftHandSide, ctx);
    final rhs = _expr(e.rightHandSide, ctx);
    final op = e.operator.type;
    switch (op) {
      case TokenType.EQ:
      case TokenType.PLUS_EQ:
      case TokenType.MINUS_EQ:
      case TokenType.STAR_EQ:
      case TokenType.SLASH_EQ:
      case TokenType.QUESTION_QUESTION_EQ:
        if (op == TokenType.PLUS_EQ && _list(e.leftHandSide.staticType)) {
          return '$lhs = [...$lhs, ...$rhs]';
        }
        // Duration's operators are methods (`d += x` → `d = d.plus(x)`).
        if (op != TokenType.EQ &&
            op != TokenType.QUESTION_QUESTION_EQ &&
            _valueType(e.readType) == 'Duration') {
          final o = e.operator.lexeme;
          final bin = _binaryJs(
            o.substring(0, o.length - 1),
            lhs,
            '($rhs)',
            e.readType,
            e.rightHandSide.staticType,
            e,
          );
          return '$lhs = $bin';
        }
        return '$lhs ${e.operator.lexeme} $rhs';
    }
    final simple =
        e.leftHandSide is SimpleIdentifier ||
        e.leftHandSide is PrefixedIdentifier;
    if (!simple) {
      return _fail(
        e,
        '`${e.operator.lexeme}` on ${_src(e.leftHandSide)}: assign to a local first.',
      );
    }
    final bin = _binaryJs(
      e.operator.lexeme.substring(0, e.operator.lexeme.length - 1),
      lhs,
      '($rhs)',
      e.leftHandSide.staticType,
      e.rightHandSide.staticType,
      e,
    );
    return '$lhs = $bin';
  }

  /// The signal of assignment [a]'s `signal.value` when its value compares
  /// by value (a DateTime, Duration, TimeOfDay, record or class with
  /// `operator ==`): set like Dart's, which skips an equal value
  /// ([_setDateSignal]); else null.
  Expression? _dateSignalValue(AssignmentExpression a) {
    final e = a.leftHandSide;
    final (Expression? target, String prop) = switch (e) {
      PrefixedIdentifier() => (e.prefix, e.identifier.name),
      PropertyAccess() => (e.target, e.propertyName.name),
      _ => (null, ''),
    };
    if (target == null || prop != 'value') return null;
    if (!_isSignal(target.staticType) || !_valueEq(a.writeType)) return null;
    return target;
  }

  String _setDateSignal(AssignmentExpression e, Expression target, _Ctx ctx) {
    final s = _target(target, ctx);
    final rhs = _expr(e.rightHandSide, ctx);
    final op = e.operator.lexeme;
    final next = switch (e.operator.type) {
      TokenType.EQ => rhs,
      TokenType.QUESTION_QUESTION_EQ => '$s.value ?? $rhs',
      _ => _binaryJs(
        op.substring(0, op.length - 1),
        '$s.value',
        '($rhs)',
        e.writeType,
        e.rightHandSide.staticType,
        e,
      ),
    };
    _use(r'$deq');
    return '${_use(r'$sset')}($s, ${_unwrap(next)})';
  }

  String _binary(BinaryExpression e, _Ctx ctx) {
    final op = e.operator.lexeme;
    final lt = e.leftOperand.staticType, rt = e.rightOperand.staticType;
    final userOp = e.element;
    // `==` of the app's own classes is `operator ==` (`$eq`, see `_eqJs`).
    if (userOp != null && _isApp(userOp) && op != '==' && op != '!=') {
      return _fail(
        e,
        'Operator $op of ${lt?.getDisplayString()} is not in the lite subset.',
      );
    }
    // `super == other`: the base class's `operator ==` (a class without one
    // has identity).
    if (e.leftOperand is SuperExpression && (op == '==' || op == '!=')) {
      final r = _expr(e.rightOperand, ctx);
      final base = userOp?.enclosingElement;
      final call = base is InterfaceElement && _isApp(base)
          ? 'super.\$eq($r)'
          : '(this === $r)';
      return op == '==' ? call : '!$call';
    }
    final l = _operand(e.leftOperand, ctx);
    final r = _operand(e.rightOperand, ctx);
    if (op == '==' || op == '!=') {
      final neg = op == '!=';
      if (e.leftOperand is NullLiteral || e.rightOperand is NullLiteral) {
        return '$l ${neg ? '!=' : '=='} $r';
      }
      return _eqJs(l, r, lt, rt, e, neg: neg);
    }
    if (op == '+' && _list(lt)) return '[...$l, ...$r]';
    if (op == '+' && (_str(lt) != _str(rt))) {
      return _fail(e, 'String + non-String does not compile in Dart.');
    }
    return _binaryJs(op, l, r, lt, rt, e);
  }

  /// Dart's `==` of [l] and [r] (JS operands, static types [lt], [rt]).
  String _eqJs(
    String l,
    String r,
    DartType? lt,
    DartType? rt,
    AstNode at, {
    bool neg = false,
  }) {
    final not = neg ? '!' : '';
    if (_byValue(lt, rt)) {
      return '$not${_use(r'$deq')}(${_unwrap(l)}, ${_unwrap(r)})';
    }
    if (_nullable(lt) && _nullable(rt)) {
      return '$not${_use(r'$eq')}(${_unwrap(l)}, ${_unwrap(r)})';
    }
    return '$l ${neg ? '!==' : '==='} $r';
  }

  /// Whether `a == b` of static types [a] and [b] needs `$deq`: one of them
  /// compares by value, or both are `Object?`/a type parameter (the values
  /// may be). A String, a number, a bool or an enum against `Object?` is `===`:
  /// no class of value equality equals one.
  bool _byValue(DartType? a, DartType? b) =>
      _valueEq(a) || _valueEq(b) || _maybeValue(a) && _maybeValue(b);

  /// Whether a value of static type [t] could be one that compares by
  /// value (a DateTime behind `Object?`).
  bool _maybeValue(DartType? t) =>
      t == null ||
      t is DynamicType ||
      t.isDartCoreObject ||
      t is TypeParameterType && _maybeValue(t.bound);

  /// [js] without one pair of parentheses around all of it (for helper
  /// call arguments, where they are noise).
  String _unwrap(String js) {
    if (!js.startsWith('(') || !js.endsWith(')')) return js;
    var depth = 0;
    String? quote;
    for (var i = 0; i < js.length; i++) {
      final c = js[i];
      if (quote != null) {
        if (c == '\\') {
          i++;
        } else if (c == quote) {
          quote = null;
        }
        continue;
      }
      if (c == "'" || c == '"' || c == '`') {
        quote = c;
      } else if (c == '(') {
        depth++;
      } else if (c == ')') {
        depth--;
        if (depth == 0 && i != js.length - 1) return js;
      }
    }
    return js.substring(1, js.length - 1);
  }

  String _binaryJs(
    String op,
    String l,
    String r,
    DartType? lt,
    DartType? rt,
    AstNode at,
  ) {
    if (_valueType(lt) == 'Duration') {
      final js = switch (op) {
        '+' => '$l.plus(${_unwrap(r)})',
        '-' => '$l.minus(${_unwrap(r)})',
        '*' => '$l.times(${_unwrap(r)})',
        '~/' => '$l.div(${_unwrap(r)})',
        '<' || '>' || '<=' || '>=' => '($l.compareTo(${_unwrap(r)}) $op 0)',
        _ => null,
      };
      if (js != null) return js;
    }
    // Dart's `String * int`: a zero or negative count is the empty string.
    if (op == '*' && _str(lt)) return '$l.repeat(Math.max(0, ${_unwrap(r)}))';
    switch (op) {
      case '+':
      case '-':
      case '*':
      case '/':
      case '<':
      case '>':
      case '<=':
      case '>=':
      case '&&':
      case '||':
      case '??':
        if (op != '&&' &&
            op != '||' &&
            op != '??' &&
            !(_num(lt) || _str(lt) && op == '+')) {
          return _fail(
            at,
            'Operator $op on ${lt?.getDisplayString()} is not in the lite subset.',
          );
        }
        return '$l $op $r';
      case '~/':
        return checks
            ? '${_use(r'$idiv')}(${_unwrap(l)}, ${_unwrap(r)})'
            : 'Math.trunc($l / $r)';
      case '%':
        used.add(r'$mod');
        return '\$mod(${_unwrap(l)}, ${_unwrap(r)})';
      case '&':
      case '|':
      case '^':
        if (_bool(lt)) return '!!($l $op $r)';
        return '(($l $op $r) >>> 0)';
      case '>>':
        used.add(r'$shr');
        return '\$shr(${_unwrap(l)}, ${_unwrap(r)})';
      case '<<':
        used.add(r'$shl');
        return '\$shl(${_unwrap(l)}, ${_unwrap(r)})';
      case '>>>':
        used.add(r'$ushr');
        return '\$ushr(${_unwrap(l)}, ${_unwrap(r)})';
    }
    return _fail(at, 'Operator $op is not in the lite subset.');
  }

  String _prefix(PrefixExpression e, _Ctx ctx) {
    final op = e.operator.type;
    if (op == TokenType.PLUS_PLUS || op == TokenType.MINUS_MINUS) {
      return '${e.operator.lexeme}${_lvalue(e.operand, ctx)}';
    }
    final v = _operand(e.operand, ctx);
    switch (op) {
      case TokenType.BANG:
        return '!$v';
      case TokenType.MINUS:
        if (_valueType(e.operand.staticType) == 'Duration') return '$v.neg()';
        return v.startsWith('-') ? '-($v)' : '-$v';
      case TokenType.TILDE:
        return '((~$v) >>> 0)';
      default:
        return _fail(
          e,
          'Operator ${e.operator.lexeme} is not in the lite subset.',
        );
    }
  }

  /// `x as T`: the value itself; with [checks], tested first (only what
  /// [_typeTest] can tell; the rest passes like in release).
  String _cast(AsExpression e, _Ctx ctx) {
    final v = _expr(e.expression, ctx);
    final t = e.type.type;
    if (!checks || t == null) return v;
    var test = _typeTest('v', t, e);
    if (test == null) {
      // A collection with type arguments: only the outer type can be told
      // (JS collections carry no element types; documented, like release).
      final outer = t.isDartCoreList
          ? 'Array.isArray(v)'
          : t.isDartCoreSet
          ? 'v instanceof Set'
          : t.isDartCoreMap
          ? 'v instanceof Map'
          : null;
      if (outer != null) {
        test = t.nullabilitySuffix == NullabilitySuffix.question
            ? '(v == null || $outer)'
            : outer;
      }
    }
    if (test == null || test == 'true') return v;
    return '${_use(r'$cast')}($v, (v) => $test, ${_quote(t.getDisplayString())})';
  }

  String _isTest(IsExpression e, _Ctx ctx) {
    final v = _operand(e.expression, ctx);
    final t = e.type.type;
    final not = e.notOperator != null;
    String test;
    if (t == null) return _fail(e, 'Unresolved type.');
    if (t.isDartCoreInt) {
      test = 'Number.isInteger($v)';
    } else if (t.isDartCoreDouble || t.isDartCoreNum) {
      test = "typeof $v === 'number'";
    } else if (t.isDartCoreString) {
      test = "typeof $v === 'string'";
    } else if (t.isDartCoreBool) {
      test = "typeof $v === 'boolean'";
    } else if ((t.isDartCoreList || t.isDartCoreSet) &&
        _reifiedArgs(t) &&
        !_staticallyA(e.expression.staticType, t)) {
      // JS arrays carry no element type: `['a'] is List<int>` would be true.
      return _fail(
        e,
        '`is ${t.getDisplayString()}` is not in the lite subset: JS '
        'collections carry no element types to test.',
      );
    } else if (t.isDartCoreList) {
      test = 'Array.isArray($v)';
    } else if (t.isDartCoreNull) {
      test = '$v == null';
    } else if (t.isDartCoreMap && !_reifiedArgs(t)) {
      test = '${_use(r'$isMap')}($v)';
    } else {
      final js = _typeTest(v, t, e);
      if (js == null) {
        return _fail(
          e,
          '`is ${t.getDisplayString()}` is not in the lite subset.',
        );
      }
      test = js;
    }
    return not ? '!($test)' : test;
  }

  /// JS testing that [v] (a name or a simple expression) is of type [t],
  /// or null when the lite subset can't tell.
  String? _typeTest(String v, DartType t, AstNode at) {
    String? core;
    if (t is DynamicType ||
        t.isDartCoreObject &&
            t.nullabilitySuffix == NullabilitySuffix.question) {
      return 'true';
    } else if (t.isDartCoreObject) {
      core = '$v != null';
    } else if (t.isDartCoreInt) {
      core = 'Number.isInteger($v)';
    } else if (t.isDartCoreDouble || t.isDartCoreNum) {
      core = "typeof $v === 'number'";
    } else if (t.isDartCoreString) {
      core = "typeof $v === 'string'";
    } else if (t.isDartCoreBool) {
      core = "typeof $v === 'boolean'";
    } else if ((t.isDartCoreList || t.isDartCoreSet) && _reifiedArgs(t)) {
      return null; // no element types at run time: `['a'] is List<int>`
    } else if (t.isDartCoreList) {
      core = 'Array.isArray($v)';
    } else if (t.isDartCoreSet) {
      core = '$v instanceof Set';
    } else if (t.isDartCoreMap && !_reifiedArgs(t)) {
      core = '${_use(r'$isMap')}($v)';
    } else if (t.isDartCoreNull) {
      return '$v == null';
    } else if (t is InterfaceType && _isEnum(t)) {
      core = _enumTest(v, t.element as EnumElement);
    } else if (t is InterfaceType &&
        _isApp(t.element) &&
        (t.element is ClassElement || t.element is MixinElement)) {
      core = _appInstanceTest(v, t.element);
    } else if (_dateValue(t)) {
      final h = {'DateTime': r'$DT', 'Duration': r'$Dur'}[_valueType(t)];
      core = '$v instanceof ${_use(h ?? r'$TOD')}';
    } else if (_stringBuffer(t)) {
      core = '$v instanceof ${_use(r'$SB')}';
    } else if (_locale(t)) {
      core = '$v instanceof ${_use(r'$Loc')}';
    } else if (t is InterfaceType &&
        _inThor(t.element) &&
        (_valueGetters[t.element.name]?.contains('character') ?? false)) {
      // A Focus.onKeyEvent event (`$KE`): only key downs and repeats arrive.
      core = switch (t.element.name) {
        'KeyDownEvent' => '$v?.\$r === 0',
        'KeyRepeatEvent' => '$v?.\$r === 1',
        'KeyUpEvent' => 'false',
        _ => '$v != null',
      };
    } else if (t is InterfaceType &&
        t.element.library.isDartCore &&
        (_coreExceptions.contains(t.element.name) ||
            t.element.name == 'Error')) {
      // `e is StateError`: the same test as `on StateError`.
      core = _catchTest(v, t, at);
    }
    if (core == null) return null;
    return t.nullabilitySuffix == NullabilitySuffix.question
        ? '($v == null || $core)'
        : core;
  }

  String _enumTest(String v, EnumElement e) {
    final n = _enumName(e)!;
    final d = decls[e]?.node;
    return d is EnumDeclaration && d.body.members.isNotEmpty
        ? '$v instanceof $n'
        : '$n\$values.includes($v)';
  }

  /// JS testing that [v] is a [c] of the app: `instanceof` for the class
  /// and its subclasses, plus one test per class or enum that only
  /// `implements` it (JS has no interfaces; the app's hierarchy is known).
  String _appInstanceTest(String v, InterfaceElement c) {
    final subs = <InterfaceElement>[
      for (final x in topNames.keys.whereType<InterfaceElement>())
        // (a mixin is a function, not a class to test against)
        if (x is! MixinElement &&
            (x == c || x.allSupertypes.any((s) => s.element == c)))
          x,
    ];
    bool covered(InterfaceElement x) {
      for (var p = x.supertype?.element; p != null; p = p.supertype?.element) {
        if (subs.contains(p)) return true;
      }
      return false;
    }

    final tests = [
      for (final x in subs)
        if (!covered(x))
          x is EnumElement ? _enumTest(v, x) : '$v instanceof ${topNames[x]}',
    ];
    if (tests.isEmpty) {
      return c is MixinElement ? 'false' : '$v instanceof ${topNames[c]}';
    }
    return tests.length == 1 ? tests.single : '(${tests.join(' || ')})';
  }

  String _cascadeExpr(CascadeExpression e, _Ctx ctx) {
    final t = '\$t${_tmp++}';
    final target = _expr(e.target, ctx);
    final prev = _cascade;
    _cascade = t;
    final sections = [for (final s in e.cascadeSections) '${_expr(s, ctx)};'];
    _cascade = prev;
    return '(($t) => { ${sections.join(' ')} return $t; })($target)';
  }

  String _throw(ThrowExpression e, _Ctx ctx) =>
      '(() => { ${_throwStmt(e.expression, ctx)} })()';

  /// `throw x;`: what's thrown is Dart's value (a String stays a String,
  /// `on String` catches it); an exception of dart:core is a `$X`. What a
  /// catch can test is limited instead ([_catchTest]).
  String _throwStmt(Expression x, _Ctx ctx) => 'throw ${_expr(x, ctx)};';

  /// dart:core's exceptions the lite subset models (a `$X` each).
  static const _coreExceptions = {
    'FormatException', 'StateError', 'ArgumentError', 'RangeError', //
    'UnsupportedError', 'Exception',
  };

  bool _coreException(DartType? t) =>
      t is InterfaceType &&
      t.element.library.isDartCore &&
      _coreExceptions.contains(t.element.name);

  /// The catch variables of the enclosing `catch` clauses (`rethrow`).
  final _caught = <String>[];

  /// JS testing that the caught [v] is a [t] (an `on T` clause), or null
  /// with an error.
  String? _catchTest(String v, DartType t, AstNode at) {
    if (t is DynamicType || t.isDartCoreObject) return null;
    if (_str(t)) return "typeof $v === 'string'";
    final x = _use(r'$X');
    if (t is InterfaceType && t.element.library.isDartCore) {
      switch (t.element.name) {
        case 'FormatException' ||
            'StateError' ||
            'RangeError' ||
            'UnsupportedError':
          return "($v instanceof $x && $v.\$t === '${t.element.name}')";
        case 'ArgumentError':
          return "($v instanceof $x && ($v.\$t === 'ArgumentError' || $v.\$t === 'RangeError'))";
        case 'Exception':
          // FormatException, Exception(...), and the app's classes that
          // implement Exception.
          final own = [
            for (final c in topNames.keys.whereType<ClassElement>())
              if (c.allSupertypes.any(
                (s) =>
                    s.element.name == 'Exception' &&
                    s.element.library.isDartCore,
              ))
                '$v instanceof ${topNames[c]}',
          ];
          return "($v instanceof $x ? $v.\$t === 'FormatException' || $v.\$t === 'Exception' : ${own.isEmpty ? 'false' : own.join(' || ')})";
        case 'Error':
          // The Errors of dart:core, and the JS engine's own (a null
          // dereference: dart2js's are Errors too).
          return "($v instanceof $x ? $v.\$t !== 'FormatException' && $v.\$t !== 'Exception' : $v instanceof Error)";
      }
    }
    if (t is InterfaceType &&
        _isApp(t.element) &&
        (t.element is ClassElement || t.element is MixinElement)) {
      return _appInstanceTest(v, t.element);
    }
    _fail(
      at,
      'Catching ${t.getDisplayString()} is not in the lite subset: catch '
      'FormatException, StateError, ArgumentError, RangeError, '
      'UnsupportedError, Exception, Error, String, a class of the app, or '
      'everything.',
    );
    return 'false';
  }

  /// try/catch/finally: one JS catch testing each `on T` in order; what no
  /// clause takes is thrown again.
  String _try(TryStatement s, _Ctx ctx) {
    final body = _stmt(s.body, ctx);
    final fin = s.finallyBlock == null
        ? ''
        : ' finally ${_stmt(s.finallyBlock!, ctx)}';
    if (s.catchClauses.isEmpty) return 'try $body$fin';
    final v = '\$e${_tmp++}';
    final branches = <String>[];
    var all = false;
    for (final c in s.catchClauses) {
      final t = c.exceptionType?.type;
      final test = t == null ? null : _catchTest(v, t, c);
      final binds = [
        if (c.exceptionParameter case final p?)
          '${_local(p.declaredFragment?.element, p.name.lexeme)} = $v',
        // A JS stack, not dart2js's (printing it is not in the subset).
        if (c.stackTraceParameter case final p?)
          "${_local(p.declaredFragment?.element, p.name.lexeme)} = $v?.stack ?? ''",
      ];
      _caught.add(v);
      final inner = _stmt(c.body, ctx);
      _caught.removeLast();
      final block = binds.isEmpty
          ? inner
          : '{\n  const ${binds.join(', ')};\n${_indent(inner, '  ')}\n}';
      if (test == null) {
        branches.add(block);
        all = true;
        break;
      }
      branches.add('if ($test) $block');
    }
    final chain = [
      for (var i = 0; i < branches.length; i++)
        i == 0 ? branches[i] : ' else ${branches[i]}',
    ].join();
    final handler = all ? chain : '$chain else throw $v;';
    return 'try $body catch ($v) {\n${_indent(handler, '  ')}\n}$fin';
  }

  String _switchExpression(SwitchExpression e, _Ctx ctx) {
    if (!_constantCases(e.cases.map((c) => c.guardedPattern))) {
      final v = '\$v${_tmp++}';
      final arms = [
        for (final c in e.cases)
          _caseIf(
            _match(c.guardedPattern.pattern, v, ctx),
            c.guardedPattern.whenClause,
            'return ${_expr(c.expression, ctx)};',
            ctx,
          ),
      ];
      return '(($v) => {\n${_indent([...arms, "throw new Error('No switch case matched');"].join('\n'), '  ')}\n})(${_expr(e.expression, ctx)})';
    }
    final v = '\$v${_tmp++}';
    final parts = <String>[];
    String? fallback;
    for (final c in e.cases) {
      if (c.guardedPattern.whenClause != null) {
        _fail(c, '`when` guards are not in the lite subset.');
      }
      final pats = _constantPatterns(c.guardedPattern.pattern, ctx);
      final body = _operand(c.expression, ctx);
      if (pats == null) {
        fallback = body;
        break;
      }
      parts.add('${pats.map((p) => '$v === $p').join(' || ')} ? $body');
    }
    fallback ??= "(() => { throw new Error('No switch case matched'); })()";
    return '(($v) => ${[...parts, fallback].join(' : ')})(${_expr(e.expression, ctx)})';
  }

  String _record(RecordLiteral e, _Ctx ctx) {
    _recordsMade = true;
    var i = 1;
    final fields = [
      for (final f in e.fields)
        f is NamedExpression
            ? '${f.name.label.name}: ${_expr(f.expression, ctx)}'
            : '\$${i++}: ${_expr(f, ctx)}',
    ];
    return 'Object.freeze({ ${fields.join(', ')} })';
  }

  bool _constant(TypedLiteral e) => e.isConst || e.inConstantContext;

  String _listLiteral(ListLiteral e, _Ctx ctx) {
    final simple = e.elements.every(
      (x) => x is Expression || x is SpreadElement,
    );
    String js;
    if (simple) {
      js = '[${e.elements.map((x) => _element(x, ctx)).join(', ')}]';
    } else {
      final l = '\$l${_tmp++}';
      final body = e.elements
          .map((x) => _collect(x, l, ctx, kind: _Kind.list))
          .join(' ');
      js = '(() => { const $l = []; $body return $l; })()';
    }
    if (_constant(e)) {
      js = 'Object.freeze($js)';
      if (ctx.hoist) return _hoist(js);
    }
    return js;
  }

  String _element(CollectionElement x, _Ctx ctx) {
    switch (x) {
      case Expression():
        return _expr(x, ctx);
      case SpreadElement():
        final v = _operand(x.expression, ctx);
        return x.isNullAware ? '...($v ?? [])' : '...$v';
      default:
        return _fail(x, 'Unsupported collection element.');
    }
  }

  /// Statements that add [x] to the collection [out] of [kind].
  String _collect(
    CollectionElement x,
    String out,
    _Ctx ctx, {
    required _Kind kind,
  }) {
    String add(String v) => switch (kind) {
      _Kind.list => '$out.push($v);',
      _Kind.set => '$out.add($v);',
      _Kind.map => _fail(x, 'Unsupported map element.'),
    };
    switch (x) {
      case MapLiteralEntry():
        if (x.keyQuestion != null || x.valueQuestion != null) {
          return _fail(x, 'Null-aware map entries are not in the lite subset.');
        }
        final k = _expr(x.key, ctx), v = _expr(x.value, ctx);
        return '$out.set($k, $v);';
      case Expression():
        return add(_expr(x, ctx));
      case NullAwareElement():
        final n = '\$n${_tmp++}';
        return '{ const $n = ${_expr(x.value, ctx)}; if ($n != null) ${add(n)} }';
      case SpreadElement():
        final v = _operand(x.expression, ctx);
        final empty = switch (kind) {
          _Kind.list || _Kind.set => '[]',
          _Kind.map => 'new Map()',
        };
        final src = x.isNullAware ? '($v ?? $empty)' : v;
        final it = '\$x${_tmp++}';
        return switch (kind) {
          _Kind.list => '$out.push(...$src);',
          _Kind.set => 'for (const $it of $src) $out.add($it);',
          _Kind.map => 'for (const [$it, \$w] of $src) $out.set($it, \$w);',
        };
      case IfElement():
        final elseE = x.elseElement;
        if (x.caseClause case final c?) {
          return _ifCase(
            _expr(x.expression, ctx),
            c.guardedPattern,
            () => _collect(x.thenElement, out, ctx, kind: kind),
            elseE == null ? null : () => _collect(elseE, out, ctx, kind: kind),
            ctx,
          );
        }
        return 'if (${_expr(x.expression, ctx)}) { ${_collect(x.thenElement, out, ctx, kind: kind)} }'
            '${elseE == null ? '' : ' else { ${_collect(elseE, out, ctx, kind: kind)} }'}';
      case ForElement():
        if (x.awaitKeyword != null) {
          return _fail(x, '`await for` is not supported.');
        }
        final parts = x.forLoopParts;
        if (parts is ForEachPartsWithPattern) {
          final (head, binds) = _forPattern(parts, ctx);
          return 'for ($head) { $binds ${_collect(x.body, out, ctx, kind: kind)} }';
        }
        return 'for (${_forParts(parts, ctx)}) { ${_collect(x.body, out, ctx, kind: kind)} }';
    }
  }

  String _mapLiteral(SetOrMapLiteral e, _Ctx ctx) {
    final t = e.staticType;
    if (e.isSet) {
      if (t != null) _checkElements(e, t, 'Sets');
      final simple = e.elements.every(
        (x) => x is Expression || x is SpreadElement,
      );
      final keys = [
        for (final x in e.elements)
          if (x is Expression) x.staticType,
      ];
      final js = simple
          ? (e.elements.isEmpty
                ? _newSet(t)
                : _newSet(
                    t,
                    '[${e.elements.map((x) => _element(x, ctx)).join(', ')}]',
                    keys,
                  ))
          : () {
              final s = '\$s${_tmp++}';
              final body = e.elements
                  .map((x) => _collect(x, s, ctx, kind: _Kind.set))
                  .join(' ');
              return '(() => { const $s = ${_newSet(t, '', keys)}; $body return $s; })()';
            }();
      // A const set is never written: one copy for every use, like Dart's.
      return _constant(e) && ctx.hoist ? _hoist(js) : js;
    }
    _checkElements(e, t!, 'Map keys');
    final simple = e.elements.every((x) => x is MapLiteralEntry);
    final keys = [
      for (final x in e.elements)
        if (x is MapLiteralEntry) x.key.staticType,
    ];
    final js = simple
        ? (e.elements.isEmpty
              ? _newMap(t)
              : _newMap(
                  t,
                  '[${[for (final x in e.elements.cast<MapLiteralEntry>()) '[${_expr(x.key, ctx)}, ${_expr(x.value, ctx)}]'].join(', ')}]',
                  keys,
                ))
        : () {
            final m = '\$m${_tmp++}';
            final body = e.elements
                .map((x) => _collect(x, m, ctx, kind: _Kind.map))
                .join(' ');
            return '(() => { const $m = ${_newMap(t, '', keys)}; $body return $m; })()';
          }();
    // A const map is never written: one copy for every use, like Dart's,
    // and read-only (`$ro`: writing throws UnsupportedError).
    if (!_constant(e)) return js;
    final ro = '${_use(r'$ro')}($js)';
    return ctx.hoist ? _hoist(ro) : ro;
  }

  /// Sets and map keys are JS `Set`/`Map`, which find elements by identity
  /// (SameValueZero): Dart's `==` for numbers, strings, booleans, enums and
  /// objects that don't define `==`. Records and classes with `operator ==`
  /// get `$HS`/`$HM` ([_newSet], [_newMap]); a date value is the one still
  /// out (its hash is not defined in the runtime parts).
  void _checkElements(AstNode at, DartType t, String what) {
    if (t is! InterfaceType || t.typeArguments.isEmpty) return;
    final k = t.typeArguments.first;
    if (_dateValue(k)) {
      _fail(
        at,
        '$what of ${k.getDisplayString()} compare by value in Dart: not in '
        'the lite subset (use a key String or an int).',
      );
    }
  }
}

enum _Kind { list, set, map }

/// Collects the elements an AST refers to.
class _References extends RecursiveAstVisitor<void> {
  final elements = <Element>{};

  // `[Name]` in a doc comment is not a use.
  @override
  void visitComment(Comment node) {}

  // `Point(x: var x)`: the pattern reads the getter `x`.
  @override
  void visitPatternField(PatternField node) {
    if (node.element case final e?) elements.add(e);
    super.visitPatternField(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final e = node.element;
    if (e != null) elements.add(e);
    final parent = node.parent;
    if (parent is AssignmentExpression && parent.leftHandSide == node) {
      if (parent.writeElement case final w?) elements.add(w);
    }
    if (parent is PostfixExpression || parent is PrefixExpression) {
      final w = parent is PostfixExpression
          ? parent.writeElement
          : (parent as PrefixExpression).writeElement;
      if (w != null) elements.add(w);
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final c = node.constructorName.element;
    if (c != null) elements.add(c);
    super.visitInstanceCreationExpression(node);
  }

  // `query(repo.info)`: the function runs on the server only, so what it
  // names is never translated (it may use any package). Only `arg:` is.
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (isServerQueryCall(node)) {
      for (final a in node.argumentList.arguments) {
        if (a is NamedExpression) a.expression.accept(this);
      }
      return;
    }
    // `command(repo.add)`: the same, and it has nothing else to walk.
    if (isServerCommandCall(node)) return;
    // `events(url, initial: repo.all)`: the function is the server's and
    // the rest are literals.
    if (isServerEventStreamCall(node)) return;
    super.visitMethodInvocation(node);
  }

  @override
  void visitNamedType(NamedType node) {
    // Enum types in parameters parse page arguments by name; a superclass,
    // and a class tested at run time (`is`, `whereType<T>`, a pattern), is
    // needed in the JS.
    final e = node.element;
    if (e is EnumElement) elements.add(e);
    if (e != null && (e is ClassElement || e is MixinElement)) {
      final p = node.parent;
      // A mixin is applied by `with` even when no member of it is named
      // (one that only declares `==`).
      if (p is ExtendsClause ||
          p is WithClause ||
          p is IsExpression ||
          p is ObjectPattern ||
          p is DeclaredVariablePattern ||
          p is WildcardPattern ||
          p is TypeArgumentList && p.parent is MethodInvocation) {
        elements.add(e);
      }
      // A CallbackAction method's intent: the page makes it again.
      if (e is ClassElement && intentType(e.thisType) != null) {
        elements.add(e);
      }
    }
    super.visitNamedType(node);
  }
}

/// Whether [node] is thor's `query(fn)` or `queryWith(fn, arg:)`.
bool isServerQueryCall(MethodInvocation node) {
  final name = node.methodName.name;
  if (node.target != null || (name != 'query' && name != 'queryWith')) {
    return false;
  }
  final uri = '${node.methodName.element?.library?.uri}';
  return uri.startsWith('package:thor_engine/');
}

/// Whether [t] is thor's `ServerCommand` or `ServerCommandWith`.
bool isServerCommandType(DartType? t) =>
    t is InterfaceType &&
    (t.element.name == 'ServerCommand' ||
        t.element.name == 'ServerCommandWith') &&
    '${t.element.library.uri}'.startsWith('package:thor_engine/');

/// The argument and result types of command type [t] (`ServerCommand<R>`
/// has no argument: `Null`).
(DartType arg, DartType result) commandTypes(InterfaceType t) {
  final base = t.allSupertypes.firstWhere(
    (s) => s.element.name == 'ServerCommandBase',
  );
  final [arg, result] = base.typeArguments;
  return (arg, result);
}

/// Whether [node] is thor's `command(fn)` or `commandWith(fn)`.
bool isServerCommandCall(MethodInvocation node) {
  final name = node.methodName.name;
  if (node.target != null || (name != 'command' && name != 'commandWith')) {
    return false;
  }
  final uri = '${node.methodName.element?.library?.uri}';
  return uri.startsWith('package:thor_engine/');
}

/// Whether [t] is thor's `ServerQuery`.
bool isServerQueryType(DartType? t) =>
    t is InterfaceType &&
    t.element.name == 'ServerQuery' &&
    '${t.element.library.uri}'.startsWith('package:thor_engine/');

/// Whether [node] is thor's `events(url, ...)`.
bool isServerEventStreamCall(MethodInvocation node) {
  if (node.target != null || node.methodName.name != 'events') return false;
  final uri = '${node.methodName.element?.library?.uri}';
  return uri.startsWith('package:thor_engine/');
}

/// Whether [t] is thor's `ServerEventStream`.
bool isServerEventStreamType(DartType? t) =>
    t is InterfaceType &&
    t.element.name == 'ServerEventStream' &&
    '${t.element.library.uri}'.startsWith('package:thor_engine/');

/// Whether [t] is thor's `AsyncSnapshot`.
bool isAsyncSnapshotType(DartType? t) =>
    t is InterfaceType &&
    t.element.name == 'AsyncSnapshot' &&
    '${t.element.library.uri}'.startsWith('package:thor_engine/');

/// A cookie name `state(cookie:)` accepts (the engine's own rule,
/// THOR-S009).
bool _cookieName(String name) =>
    name.isNotEmpty &&
    name.length <= 40 &&
    name.codeUnits.every(
      (c) =>
          (c >= 0x30 && c <= 0x39) ||
          (c >= 0x41 && c <= 0x5A) ||
          (c >= 0x61 && c <= 0x7A) ||
          c == 0x5F ||
          c == 0x2D,
    );

/// A JS check that a decoded cookie is a [t] (what the Dart side's typed
/// restore accepts), or null when lite can't say (the field then needs a
/// `decode`, which checks it).
String? _persistCheck(DartType t) {
  String? scalar(DartType t) {
    if (t.nullabilitySuffix != NullabilitySuffix.none) {
      // A nullable record or function type is no scalar: it needs a codec.
      if (t is! InterfaceType) return null;
      final inner = scalar(t.element.thisType);
      return inner == null ? null : '(x == null || $inner)';
    }
    if (t.isDartCoreBool) return "typeof x === 'boolean'";
    if (t.isDartCoreInt) return 'Number.isInteger(x)';
    if (t.isDartCoreDouble || t.isDartCoreNum) return "typeof x === 'number'";
    if (t.isDartCoreString) return "typeof x === 'string'";
    return null;
  }

  final direct = scalar(t);
  if (direct != null) return '(x) => $direct';
  if (t is InterfaceType && t.typeArguments.isNotEmpty) {
    final item = scalar(t.typeArguments.last);
    if (item == null) return null;
    if (t.isDartCoreList && t.nullabilitySuffix == NullabilitySuffix.none) {
      return '(v) => Array.isArray(v) && v.every((x) => $item)';
    }
    if (t.isDartCoreMap &&
        t.typeArguments.first.isDartCoreString &&
        t.nullabilitySuffix == NullabilitySuffix.none) {
      return '(v) => v instanceof Map && [...v.values()].every((x) => $item)';
    }
  }
  return null;
}
