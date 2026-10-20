@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  initializeThorTests();

  test(
    'a placeholder box: hidden from assistive technology, animated in CSS',
    () async {
      final html = await renderDocument(
        const ThorApp(child: Skeleton(width: 120, height: 20)),
      );
      expect(html, contains('aria-hidden="true"'));
      expect(html, contains('data-thor-skeleton'));
      expect(html, contains('width: 120px'));
      expect(html, contains('height: 20px'));
      expect(
        html,
        contains('@keyframes thor-skeleton{to{background-position:-200% 0}}'),
      );
      // Still for people who ask for less motion.
      expect(
        RegExp(
          r'prefers-reduced-motion: reduce\)\{[^}]*animation: none',
        ).hasMatch(html),
        isTrue,
      );
      // No script.
      expect(bodyOfPage(html), isNot(contains('<script')));
    },
  );

  test('a circle, and one that takes the width of its parent', () async {
    final circle = await renderDocument(
      const ThorApp(child: Skeleton.circle(diameter: 40)),
    );
    expect(circle, contains('border-radius: 50%'));
    final wide = await renderDocument(const ThorApp(child: Skeleton()));
    expect(wide, contains('width: 100%'));
  });

  test('Skeleton.expand fills its parent in both directions', () async {
    final html = await renderDocument(
      const ThorApp(
        child: AspectRatio(aspectRatio: 1.5, child: Skeleton.expand()),
      ),
    );
    expect(html, contains('aspect-ratio: 1.5'));
    expect(html, contains('width: 100%'));
    expect(html, contains('height: 100%'));
    expect(html, isNot(contains('height: 16px')));
    expect(html, isNot(contains('Infinity')));
    expect(html, contains('data-thor-skeleton'));
    expect(
      RegExp(
        r'prefers-reduced-motion: reduce\)\{[^}]*animation: none',
      ).hasMatch(html),
      isTrue,
    );
  });

  test('height: double.infinity is height 100%, like SizedBox', () async {
    final html = await renderDocument(
      const ThorApp(child: Skeleton(width: 80, height: double.infinity)),
    );
    expect(html, contains('width: 80px'));
    expect(html, contains('height: 100%'));
    expect(html, isNot(contains('Infinity')));
  });

  test('Skeleton.expand keeps its corner radius', () async {
    final html = await renderDocument(
      const ThorApp(child: Skeleton.expand(borderRadius: 12)),
    );
    expect(html, contains('border-radius: 12px'));
  });
}
