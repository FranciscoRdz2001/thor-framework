@TestOn('browser')
library;

// With dart2js, every state's `onHydrated` runs after the page is
// hydrated (a throw is reported, the others still run; its writes paint
// once) and `dispose` when the page is unloaded, once (never for a page
// kept for the back button).
import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thor_engine_oracle/client.dart';
import 'package:web/web.dart' as web;

final log = <String>[];

abstract class _Members extends ThorState {
  _Members({super.key});

  @override
  String get $type => 'Life';

  @override
  List<ThorMember> get $members {
    final s = this as _Life;
    return [
      ThorMember.state('n', s.n),
      ThorMember('label', s.label, call: (_) => s.label()),
    ];
  }
}

class _Life extends _Members {
  _Life(this.name, {this.boom = false, super.key});
  final String name;
  final bool boom;
  final n = state(0);

  String label() => 'n=${n.value}';

  @override
  void onHydrated() {
    log.add('h$name');
    n.value = 5;
    if (boom) throw StateError('init $name');
  }

  @override
  void dispose() => log.add('d$name');
}

void pagehide({required bool persisted}) => web.window.dispatchEvent(
  web.PageTransitionEvent(
    'pagehide',
    web.PageTransitionEventInit(persisted: persisted),
  ),
);

void main() {
  test(
    'onHydrated after hydration, throws isolated; dispose once on unload',
    () {
      log.clear();
      final root = web.document.createElement('div') as web.HTMLElement
        ..innerHTML = '<p data-tt="Life#a.label">n=0</p>'.toJS;
      web.document.body!.append(root);
      // ignore: unnecessary_lambdas
      addTearDown(() => root.remove());
      final a = _Life('a', key: 'a');
      final b = _Life('b', boom: true, key: 'b');
      ThorState.register({
        _Life: ThorStateType(
          'Life',
          (s) => (s as _Life).$members,
          disposes: true,
        ),
      });
      final detach = startThor([a, b], root: root);
      expect(log, ['ha', 'hb']);
      // b threw, a's writes reached the page
      expect(root.textContent, 'n=5');
      pagehide(persisted: true);
      expect(log, ['ha', 'hb']);
      pagehide(persisted: false);
      expect(log, ['ha', 'hb', 'da', 'db']);
      pagehide(persisted: false);
      detach();
      expect(log, ['ha', 'hb', 'da', 'db']);
    },
  );

  // The lite engine disposes a state when the last element that names it
  // leaves the page, and wakes it again when elements come back (part
  // `lifecycle`); `LifecycleFeature` does the same here.
  group('a state lives as long as the page names it', () {
    late web.HTMLElement root;
    late _Life a, b;
    late void Function() detach;

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    void start({String html = '', bool feature = true}) {
      log.clear();
      root = web.document.createElement('div') as web.HTMLElement
        ..innerHTML = html.toJS;
      web.document.body!.append(root);
      // ignore: unnecessary_lambdas
      addTearDown(() => root.remove());
      a = _Life('a', key: 'a');
      b = _Life('b', key: 'b');
      ThorState.register({
        _Life: ThorStateType(
          'Life',
          (s) => (s as _Life).$members,
          disposes: true,
        ),
      });
      detach = startThor(
        [a, b],
        root: root,
        features: [if (feature) const LifecycleFeature(), const ListsFeature()],
      );
      addTearDown(detach);
    }

    const text = '<p data-tt="Life#a.label">n=0</p>';

    test('removed from the page: disposed once; back: woken again', () async {
      start(html: '<div id="box">$text</div>');
      expect(log, ['ha', 'hb']);
      root.querySelector('#box')!.innerHTML = ''.toJS;
      await settle();
      expect(log, ['ha', 'hb', 'da'], reason: 'b was never in the page');
      root.querySelector('#box')!.innerHTML = text.toJS;
      await settle();
      expect(log, ['ha', 'hb', 'da', 'ha']);
      pagehide(persisted: false);
      expect(log, ['ha', 'hb', 'da', 'ha', 'da', 'db']);
    });

    test('moved or replaced by a copy: still named, not disposed', () async {
      start(html: '<div id="box">$text</div><div id="other"></div>');
      final p = root.querySelector('#box p')!;
      root.querySelector('#other')!.append(p);
      await settle();
      root.querySelector('#other')!.innerHTML = text.toJS;
      await settle();
      expect(log, ['ha', 'hb']);
    });

    test('a state that another element still names is kept', () async {
      start(
        html:
            '<div id="x">$text</div><div id="y">'
            '<button data-t-on="click:Life#a.n">+</button></div>',
      );
      root.querySelector('#x')!.remove();
      await settle();
      expect(log, ['ha', 'hb']);
      root.querySelector('#y')!.remove();
      await settle();
      expect(log, ['ha', 'hb', 'da']);
    });

    test('without the feature a state ends only with the page', () async {
      start(html: '<div id="box">$text</div>', feature: false);
      root.querySelector('#box')!.remove();
      await settle();
      expect(log, ['ha', 'hb']);
    });
  });
}
