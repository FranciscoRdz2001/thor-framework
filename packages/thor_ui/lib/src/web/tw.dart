// web: Tailwind's `sm:`/`md:`/`lg:`/`xl:` prefixes are Tailwind's own
// vocabulary: they are the window size classes in order (`medium`,
// `expanded`, `large`, `extraLarge`), so they follow the theme's widths.

import 'package:meta/meta.dart' show visibleForTesting;
import 'package:thor_style/thor_style.dart';

import '../foundation/errors.dart';
import 'style.dart';

/// Tailwind-style utilities, resolved on the server into the element's one
/// class: nothing reaches the browser but the declarations.
///
/// ```dart
/// Box(style: tw('flex items-center gap-2 rounded-lg border p-4 md:p-6 '
///     'hover:bg-surface-container dark:border-outline'))
/// ```
///
/// A subset of Tailwind v4, with thor's
/// differences:
///
/// * lengths in px (`p-4` is `16px`, Tailwind's `1rem`);
/// * colors are the theme's roles (`bg-primary`, `text-on-surface`,
///   `border-outline-variant`, with `/50` opacity), `white`, `black`,
///   `transparent`, `current`, a variable (`bg-(--brand)`) or a hex
///   (`bg-[#0f172a]`);
/// * `sm: md: lg: xl:` are thor's window size classes in order (`medium`,
///   `expanded`, `large`, `extraLarge`: the theme's widths, not Tailwind's);
///   `hover: active: focus-visible: focus-within: group-hover: group-open:
///   dark:`
///   thor's states; `@sm:`…`@7xl:` and `@min-[Npx]:` the nearest
///   container's width (`@container` makes one); one variant per utility.
///
/// A utility thor doesn't know is an error that names the closest one
/// (THOR-R013); two utilities setting the same property, too (THOR-R014).
Style tw(String utilities) {
  final known = _cache[utilities];
  if (known != null) return known;
  // Arbitrary values (`bg-[#$hex]`) built from data make a string each:
  // the memo is bounded, like the other per-process caches.
  if (_cache.length >= _cacheLimit) _cache.clear();
  return _cache[utilities] = _parse(utilities);
}

const _cacheLimit = 4096;
final _cache = <String, Style>{};

/// How many strings [tw] remembers.
@visibleForTesting
int get twCacheSize => _cache.length;

Style _parse(String utilities) {
  final base = <String, String>{};
  final variants = <String, Map<String, String>>{};
  final seen = <String, Map<String, String>>{};
  for (final token in utilities.split(RegExp(r'\s+'))) {
    if (token.isEmpty) continue;
    final colon = _variantSplit(token);
    final variant = colon == null ? null : token.substring(0, colon);
    final utility = colon == null ? token : token.substring(colon + 1);
    final key = variant == null ? null : _variantKey(variant, token);
    final decls = _utility(utility, token);
    final bucket = key == null ? base : (variants[key] ??= {});
    final owners = seen[key ?? ''] ??= {};
    final soft = _softOf(utility);
    for (final e in decls.entries) {
      final isSoft = soft.contains(e.key);
      if (owners[e.key] case final other?) {
        // A default of another utility (`text-sm`'s line height,
        // `transition`'s duration) gives way to the one that sets it
        // (`leading-6`, `duration-300`), in any order.
        final otherSoft = _softOf(_utilityPart(other)).contains(e.key);
        if (isSoft && !otherSoft) continue;
        if (!(otherSoft && !isSoft)) {
          throw ArgumentError(
            thorError(
              'THOR-R014',
              'tw(): `$other` and `$token` both set `${e.key}`; keep one',
            ),
          );
        }
      }
      owners[e.key] = token;
      bucket[e.key] = e.value;
    }
  }
  Style style(Map<String, String> m) {
    final css = orderShorthands(_withBorderStyles(m));
    return Style.declarations(css, themeTokens: _tokensIn(css));
  }

  final b = style(base);
  if (variants.isEmpty) return b;
  Style? v(String k) => variants[k] == null ? null : style(variants[k]!);
  return b.when(
    medium: v('medium'),
    expanded: v('expanded'),
    large: v('large'),
    extraLarge: v('extraLarge'),
    dark: v('dark'),
    open: v('open'),
    hover: v('hover'),
    focused: v('focused'),
    focusWithin: v('focus-within'),
    pressed: v('pressed'),
    groupHover: v('group-hover'),
    container: {
      for (final e in variants.entries)
        if (e.key.startsWith('@'))
          int.parse(e.key.substring(1)): style(e.value),
    },
  );
}

// The theme color tokens (not roles) that [css] reads.
Set<String> _tokensIn(CssDeclarations css) => {
  for (final v in css.values)
    for (final m in RegExp(r'var\(--t-([a-z0-9-]+)\)').allMatches(v))
      if (!_roles.contains(m[1])) m[1]!,
};

