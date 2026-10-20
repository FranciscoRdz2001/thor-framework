// Bindings in subtrees the first scan does not see: states inside the
// variant of another state, lists inside a variant, and the bindings of
// other states in the rows a list clones (`Watch` of another state in
// `each:`), also in parts that arrive after hydration. The lite runtime does
// this (`adopt`, `wire`): the
// dart2js engine must too.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:test/test.dart';
import 'package:thor_engine_oracle/client.dart';
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

List<String> _keys(web.Element root, String selector) {
  final found = root.querySelectorAll('$selector > [data-tk]');
  return [
    for (var i = 0; i < found.length; i++)
      (found.item(i)! as web.Element).getAttribute('data-tk')!,
  ];
}

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

const _tpl =
    '<template data-tlt="S.items"><li><b data-tf="S.name"></b>'
    '</li></template>';

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
  test('states inside the variant of another state follow their value', () {
    final s = _Nest();
    final root = _page(_levels, s);
    final box = _q(root, '#box');
    expect(_text(box), 'A0');
    s.tog3(); // changes while its Watch is not on screen
    s.tog1();
    expect(_text(box), 'A1 B0');
    s.tog2();
    expect(_text(box), 'A1 B1 C1', reason: 'it shows what it got while away');
    s.tog3();
    expect(_text(box), 'A1 B1 C0');
    // Away and back, with the innermost changed meanwhile.
    s.tog2();
    s.tog1();
    s.tog3();
    s.tog1();
    s.tog2();
    expect(_text(box), 'A1 B1 C1');
    for (var i = 0; i < 5; i++) {
      s
        ..tog1()
        ..tog2()
        ..tog1();
    }
    expect(_text(box), 'A1 B0');
  });

  test('a keyed list that only lives in a variant follows its items', () {
    final s = _Nest();
    final root = _page(
      '<div id="box"><p data-tv="S.l1">closed</p>'
      '<template data-tvt="S.l1" data-i="1"><div data-tv="S.l1">'
      '<ul data-tl="S.items" data-tlk="S.key">$_tpl</ul></div></template></div>',
      s,
    );
    final box = _q(root, '#box');
    s.items.value = ['p', 'r', 's']; // changed while it was away
    s.tog1();
    expect(_keys(box, 'ul'), ['p', 'r', 's']);
    expect(_text(box), 'p r s');
    s.items.value = ['s', 'p', 'z'];
    expect(_keys(box, 'ul'), ['s', 'p', 'z']);
    for (var i = 0; i < 20; i++) {
      s.tog1();
    }
    s.items.value = ['z'];
    s.tog1();
    s.tog1();
    expect(_keys(box, 'ul'), ['z']);
    expect(box.querySelectorAll('ul').length, 1);
  });

  test('a Watch of another state in the rows of a list', () {
    final s = _Nest();
    final root = _page(
      '<ul id="l" data-tl="S.items" data-tlk="S.key">'
      '<li data-tk="x"><b data-tf="S.name">x</b>$_otherRow</li>'
      '<li data-tk="q"><b data-tf="S.name">Q</b>$_otherRow</li>'
      '<template data-tlt="S.items"><li><b data-tf="S.name"></b>$_otherRow'
      '</li></template></ul>',
      s,
    );
    final l = _q(root, '#l');
    String all() => _text(l);
    expect(all(), 'x L0 a q L0 a');
    s.lab.value = 'L1';
    s.mode.value = true;
    // The server's rows and the ones the browser adds follow both.
    s.items.value = ['x', 'q', 'n'];
    expect(all(), 'x L1 b q L1 b n L1 b');
    s.lab.value = 'L2';
    s.mode.value = false;
    expect(all(), 'x L2 a q L2 a n L2 a');
    // A row that comes in after the state changed shows its current value.
    s.items.value = ['x', 'q', 'n', 'm'];
    expect(all(), 'x L2 a q L2 a n L2 a m L2 a');
    // Rows that left are not written any more.
    s.items.value = ['x'];
    s.labelCalls = 0;
    s.lab.value = 'L3';
    expect(all(), 'x L3 a');
    expect(s.labelCalls, lessThanOrEqualTo(2), reason: 'one text, not five');
  });

  test('rows with a Watch of another state arrive on an empty list', () {
    final s = _Nest()..items.value = const [];
    final root = _page(
      '<ul id="l" data-tl="S.items" data-tlk="S.key">'
      '<template data-tlt="S.items"><li><b data-tf="S.name"></b>$_otherRow'
      '</li></template></ul>',
      s,
    );
    s.lab.value = 'L9';
    s.items.value = ['a'];
    expect(_text(_q(root, '#l')), 'a L9 a');
    s.mode.value = true;
    expect(_text(_q(root, '#l')), 'a L9 b');
  });

  test('a row, a variant of another state, a list, a text of a third', () {
    final s = _Nest();
    const nested =
        '<ul data-tl="S.nitems" data-tlk="S.key">'
        '<li data-tk="n1"><b data-tf="S.name">n1</b><u data-tt="S.label">L0'
        '</u></li><li data-tk="n2"><b data-tf="S.name">n2</b>'
        '<u data-tt="S.label">L0</u></li>'
        '<template data-tlt="S.nitems"><li><b data-tf="S.name"></b>'
        '<u data-tt="S.label">L0</u></li></template></ul>';
    const inner =
        '<div data-tv="S.mode"><span>-</span></div>'
        '<template data-tvt="S.mode" data-i="1"><div data-tv="S.mode">$nested'
        '</div></template>';
    final root = _page(
      '<ul id="l" data-tl="S.items" data-tlk="S.key">'
      '<li data-tk="x"><b data-tf="S.name">x</b>$inner</li>'
      '<li data-tk="q"><b data-tf="S.name">q</b>$inner</li>'
      '<template data-tlt="S.items"><li><b data-tf="S.name"></b>$inner'
      '</li></template></ul>',
      s,
    );
    final l = _q(root, '#l');
    expect(_text(l), 'x - q -');
    s.mode.value = true;
    expect(_text(l), 'x n1 L0 n2 L0 q n1 L0 n2 L0');
    s.nitems.value = ['n1', 'n2', 'n3'];
    s.lab.value = 'L1';
    expect(_text(l), 'x n1 L1 n2 L1 n3 L1 q n1 L1 n2 L1 n3 L1');
    // Rows that come later, the variant off and on again, no duplicates.
    s.items.value = ['y', 'z'];
    expect(_text(l), 'y n1 L1 n2 L1 n3 L1 z n1 L1 n2 L1 n3 L1');
    s.mode.value = false;
    expect(_text(l), 'y - z -');
    s.nitems.value = ['n9'];
    s.lab.value = 'L2';
    s.mode.value = true;
    expect(_text(l), 'y n9 L2 z n9 L2');
    expect(l.querySelectorAll('ul').length, 2);
  });

  test('a variant that arrives late shows the state it has now', () {
    final s = _Nest();
    final state = web.document.createElement('script') as web.HTMLElement
      ..id = 'thor-state'
      ..textContent = '{}';
    web.document.body!.append(state);
    // ignore: unnecessary_lambdas
    addTearDown(() => state.remove());
    final root = _page('<div id="host"></div>', s);
    s.tog1();
    // The server drew the part when `l1` was false: its first state.
    _stream(
      _q(root, '#host'),
      '<p data-tv="S.l1">A0</p>'
      '<template data-tvt="S.l1" data-i="1"><p data-tv="S.l1">A1</p>'
      '</template>',
    );
    expect(_text(_q(root, '#host')), 'A1');
    s.tog1();
    expect(_text(_q(root, '#host')), 'A0');
  });

  test('rows and nested variants in a part that arrives late', () {
    final s = _Nest();
    final state = web.document.createElement('script') as web.HTMLElement
      ..id = 'thor-state'
      ..textContent = '{}';
    web.document.body!.append(state);
    // ignore: unnecessary_lambdas
    addTearDown(() => state.remove());
    final root = _page('<div id="host"></div>', s);
    _stream(
      _q(root, '#host'),
      '<ul id="l" data-tl="S.items" data-tlk="S.key">'
      '<li data-tk="x"><b data-tf="S.name">x</b>$_otherRow</li>'
      '<template data-tlt="S.items"><li><b data-tf="S.name"></b>$_otherRow'
      '</li></template></ul>'
      '<div id="lv">${_levels.replaceAll('id="box"', 'id="b2"')}</div>',
    );
    final host = _q(root, '#host');
    s.lab.value = 'L1';
    s.items.value = ['x', 'y'];
    expect(_text(_q(host, '#l')), 'x L1 a y L1 a');
    s.tog3();
    s.tog1();
    s.tog2();
    expect(_text(_q(host, '#b2')), 'A1 B1 C1');
  });

  test('missingFeatures also reads what the templates hold', () {
    // A tile with a callback that only a state of a variant has.
    final root = mount(
      '<p data-tv="S.l1">x</p><template data-tvt="S.l1" data-i="1">'
      '<div data-tv="S.l1"><details data-t-ev="toggle:S.tog1"></details></div>'
      '</template>',
    );
    final missing = missingFeatures(root, const [VariantsFeature()]);
    expect(missing.single, contains('ElementEventsFeature'));
    expect(
      missingFeatures(root, const [VariantsFeature(), ElementEventsFeature()]),
      isEmpty,
    );
  });

  // `row.text((o) => o.customer)`: the row's text is a property of the item,
  // read by a reader the build gives the engine (`$Rows.customer`).
  test('the properties a row lambda reads are read from the items', () {
    final s = _Nest()
      ..items.value = const []
      ..nitems.value = const [];
    final people = [_Person('ana', 'Madrid'), _Person('bo', 'Oslo')];
    final readers = RowReaders({
      'name': (it) => (it as dynamic).name as String,
      'city': (it) => (it as dynamic).city as String,
    });
    final root = mount(
      '<ul id="l" data-tl="S.people" data-tlk="S.personKey">'
      '<li data-tk="ana"><b data-tf="\$Rows.name">ana</b>'
      '<i data-tf="\$Rows.city">Madrid</i></li>'
      '<template data-tlt="S.people"><li><b data-tf="\$Rows.name"></b>'
      '<i data-tf="\$Rows.city"></i></li></template></ul>',
    );
    final who = _People(people);
    addTearDown(
      startThor([s, who, readers], root: root, features: allEngineFeatures),
    );
    expect(_text(root), 'ana Madrid bo Oslo');
    who.people.value = [..._People.of(who), _Person('cy', 'Roma')];
    expect(_text(root), 'ana Madrid bo Oslo cy Roma');
    who.people.value = [_Person('ana', 'Lima')];
    expect(_text(root), 'ana Lima', reason: 'a property that changed');
  });

  // `row.watch((o) => o.vip, builder: …)`: the row's state is a `bool` or
  // enum property of the item, read by `$Rows` and answered as an index.
  test('a bool or enum property a row.watch lambda reads picks the state', () {
    final s = _Nest()
      ..items.value = const []
      ..nitems.value = const [];
    final readers = RowReaders(
      {
        'vip': (it) => (it as dynamic).vip,
        'tier': (it) => (it as dynamic).tier,
        'name': (it) => (it as dynamic).name as String,
      },
      states: {'vip': 2, 'tier': 3},
    );
    final root = mount(
      '<ul id="l" data-tl="S.people" data-tlk="S.personKey">'
      '<li data-tk="ana"><b data-tf="\$Rows.name">ana</b>'
      '<i class="no" data-tvf="\$Rows.vip" data-tvi="0">x</i>'
      '<u class="free" data-tvf="\$Rows.tier" data-tvi="0">f</u></li>'
      '<template data-tlt="S.people"><li><b data-tf="\$Rows.name"></b>'
      '<i class="no" data-tvf="\$Rows.vip" data-tvi="0" '
      'data-tp-1="|class|=yes">x</i>'
      '<u class="free" data-tvf="\$Rows.tier" data-tvi="0" '
      'data-tp-1="|class|=pro" data-tp-2="|class|=team">f</u>'
      '</li></template></ul>',
    );
    final who = _People([_Person('ana', 'Madrid')]);
    addTearDown(
      startThor([s, who, readers], root: root, features: allEngineFeatures),
    );
    List<String> classes(String tag) => [
      for (var i = 0; i < root.querySelectorAll('li').length; i++)
        (root.querySelectorAll('li').item(i)! as web.Element)
            .querySelector(tag)!
            .className,
    ];
    who.people.value = [
      _Person('ana', 'Madrid'),
      _Person('bo', 'Oslo', vip: true, tier: _Tier.team),
      _Person('cy', 'Roma', tier: _Tier.pro),
    ];
    expect(classes('i'), ['no', 'yes', 'no']);
    expect(classes('u'), ['free', 'team', 'pro']);
    // An item that changes moves the state of its row.
    who.people.value = [
      _Person('ana', 'Madrid', vip: true, tier: _Tier.pro),
      _Person('bo', 'Oslo'),
      _Person('cy', 'Roma', tier: _Tier.team),
    ];
    expect(classes('i'), ['yes', 'no', 'no']);
    expect(classes('u'), ['pro', 'free', 'team']);
  });
}

enum _Tier { free, pro, team }

class _Person {
  _Person(this.name, this.city, {this.vip = false, this.tier = _Tier.free});
  final String name;
  final String city;
  final bool vip;
  final _Tier tier;
}

class _People extends ThorState {
  _People(List<_Person> start) : people = state(start);

  final StateSignal<List<_Person>> people;

  static List<_Person> of(_People s) => s.people.value;

  @override
  String get $type => 'S';

  @override
  List<ThorMember> get $members => [
    ThorMember.state('people', people),
    ThorMember(
      'personKey',
      personKey,
      arity: 1,
      callWithItem: (i) => personKey(i! as _Person),
    ),
  ];

  String personKey(_Person p) => p.name;
}
