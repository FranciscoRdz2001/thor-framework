// Attacks on the subtrees the dart2js engine binds after the first scan
// (variant copies, cloned rows, late parts): what it retains after thousands
// of swaps, no duplicate effects after rows leave and come back, a part that
// arrives twice, swaps inside a batch, lists inside variants inside rows.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:test/test.dart';
import 'package:thor_engine_oracle/client.dart';
import 'package:thor_engine_oracle/src/probe.dart';
import 'package:web/web.dart' as web;

web.HTMLElement mount(String html) {
  final root = web.document.createElement('div') as web.HTMLElement;
  root.innerHTML = html.toJS;
  web.document.body!.append(root);
  // ignore: unnecessary_lambdas
  addTearDown(() => root.remove());
  return root;
}

class _Nest extends ThorState {
  final l1 = state(false);
  final l2 = state(false);
  final l3 = state(false);
  final lab = state('L0');
  final mode = state(false);
  final items = state(const ['x', 'q']);
  final nitems = state(const ['n1', 'n2']);

  /// How many times `label` ran: a row that left must not keep it running.
  var labelCalls = 0;

  @override
  String get $type => 'S';

  @override
  List<ThorMember> get $members => [
    ThorMember.state('l1', l1, variants: const [false, true]),
    ThorMember.state('l2', l2, variants: const [false, true]),
    ThorMember.state('l3', l3, variants: const [false, true]),
    ThorMember.state('mode', mode, variants: const [false, true]),
    ThorMember.state('items', items),
    ThorMember.state('nitems', nitems),
    ThorMember('label', label, call: (_) => label()),
    ThorMember('key', itemKey, arity: 1, callWithItem: (i) => i! as String),
    ThorMember('name', name, arity: 1, callWithItem: (i) => i! as String),
    ThorMember('tog1', tog1, call: (_) => tog1()),
    ThorMember('tog2', tog2, call: (_) => tog2()),
    ThorMember('tog3', tog3, call: (_) => tog3()),
  ];

  String label() {
    labelCalls++;
    return lab.value;
  }

  String itemKey(String i) => i;
  String name(String i) => i;
  void tog1() => l1.value = !l1.value;
  void tog2() => l2.value = !l2.value;
  void tog3() => l3.value = !l3.value;
}

// The text nodes of [el] (a template's content is not in the page), joined by
// a space.
String _text(web.Node el) {
  final out = <String>[];
  void walk(web.Node n) {
    if (n.nodeType == web.Node.TEXT_NODE) {
      final t = (n.textContent ?? '').trim();
      if (t.isNotEmpty) out.add(t);
      return;
    }
    for (var c = n.firstChild; c != null; c = c.nextSibling) {
      walk(c);
    }
  }

  walk(el);
  return out.join(' ');
}

web.Element _q(web.Element root, String selector) =>
    root.querySelector(selector)!;

// What the loader does for a part that arrives late: the nodes in place,
// then `thor:stream` on <html>.
void _stream(web.Element host, String html) {
  host.innerHTML = html.toJS;
  final nodes = [
    for (var i = 0; i < host.children.length; i++) host.children.item(i)!,
  ];
  final detail = JSObject()
    ..['nodes'] = nodes.map((n) => n as JSAny).toList().toJS;
  web.document.documentElement!.dispatchEvent(
    web.CustomEvent('thor:stream', web.CustomEventInit(detail: detail)),
  );
}

// Three levels: the state of each level only exists in the template of the
// one above.
const _levels =
    '<div id="box"><p data-tv="S.l1">A0</p>'
    '<template data-tvt="S.l1" data-i="1"><div data-tv="S.l1">A1 '
    '<p data-tv="S.l2">B0</p>'
    '<template data-tvt="S.l2" data-i="1"><div data-tv="S.l2">B1 '
    '<p data-tv="S.l3">C0</p>'
    '<template data-tvt="S.l3" data-i="1"><p data-tv="S.l3">C1</p></template>'
    '</div></template></div></template></div>';

// A row with a text and a state of another state (`S.label`, `S.mode`).
const _otherRow =
    '<u data-tt="S.label">L0</u><i data-tv="S.mode">a</i>'
    '<template data-tvt="S.mode" data-i="1"><i data-tv="S.mode">b</i>'
    '</template>';

web.HTMLElement _page(String html, _Nest s) {
  final root = mount(html);
  addTearDown(startThor([s], root: root, features: allEngineFeatures));
  return root;
}