// The declarations of [utility] that are defaults another utility may set.
Set<String> _softOf(String utility) {
  if (utility.startsWith('text-') &&
      _fontSizes.containsKey(utility.substring(5))) {
    return const {'line-height'};
  }
  if (utility.startsWith('transition')) {
    return const {'transition-duration', 'transition-timing-function'};
  }
  return const {};
}

String _utilityPart(String token) {
  final colon = _variantSplit(token);
  return colon == null ? token : token.substring(colon + 1);
}

// The variant's end: the last `:` outside brackets (`@min-[400px]:p-4`).
int? _variantSplit(String token) {
  var depth = 0;
  int? at;
  for (var i = 0; i < token.length; i++) {
    final c = token[i];
    if (c == '[' || c == '(') depth++;
    if (c == ']' || c == ')') depth--;
    if (c == ':' && depth == 0) at = i;
  }
  return at;
}

const _containerSizes = {
  '3xs': 256,
  '2xs': 288,
  'xs': 320,
  'sm': 384,
  'md': 448,
  'lg': 512,
  'xl': 576,
  '2xl': 672,
  '3xl': 768,
  '4xl': 896,
  '5xl': 1024,
  '6xl': 1152,
  '7xl': 1280,
};

String _variantKey(String variant, String token) {
  const states = {
    // Tailwind's names for the window size classes in order, and the
    // classes' own names.
    'sm': 'medium',
    'md': 'expanded',
    'lg': 'large',
    'xl': 'extraLarge',
    'medium': 'medium',
    'expanded': 'expanded',
    'large': 'large',
    'extra-large': 'extraLarge',
    'dark': 'dark',
    'hover': 'hover',
    'active': 'pressed',
    'focus-visible': 'focused',
    'focus-within': 'focus-within',
    'group-hover': 'group-hover',
    // Tailwind's `group-open:`: the `<details>` around is open.
    'group-open': 'open',
  };
  if (states[variant] case final k?) return k;
  if (variant.startsWith('@')) {
    final size = variant.substring(1);
    if (_containerSizes[size] case final px?) return '@$px';
    final min = RegExp(r'^min-\[(\d+)px\]$').firstMatch(size);
    if (min != null) return '@${min[1]}';
  }
  final hint = switch (variant) {
    _ when variant.contains(':') =>
      'one variant per utility (thor has no `md:hover:`): use two utilities '
          'or Style(...).when()',
    'focus' => 'thor\'s focus state is the keyboard\'s: `focus-visible:`',
    '2xl' =>
      'thor has the window size classes medium, expanded, large and '
          'extra-large (and Tailwind\'s sm, md, lg, xl)',
    'disabled' ||
    'first' ||
    'last' ||
    'odd' ||
    'even' ||
    'group-focus' => 'not a thor state',
    _ =>
      'did you mean `${_closest(variant, [...states.keys, '@md', '@min-[400px]'])}:`?',
  };
  throw ArgumentError(
    thorError('THOR-R013', 'tw(): unknown variant in `$token`: $hint'),
  );
}

// A border width shows only with a style: solid unless `border-dashed`…,
// on the sides whose width is set (so `border-t` draws only the top).
Map<String, String> _withBorderStyles(Map<String, String> m) {
  final all = m.containsKey('border-width');
  final sides = [
    for (final s in ['top', 'right', 'bottom', 'left'])
      if (m.containsKey('border-$s-width')) s,
  ];
  if (!all && sides.isEmpty) return m;
  final style = m['border-style'];
  final styles = borderStyles(
    style: style == null
        ? null
        : LineStyle.values.firstWhere((s) => s.css == style),
    all: all,
    sides: sides,
  );
  // `border-t border-dashed`: the style goes to the top only, or the
  // other three sides would show the browser's medium width.
  return {...m, ...styles}..removeWhere(
    (k, _) => k == 'border-style' && !styles.containsKey('border-style'),
  );
}

// ---------------------------------------------------------------- values

const _roles = {
  'primary',
  'on-primary',
  'secondary',
  'on-secondary',
  'secondary-container',
  'on-secondary-container',
  'error',
  'on-error',
  'surface',
  'on-surface',
  'on-surface-variant',
  'surface-container',
  'surface-container-highest',
  'outline',
  'outline-variant',
};

final _hex = RegExp(
  r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
);
final _variable = RegExp(r'^--[a-z0-9][a-z0-9-]*$');
final _tokenName = RegExp(r'^[a-z][a-z0-9]*(-[a-z0-9]+)*$');
final _arbitraryLength = RegExp(
  r'^-?(\d+(\.\d+)?|\.\d+)(px|rem|em|%|ch|vw|vh|dvh|svh|lvh)$|^0$',
);

