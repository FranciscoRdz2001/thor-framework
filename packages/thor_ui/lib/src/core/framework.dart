/// thor's widget tree on the server: widgets, the build context and
/// the build itself.
///
/// A page is built once, top to bottom, in one pass: each widget gets a
/// short-lived [Element] (its [BuildContext]) that points to its parent and
/// to the inherited widgets above it, and what it builds is written into
/// markup nodes (`markup.dart`). Nothing is kept for a rebuild: the browser
/// side is thor_engine's signals, not this tree.
library;

import 'dart:collection';

import '../foundation/errors.dart';
import '../foundation/inspect.dart';
import '../foundation/row_bind.dart' show checkNoRowBindMarker;
import 'markup.dart';

part 'keys.dart';

/// A piece of the page: what `build` returns.
abstract class Widget {
  /// A widget; its [key] is accepted and unused.
  const Widget({this.key});

  /// Identifies this widget among its siblings. The server builds once
  /// and never reconciles, so keys are accepted and not used.
  final Key? key;

  /// An HTML element [tag] with its [id], [classes], inline [styles],
  /// [attributes] and [children]. The wrappers above it
  /// ([Widget.wrapElement]) merge into it.
  const factory Widget.element({
    Key? key,
    required String tag,
    String? id,
    String? classes,
    Styles? styles,
    Map<String, String>? attributes,
    List<Widget>? children,
  }) = _ElementComponent;

  /// A text node, escaped.
  const factory Widget.text(String text, {Key? key}) = _TextComponent;

  /// [children] with no element around them.
  const factory Widget.fragment(List<Widget> children, {Key? key}) =
      _FragmentComponent;

  /// Nothing.
  const factory Widget.empty({Key? key}) = _FragmentComponent._empty;

  /// [child] whose next HTML element(s) take these [id], [classes], [styles]
  /// and [attributes] too: the element's own values win, then the innermost
  /// wrapper's. A [tag] replaces the element's (`Link` makes a `div` an
  /// `<a>`), except an element that keeps its own (an `svg`, an `img`, a
  /// control).
  const factory Widget.wrapElement({
    Key? key,
    String? tag,
    String? id,
    String? classes,
    Styles? styles,
    Map<String, String>? attributes,
    required Widget child,
  }) = _WrapComponent;
}

/// A widget described by what it builds.
abstract class StatelessWidget extends Widget {
  /// A stateless widget.
  const StatelessWidget({super.key});

  /// What this widget is made of, at [context].
  Widget build(BuildContext context);
}

/// A widget with a [State]. On the server it is built once: `initState`,
/// `didChangeDependencies`, `build`, and `dispose` when the page is done.
abstract class StatefulWidget extends Widget {
  /// A stateful widget.
  const StatefulWidget({super.key});

  /// The state of this widget, for one page.
  State createState();
}

/// The state of a [StatefulWidget], for one page.
abstract class State<T extends StatefulWidget> {
  T? _widget;
  Element? _element;
  bool _disposed = false;

  /// The widget this state belongs to.
  T get widget => _widget!;

  /// Where this state is built.
  BuildContext get context => _element!;

  /// Whether the page that builds this state is still being rendered.
  bool get mounted => _element != null && !_disposed;

  /// Called once, before the first [build].
  void initState() {}

  /// Called after [initState] (the server builds once, so only then).
  void didChangeDependencies() {}

  /// What this state's widget is made of.
  Widget build(BuildContext context);

  /// Called when the page is done.
  void dispose() {}

  /// `// web:` the server draws a page once: a state that changes in the
  /// browser is a `ThorState`. Runs [fn] and, in debug, fails.
  void setState(void Function() fn) {
    fn();
    assert(
      false,
      'setState on the server: the page is drawn once. '
      'State that changes in the browser is a ThorState.',
    );
  }
}

/// Data published to the widgets below it
/// (`context.dependOnInheritedWidgetOfExactType<T>()`).
abstract class InheritedWidget extends Widget {
  /// Publishes this widget to [child] and below.
  const InheritedWidget({super.key, required this.child});

  /// The widgets that can read this one.
  final Widget child;

  /// What is built below this widget, at its own [element] (so a
  /// lookup from there finds this widget). [child] by default.
  Widget buildChild(InheritedElement element) => child;

  /// Whether readers of [oldComponent] would need to rebuild. The server
  /// builds once and never asks; kept for Flutter's API.
  bool updateShouldNotify(covariant InheritedWidget oldComponent);
}

