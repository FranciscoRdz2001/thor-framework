@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// The member list thor generates for [_Board], by hand.
abstract class _BoardMembers extends ThorState {
  @override
  String get $type => 'Board';

  @override
  List<ThorMember> get $members {
    final s = this as _Board;
    return [
      ThorMember('open', s.open, arity: 1, call: (a) => s.open(a!)),
      ThorMember(
        'swiped',
        s.swiped,
        arity: 2,
        call: (a) {
          final x = splitArgs(a, 2);
          return s.swiped(x[0], SwipeDirection.values.byName(x[1]));
        },
      ),
      ThorMember(
        'moved',
        s.moved,
        arity: 2,
        call: (a) {
          final x = splitArgs(a, 2);
          return s.moved(double.parse(x[0]), double.parse(x[1]));
        },
      ),
      ThorMember(
        'zoomed',
        s.zoomed,
        arity: 1,
        call: (a) => s.zoomed(double.parse(a!)),
      ),
      ThorMember('like', s.like, call: (_) => s.like()),
      ThorMember(
        'tappedUp',
        s.tappedUp,
        arity: 1,
        call: (a) => s.tappedUp(TapUpDetails.fromArg(a)),
      ),
    ];
  }
}

class _Board extends _BoardMembers {
  void open(String key) {}
  void swiped(String key, SwipeDirection d) {}
  void moved(double dx, double dy) {}
  void zoomed(double scale) {}
  void like() {}
  void tappedUp(TapUpDetails details) {}
}

final _board = _Board();
const _box = SizedBox(width: 10, height: 10);

Future<String> _page(Widget body) =>
    renderDocument(ThorApp(child: body)).then(headOfPage);