String? _color(String v) {
  final slash = v.lastIndexOf('/');
  final name = slash < 0 ? v : v.substring(0, slash);
  final alpha = slash < 0 ? null : int.tryParse(v.substring(slash + 1));
  if (slash >= 0 && (alpha == null || alpha < 0 || alpha > 100)) return null;
  final Color? c = switch (name) {
    'white' => const Color(0xFFFFFFFF),
    'black' => const Color(0xFF000000),
    'transparent' => const Color(0x00000000),
    'current' => const Color.css('currentColor'),
    'inherit' => const Color.css('inherit'),
    _ when _roles.contains(name) => Color.variable(CssVariable('--t-$name')),
    _ when name.startsWith('(') && name.endsWith(')') =>
      _variable.hasMatch(name.substring(1, name.length - 1))
          ? Color.variable(CssVariable(name.substring(1, name.length - 1)))
          : null,
    _ when name.startsWith('[') && name.endsWith(']') =>
      _hex.hasMatch(name.substring(1, name.length - 1))
          ? Color.css(name.substring(1, name.length - 1))
          : null,
    // One of the theme's `colorTokens` (`text-muted`): checked against the
    // theme when the element renders (see `Style.themeTokens`).
    _ when _tokenName.hasMatch(name) => Color.variable(
      CssVariable('--t-$name'),
    ),
    _ => null,
  };
  if (c == null) return null;
  return alpha == null ? c.css : c.withOpacity(alpha / 100).css;
}

/// A spacing value: `4` (16px), `0.5`, `px`, `[13px]`; with `sizes` also
/// `auto`, `full` and fractions (sizing utilities).
String? _length(String v, {bool sizes = false, bool auto = false}) {
  if (v == 'px') return '1px';
  if (auto && v == 'auto') return 'auto';
  final n = num.tryParse(v);
  if (n != null && n >= 0 && (n * 2) == (n * 2).roundToDouble()) {
    return n == 0 ? '0' : cssPx(n * 4.0);
  }
  if (v.startsWith('[') && v.endsWith(']')) {
    final inner = v.substring(1, v.length - 1);
    return _arbitraryLength.hasMatch(inner) ? inner : null;
  }
  if (v.startsWith('(') && v.endsWith(')')) {
    final inner = v.substring(1, v.length - 1);
    return _variable.hasMatch(inner) ? 'var($inner)' : null;
  }
  if (!sizes) return null;
  if (v == 'full') return '100%';
  final frac = RegExp(r'^(\d+)/(\d+)$').firstMatch(v);
  if (frac != null) {
    final d = int.parse(frac[2]!);
    if (d == 0) return null;
    return '${cssNum(int.parse(frac[1]!) * 100 / d)}%';
  }
  return null;
}

const _maxWidths = {
  '3xs': '256px',
  '2xs': '288px',
  'xs': '320px',
  'sm': '384px',
  'md': '448px',
  'lg': '512px',
  'xl': '576px',
  '2xl': '672px',
  '3xl': '768px',
  '4xl': '896px',
  '5xl': '1024px',
  '6xl': '1152px',
  '7xl': '1280px',
  'prose': '65ch',
  'none': 'none',
};

const _contentSizes = {
  'fit': 'fit-content',
  'min': 'min-content',
  'max': 'max-content',
};

// ------------------------------------------------------------- utilities

// Utilities that take a spacing value: family → properties.
const _spacing = {
  'p': ['padding'],
  'px': ['padding-inline'],
  'py': ['padding-block'],
  'pt': ['padding-top'],
  'pr': ['padding-right'],
  'pb': ['padding-bottom'],
  'pl': ['padding-left'],
  'ps': ['padding-inline-start'],
  'pe': ['padding-inline-end'],
  'm': ['margin'],
  'mx': ['margin-inline'],
  'my': ['margin-block'],
  'mt': ['margin-top'],
  'mr': ['margin-right'],
  'mb': ['margin-bottom'],
  'ml': ['margin-left'],
  'ms': ['margin-inline-start'],
  'me': ['margin-inline-end'],
  'gap': ['gap'],
  'gap-x': ['column-gap'],
  'gap-y': ['row-gap'],
  'inset': ['inset'],
  'inset-x': ['inset-inline'],
  'inset-y': ['inset-block'],
  'top': ['top'],
  'right': ['right'],
  'bottom': ['bottom'],
  'left': ['left'],
  'w': ['width'],
  'h': ['height'],
  'size': ['width', 'height'],
  'min-w': ['min-width'],
  'max-w': ['max-width'],
  'min-h': ['min-height'],
  'max-h': ['max-height'],
  'basis': ['flex-basis'],
  'leading': ['line-height'],
};

