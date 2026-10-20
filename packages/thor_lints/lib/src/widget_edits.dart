import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' show SourceEdit;
import 'package:analyzer_plugin/utilities/assist/assist.dart';

// The widget assists' edits as plain functions of source text: no analyzer
// session, no plugin context, so an editor calls exactly what the
// correction producers in widget_assists.dart call (they are built on the
// `*ForCall` functions here; nothing is written twice).
//
// The widget is found in the *parsed* (not resolved) source, so a call like
// `Text('x')` is taken for a widget when its class name is capitalised; the
// producers add the resolved type check.

/// Priority of the "Wrap with …" assists, as Flutter's.
const wrapPriority = 30;

/// A thor widget a "Wrap with …" assist writes around the selected one.
class Wrapper {
  /// A wrapper [name] with [arguments] written before `child:`; in them
  /// `{thor}` is the thor_ui prefix and `{const}` is `const ` outside a
  /// constant context.
  const Wrapper(this.name, [this.arguments = const []]);

  /// The widget class (exported by `package:thor_ui/thor_ui.dart`).
  final String name;

  /// The arguments before `child:`.
  final List<String> arguments;

  /// The other thor classes [arguments] name (`EdgeInsets`).
  Iterable<String> get imports => [
    for (final a in arguments)
      for (final m in RegExp(r'\{thor\}(\w+)').allMatches(a)) m[1]!,
  ];

  /// The assist kind, as Flutter names its own.
  AssistKind get kind => AssistKind(
    'thor.assist.wrap.${name.toLowerCase()}',
    wrapPriority,
    'Wrap with $name',
  );

  /// The wrappers thor offers, Flutter's plus [Semantics] and [Link].
  static const all = [
    Wrapper('Padding', ['padding: {const}{thor}EdgeInsets.all(8)']),
    Wrapper('Center'),
    Wrapper('Container'),
    Wrapper('SizedBox'),
    Wrapper('Expanded'),
    Wrapper('Flexible'),
    Wrapper('Align', ['alignment: {thor}Alignment.center']),
    Wrapper('Semantics'),
    Wrapper('Link', ["href: ''"]),
  ];
}

/// How the edits are laid out.
class EditStyle {
  /// A style with [eol] line endings and [indent] as one indentation level.
  const EditStyle({this.eol, this.indent = '  '});

  /// The line ending; detected from the source when null.
  final String? eol;

  /// One indentation level.
  final String indent;
}

/// A widget call in the source: `Padding(...)`, `const Text('x')`,
/// `ui.Text.rich(...)`, resolved (an [InstanceCreationExpression]) or not
/// (a [MethodInvocation]).
class WidgetCall {
  WidgetCall._(
    this.node,
    this.argumentList,
    this.nameStart,
    this.hasConst,
    this._inConstantContext,
  );

  /// The call node.
  final AstNode node;

  /// Its arguments.
  final ArgumentList argumentList;

  /// Where the written class name starts (after `const`/`new`).
  final int nameStart;

  /// Whether the call itself is written with `const`.
  final bool hasConst;

  final bool? _inConstantContext;

  /// The widget call [node] is, or null. [inConstantContext] overrides the
  /// syntactic guess (a resolved producer knows).
  static WidgetCall? of(AstNode? node, {bool? inConstantContext}) {
    if (node is InstanceCreationExpression) {
      return WidgetCall._(
        node,
        node.argumentList,
        node.constructorName.offset,
        node.keyword?.lexeme == 'const',
        inConstantContext,
      );
    }
    if (node is MethodInvocation) {
      final call = WidgetCall._(
        node,
        node.argumentList,
        node.offset,
        false,
        inConstantContext,
      );
      return call.className.isEmpty ? null : call;
    }
    return null;
  }

  /// The class name as written, with a prefix or constructor name
  /// (`ui.Text.rich`).
  String name(String source) =>
      source.substring(nameStart, argumentList.offset);

