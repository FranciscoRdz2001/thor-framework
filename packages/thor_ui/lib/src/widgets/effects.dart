import 'package:thor_style/thor_style.dart';

import '../foundation/html_attributes.dart' show HtmlAttributes;
import '../foundation/parent_data.dart';
import '../foundation/style_registry.dart' show ConditionalCss, CssCondition;
import 'basic.dart' show buttonResetCss, listResetCss;
import 'native_control.dart'
    show childHasOwnRole, childIsNativeCheck, childIsNativeRange;

/// Flutter's `Opacity` (GPU-composited `opacity`).
class Opacity extends ParentDataWrapper {
  /// Creates a widget that makes [child] partially transparent.
  const Opacity({super.key, required this.opacity, required super.child});

  /// Opacity value between 0 (invisible) and 1 (fully opaque).
  final double opacity;

  @override
  WrapData get wrapData {
    assert(opacity >= 0 && opacity <= 1, 'Opacity must be between 0 and 1.');
    return WrapData(css: {if (opacity != 1) 'opacity': cssNum(opacity)});
  }
}

/// Flutter's `BackdropFilter`: filters what is behind [child], not [child]
/// itself (a translucent panel over a blurred canvas).
///
/// ```dart
/// BackdropFilter(
///   filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
///   child: Container(color: panel.withOpacity(0.8), child: …),
/// )
/// ```
///
/// `// web:` fused into the element of [child] as `backdrop-filter`; the
/// browser clips it to the box of [child] (Flutter clips with a `ClipRect`
/// around it). [child] needs a translucent background to show anything.
class BackdropFilter extends ParentDataWrapper {
  /// Creates a widget that applies [filter] to what is behind [child].
  const BackdropFilter({
    super.key,
    required this.filter,
    this.enabled = true,
    required super.child,
  });

  /// The filter over the backdrop (`ImageFilter.blur`, `saturate`…).
  final ImageFilter filter;

  /// Whether [filter] applies; false leaves [child] as it is.
  final bool enabled;

  // web: Flutter's `blendMode` and `backdropGroupKey` have no CSS (the
  // browser composites the filtered backdrop itself).
  @override
  WrapData get wrapData => enabled
      ? WrapData(css: {'backdrop-filter': filter.css})
      : const WrapData();
}

/// Flutter's `Transform` with its named constructors. Uses CSS transforms,
/// which run on the compositor and do not trigger layout.
class Transform extends ParentDataWrapper {
  /// Creates a widget that rotates [child] by [angle] radians.
  Transform.rotate({
    super.key,
    required double angle,
    this.alignment = Alignment.center,
    required super.child,
  }) : _transform = 'rotate(${cssNum(angle)}rad)';

  /// Creates a widget that scales [child] by [scale].
  Transform.scale({
    super.key,
    required double scale,
    this.alignment = Alignment.center,
    required super.child,
  }) : _transform = 'scale(${cssNum(scale)})';

  /// Creates a widget that mirrors [child] horizontally ([flipX]) and/or
  /// vertically ([flipY]).
  const Transform.flip({
    super.key,
    bool flipX = false,
    bool flipY = false,
    required super.child,
  }) : alignment = Alignment.center,
       _transform = 'scale(${flipX ? -1 : 1}, ${flipY ? -1 : 1})';

  /// Creates a widget that translates [child] by [offset].
  Transform.translate({super.key, required Offset offset, required super.child})
    : alignment = Alignment.center,
      _transform = 'translate(${cssPx(offset.dx)}, ${cssPx(offset.dy)})';

  /// Origin of the transform, relative to `child`'s size.
  final Alignment alignment;
  final String _transform;

  @override
  WrapData get wrapData => WrapData(
    css: {
      'transform': _transform,
      if (alignment != Alignment.center)
        'transform-origin': alignment.cssPosition,
    },
  );
}

/// Flutter's `ClipRRect`. Clips the child element itself (no wrapper node).
class ClipRRect extends ParentDataWrapper {
  /// Creates a widget that clips [child] to a rounded rectangle.
  const ClipRRect({
    super.key,
    this.borderRadius = BorderRadius.zero,
    this.clipBehavior = Clip.antiAlias,
    required super.child,
  });

