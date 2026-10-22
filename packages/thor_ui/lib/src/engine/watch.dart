import 'package:thor_engine/thor_engine.dart';
import 'package:thor_server/thor_server.dart' show ThorDev;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../foundation/bound_lengths.dart'
    show
        boundLengthName,
        boundLengthPrefix,
        registerBoundLength,
        rowLengthPrefix;
import '../foundation/builder_errors.dart';
import '../foundation/child_rules.dart';
import '../foundation/element.dart' show thorElement;
import '../foundation/errors.dart';
import '../foundation/html_attributes.dart';
import '../foundation/layout_hint.dart';
import '../foundation/lazy_layout.dart';
import '../foundation/parent_data.dart';
import '../foundation/row_bind.dart';
import '../foundation/transparent.dart';
import '../widgets/basic.dart' show SizedBox;
import '../widgets/flex.dart' show Column;
import '../widgets/navigation.dart' show Link;
import '../widgets/text.dart' show Text;
import 'variants.dart';

/// A member of a [ThorState] resolved from a widget argument.
typedef _Resolved = ({ThorState state, ThorMember member, Object? arg});

_Resolved _resolve(Object source, String what) {
  Function? function;
  Object? arg;
  if (source is StateSignal) {
    function = source.call;
  } else if (source is Function) {
    final bound = BoundCall.of(source);
    function = bound?.function ?? source;
    arg = bound?.arg;
  }
  final found = function == null ? null : ThorState.resolve(function);
  if (found == null) {
    throw ArgumentError(
      thorError(
        'THOR-S001',
        '$what needs a field or method of a ThorState (e.g. counter.count or '
            'counter.label), not a closure: the browser finds it by its name.',
      ),
    );
  }
  return (state: found.$1, member: found.$2, arg: arg);
}

String _memberId(_Resolved r) => '${r.state.idPrefix}.${r.member.name}';

String _bindingIdOf(_Resolved r) =>
    bindingId(_memberId(r), r.arg == null ? null : encodeArg(r.arg));

/// Resolves [source], a row method (`lineName`, or
/// `cellLabel.withArg(3)`), and checks it works on list items.
_Resolved _itemMethod(Object source, String what) {
  final r = _resolve(source, what);
  final ok = r.arg == null
      ? r.member.callWithItem != null
      : r.member.callWithArgAndItem != null;
  if (!ok) {
    throw ArgumentError(
      thorError(
        'THOR-S002',
        '$what(${_memberId(r)}) needs a method of the state taking the item '
            '(`String lineName(Line line)`), or a fixed argument and then the '
            'item (`String cellLabel(int column, Line line)` with `withArg`).',
      ),
    );
  }
  return r;
}

/// The value of item method [r] for [item] (through the page's encoding of
/// the fixed argument, like the browser).
Object? _itemValue(_Resolved r, Object? item) =>
    r.member.callItem(item, r.arg == null ? null : encodeArg(r.arg));

/// The markers that bind DOM events of an element to [ThorState] methods.
///
/// [handlers] maps event types (`click`, `change`, `input`, `submit`) to
/// the widget's callbacks. Callbacks that are methods of a `ThorState`
/// (`counter.inc`, `cart.add.withArg(3)`) become `data-t-on`/`data-tx`
/// attributes; anything else (a closure in an island) is left alone. [arg]
/// is the argument for methods whose value comes from the widget itself
/// (a chip's next state, a menu item's value).
Map<String, String> engineAttributes(
  Map<String, Function?> handlers, {
  Object? arg,
}) {
  final on = <String, String>{};
  String? value = arg == null ? null : encodeArg(arg);
  var withControlValue = false;
  for (final e in handlers.entries) {
    final callback = e.value;
    if (callback == null) continue;
    final bound = BoundCall.of(callback);
    final found = ThorState.resolve(bound?.function ?? callback);
    if (found == null) continue;
    on[e.key] = '${found.$1.idPrefix}.${found.$2.name}';
    if (bound == null) continue;
    final fixed = encodeFixedArg(bound.arg, splits: found.$2.arity >= 2);
    if (bound.arg is MultiArgs) {
      // `withArgs`: every argument is fixed (a control's value is not one).
      value = fixed;
    } else if (found.$2.arity >= 2) {
      // The second argument: the widget's own value, or the control's.
      if (arg != null) {
        value = bindingId(fixed, encodeArg(arg));
      } else {
        value = fixed;
        withControlValue = true;
      }
    } else {
      value = fixed;
    }
  }
  if (on.isEmpty) return const {};
  return {
    onAttr: encodeOn(on),
    argAttr: ?value,
    if (withControlValue) argWithValueAttr: '',
  };
}

/// The part of a page that changes in the browser, bound to a field or a
/// method of a [ThorState]:
///
/// ```dart
/// Watch(counter.label)                       // a text: source returns a String
/// Watch(counter.isZero, builder: (zero) =>   // states: bool, enum, or int with
///     TextButton(onPressed: zero ? null : counter.reset, child: …))  // count
/// Watch.field(toast.visible, builder: (visible) =>   // a `state(false)` field
///     SnackBar(visible: visible, content: …))        // (visible is a bool)
/// Watch.list(cart.lines,                     // a list: source returns a List
///     itemKey: cart.lineKey,                 // row.key has its type
///     each: (row) => Row(children: [row.text(cart.lineName), …]))
/// ```
///
/// The server renders the current value (every state, for a finite
/// source); the browser only updates what changed. [builder] and the rows of [Watch.list]
/// run on the server only, so they can build any widget, but what they show
/// that changes must come from the state (the source, `row.text`).
class Watch<T> extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn, LayoutHint, HeightHint {
  /// Watches [source]: a method torn off from a ThorState (`counter.label`,
  /// `cart.isSelected.withArg(i)`) or a reactive field (`counter.count`).
  /// With a [builder] use [Watch.field] for a field: passed here as is, the
  /// compiler infers `Object?` for the builder's value (the analyzer
  /// doesn't; the `watch_field_with_builder` lint catches it), unless the
  /// builder names the type (`(bool visible) => …`).
  const Watch(this.source, {super.key, this.builder, this.count, this.style})
    : each = null,
      itemKey = null,
      container = null,
      templateKey = null,
      itemExtent = null,
      lazyLayout = false,
      virtual = false,
      treeChildren = null,
      eachNode = null;

  /// Watches a `state(...)` field of a [ThorState] directly, with or without
  /// a [builder]:
  ///
  /// ```dart
  /// Watch.field(toast.visible, builder: (visible) =>
  ///     SnackBar(visible: visible, content: …))
  /// ```
  ///
  /// The same as `Watch(toast.visible.call, …)`, but the builder's value has
  /// the field's type (a `bool` here) with no annotation: Dart has no
  /// overloading, and a field passed to [Watch.new] loses its type argument.
  /// A `bool` or an enum field has a copy of the builder per value; an `int`
  /// needs [count]; a `String` is a text; a nullable field can't be rebuilt
  /// (null has no copy): THOR-S003 says which and the fix.
  ///
  /// `// web:` Flutter's `ValueListenableBuilder` for a field is the same
  /// widget with Flutter's spelling; this is the short one.
  Watch.field(
    StateSignal<T> field, {
    Key? key,
    Widget Function(T value)? builder,
    int? count,
    TextStyle? style,
  }) : this(field.call, key: key, builder: builder, count: count, style: style);

  /// A list with typed rows: each `row` is a [WatchRow] whose `key` has the
  /// type [itemKey] returns (`int` for `int idOf(Order o)`), and whose
  /// methods take the item type, so a row can bind `orders.remove.withArg(row.key)`
  /// or `archive.withArg(row.key)` (a page action) with no conversion.
  ///
  /// ```dart
  /// Watch.list(
  ///   orders.rows.call,
  ///   itemKey: orders.idOf,                      // int idOf(Order o)
  ///   each: (row) => Row(children: [
  ///     row.text(orders.customerOf),
  ///     IconButton(onPressed: orders.remove.withArg(row.key), icon: …),
  ///   ]),
  /// )
  /// ```
  ///
  /// The key is a `String` or an `int` (THOR-S030 otherwise): the browser
  /// writes it into the rows as text.
  ///
  /// [itemExtent] is every row's height, as in Flutter's `ListView.itemExtent`.
  /// With [lazyLayout] the browser skips the style, layout and paint of the
  /// rows off screen (`content-visibility: auto`, CSS the server precompiles:
  /// no JS; the rows stay in the page and Ctrl+F finds them), which cuts the
  /// relayout and first-paint work of long lists.
  /// `// web:` it is off by default: Chrome leaves the skipped rows out of
  /// the accessibility tree until they near the viewport (a screen reader got
  /// 56 of 700 rows), and it clips what a row paints outside its box (a
  /// shadow, a focus ring). `// web:` Flutter's
  /// `ListView.builder` reads the item by its index; a row here has its key
  /// because the browser adds, moves and removes rows by it.
  static Watch<List<I>> list<I, K extends Object>(
    List<I> Function() source, {
    Key? key,
    required K Function(I item) itemKey,
    required Widget Function(WatchRow<I, K> row) each,
    Widget Function(List<Widget> rows)? container,
    double? itemExtent,
    bool lazyLayout = false,
    bool virtual = false,
  }) {
    if (virtual && itemExtent == null) {
      throw ArgumentError(
        thorError(
          'THOR-S040',
          'Watch.list(virtual: true) needs itemExtent: the browser finds the '
              'visible rows by arithmetic over the rows\' fixed height. Fix: '
              'give the extent of a row (`itemExtent: 48`).',
        ),
      );
    }
    final placeholder = _templateKeyOf<K>('Watch.list');
    return Watch<List<I>>._typed(
      source,
      key: key,
      itemKey: itemKey,
      container: container,
      templateKey: placeholder,
      itemExtent: itemExtent,
      lazyLayout: lazyLayout,
      virtual: virtual,
      each: (WatchItem row) => each(WatchRow<I, K>._(row, row._rawKey as K)),
    );
  }

