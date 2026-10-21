import 'package:thor_style/thor_style.dart';

import 'errors.dart';
import 'foundation.dart' show kDebugMode;
import 'responsive.dart' show StyleProps;

// Debug pages are indented, release pages compact (the same layout as the
// rest of the page).
const _inset = kDebugMode ? '  ' : '';
const _space = kDebugMode ? '\n' : ' ';

/// A rule of the app's stylesheet (`styles:` of `initializeThor` or
/// `WidgetRenderer`): what no widget covers (`::before`, `:nth-child`,
/// classes of markup thor didn't build, keyframes). Built with [css].
sealed class StyleRule {
  const StyleRule();

  /// The CSS of this rule, at [indent] (in debug; release is compact).
  String toCss([String indent = '']);

  /// This rule inside the rule selecting [parent] (`&` stands for it).
  List<StyleRule> _resolve(String parent);
}

/// Builds the app's stylesheet rules:
///
/// ```dart
/// final appStyles = [
///   css('.card', [
///     css('&').props(StyleProps(padding: EdgeInsets.all(12))),
///     css('&:hover').props(const StyleProps(offset: Offset(0, -2))),
///   ]),
///   css.keyframes('fade', {
///     'from': const StyleProps(opacity: 0),
///     'to': const StyleProps(opacity: 1),
///   }),
///   WindowSizeClass.medium.media([css('.card').props(...)]),
/// ];
/// ```
const css = Css._();

/// The builder behind [css].
final class Css {
  const Css._();

  /// Rules for [selector], its own declarations (`.props()`) and nested
  /// [children], where `&` is this selector (`&:hover`; without `&` a child
  /// is a descendant).
  NestedStyleRule call(
    String selector, [
    List<StyleRule> children = const [],
  ]) => NestedStyleRule._(selector, const {}, children);

  /// `@property --name`: registers the custom property [name] as a color
  /// that starts as [initialValue], so a transition can animate it (a theme
  /// change as a cross-fade).
  ///
  /// `// web:` an unregistered custom property is text for the browser and
  /// jumps; registered, it interpolates like `color`.
  NestedStyleRule colorProperty(
    String name, {
    required Color initialValue,
    bool inherits = true,
  }) {
    assert(name.startsWith('--'), 'A custom property starts with --: $name');
    return NestedStyleRule._('@property $name', {
      'syntax': '"<color>"',
      'inherits': '$inherits',
      'initial-value': initialValue.css,
    }, const []);
  }

  /// `@media <query> { rules }`.
  StyleRule media(String query, List<StyleRule> rules) =>
      _GroupRule('@media', query, rules);

  /// `@media screen and (min-width: <px>) { rules }`: from a viewport width
  /// up, any width (`css.minWidth(920, [...])`), for the sizes that are no
  /// size class. Mobile-first, like `.when(medium: …)`.
  ///
  /// `// web:` the widths of widgets are the theme's four size classes; this
  /// is the escape for the app stylesheet. The widths of the size classes
  /// themselves: `WindowSizeClass.medium.media`.
  StyleRule minWidth(num px, List<StyleRule> rules) => _GroupRule(
    '@media',
    'screen and (min-width: ${cssPx(px.toDouble())})',
    rules,
  );

  /// `@media screen and (max-width: <px>) { rules }`: up to and including a
  /// viewport width (`css.maxWidth(919.98, …)` is "below 920"; a fraction
  /// avoids the 1px overlap with `css.minWidth(920, …)`).
  StyleRule maxWidth(num px, List<StyleRule> rules) => _GroupRule(
    '@media',
    'screen and (max-width: ${cssPx(px.toDouble())})',
    rules,
  );

