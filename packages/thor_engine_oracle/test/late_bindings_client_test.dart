// `WatchVariables` / `WatchAttributes` where the page gains markup after the
// state started: a late part (`thor:stream`), a copy put in place of a subtree
// and the rows the engine clones. The pairs (name, id) they bring are followed,
// and released when their elements leave. The lite engine does the same
// (`test/e2e/checks/lite_late_bindings_check.mjs`).
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

// What the loader does for a part that arrives late: the nodes in place,
// then `thor:stream` on <html>.
void stream(web.Element host, String html) {
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

Future<void> frames([int ms = 0]) =>
    Future<void>.delayed(Duration(milliseconds: ms + 50));

class _Vars extends ThorState {
  final m = state(2);
  final items = state(const <String>[]);

  /// How many times a pair's method ran: a pair that left must not keep
  /// running.
  var calls = 0;

  @override
  String get $type => 'LV';

  @override
  List<ThorMember> get $members => [
    ThorMember.state('m', m),
    ThorMember.state('items', items),
    ThorMember('key', _id, arity: 1, callWithItem: (i) => i! as String),
    ThorMember('title', _id, arity: 1, callWithItem: (i) => i! as String),
    ThorMember('w', w, arity: 1, call: (a) => w(a!)),
    ThorMember('lab', lab, arity: 1, call: (a) => lab(a!)),
  ];

  String _id(String i) => i;

  int w(String k) {
    calls++;
    return int.parse(k) * m.value;
  }

  String lab(String k) => 'L$k:${m.value}';
}

web.HTMLElement _page(String html, _Vars s) {
  final root = mount(html);
  addTearDown(startThor([s], root: root, features: allEngineFeatures));
  return root;
}

web.HTMLElement _q(web.Element root, String selector) =>
    root.querySelector(selector)! as web.HTMLElement;

String _css(web.Element root, String selector, String name) =>
    _q(root, selector).style.getPropertyValue(name);

String? _attr(web.Element root, String selector, String name) =>
    _q(root, selector).getAttribute(name);

const _rows =
    '<ul id="l" data-tl="LV.items" data-tlk="LV.key"><template '
    'data-tlt="LV.items"><li data-tf="LV.title" data-tcv="--r:LV.w~{{key}}" '
    'data-tca="aria-label:LV.lab~{{key}}"></li></template></ul>';

void main() {
  test('a pair only a late part brings is followed', () async {
    final s = _Vars();
    final root = _page(
      '<div id="s0" data-tcv="--a:LV.w~1" style="--a:2px"></div>'
      '<div id="host"></div>',
      s,
    );
    await frames();
    stream(
      _q(root, '#host'),
      '<div id="late" data-tcv="--w:LV.w~5" data-tca="aria-label:LV.lab~z" '
      'style="--w:0px"></div>',
    );
    await frames();
    expect(_css(root, '#late', '--w'), '10px');
    expect(_attr(root, '#late', 'aria-label'), 'Lz:2');
    s.m.value = 3;
    expect(_css(root, '#late', '--w'), '15px');
    expect(_attr(root, '#late', 'aria-label'), 'Lz:3');
    expect(_css(root, '#s0', '--a'), '3px', reason: 'the page one still does');
  });

  test('rows cloned from a template follow their own pair', () async {
    final s = _Vars();
    final root = _page(_rows, s);
    await frames();
    s.items.value = ['1', '2', '3'];
    await frames();
    expect(_css(root, '[data-tk="2"]', '--r'), '4px');
    expect(_attr(root, '[data-tk="3"]', 'aria-label'), 'L3:2');
    s.m.value = 5;
    expect(_css(root, '[data-tk="3"]', '--r'), '15px');
    expect(_attr(root, '[data-tk="1"]', 'aria-label'), 'L1:5');
    s.items.value = ['2', '4'];
    await frames();
    s.m.value = 6;
    expect(_css(root, '[data-tk="4"]', '--r'), '24px');
    expect(_css(root, '[data-tk="2"]', '--r'), '12px');
  });

  test('a pair of a subtree put in place of another is followed', () async {
    final s = _Vars();
    final root = _page('<div id="swap"><p data-tcv="--o:LV.w~9"></p></div>', s);
    await frames();
    final copy = web.document.createElement('div')..id = 'swap2';
    copy.innerHTML = '<p id="new" data-tcv="--n:LV.w~7"></p>'.toJS;
    _q(root, '#swap').replaceWith(copy);
    await frames();
    s.m.value = 7;
    expect(_css(root, '#new', '--n'), '49px');
  });

  test('many swaps leave no pair behind', () async {
    final s = _Vars();
    final root = _page(_rows, s);
    await frames();
    for (var i = 0; i < 300; i++) {
      s.items.value = ['${i * 3 + 1}', '${i * 3 + 2}', '${i * 3 + 3}'];
      await Future<void>.delayed(Duration.zero);
    }
    await frames();
    s.m.value = 9; // the pairs of rows that left end when they run
    expect(_css(root, '[data-tk="900"]', '--r'), '8100px');
    s.calls = 0;
    s.m.value = 10;
    expect(s.calls, 3, reason: 'only the rows in the page run');
    s.items.value = const [];
    await frames();
    s.m.value = 10;
    s.calls = 0;
    s.m.value = 11;
    expect(s.calls, 0, reason: 'with no row left no pair runs');
  });
}