  /// Corner radii of the clip.
  final BorderRadiusGeometry borderRadius;

  /// How to clip. Flutter default: `Clip.antiAlias`.
  final Clip clipBehavior;

  @override
  WrapData get wrapData =>
      WrapData(css: {...borderRadius.toCss(), 'overflow': clipBehavior.css});
}

/// Flutter's `ClipOval`.
class ClipOval extends ParentDataWrapper {
  /// Creates a widget that clips [child] to an oval/circle.
  const ClipOval({super.key, required super.child});

  @override
  WrapData get wrapData =>
      const WrapData(css: {'border-radius': '50%', 'overflow': 'hidden'});
}

/// Flutter's `Visibility`.
class Visibility extends ParentDataWrapper {
  /// Creates a widget that shows or hides [child].
  const Visibility({
    super.key,
    this.visible = true,
    this.maintainSize = false,
    required super.child,
  });

  /// Whether `child` is shown. When `false`, hides it per [maintainSize].
  final bool visible;

  /// When hidden, keep the layout space instead of collapsing it
  /// (`visibility: hidden`).
  final bool maintainSize;

  @override
  WrapData get wrapData => visible
      ? const WrapData()
      : WrapData(
          css: maintainSize
              ? const {'visibility': 'hidden'}
              : const {'display': 'none'},
          attributes: const {'aria-hidden': 'true'},
        );
}

/// Shows [child] only when the page runs without JavaScript: the fallback a
/// native-first page keeps for no JS (the submit button of a form whose controls
/// apply on their own with the engine), gone and out of the accessibility
/// tree when scripting is on.
///
/// ```dart
/// Form(formMethod: FormMethod.get, child: Row(children: [
///   DropdownButtonFormField<String>(name: 'device', …),
///   NoScript(child: FilledButton(buttonType: ButtonType.submit, child: Text('View'))),
/// ]))
/// ```
///
/// `// web:` no Flutter equivalent. The child's element is the one that
/// hides (`@media (scripting: enabled) { display: none }`, compiled on the
/// server, so the client generates no style); it stays in the HTML, unlike a
/// `<noscript>`, whose content the browser reads as text when scripting is on.
class NoScript extends ParentDataWrapper {
  /// Shows [child] only without scripting.
  const NoScript({super.key, required super.child});

  @override
  WrapData get wrapData => const WrapData(
    conditions: [
      ConditionalCss(CssCondition.media('(scripting: enabled)'), {
        'display': 'none',
      }),
    ],
  );
}

/// Flutter's `Offstage`.
class Offstage extends ParentDataWrapper {
  /// Creates a widget that hides [child] without removing it from the tree.
  const Offstage({super.key, this.offstage = true, required super.child});

  /// When `true`, hides the child (`display: none`).
  final bool offstage;

  @override
  WrapData get wrapData =>
      offstage ? const WrapData(css: {'display': 'none'}) : const WrapData();
}

// A heading's (`<h1>`…`<h6>`) UA margins, size and weight, reset under
// the element's own props, whatever its child is (a Text, a Row, a Link).
const _headingResetCss = <String, String>{
  'margin': '0',
  'font-size': 'inherit',
  'font-weight': 'inherit',
};

/// Flutter's `Semantics`, reduced to what maps onto ARIA.
class Semantics extends ParentDataWrapper {
  /// Creates a widget that attaches accessibility metadata to [child].
  const Semantics({
    super.key,
    this.role,
    this.headingLevel,
    this.label,
    this.button = false,
    this.header = false,
    this.link = false,
    this.image = false,
    this.hidden = false,
    this.enabled,
    this.selected,
    this.toggled,
    this.rowIndex,
    this.rowCount,
    this.columnIndex,
    this.columnCount,
    this.liveRegion = false,
    this.current,
    this.identifier,
    this.value,
    this.hint,
    this.checked,
    this.expanded,
    this.readOnly,
    this.obscured,
    this.focusable,
    this.tooltip,
    this.textField = false,
    this.slider = false,
    this.container = false,
    this.explicitChildNodes = false,
    this.excludeSemantics = false,
    this.sortKey,
    required super.child,
  });