// Families that also take `auto`, `full`, fractions, `screen`…
const _sized = {
  'w', 'h', 'size', 'min-w', 'max-w', 'min-h', 'max-h', 'basis', //
  'inset', 'inset-x', 'inset-y', 'top', 'right', 'bottom', 'left',
};

// Families that take `auto` and a leading `-`.
const _signed = {
  'm', 'mx', 'my', 'mt', 'mr', 'mb', 'ml', 'ms', 'me', //
  'inset', 'inset-x', 'inset-y', 'top', 'right', 'bottom', 'left',
};

final _families = _spacing.keys.toList()
  ..sort((a, b) => b.length.compareTo(a.length));

const _fontSizes = {
  'xs': ('12px', '16px'),
  'sm': ('14px', '20px'),
  'base': ('16px', '24px'),
  'lg': ('18px', '28px'),
  'xl': ('20px', '28px'),
  '2xl': ('24px', '32px'),
  '3xl': ('30px', '36px'),
  '4xl': ('36px', '40px'),
  '5xl': ('48px', '1'),
  '6xl': ('60px', '1'),
  '7xl': ('72px', '1'),
};

const _radii = {
  '': '4px',
  'xs': '2px',
  'sm': '4px',
  'md': '6px',
  'lg': '8px',
  'xl': '12px',
  '2xl': '16px',
  '3xl': '24px',
  '4xl': '32px',
  'full': '9999px',
  'none': '0',
};

const _corners = {
  '': ['border-radius'],
  't': ['border-top-left-radius', 'border-top-right-radius'],
  'r': ['border-top-right-radius', 'border-bottom-right-radius'],
  'b': ['border-bottom-right-radius', 'border-bottom-left-radius'],
  'l': ['border-top-left-radius', 'border-bottom-left-radius'],
  'tl': ['border-top-left-radius'],
  'tr': ['border-top-right-radius'],
  'br': ['border-bottom-right-radius'],
  'bl': ['border-bottom-left-radius'],
};

const _shadows = {
  'shadow-2xs': '0 1px rgba(0, 0, 0, 0.05)',
  'shadow-xs': '0 1px 2px 0 rgba(0, 0, 0, 0.05)',
  'shadow-sm':
      '0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px -1px rgba(0, 0, 0, 0.1)',
  'shadow': '0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px -1px rgba(0, 0, 0, 0.1)',
  'shadow-md':
      '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -2px rgba(0, 0, 0, 0.1)',
  'shadow-lg':
      '0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -4px rgba(0, 0, 0, 0.1)',
  'shadow-xl':
      '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 8px 10px -6px rgba(0, 0, 0, 0.1)',
  'shadow-2xl': '0 25px 50px -12px rgba(0, 0, 0, 0.25)',
  'shadow-none': 'none',
};

const _transitionColors =
    'color, background-color, border-color, text-decoration-color, fill, '
    'stroke';
const _ease = 'cubic-bezier(0.4, 0, 0.2, 1)';

