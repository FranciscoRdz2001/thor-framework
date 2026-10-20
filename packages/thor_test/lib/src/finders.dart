import 'package:html/dom.dart' as dom;
import 'package:matcher/matcher.dart';
import 'package:thor_ui/thor_ui.dart' show Key, SemanticsRole, Text;

import 'tester.dart';

/// Elements that never carry visible content.
const _inert = {'style', 'script', 'template'};

/// A query over the HTML a [ThorTester] rendered: the counterpart of
/// Flutter's `Finder`.
///
/// `// web:` a Flutter finder returns widgets; this one returns the HTML
/// elements they became, so its results work with [ThorTester.widgetHtml].
/// Keys and widget types are not written to the HTML; [ThorTester.pumpWidget]
/// records them while it renders, so `byKey` and `byType` work on a pumped
/// widget (not on a page that came from a server).
class Finder {
  /// Creates a finder described by [description] that keeps the elements
  /// [matches] accepts, searching below [roots] (default: the rendered
  /// page).
  const Finder(this.description, this.matches, {this.roots});

  /// What this finder looks for, for failure messages.
  final String description;

  /// Whether an element is a result.
  final bool Function(dom.Element element) matches;

  /// Where to search; null is the whole page of the current tester.
  final Finder? roots;

  /// The matching elements, in document order.
  Iterable<dom.Element> evaluate() {
    final scopes = roots == null
        ? ThorTester.current.fragment.nodes.toList()
        : roots!.evaluate().toList();
    final found = <dom.Element>[];
    void walk(dom.Node node, {required bool isScope}) {
      if (node is dom.Element) {
        if (_inert.contains(node.localName)) return;
        // A scope given by `descendant(of:)` does not match itself.
        if ((roots == null || !isScope) && matches(node)) found.add(node);
      }
      for (final child in node.nodes) {
        walk(child, isScope: false);
      }
    }

    for (final scope in scopes) {
      walk(scope, isScope: true);
    }
    return found;
  }

  /// How many elements match.
  int get count => evaluate().length;

  /// The first match only.
  Finder get first => _Pick(this, (all) => all.first, 'first');

  /// The last match only.
  Finder get last => _Pick(this, (all) => all.last, 'last');

  /// The match at [index].
  Finder at(int index) => _Pick(this, (all) => all[index], 'at($index)');

  @override
  String toString() => description;
}

class _Pick extends Finder {
  _Pick(this._source, this._pick, String label)
    : super('${_source.description} ($label)', _never);

  final Finder _source;
  final dom.Element Function(List<dom.Element>) _pick;

  static bool _never(dom.Element _) => false;

  @override
  Iterable<dom.Element> evaluate() {
    final all = _source.evaluate().toList();
    return all.isEmpty ? const [] : [_pick(all)];
  }
}

const _inlineTags = {
  'span', 'a', 'b', 'i', 'em', 'strong', 'code', 'sub', 'sup', 'small', //
  'mark', 'u', 's', 'br',
};

bool _isInlineText(dom.Element element) =>
    _inlineTags.contains(element.localName) &&
    element.children.every(_isInlineText);

/// Whether [element] is the element of a `Text` widget of a pumped page
/// (never true on a page from a server, which keeps no widget tree).
bool _isTextWidget(dom.Element element) =>
    ThorTester.current.widgetsOf(element).any((w) => w.type == Text);

/// [element]'s text without the `Text` widgets inside it (a `WidgetSpan`'s
/// child is a text of its own, not part of the run around it).
String _runText(dom.Element element) => [
  for (final node in element.nodes)
    if (node is dom.Text)
      node.data
    else if (node is dom.Element && !_isTextWidget(node))
      _runText(node),
].join();

/// The text an element holds itself: `Text('Hi')` is a `<span>Hi</span>`,
/// and a button's label is its own text. A `Text.rich` is a span with inline
/// spans inside (`Hola <span>mundo</span>`): the outermost one holds the
/// whole of it (`toPlainText()`, like Flutter), and the spans inside it are
/// fragments, not texts of their own (null).
String? _ownText(dom.Element element) {
  final parent = element.parent;
  if (parent != null && _isInlineText(parent) && !_isTextWidget(element)) {
    return null;
  }
  if (element.children.isNotEmpty && _isInlineText(element)) {
    return _runText(element);
  }
  return element.nodes.whereType<dom.Text>().map((text) => text.data).join();
}

bool _hasPattern(String? value, Pattern pattern) {
  if (value == null) return false;
  if (pattern is String) return value == pattern;
  return pattern.allMatches(value).isNotEmpty;
}

/// The finders, like Flutter's `find`.
///
/// ```dart
/// expect(find.text('Cold brew'), findsOneWidget);
/// ```
const find = CommonFinders._();

/// The set of finders behind [find].
class CommonFinders {
  const CommonFinders._();

