@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// The member list thor generates for [CardState], by hand (tests don't run the build).
abstract class _CardStateMembers extends ThorState {
  _CardStateMembers({super.key});

  @override
  String get $type => 'CardState';

  @override
  List<ThorMember> get $members {
    final s = this as CardState;
    return [
      ThorMember.controller('reveal', s.reveal),
      ThorMember.controller('pop', s.pop),
      ThorMember('show', s.show, call: (_) => s.show()),
    ];
  }
}

class CardState extends _CardStateMembers {
  CardState({super.key});

  final reveal = AnimationController(
    duration: const Duration(milliseconds: 300),
  );
  final pop = AnimationController(duration: const Duration(milliseconds: 200));

  void show() => reveal.forward();
}

final card = CardState(key: 'transitions');

const _box = SizedBox(width: 10, height: 10);

/// The tracks of the element's `data-ta`, decoded.
List<Map<String, Object?>> tracks(String html) {
  final m = RegExp(r'data-ta="([^"]*)"').firstMatch(html);
  if (m == null) return const [];
  final json = m[1]!.replaceAll('&quot;', '"').replaceAll('&amp;', '&');
  return [
    for (final t in jsonDecode(json) as List)
      (t as Map).cast<String, Object?>(),
  ];
}

List<Map<String, Object?>> keyframes(
  Map<String, Object?> track, [
  String key = 'k',
]) => [for (final k in track[key]! as List) (k as Map).cast<String, Object?>()];

/// The page, with the stylesheet's `prop: value; ` written compactly.
Future<String> page(Widget body) async => (await renderDocument(
  ThorApp(child: body),
)).replaceAll(': ', ':').replaceAll('; ', ';');

