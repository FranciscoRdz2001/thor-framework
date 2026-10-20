// The controllers of a ThorState on the dart2js engine (the lite engine's
// twin checks are test/e2e/checks/controllers_check.mjs):
// ScrollController.hasClients, TextEditingController.value, FocusNode
// listeners, PageController and PageView.onPageChanged.
@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thor_engine_oracle/client.dart';
import 'package:web/web.dart' as web;

/// What a thor_style `Curve` is to the controller: an object with a CSS
/// easing.
class _Curve {
  const _Curve(this.css);
  final String css;
}

// The member list thor generates for [_Ctl], by hand.
abstract class _CtlMembers extends ThorState {
  _CtlMembers({super.key});

  @override
  String get $type => 'Ctl';

  @override
  List<ThorMember> get $members {
    final s = this as _Ctl;
    return [
      ThorMember.controller('scroll', s.scroll),
      ThorMember.controller('draft', s.draft),
      ThorMember.controller('focus', s.focus),
      ThorMember.controller('pages', s.pages),
      ThorMember('go', s.go, arity: 1, call: (a) => s.go(int.parse(a!))),
    ];
  }
}

class _Ctl extends _CtlMembers {
  _Ctl(String key, {int initialPage = 0})
    : pages = PageController(initialPage: initialPage),
      super(key: key);

  final scroll = ScrollController();
  final draft = TextEditingController();
  final focus = FocusNode();
  final PageController pages;

  /// The pages `onPageChanged` reported.
  final went = <int>[];
  void go(int page) => went.add(page);
}

var _keys = 0;

/// A fresh state (ids are per key) and its id prefix.
(_Ctl, String) _state({int initialPage = 0}) {
  final s = _Ctl('k${_keys++}', initialPage: initialPage);
  return (s, s.idPrefix);
}

web.HTMLElement mount(String html) {
  final root = web.document.createElement('div') as web.HTMLElement;
  root.innerHTML = html.toJS;
  web.document.body!.append(root);
  // A lambda: tear-offs of interop members are not allowed.
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

/// A PageView's markup: [count] pages of the view's size in a scroll-snap
/// flex row (or column); [attrs] the engine's markers.
String pagesHtml(
  String attrs, {
  int count = 4,
  bool horizontal = true,
  String style = '',
  String dir = '',
}) {
  final axis = horizontal ? 'x' : 'y';
  final flow = horizontal ? 'row' : 'column';
  return '<div id="v" $dir $attrs style="display:flex;flex-direction:$flow;'
      'width:200px;height:100px;overflow-$axis:auto;'
      'scroll-snap-type:$axis mandatory;$style">'
      '${List.filled(count, '<div style="flex:0 0 100%;min-width:0;min-height:0;'
      'scroll-snap-align:start"></div>').join()}</div>';
}

web.HTMLElement view(web.Element root) =>
    root.querySelector('#v')! as web.HTMLElement;

