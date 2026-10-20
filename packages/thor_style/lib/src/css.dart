/// A set of CSS declarations, e.g. `{'padding': '8px', 'color': '#fff'}`.
///
/// Every thor_style value type compiles to one of these. Keeping the output a
/// plain map (instead of a framework-specific type) is what lets the same
/// styles be consumed by thor_ui, the thor runtime, SSR, or a static CSS emitter.
typedef CssDeclarations = Map<String, String>;

/// Formats a logical pixel value the way Flutter users expect:
/// `16` → `16px`, `0.5` → `0.5px`, `double.infinity` → `100%`.
///
/// Interned: equal values give the same string, so the render's style
/// memo hashes it once and compares it by identity (every element of
/// every page asks).
String cssPx(double value) {
  assert(!value.isNaN, 'NaN is not a valid length.');
  if (value == double.infinity) return '100%';
  final known = _pxStrings[value];
  if (known != null) return known;
  if (_pxStrings.length >= _internLimit) _pxStrings.clear();
  return _pxStrings[value] = '${cssNum(value)}px';
}

/// The `border-radius` of a fully rounded end (a pill).
///
/// `// web:` Flutter clamps `Radius.circular(double.infinity)` to half the
/// shorter side; CSS needs a large finite radius (`100%` would draw an
/// ellipse on a non-square box), and the browser clamps it the same way.
const cssPillRadius = '9999px';

/// Formats a corner radius: like [cssPx], but an infinite radius is
/// [cssPillRadius], not the `100%` that means a full width or height.
String cssRadiusPx(double value) =>
    value == double.infinity ? cssPillRadius : cssPx(value);

/// Formats a number without a trailing `.0` (interned, like [cssPx]).
String cssNum(num value) {
  assert(!value.isNaN, 'NaN is not a valid CSS number.');
  final known = _numStrings[value];
  if (known != null) return known;
  if (_numStrings.length >= _internLimit) _numStrings.clear();
  return _numStrings[value] = _formatNum(value);
}

String _formatNum(num value) {
  if (value is int) return '$value';
  if (!value.isFinite) {
    throw ArgumentError.value(
      value,
      'value',
      'A CSS number must be finite (only a length may be double.infinity, '
          'and it means 100%).',
    );
  }
  if (value == value.roundToDouble()) return '${value.toInt()}';
  // Four decimals without trailing zeros (and no trailing dot).
  final fixed = value.toStringAsFixed(4);
  var end = fixed.length;
  while (end > 0 && fixed.codeUnitAt(end - 1) == 0x30) {
    end--;
  }
  if (end > 0 && fixed.codeUnitAt(end - 1) == 0x2E) end--;
  return fixed.substring(0, end);
}

// Bounded: values computed from data (a width per item) must not grow the
// interned strings forever.
const _internLimit = 4096;
final _pxStrings = <double, String>{};
final _numStrings = <num, String>{};

/// Shortest CSS box shorthand for four sides (`8px`, `8px 16px`, …); works
/// for any length expression (`calc(env(…) + 8px)`).
String cssBox(String top, String right, String bottom, String left) {
  if (top == right && right == bottom && bottom == left) return top;
  if (top == bottom && right == left) return '$top $right';
  if (right == left) return '$top $right $bottom';
  return '$top $right $bottom $left';
}

/// Helpers on a declaration map.
extension CssDeclarationsX on CssDeclarations {
  /// Invalid property names dropped, values neutralized ([cssSafeValue]).
  CssDeclarations get sanitized => {
    for (final e in entries)
      if (isCssPropertyName(e.key)) e.key: cssSafeValue(e.value),
  };

  /// `prop: value; …` (sanitized).
  String get inline => cssInline(this);
}

/// Map entries in ascending key order (breakpoints, container widths).
extension SortedByKey<K extends Comparable<K>, V> on Map<K, V> {
  /// This map's entries, sorted in ascending key order.
  List<MapEntry<K, V>> get sortedByKey =>
      entries.toList()..sort((a, b) => a.key.compareTo(b.key));
}

/// Serializes [declarations] into an inline style / rule body string.
///
/// Invalid property names are dropped and values are sanitized with
/// [cssSafeValue], so the result is safe inside a `style` attribute *and*
/// inside a `<style>` element.
String cssInline(CssDeclarations declarations) => [
  for (final e in declarations.entries)
    if (isCssPropertyName(e.key)) '${e.key}: ${cssSafeValue(e.value)}',
].join('; ');

final _propertyName = RegExp(r'^(--[A-Za-z0-9_-]+|-?[A-Za-z][A-Za-z0-9-]*)$');

/// Whether [name] is a syntactically valid CSS property (or custom property).
bool isCssPropertyName(String name) => _propertyName.hasMatch(name);

/// Neutralizes characters that could end a declaration, a rule or the
/// `<style>` element itself (`;`, `{`, `}`, `<`, `>`, newlines) when they
/// appear outside quoted strings.
///
/// Values come from app data too (image URLs, font names, `Color.css`), so
/// `fontFamily: 'x; background: red'` or `'</style><script>'` must not be able
/// to inject declarations, rules or markup. Escaped characters are kept as CSS
/// escapes, which makes a malicious value invalid (the browser drops the
/// declaration) instead of executable.
String cssSafeValue(String value) {
  final out = StringBuffer();
  String? quote;
  for (var i = 0; i < value.length; i++) {
    final c = value[i];
    if (c == '<') {
      // Never allowed, not even in strings: `</style>` ends the element.
      out.write(r'\3c ');
      continue;
    }
    if (c == '\n' || c == '\r') {
      out.write(r'\a ');
      continue;
    }
    if (quote != null) {
      if (c == r'\' && i + 1 < value.length) {
        // The escaped character gets the same `<` and line-break checks: the
        // HTML tokenizer ignores CSS escapes, so `\</style>` still ends the
        // element. `\<` is `<` in a CSS string, so `\3c ` means the same.
        final next = value[++i];
        out.write(switch (next) {
          '<' => r'\3c ',
          '\n' || '\r' => r'\a ',
          _ => '$c$next',
        });
        continue;
      }
      if (c == quote) quote = null;
      out.write(c);
      continue;
    }
    switch (c) {
      case '"' || "'":
        quote = c;
        out.write(c);
      case ';':
        out.write(r'\3b ');
      case '{':
        out.write(r'\7b ');
      case '}':
        out.write(r'\7d ');
      case '>':
        out.write(r'\3e ');
      default:
        out.write(c);
    }
  }
  // An unterminated string would swallow the rest of the rule.
  if (quote != null) out.write(quote);
  return out.toString();
}

/// A CSS `url("…")` with the string properly escaped.
String cssUrl(String url) =>
    'url("${url.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('\n', '')}")';