  /// What [child] is (Flutter's `SemanticsRole`). On the web a role is
  /// the element's tag when HTML has one (`list` → `<ul>`, `navigation` →
  /// `<nav>`), else an ARIA `role`.
  final SemanticsRole? role;

  /// Flutter's `headingLevel` (1–6): [child] becomes `<h1>`…`<h6>`.
  final int? headingLevel;

  /// The accessible name announced by assistive technology (`aria-label`).
  final String? label;

  /// Flutter's `identifier`: a stable name for [child]. On the web it is
  /// the element's `id`, so an in-page link (`href="#contact"`) lands on it.
  final String? identifier;

  /// Announces `child` as a button. On the web a thor element becomes a
  /// native `<button type="button">` (keyboard and focus included); any
  /// other child gets `role="button"`.
  final bool button;

  /// Announces `child` as a heading (`role="heading"`).
  final bool header;

  /// Announces `child` as a link (`role="link"`).
  final bool link;

  /// Announces `child` as an image (`role="img"`).
  final bool image;

  /// Hides `child` from assistive technology (`aria-hidden`).
  final bool hidden;

  /// `false` → `aria-disabled` (still focusable, announced as unavailable).
  final bool? enabled;

  /// Whether [child] is selected: `aria-selected` on what ARIA lets be
  /// selected (a grid cell or row, a tab, an option). On a button
  /// ([button], or a `TextButton`/`IconButton`… child) it is `aria-pressed`
  /// instead (a two-state button: `aria-selected` isn't allowed on
  /// `role=button`). Null leaves it out (not selectable).
  final bool? selected;

  /// Whether [child] is on or off (Flutter's `toggled`): `aria-pressed` on
  /// a button (a toggle button), else a switch (`role="switch"` and
  /// `aria-checked`). Null leaves it out.
  final bool? toggled;

  /// Whether changes to [child]'s text are announced when they happen
  /// (`aria-live="polite"`), like Flutter's `liveRegion`: a status line, or
  /// the value under a selection that moves while the focus stays put.
  final bool liveRegion;

  /// `// web:` not in Flutter: which item of a set [child] is, as a screen
  /// reader says it (`aria-current`): the page in a breadcrumb or a menu, the
  /// step of a process, today in a calendar. Null leaves it out.
  final SemanticsCurrent? current;

  /// The current value announced for [child]: a slider's "50 percent"
  /// (`aria-valuetext`, which ARIA allows only on range roles: sliders,
  /// progress bars, spin buttons). Elsewhere it is read after the [hint]
  /// (`aria-description`).
  final String? value;

  /// What happens when [child] is used, read after its name
  /// (`aria-description`).
  final String? hint;

  /// Whether [child] is checked (`aria-checked`). Over a child with no
  /// role of its own it is a `role="checkbox"`.
  final bool? checked;

  /// Whether the content [child] controls is open (`aria-expanded`).
  final bool? expanded;

  /// Whether [child] shows a value the user can't edit (`aria-readonly`).
  final bool? readOnly;

  /// Whether [child] hides its text, like a password.
  ///
  /// `// web:` ARIA has no attribute for it: the browser hides a password
  /// from assistive technology only in `<input type="password">`, which
  /// `TextField(obscureText: true)` already is. Kept for the Flutter
  /// signature; it writes nothing.
  final bool? obscured;

  /// Whether the keyboard can focus [child]: `true` is `tabindex="0"`,
  /// `false` is `tabindex="-1"` (focusable by code, out of the tab order).
  final bool? focusable;

  /// A short text shown or announced on hover or focus (`title`).
  final String? tooltip;

  /// Announces [child] as a text field (`role="textbox"`).
  final bool textField;

  /// Announces [child] as a slider (`role="slider"`; its value is the
  /// [value] text, and `aria-valuenow` too when it is a number: give it
  /// one).
  final bool slider;

  /// Groups [child]'s content into one node (`role="group"` when [child]
  /// has no role of its own: never over a button or a list item).
  final bool container;

  /// Whether the children of [child] are separate nodes.
  ///
  /// `// web:` the accessibility tree always keeps one node per element;
  /// kept for the Flutter signature, it writes nothing.
  final bool explicitChildNodes;