/// An [InheritedWidget] that names what its readers see, so a subtree kept
/// by the memo of `const` subtrees ([SubtreeMemo]) can be added
/// again below another instance of it: two instances with equal
/// [memoKey]s (`==`) give every reader the same answers.
///
/// Without it an inherited widget is compared by identity (the same
/// instance). `updateShouldNotify` is no substitute: the server never asks
/// it, and several scopes answer `false` for values that do change.
abstract interface class InheritedMemoKey {
  /// What readers of this widget see; equal keys, equal answers.
  Object? get memoKey;
}

/// Builds [builder] with the context at this place in the tree.
class Builder extends StatelessWidget implements InspectSourceOwner {
  /// Builds [builder] here.
  const Builder({super.key, required this.builder});

  /// What to build.
  final Widget Function(BuildContext context) builder;

  @override
  Function get inspectSource => builder;

  @override
  Widget build(BuildContext context) => builder(context);
}

/// Where a widget is built: its place in the tree, the widgets
/// above it and what they publish.
abstract interface class BuildContext {
  /// The nearest [T] above, or null.
  T? dependOnInheritedWidgetOfExactType<T extends InheritedWidget>();

  /// The element of the nearest [T] above, or null.
  InheritedElement?
  getElementForInheritedWidgetOfExactType<T extends InheritedWidget>();

  /// Calls [visitor] with each element above, nearest first, until it
  /// returns false.
  void visitAncestorElements(bool Function(Element element) visitor);
}

/// A widget at its place in the tree, while the page is built.
class Element implements BuildContext {
  Element._(this.widget, this.parent, this._inherited)
    : depth = parent == null ? 0 : parent.depth + 1,
      _source = parent?._source;

  /// The widget built here.
  final Widget widget;

  /// The element above, or null at the root.
  final Element? parent;

  /// How many elements are above this one.
  final int depth;

  final _Inherited? _inherited;

  /// The nearest app code above that builds this element, for the
  /// development inspector ([ThorInspect]); null when it is off.
  String? _source;

  // See [typePathOf].
  TypePath? _typePath;

  @override
  T? dependOnInheritedWidgetOfExactType<T extends InheritedWidget>() =>
      getElementForInheritedWidgetOfExactType<T>()?.widget as T?;

  @override
  InheritedElement?
  getElementForInheritedWidgetOfExactType<T extends InheritedWidget>() {
    final found = _inherited?.lookup(T);
    if (found != null && _MemoRecording._current != null) {
      _MemoRecording.noteDependency(found);
    }
    if (_Preview._recording != null) _Preview.noteRead(T, found);
    return found;
  }

  /// The nearest [InheritedElement] above (or at) this element whose
  /// widget's runtime type is [type]: what a lookup of that type finds.
  /// For the memo of `const` subtrees ([SubtreeMemo]), which compares
  /// the inherited widgets a kept subtree read with the ones here.
  InheritedElement? inheritedElementOfType(Type type) =>
      _inherited?.lookup(type);

  @override
  void visitAncestorElements(bool Function(Element element) visitor) {
    // A preview's element has other ancestors than the real one.
    if (_Preview._recording != null) _Preview.noteAncestors();
    for (var e = parent; e != null; e = e.parent) {
      if (!visitor(e)) return;
    }
  }
}

/// The element of an [InheritedWidget].
class InheritedElement extends Element {
  InheritedElement._(
    InheritedWidget super.widget,
    super.parent,
    super.inherited,
  ) : super._();

  @override
  InheritedWidget get widget => super.widget as InheritedWidget;
}

/// The inherited widgets above an element, nearest first.
final class _Inherited {
  _Inherited(this.element, this.next) : type = element.widget.runtimeType;

  final InheritedElement element;
  final _Inherited? next;

  /// The type of [element]'s widget: what a lookup compares.
  final Type type;

  // What a lookup that started here found (null too: none above). The
  // chain never changes once built, so each node answers each type once
  // per page: a type missing from the page (or at its root) no longer
  // walks the whole chain from every element below.
  Map<Type, InheritedElement?>? _found;

  /// The nearest element whose widget's runtime type is [type], from this
  /// node up.
  InheritedElement? lookup(Type type) {
    if (this.type == type) return element;
    final memo = _found;
    if (memo != null) {
      final known = memo[type];
      if (known != null || memo.containsKey(type)) return known;
    }
    InheritedElement? result;
    for (var i = next; i != null; i = i.next) {
      if (i.type == type) {
        result = i.element;
        break;
      }
      final below = i._found;
      if (below != null) {
        final known = below[type];
        if (known != null || below.containsKey(type)) {
          result = known;
          break;
        }
      }
    }
    (_found ??= {})[type] = result;
    return result;
  }
}

/// Inline styles of an element, as CSS declarations.
class Styles {
  /// Inline styles from `raw` declarations.
  const Styles({Map<String, String>? raw}) : properties = raw ?? const {};