  /// A tree with typed rows: [source] gives the top rows, [children] (a
  /// method of the state, `List<Node> childrenOf(Node n)`) the rows under
  /// each one, and [each] builds a row with the place where its children go
  /// (`children`, a [Column] of rows built by [each] again, at any depth):
  ///
  /// ```dart
  /// Watch.tree(
  ///   editor.roots,                        // List<Node> roots()
  ///   itemKey: editor.idOf,                // String idOf(Node n)
  ///   children: editor.childrenOf,         // List<Node> childrenOf(Node n)
  ///   each: (row, children) => ExpansionTile(
  ///     title: row.text(editor.labelOf),
  ///     children: [children],
  ///   ),
  /// )
  /// ```
  ///
  /// The server draws the whole tree as it is now; the browser keeps every
  /// level in step with the items (rows added, moved and removed by key,
  /// like [Watch.list]), so a tree that arrives later (a `query` the page
  /// asks for when a panel opens) draws itself with no reload. A row's
  /// `<details>` stays as the visitor left it while its key stays.
  ///
  /// Keys must be unique in the whole tree (a `withArg(row.key)` callback
  /// names one node). The row template is one: the browser clones it for a
  /// row at any depth, so the page carries no copy per level.
  ///
  /// `// web:` Flutter's `TreeSliver` takes a tree of `TreeSliverNode`s and
  /// lays it out flat in Dart; here each level is a real child of its row
  /// (a `<details>` holds its children, with no JS to open it), and the
  /// rows come from the state's items, like [Watch.list]. No `virtual` or
  /// `lazyLayout` yet.
  static Watch<List<I>> tree<I, K extends Object>(
    List<I> Function() source, {
    Key? key,
    required K Function(I item) itemKey,
    required List<I> Function(I item) children,
    required Widget Function(WatchRow<I, K> row, Widget children) each,
  }) {
    return Watch<List<I>>._typed(
      source,
      key: key,
      itemKey: itemKey,
      container: null,
      templateKey: _templateKeyOf<K>('Watch.tree'),
      treeChildren: children,
      each: null,
      eachNode: (WatchItem row, Widget kids) =>
          each(WatchRow<I, K>._(row, row._rawKey as K), kids),
    );
  }

  /// What the row template has in place of a `K` key (`row.key`).
  static Object _templateKeyOf<K>(String what) {
    if (K == int) return templateIntKey;
    if (K == String) return keyToken;
    throw ArgumentError(
      thorError(
        'THOR-S030',
        '$what(itemKey: …) returns a $K: a row key is a String or an '
            'int (the browser writes it into the rows as text). Fix: '
            'return the id (`int idOf(Order o) => o.id`) or its text '
            '(`String slugOf(Order o) => o.slug`).',
      ),
    );
  }

  const Watch._typed(
    this.source, {
    super.key,
    required this.each,
    required this.itemKey,
    required this.container,
    required this.templateKey,
    this.itemExtent,
    this.lazyLayout = false,
    this.virtual = false,
    this.treeChildren,
    this.eachNode,
  }) : builder = null,
       count = null,
       style = null;

  /// The placeholder a typed list's template has for `row.key`.
  final Object? templateKey;

  /// The main-axis extent of every row of a [Watch.list] (see there).
  final double? itemExtent;

  /// Whether the rows of a [Watch.list] skip off-screen layout.
  final bool lazyLayout;

  /// Whether a [Watch.list] keeps only the rows near the viewport in the page.
  final bool virtual;

  /// The method or field whose value this part shows.
  final T Function() source;

  /// Builds the part for a value: for a text, a [Text] (default: plain
  /// `Text(value)`); for states, one widget per value.
  final Widget Function(T value)? builder;

  /// Builds one row of a list source.
  final Widget Function(WatchItem row)? each;

  /// The method of the state that gives an item's children ([Watch.tree]).
  final Function? treeChildren;

  /// Builds one row of a tree with the place of its children ([Watch.tree]).
  final Widget Function(WatchItem row, Widget children)? eachNode;

  /// A method of the state giving each item's stable key (lists).
  final Function? itemKey;

  /// Wraps the rows of a list (default: a `Column`).
  final Widget Function(List<Widget> rows)? container;

  /// Number of states of an `int` source (values `0 … count-1`).
  final int? count;

  /// Style of a text source without [builder].
  final TextStyle? style;

  Object? _value(_Resolved r) => untracked(source);

  List<Object?> _values(_Resolved r) {
    final known = r.member.variants;
    if (known != null) return known;
    if (count != null) return List<Object?>.generate(count!, (i) => i);
    final id = _memberId(r);
    final value = _value(r);
    final nullable = '$T'.endsWith('?');
    final why = nullable
        ? 'a $T can be null, which has no copy to show'
        : value is int
        ? 'an int has unbounded values'
        : 'a $T has no finite set of values';
    final fix = nullable
        ? 'make it non-null (`state(false)`, or an enum with a `none` case), '
              'or watch a method that returns a non-null bool or enum '
              '(`bool shown() => flag.value ?? false`)'
        : value is int
        ? '`count: n` gives the values 0 … n - 1 (`Watch.field($id, count: '
              'n, builder: …)`), or watch a method returning a bool or enum'
        : 'a text that changes is `Watch` with no builder, a list is '
              '`each:`, a structure that changes is a bool or an enum '
              '(a method `bool isX() => …`)';
    throw ArgumentError(
      thorError(
        'THOR-S003',
        'Watch($id, builder: …) can\'t rebuild in the browser: the server '
            'renders one copy of the builder per value, and $why. Fix: $fix.',
      ),
    );
  }

  Widget _current() {
    final r = _resolve(source, 'Watch');
    final v = _value(r);
    if (each != null || v is List || v is String || builder == null) {
      return builder == null
          ? Text('${v ?? ''}', style: style)
          : builder!(v as T);
    }
    // A container asks its child whether it fills the width before the
    // build: a source the browser can't rebuild fails here, with its
    // THOR-S003, not inside the builder given a value it can't take (a
    // `v!` on a null field).
    _values(r);
    return builder!(v as T);
  }

  @override
  bool get fillsWidth => layoutFillsWidth(_current());

  @override
  bool get fillsHeight => layoutFillsHeight(_current());

  @override
  Widget build(BuildContext context) {
    final r = _resolve(source, 'Watch');
    final id = _bindingIdOf(r);
    final value = _value(r);

    if (treeChildren != null) return _tree(id, value! as List<Object?>);

    if (each != null) {
      final key = _resolve(itemKey!, 'itemKey');
      final items = value! as List<Object?>;
      // `// web:` `lazyLayout` skips the layout and paint of the rows off
      // screen (`content-visibility: auto`, plain CSS on the row's class,
      // the template's too, so the rows the browser adds get it).
      final rowCss = <String, String>{
        if (itemExtent != null) 'height': cssPx(itemExtent!),
        ...lazyLayoutCss(lazyLayout, itemExtent ?? lazyRowEstimate),
      };
      final rows = [
        for (final item in items)
          () {
            final raw = key.member.callWithItem!(item);
            final k = '$raw';
            if (templateKey != null && raw == templateKey) {
              throw StateError(
                thorError(
                  'THOR-S030',
                  'Watch.list: a row\'s key is `$k`, the value the row '
                      'template stands in for it with. Use another key.',
                ),
              );
            }
            final row = WatchItem._(item, k, raw);
            final child = each!(row);
            return RowWrapWith(
              WrapData(attributes: {itemKeyAttr: k}, css: rowCss),
              row._lengths,
              child: child,
            );
          }(),
      ];
      final wrap = container ?? (rows) => Column(children: rows);
      final built = wrap([
        ...rows,
        () {
          final row = WatchItem._template(templateKey);
          final child = each!(row);
          return Widget.element(
            tag: 'template',
            attributes: {listTemplateAttr: id},
            children: [
              RowWrapWith(WrapData(css: rowCss), row._lengths, child: child),
            ],
          );
        }(),
      ]);
      return WrapWith(
        WrapData(
          attributes: {
            listAttr: id,
            listKeyAttr: _memberId(key),
            if (virtual)
              listVirtualAttr: itemExtent! == itemExtent!.roundToDouble()
                  ? '${itemExtent!.round()}'
                  : '$itemExtent',
          },
        ),
        // A container with several roots (a `ResponsiveLayout` with a list
        // per breakpoint) gets the mark on a box of its own; the engine
        // finds each copy's rows by their template.
        child: drawsSeveralRoots(built) ? _StatesBox(built) : built,
      );
    }

    if (value is String || builder == null) {
      final text = builder == null
          ? Text('${value ?? ''}', style: style)
          : builder!(value as T);
      // web: the value changes in the browser, so a `\n` may arrive in a
      // text the server drew in one line (a log, code): a text of ours
      // keeps its line breaks (`white-space: pre-wrap`) whatever it holds.
      return WrapWith(
        WrapData(
          attributes: {textAttr: id},
          css: builder == null ? const {'white-space': 'pre-wrap'} : const {},
        ),
        child: text,
      );
    }

    final values = _values(r);
    final current = values.indexOf(value);
    // Every other state ships as a patch of the live element, or as a
    // template when its structure differs (see VariantStates).
    return VariantStates(
      id: id,
      live: WrapWith(
        WrapData(attributes: {variantAttr: id}),
        child: _own(builder!(value as T)),
      ),
      others: {
        for (var i = 0; i < values.length; i++)
          if (i != current) i: _own(builder!(values[i] as T)),
      },
    );
  }

