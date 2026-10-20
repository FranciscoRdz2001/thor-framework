// A late part (`thor:stream`) with the markup of every page-wide feature:
// each one must work in the part as it does in the page. Features that only
// listen on the scope reach the part by themselves; the ones that scan the
// page when they start (controllers, element events' initial state) need
// `installLate`.
@TestOn('browser')
library;

import 'dart:async';
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

var _keys = 0;

/// A state that records what the page calls on it, and holds one of each
/// controller.
class _Page extends ThorState {
  _Page({int initialPage = 0})
    : pages = PageController(initialPage: initialPage),
      super(key: 'p${_keys++}');

  final calls = <String>[];
  final scroll = ScrollController(initialScrollOffset: 120);
  final PageController pages;
  final draft = TextEditingController();
  final focus = FocusNode();
  final dialog = DialogController();

  @override
  String get $type => 'LatePage';

  @override
  List<ThorMember> get $members => [
    ThorMember('go', go, arity: 1, call: go),
    ThorMember.controller('scroll', scroll),
    ThorMember.controller('pages', pages),
    ThorMember.controller('draft', draft),
    ThorMember.controller('focus', focus),
    ThorMember.controller('dialog', dialog),
  ];

  void go(String? a) => calls.add('$a');
}

void main() {
  late web.HTMLElement root;
  late _Page s;
  late String p;

  void start(List<EngineFeature> features) {
    s = _Page();
    p = s.idPrefix;
    root = mount('<div id="host"></div>');
    addTearDown(startThor([s], root: root, features: features));
  }

  void late_(String html) => stream(root.querySelector('#host')!, html);

  web.Element q(String selector) => root.querySelector(selector)!;

  test('Commands: a button of the part opens and closes its dialog', () {
    start(const [CommandsFeature()]);
    late_(
      '<button id="o" type="button" commandfor="d" command="show-modal">o'
      '</button><dialog id="d"><button id="c" type="button" commandfor="d" '
      'command="close">c</button></dialog>',
    );
    final d = q('#d') as web.HTMLDialogElement;
    (q('#o') as web.HTMLElement).click();
    expect(d.open, isTrue);
    (q('#c') as web.HTMLElement).click();
    expect(d.open, isFalse);
  });

  test('Transitions: one onEnd per change in a part', () async {
    start(const [TransitionsFeature()]);
    late_(
      '<div id="t" data-t-on="transitionend:$p.go" style="width:10px;'
      'height:10px;transition:width 60ms, height 60ms"></div>',
    );
    final t = q('#t') as web.HTMLElement;
    await frames();
    t.style
      ..width = '40px'
      ..height = '40px';
    await frames(200);
    expect(s.calls, ['null'], reason: 'two properties, one call');
  });

  test(
    'ElementEvents: a tile, a region and a view of the part report',
    () async {
      start(const [ElementEventsFeature()]);
      late_(
        '<details id="d" open data-t-ev="toggle:$p.go"><summary>s</summary>c'
        '</details>'
        '<div id="r" data-t-ev="enter:$p.go;leave:$p.go"><input id="i"></div>'
        '<div id="f" data-t-ev="focus:$p.go"><input id="fi"></div>',
      );
      final d = q('#d') as web.HTMLDetailsElement;
      await frames(); // the toggle the browser fires for a tile that is open
      expect(s.calls, isEmpty, reason: 'arriving open is not a change');
      d.open = false;
      await frames();
      expect(s.calls, [
        'false',
      ], reason: 'it arrived open: closing is a change');
      s.calls.clear();
      (q('#fi') as web.HTMLElement).focus();
      expect(s.calls, ['true']);
      (q('#fi') as web.HTMLElement).blur();
      expect(s.calls, ['true', 'false']);
      s.calls.clear();
      q('#i').dispatchEvent(
        web.PointerEvent(
          'pointerover',
          web.PointerEventInit(bubbles: true, pointerType: 'mouse'),
        ),
      );
      expect(s.calls, ['null']);
    },
  );

  test(
    'ElementEvents: a view that arrives on its initial page is silent',
    () async {
      s = _Page(initialPage: 2);
      root = mount('<div id="host"></div>');
      addTearDown(
        startThor(
          [s],
          root: root,
          features: const [ElementEventsFeature(), ControllersFeature()],
        ),
      );
      p = s.idPrefix;
      await frames(); // the engine has started
      late_(
        '<div id="v" data-t-ev="page:$p.go" data-tsc="$p.pages" data-tsc-h '
        'style="display:flex;width:200px;height:50px;overflow-x:auto;'
        'scroll-snap-type:x mandatory">'
        '${List.filled(4, '<div style="flex:0 0 100%;scroll-snap-align:start">'
        '</div>').join()}</div>',
      );
      await frames(300);
      expect((q('#v') as web.HTMLElement).scrollLeft, 400);
      q('#v').dispatchEvent(web.Event('scrollend'));
      expect(s.calls, isEmpty, reason: 'no page change happened');
    },
  );

  test('Gestures: a double tap on an element of the part', () async {
    start(const [GesturesFeature()]);
    late_('<div id="g" data-t-on="" data-tg="dtap:$p.go">g</div>');
    final g = q('#g') as web.HTMLElement;
    void tap() {
      for (final type in ['pointerdown', 'pointerup']) {
        g.dispatchEvent(
          web.PointerEvent(
            type,
            web.PointerEventInit(
              bubbles: true,
              pointerType: 'mouse',
              isPrimary: true,
              clientX: 5,
              clientY: 5,
              button: 0,
            ),
          ),
        );
      }
    }

    tap();
    tap();
    await frames();
    expect(s.calls, ['null']);
  });

  test('Dropdown and Autocomplete: the part opens its panels', () async {
    start(const [DropdownMenuFeature(), AutocompleteFeature()]);
    late_(
      '<div data-t-ac="f"><input id="a" type="text"><div id="ap" '
      'popover="manual" role="listbox"><div role="option">x</div></div></div>'
      '<div data-t-dd="s"><button id="b" type="button" role="combobox" '
      'aria-haspopup="listbox" aria-expanded="false" aria-controls="dp" '
      'popovertarget="dp"><span data-tdl>x</span></button><select><option '
      'value="x" selected>x</option></select><div id="dp" popover="auto" '
      'role="listbox"><div role="option" aria-selected="true">x</div></div>'
      '</div>',
    );
    (q('#a') as web.HTMLElement).focus();
    await frames();
    expect(q('#ap').matches(':popover-open'), isTrue);
    (q('#b') as web.HTMLElement).click();
    await frames();
    expect(q('#b').getAttribute('aria-expanded'), 'true');
  });

  test('SizeAnimations: a shell of the part animates', () async {
    start(const [SizeAnimationsFeature()]);
    late_(
      '<div id="s2" data-tsz="400|linear|400" style="display:flex;'
      'flex-direction:column;overflow:hidden"><div style="display:flow-root;'
      'flex:none"><div id="c2" style="height:50px"></div></div></div>',
    );
    await frames(60);
    (q('#c2') as web.HTMLElement).style.height = '150px';
    await frames(100);
    expect(q('#s2').getAnimations().length, 1);
  });

  group('Controllers in a part', () {
    test('a scroll view starts where its controller says', () async {
      start(const [ControllersFeature()]);
      late_(
        '<div id="v" data-tsc="$p.scroll" style="width:100px;height:50px;'
        'overflow-y:auto"><div style="height:1000px"></div></div>',
      );
      await frames();
      expect((q('#v') as web.HTMLElement).scrollTop, 120);
      expect(s.scroll.hasClients, isTrue);
      expect(s.scroll.position.pixels, 120);
    });

    test('a page view starts on the initial page', () async {
      start(const [ControllersFeature()]);
      s = _Page(initialPage: 2);
      root = mount('<div id="host"></div>');
      addTearDown(
        startThor([s], root: root, features: const [ControllersFeature()]),
      );
      p = s.idPrefix;
      late_(
        '<div id="v" data-tsc="$p.pages" data-tsc-h style="display:flex;'
        'width:200px;height:50px;overflow-x:auto;scroll-snap-type:x mandatory">'
        '${List.filled(4, '<div style="flex:0 0 100%;scroll-snap-align:start">'
        '</div>').join()}</div>',
      );
      await frames();
      expect((q('#v') as web.HTMLElement).scrollLeft, 400);
      expect(s.pages.page, 2);
    });

    test('a field of the part follows the text controller', () async {
      start(const [ControllersFeature()]);
      late_('<input id="t" data-ttc="$p.draft" value="">');
      final t = q('#t') as web.HTMLInputElement;
      s.draft.text = 'hello';
      expect(t.value, 'hello');
      t.value = 'typed';
      t.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
      expect(s.draft.text, 'typed');
    });

    test('a field of the part follows the focus node', () async {
      start(const [ControllersFeature()]);
      late_('<input id="f" data-tfn="$p.focus">');
      s.focus.requestFocus();
      await frames();
      expect(web.document.activeElement, q('#f'));
      expect(s.focus.hasFocus, isTrue);
      (q('#f') as web.HTMLElement).blur();
      expect(s.focus.hasFocus, isFalse);
    });

    test('a dialog of the part follows the dialog controller', () async {
      start(const [ControllersFeature()]);
      late_('<dialog id="dl" data-tdc="$p.dialog">hi</dialog>');
      final d = q('#dl') as web.HTMLDialogElement;
      s.dialog.open();
      await frames();
      expect(d.open, isTrue);
      d.close();
      await frames();
      expect(s.dialog.isOpen, isFalse);
    });
  });
}