void main() {
  initializeThorTests();

  test('a swipeable row: markers, setup, CSS fused into the child', () async {
    final html = await renderHtml(
      Gesture(
        onTap: _board.open.withArg('m1'),
        onSwipe: _board.swiped.withArg('m1'),
        swipe: const Swipe(dismiss: true),
        child: const Container(width: 10, color: Color(0xFFFFFFFF)),
      ),
    );
    expect(RegExp('<div').allMatches(html), hasLength(1));
    expect(html, contains('data-t-on="click:Board.open"'));
    expect(html, contains('data-tg="swipe:Board.swiped"'));
    expect(html, contains('data-tx="m1"'));
    expect(html, contains('data-tg-swipe="h|1|0.4"'));
    expect(html, contains('translate: var(--tg-x, 0px) var(--tg-y, 0px)'));
    expect(html, contains('touch-action: pan-y'));
    // A non-native tap target gets button semantics.
    expect(html, contains('role="button"'));
  });

  test('the gesture variables are typed, not inherited, and only on a page '
      'that has a Gesture (rule 4)', () async {
    final swipe = await _page(
      Gesture(onSwipe: _board.swiped.withArg('m1'), child: _box),
    );
    expect(
      swipe,
      contains(
        "@property --tg-x{syntax:'<length>';inherits:false;initial-value:0px}",
      ),
    );
    expect(swipe, contains('@property --tg-y{'));
    expect(swipe, isNot(contains('@property --tg-s')));
    final pinch = await _page(Gesture(onScaleEnd: _board.zoomed, child: _box));
    expect(
      pinch,
      contains(
        "@property --tg-s{syntax:'<number>';inherits:false;initial-value:1}",
      ),
    );
    expect(pinch, isNot(contains('@property --tg-x')));
    // A live drag moves things through the state: nothing to register.
    final live = await _page(Gesture(onDragUpdate: _board.moved, child: _box));
    expect(live, isNot(contains('@property')));
    // A page without a Gesture ships no @property at all.
    final none = await _page(const SizedBox(width: 10, height: 10));
    expect(none, isNot(contains('@property')));
    // Once per page, even with many gestures, and through a wrapper chain.
    final many = await _page(
      Column(
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.all(2),
              child: Gesture(
                onSwipe: _board.swiped.withArg('m$i'),
                child: _box,
              ),
            ),
        ],
      ),
    );
    expect(RegExp('@property --tg-x').allMatches(many), hasLength(1));
  });

  test('a replayed Cached fragment, and a swipe with a pinch, keep the '
      'registration (adversarial)', () async {
    Widget fragment() => Cached(
      cacheKey: 'g',
      child: Gesture(
        onSwipe: _board.swiped.withArg('m1'),
        onScaleEnd: _board.zoomed,
        child: _box,
      ),
    );
    Cached.clear();
    final cold = await _page(fragment());
    final warm = await _page(fragment());
    expect(warm, cold, reason: 'the replay is the fresh render');
    for (final name in ['--tg-x', '--tg-y', '--tg-s']) {
      expect(RegExp('@property $name').allMatches(warm), hasLength(1));
    }
    // A page that has it only inside the fragment, with something else first.
    final other = await _page(Column(children: [const Text('a'), fragment()]));
    expect(RegExp('@property --tg-x').allMatches(other), hasLength(1));
  });

  test('shared sheets: a specimen with a Gesture puts the rule in the file, '
      'a page with another kind keeps its own inline (adversarial)', () async {
    final handler = RouteHandler<Widget>(
      renderer: WidgetRenderer(
        app: (page) => ThorApp(theme: ThemeData(), child: page),
        styles: const [],
        shareStyles: true,
        specimens: [Gesture(onSwipe: _board.swiped.withArg('m1'), child: _box)],
      ),
      onError: (request, error, stack) {},
      routes: [
        routePage<void>(
          path: 'swipe',
          build: (c, s) =>
              Gesture(onSwipe: _board.swiped.withArg('m2'), child: _box),
        ),
        routePage<void>(
          path: 'pinch',
          build: (c, s) => Gesture(onScaleEnd: _board.zoomed, child: _box),
        ),
        routePage<void>(path: 'none', build: (c, s) => _box),
      ],
    );
    PageRequest get(String path) => PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://site.test$path'),
      headers: {HttpHeader.host: 'site.test'},
    );
    final swipe = (await handler.handle(get('/swipe'))).text;
    final base = RegExp(
      r'<link rel="stylesheet" href="([^"]+)"',
    ).firstMatch(swipe)![1]!;
    final sheet = (await handler.handle(get(base))).text;
    expect(sheet, contains('@property --tg-x{'));
    expect(sheet, contains('@property --tg-y{'));
    // Not repeated in the page that links the file.
    expect(swipe, isNot(contains('@property')));
    // A page of another kind: its own rule inline, the file's untouched.
    final pinch = (await handler.handle(get('/pinch'))).text;
    expect(pinch, contains('@property --tg-s{'));
    expect(pinch, isNot(contains('@property --tg-x')));
    expect(sheet, isNot(contains('@property --tg-s')));
    expect(
      (await handler.handle(get('/none'))).text,
      isNot(contains('@property')),
    );
  });

  test('drag, pinch and double tap setups', () async {
    final html = await renderHtml(
      Gesture(
        onDragEnd: _board.moved,
        drag: const Drag(axis: Axis.vertical, snapBack: false, step: 5),
        onScaleEnd: _board.zoomed,
        pinch: const Pinch(max: 3),
        onDoubleTap: _board.like,
        child: _box,
      ),
    );
    expect(
      html,
      contains('data-tg="dtap:Board.like;drag:Board.moved;scale:Board.zoomed"'),
    );
    expect(html, contains('data-tg-drag="v|0|5"'));
    expect(html, contains('data-tg-scale="1|3|0|0.25"'));
    expect(html, contains('scale: var(--tg-s, 1)'));
    expect(html, contains('touch-action: none'));
  });

  test('a live drag (onDragUpdate) marks the drag but does not translate '
      'the element', () async {
    final html = await renderHtml(
      Gesture(
        onDragUpdate: _board.moved,
        drag: const Drag(axis: Axis.horizontal),
        child: _box,
      ),
    );
    expect(html, contains('data-tg="dragu:Board.moved"'));
    expect(html, contains('data-tg-drag="h|1|10"'));
    expect(html, contains('touch-action: pan-y'));
    expect(html, isNot(contains('translate:')));
  });

  test('press feedback is a CSS :active condition', () async {
    final html = await renderHtml(
      Gesture(
        onDoubleTap: _board.like,
        feedback: const Press(scale: 0.9),
        child: _box,
      ),
    );
    expect(html, contains(':active'));
    expect(html, contains('scale: 0.9'));
  });

  test('a swipe names its keyboard alternative (Shift+arrow)', () async {
    final h = await renderHtml(
      Gesture(onSwipe: _board.swiped.withArg('a'), child: _box),
    );
    expect(h, contains('aria-keyshortcuts="Shift+ArrowLeft Shift+ArrowRight"'));
    final v = await renderHtml(
      Gesture(
        onSwipe: _board.swiped.withArg('a'),
        swipe: const Swipe(axis: Axis.vertical),
        child: _box,
      ),
    );
    expect(v, contains('aria-keyshortcuts="Shift+ArrowUp Shift+ArrowDown"'));
    final none = await renderHtml(Gesture(onTap: _board.like, child: _box));
    expect(none, isNot(contains('aria-keyshortcuts')));
  });

  test(
    'a horizontal swipe is logical only: start/end, no left/right',
    () async {
      final html = await renderHtml(
        Gesture(
          onSwipe: _board.swiped.withArg('a'),
          swipe: const Swipe(dismiss: true),
          child: _box,
        ),
      );
      // The setup has no field for the direction any more: three, as always.
      expect(html, contains('data-tg-swipe="h|1|0.4"'));
      expect(SwipeDirection.values.map((d) => d.name), [
        'up',
        'down',
        'start',
        'end',
      ]);
    },
  );

  test('a dragged handle keeps the transitions of what wraps it', () async {
    // The slide-to-confirm handle: an AnimatedPositioned around a Gesture
    // with press feedback, fused into one element. The gesture's transitions
    // merge with the position's instead of replacing them.
    final html = await renderHtml(
      Stack(
        children: [
          AnimatedPositioned(
            left: 4,
            duration: const Duration(milliseconds: 300),
            child: Gesture(
              onDragEnd: _board.moved,
              drag: const Drag(axis: Axis.horizontal),
              feedback: const Press(scale: 0.95),
              child: _box,
            ),
          ),
        ],
      ),
    );
    final property = RegExp(
      r'transition-property: ([^;}]*)',
    ).allMatches(html).map((m) => m[1]!).join(' | ');
    expect(property, contains('left'));
    expect(property, contains('translate'));
    expect(property, contains('scale'));
    expect(html, isNot(contains('transition: scale')));
    expect(html, isNot(contains('[data-tg-release]')));
  });

  test('press feedback honors prefers-reduced-motion', () async {
    final page = await renderDocument(
      ThorApp(
        child: Gesture(
          onDoubleTap: _board.like,
          feedback: const Press(),
          child: _box,
        ),
      ),
    );
    final css = RegExp(
      r'<style id="thor-styles">(.*?)</style>',
      dotAll: true,
    ).firstMatch(page)![1]!;
    expect(
      RegExp(
        r'@media \(prefers-reduced-motion: ?reduce\)\{[^}]*transition-duration: ?1ms',
      ).hasMatch(css),
      isTrue,
      reason: css,
    );
  });

  test(
    'onTapDown and onTapUp mark the element and make it focusable',
    () async {
      final html = await renderHtml(
        Gesture(
          onTapDown: _board.moved,
          onTapUp: _board.moved,
          child: const Container(width: 10, color: Color(0xFFFFFFFF)),
        ),
      );
      expect(html, contains('data-tg="tapd:Board.moved;tapu:Board.moved"'));
      // No click handler of its own: the engine's gesture reads the pointer.
      expect(html, isNot(contains('data-t-on')));
      expect(html, contains('role="button"'));
      expect(html, contains('tabindex="0"'));
    },
  );

  test('GestureDetector passes the tap position callbacks through', () async {
    final html = await renderHtml(
      GestureDetector(onTapUp: _board.tappedUp, child: _box),
    );
    expect(html, contains('tapu:Board.tappedUp'));
  });
}
