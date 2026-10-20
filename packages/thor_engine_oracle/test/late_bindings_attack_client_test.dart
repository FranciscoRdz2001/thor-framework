// Adversarial pass over the pairs of `WatchVariables` / `WatchAttributes` of
// the dart2js engine (the lite engine's twin:
// `test/e2e/checks/lite_late_bindings_adversarial_check.mjs`): moved,
// detached and put back elements, odd names, the same pair in two late parts,
// a method that throws, and a page that gains thousands of unrelated nodes.
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

void stream(web.Element host, String html) {
  final before = host.children.length;
  host.insertAdjacentHTML('beforeend', html.toJS);
  final nodes = [
    for (var i = before; i < host.children.length; i++) host.children.item(i)!,
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

  /// How many times a method ran: a pair that left must not keep running.
  var calls = 0;
  var bad = 0;

  @override
  String get $type => 'AV';

  @override
  List<ThorMember> get $members => [
    ThorMember.state('m', m),
    ThorMember('w', w, arity: 1, call: (a) => w(a!)),
    ThorMember('lab', lab, arity: 1, call: (a) => lab(a!)),
    ThorMember('boom', boom, arity: 1, call: (a) => boom(a!)),
  ];

  int w(String k) {
    calls++;
    return int.parse(k) * m.value;
  }

  String lab(String k) => 'L$k:${m.value}';

  int boom(String k) {
    bad++;
    final v = m.value;
    if (k == 'bad') throw StateError('bad pair $v');
    return v;
  }
}

(web.HTMLElement, _Vars) _page(String html) {
  final s = _Vars();
  final root = mount(html);
  addTearDown(startThor([s], root: root, features: allEngineFeatures));
  return (root, s);
}

web.HTMLElement _q(web.Element root, String selector) =>
    root.querySelector(selector)! as web.HTMLElement;

String _css(web.Element root, String selector, String name) =>
    _q(root, selector).style.getPropertyValue(name);

String _pair(String id, int k) =>
    '<div id="$id" data-tcv="--w:AV.w~$k" data-tca="aria-label:AV.lab~$k">'
    '</div>';

const _hosts = '<div id="a"></div><div id="b"></div><div id="host"></div>';

void main() {
  test('a moved element keeps its pair, a detached one gets it back', () async {
    final (root, s) = _page(_hosts);
    await frames();
    stream(_q(root, '#host'), _pair('x', 1));
    stream(_q(root, '#b'), _pair('y', 1));
    await frames();
    s.calls = 0;
    s.m.value = 3;
    expect(s.calls, 1, reason: 'one effect for two elements');
    // Moved, not removed.
    final x = _q(root, '#x');
    _q(root, '#b').insertBefore(x, _q(root, '#y'));
    _q(root, '#a').append(x);
    await frames();
    s.calls = 0;
    s.m.value = 4;
    expect(_css(root, '#x', '--w'), '4px');
    expect(s.calls, 1, reason: 'no second effect for a moved element');
    // Detached while the signal fires, put back later.
    x.remove();
    s.m.value = 5;
    expect(_css(root, '#y', '--w'), '5px');
    _q(root, '#a').append(x);
    await frames();
    expect(_css(root, '#x', '--w'), '5px');
    expect(_q(root, '#x').getAttribute('aria-label'), 'L1:5');
    s.m.value = 6;
    expect(_css(root, '#x', '--w'), '6px');
    // Every element gone: the pair is released, and bound again when they return.
    final y = _q(root, '#y');
    x.remove();
    y.remove();
    s.m.value = 7;
    s.calls = 0;
    s.m.value = 8;
    expect(s.calls, 0, reason: 'released');
    _q(root, '#a')
      ..append(x)
      ..append(y);
    await frames();
    expect(_css(root, '#x', '--w'), '8px');
    expect(_css(root, '#y', '--w'), '8px');
    s.m.value = 9;
    expect(_css(root, '#y', '--w'), '9px');
    // Removed, fired and re-added in one task.
    x.remove();
    s.m.value = 10;
    _q(root, '#b').append(x);
    await frames();
    expect(_css(root, '#x', '--w'), '10px');
  });

  test('odd names are not written, odd arguments are', () async {
    final (root, _) = _page(_hosts);
    await frames();
    stream(
      _q(root, '#host'),
      '<div id="n1" data-tcv="--a_b-C1:AV.w~2;--x.y:AV.w~2;--:AV.w~2;'
      '--ñ:AV.w~2" data-tca="data-x-y:AV.lab~a:b|c;aria-label:AV.lab~ü ñ;'
      'data-x_y:AV.lab~1;onclick:AV.lab~1;href:AV.lab~javascript:1"></div>',
    );
    await frames();
    expect(_css(root, '#n1', '--a_b-C1'), '4px');
    expect(_css(root, '#n1', '--x.y'), '');
    expect(_css(root, '#n1', '--ñ'), '');
    expect(_q(root, '#n1').getAttribute('data-x-y'), 'La:b|c:2');
    expect(_q(root, '#n1').getAttribute('aria-label'), 'Lü ñ:2');
    expect(_q(root, '#n1').hasAttribute('data-x_y'), isFalse);
    expect(_q(root, '#n1').hasAttribute('onclick'), isFalse);
    expect(_q(root, '#n1').hasAttribute('href'), isFalse);
  });

  test('the same pair in two late parts, and a late part in another', () async {
    final (root, s) = _page(_hosts);
    await frames();
    stream(_q(root, '#host'), _pair('p1', 5));
    stream(_q(root, '#b'), _pair('p2', 5));
    stream(_q(root, '#host'), '<section id="outer"></section>');
    stream(_q(root, '#outer'), _pair('p3', 5));
    web.document.documentElement!.dispatchEvent(
      web.CustomEvent(
        'thor:stream',
        web.CustomEventInit(
          detail: JSObject()..['nodes'] = [_q(root, '#outer') as JSAny].toJS,
        ),
      ),
    );
    await frames();
    s.calls = 0;
    s.m.value = 4;
    expect(s.calls, 1, reason: 'one effect for the three elements');
    for (final id in ['p1', 'p2', 'p3']) {
      expect(_css(root, '#$id', '--w'), '20px');
    }
  });

  test('a method that throws keeps the value the server wrote', () async {
    final (root, s) = _page(_hosts);
    await frames();
    stream(
      _q(root, '#host'),
      '<div id="t" data-tcv="--w:AV.boom~bad" style="--w:7px"></div>',
    );
    await frames();
    final t = _q(root, '#t');
    s.bad = 0;
    for (var i = 0; i < 50; i++) {
      _q(root, '#b').append(t);
      _q(root, '#a').append(t);
      await Future<void>.delayed(Duration.zero);
    }
    await frames();
    expect(s.bad, lessThanOrEqualTo(1), reason: 'not run again per move');
    expect(_css(root, '#t', '--w'), '7px', reason: 'no value, no write');
    stream(
      _q(root, '#host'),
      '<div id="t2" data-tcv="--w:AV.boom~bad" style="--w:7px"></div>',
    );
    await frames();
    expect(_css(root, '#t2', '--w'), '7px', reason: 'a joiner is not zeroed');
  });

  test('thousands of unrelated nodes cost no pair work', () async {
    final (root, s) = _page(_hosts);
    await frames();
    final host = _q(root, '#host');
    final watch = Stopwatch()..start();
    for (var i = 0; i < 10000; i++) {
      final d = web.document.createElement('div');
      d.innerHTML = '<span>x</span>'.toJS;
      host.append(d);
    }
    await frames();
    watch.stop();
    expect(s.calls, 0);
    expect(watch.elapsedMilliseconds, lessThan(3000));
    // And the pairs still bind afterwards.
    stream(host, _pair('late', 3));
    await frames();
    expect(_css(root, '#late', '--w'), '6px');
  });
}