  /// The declarations, in order.
  final Map<String, String> properties;
}

/// HTML written as is, not escaped: markup that is already HTML (an SVG
/// sprite, a stylesheet). Never data from a user.
final class RawText extends Widget {
  /// [text] written as HTML.
  const RawText(this.text, {super.key});

  /// The HTML.
  final String text;
}

final class _ElementComponent extends Widget {
  const _ElementComponent({
    super.key,
    required this.tag,
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    this.children,
  });

  final String tag;
  final String? id;
  final String? classes;
  final Styles? styles;
  final Map<String, String>? attributes;
  final List<Widget>? children;
}

final class _TextComponent extends Widget {
  const _TextComponent(this.text, {super.key});
  final String text;
}

/// The children of [widget] when it is a fragment (`Widget.fragment`), or
/// null: how a widget that draws several nodes side by side is told apart.
List<Widget>? fragmentChildren(Widget? widget) =>
    widget is _FragmentComponent ? widget.children : null;

/// Whether [widget] is a `Widget.element` of [tag] that carries the
/// attribute [attribute] (how a container finds a list's row template).
bool isElementWith(Widget widget, String tag, String attribute) =>
    widget is _ElementComponent &&
    widget.tag == tag &&
    (widget.attributes?.containsKey(attribute) ?? false);

/// [widget] as the `Widget.element` it is, with each of its children replaced
/// by what [replace] makes of it; null when it is not one. How a container
/// that wraps what it holds (a list's items) reaches the items of a row
/// template, which a `Watch.list` hands over as an element.
Widget? mapElementChildren(
  Widget widget,
  Widget Function(Widget child) replace,
) => widget is _ElementComponent
    ? Widget.element(
        key: widget.key,
        tag: widget.tag,
        id: widget.id,
        classes: widget.classes,
        styles: widget.styles,
        attributes: widget.attributes,
        children: [
          for (final c in widget.children ?? const <Widget>[]) replace(c),
        ],
      )
    : null;

final class _FragmentComponent extends Widget {
  const _FragmentComponent(this.children, {super.key});
  const _FragmentComponent._empty({super.key}) : children = const [];
  final List<Widget> children;
}

final class _WrapComponent extends Widget {
  const _WrapComponent({
    super.key,
    this.tag,
    this.id,
    this.classes,
    this.styles,
    this.attributes,
    required this.child,
  });

  final String? tag;
  final String? id;
  final String? classes;
  final Styles? styles;
  final Map<String, String>? attributes;
  final Widget child;
}

/// Elements whose tag a wrapper never replaces (an icon's `svg`, an image,
/// a control): `Link` around them can't turn them into an `<a>`.
const wrapKeepsTag = {
  'svg', 'img', 'picture', 'video', 'audio', 'iframe', 'canvas', //
  'input', 'textarea', 'select', 'button', 'a',
};

/// Wrappers waiting for the next element, innermost first.
final class _Wraps {
  const _Wraps(this.wrap, this.outer);
  final _WrapComponent wrap;
  final _Wraps? outer;
}

/// A widget whose build is done by the page (the document's `<head>`
/// portal): it gets its element and the node it builds into.
abstract class PageComponent extends Widget {
  /// A widget the page builds itself.
  const PageComponent({super.key});

  /// Builds this widget of [page] at [element] into [into]; [build]
  /// builds a child.
  void buildInto(
    PageBuild page,
    Element element,
    ParentNode into,
    BuildChild build,
  );
}

/// Where a [ReplayableWidget] gets its node: one built before, or
/// [build]'s. [wrapped]: wrappers above (`Widget.wrapElement`) wait for the
/// first element below, so the child's nodes would carry them. [build]
/// builds the child into a new fragment and says whether it added `<head>`
/// content.
typedef ReplayOrBuild =
    Node Function(
      Element element, {
      required bool wrapped,
      required ({FragmentNode node, bool head}) Function() build,
    });

/// A [child] built into a fragment of its own, which [replayOrBuild] may
/// keep and add again, as it is, to later pages (`Cached`).
///
/// A kept fragment is shared: nothing may change its nodes after they are
/// built (no `<head>` portal inside, no `<html>`/`<head>`/`<body>`).
final class ReplayableWidget extends Widget {
  /// [child], built or replayed by [replayOrBuild].
  const ReplayableWidget({
    super.key,
    required this.child,
    required this.replayOrBuild,
  });

  /// What is built below this widget.
  final Widget child;

  /// Returns the node to add (see [ReplayOrBuild]).
  final ReplayOrBuild replayOrBuild;
}