  /// `@container [name] <query> { rules }`: rules for the size of the
  /// nearest ancestor that is a size container (`containerType:
  /// ContainerType.inlineSize`, or `LayoutScope`), not of the window.
  ///
  /// ```dart
  /// css.container('(min-width: 36rem)', [css('.product').props(…)]),
  /// css.container('(min-width: 48rem)', [...], name: 'catalog'),
  /// ```
  ///
  /// `// web:` no Flutter counterpart (its `LayoutBuilder` reads the box in
  /// `build`); for a widget that varies with its container use
  /// `.when(container: {…})` or `GridLayout(container:)`. This is the
  /// escape for rules of the app stylesheet. [name] picks the ancestor
  /// whose `container-name` it is.
  StyleRule container(String query, List<StyleRule> rules, {String? name}) {
    assert(
      name == null || RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*$').hasMatch(name),
      'A container name is one identifier: "$name"',
    );
    return _GroupRule(
      '@container',
      name == null ? query : '$name $query',
      rules,
    );
  }

  /// `@container (min-width: <px>) { rules }`: from the width of the
  /// container up, any width (`css.containerMinWidth(576, […])`).
  StyleRule containerMinWidth(num px, List<StyleRule> rules, {String? name}) =>
      container('(min-width: ${cssPx(px.toDouble())})', rules, name: name);

  /// `@layer <name> { rules }` (an anonymous layer without [name]).
  ///
  /// `name: 'thor'` means `thor.reset`: thor's layers are sublayers of
  /// `thor`, and rules straight in `thor` would beat all of
  /// them (widget props included) instead of sitting below.
  StyleRule layer(List<StyleRule> rules, {String? name}) =>
      _GroupRule('@layer', name == 'thor' ? 'thor.reset' : name, rules);

  /// The stylesheet of the app's reusable components, in `@layer
  /// thor.components`: below every element's own props, so a widget's
  /// values (`Container(color: …)`) and `Styled(style:)` beat the
  /// component's defaults, and above the reset and the theme.
  ///
  /// Declared once, next to the component (its class name, the rules for
  /// its states and breakpoints), and listed in the app stylesheet
  /// (`WidgetRenderer(styles:)`, `initializeThor(styles:)`): with shared
  /// styles it travels in the cached sheet, not in every page.
  ///
  /// ```dart
  /// class ProductCard extends StatelessWidget {
  ///   static final styles = css.components([
  ///     css('.product-card', [
  ///       css('&').props(StyleProps(padding: EdgeInsets.all(12))),
  ///       css('&:hover').props(StyleProps(offset: Offset(0, -2))),
  ///     ]),
  ///   ]);
  ///
  ///   @override
  ///   Widget build(BuildContext context) =>
  ///       Styled(classes: const ['product-card'], child: …);
  /// }
  /// ```
  StyleRule components(List<StyleRule> rules) =>
      _GroupRule('@layer', 'thor.components', rules);

  /// Rules in `@layer thor.overrides`, the last thor layer: they beat the
  /// own props of the elements they select, which [components] (below
  /// `thor.props`) cannot. For the states no widget prop names and that
  /// live on an ancestor (`:hover`, `:has([aria-current])`, `[open]`):
  /// `.row:has(a[aria-current]) .name` wins over the `Text`'s own
  /// `fontWeight`.
  ///
  /// ```dart
  /// css.states([
  ///   css('.tree-row:has(a[aria-current]) .tree-name')
  ///       .props(StyleProps(fontWeight: FontWeight.w600)),
  /// ]);
  /// ```
  ///
  /// `// web:` Flutter has no cascade; this is the layer order of CSS. The
  /// app stylesheet is unlayered and still beats every thor layer.
  StyleRule states(List<StyleRule> rules) =>
      _GroupRule('@layer', 'thor.overrides', rules);

  /// `@supports <condition> { rules }`.
  StyleRule supports(String condition, List<StyleRule> rules) =>
      _GroupRule('@supports', condition, rules);

  /// `@keyframes <name>`: each stop (`from`, `50%`, `to`) with its values.
  StyleRule keyframes(String name, Map<String, StyleProps> frames) =>
      _KeyframesRule(name, {
        for (final MapEntry(:key, :value) in frames.entries)
          key: _propsDeclarations(value),
      });
}

/// A selector with its declarations and nested rules (what [css] returns).
final class NestedStyleRule extends StyleRule {
  const NestedStyleRule._(this._selector, this._declarations, this._children);

