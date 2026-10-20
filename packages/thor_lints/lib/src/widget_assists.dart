import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' show SourceEdit;
import 'widget_edits.dart';

export 'widget_edits.dart' show Wrapper;

/// The library an app imports thor's widgets from.
const thorUiLibrary = 'package:thor_ui/thor_ui.dart';

// Priorities as Flutter's: the generic wrap first, then the named wraps,
// then the structural edits.
const _wrapGenericPriority = 31;
const _structurePriority = 29;

/// Whether [type] is thor_ui's `Widget` or a subclass of it (the app's own
/// widgets included).
bool isThorWidgetType(DartType? type) {
  if (type is! InterfaceType) return false;
  bool isWidget(InterfaceType t) =>
      t.element.name == 'Widget' &&
      t.element.library.uri.toString().startsWith('package:thor_ui/');
  return isWidget(type) || type.allSupertypes.any(isWidget);
}

/// The thor widget created where the caret is: on its constructor name
/// (`Padding`, `Text.rich`, `ui.Text`), its `const`/`new` keyword or just
/// before its `(`.
InstanceCreationExpression? thorWidgetAt(AstNode node, int offset) {
  AstNode? n = node;
  if (n is ArgumentList && n.offset == offset) n = n.parent;
  while (n != null && n is! InstanceCreationExpression) {
    if (n is! NamedType &&
        n is! ConstructorName &&
        n is! SimpleIdentifier &&
        n is! ImportPrefixReference &&
        n is! TypeArgumentList) {
      return null;
    }
    n = n.parent;
  }
  if (n is! InstanceCreationExpression) return null;
  // Inside the arguments is another widget's (or no widget's) business.
  if (offset > n.argumentList.offset) return null;
  return isThorWidgetType(n.staticType) ? n : null;
}

/// The named argument [name] (`child`, `children`) of [creation].
NamedExpression? namedArgument(
  InstanceCreationExpression creation,
  String name,
) {
  return namedArgumentOf(creation.argumentList, name);
}

/// Base of the widget assists: finds the widget under the caret and
/// offers helpers to write thor classes and re-indent source.
abstract class _WidgetAssist extends ResolvedCorrectionProducer {
  _WidgetAssist({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  /// The thor widget under the caret.
  InstanceCreationExpression? get widget => thorWidgetAt(node, selectionOffset);

  /// The widget under the caret as a [WidgetCall].
  WidgetCall? get call {
    final w = widget;
    return w == null
        ? null
        : WidgetCall.of(w, inConstantContext: w.inConstantContext);
  }

  /// The source with this file's line ending and indentation, for the pure
  /// edit functions in widget_edits.dart.
  EditContext get edits => EditContext(
    unitResult.content,
    unitResult.unit,
    EditStyle(eol: utils.endOfLine, indent: utils.oneIndent),
  );

  /// Applies [edits] to the file; when [linked] is a token in a
  /// replacement, the user types over it.
  void _apply(
    DartFileEditBuilder b,
    List<SourceEdit> edits, {
    String? linked,
    String group = 'LINKED',
  }) {
    for (final e in edits) {
      final span = SourceRange(e.offset, e.length);
      final at = linked == null ? -1 : e.replacement.indexOf(linked);
      if (at < 0) {
        b.addSimpleReplacement(span, e.replacement);
        continue;
      }
      b.addReplacement(span, (b) {
        b.write(e.replacement.substring(0, at));
        b.addSimpleLinkedEdit(group, linked!);
        b.write(e.replacement.substring(at + linked.length));
      });
    }
  }

  /// The thor_ui prefix to write [names] with (`''` or `'ui.'`); writing
  /// it imports thor_ui when the file doesn't, or shows the one name its
  /// import lacks. `null` when the app doesn't depend on thor_ui or the
  /// import can't take the names (a prefix, or several names to show).
  Future<String Function(DartFileEditBuilder)?> _thorPrefix(
    List<String> names,
  ) async {
    final cls = await sessionHelper.getClass(thorUiLibrary, names.first);
    if (cls == null) return null;
    String? prefix;
    final visible = <String>{};
    for (final import in unitResult.libraryFragment.libraryImports) {
      final name = import.prefix?.name;
      Object? lookup(String n) => name == null
          ? import.namespace.get2(n)
          : import.namespace.getPrefixed2(name, n);
      if (lookup(names.first) == cls) {
        prefix = name == null ? '' : '$name.';
        visible.addAll(names.where((n) => lookup(n) != null));
        break;
      }
    }
    final missing = names.where((n) => !visible.contains(n)).toList();
    if (missing.isEmpty) return (_) => prefix!;
    final importsThor = unitResult.libraryFragment.libraryImports.any(
      (i) => i.importedLibrary?.uri.toString() == thorUiLibrary,
    );
    if (importsThor && (missing.length > 1 || (prefix ?? '').isNotEmpty)) {
      return null;
    }
    return (b) {
      final uri = Uri.parse(thorUiLibrary);
      final added = importsThor
          ? b.importLibraryElement(uri, showName: missing.single).prefix
          : b.importLibraryElement(uri).prefix;
      return prefix ?? (added == null ? '' : '$added.');
    };
  }
}

/// "Wrap with Padding" and the other [Wrapper]s:
/// `Padding(padding: …, child: <widget>)`.
class WrapWith extends _WidgetAssist {
  /// Wraps the widget in [wrapper].
  WrapWith(this.wrapper, {required super.context});

  /// The widget written around.
  final Wrapper wrapper;

  @override
  AssistKind get assistKind => wrapper.kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final w = call;
    if (w == null) return;
    // Wrapping a widget in its own kind (Padding in Padding) is noise.
    if (w.className == wrapper.name) return;
    final prefixOf = await _thorPrefix([wrapper.name, ...wrapper.imports]);
    if (prefixOf == null) return;
    await builder.addDartFileEdit(file, (b) {
      _apply(b, wrapEditsForCall(edits, w, wrapper, prefixOf(b)));
    });
  }
}

/// "Wrap with widget...": `widget(child: <widget>)` with `widget` selected
/// to type the name.
class WrapWithWidget extends WrapWith {
  /// Wraps the widget in a widget the user names.
  WrapWithWidget({required super.context}) : super(const Wrapper('widget'));