/// Builds a [SubtreeMemo] candidate's child into a new fragment and says
/// what the memo needs to decide whether the fragment can be kept:
/// `head` (it added `<head>` content), `sideEffects` (a `State`, a page
/// component or `<html>` attributes: effects a kept fragment would not
/// repeat) and the `dependencies` (the inherited elements above the
/// candidate that something inside read, nearest lookups first).
typedef MemoBuild =
    ({
      FragmentNode node,
      bool head,
      bool sideEffects,
      List<InheritedElement> dependencies,
    })
    Function();

/// The memo of `const` subtrees: asked for every
/// [StatelessWidget] built without wrappers waiting above it. Returns the
/// node to add (kept from an earlier page, or the `build` callback's), or
/// null to let the page build the widget as usual — then that callback
/// must not have been called.
abstract interface class SubtreeMemo {
  /// The node for [widget] at [element] of [page], or null.
  Node? replayOrBuild(
    PageBuild page,
    Element element,
    StatelessWidget widget,
    MemoBuild build,
  );
}

/// The inherited elements read while a [SubtreeMemo] candidate is built,
/// the ones above it only; recordings nest.
final class _MemoRecording {
  _MemoRecording(this.rootDepth, this.parent);

  static _MemoRecording? _current;

  final int rootDepth;
  final _MemoRecording? parent;
  final dependencies = <Type, InheritedElement>{};
  bool sideEffects = false;

  static void noteDependency(InheritedElement found) {
    for (var r = _current; r != null; r = r.parent) {
      if (found.depth < r.rootDepth) {
        r.dependencies.putIfAbsent(found.widget.runtimeType, () => found);
      }
    }
  }

  static void noteSideEffect() {
    for (var r = _current; r != null; r = r.parent) {
      r.sideEffects = true;
    }
  }
}

/// What a [StatelessWidget] builds, known before the page builds it: an
/// app component is transparent to the decisions its
/// parent makes by type (whether it fills the width, whether its first
/// element is a thor element, a `Text` a box can render itself…).
///
/// [widget] is built with the context of the widget being built now (its
/// parent's, with the same inherited widgets above); null when nothing is
/// being built or its build throws there (the page then builds it as
/// usual, and a real error surfaces in its place). A preview is kept for
/// the page: when the page reaches [widget] and every inherited widget
/// its build read is the same one there, the page uses the preview
/// instead of building it again, so a component is built once. It is used
/// once: the same `const` widget in another place is built there.
Widget? previewBuild(StatelessWidget widget) {
  final page = PageBuild._active;
  final parent = PageBuild._building;
  if (page == null || parent == null) return null;
  final known = page._previews[widget];
  if (known != null) {
    // One that can't be previewed isn't tried again on this page.
    if (known.output == null ||
        known.parent == parent ||
        known.readsSameAt(parent._inherited)) {
      return known.output;
    }
  }
  final element = Element._(widget, parent, parent._inherited);
  final recording = _Preview._recording = _PreviewRecording(
    _Preview._recording,
  );
  final Widget output;
  try {
    PageBuild._building = element;
    output = widget.build(element);
  } catch (_) {
    page._previews[widget] = _Preview(parent, null, const {}, reusable: false);
    return null;
  } finally {
    PageBuild._building = parent;
    _Preview._recording = recording.parent;
  }
  // A lookup read in the preview also counts for an outer preview.
  if (recording.parent case final outer?) {
    outer.ancestors |= recording.ancestors;
  }
  page._previewed++;
  page._previews[widget] = _Preview(
    parent,
    output,
    recording.reads ?? const {},
    reusable: !recording.ancestors,
  );
  return output;
}

/// The context of the widget being built now (or previewed), or null
/// outside a build: for a decision a widget's parent makes about it
/// without a context of its own, such as whether a box can render a
/// `Text` child itself. Its lookups count like the build's own.
BuildContext? buildingContext() => PageBuild._building;

/// Tells a running [previewBuild] that the build reaches for the page
/// itself (its stylesheet registry: an id, the engine, a class): a preview
/// must not do that twice, or in another order, so it is dropped and the
/// widget is built only at its place (opaque to its parent). Nothing
/// happens outside a preview.
void notePageAccess() {
  if (_Preview._recording != null) throw const _PreviewDropped();
}

final class _PreviewDropped implements Exception {
  const _PreviewDropped();
}

/// A [previewBuild] of one widget on one page.
final class _Preview {
  _Preview(this.parent, this.output, this.reads, {required this.reusable});

  static _PreviewRecording? _recording;

  /// The element whose context it was built with.
  final Element parent;

  /// Null: the build can't be previewed here (it threw, or it reached for
  /// the page).
  final Widget? output;

