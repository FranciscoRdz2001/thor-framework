@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thor_engine_oracle/client.dart';
import 'package:web/web.dart' as web;

void main() {
  test(
    'the height animates from where it was to the new content height',
    () async {
      final root = web.document.createElement('div') as web.HTMLElement;
      root.innerHTML =
          '''
<div id="s" data-tsz="400|linear|400" style="display:flex;flex-direction:column;overflow:hidden">
  <div style="display:flow-root;flex:none"><div id="c" style="height:50px"></div></div>
</div>'''
              .toJS;
      web.document.body!.append(root);
      // ignore: unnecessary_lambdas
      addTearDown(() => root.remove());
      final off = hydrate(
        const [],
        root: root,
        features: const [SizeAnimationsFeature()],
      );
      addTearDown(off);
      final s = root.querySelector('#s')!;
      (root.querySelector('#c')! as web.HTMLElement).style.height = '150px';
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final mid = s.getBoundingClientRect().height;
      expect(s.getAnimations().length, 1);
      expect(mid, allOf(greaterThan(55), lessThan(145)));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(s.getBoundingClientRect().height, 150);
      expect(s.getAnimations(), isEmpty);
    },
  );

  // One shell the tests below share the shape of.
  web.HTMLElement mount(
    String attr, {
    String inner = 'height:50px',
    String shell = '',
    String measure = '',
  }) {
    final root = web.document.createElement('div') as web.HTMLElement;
    root.innerHTML =
        '''
<div id="s" data-tsz="$attr" style="display:flex;flex-direction:column;overflow:hidden;$shell">
  <div id="m" style="display:flow-root;flex:none;$measure"><div id="c" style="$inner"></div></div>
</div>'''
            .toJS;
    web.document.body!.append(root);
    // ignore: unnecessary_lambdas
    addTearDown(() => root.remove());
    final off = hydrate(
      const [],
      root: root,
      features: const [SizeAnimationsFeature()],
    );
    addTearDown(off);
    return root;
  }

  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  test(
    'onEnd: one transitionend when it finishes, none when cut short',
    () async {
      final root = mount('200|linear|200');
      final s = root.querySelector('#s')!;
      final c = root.querySelector('#c')! as web.HTMLElement;
      var ends = 0;
      s.addEventListener('transitionend', ((web.Event _) => ends++).toJS);
      c.style.height = '150px';
      await wait(80);
      c.style.height = '100px'; // interrupts the first animation
      await wait(500);
      expect(s.getBoundingClientRect().height, 100);
      expect(ends, 1, reason: 'only the animation that ran to its end');
    },
  );

  test('a width-only change does not animate unless animateWidth', () async {
    final root = mount('200|linear|200', inner: 'height:50px;width:50px');
    final s = root.querySelector('#s')!;
    (root.querySelector('#c')! as web.HTMLElement).style.width = '120px';
    await wait(60);
    expect(s.getAnimations(), isEmpty);
  });

  test('animateWidth animates a width-only change', () async {
    final root = mount(
      '300|linear|300|w',
      inner: 'height:50px;width:50px',
      shell: 'width:fit-content',
      measure: 'width:max-content',
    );
    var ends = 0;
    final s = root.querySelector('#s')!;
    s.addEventListener('transitionend', ((web.Event _) => ends++).toJS);
    (root.querySelector('#c')! as web.HTMLElement).style.width = '150px';
    await wait(120);
    final mid = s.getBoundingClientRect().width;
    expect(s.getAnimations().length, 1);
    expect(mid, allOf(greaterThan(55), lessThan(145)));
    await wait(500);
    expect(s.getBoundingClientRect().width, 150);
    expect(ends, 1);
  });

  test('a hidden shell shown later is not a growth from nothing', () async {
    // Same as the lite engine: not rendered means unknown, not zero.
    final root = mount('400|linear|400');
    final s = root.querySelector('#s')! as web.HTMLElement;
    s.style.display = 'none';
    await wait(60);
    (root.querySelector('#c')! as web.HTMLElement).style.height = '150px';
    s.style.display = 'flex';
    await wait(120);
    expect(s.getAnimations(), isEmpty);
    expect(s.getBoundingClientRect().height, 150);
  });

  test('a shell the page gains after hydrating is followed too', () async {
    final root = mount('400|linear|400');
    final late = web.document.createElement('div') as web.HTMLElement;
    late.innerHTML =
        '''
<div id="s2" data-tsz="400|linear|400" style="display:flex;flex-direction:column;overflow:hidden">
  <div style="display:flow-root;flex:none"><div id="c2" style="height:50px"></div></div>
</div>'''
            .toJS;
    root.append(late);
    await wait(60);
    (late.querySelector('#c2')! as web.HTMLElement).style.height = '150px';
    await wait(120);
    final s2 = late.querySelector('#s2')!;
    expect(s2.getAnimations().length, 1);
    expect(s2.getBoundingClientRect().height, lessThan(145));
  });
}
