// The curves of animateTo / animateBack / fling and the scroll animations on
// the dart2js engine (the lite engine's twin checks are in
// test/e2e/checks/): the browser evaluates the
// easing, so these sample real animations.
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

/// A curve with its function too: t squared.
class _Quad {
  const _Quad();
  String get css => 'cubic-bezier(0.42, 0, 1, 1)';
  double transform(double t) => t * t;
}

abstract class _Members extends ThorState {
  _Members({super.key});

  @override
  String get $type => 'Crv';

  @override
  List<ThorMember> get $members {
    final s = this as _Crv;
    return [
      ThorMember.controller('fade', s.fade),
      ThorMember.controller('list', s.list),
      ThorMember.controller('pages', s.pages),
      ThorMember('go', s.go, arity: 1, call: (a) => s.go(int.parse(a!))),
    ];
  }
}

class _Crv extends _Members {
  _Crv(String key) : super(key: key);

  final fade = AnimationController(duration: const Duration(milliseconds: 400));
  final list = ScrollController();
  final pages = PageController();
  final went = <int>[];
  void go(int page) => went.add(page);
}

var _keys = 0;

(_Crv, String) _state() {
  final s = _Crv('c${_keys++}');
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
      features: const [
        AnimationsFeature(),
        ElementEventsFeature(),
        ControllersFeature(),
      ],
    ),
  );
}

double opacity(web.Element el) =>
    double.parse(web.window.getComputedStyle(el).opacity);

/// The progress of the CSS easing [css] at [s], by the browser.
double along(String css, double s) {
  final a = web.Animation(
    web.KeyframeEffect(
      null,
      null,
      web.KeyframeAnimationOptions(
        duration: 1000.toJS,
        easing: css,
        fill: 'both',
      ),
    ),
  )..pause();
  a.currentTime = (s * 1000).toJS;
  return a.effect!.getComputedTiming().progress!;
}

