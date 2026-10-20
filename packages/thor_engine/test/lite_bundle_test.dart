@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/lite.dart';

/// What node prints running [js] (or null without node).
String? _node(String js) {
  final r = Process.runSync('node', ['-e', js]);
  if (r.exitCode != 0) fail('node failed:\n${r.stderr}\n$js');
  return (r.stdout as String).trim();
}

/// Whether node parses [js] (without running it).
bool _parses(String js) {
  final dir = Directory.systemTemp.createTempSync('lite');
  try {
    final f = File('${dir.path}/bundle.js')..writeAsStringSync(js);
    final r = Process.runSync('node', ['--check', f.path]);
    if (r.exitCode != 0) fail('node --check failed:\n${r.stderr}');
    return true;
  } finally {
    dir.deleteSync(recursive: true);
  }
}

final _hasNode = Process.runSync('node', ['--version']).exitCode == 0;

void main() {
  group('minifyJs', () {
    test('drops comments and collapses whitespace', () {
      expect(
        minifyJs('''
// a comment
const a = 1; /* block */ const b = a + 2;
function f ( x ) {
  return x * 2 ;
}
'''),
        'const a=1;const b=a+2;function f(x){return x*2;}',
      );
    });

    test('keeps strings, template literals and regexes as they are', () {
      const src = r'''
const s = '// not a comment', t = "a  /* b */  c";
const u = `x  ${ `inner ${ s + "}" }` }  y // z`;
const r = /^(a|b)\/[/]c/g.test(s) ? /x/ : 1;
''';
      final m = minifyJs(src);
      expect(m, contains("'// not a comment'"));
      expect(m, contains('"a  /* b */  c"'));
      expect(m, contains(r'`x  ${`inner ${s+"}"}`}  y // z`'));
      expect(m, contains(r'/^(a|b)\/[/]c/g.test(s)?/x/:1'));
    });

    test('division is not a regex', () {
      expect(
        minifyJs('const a = (b) / 2 / c;\nx = y[0] / z;'),
        'const a=(b)/2/c;x=y[0]/z;',
      );
    });

    test('never glues + +, - - or words', () {
      expect(
        minifyJs('a = b + +c - -d; return typeof x'),
        'a=b+ +c- -d;return typeof x',
      );
    });

    test('keeps a line break where a statement may end without ;', () {
      expect(
        minifyJs('let a = 1\nlet b = a\n(f)()\n'),
        'let a=1\nlet b=a\n(f)()',
      );
      expect(minifyJs('a = {\n  x: 1,\n}\n'), 'a={x:1,}');
    });

    for (final bad in ["'open", '`open', '/* open', 'x = /open']) {
      test('$bad is an error, not a guess', () {
        expect(() => minifyJs(bad), throwsFormatException);
      });
    }

    test(
      'the runtime and every part minify to code that runs the same',
      () {
        final dir = Directory('lib/lite');
        final runtime = File('${dir.path}/runtime.js').readAsStringSync();
        final parts = {
          for (final p in liteParts)
            p: File('${dir.path}/parts/$p.js').readAsStringSync(),
        };
        const state = '''
thor.def('T', (\$) => { const n = \$.state('n', 1); return { n: () => n.value }; });
''';
        final min = liteBundle(runtime: runtime, parts: parts, stateJs: state);
        final raw = liteBundle(
          runtime: runtime,
          parts: parts,
          stateJs: state,
          minify: false,
        );
        expect(min.length, lessThan(raw.length * 0.65));
        // The whole bundle parses; the runtime alone (no DOM here, only
        // what loads) defines the same API minified or not.
        expect(_parses(min), isTrue);
        const probe = '''
globalThis.window = globalThis; globalThis.document = { addEventListener() {}, readyState: 'loading', querySelectorAll: () => [] };
globalThis.queueMicrotask = () => {};
''';
        String api(String js) => _node(
          '$probe$js\nconsole.log(Object.keys(thor).sort().join(","))',
        )!;
        String alone({required bool minify}) => liteBundle(
          runtime: runtime,
          parts: const {},
          stateJs: state,
          minify: minify,
        );
        expect(api(alone(minify: true)), api(alone(minify: false)));
      },
      skip: _hasNode ? false : 'needs node',
    );
  });

  group('litePartsFor', () {
    test('stream: only a server app that builds a FutureBuilder ships it', () {
      const page = 'FutureBuilder<List<int>>(future: data.rows, builder: b)';
      expect(litePartsFor(stateJs: '', engineEntry: '', sources: page), [
        'stream',
      ]);
      expect(
        litePartsFor(stateJs: '', engineEntry: '', sources: 'Text("x")'),
        isEmpty,
      );
      // A static site is complete when it is exported: nothing arrives late.
      expect(
        litePartsFor(stateJs: '', engineEntry: '', pages: [''], sources: page),
        isEmpty,
      );
    });

    test(
      'stream: a LazyPiece brings it too (the content it loads is late)',
      () {
        const page = 'LazyPiece<List<int>>(id: "x", load: l, builder: b)';
        expect(litePartsFor(stateJs: '', engineEntry: '', sources: page), [
          'stream',
        ]);
        expect(
          litePartsFor(
            stateJs: '',
            engineEntry: '',
            pages: [''],
            sources: page,
          ),
          isEmpty,
        );
      },
    );

    test('never ships dev_state (only thor dev adds it)', () {
      const markup =
          ' data-tvf= data-tfa= data-t-validate data-t-dd data-t-date '
          'commandfor= data-tcv= data-tks= data-tg=';
      final parts = litePartsFor(
        stateJs:
            '// thor-lite parts: animation_controller controllers duration\n',
        engineEntry: '',
        pages: [markup],
      );
      expect(parts, isNot(contains('dev_state')));
      expect(liteParts.last, 'dev_state');
    });

    test('the parts the states name, in bundle order', () {
      expect(
        litePartsFor(
          stateJs: '// thor-lite parts: duration datetime\n{}',
          engineEntry: '',
        ),
        ['datetime', 'duration'],
      );
    });

    test('a static site: a feature part only if a page has its markup', () {
      const entry = 'FormsFeature(), DropdownMenuFeature()';
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: entry,
          pages: ['<form><input data-t-validate="x"></form>'],
        ),
        ['forms'],
      );
    });

    test('the tabs and menu parts ship by their markup or their feature', () {
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'TabsFeature(), MenuFeature()',
          pages: [
            '<div role="radiogroup" data-t-tabs><label>x</label></div>',
            '<div popover role="menu" data-t-menu>x</div>',
          ],
        ),
        ['tabs', 'menu'],
      );
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'TabsFeature(), MenuFeature()',
          pages: ['<p>no tabs here</p>'],
        ),
        isEmpty,
      );
      expect(litePartsFor(stateJs: '', engineEntry: 'MenuFeature()'), ['menu']);
    });

    test('element events ship only with their markup or feature', () {
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'ElementEventsFeature()',
          pages: ['<div data-t-ev="enter:S.a">x</div>'],
        ),
        ['element_events'],
      );
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'ElementEventsFeature()',
          pages: ['<div data-t-on="click:S.a">x</div>'],
        ),
        isEmpty,
      );
      expect(litePartsFor(stateJs: '', engineEntry: 'ElementEventsFeature()'), [
        'element_events',
      ]);
    });

    test('size animations ship with their markup or feature', () {
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'SizeAnimationsFeature()',
          pages: ['<div data-tsz="200|linear|200"><div></div></div>'],
        ),
        ['animated_size'],
      );
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'SizeAnimationsFeature(), GesturesFeature()',
          pages: ['<p>x</p>'],
        ),
        isEmpty,
      );
    });

    test('the carousel part ships with its markup or feature', () {
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'CarouselFeature()',
          pages: ['<div data-t-carousel="5000"></div>'],
        ),
        ['carousel'],
      );
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'CarouselFeature()',
          pages: ['<div class="a" data-t-cv data-thor="CarouselControls">'],
        ),
        ['carousel'],
      );
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'CarouselFeature()',
          pages: ['<p>x</p>'],
        ),
        isEmpty,
      );
    });

    test('the dismissible part ships with its markup or feature only', () {
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'DismissibleFeature()',
          pages: [
            '<li data-t-dm="dismissed:A.b" data-t-dm-cfg="h|0.4|0.4|-|-|200|300">',
          ],
        ),
        ['dismissible'],
      );
      // The feature without the markup, and a page without the feature.
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'DismissibleFeature()',
          pages: ['<p>x</p>'],
        ),
        isEmpty,
      );
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'GesturesFeature()',
          pages: ['<div data-tg="swipe:A.b">'],
        ),
        ['gestures'],
        reason: 'a Gesture does not bring the Dismissible part',
      );
      // A server app: the feature the app's sources named is enough.
      expect(litePartsFor(stateJs: '', engineEntry: 'DismissibleFeature()'), [
        'dismissible',
      ]);
    });

    test('the drag parts ship with a draggable or a target, kit first', () {
      for (final markup in [
        '<div data-t-dg="start:A.b" data-t-dg-type="String">',
        '<div data-t-dg data-t-dg-type="String">',
        '<div data-t-dt data-t-dg-type="int">',
        '<div data-t-dt="drop:A.b" data-t-dg-type="int">',
      ]) {
        expect(
          litePartsFor(
            stateJs: '',
            engineEntry: 'DragDropFeature()',
            pages: [markup],
          ),
          ['drag_kit', 'drag_drop'],
          reason: markup,
        );
      }
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'DragDropFeature()',
          pages: ['<div data-t-dg-cfg="f|0|c|1|0|0">'],
        ),
        isEmpty,
        reason: 'a stray attribute is not a draggable',
      );
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'DragDropFeature()',
          pages: ['<p>x</p>'],
        ),
        isEmpty,
      );
      // A server app: the feature its sources named.
      expect(litePartsFor(stateJs: '', engineEntry: 'DragDropFeature()'), [
        'drag_kit',
        'drag_drop',
      ]);
    });

    test('the native drag part ships with its own markers, kit first', () {
      for (final markup in [
        '<div draggable="true" data-t-nd="start:A.b" data-t-nd-type="String">',
        '<div data-t-nt="drop:A.b" data-t-nd-type="int">',
        '<div data-t-nd data-t-nd-cfg="text/plain|copy">',
      ]) {
        expect(
          litePartsFor(
            stateJs: '',
            engineEntry: 'DragDropFeature()',
            pages: [markup],
          ),
          ['drag_kit', 'native_drag'],
          reason: markup,
        );
      }
      // The attributes that go with it are not a native draggable.
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'DragDropFeature()',
          pages: ['<div data-t-nd-data="x" data-t-nd-cfg="a|b">'],
        ),
        isEmpty,
      );
      // A server app: only the widgets its sources use.
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'DragDropFeature()',
          sources: 'Draggable<String>(child: x, feedback: y)',
        ),
        ['drag_kit', 'drag_drop'],
      );
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'DragDropFeature()',
          sources: 'NativeDraggable<String>(child: x)',
        ),
        ['drag_kit', 'native_drag'],
      );
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'DragDropFeature()',
          sources:
              'NativeDragTarget<String>(builder: b); DragTarget(builder: b)',
        ),
        ['drag_kit', 'drag_drop', 'native_drag'],
      );
    });

    test('the reorderable part ships with a reorderable list, kit first', () {
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'ReorderableFeature()',
          pages: ['<div data-t-ro="reorder:A.b" data-t-ro-cfg="v|1">'],
        ),
        ['drag_kit', 'reorderable'],
      );
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'ReorderableFeature()',
          pages: ['<div data-t-ro data-t-ro-cfg="h|0">'],
        ),
        ['drag_kit', 'reorderable'],
      );
      // The item and the handle markers alone are not a list.
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'ReorderableFeature()',
          pages: ['<div data-t-ro-item><button data-t-ro-h></button></div>'],
        ),
        isEmpty,
      );
      // With a draggable on the page too, the kit is sewn in once.
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'DragDropFeature(), ReorderableFeature()',
          pages: ['<div data-t-ro="x:A.b"></div><div data-t-dg></div>'],
        ),
        ['drag_kit', 'drag_drop', 'reorderable'],
      );
      expect(litePartsFor(stateJs: '', engineEntry: 'ReorderableFeature()'), [
        'drag_kit',
        'reorderable',
      ]);
    });

    test('autocomplete ships with its markup or feature, after dropdown', () {
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'AutocompleteFeature()',
          pages: ['<div data-t-ac="f"><input></div>'],
        ),
        ['autocomplete'],
      );
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'AutocompleteFeature()',
          pages: ['<p>x</p>'],
        ),
        isEmpty,
      );
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry:
              'CommandsFeature(), AutocompleteFeature(), DropdownMenuFeature()',
        ),
        ['dropdown', 'autocomplete', 'commands'],
      );
    });

    test('a server app: every part its features name; row states only '
        'with a row.watch', () {
      const entry = 'ListsFeature(), RowAttributes(), CommandsFeature()';
      // row_attributes brings the attributes part it uses.
      expect(litePartsFor(stateJs: '', engineEntry: entry), [
        'lists',
        'attributes',
        'row_attributes',
        'commands',
      ]);
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: entry,
          sources: 'each: (row) => row.watch(s.on, builder: b)',
        ),
        ['lists', 'row_states', 'attributes', 'row_attributes', 'commands'],
      );
    });

    test('animated_list ships with animatedRows, or with its markup', () {
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry:
              'ListsFeature(rowAttributes: RowAttributes(), '
              'animatedRows: true)',
        ),
        ['lists', 'attributes', 'row_attributes', 'animated_list'],
      );
      expect(
        litePartsFor(stateJs: '', engineEntry: 'ListsFeature()'),
        ['lists'],
        reason: 'a list that does not animate its exit',
      );
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'ListsFeature(animatedRows: true)',
          pages: ['<div data-tl="S.l" data-tlk="S.k" data-tlx="300"></div>'],
        ),
        ['lists', 'animated_list'],
      );
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'ListsFeature(animatedRows: true)',
          pages: ['<div data-tl="S.l" data-tlk="S.k"></div>'],
        ),
        ['lists'],
      );
    });

    // The window itself runs in a real browser (test/client_test.dart for the
    // dart2js engine, tool/thor e2e for this one); these keep the two lite
    // sources in step with it.
    test('virtual_list: a list that scrolls itself is its own scroller, and '
        'a wrapped list keeps data-tlv with the rows', () {
      final part = File('lib/lite/parts/virtual_list.js').readAsStringSync();
      expect(part, contains('for (let p = el; p && p !== D.body;'));
      final lists = File('lib/lite/parts/lists.js').readAsStringSync();
      expect(
        lists,
        contains("['data-tl', 'data-tlk', 'data-tlv']) el.hasAttribute(a)"),
      );
      expect(
        lists,
        contains(
          "for (const a of ['data-tl', 'data-tlk', 'data-tlv']) el.removeAttribute(a)",
        ),
      );
    });

    test('lists: keyed lists ship with their markup or ListsFeature, and '
        'every row part brings them', () {
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'ListsFeature()',
          pages: ['<ul data-tl="S.items" data-tlk="S.key"></ul>'],
        ),
        ['lists'],
      );
      // A row template alone (`data-tlt`) or the key (`data-tlk`) is not a list.
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'ListsFeature()',
          pages: ['<p data-tt="S.label">0</p>', '<template data-tlt="x">'],
        ),
        isEmpty,
      );
      expect(
        litePartsFor(stateJs: '', engineEntry: 'VariantsFeature()'),
        isNot(contains('lists')),
      );
      for (final row in ['row_states', 'row_attributes', 'animated_list']) {
        expect(
          litePartsFor(stateJs: '// thor-lite parts: $row\n', engineEntry: ''),
          contains('lists'),
          reason: row,
        );
      }
      expect(
        liteParts.indexOf('lists'),
        lessThan(liteParts.indexOf('row_states')),
        reason: 'the row parts push into its rowParts when they load',
      );
    });

    test('view_transition: an AnimatedSwitcher ships it, by its markup or '
        'its source', () {
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'VariantsFeature()',
          pages: ['<div data-tv="S.on" data-t-vt="t0">x</div>'],
        ),
        ['view_transition'],
      );
      // The page's rules name it (`:root[data-t-vt]`): not an AnimatedSwitcher.
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'VariantsFeature()',
          pages: [
            '<style>:root[data-t-vt] [data-t-vt]{}</style><div data-tv="S.on">',
          ],
        ),
        isEmpty,
      );
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'VariantsFeature()',
          sources: 'AnimatedSwitcher(duration: d, child: c)',
        ),
        ['view_transition'],
      );
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'VariantsFeature()',
          sources: 'Watch(s.on, builder: (on) => Text("x"))',
        ),
        isEmpty,
      );
    });

    test('virtual_list ships with a windowed list (VirtualLists in the entry, '
        'or data-tlv in a static page)', () {
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'ListsFeature(virtualLists: VirtualLists())',
        ),
        ['lists', 'virtual_list'],
      );
      expect(litePartsFor(stateJs: '', engineEntry: 'ListsFeature()'), [
        'lists',
      ]);
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'ListsFeature(virtualLists: VirtualLists())',
          pages: ['<div data-tl="S.rows" data-tlv="34"></div>'],
        ),
        ['lists', 'virtual_list'],
      );
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: 'ListsFeature(virtualLists: VirtualLists())',
          pages: ['<div data-tl="S.rows"></div>'],
        ),
        ['lists'],
      );
    });

    test('key_actions ships for Shortcuts, Actions or onKeyEvent, not for '
        'CallbackShortcuts, and brings the shortcuts part', () {
      const entry = 'ShortcutsFeature()';
      expect(litePartsFor(stateJs: '', engineEntry: entry), ['shortcuts']);
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: entry,
          sources: 'CallbackShortcuts(bindings: {}, child: x)',
        ),
        ['shortcuts'],
      );
      for (final s in [
        'Shortcuts(shortcuts: {}, child: x)',
        'Actions(actions: {}, child: x)',
        'Focus(onKeyEvent: g.onKey, child: x)',
      ]) {
        expect(litePartsFor(stateJs: '', engineEntry: entry, sources: s), [
          'shortcuts',
          'key_actions',
        ], reason: s);
      }
      // A static site: by its markup.
      for (final page in [
        '<div data-tsi="m+s>SaveIntent"></div>',
        '<div data-tke="G.onKey"></div>',
      ]) {
        expect(litePartsFor(stateJs: '', engineEntry: entry, pages: [page]), [
          'shortcuts',
          'key_actions',
        ]);
      }
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: entry,
          pages: ['<div data-tks="m+s>A.b"></div>'],
        ),
        ['shortcuts'],
      );
    });

    test('page_view ships only for an onPageChanged (not for the other '
        'element events)', () {
      const entry = 'ElementEventsFeature()';
      expect(litePartsFor(stateJs: '', engineEntry: entry), ['element_events']);
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: entry,
          sources: 'MouseRegion(onEnter: s.hover, child: x)',
        ),
        ['element_events'],
      );
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: entry,
          sources: 'PageView(onPageChanged: deck.changed, children: [])',
        ),
        ['element_events', 'page_view'],
      );
      // A static site: by its markup.
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: entry,
          pages: ['<div data-t-ev="enter:A.b;page:A.c"></div>'],
        ),
        ['element_events', 'page_view'],
      );
      expect(
        litePartsFor(
          stateJs: '',
          engineEntry: entry,
          pages: ['<div data-t-ev="enter:A.b"></div>'],
        ),
        ['element_events'],
      );
    });

    test('a PageController brings the scroll part it extends', () {
      expect(
        litePartsFor(
          stateJs: '// thor-lite parts: controllers page_controller\n',
          engineEntry: '',
        ),
        ['controllers', 'scroll_controller', 'page_controller'],
      );
    });

    test('an unknown part is an error', () {
      expect(
        () => litePartsFor(
          stateJs: '// thor-lite parts: wasm\n',
          engineEntry: '',
        ),
        throwsArgumentError,
      );
    });
  });

  test('liteBundle needs the runtime\'s parts line', () {
    expect(
      () => liteBundle(runtime: '(() => {})()', parts: {}, stateJs: ''),
      throwsArgumentError,
    );
  });

  group('trimIntlPart', () {
    final full = File('lib/lite/parts/intl.js').readAsStringSync();

    test('keeps only the app\'s languages, their renamed ones and en', () {
      final trimmed = trimIntlPart(full, ['es', 'pt_BR', 'he']);
      expect(trimmed.length, lessThan(full.length ~/ 2));
      expect(trimmed, contains("'es': R."));
      expect(trimmed, contains("'pt_PT': R."));
      expect(trimmed, contains("'iw': R."), reason: 'he is spelled iw too');
      expect(trimmed, contains("'en': R."));
      expect(trimmed, isNot(contains("'ru': R.")));
      expect(trimmed, isNot(contains("'ar': R.")));
      expect(trimmed, contains('default: () =>'));
    });

    test('answers like the whole part for every locale of those languages', () {
      if (!_hasNode) return markTestSkipped('node is not installed');
      final trimmed = trimIntlPart(full, ['es', 'pt_BR', 'he', 'ar']);
      String run(String part) => _node('''
const thor = {};
$part
const out = [];
for (const l of ['es', 'es_MX', 'pt_BR', 'pt', 'pt_PT', 'he', 'iw', 'ar',
    'ar_EG', 'en', 'en_US', null]) {
  for (const n of [0, 1, 2, 3, 5, 11, 21, 101, 1.5, 0.1, -1, 1000000]) {
    for (const p of [null, 0, 2]) {
      out.push(thor.intl.plural(n, 'Z', 'O', 'T', 'F', 'M', 'X', l, p, false));
    }
  }
}
console.log(out.join(''));
''')!;
      expect(run(trimmed), run(full));
    });

    test('with no languages it keeps the system locale (en) only', () {
      final trimmed = trimIntlPart(full, const []);
      expect(trimmed, contains("'en': R."));
      expect(trimmed, isNot(contains("'es': R.")));
    });
  });
}
