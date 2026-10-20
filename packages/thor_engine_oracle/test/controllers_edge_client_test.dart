// The controllers pushed further on the dart2js engine (the lite engine has
// twin checks in test/e2e/checks/): identical values,
// FocusNode listeners (order, doubles, removal during a dispatch, dispose),
// fractional pages, no snapping, nested PageViews, a view that grows and
// hasClients of views that are hidden.
@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thor_engine_oracle/client.dart';
import 'package:web/web.dart' as web;

abstract class _Members extends ThorState {
  _Members({super.key});

  @override
  String get $type => 'Brk';

  @override
  List<ThorMember> get $members {
    final s = this as _Brk;
    return [
      ThorMember.controller('draft', s.draft),
      ThorMember.controller('a', s.a),
      ThorMember.controller('b', s.b),
      ThorMember.controller('pages', s.pages),
      ThorMember.controller('inner', s.inner),
      ThorMember.controller('hid', s.hid),
      ThorMember('go', s.go, arity: 1, call: (a) => s.go(int.parse(a!))),
      ThorMember('goIn', s.goIn, arity: 1, call: (a) => s.goIn(int.parse(a!))),
    ];
  }
}

class _Brk extends _Members {
  _Brk(String key) : super(key: key);

  final draft = TextEditingController();
  final a = FocusNode();
  final b = FocusNode();
  final pages = PageController();
  final inner = PageController();
  final hid = ScrollController();
  final went = <int>[];
  final wentIn = <int>[];
  void go(int page) => went.add(page);
  void goIn(int page) => wentIn.add(page);
}

var _keys = 0;

(_Brk, String) _state() {
  final s = _Brk('b${_keys++}');
  return (s, s.idPrefix);
}

web.HTMLElement mount(String html) {
  final root = web.document.createElement('div') as web.HTMLElement;
  root.innerHTML = html.toJS;
  web.document.body!.append(root);
  // ignore: unnecessary_lambdas
  addTearDown(() => root.remove());
  return root;
}

void start(web.Element root, List<ThorState> states) {
  addTearDown(
    startThor(
      states,
      root: root,
      features: const [ElementEventsFeature(), ControllersFeature()],
    ),
  );
}

String pagesHtml(String attrs, {String style = '', String inner = ''}) =>
    '<div id="v" $attrs style="display:flex;width:200px;height:100px;'
    'overflow-x:auto;scroll-snap-type:x mandatory;$style">'
    '${[for (var i = 0; i < 3; i++) _page(i == 0 ? inner : '')].join()}</div>';

String _page(String inner) =>
    '<div style="flex:0 0 100%;min-width:0;scroll-snap-align:start">'
    '$inner</div>';

web.HTMLElement view(web.Element root) =>
    root.querySelector('#v')! as web.HTMLElement;