  // A [Watch.tree]: the rows of [items] and, in each one, its children's
  // rows, at any depth; then the one row template, whose children slot is
  // empty (the browser clones the same template into it).
  Widget _tree(String id, List<Object?> items) {
    final key = _resolve(itemKey!, 'itemKey');
    final kids = _itemMethod(treeChildren!, 'Watch.tree(children: …)');
    final kidsId = _bindingIdOf(kids);
    // web: each level is a Column of rows inside its row (a `<details>`
    // holds its children); the slot carries the children method's id.
    // Every level stretches its rows, the top one too: a row's class is the
    // same at any depth (the browser clones one template for all), and a
    // slot's own class doesn't depend on whether it has rows yet.
    Widget level(List<Widget> rows) =>
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
    Widget slot(List<Widget> rows) => WrapWith(
      WrapData(attributes: {treeChildrenAttr: kidsId}),
      child: level(rows),
    );
    final seen = <String>{};
    List<Widget> rowsOf(List<Object?> items) => [
      for (final item in items)
        () {
          final raw = key.member.callWithItem!(item);
          final k = '$raw';
          if (raw == templateKey) {
            throw StateError(
              thorError(
                'THOR-S030',
                'Watch.tree: a row\'s key is `$k`, the value the row '
                    'template stands in for it with. Use another key.',
              ),
            );
          }
          // A key met twice is two rows the browser can't tell apart, or a
          // node that is its own descendant (a cycle, which never ends).
          if (!seen.add(k)) {
            throw StateError(
              thorError(
                'THOR-S043',
                'Watch.tree: the key `$k` is in the tree twice. Keys must be '
                    'unique in the whole tree (a `withArg(row.key)` names one '
                    'node), and a node can\'t be its own descendant.',
              ),
            );
          }
          final row = WatchItem._(item, k, raw);
          final children =
              _itemValue(kids, item) as List<Object?>? ?? const <Object?>[];
          final child = eachNode!(row, slot(rowsOf(children)));
          return RowWrapWith(
            WrapData(attributes: {itemKeyAttr: k}),
            row._lengths,
            child: child,
          );
        }(),
    ];
    final rows = rowsOf(items);
    final template = WatchItem._template(templateKey);
    final templateRow = eachNode!(template, slot(const []));
    return WrapWith(
      WrapData(attributes: {listAttr: id, listKeyAttr: _memberId(key)}),
      child: level([
        ...rows,
        Widget.element(
          tag: 'template',
          attributes: {listTemplateAttr: id},
          children: [
            RowWrapWith(
              const WrapData(),
              template._lengths,
              child: templateRow,
            ),
          ],
        ),
      ]),
    );
  }

  // Whether this Watch marks its element as finite states (`data-tv`).
  bool get _marksStates =>
      builder != null && each == null && untracked(source) is! String;

  /// A state needs an element of its own: a builder that returns another
  /// `Watch` (states inside states) or several elements ([MultipleRoots], a
  /// fragment such as a `ResponsiveLayout`'s copies)
  /// gets a box that doesn't take part in the layout (`display: contents`),
  /// or the engine would mark, and swap, only the first one.
  static Widget _own(Widget built) {
    // Also what an app component builds.
    final r = resolveComponent(built);
    // `// web:` a state that draws nothing (`SizedBox.shrink()`) must not
    // take a `gap` slot in its flex/grid parent: Flutter would have no
    // child there at all. Its marked element generates no box.
    if (r is SizedBox && r.isEmptyShrink) return const _EmptyState();
    // A `QueryBuilder` in a state of another one marks its element too.
    return (r is Watch && r._marksStates) ||
            r is _QueryStates ||
            drawsSeveralRoots(built)
        ? _StatesBox(built)
        : built;
  }
}

/// Flutter's `ValueListenableBuilder` on a field of a [ThorState]: a
/// [Watch]. The server renders the builder once per value (`bool` or enum
/// fields) and the browser shows the one that matches, like any `Watch`.
///
/// ```dart
/// ValueListenableBuilder<bool>(
///   valueListenable: panel.open,   // final open = state(false);
///   builder: (context, open, child) => Text(open ? 'Open' : 'Closed'),
/// )
/// ```
///
/// `// web:` the builder runs on the server only, once per value: what
/// changes must come from the `value` it receives. An `int` or a `String`
/// field has unbounded values, so it can't be prerendered (THOR-S013): show a
/// String with `Watch(state.field)`, an int with `Watch(state.field.call,
/// count: n, …)`. A [ValueListenable] that is not a `StateSignal` (a plain
/// `ValueNotifier`) is drawn once with its current value: nothing in the
/// browser listens to it (a `ThorState` field of that type is a build
/// error).
class ValueListenableBuilder<T> extends StatelessWidget {
  /// Builds [builder] for each value of [valueListenable].
  const ValueListenableBuilder({
    super.key,
    required this.valueListenable,
    required this.builder,
    this.child,
  });

  /// The field to watch: a `state(...)` of a [ThorState].
  final ValueListenable<T> valueListenable;

  /// Builds the region for a value; [child] is passed through untouched.
  final Widget Function(BuildContext context, T value, Widget? child) builder;

  /// A part of the region that doesn't depend on the value.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final source = valueListenable;
    if (source is! StateSignal<T>) return builder(context, source.value, child);
    final found = ThorState.resolve(source.call);
    if (found == null) {
      throw ArgumentError(
        thorError(
          'THOR-S013',
          'ValueListenableBuilder needs a StateSignal that is a field of a '
              'top-level ThorState (`final open = state(false);`), the '
              'browser finds it by its name.',
        ),
      );
    }
    final id = '${found.$1.idPrefix}.${found.$2.name}';
    if (found.$2.variants == null) {
      // A `bool?` / `Mood?` is finite but for its null, which has no copy.
      final orNull = <T>[] is List<bool?> || <T>[] is List<Enum?>;
      final unbounded = orNull
          ? 'make the field non-null (`state(false)`, or an enum with a `none` '
                'value): the browser can only show the values listed'
          : source.peek() is String
          ? 'Watch(state.${found.$2.name}) shows a String field as text'
          : 'Watch(state.${found.$2.name}.call, count: n, builder: …) '
                'takes an int from 0 to n - 1; or a method returning a '
                'String (`String label() => \'\${${found.$2.name}.value}\'`) '
                'with Watch(state.label)';
      throw ArgumentError(
        thorError(
          'THOR-S013',
          'ValueListenableBuilder<$T> on $id can\'t rebuild in the browser: '
              'the server renders one copy per value, and '
              '${orNull ? 'a $T can be null, which has no copy to show' : 'a $T has unbounded values'}. '
              'Fix: $unbounded.',
        ),
      );
    }
    return Watch<T>(
      source.call,
      builder: (value) => builder(context, value, child),
    );
  }
}

/// Flutter's `FutureBuilder` for a `query`: [builder] draws the query's
/// [AsyncSnapshot], on the server for the first paint and, in the browser,
/// by switching among the states the server shipped.
///
/// ```dart
/// QueryBuilder(
///   query: cart.lines,
///   builder: (context, snapshot) {
///     if (snapshot.hasError) return Text('Could not load');
///     if (!snapshot.hasData) return const Text('Loading…');
///     return Watch(cart.rows, itemKey: cart.lineKey,
///         each: (row) => row.text(cart.lineText));
///   },
/// )
/// ```
///
/// The states are the query's `phase`: waiting with nothing to show,
/// waiting with the last value, done, failed and done without data (the
/// answer was null). [builder] runs on the
/// server, once per state, so **what changes with the data goes through
/// the state** (`Watch`, `row.text`, [QueryError]), never through
/// `snapshot.data` read in the builder: the structure is fixed and only
/// the bindings move.
///
/// A state that needs data is left out when the server has none (the query
/// failed or hasn't run) unless [initialData] stands in for it: give it
/// when a first paint that failed must switch to the list after a retry.
///
/// `// web:` Flutter's builder runs again in every frame; here it runs on
/// the server and the browser only switches. Flutter's
/// `FutureBuilder(future:)` has no equivalent for a query, so this is
/// named after it (TanStack's `useQuery` states, SWR's `isLoading` /
/// `isValidating`).
class QueryBuilder<T> extends StatelessWidget {
  /// Draws [query] with [builder].
  const QueryBuilder({
    super.key,
    required this.query,
    required this.builder,
    this.initialData,
  });

