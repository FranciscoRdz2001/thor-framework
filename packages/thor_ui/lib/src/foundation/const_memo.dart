import '../core/core.dart';
import '../core/framework.dart'
    show MemoBuild, PageBuild, StatelessWidget, SubtreeMemo;
import '../core/markup.dart';
import 'child_rules.dart';
import 'errors.dart';
import 'style_registry.dart';

/// What the memo of `const` subtrees does.
enum ConstMemoMode {
  /// Every widget is built on every page (the default).
  off,

  /// A `const` widget's subtree, built once on an earlier page, is added
  /// again as it is.
  on,

  /// Like [on], and every reuse is built again and compared: a `const`
  /// widget whose build reads something else than its fields and the
  /// inherited widgets above it (a global, the clock) is THOR-R017. For
  /// tests and `thor dev`, never production (it costs a build per reuse).
  verify,
}

/// The memo of `const` subtrees: the HTML of a [StatelessWidget]
/// that is the same instance on every page (a `const` widget) is built
/// once and added again as it is, with the classes, keyframes and symbols
/// it registered.
///
/// The contract:
///
/// - **A candidate** is a [StatelessWidget] instance already built on an
///   earlier page of the process, with no wrapper (`Padding`,
///   `Expanded`…) waiting above it. Its second page records it; the third
///   and later can reuse it.
/// - **Its key** is the instance, the types of the widgets above it and
///   every inherited widget above that something inside read, compared by
///   [InheritedMemoKey.memoKey] or else by identity. A request, a route
///   or a scope made per page (compared by identity) never matches: those
///   subtrees are always built.
/// - **Never kept**: a subtree that uses a `ThorState`, generates page ids,
///   is named after the page's components (debug), puts content in
///   `<head>`, sets `<html>` attributes, holds a `StatefulWidget` or
///   `<html>`/`<head>`/`<body>`, or has fewer than [minNodes] nodes.
/// - **Pure builds**: a `const` widget's build must depend only on its
///   fields and on inherited widgets. Dart cannot check it; a build that
///   reads a global, the clock or a singleton gives stale HTML.
///   [ConstMemoMode.verify] finds them.
///
/// Off by default: measured, it saves almost nothing on pages served per
/// request (whose `const` subtrees read the route or a `ThorState`) and
/// only pays off on pure pages built once. `THOR_CONST_MEMO` (`on`,
/// `verify`) sets [mode] at startup.
///
/// `// web:` Flutter has no equivalent (it never renders HTML twice).
abstract final class ConstMemo {
  static ConstMemoMode _mode = ConstMemoMode.off;

  /// Whether the memo is on and how.
  static ConstMemoMode get mode => _mode;
  static set mode(ConstMemoMode mode) {
    _mode = mode;
    _install();
  }

  /// Fewest nodes a subtree needs to be kept (smaller ones cost less to
  /// build than to look up).
  static int minNodes = 12;

  /// Most subtrees kept per process (the least recently used go first).
  static int maxEntries = 2000;

  /// Drops every kept subtree (a `thor dev` reload does).
  static void clear() {
    _entries.clear();
    _verdicts = Expando();
    _byWidget = Expando();
    _types.clear();
  }

  /// Number of subtrees kept (tests, monitoring).
  static int get length => _entries.length;

  // Hooks the memo into the page build (idempotent): what the `mode`
  // setter calls.
  static void _install() {
    PageBuild.subtreeMemo = _mode == ConstMemoMode.off ? null : _memo;
  }

  static const _memo = _ConstMemo();

  /// Kept subtrees, least recently used first.
  static final _entries = <_Entry, _Entry>{};

  /// Widgets never kept (too small, or with effects a replay would miss).
  static Expando<bool> _verdicts = Expando();

  /// Per widget type, the instances found the same on two pages.
  static final _types = <Type, _TypeState>{};

  /// The kept entries of each widget instance.
  static Expando<List<_Entry>> _byWidget = Expando();
}

final class _TypeState {
  StatelessWidget? last;
  int lastPage = 0;
  final candidates = <StatelessWidget>[];
}

final class _Entry {
  _Entry(this.widget, this.above, this.dependencies, this.node, this.record);

  final StatelessWidget widget;
  final List<Type> above;

  /// Each inherited type read, with what its readers saw.
  final List<(Type, Object?, bool)> dependencies;
  final FragmentNode node;
  final FragmentRecord record;
}

final class _ConstMemo implements SubtreeMemo {
  const _ConstMemo();

