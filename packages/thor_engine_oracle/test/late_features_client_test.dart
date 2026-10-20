// What the engine installs for the whole page, in a part of the page that
// arrives after hydration (`LazyPiece`, `FutureBuilder`: the loader fires
// `thor:stream` on <html> with the nodes it put in place). The lite runtime
// wires the late nodes of its parts the same way.
@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
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

/// What the loader does: the part in place, then `thor:stream`.
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

class _Count extends ThorState {
  _Count() : super(key: 'c${_keys++}');

  var taps = 0;

  @override
  String get $type => 'LCount';

  @override
  List<ThorMember> get $members => [ThorMember('go', go, call: (_) => go())];

  void go() => taps++;
}

class _Anim extends ThorState {
  _Anim(String key) : super(key: key);

  final fade = AnimationController(duration: const Duration(milliseconds: 120));

  @override
  String get $type => 'LAnim';

  @override
  List<ThorMember> get $members => [ThorMember.controller('fade', fade)];
}

var _keys = 0;

String _track(String id) => jsonEncode({
  'c': id,
  'k': [
    {'offset': 0, 'opacity': '0'},
    {'offset': 1, 'opacity': '1'},
  ],
});

double opacity(web.Element el) =>
    double.parse(web.window.getComputedStyle(el).opacity);

void main() {
  test(
    'an element animation that arrives late follows the controller',
    () async {
      final s = _Anim('k${_keys++}');
      final id = '${s.idPrefix}.fade';
      final root = mount(
        "<div id='p' style='opacity:0' data-ta='[${_track(id)}]'></div>"
        '<div id="host"></div>',
      );
      addTearDown(
        startThor([s], root: root, features: const [AnimationsFeature()]),
      );
      final statuses = <AnimationStatus>[];
      s.fade.addStatusListener(statuses.add);
      await frames();
      stream(
        root.querySelector('#host')!,
        "<div id='q' style='opacity:0' data-ta='[${_track(id)}]'></div>",
      );
      final p = root.querySelector('#p')!, q = root.querySelector('#q')!;
      s.fade.value = 0.5;
      await frames();
      expect(
        opacity(p),
        closeTo(0.5, 0.01),
        reason: 'the page element still follows',
      );
      expect(
        opacity(q),
        closeTo(0.5, 0.01),
        reason: 'the late one follows too',
      );
      s.fade.forward();
      await frames(250);
      expect(opacity(p), 1);
      expect(opacity(q), 1);
      expect(s.fade.status, AnimationStatus.completed);
      expect(statuses, [AnimationStatus.forward, AnimationStatus.completed]);
    },
  );

  // `startThor` with a hand-made state, the page's features, and a late part.
  group('page-wide features in a part that arrives late', () {
    web.HTMLElement page(List<EngineFeature> features) {
      final root = mount('<div id="host"></div>');
      addTearDown(
        startThor([_Anim('k${_keys++}')], root: root, features: features),
      );
      return root;
    }

    test('a validated form is checked with the page\'s own messages', () async {
      final root = page(const [FormsFeature()]);
      stream(
        root.querySelector('#host')!,
        '<form method="post" action="/nowhere">'
        '<input id="e" name="email" type="email" required data-t-validate '
        'data-msg-valuemissing="Escribe tu correo" aria-describedby="m">'
        '<span id="m" data-helper="ayuda">ayuda</span>'
        '<button type="submit">Entrar</button></form>',
      );
      final form = root.querySelector('form')! as web.HTMLFormElement;
      form.requestSubmit();
      await Future<void>.delayed(Duration.zero);
      expect(root.querySelector('#m')!.textContent, 'Escribe tu correo');
      expect(root.querySelector('#e')!.getAttribute('aria-invalid'), 'true');
    });

    test('a shortcut and a gesture of the part run the page\'s actions', () {
      final c = _Count();
      final root = mount('<div id="host"></div>');
      addTearDown(
        startThor(
          [c],
          root: root,
          features: const [ShortcutsFeature(), KeyboardFeature()],
        ),
      );
      stream(
        root.querySelector('#host')!,
        '<p id="k" tabindex="0" data-tks="+arrowdown>${c.idPrefix}.go">k</p>'
        '<div id="b" role="button" tabindex="0" '
        'data-t-on="click:${c.idPrefix}.go">b</div>',
      );
      root
          .querySelector('#k')!
          .dispatchEvent(
            web.KeyboardEvent(
              'keydown',
              web.KeyboardEventInit(
                key: 'ArrowDown',
                bubbles: true,
                cancelable: true,
              ),
            ),
          );
      expect(c.taps, 1);
      // Enter on a role=button of the part is a click, once.
      root
          .querySelector('#b')!
          .dispatchEvent(
            web.KeyboardEvent(
              'keydown',
              web.KeyboardEventInit(
                key: 'Enter',
                bubbles: true,
                cancelable: true,
              ),
            ),
          );
      expect(c.taps, 2);
    });

    test('a date button that needs the engine is shown', () {
      final root = page(const [DatePickerFeature()]);
      stream(
        root.querySelector('#host')!,
        '<button type="button" hidden data-t-date-open id="open">Elegir</button>',
      );
      expect(root.querySelector('#open')!.hasAttribute('hidden'), isFalse);
    });
  });
}
