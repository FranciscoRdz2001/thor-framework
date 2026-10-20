@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _render(Widget button) => renderDocument(ThorApp(child: button));

void main() {
  setUpAll(initializeThorTests);

  test('resolveWith compiles to a rule per state, in the same class', () async {
    const hover = Color(0xff00aa00);
    const press = Color(0xff0000aa);
    const focus = Color(0xffaa00aa);
    const off = Color(0xff999999);
    final html = await _render(
      FilledButton(
        onPressed: () {},
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.disabled)) return off;
            if (states.contains(WidgetState.pressed)) return press;
            if (states.contains(WidgetState.hovered)) return hover;
            if (states.contains(WidgetState.focused)) return focus;
            return null;
          }),
        ),
        child: const Text('x'),
      ),
    );
    expect(
      html,
      contains(
        ':hover:not(:is(:disabled,[aria-disabled="true"])){background-color: #00aa00',
      ),
    );
    expect(
      html,
      contains(
        ':active:not(:is(:disabled,[aria-disabled="true"])){background-color: #0000aa',
      ),
    );
    expect(html, contains('#aa00aa'));
    // The disabled colors replace the faded look.
    final disabled = RegExp(
      r'aria-disabled="true"\]\)\{[^}]*\}',
    ).firstMatch(html)![0]!;
    expect(disabled, contains('background-color: #999999'));
    expect(disabled, isNot(contains('opacity')));
    // The client builds nothing: one class, no inline style.
    expect(html, isNot(contains('<button style=')));
  });

  test(
    'a plain value renders no state rules and keeps the faded look',
    () async {
      final plain = await _render(
        FilledButton(
          onPressed: () {},
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xff123456),
          ),
          child: const Text('x'),
        ),
      );
      expect(plain, contains('background-color: #123456'));
      expect(plain, contains('opacity: 0.38'));
    },
  );

  test('styleFrom takes the disabled colors of Flutter', () {
    final s = TextButton.styleFrom(
      foregroundColor: const Color(0xff111111),
      disabledForegroundColor: const Color(0xff222222),
    );
    expect(s.foregroundColor!.resolve({}), const Color(0xff111111));
    expect(
      s.foregroundColor!.resolve({WidgetState.disabled}),
      const Color(0xff222222),
    );
  });

  test('IconButton isSelected sets aria-pressed and swaps the icon', () async {
    final html = await _render(
      IconButton(
        onPressed: () {},
        tooltip: 'Like',
        isSelected: true,
        icon: const Text('off'),
        selectedIcon: const Text('on'),
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.selected)
                ? const Color(0xffcc0000)
                : null,
          ),
        ),
      ),
    );
    expect(html, contains('aria-pressed="true"'));
    expect(html, contains('>on<'));
    expect(html, isNot(contains('>off<')));
    expect(html, contains('#cc0000'));
  });
}
