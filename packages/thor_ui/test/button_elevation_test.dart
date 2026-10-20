@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _css(Widget w) async => RegExp(r'<style[^>]*>([\s\S]*?)</style>')
    .allMatches(await renderDocument(ThorApp(child: w)))
    .map((m) => m[1])
    .join()
    .replaceAll(' ', '');

void main() {
  setUpAll(initializeThorTests);

  test('elevation and shadowColor draw the button shadow', () async {
    final css = await _css(
      OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          elevation: 1,
          shadowColor: const Color(0x0A0F172A),
        ),
        child: const Text('x'),
      ),
    );
    // Flutter's elevation 1 (Material 3 level 1): two layers tinted by the
    // shadow color, each at its share of the color's alpha.
    expect(
      css,
      contains(
        'box-shadow:01px2pxrgba(15,23,42,0.0118),'
        '01px3px1pxrgba(15,23,42,0.0059)',
      ),
    );
  });

  test('shadowColor tints the layers of a higher elevation', () async {
    final css = await _css(
      FilledButton(
        onPressed: () {},
        style: FilledButton.styleFrom(
          elevation: 6,
          shadowColor: const Color(0xFF123456),
        ),
        child: const Text('x'),
      ),
    );
    expect(
      css,
      contains(
        'box-shadow:01px3pxrgba(18,52,86,0.3),'
        '04px8px3pxrgba(18,52,86,0.15)',
      ),
    );
  });

  test('elevations map to Material 3 levels by dp (1, 3, 6, 8, 12)', () async {
    for (final (e, layer) in [
      (1.0, '01px2pxrgba(0,0,0,0.3),01px3px1px'),
      (3.0, '01px2pxrgba(0,0,0,0.3),02px6px2px'),
      (6.0, '01px3pxrgba(0,0,0,0.3),04px8px3px'),
      (8.0, '02px3pxrgba(0,0,0,0.3),06px10px4px'),
      (12.0, '04px4pxrgba(0,0,0,0.3),08px12px6px'),
    ]) {
      final css = await _css(
        FilledButton(
          onPressed: () {},
          style: FilledButton.styleFrom(elevation: e),
          child: const Text('x'),
        ),
      );
      expect(css, contains('box-shadow:$layer'), reason: 'elevation $e');
    }
  });

  test('elevation without a color is the Material level, 0 is none', () async {
    final raised = await _css(
      FilledButton(
        onPressed: () {},
        style: FilledButton.styleFrom(elevation: 2),
        child: const Text('x'),
      ),
    );
    expect(raised, contains('02px6px2px'));
    final flat = await _css(
      ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(elevation: 0),
        child: const Text('x'),
      ),
    );
    expect(flat, contains('box-shadow:none'));
  });

  test(
    'the base rule draws it; a hovered elevation is the hover rule',
    () async {
      final css = await _css(
        TextButton(
          onPressed: () {},
          style: ButtonStyle(
            elevation: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.hovered) ? 6 : 3,
            ),
          ),
          child: const Text('x'),
        ),
      );
      final rules = css.split('}');
      final base = rules.firstWhere((r) => r.contains('cursor:pointer'));
      expect(base, contains('box-shadow:01px2pxrgba(0,0,0,0.3),02px6px2px'));
      final hover = rules.firstWhere((r) => r.contains(':hover'));
      expect(hover, contains('box-shadow:01px3pxrgba(0,0,0,0.3),04px8px3px'));
      final pressed = rules.firstWhere((r) => r.contains(':active'));
      expect(pressed, contains('01px2pxrgba(0,0,0,0.3),02px6px2px'));
    },
  );

  test('copyWith and merge keep it', () {
    const base = ButtonStyle(
      elevation: WidgetStatePropertyAll(1),
      shadowColor: WidgetStatePropertyAll(Color(0xFF000000)),
    );
    expect(base.copyWith().elevation?.resolve({}), 1);
    expect(const ButtonStyle().merge(base).shadowColor?.resolve({}), isNotNull);
  });

  test(
    'shadows draws an exact box-shadow, per state, over elevation',
    () async {
      const exact = BoxShadow(
        color: Color(0x594F46E5),
        offset: Offset(0, 1),
        blurRadius: 2,
      );
      const lifted = BoxShadow(
        color: Color(0x594F46E5),
        offset: Offset(0, 4),
        blurRadius: 8,
      );
      final css = await _css(
        FilledButton(
          onPressed: () {},
          style: FilledButton.styleFrom(elevation: 6).copyWith(
            shadows: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.hovered)
                  ? const [lifted]
                  : s.contains(WidgetState.disabled)
                  ? const <BoxShadow>[]
                  : const [exact],
            ),
          ),
          child: const Text('x'),
        ),
      );
      expect(css, contains('box-shadow:0px1px2px0pxrgba(79,70,229,0.349)'));
      expect(css, contains('box-shadow:0px4px8px0pxrgba(79,70,229,0.349)'));
      expect(css, contains('box-shadow:none'));
      // Wins over elevation: the level-4 layers are not drawn.
      expect(css, isNot(contains('rgba(0,0,0,0.3)')));
    },
  );

  test('shadows survives copyWith, merge and styleFrom', () {
    const s = [BoxShadow(blurRadius: 2)];
    final base = FilledButton.styleFrom(shadows: s);
    expect(base.shadows?.resolve({}), s);
    expect(base.copyWith().shadows?.resolve({}), s);
    expect(const ButtonStyle().merge(base).shadows?.resolve({}), s);
    expect(ElevatedButton.styleFrom(shadows: s).shadows, isNotNull);
    expect(OutlinedButton.styleFrom(shadows: s).shadows, isNotNull);
    expect(TextButton.styleFrom(shadows: s).shadows, isNotNull);
    expect(IconButton.styleFrom(shadows: s).shadows?.resolve({}), s);
    expect(FilledButton.styleFrom().shadows, isNull);
  });

  test('the variants raise with the same levels as styleFrom', () async {
    String shadow(String css, String marker) => RegExp(
      r'box-shadow:([^;}]+)',
    ).firstMatch(css.split('}').firstWhere((r) => r.contains(marker)))![1]!;
    final own = await _css(
      ElevatedButton(onPressed: () {}, child: const Text('x')),
    );
    for (final (e, marker) in [(1.0, 'cursor:pointer'), (3.0, ':hover')]) {
      final styled = await _css(
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(elevation: e),
          child: const Text('x'),
        ),
      );
      expect(
        shadow(own, marker),
        shadow(styled, 'cursor:pointer'),
        reason: 'elevation $e',
      );
    }
  });

  test('a lone shadowColor tints the variant\'s own raise per state', () async {
    const c = Color(0xFF123456);
    List<String> rules(String css) => css.split('}');
    final raised = rules(
      await _css(
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(shadowColor: c),
          child: const Text('x'),
        ),
      ),
    );
    // Level 1 at rest, level 2 (3 dp) while hovered, both tinted.
    expect(
      raised.firstWhere((r) => r.contains('cursor:pointer')),
      contains('box-shadow:01px2pxrgba(18,52,86,0.3),01px3px1px'),
    );
    expect(
      raised.firstWhere((r) => r.contains(':hover')),
      contains('box-shadow:01px2pxrgba(18,52,86,0.3),02px6px2px'),
    );
    // A flat variant stays flat; FilledButton only lifts on hover.
    final flat = await _css(
      TextButton(
        onPressed: () {},
        style: TextButton.styleFrom(shadowColor: c),
        child: const Text('x'),
      ),
    );
    expect(flat, isNot(contains('rgba(18,52,86')));
    final filled = rules(
      await _css(
        FilledButton(
          onPressed: () {},
          style: FilledButton.styleFrom(shadowColor: c),
          child: const Text('x'),
        ),
      ),
    );
    expect(
      filled.firstWhere((r) => r.contains('cursor:pointer')),
      isNot(contains('rgba(18,52,86')),
    );
    expect(
      filled.firstWhere((r) => r.contains(':hover')),
      contains('box-shadow:01px2pxrgba(18,52,86,0.3),01px3px1px'),
    );
  });
}