// Utilities without a value.
const Map<String, Map<String, String>> _static = {
  // Display.
  'block': {'display': 'block'},
  'inline-block': {'display': 'inline-block'},
  'inline': {'display': 'inline'},
  'flex': {'display': 'flex'},
  'inline-flex': {'display': 'inline-flex'},
  'grid': {'display': 'grid'},
  'inline-grid': {'display': 'inline-grid'},
  'contents': {'display': 'contents'},
  'flow-root': {'display': 'flow-root'},
  'hidden': {'display': 'none'},
  // Position.
  'static': {'position': 'static'},
  'relative': {'position': 'relative'},
  'absolute': {'position': 'absolute'},
  'fixed': {'position': 'fixed'},
  'sticky': {'position': 'sticky'},
  'isolate': {'isolation': 'isolate'},
  'visible': {'visibility': 'visible'},
  'invisible': {'visibility': 'hidden'},
  'sr-only': {
    'position': 'absolute',
    'width': '1px',
    'height': '1px',
    'padding': '0',
    'margin': '-1px',
    'overflow': 'hidden',
    'clip-path': 'inset(50%)',
    'white-space': 'nowrap',
    'border-width': '0',
  },
  '@container': {'container-type': 'inline-size'},
  // Flex and grid.
  'flex-row': {'flex-direction': 'row'},
  'flex-row-reverse': {'flex-direction': 'row-reverse'},
  'flex-col': {'flex-direction': 'column'},
  'flex-col-reverse': {'flex-direction': 'column-reverse'},
  'flex-wrap': {'flex-wrap': 'wrap'},
  'flex-nowrap': {'flex-wrap': 'nowrap'},
  'flex-wrap-reverse': {'flex-wrap': 'wrap-reverse'},
  'flex-1': {'flex': '1 1 0%'},
  'flex-auto': {'flex': '1 1 auto'},
  'flex-initial': {'flex': '0 1 auto'},
  'flex-none': {'flex': 'none'},
  'grow': {'flex-grow': '1'},
  'grow-0': {'flex-grow': '0'},
  'shrink': {'flex-shrink': '1'},
  'shrink-0': {'flex-shrink': '0'},
  'order-first': {'order': '-9999'},
  'order-last': {'order': '9999'},
  'order-none': {'order': '0'},
  'grid-cols-none': {'grid-template-columns': 'none'},
  'grid-cols-subgrid': {'grid-template-columns': 'subgrid'},
  'grid-rows-none': {'grid-template-rows': 'none'},
  'grid-flow-row': {'grid-auto-flow': 'row'},
  'grid-flow-col': {'grid-auto-flow': 'column'},
  'grid-flow-dense': {'grid-auto-flow': 'dense'},
  'col-span-full': {'grid-column': '1 / -1'},
  'row-span-full': {'grid-row': '1 / -1'},
  'items-start': {'align-items': 'flex-start'},
  'items-end': {'align-items': 'flex-end'},
  'items-center': {'align-items': 'center'},
  'items-baseline': {'align-items': 'baseline'},
  'items-stretch': {'align-items': 'stretch'},
  'justify-start': {'justify-content': 'flex-start'},
  'justify-end': {'justify-content': 'flex-end'},
  'justify-center': {'justify-content': 'center'},
  'justify-between': {'justify-content': 'space-between'},
  'justify-around': {'justify-content': 'space-around'},
  'justify-evenly': {'justify-content': 'space-evenly'},
  'justify-stretch': {'justify-content': 'stretch'},
  'justify-items-start': {'justify-items': 'start'},
  'justify-items-center': {'justify-items': 'center'},
  'justify-items-end': {'justify-items': 'end'},
  'justify-items-stretch': {'justify-items': 'stretch'},
  'justify-self-start': {'justify-self': 'start'},
  'justify-self-center': {'justify-self': 'center'},
  'justify-self-end': {'justify-self': 'end'},
  'justify-self-stretch': {'justify-self': 'stretch'},
  'content-start': {'align-content': 'flex-start'},
  'content-center': {'align-content': 'center'},
  'content-end': {'align-content': 'flex-end'},
  'content-between': {'align-content': 'space-between'},
  'self-auto': {'align-self': 'auto'},
  'self-start': {'align-self': 'flex-start'},
  'self-end': {'align-self': 'flex-end'},
  'self-center': {'align-self': 'center'},
  'self-stretch': {'align-self': 'stretch'},
  'self-baseline': {'align-self': 'baseline'},
  'place-items-center': {'place-items': 'center'},
  'place-content-center': {'place-content': 'center'},
  'place-self-center': {'place-self': 'center'},
  // Sizing keywords.
  'w-screen': {'width': '100vw'},
  'w-dvw': {'width': '100dvw'},
  'h-screen': {'height': '100vh'},
  'h-dvh': {'height': '100dvh'},
  'h-svh': {'height': '100svh'},
  'min-h-screen': {'min-height': '100vh'},
  'min-h-dvh': {'min-height': '100dvh'},
  'max-h-screen': {'max-height': '100vh'},
  'max-h-dvh': {'max-height': '100dvh'},
  'aspect-square': {'aspect-ratio': '1 / 1'},
  'aspect-video': {'aspect-ratio': '16 / 9'},
  'aspect-auto': {'aspect-ratio': 'auto'},
  // Overflow.
  'overflow-auto': {'overflow': 'auto'},
  'overflow-hidden': {'overflow': 'hidden'},
  'overflow-clip': {'overflow': 'clip'},
  'overflow-visible': {'overflow': 'visible'},
  'overflow-scroll': {'overflow': 'scroll'},
  'overflow-x-auto': {'overflow-x': 'auto'},
  'overflow-x-hidden': {'overflow-x': 'hidden'},
  'overflow-x-scroll': {'overflow-x': 'scroll'},
  'overflow-y-auto': {'overflow-y': 'auto'},
  'overflow-y-hidden': {'overflow-y': 'hidden'},
  'overflow-y-scroll': {'overflow-y': 'scroll'},
  // Borders.
  'border-solid': {'border-style': 'solid'},
  'border-dashed': {'border-style': 'dashed'},
  'border-dotted': {'border-style': 'dotted'},
  'border-double': {'border-style': 'double'},
  'border-none': {'border-style': 'none'},
  // Typography.
  'font-sans': {
    'font-family':
        'ui-sans-serif, system-ui, sans-serif, "Apple Color Emoji", '
        '"Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji"',
  },
  'font-serif': {
    'font-family':
        'ui-serif, Georgia, Cambria, "Times New Roman", Times, serif',
  },
  'font-mono': {
    'font-family':
        'ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, '
        '"Liberation Mono", "Courier New", monospace',
  },
  'font-thin': {'font-weight': '100'},
  'font-extralight': {'font-weight': '200'},
  'font-light': {'font-weight': '300'},
  'font-normal': {'font-weight': '400'},
  'font-medium': {'font-weight': '500'},
  'font-semibold': {'font-weight': '600'},
  'font-bold': {'font-weight': '700'},
  'font-extrabold': {'font-weight': '800'},
  'font-black': {'font-weight': '900'},
  'italic': {'font-style': 'italic'},
  'not-italic': {'font-style': 'normal'},
  'underline': {'text-decoration-line': 'underline'},
  'overline': {'text-decoration-line': 'overline'},
  'line-through': {'text-decoration-line': 'line-through'},
  'no-underline': {'text-decoration-line': 'none'},
  'uppercase': {'text-transform': 'uppercase'},
  'lowercase': {'text-transform': 'lowercase'},
  'capitalize': {'text-transform': 'capitalize'},
  'normal-case': {'text-transform': 'none'},
  'truncate': {
    'overflow': 'hidden',
    'text-overflow': 'ellipsis',
    'white-space': 'nowrap',
  },
  'text-ellipsis': {'text-overflow': 'ellipsis'},
  'text-clip': {'text-overflow': 'clip'},
  'text-left': {'text-align': 'left'},
  'text-center': {'text-align': 'center'},
  'text-right': {'text-align': 'right'},
  'text-justify': {'text-align': 'justify'},
  'text-start': {'text-align': 'start'},
  'text-end': {'text-align': 'end'},
  'text-wrap': {'text-wrap': 'wrap'},
  'text-nowrap': {'text-wrap': 'nowrap'},
  'text-balance': {'text-wrap': 'balance'},
  'text-pretty': {'text-wrap': 'pretty'},
  'whitespace-normal': {'white-space': 'normal'},
  'whitespace-nowrap': {'white-space': 'nowrap'},
  'whitespace-pre': {'white-space': 'pre'},
  'whitespace-pre-line': {'white-space': 'pre-line'},
  'whitespace-pre-wrap': {'white-space': 'pre-wrap'},
  'break-words': {'overflow-wrap': 'break-word'},
  'break-all': {'word-break': 'break-all'},
  'break-normal': {'overflow-wrap': 'normal', 'word-break': 'normal'},
  'tabular-nums': {'font-variant-numeric': 'tabular-nums'},
  'antialiased': {
    '-webkit-font-smoothing': 'antialiased',
    '-moz-osx-font-smoothing': 'grayscale',
  },
  'tracking-tighter': {'letter-spacing': '-0.05em'},
  'tracking-tight': {'letter-spacing': '-0.025em'},
  'tracking-normal': {'letter-spacing': '0'},
  'tracking-wide': {'letter-spacing': '0.025em'},
  'tracking-wider': {'letter-spacing': '0.05em'},
  'tracking-widest': {'letter-spacing': '0.1em'},
  'leading-none': {'line-height': '1'},
  'leading-tight': {'line-height': '1.25'},
  'leading-snug': {'line-height': '1.375'},
  'leading-normal': {'line-height': '1.5'},
  'leading-relaxed': {'line-height': '1.625'},
  'leading-loose': {'line-height': '2'},
  'list-none': {'list-style-type': 'none'},
  'list-disc': {'list-style-type': 'disc'},
  'list-decimal': {'list-style-type': 'decimal'},
  'list-inside': {'list-style-position': 'inside'},
  'list-outside': {'list-style-position': 'outside'},
  // Images.
  'object-contain': {'object-fit': 'contain'},
  'object-cover': {'object-fit': 'cover'},
  'object-fill': {'object-fit': 'fill'},
  'object-none': {'object-fit': 'none'},
  'object-scale-down': {'object-fit': 'scale-down'},
  'object-center': {'object-position': 'center'},
  'object-top': {'object-position': 'top'},
  // Interaction.
  'cursor-auto': {'cursor': 'auto'},
  'cursor-default': {'cursor': 'default'},
  'cursor-pointer': {'cursor': 'pointer'},
  'cursor-text': {'cursor': 'text'},
  'cursor-move': {'cursor': 'move'},
  'cursor-grab': {'cursor': 'grab'},
  'cursor-wait': {'cursor': 'wait'},
  'cursor-help': {'cursor': 'help'},
  'cursor-not-allowed': {'cursor': 'not-allowed'},
  'pointer-events-none': {'pointer-events': 'none'},
  'pointer-events-auto': {'pointer-events': 'auto'},
  'select-none': {'user-select': 'none'},
  'select-text': {'user-select': 'text'},
  'select-all': {'user-select': 'all'},
  'select-auto': {'user-select': 'auto'},
  'appearance-none': {'appearance': 'none'},
  'outline-none': {'outline-style': 'none'},
  // Transitions (thor has no motion variant: prefer `AnimatedContainer`
  // or `Styled(duration:)` where reduced motion matters).
  'transition': {
    'transition-property':
        '$_transitionColors, opacity, box-shadow, transform, translate, '
        'scale, rotate, filter',
    'transition-timing-function': _ease,
    'transition-duration': '150ms',
  },
  'transition-colors': {
    'transition-property': _transitionColors,
    'transition-timing-function': _ease,
    'transition-duration': '150ms',
  },
  'transition-opacity': {
    'transition-property': 'opacity',
    'transition-timing-function': _ease,
    'transition-duration': '150ms',
  },
  'transition-shadow': {
    'transition-property': 'box-shadow',
    'transition-timing-function': _ease,
    'transition-duration': '150ms',
  },
  'transition-transform': {
    'transition-property': 'transform, translate, scale, rotate',
    'transition-timing-function': _ease,
    'transition-duration': '150ms',
  },
  'transition-all': {
    'transition-property': 'all',
    'transition-timing-function': _ease,
    'transition-duration': '150ms',
  },
  'transition-none': {'transition-property': 'none'},
  'ease-linear': {'transition-timing-function': 'linear'},
  'ease-in': {'transition-timing-function': 'cubic-bezier(0.4, 0, 1, 1)'},
  'ease-out': {'transition-timing-function': 'cubic-bezier(0, 0, 0.2, 1)'},
  'ease-in-out': {'transition-timing-function': _ease},
};