  /// Replaces what [child]'s content says with this node alone (Flutter's
  /// `excludeSemantics`).
  ///
  /// `// web:` ARIA can't hide the children of a node and keep the node.
  /// What it has is roles whose children are presentational (`img`,
  /// `button`, `checkbox`, `slider`...): a node with no role of its own
  /// gets `role="img"` (when it has a [label]), so its [label] is all
  /// assistive technology reads. A child with a role of its own (a button)
  /// keeps it.
  final bool excludeSemantics;

  /// The order assistive technology reads [child] in among its siblings.
  ///
  /// `// web:` the reading order is the document order, which is also the
  /// visual one; a sort key doesn't change it. Kept for the Flutter
  /// signature; it writes nothing.
  final SemanticsSortKey? sortKey;

  /// `// web:` not in Flutter: the 1-based row of [child] in a table or
  /// grid that renders only some of its rows (`aria-rowindex`). A row that
  /// changes per item uses `row.attribute(AttributeName.ariaOf(AriaAttribute.rowindex), …)`.
  final int? rowIndex;

  /// `// web:` not in Flutter: the number of rows of a table or grid, when
  /// not all of them are in the page (`aria-rowcount`). A count that
  /// changes uses `WatchAttributes`.
  final int? rowCount;

  /// `// web:` not in Flutter: the 1-based column of a cell or header
  /// (`aria-colindex`), when some columns are hidden or scrolled out.
  final int? columnIndex;

  /// `// web:` not in Flutter: the number of columns of a table or grid,
  /// when not all of them are shown (`aria-colcount`).
  final int? columnCount;

  @override
  WrapData get wrapData {
    assert(
      headingLevel == null || (headingLevel! >= 1 && headingLevel! <= 6),
      'Semantics(headingLevel: $headingLevel): use 1 to 6.',
    );
    final tag = headingLevel != null
        ? 'h$headingLevel'
        : button
        ? 'button'
        : role?.tag;
    // A button's state is `aria-pressed`: `aria-selected` is for cells,
    // rows, tabs and options (WAI-ARIA), which aren't buttons.
    final onButton = button || child is SemanticsButton;
    // A node with no tag or role of its own may get one from the flags
    // below; the first that applies wins.
    // Never over a child that has one (a button, a list item, a field):
    // ARIA says not to override native semantics.
    final bareRole = tag != null || role?.aria != null || childHasOwnRole(child)
        ? null
        : checked != null
        ? 'checkbox'
        : slider
        ? 'slider'
        : textField
        ? 'textbox'
        : excludeSemantics && label != null
        ? 'img'
        : container
        ? 'group'
        : null;
    final nativeCheck = childIsNativeCheck(child);
    // `aria-valuetext` is only allowed on range roles; elsewhere the value
    // is read as part of the description.
    final isRange =
        bareRole == 'slider' ||
        const {
          'slider',
          'progressbar',
          'spinbutton',
          'scrollbar',
        }.contains(role?.aria) ||
        childIsNativeRange(child);
    final description = isRange || value == null
        ? hint
        : hint == null
        ? value
        : '$hint. $value';
    return WrapData(
      tag: tag,
      baseCss: headingLevel != null
          // A heading level is semantics only (as in Flutter): the
          // browser's heading margins, size and weight don't leak in, also
          // when the child isn't a Text (a Row, a Column, a Link).
          ? _headingResetCss
          : role == SemanticsRole.list || role == SemanticsRole.orderedList
          ? listResetCss
          : button
          ? buttonResetCss
          : const {},
      attributes: {
        if (tag == null && role?.aria != null) 'role': role!.aria!,
        'aria-label': ?label,
        // web: Flutter web writes `identifier` as `flt-semantics-identifier`
        // (for tests); here it is the element's `id`, the one thing an
        // in-page `#anchor` can land on. An element holds one: another id
        // on it is THOR-R022.
        'id': ?identifier,
        if (button) 'type': 'button',
        if (isRange) 'aria-valuetext': ?value,
        // web: a slider role requires `aria-valuenow`: a numeric value is it.
        if (bareRole == 'slider' && double.tryParse(value ?? '') != null)
          'aria-valuenow': value!,
        'aria-description': ?description,
        'title': ?tooltip,
        if (bareRole != null &&
            !header &&
            !link &&
            !image &&
            !(toggled != null && !onButton))
          'role': bareRole,
        // A native checkbox, switch or radio exposes its own state: a
        // static attribute would go stale when the user toggles it.
        if (checked != null && !nativeCheck) 'aria-checked': '$checked',
        if (expanded != null) 'aria-expanded': '$expanded',
        if (readOnly != null) 'aria-readonly': '$readOnly',
        if (focusable != null) 'tabindex': focusable! ? '0' : '-1',
        if (header) 'role': 'heading',
        if (link) 'role': 'link',
        if (image) 'role': 'img',
        if (hidden) 'aria-hidden': 'true',
        if (enabled == false) 'aria-disabled': 'true',
        if (selected != null)
          (onButton ? 'aria-pressed' : 'aria-selected'): '$selected',
        if (toggled != null) ...{
          if (onButton)
            'aria-pressed': '$toggled'
          else ...{
            if (tag == null && role?.aria == null && !childHasOwnRole(child))
              'role': 'switch',
            if (!nativeCheck) 'aria-checked': '$toggled',
          },
        },
        if (rowIndex != null) 'aria-rowindex': '$rowIndex',
        if (rowCount != null) 'aria-rowcount': '$rowCount',
        if (columnIndex != null) 'aria-colindex': '$columnIndex',
        if (columnCount != null) 'aria-colcount': '$columnCount',
        if (liveRegion) 'aria-live': 'polite',
        'aria-current': ?current?.value,
      },
    );
  }
}