  /// `Text` for `ui.Text.rich`: the first capitalised segment of the name
  /// (empty when there is none, so a plain method is no widget).
  String get className {
    final n = node;
    if (n is InstanceCreationExpression) {
      return n.constructorName.type.name.lexeme;
    }
    n as MethodInvocation;
    final segments = [..._segments(n.target), n.methodName.name];
    return segments.firstWhere(
      (s) => s.isNotEmpty && s[0] == s[0].toUpperCase() && s[0] != '_',
      orElse: () => '',
    );
  }

  static List<String> _segments(Expression? e) => switch (e) {
    null => const [],
    SimpleIdentifier() => [e.name],
    PrefixedIdentifier() => [e.prefix.name, e.identifier.name],
    PropertyAccess() => [..._segments(e.target), e.propertyName.name],
    _ => const [''],
  };

  /// Whether a `const` written around makes a nested `const` redundant.
  bool get inConstantContext {
    final given = _inConstantContext;
    if (given != null) return given;
    for (AstNode? p = node.parent; p != null; p = p.parent) {
      if (p is InstanceCreationExpression && p.keyword?.lexeme == 'const') {
        return true;
      }
      if (p is TypedLiteral && p.constKeyword != null) return true;
      if (p is VariableDeclarationList && p.isConst) return true;
      if (p is FunctionBody || p is ClassMember) return false;
    }
    return false;
  }

  /// The named argument [name] (`child`, `children`).
  NamedExpression? named(String name) => namedArgumentOf(argumentList, name);

  /// The widget call that is the `child:` of this one.
  WidgetCall? get child => of(named('child')?.expression);

  /// The widget call whose `child:` this one is.
  WidgetCall? get parentWidget {
    final named = node.parent;
    if (named is! NamedExpression || named.name.label.name != 'child') {
      return null;
    }
    return of(named.parent?.parent);
  }
}

/// The named argument [name] of [list].
NamedExpression? namedArgumentOf(ArgumentList list, String name) {
  for (final a in list.arguments) {
    if (a is NamedExpression && a.name.label.name == name) return a;
  }
  return null;
}

/// The source being edited, with its layout helpers.
class EditContext {
  /// A context over [source] parsed as [unit].
  EditContext(this.source, this.unit, [EditStyle style = const EditStyle()])
    : indentUnit = style.indent,
      eol = style.eol ?? (source.contains('\r\n') ? '\r\n' : '\n') {
    unit.accept(_MultilineStrings(_strings));
  }

  /// A context over [source], parsed here.
  factory EditContext.parse(
    String source, [
    EditStyle style = const EditStyle(),
  ]) => EditContext(
    source,
    parseString(content: source, throwIfDiagnostics: false).unit,
    style,
  );

  /// The source.
  final String source;

  /// Its parsed unit.
  final CompilationUnit unit;

  /// The line ending.
  final String eol;

  /// One indentation level.
  final String indentUnit;

  final _strings = <(int, int)>[];

  /// The text of [n].
  String text(AstNode n) => source.substring(n.offset, n.end);

  /// The whitespace before [offset] on its line.
  String linePrefix(int offset) {
    var start = offset;
    while (start > 0 && source[start - 1] != '\n') {
      start--;
    }
    var end = start;
    while (end < offset && (source[end] == ' ' || source[end] == '\t')) {
      end++;
    }
    return source.substring(start, end);
  }

  /// [text], which starts at [origin] in the source, with its lines after
  /// the first moved from the indentation of [origin]'s line to [indent]
  /// (lines inside a multi-line string are left as they are).
  String reindent(String text, int origin, String indent) {
    final old = linePrefix(origin);
    final lines = text.split(RegExp(r'(?<=\n)'));
    final out = StringBuffer();
    var position = 0;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final absolute = origin + position;
      position += line.length;
      final inString = _strings.any((s) => absolute > s.$1 && absolute < s.$2);
      if (i == 0 || inString || !line.startsWith(old)) {
        out.write(line);
      } else {
        out.write('$indent${line.substring(old.length)}');
      }
    }
    return out.toString();
  }

  /// An edit replacing [n] with [replacement].
  SourceEdit replace(AstNode n, String replacement) =>
      SourceEdit(n.offset, n.length, replacement);
}

