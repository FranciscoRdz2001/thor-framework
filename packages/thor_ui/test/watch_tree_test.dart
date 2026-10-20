@TestOn('vm')
library;

// `Watch.tree`: a list whose rows hold their children, drawn by the same
// row template at any depth. The server draws the tree as it is now, each
// level inside its row; the page carries one row template, with an empty
// children slot (`data-tlc`) the browser clones the template into.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/lite.dart' show liteBundle;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class Node {
  const Node(this.id, this.label, [this.children = const []]);
  final String id;
  final String label;
  final List<Node> children;

  factory Node.fromJson(Map<String, Object?> json) =>
      Node(json['id']! as String, json['label']! as String, [
        for (final c in json['children']! as List<Object?>)
          Node.fromJson(c! as Map<String, Object?>),
      ]);

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'children': [for (final c in children) c.toJson()],
  };
}

abstract class _EditorMembers extends ThorState {
  @override
  String get $type => 'EditorState';

  @override
  List<ThorMember> get $members {
    final s = this as EditorState;
    return [
      ThorMember.state('nodes', s.nodes),
      ThorMember.state('picked', s.picked),
      ThorMember('roots', s.roots),
      ThorMember(
        'idOf',
        s.idOf,
        arity: 1,
        callWithItem: (i) => s.idOf(i as Node),
      ),
      ThorMember(
        'labelOf',
        s.labelOf,
        arity: 1,
        callWithItem: (i) => s.labelOf(i as Node),
      ),
      ThorMember(
        'childrenOf',
        s.childrenOf,
        arity: 1,
        callWithItem: (i) => s.childrenOf(i as Node),
      ),
      ThorMember('select', s.select, arity: 1, call: (a) => s.select(a!)),
    ];
  }
}

class EditorState extends _EditorMembers {
  final nodes = state<List<Node>>(const [
    Node('app', 'App', [
      Node('col', 'Column', [Node('t1', 'Text'), Node('t2', 'Text')]),
    ]),
    Node('fab', 'Fab'),
  ]);

  final picked = state('');

  List<Node> roots() => nodes.value;
  String idOf(Node n) => n.id;
  String labelOf(Node n) => n.label;
  List<Node> childrenOf(Node n) => n.children;
  void select(String id) {}
}

final editor = EditorState();

Future<String> _html(Widget w) => renderHtml(ThorApp(child: w));

Widget _tree() => Watch.tree(
  editor.roots,
  itemKey: editor.idOf,
  children: editor.childrenOf,
  each: (row, children) => ExpansionTile(
    title: row.text(editor.labelOf),
    trailing: IconButton(
      onPressed: editor.select.withArg(row.key),
      tooltip: 'Select',
      icon: const Icon(IconData.svg('x', '<path d="M0 0"/>')),
    ),
    children: [children],
  ),
);

// A row part that follows which row is picked (`row.selected`): each row
// patches its own part, at any depth.
Widget _pickTree() => Watch.tree(
  editor.roots,
  itemKey: editor.idOf,
  children: editor.childrenOf,
  each: (row, children) => ExpansionTile(
    title: row.selected(
      editor.picked,
      builder: (on) => Text(on ? 'picked' : 'not'),
    ),
    children: [children],
  ),
);

int _count(String s, String part) => part.allMatches(s).length;

