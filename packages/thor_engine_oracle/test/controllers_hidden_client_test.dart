// A scroll view or PageView that is hidden when the engine reaches it (a closed
// tab, `display: none`) starts from its controller's initial offset / page when
// it first gets a size, and that start is not an onPageChanged. The lite
// engine's twin is in
// `test/e2e/checks/lite_late_bindings_adversarial_check.mjs`.
@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thor_engine_oracle/client.dart';
import 'package:web/web.dart' as web;

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
  test('a hidden PageView starts on its initialPage when it is shown', () async {
    final (s, id) = _state(initialPage: 2);
    final root = mount(
      '<div id="wrap" style="display:none">'
      '${pagesHtml('data-tsc="$id.pages" data-tsc-h data-t-ev="page:$id.go"')}'
      '</div>',
    );
    start(root, [s]);
    await frames();
    expect(view(root).scrollLeft, 0, reason: 'no size, nothing to move');
    (root.querySelector('#wrap')! as web.HTMLElement).style.display = 'block';
    await until(() => view(root).scrollLeft == 400, 'the start');
    await frames(200);
    expect(s.pages.page, 2);
    expect(s.went, isEmpty, reason: 'starting there is not a change');
    view(root).scrollLeft = 600;
    await until(() => s.went.isNotEmpty, 'the next change');
    expect(s.went, [3]);
  });

  test('a hidden scroll view starts at its initialScrollOffset', () async {
    final controller = ScrollController(initialScrollOffset: 60);
    final state = _ScrollOnly(controller, key: 'hs${_keys++}');
    final id = state.idPrefix;
    final root = mount(
      '<div id="wrap" style="display:none"><div id="v" data-tsc="$id.scroll" '
      'style="height:100px;overflow:auto"><div style="height:1000px"></div>'
      '</div></div>',
    );
    start(root, [state]);
    await frames();
    expect(view(root).scrollTop, 0);
    (root.querySelector('#wrap')! as web.HTMLElement).style.display = 'block';
    await until(() => view(root).scrollTop == 60, 'the offset');
    await until(() => controller.offset == 60, 'measured');
  });
}

class _ScrollOnly extends ThorState {
  _ScrollOnly(this.scroll, {super.key});

  final ScrollController scroll;

  @override
  String get $type => 'ScrollOnly';

  @override
  List<ThorMember> get $members => [ThorMember.controller('scroll', scroll)];
}
