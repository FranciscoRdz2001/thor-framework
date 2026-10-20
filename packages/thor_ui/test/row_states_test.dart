@TestOn('vm')
library;

// The lite engine's row states: a `row.watch` inside the structural variant
// of another, a patch that changes only the `href` of a `<use>`, and the
// class of a cloned row, which must not depend on the live variant of the
// template's states. Run in node over the
// server's HTML (as `watch_tree_test.dart`), as written and minified.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/lite.dart' show liteBundle;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class Item {
  const Item(this.id, {this.group = false, this.open = false, this.kind = 0});
  final String id;
  final bool group;
  final bool open;
  final int kind;

  Map<String, Object?> toJson() => {
    'id': id,
    'group': group,
    'open': open,
    'kind': kind,
  };
}

abstract class _TreeMembers extends ThorState {
  @override
  String get $type => 'TreeState';

  @override
  List<ThorMember> get $members {
    final s = this as TreeState;
    return [
      ThorMember.state('items', s.items),
      ThorMember('list', s.list),
      ThorMember(
        'idOf',
        s.idOf,
        arity: 1,
        callWithItem: (i) => s.idOf(i as Item),
      ),
      ThorMember(
        'isGroup',
        s.isGroup,
        arity: 1,
        callWithItem: (i) => s.isGroup(i as Item),
        variants: const [false, true],
      ),
      ThorMember(
        'isOpen',
        s.isOpen,
        arity: 1,
        callWithItem: (i) => s.isOpen(i as Item),
        variants: const [false, true],
      ),
      ThorMember(
        'kindOf',
        s.kindOf,
        arity: 1,
        callWithItem: (i) => s.kindOf(i as Item),
      ),
    ];
  }
}

class TreeState extends _TreeMembers {
  final items = state<List<Item>>(const []);
  List<Item> list() => items.value;
  String idOf(Item i) => i.id;
  bool isGroup(Item i) => i.group;
  bool isOpen(Item i) => i.open;
  int kindOf(Item i) => i.kind;
}

final tree = TreeState();

const _icons = [
  IconData.svg('icon-a', '<path d="M0 0"/>'),
  IconData.svg('icon-b', '<path d="M1 1"/>'),
  IconData.svg('icon-c', '<path d="M2 2"/>'),
];

// A state inside the variant of another.
Widget _nested() => Watch.list(
  tree.list,
  itemKey: tree.idOf,
  each: (row) => row.watch(
    tree.isGroup,
    builder: (g) => g
        ? row.watch(tree.isOpen, builder: (o) => Text(o ? 'open' : 'closed'))
        : const Text('leaf'),
  ),
);

// The states differ only in the `href` of the icon's `<use>`.
Widget _icon() => Watch.list(
  tree.list,
  itemKey: tree.idOf,
  each: (row) =>
      row.watch(tree.kindOf, count: 3, builder: (k) => Icon(_icons[k])),
);

// The template draws the live variant of its states, and what the
// layout infers from it (`Stack.fillsWidth`) must not reach the row's class.
Widget _stack() => Watch.list(
  tree.list,
  itemKey: tree.idOf,
  each: (row) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        child: Stack(
          children: [
            row.watch(
              tree.isOpen,
              builder: (on) => on
                  ? const SizedBox(width: double.infinity, child: Text('on'))
                  : const SizedBox.shrink(),
            ),
            const Positioned.fill(child: Text('base')),
          ],
        ),
      ),
    ],
  ),
);