class _MultilineStrings extends RecursiveAstVisitor<void> {
  _MultilineStrings(this.out);

  final List<(int, int)> out;

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (node.isMultiline) out.add((node.offset, node.end));
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    if (node.isMultiline) out.add((node.offset, node.end));
    super.visitStringInterpolation(node);
  }
}

/// The widget call under [offset] in [unit]: on its constructor name
/// (`Padding`, `Text.rich`, `ui.Text`), its `const`/`new` keyword or just
/// before its `(`.
WidgetCall? widgetCallAt(CompilationUnit unit, int offset) {
  AstNode deepest(AstNode n) {
    for (final c in n.childEntities) {
      if (c is AstNode && c.offset <= offset && offset <= c.end) {
        return deepest(c);
      }
    }
    return n;
  }

  AstNode? n = deepest(unit);
  if (n is ArgumentList && n.offset == offset) n = n.parent;
  while (n != null && n is! InstanceCreationExpression) {
    if (n is MethodInvocation) break;
    if (n is! NamedType &&
        n is! ConstructorName &&
        n is! SimpleIdentifier &&
        n is! PrefixedIdentifier &&
        n is! PropertyAccess &&
        n is! ImportPrefixReference &&
        n is! TypeArgumentList) {
      return null;
    }
    n = n.parent;
  }
  final call = WidgetCall.of(n);
  if (call == null) return null;
  // Inside the arguments is another widget's (or no widget's) business.
  if (offset > call.argumentList.offset) return null;
  return call;
}

/// `child: <widget>` after [arguments]: on one line when all fits in one
/// (`Center(child: Text(''))`), else one argument per line.
String _childArguments(EditContext c, WidgetCall w, List<String> arguments) {
  final source = c.text(w.node);
  if (arguments.isEmpty && !source.contains(c.eol)) return 'child: $source';
  final indentOld = c.linePrefix(w.node.offset);
  final indent = '$indentOld${c.indentUnit}';
  final b = StringBuffer();
  for (final a in arguments) {
    b.write('${c.eol}$indent$a,');
  }
  b.write(
    '${c.eol}${indent}child: ${c.reindent(source, w.node.offset, indent)},',
  );
  b.write('${c.eol}$indentOld');
  return b.toString();
}

/// "Wrap with [wrapper]": `Name(arguments, child: <widget>)`. The `{thor}`
/// and `{const}` of the arguments are filled in here; [thor] is the thor_ui
/// prefix (`''` or `'ui.'`), which the caller makes importable.
List<SourceEdit> wrapEditsForCall(
  EditContext c,
  WidgetCall w,
  Wrapper wrapper,
  String thor,
) {
  // Wrapping a widget in its own kind (Padding in Padding) is noise.
  if (w.className == wrapper.name) return const [];
  final constKeyword = w.inConstantContext ? '' : 'const ';
  final arguments = [
    for (final a in wrapper.arguments)
      a.replaceAll('{thor}', thor).replaceAll('{const}', constKeyword),
  ];
  return [
    c.replace(
      w.node,
      '$thor${wrapper.name}(${_childArguments(c, w, arguments)})',
    ),
  ];
}

/// The token "Wrap with widget..." leaves for the user to type.
const wrapWidgetToken = 'widget';

/// "Wrap with widget...": `widget(child: <widget>)`.
List<SourceEdit> wrapWidgetEditsForCall(EditContext c, WidgetCall w) => [
  c.replace(w.node, '$wrapWidgetToken(${_childArguments(c, w, const [])})'),
];