// Utilities Tailwind has and thor answers differently.
const _instead = {
  'space-x': 'gap-x-N on the parent (flex or grid)',
  'space-y': 'gap-y-N on the parent (flex or grid)',
  'divide-x': 'border-l on each child',
  'divide-y': 'border-t on each child',
  'container': 'mx-auto max-w-7xl (thor has no container class)',
  'ring': 'border or shadow (thor has no ring)',
  'bg-gradient': 'a BoxDecoration(gradient:) in Flutter mode',
  'animate': 'an Animated* widget or a keyframes stylesheet',
  'translate': 'Style(...) and a Transform widget',
  'rotate': 'a Transform widget',
  'scale': 'a Transform widget',
};

CssDeclarations _utility(String u, String token) {
  if (_static[u] case final d?) return d;
  if (_shadows[u] case final s?) return {'box-shadow': s};
  final r = _valued(u);
  if (r != null) return r;
  final family = _instead.keys.where(u.startsWith).firstOrNull;
  throw ArgumentError(
    thorError(
      'THOR-R013',
      family != null
          ? 'tw(): `$token` is not in thor; use ${_instead[family]}'
          : 'tw(): unknown utility `$token`; did you mean '
                '`${_closest(u, _examples)}`?',
    ),
  );
}

CssDeclarations? _valued(String u) {
  // Negative values of margins and offsets: `-mt-2`.
  final negative = u.startsWith('-');
  final body = negative ? u.substring(1) : u;
  for (final f in _families) {
    if (!body.startsWith('$f-')) continue;
    final v = body.substring(f.length + 1);
    if (negative && !_signed.contains(f)) return null;
    String? value;
    if (f == 'leading') {
      value = negative ? null : _length(v);
    } else if (f == 'max-w' && _maxWidths[v] != null) {
      value = _maxWidths[v];
    } else if (_sized.contains(f) && _contentSizes[v] != null) {
      value = _contentSizes[v];
    } else {
      value = _length(
        v,
        sizes: _sized.contains(f),
        auto: _signed.contains(f) || _sized.contains(f),
      );
    }
    if (value == null) return null;
    if (negative && value != '0') {
      value = RegExp(r'^\d').hasMatch(value) ? '-$value' : 'calc($value * -1)';
    }
    return {for (final p in _spacing[f]!) p: value};
  }
  if (negative) return null;
  // Typography, colors and borders.
  if (u.startsWith('text-')) {
    final v = u.substring(5);
    if (_fontSizes[v] case (final size, final lh)) {
      return {'font-size': size, 'line-height': lh};
    }
    // `text-[28px]`: an arbitrary size (a hex in brackets is a color).
    if (v.startsWith('[') &&
        v.endsWith(']') &&
        _arbitraryLength.hasMatch(v.substring(1, v.length - 1))) {
      return {'font-size': v.substring(1, v.length - 1)};
    }
    // `text-sm/6`: a size with its line height.
    final slash = v.indexOf('/');
    final sized = slash > 0 ? _fontSizes[v.substring(0, slash)] : null;
    if (sized != null) {
      final lh = _length(v.substring(slash + 1));
      if (lh != null) return {'font-size': sized.$1, 'line-height': lh};
    }
    if (_color(v) case final c?) return {'color': c};
    return null;
  }
  if (u.startsWith('bg-')) {
    if (_color(u.substring(3)) case final c?) return {'background-color': c};
    return null;
  }
  if (u == 'border' || u.startsWith('border-')) return _border(u);
  if (u == 'rounded' || u.startsWith('rounded-')) return _rounded(u);
  // Numbered utilities.
  final m = RegExp(r'^([a-z-]+)-(\d+)$').firstMatch(u);
  if (m == null) return null;
  final n = int.parse(m[2]!);
  return switch (m[1]) {
    'grid-cols' when n > 0 => {
      'grid-template-columns': 'repeat($n, minmax(0, 1fr))',
    },
    'grid-rows' when n > 0 => {
      'grid-template-rows': 'repeat($n, minmax(0, 1fr))',
    },
    'col-span' when n > 0 => {'grid-column': 'span $n / span $n'},
    'row-span' when n > 0 => {'grid-row': 'span $n / span $n'},
    'col-start' when n > 0 => {'grid-column-start': '$n'},
    'col-end' when n > 0 => {'grid-column-end': '$n'},
    'row-start' when n > 0 => {'grid-row-start': '$n'},
    'row-end' when n > 0 => {'grid-row-end': '$n'},
    'order' => {'order': '$n'},
    'grow' => {'flex-grow': '$n'},
    'shrink' => {'flex-shrink': '$n'},
    'z' => {'z-index': '$n'},
    'opacity' when n <= 100 => {'opacity': cssNum(n / 100)},
    'duration' => {'transition-duration': '${n}ms'},
    'line-clamp' when n > 0 => {
      'overflow': 'hidden',
      'display': '-webkit-box',
      '-webkit-box-orient': 'vertical',
      '-webkit-line-clamp': '$n',
    },
    _ => null,
  };
}