/// `// web:` not in Flutter: the values of `aria-current` ([Semantics.current]).
enum SemanticsCurrent {
  /// The page the user is on (`aria-current="page"`): the last item of a
  /// breadcrumb, the link of a menu that points here.
  page('page'),

  /// The step of a process (`aria-current="step"`).
  step('step'),

  /// The place of a flow (`aria-current="location"`).
  location('location'),

  /// The current date (`aria-current="date"`).
  date('date'),

  /// The current time (`aria-current="time"`).
  time('time'),

  /// The current item of a set that is none of the above
  /// (`aria-current="true"`).
  item('true');

  const SemanticsCurrent(this.value);

  /// The attribute's value.
  final String value;
}

/// Flutter's `SemanticsSortKey`: the order a node is read in.
///
/// `// web:` the browser reads in document order; see [Semantics.sortKey].
abstract class SemanticsSortKey {
  /// Creates a sort key.
  const SemanticsSortKey({this.name});

  /// Identifies the sort key for debugging.
  final String? name;
}

/// Flutter's `OrdinalSortKey`: nodes are read by increasing [order].
class OrdinalSortKey extends SemanticsSortKey {
  /// Creates a sort key at position [order].
  const OrdinalSortKey(this.order, {super.name});

  /// The position of the node.
  final double order;
}

/// A widget whose element is a `<button>` (the Material buttons,
/// `IconButton`): [Semantics] writes its `selected`/`toggled` as
/// `aria-pressed`. Not exported.
abstract interface class SemanticsButton {}

/// Flutter's `SemanticsRole`: what a widget is for assistive technology.
/// On the web most roles are HTML elements; the rest are ARIA roles.
///
/// A role is put on [Semantics]' child, whatever it is: a role whose native
/// element can't hold other content (`<progress>`, `<img>`, `<select>`,
/// `<input>`) is an ARIA role here. The native control is a widget of its
/// own: `LinearProgressIndicator` (`<progress>`), `Image` (`<img>`),
/// `ListBox` (`<select size>`), `Slider` (`<input type=range>`).
enum SemanticsRole {
  /// No role (Flutter's default): nothing is written, [Semantics]' other
  /// properties still apply.
  none(),

  /// A list (`<ul>`, without bullets or indent).
  ///
  /// `// web:` the marker and the indent of a prose list are
  /// `Styled(style: StyleProps(listStyleType: ListStyleType.disc, padding: …))`
  /// around it.
  list(tag: 'ul'),