  static const _kind = AssistKind(
    'thor.assist.wrap.generic',
    _wrapGenericPriority,
    'Wrap with widget...',
  );

  @override
  AssistKind get assistKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final w = call;
    if (w == null) return;
    await builder.addDartFileEdit(file, (b) {
      _apply(
        b,
        wrapWidgetEditsForCall(edits, w),
        linked: wrapWidgetToken,
        group: 'WIDGET',
      );
    });
  }
}

/// "Wrap with Column" / "Wrap with Row": the widget as the only element
/// of `children: [ … ]`.
class WrapWithFlex extends _WidgetAssist {
  /// Wraps the widget in a [name] (`Column` or `Row`).
  WrapWithFlex(this.name, {required super.context});

  /// `Column` or `Row`.
  final String name;

  @override
  AssistKind get assistKind => AssistKind(
    'thor.assist.wrap.${name.toLowerCase()}',
    wrapPriority,
    'Wrap with $name',
  );

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final w = call;
    if (w == null) return;
    final prefixOf = await _thorPrefix([name]);
    if (prefixOf == null) return;
    await builder.addDartFileEdit(file, (b) {
      _apply(b, wrapFlexEditsForCall(edits, w, name, prefixOf(b)));
    });
  }
}

/// "Wrap with Watch": `Watch(source, builder: (value) => <widget>)` with
/// `source` selected to type the state's member (`counter.count`).
class WrapWithWatch extends _WidgetAssist {
  /// Wraps the widget in a `Watch`.
  WrapWithWatch({required super.context});

  static const _kind = AssistKind(
    'thor.assist.wrap.watch',
    wrapPriority,
    'Wrap with Watch',
  );

  @override
  AssistKind get assistKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final w = call;
    if (w == null) return;
    if (w.className == 'Watch') return;
    final prefixOf = await _thorPrefix(['Watch']);
    if (prefixOf == null) return;
    await builder.addDartFileEdit(file, (b) {
      _apply(
        b,
        wrapWatchEditsForCall(edits, w, prefixOf(b)),
        linked: watchSourceToken,
        group: 'SOURCE',
      );
    });
  }
}