CssDeclarations? _border(String u) {
  final rest = u == 'border' ? '' : u.substring('border-'.length);
  const sides = {
    '': ['border-width'],
    'x': ['border-left-width', 'border-right-width'],
    'y': ['border-top-width', 'border-bottom-width'],
    't': ['border-top-width'],
    'r': ['border-right-width'],
    'b': ['border-bottom-width'],
    'l': ['border-left-width'],
  };
  // `border`, `border-2`, `border-t`, `border-t-2`, `border-x-4`.
  final m = RegExp(r'^(?:([xytrbl])(?:-|$))?(\d+)?$').firstMatch(rest);
  if (m != null && (m[1] != null || m[2] != null || rest.isEmpty)) {
    final width = m[2] == null ? '1px' : cssPx(double.parse(m[2]!));
    return {for (final p in sides[m[1] ?? '']!) p: width};
  }
  if (_color(rest) case final c?) return {'border-color': c};
  return null;
}

CssDeclarations? _rounded(String u) {
  final rest = u == 'rounded' ? '' : u.substring('rounded-'.length);
  final parts = rest.split('-');
  final corner = _corners.containsKey(parts.first) && parts.first.isNotEmpty
      ? parts.first
      : '';
  final size = corner.isEmpty ? rest : parts.skip(1).join('-');
  final value = _radii[size];
  if (value == null) return null;
  return {for (final p in _corners[corner]!) p: value};
}

// Candidates for "did you mean": every static utility and one of each
// valued family.
final List<String> _examples = [
  ..._static.keys,
  ..._shadows.keys,
  for (final f in _spacing.keys) '$f-4',
  'max-w-md', 'w-full', 'h-full', 'mx-auto', 'text-sm', 'text-lg', //
  'text-primary', 'text-on-surface', 'bg-primary', 'bg-surface',
  'bg-surface-container', 'border', 'border-2', 'border-t',
  'border-outline', 'border-outline-variant', 'rounded', 'rounded-lg',
  'rounded-full', 'grid-cols-2', 'col-span-2', 'opacity-50', 'z-10',
  'duration-200', 'line-clamp-2', 'order-1',
];

String _closest(String s, List<String> candidates) {
  var best = candidates.first;
  var bestD = 1 << 30;
  for (final c in candidates) {
    final d = _distance(s, c);
    if (d < bestD) {
      best = c;
      bestD = d;
    }
  }
  return best;
}

int _distance(String a, String b) {
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = [i, ...List.filled(b.length, 0)];
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = [
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}
