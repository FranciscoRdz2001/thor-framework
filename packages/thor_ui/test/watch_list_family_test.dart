@TestOn('vm')
library;

// A `Watch.list` over a method with a fixed argument
// (`branchOf.withArg(slug)`): one list per instance of the same state, each
// with its own rows, its own binding id and the same row template.
import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart' show parseBindingId;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

abstract class _TreeMembers extends ThorState {
  @override
  String get $type => 'TreeState';

  @override
  List<ThorMember> get $members {
    final s = this as TreeState;
    return [
      ThorMember('branchOf', s.branchOf, arity: 1, call: (a) => s.branchOf(a!)),
      ThorMember(
        'nameOf',
        s.nameOf,
        arity: 1,
        callWithItem: (i) => s.nameOf(i as String),
      ),
    ];
  }
}

class TreeState extends _TreeMembers {
  final branches = state<Map<String, List<String>>>(const {
    'food': ['fruit', 'bread'],
    'home': ['lamp'],
    // Arguments that look like the markup around them.
    'a~b': ['tilde'],
    'x/y': ['slash'],
    'é☃😀': ['unicode'],
    'q"uo\'te': ['quote'],
    '<b>&amp;': ['markup'],
    '': ['empty'],
    '%7E': ['percent'],
    ' sp ': ['space'],
  });

  List<String> branchOf(String slug) => branches.value[slug] ?? const [];
  String nameOf(String s) => s;
}

final tree = TreeState();

Future<String> _html(Widget w) => renderHtml(ThorApp(child: w));

Widget _list(String slug) => Watch.list(
  tree.branchOf.withArg(slug),
  itemKey: tree.nameOf,
  each: (row) => row.text(tree.nameOf),
);

void main() {
  setUpAll(initializeThorTests);

  test('each instance draws its own rows under its own id', () async {
    final html = await _html(Column(children: [_list('food'), _list('home')]));
    expect(html, contains('data-tl="TreeState.branchOf~food"'));
    expect(html, contains('data-tl="TreeState.branchOf~home"'));
    expect(RegExp('data-tk="').allMatches(html), hasLength(3));
    expect(html, contains('data-tk="fruit"'));
    expect(html, contains('data-tk="lamp"'));
    // The template of each is told apart by the same id.
    expect(html, contains('data-tlt="TreeState.branchOf~food"'));
    expect(html, contains('data-tlt="TreeState.branchOf~home"'));
  });

  test('a Link needs no href where the row writes it', () async {
    final html = await _html(
      Watch.list(
        tree.branchOf.withArg('food'),
        itemKey: tree.nameOf,
        each: (row) => row.attribute(
          AttributeName.href,
          tree.nameOf,
          child: Link(child: row.text(tree.nameOf)),
        ),
      ),
    );
    // The row has the row's own href (the binding wins over the placeholder).
    expect(html, contains('href="fruit"'));
    expect(html, contains('href="bread"'));
    // The template has no href at all: the browser writes the row's on each clone.
    final template = html.substring(html.indexOf('<template'));
    expect(template, contains('<a '));
    expect(template, isNot(contains('href="#"')));
    expect(template, contains('data-tfa="href:TreeState.nameOf"'));
    expect(html, isNot(contains('href="#"')));
  });

  test('a Link with no href is a link to the top of the page', () async {
    final html = await _html(const Link(child: Text('x')));
    expect(html, contains('href="#"'));
  });

  group('an argument that looks like markup or like the id around it', () {
    const odd = {
      'a~b': 'tilde',
      'x/y': 'slash',
      'é☃😀': 'unicode',
      'q"uo\'te': 'quote',
      '<b>&amp;': 'markup',
      '': 'empty',
      '%7E': 'percent',
      ' sp ': 'space',
    };

    test(
      'each draws its own rows and the attribute stays well formed',
      () async {
        for (final MapEntry(key: arg, value: row) in odd.entries) {
          final html = await _html(
            Column(children: [_list(arg), _list('home')]),
          );
          expect(html, contains('data-tk="$row"'), reason: 'arg "$arg"');
          expect(html, contains('data-tk="lamp"'), reason: 'arg "$arg"');
          // Only the rows of this argument and of `home`: nothing leaked from
          // the argument into the markup.
          expect(RegExp('data-tk="').allMatches(html), hasLength(2));
          expect(html, isNot(contains('<b>&amp;<')), reason: 'arg "$arg"');
          expect(RegExp('data-tl="').allMatches(html), hasLength(2));
          expect(RegExp('data-tlt="').allMatches(html), hasLength(2));
        }
      },
    );

    test('the id splits at the first ~ only: the argument keeps its own', () {
      expect(parseBindingId('TreeState.branchOf~a~b'), (
        'TreeState.branchOf',
        'a~b',
      ));
      expect(parseBindingId('TreeState.branchOf~'), ('TreeState.branchOf', ''));
      expect(parseBindingId('TreeState.branchOf'), (
        'TreeState.branchOf',
        null,
      ));
    });
  });
}