final _hasNode = () {
  try {
    return Process.runSync('node', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();

// What thor_builder writes for TreeState, by hand.
const _stateJs = r'''
thor.def('TreeState', ($) => {
  const items = $.state('items', globalThis.initialItems);
  return {
    list: () => items.value,
    idOf: (i) => i.id,
    isGroup: (i) => i.group,
    isOpen: (i) => i.open,
    kindOf: (i) => i.kind,
    set: (v) => { items.value = v; },
    $s: { items },
  };
}, { eager: true });
''';

Object? _json(List<Item> items) => [for (final i in items) i.toJson()];

Future<String> _bodyFor(List<Item> items, Widget Function() page) async {
  final old = tree.items.value;
  tree.items.value = items;
  try {
    final html = await renderHtml(ThorApp(child: page()));
    final body = html.substring(
      html.indexOf('>', html.indexOf('<body')) + 1,
      html.indexOf('</body>'),
    );
    return body.replaceAll(RegExp(r'<script[\s\S]*?</script>'), '');
  } finally {
    tree.items.value = old;
  }
}

// Loads the page drawn for [first], starts the engine (minified or not), then
// runs [script] (`S`: the state; `box()`: the list's element; `serverBox(n)`:
// the one the server drew for page [n]; `rows(b)`: the markup of [b] without
// its templates).
Future<Map<String, Object?>> _runLite(
  Widget Function() page,
  List<Item> first,
  Map<String, List<Item>> pages,
  String script, {
  required bool minify,
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
    for (final e in pages.entries) e.key: await _bodyFor(e.value, page),
  };
  final js =
      '''
${File('test/support/mini_dom.js').readAsStringSync()}
const { parseHtml, outer, body } = miniDom;
body.append(parseHtml(${jsonEncode(await _bodyFor(first, page))}));
globalThis.initialItems = ${jsonEncode(_json(first))};
const pages = ${jsonEncode(drawn)};
const data = ${jsonEncode({for (final e in pages.entries) e.key: _json(e.value)})};
const box = () => document.querySelector('[data-tl]');
const serverBox = (n) => parseHtml(pages[n]).querySelector('[data-tl]');
const step = () => new Promise((r) => setTimeout(r, 0));
const rows = (b) => { const c = b.cloneNode(true); c.querySelectorAll('template').forEach((t) => t.remove()); return outer(c); };
$bundle
(async () => {
  await step();
  const S = thor.use('TreeState');
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

const _compare = '''
out.same = rows(box()) === rows(serverBox('later'));
if (!out.same) { out.got = rows(box()); out.want = rows(serverBox('later')); }
''';

void main() {
  initializeThorTests();

  for (final minify in [false, true]) {
    group(
      'lite (${minify ? 'minified' : 'as written'})',
      skip: _hasNode ? false : 'needs node',
      () {
        test('a row.watch inside the variant of another gets its value '
            'in the rows the browser clones', () async {
          const later = [
            Item('a'),
            Item('b', group: true),
            Item('c', group: true, open: true),
          ];
          const toggled = [
            Item('a'),
            Item('b', group: true, open: true),
            Item('c', group: true),
          ];
          final out = await _runLite(
            _nested,
            const [Item('a')],
            {'later': later, 'toggled': toggled},
            '''
S.set(data.later);
await step();
$_compare
S.set(data.toggled);
await step();
out.toggled = rows(box()) === rows(serverBox('toggled'));
if (!out.toggled) { out.got2 = rows(box()); out.want2 = rows(serverBox('toggled')); }
''',
            minify: minify,
          );
          expect(out['got'], out['want']);
          expect(out['got2'], out['want2']);
          expect(out, {'same': true, 'toggled': true});
        });

        test('a state patch that changes only the href of a <use> is '
            'applied', () async {
          const later = [Item('a', kind: 2), Item('b', kind: 1), Item('c')];
          final out = await _runLite(
            _icon,
            const [Item('a')],
            {'later': later},
            'S.set(data.later);\nawait step();\n$_compare',
            minify: minify,
          );
          expect(out['got'], out['want']);
          expect(out, {'same': true});
        });

        test('the class of a cloned row does not depend on the live '
            "variant of the template's states", () async {
          const later = [
            Item('a', open: true),
            Item('b'),
            Item('c', open: true),
          ];
          final out = await _runLite(
            _stack,
            const [Item('a', open: true)],
            {'later': later},
            'S.set(data.later);\nawait step();\n$_compare',
            minify: minify,
          );
          expect(out['got'], out['want']);
          expect(out, {'same': true});
        });
      },
    );
  }
}