  /// Each inherited type its build looked up, with what it found.
  final Map<Type, InheritedElement?> reads;

  /// Whether the page may use [output] (a build that walked its
  /// ancestors saw the preview's, not the real ones).
  final bool reusable;

  static void noteRead(Type type, InheritedElement? found) {
    for (var r = _recording; r != null; r = r.parent) {
      (r.reads ??= {}).putIfAbsent(type, () => found);
    }
  }

  static void noteAncestors() {
    for (var r = _recording; r != null; r = r.parent) {
      r.ancestors = true;
    }
  }

  /// Whether each lookup of the build finds the same element below
  /// [inherited].
  bool readsSameAt(_Inherited? inherited) {
    for (final e in reads.entries) {
      if (!identical(inherited?.lookup(e.key), e.value)) return false;
    }
    return true;
  }
}

final class _PreviewRecording {
  _PreviewRecording(this.parent);
  final _PreviewRecording? parent;
  // Most builds look nothing up: made on the first lookup.
  Map<Type, InheritedElement?>? reads;
  bool ancestors = false;
}

/// Builds [child] below [parent] into [into]. With [bare] the wrappers waiting
/// above for the next element (`Expanded`, `Padding`, a `Hero`…) are not
/// handed to it: what a page component draws for itself and that is not the
/// widget the wrappers decorate (a `<template>` with a drag's feedback)
/// is built bare.
typedef BuildChild =
    void Function(Widget child, Element parent, ParentNode into, {bool bare});

/// One page being built: the build pass and what runs when it is done.
class PageBuild {
  /// The memo of `const` subtrees, when it is on ([SubtreeMemo]).
  static SubtreeMemo? subtreeMemo;

  /// When set, every widget that builds into an element is recorded in it
  /// and the element is marked with [WidgetTrace.attribute]: what
  /// `find.byType` and `find.byKey` of `thor_test` read. Off (null) in
  /// every real render: it costs nothing and writes nothing.
  ///
  /// Global to the isolate and set across an await: `renderHtmlTraced` must
  /// not overlap another render in the same isolate.
  static WidgetTrace? trace;

  static int _serials = 0;

  /// The page being built and the element whose build runs now (what a
  /// [previewBuild] builds with).
  static PageBuild? _active;
  static Element? _building;

  /// This page's [previewBuild]s, by widget, and how many were made.
  // An identity map, not an `Expando`: looked up for most widgets of the
  // page, and it lives only as long as the page.
  final _previews = HashMap<Widget, _Preview?>.identity();
  int _previewed = 0;

  /// This page among the pages the process built (1, 2…): a widget seen in
  /// an earlier page's build is the same instance on every page.
  final int serial = ++_serials;

  /// Tells the recordings around a kept fragment that it read
  /// [dependencies] (the ones found at this page's place): replaying it
  /// reads nothing, yet a fragment around it depends on them too.
  static void noteReplayedDependencies(
    Iterable<InheritedElement> dependencies,
  ) {
    if (_MemoRecording._current == null) return;
    for (final d in dependencies) {
      _MemoRecording.noteDependency(d);
    }
  }

  final List<State> _states = [];

  /// The `<head>` portals built, in build order (see `document.dart`).
  final List<({FragmentNode node, ParentNode parent, int depth, bool leading})>
  headPortals = [];

  /// Attributes for the page's `<html>` (see `document.dart`).
  final Map<String, String> htmlAttributes = {};

  /// Builds [root] into [into].
  ///
  /// A tree deeper than the stack fails with THOR-R020 (its depth and the
  /// two ends of its chain) instead of a stack overflow with thousands of
  /// frames. web: the build is recursive; a few thousand levels is the
  /// limit (about 2400 `Container`s in release).
  void buildRoot(Widget root, ParentNode into) {
    final active = _active, building = _building;
    _active = this;
    _building = null;
    try {
      _build(root, null, null, null, into);
      // A stack overflow is the only Error worth turning into a message:
      // the stack is unwound here, so describing the chain is safe.
      // ignore: avoid_catching_errors
    } on StackOverflowError {
      throw StateError(_tooDeep());
    } finally {
      _at = null;
      _active = active;
      _building = building;
    }
  }

  /// The parent of the widget being built: the deepest element after a
  /// stack overflow.
  Element? _at;

  String _tooDeep() {
    final chain = <String>[];
    for (Element? e = _at; e != null; e = e.parent) {
      final w = e.widget;
      chain.add(w is _ElementComponent ? '<${w.tag}>' : '${w.runtimeType}');
    }
    final depth = chain.length;
    final path = chain.reversed.toList();
    final shown = depth <= 12
        ? path.join(' > ')
        : '${path.take(6).join(' > ')} > … > ${path.skip(depth - 6).join(' > ')}';
    return thorError(
      'THOR-R020',
      'the widget tree is too deep to render: the stack ran out '
          '$depth elements deep ($shown). Build long sequences as a list of children, not '
          'nested widgets.',
    );
  }

