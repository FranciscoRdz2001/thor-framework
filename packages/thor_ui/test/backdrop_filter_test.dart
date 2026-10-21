@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  setUpAll(initializeThorTests);

  test('BackdropFilter fuses backdrop-filter into the child element', () async {
    final html = await renderDocument(
      ThorApp(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: const SizedBox(width: 10, height: 10),
        ),
      ),
    );
    expect(html, contains('backdrop-filter: blur(8px)'));
    // Fused: no wrapper element of its own.
    expect(html, isNot(contains('BackdropFilter')));
  });

  test('BackdropFilter(enabled: false) leaves the child as it is', () async {
    final html = await renderDocument(
      ThorApp(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          enabled: false,
          child: const SizedBox(width: 10, height: 10),
        ),
      ),
    );
    expect(html, isNot(contains('backdrop-filter')));
  });

  test('StyleProps.backdropFilter writes backdrop-filter', () {
    final css = StyleProps(
      backdropFilter: ImageFilter.compose(
        outer: ImageFilter.blur(sigmaX: 4),
        inner: ImageFilter.saturate(1.2),
      ),
    ).toCss();
    expect(css['backdrop-filter'], 'saturate(1.2) blur(4px)');
  });

  test('a frosted header: saturate then blur', () async {
    final html = await renderDocument(
      ThorApp(
        child: BackdropFilter(
          filter: ImageFilter.compose(
            outer: ImageFilter.blur(sigmaX: 12),
            inner: ImageFilter.saturate(1.4),
          ),
          child: const SizedBox(width: 10, height: 10),
        ),
      ),
    );
    expect(html, contains('backdrop-filter: saturate(1.4) blur(12px)'));
  });

  test('a disabled state matches :disabled and aria-disabled', () async {
    final html = await renderDocument(
      ThorApp(
        child: IconButton(
          onPressed: () {},
          style: IconButton.styleFrom(
            disabledForegroundColor: const Color(0xff999999),
          ),
          icon: const Icon(Icons.undo),
          tooltip: 'Undo',
        ),
      ),
    );
    expect(html, contains(':is(:disabled,[aria-disabled="true"]){'));
    // Neither hover nor pressed stick on an aria-disabled button.
    expect(
      html,
      contains(':hover:not(:is(:disabled,[aria-disabled="true"])){'),
    );
    expect(
      html,
      contains(':active:not(:is(:disabled,[aria-disabled="true"])){'),
    );
    expect(html, isNot(contains(':hover:not(:disabled)')));
    expect(html, isNot(contains(':active:not(:disabled)')));
  });

  test('a button style\'s disabled color matches aria-disabled', () async {
    final html = await renderDocument(
      ThorApp(
        child: TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
            disabledForegroundColor: const Color(0xff999999),
          ),
          child: const Text('Undo'),
        ),
      ),
    );
    expect(
      RegExp(
        r':is\(:disabled,\[aria-disabled="true"\]\)\{[^}]*#999999',
      ).hasMatch(html),
      isTrue,
    );
    expect(
      html,
      contains(':active:not(:is(:disabled,[aria-disabled="true"])){'),
    );
  });

  test('scaffoldBackgroundColor paints the body', () async {
    final html = await renderDocument(
      ThorApp(
        theme: ThemeData(scaffoldBackgroundColor: const Color(0xfff5f6f9)),
        child: const Text('x'),
      ),
    );
    expect(html, contains('--t-scaffold:#f5f6f9'));
    expect(
      html,
      contains(
        'body{margin:0;background-color:var(--t-scaffold,var(--t-surface))',
      ),
    );
    final plain = await renderDocument(
      ThorApp(theme: ThemeData(), child: const Text('x')),
    );
    expect(plain, contains('background-color:var(--t-surface)'));
    expect(plain, isNot(contains('--t-scaffold')));
  });

  test('a Scaffold paints the scaffold color, its own one wins', () async {
    final theme = ThemeData(scaffoldBackgroundColor: const Color(0xfff5f6f9));
    final html = await renderDocument(
      ThorApp(
        theme: theme,
        child: const Scaffold(body: Text('x')),
      ),
    );
    expect(html, contains('background-color: var(--t-scaffold)'));
    final own = await renderDocument(
      ThorApp(
        theme: theme,
        child: const Scaffold(
          backgroundColor: Color(0xff123456),
          body: Text('x'),
        ),
      ),
    );
    expect(own, contains('background-color: #123456'));
    expect(own, isNot(contains('background-color: var(--t-scaffold)')));
    final plain = await renderDocument(
      const ThorApp(child: Scaffold(body: Text('x'))),
    );
    expect(plain, isNot(contains('--t-scaffold')));
  });

  test('a dark theme without a scaffold color uses its surface', () async {
    final html = await renderDocument(
      ThorApp(
        theme: ThemeData(scaffoldBackgroundColor: const Color(0xfff5f6f9)),
        darkTheme: ThemeData(
          colorScheme: const ColorScheme.dark(surface: Color(0xff101010)),
        ),
        child: const Text('x'),
      ),
    );
    expect(html, contains('--t-scaffold:light-dark(#f5f6f9, #101010)'));
  });

  test('copyWith keeps and replaces the new theme fields', () {
    const scrollbar = ScrollbarThemeData(thickness: WidgetStatePropertyAll(6));
    final theme = ThemeData(
      scaffoldBackgroundColor: const Color(0xfff5f6f9),
      scrollbarTheme: scrollbar,
    );
    final kept = theme.copyWith(focusColor: const Color(0xff000000));
    expect(kept.scaffoldBackgroundColor, const Color(0xfff5f6f9));
    expect(kept.scrollbarTheme, same(scrollbar));
    const other = ScrollbarThemeData(thickness: WidgetStatePropertyAll(0));
    final changed = theme.copyWith(
      scaffoldBackgroundColor: const Color(0xff000000),
      scrollbarTheme: other,
    );
    expect(changed.scaffoldBackgroundColor, const Color(0xff000000));
    expect(changed.scrollbarTheme, same(other));
  });

  test('Theme.of hands out the scaffold color', () async {
    Color? seen;
    await renderDocument(
      ThorApp(
        theme: ThemeData(scaffoldBackgroundColor: const Color(0xfff5f6f9)),
        child: Builder(
          builder: (context) {
            seen = Theme.of(context).scaffoldBackgroundColor;
            return const Text('x');
          },
        ),
      ),
    );
    expect(seen, isNotNull);
  });

  test('ScrollbarThemeData thickness picks none, thin or auto', () {
    String? rule(double t) =>
        ScrollbarThemeData(thickness: WidgetStatePropertyAll(t)).rule;
    expect(rule(0), '*{scrollbar-width:none}');
    expect(rule(10), '*{scrollbar-width:thin}');
    expect(rule(11), '*{scrollbar-width:auto}');
    expect(const ScrollbarThemeData().rule, isNull);
    // CSS takes both colors or none: a lone track writes nothing.
    expect(
      const ScrollbarThemeData(
        trackColor: WidgetStatePropertyAll(Color(0xff000000)),
      ).rule,
      isNull,
    );
    expect(
      const ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(Color(0xff111111)),
        trackColor: WidgetStatePropertyAll(Color(0xff000000)),
      ).rule,
      '*{scrollbar-color:var(--t-scrollbar-thumb) var(--t-scrollbar-track)}',
    );
  });

  test('ScrollbarThemeData writes scrollbar-width and -color', () async {
    final html = await renderDocument(
      ThorApp(
        theme: ThemeData(
          scrollbarTheme: const ScrollbarThemeData(
            thickness: WidgetStatePropertyAll(6),
            thumbColor: WidgetStatePropertyAll(Color(0xff112233)),
          ),
        ),
        child: const Text('x'),
      ),
    );
    expect(html, contains('--t-scrollbar-thumb:#112233'));
    expect(
      html,
      contains(
        '*{scrollbar-width:thin;'
        'scrollbar-color:var(--t-scrollbar-thumb) transparent}',
      ),
    );
  });

  test('a lone scrollbar track publishes nothing', () async {
    final html = await renderDocument(
      ThorApp(
        theme: ThemeData(
          scrollbarTheme: const ScrollbarThemeData(
            trackColor: WidgetStatePropertyAll(Color(0xff000000)),
          ),
        ),
        child: const Text('x'),
      ),
    );
    expect(html, isNot(contains('scrollbar')));
  });

  test('StyleProps scrollbar fields', () {
    final css = const StyleProps(
      scrollbarWidth: ScrollbarWidth.thin,
      scrollbarThumbColor: Color(0xff112233),
    ).toCss();
    expect(css['scrollbar-width'], 'thin');
    expect(css['scrollbar-color'], '#112233 transparent');
    expect(
      const StyleProps(
        scrollbarThumbColor: Color(0xff112233),
        scrollbarTrackColor: Color(0xff445566),
      ).toCss()['scrollbar-color'],
      '#112233 #445566',
    );
    expect(
      const StyleProps(
        scrollbarTrackColor: Color(0xff445566),
      ).toCss().containsKey('scrollbar-color'),
      isFalse,
    );
  });
}
