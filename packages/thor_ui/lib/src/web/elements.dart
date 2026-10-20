import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../engine/watch.dart' show engineAttributes;
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/errors.dart';
import '../widgets/theme.dart' show Theme;
import 'style.dart';

// Every element here is one `thorElement`: one HTML element with one class
// (its `Style`, in the `thor.props` layer), granting its children nothing
// (`ChildRules.none`): inside, CSS works as CSS. A Flutter widget placed in
// one keeps its own styles; a web element placed in a Row gets what the
// Row grants any child.

// What the element starts from, the preflight most web code assumes today
// (Tailwind's, shadcn's): no browser margins, headings and links that
// inherit the text around them, lists without bullets, images as blocks,
// buttons without chrome. Lowest priority: a `Style` always wins.
const _noMargin = {'margin': '0'};
const _heading = {
  'margin': '0',
  'font-size': 'inherit',
  'font-weight': 'inherit',
};
const _list = {'margin': '0', 'padding': '0', 'list-style': 'none'};
const _link = {'color': 'inherit', 'text-decoration': 'inherit'};
const _button = {
  'margin': '0',
  'padding': '0',
  'border': '0',
  'background-color': 'transparent',
  'color': 'inherit',
  'font': 'inherit',
  'text-align': 'inherit',
  'cursor': 'pointer',
};
const _image = {'display': 'block', 'max-width': '100%', 'height': 'auto'};
const _table = {
  'border-collapse': 'collapse',
  'border-spacing': '0',
  'text-indent': '0',
  'border-color': 'inherit',
};

/// Base of the HTML elements of `package:thor_ui/web.dart`: [tag] with
/// [style], [text] and [children].
abstract class WebElement extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// An element with [style], an optional [id] and extra [attributes].
  const WebElement({
    super.key,
    this.id,
    this.classes,
    this.style,
    this.text,
    this.children = const [],
    this.attributes = const {},
  });

  /// The element's `id`.
  final String? id;

  /// App class names, separated by spaces, next to the element's own
  /// generated class (`classes: 'table table-hover'`). A `class` in
  /// [attributes] is merged in the same way, never dropped.
  final String? classes;

  /// Its CSS properties (`Style(...)` or `tw('...')`).
  final Style? style;

  /// Text before [children], as a text node (no element of its own).
  final String? text;

  /// The elements inside.
  final List<Widget> children;

  /// Extra attributes (`data-*`, `aria-*`, `role`).
  final Map<String, String> attributes;

  /// The HTML tag.
  String get tag;

  CssDeclarations get _preflight => const {};

  CssDeclarations get _ownCss => const {};

  Map<String, String> get _ownAttributes => const {};

  // [classes] and a `class` attribute, split into names, without repeats.
  List<String> get _classNames {
    final raw = attributes['class'];
    if (classes == null && raw == null) return const [];
    return {
      for (final c in [?classes, ?raw])
        ...c.split(RegExp(r'\s+')).where((n) => n.isNotEmpty),
    }.toList();
  }

  // `class` goes through `classes:` so it joins the generated class instead
  // of being overwritten by it (or overwriting it).
  Map<String, String> get _attributesWithoutClass => {
    for (final e in {...attributes, ..._ownAttributes}.entries)
      if (e.key != 'class') e.key: e.value,
  };

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) _checkTokens(context, style);
    return thorElement(
      tag,
      id: id,
      debugName: _debugNames[tag] ?? 'WebElement',
      baseCss: _preflight,
      css: _ownCss.isEmpty
          ? style?.toCss() ?? const {}
          : orderShorthands(mergeAdaptive(_ownCss, style?.toCss() ?? const {})),
      classes: _classNames,
      attributes: _attributesWithoutClass,
      children: [if (text case final t?) Widget.text(t), ...children],
    );
  }
}

// A color token read by name (`tw('text-muted')`) must be in the theme:
// otherwise the variable is undefined and the color silently disappears.
void _checkTokens(BuildContext context, Style? style) {
  final wanted = style?.themeTokens ?? const <String>{};
  if (wanted.isEmpty) return;
  final known = Theme.of(context).colorTokens.keys.toSet();
  final missing = wanted.difference(known);
  if (missing.isEmpty) return;
  final name = missing.first;
  throw ArgumentError(
    thorError(
      'THOR-R013',
      'tw(): `$name` is not a color of the theme. Add it to '
          "ThemeData(colorTokens: {'$name': …}), use a role (primary, "
          'on-surface, outline…) or a hex (`bg-[#0f172a]`); thor has no '
          'Tailwind palette${known.isEmpty ? '' : '. Theme tokens: ${known.join(', ')}'}',
    ),
  );
}