  /// What [component] builds at [element]: its [previewBuild] when the
  /// build read the same inherited widgets there, or a new build.
  Widget _buildStateless(StatelessWidget component, Element element) {
    _building = element;
    // Most widgets were never previewed: no lookup until one was.
    if (_previewed == 0) return component.build(element);
    final preview = _previews[component];
    final output = preview?.output;
    if (output != null &&
        preview!.reusable &&
        (identical(preview.parent, element.parent) ||
            preview.readsSameAt(element._inherited))) {
      // Used once: the same (`const`) widget elsewhere on the page is built
      // there, so what its build asks of the page (an id) stays unique.
      _previews.remove(component);
      // Its reads count where it is used (the memo of `const` subtrees).
      if (_MemoRecording._current != null) {
        for (final found in preview.reads.values) {
          if (found != null) _MemoRecording.noteDependency(found);
        }
      }
      return output;
    }
    return component.build(element);
  }

  /// Runs [body] as part of this page after it was written: what a widget
  /// that builds later does (a deferred value, `FutureBuilder`, through the
  /// `build` its [PageComponent] was given). The [State]s [body] creates are
  /// disposed when it ends.
  R late<R>(R Function() body) {
    final active = _active, building = _building;
    _active = this;
    _building = null;
    try {
      return body();
    } finally {
      _at = null;
      _active = active;
      _building = building;
      dispose();
    }
  }

  /// Disposes every [State] the page created, in build order.
  void dispose() {
    for (final state in _states) {
      state
        .._disposed = true
        ..dispose()
        .._element = null;
    }
    _states.clear();
  }

  void _build(
    Widget component,
    Element? parent,
    _Inherited? inherited,
    _Wraps? wraps,
    ParentNode into,
  ) {
    final trace = PageBuild.trace;
    if (trace == null && !ThorInspect.enabled) {
      return _buildNode(component, parent, inherited, wraps, into);
    }
    if (component is _ElementComponent) {
      // Dev only: the child sites of this element start from its own path.
      final path = _path;
      _buildNode(component, parent, inherited, wraps, into);
      _path = path;
      return;
    }
    final before = into.children.length;
    final path = _path;
    _buildNode(component, parent, inherited, wraps, into);
    _path = path;
    if (trace != null) {
      trace._mark(component, into, before);
    } else {
      WidgetTrace._markNamed(component, into, before);
    }
  }

  /// Dev only (`ThorInspect.enabled`): the place of the component being
  /// built in the widget tree of the app code that builds it, as
  /// `data-thor-at` writes it. Root of the page: `0`.
  String _path = '0';