void main() {
  initializeThorTests();

  setUp(() {
    // The state's controllers are page-wide: every test starts at rest.
    card.reveal.value = 0;
    card.pop.value = 0;
  });

  group('the first frame is plain CSS (the page works without the engine)', () {
    test(
      'a stopped animation is a static style, no track, no keyframes',
      () async {
        final html = await page(
          const FadeTransition(
            opacity: AlwaysStoppedAnimation(0.5),
            child: _box,
          ),
        );
        expect(html, contains('opacity:0.5'));
        expect(html, isNot(contains('data-ta')));
        expect(html, isNot(contains('@keyframes')));
        expect(html, isNot(contains('engine.dart.js')));
      },
    );

    test(
      'an idle controller outside a state renders its value, no JS',
      () async {
        final html = await page(
          FadeTransition(
            opacity: AnimationController(
              value: 0.25,
              duration: const Duration(seconds: 1),
            ),
            child: _box,
          ),
        );
        expect(html, contains('opacity:0.25'));
        expect(html, isNot(contains('data-ta')));
        expect(html, isNot(contains('animation:')));
        expect(html, isNot(contains('engine.dart.js')));
      },
    );

    test('a state controller: initial frame in the class, keyframes in '
        'data-ta, the engine ships', () async {
      final html = await page(
        FadeTransition(opacity: card.reveal, child: _box),
      );
      expect(html, contains('opacity:0'));
      final t = tracks(html).single;
      expect(t['c'], 'CardState#transitions.reveal');
      expect(keyframes(t), [
        {'offset': 0.0, 'opacity': '0'},
        {'offset': 1.0, 'opacity': '1'},
      ]);
      expect(t.containsKey('v'), isFalse, reason: 'at the lower bound');
      expect(t.containsKey('a'), isFalse, reason: 'not playing');
      expect(html, contains('engine.dart.js'));
      // One element: the transition fused into the box.
      expect(RegExp('<div').allMatches(bodyOfPage(html)), hasLength(1));
    });

    test('the server value travels when it is not the lower bound', () async {
      card.reveal.value = 0.4;
      final html = await page(
        FadeTransition(opacity: card.reveal, child: _box),
      );
      expect(html, contains('opacity:0.4'));
      expect(tracks(html).single['v'], 0.4);
    });
  });

  group('CSS animations: entrances and loops with no JavaScript', () {
    test('forward() at render is a CSS animation from its value', () async {
      final html = await page(
        FadeTransition(
          opacity: AnimationController(
            duration: const Duration(milliseconds: 400),
          )..forward(from: 0.25),
          child: _box,
        ),
      );
      final name = RegExp(r'@keyframes (ta\w+)').firstMatch(html)![1]!;
      expect(html, contains('@keyframes $name{0%{opacity:0}100%{opacity:1}}'));
      expect(
        html,
        contains('animation:$name 400ms linear -100ms 1 normal both'),
      );
      expect(
        html,
        contains(
          'animation-duration:1ms;animation-delay:-1ms;animation-iteration-count:1',
        ),
        reason: 'reduced motion: it shows the end',
      );
      expect(html, isNot(contains('engine.dart.js')));
      expect(html, isNot(contains('data-ta')));
    });

    test('repeat(reverse: true) loops forever, alternating', () async {
      final html = await page(
        ScaleTransition(
          scale: Tween(begin: 0.9, end: 1.1).animate(
            AnimationController(duration: const Duration(seconds: 1))
              ..repeat(reverse: true),
          ),
          child: _box,
        ),
      );
      expect(html, contains('{0%{scale:0.9}100%{scale:1.1}}'));
      expect(html, contains('1000ms linear 0s infinite alternate both'));
    });

    group('repeat(min:, max:) loops over a stretch of the range', () {
      test('the keyframes are the stretch, not the whole range', () async {
        final html = await page(
          FadeTransition(
            opacity: AnimationController(duration: const Duration(seconds: 1))
              ..repeat(min: 0.25, max: 0.75, reverse: true),
            child: _box,
          ),
        );
        expect(html, contains('{0%{opacity:0.25}100%{opacity:0.75}}'));
        expect(html, contains('1000ms linear 0s infinite alternate both'));
      });

      test('it starts where the value is in the stretch', () async {
        final html = await page(
          ScaleTransition(
            scale: Tween(begin: 1.0, end: 2.0).animate(
              AnimationController(
                value: 0.5,
                duration: const Duration(seconds: 1),
              )..repeat(min: 0.25, max: 0.75),
            ),
            child: _box,
          ),
        );
        expect(html, contains('{0%{scale:1.25}100%{scale:1.75}}'));
        expect(html, contains('1000ms linear -500ms infinite normal both'));
      });

      test('a curve is sampled over the stretch (exact at its ends)', () async {
        final c = AnimationController(duration: const Duration(seconds: 1))
          ..repeat(min: 0.25, max: 0.75);
        final html = await page(
          FadeTransition(
            opacity: CurvedAnimation(parent: c, curve: Curves.easeIn),
            child: _box,
          ),
        );
        final body = RegExp(
          r'@keyframes ta\w+\{(.*?)\}\}',
        ).firstMatch(html)![1]!;
        final stops = RegExp(
          r'(\d+(?:\.\d+)?)%\{opacity:([\d.]+)',
        ).allMatches('$body}').toList();
        expect(stops.length, greaterThan(3));
        expect(
          double.parse(stops.first[2]!),
          closeTo(Curves.easeIn.transform(0.25), 1e-3),
        );
        expect(
          double.parse(stops.last[2]!),
          closeTo(Curves.easeIn.transform(0.75), 1e-3),
        );
      });

      test('a loop of a state is the same CSS; the page gets the stretch '
          'to take it over', () async {
        final spin = CardState(key: 'windowed');
        spin.pop.repeat(min: 0.2, max: 0.6);
        addTearDown(spin.pop.stop);
        final html = await page(FadeTransition(opacity: spin.pop, child: _box));
        final t = tracks(html).single;
        expect(t['w'], [0.2, 0.6]);
        expect(
          keyframes(t).map((k) => k['opacity']),
          ['0', '1'],
          reason: 'the engine plays the whole range with an easing',
        );
        expect(html, contains('{0%{opacity:0.2}100%{opacity:0.6}}'));
      });

      test('a loop over the whole range has no stretch', () async {
        final spin = CardState(key: 'whole');
        spin.pop.repeat(min: 0, max: 1);
        addTearDown(spin.pop.stop);
        final html = await page(FadeTransition(opacity: spin.pop, child: _box));
        expect(tracks(html).single.containsKey('w'), isFalse);
      });

      test('reduced motion rests at the top of the stretch', () async {
        final html = await page(
          FadeTransition(
            opacity: AnimationController(duration: const Duration(seconds: 1))
              ..repeat(min: 0.25, max: 0.75, reverse: true),
            child: _box,
          ),
        );
        expect(html, contains('animation-duration:1ms'));
        expect(html, contains('{0%{opacity:0.25}100%{opacity:0.75}}'));
      });
    });

    test('reverse() at render runs the keyframes backwards', () async {
      final c = AnimationController(
        value: 1,
        duration: const Duration(milliseconds: 200),
        reverseDuration: const Duration(milliseconds: 100),
      )..reverse();
      final html = await page(RotationTransition(turns: c, child: _box));
      expect(html, contains('100ms linear 0s 1 reverse both'));
      expect(html, contains('rotate:1turn'), reason: 'first frame: the end');
    });

    test(
      'animateTo(0.5) at render stops half way: a fractional count',
      () async {
        final c = AnimationController(
          duration: const Duration(milliseconds: 400),
        )..animateTo(0.5).ignore();
        final html = await page(FadeTransition(opacity: c, child: _box));
        final name = RegExp(r'@keyframes (ta\w+)').firstMatch(html)![1]!;
        expect(
          html,
          contains('animation:$name 400ms linear 0s 0.5 normal both'),
        );
        expect(
          html,
          contains(
            'animation-duration:1ms;animation-delay:-1ms;'
            'animation-iteration-count:0.5',
          ),
          reason: 'reduced motion shows where it stops, not the end',
        );
      },
    );

    test(
      'animateBack(0.25) from 1 runs reversed for the part it covers',
      () async {
        final c = AnimationController(
          value: 1,
          duration: const Duration(milliseconds: 400),
        )..animateBack(0.25).ignore();
        final html = await page(FadeTransition(opacity: c, child: _box));
        expect(html, contains('400ms linear 0s 0.75 reverse both'));
      },
    );

    test('the curve of an animateTo at render is in the keyframes the server '
        'writes (the page continues the same move)', () async {
      final c = AnimationController(duration: const Duration(milliseconds: 400))
        ..animateTo(0.5, curve: Curves.easeOut).ignore();
      final html = await page(FadeTransition(opacity: c, child: _box));
      final body = RegExp(r'@keyframes ta\w+\{(.*?)\}\}').firstMatch(html)![1]!;
      final stops = RegExp(
        r'linear\(([^)]*)\)',
      ).firstMatch(body)![1]!.split(', ').map(double.parse).toList();
      // The pass is 0..1 and the move covers its first half: a quarter of
      // the pass is the value easeOut gives half way through the stretch.
      final u = stops[(stops.length - 1) ~/ 4];
      expect(u, closeTo(0.5 * Curves.easeOut.transform(0.5), 0.02));
      expect(stops.last, 1);
      expect(html, contains('400ms linear 0s 0.5 normal both'));
    });

    test(
      'the track tells the page the curve and the stretch of the move',
      () async {
        final eased = CardState(key: 'eased');
        eased.reveal.animateTo(0.5, curve: Curves.easeOut).ignore();
        addTearDown(eased.reveal.stop);
        final html = await page(
          FadeTransition(opacity: eased.reveal, child: _box),
        );
        expect(tracks(html).single['x'], [
          'cubic-bezier(0, 0, 0.58, 1)',
          0,
          0.5,
        ]);
        final plain = CardState(key: 'plain');
        plain.reveal.animateTo(0.5).ignore();
        addTearDown(plain.reveal.stop);
        expect(
          tracks(
            await page(FadeTransition(opacity: plain.reveal, child: _box)),
          ).single,
          isNot(contains('x')),
        );
      },
    );

    test('a move without a curve keeps plain keyframes', () async {
      final c = AnimationController(duration: const Duration(milliseconds: 400))
        ..animateTo(0.5).ignore();
      final html = await page(FadeTransition(opacity: c, child: _box));
      expect(html, contains('{0%{opacity:0}100%{opacity:1}}'));
    });

    test('a backwards move and a fling are eased too', () async {
      final back = AnimationController(
        value: 1,
        duration: const Duration(milliseconds: 400),
      )..animateBack(0.25, curve: Curves.easeIn).ignore();
      expect(
        await page(FadeTransition(opacity: back, child: _box)),
        contains('animation-timing-function:linear('),
      );
      final fling = AnimationController(
        duration: const Duration(milliseconds: 400),
      )..fling().ignore();
      expect(
        await page(FadeTransition(opacity: fling, child: _box)),
        contains('animation-timing-function:linear('),
      );
    });

    test('animateTo from the middle starts there', () async {
      final c = AnimationController(
        value: 0.25,
        duration: const Duration(milliseconds: 400),
      )..animateTo(0.75).ignore();
      final html = await page(FadeTransition(opacity: c, child: _box));
      expect(html, contains('400ms linear -100ms 0.75 normal both'));
    });

    test('without a ThorApp the keyframes ship next to the element', () async {
      final html = await renderHtml(
        FadeTransition(
          opacity: AnimationController(duration: const Duration(seconds: 1))
            ..forward(),
          child: _box,
        ),
      );
      expect(html, matches(RegExp(r'<style>@keyframes ta\w+\{')));
    });

    test('a state controller playing at render: CSS until the engine '
        'takes over', () async {
      final spin = CardState(key: 'spinning');
      spin.pop.repeat();
      addTearDown(spin.pop.stop);
      final html = await page(RotationTransition(turns: spin.pop, child: _box));
      final name = RegExp(r'@keyframes (ta\w+)').firstMatch(html)![1]!;
      expect(tracks(html).single['a'], name);
      expect(html, contains('animation:$name 200ms linear 0s infinite'));
    });
  });

  group('AnimationController.inView: on scroll, with no JavaScript', () {
    test('a CSS animation on the view timeline, shown whole by '
        'default', () async {
      final html = await page(
        FadeTransition(opacity: AnimationController.inView(), child: _box),
      );
      final name = RegExp(r'@keyframes (ta\w+)').firstMatch(html)![1]!;
      expect(html, contains('@keyframes $name{0%{opacity:0}100%{opacity:1}}'));
      // The element's own value is the end: a browser with no view
      // timelines (or no `auto` duration) never leaves it hidden.
      expect(
        html,
        contains(
          'opacity:1;animation:$name auto linear both;'
          'animation-timeline:view();animation-range:entry 0% entry 100%',
        ),
      );
      expect(
        html,
        contains('{animation-timeline:auto}'),
        reason: 'reduced motion: a 0s time animation, straight to the end',
      );
      expect(html, isNot(contains('engine.dart.js')));
      expect(html, isNot(contains('data-ta')));
    });

    test('its range, across phases', () async {
      final html = await page(
        FadeTransition(
          opacity: AnimationController.inView(
            range: const ViewRange.span(
              ViewPhase.entry,
              0.1,
              ViewPhase.cover,
              0.35,
            ),
          ),
          child: _box,
        ),
      );
      expect(html, contains('animation-range:entry 10% cover 35%'));
    });

    test('an Interval staggers one element after another', () async {
      final view = AnimationController.inView();
      final html = await page(
        Column(
          children: [
            for (var i = 0; i < 2; i++)
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: view,
                  curve: Interval(i * 0.3, 1),
                ),
                child: _box,
              ),
          ],
        ),
      );
      // Interval is sampled into linear(): the second waits (flat at 0)
      // for the first 30% of the range.
      final frames = RegExp(
        r'@keyframes ta\w+\{([^@]*)\}\}',
      ).allMatches(html).map((m) => m[1]!).toList();
      expect(frames, hasLength(2));
      expect(frames[0], contains('linear(0, 0.025,'));
      expect(
        frames[1],
        contains('linear(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,'),
      );
    });

    test('a fade and a slide: one timeline and range per animation, after '
        'the shorthand', () async {
      final view = AnimationController.inView();
      final html = await page(
        FadeTransition(
          opacity: view,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(view),
            child: _box,
          ),
        ),
      );
      expect(
        html,
        matches(
          RegExp(
            r'animation:ta\w+ auto linear both, ta\w+ auto linear both;'
            r'animation-timeline:view\(\), view\(\);'
            r'animation-range:entry 0% entry 100%, entry 0% entry 100%',
          ),
        ),
      );
      expect(html, contains('translate:0% 0%'), reason: 'at rest: the end');
    });

    test('with an entrance on the same element, each keeps its '
        'timeline', () async {
      final html = await page(
        FadeTransition(
          opacity: AnimationController(duration: const Duration(seconds: 1))
            ..forward(),
          child: ScaleTransition(
            scale: AnimationController.inView(),
            child: _box,
          ),
        ),
      );
      expect(
        html,
        contains(
          'animation-timeline:auto, view();'
          'animation-range:normal, entry 0% entry 100%',
        ),
      );
    });

    test('time does not move it', () {
      final view = AnimationController.inView();
      for (final play in [
        view.forward,
        view.reverse,
        view.repeat,
        view.toggle,
      ]) {
        expect(play, throwsStateError);
      }
      expect(view.playback, isNull);
      expect(view.viewRange, ViewRange.entry);
      expect(AnimationController().viewRange, isNull);
    });
  });

  group('AnimationController.onVisible: once, when seen, with no '
      'JavaScript', () {
    test('a time animation that waits for its scroll trigger', () async {
      final html = await page(
        FadeTransition(
          opacity: AnimationController.onVisible(
            duration: const Duration(milliseconds: 700),
          ),
          child: _box,
        ),
      );
      final name = RegExp(r'@keyframes (ta\w+)').firstMatch(html)![1]!;
      final trigger = RegExp(
        r'timeline-trigger:(--tv\w+) view\(\) entry 30% exit 100%',
      ).firstMatch(html)![1]!;
      expect(
        html,
        contains(
          'opacity:1;animation:$name 700ms linear 0s 1 normal both;'
          'timeline-trigger:$trigger view() entry 30% exit 100%;'
          'animation-trigger:$trigger play-once',
        ),
        reason:
            'its own value is the end: it waits at the start only '
            'while the animation holds it',
      );
      expect(html, isNot(contains('engine.dart.js')));
      expect(html, isNot(contains('data-ta')));
    });

    test(
      'reduced motion and print drop the animation: it shows whole',
      () async {
        final html = await page(
          FadeTransition(
            opacity: AnimationController.onVisible(
              duration: const Duration(milliseconds: 700),
            ),
            child: _box,
          ),
        );
        expect(
          html,
          matches(
            RegExp(
              r'@media \(prefers-reduced-motion:reduce\)'
              r'\{\.t\w+\{animation:none\}',
            ),
          ),
        );
        expect(
          html,
          matches(RegExp(r'@media print\{\.t\w+\{animation:none\}')),
        );
      },
    );

    test('its range, and a fade with a rise: one trigger entry per '
        'animation', () async {
      final visible = AnimationController.onVisible(
        duration: const Duration(milliseconds: 500),
        range: const ViewRange.span(ViewPhase.entry, 0.5, ViewPhase.exit, 1),
      );
      final html = await page(
        FadeTransition(
          opacity: visible,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(visible),
            child: _box,
          ),
        ),
      );
      final t = RegExp(
        r'timeline-trigger:(--tv\w+) view\(\) entry 50% exit 100%[;}]',
      ).firstMatch(html)![1]!;
      expect(html, contains('animation-trigger:$t play-once, $t play-once'));
      expect(
        RegExp('timeline-trigger:').allMatches(html),
        hasLength(1),
        reason: 'the trigger is declared once',
      );
    });

    test('next to a load entrance, only its own animation waits', () async {
      final html = await page(
        FadeTransition(
          opacity: AnimationController(duration: const Duration(seconds: 1))
            ..forward(),
          child: ScaleTransition(
            scale: AnimationController.onVisible(
              duration: const Duration(seconds: 1),
            ),
            child: _box,
          ),
        ),
      );
      expect(
        html,
        matches(RegExp(r'animation-trigger:none, --tv\w+ play-once')),
      );
    });

    test('it has started, like forward()', () {
      final visible = AnimationController.onVisible(
        duration: const Duration(milliseconds: 300),
      );
      expect(visible.isAnimating, isTrue);
      expect(visible.visibleRange, isNotNull);
      expect(visible.viewRange, isNull);
      expect(AnimationController().visibleRange, isNull);
    });
  });

  group('CountTransition', () {
    CountTransition count96(AnimationController c) => CountTransition(
      count: IntTween(begin: 0, end: 96).animate(c),
      suffix: ' %',
    );

    test('the page holds the final figure as text', () async {
      final html = await page(
        count96(
          AnimationController.onVisible(
            duration: const Duration(milliseconds: 700),
          ),
        ),
      );
      expect(html, matches(RegExp(r'<span class="\w+">96 %</span>')));
      expect(html, contains('aria-hidden="true"'));
      expect(html, contains('{content:"" counter(tc) " %"}'));
    });

    test('the steps hold one number each, up to the end', () async {
      final html = await page(
        count96(
          AnimationController(duration: const Duration(milliseconds: 700))
            ..forward(),
        ),
      );
      final steps = RegExp(
        r'counter-reset:tc (\d+)',
      ).allMatches(html).map((m) => int.parse(m[1]!)).toList();
      expect(steps.first, 96, reason: 'the element at rest');
      final frames = steps.skip(1).toList();
      expect(frames.first, 0);
      expect(frames.last, 96);
      expect(frames, orderedEquals([...frames]..sort()));
      expect(frames.length, lessThanOrEqualTo(CountTransition.maxSteps + 1));
      expect(html, contains('animation-timing-function:step-end'));
    });

    test(
      'the final text hides while it counts; the steps hide after',
      () async {
        final html = await page(
          count96(
            AnimationController(duration: const Duration(milliseconds: 700))
              ..forward(),
          ),
        );
        expect(
          html,
          contains(
            '{0%{visibility:hidden;animation-timing-function:step-end}'
            '100%{visibility:visible}}',
          ),
        );
        expect(
          html,
          contains(
            '{0%{visibility:visible;animation-timing-function:step-end}'
            '100%{visibility:hidden}}',
          ),
        );
      },
    );

    test('a controller at rest: just the figure, formatted', () async {
      final html = await page(
        CountTransition(
          count: IntTween(
            begin: 0,
            end: 1250,
          ).animate(AnimationController(value: 1)),
          prefix: r'$',
          format: (n) => n == 1250 ? '1,250' : '$n',
        ),
      );
      expect(html, contains(r'>$1,250</span>'));
      expect(html, isNot(contains('counter(tc)')));
    });

    test('IntTween rounds like Flutter', () {
      final t = IntTween(begin: 0, end: 10);
      expect(t.transform(0.24), 2);
      expect(t.transform(0.25), 3);
      expect(t.transform(1), 10);
    });
  });

  group('curves and tweens compile exactly', () {
    test('CurvedAnimation: two keyframes and the cubic as easing', () async {
      final html = await page(
        FadeTransition(
          opacity: CurvedAnimation(parent: card.reveal, curve: Curves.easeOut),
          child: _box,
        ),
      );
      final k = keyframes(tracks(html).single);
      expect(k, hasLength(2));
      expect(k.first['easing'], Curves.easeOut.css);
    });

    test('a reverseCurve adds reverse keyframes', () async {
      final html = await page(
        FadeTransition(
          opacity: CurvedAnimation(
            parent: card.reveal,
            curve: Curves.easeIn,
            reverseCurve: Curves.easeOut,
          ),
          child: _box,
        ),
      );
      final t = tracks(html).single;
      expect(keyframes(t).first['easing'], Curves.easeIn.css);
      expect(keyframes(t, 'r').first['easing'], Curves.easeOut.css);
    });

    test('Tween over a curve keeps the curve and maps the values', () async {
      final html = await page(
        SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
            CurvedAnimation(parent: card.reveal, curve: Curves.fastOutSlowIn),
          ),
          textDirection: TextDirection.rtl,
          child: _box,
        ),
      );
      final k = keyframes(tracks(html).single);
      expect(k.first['translate'], '0% 100%');
      expect(k.last['translate'], '0% 0%');
      expect(k.first['easing'], Curves.fastOutSlowIn.css);
    });

    test('TweenSequence: one stretch per item, by weight', () async {
      final seq = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1, end: 1.2), weight: 1),
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 1.2,
            end: 1,
          ).chain(CurveTween(curve: Curves.easeIn)),
          weight: 3,
        ),
      ]);
      final html = await page(
        ScaleTransition(scale: seq.animate(card.reveal), child: _box),
      );
      final k = keyframes(tracks(html).single);
      expect([for (final f in k) f['offset']], [0.0, 0.25, 1.0]);
      expect([for (final f in k) f['scale']], ['1', '1.2', '1']);
      expect(k[1]['easing'], Curves.easeIn.css);
    });

    test('what has no exact form is sampled', () async {
      // A curve of a curve: not one easing any more.
      final twice = CurvedAnimation(
        parent: CurvedAnimation(parent: card.reveal, curve: Curves.easeIn),
        curve: Curves.easeOut,
      );
      final html = await page(FadeTransition(opacity: twice, child: _box));
      final k = keyframes(tracks(html).single);
      expect(k, hasLength(41));
      // The sampled middle is what Dart computes.
      final mid = Curves.easeOut.transform(Curves.easeIn.transform(0.5));
      expect(double.parse(k[20]['opacity']! as String), closeTo(mid, 1e-3));
    });
  });

  group('composition', () {
    test('two controllers on one element: one class, two tracks', () async {
      final html = await page(
        FadeTransition(
          opacity: card.reveal,
          child: ScaleTransition(scale: card.pop, child: _box),
        ),
      );
      final body = bodyOfPage(html);
      expect(RegExp('<div').allMatches(body), hasLength(1));
      expect(
        [for (final t in tracks(html)) t['c']],
        ['CardState#transitions.reveal', 'CardState#transitions.pop'],
      );
    });

    test('two playing controllers on one element run both CSS '
        'animations', () async {
      final html = await page(
        FadeTransition(
          opacity: AnimationController(duration: const Duration(seconds: 1))
            ..forward(),
          child: ScaleTransition(
            scale: AnimationController(duration: const Duration(seconds: 2))
              ..repeat(),
            child: _box,
          ),
        ),
      );
      expect(
        html,
        matches(
          RegExp(
            r'animation:ta\w+ 1000ms linear 0s 1 normal both, '
            r'ta\w+ 2000ms linear 0s infinite normal both',
          ),
        ),
      );
    });

    test('one controller drives several widgets', () async {
      final html = await page(
        Column(
          children: [
            FadeTransition(opacity: card.reveal, child: _box),
            ScaleTransition(scale: card.reveal, child: _box),
          ],
        ),
      );
      final ids = RegExp(
        'CardState#transitions.reveal',
      ).allMatches(html.replaceAll('&quot;', '"'));
      expect(ids, hasLength(2));
    });
  });

  group('the Dart values match Flutter', () {
    test('CurvedAnimation uses the reverse curve while reversing', () {
      final c = AnimationController(
        value: 0.5,
        duration: const Duration(seconds: 1),
      );
      final a = CurvedAnimation(
        parent: c,
        curve: Curves.easeIn,
        reverseCurve: Curves.easeOut,
      );
      c.forward();
      expect(a.value, Curves.easeIn.transform(0.5));
      c.reverse();
      expect(a.value, Curves.easeOut.transform(0.5));
      expect(ReverseAnimation(c).value, 0.5);
      expect(ReverseAnimation(c).status, AnimationStatus.forward);
    });

    test('tweens interpolate, and fail loudly for unknown types', () {
      expect(Tween<double>(begin: 0, end: 10).transform(0.25), 2.5);
      final o = Tween(
        begin: Offset.zero,
        end: const Offset(2, 4),
      ).transform(0.5);
      expect((o.dx, o.dy), (1.0, 2.0));
      expect(
        ColorTween(
          begin: const Color(0xFF000000),
          end: const Color(0xFFFFFFFF),
        ).transform(0.5),
        const Color(0xFF808080),
      );
      expect(
        ColorTween(
          begin: const Color.variable(CssVariable('--a')),
          end: const Color.variable(CssVariable('--b')),
        ).transform(0.25)!.css,
        'color-mix(in srgb, var(--a) 75%, var(--b))',
      );
      expect(
        () => Tween<String>(begin: 'a', end: 'b').transform(0.5),
        throwsUnsupportedError,
      );
      expect(() => TweenSequence<double>([]), throwsArgumentError);
      expect(
        () => TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 0),
        ]),
        anyOf(throwsArgumentError, throwsA(isA<AssertionError>())),
      );
      expect(
        Tween<double>(
          begin: 0,
          end: 2,
        ).chain(CurveTween(curve: Curves.easeIn)).transform(0.5),
        2 * Curves.easeIn.transform(0.5),
      );
    });

    test('drive is animate', () {
      final c = AnimationController(value: 0.5);
      expect(c.drive(Tween<double>(begin: 10, end: 20)).value, 15);
    });
  });

  group('DecoratedBoxTransition', () {
    const from = BoxDecoration(
      color: Color(0xFFFF0000),
      borderRadius: BorderRadius.all(Radius.circular(4)),
    );
    const to = BoxDecoration(
      color: Color(0xFF0000FF),
      borderRadius: BorderRadius.all(Radius.circular(20)),
      boxShadow: [BoxShadow(blurRadius: 8, color: Color(0x33000000))],
    );

    test('a state controller: one track per property that changes', () async {
      final html = await page(
        DecoratedBoxTransition(
          decoration: DecorationTween(
            begin: from,
            end: to,
          ).animate(card.reveal),
          child: _box,
        ),
      );
      final props = [
        for (final t in tracks(html))
          (keyframes(t).first.keys.toSet()..remove('offset')).single,
      ]..sort();
      expect(props, ['backgroundColor', 'borderRadius', 'boxShadow']);
      // The first frame is the value now.
      expect(html, contains('background-color:#ff0000'));
      expect(html, contains('border-radius:4px'));
    });

    test('the ends are what CSS interpolates itself', () async {
      final html = await page(
        DecoratedBoxTransition(
          decoration: DecorationTween(begin: from, end: to).animate(
            AnimationController(duration: const Duration(seconds: 1))
              ..forward(),
          ),
          child: _box,
        ),
      );
      expect(
        html,
        contains(
          '{0%{background-color:#ff0000}100%{background-color:#0000ff}}',
        ),
      );
      expect(html, contains('{0%{border-radius:4px}100%{border-radius:20px}}'));
      expect(html, contains('1000ms linear 0s 1 normal both'));
    });

    test('an image URL cannot close the style element', () async {
      final html = await page(
        DecoratedBoxTransition(
          decoration:
              DecorationTween(
                begin: const BoxDecoration(
                  image: DecorationImage(
                    url: 'x</style><script>alert(1)</script>',
                  ),
                ),
                end: const BoxDecoration(
                  image: DecorationImage(
                    url: 'y</style><script>alert(2)</script>',
                  ),
                ),
              ).animate(
                AnimationController(duration: const Duration(seconds: 1))
                  ..forward(),
              ),
          child: _box,
        ),
      );
      expect(html, isNot(contains('<script>alert')));
      expect(html, contains('@keyframes'));
      expect(html, isNot(contains('</style><script>alert')));
    });

    test('what does not change is not animated', () async {
      final html = await page(
        DecoratedBoxTransition(
          decoration: DecorationTween(
            begin: from,
            end: const BoxDecoration(
              color: Color(0xFF0000FF),
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ).animate(card.reveal),
          child: _box,
        ),
      );
      expect(tracks(html), hasLength(1));
      expect(html, isNot(contains('box-shadow')));
    });

    test('a controller part way draws the value in between', () async {
      final c = AnimationController(
        value: 0.5,
        duration: const Duration(seconds: 1),
      );
      final html = await page(
        DecoratedBoxTransition(
          decoration: DecorationTween(begin: from, end: to).animate(c),
          child: _box,
        ),
      );
      expect(html, contains('border-radius:12px'));
      expect(html, contains('background-color:#800080'));
    });

    test('a curve eases every property', () async {
      final html = await page(
        DecoratedBoxTransition(
          decoration: DecorationTween(begin: from, end: to).animate(
            CurvedAnimation(parent: card.reveal, curve: Curves.easeOut),
          ),
          child: _box,
        ),
      );
      expect(html, contains(Curves.easeOut.css));
    });

    test('DecorationTween interpolates color, radius, border and shadows', () {
      final mid = DecorationTween(begin: from, end: to).transform(0.5);
      expect(mid.color!.css, '#800080');
      expect((mid.borderRadius! as BorderRadius).topLeft.x, 12);
      expect(mid.boxShadow!.single.blurRadius, 4);
      final border = DecorationTween(
        begin: BoxDecoration(border: Border.all(width: 2)),
        end: BoxDecoration(border: Border.all(width: 6)),
      ).transform(0.5);
      expect(border.border!.top.width, 4);
      expect(DecorationTween(begin: from, end: to).transform(0), same(from));
      expect(DecorationTween(begin: from, end: to).transform(1), same(to));
    });
  });
}