Future<void> until(bool Function() ready, [String? what]) async {
  final end = DateTime.now().add(const Duration(seconds: 10));
  while (!ready()) {
    if (DateTime.now().isAfter(end)) fail('timed out: ${what ?? 'condition'}');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> frames([int ms = 0]) =>
    Future<void>.delayed(Duration(milliseconds: ms + 50));

void main() {
  group('TextEditingController.value', () {
    test('an identical value or selection is not a change', () async {
      final (s, id) = _state();
      final root = mount('<input data-ttc="$id.draft" value="Ana">');
      start(root, [s]);
      var runs = 0;
      final stop = effect(() {
        s.draft.value;
        runs++;
      });
      addTearDown(stop);
      final v0 = s.draft.value;
      s.draft.value = v0;
      s.draft.value = TextEditingValue(text: v0.text, selection: v0.selection);
      s.draft.selection = s.draft.selection;
      await frames();
      expect(runs, 1);
    });

    test('a selection past the text is clamped, in the controller and the '
        'field; text and selection reach an effect together', () async {
      final (s, id) = _state();
      final root = mount('<input data-ttc="$id.draft">');
      start(root, [s]);
      final seen = <String>[];
      final stop = effect(
        () => seen.add('${s.draft.text}|${s.draft.selection.baseOffset}'),
      );
      addTearDown(stop);
      s.draft.value = const TextEditingValue(
        text: 'abc',
        selection: TextSelection(baseOffset: 9, extentOffset: 12),
      );
      await frames();
      final f = root.querySelector('input')! as web.HTMLInputElement;
      expect((f.selectionStart, f.selectionEnd), (3, 3));
      expect(s.draft.selection, const TextSelection.collapsed(offset: 3));
      expect(seen.length, 2, reason: 'one run for the pair: $seen');
      expect(seen.last, 'abc|3');
    });
  });

  group('FocusNode listeners', () {
    test(
      'moving focus between two fields: each once, the old one first',
      () async {
        final (s, id) = _state();
        final root = mount(
          '<input id="a" data-tfn="$id.a"><input id="b" data-tfn="$id.b">',
        );
        start(root, [s]);
        final log = <String>[];
        s.a.addListener(() => log.add('a:${s.a.hasFocus}'));
        s.b.addListener(() => log.add('b:${s.b.hasFocus}'));
        (root.querySelector('#a')! as web.HTMLElement).focus();
        (root.querySelector('#b')! as web.HTMLElement).focus();
        await frames();
        expect(log, ['a:true', 'a:false', 'b:true']);
      },
    );

    test(
      'a listener added twice is called twice; each removal takes one',
      () async {
        final (s, id) = _state();
        final root = mount('<input id="a" data-tfn="$id.a">');
        start(root, [s]);
        final el = root.querySelector('#a')! as web.HTMLElement;
        var n = 0;
        void f() => n++;
        s.a
          ..addListener(f)
          ..addListener(f);
        el.focus();
        await frames();
        expect(n, 2);
        el.blur();
        await frames();
        n = 0;
        s.a.removeListener(f);
        el.focus();
        await frames();
        expect(n, 1);
        el.blur();
        s.a.removeListener(f);
        await frames();
        n = 0;
        el.focus();
        await frames();
        expect(n, 0);
      },
    );

    test('removed by an earlier listener in the same dispatch: not called; '
        'added during it: waits', () async {
      final (s, id) = _state();
      final root = mount('<input id="a" data-tfn="$id.a">');
      start(root, [s]);
      final log = <String>[];
      void second() => log.add('second');
      void late() => log.add('late');
      void first() {
        log.add('first');
        s.a
          ..removeListener(second)
          ..addListener(late);
      }

      s.a
        ..addListener(first)
        ..addListener(second);
      (root.querySelector('#a')! as web.HTMLElement).focus();
      await frames();
      expect(log, ['first']);
    });

    test(
      'addListener after dispose throws; a disposed node tells nobody',
      () async {
        final (s, id) = _state();
        final root = mount('<input id="a" data-tfn="$id.a">');
        start(root, [s]);
        var n = 0;
        s.a
          ..addListener(() => n++)
          ..dispose();
        expect(() => s.a.addListener(() {}), throwsStateError);
        (root.querySelector('#a')! as web.HTMLElement).focus();
        await frames();
        expect(n, 0);
      },
    );
  });

  group('PageController', () {
    test('page is fractional between pages (not rounded)', () async {
      final (s, id) = _state();
      final root = mount(
        pagesHtml(
          'data-tsc="$id.pages" data-tsc-h',
          style: 'scroll-snap-type:none',
        ),
      );
      start(root, [s]);
      view(root).scrollLeft = 130;
      await until(() => s.pages.offset == 130, 'the scroll event');
      expect(s.pages.page, 0.65);
    });

    test('without snapping the view stays where it was left; the report is '
        'the nearest page', () async {
      final (s, id) = _state();
      final root = mount(
        pagesHtml(
          'data-tsc="$id.pages" data-tsc-h data-t-ev="page:$id.go"',
          style: 'scroll-snap-type:none',
        ),
      );
      start(root, [s]);
      await frames();
      view(root).scrollLeft = 270;
      await until(() => s.went.isNotEmpty);
      expect(s.went, [1]);
      expect(view(root).scrollLeft, 270);
      expect(s.pages.page, closeTo(1.35, 1e-9));
    });

    test('nested views report on their own, and jump independently', () async {
      final (s, id) = _state();
      final root = mount(
        pagesHtml(
          'data-tsc="$id.pages" data-tsc-h data-t-ev="page:$id.go"',
          inner:
              '<div id="in" data-tsc="$id.inner" data-tsc-h '
              'data-t-ev="page:$id.goIn" style="display:flex;width:100px;'
              'height:100px;overflow-x:auto;scroll-snap-type:x mandatory">'
              '${'<div style="flex:0 0 100%;scroll-snap-align:start"></div>' * 3}'
              '</div>',
        ),
      );
      start(root, [s]);
      await frames();
      (root.querySelector('#in')! as web.HTMLElement).scrollLeft = 100;
      await until(() => s.wentIn.isNotEmpty);
      await frames(200);
      expect(s.went, isEmpty);
      expect(s.wentIn, [1]);
      view(root).scrollLeft = 200;
      await until(() => s.went.isNotEmpty);
      await frames(200);
      expect(s.went, [1]);
      expect(s.wentIn, [1]);
      s.pages.jumpToPage(2);
      s.inner.jumpToPage(2);
      await until(() => s.went.length == 2 && s.wentIn.length == 2);
      expect(s.pages.page, 2);
      expect(s.inner.page, 2);
    });

    test('the view growing keeps the page', () async {
      final (s, id) = _state();
      final root = mount(
        pagesHtml('data-tsc="$id.pages" data-tsc-h data-t-ev="page:$id.go"'),
      );
      start(root, [s]);
      await frames();
      s.pages.jumpToPage(2);
      await until(() => s.went.isNotEmpty);
      view(root).style.width = '300px';
      await frames(300);
      expect(s.pages.page, 2);
      expect(s.went, [2]);
    });
  });

  group('ScrollController.hasClients', () {
    test('a view in a closed <dialog> or display:none is in the page '
        '(size 0); it measures once shown', () async {
      final (s, id) = _state();
      final root = mount(
        '<div id="h" data-tsc="$id.hid" style="display:none;height:50px;'
        'overflow:auto"><div style="height:500px">x</div></div>',
      );
      start(root, [s]);
      expect(s.hid.hasClients, isTrue);
      expect(s.hid.position.viewportDimension, 0);
      (root.querySelector('#h')! as web.HTMLElement).style.display = 'block';
      s.hid.jumpTo(30);
      await until(() => s.hid.offset == 30);
      expect(s.hid.position.viewportDimension, 50);
    });
  });
}