  void _buildNode(
    Widget component,
    Element? parent,
    _Inherited? inherited,
    _Wraps? wraps,
    ParentNode into,
  ) {
    _at = parent;
    switch (component) {
      case _ElementComponent():
        into.add(_element(component, wraps));
        final node = into.last as ElementNode;
        final source = parent?._source;
        final at = ThorInspect.enabled ? _path : null;
        if (source != null) {
          node.attributes = {
            ...?node.attributes,
            inspectSourceAttribute: source,
            inspectAtAttribute: ?at,
          };
        }
        final children = component.children;
        if (children != null && children.isNotEmpty) {
          final element = Element._(component, parent, inherited);
          var i = 0;
          for (final child in children) {
            if (at != null) _path = '$at.${i++}';
            // The element takes the wrappers: its children start clean.
            _build(child, element, inherited, null, node);
          }
        }
      case _TextComponent(:final text):
        checkNoRowBindMarker(text, 'in a text');
        into.add(TextNode(text));
      case RawText(:final text):
        into.add(TextNode(text, raw: true));
      case _FragmentComponent(:final children):
        final fragment = FragmentNode();
        into.add(fragment);
        final element = Element._(component, parent, inherited);
        final at = ThorInspect.enabled ? _path : null;
        var i = 0;
        for (final child in children) {
          if (at != null) _path = '$at.${i++}';
          _build(child, element, inherited, wraps, fragment);
        }
      case _WrapComponent():
        final element = Element._(component, parent, inherited);
        _build(
          component.child,
          element,
          inherited,
          _Wraps(component, wraps),
          into,
        );
      case StatelessWidget():
        final element = Element._(component, parent, inherited);
        if (ThorInspect.enabled) {
          final source = ThorInspect.sourceOf(switch (component) {
            final InspectSourceOwner owner => owner.inspectSource,
            _ => component.runtimeType,
          });
          if (source != null) {
            element._source = source;
            _path = '$_path/0';
          }
        }
        final memo = subtreeMemo;
        final kept =
            memo == null ||
                wraps != null ||
                ThorInspect.enabled ||
                PageBuild.trace != null
            ? null
            : _replayOrBuild(memo, element, component, inherited);
        if (kept != null) {
          into.add(kept);
        } else {
          _build(
            _buildStateless(component, element),
            element,
            inherited,
            wraps,
            into,
          );
        }
      case InheritedWidget():
        final element = InheritedElement._(component, parent, inherited);
        _building = element;
        _build(
          component.buildChild(element),
          element,
          _Inherited(element, inherited),
          wraps,
          into,
        );
      case StatefulWidget():
        if (_MemoRecording._current != null) _MemoRecording.noteSideEffect();
        final element = Element._(component, parent, inherited);
        final state = component.createState()
          .._widget = component
          .._element = element;
        _states.add(state);
        if (ThorInspect.enabled) {
          final source = ThorInspect.sourceOf(state.runtimeType);
          if (source != null) {
            element._source = source;
            _path = '$_path/0';
          }
        }
        _building = element;
        state
          ..initState()
          ..didChangeDependencies();
        _build(state.build(element), element, inherited, wraps, into);
      case ReplayableWidget():
        into.add(_replayable(component, parent, inherited, wraps));
      case PageComponent():
        if (_MemoRecording._current != null) _MemoRecording.noteSideEffect();
        _buildPageComponent(component, parent, inherited, wraps, into);
      default:
        throw UnsupportedError(
          thorError(
            'THOR-R001',
            'thor cannot build a ${component.runtimeType}: extend '
                'StatelessWidget, StatefulWidget or InheritedWidget.',
          ),
        );
    }
  }

  // The cases of [_buildNode] that hand a closure on: apart, so the closure's
  // context is allocated only for them, not for every node of every page.

  Node? _replayOrBuild(
    SubtreeMemo memo,
    Element element,
    StatelessWidget component,
    _Inherited? inherited,
  ) => memo.replayOrBuild(
    this,
    element,
    component,
    () => _buildForMemo(component, element, inherited),
  );

  Node _replayable(
    ReplayableWidget component,
    Element? parent,
    _Inherited? inherited,
    _Wraps? wraps,
  ) {
    final element = Element._(component, parent, inherited);
    return component.replayOrBuild(
      element,
      wrapped: wraps != null,
      build: () {
        final node = FragmentNode();
        final portals = headPortals.length;
        _build(component.child, element, inherited, wraps, node);
        return (node: node, head: headPortals.length != portals);
      },
    );
  }

  void _buildPageComponent(
    PageComponent component,
    Element? parent,
    _Inherited? inherited,
    _Wraps? wraps,
    ParentNode into,
  ) {
    final element = Element._(component, parent, inherited);
    component.buildInto(
      this,
      element,
      into,
      (child, parent, into, {bool bare = false}) =>
          _build(child, parent, parent._inherited, bare ? null : wraps, into),
    );
  }

  ({
    FragmentNode node,
    bool head,
    bool sideEffects,
    List<InheritedElement> dependencies,
  })
  _buildForMemo(
    StatelessWidget component,
    Element element,
    _Inherited? inherited,
  ) {
    final node = FragmentNode();
    final portals = headPortals.length;
    final attributes = htmlAttributes.length;
    final recording = _MemoRecording._current = _MemoRecording(
      element.depth,
      _MemoRecording._current,
    );
    try {
      _build(
        _buildStateless(component, element),
        element,
        inherited,
        null,
        node,
      );
    } finally {
      _MemoRecording._current = recording.parent;
    }
    final sideEffects =
        recording.sideEffects || htmlAttributes.length != attributes;
    if (sideEffects && recording.parent != null) {
      _MemoRecording.noteSideEffect();
    }
    return (
      node: node,
      head: headPortals.length != portals,
      sideEffects: sideEffects,
      dependencies: recording.dependencies.values.toList(),
    );
  }