void main() {
  _rowReaderTests();
  test(
    '1000 swaps of a variant with a row inside keep what they retain bounded',
    () async {
      final s = _Nest();
      final root = _page(
        '<ul id="l" data-tl="S.items" data-tlk="S.key">'
        '<li data-tk="x"><b data-tf="S.name">x</b>$_inner</li>'
        '<template data-tlt="S.items"><li><b data-tf="S.name"></b>$_inner'
        '</li></template></ul>',
        s,
      );
      for (var round = 0; round < 3; round++) {
        for (var i = 0; i < 1000; i++) {
          s.mode.value = !s.mode.value;
        }
        await Future<void>.delayed(Duration.zero);
      }
      final after = EngineProbe.total();
      for (var i = 0; i < 4000; i++) {
        s.mode.value = !s.mode.value;
      }
      await Future<void>.delayed(Duration.zero);
      final more = EngineProbe.total();
      expect(more.texts, lessThanOrEqualTo(after.texts + 4), reason: '$more');
      expect(more.instances, lessThanOrEqualTo(after.instances + 4));
      expect(more.lists, lessThanOrEqualTo(after.lists + 4));
      expect(more.disposers, after.disposers);
      expect(_text(_q(root, '#l')), isNotEmpty);
    },
  );

  test(
    'rows that come and go 500 times keep one effect and bounded nodes',
    () async {
      final s = _Nest();
      final root = _page(
        '<ul id="l" data-tl="S.items" data-tlk="S.key">'
        '<li data-tk="x"><b data-tf="S.name">x</b>$_otherRow</li>'
        '<template data-tlt="S.items"><li><b data-tf="S.name"></b>$_otherRow'
        '</li></template></ul>',
        s,
      );
      for (var i = 0; i < 500; i++) {
        s.items.value = ['x', 'a$i', 'b$i'];
        s.items.value = ['x'];
        if (i % 100 == 0) await Future<void>.delayed(Duration.zero);
      }
      s.items.value = ['x', 'z'];
      await Future<void>.delayed(Duration.zero);
      s.labelCalls = 0;
      s.lab.value = 'L7';
      expect(_text(_q(root, '#l')), 'x L7 a z L7 a');
      expect(
        s.labelCalls,
        lessThanOrEqualTo(2),
        reason: 'one text effect, not one per row that ever existed',
      );
      expect(EngineProbe.total().texts, lessThan(700));
      s.mode.value = true;
      expect(_text(_q(root, '#l')), 'x L7 b z L7 b');
    },
  );

  test('a late part that arrives twice is bound once', () {
    final s = _Nest();
    final state = web.document.createElement('script') as web.HTMLElement
      ..id = 'thor-state'
      ..textContent = '{}';
    web.document.body!.append(state);
    // ignore: unnecessary_lambdas
    addTearDown(() => state.remove());
    final root = _page('<div id="host"></div>', s);
    final host = _q(root, '#host');
    host.innerHTML = '<u data-tt="S.label">L0</u>$_levels'.toJS;
    final nodes = [
      for (var i = 0; i < host.children.length; i++) host.children.item(i)!,
    ];
    void again() => web.document.documentElement!.dispatchEvent(
      web.CustomEvent(
        'thor:stream',
        web.CustomEventInit(
          detail: (JSObject()
            ..['nodes'] = nodes.map((n) => n as JSAny).toList().toJS),
        ),
      ),
    );
    again();
    again();
    s.labelCalls = 0;
    s.lab.value = 'L1';
    expect(_text(host), startsWith('L1'));
    expect(s.labelCalls, lessThanOrEqualTo(1), reason: 'bound twice');
    s.tog1();
    s.tog2();
    expect(_text(host), 'L1 A1 B1 C0');
    s.tog2();
    s.tog1();
    expect(_text(host), 'L1 A0');
  });

  test('late parts that are replaced let go of what they bound', () {
    final s = _Nest();
    final state = web.document.createElement('script') as web.HTMLElement
      ..id = 'thor-state'
      ..textContent = '{}';
    web.document.body!.append(state);
    // ignore: unnecessary_lambdas
    addTearDown(() => state.remove());
    final root = _page('<div id="host"></div>', s);
    final host = _q(root, '#host');
    final before = EngineProbe.sources.length;
    for (var i = 0; i < 300; i++) {
      _stream(host, '<u data-tt="S.label">L0</u>$_levels');
    }
    expect(
      EngineProbe.sources.length,
      lessThanOrEqualTo(before + 2),
      reason: 'a part that left the page is not kept',
    );
    s.labelCalls = 0;
    s.lab.value = 'L5';
    expect(_text(host), 'L5 A0');
    expect(s.labelCalls, lessThanOrEqualTo(3));
  });

  test('variant swaps inside a batch end at the last value', () {
    final s = _Nest();
    final root = _page(_levels, s);
    final box = _q(root, '#box');
    batch(() {
      s.tog1();
      s.tog2();
      s.tog1();
      s.tog1();
      s.tog3();
    });
    expect(_text(box), 'A1 B1 C1');
    batch(() {
      s.tog1();
      s.tog1();
    });
    expect(_text(box), 'A1 B1 C1');
    batch(() {
      s.tog2();
      s.tog3();
      s.tog1();
    });
    expect(_text(box), 'A0');
    s.tog1();
    expect(_text(box), 'A1 B0');
  });

  test('a list inside a variant inside a row, items change while away', () {
    final s = _Nest();
    const nested =
        '<ul data-tl="S.nitems" data-tlk="S.key">'
        '<template data-tlt="S.nitems"><li><b data-tf="S.name"></b>'
        '<u data-tt="S.label">L0</u></li></template></ul>';
    const inner =
        '<div data-tv="S.mode"><span>-</span></div>'
        '<template data-tvt="S.mode" data-i="1"><div data-tv="S.mode">$nested'
        '</div></template>';
    final root = _page(
      '<ul id="l" data-tl="S.items" data-tlk="S.key">'
      '<template data-tlt="S.items"><li><b data-tf="S.name"></b>$inner'
      '</li></template></ul>',
      s,
    );
    final l = _q(root, '#l');
    s.items.value = ['a', 'b'];
    s.nitems.value = ['1'];
    s.mode.value = true;
    expect(_text(l), 'a 1 L0 b 1 L0');
    for (var i = 0; i < 30; i++) {
      s.mode.value = !s.mode.value;
      s.nitems.value = ['$i', 'k'];
      s.items.value = i.isEven ? ['a'] : ['a', 'b', 'c'];
    }
    s.mode.value = true;
    expect(_text(l), 'a 29 L0 k L0 b 29 L0 k L0 c 29 L0 k L0');
    expect(l.querySelectorAll('ul').length, 3, reason: 'one per row');
    s.lab.value = 'Z';
    expect(_text(l), 'a 29 Z k Z b 29 Z k Z c 29 Z k Z');
  });
}

