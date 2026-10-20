/// Plain-text helpers for the stylesheets thor writes: split them into
/// statements and group conditional rules under one at-rule each.
///
/// They read the CSS thor generates (flat rules, at-rules holding rules),
/// not any CSS: no nesting beyond one at-rule, no comments.
library;

/// A top-level statement of a stylesheet: `prelude{body}`, or `prelude;`
/// when `body` is null (`@layer a, b;`).
typedef CssStatement = ({String prelude, String? body});

/// The top-level statements of [css], in order. Quotes and parentheses are
/// skipped, so a brace inside a string or `url()` doesn't end a block.
List<CssStatement> splitCssStatements(String css) {
  final out = <CssStatement>[];
  var i = 0;
  final n = css.length;
  while (i < n) {
    // The prelude: up to `{` or `;` outside quotes/parentheses.
    var j = i;
    var paren = 0;
    String? quote;
    for (; j < n; j++) {
      final c = css[j];
      if (quote != null) {
        if (c == r'\') {
          j++;
        } else if (c == quote) {
          quote = null;
        }
      } else if (c == '"' || c == "'") {
        quote = c;
      } else if (c == '(') {
        paren++;
      } else if (c == ')') {
        paren--;
      } else if (paren == 0 && (c == '{' || c == ';')) {
        break;
      }
    }
    if (j >= n) {
      final rest = css.substring(i).trim();
      if (rest.isNotEmpty) out.add((prelude: rest, body: null));
      break;
    }
    final prelude = css.substring(i, j).trim();
    if (css[j] == ';') {
      if (prelude.isNotEmpty) out.add((prelude: prelude, body: null));
      i = j + 1;
      continue;
    }
    // The block: up to its matching `}`.
    var depth = 1;
    var k = j + 1;
    quote = null;
    for (; k < n && depth > 0; k++) {
      final c = css[k];
      if (quote != null) {
        if (c == r'\') {
          k++;
        } else if (c == quote) {
          quote = null;
        }
      } else if (c == '"' || c == "'") {
        quote = c;
      } else if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
      }
    }
    out.add((prelude: prelude, body: css.substring(j + 1, k - 1)));
    i = k;
  }
  return out;
}

/// The text of [statement].
String cssStatementText(CssStatement statement) => statement.body == null
    ? '${statement.prelude};'
    : '${statement.prelude}{${statement.body}}';

/// Whether [prelude] is a conditional group rule whose body holds rules
/// (`@media`, `@container`, `@supports`, `@starting-style`).
bool isConditionalPrelude(String prelude) =>
    prelude.startsWith('@media') ||
    prelude.startsWith('@container') ||
    prelude.startsWith('@supports') ||
    prelude.startsWith('@starting-style');

/// One rule of a class, and the at-rule that holds it (null: none).
typedef ClassRule = ({String? wrap, String rule});

/// The rules of a sequence of statements as `(wrap, rule)` pairs: the rules
/// inside a conditional group rule come out one by one, with its prelude.
List<ClassRule> flattenRules(Iterable<CssStatement> statements) => [
  for (final s in statements)
    if (s.body != null && isConditionalPrelude(s.prelude))
      for (final inner in splitCssStatements(s.body!))
        (wrap: s.prelude, rule: cssStatementText(inner))
    else
      (wrap: null, rule: cssStatementText(s)),
];

/// The rules of many classes as one stylesheet with one at-rule per run of
/// the same condition: `@media X{.a{…}.b{…}}` instead of
/// `@media X{.a{…}}@media X{.b{…}}`.
///
/// The order of each class's own rules is kept (a breakpoint after the
/// base, a later state over an earlier one): every rule goes to the first
/// group with its condition that comes after the group of the class's
/// previous rule, or to a new group at the end. Rules of different classes
/// may change order: they never meet on one element (one class per element
/// and layer), so their order doesn't matter.
String groupClassRules(Iterable<List<ClassRule>> classes) {
  final wraps = <String?>[];
  final bodies = <StringBuffer>[];
  // Group index → its condition, to find the next group with one.
  final byWrap = <String?, List<int>>{};
  for (final rules in classes) {
    var previous = -1;
    for (final (:wrap, :rule) in rules) {
      var target = -1;
      for (final g in byWrap[wrap] ?? const <int>[]) {
        if (g >= previous) {
          target = g;
          break;
        }
      }
      if (target < 0) {
        target = wraps.length;
        wraps.add(wrap);
        bodies.add(StringBuffer());
        (byWrap[wrap] ??= []).add(target);
      }
      bodies[target].write(rule);
      previous = target;
    }
  }
  final out = StringBuffer();
  for (var g = 0; g < wraps.length; g++) {
    final wrap = wraps[g];
    out.write(wrap == null ? bodies[g] : '$wrap{${bodies[g]}}');
  }
  return out.toString();
}
