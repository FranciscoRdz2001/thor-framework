@TestOn('vm')
library;

// Hover exists only with a pointer that hovers: every hover rule thor
// writes is inside `@media (hover: hover)`, so a tap on a phone never
// leaves it stuck. Everything else is written as before.
import 'package:test/test.dart';
import 'package:thor_engine/css_text.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _css(Widget child) async {
  final page = await renderDocument(ThorApp(child: child));
  return RegExp(
    r'<style id="thor-styles">(.*?)</style>',
    dotAll: true,
  ).firstMatch(page)![1]!;
}

/// Every rule of [css] that mentions `:hover`, with whether it is guarded.
List<(String, bool)> _hoverRules(String css) {
  final out = <(String, bool)>[];
  // Rules grouped under one at-rule (`@media X{.a:hover{…}.b:hover{…}}`)
  // are read one by one, each with the at-rules around it.
  void walk(String text, List<String> within) {
    for (final s in splitCssStatements(text)) {
      final body = s.body;
      if (body == null) continue;
      if (s.prelude.startsWith('@')) {
        walk(body, [...within, s.prelude]);
      } else if (s.prelude.contains(':hover')) {
        final guards = within.join(' ');
        out.add((
          '$guards ${s.prelude}',
          within.contains('@media (hover: hover)'),
        ));
      }
    }
  }

  walk(css, const []);
  return out;
}

void main() {
  setUpAll(initializeThorTests);

  test('.when(hover:) is guarded; pressed and focus are not', () async {
    final css = await _css(
      Styled(
        style: const StyleProps(opacity: 1).when(
          hover: const StyleProps(opacity: 0.5),
          pressed: const StyleProps(opacity: 0.3),
          focused: const StyleProps(opacity: 0.8),
        ),
        child: const Text('x'),
      ),
    );
    final hovers = _hoverRules(css);
    expect(hovers, isNotEmpty);
    expect(hovers.every((h) => h.$2), isTrue, reason: css);
    expect(css, contains(':active{'));
    expect(
      RegExp(r'@media \(hover: hover\)\{[^}]*:active').hasMatch(css),
      isFalse,
    );
    expect(
      RegExp(r'@media \(hover: hover\)\{[^}]*:focus-visible').hasMatch(css),
      isFalse,
    );
  });

  test('a control\'s hover (hoverEnabled) is guarded', () async {
    final css = await _css(
      FilledButton(onPressed: () {}, child: const Text('Ok')),
    );
    expect(_hoverRules(css).every((h) => h.$2), isTrue, reason: css);
  });

  test('a HoverGroup (group-hover) is guarded', () async {
    final css = await _css(
      HoverGroup(
        child: Styled(
          style: const StyleProps(
            opacity: 1,
          ).when(groupHover: const StyleProps(opacity: 0.5)),
          child: const Text('x'),
        ),
      ),
    );
    final hovers = _hoverRules(css);
    expect(hovers, isNotEmpty);
    expect(hovers.every((h) => h.$2), isTrue, reason: css);
  });

  test(
    'descendants with :hover are guarded; plain descendants are not',
    () async {
      final css = await _css(
        const Styled(
          descendants: {
            'a': StyleProps(opacity: 0.9),
            'a:hover': StyleProps(opacity: 0.5),
          },
          child: Text('x'),
        ),
      );
      expect(_hoverRules(css).every((h) => h.$2), isTrue, reason: css);
      expect(
        RegExp(r'@media \(hover: hover\)\{[^{]* a:where\(').hasMatch(css),
        isFalse,
      );
    },
  );

  test('no page writes a hover rule outside the guard', () async {
    final css = await _css(
      Column(
        children: [
          OutlinedButton(onPressed: () {}, child: const Text('a')),
          TextButton(onPressed: () {}, child: const Text('b')),
          Checkbox(value: true, onChanged: (_) {}),
          const Link(href: RouteUrl('/x'), child: Text('link')),
        ],
      ),
    );
    final hovers = _hoverRules(css);
    expect(hovers.where((h) => !h.$2), isEmpty, reason: css);
  });

  test('without a ThorApp (local rules) hover is guarded too', () async {
    final html = await renderHtml(
      Styled(
        style: const StyleProps(
          opacity: 1,
        ).when(hover: const StyleProps(opacity: 0.5)),
        child: const Text('x'),
      ),
    );
    expect(_hoverRules(html).every((h) => h.$2), isTrue, reason: html);
  });

  test(
    '.when(focusWithin:) styles the box while something inside has focus',
    () async {
      final css = await _css(
        Container(
          decoration:
              BoxDecoration(
                border: Border.all(color: const Color(0xFFCCCCCC)),
              ).when(
                focusWithin: BoxDecoration(
                  border: Border.all(color: const Color(0xFF111111)),
                ),
              ),
          child: const Text('x'),
        ),
      );
      expect(css, contains(':focus-within{'));
      expect(css, contains('#111111'));
    },
  );

  test('.when(disabled:) styles a disabled control', () async {
    final css = await _css(
      Styled(
        style: const StyleProps().when(
          disabled: const StyleProps(opacity: 0.5),
        ),
        child: const TextButton(onPressed: null, child: Text('x')),
      ),
    );
    expect(css, contains('[aria-disabled="true"]){'));
    expect(css, endsWith('[aria-disabled="true"]){opacity: 0.5}}'));
  });
}
