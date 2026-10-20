# thor_test

Test tooling for thor apps, the way `flutter_test` is for Flutter. Add it as
a **dev dependency**; `thor_ui` (a runtime dependency) carries none of it, so
`matcher` and `html` never reach a production build.

```yaml
dev_dependencies:
  test: ^1.25.0
  thor_test:
```

```dart
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';

void main() {
  final app = appHandler().client(); // a visitor: cookies, same-origin headers

  test('signing in redirects to the account', () async {
    final login = await app.post('/login?/signin', form: {'user': 'ana'});
    expect(login, redirectsTo('/account'));
  });
}
```

`package:thor_test/thor_test.dart` exports:

- `handler.client()` (`ThorTestClient`) and its responses, `hasStatus` and
  `redirectsTo` (need `matcher`).
- Widget tests, like `testWidgets` and `find`: `testThor` (`ThorTester`),
  `find` (`Finder`, `find.byRole` with `SemanticsRole`) and `findsOneWidget`,
  `findsNothing`, `findsNWidgets`, `findsWidgets`.
- HTTP mocks for the app's outgoing requests: `withHttpMock`
  (`MockTransport`), `withHttpFixtures` (`ThorHttpFixture`) and
  `UnmockedHttpRequest`.
- Contrast checks for a theme: `contrastRatio`, `schemeContrast`,
  `themeContrast`, `expectThemeContrast` (`ContrastPair`).
- `HttpHeader`, the key type of the client's `headers:`.
- Everything in `package:thor_ui/testing.dart`: `initializeThorTests`,
  `renderHtml`, `renderDocument`, `withThorNow`, `runAppScript`.

```dart
testThor('greets', (tester) async {
  await tester.pumpWidget(const Text('Hi'));
  expect(find.text('Hi'), findsOneWidget);
});
```

Why a separate package: Flutter pins `matcher` and `test_api` through
`flutter_test` (a dev dependency); a runtime `matcher` in `thor_ui` would
clash with hybrid apps. The dependencies here are ranges, so both resolve.
Guide: [docs/guia/en/testing.md](../../docs/guia/en/testing.md).