  /// Elements whose own text is exactly [text] (a `Text('Hi')`, a button's
  /// label).
  Finder text(String text) =>
      Finder('text "$text"', (element) => _ownText(element)?.trim() == text);

  /// Elements whose own text contains [substring].
  Finder textContaining(Pattern substring) => Finder(
    'text containing ${substring is String ? '"$substring"' : substring}',
    (element) => substring.allMatches(_ownText(element) ?? '').isNotEmpty,
  );

  /// Elements announced with this `Semantics(label:)` (`aria-label`):
  /// [label] is a `String` (exact) or a `RegExp`.
  Finder bySemanticsLabel(Pattern label) => Finder(
    'semantics label $label',
    (element) => _hasPattern(element.attributes['aria-label'], label),
  );

  /// Elements with this `Semantics(identifier:)`.
  ///
  /// `// web:` Flutter writes it to `flt-semantics-identifier`; here it is
  /// the element's `id`.
  Finder bySemanticsIdentifier(String identifier) => Finder(
    'semantics identifier "$identifier"',
    (element) => element.id == identifier,
  );

  /// Elements with this `Semantics(role:)`: the role's HTML element, or
  /// its ARIA `role`.
  ///
  /// `// web:` a role that is an HTML element (`list` is `<ul>`) also
  /// matches the same element written by another widget.
  Finder byRole(SemanticsRole role) => Finder(
    'role ${role.name}',
    (element) => role.tag != null
        ? element.localName == role.tag
        : element.attributes['role'] == role.aria,
  );

  /// The element a `Tooltip(message:)` is anchored to: the one described
  /// by the tooltip whose text is [message].
  Finder byTooltip(String message) => Finder('tooltip "$message"', (element) {
    final ids = element.attributes['aria-describedby'];
    if (ids == null) return false;
    final root = _root(element);
    for (final id in ids.split(' ')) {
      final tip = _byId(root, id);
      if (tip != null &&
          tip.attributes['role'] == 'tooltip' &&
          tip.text.trim() == message) {
        return true;
      }
    }
    return false;
  });

  static dom.Node _root(dom.Node node) {
    var current = node;
    while (current.parentNode != null) {
      current = current.parentNode!;
    }
    return current;
  }

  static dom.Element? _byId(dom.Node node, String id) {
    for (final child in node.nodes) {
      if (child is dom.Element) {
        if (child.id == id) return child;
        final inner = _byId(child, id);
        if (inner != null) return inner;
      }
    }
    return null;
  }

  /// The element built by the widget whose key is [key] (the first element
  /// that widget writes).
  ///
  /// `// web:` only for a tree given to `pumpWidget`; a page from a server
  /// has no widgets.
  Finder byKey(Key key) => Finder(
    'key $key',
    (element) => ThorTester.current.widgetsOf(element).any((w) => w.key == key),
  );

  /// The element built by a widget of exactly [type] (the first element
  /// that widget writes): `find.byType(Text)`.
  ///
  /// `// web:` an element can be built by several widgets (`Padding` above
  /// a `Text` is one `<span>`), and each of them finds it; only for a tree
  /// given to `pumpWidget`.
  Finder byType(Type type) => Finder(
    'type $type',
    (element) =>
        ThorTester.current.widgetsOf(element).any((w) => w.type == type),
  );

  /// Elements with the HTML tag [tag] (`'button'`).
  ///
  /// `// web:` not in Flutter.
  Finder byTag(String tag) =>
      Finder('tag <$tag>', (element) => element.localName == tag);

  /// The elements that [matching] finds below those of [of], never [of]
  /// itself.
  Finder descendant({required Finder of, required Finder matching}) => Finder(
    '${matching.description} inside ${of.description}',
    matching.matches,
    roots: of,
  );
}

/// Matches a [Finder] that finds exactly one element.
const Matcher findsOneWidget = _FindsCount(1, 'exactly one widget');

/// Matches a [Finder] that finds nothing.
const Matcher findsNothing = _FindsCount(0, 'no widgets');

/// Matches a [Finder] that finds [count] elements.
Matcher findsNWidgets(int count) => _FindsCount(count, '$count widgets');

/// Matches a [Finder] that finds at least one element.
const Matcher findsWidgets = _FindsCount(null, 'at least one widget');

class _FindsCount extends Matcher {
  const _FindsCount(this.expected, this.label);

  final int? expected;
  final String label;

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! Finder) return false;
    final count = item.count;
    matchState['count'] = count;
    return expected == null ? count > 0 : count == expected;
  }

  @override
  Description describe(Description description) => description.add(label);

  @override
  Description describeMismatch(
    Object? item,
    Description mismatch,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is! Finder) return mismatch.add('is not a Finder');
    return mismatch.add(
      'found ${matchState['count']} widgets for ${item.description}',
    );
  }
}