/// Waits until [ready], or fails after a deadline.
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
  group('ScrollController.hasClients', () {
    test('is true while its element is in the page', () async {
      final (s, id) = _state();
      final root = mount(
        '<div id="v" style="height:50px;overflow:auto" data-tsc="$id.scroll">'
        '<div style="height:500px"></div></div>',
      );
      start(root, [s]);
      expect(s.scroll.hasClients, isTrue);
      root.querySelector('#v')!.remove();
      expect(s.scroll.hasClients, isFalse, reason: 'its view is gone');
    });

    test('is false when no element of the page uses it', () async {
      final (s, _) = _state();
      start(mount('<p>nothing</p>'), [s]);
      expect(s.scroll.hasClients, isFalse);
    });
  });

  group('TextEditingController.value', () {
    web.HTMLInputElement field(web.Element root) =>
        root.querySelector('input')! as web.HTMLInputElement;

    test('set shows the text and puts the selection in the field', () async {
      final (s, id) = _state();
      final root = mount('<input data-ttc="$id.draft" value="Ana">');
      start(root, [s]);
      s.draft.value = const TextEditingValue(
        text: 'Maria',
        selection: TextSelection(baseOffset: 1, extentOffset: 3),
      );
      await frames();
      final f = field(root);
      expect((f.value, f.selectionStart, f.selectionEnd), ('Maria', 1, 3));
      expect(
        s.draft.value,
        const TextEditingValue(
          text: 'Maria',
          selection: TextSelection(baseOffset: 1, extentOffset: 3),
        ),
      );
    });

    test('typing updates the text and the caret it reads back', () async {
      final (s, id) = _state();
      final root = mount('<input data-ttc="$id.draft" value="">');
      start(root, [s]);
      final f = field(root)..focus();
      f.value = 'hola';
      f.setSelectionRange(2, 2);
      f.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
      expect(s.draft.value.text, 'hola');
      expect(s.draft.value.selection, const TextSelection.collapsed(offset: 2));
      f.setSelectionRange(1, 4, 'backward');
      f.dispatchEvent(web.Event('select', web.EventInit(bubbles: true)));
      expect(
        s.draft.selection,
        const TextSelection(baseOffset: 4, extentOffset: 1),
      );
    });

    test('a selection past the text stops at its end; a type with no '
        'selection keeps the value', () async {
      final (s, id) = _state();
      final root = mount('<input type="email" data-ttc="$id.draft">');
      start(root, [s]);
      s.draft.value = const TextEditingValue(
        text: 'a@b.c',
        selection: TextSelection(baseOffset: 0, extentOffset: 99),
      );
      await frames();
      expect(field(root).value, 'a@b.c');
      expect(
        s.draft.selection,
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );
    });
  });

  group('FocusNode listeners', () {
    test('hear the element gain and lose the focus, hasFocus is new', () async {
      final (s, id) = _state();
      final root = mount(
        '<input id="f" data-tfn="$id.focus"><button>b</button>',
      );
      start(root, [s]);
      final seen = <bool>[];
      s.focus.addListener(() => seen.add(s.focus.hasFocus));
      (root.querySelector('#f')! as web.HTMLElement).focus();
      await frames();
      expect(seen, [true]);
      expect(s.focus.hasFocus, isTrue);
      (root.querySelector('button')! as web.HTMLElement).focus();
      await frames();
      expect(seen, [true, false]);
    });

    test('requestFocus and unfocus from a method notify too; a removed '
        'listener is quiet', () async {
      final (s, id) = _state();
      final root = mount('<input id="f" data-tfn="$id.focus">');
      start(root, [s]);
      var calls = 0;
      void listener() => calls++;
      s.focus.addListener(listener);
      s.focus.requestFocus();
      await frames();
      expect(calls, 1);
      s.focus.removeListener(listener);
      s.focus.unfocus();
      await frames();
      expect(calls, 1);
      expect(s.focus.hasFocus, isFalse);
    });
  });

  group('PageController', () {
    test('initialPage is where the view starts, and page says so', () async {
      final (s, id) = _state(initialPage: 2);
      final root = mount(pagesHtml('data-tsc="$id.pages" data-tsc-h'));
      start(root, [s]);
      expect(view(root).scrollLeft, 400);
      expect(s.pages.page, 2);
      expect(s.pages.hasClients, isTrue);
    });

    test('a restored position wins over initialPage', () async {
      final (s, id) = _state(initialPage: 2);
      final root = mount(pagesHtml('data-tsc="$id.pages" data-tsc-h'));
      view(root).scrollLeft = 200;
      start(root, [s]);
      expect(view(root).scrollLeft, 200);
      expect(s.pages.page, 1);
    });

    test('jumpToPage and animateToPage move the view; page follows', () async {
      final (s, id) = _state();
      final root = mount(pagesHtml('data-tsc="$id.pages" data-tsc-h'));
      start(root, [s]);
      s.pages.jumpToPage(3);
      expect(view(root).scrollLeft, 600);
      await until(() => s.pages.page == 3, 'page 3');
      await s.pages.animateToPage(
        1,
        duration: const Duration(milliseconds: 200),
        curve: const _Curve('ease'),
      );
      await until(() => s.pages.page == 1, 'page 1');
      expect(view(root).scrollLeft, 200);
    });

    test('a vertical PageView counts rows', () async {
      final (s, id) = _state();
      final root = mount(pagesHtml('data-tsc="$id.pages"', horizontal: false));
      start(root, [s]);
      s.pages.jumpToPage(2);
      expect(view(root).scrollTop, 200);
      await until(() => s.pages.page == 2);
    });

    test('RTL: offsets and pages count from the first page', () async {
      final (s, id) = _state();
      final root = mount(
        pagesHtml('data-tsc="$id.pages" data-tsc-h', dir: 'dir="rtl"'),
      );
      start(root, [s]);
      expect(s.pages.page, 0);
      s.pages.jumpToPage(2);
      expect(view(root).scrollLeft, -400, reason: 'the browser goes negative');
      await until(() => s.pages.page == 2, 'page 2');
      expect(s.pages.offset, 400);
      await s.pages.animateToPage(
        1,
        duration: const Duration(milliseconds: 100),
        curve: const _Curve('ease'),
      );
      await until(() => s.pages.page == 1);
      expect(view(root).scrollLeft, -200);
    });

    test('reverse (row-reverse) counts from the first page too', () async {
      final (s, id) = _state();
      final root = mount(
        pagesHtml(
          'data-tsc="$id.pages" data-tsc-h',
          style: 'flex-direction:row-reverse',
        ),
      );
      start(root, [s]);
      s.pages.jumpToPage(1);
      expect(view(root).scrollLeft, -200);
      await until(() => s.pages.page == 1);
      expect(s.pages.offset, 200);
    });

    test('a column-reverse view counts from its start too', () async {
      final (s, id) = _state();
      final root = mount(
        pagesHtml(
          'data-tsc="$id.pages"',
          horizontal: false,
          style: 'flex-direction:column-reverse',
        ),
      );
      start(root, [s]);
      s.pages.jumpToPage(2);
      expect(view(root).scrollTop, -200);
      await until(() => s.pages.page == 2);
      expect(s.pages.offset, 200);
    });

    test('RTL initialPage', () async {
      final (s, id) = _state(initialPage: 1);
      final root = mount(
        pagesHtml('data-tsc="$id.pages" data-tsc-h', dir: 'dir="rtl"'),
      );
      start(root, [s]);
      expect(view(root).scrollLeft, -200);
      expect(s.pages.page, 1);
    });
  });

  group('PageView.onPageChanged', () {
    test(
      'reports the page when scrolling ends, only when it changes',
      () async {
        final (s, id) = _state();
        final root = mount(
          pagesHtml('data-tsc="$id.pages" data-tsc-h data-t-ev="page:$id.go"'),
        );
        start(root, [s]);
        await frames();
        view(root).scrollLeft = 400;
        await until(() => s.went.isNotEmpty, 'first report');
        expect(s.went, [2]);
        // Still page 2 (a little further, within its half): nothing.
        view(root).scrollLeft = 430;
        await frames(150);
        expect(s.went, [2]);
        view(root).scrollLeft = 0;
        await until(() => s.went.length == 2, 'back to 0');
        expect(s.went, [2, 0]);
      },
    );

    test('halfway rounds like Flutter: 0.49 stays, 0.5 turns', () async {
      final (s, id) = _state();
      final root = mount(
        pagesHtml(
          'data-tsc="$id.pages" data-tsc-h data-t-ev="page:$id.go"',
          style: 'scroll-snap-type:none',
        ),
      );
      start(root, [s]);
      view(root).scrollLeft = 97;
      await frames(150);
      expect(s.went, isEmpty);
      view(root).scrollLeft = 100;
      await until(() => s.went.isNotEmpty);
      expect(s.went, [1]);
    });

    test('the initial page is not a change; a view with no controller counts '
        'from page 0', () async {
      final (s, id) = _state(initialPage: 2);
      final root = mount(
        pagesHtml('data-tsc="$id.pages" data-tsc-h data-t-ev="page:$id.go"'),
      );
      start(root, [s]);
      await frames(200);
      expect(s.went, isEmpty);
      s.pages.jumpToPage(3);
      await until(() => s.went.isNotEmpty);
      expect(s.went, [3], reason: 'jumpToPage reports, like Flutter');
    });

    test('RTL: the page is the same count', () async {
      final (s, id) = _state();
      final root = mount(
        pagesHtml(
          'data-tsc="$id.pages" data-tsc-h data-t-ev="page:$id.go"',
          dir: 'dir="rtl"',
        ),
      );
      start(root, [s]);
      await frames();
      view(root).scrollLeft = -400;
      await until(() => s.went.isNotEmpty);
      expect(s.went, [2]);
    });

    test('a vertical PageView', () async {
      final (s, id) = _state();
      final root = mount(
        pagesHtml('data-t-ev="page:$id.go"', horizontal: false),
      );
      start(root, [s]);
      await frames();
      view(root).scrollTop = 300;
      await until(() => s.went.isNotEmpty);
      expect(s.went, [3]);
    });

    test('without scrollend (Safari) a pause in the scroll ends it', () async {
      final (s, id) = _state();
      final root = mount(
        pagesHtml('data-tsc="$id.pages" data-tsc-h data-t-ev="page:$id.go"'),
      );
      // Registered first on the scope: nothing after it hears scrollend.
      root.addEventListener(
        'scrollend',
        ((web.Event e) => e.stopImmediatePropagation()).toJS,
        true.toJS,
      );
      start(root, [s]);
      await frames();
      view(root).scrollLeft = 200;
      await until(() => s.went.isNotEmpty, 'the timer fallback');
      expect(s.went, [1]);
    });
  });
}