const _debugNames = {
  'div': 'Box',
  'section': 'Section',
  'header': 'Header',
  'main': 'Main',
  'nav': 'Nav',
  'footer': 'Footer',
  'article': 'Article',
  'aside': 'Aside',
  'ul': 'Ul',
  'ol': 'Ol',
  'li': 'Li',
  'p': 'P',
  'span': 'Span',
  'h1': 'H1',
  'h2': 'H2',
  'h3': 'H3',
  'h4': 'H4',
  'h5': 'H5',
  'h6': 'H6',
  'a': 'A',
  'button': 'Button',
  'img': 'Img',
  'label': 'Label',
  'table': 'Table',
  'caption': 'Caption',
  'thead': 'Thead',
  'tbody': 'Tbody',
  'tfoot': 'Tfoot',
  'tr': 'Tr',
  'th': 'Th',
  'td': 'Td',
};

/// A `<div>` with a [Style]: the web layer's box.
///
/// ```dart
/// Box(style: tw('rounded-lg border p-4'), children: [...])
/// ```
class Box extends WebElement {
  /// A `<div>`.
  const Box({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.text,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'div';
}

/// Same as [Box], by its HTML name.
typedef Div = Box;

/// A flex container (`display: flex`) with CSS's names and defaults: a row
/// that doesn't wrap, children at their content size.
///
/// ```dart
/// FlexBox(direction: FlexDirection.column, gap: 8.px, children: [...])
/// ```
///
/// `// web:` not Flutter's `Flex`: children aren't stretched or shared out
/// (no `Expanded`); give one `Style(flexGrow: 1)` to take the rest.
class FlexBox extends WebElement {
  /// A `<div>` with `display: flex`.
  const FlexBox({
    super.key,
    super.id,
    super.classes,
    this.direction,
    this.wrap,
    this.gap,
    this.justify,
    this.align,
    super.style,
    super.children,
    super.attributes,
  });

  /// `flex-direction` (CSS default: row).
  final FlexDirection? direction;

  /// `flex-wrap` (CSS default: nowrap).
  final FlexWrap? wrap;

  /// `gap` between children.
  final Length? gap;

  /// `justify-content`: the main axis.
  final JustifyContent? justify;

  /// `align-items`: the cross axis (CSS default: stretch).
  final AlignItems? align;

  @override
  String get tag => 'div';

  @override
  CssDeclarations get _ownCss => Style(
    display: Display.flex,
    flexDirection: direction,
    flexWrap: wrap,
    gap: gap,
    justifyContent: justify,
    alignItems: align,
  ).toCss();
}

/// `<section>`.
class Section extends WebElement {
  /// A `<section>`.
  const Section({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.text,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'section';
}

/// `<header>`.
class Header extends WebElement {
  /// A `<header>`.
  const Header({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.text,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'header';
}

/// `<main>`.
class Main extends WebElement {
  /// A `<main>`.
  const Main({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.text,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'main';
}

/// `<nav>`.
class Nav extends WebElement {
  /// A `<nav>`.
  const Nav({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.text,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'nav';
}

/// `<footer>`.
class Footer extends WebElement {
  /// A `<footer>`.
  const Footer({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.text,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'footer';
}

/// `<article>`.
class Article extends WebElement {
  /// An `<article>`.
  const Article({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.text,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'article';
}

/// `<aside>`.
class Aside extends WebElement {
  /// An `<aside>`.
  const Aside({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.text,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'aside';
}

/// `<ul>`, without bullets or indent (see [Li]).
class Ul extends WebElement {
  /// A `<ul>`.
  const Ul({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'ul';

  @override
  CssDeclarations get _preflight => _list;
}

/// `<ol>`, without numbers or indent.
class Ol extends WebElement {
  /// An `<ol>`.
  const Ol({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'ol';

  @override
  CssDeclarations get _preflight => _list;
}

/// `<li>`.
class Li extends WebElement {
  /// An `<li>`.
  const Li({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.text,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'li';
}

/// `<p>`, without the browser's margins.
class P extends WebElement {
  /// A `<p>`.
  const P({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.text,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'p';

  @override
  CssDeclarations get _preflight => _noMargin;
}

/// `<span>`.
class Span extends WebElement {
  /// A `<span>`.
  const Span({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.text,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'span';
}

/// `<label>`; [htmlFor] is its `for`.
class Label extends WebElement {
  /// A `<label>`.
  const Label({
    super.key,
    super.id,
    super.classes,
    this.htmlFor,
    super.style,
    super.text,
    super.children,
    super.attributes,
  });

  /// The `id` of the control it names (`for`).
  final String? htmlFor;

  @override
  String get tag => 'label';

  @override
  Map<String, String> get _ownAttributes => {'for': ?htmlFor};
}

/// A heading `<h1>`…`<h6>`: semantics only, it inherits size and weight
/// (style it with [style]).
abstract class _Heading extends WebElement {
  const _Heading({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.text,
    super.children,
    super.attributes,
  });

  @override
  CssDeclarations get _preflight => _heading;
}

/// `<h1>`.
class H1 extends _Heading {
  /// An `<h1>`.
  const H1({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.text,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'h1';
}

/// `<h2>`.
class H2 extends _Heading {
  /// An `<h2>`.
  const H2({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.text,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'h2';
}

/// `<h3>`.
class H3 extends _Heading {
  /// An `<h3>`.
  const H3({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.text,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'h3';
}

/// `<h4>`.
class H4 extends _Heading {
  /// An `<h4>`.
  const H4({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.text,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'h4';
}

/// `<h5>`.
class H5 extends _Heading {
  /// An `<h5>`.
  const H5({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.text,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'h5';
}

/// `<h6>`.
class H6 extends _Heading {
  /// An `<h6>`.
  const H6({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.text,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'h6';
}

/// A link `<a href>` that inherits the text's color.
class A extends WebElement {
  /// A link to [href].
  const A({
    super.key,
    super.id,
    super.classes,
    required this.href,
    this.onClick,
    super.style,
    super.text,
    super.children,
    super.attributes,
  });

  /// Where it goes (`Routes.x()` for a page of the app).
  final String href;

  /// A `ThorState` method run on click (the link still works without JS).
  final void Function()? onClick;

  @override
  String get tag => 'a';

  @override
  CssDeclarations get _preflight => _link;

  @override
  Map<String, String> get _ownAttributes => {
    'href': href,
    ...engineAttributes({'click': onClick}),
  };
}

/// `<button type>` without the browser's chrome; with no [onClick] and in
/// no form it does nothing, like HTML's.
class Button extends WebElement {
  /// A button.
  const Button({
    super.key,
    super.id,
    super.classes,
    this.onClick,
    this.type = 'button',
    this.disabled = false,
    super.style,
    super.text,
    super.children,
    super.attributes,
  }) : assert(
         type == 'button' || type == 'submit' || type == 'reset',
         'A button type is button, submit or reset.',
       );

  /// A `ThorState` method run on click.
  final void Function()? onClick;

  /// `button`, `submit` (sends its form) or `reset`.
  final String type;

  /// `disabled`.
  final bool disabled;

  @override
  String get tag => 'button';

  @override
  CssDeclarations get _preflight => _button;

  @override
  Map<String, String> get _ownAttributes => {
    'type': type,
    if (disabled) 'disabled': '',
    ...engineAttributes({'click': onClick}),
  };
}

/// An image `<img>`: a block no wider than its box, height from its ratio.
/// [alt] is required (`''` for a decorative one).
class Img extends WebElement {
  /// An image of [src].
  const Img({
    super.key,
    super.id,
    super.classes,
    required this.src,
    required this.alt,
    this.width,
    this.height,
    this.lazy = true,
    super.style,
    super.attributes,
  });

  /// Its URL.
  final String src;

  /// What it shows, for who can't see it.
  final String alt;

  /// Intrinsic width in pixels (reserves its space before it loads).
  final int? width;

  /// Intrinsic height in pixels.
  final int? height;

  /// `loading="lazy"`: loads when it nears the screen.
  final bool lazy;

  @override
  String get tag => 'img';

  @override
  CssDeclarations get _preflight => _image;

  @override
  Map<String, String> get _ownAttributes => {
    'src': src,
    'alt': alt,
    if (width case final w?) 'width': '$w',
    if (height case final h?) 'height': '$h',
    if (lazy) 'loading': 'lazy',
  };
}

/// A `<table>`: rows and cells with the table's own semantics (screen
/// readers announce its size and each cell's header), collapsed borders.
///
/// ```dart
/// Table(children: [
///   Caption(text: "Today's orders"),
///   Thead(children: [Tr(children: [Th(scope: 'col', text: 'Customer')])]),
///   Tbody(children: [Tr(children: [Td(text: 'Jane Doe')])]),
/// ])
/// ```
///
/// `// web:` not Flutter's `Table` (that one is `TableRow`/`TableCell` on a
/// grid, from `thor_ui.dart`); this is HTML's. Keep its `display` (a table
/// laid out as `grid` or `flex` loses its semantics in some browsers): wrap
/// it in a `Box(style: tw('overflow-x-auto'))` to let it scroll on a phone.
class Table extends WebElement {
  /// A `<table>`.
  const Table({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'table';

  @override
  CssDeclarations get _preflight => _table;
}

/// `<caption>`: the table's title, announced with it.
class Caption extends WebElement {
  /// A `<caption>`.
  const Caption({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.text,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'caption';
}

/// `<thead>`: the header rows.
class Thead extends WebElement {
  /// A `<thead>`.
  const Thead({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'thead';
}

/// `<tbody>`: the body rows.
class Tbody extends WebElement {
  /// A `<tbody>`.
  const Tbody({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'tbody';
}

/// `<tfoot>`: the footer rows (totals).
class Tfoot extends WebElement {
  /// A `<tfoot>`.
  const Tfoot({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'tfoot';
}

/// `<tr>`: a row of [Th] and [Td].
class Tr extends WebElement {
  /// A `<tr>`.
  const Tr({
    super.key,
    super.id,
    super.classes,
    super.style,
    super.children,
    super.attributes,
  });

  @override
  String get tag => 'tr';
}

// `colspan`/`rowspan` as HTML takes them: a positive count.
Map<String, String> _spans(int? colSpan, int? rowSpan) => {
  if (colSpan case final c?) 'colspan': '$c',
  if (rowSpan case final r?) 'rowspan': '$r',
};

/// `<th>`: a header cell. [scope] says what it heads: `col`, `row`,
/// `colgroup` or `rowgroup`.
class Th extends WebElement {
  /// A `<th>`.
  const Th({
    super.key,
    super.id,
    super.classes,
    this.scope,
    this.colSpan,
    this.rowSpan,
    super.style,
    super.text,
    super.children,
    super.attributes,
  }) : assert(
         scope == null ||
             scope == 'col' ||
             scope == 'row' ||
             scope == 'colgroup' ||
             scope == 'rowgroup',
         'A th scope is col, row, colgroup or rowgroup.',
       ),
       assert(colSpan == null || colSpan > 0, 'colSpan is at least 1.'),
       assert(rowSpan == null || rowSpan >= 0, 'rowSpan is 0 or more.');

  /// `scope`: the cells this header names.
  final String? scope;

  /// `colspan`: columns it takes.
  final int? colSpan;

  /// `rowspan`: rows it takes (`0`: to the end of its section).
  final int? rowSpan;

  @override
  String get tag => 'th';

  @override
  Map<String, String> get _ownAttributes => {
    'scope': ?scope,
    ..._spans(colSpan, rowSpan),
  };
}

/// `<td>`: a data cell.
class Td extends WebElement {
  /// A `<td>`.
  const Td({
    super.key,
    super.id,
    super.classes,
    this.colSpan,
    this.rowSpan,
    super.style,
    super.text,
    super.children,
    super.attributes,
  }) : assert(colSpan == null || colSpan > 0, 'colSpan is at least 1.'),
       assert(rowSpan == null || rowSpan >= 0, 'rowSpan is 0 or more.');

  /// `colspan`: columns it takes.
  final int? colSpan;

  /// `rowspan`: rows it takes (`0`: to the end of its section).
  final int? rowSpan;

  @override
  String get tag => 'td';

  @override
  Map<String, String> get _ownAttributes => _spans(colSpan, rowSpan);
}