  /// The element node of [component], with the wrappers above it merged
  /// from the outermost in; the widget's own values win.
  static ElementNode _element(_ElementComponent component, _Wraps? wraps) {
    if (wraps == null) {
      return ElementNode(
        component.tag,
        id: component.id,
        classes: component.classes,
        styles: component.styles?.properties,
        attributes: component.attributes,
      );
    }
    final chain = <_WrapComponent>[
      for (_Wraps? w = wraps; w != null; w = w.outer) w.wrap,
    ];
    String? tag;
    String? id;
    String? classes;
    Map<String, String>? styles;
    Map<String, String>? attributes;
    for (final wrap in chain.reversed) {
      tag = wrap.tag ?? tag;
      id = wrap.id ?? id;
      classes = _join(classes, wrap.classes);
      styles = _merge(styles, wrap.styles?.properties);
      attributes = _merge(attributes, wrap.attributes);
    }
    var mergedStyles = _merge(styles, component.styles?.properties);
    var mergedAttributes = _merge(attributes, component.attributes);
    // A `style` attribute (a bound variable's first value, a view transition
    // name) next to inline styles would be a second `style=""` the browser
    // drops: it joins them, as `thorElement` does.
    final extra = mergedAttributes?['style'];
    if (mergedStyles != null && mergedAttributes != null && extra != null) {
      mergedAttributes = {...mergedAttributes}..remove('style');
      mergedStyles = {
        ...mergedStyles,
        for (final part in extra.split(';'))
          if (part.contains(':'))
            part.substring(0, part.indexOf(':')).trim(): part
                .substring(part.indexOf(':') + 1)
                .trim(),
      };
    }
    return ElementNode(
      tag == null || wrapKeepsTag.contains(component.tag) ? component.tag : tag,
      id: component.id ?? id,
      classes: _join(classes, component.classes),
      styles: mergedStyles,
      attributes: mergedAttributes,
    );
  }

  static String? _join(String? a, String? b) =>
      a == null ? b : (b == null ? a : '$a $b');

  /// [b] over [a]; a key of both keeps [a]'s position.
  static Map<String, String>? _merge(
    Map<String, String>? a,
    Map<String, String>? b,
  ) {
    if (a == null || a.isEmpty) return b;
    if (b == null || b.isEmpty) return a;
    return {...a, ...b};
  }
}

/// The widget types from the page root down to [element] (its own
/// included), computed once per element and shared with the elements
/// below: what a place is when `Cached` keys a fragment by it.
TypePath typePathOf(Element element) => element._typePath ??= TypePath._of(
  element.parent == null ? null : typePathOf(element.parent!),
  element.widget.runtimeType,
);

/// A path of widget types, canonical per process: two paths with the same
/// types level by level are the same object, so a place compares and
/// hashes by identity instead of walking the tree.
final class TypePath {
  TypePath._(this.parent, this.type);

  /// The path above, or null at the root.
  final TypePath? parent;

  /// The widget type at this level.
  final Type type;

  static final _paths = <(TypePath?, Type), TypePath>{};

  static TypePath _of(TypePath? parent, Type type) {
    // Bounded (paths come from the app's code, but recursive data can make
    // deep ones): a path made again after a clear is a new object, so a
    // place that compared equal before only misses, never matches wrong.
    if (_paths.length >= 1 << 16) _paths.clear();
    return _paths[(parent, type)] ??= TypePath._(parent, type);
  }
}

/// The widgets that built each element of a page (see `renderHtmlTraced`):
/// a test tool, since the HTML does not say which widget wrote an element.
final class WidgetTrace {
  /// The attribute that lists, on an element, the indexes in [widgets] of
  /// the widgets that built it (space separated, innermost first).
  static const attribute = 'data-thor-w';

  /// The widgets seen, in build order.
  final widgets = <({Type type, Key? key})>[];

  void _mark(Widget widget, ParentNode into, int before) {
    final node = _firstElement(into, before);
    if (node == null) return;
    final index = widgets.length;
    widgets.add((type: widget.runtimeType, key: widget.key));
    final current = node.attributes?[attribute];
    node.attributes = {
      ...?node.attributes,
      attribute: current == null ? '$index' : '$current $index',
    };
  }

  /// Dev only: [widget]'s type name on the first element it built, in the
  /// live pages of `thor dev` (`data-thor-w="Text Padding Expanded"`,
  /// innermost first), so a fused wrapper that has no node of its own can
  /// still be read from the DOM.
  static void _markNamed(Widget widget, ParentNode into, int before) {
    final node = _firstElement(into, before);
    if (node == null) return;
    final name = _names[widget.runtimeType] ??= '${widget.runtimeType}';
    final current = node.attributes?[attribute];
    node.attributes = {
      ...?node.attributes,
      attribute: current == null ? name : '$current $name',
    };
  }

  static final _names = <Type, String>{};

  static ElementNode? _firstElement(ParentNode parent, int from) {
    for (var i = from; i < parent.children.length; i++) {
      final child = parent.children[i];
      if (child is ElementNode) return child;
      if (child is FragmentNode) {
        final inner = _firstElement(child, 0);
        if (inner != null) return inner;
      }
    }
    return null;
  }
}
