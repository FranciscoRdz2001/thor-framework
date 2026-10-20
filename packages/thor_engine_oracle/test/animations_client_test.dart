@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:test/test.dart';
import 'package:thor_engine_oracle/client.dart';
import 'package:web/web.dart' as web;

// The member list thor generates for [_Anim], by hand.
abstract class _AnimMembers extends ThorState {
  _AnimMembers({super.key});

  @override
  String get $type => 'Anim';

  @override
  List<ThorMember> get $members {
    final s = this as _Anim;
    return [
      ThorMember.controller('fade', s.fade),
      ThorMember.controller('grow', s.grow),
      ThorMember('show', s.show, call: (_) => s.show()),
    ];
  }
}

class _Anim extends _AnimMembers {
  _Anim(String key, {Duration fadeFor = const Duration(milliseconds: 120)})
    : fade = AnimationController(duration: fadeFor),
      super(key: key);

  final AnimationController fade;
  final grow = AnimationController(duration: const Duration(seconds: 10));

  void show() => fade.forward();
}

var _keys = 0;

/// A fresh state (ids are per key) and its id prefix.
(_Anim, String) _state({Duration? fadeFor}) {
  final s = fadeFor == null
      ? _Anim('k${_keys++}')
      : _Anim('k${_keys++}', fadeFor: fadeFor);
  return (s, s.idPrefix);
}

/// What the server writes for a transition of `opacity` from 0 to 1.
String _track(String id, {String prop = 'opacity', Object? v, String? a}) =>
    jsonEncode({
      'c': id,
      'k': [
        {'offset': 0, prop: prop == 'opacity' ? '0' : '1'},
        {'offset': 1, prop: prop == 'opacity' ? '1' : '2'},
      ],
      'v': ?v,
      'a': ?a,
    });

web.HTMLElement mount(String html) {
  final root = web.document.createElement('div') as web.HTMLElement;
  root.innerHTML = html.toJS;
  web.document.body!.append(root);
  // A lambda: tear-offs of interop members are not allowed.
  // ignore: unnecessary_lambdas
  addTearDown(() => root.remove());
  return root;
}

web.HTMLElement box(String tracks, {String style = 'opacity:0'}) {
  final root = mount(
    '<div id="b" style="width:10px;height:10px;$style" '
    "data-ta='[$tracks]'></div>",
  );
  return root.querySelector('#b')! as web.HTMLElement;
}

double opacity(web.Element el) =>
    double.parse(web.window.getComputedStyle(el).opacity);

double scale(web.Element el) {
  final s = web.window.getComputedStyle(el).getPropertyValue('scale');
  return s == 'none' ? 1 : double.parse(s);
}

Future<void> frames([int ms = 0]) =>
    Future<void>.delayed(Duration(milliseconds: ms + 50));

/// Starts the engine on [root] with only the animations feature.
void start(web.Element root, List<ThorState> states) {
  final detach = startThor(
    states,
    root: root,
    features: const [AnimationsFeature()],
  );
  addTearDown(detach);
}