void main() {
  initializeThorTests();

  test('the server draws every level inside its row', () async {
    final html = await _html(_tree());
    final rows = html.substring(0, html.indexOf('<template'));
    for (final k in ['app', 'col', 't1', 't2', 'fab']) {
      expect(rows, contains('data-tk="$k"'));
    }
    // Each level is in its row's `<details>`: `t1` comes after `col` opens
    // and before `fab` (a top row).
    final col = rows.indexOf('data-tk="col"');
    expect(rows.indexOf('data-tk="t1"'), greaterThan(col));
    expect(rows.indexOf('data-tk="fab"'), greaterThan(rows.indexOf('t2')));
    expect(_count(rows, '<details'), 5);
    // One children slot per row, every one bound to the children method.
    expect(_count(rows, 'data-tlc="EditorState.childrenOf"'), 5);
    // Callbacks carry each row's own key.
    expect(rows, contains('data-tx="t2"'));
  });

  test('a row and a slot have one class at any depth, as in the template '
      '(the browser clones it anywhere; it writes no class)', () async {
    final html = await _html(_tree());
    final body = html.substring(html.indexOf('<body'));
    final rowClasses = {
      for (final m in RegExp(r'<details class="([^"]+)"').allMatches(body))
        m.group(1),
    };
    expect(rowClasses, hasLength(1));
    final slotClasses = {
      for (final m in RegExp(
        r'<div class="([^"]+)" data-tlc=',
      ).allMatches(body))
        m.group(1),
    };
    // Slots with rows, without and the template's.
    expect(slotClasses, hasLength(1));
  });

  test('one row template, its children slot empty', () async {
    final html = await _html(_tree());
    expect(_count(html, '<template'), 1);
    final template = html.substring(
      html.indexOf('<template'),
      html.indexOf('</template>'),
    );
    expect(template, contains('data-tlc="EditorState.childrenOf"'));
    expect(template, contains('data-tx="{{key}}"'));
    expect(_count(template, 'data-tk='), 0);
    final slot = RegExp(r'<div[^>]*data-tlc="[^"]*"[^>]*>(.*?)</div>');
    expect(slot.firstMatch(template)!.group(1), isEmpty);
    // The list's markers sit on the top level, as `Watch.list`'s.
    expect(html, contains('data-tl="EditorState.roots"'));
    expect(html, contains('data-tlk="EditorState.idOf"'));
  });

  test('an empty tree still ships its template', () async {
    final old = editor.nodes.value;
    editor.nodes.value = const [];
    try {
      final html = await _html(_tree());
      expect(html, contains('<template data-tlt="EditorState.roots"'));
      expect(html, isNot(contains('data-tk=')));
    } finally {
      editor.nodes.value = old;
    }
  });

  test('a key met twice (or a cycle) is THOR-S043', () async {
    final old = editor.nodes.value;
    editor.nodes.value = const [
      Node('a', 'A', [Node('a', 'again')]),
    ];
    try {
      await expectLater(
        _html(_tree()),
        throwsA(
          isA<Object>().having((e) => '$e', 'message', contains('THOR-S043')),
        ),
      );
    } finally {
      editor.nodes.value = old;
    }
  });

  test('children must be a method of the state taking the item', () {
    expect(
      () => _html(
        Watch.tree(
          editor.roots,
          itemKey: editor.idOf,
          children: (Node n) => n.children,
          each: (row, children) => children,
        ),
      ),
      throwsA(
        isA<Object>().having((e) => '$e', 'message', contains('THOR-S001')),
      ),
    );
  });

  _lite();
}

// --- The lite engine in node over the server's HTML ----------------------