Future<void> until(bool Function() ready, [String? what]) async {
  final end = DateTime.now().add(const Duration(seconds: 10));
  while (!ready()) {
    if (DateTime.now().isAfter(end)) fail('timed out: ${what ?? 'condition'}');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> frames([int ms = 0]) =>
    Future<void>.delayed(Duration(milliseconds: ms + 50));

const _track =
    '{"c":"%ID%.fade","k":[{"offset":0,"opacity":"0"},'
    '{"offset":1,"opacity":"1"}]}';

void main() {
  group('AnimationController curves', () {
    // Each case: from, to, the CSS curve.
    for (final (name, from, to, css) in [
      ('0 to 1 easeOut', 0.0, 1.0, 'cubic-bezier(0, 0, 0.58, 1)'),
      ('0 to 0.5 easeInOut', 0.0, 0.5, 'cubic-bezier(0.42, 0, 0.58, 1)'),
      ('1 to 0 easeOut', 1.0, 0.0, 'cubic-bezier(0, 0, 0.58, 1)'),
      ('0.8 to 0.2 easeIn', 0.8, 0.2, 'cubic-bezier(0.42, 0, 1, 1)'),
      ('0.2 to 0.6 easeOut', 0.2, 0.6, 'cubic-bezier(0, 0, 0.58, 1)'),
      (
        '0 to 1 overshooting',
        0.0,
        1.0,
        'cubic-bezier(0.175, 0.885, 0.32, 1.275)',
      ),
    ]) {
      test(
        '$name: the element follows the curve, clamped to the range',
        () async {
          final (s, id) = _state();
          final root = mount(
            '<div id="b" style="width:10px;height:10px;opacity:0" '
            "data-ta='[${_track.replaceAll('%ID%', id)}]'></div>",
          );
          final el = root.querySelector('#b')! as web.HTMLElement;
          start(root, [s]);
          s.fade.value = from;
          final f = s.fade.animateTo(
            to,
            duration: const Duration(seconds: 1),
            curve: _Curve(css),
          );
          for (final t in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]) {
            final q = from + (to - from) * t; // directed progress
            for (final a in el.getAnimations().toDart) {
              a.pause();
              // Partial backwards moves run the reversed pass forwards.
              a.currentTime = ((to < from && to != 0 ? 1 - q : q) * 1000).toJS;
            }
            final want = (from + (to - from) * along(css, t)).clamp(0.0, 1.0);
            expect(opacity(el), closeTo(want, 0.012), reason: 't=$t');
          }
          s.fade.stop();
          await f;
        },
      );
    }

    test('a run: statuses, the end value, the future; reduced motion is not '
        'in play here', () async {
      final (s, id) = _state();
      start(mount('<p>$id</p>'), [s]);
      final seen = <AnimationStatus>[];
      s.fade.addStatusListener(seen.add);
      await s.fade.animateTo(
        0.5,
        duration: const Duration(milliseconds: 150),
        curve: const _Curve('cubic-bezier(0.42, 0, 0.58, 1)'),
      );
      expect(s.fade.value, 0.5);
      expect(s.fade.status, AnimationStatus.completed);
      await s.fade.animateBack(
        0,
        duration: const Duration(milliseconds: 100),
        curve: const _Curve('cubic-bezier(0, 0, 0.58, 1)'),
      );
      expect(s.fade.value, 0);
      expect(seen, [
        AnimationStatus.forward,
        AnimationStatus.completed,
        AnimationStatus.reverse,
        AnimationStatus.dismissed,
      ]);
    });

    test('fling arrives at the bound, in the spring\'s time; the velocity '
        'sign picks the bound', () async {
      final (s, id) = _state();
      start(mount('<p>$id</p>'), [s]);
      final t0 = DateTime.now();
      await s.fade.fling();
      final took = DateTime.now().difference(t0).inMilliseconds;
      expect(s.fade.value, 1);
      expect(s.fade.status, AnimationStatus.completed);
      expect(took, inInclusiveRange(150, 900));
      await s.fade.fling(velocity: -3);
      expect(s.fade.value, 0);
      expect(s.fade.status, AnimationStatus.dismissed);
    });

    test('dispose mid-animation releases the future', () async {
      final (s, id) = _state();
      start(mount('<p>$id</p>'), [s]);
      final f = s.fade.animateTo(
        1,
        duration: const Duration(seconds: 5),
        curve: const _Curve('cubic-bezier(0, 0, 0.58, 1)'),
      );
      await frames();
      s.fade.dispose();
      await f.timeout(const Duration(seconds: 2));
      expect(s.fade.isAnimating, isFalse);
      expect(
        () => s.fade.animateTo(1, duration: const Duration(seconds: 1)),
        throwsStateError,
      );
    });
  });

  test('a move made before the page woke up goes on from the pass the '
      'server\'s CSS animation was at, with the same curve', () async {
    final (s, id) = _state();
    // The server's output: the animation a quarter of a pass in.
    final root = mount(
      '<style>@keyframes kf{0%{opacity:0}100%{opacity:1}}</style>'
      '<div id="b" style="width:10px;height:10px;animation:kf 400ms linear '
      '-100ms 0.5 normal both paused" '
      "data-ta='[{\"c\":\"$id.fade\",\"k\":[{\"offset\":0,\"opacity\":\"0\"},"
      '{"offset":1,"opacity":"1"}],"a":"kf"}]\'></div>',
    );
    final f = s.fade.animateTo(
      0.5,
      duration: const Duration(milliseconds: 200),
      curve: const _Quad(),
    );
    start(root, [s]);
    expect(s.fade.isAnimating, isTrue);
    final el = root.querySelector('#b')! as web.HTMLElement;
    // Where the move was: a quarter of the pass (a quarter of 400 ms was
    // 100 ms in); the value is the curve's there (0.5 * 0.5^2... of 0.5).
    expect(s.fade.value, closeTo(0.0625, 0.12));
    await f;
    await until(() => s.fade.status == AnimationStatus.completed, 'end');
    expect(s.fade.value, 0.5);
    expect(s.fade.status, AnimationStatus.completed);
    expect(opacity(el), closeTo(0.5, 0.01));
  });

  group('scroll animations', () {
    web.HTMLElement view(web.Element root) =>
        root.querySelector('#v')! as web.HTMLElement;

    test('ScrollController.animateTo scrolls over its duration along the '
        'curve and lands; the snap points come back', () async {
      final (s, id) = _state();
      final root = mount(
        '<div id="v" data-tsc="$id.list" style="height:100px;overflow:auto;'
        'scroll-snap-type:y proximity"><div style="height:1000px">x</div></div>',
      );
      start(root, [s]);
      final el = view(root);
      final rows = <(int, double)>[];
      final t0 = DateTime.now();
      final f = s.list.animateTo(
        800,
        duration: const Duration(milliseconds: 600),
        curve: const _Curve('cubic-bezier(0, 0, 0.58, 1)'),
      );
      final timer = Timer.periodic(
        const Duration(milliseconds: 16),
        (_) => rows.add((
          DateTime.now().difference(t0).inMilliseconds,
          el.scrollTop,
        )),
      );
      await f;
      timer.cancel();
      expect(el.scrollTop, 800);
      expect(s.list.offset, 800);
      expect(
        el.style.scrollSnapType,
        'y',
        reason: 'the browser says `y` for it',
      );
      final took = DateTime.now().difference(t0).inMilliseconds;
      expect(took, inInclusiveRange(560, 1500));
      // Never backwards; around half the time it is past half (easeOut).
      for (var i = 1; i < rows.length; i++) {
        expect(rows[i].$2, greaterThanOrEqualTo(rows[i - 1].$2));
      }
      final half = rows.reduce(
        (a, b) => (a.$1 - 300).abs() < (b.$1 - 300).abs() ? a : b,
      );
      expect(
        half.$2 / 800,
        closeTo(along('cubic-bezier(0, 0, 0.58, 1)', 0.5), 0.15),
      );
    });

    test(
      'the visitor\'s wheel cuts it where it is and the future completes',
      () async {
        final (s, id) = _state();
        final root = mount(
          '<div id="v" data-tsc="$id.list" style="height:100px;overflow:auto">'
          '<div style="height:1000px">x</div></div>',
        );
        start(root, [s]);
        final el = view(root);
        final f = s.list.animateTo(
          900,
          duration: const Duration(milliseconds: 1500),
          curve: const _Curve('linear'),
        );
        await frames(150);
        final at = el.scrollTop;
        el.dispatchEvent(
          web.WheelEvent('wheel', web.WheelEventInit(deltaY: 10)),
        );
        await f.timeout(const Duration(seconds: 1));
        expect(at, greaterThan(50));
        expect(el.scrollTop, lessThan(700));
        expect(s.list.offset, el.scrollTop);
      },
    );

    test('a jumpTo and another animateTo cut the one running', () async {
      final (s, id) = _state();
      final root = mount(
        '<div id="v" data-tsc="$id.list" style="height:100px;overflow:auto">'
        '<div style="height:1000px">x</div></div>',
      );
      start(root, [s]);
      var first = false;
      unawaited(
        s.list
            .animateTo(
              900,
              duration: const Duration(seconds: 2),
              curve: const _Curve('linear'),
            )
            .then((_) => first = true),
      );
      await frames(100);
      s.list.jumpTo(10);
      await frames();
      expect(first, isTrue);
      expect(view(root).scrollTop, 10);
      var second = false;
      unawaited(
        s.list
            .animateTo(
              500,
              duration: const Duration(seconds: 2),
              curve: const _Curve('linear'),
            )
            .then((_) => second = true),
      );
      await frames(100);
      final last = s.list.animateTo(
        200,
        duration: const Duration(milliseconds: 100),
        curve: const _Curve('linear'),
      );
      await last;
      expect(second, isTrue);
      expect(view(root).scrollTop, 200);
    });

    test('animateToPage lands on the page after its duration and reports '
        'where it ended, not each page on the way', () async {
      final (s, id) = _state();
      final root = mount(
        '<div id="v" data-tsc="$id.pages" data-tsc-h '
        'data-t-ev="page:$id.go" style="display:flex;width:200px;height:100px;'
        'overflow-x:auto;scroll-snap-type:x mandatory">'
        '${'<div style="flex:0 0 100%;scroll-snap-align:start"></div>' * 4}'
        '</div>',
      );
      start(root, [s]);
      await frames();
      final t0 = DateTime.now();
      await s.pages.animateToPage(
        3,
        duration: const Duration(milliseconds: 600),
        curve: const _Curve('cubic-bezier(0.4, 0, 0.2, 1)'),
      );
      expect(DateTime.now().difference(t0).inMilliseconds, greaterThan(550));
      expect(view(root).scrollLeft, 600);
      expect(view(root).style.scrollSnapType, 'x mandatory');
      await until(() => s.went.isNotEmpty);
      await frames(200);
      expect(s.went, [3]);
      expect(s.pages.page, 3);
    });
  });
}