void main() {
  test('the first frame stays until a method plays it; then it ends and '
      'reports its status', () async {
    final (s, id) = _state();
    final el = box(_track('$id.fade'));
    final statuses = <AnimationStatus>[];
    s.fade.addStatusListener(statuses.add);
    start(el.parentElement!, [s]);
    await frames();
    expect(opacity(el), 0);
    expect(s.fade.status, AnimationStatus.dismissed);
    s.show();
    expect(s.fade.isAnimating, isTrue);
    await frames(200);
    expect(opacity(el), 1);
    expect(s.fade.status, AnimationStatus.completed);
    expect(s.fade.value, 1);
    expect(statuses, [AnimationStatus.forward, AnimationStatus.completed]);
  });

  test('stop mid-way freezes the element where the controller is', () async {
    final (s, id) = _state(fadeFor: const Duration(seconds: 2));
    final el = box(_track('$id.fade'));
    start(el.parentElement!, [s]);
    s.fade.forward();
    await frames(300);
    s.fade.stop();
    final v = s.fade.value;
    expect(v, inExclusiveRange(0.05, 0.6));
    await frames(200);
    expect(s.fade.value, v, reason: 'stopped');
    expect(opacity(el), closeTo(v, 0.02));
    expect(s.fade.status, AnimationStatus.forward);
    // Reverse from there goes back to the start.
    s.fade.reverse(from: v);
    await frames((v * 2000).round() + 150);
    expect(s.fade.status, AnimationStatus.dismissed);
    expect(opacity(el), 0);
  });

  test('repeat(reverse: true) loops alternating until stopped', () async {
    final (s, id) = _state();
    final el = box(_track('$id.fade'));
    start(el.parentElement!, [s]);
    s.fade.repeat(reverse: true, period: const Duration(milliseconds: 80));
    await frames(300);
    expect(s.fade.isAnimating, isTrue, reason: 'no end');
    final timing = el.getAnimations().toDart.single.effect!.getComputedTiming();
    expect(timing.direction, 'alternate');
    expect(timing.iterations, double.infinity);
    s.fade.stop();
    final v = s.fade.value;
    await frames(100);
    expect(opacity(el), closeTo(v, 0.02));
  });

  test('repeat(min:, max:) loops over the stretch only', () async {
    final (s, id) = _state();
    final el = box(_track('$id.fade'));
    start(el.parentElement!, [s]);
    s.fade.repeat(
      min: 0.4,
      max: 0.7,
      reverse: true,
      period: const Duration(milliseconds: 60),
    );
    final seen = <double>[];
    for (var i = 0; i < 25; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 12));
      seen.add(opacity(el));
      expect(s.fade.value, closeTo(opacity(el), 0.15));
    }
    expect(seen.reduce((a, b) => a < b ? a : b), greaterThanOrEqualTo(0.39));
    expect(seen.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(0.71));
    expect(seen.toSet().length, greaterThan(3), reason: 'it moves');
    expect(s.fade.value, inInclusiveRange(0.39, 0.71));
    s.fade.stop();
    final v = s.fade.value;
    await frames(100);
    expect(opacity(el), closeTo(v, 0.02));
    expect(v, inInclusiveRange(0.39, 0.71));
  });

  test(
    'a loop over a stretch the server ran is taken over where it is',
    () async {
      final (s, id) = _state(fadeFor: const Duration(seconds: 4));
      // What the server saw: `..repeat(min: .2, max: .6)`, 2 s in (half way).
      s.fade.repeat(min: 0.2, max: 0.6);
      final style = web.document.createElement('style')
        ..textContent =
            '@keyframes t-win{from{opacity:.2}to{opacity:.6}}'
            '.t-run{animation:t-win 4s linear -2s infinite normal both}';
      web.document.head!.append(style);
      // ignore: unnecessary_lambdas
      addTearDown(() => style.remove());
      final track = jsonDecode(_track('$id.fade', a: 't-win')) as Map;
      track['w'] = [0.2, 0.6];
      final el = box(jsonEncode(track), style: '')..className = 't-run';
      await frames();
      start(el.parentElement!, [s]);
      expect(s.fade.value, closeTo(0.4, 0.06), reason: '0.2 + 0.5 * 0.4');
      expect(s.fade.isAnimating, isTrue);
      await frames(200);
      expect(s.fade.value, inInclusiveRange(0.2, 0.6));
    },
  );

  group('animateTo, animateBack and fling', () {
    test('animateTo stops half way: the element, the value, the status and '
        'the future agree', () async {
      final (s, id) = _state(fadeFor: const Duration(milliseconds: 200));
      final el = box(_track('$id.fade'));
      start(el.parentElement!, [s]);
      var finished = false;
      final f = s.fade.animateTo(0.5).then((_) => finished = true);
      expect(s.fade.status, AnimationStatus.forward);
      await frames(20);
      expect(finished, isFalse, reason: 'still on its way');
      await f;
      await frames();
      expect(s.fade.value, closeTo(0.5, 1e-6));
      expect(opacity(el), closeTo(0.5, 0.02));
      expect(s.fade.status, AnimationStatus.completed);
      expect(s.fade.isAnimating, isFalse);
      // It holds there.
      await frames(100);
      expect(opacity(el), closeTo(0.5, 0.02));
      expect(s.fade.value, closeTo(0.5, 1e-6));
    });

    test('animateTo below the value plays backwards and stops there', () async {
      final (s, id) = _state(fadeFor: const Duration(milliseconds: 200));
      final el = box(_track('$id.fade'), style: 'opacity:1');
      start(el.parentElement!, [s]);
      s.fade.value = 1;
      await s.fade.animateTo(0.25);
      await frames();
      expect(s.fade.value, closeTo(0.25, 1e-6));
      expect(opacity(el), closeTo(0.25, 0.02));
      expect(s.fade.status, AnimationStatus.completed);
    });

    test('animateBack stops at the target and ends dismissed', () async {
      final (s, id) = _state(fadeFor: const Duration(milliseconds: 200));
      final el = box(_track('$id.fade'));
      start(el.parentElement!, [s]);
      s.fade.value = 1;
      final statuses = <AnimationStatus>[];
      s.fade.addStatusListener(statuses.add);
      await s.fade.animateBack(0.5);
      await frames();
      expect(s.fade.value, closeTo(0.5, 1e-6));
      expect(opacity(el), closeTo(0.5, 0.02));
      expect(statuses, [AnimationStatus.reverse, AnimationStatus.dismissed]);
    });

    test('an explicit duration is this move: half the range in 100 ms', () {
      final (s, id) = _state(fadeFor: const Duration(seconds: 10));
      final el = box(_track('$id.fade'));
      start(el.parentElement!, [s]);
      final sw = Stopwatch()..start();
      return s.fade
          .animateTo(0.5, duration: const Duration(milliseconds: 100))
          .then((_) {
            expect(sw.elapsedMilliseconds, inInclusiveRange(60, 600));
            expect(s.fade.value, closeTo(0.5, 1e-6));
          });
    });

    test('fling runs to the bound', () async {
      final (s, id) = _state(fadeFor: const Duration(seconds: 10));
      final el = box(_track('$id.fade'));
      start(el.parentElement!, [s]);
      await s.fade.fling();
      await frames();
      expect(s.fade.value, 1);
      expect(opacity(el), 1);
      expect(s.fade.status, AnimationStatus.completed);
      await s.fade.fling(velocity: -1);
      await frames();
      expect(s.fade.value, 0);
      expect(s.fade.status, AnimationStatus.dismissed);
    });

    test('a second move interrupts the first: its future completes', () async {
      final (s, id) = _state(fadeFor: const Duration(seconds: 2));
      final el = box(_track('$id.fade'));
      start(el.parentElement!, [s]);
      var first = false;
      unawaited(s.fade.animateTo(1).then((_) => first = true));
      await frames(100);
      expect(first, isFalse);
      unawaited(
        s.fade.animateTo(0.2, duration: const Duration(milliseconds: 100)),
      );
      await frames(10);
      expect(first, isTrue);
      await frames(250);
      expect(s.fade.value, closeTo(0.2, 1e-6));
      expect(opacity(el), closeTo(0.2, 0.02));
    });

    test('forward after animateTo continues from where it stopped', () async {
      final (s, id) = _state(fadeFor: const Duration(milliseconds: 100));
      final el = box(_track('$id.fade'));
      start(el.parentElement!, [s]);
      await s.fade.animateTo(0.5);
      s.fade.forward();
      await frames(250);
      expect(s.fade.value, 1);
      expect(opacity(el), 1);
    });
  });

  test('two controllers on one element move their own property', () async {
    final (s, id) = _state();
    final el = box(
      '${_track('$id.fade')},${_track('$id.grow', prop: 'scale')}',
      style: 'opacity:0;scale:1',
    );
    start(el.parentElement!, [s]);
    s.grow.value = 0.5;
    await frames();
    expect(scale(el), closeTo(1.5, 0.01));
    expect(opacity(el), 0, reason: 'the fade did not move');
    s.fade.value = 1;
    await frames();
    expect(opacity(el), 1);
    expect(scale(el), closeTo(1.5, 0.01));
  });

  test('one controller drives every element that uses it', () async {
    final (s, id) = _state();
    final root = mount(
      "<div id='x' style='opacity:0' data-ta='[${_track('$id.fade')}]'></div>"
      "<div id='y' style='opacity:0' data-ta='[${_track('$id.fade')}]'></div>",
    );
    start(root, [s]);
    s.show();
    await frames(200);
    for (final sel in ['#x', '#y']) {
      expect(opacity(root.querySelector(sel)!), 1, reason: sel);
    }
  });

  test('hydration mismatch: the value the server rendered wins', () async {
    final (s, id) = _state();
    expect(s.fade.value, 0, reason: "the code's initial value");
    final el = box(_track('$id.fade', v: 0.5), style: 'opacity:0.5');
    start(el.parentElement!, [s]);
    await frames();
    expect(s.fade.value, 0.5);
    expect(opacity(el), closeTo(0.5, 0.01));
  });

  test('a CSS animation that ran before the engine is taken over', () async {
    final (s, id) = _state(fadeFor: const Duration(seconds: 4));
    s.fade.forward(); // what the state's code did (as the server saw it)
    final style = web.document.createElement('style')
      ..textContent =
          '@keyframes t-css{from{opacity:0}to{opacity:1}}'
          '.t-run{animation:t-css 4s linear -1s 1 normal both}';
    web.document.head!.append(style);
    // ignore: unnecessary_lambdas
    addTearDown(() => style.remove());
    final el = box(_track('$id.fade', a: 't-css'), style: '')
      ..className = 't-run';
    await frames();
    start(el.parentElement!, [s]);
    final kinds = [
      for (final a in el.getAnimations().toDart) a.isA<web.CSSAnimation>(),
    ];
    expect(kinds, [false], reason: 'the CSS animation was cancelled');
    expect(s.fade.value, greaterThan(0.2), reason: 'continues from there');
    expect(s.fade.isAnimating, isTrue);
  });

  test('reduced motion: nothing moves, it jumps to the end', () async {
    final window = web.window as JSObject;
    final original = window['matchMedia'];
    window['matchMedia'] =
        ((JSString q) =>
                JSObject()
                  ..['matches'] = q.toDart.contains('reduced-motion').toJS)
            .toJS;
    addTearDown(() => window['matchMedia'] = original);
    final (s, id) = _state(fadeFor: const Duration(seconds: 5));
    final el = box(_track('$id.fade'));
    start(el.parentElement!, [s]);
    final statuses = <AnimationStatus>[];
    s.fade.addStatusListener(statuses.add);
    s.show();
    expect(s.fade.isAnimating, isFalse);
    await frames();
    expect(opacity(el), 1);
    expect(statuses, [AnimationStatus.completed]);
  });

  test('a controller no element uses still keeps time', () async {
    final (s, _) = _state();
    final statuses = <AnimationStatus>[];
    s.fade.addStatusListener(statuses.add);
    start(mount('<div></div>'), [s]);
    s.fade.forward();
    await frames(200);
    expect(statuses, [AnimationStatus.forward, AnimationStatus.completed]);
  });

  test('a track of an unknown controller is ignored', () async {
    final (s, _) = _state();
    final el = box(_track('Nobody.fade'));
    start(el.parentElement!, [s]);
    await frames();
    expect(opacity(el), 0);
    expect(el.getAnimations().toDart, isEmpty);
  });
}
