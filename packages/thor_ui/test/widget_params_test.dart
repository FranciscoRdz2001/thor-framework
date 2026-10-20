// Fixture: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
// These tests are about the button's wiring, not its name.
// ignore_for_file: thor_lints/icon_button_without_name
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

const _x = IconData.svg('x', '<path d="M0 0"/>');

void _noop() {}

void main() {
  setUpAll(initializeThorTests);

  group('IconButton', () {
    test('keeps its 48x48 box by default', () async {
      final html = await renderHtml(
        const IconButton(icon: Icon(_x), onPressed: _noop),
      );
      expect(html, contains('width: 48px'));
      expect(html, contains('padding: 12px'));
      expect(html, contains('type="button"'));
    });

    test('iconSize sizes the icon inside', () async {
      final html = await renderHtml(
        const IconButton(icon: Icon(_x), iconSize: 32, onPressed: _noop),
      );
      expect(html, contains('width: 32px'));
      expect(html, contains('height: 32px'));
    });

    test('padding and constraints replace the fixed box', () async {
      final html = await renderHtml(
        const IconButton(
          icon: Icon(_x),
          padding: EdgeInsets.all(4),
          constraints: BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: _noop,
        ),
      );
      expect(html, contains('padding: 4px'));
      expect(html, contains('min-width: 32px'));
      expect(html, contains('min-height: 32px'));
      expect(html, isNot(contains('width: 48px')));
    });

    test('visualDensity shrinks the minimum size by 4px a step', () async {
      final html = await renderHtml(
        const IconButton(
          icon: Icon(_x),
          visualDensity: VisualDensity.compact,
          onPressed: _noop,
        ),
      );
      expect(html, contains('min-width: 40px'));
      expect(html, contains('min-height: 40px'));
    });

    test('style wins over the plain parameters', () async {
      final html = await renderHtml(
        const IconButton(
          icon: Icon(_x),
          color: Color(0xff111111),
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(Color(0xff222222)),
            backgroundColor: WidgetStatePropertyAll(Color(0xff333333)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          ),
          onPressed: _noop,
        ),
      );
      expect(html, contains('color: #222222'));
      expect(html, contains('background-color: #333333'));
      expect(html, contains('border-radius: 8px'));
      expect(html, isNot(contains('color: #111111')));
    });

    test('type submit posts its form, formAction included', () async {
      final html = await renderHtml(
        const IconButton(
          icon: Icon(_x, semanticLabel: 'Log out'),
          buttonType: ButtonType.submit,
          // The string form still works (deprecated path).
          // ignore: thor_lints/untyped_form_action
          formAction: '?/logout',
          onPressed: _noop,
        ),
      );
      expect(html, contains('type="submit"'));
      expect(html, contains('formaction="?/logout"'));
    });
  });

  test('VisualDensity matches Flutter', () {
    expect(VisualDensity.compact.horizontal, -2);
    expect(VisualDensity.comfortable.vertical, -1);
    expect(VisualDensity.standard.baseSizeAdjustment.dx, 0);
    expect(
      const VisualDensity(horizontal: 1, vertical: -1).baseSizeAdjustment.dy,
      -4,
    );
  });

  group('current page', () {
    test('ListTile with href and selected is the current page', () async {
      final html = await renderHtml(
        const ListTile(title: Text('Home'), href: '/', selected: true),
      );
      expect(html, contains('aria-current="page"'));
    });

    test('ListTile without href keeps aria-current="true"', () async {
      final html = await renderHtml(
        const ListTile(title: Text('Home'), onTap: _noop, selected: true),
      );
      expect(html, contains('aria-current="true"'));
    });

    test('Link(current: true) marks the page', () async {
      final html = await renderHtml(
        const Link(href: RouteUrl('/'), current: true, child: Text('Home')),
      );
      expect(html, contains('aria-current="page"'));
      final plain = await renderHtml(
        const Link(href: RouteUrl('/'), child: Text('Home')),
      );
      expect(plain, isNot(contains('aria-current')));
    });

    test('ListTile dense, contentPadding, tile colors and shape', () async {
      final html = await renderHtml(
        const ListTile(
          title: Text('Home'),
          href: '/',
          selected: true,
          dense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
          tileColor: Color(0xff101010),
          selectedTileColor: Color(0xff202020),
          selectedColor: Color(0xff303030),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      );
      expect(html, contains('min-height: 48px'));
      expect(html, contains('padding: 0px 12px'));
      expect(html, contains('background-color: #101010'));
      expect(html, contains('[aria-current]'));
      expect(html, contains('background-color: #202020'));
      expect(html, contains('color: #303030'));
      expect(html, contains('border-radius: 8px'));
    });
  });

  group('DropdownButton', () {
    const items = [
      DropdownMenuItem(value: 'a', child: Text('Activo')),
      DropdownMenuItem(value: 'b', child: Text('Baja')),
    ];

    test('style, borderRadius and a line underline', () async {
      final html = await renderHtml(
        DropdownButton<String>(
          items: items,
          value: 'a',
          onChanged: (_) {},
          style: const TextStyle(fontSize: 14),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          underline: const Container(height: 2, color: Color(0xff444444)),
        ),
      );
      expect(html, contains('font-size: 14px'));
      expect(html, contains('border-radius: 8px'));
      expect(html, contains('border-bottom: 2px solid #444444'));
    });

    test('an empty underline removes the outline', () async {
      final html = await renderHtml(
        DropdownButton<String>(
          items: items,
          value: 'a',
          onChanged: (_) {},
          underline: const SizedBox.shrink(),
        ),
      );
      expect(html, contains('border: 0'));
    });

    test('the hint names a control without a label', () async {
      final html = await renderHtml(
        DropdownButton<String>(
          items: items,
          value: null,
          hint: 'Status',
          onChanged: (_) {},
        ),
      );
      expect(html, contains('aria-label="Status"'));
    });

    test('DropdownButtonFormField shows its label for the select', () async {
      final html = await renderHtml(
        DropdownButtonFormField<String>(
          items: items,
          initialValue: 'b',
          name: 'status',
          decoration: const InputDecoration(
            labelText: 'Status',
            helperText: 'Filters the list',
          ),
          onChanged: (_) {},
        ),
      );
      expect(html, contains('for="f-status">Status</label>'));
      expect(html, contains('<select'));
      expect(html, contains('id="f-status"'));
      expect(html, contains('name="status"'));
      expect(html, contains('aria-describedby="f-status-msg"'));
      expect(html, contains('Filters the list'));
      expect(RegExp('selected').allMatches(html).length, 1);
    });
  });

  group('chips', () {
    test(
      'ChoiceChip takes Flutter\'s colors, shape, side and padding',
      () async {
        final html = await renderHtml(
          ChoiceChip(
            label: const Text('Mensual'),
            selected: true,
            onSelected: (_) {},
            selectedColor: const Color(0xff101010),
            backgroundColor: const Color(0xff202020),
            shape: const StadiumBorder(),
            side: const BorderSide(color: Color(0xff303030)),
            labelStyle: const TextStyle(color: Color(0xff404040)),
            padding: const EdgeInsets.all(4),
          ),
        );
        expect(html, contains('background-color: #202020'));
        expect(
          html,
          contains('[aria-pressed="true"]{background-color: #101010'),
        );
        expect(html, contains('border: 1px solid #303030'));
        expect(html, contains('color: #404040'));
        expect(html, contains('padding: 4px'));
        expect(html, contains('border-radius: 9999px'));
      },
    );

    test('FilterChip draws a checkmark only when asked', () async {
      final plain = await renderHtml(
        FilterChip(label: const Text('A'), selected: true, onSelected: (_) {}),
      );
      expect(plain, isNot(contains('::before')));
      final check = await renderHtml(
        FilterChip(
          label: const Text('A'),
          selected: true,
          showCheckmark: true,
          onSelected: (_) {},
        ),
      );
      expect(check, contains('[aria-pressed="true"]::before'));
    });
  });

  group('ExpansionTile', () {
    test('the chevron follows the theme and turns when open', () async {
      final html = await renderHtml(
        const ExpansionTile(
          title: Text('What is it?'),
          children: [Text('This')],
        ),
      );
      expect(html, isNot(contains('%2349454f')));
      expect(html, contains('::after'));
      expect(html, contains('var(--t-on-surface-variant, #49454f)'));
      expect(html, contains('[open] > summary::after'));
    });

    test('the content, its fade and the chevron move as one', () async {
      final html = await renderHtml(
        const ExpansionTile(
          title: Text('What is it?'),
          children: [Text('This')],
        ),
      );
      const motion = '250ms cubic-bezier(0.4, 0, 0.2, 1)';
      expect(html, contains('interpolate-size: allow-keywords'));
      expect(html, contains('::details-content{block-size: 0'));
      expect(html, contains('transition: block-size $motion, opacity $motion'));
      expect(html, contains('[open]::details-content{block-size: auto'));
      expect(html, contains('rotate $motion, background-color $motion'));
      // Reduced motion reaches the chevron itself, not only the header.
      expect(
        html,
        matches(RegExp(r'prefers-reduced-motion: reduce\)\{[^}]*::after\{')),
      );
    });

    test('tilePadding, icon colors, shapes and backgrounds', () async {
      final html = await renderHtml(
        const ExpansionTile(
          title: Text('What is it?'),
          tilePadding: EdgeInsets.symmetric(horizontal: 24),
          iconColor: Color(0xff101010),
          collapsedIconColor: Color(0xff202020),
          backgroundColor: Color(0xff303030),
          collapsedBackgroundColor: Color(0xff404040),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          children: [Text('This')],
        ),
      );
      expect(html, contains('padding: 0px 64px 0px 24px'));
      expect(html, contains('right: 24px'));
      expect(html, contains('background-color: #202020'));
      expect(html, contains('background-color: #101010'));
      expect(html, contains('background-color: #404040'));
      expect(html, contains('[open]{background-color: #303030'));
      expect(html, contains('border-radius: 4px'));
      expect(html, contains('border-radius: 12px'));
    });
  });

  group('dense fields and inverse color roles', () {
    test('isDense tightens the vertical padding', () async {
      final html = await renderHtml(
        const TextField(decoration: InputDecoration(isDense: true)),
      );
      expect(html, contains('padding: 8px 12px'));
      final normal = await renderHtml(const TextField());
      expect(normal, contains('padding: 16px 12px'));
    });

    test('ColorScheme publishes the inverse and low container roles', () {
      final light = const ColorScheme.light().toCssVariables();
      expect(light['--t-inverse-surface'], '#322f35');
      expect(light['--t-inverse-on-surface'], '#f5eff7');
      expect(light['--t-inverse-primary'], '#d0bcff');
      expect(light['--t-surface-container-low'], '#f7f2fa');
      final dark = const ColorScheme.dark().toCssVariables();
      expect(dark['--t-inverse-surface'], '#e6e0e9');
      expect(dark['--t-surface-container-low'], '#1d1b20');
      expect(
        ThemeColor.onInverseSurface.css,
        contains('--t-inverse-on-surface'),
      );
    });
  });

  group('surfaceContainerHigh', () {
    // A Dialog/AlertDialog paints `var(--t-surface-container-high, #ece6f0)`:
    // no scheme published the variable, so a dark theme's dialog stayed
    // lavender under light text.
    test('the dark scheme publishes it, the light one keeps the fallback', () {
      expect(
        const ColorScheme.dark().toCssVariables()['--t-surface-container-high'],
        '#2b2930',
      );
      expect(
        const ColorScheme.light().toCssVariables(),
        isNot(contains('--t-surface-container-high')),
      );
      const custom = ColorScheme.light(surfaceContainerHigh: Color(0xFFABCDEF));
      expect(custom.toCssVariables()['--t-surface-container-high'], '#abcdef');
      expect(
        ThemeColor.surfaceContainerHigh.css,
        contains('--t-surface-container-high'),
      );
    });

    test('a dark theme\'s dialog is not the light fallback', () async {
      final html = await renderDocument(
        ThorApp(
          theme: ThemeData(),
          darkTheme: ThemeData(colorScheme: const ColorScheme.dark()),
          child: const AlertDialog(id: 'd', title: Text('t')),
        ),
      );
      expect(html, contains('--t-surface-container-high:'));
    });
  });

  group('inputDecorationTheme', () {
    final theme = ThemeData(
      inputDecorationTheme: const InputDecorationTheme(
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        filled: true,
        fillColor: Color(0xff101010),
        border: OutlineInputBorder(),
        labelStyle: TextStyle(color: Color(0xff202020)),
      ),
    );

    test('fills what the field leaves null', () async {
      final html = await renderHtml(
        Theme.provide(
          data: theme,
          child: const TextField(
            decoration: InputDecoration(labelText: 'Name'),
          ),
        ),
      );
      expect(html, contains('padding: 6px 10px'));
      expect(html, contains('background-color: #101010'));
      expect(html, contains('border-radius: 4px'));
      expect(html, contains('color: #202020'));
    });

    test('the field\'s own decoration wins', () async {
      final html = await renderHtml(
        Theme.provide(
          data: theme,
          child: const TextField(
            decoration: InputDecoration(
              contentPadding: EdgeInsets.all(2),
              fillColor: Color(0xff303030),
            ),
          ),
        ),
      );
      expect(html, contains('padding: 2px'));
      expect(html, contains('background-color: #303030'));
    });

    test('TextFormField and DropdownButtonFormField read it too', () async {
      final form = await renderHtml(
        Theme.provide(
          data: theme,
          child: const TextFormField(
            name: 'a',
            decoration: InputDecoration(labelText: 'A'),
          ),
        ),
      );
      expect(form, contains('background-color: #101010'));
      final dropdown = await renderHtml(
        Theme.provide(
          data: theme,
          child: DropdownButtonFormField<String>(
            items: const [DropdownMenuItem(value: 'a', child: Text('A'))],
            decoration: const InputDecoration(labelText: 'A'),
            onChanged: (_) {},
          ),
        ),
      );
      expect(dropdown, contains('color: #202020'));
      expect(dropdown, contains('padding: 6px 36px 6px 10px'));
      expect(dropdown, contains('background-color: #101010'));
    });

    test('applyDefaults keeps the decoration\'s values', () {
      const d = InputDecoration(hintText: 'x', isDense: true);
      final merged = d.applyDefaults(
        const InputDecorationTheme(isDense: false, filled: true),
      );
      expect(merged.hintText, 'x');
      expect(merged.isDense, isTrue);
      expect(merged.filled, isTrue);
    });
  });

  group('SizedBox width in a narrower parent', () {
    test('a Column child is clamped to the parent (Flutter)', () async {
      final html = await renderHtml(
        const Column(
          children: [SizedBox(width: 560, height: 10, child: Text('x'))],
        ),
      );
      expect(html, contains('width: 560px'));
      expect(html, contains('max-width: 100%'));
    });

    test('a Row child keeps its width (Flutter overflows)', () async {
      final html = await renderHtml(
        const Row(children: [SizedBox(width: 560, height: 10)]),
      );
      expect(html, contains('width: 560px'));
      expect(html, isNot(contains('max-width: 100%')));
    });
  });

  group('SnackBar duration', () {
    test('hides itself after Flutter\'s 4 s by default, with CSS', () async {
      final html = await renderDocument(
        const SnackBar(
          content: Text('Saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      expect(html, contains('@keyframes thor-snack-out'));
      expect(
        html,
        contains('animation: thor-snack-out 200ms ease-in 4000ms both'),
      );
      expect(html, contains('animation-play-state: paused'));
    });

    // Firefox: a transition on the properties a delayed animation moves (with
    // only a `to` keyframe and `forwards`) leaves the bar at `opacity: 0`
    // once the entry transition ends. The shown state is the animation's own
    // `from`, held through the delay with `both` (toast_modal_check in Firefox).
    test('the animation starts from the shown state and holds it', () async {
      final html = await renderDocument(
        const SnackBar(
          content: Text('Saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      expect(
        html,
        contains(
          '@keyframes thor-snack-out{from{opacity:1;visibility:visible;translate:-50% 0}'
          'to{opacity:0;visibility:hidden;translate:-50% 16px}}',
        ),
      );
    });

    test('a custom duration, and none while hidden', () async {
      final shown = await renderDocument(
        const SnackBar(content: Text('Saved'), duration: Duration(seconds: 2)),
      );
      expect(shown, contains('ease-in 2000ms both'));
      final hidden = await renderDocument(
        const SnackBar(content: Text('Saved'), visible: false),
      );
      expect(hidden, isNot(contains('thor-snack-out 200ms')));
    });
  });
}