  /// The query, a field of a `ThorState` (`cart.lines`).
  final ServerQuery<Object?, T> query;

  /// Draws a snapshot of the query.
  final Widget Function(BuildContext context, AsyncSnapshot<T> snapshot)
  builder;

  /// The data to draw the states that need it with when the server has
  /// none.
  final T? initialData;

  @override
  Widget build(BuildContext context) => _QueryStates<T>(this, context);
}

/// The states of a [QueryBuilder] (what its `build` returns), with the
/// context its builder is given; it answers the layout hints for the state
/// drawn.
class _QueryStates<T> extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn, LayoutHint, HeightHint {
  const _QueryStates(this.owner, this.context);

  final QueryBuilder<T> owner;
  final BuildContext context;

  static const _phases = [0, 1, 2, 3, 4];

  ServerQuery<Object?, T> get _query => owner.query;

  T? get _data => untracked(() => _query.data.value) ?? owner.initialData;

  Widget _state(int phase) => owner.builder(
    context,
    _query.snapshotOf(phase, phase == 3 || phase == 4 ? null : _data),
  );

  int get _current => untracked(_query.phase);

  @override
  bool get fillsWidth => layoutFillsWidth(_state(_current));

  @override
  bool get fillsHeight => layoutFillsHeight(_state(_current));

  @override
  Widget build(BuildContext _) {
    if (ThorState.resolve(_query.phase) == null) {
      throw ArgumentError(
        thorError(
          'THOR-S001',
          'QueryBuilder(query: …) needs a query that is a field of a '
              'ThorState (`final lines = query(repo.lines);`), not one made '
              'in a build: the browser finds it by its name.',
        ),
      );
    }
    final r = _resolve(_query.phase, 'QueryBuilder');
    final id = _bindingIdOf(r);
    final current = _current;
    final hasData = _data != null;
    final others = <int, Widget>{};
    for (final p in _phases) {
      if (p == current) continue;
      // The states that have data, when the server has none (the browser
      // runs the query, or it failed): drawn with a placeholder snapshot
      // that says `hasData` and holds nothing, so the browser can switch to
      // them when the data arrives. A builder that reads `snapshot.data`
      // can't be drawn that way: its state is left out (THOR-S037 in
      // `thor dev`).
      final widget = hasData || (p != 1 && p != 2)
          ? _state(p)
          : _placeholderState(p);
      if (widget != null) others[p] = Watch._own(widget);
    }
    return VariantStates(
      id: id,
      live: WrapWith(
        WrapData(attributes: {variantAttr: id}),
        child: Watch._own(_state(current)),
      ),
      others: others,
    );
  }

  /// The state [phase] (waiting with data, or done) drawn with no data on
  /// the server, or null when its builder needs the data itself (a `data!`,
  /// a `requireData`): what a builder does with a value that isn't there.
  Widget? _placeholderState(int phase) {
    try {
      return owner.builder(
        context,
        AsyncSnapshot<T>.placeholder(
          phase == 1 ? ConnectionState.waiting : ConnectionState.done,
        ),
      );
      // A builder that reads the data it can't have: only these (a null
      // check, a cast, a call on null, `requireData`) mean that. Any other
      // error is a bug the live state would have hit too.
      // ignore: avoid_catching_errors
    } on TypeError catch (e, s) {
      return _leftOut(phase, e, s);
      // ignore: avoid_catching_errors
    } on NoSuchMethodError catch (e, s) {
      return _leftOut(phase, e, s);
    } on StateError catch (e, s) {
      if (e.message.startsWith('Snapshot has')) return _leftOut(phase, e, s);
      rethrow;
    }
  }

  static final _reported = <String>{};

  // Release: the builders already reported (a builder is one place in the
  // app's code, so its error type and frame name it), once per process.
  static final _reportedInRelease = <String>{};

  /// Whether [error] is what a builder does when it reads the data it
  /// can't have (a `data!`, a call on null, `requireData`): expected, not a
  /// bug to report.
  static bool _readsMissingData(Object error) => switch (error) {
    StateError(:final message) => message.startsWith('Snapshot has'),
    TypeError() => '$error'.startsWith('Null check operator'),
    NoSuchMethodError() => '$error'.contains('null'),
    _ => false,
  };

  /// Says (under `thor dev`, once per cause) that the state [phase] was left
  /// out and what the builder threw: an error that is a bug of the builder
  /// and not a read of the data looks the same from here, so the developer
  /// gets the original error and its frame.
  ///
  /// In release the page is the same, but an error that is not a read of the
  /// data (a cast that fails, a bad index: a real bug that the live state
  /// would hit too) goes to the server's `onError`, once per builder.
  Widget? _leftOut(int phase, Object error, StackTrace stack) {
    if (ThorDev.enabled) {
      final frame = ThorDev.appFrame(stack);
      final text = ThorDev.terminalSafe('$error'.split('\n').first, 300);
      final line =
          '[thor] THOR-S037 QueryBuilder<$T>: the '
          '${phase == 1 ? 'waiting with data' : 'done'} state was left out, '
          'its builder threw ${error.runtimeType}: $text'
          '${frame == null ? '' : ' (at $frame)'}';
      if (_reported.add(line)) ThorDev.errorSink(line);
    } else if (!_readsMissingData(error)) {
      final errors = BuilderErrorScope.maybeOf(context);
      final key = '$T ${error.runtimeType} ${ThorDev.appFrame(stack)}';
      if (errors != null && _reportedInRelease.add(key)) {
        errors.add((error, stack));
      }
    }
    return null;
  }
}

/// The visitor's message of a failed [query], bound to the page (a text
/// that follows the query in the browser): the error state of a
/// [QueryBuilder] shows it with this, since its builder runs on the server.
///
/// ```dart
/// if (snapshot.hasError) return QueryError(cart.lines);
/// ```
///
/// `// web:` no Flutter equivalent (Flutter reads `snapshot.error` in a
/// builder that runs again; here the message arrives after the builder ran).
class QueryError extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Shows the message of [query], styled with [style].
  const QueryError(this.query, {super.key, this.style});

  /// The query, a field of a `ThorState`.
  final ServerQuery<Object?, Object?> query;

  /// The text's style.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) =>
      Watch<String>(query.message, style: style);
}

/// The marked element of a state that draws nothing: `display: contents`
/// without children generates no box, so it takes no `gap` slot.
class _EmptyState extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => thorElement(
    'div',
    debugName: 'Watch',
    css: const {'display': 'contents'},
    childRules: ChildRules.none,
    children: const [],
  );
}

/// The box of a state whose builder returns another states `Watch`. It
/// takes no part in the layout (`display: contents`), so it keeps only the
/// engine's marks (the attributes) and hands everything else its wrappers
/// gave it (a `SizedBox` folded into a margin, `Expanded`, a padding) to
/// the element inside, where the layout happens; that element gets the
/// rules of the box's parent too, as if the box weren't there.
class _StatesBox extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  const _StatesBox(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = ChildRulesScope.maybeOf(context);
    final pending = scope?.pending;
    final box = thorElement(
      'div',
      debugName: 'Watch',
      css: const {'display': 'contents'},
      childRules: scope?.rules ?? ChildRules.none,
      children: [
        if (pending == null)
          child
        else
          WrapWith(
            WrapData(
              classes: pending.classes,
              baseCss: pending.baseCss,
              css: pending.css,
              classCss: pending.classCss,
              conditions: pending.conditions,
              fillsWidth: pending.fillsWidth,
              fixesWidth: pending.fixesWidth,
              fillsHeight: pending.fillsHeight,
              tag: pending.tag,
              flexible: pending.flexible,
            ),
            child: child,
          ),
      ],
    );
    if (pending == null) return box;
    return ChildRulesScope(
      rules: scope?.rules,
      pending: WrapData(
        attributes: pending.attributes,
        debugAttributes: pending.debugAttributes,
      ),
      // The element reads the scope above its parent: one node between.
      child: Widget.fragment([box]),
    );
  }
}

/// One row of a list [Watch]: its [key] and its changing texts.
class WatchItem {
  WatchItem._(this._item, this.key, [Object? rawKey])
    : _rawKey = rawKey ?? key,
      _template = false;
  WatchItem._template([Object? placeholder])
    : _item = null,
      key = keyToken,
      _rawKey = placeholder ?? keyToken,
      _template = true;

  final Object? _item;
  final bool _template;

  // The key as `itemKey` returned it (an int for an int key); in the
  // template, the value that stands in for it (`Watch.list`).
  final Object _rawKey;

  /// The row's key (in the row template, the placeholder the browser fills):
  /// use it as an argument, `onPressed: cart.remove.withArg(row.key)`.
  final String key;