  /// `// web:` not in Flutter: a list whose order matters, like the steps of a
  /// process (`<ol>`, without numbers or indent: see [list]).
  orderedList(tag: 'ol'),

  /// An item of a [list] (`<li>`).
  listItem(tag: 'li'),

  /// The page's main content (`<main>`).
  main(tag: 'main'),

  /// Navigation links (`<nav>`).
  navigation(tag: 'nav'),

  /// Content aside from the main one (`<aside>`).
  complementary(tag: 'aside'),

  /// Information about the page: the footer (`<footer>`).
  contentInfo(tag: 'footer'),

  /// A labelled part of the page (`<section>`).
  region(tag: 'section'),

  /// A form (`<form>`).
  form(tag: 'form'),

  /// A table (`<table>`).
  table(tag: 'table'),

  /// `// web:` not in Flutter: a row of controls, like the actions of an
  /// editor (`role="toolbar"`; name it with `Semantics(label:)`).
  toolbar(aria: 'toolbar'),

  /// A row of a table or grid (`role="row"`: its cells need not be a
  /// `<table>`'s, like a virtualized grid's).
  row(aria: 'row'),

  /// A cell of a table (`role="cell"`).
  cell(aria: 'cell'),

  /// The header of a column (`role="columnheader"`).
  columnHeader(aria: 'columnheader'),

  /// `// web:` not in Flutter: an interactive table whose cells are
  /// navigated with the arrow keys, like a spreadsheet (`role="grid"`).
  /// Its rows are [row]s of [gridCell]s, [rowHeader]s and [columnHeader]s.
  grid(aria: 'grid'),

  /// `// web:` not in Flutter: a cell of a [grid] (`role="gridcell"`).
  gridCell(aria: 'gridcell'),

  /// `// web:` not in Flutter: the cell that names its row
  /// (`role="rowheader"`), like a record's primary field.
  rowHeader(aria: 'rowheader'),

  /// A handle that resizes or moves something by dragging, like a column
  /// edge or a splitter (`role="separator"`; focusable when it also takes
  /// the arrow keys).
  dragHandle(aria: 'separator'),

  /// A status message, announced politely (`role="status"`).
  status(aria: 'status'),

  /// An important message, announced at once (`role="alert"`).
  alert(aria: 'alert'),

  /// `// web:` not in Flutter: an aside the reader may skip, a callout
  /// (`role="note"`; with a `label`, its name).
  note(aria: 'note'),

  /// A group of radio buttons (`role="radiogroup"`).
  radioGroup(aria: 'radiogroup'),

  /// A tooltip (`role="tooltip"`).
  tooltip(aria: 'tooltip'),

  /// A progress bar with a value (`role="progressbar"`; give it the
  /// value with `Semantics(value:)`, read as `aria-valuetext`).
  progressBar(aria: 'progressbar'),

  /// A spinner that says the app is busy, with no value (Flutter's
  /// `CircularProgressIndicator`): an indeterminate `role="progressbar"`.
  ///
  /// `// web:` ARIA has no spinner role; a progress bar without a value is
  /// the busy indicator (what `<progress>` without `value` is).
  loadingSpinner(aria: 'progressbar'),

  /// A control that steps a value up or down, like a calendar's next and
  /// previous month (`role="spinbutton"`).
  spinButton(aria: 'spinbutton'),

  /// A field that records a keyboard shortcut.
  ///
  /// `// web:` ARIA has no role for it (Flutter web writes none either):
  /// nothing is written. A key shown in text is [keyboardKey] (`<kbd>`).
  hotKey(),

  /// `// web:` not in Flutter: a slider (`role="slider"`). The native one is
  /// `Slider` (`<input type=range>`).
  slider(aria: 'slider'),

  /// `// web:` not in Flutter: a list of options to choose from
  /// (`role="listbox"`, its rows [option]s). The native one is `ListBox`
  /// (`<select size>`).
  listBox(aria: 'listbox'),

  /// `// web:` not in Flutter (its `Semantics(image: true)`): an image
  /// (`role="img"`).
  image(aria: 'img'),

  /// A tab of a [tabBar] (`role="tab"`).
  tab(aria: 'tab'),

  /// A row of [tab]s (`role="tablist"`).
  tabBar(aria: 'tablist'),