  @override
  Node? replayOrBuild(
    PageBuild page,
    Element element,
    StatelessWidget widget,
    MemoBuild build,
  ) {
    if (!_isCandidate(page, widget)) return null;
    if (ConstMemo._verdicts[widget] == true) return null;
    if (ChildRulesScope.maybeOf(element)?.pending != null) return null;
    final registry = ThorStyleRegistry.active(element);
    if (registry == null) return null;

    final above = _above(element);
    final entries = ConstMemo._byWidget[widget];
    if (entries != null) {
      for (final entry in entries) {
        final current = _matches(entry, element, above);
        if (current == null) continue;
        if (!replayFragmentRecord(registry, entry.record)) break;
        PageBuild.noteReplayedDependencies(current);
        ConstMemo._entries
          ..remove(entry)
          ..[entry] = entry; // most recently used
        if (ConstMemo._mode == ConstMemoMode.verify) {
          _verify(entry, build);
        }
        return entry.node;
      }
    }

    beginFragmentRecord(registry);
    final ({
      FragmentNode node,
      bool head,
      bool sideEffects,
      List<InheritedElement> dependencies,
    })
    built;
    try {
      built = build();
    } catch (_) {
      endFragmentRecord(registry);
      rethrow;
    }
    // Also counts for any recording around this one.
    final record = endFragmentRecord(registry);
    if (record.usedState ||
        !record.replayable ||
        built.head ||
        built.sideEffects ||
        _hasDocumentElement(built.node) ||
        _size(built.node, ConstMemo.minNodes) < ConstMemo.minNodes) {
      ConstMemo._verdicts[widget] = true;
      return built.node;
    }
    _keep(
      _Entry(
        widget,
        above,
        [
          for (final d in built.dependencies)
            if (_keyOf(d.widget) case (final key, final byValue))
              (d.widget.runtimeType, key, byValue),
        ],
        built.node..kept = true,
        record,
      ),
    );
    return built.node;
  }

  /// Whether [widget] is the same instance it was on an earlier page. Per
  /// type, the last instance built and the ones already found the same:
  /// a widget made anew for every page (most of them) costs one lookup,
  /// never an entry of its own.
  static bool _isCandidate(PageBuild page, StatelessWidget widget) {
    final type = ConstMemo._types[widget.runtimeType] ??= _TypeState();
    for (final known in type.candidates) {
      if (identical(known, widget)) return true;
    }
    if (identical(type.last, widget) && type.lastPage != page.serial) {
      if (type.candidates.length < _candidatesPerType) {
        type.candidates.add(widget);
      }
      return true;
    }
    type
      ..last = widget
      ..lastPage = page.serial;
    return false;
  }

  static const _candidatesPerType = 32;

  /// The dependencies of [entry] found at [element] when every one gives
  /// readers what it gave when [entry] was built; null otherwise.
  static List<InheritedElement>? _matches(
    _Entry entry,
    Element element,
    List<Type> above,
  ) {
    if (!_sameTypes(entry.above, above)) return null;
    final found = <InheritedElement>[];
    for (final (type, key, byValue) in entry.dependencies) {
      final current = element.inheritedElementOfType(type);
      if (current == null) return null;
      final (now, nowByValue) = _keyOf(current.widget);
      if (nowByValue != byValue) return null;
      if (byValue ? now != key : !identical(now, key)) return null;
      found.add(current);
    }
    return found;
  }

  static (Object?, bool) _keyOf(InheritedWidget widget) =>
      widget is InheritedMemoKey
      ? ((widget as InheritedMemoKey).memoKey, true)
      : (widget, false);

  static void _keep(_Entry entry) {
    while (ConstMemo._entries.length >= ConstMemo.maxEntries &&
        ConstMemo._entries.isNotEmpty) {
      final old = ConstMemo._entries.keys.first;
      ConstMemo._entries.remove(old);
      ConstMemo._byWidget[old.widget]?.remove(old);
    }
    if (ConstMemo.maxEntries <= 0) return;
    ConstMemo._entries[entry] = entry;
    (ConstMemo._byWidget[entry.widget] ??= []).add(entry);
  }

  /// Builds [entry]'s widget again and compares: a difference is a build
  /// that reads more than its fields and inherited widgets.
  static void _verify(_Entry entry, MemoBuild build) {
    // Registering the same classes again changes nothing on the page.
    final fresh = build();
    final a = writePage(RootNode()..add(entry.node), compact: true);
    final b = writePage(RootNode()..add(fresh.node), compact: true);
    if (a != b) {
      throw StateError(
        thorError(
          'THOR-R017',
          'const ${entry.widget.runtimeType} built different HTML on two '
              'pages with the same inherited widgets: its build reads '
              'something else (a global, the clock, a singleton). Take the '
              'value as a field, or build it without const.',
        ),
      );
    }
  }

  static List<Type> _above(Element element) {
    final above = <Type>[];
    element.visitAncestorElements((e) {
      above.add(e.widget.runtimeType);
      return true;
    });
    return above;
  }

  static bool _sameTypes(List<Type> a, List<Type> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Nodes in [node], counting up to [limit].
  static int _size(ParentNode node, int limit) {
    var count = 0;
    void visit(ParentNode parent) {
      for (final child in parent.children) {
        if (++count >= limit) return;
        if (child is ParentNode) visit(child);
        if (count >= limit) return;
      }
    }

    visit(node);
    return count;
  }

  static bool _hasDocumentElement(ParentNode node) {
    for (final child in node.children) {
      if (child is ElementNode &&
          const {'html', 'head', 'body'}.contains(child.tag.toLowerCase())) {
        return true;
      }
      if (child is ParentNode && _hasDocumentElement(child)) return true;
    }
    return false;
  }
}