  /// A part of the row with finite states computed from the item: [state]
  /// is a method of the state taking the item and returning a `bool` or an
  /// enum (`bool isOffer(Line line)`); [builder] builds each state. The
  /// states must have the same structure (they differ in classes,
  /// attributes and texts), like a chip selected or not.
  ///
  /// An `int` state (`int stars(Line line)`, values `0 … count-1`) needs
  /// [count], like `Watch`.
  Widget watch<V>(
    V Function(Never item) state, {
    required Widget Function(V value) builder,
    int? count,
  }) {
    final r = _itemMethod(state, 'row.watch');
    final values =
        r.member.variants ??
        (count != null
            ? List<Object?>.generate(count, (i) => i)
            : throw ArgumentError(
                thorError(
                  'THOR-S003',
                  'row.watch(${_memberId(r)}) needs a method returning a bool '
                      'or an enum, or `count:` for an int.',
                ),
              ));
    return _states<V>(
      _bindingIdOf(r),
      values,
      _template ? 0 : values.indexOf(_itemValue(r, _item)),
      builder,
    );
  }

  // The part of the row with the finite states [values] of the binding [id],
  // now in state [current].
  Widget _states<V>(
    String id,
    List<Object?> values,
    int current,
    Widget Function(V value) builder, {
    bool select = false,
  }) {
    final child = builder(values[current] as V);
    final live = _RowLive(
      WrapData(
        attributes: {
          rowVariantAttr: id,
          rowVariantIndexAttr: '$current',
          if (select) rowSelectAttr: '',
        },
      ),
      child: child,
      // web: the browser clones the row template, drawn in state 0: what the
      // layout infers from a state (`Stack.fillsWidth`, a parent's rules)
      // reads that one in every row, or the server's class would differ from
      // the clone's.
      first: current == 0 ? child : null,
      template: () => builder(values[0] as V),
    );
    if (!_template) return live;
    // The row template carries every other state (rows patch from it).
    return _RowStates(
      id: id,
      select: select,
      live: live,
      others: {
        for (var i = 1; i < values.length; i++) i: builder(values[i] as V),
      },
    );
  }

  /// A part of the row that is in one state while the row's key is the value
  /// of [source] (a `state(...)` field of the key's type) and in the other
  /// while it is not: a highlighted row, an open one.
  ///
  /// ```dart
  /// row.selected(table.selected, builder: (on) => Row(selected: on, …))
  /// ```
  ///
  /// Unlike [watch] with a method that reads the field, the browser does not ask
  /// every row when [source] changes: only the row that was selected and the
  /// one that is now are patched (Solid's `createSelector`), so selecting a row
  /// of a 1 000-row list costs two rows, not 1 000.
  ///
  /// `// web:` no Flutter equivalent (Flutter rebuilds the list).
  Widget selected(
    StateSignal<Object?> source, {
    required Widget Function(bool selected) builder,
  }) {
    final r = _resolve(source, 'row.selected');
    final on = !_template && '${untracked(source.call)}' == key;
    return _states<bool>(
      _bindingIdOf(r),
      const [false, true],
      on ? 1 : 0,
      builder,
      select: true,
    );
  }

  // [watch] of the `bool` or enum property [property] with [values], read by
  // the lambda [state] here and by the browser through `$Rows.property`.
  Widget _propertyWatch<V>(
    String property,
    List<Object?> values,
    Function state,
    Widget Function(V value) builder,
  ) => _states<V>(
    '$rowFieldsState.$property',
    values,
    _template ? 0 : values.indexOf(Function.apply(state, [_item])),
    builder,
  );

  // web: not in Flutter.
  /// An `<input type="hidden" name=[name]>` whose value is
  /// [value] (a method of the state taking the item), so each row posts
  /// with the enclosing form (`row.field('tag', editor.tagName)`).
  Widget field(String name, Function value) {
    final r = _itemMethod(value, 'row.field');
    return _hiddenField(
      name,
      _bindingIdOf(r),
      _template ? '' : '${_itemValue(r, _item)}',
    );
  }

  Widget _hiddenField(String name, String binding, String value) =>
      Widget.element(
        tag: 'input',
        attributes: {
          'type': 'hidden',
          'name': name,
          'value': value,
          fieldAttr: binding,
        },
      );

  // [field] of the `String` property [property], read by the lambda [value]
  // here and by the browser through `$Rows.property`.
  Widget _propertyField(String name, String property, Function value) =>
      _hiddenField(
        name,
        '$rowFieldsState.$property',
        _template ? '' : '${Function.apply(value, [_item])}',
      );

  // Whether [field] is a member of a state (or a `withArg` of one).
  bool _isMember(Function field) =>
      ThorState.resolve(BoundCall.of(field)?.function ?? field) != null;

  // A [Text] showing the `String` property [property] of the item, read by
  // the lambda [field] here and by the browser through `$Rows.property`.
  Widget _propertyText(
    String property,
    Function field, {
    TextStyle? style,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
  }) => WrapWith(
    WrapData(attributes: {fieldAttr: '$rowFieldsState.$property'}),
    child: Text(
      _template ? '' : '${Function.apply(field, [_item])}',
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    ),
  );