  /// The content a [tab] shows (`role="tabpanel"`).
  tabPanel(aria: 'tabpanel'),

  /// A dialog window (`role="dialog"`).
  dialog(aria: 'dialog'),

  /// A dialog that demands an answer (`role="alertdialog"`).
  alertDialog(aria: 'alertdialog'),

  /// A menu of commands (`role="menu"`).
  menu(aria: 'menu'),

  /// A bar of menus (`role="menubar"`).
  menuBar(aria: 'menubar'),

  /// A command of a [menu] (`role="menuitem"`).
  menuItem(aria: 'menuitem'),

  /// A command of a [menu] that is on or off (`role="menuitemcheckbox"`;
  /// its state is `Semantics(checked:)`).
  menuItemCheckbox(aria: 'menuitemcheckbox'),

  /// One of a group of commands of a [menu] of which one is on
  /// (`role="menuitemradio"`; its state is `Semantics(checked:)`).
  menuItemRadio(aria: 'menuitemradio'),

  /// A text field with a list of values (`role="combobox"`).
  comboBox(aria: 'combobox'),

  /// `// web:` not in Flutter: a search field (`role="searchbox"`).
  searchBox(aria: 'searchbox'),

  /// `// web:` not in Flutter (its `Semantics(checked:)`): a checkbox
  /// (`role="checkbox"`).
  checkbox(aria: 'checkbox'),

  /// `// web:` not in Flutter: a radio button (`role="radio"`).
  radio(aria: 'radio'),

  /// `// web:` not in Flutter (its `Semantics(toggled:)`): a switch
  /// (`role="switch"`).
  switchRole(aria: 'switch'),

  /// `// web:` not in Flutter: a row of the options panel of an
  /// `Autocomplete` (`role="option"`), for a view built with
  /// `RawAutocomplete(optionsViewBuilder:)`.
  option(aria: 'option'),

  /// `// web:` not in Flutter: a self-contained piece (`<article>`): a card,
  /// a post.
  article(tag: 'article'),

  /// `// web:` not in Flutter: a paragraph of text (`<p>`).
  paragraph(tag: 'p'),

  /// `// web:` not in Flutter: the introduction of the page or of a piece
  /// (`<header>`).
  header(tag: 'header'),

  /// `// web:` not in Flutter: text whose spaces and line breaks are kept,
  /// like code (`<pre>`).
  preformatted(tag: 'pre'),

  /// `// web:` not in Flutter: a key of the keyboard (`<kbd>`).
  keyboardKey(tag: 'kbd'),

  /// `// web:` not in Flutter: self-contained content with a caption, like
  /// an image or a code sample (`<figure>`).
  figure(tag: 'figure'),

  /// `// web:` not in Flutter: the caption of a [figure] (`<figcaption>`).
  figureCaption(tag: 'figcaption'),

  /// `// web:` not in Flutter: text of strong importance, in bold
  /// (`<strong>`).
  strong(tag: 'strong'),

  /// `// web:` not in Flutter: text stressed, in italics (`<em>`).
  emphasis(tag: 'em'),

  /// `// web:` not in Flutter: a quotation from another source
  /// (`<blockquote>`).
  blockquote(tag: 'blockquote'),

  /// `// web:` not in Flutter: an inline label of a form control
  /// (`<label>`).
  label(tag: 'label');

  const SemanticsRole({this.tag, this.aria});

  /// The HTML element for this role, when there is one.
  final String? tag;

  /// The ARIA role otherwise.
  final String? aria;
}

/// Flutter's `ExcludeSemantics`: hides decorative content (image
/// placeholders, duplicated labels) from assistive technology.
class ExcludeSemantics extends ParentDataWrapper {
  /// Creates a widget that excludes [child] from the accessibility tree.
  const ExcludeSemantics({
    super.key,
    this.excluding = true,
    required super.child,
  });

  /// When `true`, hides `child` from assistive technology.
  final bool excluding;

  @override
  WrapData get wrapData => excluding
      ? const WrapData(attributes: {'aria-hidden': 'true'})
      : const WrapData();
}

