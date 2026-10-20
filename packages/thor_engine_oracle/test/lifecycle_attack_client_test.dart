// Attacks on the dart2js engine's state life (`LifecycleFeature`) against
// what the lite engine does (lite_lifecycle_test / lite_lifecycle_adversarial
// _test): only a state that overrides `dispose` lives as long as the page
// names it; the effects its `onHydrated` made stop with it; a state that
// comes back starts from the server's values; a throwing `dispose` or
// `onHydrated` is reported and nothing loops; a move is not an end.
//
// The one thing the lite engine does that this one cannot is making a new
// object (the engine is given its instances): plain fields keep their
// values here. The last test says so.
@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thor_engine_oracle/client.dart';
import 'package:web/web.dart' as web;

final log = <String>[];

/// Overrides `dispose`: lives as long as the page names it.
class _Timer extends ThorState {
  _Timer(this.name, {this.boomOnDispose = false, this.boomOnHydrated = false})
    : super(key: name);

  final String name;
  final bool boomOnDispose, boomOnHydrated;
  final n = state(0);
  final shown = state('server');

  /// A field that is not a `state(...)`: the object keeps it.
  var plain = 0;

  /// What an effect made in `onHydrated` saw.
  final seen = <int>[];

  @override
  String get $type => 'Tick';

  @override
  List<ThorMember> get $members => [
    ThorMember.state('n', n),
    ThorMember.state('shown', shown),
    ThorMember('label', label, call: (_) => label()),
  ];

  String label() => '${n.value}';

  @override
  void onHydrated() {
    log.add('h$name');
    plain++;
    effect(() => seen.add(n.value));
    if (boomOnHydrated) throw StateError('hydrate $name');
  }

  @override
  void dispose() {
    log.add('d$name');
    if (boomOnDispose) throw StateError('dispose $name');
  }
}

/// Only `onHydrated`: never ends before the page.
class _Plain extends ThorState {
  _Plain() : super(key: 'p');

  @override
  String get $type => 'Plain';

  @override
  List<ThorMember> get $members => [
    ThorMember('label', label, call: (_) => 'p'),
  ];

  String label() => 'p';

  @override
  void onHydrated() => log.add('hp');

  @override
  void dispose() => log.add('dp');
}