/// "Wrap with Column" / "Wrap with Row" (`name`): the widget as the only
/// element of `children: [ … ]`.
List<SourceEdit> wrapFlexEditsForCall(
  EditContext c,
  WidgetCall w,
  String name,
  String thor,
) {
  final indentOld = c.linePrefix(w.node.offset);
  final indent1 = '$indentOld${c.indentUnit}';
  final indent2 = '$indent1${c.indentUnit}';
  final b = StringBuffer('$thor$name(')
    ..write('${c.eol}${indent1}children: [')
    ..write(
      '${c.eol}$indent2${c.reindent(c.text(w.node), w.node.offset, indent2)},',
    )
    ..write('${c.eol}$indent1],')
    ..write('${c.eol}$indentOld)');
  return [c.replace(w.node, b.toString())];
}

/// The token a Watch wrap leaves for the user to type.
const watchSourceToken = 'source';

/// "Wrap with Watch": `Watch(source, builder: (value) => <widget>)`, with
/// [watchSourceToken] where the state's member goes.
List<SourceEdit> wrapWatchEditsForCall(
  EditContext c,
  WidgetCall w,
  String thor,
) {
  if (w.className == 'Watch') return const [];
  final source = c.text(w.node);
  if (!source.contains(c.eol)) {
    return [
      c.replace(
        w.node,
        '${thor}Watch($watchSourceToken, builder: (value) => $source)',
      ),
    ];
  }
  final indentOld = c.linePrefix(w.node.offset);
  final indent = '$indentOld${c.indentUnit}';
  final b = StringBuffer('${thor}Watch(')
    ..write('${c.eol}$indent$watchSourceToken,')
    ..write('${c.eol}${indent}builder: (value) => ')
    ..write('${c.reindent(source, w.node.offset, indent)},')
    ..write('${c.eol}$indentOld)');
  return [c.replace(w.node, b.toString())];
}

/// "Remove this widget": the widget replaced by its `child:`, or by the
/// elements of its `children:` when it is itself in a list.
List<SourceEdit> removeEditsForCall(EditContext c, WidgetCall w) {
  final indent = c.linePrefix(w.node.offset);
  final child = w.named('child')?.expression;
  if (child != null) {
    return [c.replace(w.node, c.reindent(c.text(child), child.offset, indent))];
  }
  final children = w.named('children')?.expression;
  if (children is! ListLiteral || children.elements.isEmpty) return const [];
  final first = children.elements.first;
  final last = children.elements.last;
  // Many children only fit where a list takes the widget's place.
  if (first != last && w.node.parent is! ListLiteral) return const [];
  final source = c.source.substring(first.offset, last.end);
  return [c.replace(w.node, c.reindent(source, first.offset, indent))];
}

/// Swaps [parent] and its `child:` [child]: the child's class and arguments
/// go outside, the parent's inside, around the child's own `child:`.
List<SourceEdit> swapEditsForCall(
  EditContext c,
  WidgetCall parent,
  WidgetCall child,
) {
  final grandChild = child.named('child');
  if (grandChild == null) return const [];
  final indentParent = c.linePrefix(parent.node.offset);
  final indentChild = '$indentParent${c.indentUnit}';
  final indentArgs = '$indentChild${c.indentUnit}';
  String arg(AstNode a, String indent) =>
      c.reindent(c.text(a), a.offset, indent);
  // The parent's `const` covers the whole swapped pair; the child's own
  // `const` may no longer hold around the parent's arguments.
  final keyword = parent.hasConst ? 'const ' : '';
  final b = StringBuffer('$keyword${child.name(c.source)}(');
  for (final a in child.argumentList.arguments) {
    if (a == grandChild) continue;
    b.write('${c.eol}$indentChild${arg(a, indentChild)},');
  }
  b.write('${c.eol}${indentChild}child: ${parent.name(c.source)}(');
  for (final a in parent.argumentList.arguments) {
    if (a is NamedExpression && a.name.label.name == 'child') continue;
    b.write('${c.eol}$indentArgs${arg(a, indentArgs)},');
  }
  b.write('${c.eol}$indentArgs${arg(grandChild, indentArgs)},');
  b.write('${c.eol}$indentChild),');
  b.write('${c.eol}$indentParent)');
  return [c.replace(parent.node, b.toString())];
}

