@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

const _ms200 = Duration(milliseconds: 200);

void main() {
  group('Container.transform', () {
    test('a Container transforms from its top-left, like Flutter', () async {
      final html = await renderHtml(
        Container(width: 10, height: 10, transform: Matrix4.rotationZ(0.5)),
      );
      expect(html, contains('transform: matrix('));
      // web: CSS rotates around the center by default, Flutter around (0, 0).
      expect(html, contains('transform-origin: 0 0'));
    });

    test('transformAlignment sets the origin', () async {
      final html = await renderHtml(
        Container(
          width: 10,
          height: 10,
          transform: Matrix4.diagonal3Values(2, 2, 1),
          transformAlignment: Alignment.center,
        ),
      );
      expect(html, contains('transform: matrix(2, 0, 0, 2, 0, 0)'));
      expect(html, contains('transform-origin: 50% 50%'));
    });

    test('no transform: no transform declarations', () async {
      final html = await renderHtml(const Container(width: 10, height: 10));
      expect(html, isNot(contains('transform')));
    });

    test('AnimatedContainer transitions the transform', () async {
      final html = await renderHtml(
        AnimatedContainer(
          width: 10,
          height: 10,
          duration: _ms200,
          transform: Matrix4.translationValues(8, 0, 0),
        ),
      );
      expect(html, matches(RegExp(r'transition-property: [^;]*\btransform\b')));
      expect(html, contains('transform: matrix(1, 0, 0, 1, 8, 0)'));
      expect(html, contains('transform-origin: 0 0'));
    });
  });

  group('AnimatedDefaultTextStyle', () {
    test('transitions weight, line height and letter spacing', () async {
      final html = await renderHtml(
        const AnimatedDefaultTextStyle(
          style: TextStyle(
            fontWeight: FontWeight.w700,
            height: 1.5,
            letterSpacing: 2,
          ),
          duration: _ms200,
          child: Text('t'),
        ),
      );
      expect(
        html,
        matches(
          RegExp(
            r'transition-property: [^;]*font-weight[^;]*line-height[^;]*letter-spacing',
          ),
        ),
      );
      expect(html, contains('font-weight: 700'));
      expect(html, contains('line-height: 1.5'));
      expect(html, contains('letter-spacing: 2px'));
    });
  });

  group('TweenAnimationBuilder', () {
    test(
      'builds the target and transitions what the builder returns',
      () async {
        final html = await renderHtml(
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 0.5),
            duration: _ms200,
            curve: Curves.easeOut,
            builder: (context, value, child) =>
                Opacity(opacity: value, child: child!),
            child: const SizedBox(width: 10, height: 10),
          ),
        );
        expect(html, contains('opacity: 0.5'));
        expect(html, contains('transition-property: all'));
        expect(html, contains('transition-duration: 200ms'));
        expect(html, contains('cubic-bezier(0, 0, 0.58, 1)'));
        expect(html, contains('prefers-reduced-motion: reduce'));
      },
    );

    test('a color tween works through the builder', () async {
      final html = await renderHtml(
        TweenAnimationBuilder<Color?>(
          tween: ColorTween(
            begin: const Color(0xFF000000),
            end: const Color(0xFFFF0000),
          ),
          duration: _ms200,
          builder: (context, color, _) =>
              Container(width: 10, height: 10, color: color),
        ),
      );
      expect(html, contains('background-color: #ff0000'));
      expect(html, contains('transition-property: all'));
    });

    test('the child reaches the builder untouched', () async {
      Widget? seen;
      const child = Text('hi');
      await renderHtml(
        TweenAnimationBuilder<double>(
          tween: Tween(end: 1),
          duration: _ms200,
          builder: (context, value, c) {
            seen = c;
            return c!;
          },
          child: child,
        ),
      );
      expect(seen, same(child));
    });

    test('onEnd is the transitionend of the root element', () async {
      final html = await renderHtml(
        TweenAnimationBuilder<double>(
          tween: Tween(end: 1),
          duration: _ms200,
          onEnd: () {},
          builder: (context, value, _) =>
              Opacity(opacity: value, child: const Text('x')),
        ),
      );
      // A plain closure cannot run in the browser: it is not wired (a
      // ThorState method is), but the transition still renders.
      expect(html, contains('transition-property: all'));
    });
  });

  group('transforms compose instead of replacing each other', () {
    test('Transform.rotate around Container(transform:) keeps both', () async {
      final html = await renderHtml(
        Transform.rotate(
          angle: 0.5,
          child: Container(
            width: 10,
            height: 10,
            transform: Matrix4.translationValues(8, 0, 0),
          ),
        ),
      );
      // The rotation is outer (it turns around the center), the container's
      // matrix inner (anchored at its top-left): origins are baked in.
      expect(
        html,
        contains(
          'transform: translate(50%, 50%) rotate(0.5rad) translate(-50%, -50%) '
          'matrix(1, 0, 0, 1, 8, 0); transform-origin: 0 0',
        ),
      );
    });

    test('nested Transform wrappers keep both', () async {
      final html = await renderHtml(
        Transform.rotate(
          angle: 0.5,
          child: Transform.scale(
            scale: 2,
            child: const SizedBox(width: 3, height: 3),
          ),
        ),
      );
      expect(html, contains('transform: rotate(0.5rad) scale(2)'));
    });

    test('an AnimatedOpacity keeps its timing around a '
        'TweenAnimationBuilder (`all` goes first)', () async {
      final html = await renderHtml(
        AnimatedOpacity(
          opacity: 0.5,
          duration: const Duration(seconds: 2),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: 1),
            duration: _ms200,
            builder: (context, value, child) =>
                const Container(width: 10, color: Color(0xFF000000)),
          ),
        ),
      );
      expect(html, contains('transition-property: all, opacity'));
      expect(html, contains('transition-duration: 200ms, 2000ms'));
    });
  });
}