/// Flutter's `MergeSemantics`: [child]'s content is one node for assistive
/// technology.
class MergeSemantics extends ParentDataWrapper {
  /// Creates a widget that merges the semantics of [child] into one node.
  const MergeSemantics({super.key, required super.child});

  // web: the accessibility tree is made from the elements, and a browser
  // already reads the text of an element as a whole when its name is taken
  // from its content (a button, a link, a list item): nothing to add.
  @override
  WrapData get wrapData => const WrapData();
}

/// Flutter's `BlockSemantics`: assistive technology ignores what is behind
/// [child] (a modal route).
class BlockSemantics extends ParentDataWrapper {
  /// Creates a widget that blocks the semantics behind [child].
  const BlockSemantics({super.key, this.blocking = true, required super.child});

  /// When `false`, nothing is blocked.
  final bool blocking;

  // web: `aria-modal` tells assistive technology to treat the rest of the
  // page as unavailable. For the sighted and the keyboard, `<dialog>` with
  // `showModal()` (the `Dialog` widgets) makes the rest inert by itself.
  @override
  WrapData get wrapData => blocking
      ? const WrapData(attributes: {'aria-modal': 'true'})
      : const WrapData();
}

/// Flutter's `IgnorePointer`: [child] doesn't take pointer events, and
/// neither does its content; the events go through to what is behind.
class IgnorePointer extends ParentDataWrapper {
  /// Creates a widget that is invisible to pointers when [ignoring].
  const IgnorePointer({
    super.key,
    this.ignoring = true,
    this.ignoringSemantics,
    required super.child,
  });

  /// Whether pointers pass through [child].
  final bool ignoring;

  /// Whether the semantics of [child] are dropped too.
  ///
  /// `// web:` null leaves the semantics (Flutter defaults it to
  /// [ignoring]): `pointer-events: none` is only pointer input, and the
  /// keyboard still reaches [child]. `true` writes `aria-hidden`.
  final bool? ignoringSemantics;

  @override
  WrapData get wrapData => ignoring
      ? WrapData(
          css: const {'pointer-events': 'none'},
          attributes: ignoringSemantics == true
              ? const {'aria-hidden': 'true'}
              : const {},
        )
      : const WrapData();
}

/// Flutter's `AbsorbPointer`: [child] takes pointer events away from what
/// is behind it without answering them.
class AbsorbPointer extends ParentDataWrapper {
  /// Creates a widget that absorbs pointer events when [absorbing].
  const AbsorbPointer({
    super.key,
    this.absorbing = true,
    this.ignoringSemantics,
    required super.child,
  });

  /// Whether the pointer events are absorbed.
  final bool absorbing;

  /// Whether the semantics of [child] are dropped too.
  ///
  /// `// web:` an `inert` subtree is out of the accessibility tree
  /// already, so this changes nothing.
  final bool? ignoringSemantics;

  // web: `inert` is the native answer: [child] and its content take no
  // pointer events and no focus, and assistive technology skips them. A
  // wrapper around a node that keeps pointing at itself is not expressible.
  @override
  WrapData get wrapData =>
      absorbing ? const WrapData(attributes: {'inert': ''}) : const WrapData();
}

/// `// web:` not in Flutter (it has no attributes): sets attributes on the
/// element of [child], with no element of its own.
///
/// ```dart
/// ElementAttributes(
///   HtmlAttributes(data: {'track': 'cta', 'track-id': 'hero'}),
///   child: Semantics(role: SemanticsRole.listItem, child: Link(…)),
/// )
/// ```
///
/// For analytics markers, test hooks and `aria-*` that [Semantics] does not
/// cover. It fuses into the element, so a `data-*` on a list item keeps the
/// `<li>` (a wrapper element would break the list). An attribute the element
/// already has is replaced by this one; `class`, `style` and event handlers
/// are refused by [HtmlAttributes]. For values that change on the page use
/// `WatchAttributes`.
class ElementAttributes extends ParentDataWrapper {
  /// Puts [attributes] on the element of [child].
  const ElementAttributes(this.attributes, {super.key, required super.child});

  /// The attributes to write.
  final HtmlAttributes attributes;

  @override
  WrapData get wrapData => WrapData(attributes: attributes);
}
