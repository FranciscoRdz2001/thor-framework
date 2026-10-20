@TestOn('vm')
library;

// AnimatedSize, AnimatedCrossFade and SizeTransition. The first state
// is plain CSS (right without JS); the browser animates the rest.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

abstract class _PanelMembers extends ThorState {
  _PanelMembers({super.key});

  @override
  String get $type => 'Panel';

  @override
  List<ThorMember> get $members {
    final s = this as _Panel;
    return [
      ThorMember.controller('size', s.size),
      ThorMember('settled', s.settled, call: (_) => s.settled()),
    ];
  }
}

class _Panel extends _PanelMembers {
  _Panel({super.key});

  final size = AnimationController(duration: const Duration(milliseconds: 300));
  var ends = 0;
  void settled() => ends++;
}

final _panel = _Panel(key: 'size');

/// The page with the stylesheet written compactly.
Future<String> _page(Widget body) async => (await renderDocument(
  ThorApp(child: body),
)).replaceAll(': ', ':').replaceAll('; ', ';');

const _a = SizedBox(key: ValueKey('a'), width: 10, height: 10);
const _b = SizedBox(key: ValueKey('b'), width: 20, height: 40);

void main() {
  initializeThorTests();

  setUp(() => _panel.size.value = 0);

  group('AnimatedSize', () {
    test('an element that clips, measures its content and names its '
        'timing', () async {
      final html = await renderHtml(
        const AnimatedSize(
          duration: Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: _a,
        ),
      );
      expect(html, contains('data-tsz="250|'));
      // The shell, the measured content and the child.
      expect(RegExp('<div').allMatches(html), hasLength(3));
    });

    test('the first state has no JS: the content sets the size', () async {
      final html = await _page(
        const AnimatedSize(duration: Duration(milliseconds: 200), child: _a),
      );
      expect(html, contains('overflow:hidden'));
      // The content sets the size: no inline height on the page.
      expect(bodyOfPage(html), isNot(contains('style=')));
    });

    test('reverseDuration rides as the third field; clipBehavior none '
        'does not clip', () async {
      final html = await _page(
        const AnimatedSize(
          duration: Duration(milliseconds: 200),
          reverseDuration: Duration(milliseconds: 500),
          clipBehavior: Clip.none,
          child: _a,
        ),
      );
      expect(html, contains('|500"'));
      expect(html, isNot(contains('overflow:hidden')));
    });
  });

  group('AnimatedSize onEnd and width', () {
    test('onEnd of a state method is the transitionend of the shell', () async {
      final html = await _page(
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          onEnd: _panel.settled,
          child: _a,
        ),
      );
      expect(
        RegExp(
              r'<div[^>]*data-t-on="transitionend:[^"]*settled"[^>]*data-tsz=',
            ).hasMatch(html) ||
            RegExp(
              r'<div[^>]*data-tsz=[^>]*data-t-on="transitionend:[^"]*settled"',
            ).hasMatch(html),
        isTrue,
        reason: html,
      );
    });

    test('no onEnd, no handler', () async {
      final html = await _page(
        const AnimatedSize(duration: Duration(milliseconds: 200), child: _a),
      );
      expect(html, isNot(contains('transitionend')));
    });

    test('animateWidth shrink-wraps the shell and tells the engine', () async {
      final html = await _page(
        const AnimatedSize(
          duration: Duration(milliseconds: 200),
          animateWidth: true,
          child: _a,
        ),
      );
      expect(html, contains('data-tsz="200|linear|200|w"'));
      expect(html, contains('width:fit-content'));
      expect(html, contains('max-width:100%'));
    });

    test(
      'by default only the height animates, the shell fills the width',
      () async {
        final html = await _page(
          const AnimatedSize(duration: Duration(milliseconds: 200), child: _a),
        );
        expect(html, isNot(contains('fit-content')));
        expect(html, isNot(contains('|w"')));
      },
    );
  });

  group('AnimatedCrossFade onEnd and layoutBuilder', () {
    test('onEnd rides the shell like AnimatedSize\'s', () async {
      final html = await _page(
        AnimatedCrossFade(
          firstChild: _a,
          secondChild: _b,
          crossFadeState: CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          onEnd: _panel.settled,
        ),
      );
      expect(html, contains('transitionend:'));
    });

    test('layoutBuilder lays the two children out; the shown one is the '
        'top child, with Flutter\'s keys', () async {
      Widget? top, bottom;
      Key? topKey, bottomKey;
      final html = await _page(
        AnimatedCrossFade(
          firstChild: const Text('one'),
          secondChild: const Text('two'),
          crossFadeState: CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
          layoutBuilder: (t, tk, b, bk) {
            top = t;
            bottom = b;
            topKey = tk;
            bottomKey = bk;
            return Column(children: [b, t]);
          },
        ),
      );
      expect(top, isNotNull);
      expect(bottom, isNotNull);
      expect(topKey, const ValueKey<CrossFadeState>(CrossFadeState.showSecond));
      expect(
        bottomKey,
        const ValueKey<CrossFadeState>(CrossFadeState.showFirst),
      );
      // The builder's order (bottom first) is the document order.
      expect(html.indexOf('one'), lessThan(html.indexOf('two')));
      // web: the hidden child is not taken out of the flow: the builder
      // decides where it goes. It still fades and is not focusable.
      expect(html, contains('visibility:hidden'));
      expect(html, isNot(contains('position:absolute')));
    });
  });

  group('AnimatedCrossFade', () {
    Future<String> fade(CrossFadeState state) => _page(
      AnimatedCrossFade(
        firstChild: _a,
        secondChild: _b,
        crossFadeState: state,
        duration: const Duration(milliseconds: 300),
      ),
    );

    test('both children are always there, only the class differs (the '
        'engine swaps states by patching classes)', () async {
      final first = await fade(CrossFadeState.showFirst);
      final second = await fade(CrossFadeState.showSecond);
      expect(
        RegExp('<div').allMatches(bodyOfPage(first)).length,
        RegExp('<div').allMatches(bodyOfPage(second)).length,
      );
      String strip(String h) =>
          bodyOfPage(h).replaceAll(RegExp(r'class="[^"]*"'), 'class');
      expect(strip(first), strip(second));
      expect(bodyOfPage(first), isNot(equals(bodyOfPage(second))));
    });

    test('the hidden child leaves the flow, the accessibility tree and '
        'the tab order; the shown one sets the size', () async {
      final first = await fade(CrossFadeState.showFirst);
      // One rule for the hidden child, none of it on the shown one.
      expect(first, contains('visibility:hidden'));
      expect(first, contains('position:absolute'));
      expect(first, contains('opacity:0'));
      expect(first, contains('data-tsz="300|'));
    });
  });

  group('SizeTransition', () {
    test('a stopped factor is a static grid track and a clip', () async {
      final html = await _page(
        const SizeTransition(
          sizeFactor: AlwaysStoppedAnimation(0.5),
          child: _a,
        ),
      );
      expect(html, contains('grid-template-rows:0.5fr'));
      expect(html, contains('overflow:hidden'));
      expect(html, isNot(contains('data-ta')));
      expect(html, isNot(contains('visibility:hidden')));
    });

    test('a collapsed one is out of the accessibility tree', () async {
      final html = await _page(
        const SizeTransition(sizeFactor: AlwaysStoppedAnimation(0), child: _a),
      );
      expect(html, contains('grid-template-rows:0fr'));
      expect(html, contains('visibility:hidden'));
    });

    test('horizontal animates the columns', () async {
      final html = await _page(
        const SizeTransition(
          sizeFactor: AlwaysStoppedAnimation(1),
          axis: Axis.horizontal,
          child: _a,
        ),
      );
      expect(html, contains('grid-template-columns:1fr'));
      expect(html, isNot(contains('grid-template-rows')));
    });

    test('a state controller plays the track in the browser, with its '
        'visibility', () async {
      final html = await _page(
        SizeTransition(sizeFactor: _panel.size, child: _a),
      );
      final raw = RegExp(r'data-ta="([^"]*)"')
          .firstMatch(html)![1]!
          .replaceAll('&quot;', '"')
          .replaceAll('&amp;', '&');
      final tracks = [
        for (final t in jsonDecode(raw) as List)
          (t as Map).cast<String, Object?>(),
      ];
      expect(tracks, hasLength(2));
      expect(json.encode(tracks), contains('gridTemplateRows'));
      expect(json.encode(tracks), contains('visibility'));
    });

    test('axisAlignment: -1 keeps the start, 1 the end', () async {
      String justify(double a) => a.toString();
      final start = await _page(
        const SizeTransition(
          sizeFactor: AlwaysStoppedAnimation(0.5),
          axisAlignment: -1,
          child: _a,
        ),
      );
      final end = await _page(
        const SizeTransition(
          sizeFactor: AlwaysStoppedAnimation(0.5),
          axisAlignment: 1,
          child: _a,
        ),
      );
      expect(
        start,
        contains('justify-content:flex-start'),
        reason: justify(-1),
      );
      expect(end, contains('justify-content:flex-end'));
    });
  });
}