  /// A [Text] showing [field] (a method of the state taking the item:
  /// `String lineName(CartLine line)`).
  Widget text(
    Function field, {
    TextStyle? style,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    final r = _itemMethod(field, 'row.text');
    return WrapWith(
      WrapData(attributes: {fieldAttr: _bindingIdOf(r)}),
      child: Text(
        _template ? '' : '${_itemValue(r, _item)}',
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }

  /// [text] without its own element: the binding of [field] for an element
  /// of yours to carry. See [WatchRow.bindText].
  RowTextBinding bindText(Function field) {
    final r = _itemMethod(field, 'row.bindText');
    return RowTextBinding._(
      _bindingIdOf(r),
      _template ? '' : '${_itemValue(r, _item)}',
    );
  }

  // [bindText] of the property [property], read by the lambda [field] here
  // and by the browser through `$Rows.property`.
  RowTextBinding _propertyBindText(String property, Function field) =>
      RowTextBinding._(
        '$rowFieldsState.$property',
        _template ? '' : '${Function.apply(field, [_item])}',
      );

  /// The row's [value] (a method of the state taking the item) as a
  /// `String`, for a widget parameter that becomes an HTML attribute:
  /// `Checkbox(semanticLabel: row.bind(todos.titleOf))`. See
  /// [WatchRow.bind].
  String bind(Function value) {
    final r = _itemMethod(value, 'row.bind');
    return rowBindMarker(
      _bindingIdOf(r),
      _template ? '' : '${_itemValue(r, _item)}',
    );
  }

  // [bind] of the `String` property [property], read by the lambda [field]
  // here and by the browser through `$Rows.property`.
  String _bindProperty(String property, Function field) => rowBindMarker(
    '$rowFieldsState.$property',
    _template ? '' : '${Function.apply(field, [_item])}',
  );

  /// [child] with HTML attribute [name] set to [value] (a method of the
  /// state taking the item, like [text]): a link per row
  /// (`row.attribute(AttributeName.href, links.urlOf, child: Link(…))`), an image's
  /// `src`/`alt`, an `aria-label` or `title` that names the row's control,
  /// an `aria-rowindex`. The server writes the first value; the browser
  /// rewrites it when the row's item changes (also on rows cloned for new
  /// items).
  ///
  /// [name] must be an `aria-*` or `data-*` attribute or one of a fixed
  /// set (`href`, `src`, `alt`, `title`, `value`, `id`, `role`…; see
  /// `isBindableAttribute`): never an event handler (`on*`), `style` or
  /// `class`. A URL attribute (`href`, `src`, `action`…) with an empty
  /// value or an unsafe scheme (`javascript:`, `data:`…) is left out, on
  /// the server and in the browser (`safeAttributeValue`). The value wins
  /// over the same attribute set by [child] or a wrapper around this one.
  ///
  /// Around a `TextField` (or `TextFormField`), the control's attributes
  /// (`value`, `placeholder`, `name`, `min`/`max`/`step`, `tabindex`,
  /// `aria-*`) go to its `<input>`, the rest to its outer element: a row
  /// can edit its item (`row.attribute(AttributeName.value, env.keyOf, child:
  /// TextField(name: 'key'))`). A multi-line one (`maxLines` above 1) is a
  /// `<textarea>`: the value is its content, not a `value` attribute.
  ///
  /// `// web:` no Flutter equivalent (Flutter has no attributes).
  Widget attribute(
    AttributeName name,
    Function value, {
    required Widget child,
  }) {
    if (!isBindableAttribute(name)) {
      throw ArgumentError.value(
        name,
        'name',
        'row.attribute can set aria-*, data-* and plain attributes like href, '
            'src, alt, title or value; never on* handlers, style or class',
      );
    }
    final r = _itemMethod(value, 'row.attribute');
    return _attributeWith(
      name,
      _bindingIdOf(r),
      _template ? '' : '${_itemValue(r, _item)}',
      child,
    );
  }

  /// A link per row: [child] inside a `Link` whose `href` is [href]'s
  /// value for the row's item (a method of the state taking the item, like
  /// [text]); the same as `attribute('href', href, child: Link(…))`.
  ///
  /// `// web:` no Flutter equivalent (Flutter navigates in a callback).
  Widget link(
    Function href, {
    required Widget child,
    bool newTab = false,
    String? label,
    bool current = false,
    bool prefetch = true,
  }) => attribute(
    AttributeName.href,
    href,
    child: Link(
      newTab: newTab,
      label: label,
      current: current,
      prefetch: prefetch,
      child: child,
    ),
  );

  Widget _attributeWith(
    String name,
    String binding,
    String value,
    Widget child,
  ) {
    final v = safeAttributeValue(name, value);
    return WrapWith(
      WrapData(
        attributes: {
          rowAttributesAttr: encodeOn({name: binding}),
          name: ?v,
        },
      ),
      child: child,
    );
  }

  /// See [WatchRow.length].
  RowLength length(Function source) {
    final r = _itemMethod(source, 'row.length');
    final v = _template ? 0 : _itemValue(r, _item);
    final id = _bindingIdOf(r);
    final name = boundLengthName(
      id,
    ).replaceFirst(boundLengthPrefix, rowLengthPrefix);
    _lengths[name] = (id: id, first: cssPxValue(v is num ? v : 0));
    return RowLength._(name);
  }

  /// See [WatchRow.color].
  RowColor color(Function source) {
    final r = _itemMethod(source, 'row.color');
    return _color(_bindingIdOf(r), _template ? null : _itemValue(r, _item));
  }

  // [color] of the `String` property [property], read by the lambda [source]
  // here and by the browser through `$Rows.property`.
  RowColor _propertyColor(String property, Function source) => _color(
    '$rowFieldsState.$property',
    _template ? null : Function.apply(source, [_item]),
  );

  RowColor _color(String id, Object? first) {
    final name = boundLengthName(
      id,
    ).replaceFirst(boundLengthPrefix, rowColorPrefix);
    // An empty first value leaves the variable unset (see `safeCssColor`).
    _lengths[name] = (id: id, first: safeCssColor('${first ?? ''}') ?? '');
    return RowColor._(name);
  }

  // The row's lengths. `row.length` can run after `each` returned (in a
  // component's `build`), so they live here, shared with the row's wrapper
  // (`RowWrapWith`): the element that reads one binds it on itself.
  final _lengths = <String, ({String id, String first})>{};

  // [attribute] of the `String` property [property], read by the lambda
  // [value] here and by the browser through `$Rows.property`.
  Widget _propertyAttribute(
    String name,
    String property,
    Function value,
    Widget child,
  ) {
    if (!isBindableAttribute(name)) {
      throw ArgumentError.value(
        name,
        'name',
        'row.attribute can set aria-*, data-* and plain attributes like href, '
            'src, alt, title or value; never on* handlers, style or class',
      );
    }
    return _attributeWith(
      name,
      '$rowFieldsState.$property',
      _template ? '' : '${Function.apply(value, [_item])}',
      child,
    );
  }
}

/// A row's changing text bound to an element of your own, with no `<span>`
/// in between: `<td data-tf="…">text</td>`. What [WatchRow.bindText]
/// returns.
///
/// ```dart
/// final id = row.bindText((o) => '${o.id}');
/// Td(text: id.text, attributes: id.attributes)   // or td([...id.children], attributes: id.attributes)
/// ```
///
/// `// web:` no Flutter equivalent: Flutter's `Text` is always its own
/// widget; here a table cell or a link can be the text node's element.
final class RowTextBinding {
  const RowTextBinding._(this._id, this.text);

  final String _id;

  /// The text the server draws (empty in the row template: the browser
  /// fills it).
  final String text;

  /// The attributes the element that holds [text] must carry (merge them
  /// with your own `attributes`): the binding the browser follows to keep
  /// [text] current.
  Map<String, String> get attributes => {fieldAttr: _id};

  /// [text] as the element's content (`td([...id.children], …)`).
  List<Widget> get children => [Widget.text(text)];
}

/// One row of a [Watch.list]: [key] typed like `itemKey`'s result, and the
/// methods of [WatchItem] taking the item type [I], so a lambda or a
/// tear-off is checked against it.
class WatchRow<I, K extends Object> {
  WatchRow._(this._row, this.key);

  final WatchItem _row;

  /// The row's key, typed (in the row template, a placeholder the browser
  /// fills): use it as an argument, `orders.remove.withArg(row.key)` or
  /// `archive.withArg(row.key)`.
  final K key;

  /// Whether this is the row template (the one the browser clones for the
  /// rows it adds) and not a row the server draws for an item. What a widget
  /// that only the rows added in the browser carry, like an `AnimatedList`'s
  /// entrance, tells them apart by.
  ///
  /// `// web:` no Flutter equivalent.
  bool get isTemplate => _row._template;

  /// See [WatchItem.watch]. [state] is a method of the state, or a lambda
  /// that only reads one `bool` or enum property of the item
  /// (`row.watch((o) => o.isOffer, builder: …)`), like [text]. An `int`
  /// state needs a method (and `count:`).
  Widget watch<V>(
    V Function(I item) state, {
    required Widget Function(V value) builder,
    int? count,
  }) {
    if (!_row._isMember(state)) {
      final (property, values) = _lambdaStates(state);
      return _row._propertyWatch<V>(property, values, state, builder);
    }
    return _row.watch<V>(state, builder: builder, count: count);
  }

  /// See [WatchItem.selected]: [source] is a field of a state holding the
  /// selected row's key (`final selected = state(0)` for `int` keys).
  Widget selected(
    StateSignal<K?> source, {
    required Widget Function(bool selected) builder,
  }) => _row.selected(source, builder: builder);

  /// A [Length] that follows [source], a method of the state taking the
  /// item, for this row: a circle placed by its own data
  /// (`final x = row.length(circles.left)`, then `Positioned(leftLength: x)`
  /// or any `StyleProps` length). Use it inside the row only: outside it
  /// the element fails with THOR-S042.
  ///
  /// `// web:` Flutter lays out in Dart; here the value is a CSS variable the
  /// class reads (the same class for every row), the server writes the first
  /// value into the element's `style`, and the browser rewrites it when the
  /// row's item changes (also on rows cloned for new items), so the client
  /// still writes no style of its own. The variable's name is thor's.
  RowLength length(num Function(I item) source) => _row.length(source);

  /// A [Color] that follows [source] for this row: a method of the state
  /// taking the item, or a lambda that only reads one `String` property of
  /// it (`row.color((p) => p.hex)`), like [text]. The value is a CSS color
  /// as text: `#rgb`, `#rrggbb` (with alpha too), a plain `rgb()`, `hsl()`
  /// or `oklch()` of numbers, or a keyword (`red`, `transparent`); anything
  /// else leaves the color unset. It goes wherever a `Color` does, inside
  /// the row only (outside it the element fails with THOR-S042):
  ///
  /// ```dart
  /// final swatch = row.color((p) => p.hex);
  /// Container(width: 28, height: 28, color: swatch)
  /// ```
  ///
  /// `// web:` Flutter rebuilds the row per item. Here the value is a CSS
  /// variable the class reads (the same class for every row), the server
  /// writes the first value into the element's `style`, and the browser
  /// rewrites it when the row's item changes (also on rows cloned for new
  /// items), so the client still writes no style of its own. The variable's
  /// name is thor's.
  RowColor color(String Function(I item) source) {
    if (!_row._isMember(source)) {
      return _row._propertyColor(_lambdaProperty(source, 'row.color'), source);
    }
    return _row.color(source);
  }

  /// A hidden `<input name=[name]>` with the row's [value]: a method of the
  /// state taking the item (`row.field('tag', editor.tagName)`), or a lambda
  /// that only reads one `String` property of it
  /// (`row.field('tag', (t) => t.name)`), like [text]. See
  /// [WatchItem.field].
  Widget field(String name, Object? Function(I item) value) {
    if (!_row._isMember(value)) {
      return _row._propertyField(
        name,
        _lambdaProperty(value, 'row.field'),
        value,
      );
    }
    return _row.field(name, value);
  }

  /// A [Text] showing [field]: a method of the state taking the item
  /// (`row.text(orders.customerOf)`), or a lambda that only reads one
  /// `String` property of it (`row.text((o) => o.customer)`), or an `int`,
  /// `num`, `double` or `bool` one as text (`row.text((o) => '${o.id}')`,
  /// `o.id.toString()`): no method per property. The build gives the browser the same read; a lambda that does
  /// more (`(o) => o.customer.toUpperCase()`, `'${o.a} ${o.b}'`) is a
  /// method's work (THOR-S033, and THOR-B030 at build time).
  ///
  /// `// web:` the lambda runs on the server to draw the row; the browser
  /// never runs it, it reads the property the build found.
  Widget text(
    String Function(I item) field, {
    TextStyle? style,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    if (!_row._isMember(field)) {
      final property = _lambdaProperty(field);
      return _row._propertyText(
        property,
        field,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    return _row.text(
      field,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  /// The row's [field] as text for **your own element** to hold, without
  /// the `<span>` [text] draws: a `<td>`, an `<a>`, a `<th>` or any element
  /// of the web layer or `html.dart` that binds its content directly.
  /// [field] is a method of the state taking the item, or a lambda that
  /// reads one property of it (`(o) => o.label`; `'${o.id}'` or
  /// `o.id.toString()` for an `int`, `num`, `double` or `bool`), like
  /// [text]. Same markup the browser follows (`data-tf`), on both engines.
  ///
  /// ```dart
  /// final label = row.bindText((o) => o.label);
  /// td([...label.children], attributes: label.attributes)
  /// ```
  ///
  /// `// web:` no Flutter equivalent (see [RowTextBinding]).
  RowTextBinding bindText(String Function(I item) field) {
    if (!_row._isMember(field)) {
      return _row._propertyBindText(
        _lambdaProperty(field, 'row.bindText'),
        field,
      );
    }
    return _row.bindText(field);
  }

  (String, List<Object?>) _lambdaStates(Function state) {
    const call = 'row.watch(state.isOfferOf';
    if (!hasRowProbe(I)) {
      throw StateError(
        thorError(
          'THOR-S032',
          'row.watch(lambda) over a $I needs the probe of its class that '
              'thor generates: run the app with `thor dev`, `thor build` or '
              '`thor test` (or pass a method of the state: `$call, …)`).',
        ),
      );
    }
    final found = statesOfRowLambda(I, state);
    if (found == null) {
      throw ArgumentError(
        thorError(
          'THOR-S033',
          'row.watch(…) got a lambda that is not a single `bool` or enum '
              'property of the item: the browser can only read '
              '`o.isOffer`, not compute it. Fix: a method of the state '
              '(`bool isOfferOf($I o) => …`) passed as `$call, …)`, or '
              '`(o) => o.property` of a `bool` or enum property. An `int` '
              'state needs a method and `count:`.',
        ),
      );
    }
    return (found.property, found.values);
  }

  String _lambdaProperty(Function field, [String what = 'row.text']) {
    // `row.attribute(AttributeName.href, state.urlOf, …)`: the name comes first.
    final named = what == 'row.attribute' || what == 'row.field';
    final call = named
        ? "$what(${what == 'row.attribute' ? 'AttributeName.title' : "'name'"}, state.customerOf"
        : '$what(state.customerOf';
    if (!hasRowProbe(I)) {
      throw StateError(
        thorError(
          'THOR-S032',
          '$what(lambda) over a $I needs the probe of its class that '
              'thor generates: run the app with `thor dev`, `thor build` or '
              '`thor test` (or pass a method of the state: '
              '`$call)`).',
        ),
      );
    }
    return propertyOfRowLambda(I, field) ??
        (throw ArgumentError(
          thorError(
            'THOR-S033',
            '$what(…) got a lambda that is not a single property of the '
                'item: the browser can only read `o.customer`, not compute '
                'it. Fix: a method of the state '
                '(`String customerOf($I o) => …`) passed as '
                '`$call)`, or `(o) => o.property` of a '
                'String property (an int, num, double or bool one as text: '
                r"`'${o.id}'` or `o.id.toString()`).",
          ),
        ));
  }

  /// The row's [value] as a `String` for a widget parameter that becomes an
  /// HTML attribute, so a row names its own controls the way a Flutter
  /// `ListView.builder` does, with the item in hand:
  ///
  /// ```dart
  /// Checkbox(
  ///   value: done,
  ///   semanticLabel: row.bind(todos.titleOf),   // or row.bind((t) => t.title)
  ///   onChanged: todos.setDone.withArg(row.key),
  /// )
  /// ```
  ///
  /// [value] is a method of the state taking the item, or a lambda that only
  /// reads one `String` property of it (like [text]). Works wherever a
  /// widget writes a `String` as an `aria-*`, `data-*` or plain attribute
  /// (`semanticLabel:`, `tooltip:`, `Semantics(label:)`, an image's `alt`,
  /// `hintText`…): the server writes the row's value and the browser fills
  /// it in rows it adds and keeps it current when the item changes (the
  /// same markup as [attribute]). The URL attributes (`href`, `src`) are
  /// left out when the value is unsafe.
  ///
  /// The `String` is not meant to be shown or computed on: for a visible
  /// text use [text]; `'${row.bind(…)}!'` or `.trim()` lose the binding.
  /// The value evaluated with the row key (`todos.titleOf(row.key)`) runs
  /// once on the server with the template's key: that is what this is for
  /// (THOR-S034).
  ///
  /// `// web:` no Flutter equivalent (Flutter rebuilds the row per item).
  String bind(String Function(I item) value) {
    if (!_row._isMember(value)) {
      return _row._bindProperty(_lambdaProperty(value, 'row.bind'), value);
    }
    return _row.bind(value);
  }

  /// See [WatchItem.attribute]. [value] is a method of the state taking the
  /// item, or a lambda that only reads one `String` property of it
  /// (`row.attribute(AttributeName.href, (l) => l.url, child: Link(…))`), like [text].
  Widget attribute(
    AttributeName name,
    Object? Function(I item) value, {
    required Widget child,
  }) {
    if (!_row._isMember(value)) {
      return _row._propertyAttribute(
        name,
        _lambdaProperty(value, 'row.attribute'),
        value,
        child,
      );
    }
    return _row.attribute(name, value, child: child);
  }

  /// A link per row: [child] inside a `Link` whose `href` is [href]'s value
  /// for the row's item, a method of the state taking the item or a lambda
  /// that only reads one `String` property of it
  /// (`row.link((l) => l.url, child: Text(…))`). The same as
  /// `row.attribute(AttributeName.href, href, child: Link(…))`; an unsafe URL
  /// (`javascript:`) is left out.
  ///
  /// `// web:` no Flutter equivalent (Flutter navigates in a callback).
  Widget link(
    Object? Function(I item) href, {
    required Widget child,
    bool newTab = false,
    String? label,
    bool current = false,
    bool prefetch = true,
  }) => attribute(
    AttributeName.href,
    href,
    child: Link(
      newTab: newTab,
      label: label,
      current: current,
      prefetch: prefetch,
      child: child,
    ),
  );
}

/// HTML attributes of [child]'s element whose values come from a
/// `ThorState` (outside a list; in a list row use `row.attribute`): each
/// method returns the attribute's value, kept current in the browser.
///
/// ```dart
/// WatchAttributes(
///   {'aria-rowcount': grid.ariaRowCount},
///   child: Semantics(role: SemanticsRole.grid, child: …),
/// )
/// ```
///
/// Names follow `row.attribute`: `aria-*`, `data-*` and a fixed set of
/// plain attributes, never `on*`, `style` or `class`; a URL attribute with
/// an unsafe value is left out. Finite states with a different look go
/// through `Watch(builder:)` instead.
///
/// The server writes the first values, so the page is right without JS. An
/// attribute in [clientOnly] is the exception: the server leaves it out and
/// the engine writes it when the page starts. Use it for a button that the
/// state disables (`AttributeName.disabled`) and that must still work
/// without JS, where nothing would ever enable it again:
///
/// ```dart
/// WatchAttributes(
///   {AttributeName.disabled: create.invalid},
///   clientOnly: {AttributeName.disabled},
///   child: FilledButton(buttonType: ButtonType.submit, child: Text('Create')),
/// )
/// ```
///
/// `// web:` no Flutter equivalent (Flutter has no attributes).
class WatchAttributes extends ParentDataWrapper {
  /// Binds each attribute of [attributes] to its method.
  const WatchAttributes(
    this.attributes, {
    super.key,
    this.clientOnly = const {},
    required super.child,
  });

  /// Attribute name → method of a `ThorState` (torn off or with
  /// `withArg`) whose result, as text, is the value.
  final Map<AttributeName, Object? Function()> attributes;

  /// The attributes whose first value the server leaves out: the engine
  /// starts the states they name when the page loads (not on the first
  /// event, as it does otherwise) and writes them, so without JS the element
  /// has none of them.
  ///
  /// `// web:` the browser blocks a disabled submit button for good; with
  /// no engine nothing can enable it, so the server must not disable it.
  final Set<AttributeName> clientOnly;

  @override
  WrapData get wrapData {
    final ids = <String, String>{};
    final first = <String, String>{};
    for (final e in attributes.entries) {
      if (!isBindableAttribute(e.key)) {
        throw ArgumentError.value(
          e.key,
          'attributes',
          'WatchAttributes can set aria-*, data-* and plain attributes like '
              'href, src, alt, title or value; never on* handlers, style or '
              'class',
        );
      }
      final r = _resolve(e.value, 'WatchAttributes');
      ids[e.key] = _bindingIdOf(r);
      if (clientOnly.contains(e.key)) continue;
      final v = safeAttributeValue(e.key, '${untracked(e.value) ?? ''}');
      if (v != null) first[e.key] = v;
    }
    return WrapData(
      attributes: {
        attributesAttr: encodeOn(ids),
        if (clientOnly.any(attributes.containsKey)) attributesAtStartAttr: '',
        ...first,
      },
    );
  }
}

/// [child]'s control value bound to [method] with no `value` attribute: for
/// a `<select>` or a radio group (`role="radiogroup"`), where `value` is not
/// an attribute of the element (the server draws the chosen option or
/// radio, the browser sets the control).
Widget watchControlValue(Object? Function() method, {required Widget child}) {
  final id = _bindingIdOf(_resolve(method, 'valueWatch'));
  return WrapWith(
    WrapData(
      attributes: {
        attributesAttr: encodeOn({AttributeName.value: id}),
      },
    ),
    child: child,
  );
}

/// The markers of a `Gesture`: [gestures] maps `tapd`, `tapu`, `dtap`, `long`, `swipe`,
/// `drag` and `scale` to the widget's callbacks (methods of a `ThorState`,
/// possibly `withArg`). Returns the gesture map and the fixed argument, if
/// any callback has one. With [attribute] [elementEventsAttr] it marks the
/// events of `MouseRegion`, `Focus` and `ExpansionTile` the same way.
({Map<String, String> attributes, String? fixed}) gestureAttributes(
  Map<String, Function?> gestures, {
  String attribute = gestureAttr,
}) {
  final ids = <String, String>{};
  String? fixed;
  for (final e in gestures.entries) {
    final callback = e.value;
    if (callback == null) continue;
    final bound = BoundCall.of(callback);
    final found = ThorState.resolve(bound?.function ?? callback);
    if (found == null) continue;
    ids[e.key] = '${found.$1.idPrefix}.${found.$2.name}';
    if (bound != null) {
      fixed = encodeFixedArg(bound.arg, splits: found.$2.arity >= 2);
    }
  }
  return (
    attributes: ids.isEmpty ? const {} : {attribute: encodeOn(ids)},
    fixed: fixed,
  );
}

/// CSS custom properties of [child]'s element whose values come from a
/// `ThorState`: each method returns a number of pixels, written as
/// `--name: <n>px` and kept current in the browser.
///
/// ```dart
/// WatchVariables(
///   {
///     CssVariable<Length>('--grid-before'): grid.spaceBefore,
///     CssVariable<Length>('--col-2'): grid.width.withArg(2),
///   },
///   child: Styled(
///     style: StyleProps(
///       minHeight: Length.variable(CssVariable('--grid-before')),
///     ),
///     child: const SizedBox(),
///   ),
/// )
/// ```
///
/// For values with no finite set of states (a virtualized list's offset,
/// a column the user resized): the element's class reads the variable
/// (`Length.variable`) and only the value changes, so the client still
/// generates no style. Finite states go through `Watch(builder:)`.
///
/// `// web:` no Flutter equivalent (Flutter lays out in Dart). The first
/// values are in the element's `style`, so the page is right without JS.
///
/// This is the low-level layer, with the variable's name in the app's hands
/// (a stylesheet, a theme or a `StyleProps(raw:)` that reads it). A value a
/// widget reads (padding, a radius, a size, a position) needs no name:
/// `BoundLength` (`card.radius.px`) makes the variable, binds it and puts it
/// on the element that reads it.
class WatchVariables extends ParentDataWrapper {
  /// Binds each variable of [variables] to its method.
  const WatchVariables(this.variables, {super.key, required super.child});

  /// Variable → method of a `ThorState` returning pixels (`double` or
  /// `int`), torn off or with `withArg`.
  final Map<CssVariable<Length>, num Function()> variables;

  @override
  WrapData get wrapData {
    final ids = <String>[];
    final first = <String>[];
    for (final e in variables.entries) {
      if (!isCssVariableName(e.key.name)) {
        throw ArgumentError.value(
          e.key.name,
          'variables',
          'must be a custom property name (--letters-digits)',
        );
      }
      final r = _resolve(e.value, 'WatchVariables');
      ids.add('${e.key}:${_bindingIdOf(r)}');
      first.add('${e.key}:${cssPxValue(untracked(e.value))}');
    }
    return WrapData(
      attributes: {variablesAttr: ids.join(';'), 'style': first.join(';')},
    );
  }
}

/// A length that follows a `ThorState` value, in logical pixels: padding,
/// a radius, a font size, a size or a position that change in the browser
/// without a rebuild.
///
/// ```dart
/// Container(
///   padding: EdgeInsetsGeometry.allLength(card.padding.px),
///   decoration: BoxDecoration(
///     borderRadius: BorderRadius.circularLength(card.radius.px),
///   ),
///   child: content,
/// )
/// ```
///
/// It takes a field (`card.radius`) or a method returning a number
/// (`card.radiusPx`, `grid.width.withArg(2)`), and goes wherever a `Length`
/// does (`EdgeInsetsGeometry.allLength`, `BorderRadius.circularLength`,
/// `TextStyle(fontSizeLength:)`, `SizedBox(widthLength:)`,
/// `Positioned(leftLength:)`, `StyleProps(minHeight:)`), alone or in
/// arithmetic (`card.gap.px * 2`).
///
/// `// web:` Flutter lays out in Dart, so a value that changes is a rebuild.
/// Here the value reaches the element's class as a CSS variable whose name
/// thor makes from the binding: the server writes the class once (the same
/// for every session), the element gets the binding and the first value
/// (right without JS), and the browser only changes the variable. The
/// variable and the element that reads it are thor's; `WatchVariables` and
/// `Length.variable` are the same mechanism by name.
final class BoundLength extends Length {
  BoundLength._(String name) : super.variable(CssVariable(name));

  /// Follows [source]: a field of a `ThorState` (`card.radius.px`) or a
  /// method of one that returns pixels, torn off or with `withArg`.
  factory BoundLength(num Function() source) {
    final r = _resolve(source, 'BoundLength');
    return BoundLength._(registerBoundLength(_bindingIdOf(r), source));
  }
}

/// A [Color] that follows a value of the item per list row: what
/// `row.color(…)` returns. It goes wherever a `Color` does (a `Container`'s
/// `color`, a `BoxDecoration`, a `TextStyle`); the row's element gets its
/// binding and first value, the app never names the variable.
final class RowColor extends Color {
  RowColor._(String name) : super.variable(CssVariable(name));
}

/// A [Length] that follows a method of the state per list row: what
/// `row.length(…)` returns. It goes wherever a `Length` does; the row's
/// element gets its binding and first value, the app never names the variable.
final class RowLength extends Length {
  RowLength._(String name) : super.variable(CssVariable(name));
}

/// `card.radius.px`: a [BoundLength] that follows a state field of pixels,
/// as `16.px` is a fixed one.
extension BoundLengthOfField on StateSignal<num> {
  /// The field's value, in pixels, as a [Length] that follows it.
  BoundLength get px => BoundLength(call);
}

/// `card.radiusPx.px`: a [BoundLength] that follows a state method that
/// returns pixels (`withArg` too: `grid.width.withArg(2).px`).
extension BoundLengthOfMethod on num Function() {
  /// What the method returns, in pixels, as a [Length] that follows it.
  BoundLength get px => BoundLength(this);
}

/// The state a row is in, marked as a part of the row. Its layout hint is
/// that of state 0, the one the row template (and so every row the browser
/// clones) is drawn in, not of the state it is in now.
final class _RowLive extends WrapWith implements LayoutHint, HeightHint {
  const _RowLive(
    super.wrapData, {
    required super.child,
    required this.first,
    required this.template,
  });

  /// The child when it is state 0 already.
  final Widget? first;

  /// Draws state 0.
  final Widget Function() template;

  @override
  bool get fillsWidth => layoutFillsWidth(first ?? template());

  @override
  bool get fillsHeight => layoutFillsHeight(first ?? template());
}

/// The states of a `row.watch` in the row template: [live] and every
/// other state as a patch of its element, or a `<template>` after it when
/// its structure differs (see [RowVariantStates]). A wrapper around
/// `row.watch` (`Semantics(role: listItem)`, `row.attribute`) decorates
/// each state the same way, so a row that changes state keeps its element
/// (its tag, its key and bound attributes), and never the `<template>`
/// elements.
final class _RowStates extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn, LayoutHint, HeightHint {
  const _RowStates({
    required this.id,
    required this.live,
    required this.others,
    this.select = false,
  });

  final String id;

  /// Whether the states are a `row.selected` (the elements carry the mark).
  final bool select;
  final Widget live;
  final Map<int, Widget> others;

  // The template is drawn in state 0 ([live]), the same one every row's
  // layout hint reads ([_RowLive]).
  @override
  bool get fillsWidth => layoutFillsWidth(live);

  @override
  bool get fillsHeight => layoutFillsHeight(live);

  @override
  Widget build(BuildContext context) {
    final scope = ChildRulesScope.maybeOf(context);
    final pending = scope?.pending;
    Widget decorate(Widget state) =>
        pending == null ? state : WrapWith(pending, child: state);
    // The wrappers' data is applied per state: nothing below consumes it.
    return ChildRulesScope(
      rules: scope?.rules,
      child: RowVariantStates(
        id: id,
        live: decorate(live),
        patchable: {
          for (final MapEntry(key: i, value: state) in others.entries)
            i: decorate(
              WrapWith(
                WrapData(
                  attributes: {
                    rowVariantAttr: id,
                    rowVariantIndexAttr: '0',
                    if (select) rowSelectAttr: '',
                  },
                ),
                child: state,
              ),
            ),
        },
        templates: {
          for (final MapEntry(key: i, value: state) in others.entries)
            i: Widget.element(
              tag: 'template',
              attributes: {rowVariantTemplateAttr: id, variantIndexAttr: '$i'},
              children: [decorate(state)],
            ),
        },
      ),
    );
  }
}

/// The `data-t-ev` marker of an element whose [events] (`enter`, `leave`,
/// `focus`, `toggle`) are methods of a `ThorState`, and the fixed argument
/// (`data-tx`) of a `withArg` one. Empty when none is.
Map<String, String> elementEventAttributes(Map<String, Function?> events) {
  final marks = gestureAttributes(events, attribute: elementEventsAttr);
  return {...marks.attributes, argAttr: ?marks.fixed};
}
