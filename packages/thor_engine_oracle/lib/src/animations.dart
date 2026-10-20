/// Explicit animations in the page: plays the keyframes the server
/// precompiled for thor_ui's `*Transition` widgets with the Web Animations
/// API, driven by the `AnimationController`s of the page's `ThorState`s.
///
/// Every element animation runs on one fixed timeline ([_span] ms = the
/// controller's whole range); the controller's durations become playback
/// rates. A target-less animation per controller is its clock: it reports
/// the progress and the end, even when no element uses the controller.
/// Nothing here writes a style: the keyframes come from the server.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:thor_engine/src/animation.dart';
import 'package:thor_engine/src/bindings.dart';
import 'package:thor_engine/src/protocol.dart';
import 'package:thor_engine/src/thor_state.dart';
import 'package:thor_engine_oracle/client.dart' show EngineFeature;
import 'package:thor_engine_oracle/src/dom_scan.dart';
import 'package:web/web.dart' as web;

/// `*Transition` widgets driven by an `AnimationController` of a
/// `ThorState`.
final class AnimationsFeature extends EngineFeature {
  /// The feature.
  const AnimationsFeature();

  @override
  void collect(
    web.Element scope,
    ThorMember Function(String id) member,
    List<Binding> bindings,
    Set<String> seen, {
    bool late = false,
  }) {
    // Every controller of the page's states gets a driver, even one no
    // element uses: its clock still reports the end. A part that arrives
    // later adds its elements to the drivers the page has (a new driver
    // would replace the page's).
    final drivers = <String, _Driver>{};
    final fresh = <_Driver>[];
    for (final s in ThorState.all) {
      for (final m in s.members) {
        if (m.function != null) continue;
        final c = m.call?.call(null);
        if (c is AnimationController) {
          var d = late ? _drivers[c] : null;
          if (d == null) {
            d = _drivers[c] = _Driver(c);
            fresh.add(d);
          }
          drivers['${s.idPrefix}.${m.name}'] = d;
        }
      }
    }
    final marked = withRoot(scope, '[$animationAttr]');
    final json = globalContext['JSON']! as JSObject;
    for (final el in marked) {
      final tracks = json.callMethod<JSArray<JSObject>>(
        'parse'.toJS,
        el.getAttribute(animationAttr)!.toJS,
      );
      for (final track in tracks.toDart) {
        drivers[(track['c']! as JSString).toDart]?.add(el, track);
      }
    }
    for (final d in fresh) {
      d.start();
    }
  }
}

/// The driver of each controller of the page.
final _drivers = Expando<_Driver>('thor.driver');

/// The fixed timeline of every element animation, in ms.
const _span = 1000.0;

class _Driver implements AnimationDriver {
  _Driver(this.controller)
    : lead = web.Animation(
        web.KeyframeEffect(
          null,
          null,
          web.KeyframeAnimationOptions(duration: _span.toJS, fill: 'both'),
        ),
      ) {
    lead.pause();
    _all.add((lead, null, null));
  }

  final AnimationController controller;

  /// The clock: no target, same timing as the element animations.
  final web.Animation lead;

  /// Every animation with its keyframes forward and in reverse (only with
  /// a `reverseCurve`).
  final _all = <(web.Animation, JSObject?, JSObject?)>[];

  /// The value the page starts from: the server's value, or the progress
  /// of the CSS animation that ran until now.
  double? _from;

  void add(web.Element el, JSObject track) {
    final forward = track['k'] as JSObject?;
    final reversed = track['r'] as JSObject?;
    if (_from == null) {
      final css = track['a'];
      if (css != null) {
        final name = (css as JSString).toDart;
        for (final a in el.getAnimations().toDart) {
          if (!a.isA<web.CSSAnimation>() ||
              (a as web.CSSAnimation).animationName != name) {
            continue;
          }
          var p = a.effect?.getComputedTiming().progress;
          // Reduced motion: the CSS animation (1 ms) rests at its end, but
          // it may not have run yet when the page hydrates (progress 0).
          if (reducedMotion) {
            final direction = a.effect?.getTiming().direction;
            p = direction == 'reverse' || direction == 'alternate-reverse'
                ? 0.0
                : 1.0;
          }
          a.cancel();
          if (p != null) {
            // A loop over a stretch of the range (`repeat(min:, max:)`) has
            // the pass progress, not the value: [min, max] says where.
            final window = track['w'];
            if (window != null) {
              final w = (window as JSArray<JSNumber>).toDart;
              p =
                  w[0].toDartDouble +
                  p * (w[1].toDartDouble - w[0].toDartDouble);
            }
            _from =
                controller.lowerBound +
                p * (controller.upperBound - controller.lowerBound);
          }
        }
      } else if (track['v'] case final JSNumber v) {
        _from = v.toDartDouble;
      }
    }
    final a = el.animate(
      forward,
      web.KeyframeAnimationOptions(duration: _span.toJS, fill: 'both'),
    );
    a.pause();
    _all.add((a, forward, reversed));
    if (started) _follow(a, forward, reversed);
  }