web.HTMLElement mount(String html) {
  final root = web.document.createElement('div') as web.HTMLElement
    ..innerHTML = html.toJS;
  web.document.body!.append(root);
  // ignore: unnecessary_lambdas
  addTearDown(() => root.remove());
  return root;
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late web.HTMLElement root;
  late _Timer a, b, c;
  late _Plain p;

  void start(String html) {
    log.clear();
    root = mount(html);
    a = _Timer('a');
    b = _Timer('b', boomOnDispose: true);
    c = _Timer('c', boomOnHydrated: true);
    p = _Plain();
    ThorState.register({
      _Timer: ThorStateType(
        'Tick',
        (s) => (s as _Timer).$members,
        disposes: true,
      ),
      _Plain: ThorStateType('Plain', (s) => (s as _Plain).$members),
    });
    addTearDown(
      startThor(
        [a, b, c, p],
        root: root,
        features: const [LifecycleFeature(), VariantsFeature()],
      ),
    );
  }

  const ta = '<p data-tt="Tick#a.label">0</p>';
  const tb = '<p data-tt="Tick#b.label">0</p>';
  const tc = '<p data-tt="Tick#c.label">0</p>';
  const tp = '<p data-tt="Plain#p.label">p</p>';

  test(
    'an onHydrated that throws is reported on every wake; the rest lives',
    () async {
      start('<div id="box">$tc$ta</div>');
      expect(log, containsAllInOrder(['ha', 'hc']));
      root.querySelector('#box')!.innerHTML = ''.toJS;
      await settle();
      root.querySelector('#box')!.innerHTML = '$tc$ta'.toJS;
      await settle();
      expect(log.where((e) => e == 'hc').length, 2);
      expect(log.where((e) => e == 'ha').length, 2);
    },
  );

  test(
    'a state that does not override dispose ends with the page only',
    () async {
      start('<div id="box">$tp</div>');
      expect(log, containsAll(['hp']));
      root.querySelector('#box')!.innerHTML = ''.toJS;
      await settle();
      root.querySelector('#box')!.innerHTML = tp.toJS;
      await settle();
      expect(log.where((e) => e == 'hp').length, 1, reason: 'no second wake');
      expect(log, isNot(contains('dp')));
    },
  );

  test('the effects onHydrated made stop with the state', () async {
    start('<div id="box">$ta</div>');
    a.n.value = 1;
    expect(a.seen, [0, 1]);
    root.querySelector('#box')!.innerHTML = ''.toJS;
    await settle();
    a.n.value = 2; // the page does not name it: nobody follows
    expect(a.seen, [0, 1], reason: 'the effect of the ended state stopped');
    root.querySelector('#box')!.innerHTML = ta.toJS;
    await settle();
    a.n.value = 3;
    expect(
      a.seen.where((v) => v == 3).length,
      1,
      reason: 'one effect, not two',
    );
  });

  test('a state that comes back starts from the server values', () async {
    start('<div id="box">$ta</div>');
    a
      ..n.value = 7
      ..shown.value = 'typed';
    root.querySelector('#box')!.innerHTML = ''.toJS;
    await settle();
    root.querySelector('#box')!.innerHTML = ta.toJS;
    await settle();
    expect(a.n.value, 0, reason: 'the value in the code');
    expect(a.shown.value, 'server');
    expect(root.querySelector('#box p')!.textContent, '0');
  });

  test(
    'a dispose that throws is reported, once; the state can come back',
    () async {
      start('<div id="box">$tb</div>');
      root.querySelector('#box')!.innerHTML = ''.toJS;
      await settle();
      expect(log.where((e) => e == 'db').length, 1);
      root.querySelector('#box')!.innerHTML = tb.toJS;
      await settle();
      expect(log.where((e) => e == 'hb').length, 2);
      pagehide();
      expect(log.where((e) => e == 'db').length, 2);
    },
  );

  test(
    'a move inside one task, an ancestor and a copy are not an end',
    () async {
      start('<div id="x">$ta</div><div id="y"></div>');
      final el = root.querySelector('#x p')!;
      root.querySelector('#y')!.append(el);
      root.querySelector('#x')!.remove();
      await settle();
      expect(log, ['ha', 'hb', 'hc', 'hp'], reason: 'moved: still named');
      root.querySelector('#y')!.remove();
      await settle();
      expect(log.where((e) => e == 'da').length, 1);
    },
  );

  test(
    '500 times in and out: one dispose and one wake each, no drift',
    () async {
      start('<div id="box">$ta</div>');
      for (var i = 0; i < 500; i++) {
        root.querySelector('#box')!.innerHTML = ''.toJS;
        await settle();
        root.querySelector('#box')!.innerHTML = ta.toJS;
        await settle();
      }
      expect(log.where((e) => e == 'da').length, 500);
      expect(log.where((e) => e == 'ha').length, 501);
      a.seen.clear();
      a.n.value = 9;
      expect(a.seen, [9], reason: 'one effect alive, not 501');
    },
  );

  test(
    'plain fields keep their values: the object is not made again',
    () async {
      start('<div id="box">$ta</div>');
      root.querySelector('#box')!.innerHTML = ''.toJS;
      await settle();
      root.querySelector('#box')!.innerHTML = ta.toJS;
      await settle();
      expect(a.plain, 2, reason: 'lite would start a new object at 1');
    },
  );
}

void pagehide() => web.window.dispatchEvent(
  web.PageTransitionEvent(
    'pagehide',
    web.PageTransitionEventInit(persisted: false),
  ),
);