  final String _selector;
  final CssDeclarations _declarations;
  final List<StyleRule> _children;

  /// These values as the rule's declarations: everything [StyleProps]
  /// covers. A stylesheet varies with its selectors and media queries, not
  /// with `.when()`: a value with variants is rejected.
  NestedStyleRule props(StyleProps props) => _with(_propsDeclarations(props));

  /// Declarations written as CSS (`raw:`): what no typed value covers yet.
  /// Invalid property names are dropped and values neutralized when the
  /// sheet is written.
  NestedStyleRule styles({required CssDeclarations raw}) => _with(raw);

  NestedStyleRule _with(CssDeclarations more) =>
      NestedStyleRule._(_selector, {..._declarations, ...more}, _children);

  @override
  String toCss([String indent = '']) =>
      [for (final rule in _resolve('')) rule.toCss(indent)].join(_space);

  @override
  List<StyleRule> _resolve(String parent) {
    final selector = resolveSelector(_selector, parent);
    return [
      if (_declarations.isNotEmpty) _BlockRule(selector, _declarations),
      for (final child in _children) ...child._resolve(selector),
    ];
  }
}

final class _BlockRule extends StyleRule {
  const _BlockRule(this.selector, this.declarations);

  final String selector;
  final CssDeclarations declarations;

  @override
  String toCss([String indent = '']) =>
      '$indent${safeCssPrelude(selector)} {$_space'
      '${_body(declarations, '$indent$_inset')}'
      '$indent}';

  @override
  List<StyleRule> _resolve(String parent) => [
    _BlockRule(resolveSelector(selector, parent), declarations),
  ];
}

final class _GroupRule extends StyleRule {
  const _GroupRule(this.keyword, this.prelude, this.rules);

  final String keyword;
  final String? prelude;
  final List<StyleRule> rules;

  @override
  String toCss([String indent = '']) =>
      '$indent$keyword${prelude == null ? '' : ' ${safeCssPrelude(prelude!)}'}'
      ' {$_space'
      '${[for (final r in rules) r.toCss('$indent$_inset') + _space].join()}'
      '$indent}';

  @override
  List<StyleRule> _resolve(String parent) => [
    _GroupRule(keyword, prelude, [
      for (final rule in rules) ...rule._resolve(parent),
    ]),
  ];
}

final class _KeyframesRule extends StyleRule {
  const _KeyframesRule(this.name, this.frames);

  final String name;
  final Map<String, CssDeclarations> frames;

  @override
  String toCss([String indent = '']) {
    final stops = StringBuffer();
    for (final MapEntry(:key, :value) in frames.entries) {
      stops
        ..write('$indent$_inset${safeCssPrelude(key)} {$_space')
        ..write(_body(value, '$indent$_inset$_inset'))
        ..write('$indent$_inset}$_space');
    }
    return '$indent@keyframes ${safeCssPrelude(name)} {$_space$stops$indent}';
  }

  @override
  List<StyleRule> _resolve(String parent) {
    if (parent.isNotEmpty) {
      throw ArgumentError(
        thorError(
          'THOR-R005',
          '@keyframes $name is nested inside `$parent`: keyframes go at the '
              'top of the stylesheet.',
        ),
      );
    }
    return [this];
  }
}

String _body(CssDeclarations declarations, String indent) => [
  for (final MapEntry(:key, :value) in declarations.entries)
    if (isCssPropertyName(key)) '$indent$key: ${cssSafeValue(value)};$_space',
].join();

CssDeclarations _propsDeclarations(StyleProps props) {
  final css = props.toCss();
  if (css.values.any(isAdaptive)) {
    // Not an assert: in release the variant's placeholder would reach the
    // stylesheet as garbage.
    throw ArgumentError(
      thorError(
        'THOR-R004',
        'A stylesheet varies with its selectors and media queries: '
            'StyleProps.when() is for Styled(style:).',
      ),
    );
  }
  return css;
}