  /// Whether the controller has this driver: an element that comes after
  /// goes where the others are.
  bool started = false;

  /// Puts [a], an animation that arrived late, where the clock is: its
  /// timing, rate and time, playing if the clock plays.
  void _follow(web.Animation a, JSObject? forward, JSObject? reversed) {
    final effect = a.effect! as web.KeyframeEffect;
    final timing = lead.effect!.getTiming();
    effect.updateTiming(
      web.OptionalEffectTiming(
        iterations: timing.iterations,
        direction: timing.direction,
        easing: timing.easing,
      ),
    );
    final backwards = lead.playbackRate < 0 || timing.direction == 'reverse';
    if (reversed != null) effect.setKeyframes(backwards ? reversed : forward);
    a
      ..playbackRate = lead.playbackRate
      ..currentTime = lead.currentTime;
    if (lead.playState == 'running') a.play();
  }

  void start() {
    started = true;
    lead.onfinish = ((web.Event _) {
      // A finish queued before another play() started is stale.
      if (lead.playState == 'finished') controller.driverFinished();
    }).toJS;
    controller.attachDriver(this, from: _from);
  }

  @override
  double get progress =>
      lead.effect?.getComputedTiming().progress ??
      ((lead.currentTime as JSNumber?)?.toDartDouble ?? 0) / _span;

  @override
  bool get reducedMotion =>
      web.window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  @override
  void play(AnimationPlayback p) {
    // A move that stops short of the bound (`animateTo`) can't run on a
    // negative rate, which only ends at 0: backwards it plays the reversed
    // direction forwards in time, for the part of a pass that it covers.
    final partial = p.reverse && p.to != null;
    final speed = _span / (p.sweep.inMicroseconds / 1000);
    // The move's curve, as an easing of the whole range that is the
    // identity outside the stretch it plays.
    final easing =
        p.windowEasing ??
        (p.easing == null
            ? 'linear'
            : _compose(p.easing!, p.from, p.to ?? (p.reverse ? 0 : 1)));
    for (final (a, forward, reversed) in _all) {
      final effect = a.effect! as web.KeyframeEffect;
      effect.updateTiming(
        web.OptionalEffectTiming(
          iterations: p.count,
          direction: partial
              ? 'reverse'
              : p.alternate
              ? 'alternate'
              : 'normal',
          easing: easing,
        ),
      );
      if (reversed != null) effect.setKeyframes(p.reverse ? reversed : forward);
      a
        ..playbackRate = p.reverse && !partial ? -speed : speed
        ..currentTime = ((partial ? 1 - p.at : p.passAt) * _span).toJS
        ..play();
    }
  }

  @override
  void seek(double t) {
    // The keyframes stay: stopped mid-reverse, a `reverseCurve` still
    // applies (like Flutter's CurvedAnimation until the status changes).
    for (final (a, _, _) in _all) {
      a.pause();
      a.effect!.updateTiming(
        web.OptionalEffectTiming(
          iterations: 1,
          direction: 'normal',
          easing: 'linear',
        ),
      );
      a
        ..playbackRate = 1
        ..currentTime = (t * _span).toJS;
    }
  }
}

/// The easing of a move from [from] to [to] (fractions of the range) with
/// the CSS [curve] over that stretch: a `linear()` of the whole range, the
/// identity outside the stretch, that inside it goes from [from] to [to]
/// along the curve (clamped to the range, like the controller's value). The
/// browser evaluates the curve: an animation with that easing, paused at each
/// sample. Where it can't (no `linear()`), the move is linear.
String _compose(String curve, double from, double to) {
  const points = 32;
  try {
    final probe = web.Animation(
      web.KeyframeEffect(
        null,
        null,
        web.KeyframeAnimationOptions(
          duration: 1000.toJS,
          easing: curve,
          fill: 'both',
        ),
      ),
    )..pause();
    final inside = <(double, double)>[];
    for (var i = 0; i <= points; i++) {
      final s = i / points;
      probe.currentTime = (s * 1000).toJS;
      final c = probe.effect!.getComputedTiming().progress ?? s;
      inside.add((
        from + (to - from) * s,
        (from + (to - from) * c).clamp(0.0, 1.0),
      ));
    }
    probe.cancel();
    if (to < from) {
      inside.setAll(0, inside.reversed.toList());
    }
    final low = from < to ? from : to;
    final high = from < to ? to : from;
    // (position, value) pairs.
    final stops = <(double, double)>[
      if (low > 0) (0, 0),
      ...inside,
      if (high < 1) (1, 1),
    ];
    String n(double v, int digits) {
      final s = v.toStringAsFixed(digits);
      return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
    }

    final css =
        'linear(${[for (final (q, v) in stops) '${n(v, 4)} ${n(q * 100, 2)}%'].join(', ')})';
    // A browser without `linear()` throws here: the move is linear.
    web.KeyframeEffect(null, null, web.KeyframeAnimationOptions(easing: css));
    return css;
  } on Object {
    return 'linear';
  }
}