/// "Move widget up/down": swaps the widget with its neighbour in a
/// `children:` list.
List<SourceEdit> moveEditsForCall(
  EditContext c,
  WidgetCall w, {
  required bool up,
}) {
  final list = w.node.parent;
  if (list is! ListLiteral) return const [];
  final named = list.parent;
  if (named is! NamedExpression || named.name.label.name != 'children') {
    return const [];
  }
  final i = list.elements.indexOf(w.node as CollectionElement);
  final j = up ? i - 1 : i + 1;
  if (j < 0 || j >= list.elements.length) return const [];
  final other = list.elements[j];
  // Last edit first, so each offset still holds when the next is applied.
  final edits = [
    c.replace(other, c.text(w.node)),
    c.replace(w.node, c.text(other)),
  ]..sort((a, b) => b.offset.compareTo(a.offset));
  return edits;
}

// The functions an editor calls: source text and a caret offset in, edits
// out (apply them with `SourceEdit.applySequence`). An empty list means the
// assist isn't offered there.

/// "Wrap with [wrapper]" for the widget at [offset]; [thor] is the thor_ui
/// prefix to write the classes with (`''` or `'ui.'`).
List<SourceEdit> wrapEdits(
  String source,
  int offset,
  Wrapper wrapper, {
  String thor = '',
  EditStyle style = const EditStyle(),
}) {
  final c = EditContext.parse(source, style);
  final w = widgetCallAt(c.unit, offset);
  return w == null ? const [] : wrapEditsForCall(c, w, wrapper, thor);
}

/// "Wrap with Column" / "Wrap with Row".
List<SourceEdit> wrapFlexEdits(
  String source,
  int offset,
  String name, {
  String thor = '',
  EditStyle style = const EditStyle(),
}) {
  final c = EditContext.parse(source, style);
  final w = widgetCallAt(c.unit, offset);
  return w == null ? const [] : wrapFlexEditsForCall(c, w, name, thor);
}

/// "Wrap with Watch"; the result holds [watchSourceToken] to replace.
List<SourceEdit> wrapWatchEdits(
  String source,
  int offset, {
  String thor = '',
  EditStyle style = const EditStyle(),
}) {
  final c = EditContext.parse(source, style);
  final w = widgetCallAt(c.unit, offset);
  return w == null ? const [] : wrapWatchEditsForCall(c, w, thor);
}

/// "Remove this widget" (unwrap).
List<SourceEdit> removeWidgetEdits(
  String source,
  int offset, {
  EditStyle style = const EditStyle(),
}) {
  final c = EditContext.parse(source, style);
  final w = widgetCallAt(c.unit, offset);
  return w == null ? const [] : removeEditsForCall(c, w);
}

/// "Swap with child".
List<SourceEdit> swapWithChildEdits(
  String source,
  int offset, {
  EditStyle style = const EditStyle(),
}) {
  final c = EditContext.parse(source, style);
  final w = widgetCallAt(c.unit, offset);
  final child = w?.child;
  return w == null || child == null ? const [] : swapEditsForCall(c, w, child);
}

/// "Swap with parent".
List<SourceEdit> swapWithParentEdits(
  String source,
  int offset, {
  EditStyle style = const EditStyle(),
}) {
  final c = EditContext.parse(source, style);
  final w = widgetCallAt(c.unit, offset);
  final parent = w?.parentWidget;
  return w == null || parent == null
      ? const []
      : swapEditsForCall(c, parent, w);
}

/// "Move widget up" / "Move widget down".
List<SourceEdit> moveWidgetEdits(
  String source,
  int offset, {
  required bool up,
  EditStyle style = const EditStyle(),
}) {
  final c = EditContext.parse(source, style);
  final w = widgetCallAt(c.unit, offset);
  return w == null ? const [] : moveEditsForCall(c, w, up: up);
}
