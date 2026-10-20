// Flutter-like widget tests: testThor, find.* and the finds* matchers.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  testThor('find.text matches a Text exactly', (tester) async {
    await tester.pumpWidget(
      const Column(children: [Text('Hi'), Text('Hi there')]),
    );
    expect(find.text('Hi'), findsOneWidget);
    expect(find.text('Hi there'), findsOneWidget);
    expect(find.text('H'), findsNothing);
  });

  testThor('find.text reads a Text.rich as a whole, not by fragments', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Text.rich(
        TextSpan(
          text: 'Hola ',
          children: [
            TextSpan(
              text: 'mundo',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
    expect(find.text('Hola mundo'), findsOneWidget);
    expect(find.text('Hola'), findsNothing);
    expect(find.text('mundo'), findsNothing);
  });

  testThor('find.text finds a Text.rich once, and a WidgetSpan text alone', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Column(
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Solo',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Text.rich(
            TextSpan(
              text: 'See ',
              children: [
                TextSpan(
                  text: 'bold',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                WidgetSpan(child: Text('chip')),
              ],
            ),
          ),
        ],
      ),
    );
    expect(find.text('Solo'), findsOneWidget);
    expect(find.text('See bold'), findsOneWidget);
    expect(find.text('chip'), findsOneWidget);
  });

  testThor('find.textContaining matches substrings and patterns', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Column(children: [Text('Cold brew'), Text('Hot brew')]),
    );
    expect(find.textContaining('brew'), findsNWidgets(2));
    expect(find.textContaining('Cold'), findsOneWidget);
    expect(find.textContaining(RegExp('^(Cold|Hot)')), findsWidgets);
    expect(find.textContaining('tea'), findsNothing);
  });

  testThor('styles and scripts are never text', (tester) async {
    await tester.pumpWidget(
      ElevatedButton(onPressed: () {}, child: const Text('Go')),
    );
    expect(find.textContaining('@layer'), findsNothing);
    expect(find.text('Go'), findsOneWidget);
  });

  testThor('find.bySemanticsLabel is exact for a String', (tester) async {
    await tester.pumpWidget(const Semantics(label: 'Close', child: Text('x')));
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    expect(find.bySemanticsLabel('Clos'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Clo')), findsOneWidget);
  });

  testThor('find.bySemanticsIdentifier reads the id', (tester) async {
    await tester.pumpWidget(
      const Semantics(identifier: 'save', child: Text('Save')),
    );
    expect(find.bySemanticsIdentifier('save'), findsOneWidget);
    expect(find.bySemanticsIdentifier('load'), findsNothing);
  });

  testThor('find.byRole matches tags and ARIA roles', (tester) async {
    await tester.pumpWidget(
      const Column(
        children: [
          Semantics(role: SemanticsRole.navigation, child: Text('n')),
          Semantics(role: SemanticsRole.alert, child: Text('a')),
        ],
      ),
    );
    expect(find.byRole(SemanticsRole.navigation), findsOneWidget);
    expect(find.byRole(SemanticsRole.alert), findsOneWidget);
    expect(find.byRole(SemanticsRole.main), findsNothing);
  });

  testThor('find.byTooltip finds the anchored element', (tester) async {
    await tester.pumpWidget(
      const Tooltip(message: 'Delete', child: Text('Bin')),
    );
    expect(find.byTooltip('Delete'), findsOneWidget);
    expect(tester.widgetHtml(find.byTooltip('Delete')), contains('Bin'));
    expect(find.byTooltip('Other'), findsNothing);
  });

  testThor('find.byTag and descendant', (tester) async {
    await tester.pumpWidget(
      Column(
        children: [
          Semantics(
            role: SemanticsRole.navigation,
            child: ElevatedButton(onPressed: () {}, child: const Text('In')),
          ),
          ElevatedButton(onPressed: () {}, child: const Text('Out')),
        ],
      ),
    );
    expect(find.byTag('button'), findsNWidgets(2));
    final nav = find.byRole(SemanticsRole.navigation);
    expect(
      find.descendant(of: nav, matching: find.byTag('button')),
      findsOneWidget,
    );
    expect(find.descendant(of: nav, matching: find.text('Out')), findsNothing);
    // The scope itself is not a descendant.
    expect(
      find.descendant(of: nav, matching: find.byRole(SemanticsRole.navigation)),
      findsNothing,
    );
  });

  testThor('first, last and at pick one match', (tester) async {
    await tester.pumpWidget(
      const Column(children: [Text('a'), Text('b'), Text('c')]),
    );
    final spans = find.byTag('span');
    expect(spans, findsNWidgets(3));
    expect(tester.widgetHtml(spans.first), contains('a'));
    expect(tester.widgetHtml(spans.last), contains('c'));
    expect(tester.widgetHtml(spans.at(1)), contains('b'));
    expect(find.text('zzz').first, findsNothing);
  });

  testThor('widgetHtml gives the element for attribute checks', (tester) async {
    await tester.pumpWidget(
      ElevatedButton(onPressed: () {}, child: const Text('Go')),
    );
    final html = tester.widgetHtml(find.text('Go'));
    expect(html, startsWith('<button'));
    expect(html, contains('type="button"'));
    expect(tester.html, contains('Go'));
  });

  testThor('widgetHtml fails unless exactly one element matches', (
    tester,
  ) async {
    await tester.pumpWidget(const Column(children: [Text('a'), Text('b')]));
    expect(() => tester.widgetHtml(find.byTag('span')), throwsStateError);
    expect(() => tester.widgetHtml(find.text('z')), throwsStateError);
  });

  testThor('pumpWidget replaces the previous render', (tester) async {
    await tester.pumpWidget(const Text('one'));
    expect(find.text('one'), findsOneWidget);
    await tester.pumpWidget(const Text('two'));
    expect(find.text('one'), findsNothing);
    expect(find.text('two'), findsOneWidget);
  });

  testThor('nothing is found before pumpWidget', (tester) async {
    expect(find.text('x'), findsNothing);
  });

  group('matchers', () {
    testThor('explain the mismatch', (tester) async {
      await tester.pumpWidget(const Column(children: [Text('a'), Text('a')]));
      expect(
        () => expect(find.text('a'), findsOneWidget),
        throwsA(
          isA<TestFailure>().having(
            (e) => e.message,
            'message',
            allOf(contains('found 2 widgets'), contains('text "a"')),
          ),
        ),
      );
      expect(
        () => expect(find.text('a'), findsNothing),
        throwsA(isA<TestFailure>()),
      );
      expect(
        () => expect(find.text('b'), findsWidgets),
        throwsA(isA<TestFailure>()),
      );
      expect(
        () => expect(find.text('a'), findsNWidgets(3)),
        throwsA(isA<TestFailure>()),
      );
    });

    testThor('reject what is not a Finder', (tester) async {
      expect(() => expect('x', findsOneWidget), throwsA(isA<TestFailure>()));
    });
  });

  test('a finder outside testThor says why it cannot run', () {
    expect(() => find.text('x').evaluate(), throwsStateError);
  });
}