const _inner =
    '<div data-tv="S.mode"><span>-</span><u data-tt="S.label">L0</u></div>'
    '<template data-tvt="S.mode" data-i="1"><div data-tv="S.mode">'
    '<em>on</em><u data-tt="S.label">L0</u></div></template>';

class _Wide {
  _Wide(this.id, {this.fail = false});
  final String id;
  final bool fail;
  String get a => fail ? throw StateError('a of $id') : 'a-$id';
  String get b => 'b-$id';
  String get city => 'c-$id';
}

class _Wides extends ThorState {
  _Wides(List<_Wide> start) : items = state(start);

  final StateSignal<List<_Wide>> items;

  @override
  String get $type => 'W';

  @override
  List<ThorMember> get $members => [
    ThorMember.state('items', items),
    ThorMember('key', key_, arity: 1, callWithItem: (i) => key_(i! as _Wide)),
  ];

  String key_(_Wide w) => w.id;
}

void _rowReaderTests() {
  group('RowReaders', () {
    test('many lambdas, rows that come later, a getter that throws', () async {
      final readers = RowReaders({
        'a': (it) => (it as _Wide).a,
        'b': (it) => (it as _Wide).b,
        'city': (it) => (it as _Wide).city,
        for (var i = 0; i < 150; i++) 'p$i': (it) => 'p$i-${(it as _Wide).id}',
      });
      final root = mount(
        '<ul id="l" data-tl="W.items" data-tlk="W.key">'
        '<template data-tlt="W.items"><li><b data-tf="\$Rows.a"></b>'
        '<i data-tf="\$Rows.b"></i><u data-tf="\$Rows.p149"></u>'
        '<s data-tf="\$Rows.city"></s></li></template></ul>',
      );
      final w = _Wides(const []);
      addTearDown(
        startThor([w, readers], root: root, features: allEngineFeatures),
      );
      w.items.value = [_Wide('1'), _Wide('2')];
      expect(_text(root), 'a-1 b-1 p149-1 c-1 a-2 b-2 p149-2 c-2');
      // A row whose getter throws: the write does not throw, the row keeps
      // its template text for that field, the others show (lite's rows).
      final bad = _Wide('3', fail: true);
      w.items.value = [_Wide('1'), bad, _Wide('4')];
      expect(
        _text(root),
        'a-1 b-1 p149-1 c-1 b-3 p149-3 c-3 a-4 b-4 p149-4 c-4',
      );
      // The failed row is retried by the next render (a new item for it).
      w.items.value = [_Wide('1'), _Wide('3'), _Wide('4')];
      expect(
        _text(root),
        'a-1 b-1 p149-1 c-1 a-3 b-3 p149-3 c-3 a-4 b-4 p149-4 c-4',
      );
      w.items.value = [_Wide('5')];
      expect(_text(root), 'a-5 b-5 p149-5 c-5');
    });
  });
}
