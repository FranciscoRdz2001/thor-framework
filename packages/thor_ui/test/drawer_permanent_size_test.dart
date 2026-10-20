@TestOn('vm')
library;

// A `Drawer(permanentFrom:)` that is 320 px as a modal and 200 px
// (with its own padding) as an inline panel, with no `Styled.when` around it.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

String _head(String html) => html.substring(0, html.indexOf('</head>'));

void main() {
  setUpAll(initializeThorTests);

  Future<String> css(Drawer d) async =>
      _head(await renderDocument(ThorApp(child: Row(children: [d]))));

  test(
    'permanentWidth and permanentPadding apply only to the inline panel',
    () async {
      final head = await css(
        const Drawer(
          id: 'f',
          width: 320,
          padding: EdgeInsets.all(16),
          permanentFrom: WindowSizeClass.medium,
          permanentWidth: 200,
          permanentPadding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('x'),
        ),
      );
      // The modal keeps its own size.
      expect(head, contains('width: min(320px, 85vw)'));
      expect(head, contains('padding: 16px'));
      // The inline panel (closed, from the breakpoint) has the permanent ones.
      expect(
        RegExp(
          r'min-width: 600px\)\{[^@]*:not\(\[open\]\)\{[^}]*width: 200px',
        ).hasMatch(head),
        isTrue,
        reason: head,
      );
      expect(
        RegExp(
          r'min-width: 600px\)\{[^@]*:not\(\[open\]\)\{[^}]*padding: 0px 8px',
        ).hasMatch(head),
        isTrue,
        reason: head,
      );
    },
  );

  test('without them the inline panel keeps width and padding', () async {
    final head = await css(
      const Drawer(
        id: 'f',
        width: 320,
        permanentFrom: WindowSizeClass.medium,
        child: Text('x'),
      ),
    );
    expect(
      RegExp(r':not\(\[open\]\)\{[^}]*width: 200px').hasMatch(head),
      isFalse,
    );
  });

  test('the inline panel does not scroll itself; the modal does', () async {
    final head = await css(
      const Drawer(
        id: 'f',
        permanentFrom: WindowSizeClass.medium,
        child: Text('x'),
      ),
    );
    // A sticky box inside the inline panel sticks to the page's scroll.
    expect(
      RegExp(
        r'min-width: 600px\)\{[^@]*:not\(\[open\]\)\{[^}]*overflow: visible',
      ).hasMatch(head),
      isTrue,
      reason: head,
    );
    expect(head, contains('overflow-y: auto'));
  });

  test('permanentWidth without permanentFrom is rejected', () {
    expect(
      () => Drawer(id: 'f', permanentWidth: 200, child: const Text('x')),
      throwsA(isA<AssertionError>()),
    );
  });
}