/// "Remove this widget": the widget replaced by its `child:`, or by the
/// elements of its `children:` when it is itself in a list.
class RemoveWidget extends _WidgetAssist {
  /// Removes the widget, keeping its children.
  RemoveWidget({required super.context});

  static const _kind = AssistKind(
    'thor.assist.removeWidget',
    _structurePriority,
    'Remove this widget',
  );

  @override
  AssistKind get assistKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final w = call;
    if (w == null) return;
    final result = removeEditsForCall(edits, w);
    if (result.isEmpty) return;
    await builder.addDartFileEdit(file, (b) => _apply(b, result));
  }
}

/// "Swap with child": the widget's `child:` goes outside it.
class SwapWithChild extends _WidgetAssist {
  /// Swaps the widget with its child.
  SwapWithChild({required super.context});

  static const _kind = AssistKind(
    'thor.assist.swapWithChild',
    _structurePriority,
    'Swap with child',
  );

  @override
  AssistKind get assistKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final w = call;
    if (w == null) return;
    final child = namedArgument(widget!, 'child')?.expression;
    if (child is! InstanceCreationExpression ||
        !isThorWidgetType(child.staticType)) {
      return;
    }
    final result = swapEditsForCall(
      edits,
      w,
      WidgetCall.of(child, inConstantContext: child.inConstantContext)!,
    );
    if (result.isEmpty) return;
    await builder.addDartFileEdit(file, (b) => _apply(b, result));
  }
}

/// "Swap with parent": the widget goes outside the widget whose `child:`
/// it is.
class SwapWithParent extends _WidgetAssist {
  /// Swaps the widget with its parent.
  SwapWithParent({required super.context});

  static const _kind = AssistKind(
    'thor.assist.swapWithParent',
    _structurePriority,
    'Swap with parent',
  );

  @override
  AssistKind get assistKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final w = call;
    if (w == null) return;
    final parent = w.parentWidget;
    final parentNode = parent?.node;
    if (parent == null ||
        parentNode is! InstanceCreationExpression ||
        !isThorWidgetType(parentNode.staticType)) {
      return;
    }
    final result = swapEditsForCall(edits, parent, w);
    if (result.isEmpty) return;
    await builder.addDartFileEdit(file, (b) => _apply(b, result));
  }
}

/// "Move widget up" / "Move widget down": swaps the widget with its
/// neighbour in a `children:` list.
class MoveWidget extends _WidgetAssist {
  /// Moves the widget one place up (or down when [up] is false).
  MoveWidget({required this.up, required super.context});

  /// Towards the start of the list.
  final bool up;

  static const _up = AssistKind(
    'thor.assist.moveWidgetUp',
    _structurePriority,
    'Move widget up',
  );
  static const _down = AssistKind(
    'thor.assist.moveWidgetDown',
    _structurePriority,
    'Move widget down',
  );

  @override
  AssistKind get assistKind => up ? _up : _down;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final w = call;
    if (w == null) return;
    final result = moveEditsForCall(edits, w, up: up);
    if (result.isEmpty) return;
    await builder.addDartFileEdit(file, (b) => _apply(b, result));
  }
}

/// Registers the widget assists: Flutter's "Wrap with …", "Remove this
/// widget", "Swap with child/parent" and "Move widget up/down", for thor
/// widgets (Dart's own only fire on `package:flutter` widgets).
void registerWidgetAssists(PluginRegistry registry) {
  registry.registerAssist(WrapWithWidget.new);
  for (final wrapper in Wrapper.all) {
    registry.registerAssist(
      ({required context}) => WrapWith(wrapper, context: context),
    );
  }
  registry
    ..registerAssist(
      ({required context}) => WrapWithFlex('Column', context: context),
    )
    ..registerAssist(
      ({required context}) => WrapWithFlex('Row', context: context),
    )
    ..registerAssist(WrapWithWatch.new)
    ..registerAssist(RemoveWidget.new)
    ..registerAssist(SwapWithChild.new)
    ..registerAssist(SwapWithParent.new)
    ..registerAssist(
      ({required context}) => MoveWidget(up: true, context: context),
    )
    ..registerAssist(
      ({required context}) => MoveWidget(up: false, context: context),
    );
}