final _hasNode = () {
  try {
    return Process.runSync('node', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();

// What thor_builder writes for EditorState, by hand (the translator's
// output for these one-line methods).
const _stateJs = r'''
thor.def('EditorState', ($) => {
  const nodes = $.state('nodes', globalThis.initialNodes);
  const picked = $.state('picked', '');
  return {
    roots: () => nodes.value,
    idOf: (n) => n.id,
    labelOf: (n) => n.label,
    childrenOf: (n) => n.children,
    select: (a) => { globalThis.selected = a; },
    picked: () => picked.value,
    pick: (k) => { picked.value = k; },
    set: (v) => { nodes.value = v; },
    $s: { nodes },
  };
}, { eager: true });
''';

Object? _json(List<Node> nodes) => [for (final n in nodes) n.toJson()];

// The page's body for [nodes], as the server draws it.
Future<String> _bodyFor(
  List<Node> nodes, {
  Widget Function() tree = _tree,
  String picked = '',
}) async {
  final old = editor.nodes.value;
  editor.nodes.value = nodes;
  editor.picked.value = picked;
  try {
    final html = await _html(tree());
    final body = html.substring(
      html.indexOf('>', html.indexOf('<body')) + 1,
      html.indexOf('</body>'),
    );
    return body.replaceAll(RegExp(r'<script[\s\S]*?</script>'), '');
  } finally {
    editor.nodes.value = old;
    editor.picked.value = '';
  }
}

// Loads the page drawn for [first] in node, starts the engine (minified or
// not), then runs [script] (`S`: the state; `box()`: the tree's element;
// `serverBox(name)`: the element the server drew for one of [pages]).
Future<Map<String, Object?>> _runLite(
  List<Node> first,
  Map<String, List<Node>> pages,
  String script, {
  required bool minify,
  Widget Function() tree = _tree,
  Map<String, String> picked = const {},
}) async {
  String read(String p) =>
      File('../thor_engine/lib/lite/$p').readAsStringSync();
  final bundle = liteBundle(
    runtime: read('runtime.js'),
    parts: {
      for (final p in ['lists', 'row_states', 'attributes', 'row_attributes'])
        p: read('parts/$p.js'),
    },
    stateJs: _stateJs,
    minify: minify,
  );
  final drawn = {
    for (final e in pages.entries)
      e.key: await _bodyFor(e.value, tree: tree, picked: picked[e.key] ?? ''),
  };
  final js =
      '''
${File('test/support/mini_dom.js').readAsStringSync()}
const { parseHtml, outer, body } = miniDom;
body.append(parseHtml(${jsonEncode(await _bodyFor(first, tree: tree))}));
globalThis.initialNodes = ${jsonEncode(_json(first))};
const pages = ${jsonEncode(drawn)};
const data = ${jsonEncode({for (final e in pages.entries) e.key: _json(e.value)})};
const box = () => document.querySelector('[data-tl]');
const serverBox = (n) => parseHtml(pages[n]).querySelector('[data-tl]');
const step = () => new Promise((r) => setTimeout(r, 0));
const row = (k) => box().querySelectorAll('[data-tk]').find((e) => e.getAttribute('data-tk') === k);
$bundle
(async () => {
  await step();
  const S = thor.use('EditorState');
  const out = {};
$script
  console.log(JSON.stringify(out));
})().catch((e) => { console.error(e); process.exit(1); });
''';
  final r = Process.runSync('node', ['-e', js]);
  if (r.exitCode != 0 || '${r.stderr}'.isNotEmpty) {
    fail('node failed:\n${r.stderr}');
  }
  return jsonDecode((r.stdout as String).trim()) as Map<String, Object?>;
}

const _start = [
  Node('app', 'App', [
    Node('col', 'Column', [Node('t1', 'Text'), Node('t2', 'Text')]),
  ]),
  Node('fab', 'Fab'),
];

// Every kind of change at once: a label deep down, a grandchild added, a
// row removed, a row moved to another parent, siblings reordered.
const _edited = [
  Node('fab', 'Fab'),
  Node('app', 'App', [
    Node('col', 'Column', [
      Node('t1', 'Title', [Node('s1', 'Span')]),
      Node('pad', 'Padding'),
    ]),
    Node('t2', 'Text'),
  ]),
];

void _lite() {
  for (final minify in [false, true]) {
    group(
      'lite (${minify ? 'minified' : 'as written'})',
      skip: _hasNode ? false : 'needs node',
      () {
        test('the engine takes the server\'s tree as it is', () async {
          final out = await _runLite(
            _start,
            {'start': _start},
            '''
const before = row('t2');
S.set(data.start);
await step();
out.same = outer(box()) === outer(serverBox('start'));
out.kept = row('t2') === before;
''',
            minify: minify,
          );
          expect(out, {'same': true, 'kept': true});
        });

        test('every change at any depth draws what the server would, rows '
            'that stay under their parent keep their element (and an open '
            '<details>)', () async {
          final out = await _runLite(
            _start,
            {'edited': _edited},
            '''
const col = row('col');
col.setAttribute('open', '');
const t2 = row('t2');
S.set(data.edited);
await step();
out.colKept = row('col') === col;
out.stillOpen = col.hasAttribute('open');
// Each level is keyed on its own: a row moved to another parent is a new row
// there.
out.t2New = row('t2') !== t2 && !t2.isConnected;
col.removeAttribute('open');
out.same = outer(box()) === outer(serverBox('edited'));
if (!out.same) { out.got = outer(box()); out.want = outer(serverBox('edited')); }
''',
            minify: minify,
          );
          expect(out['got'], out['want']);
          expect(out, {
            'colKept': true,
            'stillOpen': true,
            't2New': true,
            'same': true,
          });
        });

        test('a tree that arrives later (an empty first paint) is drawn whole '
            'from the one template', () async {
          final out = await _runLite(
            const [],
            {'edited': _edited, 'empty': const []},
            '''
out.empty = outer(box()) === outer(serverBox('empty'));
S.set(data.edited);
await step();
out.same = outer(box()) === outer(serverBox('edited'));
if (!out.same) { out.got = outer(box()); out.want = outer(serverBox('edited')); }
S.set([]);
await step();
out.emptyAgain = outer(box()) === outer(serverBox('empty'));
''',
            minify: minify,
          );
          expect(out['got'], out['want']);
          expect(out, {'empty': true, 'same': true, 'emptyAgain': true});
        });

        test('row.selected patches the row picked at any depth, the rows '
            'the browser drew too', () async {
          final out = await _runLite(
            _start,
            {'t1': _start, 's1': _edited},
            '''
// The rows (the part row_states prepares the template at load: its
// patches move out of it).
const rows = (b) => { const c = b.cloneNode(true); c.querySelectorAll('template').forEach((t) => t.remove()); return outer(c); };
S.pick('t1');
await step();
out.t1 = rows(box()) === rows(serverBox('t1'));
S.set(data.s1);
await step();
S.pick('s1');
await step();
out.s1 = rows(box()) === rows(serverBox('s1'));
if (!out.s1) { out.got = rows(box()); out.want = rows(serverBox('s1')); }
''',
            minify: minify,
            tree: _pickTree,
            picked: {'t1': 't1', 's1': 's1'},
          );
          expect(out['got'], out['want']);
          expect(out, {'t1': true, 's1': true});
        });

        test(
          'a row drawn in the browser carries its key in its callback',
          () async {
            final out = await _runLite(
              const [],
              {'edited': _edited},
              '''
S.set(data.edited);
await step();
const b = row('s1').querySelector('[data-tx]');
out.tx = b.getAttribute('data-tx');
''',
              minify: minify,
            );
            expect(out['tx'], 's1');
          },
        );
      },
    );
  }
}