/// [selector] inside the rule that selects [parent]: `&` stands for the
/// parent; without `&` the selector is a descendant of it. Lists are
/// resolved item by item (`.a, .b` with `&:hover` is `.a:hover,
/// .b:hover`), so no item escapes the parent.
String resolveSelector(String selector, String parent) {
  if (parent.isEmpty) return selector.replaceAll('&', '');
  final parents = _topLevelList(parent);
  final items = _topLevelList(selector);
  if (parents.length == 1 && items.length == 1) {
    // One selector, one parent: exactly the nesting rule stylesheets use.
    return selector.startsWith('&') || _hasNestingMark(selector)
        ? _replaceNestingMark(selector, parent)
        : '$parent $selector';
  }
  return [
    for (final item in items)
      for (final p in parents)
        _hasNestingMark(item) ? _replaceNestingMark(item, p) : '$p $item',
  ].join(', ');
}

/// The items of a selector list, split at commas outside quotes, brackets
/// and parentheses (`:is(a, b)` is one item).
List<String> _topLevelList(String selector) {
  final items = <String>[];
  var depth = 0, start = 0;
  String? quote;
  for (var i = 0; i < selector.length; i++) {
    final c = selector[i];
    if (quote != null) {
      if (c == r'\') {
        i++;
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    switch (c) {
      case '"' || "'":
        quote = c;
      case '(' || '[':
        depth++;
      case ')' || ']':
        depth--;
      case ',' when depth == 0:
        items.add(selector.substring(start, i).trim());
        start = i + 1;
    }
  }
  items.add(selector.substring(start).trim());
  return items;
}

bool _hasNestingMark(String selector) =>
    _replaceNestingMark(selector, '\u0000') != selector;

/// Replaces `&` outside quotes and attribute brackets (`[data-x="a&b"]`
/// keeps its `&`).
String _replaceNestingMark(String selector, String parent) {
  final out = StringBuffer();
  var bracket = 0;
  String? quote;
  for (var i = 0; i < selector.length; i++) {
    final c = selector[i];
    if (quote != null) {
      out.write(c);
      if (c == r'\' && i + 1 < selector.length) {
        out.write(selector[++i]);
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    if (c == '"' || c == "'") quote = c;
    if (c == '[') bracket++;
    if (c == ']') bracket--;
    out.write(c == '&' && bracket == 0 ? parent : c);
  }
  return out.toString();
}

/// A selector, media query or other at-rule prelude that can't end the
/// rule or the `<style>` element: `{`, `}`, `;` and line breaks outside
/// quotes and `<` anywhere become CSS escapes (the browser then drops the
/// rule instead of reading what follows as CSS or HTML). A valid prelude is
/// unchanged.
String safeCssPrelude(String prelude) {
  final out = StringBuffer();
  String? quote;
  for (var i = 0; i < prelude.length; i++) {
    final c = prelude[i];
    if (c == '<') {
      out.write(r'\3c ');
      continue;
    }
    if (c == '\n' || c == '\r') {
      out.write(r'\a ');
      continue;
    }
    if (quote != null) {
      if (c == r'\' && i + 1 < prelude.length) {
        // Same checks as `cssSafeValue`: `\</style>` still ends the element.
        final next = prelude[++i];
        out.write(switch (next) {
          '<' => r'\3c ',
          '\n' || '\r' => r'\a ',
          _ => '$c$next',
        });
        continue;
      }
      out.write(c);
      if (c == quote) {
        quote = null;
      }
      continue;
    }
    switch (c) {
      case '"' || "'":
        quote = c;
        out.write(c);
      case '{':
        out.write(r'\7b ');
      case '}':
        out.write(r'\7d ');
      case ';':
        out.write(r'\3b ');
      default:
        out.write(c);
    }
  }
  if (quote != null) out.write(quote);
  return out.toString();
}

/// Serializes [rules] into the app stylesheet, each rule once (a list
/// spread twice doesn't repeat it), in order.
String renderStyleRules(Iterable<StyleRule> rules) => [
  for (final rule in {...rules}) rule.toCss(),
].join();

/// [rules] without repeats (the first of each stays), in order.
List<StyleRule> uniqueStyleRules(Iterable<StyleRule> rules) => [
  ...{...rules},
];
