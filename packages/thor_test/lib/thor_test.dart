/// Test tooling for thor apps, the counterpart of Flutter's `flutter_test`:
/// add it as a `dev_dependency`.
///
/// ```dart
/// import 'package:test/test.dart';
/// import 'package:thor_test/thor_test.dart';
///
/// void main() {
///   final app = appHandler().client();
///   test('the home renders', () async {
///     final home = await app.get('/');
///     expect(home, hasStatus(200));
///   });
/// }
/// ```
///
/// Widget tests with finders, like `testWidgets` and `find`:
///
/// ```dart
/// testThor('greets', (tester) async {
///   await tester.pumpWidget(const Text('Hi'));
///   expect(find.text('Hi'), findsOneWidget);
/// });
/// ```
///
/// It exports the render helpers of `package:thor_ui/testing.dart`
/// (`initializeThorTests`, `renderHtml`, `withThorNow`…) too, so one import
/// is enough.
library;

// The key type of the client's `headers:`.
export 'package:thor_server/thor_server.dart' show HttpHeader;
export 'package:thor_ui/testing.dart';
// `find.byRole` takes a role; tests should not need the full facade for it.
export 'package:thor_ui/thor_ui.dart' show SemanticsRole;

export 'src/contrast.dart'
    show
        ContrastPair,
        contrastRatio,
        expectThemeContrast,
        schemeContrast,
        themeContrast;
export 'src/finders.dart'
    show
        CommonFinders,
        Finder,
        find,
        findsNWidgets,
        findsNothing,
        findsOneWidget,
        findsWidgets;
export 'src/http_fixtures.dart'
    show
        MockTransport,
        ThorHttpFixture,
        UnmockedHttpRequest,
        withHttpFixtures,
        withHttpMock;
export 'src/test_client.dart'
    show
        ThorCallResponse,
        ThorTestClient,
        ThorTestClientOf,
        ThorTestResponse,
        hasStatus,
        redirectsTo;
export 'src/tester.dart' show ThorTester, testThor;
