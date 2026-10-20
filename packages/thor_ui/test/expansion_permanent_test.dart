@TestOn('vm')
library;

// `ExpansionTile(permanentFrom:)`, an accordion below a breakpoint
// and an always-open plain block from it up (one DOM, CSS only).
import 'package:test/test.dart';
import 'package:thor_ui/src/engine/permanent_script.dart' show permanentScript;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

String _head(String html) => html.substring(0, html.indexOf('</head>'));

Future<String> _page(Widget w) => renderDocument(ThorApp(child: w));

void main() {
  setUpAll(initializeThorTests);

  test('from the breakpoint the content shows although the tile is closed '
      'and the summary is no control', () async {
    final head = _head(
      await _page(
        const ExpansionTile(
          permanentFrom: WindowSizeClass.medium,
          title: Text('Help'),
          children: [Text('FAQ')],
        ),
      ),
    );
    final md = RegExp(
      r'@media screen and \(min-width: 600px\)\{(.*)',
    ).firstMatch(head)![1]!;
    expect(md, contains('::details-content'));
    expect(md, contains('content-visibility: visible'));
    // The summary stops being clickable and its chevron goes away, only in
    // a browser that has `::details-content` (else the accordion must stay
    // operable at every width).
    expect(md, contains('@supports selector(::details-content)'));
    final supported = md.substring(md.indexOf('@supports'));
    expect(supported, contains('pointer-events: none'));
    expect(supported, contains('summary::after'));
    expect(supported, contains('display: none'));
    expect(
      md.substring(0, md.indexOf('@supports')),
      isNot(contains('pointer-events')),
      reason: 'no rule on the summary outside @supports',
    );
  });

  test('the page ships the script that takes the header out of the Tab '
      'order, once, with the width of the breakpoint', () async {
    final html = await _page(
      const Column(
        children: [
          ExpansionTile(
            permanentFrom: WindowSizeClass.medium,
            title: Text('A'),
            children: [Text('a')],
          ),
          ExpansionTile(
            permanentFrom: WindowSizeClass.expanded,
            title: Text('B'),
            children: [Text('b')],
          ),
        ],
      ),
    );
    expect(html, contains('data-thor-pf="600"'));
    expect(html, contains('data-thor-pf="840"'));
    expect(
      RegExp(RegExp.escape(permanentScript)).allMatches(html),
      hasLength(1),
    );
  });

  test('a page without it ships no script', () async {
    final html = await _page(
      const ExpansionTile(title: Text('Help'), children: [Text('FAQ')]),
    );
    expect(html, isNot(contains('data-thor-pf')));
    expect(html, isNot(contains(permanentScript)));
  });

  test('the tile is one <details> with the usual markup', () async {
    final html = await _page(
      const ExpansionTile(
        permanentFrom: WindowSizeClass.medium,
        title: Text('Help'),
        children: [Text('FAQ')],
      ),
    );
    expect(RegExp('<details').allMatches(html), hasLength(1));
    expect(html, contains('<summary'));
    // Below the breakpoint it is the accordion it always was: not open.
    expect(html, isNot(contains(' open')));
  });

  test('without permanentFrom nothing changes', () async {
    final head = _head(
      await _page(
        const ExpansionTile(title: Text('Help'), children: [Text('FAQ')]),
      ),
    );
    expect(head, isNot(contains('content-visibility: visible')));
    expect(head, isNot(contains('pointer-events: none')));
  });
}
